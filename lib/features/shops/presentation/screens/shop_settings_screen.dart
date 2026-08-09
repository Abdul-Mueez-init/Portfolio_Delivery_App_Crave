import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../application/owner_shop_provider.dart';
import '../../application/shops_provider.dart';
import '../../data/models/shop_model.dart';

/// design.md screen 21 — edits everything captured at onboarding, after
/// the fact. Without this screen those fields are permanently locked
/// after the first save (the real gap flagged in the Phase 8 handoff).
/// Reached from the Dashboard's Quick Actions / an app bar icon (next
/// batch) via context.push, not part of the owner bottom nav.
class ShopSettingsScreen extends ConsumerWidget {
  const ShopSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(myShopProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Shop Settings',
            style:
                AppTextStyles.headlineMd.copyWith(color: AppColors.onSurface)),
      ),
      body: shopAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, stack) => ErrorView(
          message: "We couldn't load your shop. Please try again.",
          onRetry: () => ref.invalidate(myShopProvider),
        ),
        data: (shop) {
          if (shop == null) {
            // Shouldn't happen in practice — Shop Settings is only
            // reachable from the Dashboard, which itself requires a
            // shop to exist. Defensive, not a real user-facing path.
            return const ErrorView(
              title: 'No shop found',
              message: 'Complete Shop Onboarding first.',
            );
          }
          return _SettingsForm(shop: shop);
        },
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.shop});
  final ShopModel shop;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _categoryController;

  late bool _isOpen;
  late bool _acceptsDelivery;
  late bool _acceptsBooking;
  Uint8List? _newCoverBytes;
  String? _newCoverExt;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final shop = widget.shop;
    _nameController = TextEditingController(text: shop.name);
    _descriptionController = TextEditingController(text: shop.description);
    _addressController = TextEditingController(text: shop.address);
    _categoryController = TextEditingController(text: shop.category);
    _isOpen = shop.isOpen;
    _acceptsDelivery = shop.acceptsDelivery;
    _acceptsBooking = shop.acceptsBooking;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _newCoverBytes = bytes;
      _newCoverExt = picked.path.split('.').last;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptsDelivery && !_acceptsBooking) {
      setState(() =>
          _errorMessage = 'Turn on at least one of Delivery or Table Booking.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final shopsRepo = ref.read(shopsRepositoryProvider);
      String? coverUrl;
      if (_newCoverBytes != null) {
        coverUrl = await shopsRepo.uploadShopCoverImage(
          shopId: widget.shop.id,
          bytes: _newCoverBytes!,
          fileExt: _newCoverExt ?? 'jpg',
        );
      }

      await shopsRepo.updateShop(
        shopId: widget.shop.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        category: _categoryController.text.trim(),
        acceptsDelivery: _acceptsDelivery,
        acceptsBooking: _acceptsBooking,
        isOpen: _isOpen,
        coverImageUrl: coverUrl,
      );

      ref.invalidate(myShopProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Shop settings saved.')));
      context.pop();
    } catch (e, st) {
      debugPrint('MenuItemFormScreen._submit failed: $e\n$st');
      setState(() => _errorMessage = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.marginMain),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CoverPreview(
              currentUrl: widget.shop.coverImageUrl,
              newBytes: _newCoverBytes,
              onTap: _pickCoverImage,
            ),
            const SizedBox(height: AppSpacing.stackLg),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.onErrorContainer),
                ),
              ),
              const SizedBox(height: AppSpacing.stackMd),
            ],
            Container(
              padding: const EdgeInsets.all(AppSpacing.stackMd),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(
                    _isOpen ? Icons.storefront : Icons.storefront_outlined,
                    color: _isOpen
                        ? AppColors.success
                        : AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.stackSm),
                  Expanded(
                    child: Text(
                      _isOpen ? 'Shop is open' : 'Shop is closed',
                      style: AppTextStyles.bodyLg
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Switch(
                    value: _isOpen,
                    onChanged: (v) => setState(() => _isOpen = v),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackLg),
            CustomTextField(
              label: 'Shop Name',
              controller: _nameController,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Shop name is required'
                  : null,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            CustomTextField(
              label: 'Description',
              controller: _descriptionController,
              maxLines: 3,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Description is required'
                  : null,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            CustomTextField(
              label: 'Address',
              controller: _addressController,
              prefixIcon: Icons.location_on_outlined,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Address is required'
                  : null,
            ),
            const SizedBox(height: AppSpacing.stackMd),
            CustomTextField(
              label: 'Category',
              controller: _categoryController,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Category is required'
                  : null,
            ),
            const SizedBox(height: AppSpacing.stackLg),
            Text('CAPABILITIES', style: AppTextStyles.labelCaps),
            const SizedBox(height: AppSpacing.stackSm),
            _CapabilitySwitch(
              icon: Icons.delivery_dining_outlined,
              title: 'Delivery & Pickup Orders',
              value: _acceptsDelivery,
              onChanged: (v) => setState(() => _acceptsDelivery = v),
            ),
            const SizedBox(height: AppSpacing.stackSm),
            _CapabilitySwitch(
              icon: Icons.event_seat_outlined,
              title: 'Table Booking',
              value: _acceptsBooking,
              onChanged: (v) => setState(() => _acceptsBooking = v),
            ),
            const SizedBox(height: AppSpacing.stackLg),
            CustomButton(
              label: 'Save Changes',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPreview extends StatelessWidget {
  const _CoverPreview({
    required this.currentUrl,
    required this.newBytes,
    required this.onTap,
  });

  final String currentUrl;
  final Uint8List? newBytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          image: newBytes != null
              ? DecorationImage(
                  image: MemoryImage(newBytes!), fit: BoxFit.cover)
              : (currentUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(currentUrl), fit: BoxFit.cover)
                  : null),
        ),
        child: Align(
          alignment: Alignment.bottomRight,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
                color: Colors.black45, shape: BoxShape.circle),
            child: const Icon(Icons.edit, color: Colors.white, size: 16),
          ),
        ),
      ),
    );
  }
}

class _CapabilitySwitch extends StatelessWidget {
  const _CapabilitySwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: AppSpacing.stackSm),
          Expanded(child: Text(title, style: AppTextStyles.bodyLg)),
          Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary),
        ],
      ),
    );
  }
}
