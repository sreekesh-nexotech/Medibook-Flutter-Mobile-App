import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/validators.dart';
import '../../domain/entities/user.dart';
import 'auth_flow_draft.dart';
import 'auth_form_controller.dart';
import 'code_delivery.dart';

/// Field keys for the Forgot Password form.
abstract final class ForgotFields {
  ForgotFields._();

  static const String email = 'email';
  static const String phone = 'phone';
}

/// The Forgot Password form (§4.7).
///
/// The user may identify the account by email or by mobile; either way the
/// backend sends the code by **SMS** to the account's phone (patients reset by
/// SMS only). The chosen identifier is recorded in [passwordResetDraftProvider]
/// with the challenge id, so `/verify` and `/reset` can follow it through.
class ForgotFormController extends AuthFormController {
  ForgotFormController(this._ref);

  final Ref _ref;

  @override
  String? validateField(String field, String value) => switch (field) {
    ForgotFields.email => Validators.email(value),
    ForgotFields.phone => Validators.phone(value),
    _ => null,
  };

  /// Validate the email tab. True when it may be submitted.
  bool validateEmailForm({required String email}) =>
      validateAll(<String, String>{ForgotFields.email: email});

  /// Validate the mobile tab. True when it may be submitted.
  bool validateMobileForm({required String phone}) =>
      validateAll(<String, String>{ForgotFields.phone: phone});

  /// Send the reset code for [identifier] and open the reset draft. Returns
  /// the challenge, or null with the failure rendered.
  Future<OtpChallenge?> sendResetCode({
    required ResetChannel channel,
    required String identifier,
  }) async {
    if (state.isBusy) return null;
    setBusy(true);
    try {
      final challenge = await CodeDelivery.requestResetCode(_ref, identifier);
      if (challenge == null) {
        setFailure(CodeDelivery.lastFailure(_ref));
        return null;
      }
      setFailure(null);
      _ref
          .read(passwordResetDraftProvider.notifier)
          .start(
            channel: channel,
            destination: identifier,
            challengeId: challenge.challengeId,
          );
      return challenge;
    } finally {
      setBusy(false);
    }
  }
}

/// autoDispose — one visit to the screen, one form state.
final forgotFormControllerProvider =
    StateNotifierProvider.autoDispose<ForgotFormController, AuthFormState>(
      (ref) => ForgotFormController(ref),
    );
