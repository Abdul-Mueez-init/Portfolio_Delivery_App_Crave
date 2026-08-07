/// Maps to the `bookings.status` enum('pending','confirmed','cancelled',
/// 'completed') — ERD.md §2. Same naming pattern as UserRole
/// (user_role.dart): a plain enum + a toDb/fromDb extension.
enum BookingStatus { pending, confirmed, cancelled, completed }

extension BookingStatusX on BookingStatus {
  String toDb() => name;

  static BookingStatus fromDb(String value) {
    return BookingStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => BookingStatus.pending,
    );
  }

  /// Display label — rules.md §3: pending -> confirmed (owner action) or
  /// -> cancelled. 'completed' is a future owner action, not used yet.
  String get label {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.completed:
        return 'Completed';
    }
  }
}

/// Maps 1:1 to the `bookings` table — ERD.md §2.
///
/// [shopName], [shopCoverImageUrl], and [slotTime] are only populated
/// when fetched via [BookingsRepository.fetchBookingById], which joins
/// `shops` and `time_slots` (Booking Confirmation needs to show shop
/// name + slot time without a second round trip). They're null on a
/// booking built from a bare `bookings` row.
class BookingModel {
  const BookingModel({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.timeSlotId,
    required this.partySize,
    required this.status,
    required this.createdAt,
    this.assignedTableLabel,
    this.shopName,
    this.shopCoverImageUrl,
    this.slotTime,
  });

  final String id;
  final String shopId;
  final String customerId;
  final String timeSlotId;
  final int partySize;
  final BookingStatus status;
  final DateTime createdAt;
  final String? assignedTableLabel;

  final String? shopName;
  final String? shopCoverImageUrl;
  final DateTime? slotTime;

  /// rules.md §3: "Customer can cancel a booking any time before the
  /// slot's start time" — draft, marked [ASSUMPTION] in rules.md, no
  /// cutoff enforced yet. See the doc comment on
  /// [BookingsRepository.cancelBooking] for where that cutoff would
  /// plug in if you decide to add one later.
  bool get isCancellable =>
      status != BookingStatus.cancelled &&
      status != BookingStatus.completed &&
      (slotTime == null || slotTime!.isAfter(DateTime.now()));

  factory BookingModel.fromMap(Map<String, dynamic> map) {
    return BookingModel(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      customerId: map['customer_id'] as String,
      timeSlotId: map['time_slot_id'] as String,
      partySize: map['party_size'] as int,
      status: BookingStatusX.fromDb(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      assignedTableLabel: map['assigned_table_label'] as String?,
    );
  }

  /// Parses a row shaped by the joined select in
  /// `fetchBookingById` — `.select('*, shops(name, cover_image_url), time_slots(slot_time)')`.
  factory BookingModel.fromJoinedMap(Map<String, dynamic> map) {
    final base = BookingModel.fromMap(map);
    final shop = map['shops'] as Map<String, dynamic>?;
    final slot = map['time_slots'] as Map<String, dynamic>?;
    return BookingModel(
      id: base.id,
      shopId: base.shopId,
      customerId: base.customerId,
      timeSlotId: base.timeSlotId,
      partySize: base.partySize,
      status: base.status,
      createdAt: base.createdAt,
      assignedTableLabel: base.assignedTableLabel,
      shopName: shop?['name'] as String?,
      shopCoverImageUrl: shop?['cover_image_url'] as String?,
      slotTime: slot?['slot_time'] != null
          ? DateTime.parse(slot!['slot_time'] as String).toLocal()
          : null,
    );
  }
}
