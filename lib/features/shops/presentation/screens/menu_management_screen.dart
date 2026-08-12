import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/owner_bottom_nav.dart';
import '../../application/menu_provider.dart';
import '../../application/owner_shop_provider.dart';
import '../../data/models/menu_item_model.dart';
import 'menu_item_form_screen.dart';

/// design.md screen 19. Reuses menuForShopProvider — the same provider
/// ShopDetailScreen's Menu tab watches — rather than a separate
/// owner-only provider: fetchMenuForShop already returns unavailable
/// items too (see menu_repository.dart's doc comment), so there's no
/// data-shape reason to duplicate it, and invalidating this provider
/// after an owner edit keeps the customer-facing menu tab correct too.
class MenuManagementScreen extends ConsumerWidget {
  const MenuManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(myShopProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Manage Menu',
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
          return _MenuBody(shopId: shop.id);
        },
      ),
      floatingActionButton: shopAsync.maybeWhen(
        data: (shop) => shop == null
            ? null
            : FloatingActionButton(
                backgroundColor: AppColors.primaryContainer,
                onPressed: () async {
                  await context.push(AppRoutes.ownerMenuItemForm,
                      extra: MenuItemFormArgs(shopId: shop.id));
                  ref.invalidate(menuForShopProvider(shop.id));
                },
                child:
                    const Icon(Icons.add, color: AppColors.onPrimaryContainer),
              ),
        orElse: () => null,
      ),
      bottomNavigationBar: const OwnerBottomNav(currentIndex: 3),
    );
  }
}

class _MenuBody extends ConsumerStatefulWidget {
  const _MenuBody({required this.shopId});
  final String shopId;

  @override
  ConsumerState<_MenuBody> createState() => _MenuBodyState();
}

class _MenuBodyState extends ConsumerState<_MenuBody> {
  String _selectedCategory = 'All Items';

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(menuForShopProvider(widget.shopId));

    return menuAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, s) => ErrorView(
        message: "We couldn't load your menu.",
        onRetry: () => ref.invalidate(menuForShopProvider(widget.shopId)),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.restaurant_menu_outlined,
            title: 'No menu items yet',
            message: 'Tap + to add your first item.',
          );
        }

        final categories = [
          'All Items',
          ...{for (final i in items) i.category}
        ];
        final visible = _selectedCategory == 'All Items'
            ? items
            : items.where((i) => i.category == _selectedCategory).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.marginMain,
                    vertical: AppSpacing.stackSm),
                itemCount: categories.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: AppSpacing.stackSm),
                itemBuilder: (context, i) {
                  final cat = categories[i];
                  final isSelected = cat == _selectedCategory;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  );
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.marginMain, 0, AppSpacing.marginMain, 96),
                itemCount: visible.length,
                itemBuilder: (context, i) =>
                    _MenuItemRow(item: visible[i], shopId: widget.shopId),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MenuItemRow extends ConsumerStatefulWidget {
  const _MenuItemRow({required this.item, required this.shopId});
  final MenuItemModel item;
  final String shopId;

  @override
  ConsumerState<_MenuItemRow> createState() => _MenuItemRowState();
}

class _MenuItemRowState extends ConsumerState<_MenuItemRow> {
  bool _isBusy = false;

  Future<void> _toggleAvailability(bool value) async {
    setState(() => _isBusy = true);
    try {
      await ref
          .read(menuRepositoryProvider)
          .setAvailability(itemId: widget.item.id, isAvailable: value);
      ref.invalidate(menuForShopProvider(widget.shopId));
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

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove item?'),
        content: Text(
            '"${widget.item.name}" will be hidden from your menu. Past orders referencing it are unaffected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBusy = true);
    try {
      await ref.read(menuRepositoryProvider).deleteMenuItem(widget.item.id);
      ref.invalidate(menuForShopProvider(widget.shopId));
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
    final item = widget.item;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.stackSm),
      padding: const EdgeInsets.all(AppSpacing.stackSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: item.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    width: 56,
                    height: 56,
                    // Decode near the 56x56 display size (2x for device
                    // pixel ratio) instead of full source res.
                    memCacheWidth: 112,
                    memCacheHeight: 112,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                        width: 56,
                        height: 56,
                        color: AppColors.surfaceContainer),
                    errorWidget: (context, url, error) => Container(
                        width: 56,
                        height: 56,
                        color: AppColors.surfaceContainer,
                        child: const Icon(Icons.fastfood_outlined,
                            color: AppColors.secondary)),
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: AppColors.surfaceContainer,
                    child: const Icon(Icons.fastfood_outlined,
                        color: AppColors.secondary),
                  ),
          ),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: AppTextStyles.bodyLg.copyWith(
                      fontWeight: FontWeight.w600,
                      color: item.isAvailable
                          ? AppColors.onSurface
                          : AppColors.onSurfaceVariant,
                    )),
                Text('\$${item.price.toStringAsFixed(2)}',
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.primary)),
              ],
            ),
          ),
          Switch(
            value: item.isAvailable,
            onChanged: _isBusy ? null : _toggleAvailability,
            activeColor: AppColors.primary,
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: _isBusy
                ? null
                : () async {
                    await context.push(AppRoutes.ownerMenuItemForm,
                        extra: MenuItemFormArgs(
                            shopId: widget.shopId, item: item));
                    ref.invalidate(menuForShopProvider(widget.shopId));
                  },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 20, color: AppColors.error),
            onPressed: _isBusy ? null : _delete,
          ),
        ],
      ),
    );
  }
}
