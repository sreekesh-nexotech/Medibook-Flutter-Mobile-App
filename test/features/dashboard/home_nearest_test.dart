import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/di/dependencies.dart';
import 'package:medibook/core/utils/location/device_location.dart';
import 'package:medibook/core/network/api_client.dart' show Page;
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/features/booking/application/providers/discovery_providers.dart';
import 'package:medibook/features/booking/domain/entities/hospital.dart';
import 'package:medibook/features/booking/domain/repositories/discovery_repository.dart';
import 'package:medibook/features/dashboard/application/providers/home_providers.dart';

/// Checklist DISC-015 (owner decision 6 Oct 2026): "Hospitals Near You" is
/// sorted by distance — the app sends the position, the backend sorts.
void main() {
  test('coordinates are rounded to about 1 km before leaving the phone', () {
    final at = Coordinates(9.93123, 76.26789);
    expect(at.latText, '9.93');
    expect(at.lngText, '76.27');
  });

  test('with a position Home asks for distance order; without, name', () {
    final near = homeHospitalsQueryFor(Coordinates(18.53, 73.85));
    expect(near.sort, HospitalSort.distance);
    expect(near.lat, '18.53');
    expect(near.lng, '73.85');
    final none = homeHospitalsQueryFor(null);
    expect(none.sort, HospitalSort.name);
    expect(none.hasCoordinates, isFalse);
  });

  for (final found in [true, false]) {
    test('Home sends ${found ? 'the position' : 'no position'}', () async {
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [
          ...appDependencies(),
          discoveryRepositoryProvider.overrideWithValue(repository),
          deviceLocatorProvider.overrideWithValue(
            _Locator(
              found
                  ? LocationResult.found(Coordinates(18.53, 73.85))
                  : const LocationResult.unavailable(
                      LocationUnavailable.denied,
                    ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(homeHospitalsProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(homeHospitalsProvider.future);
      // The list is asked for at once (name order); once the position is
      // in, it is asked for again nearest first.
      await container.read(homeCoordinatesProvider.future);
      await container.read(homeHospitalsProvider.future);
      expect(repository.asked.first.sort, HospitalSort.name);
      final query = repository.asked.last;
      expect(query.sort, found ? HospitalSort.distance : HospitalSort.name);
      expect(query.lat, found ? '18.53' : isNull);
    });
  }

  // Home watches only the list. The position provider used to be dropped
  // while the list rebuilt for it, come back still loading, and restart the
  // list without it — about 60 times a second, so the list never settled
  // and the promo strip (which waits for it) never showed.
  test('once the position arrives the list settles, nearest first', () async {
    final repository = _Repository();
    final container = ProviderContainer(
      overrides: [
        ...appDependencies(),
        discoveryRepositoryProvider.overrideWithValue(repository),
        deviceLocatorProvider.overrideWithValue(
          _Locator(LocationResult.found(Coordinates(18.53, 73.85))),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(homeHospitalsProvider, (_, _) {});
    addTearDown(sub.close);

    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(repository.asked.length, lessThanOrEqualTo(3));
    expect(repository.asked.last.sort, HospitalSort.distance);
    expect(container.read(homeHospitalsProvider).hasValue, isTrue);
  });
}

class _Locator implements DeviceLocator {
  _Locator(this.result);
  final LocationResult result;

  @override
  Future<LocationResult> current() async => result;

  @override
  Future<void> openSettings() async {}
}

class _Repository implements DiscoveryRepository {
  final List<HospitalsQuery> asked = [];

  @override
  Stream<CachedResult<Page<HospitalCard>>> hospitals(
    HospitalsQuery query, {
    bool forceRefresh = false,
  }) async* {
    asked.add(query);
    yield CachedResult(
      value: const Page.empty(),
      source: CacheSource.network,
      cachedAt: DateTime.now(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
