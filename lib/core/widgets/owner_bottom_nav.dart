import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Owner shell's bottom nav — architecture.md §3: Dashboard / Orders /
/// Bookings / Menu (4 tabs). NOTE: two of the Stitch exports
/// (dashboard_home_updated, order_queue_updated) show only 3 tabs with
/// no Calendar entry, but booking_calendar_updated and
/// menu_management_updated both show the full 4-tab bar — going with
/// architecture.md + the majority of the real screens, same call made
/// for the customer nav's 3-vs-4-tab conflict in Phase 4.
///
/// References AppRoutes.ownerOrderQueue / ownerBookingCalendar /
/// ownerMenuManagement, which land in the next batch (router update) —
/// this file will not compile on its own until that batch is in.
class OwnerBottomNav extends StatelessWidget {
  const OwnerBottomNav({super.key, required this.currentIndex});

  /// 0 = Dashboard, 1 = Orders, 2 = Calendar, 3 = Menu
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final items = <_NavItem>[
      _NavItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        route: AppRoutes.ownerDashboard,
      ),
      _NavItem(
        icon: Icons.receipt_long_rounded,
        label: 'Orders',
        route: AppRoutes.ownerOrderQueue,
      ),
      _NavItem(
        icon: Icons.calendar_month_rounded,
        label: 'Calendar',
        route: AppRoutes.ownerBookingCalendar,
      ),
      _NavItem(
        icon: Icons.restaurant_menu_rounded,
        label: 'Menu',
        route: AppRoutes.ownerMenuManagement,
      ),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.outlineVariant, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isActive = index == currentIndex;
            return _NavButton(
              icon: item.icon,
              label: item.label,
              isActive: isActive,
              onTap: () {
                if (!isActive) context.go(item.route);
              },
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
  final IconData icon;
  final String label;
  final String route;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.onPrimaryContainer : AppColors.secondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style:
                  AppTextStyles.labelCaps.copyWith(color: color, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
