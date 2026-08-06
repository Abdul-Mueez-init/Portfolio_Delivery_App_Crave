import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/cart_item_model.dart';

/// Cart is scoped to exactly one shop at a time, mirroring orders.shop_id
/// being a single FK (ERD.md). shopId is null when the cart is empty.
class CartState {
  const CartState({this.shopId, this.items = const []});

  final String? shopId;
  final List<CartItemModel> items;

  /// FLAGGED ASSUMPTION: no real tax/fees table or config exists yet —
  /// matches cart_updated's exact numbers (10% of subtotal, e.g.
  /// $21.50 -> $2.15). Revisit once a real tax rule (or delivery fee,
  /// which Checkout shows as its own separate line) is defined.
  static const double taxRate = 0.10;

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.lineTotal);

  double get taxAmount => subtotal * taxRate;

  double get total => subtotal + taxAmount;

  bool get isEmpty => items.isEmpty;
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  /// True if adding from `shopId` would mix items from two different
  /// shops. The UI (MenuTab/ItemDetailSheet) should confirm with the
  /// person before calling addItem after this returns true.
  bool belongsToDifferentShop(String shopId) {
    return state.shopId != null && state.shopId != shopId;
  }

  /// Adds one unit, or bumps quantity if the menu item is already in
  /// the cart (rules.md doesn't distinguish separate lines by notes for
  /// MVP — same menu item merges into one line).
  void addItem(String shopId, CartItemModel newItem) {
    final existingIndex =
        state.items.indexWhere((i) => i.menuItemId == newItem.menuItemId);

    if (existingIndex == -1) {
      state = CartState(shopId: shopId, items: [...state.items, newItem]);
      return;
    }

    final updated = [...state.items];
    final existing = updated[existingIndex];
    updated[existingIndex] = existing.copyWith(
      quantity: existing.quantity + newItem.quantity,
      notes: newItem.notes,
    );
    state = CartState(shopId: shopId, items: updated);
  }

  void incrementItem(String menuItemId) {
    final updated = state.items.map((item) {
      if (item.menuItemId != menuItemId) return item;
      return item.copyWith(quantity: item.quantity + 1);
    }).toList();
    state = CartState(shopId: state.shopId, items: updated);
  }

  /// Decrementing to 0 removes the line entirely.
  void decrementItem(String menuItemId) {
    final updated = <CartItemModel>[];
    for (final item in state.items) {
      if (item.menuItemId != menuItemId) {
        updated.add(item);
        continue;
      }
      if (item.quantity > 1) {
        updated.add(item.copyWith(quantity: item.quantity - 1));
      }
    }
    state = CartState(
      shopId: updated.isEmpty ? null : state.shopId,
      items: updated,
    );
  }

  /// Explicit remove, distinct from decrementing to 0 — trash icon on
  /// CartItemTile calls this directly regardless of current quantity.
  void removeItem(String menuItemId) {
    final updated =
        state.items.where((item) => item.menuItemId != menuItemId).toList();
    state = CartState(
      shopId: updated.isEmpty ? null : state.shopId,
      items: updated,
    );
  }

  /// Clears the cart — called when confirming a "start a new order?"
  /// switch to a different shop, or after a successful checkout.
  void clear() {
    state = const CartState();
  }

  int quantityOf(String menuItemId) {
    final match = state.items.where((i) => i.menuItemId == menuItemId);
    return match.isEmpty ? 0 : match.first.quantity;
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
