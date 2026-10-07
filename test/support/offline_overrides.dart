import 'package:medibook/app/di/dependencies.dart';
import 'package:medibook/core/utils/location/device_location.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/core/network/connectivity/connectivity_monitor.dart';
import 'package:medibook/core/network/realtime/ws_client.dart';
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/features/appointments/application/providers/appointments_provider.dart';
import 'package:medibook/features/auth/application/providers/auth_provider.dart';
import 'package:medibook/features/notifications/application/providers/notifications_provider.dart';

/// Provider overrides for widget and golden tests that pump real screens.
///
/// Every screen now reads the backend through `cachedFetcherProvider`, which
/// bootstrap overrides and which throws when it is not. These overrides give
/// the tests a fetcher over an in-memory store behind an **offline** monitor,
/// so each read fails fast and deterministically with a `NetworkFailure`
/// (HIVE Scenario 3) and the screens render their offline / empty states —
/// no timers, no network, no scripted fixtures to keep in step with the
/// contract. Tests that assert on loaded data override the feature's
/// repository provider with a fake instead (see `test/features/*/support`).
///
/// The two WebSocket factories hand out a client whose `connect()` is a
/// no-op: flutter_test's mocked `HttpClient` cannot upgrade a socket and
/// the failure escapes the caller's zone, and a connect attempt would
/// otherwise schedule reconnect timers that `pumpAndSettle` waits on.
///
/// Callers that pump the app also set `HiveInit.store = InMemoryLocalStore()`
/// in `setUp` (the auth and onboarding local data sources read it); this
/// helper deliberately does not, so a test can seed the store first.
List<Override> offlineOverrides() {
  final monitor = _OfflineMonitor();
  WsClient noSocket(String path) => _NoopWsClient(path);
  return [
    // The app's wiring (app/di); everything after it replaces parts of it.
    ...appDependencies(),
    connectivityMonitorProvider.overrideWithValue(monitor),
    // No location plugin in tests: the position is simply unavailable.
    deviceLocatorProvider.overrideWithValue(const _NoLocation()),
    inboxSocketFactoryProvider.overrideWithValue(noSocket),
    wsClientFactoryProvider.overrideWithValue(noSocket),
    cachedFetcherProvider.overrideWith((ref) {
      final fetcher = CachedFetcher(
        client: ref.watch(apiClientProvider),
        connectivity: monitor,
        store: InMemoryLocalStore(),
      );
      ref.onDispose(fetcher.dispose);
      return fetcher;
    }),
  ];
}

class _OfflineMonitor extends ConnectivityMonitor {
  @override
  bool get isOnline => false;

  /// Truly offline (no network at all), not "a network but no server".
  @override
  bool get hasRoute => false;

  @override
  Stream<bool> get changes => const Stream.empty();

  @override
  Stream<void> get onReconnect => const Stream.empty();
}

class _NoopWsClient extends WsClient {
  _NoopWsClient(String path)
    : super(url: 'ws://offline.invalid$path', accessToken: () async => null);

  @override
  Future<void> connect() async {}
}

class _NoLocation implements DeviceLocator {
  const _NoLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationResult.unavailable(LocationUnavailable.noFix);

  @override
  Future<void> openSettings() async {}
}
