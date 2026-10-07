import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/di/dependencies.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/core/utils/location/device_location.dart';
import 'package:medibook/features/booking/application/providers/location_scope_provider.dart';
import 'package:medibook/features/booking/domain/entities/location_scope.dart';
import 'package:medibook/features/booking/domain/repositories/discovery_repository.dart';
import 'package:medibook/features/dashboard/application/providers/home_providers.dart';

/// Checklist DISC-001 (owner decision 6 Oct 2026): the chosen location is
/// saved, survives a relaunch, and scopes Home.
void main() {
  setUp(() => HiveInit.store = InMemoryLocalStore());

  test('the choice survives a relaunch and can be cleared', () async {
    final first = ProviderContainer(overrides: appDependencies());
    await first
        .read(locationScopeProvider.notifier)
        .choose(const LocationScope(city: 'Kochi', area: 'Kadavanthra'));
    first.dispose();

    // A new container reads the same store, like a cold start.
    final second = ProviderContainer(overrides: appDependencies());
    addTearDown(second.dispose);
    expect(
      second.read(locationScopeProvider),
      const LocationScope(city: 'Kochi', area: 'Kadavanthra'),
    );
    expect(second.read(locationScopeProvider)!.label, 'Kadavanthra, Kochi');

    await second.read(locationScopeProvider.notifier).clear();
    final third = ProviderContainer(overrides: appDependencies());
    addTearDown(third.dispose);
    expect(third.read(locationScopeProvider), isNull);
  });

  test('Home asks for the saved city and area', () {
    final q = homeHospitalsQueryFor(
      Coordinates(9.93, 76.26),
      const LocationScope(city: 'Kochi', area: 'Kadavanthra'),
    );
    expect(q.city, 'Kochi');
    expect(q.area, 'Kadavanthra');
    expect(q.sort, HospitalSort.distance);

    final cityOnly = homeHospitalsQueryFor(
      null,
      const LocationScope(city: 'Pune'),
    );
    expect(cityOnly.city, 'Pune');
    expect(cityOnly.area, isNull);

    final everywhere = homeHospitalsQueryFor(null);
    expect(everywhere.city, isNull);
  });
}
