import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../data/models/cart_item_model.dart';

/// Matches cart_updated/code.html: 80x80 image, name + price stacked,
/// pill stepper below, trash icon pinned top-right of the card (not
/// swipe-to-delete — a persistent visible action).
class CartItemTile extends StatelessWidget {
  const CartItemTile({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartItemModel item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.05),
              blurRadius: 8),
        ],
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: item.imageUrl.isEmpty
                      ? Container(color: AppColors.surfaceContainerHigh)
                      : CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: AppColors.surfaceContainerHigh),
                          errorWidget: (context, url, error) =>
                              Container(color: AppColors.surfaceContainerHigh),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.gutter),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      // leaves room so the name never runs under the
                      // trash icon pinned top-right
                      padding: const EdgeInsets.only(right: 32),
                      child: Text(
                        item.name,
                        style: AppTextStyles.headlineMd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${item.price.toStringAsFixed(2)}',
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.secondary),
                    ),
                    const SizedBox(height: AppSpacing.stackSm),
                    QuantityStepper(
                      quantity: item.quantity,
                      minQuantity: 1,
                      compact: true,
                      onDecrement: onDecrement,
                      onIncrement: onIncrement,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.delete_outline,
                    size: 22, color: AppColors.outline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
