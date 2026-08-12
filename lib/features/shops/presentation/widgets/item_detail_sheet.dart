import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../cart/application/cart_provider.dart';
import '../../../cart/data/models/cart_item_model.dart';
import '../../data/models/menu_item_model.dart';

/// Matches item_detail_redesigned/code.html — full-bleed image, close
/// button floating over it, name+price, description, divider, Quantity
/// stepper, "Add a note" field, sticky "Add to Cart • $X.XX" CTA.
///
/// Deliberately starts quantity at 1 regardless of what's already in the
/// cart for this item — "Add to Cart" here adds *this many more*, and
/// CartNotifier.addItem merges into the existing line (see cart_provider.dart).
Future<void> showItemDetailSheet(
  BuildContext context, {
  required String shopId,
  required MenuItemModel item,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ItemDetailSheetContent(shopId: shopId, item: item),
  );
}

class _ItemDetailSheetContent extends ConsumerStatefulWidget {
  const _ItemDetailSheetContent({required this.shopId, required this.item});

  final String shopId;
  final MenuItemModel item;

  @override
  ConsumerState<_ItemDetailSheetContent> createState() =>
      _ItemDetailSheetContentState();
}

class _ItemDetailSheetContentState
    extends ConsumerState<_ItemDetailSheetContent> {
  int _quantity = 1;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleAddToCart() async {
    final notifier = ref.read(cartProvider.notifier);

    if (notifier.belongsToDifferentShop(widget.shopId)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a new order?'),
          content: const Text(
            'Your cart has items from another shop. Adding this item will '
            'clear your current cart.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start New Order'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      notifier.clear();
    }

    final note = _noteController.text.trim();
    notifier.addItem(
      widget.shopId,
      CartItemModel.fromMenuItem(widget.item, quantity: _quantity)
          .copyWith(notes: note.isEmpty ? null : note),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusLg),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.stackSm),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.stackMd),
                      _ImageWithCloseButton(item: item),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.marginMain),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(item.name,
                                      style: AppTextStyles.headlineMd),
                                ),
                                Text(
                                  '\$${item.price.toStringAsFixed(2)}',
                                  style: AppTextStyles.headlineMd
                                      .copyWith(color: AppColors.primary),
                                ),
                              ],
                            ),
                            if (item.description.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.stackSm),
                              Text(item.description,
                                  style: AppTextStyles.bodyLg.copyWith(
                                      color: AppColors.onSurfaceVariant)),
                            ],
                            const SizedBox(height: AppSpacing.stackMd),
                            const Divider(),
                            const SizedBox(height: AppSpacing.stackMd),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Quantity',
                                    style: AppTextStyles.headlineMd),
                                QuantityStepper(
                                  quantity: _quantity,
                                  onDecrement: () =>
                                      setState(() => _quantity--),
                                  onIncrement: () =>
                                      setState(() => _quantity++),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.stackLg),
                            Text('Add a note', style: AppTextStyles.headlineMd),
                            const SizedBox(height: AppSpacing.stackSm),
                            TextField(
                              controller: _noteController,
                              maxLines: 3,
                              style: AppTextStyles.bodyLg,
                              decoration: const InputDecoration(
                                hintText: 'e.g. Extra hot, oat milk...',
                              ),
                            ),
                            const SizedBox(height: AppSpacing.stackMd),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.marginMain,
                    AppSpacing.stackSm,
                    AppSpacing.marginMain,
                    AppSpacing.stackMd,
                  ),
                  child: CustomButton(
                    label:
                        'Add to Cart  •  \$${(item.price * _quantity).toStringAsFixed(2)}',
                    onPressed: item.isAvailable ? _handleAddToCart : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageWithCloseButton extends StatelessWidget {
  const _ImageWithCloseButton({required this.item});
  final MenuItemModel item;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: SizedBox(
            width: double.infinity,
            height: 240,
            child: item.imageUrl.isEmpty
                ? Container(color: AppColors.surfaceContainerHigh)
                : CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.cover,
                    // Decode near the actual display size (2x for device
                    // pixel ratio) instead of the full source resolution.
                    memCacheWidth: 800,
                    memCacheHeight: 480,
                    placeholder: (context, url) =>
                        Container(color: AppColors.surfaceContainerHigh),
                    errorWidget: (context, url, error) =>
                        Container(color: AppColors.surfaceContainerHigh),
                  ),
          ),
        ),
        Positioned(
          top: AppSpacing.stackMd,
          right: AppSpacing.stackMd,
          child: Material(
            color: AppColors.surface.withValues(alpha: 0.9),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close, size: 20, color: AppColors.onSurface),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
