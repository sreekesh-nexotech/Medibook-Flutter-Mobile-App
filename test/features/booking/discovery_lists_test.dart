import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medibook/core/network/connectivity/connectivity_monitor.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/app/config/constants.dart';
import 'package:medibook/app/theme/theme.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/models/page.dart';
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/features/booking/application/providers/discovery_providers.dart';
import 'package:medibook/features/booking/application/providers/location_scope_provider.dart';
import 'package:medibook/features/booking/domain/entities/department.dart';
import 'package:medibook/features/booking/domain/entities/hospital.dart';
import 'package:medibook/features/booking/domain/entities/location.dart';
import 'package:medibook/features/booking/domain/entities/location_scope.dart';
import 'package:medibook/features/booking/domain/repositories/discovery_repository.dart';
import 'package:medibook/features/booking/infrastructure/data_sources/remote/discovery_api.dart';
import 'package:medibook/features/booking/presentation/screen/hospitals_screen.dart';
import 'package:medibook/features/booking/presentation/screen/locations_screen.dart';

import '../../support/offline_overrides.dart';

/// "Choose a location" and the hospital list it opens (Choose a location
/// audit, 6 Oct 2026): a list that cannot load shows its error view instead
/// of Flutter's red page; "See every hospital" from it forgets the saved
/// area; pull-to-refresh asks the server; every area is fetched and counted
/// from the server's total.
void main() {
  setUp(() => HiveInit.store = InMemoryLocalStore());

  test('every area is asked for in one page', () {
    expect(DiscoveryApi.locations().query['page_size'], 100);
  });

  Future<(ProviderContainer, GoRouter)> open(
    WidgetTester tester,
    _Discovery repository, {
    String at = '/locations',
  }) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: at,
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('Home')),
        GoRoute(path: '/locations', builder: (_, _) => const LocationsScreen()),
        GoRoute(
          path: '/hospitals',
          builder: (_, state) => HospitalsScreen(
            city: state.uri.queryParameters['city'],
            area: state.uri.queryParameters['area'],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [
        ...offlineOverrides(),
        // Online: a pull while offline only says so (app_refresh.dart).
        connectivityMonitorProvider.overrideWithValue(_OnlineMonitor()),
        discoveryRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: AppConstants.designSize,
          builder: (_, _) =>
              MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container, router);
  }

  group('Choose a location', () {
    testWidgets('a list that cannot load shows the error view', (tester) async {
      await open(tester, _Discovery(locationsFail: true));
      expect(tester.takeException(), isNull);
      expect(find.text("You're offline"), findsOneWidget);
      expect(find.text('See every hospital'), findsOneWidget);
    });

    testWidgets('"See every hospital" from the error forgets the saved area', (
      tester,
    ) async {
      final (container, router) = await open(
        tester,
        _Discovery(locationsFail: true),
      );
      await container
          .read(locationScopeProvider.notifier)
          .choose(const LocationScope(city: 'Kochi', area: 'Kadavanthra'));

      await tester.tap(find.text('See every hospital'));
      await tester.pumpAndSettle();
      expect(container.read(locationScopeProvider), isNull);
      // The list opened on top, unscoped.
      expect(find.byType(HospitalsScreen), findsOneWidget);
      expect(find.textContaining('Kadavanthra'), findsNothing);
    });

    testWidgets('pull-to-refresh asks the server', (tester) async {
      final repository = _Discovery();
      await open(tester, repository);
      expect(repository.forcedLocations, 0);

      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 500),
      );
      await tester.pumpAndSettle();
      expect(repository.forcedLocations, 1);
    });

    testWidgets('the no-match line counts every area on the server', (
      tester,
    ) async {
      await open(tester, _Discovery(totalAreas: 30));
      await tester.enterText(find.byType(TextField).first, 'xyz');
      await tester.pumpAndSettle();
      expect(
        find.text('We currently list 30 areas across 2 cities.'),
        findsOneWidget,
      );
    });
  });

  group('Hospitals', () {
    testWidgets('a list never saved shows the error view offline', (
      tester,
    ) async {
      await open(
        tester,
        _Discovery(hospitalsFail: true),
        at: '/hospitals?city=Hyderabad&area=Jubilee%20Hills',
      );
      expect(tester.takeException(), isNull);
      expect(find.text("You're offline"), findsOneWidget);
    });

    testWidgets('pull-to-refresh asks the server', (tester) async {
      final repository = _Discovery();
      await open(tester, repository, at: '/hospitals?city=Kochi');
      expect(repository.forcedHospitals, 0);

      await tester.drag(find.text('Lakeshore'), const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(repository.forcedHospitals, 1);
    });
  });
}

CachedResult<T> _fresh<T>(T value) => CachedResult<T>(
  value: value,
  source: CacheSource.network,
  cachedAt: DateTime.now(),
);

class _Discovery implements DiscoveryRepository {
  _Discovery({
    this.locationsFail = false,
    this.hospitalsFail = false,
    this.totalAreas = 2,
  });

  final bool locationsFail;
  final bool hospitalsFail;
  final int totalAreas;
  int forcedLocations = 0;
  int forcedHospitals = 0;

  @override
  Stream<CachedResult<Page<Location>>> locations({
    String? city,
    bool? popular,
    bool forceRefresh = false,
  }) async* {
    if (forceRefresh) forcedLocations++;
    if (locationsFail) throw const NetworkFailure();
    yield _fresh(
      Page(
        results: const [
          Location(
            id: 'l1',
            city: 'Kochi',
            area: 'Kadavanthra',
            state: 'Kerala',
            isPopular: true,
          ),
          Location(id: 'l2', city: 'Pune', area: 'Kothrud', state: 'MH'),
        ],
        page: 1,
        pageSize: 100,
        total: totalAreas,
        hasNext: false,
      ),
    );
  }

  @override
  Stream<CachedResult<Page<DepartmentSummary>>> departments({
    bool forceRefresh = false,
  }) => Stream.value(
    _fresh(
      const Page(results: [], page: 1, pageSize: 50, total: 0, hasNext: false),
    ),
  );

  @override
  Stream<CachedResult<Page<HospitalCard>>> hospitals(
    HospitalsQuery query, {
    bool forceRefresh = false,
  }) async* {
    if (forceRefresh) forcedHospitals++;
    if (hospitalsFail) throw const NetworkFailure();
    yield _fresh(
      const Page(
        results: [
          HospitalCard(
            id: 'h1',
            slug: 'h1',
            name: 'Lakeshore',
            city: 'Kochi',
            departments: [],
            onlineBookingEnabled: true,
          ),
        ],
        page: 1,
        pageSize: 50,
        total: 1,
        hasNext: false,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OnlineMonitor extends ConnectivityMonitor {
  @override
  bool get isOnline => true;

  @override
  Stream<bool> get changes => const Stream.empty();

  @override
  Stream<void> get onReconnect => const Stream.empty();
}
