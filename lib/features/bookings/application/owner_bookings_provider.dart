import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/booking_model.dart';
import 'time_slots_provider.dart';

/// Family key for [shopBookingsProvider] — same day-normalization
/// pattern as TimeSlotsQuery (time_slots_provider.dart): a raw
/// (shopId, DateTime) tuple isn't safely hashable once time-of-day
/// noise is in play, so this strips it and implements ==/hashCode
/// explicitly.
class ShopBookingsQuery {
  ShopBookingsQuery({required this.shopId, required DateTime date})
      : date = DateTime(date.year, date.month, date.day);

  final String shopId;
  final DateTime date;

  @override
  bool operator ==(Object other) =>
      other is ShopBookingsQuery &&
      other.shopId == shopId &&
      other.date == date;

  @override
  int get hashCode => Object.hash(shopId, date);
}

/// Owner-side: bookings for one shop on one day — Booking Calendar
/// (design.md screen 18). One-shot fetch per (shop, day), same as
/// customer-side timeSlotsProvider — not Realtime, since the Booking
/// Calendar's own confirm/cancel/assign-table actions already re-fetch
/// after each mutation (see BookingCalendarScreen, next batch).
/// autoDispose so switching days doesn't leak a growing cache.
final shopBookingsProvider = FutureProvider.autoDispose
    .family<List<BookingModel>, ShopBookingsQuery>((ref, query) async {
  final repo = ref.watch(bookingsRepositoryProvider);
  return repo.fetchShopBookings(shopId: query.shopId, date: query.date);
});
