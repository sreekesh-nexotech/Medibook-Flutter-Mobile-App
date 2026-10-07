import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import '../states/phone_change_state.dart';
import 'profile_mutations_provider.dart';
import 'profile_provider.dart';

/// The three-call mobile-number change (§5.3):
///
/// 1. [start] — `phone/change/start` sends a code to the **old** number;
/// 2. [confirmOld] — `confirm-old` checks it and sends one to the **new**;
/// 3. [verifyNew] — `verify-new` checks that and returns the user.
///
/// Both codes must be entered within 10 minutes of step 1
/// (`AUTH_OTP_EXPIRED` otherwise: "Start again"). Resends go through the
/// generic `otp/resend` with the current challenge id (§4.6).
///
/// No `BuildContext`, toast or navigation; the screen watches
/// [PhoneChangeState.step] and reacts to the returned `Failure`.
class PhoneChangeController extends StateNotifier<PhoneChangeState> {
  PhoneChangeController(
    this._ref, {
    required ProfileRepository repository,
    required AuthRepository auth,
  }) : _repository = repository,
       _auth = auth,
       super(const PhoneChangeState());

  final Ref _ref;
  final ProfileRepository _repository;
  final AuthRepository _auth;

  /// Step 1. `400` on `new_phone_e164` ("already your number", "belongs to
  /// another account") comes back as a `ValidationFailure` on that field.
  Future<Failure?> start(String newPhoneE164) => _run(() async {
    final challenge = await _repository.startPhoneChange(
      newPhoneE164: newPhoneE164,
    );
    state = state.copyWith(
      step: PhoneChangeStep.confirmOld,
      newPhoneE164: newPhoneE164,
      challenge: challenge,
      startedAt: DateTime.now(),
      clearAttempts: true,
    );
  });

  /// Step 2.
  Future<Failure?> confirmOld(String code) => _run(() async {
    if (state.isExpired) throw _expired();
    final challenge = await _repository.confirmOldPhone(
      challengeId: state.challenge?.challengeId ?? '',
      code: code,
    );
    state = state.copyWith(
      step: PhoneChangeStep.verifyNew,
      challenge: challenge,
      clearAttempts: true,
    );
  }, isVerify: true);

  /// Step 3. On success the session's user carries the new number.
  Future<Failure?> verifyNew(String code) => _run(() async {
    if (state.isExpired) throw _expired();
    final fresh = await _repository.verifyNewPhone(
      challengeId: state.challenge?.challengeId ?? '',
      code: code,
    );
    mergeUserIntoSession(_ref, fresh);
    // The "self" person is kept in step server-side; reload so it shows.
    await _ref.read(personsProvider.notifier).refresh(force: true);
    state = state.copyWith(step: PhoneChangeStep.done, clearAttempts: true);
  }, isVerify: true);

  /// Re-sends the code for the current step's challenge (§4.6). The new
  /// challenge replaces the old one; the 10-minute window does not reset.
  Future<Failure?> resend() => _run(() async {
    final id = state.challenge?.challengeId;
    if (id == null) throw _expired();
    final challenge = await _auth.resendOtp(challengeId: id);
    state = state.copyWith(challenge: challenge, clearAttempts: true);
  });

  /// Back to the number field — after an expiry or on "start again".
  void reset() => state = const PhoneChangeState();

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
        // A dead challenge cannot be retried; send the user back to start.
        step: expired && isVerify ? PhoneChangeStep.enterNumber : null,
      );
      return failure;
    }
  }

  static Failure _expired() => const UnauthorizedFailure(
    userMessage: 'Both codes must be confirmed within 10 minutes. Start again.',
    sessionExpired: false,
    apiCode: ApiErrorCodes.authOtpExpired,
  );
}

/// autoDispose — the flow belongs to one visit to `/profile/phone`; leaving
/// it abandons the open challenge, which simply expires server-side.
final phoneChangeControllerProvider =
    StateNotifierProvider.autoDispose<PhoneChangeController, PhoneChangeState>(
      (ref) => PhoneChangeController(
        ref,
        repository: ref.watch(profileRepositoryProvider),
        auth: ref.watch(authRepositoryProvider),
      ),
    );

/// The masked destination of the current step's challenge, for the copy.
final phoneChangeDestinationProvider = Provider.autoDispose<String?>(
  (ref) => ref.watch(
    phoneChangeControllerProvider.select((s) => s.challenge?.destinationMasked),
  ),
);

/// Convenience for screens that need the challenge shape without importing
/// the auth entity file directly.
typedef PhoneChangeChallenge = OtpChallenge;
