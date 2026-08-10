import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cart/data/models/cart_item_model.dart';
import '../data/models/fulfillment_type.dart';
import '../data/models/order_model.dart';
import 'orders_provider.dart';

class CheckoutState {
  const CheckoutState({this.isPlacingOrder = false, this.error});
  final bool isPlacingOrder;
  final String? error;

  CheckoutState copyWith({bool? isPlacingOrder, String? error}) {
    return CheckoutState(
      isPlacingOrder: isPlacingOrder ?? this.isPlacingOrder,
      error: error,
    );
  }
}

/// Thin wrapper around OrdersRepository.createOrder for Checkout's
/// loading/error state — the insert logic itself lives in the
/// repository so other screens could reuse it without this UI state.
class CheckoutNotifier extends StateNotifier<CheckoutState> {
  CheckoutNotifier(this._ref) : super(const CheckoutState());
  final Ref _ref;

  Future<OrderModel?> placeOrder({
    required String shopId,
    required FulfillmentType fulfillmentType,
    required List<CartItemModel> cartItems,
    required double subtotal,
    required double deliveryFee,
    required double total,
    String? deliveryAddress,
    double? deliveryLat,
    double? deliveryLng,
  }) async {
    state = state.copyWith(isPlacingOrder: true, error: null);
    try {
      final repo = _ref.read(ordersRepositoryProvider);
      final order = await repo.createOrder(
        shopId: shopId,
        fulfillmentType: fulfillmentType,
        cartItems: cartItems,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        total: total,
        deliveryAddress: deliveryAddress,
        deliveryLat: deliveryLat,
        deliveryLng: deliveryLng,
      );
      state = state.copyWith(isPlacingOrder: false);
      return order;
    } catch (e) {
      // Surface the real cause (e.g. an RLS 403) instead of swallowing
      // it into a generic message — same "don't silently paper over
      // blockers" pattern as menu_item_form_screen.dart/
      // shop_settings_screen.dart's error surfacing fix.
      state = state.copyWith(
        isPlacingOrder: false,
        error: "Couldn't place your order: $e",
      );
      return null;
    }
  }
}

final checkoutProvider =
    StateNotifierProvider<CheckoutNotifier, CheckoutState>((ref) {
  return CheckoutNotifier(ref);
});
