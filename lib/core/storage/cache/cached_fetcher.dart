import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/bootstrap/hive_init.dart';
import '../../network/connectivity/connectivity_monitor.dart';
import '../../error/failure.dart';
import '../../network/api_client.dart';
import '../../network/network_exceptions.dart';
import '../../utils/logger.dart';
import '../hive/adapters/cache_entry_adapter.dart';
import '../hive/boxes.dart';
import '../hive/keys.dart';
import '../hive_local_store.dart';
import 'cached_result.dart';

export 'cached_result.dart';

/// The three-layer read path from `docs-flutter/HIVE implementation.md`:
/// Memory (L1) → Hive (L2) → Network (L3), with every scenario's error path.
///
/// Repositories call [fetch] for cacheable GETs and [invalidate] after a
/// mutation. The decoded value is what the caller's [decode] returns, so the
/// validation pipeline (Scenario 10) — HTTP status → JSON parse → schema →
/// required fields — runs *before* anything is written to either cache.
///
/// * **Cold start** — miss, miss, network; write memory sync, Hive async.
/// * **Warm start (< 12 h)** — serve Hive immediately, revalidate in the
///   background with `If-None-Match`; 304 re-stamps, 200 replaces.
/// * **Stale (> 24 h)** — serve with `isStale`, revalidate with the
///   4-attempt backoff; 4xx stops, 5xx retries.
/// * **Offline** — serve whatever is cached; no retry loop; one retry when
///   the connectivity monitor reports a reconnect.
/// * **Concurrency** — one network call per key ([RequestPool]).
/// * **Corruption** — a corrupt Hive entry is deleted and the key quarantined
///   for 5 minutes; three strikes in an hour and the key is no longer cached.
/// * **Eviction** — L1 LRU on every write; L2 sweep every 5 minutes at 90 %.
class CachedFetcher {
  CachedFetcher({
    required ApiClient client,
    required ConnectivityMonitor connectivity,
    LocalStore? store,
    Future<String?> Function()? cacheScope,
  }) : _client = client,
       _connectivity = connectivity,
       _store = store,
       _cacheScope = cacheScope ?? (() async => null) {
    _monitor = Timer.periodic(CacheConfig.monitorInterval, (_) => _sweep());
  }

  final ApiClient _client;
  final ConnectivityMonitor _connectivity;
  final LocalStore? _store;

  /// The signed-in account's id, or null when signed out — the key's tenant
  /// part (see [CacheKeyBuilder]). Stable across token refreshes.
  final Future<String?> Function() _cacheScope;
  final RequestPool _pool = RequestPool();
  final RetryPolicy _retry = const RetryPolicy();

  // ---- L1 ----
  final Map<String, CacheEntry> _memory = <String, CacheEntry>{};
  int _memoryBytes = 0;

  // ---- Corruption bookkeeping (Scenario 9) ----
  final Map<String, DateTime> _quarantined = <String, DateTime>{};
  final Map<String, List<DateTime>> _strikes = <String, List<DateTime>>{};

  late final Timer _monitor;

  // ---- Key → path ----
  /// The request path each key was cached for. Keys are hashes, so this is
  /// what lets [invalidatePaths] drop one endpoint's entries and keep the
  /// rest. A key is derived from its path, so an entry never goes out of
  /// date; it is mirrored in [HiveBoxes.cacheMeta] to survive a restart.
  final Map<String, String> _paths = <String, String>{};

  static String _pathMetaKey(String key) => 'path:$key';

  // ---- Arrivals ----
  /// When the patient last arrived at a screen (ms since epoch; 0 before the
  /// first arrival).
  int _arrivedAt = 0;

  /// The patient has just arrived at a screen (see `RouteArrival`).
  ///
  /// From now on a memory copy answers without the network only if it has
  /// been checked with the server *since this arrival*; an older one is still
  /// shown at once, and then checked again — a 304 when nothing changed. So
  /// every screen shows the latest data when it is navigated to, while reads
  /// repeated during one visit stay free (Scenario 4).
  void markArrival() => _arrivedAt = DateTime.now().millisecondsSinceEpoch;

