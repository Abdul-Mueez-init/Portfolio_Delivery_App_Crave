import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// Shared pill-shaped quantity control — used inline on menu item cards
/// (compact: true) and standalone in the Item Detail sheet / Cart screen
/// (compact: false, matches item_detail_redesigned's larger stepper).
/// Reused instead of rolling a one-off per screen (context.md working
/// process rule 5).
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.minQuantity = 1,
    this.compact = false,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  /// Decrement button disables once quantity reaches this floor. Pass 0
  /// for contexts where hitting 0 should be allowed (e.g. a cart line
  /// that removes itself at 0) — the parent decides what happens next,
  /// this widget just won't block the tap.
  final int minQuantity;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 16.0 : 20.0;
    final buttonPadding = compact ? 6.0 : 10.0;
    final canDecrement = quantity > minQuantity;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperIconButton(
            icon: Icons.remove,
            iconSize: iconSize,
            padding: buttonPadding,
            onTap: canDecrement ? onDecrement : null,
          ),
          SizedBox(
            width: compact ? 24 : 32,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: (compact ? AppTextStyles.bodyLg : AppTextStyles.headlineMd)
                  .copyWith(color: AppColors.primary),
            ),
          ),
          _StepperIconButton(
            icon: Icons.add,
            iconSize: iconSize,
            padding: buttonPadding,
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepperIconButton extends StatelessWidget {
  const _StepperIconButton({
    required this.icon,
    required this.iconSize,
    required this.padding,
    required this.onTap,
  });

  final IconData icon;
  final double iconSize;
  final double padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Icon(
          icon,
          size: iconSize,
          color: disabled
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.primary,
        ),
      ),
    );
  }
}
