import 'package:flutter/material.dart';

enum CustomButtonVariant { primary, secondary }

/// Wraps ElevatedButton/OutlinedButton with a built-in loading state.
/// Per design.md §4 ("one primary action per screen"), most screens should
/// use exactly one CustomButtonVariant.primary and, if needed, one
/// CustomButtonVariant.secondary for a ghost/cancel action.
class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = CustomButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final CustomButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // Disable the button while loading — prevents double-submits (e.g.
    // double-tapping "Confirm Booking" and firing the RPC twice).
    final effectiveOnPressed = isLoading ? null : onPressed;

    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: variant == CustomButtonVariant.primary
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              )
            : Text(label);

    final button = variant == CustomButtonVariant.primary
        ? ElevatedButton(onPressed: effectiveOnPressed, child: child)
        : OutlinedButton(onPressed: effectiveOnPressed, child: child);

    if (!fullWidth) return button;

    return SizedBox(width: double.infinity, child: button);
  }
}
