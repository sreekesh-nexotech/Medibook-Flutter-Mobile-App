import '../entities/location_scope.dart';

/// Where the chosen browse location is kept: the `settings` box, so it
/// survives a relaunch (CL DISC-001). A city is a per-device preference,
/// like the onboarding flags beside it.
abstract interface class LocationScopeStore {
  LocationScope? read();

  Future<void> write(LocationScope scope);

  Future<void> clear();
}
