import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/feature_flags.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../application/providers/auth_provider.dart';
import 'auth_flow_draft.dart';
import 'auth_form_controller.dart';

/// Field keys for the New Password (logged-out reset) form.
abstract final class ResetFields {
  ResetFields._();

  static const String password = 'password';
  static const String confirm = 'confirm';
}

/// The New Password form — the last step of the logged-out reset flow.
///
/// The signed-in change-password screen (CM-51) is deliberately a *different*
/// controller: it has a current-password field, a different failure ("your
/// current password is wrong" is a field error, not a form error) and a
/// different destination. What the two share is the new + confirm pair, which
/// is a widget, not logic — see `components/new_password_fields.dart`.
class ResetFormController extends AuthFormController {
  ResetFormController(this._ref);

  final Ref _ref;

  /// The new password as last typed, so the confirm field can be re-checked
  /// against it live. Dies with this autoDispose controller.
  String _password = '';

  @override
  String? validateField(String field, String value) => switch (field) {
    ResetFields.password => Validators.password(value),
    ResetFields.confirm => Validators.confirmPassword(value, _password),
    _ => null,
  };

  /// The new-password field's `onChanged` — re-checks the confirm field too,
  /// so "Passwords do not match" clears when either half is fixed.
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

  /// Submit the new password. Returns true when the screen should go on to
  /// sign-in.
  ///
  /// Demo mode completes locally — there is no account server to change and
  /// the reviewer needs the flow to finish. Outside demo mode the verified
  /// code from [passwordResetDraftProvider] is submitted with the new password
  /// and a failure is rendered rather than swallowed.
  Future<bool> submit({required String password}) async {
    if (state.isBusy) return false;
    setBusy(true);
    try {
      final failure = await _submit(password);
      setFailure(failure);
      if (failure != null) return false;
      _ref.read(passwordResetDraftProvider.notifier).clear();
      return true;
    } finally {
      setBusy(false);
    }
  }

  Future<Failure?> _submit(String password) async {
    if (FeatureFlags.demoMode) return null;

    final draft = _ref.read(passwordResetDraftProvider);
    if (draft == null || !draft.isVerified) {
      return const ValidationFailure(
        userMessage:
            'That reset link has expired. Request a new code to continue.',
        debugMessage: 'reset submitted with no verified code in the draft',
      );
    }

    try {
      await _ref
          .read(authRepositoryProvider)
          .resetPassword(
            email: draft.destination,
            code: draft.code,
            newPassword: password,
          );
      return null;
    } catch (error, stackTrace) {
      return error.asFailure(stackTrace);
    }
  }
}

/// autoDispose — one visit to the screen, one form state.
final resetFormControllerProvider =
    StateNotifierProvider.autoDispose<ResetFormController, AuthFormState>(
      (ref) => ResetFormController(ref),
    );
