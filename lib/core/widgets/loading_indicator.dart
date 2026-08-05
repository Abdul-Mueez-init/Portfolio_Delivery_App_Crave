import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A centered, brand-colored loading spinner.
/// Use for full-screen or full-section loading states where a
/// SkeletonLoader isn't a better fit (e.g. submitting a form, waiting
/// on a payment sheet) — per design.md §4, prefer SkeletonLoader for
/// list/detail screens fetching data, since a blank spinner "reads
/// unfinished."
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(
          strokeWidth: 3,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
