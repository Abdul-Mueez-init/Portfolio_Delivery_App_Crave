import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/fulfillment_type.dart';
import '../../data/models/order_model.dart';

/// Status stepper for Order Tracking — design.md §5 screen 11. The 4th
/// step's label swaps based on fulfillmentType since a real order only
/// ever has ONE of ready/out_for_delivery (ERD.md §2), never both.
class OrderStatusTimeline extends StatelessWidget {
  const OrderStatusTimeline({
    super.key,
    required this.status,
    required this.fulfillmentType,
  });

  final OrderStatus status;
  final FulfillmentType fulfillmentType;

  List<OrderStatus> get _steps => [
        OrderStatus.placed,
        OrderStatus.confirmed,
        OrderStatus.preparing,
        fulfillmentType == FulfillmentType.delivery
            ? OrderStatus.outForDelivery
            : OrderStatus.ready,
        OrderStatus.completed,
      ];

  @override
  Widget build(BuildContext context) {
    if (status == OrderStatus.cancelled) return const _CancelledBanner();

    final steps = _steps;
    final currentIndex = steps.indexOf(status);

    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineStep(
            label: steps[i].label,
            isDone: i < currentIndex,
            isCurrent: i == currentIndex,
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

  final String label;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isActive = isDone || isCurrent;
    final lineColor = isDone ? AppColors.success : AppColors.outlineVariant;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.success
                      : AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isActive
                          ? AppColors.success
                          : AppColors.outlineVariant,
                      width: 2),
                ),
                child: isDone
                    ? const Icon(Icons.check,
                        size: 14, color: AppColors.onPrimary)
                    : null,
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: lineColor)),
            ],
          ),
          const SizedBox(width: AppSpacing.stackMd),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.stackLg),
              child: Text(
                label,
                style: AppTextStyles.bodyLg.copyWith(
                  color: isActive ? AppColors.onSurface : AppColors.secondary,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelledBanner extends StatelessWidget {
  const _CancelledBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackMd),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.cancel_outlined, color: AppColors.error),
          const SizedBox(width: AppSpacing.stackSm),
          Text('This order was cancelled.',
              style: AppTextStyles.bodyLg
                  .copyWith(color: AppColors.onErrorContainer)),
        ],
      ),
    );
  }
}
