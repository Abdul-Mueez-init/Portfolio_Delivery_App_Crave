import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../application/orders_provider.dart';
import '../../data/models/order_model.dart';
import '../widgets/order_status_timeline.dart';

/// design.md §5 screen 11: status stepper, cancel button only while
/// placed/confirmed (rules.md §2). Subscribes via orderTrackingProvider's
/// Realtime stream — no manual refresh (rules.md §6, architecture.md §4).
class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  bool _isCancelling = false;

  Future<void> _handleCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep Order')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cancel Order')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      final repo = ref.read(ordersRepositoryProvider);
      final result = await repo.cancelOrder(widget.orderId);
      if (result == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  "Couldn't cancel — this order already started preparing.")),
        );
      }
      // No manual refresh needed — the cancel write fires the Realtime
      // event orderTrackingProvider is already subscribed to.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Couldn't cancel this order. Please try again.")),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderTrackingProvider(widget.orderId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Order Tracking'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: orderAsync.when(
        loading: () => const SkeletonLoader.detail(),
        error: (error, stack) => ErrorView(
          message: "We couldn't load this order right now. Please try again.",
          onRetry: () => ref.invalidate(orderTrackingProvider(widget.orderId)),
        ),
        data: (order) => _TrackingContent(
          order: order,
          isCancelling: _isCancelling,
          onCancel: _handleCancel,
        ),
      ),
    );
  }
}

class _TrackingContent extends StatelessWidget {
  const _TrackingContent({
    required this.order,
    required this.isCancelling,
    required this.onCancel,
  });

  final OrderModel order;
  final bool isCancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.marginMain),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(order.shopName ?? 'Your Order', style: AppTextStyles.headlineLg),
          const SizedBox(height: AppSpacing.stackSm),
          Text(
            order.status.label,
            style: AppTextStyles.bodyLg.copyWith(
              color: order.status == OrderStatus.cancelled
                  ? AppColors.error
                  : AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.stackLg),
          OrderStatusTimeline(
              status: order.status, fulfillmentType: order.fulfillmentType),
          const SizedBox(height: AppSpacing.stackLg),
          Text('Items', style: AppTextStyles.labelCaps),
          const SizedBox(height: AppSpacing.stackSm),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackSm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                        '${item.quantity}x ${item.menuItemName ?? 'Item'}',
                        style: AppTextStyles.bodyLg),
                  ),
                  Text('\$${item.lineTotal.toStringAsFixed(2)}',
                      style: AppTextStyles.bodyLg),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.stackMd),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: AppTextStyles.headlineMd),
              Text('\$${order.total.toStringAsFixed(2)}',
                  style: AppTextStyles.headlineMd
                      .copyWith(color: AppColors.primary)),
            ],
          ),
          if (order.isCancellable) ...[
            const SizedBox(height: AppSpacing.stackLg),
            CustomButton(
              label: 'Cancel Order',
              variant: CustomButtonVariant.secondary,
              isLoading: isCancelling,
              onPressed: onCancel,
            ),
          ],
        ],
      ),
    );
  }
}
