import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/person.dart';

/// Where the release-to-own-account flow is (§5.8).
enum ReleaseStep {
  /// Collecting the dependant's own mobile number.
  enterNumber,

  /// `release` succeeded — a code went to that number.
  verify,

  /// `release/verify` succeeded — the person has left this account.
  done,
}

/// Releasing one 18+ dependant to their own account.
///
/// [idempotencyKey] is minted once per attempt and reused on a retry of the
/// same `release` call (§1.8).
@immutable
class ReleaseState {
  const ReleaseState({
    this.step = ReleaseStep.enterNumber,
    this.phoneE164,
    this.challenge,
    this.idempotencyKey,
    this.isBusy = false,
    this.failure,
    this.attemptsRemaining,
    this.result,
  });

  final ReleaseStep step;
  final String? phoneE164;
  final OtpChallenge? challenge;
  final String? idempotencyKey;
  final bool isBusy;
  final Failure? failure;
  final int? attemptsRemaining;
  final ReleaseResult? result;

  ReleaseState copyWith({
    ReleaseStep? step,
    String? phoneE164,
    OtpChallenge? challenge,
    String? idempotencyKey,
    bool? isBusy,
    Failure? failure,
    bool clearFailure = false,
    int? attemptsRemaining,
    bool clearAttempts = false,
    ReleaseResult? result,
  }) => ReleaseState(
    step: step ?? this.step,
    phoneE164: phoneE164 ?? this.phoneE164,
    challenge: challenge ?? this.challenge,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    isBusy: isBusy ?? this.isBusy,
    failure: clearFailure ? null : (failure ?? this.failure),
    attemptsRemaining: clearAttempts
        ? null
        : (attemptsRemaining ?? this.attemptsRemaining),
    result: result ?? this.result,
  );

  @override
  bool operator ==(Object other) =>
      other is ReleaseState &&
      other.step == step &&
      other.phoneE164 == phoneE164 &&
      other.challenge?.challengeId == challenge?.challengeId &&
      other.idempotencyKey == idempotencyKey &&
      other.isBusy == isBusy &&
      other.failure == failure &&
      other.attemptsRemaining == attemptsRemaining &&
      other.result == result;

  @override
  int get hashCode => Object.hash(
    step,
    phoneE164,
    challenge?.challengeId,
    idempotencyKey,
    isBusy,
    failure,
    attemptsRemaining,
    result,
  );
}
