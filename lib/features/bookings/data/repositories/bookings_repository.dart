import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking_model.dart';
import '../models/time_slot_model.dart';

/// Follows the same pattern as ShopsRepository/AuthRepository: plain
/// class wrapping SupabaseClient, throws on failure, client injected
/// rather than reached for as a singleton inside methods.
class BookingsRepository {
  BookingsRepository(this._client);

  final SupabaseClient _client;

  /// Fetches every `time_slots` row for [shopId] on the local calendar
  /// day of [date] — the grid on the Booking screen is always one day
  /// at a time (booking_screen_updated's date chips just change which
  /// day is queried, not a range).
  Future<List<TimeSlotModel>> fetchTimeSlotsForDate({
    required String shopId,
    required DateTime date,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final rows = await _client
        .from('time_slots')
        .select()
        .eq('shop_id', shopId)
        .gte('slot_time', startOfDay.toUtc().toIso8601String())
        .lt('slot_time', endOfDay.toUtc().toIso8601String())
        .order('slot_time', ascending: true);

    return (rows as List)
        .map((row) => TimeSlotModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Books a slot via the atomic `book_time_slot` RPC.
  Future<BookingModel> bookTimeSlot({
    required String timeSlotId,
    required int partySize,
  }) async {
    final customerId = _client.auth.currentUser?.id;

    if (customerId == null) {
      throw StateError('bookTimeSlot called with no signed-in user.');
    }

    final result = await _client.rpc(
      'book_time_slot',
      params: {
        'p_slot_id': timeSlotId,
        'p_party_size': partySize,
        'p_customer_id': customerId,
      },
    );

    final Map<String, dynamic> row = result is List
        ? (result.first as Map<String, dynamic>)
        : (result as Map<String, dynamic>);

    return BookingModel.fromMap(row);
  }

  /// Cancels a booking via the matching `cancel_booking` RPC.
  Future<BookingModel> cancelBooking(String bookingId) async {
    final result = await _client.rpc(
      'cancel_booking',
      params: {
        'p_booking_id': bookingId,
      },
    );

    final Map<String, dynamic> row = result is List
        ? (result.first as Map<String, dynamic>)
        : (result as Map<String, dynamic>);

    return BookingModel.fromMap(row);
  }

  /// Fetches one booking with its shop + time slot joined in, for the
  /// Booking Confirmation screen.
  Future<BookingModel> fetchBookingById(String bookingId) async {
    final row = await _client
        .from('bookings')
        .select('*, shops(name, cover_image_url), time_slots(slot_time)')
        .eq('id', bookingId)
        .single();

    return BookingModel.fromJoinedMap(row);
  }

  /// Owner-side: bookings for [shopId] on [date]'s local calendar day,
  /// joined with slot time — Booking Calendar groups rows by slot_time
  /// (design.md screen 18), same join shape as fetchTimeSlotsForDate
  /// just from the bookings side. `time_slots!inner` so the date-range
  /// filter on the joined table actually restricts rows (a plain join
  /// would let the filter silently no-op).
  Future<List<BookingModel>> fetchShopBookings({
    required String shopId,
    required DateTime date,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final rows = await _client
        .from('bookings')
        .select('*, shops(name, cover_image_url), time_slots!inner(slot_time)')
        .eq('shop_id', shopId)
        .gte('time_slots.slot_time', startOfDay.toUtc().toIso8601String())
        .lt('time_slots.slot_time', endOfDay.toUtc().toIso8601String())
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => BookingModel.fromJoinedMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Owner's confirm action — rules.md §3: pending -> confirmed. Scoped
  /// to status='pending' so a stale double-tap is a no-op.
  Future<BookingModel?> confirmBooking(String bookingId) async {
    final rows = await _client
        .from('bookings')
        .update({'status': 'confirmed'})
        .eq('id', bookingId)
        .eq('status', 'pending')
        .select();
    if ((rows as List).isEmpty) return null;
    return fetchBookingById(bookingId);
  }

  /// Owner assigns a table label (e.g. "Table 4") — ERD.md's
  /// assigned_table_label. Plain field write, independent of confirm,
  /// since the design shows Confirm and Assign Table as separate taps.
  Future<BookingModel> assignTable({
    required String bookingId,
    required String tableLabel,
  }) async {
    final row = await _client
        .from('bookings')
        .update({'assigned_table_label': tableLabel})
        .eq('id', bookingId)
        .select()
        .single();
    return BookingModel.fromMap(row);
  }

  /// Fetches every booking for the signed-in customer, newest first.
  ///
  /// Used by the Activity → Bookings tab. Joins the shop and time slot
  /// so BookingModel.fromJoinedMap() has the same payload shape as
  /// fetchBookingById().
  Future<List<BookingModel>> fetchBookingsForCustomer(
    String customerId,
  ) async {
    final rows = await _client
        .from('bookings')
        .select('*, shops(name), time_slots(slot_time)')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map(
          (row) => BookingModel.fromJoinedMap(
            row as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  // ── Owner Slot Management (Phase F) ─────────────────────────────

  /// Every upcoming slot for [shopId] — not scoped to a single day
  /// like fetchTimeSlotsForDate, since the owner needs to see/manage
  /// everything ahead, not just today. This becomes the real,
  /// ongoing source of bookable slots once an owner starts using it —
  /// seed.sql's one-time time_slots block becomes optional/demo-only,
  /// matching architecture.md §10's actual intent (see
  /// SESSION_HANDOFF_phaseAH_fixes.md Phase F).
  Future<List<TimeSlotModel>> fetchUpcomingSlotsForShop(String shopId) async {
    final rows = await _client
        .from('time_slots')
        .select()
        .eq('shop_id', shopId)
        .gte('slot_time', DateTime.now().toUtc().toIso8601String())
        .order('slot_time', ascending: true);
    return (rows as List)
        .map((row) => TimeSlotModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Owner's "+ Add Slot" — real insert into time_slots.
  /// booked_capacity always starts at 0 and is never set from the
  /// client — it's server-managed by book_time_slot/cancel_booking
  /// (architecture.md §11), same as every seed.sql row.
  Future<TimeSlotModel> createTimeSlot({
    required String shopId,
    required DateTime slotTime,
    required int maxPartyCapacity,
  }) async {
    final row = await _client
        .from('time_slots')
        .insert({
          'shop_id': shopId,
          'slot_time': slotTime.toUtc().toIso8601String(),
          'max_party_capacity': maxPartyCapacity,
          'booked_capacity': 0,
        })
        .select()
        .single();
    return TimeSlotModel.fromMap(row);
  }

  /// Owner's Edit action — capacity only. slot_time is intentionally
  /// not editable after creation (a customer may have already booked
  /// against this exact time); delete + recreate if the time itself
  /// needs to change.
  Future<TimeSlotModel> updateTimeSlotCapacity({
    required String slotId,
    required int maxPartyCapacity,
  }) async {
    final row = await _client
        .from('time_slots')
        .update({'max_party_capacity': maxPartyCapacity})
        .eq('id', slotId)
        .select()
        .single();
    return TimeSlotModel.fromMap(row);
  }

  /// Owner's delete action. Scoped to booked_capacity = 0 so this can
  /// never silently orphan an existing booking — deleting a slot with
  /// active bookings against it is refused server-side, not just
  /// discouraged in the UI (same "enforce it for real" pattern as the
  /// booking capacity RPCs).
  Future<void> deleteTimeSlot(String slotId) async {
    await _client
        .from('time_slots')
        .delete()
        .eq('id', slotId)
        .eq('booked_capacity', 0);
  }
}
