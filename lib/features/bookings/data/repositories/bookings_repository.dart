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

  /// Books a slot via the atomic `book_time_slot` RPC — NOT a raw
  /// insert into `bookings` (PLAN.md Phase 6 is explicit about this;
  /// ERD.md §3 / architecture.md §11 explain why a plain insert can't
  /// safely guard capacity under concurrent bookings).
  ///
  /// Matches the real Phase 1 function signature: `book_time_slot(
  /// p_slot_id uuid, p_party_size int, p_customer_id uuid)`. Note there
  /// is no `p_shop_id` param — the function looks the slot's shop up
  /// itself (via the `returning shop_id into v_shop_id` on its capacity
  /// update) and stamps it onto the new `bookings` row, so passing one
  /// from the client would be redundant. `p_customer_id` is passed
  /// explicitly rather than the function reading `auth.uid()` itself,
  /// so it's supplied here from the current Supabase session.
  ///
  /// Raises (as a PostgrestException) with a `SLOT_FULL: ...` message
  /// if capacity ran out between the UI greying-out check and this
  /// call — that's the real concurrent-booking race rules.md §3 calls
  /// out, not a bug if you see it.
  Future<BookingModel> bookTimeSlot({
    required String timeSlotId,
    required int partySize,
  }) async {
    final customerId = _client.auth.currentUser?.id;
    if (customerId == null) {
      throw StateError('bookTimeSlot called with no signed-in user.');
    }

    final result = await _client.rpc('book_time_slot', params: {
      'p_slot_id': timeSlotId,
      'p_party_size': partySize,
      'p_customer_id': customerId,
    });

    // The function returns a single `bookings` row (`returns bookings`
    // in plpgsql) — PostgREST hands that back as a Map. Handled
    // defensively in case a future change returns a set instead.
    final Map<String, dynamic> row = result is List
        ? (result.first as Map<String, dynamic>)
        : (result as Map<String, dynamic>);

    return BookingModel.fromMap(row);
  }

  /// Cancels a booking via the matching `cancel_booking` RPC:
  /// `cancel_booking(p_booking_id uuid)`, which decrements
  /// `time_slots.booked_capacity` by the booking's `party_size` and
  /// sets `bookings.status = 'cancelled'` — rules.md §3 is explicit
  /// this is a correctness requirement, not optional cleanup. The
  /// function returns the updated `bookings` row.
  ///
  /// Raises with a `BOOKING_NOT_FOUND: ...` or `ALREADY_CANCELLED: ...`
  /// message (PostgrestException) if the booking id doesn't exist or
  /// was already cancelled — the UI should catch this and show a
  /// friendly message rather than a raw exception string.
  ///
  /// No cancellation-cutoff check (e.g. "not within 1 hour of the
  /// slot") is enforced here — rules.md §3 marks that as an open
  /// [ASSUMPTION] the person hasn't confirmed, and this Phase 1
  /// function doesn't implement one. If a cutoff is added later, it
  /// belongs inside this RPC (server-side, same reasoning as the
  /// capacity check) — a client-side-only cutoff could be bypassed.
  Future<BookingModel> cancelBooking(String bookingId) async {
    final result = await _client.rpc('cancel_booking', params: {
      'p_booking_id': bookingId,
    });
    final Map<String, dynamic> row = result is List
        ? (result.first as Map<String, dynamic>)
        : (result as Map<String, dynamic>);
    return BookingModel.fromMap(row);
  }

  /// Fetches one booking with its shop + time slot joined in, for the
  /// Booking Confirmation screen (shown right after booking, and again
  /// from Activity — design.md screen 14).
  Future<BookingModel> fetchBookingById(String bookingId) async {
    final row = await _client
        .from('bookings')
        .select('*, shops(name, cover_image_url), time_slots(slot_time)')
        .eq('id', bookingId)
        .single();
    return BookingModel.fromJoinedMap(row);
  }
}
