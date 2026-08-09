import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../cart/data/models/cart_item_model.dart';
import '../models/fulfillment_type.dart';
import '../models/order_model.dart';

/// Follows the same pattern as BookingsRepository/ShopsRepository: plain
/// class wrapping SupabaseClient, throws on failure, client injected.
///
/// PERMANENT DESIGN DECISION (confirmed by the project owner, Phase H):
/// payment stays simulated for good — Stripe test mode isn't usable
/// from Pakistan, so this is not a "swap for real Stripe later" stub.
/// createOrder inserts the order directly at status='placed',
/// payment_status='paid', as if payment already succeeded.
/// architecture.md §6 / rules.md §2 still hold (placed != confirmed —
/// only the owner's Accept moves it there) — only the *payment capture
/// step itself* is simulated. CheckoutScreen adds a cosmetic-only
/// "Add Card" UI beat (fake card number/expiry fields, no validation,
/// no gateway call) purely so the flow *feels* like a payment
/// happened — it does not feed into this method at all.
class OrdersRepository {
  OrdersRepository(this._client);
  final SupabaseClient _client;

  /// Creates a real `orders` row plus its `order_items` rows.
  ///
  /// NOT wrapped in a single atomic RPC (unlike bookings' capacity
  /// RPC) — there's no concurrency-sensitive constraint here, just two
  /// sequential inserts. If the order_items insert fails after the
  /// order insert succeeds, the order is left as a real 'placed' row
  /// with no items — rare (network drop mid-checkout), not auto-rolled-
  /// back client-side for MVP.
  Future<OrderModel> createOrder({
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
    final customerId = _client.auth.currentUser?.id;
    if (customerId == null) {
      throw StateError('createOrder called with no signed-in user.');
    }

    // rules.md §2: delivery_address/lat/lng required if delivery,
    // forbidden (null) if pickup.
    if (fulfillmentType == FulfillmentType.delivery &&
        (deliveryAddress == null || deliveryAddress.trim().isEmpty)) {
      throw ArgumentError('deliveryAddress is required for delivery orders.');
    }

    final orderRow = await _client
        .from('orders')
        .insert({
          'shop_id': shopId,
          'customer_id': customerId,
          'fulfillment_type': fulfillmentType.toDb(),
          'status': 'placed',
          'delivery_address': fulfillmentType == FulfillmentType.delivery
              ? deliveryAddress
              : null,
          'delivery_lat':
              fulfillmentType == FulfillmentType.delivery ? deliveryLat : null,
          'delivery_lng':
              fulfillmentType == FulfillmentType.delivery ? deliveryLng : null,
          'subtotal': subtotal,
          'delivery_fee': deliveryFee,
          'total': total,
          // Simulated payment success — see class doc comment.
          'payment_status': 'paid',
        })
        .select()
        .single();

    final orderId = orderRow['id'] as String;

    // unit_price is a snapshot at order time (rules.md §5) — taken
    // from the cart line, not re-read from menu_items.
    final itemRows = cartItems
        .map((item) => {
              'order_id': orderId,
              'menu_item_id': item.menuItemId,
              'quantity': item.quantity,
              'unit_price': item.price,
              'notes': item.notes,
            })
        .toList();

    await _client.from('order_items').insert(itemRows);

    return fetchOrderById(orderId);
  }

  /// Fetches one order with shop + items (+ each item's menu_item
  /// name/image) joined in, for Checkout's confirmation and Tracking.
  Future<OrderModel> fetchOrderById(String orderId) async {
    final row = await _client
        .from('orders')
        .select(
            '*, shops(name, cover_image_url), order_items(*, menu_items(name, image_url))')
        .eq('id', orderId)
        .single();
    return OrderModel.fromJoinedMap(row);
  }

  /// All orders for the signed-in customer, newest first, with shop
  /// name + items joined in — Activity's Orders tab (design.md
  /// screen 14). One-shot fetch (not Realtime) — refreshed via
  /// Activity's pull-to-refresh, same pattern as bookings.
  Future<List<OrderModel>> fetchCustomerOrders() async {
    final customerId = _client.auth.currentUser?.id;
    if (customerId == null) {
      throw StateError('fetchCustomerOrders called with no signed-in user.');
    }

    final rows = await _client
        .from('orders')
        .select(
            '*, shops(name, cover_image_url), order_items(*, menu_items(name, image_url))')
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => OrderModel.fromJoinedMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Realtime order tracking — architecture.md §4: subscribes to
  /// Postgres changes on `orders` filtered by `id`. Emits the full
  /// joined order (re-fetched, not the raw changed row) on the initial
  /// snapshot and every change after, so the UI never merges partial
  /// data — matches rules.md §6's "always visible, never silently
  /// stale" requirement.
  Stream<OrderModel> watchOrder(String orderId) async* {
    yield await fetchOrderById(orderId);

    final changes =
        _client.from('orders').stream(primaryKey: ['id']).eq('id', orderId);

    await for (final _ in changes) {
      yield await fetchOrderById(orderId);
    }
  }

  /// Customer-side cancel — rules.md §2: only while status is still
  /// `placed` or `confirmed`. The status filter makes this a no-op (0
  /// rows updated, returns null) rather than a silent override if
  /// status already advanced past that between the UI's isCancellable
  /// check and this call.
  ///
  /// NOTE: unlike bookings' cancel_booking RPC, this is a plain update
  /// — there's no capacity to release here, just a status write, so
  /// the same atomicity concern doesn't apply. RLS (customers can only
  /// update their own orders) is the real security boundary.
  Future<OrderModel?> cancelOrder(String orderId) async {
    final rows = await _client
        .from('orders')
        .update({'status': 'cancelled'})
        .eq('id', orderId)
        .inFilter('status', ['placed', 'confirmed'])
        .select();

    if ((rows as List).isEmpty) return null;
    return fetchOrderById(orderId);
  }

  /// Owner-side: every order for [shopId], newest first, items joined
  /// in — Order Queue needs item names/qty for each card's "3 Items"
  /// summary (design.md screen 17). No shops join here — the owner
  /// already knows which shop they're viewing.
  Future<List<OrderModel>> fetchShopOrders(String shopId) async {
    final rows = await _client
        .from('orders')
        .select(
            '*, order_items(*, menu_items(name, image_url)), users!customer_id(full_name)')
        .eq('shop_id', shopId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => OrderModel.fromJoinedMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Realtime Order Queue — architecture.md §4, same re-fetch-on-change
  /// pattern as watchOrder (never merges partial payloads), filtered by
  /// shop_id instead of id.
  Stream<List<OrderModel>> watchShopOrders(String shopId) async* {
    yield await fetchShopOrders(shopId);

    final changes =
        _client.from('orders').stream(primaryKey: ['id']).eq('shop_id', shopId);

    await for (final _ in changes) {
      yield await fetchShopOrders(shopId);
    }
  }

  /// Owner's Accept action — rules.md §2: placed -> confirmed. Scoped
  /// to status='placed' so a stale double-tap (or a customer who
  /// cancelled first) is a no-op, not a silent override.
  Future<OrderModel?> acceptOrder(String orderId) async {
    final rows = await _client
        .from('orders')
        .update({'status': 'confirmed'})
        .eq('id', orderId)
        .eq('status', 'placed')
        .select();
    if ((rows as List).isEmpty) return null;
    return fetchOrderById(orderId);
  }

  /// Owner's Reject action — rules.md §2/§4: placed -> cancelled, plus
  /// the refund path. Payment is simulated (see class doc comment), so
  /// "refund" for MVP is writing payment_status='refunded' in the same
  /// update — there's no real Stripe refund call yet. When real Stripe
  /// lands, this is the method that grows a refund API call.
  Future<OrderModel?> rejectOrder(String orderId) async {
    final rows = await _client
        .from('orders')
        .update({'status': 'cancelled', 'payment_status': 'refunded'})
        .eq('id', orderId)
        .eq('status', 'placed')
        .select();
    if ((rows as List).isEmpty) return null;
    return fetchOrderById(orderId);
  }

  /// Owner's forward status advances (rules.md §2): confirmed->preparing,
  /// preparing->ready/out_for_delivery, ready/out_for_delivery->completed.
  /// [expectedCurrentStatus] guards against a stale UI advancing an order
  /// that already moved — same no-op-if-mismatched pattern as above.
  Future<OrderModel?> advanceOrderStatus({
    required String orderId,
    required OrderStatus expectedCurrentStatus,
    required OrderStatus nextStatus,
  }) async {
    final rows = await _client
        .from('orders')
        .update({'status': nextStatus.toDb()})
        .eq('id', orderId)
        .eq('status', expectedCurrentStatus.toDb())
        .select();
    if ((rows as List).isEmpty) return null;
    return fetchOrderById(orderId);
  }
}
