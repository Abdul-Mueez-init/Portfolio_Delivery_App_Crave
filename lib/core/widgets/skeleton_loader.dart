import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Animated shimmer placeholder — per design.md §4, loading states must
/// be designed, not a bare spinner. Use on every list/detail screen that
/// fetches data (shop list, menu, activity, order queue, etc.) per
/// PLAN.md Phase 11.
///
/// No external shimmer package — implemented with a plain AnimationController
/// so we don't add a dependency for something this small.
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader.list({super.key, this.itemCount = 6})
      : variant = _SkeletonVariant.list;

  const SkeletonLoader.detail({super.key})
      : itemCount = 1,
        variant = _SkeletonVariant.detail;

  final int itemCount;
  final _SkeletonVariant variant;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

enum _SkeletonVariant { list, detail }

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final opacity = 0.4 + (_controller.value * 0.3); // pulses 0.4 → 0.7
        return widget.variant == _SkeletonVariant.list
            ? _buildList(opacity)
            : _buildDetail(opacity);
      },
    );
  }

  Widget _buildList(double opacity) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.marginMain),
      itemCount: widget.itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.gutter),
      itemBuilder: (context, index) {
        return Row(
          children: [
            _block(opacity, width: 64, height: 64, radius: AppSpacing.radiusMd),
            const SizedBox(width: AppSpacing.gutter),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _block(opacity, width: double.infinity, height: 16),
                  const SizedBox(height: AppSpacing.stackSm),
                  _block(opacity, width: 120, height: 12),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetail(double opacity) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.marginMain),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _block(opacity,
              width: double.infinity, height: 180, radius: AppSpacing.radiusLg),
          const SizedBox(height: AppSpacing.stackMd),
          _block(opacity, width: 200, height: 20),
          const SizedBox(height: AppSpacing.stackSm),
          _block(opacity, width: double.infinity, height: 14),
          const SizedBox(height: AppSpacing.stackSm),
          _block(opacity, width: double.infinity, height: 14),
          const SizedBox(height: AppSpacing.stackSm),
          _block(opacity, width: 160, height: 14),
        ],
      ),
    );
  }

  Widget _block(
    double opacity, {
    required double width,
    required double height,
    double radius = AppSpacing.radiusSm,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
