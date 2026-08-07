import 'booking_model.dart';

/// NOT a 1:1 table mapping (context.md's usual model rule) — this is a
/// joined read-model combining a `bookings` row with the shop's name/
/// category and the actual slot date+time, built specifically for
/// screens that *display* a booking (Booking Confirmation now; Activity's
/// booking list in Phase 7 will likely want the same shape). Mutations
/// (create/cancel) go through BookingModel + BookingRepository's RPC
/// calls, never through this class — it's read-only.
class BookingDetail {
  const BookingDetail({
    required this.booking,
    required this.shopName,
    required this.shopCategory,
    required this.slotTime,
  });

  final BookingModel booking;
  final String shopName;
  final String shopCategory;
  final DateTime slotTime;

  factory BookingDetail.fromMap(Map<String, dynamic> map) {
    final shop = map['shops'] as Map<String, dynamic>?;
    final slot = map['time_slots'] as Map<String, dynamic>?;

    return BookingDetail(
      booking: BookingModel.fromMap(map),
      shopName: (shop?['name'] as String?) ?? 'Shop',
      shopCategory: (shop?['category'] as String?) ?? '',
      // time_slot_id is NOT NULL on bookings (ERD.md §2), so this join
      // should never actually be null — the ! is intentional, a null
      // here means the FK relationship broke and we want a loud failure,
      // not a silently wrong confirmation screen.
      slotTime: DateTime.parse(slot!['slot_time'] as String).toLocal(),
    );
  }
}
