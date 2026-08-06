import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../router/app_router.dart';

/// Shared across Home / Activity / Profile — per architecture.md §3 the
/// customer shell has exactly 3 tabs. See the flagged deviation note in
/// this response: the Stitch export shows 4 tabs (Home/Orders/Bookings/
/// Profile), architecture.md says 3 (Home/Activity/Profile). Going with
/// architecture.md.
///
/// NOT a go_router StatefulShellRoute yet — Activity/Profile don't exist
/// until Phase 7, so each screen just drops this into its own Scaffold's
/// bottomNavigationBar. Tab switches rebuild the destination fresh
/// rather than preserving scroll/state — acceptable MVP trade-off, but
/// worth upgrading to StatefulShellRoute in Phase 9 if it feels janky.
class CustomerBottomNav extends StatelessWidget {
  const CustomerBottomNav({super.key, required this.currentIndex});

  /// 0 = Home, 1 = Activity, 2 = Profile
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final items = <_NavItem>[
      _NavItem(
          icon: Icons.home_rounded,
          label: 'Home',
          route: AppRoutes.customerHome),
      const _NavItem(
          icon: Icons.receipt_long_rounded, label: 'Activity', route: null),
      const _NavItem(icon: Icons.person_rounded, label: 'Profile', route: null),
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
              onTap: item.route == null
                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('${item.label} — coming in a later phase'),
                          duration: const Duration(seconds: 1),
                        ),
                      )
                  : () {
                      if (!isActive) context.go(item.route!);
                    },
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(
      {required this.icon, required this.label, required this.route});
  final IconData icon;
  final String label;
  final String? route;
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.labelCaps.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
