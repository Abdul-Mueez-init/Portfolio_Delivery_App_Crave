import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../cart/application/cart_provider.dart';
import '../../../shops/application/shop_detail_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../application/fulfillment_provider.dart';
import '../../data/models/fulfillment_type.dart';

/// Matches fulfillment_selection_updated/code.html: segmented Pickup/
/// Delivery control, address field + "Use current location" (delivery
/// only), a static map preview ("Visual flair" per the real markup —
/// not a live GoogleMap; see fulfillment_provider.dart note), Continue.
class FulfillmentSelectionScreen extends ConsumerWidget {
  const FulfillmentSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final shopId = cart.shopId;

    // Cart should never be empty here (Cart screen gates navigation),
    // but this is the honest fallback if someone lands here directly.
    if (shopId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fulfillment')),
        body: const ErrorView(message: 'Your cart is empty.'),
      );
    }

    final shopAsync = ref.watch(shopDetailProvider(shopId));
    final fulfillment = ref.watch(fulfillmentProvider);
    final notifier = ref.read(fulfillmentProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Fulfillment'),
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
              _SegmentedToggle(
                selected: fulfillment.type,
                onChanged: notifier.selectType,
              ),
              const SizedBox(height: AppSpacing.stackMd),
              if (fulfillment.type == FulfillmentType.delivery) ...[
                Text('Delivery Address', style: AppTextStyles.labelCaps),
                const SizedBox(height: AppSpacing.stackSm),
                TextField(
                  onChanged: notifier.setAddress,
                  style: AppTextStyles.bodyLg,
                  decoration: const InputDecoration(
                    hintText: 'Enter full address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.stackSm),
                TextButton.icon(
                  onPressed: () => notifier.useSimulatedCurrentLocation(
                    shopLat: shop.lat ?? 0,
                    shopLng: shop.lng ?? 0,
                  ),
                  icon: const Icon(Icons.my_location, size: 20),
                  label: const Text('Use current location'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                ),
                const SizedBox(height: AppSpacing.stackMd),
                const _MapPreview(),
              ],
              const Spacer(),
              CustomButton(
                label: 'Continue',
                onPressed: fulfillment.canContinue
                    ? () => context.push(AppRoutes.checkout)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({required this.selected, required this.onChanged});

  final FulfillmentType selected;
  final ValueChanged<FulfillmentType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'Pickup',
              isSelected: selected == FulfillmentType.pickup,
              onTap: () => onChanged(FulfillmentType.pickup),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: 'Delivery',
              isSelected: selected == FulfillmentType.delivery,
              onTap: () => onChanged(FulfillmentType.delivery),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.stackSm + 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineMd.copyWith(
              color: isSelected
                  ? AppColors.onPrimaryContainer
                  : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Static illustrative preview — the real Stitch markup comments this
/// exact element as "Visual flair", not a live map. See
/// fulfillment_provider.dart for the note on swapping to a real
/// GoogleMap later.
class _MapPreview extends StatelessWidget {
  const _MapPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border:
            Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child:
              const Icon(Icons.location_on, color: AppColors.primary, size: 32),
        ),
      ),
    );
  }
}
