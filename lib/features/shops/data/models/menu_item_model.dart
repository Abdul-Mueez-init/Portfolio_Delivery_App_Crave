/// Maps 1:1 to the `menu_items` table — ERD.md §2.
class MenuItemModel {
  const MenuItemModel({
    required this.id,
    required this.shopId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.isAvailable,
    required this.createdAt,
  });

  final String id;
  final String shopId;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final bool isAvailable;
  final DateTime createdAt;

  factory MenuItemModel.fromMap(Map<String, dynamic> map) {
    return MenuItemModel(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      price: (map['price'] as num).toDouble(),
      imageUrl: (map['image_url'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'Other',
      isAvailable: map['is_available'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
