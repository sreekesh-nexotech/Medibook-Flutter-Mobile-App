import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/validators.dart';
import 'auth_flow_draft.dart';
import 'auth_form_controller.dart';
import 'code_delivery.dart';

/// Field keys for the Forgot Password form.
abstract final class ForgotFields {
  ForgotFields._();

  static const String email = 'email';
  static const String phone = 'phone';
}

/// The Forgot Password form (CM-06).
///
/// The flow used to run on email only. It now takes either channel — the same
/// Email / Mobile choice the sign-in screen offers (CM-04), so a patient who
/// registered with a phone number is not locked out of their own reset — and
/// records which one was used in [passwordResetDraftProvider] so `/verify` and
/// `/reset` can follow it through.
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

  /// Send the reset code to [destination] over [channel] and open the reset
  /// draft. Returns true when `/verify` should be opened.
  Future<bool> sendResetCode({
    required ResetChannel channel,
    required String destination,
  }) async {
    if (state.isBusy) return false;
    setBusy(true);
    try {
      final failure = switch (channel) {
        ResetChannel.sms => await CodeDelivery.requestSmsCode(
          _ref,
          destination,
        ),
        ResetChannel.email => await CodeDelivery.requestEmailResetCode(
          _ref,
          destination,
        ),
      };
      setFailure(failure);
      if (failure != null) return false;
      _ref
          .read(passwordResetDraftProvider.notifier)
          .start(channel: channel, destination: destination);
      return true;
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
