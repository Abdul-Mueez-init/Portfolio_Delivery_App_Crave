import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/router/app_router.dart';
import '../../application/time_slots_provider.dart';
import '../../data/models/booking_model.dart';

const List<String> _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Matches booking_confirmation_updated/code.html: big status icon,
/// headline, summary card (date/time/party size), primary "Back to
/// Home" action. Reused for both the just-booked screen (pushed right
/// after BookingTab's Confirm Booking) and for opening a past booking
/// from Activity (design.md screen 14) — the header/icon/cancel button
/// all adapt to the booking's real status rather than assuming
/// "just confirmed".
class BookingConfirmationScreen extends ConsumerWidget {
  const BookingConfirmationScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingDetailProvider(bookingId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Booking'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: bookingAsync.when(
        loading: () => const SkeletonLoader.detail(),
        error: (error, stack) => ErrorView(
          message: "We couldn't load this booking right now. Please try again.",
          onRetry: () => ref.invalidate(bookingDetailProvider(bookingId)),
        ),
        data: (booking) => _BookingConfirmationContent(booking: booking),
      ),
    );
  }
}

class _BookingConfirmationContent extends ConsumerStatefulWidget {
  const _BookingConfirmationContent({required this.booking});
  final BookingModel booking;

  @override
  ConsumerState<_BookingConfirmationContent> createState() =>
      _BookingConfirmationContentState();
}

class _BookingConfirmationContentState
    extends ConsumerState<_BookingConfirmationContent> {
  bool _isCancelling = false;

  Future<void> _handleCancel() async {
    setState(() => _isCancelling = true);
    try {
      final repo = ref.read(bookingsRepositoryProvider);
      await repo.cancelBooking(widget.booking.id);
      ref.invalidate(bookingDetailProvider(widget.booking.id));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't cancel this booking. Please try again."),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final visual = _statusVisual(booking.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.marginMain),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.stackMd),
          _StatusIcon(icon: visual.icon, color: visual.color),
          const SizedBox(height: AppSpacing.stackLg),
          Text(
            visual.headline,
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineLgMobile,
          ),
          const SizedBox(height: AppSpacing.stackSm),
          Text(
            visual.subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySm,
          ),
          const SizedBox(height: AppSpacing.stackLg),
          _SummaryCard(booking: booking, visual: visual),
          const SizedBox(height: AppSpacing.stackLg),
          CustomButton(
            label: 'Back to Home',
            onPressed: () => context.go(AppRoutes.customerHome),
          ),
          if (booking.isCancellable) ...[
            const SizedBox(height: AppSpacing.stackSm),
            CustomButton(
              label: 'Cancel Booking',
              variant: CustomButtonVariant.secondary,
              isLoading: _isCancelling,
              onPressed: _handleCancel,
            ),
          ],
          const SizedBox(height: AppSpacing.stackLg),
        ],
      ),
    );
  }

  _StatusVisual _statusVisual(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return _StatusVisual(
          icon: Icons.hourglass_top_rounded,
          color: AppColors.warning,
          headline: 'Booking Requested!',
          subtitle: 'The shop will confirm your table shortly.',
        );
      case BookingStatus.confirmed:
        return _StatusVisual(
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
          headline: 'Booking Confirmed!',
          subtitle: "We're getting things ready for you.",
        );
      case BookingStatus.cancelled:
        return _StatusVisual(
          icon: Icons.cancel_rounded,
          color: AppColors.error,
          headline: 'Booking Cancelled',
          subtitle: 'This booking is no longer active.',
        );
      case BookingStatus.completed:
        return _StatusVisual(
          icon: Icons.event_available_rounded,
          color: AppColors.success,
          headline: 'Booking Completed',
          subtitle: 'Thanks for visiting!',
        );
    }
  }
}

class _StatusVisual {
  const _StatusVisual({
    required this.icon,
    required this.color,
    required this.headline,
    required this.subtitle,
  });
  final IconData icon;
  final Color color;
  final String headline;
  final String subtitle;
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 36),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.booking, required this.visual});
  final BookingModel booking;
  final _StatusVisual visual;

  @override
  Widget build(BuildContext context) {
    final slotTime = booking.slotTime;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.stackMd + 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.05),
              blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.shopName ?? 'Shop',
                  style: AppTextStyles.headlineMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusBadge(label: booking.status.label, color: visual.color),
            ],
          ),
          const Divider(height: AppSpacing.stackLg + 4),
          _SummaryRow(
            icon: Icons.calendar_today_rounded,
            label: 'DATE',
            value: slotTime != null ? _formatDate(slotTime) : '—',
          ),
          const Divider(height: AppSpacing.stackLg),
          _SummaryRow(
            icon: Icons.schedule_rounded,
            label: 'TIME',
            value: slotTime != null ? _formatTime(slotTime) : '—',
          ),
          const Divider(height: AppSpacing.stackLg),
          _SummaryRow(
            icon: Icons.people_alt_rounded,
            label: 'PARTY SIZE',
            value: '${booking.partySize} people',
          ),
          if (booking.assignedTableLabel != null) ...[
            const Divider(height: AppSpacing.stackLg),
            _SummaryRow(
              icon: Icons.event_seat_rounded,
              label: 'TABLE',
              value: booking.assignedTableLabel!,
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final weekday = _weekdayNames[date.weekday - 1];
    final month = _monthNames[date.month - 1];
    return '$weekday, $month ${date.day}';
  }

  String _formatTime(DateTime time) {
    final hour24 = time.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $period';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelCaps.copyWith(color: color),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.stackMd),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.labelCaps),
            Text(value, style: AppTextStyles.bodyLg),
          ],
        ),
      ],
    );
  }
}
