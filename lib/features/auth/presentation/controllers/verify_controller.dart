import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/config/feature_flags.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/mock_data/stores/profile_store.dart';
import '../../../../core/utils/validators.dart';
import '../../application/providers/auth_provider.dart';
import 'auth_flow_draft.dart';
import 'auth_form_controller.dart';
import 'code_delivery.dart';
import 'verify_request.dart';

/// Field key for the Verify Code form — the four boxes are one value.
abstract final class VerifyFields {
  VerifyFields._();

  static const String code = 'code';
}

/// The Verify Code screen's logic, for all three flows it now serves
/// (CM-03 sign-up, CM-04 mobile sign-in, CM-06 password reset).
///
/// The screen supplies the [VerifyRequest] it was opened with; this decides
/// what a correct code *does*. Nothing here navigates — the screen does that
/// with the boolean these methods return.
class VerifyFormController extends AuthFormController {
  VerifyFormController(this._ref);

  final Ref _ref;

  @override
  String? validateField(String field, String value) => switch (field) {
    VerifyFields.code => Validators.otp(value),
    _ => null,
  };

  /// True when the four boxes should be painted with the error border.
  static bool hasCodeError(AuthFormState state) =>
      state.errorOf(VerifyFields.code) != null;

  /// The user edited a box: clear the error and re-check once the form has
  /// been submitted, so "Enter all 4 digits" disappears on the fourth digit
  /// rather than lingering.
  void onCodeChanged(String code) => onChanged(VerifyFields.code, code);

  /// Check [code] for [request]. Returns true when the screen should move on.
  Future<bool> verify({
    required VerifyRequest request,
    required String code,
  }) async {
    if (state.isBusy) return false;
    if (!validateAll(<String, String>{VerifyFields.code: code})) return false;

    setBusy(true);
    try {
      final failure = await _check(request: request, code: code);
      if (failure != null) {
        // A rejected code belongs on the boxes, not in a banner: it is the
        // one field on the screen.
        if (failure is ValidationFailure || failure is UnauthorizedFailure) {
          setFieldError(VerifyFields.code, failure.userMessage);
        } else {
          setFailure(failure);
        }
        return false;
      }
      if (request.purpose == VerifyPurpose.passwordReset) {
        _ref.read(passwordResetDraftProvider.notifier).codeVerified(code);
      }
      return true;
    } finally {
      setBusy(false);
    }
  }

  /// Send the code again. Returns true when it is on its way.
  Future<bool> resend(VerifyRequest request) async {
    if (state.isBusy) return false;
    setBusy(true);
    try {
      final failure = switch (request.channel) {
        ResetChannel.sms => await CodeDelivery.requestSmsCode(
          _ref,
          request.destination,
        ),
        ResetChannel.email => await CodeDelivery.requestEmailResetCode(
          _ref,
          request.destination,
        ),
      };
      setFailure(failure);
      return failure == null;
    } finally {
      setBusy(false);
    }
  }

  /// Finish a verified sign-up (CM-03): the account is created only now, and
  /// the address the form collected is saved with it.
  ///
  /// Returns the draft that was committed so the screen can greet the new
  /// patient by name, or null when there is nothing pending (a direct hit on
  /// `/verify?purpose=signup`).
  SignupDraft? completeSignup() {
    final draft = _ref.read(signupDraftProvider);
    if (draft == null) return null;
    if (draft.addressLine1.isNotEmpty) {
      _ref.read(addressesStoreProvider.notifier).add(
        label: draft.addressLabel.isEmpty ? 'Home' : draft.addressLabel,
        line1: draft.addressLine1,
        line2: draft.addressLine2.isEmpty ? null : draft.addressLine2,
        city: draft.city,
        stateName: draft.stateName,
        pincode: draft.pincode,
        isDefault: true,
      );
    }
    _ref.read(signupDraftProvider.notifier).clear();
    return draft;
  }

  /// What a correct code is worth, per flow.
  ///
  /// * **Demo mode** accepts [AppConstants.demoOtpCode] and nothing else. The
  ///   code is stated on screen behind the same flag, so the reviewer is told
  ///   what to type rather than guessing.
  /// * **Sign-up and mobile sign-in** outside demo mode go through
  ///   `authProvider.loginWithOtp`, which shares the CM-05 attempt budget with
  ///   password sign-in — two doors into one account do not each get five
  ///   tries.
  /// * **Password reset** outside demo mode has no verify endpoint of its
  ///   own: `POST /auth/password/reset` takes the code *with* the new
  ///   password, so the code is carried to `/reset` and checked there. This
  ///   step therefore only confirms the code is well-formed, and the screen
  ///   says "Continue" rather than claiming it was verified.
  Future<Failure?> _check({
    required VerifyRequest request,
    required String code,
  }) async {
    if (FeatureFlags.demoMode) {
      if (code == AppConstants.demoOtpCode) return null;
      return const ValidationFailure(
        userMessage: 'That code is not right. Check it and try again.',
        debugMessage: 'demo OTP mismatch',
      );
    }

    if (!request.signsIn) return null;

    return _ref.read(authProvider.notifier).loginWithOtp(
      phone: request.destination,
      code: code,
    );
  }
}

/// autoDispose — the code and its error belong to one visit to the screen.
final verifyFormControllerProvider =
    StateNotifierProvider.autoDispose<VerifyFormController, AuthFormState>(
      (ref) => VerifyFormController(ref),
    );
