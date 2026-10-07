import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../logger.dart';

/// An approximate position, sent to the backend as `lat` / `lng`.
///
/// Rounded to two decimals (about 1 km): enough for the server to sort
/// hospitals by distance, without sending where exactly the patient is.
class Coordinates {
  Coordinates(double lat, double lng) : lat = _round(lat), lng = _round(lng);

  final double lat;
  final double lng;

  static double _round(double value) => (value * 100).roundToDouble() / 100;

  /// As the query string wants them (`9.93`, `76.27`).
  String get latText => lat.toStringAsFixed(2);
  String get lngText => lng.toStringAsFixed(2);

  @override
  bool operator ==(Object other) =>
      other is Coordinates && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// Why there is no position.
enum LocationUnavailable {
  /// Location is switched off on the phone.
  serviceOff,

  /// The patient said no; asking again shows the system prompt.
  denied,

  /// The patient said "don't ask again": only the app settings can change it.
  deniedForever,

  /// Allowed, but no fix came in time.
  noFix,
}

/// A position, or why there is none.
class LocationResult {
  const LocationResult.found(Coordinates this.coordinates) : unavailable = null;
  const LocationResult.unavailable(LocationUnavailable this.unavailable)
    : coordinates = null;

  final Coordinates? coordinates;
  final LocationUnavailable? unavailable;
}

/// Reads the phone's approximate position (CL DISC-015). The distance
/// itself is worked out by the backend from the coordinates.
abstract interface class DeviceLocator {
  /// Asks for permission when it has not been decided yet.
  Future<LocationResult> current();

  /// Opens the app's system settings (after "don't ask again").
  Future<void> openSettings();
}

class GeolocatorDeviceLocator implements DeviceLocator {
  const GeolocatorDeviceLocator();

  /// A fix this recent is reused rather than waiting for a new one.
  static const Duration _freshEnough = Duration(minutes: 30);

  @override
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.unavailable(LocationUnavailable.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.denied:
          return const LocationResult.unavailable(LocationUnavailable.denied);
        case LocationPermission.deniedForever:
          return const LocationResult.unavailable(
            LocationUnavailable.deniedForever,
          );
        case LocationPermission.whileInUse:
        case LocationPermission.always:
        case LocationPermission.unableToDetermine:
          break;
      }
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          DateTime.now().difference(last.timestamp) < _freshEnough) {
        return LocationResult.found(Coordinates(last.latitude, last.longitude));
      }
      final position = await _fix();
      return LocationResult.found(
        Coordinates(position.latitude, position.longitude),
      );
    } catch (error) {
      AppLogger.warning(
        'No location fix; hospitals fall back to name order',
        name: 'location',
        error: error,
      );
      return const LocationResult.unavailable(LocationUnavailable.noFix);
    }
  }

  /// A low-power fix (Wi-Fi / mobile network) first; when none comes in
  /// time, one GPS attempt. Low power never turns GPS on, so where network
  /// location is unavailable (weak signal indoors, or an emulator) it timed
  /// out every time and Home showed "We could not find your location".
  static Future<Position> _fix() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on TimeoutException {
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    }
  }

  @override
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
  }
}

final deviceLocatorProvider = Provider<DeviceLocator>(
  (ref) => const GeolocatorDeviceLocator(),
);

/// The phone's approximate position for this session. Not autoDispose: one
/// prompt and one fix per launch; invalidate it to ask again.
final deviceLocationProvider = FutureProvider<LocationResult>(
  (ref) => ref.watch(deviceLocatorProvider).current(),
);
