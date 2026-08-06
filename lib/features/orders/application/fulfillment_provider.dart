import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/fulfillment_type.dart';

class FulfillmentState {
  const FulfillmentState({
    this.type = FulfillmentType.pickup,
    this.address = '',
    this.deliveryLat,
    this.deliveryLng,
  });

  final FulfillmentType type;
  final String address;
  final double? deliveryLat;
  final double? deliveryLng;

  /// Continue is only enabled once the requirements for the chosen
  /// fulfillment type are met — pickup needs nothing extra, delivery
  /// needs a non-empty address (rules.md §2: delivery_address required
  /// if fulfillment_type = 'delivery').
  bool get canContinue =>
      type == FulfillmentType.pickup || address.trim().isNotEmpty;

  FulfillmentState copyWith({
    FulfillmentType? type,
    String? address,
    double? deliveryLat,
    double? deliveryLng,
  }) {
    return FulfillmentState(
      type: type ?? this.type,
      address: address ?? this.address,
      deliveryLat: deliveryLat ?? this.deliveryLat,
      deliveryLng: deliveryLng ?? this.deliveryLng,
    );
  }
}

class FulfillmentNotifier extends StateNotifier<FulfillmentState> {
  FulfillmentNotifier() : super(const FulfillmentState());

  void selectType(FulfillmentType type) {
    state = state.copyWith(type: type);
  }

  void setAddress(String address) {
    state = state.copyWith(address: address);
  }

  /// FLAGGED ASSUMPTION: no geolocation package (e.g. geolocator) is in
  /// pubspec.yaml yet, so "Use current location" doesn't request a real
  /// device fix here — it randomizes a point within ~1-2km of the shop,
  /// same demo approach architecture.md §5 already uses for
  /// delivery_lat/lng. Swap this for real geolocation later if you add
  /// the geolocator dependency (that's a pubspec.yaml change worth
  /// doing deliberately, not slipped into this batch).
  void useSimulatedCurrentLocation({
    required double shopLat,
    required double shopLng,
  }) {
    final rand = Random();
    final latOffset = (rand.nextDouble() - 0.5) * 0.02; // ~±1km
    final lngOffset = (rand.nextDouble() - 0.5) * 0.02;
    state = state.copyWith(
      address: 'Current Location',
      deliveryLat: shopLat + latOffset,
      deliveryLng: shopLng + lngOffset,
    );
  }

  void reset() {
    state = const FulfillmentState();
  }
}

final fulfillmentProvider =
    StateNotifierProvider<FulfillmentNotifier, FulfillmentState>((ref) {
  return FulfillmentNotifier();
});
