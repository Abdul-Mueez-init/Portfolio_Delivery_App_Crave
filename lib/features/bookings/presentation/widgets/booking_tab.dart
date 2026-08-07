import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/quantity_stepper.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/router/app_router.dart';
import '../../../bookings/application/booking_flow_provider.dart';
import '../../../bookings/application/time_slots_provider.dart';
import '../../../bookings/data/models/time_slot_model.dart';

const List<String> _weekdayAbbrev = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// Matches booking_screen_updated/code.html: Party Size card, a
/// horizontally-scrolling 7-day date chip strip, a LUNCH/DINNER time
/// slot grid, "Confirm Booking" CTA. Wired into shop_detail_screen.dart
/// in place of _BookingTabPlaceholder (PLAN.md Phase 6).
class BookingTab extends ConsumerWidget {
  const BookingTab({super.key, required this.shopId, required this.shopName});

  final String shopId;
  final String shopName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flow = ref.watch(bookingFlowProvider);
    final notifier = ref.read(bookingFlowProvider.notifier);
    final slotsAsync = ref.watch(timeSlotsProvider(
      TimeSlotsQuery(shopId: shopId, date: flow.selectedDate),
    ));

    Future<void> handleConfirm() async {
      final bookingId = await notifier.confirmBooking();
      if (bookingId == null)
        return; // error is shown inline via flow.errorMessage
      if (!context.mounted) return;
      notifier.reset();
      context.push('${AppRoutes.bookingConfirmation}/$bookingId');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.stackMd,
        AppSpacing.gutter,
        AppSpacing.stackLg,
      ),
      children: [
        Text('Book a Table', style: AppTextStyles.headlineLgMobile),
        const SizedBox(height: 4),
        Text('Reserve your spot at $shopName.', style: AppTextStyles.bodySm),
        const SizedBox(height: AppSpacing.stackLg),
        _PartySizeCard(
          partySize: flow.partySize,
          onIncrement: notifier.incrementPartySize,
          onDecrement: notifier.decrementPartySize,
        ),
        const SizedBox(height: AppSpacing.stackLg),
        Text('Select Date', style: AppTextStyles.headlineMd),
        const SizedBox(height: AppSpacing.stackMd),
        _DateChipStrip(
          selectedDate: flow.selectedDate,
          onSelect: notifier.selectDate,
        ),
        const SizedBox(height: AppSpacing.stackLg),
        Text('Select Time', style: AppTextStyles.headlineMd),
        const SizedBox(height: AppSpacing.stackMd),
        slotsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.stackLg),
            child: SkeletonLoader.list(itemCount: 2),
          ),
          error: (error, stack) => ErrorView(
            message: "We couldn't load time slots right now. Please try again.",
            onRetry: () => ref.invalidate(timeSlotsProvider(
              TimeSlotsQuery(shopId: shopId, date: flow.selectedDate),
            )),
          ),
          data: (slots) {
            final upcoming = _upcomingOnly(slots, flow.selectedDate);
            if (upcoming.isEmpty) {
              return const EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'No slots available',
                message: 'This shop has no bookable times on this day.',
              );
            }
            final lunch = upcoming.where((s) => s.isLunch).toList();
            final dinner = upcoming.where((s) => !s.isLunch).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (lunch.isNotEmpty)
                  _TimeSlotSection(
                    label: 'LUNCH',
                    slots: lunch,
                    partySize: flow.partySize,
                    selectedSlotId: flow.selectedTimeSlotId,
                    onSelect: notifier.selectTimeSlot,
                  ),
                if (lunch.isNotEmpty && dinner.isNotEmpty)
                  const SizedBox(height: AppSpacing.stackMd),
                if (dinner.isNotEmpty)
                  _TimeSlotSection(
                    label: 'DINNER',
                    slots: dinner,
                    partySize: flow.partySize,
                    selectedSlotId: flow.selectedTimeSlotId,
                    onSelect: notifier.selectTimeSlot,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.stackLg),
        if (flow.errorMessage != null) ...[
          Text(
            flow.errorMessage!,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: AppSpacing.stackSm),
        ],
        CustomButton(
          label: 'Confirm Booking',
          isLoading: flow.isSubmitting,
          onPressed: flow.canConfirm ? handleConfirm : null,
        ),
      ],
    );
  }

  /// Drops slots that have already passed today — booking a 12:00 slot
  /// at 3pm today makes no sense even though the row still exists.
  /// Future days are unaffected (every slot on them is "upcoming").
  List<TimeSlotModel> _upcomingOnly(
      List<TimeSlotModel> slots, DateTime selectedDate) {
    final now = DateTime.now();
    final isToday = selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    if (!isToday) return slots;
    return slots.where((s) => s.slotTime.isAfter(now)).toList();
  }
}

