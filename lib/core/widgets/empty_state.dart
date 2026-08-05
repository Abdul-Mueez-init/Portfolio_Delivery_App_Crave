import 'package:flutter/material.dart';
import 'custom_button.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// A designed empty state — per design.md §4 and PLAN.md Phase 11, every
/// list screen needs a real empty state, not a blank white screen.
/// Covers: empty cart, no orders yet, no bookings yet, no shops.
///
/// Usage:
/// EmptyState(
///   icon: Icons.shopping_bag_outlined,
///   title: 'Your cart is empty',
///   message: 'Add something tasty to get started.',
///   actionLabel: 'Browse Shops',
///   onAction: () => context.go('/home'),
/// )
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.marginMain),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.stackMd + 4),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 32),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineMd,
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.stackLg),
              CustomButton(
                label: actionLabel!,
                onPressed: onAction,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
