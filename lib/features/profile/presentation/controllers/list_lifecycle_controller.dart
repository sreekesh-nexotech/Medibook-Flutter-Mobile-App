import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/constants.dart';
import '../../../../core/error/failure.dart';

/// The load / refresh / error lifecycle of one of the Profile feature's lists
/// — emergency contacts (CM-49), addresses (CM-50), dependants (CM-16, CM-48).
///
/// ## Why this exists when the data is synchronous
///
/// The lists themselves come from `NotifierProvider` stores that read the seed
/// synchronously, so a screen could render them with no states at all. The
/// audit's §3.2 finding was precisely that screens skip the loading, empty and
/// error states, and they are the seam the data layer lands on: when the
/// stores become repository calls, only [_fetch] changes and the three states
/// the screens already render become real.
///
/// Nothing here claims anything was downloaded, and [refresh] never reports
/// success — the only honest thing to say about a refresh that fetched nothing
/// is nothing.
@immutable
class ListLifecycleState {
  const ListLifecycleState({
    this.isLoading = true,
    this.isRefreshing = false,
    this.failure,
  });

  final bool isLoading;
  final bool isRefreshing;

  /// Non-null when the last load or refresh failed.
  final Failure? failure;

  ListLifecycleState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ListLifecycleState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class ListLifecycleController extends StateNotifier<ListLifecycleState> {
  ListLifecycleController() : super(const ListLifecycleState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      await _fetch();
      if (!mounted) return;
      state = state.copyWith(isLoading: false, clearFailure: true);
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        failure: error.asFailure(stackTrace),
      );
    }
  }

  /// Pull-to-refresh (audit §3.9.4). Clears a previous failure on success and
  /// records a new one on failure; it never shows a toast.
  Future<void> refresh() async {
    if (state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true);
    try {
      await _fetch();
      if (!mounted) return;
      state = state.copyWith(isRefreshing: false, clearFailure: true);
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = state.copyWith(
        isRefreshing: false,
        failure: error.asFailure(stackTrace),
      );
    }
  }

  /// Retry after an error — the same path as the first load.
  Future<void> retry() {
    state = state.copyWith(isLoading: true, clearFailure: true);
    return _load();
  }

  /// The swap-point for the repository call. See the class doc.
  Future<void> _fetch() => Future<void>.delayed(AppConstants.easeShort);
}

/// One lifecycle per list, keyed by a caller-chosen name so the three Profile
/// lists do not share a loading flag.
///
/// autoDispose: the lifecycle belongs to a visit to the screen, so reopening
/// it shows the loading state again rather than a stale error from last time.
final listLifecycleProvider = StateNotifierProvider.autoDispose
    .family<ListLifecycleController, ListLifecycleState, String>(
      (ref, name) => ListLifecycleController(),
    );

/// The lifecycle keys the Profile feature's screens use.
abstract final class ProfileListKeys {
  ProfileListKeys._();

  static const String emergencyContacts = 'emergency-contacts';
  static const String addresses = 'addresses';
  static const String dependants = 'dependants';
}
