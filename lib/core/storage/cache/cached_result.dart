/// Plain-Dart value types shared by the domain contracts and the cache
/// (CL CODE-014): no Flutter, Riverpod, Hive or Dio here.
library;

/// Where a [CachedResult] came from, so the screen can render the right
/// affordance (skeleton / "updating…" / amber stale bar / offline icon).
enum CacheSource { memory, hive, network }

/// A decoded response plus the freshness facts the HIVE scenarios need.
class CachedResult<T> {
  const CachedResult({
    required this.value,
    required this.source,
    required this.cachedAt,
    this.isStale = false,
    this.revalidating = false,
  });

  final T value;
  final CacheSource source;

  /// When the underlying body was fetched.
  final DateTime cachedAt;

  /// Older than `CacheConfig.staleCacheThreshold` — show the amber bar.
  final bool isStale;

  /// A background network revalidation is running — show "updating…".
  final bool revalidating;

  CachedResult<T> copyWith({bool? revalidating}) => CachedResult<T>(
    value: value,
    source: source,
    cachedAt: cachedAt,
    isStale: isStale,
    revalidating: revalidating ?? this.revalidating,
  );
}
