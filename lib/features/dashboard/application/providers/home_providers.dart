import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/location/device_location.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/cache/cached_fetcher.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../booking/application/providers/discovery_providers.dart';
import '../../../booking/domain/entities/department.dart';
import '../../../booking/domain/entities/hospital.dart';
import '../../../booking/domain/entities/promo_banner.dart';
import '../../../booking/domain/repositories/discovery_repository.dart';
import '../../../booking/application/providers/location_scope_provider.dart';
import '../../../booking/domain/entities/location_scope.dart';

/// The first name for the Home greeting, from the signed-in user. Null when
/// signed out (the router never shows Home then, but the header must not
/// invent a name).
final homeGreetingNameProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  final first = user?.firstName.trim();
  return first == null || first.isEmpty ? null : first;
});

/// How many hospitals Home previews and how many hospitals' banners it
/// stitches into the promo strip.
abstract final class HomeLimits {
  HomeLimits._();

  static const int nearbyHospitals = 2;
  static const int bannerHospitals = 5;
}

/// The hospitals Home asks for, given the phone's position (CL DISC-015,
/// owner decision 6 Oct 2026): with coordinates the backend works out each
/// hospital's distance and returns them nearest first (`sort=distance_km`);
/// without them (location off or refused) it falls back to name order.
/// A saved browse location (CL DISC-001) narrows the list to that city and
/// area as well.
HospitalsQuery homeHospitalsQueryFor(Coordinates? at, [LocationScope? scope]) =>
    HospitalsQuery(
      city: scope?.city,
      area: (scope?.hasArea ?? false) ? scope!.area : null,
      sort: at == null ? HospitalSort.name : HospitalSort.distance,
      lat: at?.latText,
      lng: at?.lngText,
      pageSize: 25,
    );

/// The phone's position for Home, or null when there is none.
///
/// Not autoDispose, like [deviceLocationProvider] it reads. Disposable, it
/// was dropped while [homeHospitalsProvider] rebuilt for the position (an
/// `async*` body watches it only once its stream is listened to), came back
/// still loading, and the list rebuilt without it: an endless loop that kept
/// the list from ever settling, so the promo strip never appeared and the
/// list was never sorted by distance.
final homeCoordinatesProvider = FutureProvider<Coordinates?>(
  (ref) async => (await ref.watch(deviceLocationProvider.future)).coordinates,
);

/// `GET /patient/hospitals`, through the three-layer cache — nearest first
/// once the position is known, name order until then.
final homeHospitalsProvider =
    StreamProvider.autoDispose<CachedResult<Page<HospitalCard>>>((ref) async* {
      final scope = ref.watch(locationScopeProvider);
      // Not awaited: while the phone is still finding its position (up to
      // 10 s, or never) Home shows the list at once in name order; when the
      // position arrives this provider rebuilds and asks for distance order.
      // Rebuilds only when the coordinates themselves change, so "no
      // position" never restarts a request already in flight.
      final at = ref.watch(
        homeCoordinatesProvider.select((value) => value.valueOrNull),
      );
      yield* ref
          .watch(discoveryRepositoryProvider)
          .hospitals(homeHospitalsQueryFor(at, scope));
    });

/// The promo strip: the visible hospitals' banners, in hospital order then
/// `sort_order`. There is no platform-wide banner list (§18), so this is
/// one `GET …/banners` per previewed hospital, each cached.
final homeBannersProvider = FutureProvider.autoDispose<List<HospitalBanner>>((
  ref,
) async {
  final hospitals = await ref.watch(homeHospitalsProvider.future);
  final repository = ref.watch(discoveryRepositoryProvider);
  final banners = <HospitalBanner>[];
  for (final hospital in hospitals.value.results.take(
    HomeLimits.bannerHospitals,
  )) {
    try {
      final page = await repository.hospitalBanners(hospital.id).last;
      final rows = page.value.results.toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      banners.addAll(rows);
    } catch (_) {
      // One hospital's banners failing must not empty the strip.
    }
  }
  return banners;
});

/// One "Available Services" tile, derived from `GET /patient/departments`.
/// Its icon is chosen in presentation (`departmentIconFor`), so this layer
/// carries no UI (QA Prompt 1, CL CODE-009).
class HomeService {
  const HomeService({
    required this.code,
    required this.label,
    required this.hospitalCount,
  });

  final String code;
  final String label;
  final int hospitalCount;
}

/// "Available Services": the platform's departments as tiles, departments
/// with the most hospitals first.
final homeServicesProvider =
    Provider.autoDispose<AsyncValue<List<HomeService>>>((ref) {
      final departments = ref.watch(discoveryDepartmentsProvider);
      return departments.whenData((page) {
        final rows = page.value.results.toList()
          ..sort((a, b) => b.hospitalCount.compareTo(a.hospitalCount));
        return [
          for (final DepartmentSummary d in rows)
            HomeService(
              code: d.code,
              label: d.name,
              hospitalCount: d.hospitalCount,
            ),
        ];
      });
    });
