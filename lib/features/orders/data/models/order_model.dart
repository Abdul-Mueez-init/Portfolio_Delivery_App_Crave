import 'fulfillment_type.dart';

/// Maps to the `orders.status` enum('placed','confirmed','preparing',
/// 'ready','out_for_delivery','completed','cancelled') — ERD.md §2.
/// Forward-only progression except -> cancelled, per rules.md §2.
enum OrderStatus {
  placed,
  confirmed,
  preparing,
  ready,
  outForDelivery,
  completed,
  cancelled,
}

extension OrderStatusX on OrderStatus {
  String toDb() {
    return this == OrderStatus.outForDelivery ? 'out_for_delivery' : name;
  }

  static OrderStatus fromDb(String value) {
    if (value == 'out_for_delivery') return OrderStatus.outForDelivery;
    return OrderStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => OrderStatus.placed,
    );
  }

  /// Display label — design.md §4: status must read conversational,
  /// not like a raw enum ("Order Status: In Transit").
  String get label {
    switch (this) {
      case OrderStatus.placed:
        return 'Order Placed';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready for Pickup';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Maps to `orders.payment_status` enum('pending','paid','failed',
/// 'refunded') — ERD.md §2.
enum PaymentStatus { pending, paid, failed, refunded }

extension PaymentStatusX on PaymentStatus {
  String toDb() => name;

  static PaymentStatus fromDb(String value) {
    return PaymentStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PaymentStatus.pending,
    );
  }
}

/// Maps to `order_items` — ERD.md §2. [menuItemName]/[menuItemImageUrl]
/// are only populated when fetched via a joined select (see
/// OrdersRepository.fetchOrderById) — same pattern as
/// BookingModel/BookingDetail's shop/slot fields.
class OrderItemModel {
  const OrderItemModel({
    required this.id,
    required this.orderId,
    required this.menuItemId,
    required this.quantity,
    required this.unitPrice,
    this.notes,
    this.menuItemName,
    this.menuItemImageUrl,
  });

  final String id;
  final String orderId;
  final String menuItemId;
  final int quantity;
  final double unitPrice;
  final String? notes;
  final String? menuItemName;
  final String? menuItemImageUrl;

  double get lineTotal => unitPrice * quantity;

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      menuItemId: map['menu_item_id'] as String,
      quantity: map['quantity'] as int,
      unitPrice: (map['unit_price'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }

  /// Parses a row shaped by `.select('*, menu_items(name, image_url)')`
  /// on order_items, as used inside OrdersRepository.fetchOrderById.
  factory OrderItemModel.fromJoinedMap(Map<String, dynamic> map) {
    final base = OrderItemModel.fromMap(map);
    final menuItem = map['menu_items'] as Map<String, dynamic>?;
    return OrderItemModel(
      id: base.id,
      orderId: base.orderId,
      menuItemId: base.menuItemId,
      quantity: base.quantity,
      unitPrice: base.unitPrice,
      notes: base.notes,
      menuItemName: menuItem?['name'] as String?,
      menuItemImageUrl: menuItem?['image_url'] as String?,
    );
  }
}

/// Maps 1:1 to the `orders` table — ERD.md §2. [shopName]/
/// [shopCoverImageUrl] and [items] are only populated via
/// OrdersRepository.fetchOrderById's joined select — a bare
/// OrderModel.fromMap (e.g. from a raw insert response) has an empty
/// items list and null shop fields.
class OrderModel {
  const OrderModel({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.fulfillmentType,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
    this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    this.items = const [],
    this.shopName,
    this.shopCoverImageUrl,
    this.customerName,
  });

  final String id;
  final String shopId;
  final String customerId;
  final FulfillmentType fulfillmentType;
  final OrderStatus status;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final PaymentStatus paymentStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final List<OrderItemModel> items;

  final String? shopName;
  final String? shopCoverImageUrl;

  /// Owner-side only — populated by OrdersRepository.fetchShopOrders's
  /// joined select (design.md screen 17's "Customer: Jane Doe" line on
  /// each Order Queue card). Null on every other fetch path — the
  /// customer's own fetchOrderById has no reason to join their own name
  /// back to themselves.
  final String? customerName;

  /// rules.md §2: customer can only cancel while still `placed` or
  /// `confirmed` — once `preparing` starts, food's already being made.
  bool get isCancellable =>
      status == OrderStatus.placed || status == OrderStatus.confirmed;

  /// Total line items on this order (sum of quantities, not distinct
  /// menu items) — used by Activity's order row badge ("3 items").
  /// Only meaningful when [items] was populated via a joined fetch
  /// (OrdersRepository.fetchOrderById) — 0 on a bare OrderModel.fromMap.
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'] as String,
      shopId: map['shop_id'] as String,
      customerId: map['customer_id'] as String,
      fulfillmentType:
          FulfillmentTypeX.fromDb(map['fulfillment_type'] as String),
      status: OrderStatusX.fromDb(map['status'] as String),
      subtotal: (map['subtotal'] as num).toDouble(),
      deliveryFee: (map['delivery_fee'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      paymentStatus: PaymentStatusX.fromDb(map['payment_status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deliveryAddress: map['delivery_address'] as String?,
      deliveryLat: (map['delivery_lat'] as num?)?.toDouble(),
      deliveryLng: (map['delivery_lng'] as num?)?.toDouble(),
    );
  }

  /// Parses a row shaped by OrdersRepository.fetchOrderById's select:
  /// `'*, shops(name, cover_image_url), order_items(*, menu_items(name, image_url))'`
  /// or by fetchShopOrders's select, which additionally joins
  /// `users!customer_id(full_name)` for [customerName].
  factory OrderModel.fromJoinedMap(Map<String, dynamic> map) {
    final base = OrderModel.fromMap(map);
    final shop = map['shops'] as Map<String, dynamic>?;
    final customer = map['users'] as Map<String, dynamic>?;
    final itemRows = (map['order_items'] as List<dynamic>? ?? []);
    return OrderModel(
      id: base.id,
      shopId: base.shopId,
      customerId: base.customerId,
      fulfillmentType: base.fulfillmentType,
      status: base.status,
      subtotal: base.subtotal,
      deliveryFee: base.deliveryFee,
      total: base.total,
      paymentStatus: base.paymentStatus,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      deliveryAddress: base.deliveryAddress,
      deliveryLat: base.deliveryLat,
      deliveryLng: base.deliveryLng,
      shopName: shop?['name'] as String?,
      shopCoverImageUrl: shop?['cover_image_url'] as String?,
      customerName: customer?['full_name'] as String?,
      items: itemRows
          .map((row) =>
              OrderItemModel.fromJoinedMap(row as Map<String, dynamic>))
          .toList(),
    );
  }
}
