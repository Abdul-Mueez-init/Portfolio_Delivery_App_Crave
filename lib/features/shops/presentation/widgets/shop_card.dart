import 'package:cached_network_image/cached_network_image.dart';
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
    // SCROLL-PERFORMANCE FIX: this used to be `Opacity(opacity: ..., child:
    // <the whole card>)` — wrapping a Container that has a BoxShadow AND a
    // CachedNetworkImage in Opacity forces Flutter to render that entire
    // subtree to an offscreen buffer and composite it every frame it's
    // visible, for every closed shop in the list. That's the single most
    // common real-world Flutter scroll-jank cause. Fixed by:
    //  1. Only dimming the image itself (a small, isolated subtree) instead
    //     of the whole card.
    //  2. Dimming the text via color alpha (withValues) instead of Opacity
    //     — a color alpha costs nothing extra to paint, whereas Opacity
    //     always costs an offscreen composite.
    //  3. Wrapping the whole card in RepaintBoundary so its paint is cached
    //     independently of sibling cards during scroll.
    final isOpen = shop.isOpen;
    final textAlpha = isOpen ? 1.0 : 0.6;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
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
                        : Opacity(
                            // Small, isolated subtree — just the image, no
                            // shadow/text riding along in the same
                            // offscreen composite.
                            opacity: isOpen ? 1 : 0.85,
                            child: CachedNetworkImage(
                              imageUrl: shop.coverImageUrl,
                              fit: BoxFit.cover,
                              // Decode near the box's actual display size
                              // (192 logical px tall, ~2x for device pixel
                              // ratio) instead of the full 800x500 source —
                              // avoids decoding/holding a full-res bitmap
                              // in memory for every card in the list.
                              memCacheWidth: 800,
                              memCacheHeight: 400,
                              placeholder: (context, url) => Container(
                                  color: AppColors.surfaceContainerHigh),
                              errorWidget: (context, url, error) => Container(
                                  color: AppColors.surfaceContainerHigh),
                            ),
                          ),
                  ),
                  Positioned(
                    top: AppSpacing.stackMd,
                    left: AppSpacing.stackMd,
                    child: _StatusBadge(isOpen: isOpen),
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
                      style: AppTextStyles.headlineMd.copyWith(
                        color: (AppTextStyles.headlineMd.color ??
                                AppColors.onSurface)
                            .withValues(alpha: textAlpha),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            shop.category,
                            style: AppTextStyles.bodySm.copyWith(
                              color: (AppTextStyles.bodySm.color ??
                                      AppColors.onSurface)
                                  .withValues(alpha: textAlpha),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.stackSm),
                        Icon(Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.secondary
                                .withValues(alpha: textAlpha)),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            shop.address,
                            style: AppTextStyles.bodySm.copyWith(
                              color: (AppTextStyles.bodySm.color ??
                                      AppColors.onSurface)
                                  .withValues(alpha: textAlpha),
                            ),
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
