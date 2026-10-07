import 'dart:async';
import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/bootstrap/hive_init.dart';
import '../error/failure.dart';
import '../utils/logger.dart';
import 'hive/adapters/cache_entry_adapter.dart';
import 'hive/boxes.dart';

/// A tiny async mutex, so box opening is serialised (HIVE spec, "Thread
/// Safety": one Hive instance, one open per box).
class _Lock {
  Future<void> _last = Future<void>.value();

  Future<T> synchronized<T>(Future<T> Function() action) {
    final previous = _last;
    final completer = Completer<void>();
    _last = completer.future;
    return previous.then((_) => action()).whenComplete(completer.complete);
  }
}

/// The production [LocalStore]: Hive boxes on disk.
///
/// This is the **only** file that opens a Hive box. Every adapter is
/// registered in [open] before the first box is touched (QA Prompt 2 §17,
/// Prompt 6 §3), and every box is opened through [_box], which holds a lock so
/// two callers cannot race to open the same box twice.
///
/// Write failures are counted; after [CacheConfig.writeFailureLimit]
/// consecutive failures Hive is disabled for the session and reads fall
/// through to the network (Scenario 9). Read failures on a corrupt entry
/// delete that entry and rethrow as a [CacheFailure] with `isCorruption`, so
/// the cache layer can quarantine the key.
class HiveLocalStore implements LocalStore {
  /// [encryptionKey] supplies the 32-byte AES key every box is opened with:
  /// patient names, phone numbers and cached health data must not sit in
  /// readable files (QA Prompt 2; CL SEC-005 found them in plain text).
  /// Null (tests) leaves the boxes unencrypted.
  HiveLocalStore({Future<List<int>> Function()? encryptionKey})
    : _encryptionKey = encryptionKey;

  final Future<List<int>> Function()? _encryptionKey;
  HiveAesCipher? _cipher;

  final _Lock _lock = _Lock();
  final Map<String, Box<Object?>> _boxes = <String, Box<Object?>>{};
  int _consecutiveWriteFailures = 0;
  bool _disabled = false;
  bool _initialised = false;

  /// True once too many writes have failed and Hive was switched off.
  bool get isDisabled => _disabled;

  @override
  Future<void> open() async {
    if (!_initialised) {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(HiveTypeIds.cacheEntry)) {
        Hive.registerAdapter(CacheEntryAdapter());
      }
      final key = await _encryptionKey?.call();
      if (key != null) _cipher = HiveAesCipher(key);
      _initialised = true;
    }
    for (final name in HiveBoxes.all) {
      await _box(name);
    }
  }

  Future<Box<Object?>> _box(String name) => _lock.synchronized(() async {
    final existing = _boxes[name];
    if (existing != null && existing.isOpen) return existing;
    try {
      final box = await Hive.openBox<Object?>(name, encryptionCipher: _cipher);
      _boxes[name] = box;
      return box;
    } on HiveError catch (error) {
      // A box that will not open is corrupt beyond repair: drop it and start
      // clean rather than refusing to run (Scenario 9).
      AppLogger.error(
        'Box "$name" failed to open; deleting it',
        name: 'storage',
        error: error,
      );
      await Hive.deleteBoxFromDisk(name);
      final box = await Hive.openBox<Object?>(name, encryptionCipher: _cipher);
      _boxes[name] = box;
      return box;
    }
  });

  @override
  Object? read(String box, String key) {
    if (_disabled) return null;
    final opened = _boxes[box];
    if (opened == null || !opened.isOpen) return null;
    try {
      return opened.get(key);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Corrupt entry $box/$key — deleting',
        name: 'storage',
        error: error,
      );
      unawaited(opened.delete(key));
      throw CacheFailure(
        cacheKey: key,
        isCorruption: true,
        debugMessage: 'hive read $box/$key',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> write(String box, String key, Object? value) async {
    if (_disabled) return;
    try {
      final opened = await _box(box);
      if (value == null) {
        await opened.delete(key);
      } else {
        await opened.put(key, value);
      }
      _consecutiveWriteFailures = 0;
    } catch (error) {
      // Scenario 9: log, never block the UI, count towards the disable limit.
      _consecutiveWriteFailures++;
      AppLogger.warning(
        'Hive write failed ($_consecutiveWriteFailures in a row) $box/$key',
        name: 'storage',
        error: error,
      );
      if (_consecutiveWriteFailures >= CacheConfig.writeFailureLimit) {
        _disabled = true;
        AppLogger.error(
          'Hive disabled for this session after '
          '${CacheConfig.writeFailureLimit} consecutive write failures',
          name: 'storage',
        );
      }
    }
  }

  @override
  Future<void> delete(String box, String key) => write(box, key, null);

  @override
  Future<void> clearBox(String box) async {
    if (_disabled) return;
    try {
      final opened = await _box(box);
      await opened.clear();
    } catch (error) {
      AppLogger.warning('Could not clear $box', name: 'storage', error: error);
    }
  }

  /// Every key in [box] — for the LRU sweep.
  Iterable<String> keys(String box) {
    final opened = _boxes[box];
    if (opened == null || !opened.isOpen) return const <String>[];
    return opened.keys.whereType<String>();
  }

  @override
  Future<int> sizeInBytes() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      var total = 0;
      for (final name in HiveBoxes.all) {
        final file = File('${dir.path}/$name.hive');
        if (await file.exists()) total += await file.length();
      }
      return total;
    } catch (error) {
      AppLogger.warning('Size check failed', name: 'storage', error: error);
      return 0;
    }
  }

  /// Rewrite every evictable box without its dead entries (Scenario 8).
  Future<void> compact() async {
    for (final name in HiveBoxes.evictable) {
      final opened = _boxes[name];
      if (opened != null && opened.isOpen) await opened.compact();
    }
  }

  @override
  Future<void> close() async {
    for (final box in _boxes.values) {
      if (box.isOpen) await box.close();
    }
    _boxes.clear();
  }
}
