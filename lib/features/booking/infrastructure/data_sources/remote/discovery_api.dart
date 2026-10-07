import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/endpoints.dart';
import '../../../domain/repositories/discovery_repository.dart';

/// The public discovery and availability endpoints (§7, §8.1, §8.2) as typed
/// [ApiRequest] builders.
///
/// These are all cacheable GETs, so the repository hands each request to
/// `CachedFetcher` rather than calling the client itself; this class only
/// knows *which path and which query*. It never reads state, never decodes
/// and never caches. Every request is `requiresAuth: false` — sending an
/// expired token to a public endpoint is a 401 (§1.4).
abstract final class DiscoveryApi {
  DiscoveryApi._();

  /// Every area in one answer (the server's largest page): "Choose a
  /// location" groups and counts them all, and on the default page of 25 an
  /// area past the 25th went missing.
  static const int locationsPageSize = 100;

  static ApiRequest locations({String? city, bool? popular}) => ApiRequest(
    path: Endpoints.locations,
    query: {
      'city': city,
      'popular': popular,
      ...Endpoints.page(1, size: locationsPageSize),
    },
    requiresAuth: false,
  );

  static ApiRequest hospitals(HospitalsQuery q) => ApiRequest(
    path: Endpoints.hospitals,
    query: {
      'city': q.city,
      'area': q.area,
      'department_code': q.departmentCode,
      'q': q.q,
      'lat': q.lat,
      'lng': q.lng,
      'radius_km': q.hasCoordinates ? q.radiusKm : null,
      // `distance_km` is only sortable with coordinates (§7.2).
      'sort': q.sort == HospitalSort.distance && !q.hasCoordinates
          ? null
          : q.sort?.wire,
      ...Endpoints.page(q.page, size: q.pageSize),
    },
    requiresAuth: false,
  );

  static ApiRequest hospital(String id) =>
      ApiRequest(path: Endpoints.hospital(id), requiresAuth: false);

  static ApiRequest hospitalBanners(String id) =>
      ApiRequest(path: Endpoints.hospitalBanners(id), requiresAuth: false);

  static ApiRequest departments() => const ApiRequest(
    path: Endpoints.departments,
    query: {'sort': 'name', 'page_size': 100},
    requiresAuth: false,
  );

  static ApiRequest hospitalDepartments(String id) => ApiRequest(
    path: Endpoints.hospitalDepartments(id),
    query: const {'sort': 'sort_order', 'page_size': 100},
    requiresAuth: false,
  );

  static ApiRequest hospitalDoctors(HospitalDoctorsQuery q) => ApiRequest(
    path: Endpoints.hospitalDoctors(q.hospitalId),
    query: {
      'department_code': q.departmentCode,
      'department_id': q.departmentId,
      'q': q.q,
      'sort': q.sort,
      ...Endpoints.page(q.page, size: q.pageSize),
    },
    requiresAuth: false,
  );

  static ApiRequest doctor(String id) =>
      ApiRequest(path: Endpoints.doctor(id), requiresAuth: false);

  static ApiRequest availability(String doctorId, {String? from, String? to}) =>
      ApiRequest(
        path: Endpoints.doctorAvailability(doctorId),
        query: {'from': from, 'to': to},
        requiresAuth: false,
      );

  static ApiRequest slots(String doctorId, {required String date}) =>
      ApiRequest(
        path: Endpoints.doctorSlots(doctorId),
        query: {'date': date},
        requiresAuth: false,
      );
}
