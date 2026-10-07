import 'hive/boxes.dart';

/// The key-value contract every local data source writes through.
///
/// Two implementations: [InMemoryLocalStore] (tests, provider default) and
/// `HiveLocalStore` (`core/storage/hive_local_store.dart`, production). The
/// interface lives in core so that `infrastructure/local/` data sources never
/// import from `app/`.
abstract interface class LocalStore {
  /// Open every box in [HiveBoxes.all] and register adapters.
  Future<void> open();

  /// Read a value from [box]. May throw a `CacheFailure(isCorruption: true)`
  /// after deleting an unreadable entry (HIVE spec, Scenario 9).
  Object? read(String box, String key);

  /// Write a value into [box]. Cache writes are fire-and-forget by design —
  /// a failure must never block the UI (HIVE spec, Scenario 1).
  Future<void> write(String box, String key, Object? value);

  /// Delete one key.
  Future<void> delete(String box, String key);

  /// Empty one box.
  Future<void> clearBox(String box);

  /// Approximate on-disk size in bytes, for the LRU/size monitor
  /// ([CacheConfig.hiveEvictionThreshold]).
  Future<int> sizeInBytes();

  /// Flush and release handles.
  Future<void> close();
}

/// The default [LocalStore]: an in-process map.
///
/// Satisfies the contract exactly, so caching code can be tested without
/// touching disk; nothing survives a restart.
class InMemoryLocalStore implements LocalStore {
  final Map<String, Map<String, Object?>> _boxes =
      <String, Map<String, Object?>>{};

  @override
  Future<void> open() async {
    for (final box in HiveBoxes.all) {
      _boxes.putIfAbsent(box, () => <String, Object?>{});
    }
  }

  Map<String, Object?> _box(String name) =>
      _boxes.putIfAbsent(name, () => <String, Object?>{});

  @override
  Object? read(String box, String key) => _box(box)[key];

  @override
  Future<void> write(String box, String key, Object? value) async {
    if (value == null) {
      _box(box).remove(key);
      return;
    }
    _box(box)[key] = value;
  }

  @override
  Future<void> delete(String box, String key) async => _box(box).remove(key);

  @override
  Future<void> clearBox(String box) async => _box(box).clear();

  /// Every key in [box] — for the LRU sweep.
  Iterable<String> keys(String box) => _box(box).keys;

  @override
  Future<int> sizeInBytes() async {
    // Entry count is the only honest proxy without a real encoder; the real
    // implementation reports the box files' size.
    return _boxes.values.fold<int>(0, (sum, box) => sum + box.length);
  }

  @override
  Future<void> close() async => _boxes.clear();
}
