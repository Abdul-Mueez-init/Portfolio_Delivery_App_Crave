import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/owner_bottom_nav.dart';
import '../../../shops/application/owner_shop_provider.dart';
import '../../application/orders_provider.dart';
import '../../application/owner_orders_provider.dart';
import '../../data/models/fulfillment_type.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/orders_repository.dart';

/// design.md screen 17 — real `placed`+ orders for this shop, grouped
/// by status. Accept/Reject/advance write directly via OrdersRepository;
/// the screen never manually re-fetches after a mutation —
/// shopOrdersProvider is a Realtime StreamProvider (architecture.md
/// §4), so the DB write alone is enough to update the UI, same pattern
/// as the customer's Order Tracking screen.
class OrderQueueScreen extends ConsumerWidget {
  const OrderQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(myShopProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Order Queue',
            style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary)),
      ),
      body: shopAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, s) => ErrorView(
          message: "We couldn't load your shop.",
          onRetry: () => ref.invalidate(myShopProvider),
        ),
        data: (shop) {
          if (shop == null) {
            return const ErrorView(
                title: 'No shop found',
                message: 'Complete Shop Onboarding first.');
          }
          return _OrderQueueBody(shopId: shop.id);
        },
      ),
      bottomNavigationBar: const OwnerBottomNav(currentIndex: 1),
    );
  }
}

class _OrderQueueBody extends ConsumerWidget {
  const _OrderQueueBody({required this.shopId});
  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(shopOrdersProvider(shopId));

    return ordersAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, s) {
        return ErrorView(
          message: "We couldn't load your orders.",
          onRetry: () => ref.invalidate(shopOrdersProvider(shopId)),
        );
      },
      data: (orders) {
        // FLAGGED SCOPE DECISION: completed/cancelled orders need no
        // owner action, so they're left out of the Queue entirely — an
        // owner-side order history view is a reasonable V2 addition,
        // not required for this MVP screen (design.md screen 17 only
        // shows New/Preparing/Ready sections, no history section).
        final active = orders
            .where((o) =>
                o.status != OrderStatus.completed &&
                o.status != OrderStatus.cancelled)
            .toList();

        if (active.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No active orders',
            message: 'New orders will show up here the moment they come in.',
          );
        }

        final newOrders =
            active.where((o) => o.status == OrderStatus.placed).toList();
        final preparing = active
            .where((o) =>
                o.status == OrderStatus.confirmed ||
                o.status == OrderStatus.preparing)
            .toList();
        final ready = active
            .where((o) =>
                o.status == OrderStatus.ready ||
                o.status == OrderStatus.outForDelivery)
            .toList();

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.marginMain),
          children: [
            if (newOrders.isNotEmpty)
              _StatusSection(
                title: 'New',
                count: newOrders.length,
                color: AppColors.error,
                children: newOrders.map((o) => _OrderCard(order: o)).toList(),
              ),
            if (preparing.isNotEmpty)
              _StatusSection(
                title: 'Preparing',
                count: preparing.length,
                color: AppColors.warning,
                children: preparing.map((o) => _OrderCard(order: o)).toList(),
              ),
            if (ready.isNotEmpty)
              _StatusSection(
                title: 'Ready',
                count: ready.length,
                color: AppColors.success,
                children: ready.map((o) => _OrderCard(order: o)).toList(),
              ),
          ],
        );
      },
    );
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({
    required this.title,
    required this.count,
    required this.color,
    required this.children,
  });
  final String title;
  final int count;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: AppTextStyles.headlineMd),
            const SizedBox(width: AppSpacing.stackSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull)),
              child: Text('$count',
                  style: AppTextStyles.labelCaps.copyWith(color: color)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.stackSm),
        ...children.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.stackSm),
            child: c)),
        const SizedBox(height: AppSpacing.stackMd),
      ],
    );
  }
}

class _OrderCard extends ConsumerStatefulWidget {
  const _OrderCard({required this.order});
  final OrderModel order;

  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<_OrderCard> {
  bool _isBusy = false;

  Future<void> _run(Future<Object?> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Something went wrong. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final repo = ref.read(ordersRepositoryProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${order.id.substring(0, 6).toUpperCase()}',
                        style: AppTextStyles.headlineMd),
                    if (order.customerName != null)
                      Text('Customer: ${order.customerName}',
                          style: AppTextStyles.bodySm),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${order.total.toStringAsFixed(2)}',
                      style: AppTextStyles.headlineMd
                          .copyWith(color: AppColors.primary)),
                  const SizedBox(height: AppSpacing.stackSm),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            order.fulfillmentType == FulfillmentType.delivery
                                ? Icons.delivery_dining
                                : Icons.storefront,
                            size: 14),
                        const SizedBox(width: 4),
                        Text(
                            order.fulfillmentType == FulfillmentType.delivery
                                ? 'Delivery'
                                : 'Pickup',
                            style: AppTextStyles.bodySm),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.stackSm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.stackSm),
            decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${order.itemCount} Items',
                    style: AppTextStyles.bodySm
                        .copyWith(fontWeight: FontWeight.w600)),
                for (final item in order.items)
                  Text('${item.quantity}x ${item.menuItemName ?? 'Item'}',
                      style: AppTextStyles.bodySm),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          _ActionRow(order: order, isBusy: _isBusy, repo: repo, onRun: _run),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.order,
    required this.isBusy,
    required this.repo,
    required this.onRun,
  });

  final OrderModel order;
  final bool isBusy;
  final OrdersRepository repo;
  final Future<void> Function(Future<Object?> Function()) onRun;

  @override
  Widget build(BuildContext context) {
    switch (order.status) {
      case OrderStatus.placed:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isBusy
                    ? null
                    : () => onRun(() => repo.rejectOrder(order.id)),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: AppSpacing.stackSm),
            Expanded(
              child: ElevatedButton(
                onPressed: isBusy
                    ? null
                    : () => onRun(() => repo.acceptOrder(order.id)),
                child: const Text('Accept'),
              ),
            ),
          ],
        );
      case OrderStatus.confirmed:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isBusy
                ? null
                : () => onRun(() => repo.advanceOrderStatus(
                    orderId: order.id,
                    expectedCurrentStatus: OrderStatus.confirmed,
                    nextStatus: OrderStatus.preparing)),
            child: const Text('Start Preparing'),
          ),
        );
      case OrderStatus.preparing:
        final next = order.fulfillmentType == FulfillmentType.delivery
            ? OrderStatus.outForDelivery
            : OrderStatus.ready;
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isBusy
                ? null
                : () => onRun(() => repo.advanceOrderStatus(
                    orderId: order.id,
                    expectedCurrentStatus: OrderStatus.preparing,
                    nextStatus: next)),
            child: Text(order.fulfillmentType == FulfillmentType.delivery
                ? 'Send Out for Delivery'
                : 'Mark Ready'),
          ),
        );
      case OrderStatus.ready:
      case OrderStatus.outForDelivery:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isBusy
                ? null
                : () => onRun(() => repo.advanceOrderStatus(
                    orderId: order.id,
                    expectedCurrentStatus: order.status,
                    nextStatus: OrderStatus.completed)),
            child: const Text('Mark Completed'),
          ),
        );
      case OrderStatus.completed:
      case OrderStatus.cancelled:
        return const SizedBox.shrink();
    }
  }
}
