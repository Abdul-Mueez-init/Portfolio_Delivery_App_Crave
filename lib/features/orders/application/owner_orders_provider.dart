import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/order_model.dart';
import 'orders_provider.dart';

/// Realtime Order Queue — architecture.md §4. Mirrors
/// orderTrackingProvider's shape but for the owner's whole shop instead
/// of one order. autoDispose + family per shopId: leaving Order Queue
/// tears the Realtime subscription down instead of leaking it.
final shopOrdersProvider =
    StreamProvider.autoDispose.family<List<OrderModel>, String>((ref, shopId) {
  final repo = ref.watch(ordersRepositoryProvider);
  return repo.watchShopOrders(shopId);
});
