import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/repositories/family_repository.dart';
import '../states/release_state.dart';
import 'profile_provider.dart';

/// Release a dependant who is now 18+ to their own account (§5.8), keyed by
/// person id:
///
/// 1. [start] — `POST …/release` (`Idempotency-Key`) with the dependant's
///    own mobile; a code goes to that number.
/// 2. [verify] — `POST …/release/verify`; the person and their history
///    leave this account.
///
/// Errors on step 1: `409 UNDER_AGE`, `409 PERSON_IS_SELF`,
/// `409 STATE_CONFLICT`, `400` on `phone_e164`.
class ReleaseController extends StateNotifier<ReleaseState> {
  ReleaseController(
    this._ref, {
    required FamilyRepository repository,
    required AuthRepository auth,
    required String personId,
  }) : _repository = repository,
       _auth = auth,
       _personId = personId,
       super(const ReleaseState());

  final Ref _ref;
  final FamilyRepository _repository;
  final AuthRepository _auth;
  final String _personId;

  Future<Failure?> start(String phoneE164) => _run(() async {
    // Reuse the key only on a retry of this same action (§1.8). A corrected
    // number is a new action: sent with the old key, the server took it as
    // the first request again — "That request is already being processed"
    // (BL-FAM-013).
    final sameAction =
        state.idempotencyKey != null && state.phoneE164 == phoneE164;
    final key = sameAction ? state.idempotencyKey! : IdempotencyKeys.mint();
    state = state.copyWith(idempotencyKey: key, phoneE164: phoneE164);
    final challenge = await _repository.startRelease(
      personId: _personId,
      phoneE164: phoneE164,
      idempotencyKey: key,
    );
    state = state.copyWith(
      step: ReleaseStep.verify,
      challenge: challenge,
      clearAttempts: true,
    );
  });

  Future<Failure?> verify(String code) => _run(() async {
    final result = await _repository.verifyRelease(
      personId: _personId,
      challengeId: state.challenge?.challengeId ?? '',
      code: code,
    );
    _ref
        .read(personsProvider.notifier)
        .update((list) => list.where((p) => p.id != _personId).toList());
    state = state.copyWith(
      step: ReleaseStep.done,
      result: result,
      clearAttempts: true,
    );
  }, isVerify: true);

  Future<Failure?> resend() => _run(() async {
    final id = state.challenge?.challengeId;
    if (id == null) {
      throw const UnauthorizedFailure(
        userMessage: 'The code has expired. Start again.',
        sessionExpired: false,
        apiCode: ApiErrorCodes.authOtpExpired,
      );
    }
    final challenge = await _auth.resendOtp(challengeId: id);
    state = state.copyWith(challenge: challenge, clearAttempts: true);
  });

  /// Back to the number field, keeping the idempotency key so a retried
  /// `release` with the same number replays rather than duplicates; a new
  /// number gets a new key in [start].
  void backToNumber() =>
      state = state.copyWith(step: ReleaseStep.enterNumber, clearFailure: true);

  Future<Failure?> _run(
    Future<void> Function() call, {
    bool isVerify = false,
  }) async {
    if (state.isBusy) return null;
    state = state.copyWith(isBusy: true, clearFailure: true);
    try {
      await call();
      if (!mounted) return null;
      state = state.copyWith(isBusy: false);
      return null;
    } catch (error, stackTrace) {
      if (!mounted) return null;
      final failure = error.asFailure(stackTrace);
      final attempts = failure is UnauthorizedFailure
          ? failure.attemptsRemaining
          : null;
      final expired =
          failure.apiCode == ApiErrorCodes.authOtpExpired ||
          failure.apiCode == ApiErrorCodes.otpAttemptsExceeded;
      state = state.copyWith(
        isBusy: false,
        failure: failure,
        attemptsRemaining: isVerify ? attempts : null,
        step: expired && isVerify ? ReleaseStep.enterNumber : null,
      );
      return failure;
    }
  }
}

/// autoDispose family — one flow per person, per visit to their record.
final releaseControllerProvider = StateNotifierProvider.autoDispose
    .family<ReleaseController, ReleaseState, String>(
      (ref, personId) => ReleaseController(
        ref,
        repository: ref.watch(familyRepositoryProvider),
        auth: ref.watch(authRepositoryProvider),
        personId: personId,
      ),
    );
