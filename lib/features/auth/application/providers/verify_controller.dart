import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import 'auth_provider.dart';
import '../../domain/entities/user.dart';
import 'auth_flow_draft.dart';
import 'auth_form_controller.dart';
import 'code_delivery.dart';
import 'verify_request.dart';

/// Field key for the Verify Code form — the boxes are one value.
abstract final class VerifyFields {
  VerifyFields._();

  static const String code = 'code';
}

/// The Verify Code screen's logic, for the flows it serves (sign-up §4.2,
/// mobile sign-in §4.4, password reset §4.7 step 2).
///
/// The screen supplies the [VerifyRequest] it was opened with (which carries
/// the `challenge_id`); this decides what a correct code *does*. Nothing here
/// navigates — the screen does that with the boolean these methods return.
class VerifyFormController extends AuthFormController {
  VerifyFormController(this._ref);

  final Ref _ref;

  @override
  String? validateField(String field, String value) => switch (field) {
    VerifyFields.code => Validators.otp(value, length: _codeLength),
    _ => null,
  };

  int _codeLength = 4;

  /// True when the boxes should be painted with the error border.
  static bool hasCodeError(AuthFormState state) =>
      state.errorOf(VerifyFields.code) != null;

  /// The user edited a box: clear the error and re-check once the form has
  /// been submitted, so "Enter all 4 digits" disappears on the last digit.
  void onCodeChanged(String code) => onChanged(VerifyFields.code, code);

  /// Check [code] for [request]. Returns true when the screen should move on.
  Future<bool> verify({
    required VerifyRequest request,
    required String code,
  }) async {
    if (state.isBusy) return false;
    _codeLength = request.codeLength;
    if (request.isOrphan) {
      setFailure(
        const ValidationFailure(
          userMessage:
              'This code request has expired. Go back and ask for a new '
              'code.',
          debugMessage: 'verify opened without a challenge_id',
        ),
      );
      return false;
    }
    if (!validateAll(<String, String>{VerifyFields.code: code})) return false;

    setBusy(true);
    try {
      final failure = await _check(request: request, code: code);
      if (failure != null) {
        // A rejected code belongs on the boxes, not in a banner: it is the
        // one field on the screen. Lockouts and rate limits are form-level.
        final onField =
            (failure is UnauthorizedFailure &&
                !failure.sessionExpired &&
                failure.lockedUntil == null) ||
            failure is ValidationFailure;
        if (onField) {
          setFieldError(VerifyFields.code, failure.userMessage);
        } else {
          setFailure(failure);
        }
        return false;
      }
      return true;
    } finally {
      setBusy(false);
    }
  }

  /// Send the code again (§4.6). Returns the new challenge, or null with the
  /// failure rendered. The screen replaces its request with the new id.
  Future<OtpChallenge?> resend(VerifyRequest request) async {
    if (state.isBusy || request.isOrphan) return null;
    setBusy(true);
    try {
      final challenge = await CodeDelivery.resend(_ref, request.challengeId);
      if (challenge == null) {
        setFailure(CodeDelivery.lastFailure(_ref));
        return null;
      }
      setFailure(null);
      if (request.purpose == VerifyPurpose.passwordReset) {
        _ref
            .read(passwordResetDraftProvider.notifier)
            .challengeReplaced(challenge.challengeId);
      }
      return challenge;
    } finally {
      setBusy(false);
    }
  }

  /// Once a sign-up code is accepted the account exists and the session is
  /// minted; the draft has done its job. Returns it so the screen can greet
  /// the new patient by name.
  SignupDraft? completeSignup() {
    final draft = _ref.read(signupDraftProvider);
    _ref.read(signupDraftProvider.notifier).clear();
    return draft;
  }

  /// What a correct code is worth, per flow.
  Future<Failure?> _check({
    required VerifyRequest request,
    required String code,
  }) async {
    final auth = _ref.read(authProvider.notifier);
    switch (request.purpose) {
      case VerifyPurpose.signup:
        return auth.verifySignup(challengeId: request.challengeId, code: code);
      case VerifyPurpose.mobileLogin:
        return auth.verifyOtpLogin(
          challengeId: request.challengeId,
          code: code,
          // The sign-in screen hands over the full number it sent the code
          // to; a masked one cannot name the account.
          phoneE164: request.destination.contains('*')
              ? null
              : request.destination,
        );
      case VerifyPurpose.passwordReset:
        final grant = await auth.verifyPasswordReset(
          challengeId: request.challengeId,
          code: code,
        );
        if (grant == null) {
          return _ref.read(authProvider).failure ??
              const UnknownFailure(debugMessage: 'forgot/verify: no grant');
        }
        _ref
            .read(passwordResetDraftProvider.notifier)
            .granted(grant.resetToken, expiresAt: grant.expiresAt);
        return null;
    }
  }
}

/// autoDispose — the code and its error belong to one visit to the screen.
final verifyFormControllerProvider =
    StateNotifierProvider.autoDispose<VerifyFormController, AuthFormState>(
      (ref) => VerifyFormController(ref),
    );