  LocalStore get _local => _store ?? HiveInit.store;

  /// Read [request] through the three layers and decode with [decode].
  ///
  /// [forceRefresh] (pull-to-refresh, "tap to refresh") skips L1/L2 for the
  /// *first* answer but still sends the cached ETag so a 304 is cheap.
  ///
  /// The returned stream yields at most twice: the cached value first (if
  /// any), then the network value once revalidation finishes. A caller that
  /// only wants one answer can `await stream.first`.
  Stream<CachedResult<T>> fetch<T>(
    ApiRequest request,
    T Function(Object? json) decode, {
    bool forceRefresh = false,
  }) async* {
    assert(request.method.isCacheable, 'only GETs are cached');
    final scope = await _cacheScope();
    final key = cacheKeys.forRequest(request, scope: scope);
    _rememberPath(key, request.path);
    final now = DateTime.now();

    // Whether the first answer came from L1 decides Scenario 4 (no network)
    // versus Scenario 2 (revalidate), so it is recorded before `_readHive`
    // promotes a disk hit into memory.
    final memoryHit = forceRefresh ? null : _readMemory(key, now);
    CacheEntry? cached =
        memoryHit ?? (forceRefresh ? null : _readHive(key, now));
    // A force-refresh still benefits from the ETag.
    final etagEntry = cached ?? _readMemory(key, now) ?? _readHive(key, now);

    T? cachedValue;
    if (cached != null) {
      try {
        cachedValue = decode(jsonDecode(cached.data));
      } catch (error) {
        // The cached body no longer matches the model: treat as corrupt.
        AppLogger.warning(
          'Cached body undecodable for $request — dropping',
          name: 'cache',
          error: error,
        );
        _dropEntry(key);
        cached = null;
      }
    }

    if (cached != null && cachedValue is T) {
      // Scenario 4: a valid memory hit needs no network at all — provided it
      // was checked with the server since the patient arrived at this screen.
      if (memoryHit != null &&
          cached.isValid &&
          !forceRefresh &&
          cached.cachedAt >= _arrivedAt) {
        yield CachedResult<T>(
          value: cachedValue,
          source: CacheSource.memory,
          cachedAt: DateTime.fromMillisecondsSinceEpoch(cached.cachedAt),
        );
        return;
      }
      yield CachedResult<T>(
        value: cachedValue,
        source: CacheSource.hive,
        cachedAt: DateTime.fromMillisecondsSinceEpoch(cached.cachedAt),
        isStale: cached.isStale,
        revalidating: true,
      );
    }

    // Scenario 3: offline with a cached copy → keep it, do not hammer.
    if (!_connectivity.isOnline) {
      if (cached != null && cachedValue is T) {
        yield CachedResult<T>(
          value: cachedValue,
          source: CacheSource.hive,
          cachedAt: DateTime.fromMillisecondsSinceEpoch(cached.cachedAt),
          isStale: cached.isStale,
        );
        // One retry when the network returns. A subscription cancelled while
        // this waits finishes cancelling only when the wait ends (an
        // `async*` stream cannot stop at an `await`), so a caller replacing
        // its subscription — a pull-to-refresh — cancels without awaiting.
        await _connectivity.onReconnect.first.timeout(
          const Duration(minutes: 30),
          onTimeout: () {},
        );
        if (!_connectivity.isOnline) return;
      } else {
        // A network but no answers is not "offline" (Screen Coverage pass).
        throw _connectivity.hasRoute
            ? const NetworkFailure.unreachable()
            : const NetworkFailure();
      }
    }

    try {
      final result = await _pool.dedupe<CachedResult<T>>(
        key,
        () => _fromNetwork<T>(
          request,
          key,
          decode,
          etag: etagEntry?.etag,
          previous: etagEntry,
          // Scenario 5: stale data gets the backoff; fresh data one shot.
          withRetry: cached?.isStale ?? false,
        ),
      );
      yield result;
    } catch (error, stackTrace) {
      if (cached != null && cachedValue is T) {
        // Scenario 2/5 error path: keep the cached data, hide the indicator.
        AppLogger.warning(
          'Revalidation failed for $request; keeping cached copy',
          name: 'cache',
          error: error,
        );
        yield CachedResult<T>(
          value: cachedValue,
          source: CacheSource.hive,
          cachedAt: DateTime.fromMillisecondsSinceEpoch(cached.cachedAt),
          isStale: cached.isStale,
        );
        return;
      }
      Error.throwWithStackTrace(
        NetworkExceptions.toFailure(error, stackTrace),
        stackTrace,
      );
    }
  }

