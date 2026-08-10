import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
              _DeliveryAddressField(
                address: fulfillment.address,
                onChanged: notifier.setAddress,
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
              // Phase G follow-up: was a static decorative container
              // ("Visual flair" per the Stitch export) even after real
              // GPS landed — google_maps_flutter was already a dependency
              // but never actually wired to a GoogleMap widget anywhere.
              // Now centers on the real fix (deliveryLat/Lng) once
              // captured, falling back to the shop's location before
              // that so the map is never blank.
              _MapPreview(
                latitude: fulfillment.deliveryLat ?? shop.lat,
                longitude: fulfillment.deliveryLng ?? shop.lng,
                hasRealFix: fulfillment.deliveryLat != null,
              ),
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

/// TextField that stays in sync with FulfillmentState.address — the
/// old version was a bare stateless TextField with only onChanged, so
/// tapping "Use current location" updated the address in state but the
/// field on screen kept showing empty. A controller + didUpdateWidget
/// sync fixes that without restructuring the parent into a
/// ConsumerStatefulWidget.
class _DeliveryAddressField extends StatefulWidget {
  const _DeliveryAddressField({
    required this.address,
    required this.onChanged,
  });

  final String address;
  final ValueChanged<String> onChanged;

  @override
  State<_DeliveryAddressField> createState() => _DeliveryAddressFieldState();
}

class _DeliveryAddressFieldState extends State<_DeliveryAddressField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.address);
  }

  @override
  void didUpdateWidget(covariant _DeliveryAddressField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only overwrite the field when the address changed from *outside*
    // (e.g. GPS fix landing) — not on every rebuild, or the cursor
    // would jump while the person is still typing.
    if (widget.address != oldWidget.address &&
        widget.address != _controller.text) {
      _controller.text = widget.address;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      style: AppTextStyles.bodyLg,
      decoration: const InputDecoration(
        hintText: 'Enter full address',
        prefixIcon: Icon(Icons.location_on_outlined),
      ),
    );
  }
}

/// Real GoogleMap centered on the delivery point — was previously a
/// static decorative container ("Visual flair" per the Stitch export)
/// even after Phase G landed real GPS. Non-interactive (gestures off)
/// since it's a small preview inside a scrolling ListView; a
/// full-interactive map is a bigger change than this fix batch.
class _MapPreview extends StatelessWidget {
  const _MapPreview({
    required this.latitude,
    required this.longitude,
    required this.hasRealFix,
  });

  final double? latitude;
  final double? longitude;

  /// True once a real GPS fix (or manually-entered point) exists —
  /// false while still just falling back to the shop's own location,
  /// so the label below the map is honest about what it's showing.
  final bool hasRealFix;

  @override
  Widget build(BuildContext context) {
    if (latitude == null || longitude == null) {
      // No shop lat/lng and no GPS fix yet — nothing to center on.
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
              color: AppColors.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(
            'Tap "Use current location" or enter an address',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm,
          ),
        ),
      );
    }

    final point = LatLng(latitude!, longitude!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: SizedBox(
            height: 180,
            width: double.infinity,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: point, zoom: 15),
              markers: {
                Marker(
                    markerId: const MarkerId('delivery_point'),
                    position: point),
              },
              // Preview only — disable gestures so it doesn't fight the
              // parent ListView's scroll.
              zoomGesturesEnabled: false,
              scrollGesturesEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              myLocationButtonEnabled: false,
              liteModeEnabled: true,
            ),
          ),
        ),
        if (hasRealFix) ...[
          const SizedBox(height: 4),
          Text(
            'Showing your current location',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.secondary),
          ),
        ],
      ],
    );
  }
}
