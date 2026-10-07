import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/storage/cache/cached_fetcher.dart';
import '../../domain/entities/availability.dart';
import '../../domain/entities/department.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/hospital.dart';
import '../../domain/entities/location.dart';
import '../../domain/entities/promo_banner.dart';
import '../../domain/entities/slots.dart';
import '../../domain/repositories/availability_repository.dart';
import '../../domain/repositories/discovery_repository.dart';
import '../data_sources/remote/discovery_api.dart';
import 'booking_mappers.dart';

/// [DiscoveryRepository] and [AvailabilityRepository] over the three-layer
/// [CachedFetcher].
///
/// Every read is `fetcher.fetch(request, decode)`: memory → Hive → network,
/// with the ETag revalidation, offline and stale behaviour the HIVE spec
/// fixes. The `decode` callback is the mapper, so a malformed body throws
/// before it is cached (Scenario 10). Any error that escapes the fetcher is
/// converted here to a [Failure] — nothing above sees a `NetworkException`.
class DiscoveryRepositoryImpl
    implements DiscoveryRepository, AvailabilityRepository {
  const DiscoveryRepositoryImpl({required CachedFetcher fetcher})
    : _fetcher = fetcher;

  final CachedFetcher _fetcher;

  Stream<CachedResult<T>> _read<T>(
    ApiRequest request,
    T Function(Map<String, Object?> json) decode, {
    required bool forceRefresh,
  }) => _fetcher
      .fetch<T>(
        request,
        (json) => decode(BookingMappers.obj(json, request.path)),
        forceRefresh: forceRefresh,
      )
      .handleError(
        (Object error, StackTrace stack) => Error.throwWithStackTrace(
          NetworkExceptions.toFailure(error, stack),
          stack,
        ),
      );

  Stream<CachedResult<Page<T>>> _page<T>(
    ApiRequest request,
    T Function(Map<String, Object?> json) row, {
    required bool forceRefresh,
  }) => _fetcher
      .fetch<Page<T>>(
        request,
        (json) => Page.parse(json, row),
        forceRefresh: forceRefresh,
      )
      .handleError(
        (Object error, StackTrace stack) => Error.throwWithStackTrace(
          NetworkExceptions.toFailure(error, stack),
          stack,
        ),
      );

  // ---- Discovery (§7) ----

  @override
  Stream<CachedResult<Page<Location>>> locations({
    String? city,
    bool? popular,
    bool forceRefresh = false,
  }) => _page(
    DiscoveryApi.locations(city: city, popular: popular),
    BookingMappers.location,
    forceRefresh: forceRefresh,
  );

  @override
  Stream<CachedResult<Page<HospitalCard>>> hospitals(
    HospitalsQuery query, {
    bool forceRefresh = false,
  }) => _page(
    DiscoveryApi.hospitals(query),
    BookingMappers.hospitalCard,
    forceRefresh: forceRefresh,
  );

  @override
  Stream<CachedResult<HospitalDetail>> hospital(
    String hospitalId, {
    bool forceRefresh = false,
  }) => _read(
    DiscoveryApi.hospital(hospitalId),
    BookingMappers.hospitalDetail,
    forceRefresh: forceRefresh,
  );

  @override
  Stream<CachedResult<Page<HospitalBanner>>> hospitalBanners(
    String hospitalId, {
    bool forceRefresh = false,
  }) => _page(
    DiscoveryApi.hospitalBanners(hospitalId),
    (json) => BookingMappers.banner(json, hospitalId: hospitalId),
    forceRefresh: forceRefresh,
  );

  @override
  Stream<CachedResult<Page<DepartmentSummary>>> departments({
    bool forceRefresh = false,
  }) => _page(
    DiscoveryApi.departments(),
    BookingMappers.departmentSummary,
    forceRefresh: forceRefresh,
  );

  @override
  Stream<CachedResult<Page<HospitalDepartment>>> hospitalDepartments(
    String hospitalId, {
    bool forceRefresh = false,
  }) => _page(
    DiscoveryApi.hospitalDepartments(hospitalId),
    BookingMappers.hospitalDepartment,
    forceRefresh: forceRefresh,
  );

  @override
  Stream<CachedResult<Page<DoctorCard>>> hospitalDoctors(
    HospitalDoctorsQuery query, {
    bool forceRefresh = false,
  }) => _page(
    DiscoveryApi.hospitalDoctors(query),
    BookingMappers.doctorCard,
    forceRefresh: forceRefresh,
  );

  @override
  Stream<CachedResult<DoctorDetail>> doctor(
    String doctorId, {
    bool forceRefresh = false,
  }) => _read(
    DiscoveryApi.doctor(doctorId),
    BookingMappers.doctorDetail,
    forceRefresh: forceRefresh,
  );

  // ---- Availability (§8.1, §8.2) ----

  @override
  Stream<CachedResult<DoctorAvailability>> availability(
    String doctorId, {
    String? from,
    String? to,
    bool forceRefresh = false,
  }) => _read(
    DiscoveryApi.availability(doctorId, from: from, to: to),
    BookingMappers.availability,
    forceRefresh: forceRefresh,
  );

  @override
  Stream<CachedResult<DaySlots>> slots(
    String doctorId, {
    required String date,
    bool forceRefresh = false,
  }) => _read(
    DiscoveryApi.slots(doctorId, date: date),
    BookingMappers.daySlots,
    forceRefresh: forceRefresh,
  );

  @override
  Future<void> invalidateSlots() async {
    try {
      await _fetcher.invalidate(pathPrefix: '/patient/doctors');
    } catch (error, stack) {
      throw NetworkExceptions.toFailure(error, stack);
    }
  }
}
