import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/cart_provider.dart';

/// Floating cart summary bar, matches menu_updated's fixed bottom bar:
/// cart icon, "N items", total, chevron. Tap navigates to /cart
/// (wired in a later batch — currently just visible when cart has items).
class CartFab extends ConsumerWidget {
  const CartFab({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    if (cart.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: AppSpacing.gutter,
      right: AppSpacing.gutter,
      bottom: AppSpacing.stackMd,
      child: Material(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        elevation: 4,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.stackMd),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart,
                    color: AppColors.onPrimaryContainer),
                const SizedBox(width: AppSpacing.stackSm),
                Text(
                  '${cart.totalQuantity} item${cart.totalQuantity == 1 ? '' : 's'}',
                  style: AppTextStyles.headlineMd
                      .copyWith(color: AppColors.onPrimaryContainer),
                ),
                const Spacer(),
                Text(
                  '\$${cart.subtotal.toStringAsFixed(2)}',
                  style: AppTextStyles.headlineMd
                      .copyWith(color: AppColors.onPrimaryContainer),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    color: AppColors.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
