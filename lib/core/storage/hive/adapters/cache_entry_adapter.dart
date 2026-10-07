import 'package:hive/hive.dart';

import '../boxes.dart';

/// One cached HTTP response (`docs-flutter/HIVE implementation.md`,
/// "CacheEntry Model").
///
/// [data] is the JSON body **as a string**: Hive stores it as one opaque
/// value, so a model change can never make an old entry undecodable at the
/// Hive layer — the JSON decode happens (and can fail cleanly) above it.
///
/// [etag] takes the place of the spec's `lastModified`: this backend sends
/// `ETag` and honours `If-None-Match` but sends no `Last-Modified`
/// (`FLUTTER_API_INTEGRATION.md` §1.10), so the conditional request carries
/// the ETag. The rules are identical — sent on every request, replaced only on
/// a 200, untouched on a 304.
///
/// Field indices are frozen: never renumber a `@HiveField` once shipped
/// (QA Prompt 6, Hive model integrity).
@HiveType(typeId: HiveTypeIds.cacheEntry)
class CacheEntry {
  const CacheEntry({
    required this.key,
    required this.data,
    required this.cachedAt,
    required this.lastAccessed,
    required this.accessCount,
    required this.size,
    this.etag,
  });

  @HiveField(0)
  final String key;

  @HiveField(1)
  final String data;

  @HiveField(2)
  final String? etag;

  /// Epoch millis when the body was written.
  @HiveField(3)
  final int cachedAt;

  /// Epoch millis of the last read — the LRU sort key.
  @HiveField(4)
  final int lastAccessed;

  @HiveField(5)
  final int accessCount;

  /// Size of [data] in bytes (UTF-16 code units × 2 is close enough for the
  /// size monitor; exactness is not the point).
  @HiveField(6)
  final int size;

  Duration ageAt(DateTime now) =>
      now.difference(DateTime.fromMillisecondsSinceEpoch(cachedAt));

  /// Newer than [CacheConfig.validCacheThreshold]: serve and revalidate in
  /// the background.
  bool get isValid =>
      DateTime.now().millisecondsSinceEpoch - cachedAt <
      CacheConfig.validCacheThreshold.inMilliseconds;

  /// Older than [CacheConfig.staleCacheThreshold]: serve with the amber bar.
  bool get isStale =>
      DateTime.now().millisecondsSinceEpoch - cachedAt >
      CacheConfig.staleCacheThreshold.inMilliseconds;

  CacheEntry touched(DateTime now) => CacheEntry(
    key: key,
    data: data,
    etag: etag,
    cachedAt: cachedAt,
    lastAccessed: now.millisecondsSinceEpoch,
    accessCount: accessCount + 1,
    size: size,
  );

  /// The entry re-stamped as fresh after a 304 — body and ETag untouched
  /// (Scenario 6: "DON'T update Last-Modified on 304").
  CacheEntry revalidated(DateTime now) => CacheEntry(
    key: key,
    data: data,
    etag: etag,
    cachedAt: now.millisecondsSinceEpoch,
    lastAccessed: now.millisecondsSinceEpoch,
    accessCount: accessCount,
    size: size,
  );
}

/// Hand-written adapter, so the project needs no `build_runner` step and the
/// field numbering is visible in one place.
class CacheEntryAdapter extends TypeAdapter<CacheEntry> {
  @override
  int get typeId => HiveTypeIds.cacheEntry;

  @override
  CacheEntry read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, Object?>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };
    return CacheEntry(
      key: fields[0] as String,
      data: fields[1] as String,
      etag: fields[2] as String?,
      cachedAt: fields[3] as int,
      lastAccessed: fields[4] as int,
      accessCount: fields[5] as int,
      size: fields[6] as int,
    );
  }

  @override
  void write(BinaryWriter writer, CacheEntry obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.key)
      ..writeByte(1)
      ..write(obj.data)
      ..writeByte(2)
      ..write(obj.etag)
      ..writeByte(3)
      ..write(obj.cachedAt)
      ..writeByte(4)
      ..write(obj.lastAccessed)
      ..writeByte(5)
      ..write(obj.accessCount)
      ..writeByte(6)
      ..write(obj.size);
  }
}
