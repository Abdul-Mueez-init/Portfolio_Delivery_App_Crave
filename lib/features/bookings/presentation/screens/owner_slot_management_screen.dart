import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../shops/application/owner_shop_provider.dart';
import '../../application/time_slots_provider.dart';
import '../../data/models/time_slot_model.dart';
import 'time_slot_form_screen.dart';

/// Owner Slot Management (Phase F, SESSION_HANDOFF_phaseAH_fixes.md).
/// Reachable from the Dashboard's Quick Actions rather than the 4-tab
/// bottom nav (owner_bottom_nav.dart is already full at 4 — Dashboard/
/// Orders/Calendar/Menu — per architecture.md §3), matching how
/// Shop Settings is also reached from Dashboard rather than the nav bar.
/// No bottom nav bar here — this is a pushed sub-screen, same pattern
/// as shop_settings_screen.dart, not a shell tab.
///
/// This is now the real, ongoing source of bookable time_slots — before
/// this screen existed, seed.sql's one-time "today/tomorrow/+2 days"
/// block was the *only* way slots ever got created, which goes stale
/// the moment that window passes and is itself a violation of
/// architecture.md §10 ("seed data must never be the only path to real
/// data"). seed.sql's time_slots block becomes optional/demo-only now.
class OwnerSlotManagementScreen extends ConsumerWidget {
  const OwnerSlotManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(myShopProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Manage Time Slots',
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
          return _SlotBody(shopId: shop.id);
        },
      ),
      floatingActionButton: shopAsync.maybeWhen(
        data: (shop) => shop == null
            ? null
            : FloatingActionButton(
                backgroundColor: AppColors.primaryContainer,
                onPressed: () async {
                  await context.push(AppRoutes.ownerSlotForm,
                      extra: TimeSlotFormArgs(shopId: shop.id));
                  ref.invalidate(ownerUpcomingSlotsProvider(shop.id));
                },
                child:
                    const Icon(Icons.add, color: AppColors.onPrimaryContainer),
              ),
        orElse: () => null,
      ),
    );
  }
}

class _SlotBody extends ConsumerWidget {
  const _SlotBody({required this.shopId});
  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(ownerUpcomingSlotsProvider(shopId));

    return slotsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, s) => ErrorView(
        message: "We couldn't load your time slots.",
        onRetry: () => ref.invalidate(ownerUpcomingSlotsProvider(shopId)),
      ),
      data: (slots) {
        if (slots.isEmpty) {
          return const EmptyState(
            icon: Icons.event_available_outlined,
            title: 'No upcoming slots',
            message: 'Tap + to open the booking calendar for a time.',
          );
        }

        // Group by calendar day so the owner isn't scanning one long
        // flat list — same grouping idea as booking_calendar_screen.dart.
        final Map<DateTime, List<TimeSlotModel>> byDay = {};
        for (final slot in slots) {
          final day = DateTime(
              slot.slotTime.year, slot.slotTime.month, slot.slotTime.day);
          byDay.putIfAbsent(day, () => []).add(slot);
        }
        final days = byDay.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(AppSpacing.marginMain,
              AppSpacing.stackMd, AppSpacing.marginMain, 96),
          itemCount: days.length,
          itemBuilder: (context, i) {
            final day = days[i];
            final daySlots = byDay[day]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                      top: AppSpacing.stackMd, bottom: AppSpacing.stackSm),
                  child: Text(_formatDayHeader(day),
                      style: AppTextStyles.labelCaps),
                ),
                for (final slot in daySlots)
                  _SlotRow(slot: slot, shopId: shopId),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDayHeader(DateTime day) {
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    if (day == todayDay) return 'TODAY';
    if (day == todayDay.add(const Duration(days: 1))) return 'TOMORROW';
    const weekdays = [
      'MONDAY',
      'TUESDAY',
      'WEDNESDAY',
      'THURSDAY',
      'FRIDAY',
      'SATURDAY',
      'SUNDAY'
    ];
    return '${weekdays[day.weekday - 1]}, ${day.month}/${day.day}';
  }
}

class _SlotRow extends ConsumerStatefulWidget {
  const _SlotRow({required this.slot, required this.shopId});
  final TimeSlotModel slot;
  final String shopId;

  @override
  ConsumerState<_SlotRow> createState() => _SlotRowState();
}

class _SlotRowState extends ConsumerState<_SlotRow> {
  bool _isBusy = false;

  Future<void> _delete() async {
    final slot = widget.slot;
    if (slot.bookedCapacity > 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Can't delete — this slot has active bookings against it.")));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove slot?'),
        content: const Text('This time slot will no longer be bookable.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBusy = true);
    try {
      await ref.read(bookingsRepositoryProvider).deleteTimeSlot(slot.id);
      ref.invalidate(ownerUpcomingSlotsProvider(widget.shopId));
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

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final hour = slot.slotTime.hour % 12 == 0 ? 12 : slot.slotTime.hour % 12;
    final minute = slot.slotTime.minute.toString().padLeft(2, '0');
    final period = slot.slotTime.hour >= 12 ? 'PM' : 'AM';
    final isFull = slot.remainingCapacity <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.stackSm),
      padding: const EdgeInsets.all(AppSpacing.stackMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text('$hour:$minute $period',
                style:
                    AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: AppSpacing.stackMd),
          Expanded(
            child: Text(
              '${slot.bookedCapacity} / ${slot.maxPartyCapacity} booked',
              style: AppTextStyles.bodyLg.copyWith(
                color: isFull ? AppColors.error : AppColors.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: _isBusy
                ? null
                : () async {
                    await context.push(AppRoutes.ownerSlotForm,
                        extra: TimeSlotFormArgs(
                            shopId: widget.shopId, slot: slot));
                    ref.invalidate(ownerUpcomingSlotsProvider(widget.shopId));
                  },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 20, color: AppColors.error),
            onPressed: _isBusy ? null : _delete,
          ),
        ],
      ),
    );
  }
}
