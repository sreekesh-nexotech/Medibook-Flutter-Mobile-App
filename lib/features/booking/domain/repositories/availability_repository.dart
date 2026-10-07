import '../../../../core/storage/cache/cached_result.dart';
import '../entities/availability.dart';
import '../entities/slots.dart';

/// Availability and slots (§8.1, §8.2). Both are public, cached GETs; slot
/// data is cached server-side for up to 30 seconds, so a booking must always
/// be ready for `409 SLOT_UNAVAILABLE` and reload through [invalidateSlots].
abstract interface class AvailabilityRepository {
  /// `GET /patient/doctors/{id}/availability` (§8.1). [from] / [to] are
  /// hospital-local `YYYY-MM-DD`; omitted → today to the booking window.
  Stream<CachedResult<DoctorAvailability>> availability(
    String doctorId, {
    String? from,
    String? to,
    bool forceRefresh = false,
  });

  /// `GET /patient/doctors/{id}/slots?date=` (§8.2).
  Stream<CachedResult<DaySlots>> slots(
    String doctorId, {
    required String date,
    bool forceRefresh = false,
  });

  /// Drop cached slot/availability data after a `SLOT_UNAVAILABLE` so the
  /// next read is fresh.
  Future<void> invalidateSlots();
}
