import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/features/common/cached/application/providers/cached_controller.dart';
import 'package:medibook/features/support/domain/entities/app_config.dart';
import 'package:medibook/features/support/infrastructure/repositories/support_mappers.dart';

/// The read-side plumbing every cached list in profile/support shares:
/// how the fetcher's cached-first-then-network stream becomes screen state.
void main() {
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  CachedResult<List<int>> result(
    List<int> value, {
    CacheSource source = CacheSource.network,
    bool stale = false,
    bool revalidating = false,
  }) => CachedResult<List<int>>(
    value: value,
    source: source,
    cachedAt: DateTime.now(),
    isStale: stale,
    revalidating: revalidating,
  );

  test('cold start: loading, then the network value', () async {
    final loader = StreamController<CachedResult<List<int>>>();
    final controller = CachedController<List<int>>(
      ({required forceRefresh}) => loader.stream,
    );
    addTearDown(controller.dispose);
    expect(controller.state.isLoading, isTrue);

    loader.add(result([1, 2]));
    await settle();
    expect(controller.state.isLoading, isFalse);
    expect(controller.state.value, [1, 2]);
    expect(controller.state.isFresh, isTrue);
    await loader.close();
  });

  test(
    'warm start: stale cached copy shows with "updating", then network',
    () async {
      final loader = StreamController<CachedResult<List<int>>>();
      final controller = CachedController<List<int>>(
        ({required forceRefresh}) => loader.stream,
      );
      addTearDown(controller.dispose);

      loader.add(
        result([1], source: CacheSource.hive, stale: true, revalidating: true),
      );
      await settle();
      expect(controller.state.value, [1]);
      expect(controller.state.isStale, isTrue);
      expect(controller.state.isRefreshing, isTrue);

      loader.add(result([1, 2]));
      await settle();
      expect(controller.state.value, [1, 2]);
      expect(controller.state.isStale, isFalse);
      expect(controller.state.isRefreshing, isFalse);
      await loader.close();
    },
  );

  test('a failure with no value is the error state; with a value it is kept '
      'beside the data', () async {
    var calls = 0;
    final controller = CachedController<List<int>>(({required forceRefresh}) {
      calls++;
      if (calls == 1) return Stream.error(const NetworkFailure());
      return Stream.fromIterable([
        result([3], source: CacheSource.hive),
      ]).asyncExpand((r) async* {
        yield r;
        throw const TimeoutFailure();
      });
    });
    addTearDown(controller.dispose);
    await settle();
    expect(controller.state.isError, isTrue);
    expect(controller.state.failure, isA<NetworkFailure>());

    await controller.refresh(force: true);
    await settle();
    expect(controller.state.value, [3]);
    expect(controller.state.isError, isFalse);
    expect(controller.state.failure, isA<TimeoutFailure>());
    expect(controller.state.isRefreshing, isFalse);
  });

  test(
    'refresh(force) passes the flag and replace() updates in place',
    () async {
      final forced = <bool>[];
      final controller = CachedController<List<int>>(({required forceRefresh}) {
        forced.add(forceRefresh);
        return Stream.value(result([1]));
      });
      addTearDown(controller.dispose);
      await settle();

      await controller.refresh(force: true);
      expect(forced, [false, true]);

      controller.replace([9]);
      expect(controller.state.value, [9]);
      controller.update((v) => [...v, 10]);
      expect(controller.state.value, [9, 10]);
    },
  );

  test('onValue fires for every new value', () async {
    final seen = <AppConfig>[];
    final config = SupportMappers.appConfig(const {'otp_length': 6});
    final controller = CachedController<AppConfig>(
      ({required forceRefresh}) => Stream.value(
        CachedResult<AppConfig>(
          value: config,
          source: CacheSource.network,
          cachedAt: DateTime.now(),
        ),
      ),
      onValue: seen.add,
    );
    addTearDown(controller.dispose);
    await settle();
    expect(seen, [config]);
    controller.replace(AppConfig.fallback);
    expect(seen, [config, AppConfig.fallback]);
  });

  // Opened offline, the read shows the saved copy and then waits for the
  // network (HIVE Scenario 3). A pull-to-refresh replacing it used to wait
  // for that wait to end, so its spinner turned until the connection was
  // back.
  test('a pull-to-refresh offline does not wait for the network', () async {
    final network = Completer<void>();
    addTearDown(network.complete);
    final controller = CachedController<List<int>>(({
      required forceRefresh,
    }) async* {
      if (forceRefresh) throw const NetworkFailure();
      yield result([1], source: CacheSource.hive);
      await network.future;
    });
    addTearDown(controller.dispose);
    await settle();
    expect(controller.state.value, [1]);

    await controller.refresh(force: true).timeout(const Duration(seconds: 1));
    expect(controller.state.value, [1], reason: 'the saved copy stays');
    expect(controller.state.failure, isA<NetworkFailure>());
    expect(controller.state.isRefreshing, isFalse);
  });

  test('a refresh replaced by another one still finishes', () async {
    final first = StreamController<CachedResult<List<int>>>();
    var calls = 0;
    final controller = CachedController<List<int>>(
      ({required forceRefresh}) =>
          ++calls == 2 ? first.stream : Stream.value(result([calls])),
    );
    addTearDown(controller.dispose);
    await settle();

    // A pull-to-refresh still waiting, then "Tap to refresh" under it.
    final pull = controller.refresh(force: true);
    await settle();
    await controller.refresh(force: true);
    await pull.timeout(const Duration(seconds: 1));
    expect(controller.state.value, [3]);
    await first.close();
  });

  test('a failed refresh loads again when the network returns', () async {
    final reconnects = StreamController<void>.broadcast();
    addTearDown(reconnects.close);
    var online = true;
    var answer = 1;
    final controller = CachedController<List<int>>(({
      required forceRefresh,
    }) async* {
      if (!online) throw const NetworkFailure();
      yield result([answer]);
    }, reconnects: reconnects.stream);
    addTearDown(controller.dispose);
    await settle();

    online = false;
    await controller.refresh(force: true);
    expect(controller.state.failure, isA<NetworkFailure>());
    expect(controller.state.value, [1]);

    online = true;
    answer = 2;
    reconnects.add(null);
    await settle();
    expect(controller.state.value, [2]);
    expect(controller.state.failure, isNull);
  });
}
