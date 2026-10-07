import 'package:flutter/foundation.dart';

import '../../../../../core/error/failure.dart';

/// The state of one mutation notifier (save, delete, promote, revoke …).
///
/// Only two facts matter to a screen: is a request in flight (to block a
/// double submit and spin the button), and what the last one reported. The
/// outcome of an action is also *returned* from the notifier method, so a
/// screen can toast from its callback without watching this in `build`.
@immutable
class MutationState {
  const MutationState({this.isBusy = false, this.failure});

  final bool isBusy;

  /// The last failure, or null. Cleared when the next attempt starts.
  final Failure? failure;

  MutationState copyWith({
    bool? isBusy,
    Failure? failure,
    bool clearFailure = false,
  }) => MutationState(
    isBusy: isBusy ?? this.isBusy,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  bool operator ==(Object other) =>
      other is MutationState &&
      other.isBusy == isBusy &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(isBusy, failure);
}
