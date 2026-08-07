import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_textfield.dart';
import '../../application/owner_shop_provider.dart';
import '../../application/shops_provider.dart';

/// design.md screen 20 — shown once, on first owner login before the
/// Dashboard. post_auth_navigation.dart routes here when
/// fetchShopByOwnerId returns null. Real insert into `shops`, tied to
/// auth.uid() — no draft/skip state, matches PLAN.md Phase 8 scope.
class ShopOnboardingScreen extends ConsumerStatefulWidget {
  const ShopOnboardingScreen({super.key});

  @override
  ConsumerState<ShopOnboardingScreen> createState() =>
      _ShopOnboardingScreenState();
}

class _ShopOnboardingScreenState extends ConsumerState<ShopOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _categoryController = TextEditingController();

  bool _acceptsDelivery = true;
  bool _acceptsBooking = true;
  Uint8List? _coverImageBytes;
  String? _coverImageExt;
  bool _isSubmitting = false;
  String? _errorMessage;

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
      _coverImageBytes = bytes;
      _coverImageExt = picked.path.split('.').last;
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
      final ownerId = Supabase.instance.client.auth.currentUser!.id;
      final shopsRepo = ref.read(shopsRepositoryProvider);

      var shop = await shopsRepo.createShop(
        ownerId: ownerId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        category: _categoryController.text.trim(),
        acceptsDelivery: _acceptsDelivery,
        acceptsBooking: _acceptsBooking,
      );

      // Cover photo upload needs the shop's id, so it's a second step
      // after the insert, not inline inside createShop.
      if (_coverImageBytes != null) {
        final coverUrl = await shopsRepo.uploadShopCoverImage(
          shopId: shop.id,
          bytes: _coverImageBytes!,
          fileExt: _coverImageExt ?? 'jpg',
        );
        shop = await shopsRepo.updateShop(
          shopId: shop.id,
          coverImageUrl: coverUrl,
        );
      }

      ref.invalidate(myShopProvider);
      if (!mounted) return;
      context.go(AppRoutes.ownerDashboard);
    } catch (_) {
      setState(() => _errorMessage =
          'Something went wrong creating your shop. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.marginMain),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Set up your shop',
                    style: AppTextStyles.headlineLgMobile
                        .copyWith(color: AppColors.onSurface)),
                const SizedBox(height: 6),
                Text(
                  'One-time setup — everything except this can be changed later from Shop Settings.',
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.stackLg),
                _CoverPicker(bytes: _coverImageBytes, onTap: _pickCoverImage),
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
                CustomTextField(
                  label: 'Shop Name',
                  hintText: 'The Daily Grind',
                  controller: _nameController,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Shop name is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.stackMd),
                CustomTextField(
                  label: 'Description',
                  hintText: 'Specialty coffee and pastries, roasted in-house.',
                  controller: _descriptionController,
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Description is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.stackMd),
                CustomTextField(
                  label: 'Address',
                  hintText: '14 Garden Lane',
                  controller: _addressController,
                  prefixIcon: Icons.location_on_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Address is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.stackMd),
                CustomTextField(
                  label: 'Category',
                  hintText: 'e.g. Coffee Shop, Restaurant, Healthy',
                  controller: _categoryController,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Category is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.stackLg),
                Text('CAPABILITIES', style: AppTextStyles.labelCaps),
                const SizedBox(height: AppSpacing.stackSm),
                _CapabilityToggle(
                  icon: Icons.delivery_dining_outlined,
                  title: 'Delivery & Pickup Orders',
                  subtitle: 'Customers can order ahead from your menu.',
                  value: _acceptsDelivery,
                  onChanged: (v) => setState(() => _acceptsDelivery = v),
                ),
                const SizedBox(height: AppSpacing.stackSm),
                _CapabilityToggle(
                  icon: Icons.event_seat_outlined,
                  title: 'Table Booking',
                  subtitle: 'Customers can reserve a time slot.',
                  value: _acceptsBooking,
                  onChanged: (v) => setState(() => _acceptsBooking = v),
                ),
                const SizedBox(height: AppSpacing.stackLg),
                CustomButton(
                  label: 'Launch My Shop',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({required this.bytes, required this.onTap});
  final Uint8List? bytes;
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
          border: Border.all(color: AppColors.outlineVariant),
          image: bytes != null
              ? DecorationImage(image: MemoryImage(bytes!), fit: BoxFit.cover)
              : null,
        ),
        child: bytes == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined,
                      color: AppColors.primary, size: 28),
                  const SizedBox(height: 8),
                  Text('Add a cover photo',
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.onSurfaceVariant)),
                ],
              )
            : Align(
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

class _CapabilityToggle extends StatelessWidget {
  const _CapabilityToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.bodyLg
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle, style: AppTextStyles.bodySm),
              ],
            ),
          ),
          Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary),
        ],
      ),
    );
  }
}
