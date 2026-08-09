import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/booking_model.dart';
import '../data/models/time_slot_model.dart';
import '../data/repositories/bookings_repository.dart';

final bookingsRepositoryProvider = Provider<BookingsRepository>((ref) {
  return BookingsRepository(Supabase.instance.client);
});

/// Family key for [timeSlotsProvider]. A plain (shopId, DateTime) tuple
/// isn't safely hashable for Riverpod family caching once you factor in
/// time-of-day noise on the DateTime, so this normalizes to just the
/// calendar day and implements ==/hashCode explicitly.
class TimeSlotsQuery {
  TimeSlotsQuery({required this.shopId, required DateTime date})
      : date = DateTime(date.year, date.month, date.day);

  final String shopId;
  final DateTime date;

  @override
  bool operator ==(Object other) =>
      other is TimeSlotsQuery && other.shopId == shopId && other.date == date;

  @override
  int get hashCode => Object.hash(shopId, date);
}

/// One fetch per (shop, day). autoDispose so switching days doesn't
/// leak a growing cache of every day ever tapped during the session.
final timeSlotsProvider = FutureProvider.autoDispose
    .family<List<TimeSlotModel>, TimeSlotsQuery>((ref, query) async {
  final repo = ref.watch(bookingsRepositoryProvider);
  return repo.fetchTimeSlotsForDate(shopId: query.shopId, date: query.date);
});

/// Single booking fetch, used by BookingConfirmationScreen. autoDispose
/// + family per bookingId, same reasoning as shopDetailProvider.
final bookingDetailProvider = FutureProvider.autoDispose
    .family<BookingModel, String>((ref, bookingId) async {
  final repo = ref.watch(bookingsRepositoryProvider);
  return repo.fetchBookingById(bookingId);
});
final customerBookingsProvider =
    FutureProvider<List<BookingModel>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;

  if (user == null) {
    return [];
  }

  final repo = ref.watch(bookingsRepositoryProvider);

  return repo.fetchBookingsForCustomer(user.id);
});

/// Owner Slot Management (Phase F): every upcoming slot for the
/// owner's shop. autoDispose + family per shopId, same reasoning as
/// timeSlotsProvider — invalidated after create/edit/delete rather
/// than kept as a live stream.
final ownerUpcomingSlotsProvider = FutureProvider.autoDispose
    .family<List<TimeSlotModel>, String>((ref, shopId) async {
  final repo = ref.watch(bookingsRepositoryProvider);
  return repo.fetchUpcomingSlotsForShop(shopId);
});
