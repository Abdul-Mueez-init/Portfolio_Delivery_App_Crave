-- ============================================================
-- Crave — Fix batch: booking RPCs + Saved Addresses + Payment Methods
-- ============================================================
-- Run this whole file in the Supabase SQL Editor. Safe to re-run
-- (CREATE OR REPLACE FUNCTION, IF NOT EXISTS on tables/policies).
--
-- WHAT THIS FIXES:
--
-- 1) Booking crash ("Couldn't complete the booking. Please try again." /
--    Null check operator used on a null value):
--    `book_time_slot` and `cancel_booking` are the two RPCs the app
--    (bookings_repository.dart) calls. If your Supabase project never
--    had them created — or they exist with a different signature/return
--    shape than the client sends — every call fails, and the client
--    surfaced that as an unhelpful null-check crash before this fix
--    batch's Dart-side hardening. This section (re)creates both
--    functions with the EXACT signature the app calls:
--      book_time_slot(p_slot_id uuid, p_party_size int, p_customer_id uuid)
--      cancel_booking(p_booking_id uuid)
--    and both return the full `bookings` row (not the `time_slots`
--    row) — that's the shape BookingModel.fromMap() in the app expects.
--
-- 2) Adds `saved_addresses` and `payment_methods` tables (previously
--    "coming in a later phase" placeholders on the Profile screen).
-- ============================================================


-- ------------------------------------------------------------
-- 1a. book_time_slot — atomic capacity check + insert
-- ------------------------------------------------------------
-- Mirrors architecture.md §11's UPDATE ... WHERE booked_capacity +
-- :party_size <= max_party_capacity pattern, then inserts the booking
-- row inside the SAME function so both happen atomically or not at
-- all (SECURITY DEFINER + a single statement-level transaction —
-- Postgres functions are transactional by default).
create or replace function book_time_slot(
  p_slot_id uuid,
  p_party_size int,
  p_customer_id uuid
)
returns bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop_id uuid;
  v_booking bookings;
begin
  if p_party_size is null or p_party_size < 1 then
    raise exception 'INVALID_PARTY_SIZE: party size must be at least 1';
  end if;

  -- Atomic conditional update — this is the real "no double booking"
  -- guarantee (ERD.md §3 / architecture.md §11). If two customers hit
  -- this at once, Postgres's row lock on the UPDATE serializes them;
  -- the second evaluates the WHERE clause against the already-
  -- incremented row and correctly finds no match.
  update time_slots
  set booked_capacity = booked_capacity + p_party_size
  where id = p_slot_id
    and booked_capacity + p_party_size <= max_party_capacity
  returning shop_id into v_shop_id;

  if v_shop_id is null then
    -- Either the slot doesn't exist, or it exists but doesn't have
    -- room. booking_flow_provider.dart specifically greps the error
    -- string for "SLOT_FULL" to show a friendly "that slot just
    -- filled up" message — keep this prefix if you ever touch this.
    raise exception 'SLOT_FULL: this time slot no longer has room for that party size';
  end if;

  insert into bookings (shop_id, customer_id, time_slot_id, party_size, status)
  values (v_shop_id, p_customer_id, p_slot_id, p_party_size, 'pending')
  returning * into v_booking;

  return v_booking;
end;
$$;

grant execute on function book_time_slot(uuid, int, uuid) to authenticated;


