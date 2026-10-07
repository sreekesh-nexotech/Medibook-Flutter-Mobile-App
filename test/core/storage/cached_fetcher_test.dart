import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/connectivity/connectivity_monitor.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/api_client.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/core/storage/hive/adapters/cache_entry_adapter.dart';
import 'package:medibook/core/storage/hive/boxes.dart';
import 'package:medibook/core/storage/hive/keys.dart';
import 'package:medibook/core/storage/local_store.dart';

/// The HIVE-spec scenarios the fetcher must honour, driven with an in-memory
/// store and a scripted client (no Hive, no network).
void main() {
  late InMemoryLocalStore store;
  late _ScriptedClient api;
  late _FakeConnectivity connectivity;
  late CachedFetcher fetcher;

  const request = ApiRequest(path: '/patient/locations', requiresAuth: false);
  Map<String, Object?> decode(Object? json) => (json as Map).cast();

  setUp(() async {
    store = InMemoryLocalStore();
    await store.open();
    api = _ScriptedClient();
    connectivity = _FakeConnectivity();
    fetcher = CachedFetcher(
      client: api,
      connectivity: connectivity,
      store: store,
    );
  });

  tearDown(() => fetcher.dispose());

  test(
    'Scenario 1 — cold start: miss, miss, network; both caches written',
    () async {
      api.enqueue(
        const ApiResponse(
          statusCode: 200,
          data: {'v': 1},
          headers: {'etag': '"e1"'},
        ),
      );
      final results = await fetcher.fetch(request, decode).toList();
      expect(results, hasLength(1));
      expect(results.single.source, CacheSource.network);
      expect(results.single.value['v'], 1);
      expect(api.sent.single.ifNoneMatch, isNull);
      // L2 holds a CacheEntry with the ETag.
      final key = store.keys(HiveBoxes.httpCache).single;
      final entry = store.read(HiveBoxes.httpCache, key) as CacheEntry;
      expect(entry.etag, '"e1"');
    },
  );

  test('Scenario 4 — a valid memory hit needs no network', () async {
    api.enqueue(const ApiResponse(statusCode: 200, data: {'v': 1}));
    await fetcher.get(request, decode);
    final again = await fetcher.fetch(request, decode).toList();
    expect(again.single.source, CacheSource.memory);
    expect(api.sent, hasLength(1));
  });

  // Owner decision (5 Oct 2026): every screen shows the latest data when it
  // is navigated to. Arriving at a screen makes memory copies re-check once.
  test('after an arrival a memory copy is shown, then re-checked', () async {
    api.enqueue(
      const ApiResponse(
        statusCode: 200,
        data: {'v': 1},
        headers: {'etag': '"e1"'},
      ),
    );
    await fetcher.get(request, decode);

    // The entry must be strictly older than the arrival.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    fetcher.markArrival();
    api.enqueue(const ApiResponse(statusCode: 304));
    final afterArrival = await fetcher.fetch(request, decode).toList();

    expect(afterArrival.first.value['v'], 1, reason: 'shown at once');
    expect(afterArrival.first.revalidating, isTrue);
    expect(afterArrival.last.source, CacheSource.network);
    expect(api.sent, hasLength(2));
    expect(api.sent.last.ifNoneMatch, '"e1"', reason: 'a cheap 304 check');

    // Reads repeated during the same visit are free again (Scenario 4).
    final sameVisit = await fetcher.fetch(request, decode).toList();
    expect(sameVisit.single.source, CacheSource.memory);
    expect(api.sent, hasLength(2));
  });

  test('an arrival picks up data that changed on the server', () async {
    api.enqueue(const ApiResponse(statusCode: 200, data: {'v': 1}));
    await fetcher.get(request, decode);

    await Future<void>.delayed(const Duration(milliseconds: 5));
    fetcher.markArrival();
    api.enqueue(const ApiResponse(statusCode: 200, data: {'v': 2}));

    expect((await fetcher.get(request, decode))['v'], 2);
  });

  test(
    'Scenario 2/6 — warm start revalidates with If-None-Match; 304 keeps body',
    () async {
      // Seed L2 as if from an earlier run (8 h old) and no L1.
      final now = DateTime.now().subtract(const Duration(hours: 8));
      final key = _keyFor(request);
      await store.write(
        HiveBoxes.httpCache,
        key,
        CacheEntry(
          key: key,
          data: '{"v":"cached"}',
          etag: '"e1"',
          cachedAt: now.millisecondsSinceEpoch,
          lastAccessed: now.millisecondsSinceEpoch,
          accessCount: 1,
          size: 20,
        ),
      );
      api.enqueue(
        const ApiResponse(statusCode: 304, headers: {'etag': '"e1"'}),
      );

      final results = await fetcher.fetch(request, decode).toList();
      expect(results, hasLength(2));
      expect(results.first.source, CacheSource.hive);
      expect(results.first.revalidating, isTrue);
      expect(results.first.isStale, isFalse);
      expect(results.last.source, CacheSource.network);
      expect(results.last.value['v'], 'cached');
      expect(api.sent.single.ifNoneMatch, '"e1"');
      // The ETag is untouched after a 304.
      final entry = store.read(HiveBoxes.httpCache, key) as CacheEntry;
      expect(entry.etag, '"e1"');
    },
  );

  test(
    'Scenario 5 — stale cache (> 24 h) is flagged and replaced on 200',
    () async {
      final old = DateTime.now().subtract(const Duration(hours: 30));
      final key = _keyFor(request);
      await store.write(
        HiveBoxes.httpCache,
        key,
        CacheEntry(
          key: key,
          data: '{"v":"old"}',
          etag: '"e1"',
          cachedAt: old.millisecondsSinceEpoch,
          lastAccessed: old.millisecondsSinceEpoch,
          accessCount: 1,
          size: 20,
        ),
      );
      api.enqueue(
        const ApiResponse(
          statusCode: 200,
          data: {'v': 'new'},
          headers: {'etag': '"e2"'},
        ),
      );
      final results = await fetcher.fetch(request, decode).toList();
      expect(results.first.isStale, isTrue);
      expect(results.last.value['v'], 'new');
      final entry = store.read(HiveBoxes.httpCache, key) as CacheEntry;
      expect(entry.etag, '"e2"');
    },
  );

  test(
    'Scenario 2 error path — network failure keeps the cached copy',
    () async {
      final key = _keyFor(request);
      final now = DateTime.now().subtract(const Duration(hours: 1));
      await store.write(
        HiveBoxes.httpCache,
        key,
        CacheEntry(
          key: key,
          data: '{"v":"cached"}',
          cachedAt: now.millisecondsSinceEpoch,
          lastAccessed: now.millisecondsSinceEpoch,
          accessCount: 1,
          size: 20,
        ),
      );
      api.enqueueError(const NoConnectionException());
      final results = await fetcher.fetch(request, decode).toList();
      expect(results.last.value['v'], 'cached');
      expect(results.last.revalidating, isFalse);
    },
  );

  test(
    'Scenario 3 — offline with nothing cached is a NetworkFailure',
    () async {
      connectivity.isOnline = false;
      await expectLater(
        fetcher.fetch(request, decode).toList(),
        throwsA(isA<NetworkFailure>()),
      );
      expect(api.sent, isEmpty);
    },
  );

  test(
    'Scenario 7 — concurrent identical requests make one network call',
    () async {
      api.enqueue(const ApiResponse(statusCode: 200, data: {'v': 1}));
      await Future.wait([
        fetcher.get(request, decode),
        fetcher.get(request, decode),
        fetcher.get(request, decode),
      ]);
      expect(api.sent, hasLength(1));
    },
  );

  test('Scenario 10 — a response that fails decoding is not cached', () async {
    api.enqueue(const ApiResponse(statusCode: 200, data: 'not-an-object'));
    await expectLater(fetcher.get(request, decode), throwsA(anything));
    expect(store.keys(HiveBoxes.httpCache), isEmpty);
  });

  test(
    'Scenario 10 — a non-JSON Content-Type is refused and not cached',
    () async {
      api.enqueue(
        const ApiResponse(
          statusCode: 200,
          data: {'v': 1},
          headers: {'content-type': 'text/html; charset=utf-8'},
        ),
      );
      await expectLater(
        fetcher.get(request, decode),
        throwsA(isA<ServerFailure>()),
      );
      expect(store.keys(HiveBoxes.httpCache), isEmpty);
    },
  );

  test('Scenario 10 — application/json is accepted', () async {
    api.enqueue(
      const ApiResponse(
        statusCode: 200,
        data: {'v': 1},
        headers: {'content-type': 'application/json'},
      ),
    );
    expect((await fetcher.get(request, decode))['v'], 1);
  });

  test(
    'Scenario 6 — 412 drops the entry and refetches without the ETag',
    () async {
      final then = DateTime.now().subtract(const Duration(hours: 8));
      final key = _keyFor(request);
      await store.write(
        HiveBoxes.httpCache,
        key,
        CacheEntry(
          key: key,
          data: '{"v":"cached"}',
          etag: '"e1"',
          cachedAt: then.millisecondsSinceEpoch,
          lastAccessed: then.millisecondsSinceEpoch,
          accessCount: 1,
          size: 20,
        ),
      );
      api.enqueueError(
        const HttpStatusException(statusCode: 412, message: 'precondition'),
      );
      api.enqueue(
        const ApiResponse(
          statusCode: 200,
          data: {'v': 'fresh'},
          headers: {'etag': '"e2"'},
        ),
      );

      final results = await fetcher.fetch(request, decode).toList();
      expect(results.last.value['v'], 'fresh');
      expect(api.sent, hasLength(2));
      expect(api.sent.first.ifNoneMatch, '"e1"');
      expect(api.sent.last.ifNoneMatch, isNull);
      final entry = store.read(HiveBoxes.httpCache, key) as CacheEntry;
      expect(entry.etag, '"e2"');
    },
  );

  test('cache keys include the account scope (tenant isolation)', () async {
    var account = 'user-a';
    final scoped = CachedFetcher(
      client: api,
      connectivity: connectivity,
      store: store,
      cacheScope: () async => account,
    );
    addTearDown(scoped.dispose);
    api.enqueue(const ApiResponse(statusCode: 200, data: {'who': 'a'}));
    api.enqueue(const ApiResponse(statusCode: 200, data: {'who': 'b'}));
    const authed = ApiRequest(path: '/patient/me');
    final a = await scoped.get(authed, decode);
    account = 'user-b';
    final b = await scoped.get(authed, decode);
    expect(a['who'], 'a');
    expect(b['who'], 'b');
    expect(store.keys(HiveBoxes.httpCache), hasLength(2));
  });

  // DEF-065 (BL-CACHE-010): the access token is replaced every 15 minutes.
  // A key built from it lost everything saved before the refresh.
  test('a token refresh does not hide saved data from offline use', () async {
    var token = 'token-1';
    // The bootstrap scope: the account's id while a token is held.
    Future<String?> scope() async => token.isEmpty ? null : 'user-a';
    final saving = CachedFetcher(
      client: api,
      connectivity: connectivity,
      store: store,
      cacheScope: scope,
    );
    addTearDown(saving.dispose);
    api.enqueue(const ApiResponse(statusCode: 200, data: {'v': 'saved'}));
    await saving.get(request, decode);

    token = 'token-2';
    connectivity.isOnline = false;
    // A fresh fetcher, as after a relaunch: memory is empty, Hive is not.
    final relaunched = CachedFetcher(
      client: api,
      connectivity: connectivity,
      store: store,
      cacheScope: scope,
    );
    addTearDown(relaunched.dispose);
    final results = await relaunched.fetch(request, decode).first;
    expect(results.value['v'], 'saved');
    expect(api.sent, hasLength(1), reason: 'nothing sent while offline');
  });

  // BL-CACHE-008 / -010: offline, a one-shot read used to wait for the
  // connection to return (up to 30 minutes) instead of giving the saved copy.
  test('offline, a one-shot read returns the saved copy at once', () async {
    api.enqueue(const ApiResponse(statusCode: 200, data: {'v': 'saved'}));
    await fetcher.get(request, decode);
    final reopened = CachedFetcher(
      client: api,
      connectivity: _NeverReconnects(),
      store: store,
    );
    addTearDown(reopened.dispose);
    final value = await reopened
        .get(request, decode)
        .timeout(const Duration(seconds: 1));
    expect(value['v'], 'saved');
    expect(api.sent, hasLength(1), reason: 'nothing sent while offline');
  });

  test('invalidate() empties both layers', () async {
    api.enqueue(const ApiResponse(statusCode: 200, data: {'v': 1}));
    await fetcher.get(request, decode);
    await fetcher.invalidate();
    expect(store.keys(HiveBoxes.httpCache), isEmpty);
    api.enqueue(const ApiResponse(statusCode: 200, data: {'v': 2}));
    final fresh = await fetcher.get(request, decode);
    expect(fresh['v'], 2);
  });

  // Edit Profile audit (7 Oct 2026): a profile save wiped every saved list
  // and each was fetched again in full.
  group('invalidatePaths()', () {
    const me = ApiRequest(path: '/patient/me');
    const persons = ApiRequest(path: '/patient/me/persons');
    const addresses = ApiRequest(path: '/patient/me/addresses');

    Future<void> cacheAll() async {
      for (final r in [me, persons, addresses, request]) {
        api.enqueue(
          const ApiResponse(
            statusCode: 200,
            data: {'v': 1},
            headers: {'etag': '"e1"'},
          ),
        );
        await fetcher.get(r, decode);
      }
    }

    test('drops only the named paths and what is under them', () async {
      await cacheAll();
      await fetcher.invalidatePaths(
        paths: {'/patient/me'},
        under: {'/patient/me/persons'},
      );
      final kept = store.keys(HiveBoxes.httpCache).toSet();
      expect(kept, {_keyFor(addresses), _keyFor(request)});

      // The kept entries still answer offline, with their ETag.
      connectivity.isOnline = false;
      expect((await fetcher.get(addresses, decode))['v'], 1);
    });

    test('an exact path does not take its sub-paths with it', () async {
      await cacheAll();
      await fetcher.invalidatePaths(paths: {'/patient/me'});
      expect(store.keys(HiveBoxes.httpCache), isNot(contains(_keyFor(me))));
      expect(store.keys(HiveBoxes.httpCache), contains(_keyFor(persons)));
    });

    test('paths are remembered across a restart', () async {
      await cacheAll();
      fetcher.dispose();
      fetcher = CachedFetcher(
        client: api,
        connectivity: connectivity,
        store: store,
      );
      await fetcher.invalidatePaths(paths: {'/patient/me'});
      expect(store.keys(HiveBoxes.httpCache), hasLength(3));
    });

    test('an entry whose path is unknown is dropped to be safe', () async {
      await cacheAll();
      for (final key in store.keys(HiveBoxes.cacheMeta).toList()) {
        await store.delete(HiveBoxes.cacheMeta, key);
      }
      fetcher.dispose();
      fetcher = CachedFetcher(
        client: api,
        connectivity: connectivity,
        store: store,
      );
      await fetcher.invalidatePaths(paths: {'/patient/me'});
      expect(store.keys(HiveBoxes.httpCache), isEmpty);
    });
  });
}

String _keyFor(ApiRequest request) => cacheKeys.forRequest(request);

class _ScriptedClient with ApiClientVerbs implements ApiClient {
  final List<Object> _queue = [];
  final List<ApiRequest> sent = [];

  void enqueue(ApiResponse response) => _queue.add(response);
  void enqueueError(Object error) => _queue.add(error);

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    sent.add(request);
    if (_queue.isEmpty) throw StateError('no scripted response for $request');
    final next = _queue.removeAt(0);
    if (next is ApiResponse) return next;
    throw next;
  }
}

class _FakeConnectivity extends ConnectivityMonitor {
  _FakeConnectivity();

  @override
  bool isOnline = true;

  @override
  Stream<void> get onReconnect => const Stream.empty();
}

/// Offline for the whole test: never reconnects.
class _NeverReconnects extends ConnectivityMonitor {
  final StreamController<void> _never = StreamController<void>.broadcast();

  @override
  bool get isOnline => false;

  @override
  Stream<void> get onReconnect => _never.stream;
}
