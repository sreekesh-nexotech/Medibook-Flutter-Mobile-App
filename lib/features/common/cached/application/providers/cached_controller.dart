import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/storage/cache/cached_fetcher.dart';
import '../../../../../core/utils/logger.dart';
import '../states/cached_state.dart';

/// The producer a [CachedController] reads from: a repository method that
/// returns the fetcher's cached-first-then-network stream.
typedef CachedLoader<T> =
    Stream<CachedResult<T>> Function({required bool forceRefresh});

/// A read-only [StateNotifier] over one cached GET.
///
/// The fetcher's stream yields the cached copy first (if any) and the network
/// copy second; this controller folds those into a [CachedState] and keeps a
/// previous value on screen when a refresh fails (HIVE Scenario 2/5 error
/// path). It owns the subscription, so a stream parked on the connectivity
/// monitor's reconnect wait (Scenario 3) is cancelled with the screen.
///
/// Repositories are the only place that knows the endpoint; the loader is
/// injected, so the same controller serves persons, addresses, tickets, the
/// FAQ and the app config, and a test can drive it with a synthetic stream.
class CachedController<T> extends StateNotifier<CachedState<T>> {
  CachedController(
    this._load, {
    bool loadImmediately = true,
    void Function(T value)? onValue,
    Stream<void>? reconnects,
  }) : _onValue = onValue,
       super(CachedState<T>.loading()) {
    _reconnects = reconnects?.listen((_) => reloadIfFailed());
    if (loadImmediately) unawaited(refresh());
  }

  final CachedLoader<T> _load;

  /// The connectivity monitor's reconnects, when the provider passes them: a
  /// failed read loads once more when the network returns (HIVE Scenario 3).
  StreamSubscription<void>? _reconnects;

  /// Called with every new value (cache hit, network answer or a local
  /// replacement) — for a derived side effect such as publishing the "self"
  /// person id to the session. Never for UI.
  final void Function(T value)? _onValue;
  StreamSubscription<CachedResult<T>>? _subscription;

  /// The refresh currently awaited, released on dispose so a caller
  /// (pull-to-refresh) never hangs on a screen that has gone.
  Completer<void>? _pending;

  @override
  set state(CachedState<T> next) {
    final previous = super.state;
    super.state = next;
    final value = next.value;
    if (value != null && !identical(value, previous.value)) {
      _onValue?.call(value);
    }
  }

  /// Runs the loader. With [force] the first answer skips the cache
  /// (pull-to-refresh / "tap to refresh"); the fetcher still sends the ETag.
  ///
  /// Concurrent calls collapse: a refresh already running is left to finish.
  Future<void> refresh({bool force = false}) async {
    if (state.isLoading && _subscription != null) return;
    if (state.isRefreshing && !force) return;
    // Not awaited: offline, the stream being replaced is parked until the
    // network returns and would finish cancelling only then — the
    // pull-to-refresh spinner turned until the connection was back. A
    // cancelled subscription delivers nothing more.
    unawaited(_subscription?.cancel());
    // The refresh this one replaces is over for whoever awaited it (a
    // pull-to-refresh spinner, when "Tap to refresh" is tapped under it).
    final replaced = _pending;
    if (replaced != null && !replaced.isCompleted) replaced.complete();

    state = state.hasValue
        ? state.copyWith(isRefreshing: true, clearFailure: true)
        : CachedState<T>.loading();

    // Completed from onError / onDone below — never via `asFuture`, which
    // would replace those handlers.
    final done = Completer<void>();
    _pending = done;
    _subscription = _load(forceRefresh: force).listen(
      (result) {
        if (!mounted) return;
        state = state.withResult(result);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (mounted) {
          final failure = error.asFailure(stackTrace);
          AppLogger.warning(
            'Cached read failed: ${failure.code}',
            name: 'cache',
            error: error,
          );
          state = state.copyWith(
            isLoading: false,
            isRefreshing: false,
            failure: failure,
          );
        }
        // `cancelOnError` ends the stream here without an onDone.
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        if (mounted && (state.isRefreshing || state.isLoading)) {
          state = state.copyWith(isLoading: false, isRefreshing: false);
        }
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    await done.future;
  }

  /// Load again after a failed read — nothing could be loaded (the device
  /// was offline), or a refresh failed over the saved copy. A refresh that
  /// fails offline replaces the read that was waiting for the network, so
  /// without this its "You appear to be offline" stayed up once the
  /// connection was back.
  void reloadIfFailed() {
    if (mounted && state.failure != null) unawaited(refresh(force: true));
  }

  /// Replace the value locally after a mutation returned the new row, so the
  /// screen updates without waiting for the (already invalidated) cache.
  void replace(T value) {
    if (!mounted) return;
    state = state.withValue(value);
  }

  /// Apply an in-place edit to the current value (add/replace/remove a row).
  void update(T Function(T current) edit) {
    final current = state.value;
    if (!mounted || current == null) return;
    state = state.withValue(edit(current));
  }

  @override
  void dispose() {
    _reconnects?.cancel();
    _subscription?.cancel();
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete();
    super.dispose();
  }
}
