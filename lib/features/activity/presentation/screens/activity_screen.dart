import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/customer_bottom_nav.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/router/app_router.dart';
import '../../../bookings/application/time_slots_provider.dart';
import '../../../bookings/data/models/booking_model.dart';
import '../../../orders/application/orders_provider.dart';
import '../../../orders/data/models/order_model.dart';

const List<String> _monthAbbrev = [
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

/// Matches activity_updated/code.html: a two-tab (Orders | Bookings)
/// list, each row a status-badged card. Tapping a row opens the same
/// Order Tracking / Booking Confirmation screen used right after
/// checkout/booking — design.md screen 14 is explicit cancellation
/// should live in one place, not be duplicated here.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            const SizedBox(height: AppSpacing.stackSm),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryContainer,
              unselectedLabelColor: AppColors.secondary,
              indicatorColor: AppColors.primaryContainer,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: AppTextStyles.headlineMd,
              unselectedLabelStyle: AppTextStyles.headlineMd,
              tabs: const [Tab(text: 'Orders'), Tab(text: 'Bookings')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [_OrdersTab(), _BookingsTab()],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomerBottomNav(currentIndex: 1),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.marginMain,
        vertical: AppSpacing.stackSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 40),
          Text('Activity',
              style: AppTextStyles.headlineLgMobile
                  .copyWith(color: AppColors.onSurface)),
          GestureDetector(
            onTap: () => context.push(AppRoutes.profile),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  color: AppColors.surfaceVariant, shape: BoxShape.circle),
              child: const Icon(Icons.person_outline,
                  color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(customerOrdersProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(customerOrdersProvider),
      child: ordersAsync.when(
        loading: () => const SkeletonLoader.list(),
        error: (error, stack) => ErrorView(
          message: "We couldn't load your orders right now. Please try again.",
          onRetry: () => ref.invalidate(customerOrdersProvider),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return ListView(
              // ListView (not a bare Center) so pull-to-refresh still
              // works on an empty list.
              children: const [
                SizedBox(height: 80),
                EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'No orders yet',
                  message: 'Your placed orders will show up here.',
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.marginMain),
            itemCount: orders.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.stackMd),
            itemBuilder: (context, index) => _OrderCard(order: orders[index]),
          );
        },
      ),
    );
  }
}

class _BookingsTab extends ConsumerWidget {
  const _BookingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(customerBookingsProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.invalidate(customerBookingsProvider),
      child: bookingsAsync.when(
        loading: () => const SkeletonLoader.list(),
        error: (error, stack) => ErrorView(
          message:
              "We couldn't load your bookings right now. Please try again.",
          onRetry: () => ref.invalidate(customerBookingsProvider),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                EmptyState(
                  icon: Icons.event_seat_rounded,
                  title: 'No bookings yet',
                  message: 'Reserve a table from any shop to see it here.',
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.marginMain),
            itemCount: bookings.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.stackMd),
            itemBuilder: (context, index) =>
                _BookingCard(booking: bookings[index]),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final statusColor = _orderStatusColor(order.status);
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        // Order Tracking screen doesn't exist yet (Phase 5 gap — see
        // orders_repository.dart) — this is the one wire-up that has
        // to wait for that to land. Everything else on this card is
        // already real.
        onTap: () => context.push('${AppRoutes.orderTracking}/${order.id}'),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.stackMd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.shopName ?? 'Shop',
                      style: AppTextStyles.headlineMd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusPill(label: order.status.label, color: statusColor),
                ],
              ),
              const SizedBox(height: 4),
              Text(_formatDateTime(order.createdAt),
                  style: AppTextStyles.bodySm),
              const Divider(height: AppSpacing.stackLg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_outlined,
                          size: 16, color: AppColors.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
                        style: AppTextStyles.bodySm,
                      ),
                    ],
                  ),
                  Text(
                    '\$${order.total.toStringAsFixed(2)}',
                    style: AppTextStyles.headlineMd,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});
  final BookingModel booking;

  @override
  Widget build(BuildContext context) {
    final statusColor = _bookingStatusColor(booking.status);
    final slotTime = booking.slotTime;
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        onTap: () =>
            context.push('${AppRoutes.bookingConfirmation}/${booking.id}'),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.stackMd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.outlineVariant),
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
                  _StatusPill(label: booking.status.label, color: statusColor),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                slotTime != null ? _formatDateTime(slotTime) : '—',
                style: AppTextStyles.bodySm,
              ),
              const Divider(height: AppSpacing.stackLg),
              Row(
                children: [
                  const Icon(Icons.people_alt_outlined,
                      size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('${booking.partySize} people',
                      style: AppTextStyles.bodySm),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(label, style: AppTextStyles.labelCaps.copyWith(color: color)),
    );
  }
}

String _formatDateTime(DateTime dt) {
  final month = _monthAbbrev[dt.month - 1];
  final hour24 = dt.hour;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$month ${dt.day} • $hour12:$minute $period';
}

Color _orderStatusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.completed:
      return AppColors.success;
    case OrderStatus.cancelled:
      return AppColors.error;
    case OrderStatus.placed:
      return AppColors.warning;
    default:
      return AppColors.primary;
  }
}

Color _bookingStatusColor(BookingStatus status) {
  switch (status) {
    case BookingStatus.confirmed:
    case BookingStatus.completed:
      return AppColors.success;
    case BookingStatus.cancelled:
      return AppColors.error;
    case BookingStatus.pending:
      return AppColors.warning;
  }
}