-- ------------------------------------------------------------
-- 1b. cancel_booking — releases capacity, callable by the customer
--     who made the booking OR the owner of that booking's shop
--     (booking_confirmation_screen.dart calls this for customers;
--     booking_calendar_screen.dart calls it for owners — see
--     bookings_repository.dart's two call sites).
-- ------------------------------------------------------------
create or replace function cancel_booking(
  p_booking_id uuid
)
returns bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking bookings;
  v_is_owner boolean;
begin
  select * into v_booking from bookings where id = p_booking_id for update;

  if v_booking is null then
    raise exception 'BOOKING_NOT_FOUND: no booking with id %', p_booking_id;
  end if;

  select exists(
    select 1 from shops
    where shops.id = v_booking.shop_id
      and shops.owner_id = auth.uid()
  ) into v_is_owner;

  if v_booking.customer_id <> auth.uid() and not v_is_owner then
    raise exception 'NOT_AUTHORIZED: you can only cancel your own booking or one at a shop you own';
  end if;

  if v_booking.status = 'cancelled' then
    -- Already cancelled (e.g. a double-tap) — no-op, return as-is
    -- rather than double-releasing capacity.
    return v_booking;
  end if;

  update bookings
  set status = 'cancelled'
  where id = p_booking_id
  returning * into v_booking;

  -- rules.md §3 / architecture.md §11: releasing capacity on cancel is
  -- as load-bearing as the increment on create — without this a
  -- cancelled slot stays permanently "full."
  update time_slots
  set booked_capacity = greatest(0, booked_capacity - v_booking.party_size)
  where id = v_booking.time_slot_id;

  return v_booking;
end;
$$;

grant execute on function cancel_booking(uuid) to authenticated;


-- ------------------------------------------------------------
-- 2a. saved_addresses
-- ------------------------------------------------------------
-- Backs the customer's Saved Addresses screen (profile_screen.dart).
-- Capped at 4 per user via the trigger below, per the product ask
-- ("scalable... maybe 3-4 addresses").
create table if not exists saved_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  label text, -- e.g. "Home", "Work" — optional, nullable
  address text not null,
  lat float8,
  lng float8,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

alter table saved_addresses enable row level security;

drop policy if exists "saved_addresses_select_own" on saved_addresses;
create policy "saved_addresses_select_own" on saved_addresses
  for select using (user_id = auth.uid());

drop policy if exists "saved_addresses_insert_own" on saved_addresses;
create policy "saved_addresses_insert_own" on saved_addresses
  for insert with check (user_id = auth.uid());

drop policy if exists "saved_addresses_update_own" on saved_addresses;
create policy "saved_addresses_update_own" on saved_addresses
  for update using (user_id = auth.uid());

drop policy if exists "saved_addresses_delete_own" on saved_addresses;
create policy "saved_addresses_delete_own" on saved_addresses
  for delete using (user_id = auth.uid());

-- Cap at 4 saved addresses per user, enforced server-side (not just
-- disabled in the UI) — same "enforce it for real" pattern as the
-- booking capacity RPC.
create or replace function enforce_saved_address_limit()
returns trigger
language plpgsql
as $$
begin
  if (select count(*) from saved_addresses where user_id = new.user_id) >= 4 then
    raise exception 'ADDRESS_LIMIT: you can save up to 4 addresses. Delete one first.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_saved_address_limit on saved_addresses;
create trigger trg_enforce_saved_address_limit
  before insert on saved_addresses
  for each row execute function enforce_saved_address_limit();

-- Only one default address per user — setting a new default clears
-- the old one, done here rather than trusted to the client.
create or replace function enforce_single_default_address()
returns trigger
language plpgsql
as $$
begin
  if new.is_default then
    update saved_addresses
    set is_default = false
    where user_id = new.user_id
      and id <> new.id
      and is_default = true;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_single_default_address on saved_addresses;
create trigger trg_enforce_single_default_address
  before insert or update on saved_addresses
  for each row execute function enforce_single_default_address();


-- ------------------------------------------------------------
-- 2b. payment_methods
-- ------------------------------------------------------------
-- Backs the Payment Methods screen. This app's payment is permanently
-- simulated (architecture.md / checkout_screen.dart's _FakeCardSection
-- doc comment) — so this table intentionally stores NOTHING sensitive:
-- no full card number, no CVV, ever. Only what a real payment
-- processor's tokenized "saved card" API would ever hand back to a
-- client to render a card picker: brand + last 4 digits + expiry.
create table if not exists payment_methods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  brand text not null, -- 'visa' | 'mastercard' | 'amex' | 'unknown'
  last4 text not null,
  expiry_month int,
  expiry_year int,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

alter table payment_methods enable row level security;

drop policy if exists "payment_methods_select_own" on payment_methods;
create policy "payment_methods_select_own" on payment_methods
  for select using (user_id = auth.uid());

drop policy if exists "payment_methods_insert_own" on payment_methods;
create policy "payment_methods_insert_own" on payment_methods
  for insert with check (user_id = auth.uid());

drop policy if exists "payment_methods_update_own" on payment_methods;
create policy "payment_methods_update_own" on payment_methods
  for update using (user_id = auth.uid());

drop policy if exists "payment_methods_delete_own" on payment_methods;
create policy "payment_methods_delete_own" on payment_methods
  for delete using (user_id = auth.uid());

create or replace function enforce_single_default_payment_method()
returns trigger
language plpgsql
as $$
begin
  if new.is_default then
    update payment_methods
    set is_default = false
    where user_id = new.user_id
      and id <> new.id
      and is_default = true;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_single_default_payment_method on payment_methods;
create trigger trg_enforce_single_default_payment_method
  before insert or update on payment_methods
  for each row execute function enforce_single_default_payment_method();

-- ============================================================
-- Done. Verify with:
--   select proname from pg_proc where proname in ('book_time_slot','cancel_booking');
--   select * from saved_addresses limit 1;
--   select * from payment_methods limit 1;
-- ============================================================
