import 'package:flutter/material.dart';
import 'custom_button.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// A designed error state — per design.md §4, error states must be
/// designed, not a default red error dump. Use whenever a fetch/mutation
/// fails and the user needs a way to recover (e.g. Realtime dropped and
/// the fetch-on-resume fallback from rules.md §6 also failed).
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.title = 'Something went wrong',
    this.message = "We couldn't load this right now. Please try again.",
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.marginMain),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.stackMd),
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.stackMd),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineMd,
            ),
            const SizedBox(height: AppSpacing.stackSm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.stackLg),
              CustomButton(
                label: 'Try Again',
                onPressed: onRetry,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
