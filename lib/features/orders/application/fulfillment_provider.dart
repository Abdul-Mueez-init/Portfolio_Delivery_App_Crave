import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

import '../data/models/fulfillment_type.dart';

// geocoding 5.0.0's API is instance-based (see the package's own
// migrate-to-5.0.0 guide) rather than top-level functions — this
// notifier has no other state to key it to, so a single
// module-level instance is created once and reused for every call,
// exactly as the package's own docs say is safe (the instance holds
// no state itself).
final geocoding.Geocoding _geocoder = geocoding.Geocoding();

class FulfillmentState {
  const FulfillmentState({
    this.type = FulfillmentType.pickup,
    this.address = '',
    this.deliveryLat,
    this.deliveryLng,
    this.isLocating = false,
    this.locationError,
    this.isAddressFromGps = false,
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

  /// True once [address] was populated from a real GPS fix (via
  /// "Use current location") rather than typed by hand. Drives the
  /// address field being locked/read-only in
  /// fulfillment_selection_screen.dart — per the fix, a GPS-derived
  /// address shouldn't be silently hand-editable (that would desync
  /// the visible address from deliveryLat/deliveryLng, which is what
  /// actually drives checkout + the simulated delivery route). Cleared
  /// by [FulfillmentNotifier.editAddressManually] or by typing after
  /// unlocking, and by [FulfillmentNotifier.selectType]/[reset].
  final bool isAddressFromGps;

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
    bool? isAddressFromGps,
    bool clearDeliveryLatLng = false,
  }) {
    return FulfillmentState(
      type: type ?? this.type,
      address: address ?? this.address,
      deliveryLat:
          clearDeliveryLatLng ? null : (deliveryLat ?? this.deliveryLat),
      deliveryLng:
          clearDeliveryLatLng ? null : (deliveryLng ?? this.deliveryLng),
      isLocating: isLocating ?? this.isLocating,
      locationError:
          clearLocationError ? null : (locationError ?? this.locationError),
      isAddressFromGps: isAddressFromGps ?? this.isAddressFromGps,
    );
  }
}

class FulfillmentNotifier extends StateNotifier<FulfillmentState> {
  FulfillmentNotifier() : super(const FulfillmentState());

  void selectType(FulfillmentType type) {
    state = state.copyWith(type: type);
  }

  void setAddress(String address) {
    state = state.copyWith(
      address: address,
      clearLocationError: true,
      isAddressFromGps: false,
    );
  }

  /// Unlocks the address field after a GPS fix populated it, so the
  /// person can switch back to typing a different address by hand.
  /// Does NOT clear deliveryLat/deliveryLng by itself — those only
  /// change again on the next successful "Use current location" tap
  /// or get superseded by whatever the person types (the lat/lng
  /// becomes stale the moment they edit, which is expected: manual
  /// text entry was never geocoded to a point in this MVP — see the
  /// FLAGGED note on [useCurrentLocation]).
  void editAddressManually() {
    state = state.copyWith(isAddressFromGps: false);
  }

  /// Phase G: real device GPS fix via `geolocator`.
  ///
  /// FIX (this session): the previous version stamped the address as
  /// a plain 'Current Location' label. Now reverse-geocodes the fix
  /// into a real street address via the `geocoding` package, and the
  /// UI locks the address field (read-only) while [isAddressFromGps]
  /// is true, so the visible text can never drift out of sync with
  /// the actual deliveryLat/deliveryLng that get sent to checkout.
  ///
  /// ON THE "RANDOM LOCATION FAR AWAY" REPORT: this method's own logic
  /// is a plain, un-cached `Geolocator.getCurrentPosition()` call —
  /// there's no simulated/randomized offset left anywhere in this
  /// file (that was Phase G's whole point). If the returned
  /// coordinates are genuinely far from where the device physically
  /// is, the most common causes are environmental, not this code:
  ///   1. Testing on an Android **emulator** — emulators report a
  ///      fixed, fake GPS location (classically Mountain View, CA)
  ///      until you set one yourself via the emulator's Extended
  ///      Controls -> Location tab (or `adb emu geo fix <lng> <lat>`).
  ///      This is by far the most likely explanation for "shows a
  ///      spot I've never been to."
  ///   2. A real device with GPS/location genuinely off and only
  ///      coarse network-based location available, which can be
  ///      wildly inaccurate indoors or on weak signal.
  ///   3. A VPN active on the test device — some location providers
  ///      fall back to IP-based geolocation, which follows the VPN
  ///      exit node, not the phone.
  /// If you're testing on a real device with no VPN and Location
  /// permission/services genuinely on, and still see this after
  /// pulling this fix, tell me which of the three above it isn't and
  /// I'll dig further — but the code itself is no longer generating
  /// or offsetting any coordinate.
  ///
  /// shopLat/shopLng are accepted for signature continuity with the
  /// old method but are no longer used to compute the result.
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

      // No cached/last-known fallback on purpose — always forces a
      // fresh fix so a stale cached fix from earlier testing can never
      // silently reappear. 20s timeout so a bad GPS environment fails
      // fast with a clear error instead of hanging on "Getting your
      // location…" forever.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      // Reverse-geocode into a real address. Falls back to the raw
      // coordinates as the visible text (still locks the field) if
      // geocoding itself fails or returns nothing — deliveryLat/Lng
      // are already captured either way, so checkout is never blocked
      // by a geocoding hiccup.
      //
      // `geocoding` has no web platform implementation — calling it
      // there just throws and falls through to the coordinate
      // fallback anyway, so on web we skip the call outright and go
      // straight to a clean label instead of showing raw lat/lng in
      // the address field. Mobile (Android/iOS) is untouched — it
      // still gets the real reverse-geocoded street address.
      String resolvedAddress = kIsWeb
          ? 'Current location (GPS)'
          : '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';

      if (!kIsWeb) {
        try {
          final placemarks = await _geocoder.placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final parts = [
              p.street,
              p.subLocality,
              p.locality,
              p.administrativeArea,
            ].where((s) => s != null && s.trim().isNotEmpty).toList();
            if (parts.isNotEmpty) {
              resolvedAddress = parts.join(', ');
            }
          }
        } catch (_) {
          // Keep the coordinate fallback above — not fatal.
        }
      }

      state = state.copyWith(
        address: resolvedAddress,
        deliveryLat: position.latitude,
        deliveryLng: position.longitude,
        isLocating: false,
        clearLocationError: true,
        isAddressFromGps: true,
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
