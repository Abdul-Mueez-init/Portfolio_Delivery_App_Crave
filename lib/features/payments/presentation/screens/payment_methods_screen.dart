import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../application/payment_methods_provider.dart';
import '../../data/models/payment_method_model.dart';

/// Backs Profile's "Payment Methods" row — previously a "coming in a
/// later phase" snackbar. Lists cards saved from Checkout's consent
/// checkbox (see checkout_screen.dart's _FakeCardSection). Read-only
/// list here (no "add card" entry point on this screen) — a saved card
/// is only ever created at the moment of a real checkout, same as how
/// a real payment processor's "save this card" flow works, so there's
/// never a saved card with no order behind it.
class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methodsAsync = ref.watch(paymentMethodsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment Methods'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: methodsAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, stack) => ErrorView(
          message: "We couldn't load your payment methods. Please try again.",
          onRetry: () => ref.invalidate(paymentMethodsProvider),
        ),
        data: (methods) {
          if (methods.isEmpty) {
            return const EmptyState(
              icon: Icons.credit_card_outlined,
              title: 'No saved cards yet',
              message:
                  'Check "Allow Crave to save your card details" at checkout '
                  'to save a card here for next time.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.marginMain),
            children: [
              for (final method in methods) ...[
                _PaymentMethodCard(
                  method: method,
                  onSetDefault: method.isDefault
                      ? null
                      : () async {
                          await ref
                              .read(paymentMethodsRepositoryProvider)
                              .setDefault(method.id);
                          ref.invalidate(paymentMethodsProvider);
                        },
                  onDelete: () async {
                    await ref
                        .read(paymentMethodsRepositoryProvider)
                        .deletePaymentMethod(method.id);
                    ref.invalidate(paymentMethodsProvider);
                  },
                ),
                const SizedBox(height: AppSpacing.stackMd),
              ],
              const SizedBox(height: AppSpacing.stackSm),
              Row(
                children: [
                  const Icon(Icons.lock_outline,
                      size: 14, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Test mode — these are simulated cards. No real card '
                      'number or CVV is ever stored.',
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.method,
    required this.onSetDefault,
    required this.onDelete,
  });

  final PaymentMethodModel method;
  final VoidCallback? onSetDefault;
  final VoidCallback onDelete;

  IconData get _brandIcon {
    switch (method.brand) {
      case CardBrand.visa:
      case CardBrand.mastercard:
      case CardBrand.amex:
        return Icons.credit_card_rounded;
      case CardBrand.unknown:
        return Icons.credit_card_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: method.isDefault
              ? AppColors.primaryContainer
              : AppColors.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.03),
              blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(_brandIcon, color: AppColors.secondary),
          ),
          const SizedBox(width: AppSpacing.stackMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${method.brand.displayName} ${method.maskedLabel}',
                        style: AppTextStyles.headlineMd),
                    if (method.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              AppColors.primaryContainer.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          'DEFAULT',
                          style: AppTextStyles.labelCaps
                              .copyWith(color: AppColors.primaryContainer),
                        ),
                      ),
                    ],
                  ],
                ),
                if (method.expiryMonth != null && method.expiryYear != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Expires ${method.expiryMonth.toString().padLeft(2, '0')}/'
                    '${(method.expiryYear! % 100).toString().padLeft(2, '0')}',
                    style: AppTextStyles.bodySm,
                  ),
                ],
                const SizedBox(height: AppSpacing.stackSm),
                Row(
                  children: [
                    if (onSetDefault != null)
                      TextButton(
                        onPressed: onSetDefault,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Set as default'),
                      ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 20, color: AppColors.error),
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
