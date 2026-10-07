import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';

/// The state of a `PATCH /patient/me` (§5.2).
///
/// [hasConflict] is the `409 CONFLICT_VERSION` case: someone else changed the
/// account since this form loaded. The controller has already reloaded the
/// user; the screen shows the prompt and the user re-applies their edit.
@immutable
class ProfileSaveState {
  const ProfileSaveState({
    this.isSaving = false,
    this.failure,
    this.hasConflict = false,
  });

  final bool isSaving;
  final Failure? failure;
  final bool hasConflict;

  ProfileSaveState copyWith({
    bool? isSaving,
    Failure? failure,
    bool clearFailure = false,
    bool? hasConflict,
  }) => ProfileSaveState(
    isSaving: isSaving ?? this.isSaving,
    failure: clearFailure ? null : (failure ?? this.failure),
    hasConflict: hasConflict ?? this.hasConflict,
  );

  @override
  bool operator ==(Object other) =>
      other is ProfileSaveState &&
      other.isSaving == isSaving &&
      other.failure == failure &&
      other.hasConflict == hasConflict;

  @override
  int get hashCode => Object.hash(isSaving, failure, hasConflict);
}
