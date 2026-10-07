import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../../auth/domain/entities/user.dart';

/// Where the three-call mobile-number change is (§5.3).
enum PhoneChangeStep {
  /// Nothing started; collecting the new number.
  enterNumber,

  /// `start` succeeded — a code went to the **old** number.
  confirmOld,

  /// `confirm-old` succeeded — a code went to the **new** number.
  verifyNew,

  /// `verify-new` succeeded — the account has the new number.
  done,
}

/// The phone-change flow. Both codes must be confirmed within 10 minutes of
/// [startedAt]; [deadline] is what the screen counts down to.
@immutable
class PhoneChangeState {
  const PhoneChangeState({
    this.step = PhoneChangeStep.enterNumber,
    this.newPhoneE164,
    this.challenge,
    this.startedAt,
    this.isBusy = false,
    this.failure,
    this.attemptsRemaining,
  });

  static const Duration window = Duration(minutes: 10);

  final PhoneChangeStep step;
  final String? newPhoneE164;

  /// The open challenge for the current step (old number, then new number).
  final OtpChallenge? challenge;
  final DateTime? startedAt;
  final bool isBusy;
  final Failure? failure;

  /// `meta.attempts_remaining` from the last wrong code, or null.
  final int? attemptsRemaining;

  DateTime? get deadline => startedAt?.add(window);

  bool get isExpired {
    final end = deadline;
    return end != null && DateTime.now().isAfter(end);
  }

  PhoneChangeState copyWith({
    PhoneChangeStep? step,
    String? newPhoneE164,
    OtpChallenge? challenge,
    DateTime? startedAt,
    bool? isBusy,
    Failure? failure,
    bool clearFailure = false,
    int? attemptsRemaining,
    bool clearAttempts = false,
  }) => PhoneChangeState(
    step: step ?? this.step,
    newPhoneE164: newPhoneE164 ?? this.newPhoneE164,
    challenge: challenge ?? this.challenge,
    startedAt: startedAt ?? this.startedAt,
    isBusy: isBusy ?? this.isBusy,
    failure: clearFailure ? null : (failure ?? this.failure),
    attemptsRemaining: clearAttempts
        ? null
        : (attemptsRemaining ?? this.attemptsRemaining),
  );

  @override
  bool operator ==(Object other) =>
      other is PhoneChangeState &&
      other.step == step &&
      other.newPhoneE164 == newPhoneE164 &&
      other.challenge?.challengeId == challenge?.challengeId &&
      other.startedAt == startedAt &&
      other.isBusy == isBusy &&
      other.failure == failure &&
      other.attemptsRemaining == attemptsRemaining;

  @override
  int get hashCode => Object.hash(
    step,
    newPhoneE164,
    challenge?.challengeId,
    startedAt,
    isBusy,
    failure,
    attemptsRemaining,
  );
}
