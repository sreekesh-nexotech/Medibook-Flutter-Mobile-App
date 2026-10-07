import 'package:flutter/foundation.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/storage/cache/cached_fetcher.dart';

/// The screen-facing shape of one cached read (`CachedFetcher.fetch`).
///
/// Carries the HIVE-spec affordances a screen renders (`docs-flutter/HIVE
/// implementation.md`): a skeleton while nothing is known yet, the value plus
/// an "updating…" hint while a background revalidation runs, an amber bar when
/// the copy is older than 24 h, and the last failure *beside* the data rather
/// than instead of it — a list that was on screen a second ago must not be
/// replaced by an error card because the refresh timed out.
///
/// Immutable; every update goes through [copyWith] or [withResult].
@immutable
class CachedState<T> {
  const CachedState({
    this.value,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isStale = false,
    this.source,
    this.cachedAt,
    this.failure,
  });

  /// Nothing known yet, first load in flight.
  const CachedState.loading()
    : value = null,
      isLoading = true,
      isRefreshing = false,
      isStale = false,
      source = null,
      cachedAt = null,
      failure = null;

  /// The decoded value, or null before the first answer.
  final T? value;

  /// True while there is no [value] yet and a load is running — skeleton.
  final bool isLoading;

  /// True while a [value] is shown and a network revalidation is running —
  /// the quiet "updating…" indicator.
  final bool isRefreshing;

  /// The shown [value] is older than the stale threshold — amber bar.
  final bool isStale;

  final CacheSource? source;
  final DateTime? cachedAt;

  /// The most recent failure. Non-null with a [value] means "showing what we
  /// have; the refresh failed"; non-null without one is the full error state.
  final Failure? failure;

  bool get hasValue => value != null;

  /// The full-screen error case: nothing to show and the load failed.
  bool get isError => value == null && failure != null;

  /// True when the value came straight from the network on this read.
  bool get isFresh => source == CacheSource.network;

  CachedState<T> copyWith({
    T? value,
    bool? isLoading,
    bool? isRefreshing,
    bool? isStale,
    CacheSource? source,
    DateTime? cachedAt,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return CachedState<T>(
      value: value ?? this.value,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isStale: isStale ?? this.isStale,
      source: source ?? this.source,
      cachedAt: cachedAt ?? this.cachedAt,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  /// The state after one [CachedResult] arrives from the fetcher.
  CachedState<T> withResult(CachedResult<T> result) => CachedState<T>(
    value: result.value,
    isLoading: false,
    isRefreshing: result.revalidating,
    isStale: result.isStale,
    source: result.source,
    cachedAt: result.cachedAt,
  );

  /// The state after a locally-known replacement (a mutation that returned
  /// the new row) — fresh, not stale, nothing running.
  CachedState<T> withValue(T next) => CachedState<T>(
    value: next,
    source: CacheSource.network,
    cachedAt: DateTime.now(),
  );

  @override
  bool operator ==(Object other) =>
      other is CachedState<T> &&
      other.value == value &&
      other.isLoading == isLoading &&
      other.isRefreshing == isRefreshing &&
      other.isStale == isStale &&
      other.source == source &&
      other.cachedAt == cachedAt &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(
    value,
    isLoading,
    isRefreshing,
    isStale,
    source,
    cachedAt,
    failure,
  );

  @override
  String toString() =>
      'CachedState<$T>(loading: $isLoading, refreshing: $isRefreshing, '
      'stale: $isStale, source: $source, failure: ${failure?.code})';
}
