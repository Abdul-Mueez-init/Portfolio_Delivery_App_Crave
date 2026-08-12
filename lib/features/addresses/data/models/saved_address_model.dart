/// Maps 1:1 to the `saved_addresses` table added by
/// `supabase/fix_booking_rpcs_saved_addresses_payment_methods.sql`.
/// Same pattern as `TimeSlotModel`/`BookingModel` — a plain immutable
/// class with a `fromMap` factory and a `toInsertMap` for writes.
class SavedAddressModel {
  const SavedAddressModel({
    required this.id,
    required this.userId,
    required this.address,
    required this.isDefault,
    required this.createdAt,
    this.label,
    this.lat,
    this.lng,
  });

  final String id;
  final String userId;

  /// Optional short name ("Home", "Work") — nullable, shown above the
  /// full address when set, falls back to a generic "Saved address"
  /// label in the UI when null.
  final String? label;

  final String address;
  final double? lat;
  final double? lng;
  final bool isDefault;
  final DateTime createdAt;

  factory SavedAddressModel.fromMap(Map<String, dynamic> map) {
    return SavedAddressModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      label: map['label'] as String?,
      address: map['address'] as String,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      isDefault: map['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
