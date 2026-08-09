import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/router/app_router.dart';
import '../../../cart/application/cart_provider.dart';
import '../../../shops/application/shop_detail_provider.dart';
import '../../application/checkout_provider.dart';
import '../../application/fulfillment_provider.dart';
import '../../data/models/fulfillment_type.dart';

/// FLAGGED ASSUMPTION: no delivery-fee config/table exists yet — flat
/// $2.99 for delivery, $0 for pickup. Same pattern as cart_provider.dart's
/// flagged taxRate assumption. Revisit once a real fee rule is defined.
const double _flatDeliveryFee = 2.99;

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  // Phase H #14: cosmetic-only "Add Card" fields. Purely a UI beat so
  // the flow *feels* like a real payment step happened — no validation
  // beyond basic formatting, no gateway call, nothing here ever reaches
  // OrdersRepository.createOrder() (see its doc comment: payment stays
  // simulated permanently, this is not a placeholder for real Stripe).
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final shopId = cart.shopId;

    if (shopId == null || cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const ErrorView(message: 'Your cart is empty.'),
      );
    }

    final shopAsync = ref.watch(shopDetailProvider(shopId));
    final fulfillment = ref.watch(fulfillmentProvider);
    final checkoutState = ref.watch(checkoutProvider);
    final deliveryFee =
        fulfillment.type == FulfillmentType.delivery ? _flatDeliveryFee : 0.0;
    final total = cart.total + deliveryFee;

    Future<void> handlePlaceOrder() async {
      final notifier = ref.read(checkoutProvider.notifier);
      final order = await notifier.placeOrder(
        shopId: shopId,
        fulfillmentType: fulfillment.type,
        cartItems: cart.items,
        subtotal: cart.subtotal,
        deliveryFee: deliveryFee,
        total: total,
        deliveryAddress: fulfillment.type == FulfillmentType.delivery
            ? fulfillment.address
            : null,
        deliveryLat: fulfillment.deliveryLat,
        deliveryLng: fulfillment.deliveryLng,
      );

      if (!context.mounted) return;

      if (order == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ref.read(checkoutProvider).error ??
                  "Couldn't place your order.")),
        );
        return;
      }

      // Clear Cart + reset fulfillment now that the order is real,
      // then Navigate to Tracking — PLAN.md Phase 5 order.
      ref.read(cartProvider.notifier).clear();
      ref.read(fulfillmentProvider.notifier).reset();

      context.go('${AppRoutes.orderTracking}/${order.id}');
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: shopAsync.when(
        loading: () => const SkeletonLoader.detail(),
        error: (error, stack) => ErrorView(
          message: "We couldn't load this shop right now. Please try again.",
          onRetry: () => ref.invalidate(shopDetailProvider(shopId)),
        ),
        data: (shop) => Padding(
          padding: const EdgeInsets.all(AppSpacing.marginMain),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(shop.name, style: AppTextStyles.headlineMd),
              const SizedBox(height: AppSpacing.stackSm),
              Text(
                fulfillment.type == FulfillmentType.delivery
                    ? 'Delivering to ${fulfillment.address}'
                    : 'Pickup at ${shop.address}',
                style: AppTextStyles.bodySm,
              ),
              const SizedBox(height: AppSpacing.stackLg),
              Text('Order Summary', style: AppTextStyles.labelCaps),
              const SizedBox(height: AppSpacing.stackSm),
              Expanded(
                child: ListView(
                  children: [
                    for (final item in cart.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.stackSm),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text('${item.quantity}x ${item.name}',
                                  style: AppTextStyles.bodyLg),
                            ),
                            Text('\$${item.lineTotal.toStringAsFixed(2)}',
                                style: AppTextStyles.bodyLg),
                          ],
                        ),
                      ),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: AppSpacing.stackSm),
                      child: Divider(height: 1),
                    ),
                    _SummaryRow(label: 'Subtotal', value: cart.subtotal),
                    const SizedBox(height: AppSpacing.stackSm),
                    _SummaryRow(label: 'Tax & Fees', value: cart.taxAmount),
                    const SizedBox(height: AppSpacing.stackSm),
                    _SummaryRow(label: 'Delivery Fee', value: deliveryFee),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: AppSpacing.stackMd),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: AppTextStyles.headlineMd),
                        Text('\$${total.toStringAsFixed(2)}',
                            style: AppTextStyles.headlineMd
                                .copyWith(color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.stackLg),
                    _FakeCardSection(
                      cardNumberController: _cardNumberController,
                      expiryController: _expiryController,
                      cvvController: _cvvController,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.stackMd),
              // "Place Order" simulates payment success — payment is
              // permanently simulated (see OrdersRepository's class doc
              // comment). The card fields above are a cosmetic UI beat
              // only; they're never read by handlePlaceOrder below.
              CustomButton(
                label: 'Pay \$${total.toStringAsFixed(2)} & Place Order',
                isLoading: checkoutState.isPlacingOrder,
                onPressed: handlePlaceOrder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FakeCardSection extends StatelessWidget {
  const _FakeCardSection({
    required this.cardNumberController,
    required this.expiryController,
    required this.cvvController,
  });

  final TextEditingController cardNumberController;
  final TextEditingController expiryController;
  final TextEditingController cvvController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payment', style: AppTextStyles.labelCaps),
        const SizedBox(height: AppSpacing.stackSm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.stackMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            children: [
              CustomTextField(
                label: 'Card Number',
                hintText: '4242 4242 4242 4242',
                controller: cardNumberController,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.credit_card_outlined,
                onChanged: (_) {}, // cosmetic only, never read on submit
                // A light card-number formatter keeps this feeling real
                // without any actual validation (Phase H #14).
              ),
              const SizedBox(height: AppSpacing.stackMd),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      label: 'Expiry',
                      hintText: 'MM/YY',
                      controller: expiryController,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.stackMd),
                  Expanded(
                    child: CustomTextField(
                      label: 'CVV',
                      hintText: '123',
                      controller: cvvController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.stackSm),
        Row(
          children: [
            const Icon(Icons.lock_outline,
                size: 14, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              'Test mode — no real card is charged.',
              style: AppTextStyles.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ],
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
