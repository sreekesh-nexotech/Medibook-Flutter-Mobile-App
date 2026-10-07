import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/network/network_exceptions.dart';
import '../states/mutation_state.dart';

/// Base for a notifier whose whole job is running mutations against a
/// repository: one busy flag, one last failure, and the same try/catch
/// choreography every time.
///
/// Subclasses expose typed methods (`create`, `delete` …) that call [apply].
/// No `BuildContext`, toast or navigation here — the outcome is returned so
/// the screen can react from its own callback.
abstract class MutationNotifier extends StateNotifier<MutationState> {
  MutationNotifier() : super(const MutationState());

  /// Runs [call] under the busy flag. Returns null on success, otherwise the
  /// `Failure`. A second call while busy is ignored (double-submit guard).
  ///
  /// On `409 CONFLICT_VERSION` (a stale `If-Match`), [onConflict] runs first
  /// — typically a forced reload of the list — and the returned failure tells
  /// the user the row was reloaded so they can retry.
  Future<Failure?> apply(
    Future<void> Function() call, {
    Future<void> Function()? onConflict,
  }) async {
    if (state.isBusy) return null;
    state = state.copyWith(isBusy: true, clearFailure: true);
    try {
      await call();
      if (!mounted) return null;
      state = state.copyWith(isBusy: false);
      return null;
    } catch (error, stackTrace) {
      var failure = error.asFailure(stackTrace);
      // Disposed while the call was running (an autoDispose controller read
      // but not watched): the caller still awaits this result. Returning
      // null here read as success — a false "added" while offline
      // (Screen Coverage pass, 6 Oct). A failure is always reported.
      if (!mounted) return failure;
      if (failure.apiCode == ApiErrorCodes.conflictVersion &&
          onConflict != null) {
        await onConflict();
        failure = ConflictFailure(
          userMessage:
              'This record was changed elsewhere and has been reloaded. '
              'Review it and save again.',
          apiCode: failure.apiCode,
          meta: failure.meta,
          cause: failure,
        );
      }
      if (!mounted) return failure;
      state = state.copyWith(isBusy: false, failure: failure);
      return failure;
    }
  }

  void clearFailure() => state = state.copyWith(clearFailure: true);
}
