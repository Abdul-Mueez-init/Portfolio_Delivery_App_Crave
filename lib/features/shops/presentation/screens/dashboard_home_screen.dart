import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/owner_bottom_nav.dart';
import '../../../bookings/application/owner_bookings_provider.dart';
import '../../../orders/application/owner_orders_provider.dart';
import '../../application/owner_shop_provider.dart';
import '../../data/models/shop_model.dart';
import '../../../auth/application/auth_provider.dart';

/// design.md screen 16 — the owner's landing screen after onboarding.
/// Greeting + today's counts + quick links into the other owner
/// screens, all keyed off myShopProvider so the whole owner shell
/// shares one "what shop am I" source of truth.
class DashboardHomeScreen extends ConsumerWidget {
  const DashboardHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(myShopProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: shopAsync.when(
          loading: () => const LoadingIndicator(),
          error: (error, stack) => ErrorView(
            message: "We couldn't load your shop. Please try again.",
            onRetry: () => ref.invalidate(myShopProvider),
          ),
          data: (shop) {
            if (shop == null) {
              // Shouldn't happen — post_auth_navigation.dart sends a
              // shop-less owner to Onboarding, not here.
              return const ErrorView(
                title: 'No shop found',
                message: 'Complete Shop Onboarding first.',
              );
            }
            return _DashboardBody(shop: shop);
          },
        ),
      ),
      bottomNavigationBar: const OwnerBottomNav(currentIndex: 0),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.shop});
  final ShopModel shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(shopOrdersProvider(shop.id));
    final todayBookingsAsync = ref.watch(
      shopBookingsProvider(
          ShopBookingsQuery(shopId: shop.id, date: DateTime.now())),
    );

    final now = DateTime.now();
    final todayOrderCount = ordersAsync.maybeWhen(
      data: (orders) => orders.where((o) {
        final c = o.createdAt.toLocal();
        return c.year == now.year && c.month == now.month && c.day == now.day;
      }).length,
      orElse: () => 0,
    );
    final todayBookingCount = todayBookingsAsync.maybeWhen(
      data: (bookings) => bookings.length,
      orElse: () => null,
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(shopBookingsProvider);
        ref.invalidate(myShopProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.marginMain),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Marketplace Manager',
                    style: AppTextStyles.headlineMd
                        .copyWith(color: AppColors.primary)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: AppColors.onSurface,
                    ),
                    onPressed: () => context.push(AppRoutes.ownerShopSettings),
                  ),
                  IconButton(
                    // Matches profile_screen.dart's _LogOutButton token
                    // (Phase H #17) — this owner-side icon was missed in
                    // that batch and was still on the old onSurface token.
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.primaryContainer,
                    ),
                    tooltip: 'Log out',
                    onPressed: () async {
                      await ref.read(authRepositoryProvider).signOut();

                      if (context.mounted) {
                        context.go(AppRoutes.login);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.stackSm),
          Text(_greeting(now),
              style: AppTextStyles.bodyLg
                  .copyWith(color: AppColors.onSurfaceVariant)),
          Text(shop.name,
              style: AppTextStyles.headlineLgMobile
                  .copyWith(color: AppColors.primary)),
          const SizedBox(height: AppSpacing.stackLg),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: "Today's Orders",
                  value: todayOrderCount,
                  accentColor: AppColors.primaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.stackSm),
              Expanded(
                child: _StatCard(
                  label: "Today's Bookings",
                  value: todayBookingCount,
                  accentColor: AppColors.tertiaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.stackLg),
          Text('QUICK ACTIONS', style: AppTextStyles.labelCaps),
          const SizedBox(height: AppSpacing.stackSm),
          _QuickActionTile(
            icon: Icons.receipt_long_rounded,
            iconBackground: AppColors.surfaceContainer,
            title: 'View Order Queue',
            onTap: () => context.go(AppRoutes.ownerOrderQueue),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          _QuickActionTile(
            icon: Icons.calendar_month_rounded,
            iconBackground: AppColors.tertiaryContainer.withOpacity(0.25),
            title: 'View Booking Calendar',
            onTap: () => context.go(AppRoutes.ownerBookingCalendar),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          _QuickActionTile(
            icon: Icons.restaurant_menu_rounded,
            iconBackground: AppColors.surfaceContainerHigh,
            title: 'Manage Menu',
            onTap: () => context.go(AppRoutes.ownerMenuManagement),
          ),
          const SizedBox(height: AppSpacing.stackSm),
          _QuickActionTile(
            icon: Icons.event_available_rounded,
            iconBackground: AppColors.tertiaryContainer.withOpacity(0.25),
            title: 'Manage Time Slots',
            onTap: () => context.push(AppRoutes.ownerSlotManagement),
          ),
        ],
      ),
    );
  }

  String _greeting(DateTime now) {
    if (now.hour < 12) return 'Good morning,';
    if (now.hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.value, required this.accentColor});
  final String label;
  final int? value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
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
          Text(label, style: AppTextStyles.bodySm),
          const SizedBox(height: AppSpacing.stackSm),
          value == null
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                )
              : Text('$value',
                  style: AppTextStyles.headlineLg
                      .copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBackground;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.stackMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration:
                  BoxDecoration(color: iconBackground, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: AppSpacing.stackMd),
            Expanded(
                child: Text(title,
                    style: AppTextStyles.bodyLg
                        .copyWith(fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right, color: AppColors.secondary),
          ],
        ),
      ),
    );
  }
}
