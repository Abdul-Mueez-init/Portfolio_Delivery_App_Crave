import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking_model.dart';
import '../models/time_slot_model.dart';

/// Thrown by [BookingsRepository] when a booking RPC (`book_time_slot`/
/// `cancel_booking`) returns data in a shape the client can't safely
/// use — see [BookingsRepository.bookTimeSlot]'s doc comment for why
/// this exists. `toString()` deliberately does NOT contain `SLOT_FULL`,
/// so `booking_flow_provider.dart`'s message-matching for the real
/// "someone else took the seat" case can't accidentally trigger on a
/// plumbing bug instead.
class BookingRpcException implements Exception {
  BookingRpcException(this.rpcName, this.detail);
  final String rpcName;
  final String detail;

  @override
  String toString() => 'BookingRpcException($rpcName): $detail';
}

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
  ///
  /// HARDENED (booking crash fix): the previous version assumed the RPC
  /// result was always either a `Map` or a `List` containing one, then
  /// cast straight into `BookingModel.fromMap`. If the `book_time_slot`
  /// function in Postgres doesn't exist yet, or its return shape doesn't
  /// match what this client sends/expects (e.g. it was written to return
  /// only the `time_slots` row per architecture.md §11's capacity-check
  /// snippet, rather than the inserted `bookings` row this app actually
  /// needs), `result` can come back as `null`, an empty list, or a shape
  /// that doesn't have the keys `BookingModel.fromMap` requires — any of
  /// which surfaces deep inside supabase_flutter/postgrest as exactly
  /// the "Null check operator used on a null value" crash reported, with
  /// no indication of which of those it actually was. This never trusts
  /// the shape blindly again — every branch either returns a real
  /// [BookingModel] or throws a [BookingRpcException] with a message
  /// that says which assumption broke, so the next debugging pass (or
  /// this fix batch's SQL migration) has an actual answer instead of a
  /// null-check stack trace pointing at framework internals.
  ///
  /// See `fix_07_booking_rpcs_saved_addresses_payment_methods.sql` for
  /// the matching `book_time_slot` function definition — it must accept
  /// exactly `p_slot_id uuid, p_party_size int, p_customer_id uuid` and
  /// return the full `bookings` row (not the `time_slots` row) for this
  /// method to succeed.
  Future<BookingModel> bookTimeSlot({
    required String timeSlotId,
    required int partySize,
  }) async {
    final customerId = _client.auth.currentUser?.id;

    if (customerId == null) {
      throw StateError('bookTimeSlot called with no signed-in user.');
    }

    final dynamic result = await _client.rpc(
      'book_time_slot',
      params: {
        'p_slot_id': timeSlotId,
        'p_party_size': partySize,
        'p_customer_id': customerId,
      },
    );

    final row = _extractSingleRow(result, rpcName: 'book_time_slot');
    return _parseBookingRow(row, rpcName: 'book_time_slot');
  }

  /// Cancels a booking via the matching `cancel_booking` RPC.
  /// See [bookTimeSlot]'s doc comment — same hardening applies here.
  Future<BookingModel> cancelBooking(String bookingId) async {
    final dynamic result = await _client.rpc(
      'cancel_booking',
      params: {
        'p_booking_id': bookingId,
      },
    );

    final row = _extractSingleRow(result, rpcName: 'cancel_booking');
    return _parseBookingRow(row, rpcName: 'cancel_booking');
  }

  /// Pulls one row map out of an RPC result that could legitimately be a
  /// `Map`, a `List<Map>` (Postgres functions returning `SETOF`/a single
  /// composite row are sometimes wrapped in an array by postgrest-dart),
  /// `null`, or an empty list. Throws a labeled [BookingRpcException]
  /// instead of letting a bad cast/null-check bubble up unexplained.
  Map<String, dynamic> _extractSingleRow(dynamic result,
      {required String rpcName}) {
    if (result == null) {
      throw BookingRpcException(
        rpcName,
        'returned no data. Most likely the `$rpcName` Postgres function '
        "either doesn't exist yet or raised without returning a row — "
        'run the SQL migration and check the Supabase logs for the '
        'underlying Postgres error.',
      );
    }
    if (result is List) {
      if (result.isEmpty) {
        throw BookingRpcException(
          rpcName,
          'returned an empty list — the function ran but produced no '
          'row (e.g. the capacity check filtered out the update). '
          'Expected exactly one row.',
        );
      }
      final first = result.first;
      if (first is Map<String, dynamic>) return first;
      throw BookingRpcException(
        rpcName,
        'returned a list whose first element was a ${first.runtimeType}, '
        'not a row map.',
      );
    }
    if (result is Map<String, dynamic>) return result;
    throw BookingRpcException(
      rpcName,
      'returned a ${result.runtimeType}, not a row map or list of rows.',
    );
  }

  /// [BookingModel.fromMap] requires `id`, `shop_id`, `customer_id`,
  /// `time_slot_id`, `party_size`, `status`, `created_at` to all be
  /// present with the right types. Checked explicitly here — with a
  /// message naming the missing/mismatched key — rather than letting a
  /// bad `map['...'] as String` cast fail deep inside the model with no
  /// context on which field was the problem.
  BookingModel _parseBookingRow(Map<String, dynamic> row,
      {required String rpcName}) {
    const requiredKeys = [
      'id',
      'shop_id',
      'customer_id',
      'time_slot_id',
      'party_size',
      'status',
      'created_at',
    ];
    final missing = requiredKeys.where((k) => row[k] == null).toList();
    if (missing.isNotEmpty) {
      throw BookingRpcException(
        rpcName,
        'returned a row missing required field(s): ${missing.join(', ')}. '
        'Got keys: ${row.keys.join(', ')}. This usually means the '
        'function is returning the wrong table (e.g. `time_slots` '
        'instead of `bookings`) — see the SQL migration.',
      );
    }
    try {
      return BookingModel.fromMap(row);
    } catch (e) {
      throw BookingRpcException(
        rpcName,
        'returned a row that failed to parse into a Booking: $e. '
        'Row keys: ${row.keys.join(', ')}.',
      );
    }
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