  /// One-shot convenience: the freshest value the layers can give right now.
  Future<T> get<T>(
    ApiRequest request,
    T Function(Object? json) decode, {
    bool forceRefresh = false,
  }) async {
    CachedResult<T>? last;
    await for (final result in fetch(
      request,
      decode,
      forceRefresh: forceRefresh,
    )) {
      last = result;
      // Offline, the stream holds the saved copy open until the connection
      // returns (up to 30 minutes). A one-shot read wants it now: waiting
      // left the family names on Records and the detail screens blank while
      // offline (BL-CACHE-008, BL-CACHE-010).
      if (!_connectivity.isOnline && result.source != CacheSource.network) {
        break;
      }
    }
    if (last == null) {
      throw _connectivity.hasRoute
          ? const NetworkFailure.unreachable()
          : const NetworkFailure();
    }
    return last.value;
  }

  Future<CachedResult<T>> _fromNetwork<T>(
    ApiRequest request,
    String key,
    T Function(Object? json) decode, {
    String? etag,
    CacheEntry? previous,
    required bool withRetry,
  }) async {
    Future<ApiResponse> call() =>
        _client.send(request.copyWith(ifNoneMatch: etag));
    final ApiResponse response;
    try {
      response = withRetry ? await _retry.execute(call) : await call();
    } on HttpStatusException catch (error) {
      if (error.statusCode != 412 || etag == null) rethrow;
      // Scenario 6: 412 Precondition Failed — the cache is out of step with
      // the server. Drop the entry and ask again without the ETag.
      AppLogger.warning(
        '412 for $key; refetching unconditionally',
        name: 'cache',
      );
      _dropEntry(key);
      final full = await _client.send(request);
      return _store_(key, full, decode, DateTime.now());
    }
    final now = DateTime.now();

    if (response.isNotModified && previous != null) {
      // Scenario 6: 304 — re-stamp, keep body and ETag.
      final fresh = previous.revalidated(now);
      _writeMemory(key, fresh);
      _writeHive(key, fresh);
      return CachedResult<T>(
        value: decode(jsonDecode(fresh.data)),
        source: CacheSource.network,
        cachedAt: now,
      );
    }
    if (response.isNotModified) {
      // 304 with nothing to revalidate against: the ETag came from a dropped
      // entry. Fetch unconditionally.
      final full = await _client.send(request);
      return _store_(key, full, decode, now);
    }
    if (!response.isSuccess) {
      throw HttpStatusException(
        statusCode: response.statusCode,
        message: 'unexpected ${response.statusCode} for $request',
      );
    }
    return _store_(key, response, decode, now);
  }

