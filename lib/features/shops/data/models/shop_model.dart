/// Maps 1:1 to the `shops` table — ERD.md §2.
class ShopModel {
  const ShopModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.coverImageUrl,
    required this.address,
    this.lat,
    this.lng,
    required this.acceptsDelivery,
    required this.acceptsBooking,
    required this.isOpen,
    required this.category,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String coverImageUrl;
  final String address;
  final double? lat;
  final double? lng;
  final bool acceptsDelivery;
  final bool acceptsBooking;
  final bool isOpen;
  final String category;
  final DateTime createdAt;

  factory ShopModel.fromMap(Map<String, dynamic> map) {
    return ShopModel(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      coverImageUrl: (map['cover_image_url'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      acceptsDelivery: map['accepts_delivery'] as bool? ?? false,
      acceptsBooking: map['accepts_booking'] as bool? ?? false,
      isOpen: map['is_open'] as bool? ?? false,
      // Falls back to 'Other' rather than throwing — a shop missing a
      // category shouldn't crash the whole list, just filter oddly.
      category: (map['category'] as String?) ?? 'Other',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
