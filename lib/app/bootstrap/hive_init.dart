import 'dart:async';

import '../../core/error/failure.dart';
import '../../core/storage/hive/boxes.dart';
import '../../core/utils/logger.dart';

/// Opens and closes the app's local storage, and is the **only** place boxes
/// are named at runtime.
///
/// Coding Standards §3.1 asks for one central place to add or remove boxes
/// safely; that is [HiveBoxes.all] plus this initialiser. Because `hive` and
/// `hive_flutter` are not dependencies of this presentation-layer build (see
/// `pubspec.yaml`), the concrete work lives behind [LocalStore] and the app
/// currently runs on [InMemoryLocalStore]. When Hive lands, `HiveLocalStore`
/// implements the same interface — registering adapters with the typeIds
/// already allocated in [HiveTypeIds] — and this file's public surface does
/// not change.
///
/// Wired from `bootstrap()`:
///
/// ```dart
/// await HiveInit.open();
/// ```
abstract interface class LocalStore {
  /// Open every box in [HiveBoxes.all] and register adapters.
  Future<void> open();

  /// Read a value from [box].
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
/// Honest stand-in rather than a lie — it satisfies the contract, so caching
/// code can be written and tested now, but nothing survives a restart, which
/// means no code can come to depend on persistence that this build does not
/// actually have.
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

  @override
  Future<int> sizeInBytes() async {
    // Entry count is the only honest proxy without a real encoder; the real
    // implementation reports the box files' size.
    return _boxes.values.fold<int>(0, (sum, box) => sum + box.length);
  }

  @override
  Future<void> close() async => _boxes.clear();
}

/// Local-storage lifecycle.
abstract final class HiveInit {
  HiveInit._();

  /// The active store. Replace during bootstrap, before [open].
  static LocalStore store = InMemoryLocalStore();

  static bool _opened = false;

  /// True once [open] has completed successfully.
  static bool get isOpen => _opened;

  /// Open every box.
  ///
  /// Never throws: local storage is a cache, and an app that refuses to start
  /// because a cache would not open is worse than one that runs without it
  /// (HIVE spec, Scenario 9 — "disable Hive, show warning"). The failure is
  /// logged and returned as a [CacheFailure] for the caller to surface if it
  /// wants to.
  static Future<CacheFailure?> open() async {
    if (_opened) return null;
    try {
      await store.open();
      _opened = true;
      AppLogger.info(
        'Local storage ready (${HiveBoxes.all.length} boxes)',
        name: 'storage',
      );
      return null;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Local storage failed to open — running network-only',
        name: 'storage',
        error: error,
        stackTrace: stackTrace,
      );
      return CacheFailure(
        userMessage:
            'Offline data is unavailable on this device. The app will '
            'keep working but will need a connection.',
        debugMessage: 'LocalStore.open failed',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Drop every cache box, keeping session and settings
  /// ([HiveBoxes.evictable]). Used by "clear cache" and corruption recovery.
  static Future<void> clearCaches() async {
    for (final box in HiveBoxes.evictable) {
      await store.clearBox(box);
    }
    AppLogger.info('Cache boxes cleared', name: 'storage');
  }

  /// Drop everything a signed-out user must not leave behind
  /// ([HiveBoxes.clearedOnLogout]).
  ///
  /// This is the local-storage half of CM-53 ("logout clears session"); the
  /// credential half is `SecureStore.deleteAll`. `AuthNotifier.logout` calls
  /// both.
  static Future<void> clearOnLogout() async {
    for (final box in HiveBoxes.clearedOnLogout) {
      await store.clearBox(box);
    }
    AppLogger.info('Session boxes cleared on logout', name: 'storage');
  }

  /// Whether the cache has grown past its eviction threshold
  /// ([CacheConfig.hiveEvictionThreshold]).
  static Future<bool> needsEviction() async {
    final size = await store.sizeInBytes();
    return size >
        CacheConfig.hiveCacheMaxBytes * CacheConfig.hiveEvictionThreshold;
  }

  /// Close boxes (tests, and a clean shutdown).
  static Future<void> close() async {
    if (!_opened) return;
    await store.close();
    _opened = false;
  }
}