  CachedResult<T> _store_<T>(
    String key,
    ApiResponse response,
    T Function(Object? json) decode,
    DateTime now,
  ) {
    // Scenario 10: validate before caching — status (checked by the
    // caller), Content-Type, then the decode (schema and required fields).
    // Any failure throws and nothing is written.
    final type = response.headers['content-type'];
    if (type != null && !type.toLowerCase().contains('json')) {
      throw ResponseFormatException(
        message: 'expected JSON, got "$type" for $key',
      );
    }
    final value = decode(response.data);
    final body = jsonEncode(response.data);
    if (!_isQuarantined(key)) {
      final entry = CacheEntry(
        key: key,
        data: body,
        etag: response.etag,
        cachedAt: now.millisecondsSinceEpoch,
        lastAccessed: now.millisecondsSinceEpoch,
        accessCount: 1,
        size: body.length * 2,
      );
      _writeMemory(key, entry);
      _writeHive(key, entry);
    }
    return CachedResult<T>(
      value: value,
      source: CacheSource.network,
      cachedAt: now,
    );
  }

  // ---- L1 ----

  CacheEntry? _readMemory(String key, DateTime now) {
    final entry = _memory[key];
    if (entry == null) return null;
    final touched = entry.touched(now);
    _memory[key] = touched;
    return touched;
  }

  void _writeMemory(String key, CacheEntry entry) {
    final old = _memory.remove(key);
    if (old != null) _memoryBytes -= old.size;
    _memory[key] = entry;
    _memoryBytes += entry.size;
    // Scenario 8: LRU eviction on every write.
    while (_memory.length > CacheConfig.memoryCacheMaxEntries ||
        _memoryBytes > CacheConfig.memoryCacheMaxBytes) {
      final oldestKey = _memory.entries
          .reduce(
            (a, b) => a.value.lastAccessed <= b.value.lastAccessed ? a : b,
          )
          .key;
      final evicted = _memory.remove(oldestKey);
      if (evicted != null) _memoryBytes -= evicted.size;
    }
  }

  // ---- L2 ----

  CacheEntry? _readHive(String key, DateTime now) {
    if (_isQuarantined(key)) return null;
    try {
      final raw = _local.read(HiveBoxes.httpCache, key);
      if (raw is! CacheEntry) return null;
      final touched = raw.touched(now);
      _writeMemory(key, touched);
      unawaited(_local.write(HiveBoxes.httpCache, key, touched));
      return touched;
    } on CacheFailure catch (failure) {
      // Scenario 9: the store already deleted the entry; quarantine the key.
      if (failure.isCorruption) _recordStrike(key, now);
      return null;
    } catch (error) {
      AppLogger.warning('Hive read failed', name: 'cache', error: error);
      return null;
    }
  }

  void _writeHive(String key, CacheEntry entry) {
    // Async and non-blocking (Scenario 1 step 8). Failures are logged inside
    // the store.
    unawaited(_local.write(HiveBoxes.httpCache, key, entry));
  }

  void _dropEntry(String key) {
    final old = _memory.remove(key);
    if (old != null) _memoryBytes -= old.size;
    unawaited(_local.delete(HiveBoxes.httpCache, key));
    _paths.remove(key);
    unawaited(_local.delete(HiveBoxes.cacheMeta, _pathMetaKey(key)));
  }

  // ---- Key → path ----

  void _rememberPath(String key, String path) {
    if (_paths[key] == path) return;
    _paths[key] = path;
    unawaited(_local.write(HiveBoxes.cacheMeta, _pathMetaKey(key), path));
  }

  String? _pathOf(String key) {
    final known = _paths[key];
    if (known != null) return known;
    try {
      final stored = _local.read(HiveBoxes.cacheMeta, _pathMetaKey(key));
      if (stored is String) return _paths[key] = stored;
    } catch (error) {
      AppLogger.warning('Cache path read failed', name: 'cache', error: error);
    }
    return null;
  }

  /// The keys held in [box], where the store can list them.
  Iterable<String> _keysOf(String box) {
    final store = _local;
    return store is HiveLocalStore
        ? store.keys(box)
        : store is InMemoryLocalStore
        ? store.keys(box)
        : const <String>[];
  }

  // ---- Scenario 9 bookkeeping ----

