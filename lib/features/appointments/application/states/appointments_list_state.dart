import '../../../../core/error/failure.dart';
import '../../../../core/storage/cache/cached_fetcher.dart' show CacheSource;
import '../../domain/entities/appointment.dart';

/// One paginated appointments list (§10.1) plus the freshness facts the HIVE
/// scenarios render: where the rows came from, whether they are stale, and
/// whether a background revalidation is running.
///
/// Immutable; every update goes through [copyWith].
class AppointmentsListState {
  const AppointmentsListState({
    this.items = const <Appointment>[],
    this.page = 0,
    this.hasNext = false,
    this.total = 0,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.revalidating = false,
    this.isStale = false,
    this.source,
    this.cachedAt,
    this.failure,
    this.loadMoreFailure,
  });

  /// Every row loaded so far, in server order.
  final List<Appointment> items;

  /// The last page appended (0 before anything has loaded).
  final int page;
  final bool hasNext;

  /// Server-side total for the query — the "n visits" count.
  final int total;

  /// True until the first answer (cache or network) — the skeleton state.
  final bool isLoading;

  /// True while the next page is being appended.
  final bool isLoadingMore;

  /// True while a cached first page is being revalidated — "updating…".
  final bool revalidating;

  /// The rows are older than the stale threshold — the amber bar.
  final bool isStale;

  final CacheSource? source;
  final DateTime? cachedAt;

  /// The first page could not be loaded at all (nothing cached either).
  final Failure? failure;

  /// Appending the next page failed; the rows already shown stay.
  final Failure? loadMoreFailure;

  bool get isEmpty => !isLoading && items.isEmpty && failure == null;

  /// Rows exist but the last revalidation failed — shown as a banner over
  /// the (possibly stale) list rather than an error screen.
  bool get hasRowsAndFailure => items.isNotEmpty && failure != null;

  /// A first page has been shown (from the cache or the server), even an
  /// empty one. A failed refresh then keeps it — "Nothing here yet" stays a
  /// fact about the saved list, with the offline line above it — instead of
  /// replacing it with an error screen (CL E2E-009).
  bool get hasLoadedPage => page > 0;

  AppointmentsListState copyWith({
    List<Appointment>? items,
    int? page,
    bool? hasNext,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    bool? revalidating,
    bool? isStale,
    CacheSource? source,
    DateTime? cachedAt,
    Failure? failure,
    bool clearFailure = false,
    Failure? loadMoreFailure,
    bool clearLoadMoreFailure = false,
  }) {
    return AppointmentsListState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      revalidating: revalidating ?? this.revalidating,
      isStale: isStale ?? this.isStale,
      source: source ?? this.source,
      cachedAt: cachedAt ?? this.cachedAt,
      failure: clearFailure ? null : (failure ?? this.failure),
      loadMoreFailure: clearLoadMoreFailure
          ? null
          : (loadMoreFailure ?? this.loadMoreFailure),
    );
  }
}
