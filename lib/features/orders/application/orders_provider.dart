import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/order_model.dart';
import '../data/repositories/orders_repository.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(Supabase.instance.client);
});

/// Realtime order tracking stream — one instance per orderId.
/// autoDispose: leaving Order Tracking (no other widget watching this
/// orderId) tears the Realtime subscription down instead of leaking it.
final orderTrackingProvider =
    StreamProvider.autoDispose.family<OrderModel, String>((ref, orderId) {
  final repo = ref.watch(ordersRepositoryProvider);
  return repo.watchOrder(orderId);
});

/// All of the signed-in customer's orders, newest first — Activity's
/// Orders tab. autoDispose: leaving Activity tears the fetch down;
/// pull-to-refresh calls ref.invalidate(customerOrdersProvider).
final customerOrdersProvider =
    FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final repo = ref.watch(ordersRepositoryProvider);
  return repo.fetchCustomerOrders();
});
