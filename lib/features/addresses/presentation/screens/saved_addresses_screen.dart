import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../application/addresses_provider.dart';
import '../../data/models/saved_address_model.dart';

const int _kMaxSavedAddresses = 4;

final geocoding.Geocoding _geocoder = geocoding.Geocoding();

/// Backs Profile's "Saved Addresses" row — previously a "coming in a
/// later phase" snackbar. Stores up to [_kMaxSavedAddresses] addresses
/// (also enforced server-side, see the SQL migration's trigger), each
/// addable either by typing or via "Use current location" (same GPS +
/// reverse-geocode flow as fulfillment_selection_screen.dart's, so the
/// two "use my location" affordances in the app behave identically).
class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(savedAddressesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Saved Addresses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: addressesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, stack) => ErrorView(
          message: "We couldn't load your addresses. Please try again.",
          onRetry: () => ref.invalidate(savedAddressesProvider),
        ),
        data: (addresses) {
          if (addresses.isEmpty) {
            return EmptyState(
              icon: Icons.location_on_outlined,
              title: 'No saved addresses yet',
              message: 'Add an address to speed through checkout next time.',
              actionLabel: 'Add Address',
              onAction: () => _showAddAddressSheet(context, ref),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.marginMain),
            children: [
              for (final address in addresses) ...[
                _AddressCard(
                  address: address,
                  onSetDefault: address.isDefault
                      ? null
                      : () async {
                          await ref
                              .read(addressesRepositoryProvider)
                              .setDefault(address.id);
                          ref.invalidate(savedAddressesProvider);
                        },
                  onDelete: () async {
                    await ref
                        .read(addressesRepositoryProvider)
                        .deleteAddress(address.id);
                    ref.invalidate(savedAddressesProvider);
                  },
                ),
                const SizedBox(height: AppSpacing.stackMd),
              ],
              const SizedBox(height: AppSpacing.stackMd),
              if (addresses.length < _kMaxSavedAddresses)
                CustomButton(
                  label: 'Add Address',
                  icon: Icons.add,
                  variant: CustomButtonVariant.secondary,
                  onPressed: () => _showAddAddressSheet(context, ref),
                )
              else
                Text(
                  "You've reached the $_kMaxSavedAddresses-address limit. "
                  'Delete one to add another.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showAddAddressSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (context) => const _AddAddressSheet(),
    ).then((_) => ref.invalidate(savedAddressesProvider));
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.onSetDefault,
    required this.onDelete,
  });

  final SavedAddressModel address;
  final VoidCallback? onSetDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: address.isDefault
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            address.isDefault ? Icons.star_rounded : Icons.location_on_outlined,
            color: address.isDefault
                ? AppColors.primaryContainer
                : AppColors.secondary,
          ),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      (address.label?.isNotEmpty ?? false)
                          ? address.label!
                          : 'Saved address',
                      style: AppTextStyles.headlineMd,
                    ),
                    if (address.isDefault) ...[
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
                const SizedBox(height: 4),
                Text(address.address, style: AppTextStyles.bodySm),
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

class _AddAddressSheet extends ConsumerStatefulWidget {
  const _AddAddressSheet();

  @override
  ConsumerState<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends ConsumerState<_AddAddressSheet> {
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  double? _lat;
  double? _lng;
  bool _isLocating = false;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _error = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _error =
            'Location services are turned off. Enable them in your device settings.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Location permission denied.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      // `geocoding` has no web implementation — skip the call on web
      // and show a clean label instead of raw lat/lng. Mobile keeps
      // the real reverse-geocoded address, unchanged.
      String resolved = kIsWeb
          ? 'Current location (GPS)'
          : '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      if (!kIsWeb) {
        try {
          final placemarks = await _geocoder.placemarkFromCoordinates(
              position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final parts = [p.street, p.subLocality, p.locality, p.administrativeArea]
                .where((s) => s != null && s.trim().isNotEmpty)
                .toList();
            if (parts.isNotEmpty) resolved = parts.join(', ');
          }
        } catch (_) {
          // Keep the coordinate fallback — not fatal.
        }
      }

      setState(() {
        _addressController.text = resolved;
        _lat = position.latitude;
        _lng = position.longitude;
      });
    } catch (_) {
      setState(() => _error = "Couldn't get your location. Please try again.");
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _save() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() => _error = 'Enter an address first.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref.read(addressesRepositoryProvider).addAddress(
            label: _labelController.text.trim().isEmpty
                ? null
                : _labelController.text.trim(),
            address: address,
            lat: _lat,
            lng: _lng,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = "Couldn't save that address: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.marginMain,
        right: AppSpacing.marginMain,
        top: AppSpacing.stackLg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.stackLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Address', style: AppTextStyles.headlineLgMobile),
          const SizedBox(height: AppSpacing.stackLg),
          CustomTextField(
            label: 'Label (optional)',
            hintText: 'Home, Work…',
            controller: _labelController,
          ),
          const SizedBox(height: AppSpacing.stackMd),
          CustomTextField(
            label: 'Address',
            hintText: 'Enter full address',
            controller: _addressController,
            maxLines: 2,
            onChanged: (_) {
              // Typing by hand invalidates any GPS-derived point — the
              // saved row shouldn't claim a coordinate for text the
              // person edited afterwards.
              if (_lat != null || _lng != null) {
                setState(() {
                  _lat = null;
                  _lng = null;
                });
              }
            },
          ),
          const SizedBox(height: AppSpacing.stackSm),
          TextButton.icon(
            onPressed: _isLocating ? null : _useCurrentLocation,
            icon: _isLocating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, size: 20),
            label: Text(
                _isLocating ? 'Getting your location…' : 'Use current location'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.stackSm),
            Text(_error!,
                style: AppTextStyles.bodySm.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.stackLg),
          CustomButton(
            label: 'Save Address',
            isLoading: _isSaving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
