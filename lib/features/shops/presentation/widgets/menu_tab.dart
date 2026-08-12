import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../cart/application/cart_provider.dart';
import '../../../cart/data/models/cart_item_model.dart';
import '../../application/menu_provider.dart';
import '../../data/models/menu_item_model.dart';
import 'item_detail_sheet.dart';

/// Matches menu_updated/code.html: category-grouped item cards, each with
/// a lone "+" (not yet in cart) that becomes an inline pill stepper once
/// quantity > 0 — not a separate widget swap, same slot in the card.
/// Tapping the card body (not the +/stepper) opens the Item Detail sheet.
class MenuTab extends ConsumerWidget {
  const MenuTab({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(menuForShopProvider(shopId));

    return menuAsync.when(
      loading: () => const SkeletonLoader.list(),
      error: (error, stack) => ErrorView(
        message: "We couldn't load the menu right now. Please try again.",
        onRetry: () => ref.invalidate(menuForShopProvider(shopId)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.restaurant_menu_rounded,
            title: 'No menu items yet',
            message: 'This shop hasn\'t added anything to their menu.',
          );
        }
        final grouped = groupByCategory(items);
        // FIX (shop detail scroll-lock bug): this used to be a bare
        // ListView, which meant it ran its own independent scroll
        // position instead of participating in shop_detail_screen.dart's
        // NestedScrollView. SliverOverlapInjector consumes the overlap
        // recorded by the tab bar's SliverOverlapAbsorber in the header,
        // so the first category label starts right below the pinned tab
        // bar instead of underneath it.
        return CustomScrollView(
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.stackMd,
                AppSpacing.gutter,
                120, // clears the floating cart bar
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  for (final entry in grouped.entries) ...[
                    Text(entry.key, style: AppTextStyles.headlineMd),
                    const SizedBox(height: AppSpacing.stackMd),
                    for (final item in entry.value) ...[
                      _MenuItemCard(shopId: shopId, item: item),
                      const SizedBox(height: AppSpacing.stackMd),
                    ],
                    const SizedBox(height: AppSpacing.stackSm),
                  ],
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MenuItemCard extends ConsumerWidget {
  const _MenuItemCard({required this.shopId, required this.item});

  final String shopId;
  final MenuItemModel item;

  Future<void> _handleQuickAdd(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(cartProvider.notifier);

    if (notifier.belongsToDifferentShop(shopId)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a new order?'),
          content: const Text(
            'Your cart has items from another shop. Adding this item will '
            'clear your current cart.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start New Order'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      notifier.clear();
    }

    notifier.addItem(shopId, CartItemModel.fromMenuItem(item));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final quantity = cartState.shopId == shopId
        ? ref.read(cartProvider.notifier).quantityOf(item.id)
        : 0;
    final isAvailable = item.isAvailable;
    // SCROLL-PERFORMANCE FIX: this card used to be wrapped top-to-bottom in
    // `Opacity(opacity: isAvailable ? 1.0 : 0.5, child: <whole card>)` —
    // same anti-pattern as shop_card.dart: an Opacity around a subtree that
    // includes a BoxShadow and a CachedNetworkImage forces an offscreen
    // composite of the entire card, every frame, for every unavailable
    // item. Fixed the same way: dim only the image (small subtree) via
    // Opacity, dim text/icons via color alpha (free to paint, no
    // compositing), and isolate each card's paint with RepaintBoundary.
    final dimAlpha = isAvailable ? 1.0 : 0.5;

    return RepaintBoundary(
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          onTap: () => showItemDetailSheet(context, shopId: shopId, item: item),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.stackMd),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              boxShadow: [
                BoxShadow(
                    color: AppColors.onSurface.withValues(alpha: 0.05),
                    blurRadius: 8),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: item.imageUrl.isEmpty
                        ? Container(color: AppColors.surfaceContainerHigh)
                        : Opacity(
                            // Small, isolated subtree — just the image.
                            opacity: dimAlpha,
                            child: CachedNetworkImage(
                              imageUrl: item.imageUrl,
                              fit: BoxFit.cover,
                              // Decode near the actual 80x80 display size
                              // (2x for device pixel ratio) instead of the
                              // full 500x500 source image.
                              memCacheWidth: 160,
                              memCacheHeight: 160,
                              placeholder: (context, url) => Container(
                                  color: AppColors.surfaceContainerHigh),
                              errorWidget: (context, url, error) => Container(
                                  color: AppColors.surfaceContainerHigh),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.gutter),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: AppTextStyles.headlineMd.copyWith(
                            color: (AppTextStyles.headlineMd.color ??
                                    AppColors.onSurface)
                                .withValues(alpha: dimAlpha),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(item.description,
                          style: AppTextStyles.bodySm.copyWith(
                            color: (AppTextStyles.bodySm.color ??
                                    AppColors.onSurface)
                                .withValues(alpha: dimAlpha),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: AppSpacing.stackSm),
                      Text(
                        '\$${item.price.toStringAsFixed(2)}',
                        style: AppTextStyles.headlineMd.copyWith(
                            color:
                                AppColors.primary.withValues(alpha: dimAlpha)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.stackSm),
                if (!isAvailable)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Sold Out',
                        style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  )
                else if (quantity == 0)
                  _AddButton(onTap: () => _handleQuickAdd(context, ref))
                else
                  QuantityStepper(
                    quantity: quantity,
                    compact: true,
                    minQuantity: 0,
                    onDecrement: () =>
                        ref.read(cartProvider.notifier).decrementItem(item.id),
                    onIncrement: () =>
                        ref.read(cartProvider.notifier).incrementItem(item.id),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryContainer,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.add, size: 20, color: AppColors.onPrimaryContainer),
        ),
      ),
    );
  }
}
