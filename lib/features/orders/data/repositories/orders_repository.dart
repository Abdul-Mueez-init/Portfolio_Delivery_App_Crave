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
  /// Postgres changes on `orders` filtered by `id`.
  ///
  /// PERFORMANCE FIX (was: full re-fetch-with-joins on every event):
  /// supabase_flutter's `.stream()` already hands back the current raw
  /// `orders` row on every change — the previous version discarded that
  /// payload (`await for (final _ in changes)`) and paid for a full
  /// joined re-fetch anyway, on every single status update. The joined
  /// data (shop name/cover, order_items+menu_items) never changes after
  /// an order is created (rules.md §5: order_items are a price
  /// snapshot), so there's nothing to re-fetch — only scalar columns
  /// like `status`/`updated_at` change. We merge the raw row onto the
  /// cached joined model via OrderModel.copyWith instead, which is a
  /// pure in-memory operation, zero extra network round trips, and
  /// still satisfies rules.md §6 (status always live, never stale)
  /// since every real change still reaches the UI immediately.
  Stream<OrderModel> watchOrder(String orderId) async* {
    OrderModel current = await fetchOrderById(orderId);
    yield current;

    final changes =
        _client.from('orders').stream(primaryKey: ['id']).eq('id', orderId);

    await for (final rows in changes) {
      if (rows.isEmpty)
        continue; // order no longer matches; keep last known state
      final raw = OrderModel.fromMap(rows.first);
      current = current.copyWith(
        fulfillmentType: raw.fulfillmentType,
        status: raw.status,
        subtotal: raw.subtotal,
        deliveryFee: raw.deliveryFee,
        total: raw.total,
        paymentStatus: raw.paymentStatus,
        updatedAt: raw.updatedAt,
        deliveryAddress: raw.deliveryAddress,
        deliveryLat: raw.deliveryLat,
        deliveryLng: raw.deliveryLng,
      );
      yield current;
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

  /// Realtime Order Queue — architecture.md §4.
  ///
  /// PERFORMANCE FIX (was: re-fetched the WHOLE shop's order list, with
  /// joins on order_items+menu_items+users, on every single Realtime
  /// event — the highest-impact instance of this pattern in the app,
  /// since Order Queue is the owner's main screen and any one order's
  /// status change re-ran that query for every order the shop has).
  /// Same fix shape as watchOrder: `.stream()` already hands back the
  /// current raw row set matching the filter on every emission — we
  /// reconcile that against an in-memory cache instead of discarding it:
  ///   - an id already in the cache -> merge scalar fields in-memory,
  ///     no network call.
  ///   - an id not yet in the cache (a genuinely new order just landed)
  ///     -> fetch joins for THAT ONE row only, not the whole list.
  /// Net effect: a status update anywhere in the shop costs zero extra
  /// queries; only a brand-new incoming order costs one single-row
  /// joined fetch instead of a whole-list one.
  Stream<List<OrderModel>> watchShopOrders(String shopId) async* {
    final initial = await fetchShopOrders(shopId);
    final cache = <String, OrderModel>{for (final o in initial) o.id: o};
    yield _sortedByCreatedAtDesc(cache);

    final changes =
        _client.from('orders').stream(primaryKey: ['id']).eq('shop_id', shopId);

    await for (final rows in changes) {
      final incomingIds = <String>{};
      for (final rawRow in rows) {
        final raw = OrderModel.fromMap(rawRow);
        incomingIds.add(raw.id);
        final existing = cache[raw.id];
        if (existing == null) {
          // New order this cache hasn't seen — needs the join fetch for
          // item lines + customer name, but only for this one row.
          cache[raw.id] = await _fetchSingleShopOrder(raw.id);
        } else {
          cache[raw.id] = existing.copyWith(
            fulfillmentType: raw.fulfillmentType,
            status: raw.status,
            subtotal: raw.subtotal,
            deliveryFee: raw.deliveryFee,
            total: raw.total,
            paymentStatus: raw.paymentStatus,
            updatedAt: raw.updatedAt,
            deliveryAddress: raw.deliveryAddress,
            deliveryLat: raw.deliveryLat,
            deliveryLng: raw.deliveryLng,
          );
        }
      }
      // Defensive only — orders are never deleted (rules.md §5's same
      // "never delete, only deactivate" spirit applies here), so this
      // just guards against the filter no longer matching a cached row.
      cache.removeWhere((id, _) => !incomingIds.contains(id));
      yield _sortedByCreatedAtDesc(cache);
    }
  }

  /// Single-row equivalent of [fetchShopOrders]'s joined select, used by
  /// [watchShopOrders] so a brand-new order only costs a one-row fetch
  /// instead of re-fetching every order the shop has.
  Future<OrderModel> _fetchSingleShopOrder(String orderId) async {
    final row = await _client
        .from('orders')
        .select(
            '*, order_items(*, menu_items(name, image_url)), users!customer_id(full_name)')
        .eq('id', orderId)
        .single();
    return OrderModel.fromJoinedMap(row);
  }

  List<OrderModel> _sortedByCreatedAtDesc(Map<String, OrderModel> cache) {
    final list = cache.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
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