  bool _isQuarantined(String key) {
    final until = _quarantined[key];
    if (until == null) return false;
    if (until.isAfter(DateTime.now())) return true;
    _quarantined.remove(key);
    return false;
  }

  void _recordStrike(String key, DateTime now) {
    _quarantined[key] = now.add(CacheConfig.corruptionQuarantine);
    final strikes = _strikes.putIfAbsent(key, () => <DateTime>[])
      ..add(now)
      ..removeWhere((t) => now.difference(t) > const Duration(hours: 1));
    if (strikes.length >= CacheConfig.corruptionStrikeLimit) {
      // Three strikes in an hour: stop caching this key for a while.
      _quarantined[key] = now.add(const Duration(hours: 1));
      AppLogger.warning(
        'Cache key corrupted ${strikes.length}× in an hour; not caching',
        name: 'cache',
      );
    }
  }

  // ---- Scenario 8: size monitor ----

  Future<void> _sweep() async {
    try {
      if (!await HiveInit.needsEviction()) return;
      final store = _local;
      final keys = _keysOf(HiveBoxes.httpCache).toList();
      final entries = <CacheEntry>[
        for (final key in keys)
          if (store.read(HiveBoxes.httpCache, key) case final CacheEntry e) e,
      ]..sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));
      final dropCount = (entries.length * CacheConfig.hiveEvictionFraction)
          .ceil();
      for (final entry in entries.take(dropCount)) {
        _dropEntry(entry.key);
      }
      if (store is HiveLocalStore) await store.compact();
      await store.write(
        HiveBoxes.cacheMeta,
        HiveKeys.lastEvictionSweepAt,
        DateTime.now().millisecondsSinceEpoch,
      );
      AppLogger.info('Evicted $dropCount cache entries', name: 'cache');
    } catch (error) {
      AppLogger.warning('Cache sweep failed', name: 'cache', error: error);
    }
  }

  /// Forget every cached response whose path starts with [pathPrefix] — call
  /// after a mutation so the next read is fresh. With no prefix, everything
  /// goes (sign-out).
  Future<void> invalidate({String? pathPrefix}) async {
    if (pathPrefix == null) {
      _memory.clear();
      _memoryBytes = 0;
      _pool.clear();
      await _local.clearBox(HiveBoxes.httpCache);
      return;
    }
    // Keys are hashes, so a prefix cannot be matched against them; the
    // pragmatic answer for a mutation is to clear the response cache. It is
    // small (GET bodies only) and rebuilds from ETags at 304 cost.
    _memory.clear();
    _memoryBytes = 0;
    await _local.clearBox(HiveBoxes.httpCache);
  }

  /// Forget only the cached responses a mutation made out of date: those for
  /// exactly one of [paths] (any query), and those at or under one of
  /// [under]. Everything else keeps its copy and its ETag, so other screens
  /// still open offline and revalidate at 304 cost. An entry whose path is
  /// not known is dropped too, to be safe.
  ///
  /// [invalidate] with a prefix clears the whole cache; this is the narrow
  /// form. A profile save used to wipe every list in the app and refetch
  /// each one in full (Edit Profile audit, 7 Oct 2026).
  Future<void> invalidatePaths({
    Set<String> paths = const <String>{},
    Set<String> under = const <String>{},
  }) async {
    bool stale(String key) {
      final path = _pathOf(key);
      if (path == null) return true;
      return paths.contains(path) ||
          under.any((p) => path == p || path.startsWith('$p/'));
    }

    final keys = {..._memory.keys, ..._keysOf(HiveBoxes.httpCache)};
    for (final key in keys) {
      if (stale(key)) _dropEntry(key);
    }
  }

  void dispose() => _monitor.cancel();
}

/// The process-wide fetcher. Overridden in bootstrap with the real client.
final cachedFetcherProvider = Provider<CachedFetcher>((ref) {
  throw UnimplementedError(
    'cachedFetcherProvider must be overridden in app_bootstrap.dart',
  );
});
