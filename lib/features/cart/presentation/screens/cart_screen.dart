import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../application/cart_provider.dart';
import '../widgets/cart_item_tile.dart';
import '../../../../core/router/app_router.dart';

/// Matches cart_updated/code.html — deliberately no bottom nav bar here
/// (the real design suppresses it: cart is a transactional/linear
/// screen, not a shell tab), so this is pushed via context.push, not
/// routed through the customer bottom-nav shell.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your Cart'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: cart.isEmpty
          ? const EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty.',
              message: "Let's find something delicious!",
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.marginMain,
                AppSpacing.stackMd,
                AppSpacing.marginMain,
                AppSpacing.stackLg,
              ),
              children: [
                for (final item in cart.items) ...[
                  CartItemTile(
                    item: item,
                    onIncrement: () => notifier.incrementItem(item.menuItemId),
                    onDecrement: () => notifier.decrementItem(item.menuItemId),
                    onRemove: () => notifier.removeItem(item.menuItemId),
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                ],
                const SizedBox(height: AppSpacing.stackSm),
                _OrderSummaryCard(
                  subtotal: cart.subtotal,
                  tax: cart.taxAmount,
                  total: cart.total,
                  onContinue: () => context.push(AppRoutes.fulfillment),
                ),
              ],
            ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.onContinue,
  });

  final double subtotal;
  final double tax;
  final double total;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.05),
              blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          _SummaryRow(label: 'Subtotal', value: subtotal),
          const SizedBox(height: AppSpacing.stackMd),
          _SummaryRow(label: 'Tax & Fees', value: tax),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.stackMd),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: AppTextStyles.headlineMd),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style:
                    AppTextStyles.headlineMd.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.stackMd + 8),
          CustomButton(
            label: 'Continue to Checkout',
            icon: Icons.arrow_forward,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTextStyles.bodyLg.copyWith(color: AppColors.secondary)),
        Text('\$${value.toStringAsFixed(2)}', style: AppTextStyles.bodyLg),
      ],
    );
  }
}
