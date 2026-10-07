import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import 'auth_provider.dart';
import 'auth_flow_draft.dart';
import 'auth_form_controller.dart';
import 'signup_form_controller.dart';

/// Field keys for the New Password (logged-out reset) form.
abstract final class ResetFields {
  ResetFields._();

  static const String password = 'password';
  static const String confirm = 'confirm';
}

/// The New Password form — the last step of the logged-out reset flow
/// (`POST /auth/password/reset {reset_token, new_password}`, §4.7 step 3).
///
/// The signed-in change-password screen is deliberately a *different*
/// controller: it has a current-password field and a different destination.
class ResetFormController extends AuthFormController {
  ResetFormController(this._ref);

  final Ref _ref;

  /// The new password as last typed, so the confirm field can be re-checked
  /// against it live. Dies with this autoDispose controller.
  String _password = '';

  @override
  String? validateField(String field, String value) => switch (field) {
    ResetFields.password => Validators.password(
      value,
      min: SignupFormController.passwordMinLength,
    ),
    ResetFields.confirm => Validators.confirmPassword(value, _password),
    _ => null,
  };

  /// The new-password field's `onChanged` — re-checks the confirm field too.
  void onPasswordChanged(String password, {required String confirm}) {
    _password = password;
    onChanged(ResetFields.password, password);
    onChanged(ResetFields.confirm, confirm);
  }

  /// Validate the pair. True when it may be submitted.
  bool validateForm({required String password, required String confirm}) {
    _password = password;
    return validateAll(<String, String>{
      ResetFields.password: password,
      ResetFields.confirm: confirm,
    });
  }

  /// Submit the new password with the `reset_token` from
  /// [passwordResetDraftProvider]. Returns true when the screen should go on
  /// to sign-in (every session was revoked).
  Future<bool> submit({required String password}) async {
    if (state.isBusy) return false;
    setBusy(true);
    try {
      final draft = _ref.read(passwordResetDraftProvider);
      final token = draft?.resetToken;
      if (draft == null || token == null || token.isEmpty) {
        setFailure(
          const ValidationFailure(
            userMessage:
                'That reset link has expired. Request a new code to continue.',
            debugMessage: 'reset submitted with no reset_token in the draft',
          ),
        );
        return false;
      }
      final failure = await _ref
          .read(authProvider.notifier)
          .resetPassword(resetToken: token, newPassword: password);
      if (failure is ValidationFailure &&
          failure.fieldErrors.containsKey('new_password')) {
        setFieldError(
          ResetFields.password,
          failure.fieldErrors['new_password']!,
        );
        return false;
      }
      if (failure is UnauthorizedFailure) {
        // `AUTH_TOKEN_INVALID` — the 15-minute grant was used or expired.
        setFailure(
          const ValidationFailure(
            userMessage:
                'That reset code has expired. Request a new one to continue.',
            debugMessage: 'reset_token rejected',
          ),
        );
        return false;
      }
      setFailure(failure);
      if (failure != null) return false;
      _ref.read(passwordResetDraftProvider.notifier).clear();
      return true;
    } finally {
      setBusy(false);
    }
  }
}

/// autoDispose — one visit to the screen, one form state.
final resetFormControllerProvider =
    StateNotifierProvider.autoDispose<ResetFormController, AuthFormState>(
      (ref) => ResetFormController(ref),
    );
