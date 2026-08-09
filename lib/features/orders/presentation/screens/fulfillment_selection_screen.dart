import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../auth/application/auth_provider.dart';
import '../../../auth/data/models/user_profile_model.dart';
import '../../../cart/application/cart_provider.dart';
import '../../../shops/application/shop_detail_provider.dart';
import '../../../shops/data/models/shop_model.dart';
import '../../../../core/router/app_router.dart';
import '../../application/fulfillment_provider.dart';
import '../../data/models/fulfillment_type.dart';

/// Matches fulfillment_selection_updated/code.html: segmented Pickup/
/// Delivery control, a read-only "Your Details" card shown on both
/// branches (mirrors the info-row style from shop_detail_screen.dart's
/// _ShopInfoCard — see SESSION_HANDOFF_phaseAH_fixes.md Phase C), then
/// either a shop summary card (Pickup) or address input + "Use current
/// location" + static map preview (Delivery), then Continue.
///
/// Body is a scrollable ListView with Continue as the last item —
/// matches cart_screen.dart's pattern rather than a Spacer-pinned
/// button, since Pickup/Delivery content now varies in height.
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
    final profileAsync = ref.watch(currentUserProfileProvider);

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
        data: (shop) => ListView(
          padding: const EdgeInsets.all(AppSpacing.marginMain),
          children: [
            _SegmentedToggle(
              selected: fulfillment.type,
              onChanged: notifier.selectType,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            _YourDetailsCard(profileAsync: profileAsync),
            const SizedBox(height: AppSpacing.stackMd),
            if (fulfillment.type == FulfillmentType.pickup) ...[
              _PickupShopCard(shop: shop),
            ] else ...[
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
                onPressed: fulfillment.isLocating
                    ? null
                    : () => notifier.useCurrentLocation(
                          shopLat: shop.lat ?? 0,
                          shopLng: shop.lng ?? 0,
                        ),
                icon: fulfillment.isLocating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 20),
                label: Text(fulfillment.isLocating
                    ? 'Getting your location…'
                    : 'Use current location'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
              ),
              if (fulfillment.locationError != null) ...[
                const SizedBox(height: 4),
                Text(
                  fulfillment.locationError!,
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.stackMd),
              const _MapPreview(),
            ],
            const SizedBox(height: AppSpacing.stackLg),
            CustomButton(
              label: 'Continue',
              onPressed: fulfillment.canContinue
                  ? () => context.push(AppRoutes.checkout)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only name/phone/email summary, shown on both Pickup and
/// Delivery — not editable here (that's Settings' job). Pulled from
/// the real `users` row via currentUserProfileProvider, with a graceful
/// fallback while it's loading/if it fails, so this card never blocks
/// checkout on a slow profile fetch.
class _YourDetailsCard extends StatelessWidget {
  const _YourDetailsCard({required this.profileAsync});
  final AsyncValue<UserProfileModel?> profileAsync;

  @override
  Widget build(BuildContext context) {
    final profile = profileAsync.valueOrNull;
    final isLoading = profileAsync.isLoading;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackMd + 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.surfaceVariant),
        boxShadow: [
          BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.05),
              blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Details', style: AppTextStyles.labelCaps),
          const SizedBox(height: AppSpacing.stackSm),
          if (isLoading && profile == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            _DetailRow(
              icon: Icons.person_outline,
              value: (profile?.fullName.isNotEmpty ?? false)
                  ? profile!.fullName
                  : 'Not set',
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.phone_outlined,
              value: (profile?.phone?.isNotEmpty ?? false)
                  ? profile!.phone!
                  : 'No phone on file',
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.mail_outline,
              value: (profile?.email.isNotEmpty ?? false)
                  ? profile!.email
                  : 'No email on file',
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodySm,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Pickup branch's shop summary — mirrors shop_detail_screen.dart's
/// _ShopInfoCard styling (per the mirroring map in
/// SESSION_HANDOFF_phaseAH_fixes.md §3), simplified to name + address
/// since open/closed status is already visible on Shop Detail.
class _PickupShopCard extends StatelessWidget {
  const _PickupShopCard({required this.shop});
  final ShopModel shop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackMd + 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.surfaceVariant),
        boxShadow: [
          BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.05),
              blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pickup From', style: AppTextStyles.labelCaps),
          const SizedBox(height: AppSpacing.stackSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(Icons.storefront_outlined,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.stackSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shop.name, style: AppTextStyles.headlineMd),
                    if (shop.address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: AppColors.secondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              shop.address,
                              style: AppTextStyles.bodySm,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
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
