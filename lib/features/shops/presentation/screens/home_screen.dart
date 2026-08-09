import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/widgets/customer_bottom_nav.dart';
import '../../../../core/router/app_router.dart';
import '../../../cart/presentation/widgets/cart_fab.dart';
import '../../application/shops_provider.dart';
import '../widgets/shop_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredShops = ref.watch(filteredShopsProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      // Wrapped in a Stack so CartFab (Phase H #15 — it renders its own
      // Positioned internally, same pattern as shop_detail_screen.dart)
      // can float over the shop list whenever the cart isn't empty.
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _TopBar(),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async => ref.invalidate(shopsListProvider),
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.marginMain,
                              AppSpacing.stackMd,
                              AppSpacing.marginMain,
                              0,
                            ),
                            child: Column(
                              children: [
                                _SearchBar(
                                  onChanged: (value) => ref
                                      .read(shopSearchQueryProvider.notifier)
                                      .state = value,
                                ),
                                const SizedBox(height: AppSpacing.stackMd),
                                _CategoryChips(selected: selectedCategory),
                              ],
                            ),
                          ),
                        ),
                        filteredShops.when(
                          loading: () => const SliverFillRemaining(
                            hasScrollBody: false,
                            child: SkeletonLoader.list(),
                          ),
                          error: (error, stack) => SliverFillRemaining(
                            hasScrollBody: false,
                            child: ErrorView(
                              message:
                                  "We couldn't load shops right now. Please try again.",
                              onRetry: () => ref.invalidate(shopsListProvider),
                            ),
                          ),
                          data: (shops) {
                            if (shops.isEmpty) {
                              return SliverFillRemaining(
                                hasScrollBody: false,
                                child: EmptyState(
                                  icon: Icons.storefront_outlined,
                                  title: 'No shops found',
                                  message: selectedCategory == 'All'
                                      ? 'Check back soon — new shops join Crave regularly.'
                                      : 'No shops match "$selectedCategory" right now. Try a different category.',
                                  actionLabel: selectedCategory == 'All'
                                      ? null
                                      : 'Clear filter',
                                  onAction: selectedCategory == 'All'
                                      ? null
                                      : () => ref
                                          .read(
                                              selectedCategoryProvider.notifier)
                                          .state = 'All',
                                ),
                              );
                            }
                            return SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.marginMain,
                                AppSpacing.stackMd,
                                AppSpacing.marginMain,
                                AppSpacing.stackLg,
                              ),
                              sliver: SliverList.separated(
                                itemCount: shops.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: AppSpacing.gutter),
                                itemBuilder: (context, index) {
                                  final shop = shops[index];
                                  return ShopCard(
                                    shop: shop,
                                    onTap: () => context.push(
                                        '${AppRoutes.shopDetail}/${shop.id}'),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          CartFab(
            onTap: () => context.push(AppRoutes.cart),
          ),
        ],
      ),
      bottomNavigationBar: const CustomerBottomNav(currentIndex: 0),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.marginMain,
        vertical: AppSpacing.stackSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(
              width: 40), // balances the avatar so "Crave" stays centered
          Text('Crave',
              style: AppTextStyles.headlineLgMobile
                  .copyWith(color: AppColors.primary)),
          InkWell(
            onTap: () => context.go(AppRoutes.profile),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: AppTextStyles.bodyLg,
      decoration: InputDecoration(
        hintText: 'Search restaurants, cafes...',
        hintStyle: AppTextStyles.bodyLg.copyWith(color: AppColors.secondary),
        prefixIcon: const Icon(Icons.search, color: AppColors.secondary),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(
              color: AppColors.outlineVariant.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(
              color: AppColors.outlineVariant.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide:
              const BorderSide(color: AppColors.primaryContainer, width: 2),
        ),
      ),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.selected});
  final String selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shopCategoryChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.gutter),
        itemBuilder: (context, index) {
          final label = shopCategoryChips[index];
          final isActive = label == selected;
          return ChoiceChip(
            label: Text(label),
            labelStyle: AppTextStyles.bodySm.copyWith(
              color: isActive
                  ? AppColors.onPrimaryContainer
                  : AppColors.onSurfaceVariant,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
            selected: isActive,
            onSelected: (_) =>
                ref.read(selectedCategoryProvider.notifier).state = label,
            backgroundColor: AppColors.background,
            selectedColor: AppColors.primaryContainer,
            side: BorderSide(
                color:
                    isActive ? Colors.transparent : AppColors.outlineVariant),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull)),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}
