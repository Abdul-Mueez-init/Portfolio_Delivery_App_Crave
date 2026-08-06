import '../../../shops/data/models/menu_item_model.dart';

/// A line in the local, ephemeral cart — not persisted until checkout
/// inserts real `order_items` rows (Phase 5, later batch).
class CartItemModel {
  const CartItemModel({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.quantity,
    this.notes,
  });

  final String menuItemId;
  final String name;
  final double price;
  final String imageUrl;
  final int quantity;
  final String? notes;

  double get lineTotal => price * quantity;

  CartItemModel copyWith({int? quantity, String? notes}) {
    return CartItemModel(
      menuItemId: menuItemId,
      name: name,
      price: price,
      imageUrl: imageUrl,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }

  factory CartItemModel.fromMenuItem(MenuItemModel item, {int quantity = 1}) {
    return CartItemModel(
      menuItemId: item.id,
      name: item.name,
      price: item.price,
      imageUrl: item.imageUrl,
      quantity: quantity,
    );
  }
}
