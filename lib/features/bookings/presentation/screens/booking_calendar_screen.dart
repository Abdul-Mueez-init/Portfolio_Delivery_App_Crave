import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/owner_bottom_nav.dart';
import '../../../shops/application/owner_shop_provider.dart';
import '../../application/owner_bookings_provider.dart';
import '../../application/time_slots_provider.dart';
import '../../data/models/booking_model.dart';
import '../../data/repositories/bookings_repository.dart';

const _weekdayAbbr = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

/// design.md screen 18 — real bookings for this shop, grouped by slot
/// time, for one calendar day at a time (day tabs across the top). Not
/// Realtime (unlike Order Queue) — a FutureProvider re-fetched after
/// each mutation, since bookings change far less frequently than order
/// status and a 7-day tab strip has no single "current" stream to
/// subscribe to anyway.
class BookingCalendarScreen extends ConsumerWidget {
  const BookingCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(myShopProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Booking Calendar',
            style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary)),
      ),
      body: shopAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, s) => ErrorView(
          message: "We couldn't load your shop.",
          onRetry: () => ref.invalidate(myShopProvider),
        ),
        data: (shop) {
          if (shop == null) {
            return const ErrorView(
                title: 'No shop found',
                message: 'Complete Shop Onboarding first.');
          }
          return _CalendarBody(shopId: shop.id);
        },
      ),
      bottomNavigationBar: const OwnerBottomNav(currentIndex: 2),
    );
  }
}

class _CalendarBody extends ConsumerStatefulWidget {
  const _CalendarBody({required this.shopId});
  final String shopId;

  @override
  ConsumerState<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends ConsumerState<_CalendarBody> {
  late DateTime _selectedDate;
  late final List<DateTime> _days;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDate = DateTime(today.year, today.month, today.day);
    _days = List.generate(7, (i) => _selectedDate.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final query = ShopBookingsQuery(shopId: widget.shopId, date: _selectedDate);
    final bookingsAsync = ref.watch(shopBookingsProvider(query));

    return Column(
      children: [
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMain,
                vertical: AppSpacing.stackSm),
            itemCount: _days.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSpacing.stackSm),
            itemBuilder: (context, i) {
              final day = _days[i];
              final isSelected = day == _selectedDate;
              return GestureDetector(
                onTap: () => setState(() => _selectedDate = day),
                child: Container(
                  width: 56,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryContainer
                        : AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_weekdayAbbr[day.weekday - 1],
                          style: AppTextStyles.labelCaps.copyWith(
                              color: isSelected
                                  ? AppColors.onPrimaryContainer
                                  : AppColors.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text('${day.day}',
                          style: AppTextStyles.headlineMd.copyWith(
                              color: isSelected
                                  ? AppColors.onPrimaryContainer
                                  : AppColors.onSurface)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, color: AppColors.outlineVariant),
        Expanded(
          child: bookingsAsync.when(
            loading: () => const LoadingIndicator(),
            error: (e, s) => ErrorView(
              message: "We couldn't load bookings for this day.",
              onRetry: () => ref.invalidate(shopBookingsProvider(query)),
            ),
            data: (bookings) {
              final active = bookings
                  .where((b) => b.status != BookingStatus.cancelled)
                  .toList()
                ..sort((a, b) => (a.slotTime ?? a.createdAt)
                    .compareTo(b.slotTime ?? b.createdAt));

              if (active.isEmpty) {
                return const EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'No bookings this day',
                  message: 'Bookings for this date will show up here.',
                );
              }

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.marginMain),
                children: active
                    .map((b) => _BookingCard(booking: b, query: query))
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BookingCard extends ConsumerStatefulWidget {
  const _BookingCard({required this.booking, required this.query});
  final BookingModel booking;
  final ShopBookingsQuery query;

  @override
  ConsumerState<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<_BookingCard> {
  bool _isBusy = false;

  String _formatTime(DateTime? t) {
    if (t == null) return '';
    final hour = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<void> _run(Future<Object?> Function() action) async {
    setState(() => _isBusy = true);
    try {
      await action();
      ref.invalidate(shopBookingsProvider(widget.query));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Something went wrong. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _showAssignTableDialog(BookingsRepository repo) async {
    final controller =
        TextEditingController(text: widget.booking.assignedTableLabel ?? '');
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Table'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. Table 4'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (label != null && label.isNotEmpty) {
      await _run(() =>
          repo.assignTable(bookingId: widget.booking.id, tableLabel: label));
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final repo = ref.read(bookingsRepositoryProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.stackSm),
      padding: const EdgeInsets.all(AppSpacing.stackMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time,
                  size: 16, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(_formatTime(booking.slotTime),
                  style: AppTextStyles.headlineMd),
              const Spacer(),
              _StatusChip(status: booking.status),
            ],
          ),
          const SizedBox(height: AppSpacing.stackSm),
          Row(
            children: [
              const Icon(Icons.people_outline,
                  size: 16, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${booking.partySize} people', style: AppTextStyles.bodySm),
              if (booking.assignedTableLabel != null &&
                  booking.assignedTableLabel!.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.stackSm),
                const Icon(Icons.table_bar_outlined,
                    size: 16, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(booking.assignedTableLabel!, style: AppTextStyles.bodySm),
              ],
            ],
          ),
          if (booking.status != BookingStatus.completed) ...[
            const SizedBox(height: AppSpacing.stackSm),
            Row(
              children: [
                if (booking.status == BookingStatus.pending)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isBusy
                          ? null
                          : () => _run(() => repo.confirmBooking(booking.id)),
                      child: const Text('Confirm'),
                    ),
                  ),
                if (booking.status == BookingStatus.pending)
                  const SizedBox(width: AppSpacing.stackSm),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isBusy ? null : () => _showAssignTableDialog(repo),
                    child: const Text('Assign Table'),
                  ),
                ),
                IconButton(
                  onPressed: _isBusy
                      ? null
                      : () => _run(() => repo.cancelBooking(booking.id)),
                  icon: const Icon(Icons.close, color: AppColors.error),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final BookingStatus status;

  Color get _color {
    switch (status) {
      case BookingStatus.pending:
        return AppColors.warning;
      case BookingStatus.confirmed:
        return AppColors.success;
      case BookingStatus.cancelled:
        return AppColors.error;
      case BookingStatus.completed:
        return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: _color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull)),
      child: Text(status.label,
          style: AppTextStyles.labelCaps.copyWith(color: _color)),
    );
  }
}
