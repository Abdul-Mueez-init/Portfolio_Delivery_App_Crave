/// Maps 1:1 to the `time_slots` table — ERD.md §2.
class TimeSlotModel {
  const TimeSlotModel({
    required this.id,
    required this.shopId,
    required this.slotTime,
    required this.maxPartyCapacity,
    required this.bookedCapacity,
  });

  final String id;
  final String shopId;
  final DateTime slotTime;
  final int maxPartyCapacity;
  final int bookedCapacity;

  int get remainingCapacity => maxPartyCapacity - bookedCapacity;

  /// Mirrors the exact check the `book_time_slot` RPC enforces
  /// server-side (architecture.md §11) — used here only to grey out a
  /// slot in the UI before the person taps it. The RPC re-checks this
  /// atomically, so a slot that looks available here can still be
  /// rejected if someone else books it first (rules.md §3).
  bool canFit(int partySize) => bookedCapacity + partySize <= maxPartyCapacity;

  /// UI grouping only — the DB has no "meal period" column (ERD.md has
  /// no such field on `time_slots`). FLAGGED ASSUMPTION: splitting at
  /// 17:00 local time to match booking_screen_updated's LUNCH/DINNER
  /// section headers. Revisit if a shop's actual hours don't fit this
  /// split, or add a real column if this needs to be shop-configurable.
  bool get isLunch => slotTime.hour < 17;

  factory TimeSlotModel.fromMap(Map<String, dynamic> map) {
    return TimeSlotModel(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      slotTime: DateTime.parse(map['slot_time'] as String).toLocal(),
      maxPartyCapacity: map['max_party_capacity'] as int,
      bookedCapacity: map['booked_capacity'] as int,
    );
  }
}
