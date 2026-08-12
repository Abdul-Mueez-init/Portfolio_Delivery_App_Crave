import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/time_slot_model.dart';
import 'time_slots_provider.dart';

/// Local, ephemeral state for the Booking screen — mirrors
/// FulfillmentState's pattern (fulfillment_provider.dart): plain
/// StateNotifier, reset when leaving the flow, nothing written to the
/// DB until [BookingFlowNotifier.confirmBooking] succeeds.
class BookingFlowState {
  const BookingFlowState({
    this.partySize = 2, // matches booking_screen_updated's default (2)
    DateTime? selectedDate,
    this.selectedTimeSlotId,
    this.isSubmitting = false,
    this.errorMessage,
  }) : _selectedDate = selectedDate;

  final int partySize;
  final DateTime? _selectedDate;
  final String? selectedTimeSlotId;
  final bool isSubmitting;
  final String? errorMessage;

  /// Defaults to today (calendar day, time-of-day stripped) so the
  /// first render always has a valid date without the widget needing
  /// to seed it.
  DateTime get selectedDate {
    final now = DateTime.now();
    return _selectedDate ?? DateTime(now.year, now.month, now.day);
  }

  bool get canConfirm => selectedTimeSlotId != null && !isSubmitting;

  BookingFlowState copyWith({
    int? partySize,
    DateTime? selectedDate,
    String? selectedTimeSlotId,
    bool clearSelectedTimeSlot = false,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BookingFlowState(
      partySize: partySize ?? this.partySize,
      selectedDate: selectedDate ?? _selectedDate,
      selectedTimeSlotId: clearSelectedTimeSlot
          ? null
          : (selectedTimeSlotId ?? this.selectedTimeSlotId),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class BookingFlowNotifier extends StateNotifier<BookingFlowState> {
  BookingFlowNotifier(this._ref) : super(const BookingFlowState());
  final Ref _ref;

  static const int _minPartySize = 1;

  void incrementPartySize() {
    state = state.copyWith(partySize: state.partySize + 1, clearError: true);
  }

  void decrementPartySize() {
    if (state.partySize <= _minPartySize) return;
    state = state.copyWith(partySize: state.partySize - 1, clearError: true);
  }

  /// Changing the date always clears the selected slot — a slot id
  /// from a different day is meaningless, and re-selecting nothing
  /// forces the person to actively pick a new time (no stale-looking
  /// selected pill on the wrong day).
  void selectDate(DateTime date) {
    state = state.copyWith(
      selectedDate: DateTime(date.year, date.month, date.day),
      clearSelectedTimeSlot: true,
      clearError: true,
    );
  }

  void selectTimeSlot(TimeSlotModel slot) {
    if (!slot.canFit(state.partySize)) return;
    state = state.copyWith(
      selectedTimeSlotId: slot.id,
      clearError: true,
    );
  }

  /// Calls the `book_time_slot` RPC (bookings_repository.dart) —
  /// capacity is re-checked atomically server-side even though the UI
  /// already greyed out full slots (rules.md §3: race conditions from
  /// two customers booking simultaneously are the whole reason this is
  /// an RPC and not a raw insert). Returns the new booking's id on
  /// success, or null on failure (with [BookingFlowState.errorMessage]
  /// set for the UI to show). No shopId param needed — the RPC derives
  /// the shop from the slot itself.
  Future<String?> confirmBooking() async {
    final slotId = state.selectedTimeSlotId;
    if (slotId == null) return null;

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final repo = _ref.read(bookingsRepositoryProvider);
      final booking = await repo.bookTimeSlot(
        timeSlotId: slotId,
        partySize: state.partySize,
      );
      state = state.copyWith(isSubmitting: false);
      return booking.id;
    } catch (e, st) {
      // Always logged, even though the user only ever sees the friendly
      // message below — this is what actually told us the previous
      // "Null check operator used on a null value" crash traced back to
      // the RPC's return shape, not the Dart booking code itself. Keep
      // this print (or route it to real crash reporting later per
      // PLAN.md Phase 10) so a fresh failure is diagnosable from a
      // device log instead of guessing again.
      debugPrint('BookingFlowNotifier.confirmBooking failed: $e\n$st');

      // The RPC raises a `SLOT_FULL: ...` message specifically when
      // someone else took the last seats first — the real concurrent-
      // booking race ERD.md §3 calls out. Surface that distinctly;
      // fall back to a generic message for anything else (network
      // blip, RLS issue, the RPC not existing/returning the wrong
      // shape — see BookingRpcException in bookings_repository.dart).
      final raw = e.toString();
      final message = raw.contains('SLOT_FULL')
          ? 'That slot just filled up. Please pick another time.'
          : "Couldn't complete the booking. Please try again.";
      state = state.copyWith(isSubmitting: false, errorMessage: message);
      return null;
    }
  }

  void reset() {
    state = const BookingFlowState();
  }
}

final bookingFlowProvider =
    StateNotifierProvider.autoDispose<BookingFlowNotifier, BookingFlowState>(
        (ref) {
  return BookingFlowNotifier(ref);
});
