/// One page of a list endpoint, as the domain sees it
/// (`FLUTTER_API_INTEGRATION.md` §1.6).
///
/// The transport-level `Page<T>` in `core/network/api_client.dart` is mapped
/// onto this in each feature's repository, so the domain and application
/// layers never import the HTTP client.
class Paged<T> {
  const Paged({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasNext,
  });

  const Paged.empty()
    : items = const [],
      page = 1,
      pageSize = 0,
      total = 0,
      hasNext = false;

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;
  final bool hasNext;

  bool get isEmpty => items.isEmpty;

  /// This page followed by [next] — the shape an infinite-scrolling list
  /// keeps in its state.
  Paged<T> append(Paged<T> next) => Paged<T>(
    items: [...items, ...next.items],
    page: next.page,
    pageSize: next.pageSize,
    total: next.total,
    hasNext: next.hasNext,
  );

  Paged<R> map<R>(R Function(T item) convert) => Paged<R>(
    items: [for (final item in items) convert(item)],
    page: page,
    pageSize: pageSize,
    total: total,
    hasNext: hasNext,
  );
}

/// A value plus the freshness facts the HIVE scenarios ask the UI to render:
/// skeleton (no value yet), "updating…" ([revalidating]), the amber bar
/// ([isStale]) and the offline copy ([fromCache]).
///
/// The cache layer's `CachedResult` is mapped onto this by repositories so
/// nothing above infrastructure imports the cache implementation.
class Snapshot<T> {
  const Snapshot({
    required this.value,
    required this.cachedAt,
    this.fromCache = false,
    this.isStale = false,
    this.revalidating = false,
  });

  final T value;

  /// When the underlying response was fetched from the network.
  final DateTime cachedAt;

  /// True when [value] came from memory or Hive rather than the network.
  final bool fromCache;

  /// Older than the stale threshold (24 h) — show the amber "tap to refresh".
  final bool isStale;

  /// A background network revalidation is running — show "updating…".
  final bool revalidating;

  Snapshot<R> map<R>(R Function(T value) convert) => Snapshot<R>(
    value: convert(value),
    cachedAt: cachedAt,
    fromCache: fromCache,
    isStale: isStale,
    revalidating: revalidating,
  );
}