class _PartySizeCard extends StatelessWidget {
  const _PartySizeCard({
    required this.partySize,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int partySize;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.stackMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.03),
              blurRadius: 16),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Party Size', style: AppTextStyles.headlineMd),
              Text('Number of people', style: AppTextStyles.bodySm),
            ],
          ),
          QuantityStepper(
            quantity: partySize,
            minQuantity: 1,
            onIncrement: onIncrement,
            onDecrement: onDecrement,
          ),
        ],
      ),
    );
  }
}

class _DateChipStrip extends StatelessWidget {
  const _DateChipStrip({required this.selectedDate, required this.onSelect});

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    final days =
        List.generate(7, (i) => todayNormalized.add(Duration(days: i)));

    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final day = days[index];
          final isSelected = day == selectedDate;
          final label = index == 0 ? 'Today' : _weekdayAbbrev[day.weekday - 1];
          return _DateChip(
            label: label,
            dayNumber: day.day,
            isSelected: isSelected,
            onTap: () => onSelect(day),
          );
        },
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.dayNumber,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int dayNumber;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.primaryContainer
          : AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          width: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border:
                isSelected ? null : Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySm.copyWith(
                  color: isSelected
                      ? AppColors.onPrimary.withValues(alpha: 0.9)
                      : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$dayNumber',
                style: AppTextStyles.headlineMd.copyWith(
                  color: isSelected ? AppColors.onPrimary : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeSlotSection extends StatelessWidget {
  const _TimeSlotSection({
    required this.label,
    required this.slots,
    required this.partySize,
    required this.selectedSlotId,
    required this.onSelect,
  });

  final String label;
  final List<TimeSlotModel> slots;
  final int partySize;
  final String? selectedSlotId;
  final ValueChanged<TimeSlotModel> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelCaps),
        const SizedBox(height: AppSpacing.stackSm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: slots.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: AppSpacing.stackMd,
            crossAxisSpacing: AppSpacing.stackMd,
            childAspectRatio: 2.2,
          ),
          itemBuilder: (context, index) {
            final slot = slots[index];
            final canFit = slot.canFit(partySize);
            final isSelected = slot.id == selectedSlotId;
            return _TimeSlotButton(
              label: _formatTime(slot.slotTime),
              isSelected: isSelected,
              isDisabled: !canFit,
              onTap: canFit ? () => onSelect(slot) : null,
            );
          },
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _TimeSlotButton extends StatelessWidget {
  const _TimeSlotButton({
    required this.label,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSelected
        ? AppColors.primaryContainer
        : isDisabled
            ? AppColors.surfaceContainer
            : AppColors.surfaceContainerLowest;
    final textColor = isSelected
        ? AppColors.onPrimary
        : isDisabled
            ? AppColors.onSurfaceVariant.withValues(alpha: 0.5)
            : AppColors.onSurface;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: isSelected || isDisabled
                ? null
                : Border.all(color: AppColors.outlineVariant),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.headlineMd.copyWith(color: textColor),
          ),
        ),
      ),
    );
  }
}
