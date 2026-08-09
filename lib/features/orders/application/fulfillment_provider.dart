import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../data/models/fulfillment_type.dart';

class FulfillmentState {
  const FulfillmentState({
    this.type = FulfillmentType.pickup,
    this.address = '',
    this.deliveryLat,
    this.deliveryLng,
    this.isLocating = false,
    this.locationError,
  });

  final FulfillmentType type;
  final String address;
  final double? deliveryLat;
  final double? deliveryLng;

  /// True while a real GPS fix is in flight (Phase G) — drives the
  /// loading spinner on "Use current location" in
  /// fulfillment_selection_screen.dart.
  final bool isLocating;

  /// Set when the GPS fix fails (service disabled, permission denied,
  /// permission denied forever). Null when there's nothing to show.
  final String? locationError;

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
    bool? isLocating,
    String? locationError,
    bool clearLocationError = false,
  }) {
    return FulfillmentState(
      type: type ?? this.type,
      address: address ?? this.address,
      deliveryLat: deliveryLat ?? this.deliveryLat,
      deliveryLng: deliveryLng ?? this.deliveryLng,
      isLocating: isLocating ?? this.isLocating,
      locationError:
          clearLocationError ? null : (locationError ?? this.locationError),
    );
  }
}

class FulfillmentNotifier extends StateNotifier<FulfillmentState> {
  FulfillmentNotifier() : super(const FulfillmentState());

  void selectType(FulfillmentType type) {
    state = state.copyWith(type: type);
  }

  void setAddress(String address) {
    state = state.copyWith(address: address, clearLocationError: true);
  }

  /// Phase G: real device GPS fix via `geolocator`, replacing the
  /// random-offset simulation that used to live here. Renamed from
  /// useSimulatedCurrentLocation() -> useCurrentLocation() since the
  /// old name would now be actively misleading — flagged per
  /// SESSION_HANDOFF_phaseAH_fixes.md rule 4 rather than silently
  /// decided. The call site in fulfillment_selection_screen.dart is
  /// updated to match; the method's shape (shopLat/shopLng in, void
  /// out via state) is otherwise unchanged.
  ///
  /// FLAGGED ASSUMPTION: this sets `address` to a plain 'Current
  /// Location' label rather than a real street address. Reverse
  /// geocoding a lat/lng into a street address needs a geocoding
  /// package (e.g. `geocoding`), which is NOT one of this session's
  /// two pre-approved dependencies (geolocator, cached_network_image —
  /// see SESSION_HANDOFF_phaseAH_fixes.md rule 2). What actually
  /// matters functionally — `deliveryLat`/`deliveryLng`, which drive
  /// the simulated delivery route per architecture.md §5 — is now real
  /// GPS data. Swap in reverse geocoding later if you want a real
  /// address string too; that's a separate pubspec.yaml change worth
  /// its own sign-off.
  ///
  /// shopLat/shopLng are accepted for signature continuity with the
  /// old method but are no longer used to compute the result — kept so
  /// call sites don't need restructuring, and in case a future
  /// "distance from shop" sanity check wants them.
  Future<void> useCurrentLocation({
    required double shopLat,
    required double shopLng,
  }) async {
    state = state.copyWith(isLocating: true, clearLocationError: true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = state.copyWith(
          isLocating: false,
          locationError:
              'Location services are turned off. Enable them in your device settings.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = state.copyWith(
            isLocating: false,
            locationError: 'Location permission denied.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          isLocating: false,
          locationError:
              'Location permission is permanently denied. Enable it from app settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      state = state.copyWith(
        address: 'Current Location',
        deliveryLat: position.latitude,
        deliveryLng: position.longitude,
        isLocating: false,
        clearLocationError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLocating: false,
        locationError: "Couldn't get your location. Please try again.",
      );
    }
  }

  void reset() {
    state = const FulfillmentState();
  }
}

final fulfillmentProvider =
    StateNotifierProvider<FulfillmentNotifier, FulfillmentState>((ref) {
  return FulfillmentNotifier();
});
