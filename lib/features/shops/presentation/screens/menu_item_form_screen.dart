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
import '../../application/menu_provider.dart';
import '../../data/models/menu_item_model.dart';

/// Args passed via go_router's `extra` to /owner/menu/item-form —
/// [item] null means "add mode", non-null means "edit mode". A plain
/// data class rather than encoding this in the URL, since MenuItemModel
/// doesn't need to survive a deep link / browser refresh the way an id
/// would.
class MenuItemFormArgs {
  const MenuItemFormArgs({required this.shopId, this.item});
  final String shopId;
  final MenuItemModel? item;
}

/// design.md screen 19's "+ Add Item" form, reused for Edit too (same
/// fields, pre-filled). Image upload wired for real via
/// MenuRepository.uploadMenuItemImage — see the Storage bucket setup
/// notes for the one-time `shop-images` bucket this depends on.
class MenuItemFormScreen extends ConsumerStatefulWidget {
  const MenuItemFormScreen({super.key, required this.args});
  final MenuItemFormArgs args;

  @override
  ConsumerState<MenuItemFormScreen> createState() => _MenuItemFormScreenState();
}

class _MenuItemFormScreenState extends ConsumerState<MenuItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _categoryController;

  late bool _isAvailable;
  Uint8List? _newImageBytes;
  String? _newImageExt;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.args.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.args.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController =
        TextEditingController(text: item?.description ?? '');
    _priceController = TextEditingController(
        text: item != null ? item.price.toStringAsFixed(2) : '');
    _categoryController = TextEditingController(text: item?.category ?? '');
    _isAvailable = item?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _newImageBytes = bytes;
      _newImageExt = picked.path.split('.').last;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(menuRepositoryProvider);
      final price = double.parse(_priceController.text.trim());

      String? imageUrl;
      if (_newImageBytes != null) {
        imageUrl = await repo.uploadMenuItemImage(
          shopId: widget.args.shopId,
          bytes: _newImageBytes!,
          fileExt: _newImageExt ?? 'jpg',
        );
      }

      if (_isEditing) {
        await repo.updateMenuItem(
          itemId: widget.args.item!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          price: price,
          category: _categoryController.text.trim(),
          isAvailable: _isAvailable,
          imageUrl: imageUrl,
        );
      } else {
        await repo.createMenuItem(
          shopId: widget.args.shopId,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          price: price,
          category: _categoryController.text.trim(),
          isAvailable: _isAvailable,
          imageUrl: imageUrl ?? '',
        );
      }

      ref.invalidate(menuForShopProvider(widget.args.shopId));
      if (!mounted) return;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(_isEditing ? 'Edit Item' : 'Add Item',
            style:
                AppTextStyles.headlineMd.copyWith(color: AppColors.onSurface)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.marginMain),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ImagePicker(
                  bytes: _newImageBytes,
                  currentUrl: widget.args.item?.imageUrl,
                  onTap: _pickImage,
                ),
                const SizedBox(height: AppSpacing.stackLg),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(_errorMessage!,
                        style: AppTextStyles.bodySm
                            .copyWith(color: AppColors.onErrorContainer)),
                  ),
                  const SizedBox(height: AppSpacing.stackMd),
                ],
                CustomTextField(
                  label: 'Item Name',
                  hintText: 'Flat White',
                  controller: _nameController,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.stackMd),
                CustomTextField(
                  label: 'Description',
                  hintText: 'Double shot, steamed milk.',
                  controller: _descriptionController,
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.stackMd),
                CustomTextField(
                  label: 'Price',
                  hintText: '4.50',
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: Icons.attach_money,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'Price is required';
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null || parsed <= 0)
                      return 'Enter a valid price';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.stackMd),
                CustomTextField(
                  label: 'Category',
                  hintText: 'e.g. Coffee, Pastries, Mains',
                  controller: _categoryController,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Category is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.stackLg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.stackMd),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(_isAvailable ? 'In Stock' : 'Sold Out',
                            style: AppTextStyles.bodyLg
                                .copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Switch(
                        value: _isAvailable,
                        onChanged: (v) => setState(() => _isAvailable = v),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.stackLg),
                CustomButton(
                  label: _isEditing ? 'Save Changes' : 'Add Item',
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

class _ImagePicker extends StatelessWidget {
  const _ImagePicker(
      {required this.bytes, required this.currentUrl, required this.onTap});
  final Uint8List? bytes;
  final String? currentUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        bytes != null || (currentUrl != null && currentUrl!.isNotEmpty);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.outlineVariant),
          image: bytes != null
              ? DecorationImage(image: MemoryImage(bytes!), fit: BoxFit.cover)
              : (currentUrl != null && currentUrl!.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(currentUrl!), fit: BoxFit.cover)
                  : null),
        ),
        child: !hasImage
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined,
                      color: AppColors.primary, size: 24),
                  const SizedBox(height: 6),
                  Text('Add a photo',
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
