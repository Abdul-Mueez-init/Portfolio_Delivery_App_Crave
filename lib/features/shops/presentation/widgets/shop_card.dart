import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/shop_model.dart';

class ShopCard extends StatelessWidget {
  const ShopCard({super.key, required this.shop, required this.onTap});

  final ShopModel shop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: shop.isOpen ? 1 : 0.85,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: [
              BoxShadow(
                color: AppColors.onSurface.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: 192,
                    width: double.infinity,
                    child: shop.coverImageUrl.isEmpty
                        ? Container(color: AppColors.surfaceContainerHigh)
                        : Image.network(
                            shop.coverImageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                  color: AppColors.surfaceContainerHigh);
                            },
                            errorBuilder: (context, error, stack) => Container(
                                color: AppColors.surfaceContainerHigh),
                          ),
                  ),
                  Positioned(
                    top: AppSpacing.stackMd,
                    left: AppSpacing.stackMd,
                    child: _StatusBadge(isOpen: shop.isOpen),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.stackMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: AppTextStyles.headlineMd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            shop.category,
                            style: AppTextStyles.bodySm,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.stackSm),
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.secondary),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            shop.address,
                            style: AppTextStyles.bodySm,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isOpen});
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.08),
              blurRadius: 4),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(isOpen ? 'Open' : 'Closed',
              style: AppTextStyles.labelCaps.copyWith(color: color)),
        ],
      ),
    );
  }
}
