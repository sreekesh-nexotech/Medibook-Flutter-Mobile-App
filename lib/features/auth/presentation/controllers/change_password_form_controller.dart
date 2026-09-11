import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/config/feature_flags.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../application/providers/auth_provider.dart';
import 'auth_form_controller.dart';

/// Field keys for the signed-in Change Password form (CM-51).
abstract final class ChangePasswordFields {
  ChangePasswordFields._();

  static const String current = 'currentPassword';
  static const String password = 'newPassword';
  static const String confirm = 'confirmPassword';
}

/// The signed-in change-password form (CM-51).
///
/// The audit found *"a new-password screen exists, but only in the logged-out
/// reset flow. Profile has no entry point and no current-password field"*.
/// The current-password field is the substantive difference: a signed-in
/// session is not proof of intent — a borrowed, unlocked phone is exactly the
/// case it defends against — so the old password is required and a wrong one
/// is reported against that field, not as a form-level error.
class ChangePasswordFormController extends AuthFormController {
  ChangePasswordFormController(this._ref);

  final Ref _ref;

  /// The new password as last typed, for live confirm checking.
  String _password = '';

  @override
  String? validateField(String field, String value) => switch (field) {
    ChangePasswordFields.current => Validators.requiredPassword(value),
    ChangePasswordFields.password => Validators.password(value),
    ChangePasswordFields.confirm => Validators.confirmPassword(
      value,
      _password,
    ),
    _ => null,
  };

  /// The new-password field's `onChanged` — re-checks confirm as well.
  void onPasswordChanged(String password, {required String confirm}) {
    _password = password;
    onChanged(ChangePasswordFields.password, password);
    onChanged(ChangePasswordFields.confirm, confirm);
  }

  /// Validate all three fields. True when the form may be submitted.
  bool validateForm({
    required String current,
    required String password,
    required String confirm,
  }) {
    _password = password;
    final valid = validateAll(<String, String>{
      ChangePasswordFields.current: current,
      ChangePasswordFields.password: password,
      ChangePasswordFields.confirm: confirm,
    });
    // A new password identical to the old one is not a change. Checked here
    // rather than in validateField because it is the only rule that needs two
    // fields at once and neither of them is the confirm pair.
    if (valid && current == password) {
      setFieldError(
        ChangePasswordFields.password,
        'Choose a password you have not used before',
      );
      return false;
    }
    return valid;
  }

  /// Submit the change. Returns true when the screen should close.
  ///
  /// Demo mode checks the current password against
  /// [AppConstants.demoPassword], so the wrong-password path is demonstrable
  /// rather than theoretical: a wrong entry lands on the current-password
  /// field, exactly where a server's 403 would be shown. Outside demo mode the
  /// repository is called and whatever it throws is rendered.
  Future<bool> submit({
    required String current,
    required String password,
  }) async {
    if (state.isBusy) return false;
    setBusy(true);
    try {
      if (FeatureFlags.demoMode) {
        if (current != AppConstants.demoPassword) {
          setFieldError(
            ChangePasswordFields.current,
            'That is not your current password',
          );
          return false;
        }
        setFailure(null);
        return true;
      }

      try {
        await _ref
            .read(authRepositoryProvider)
            .changePassword(currentPassword: current, newPassword: password);
        setFailure(null);
        return true;
      } catch (error, stackTrace) {
        setFailure(error.asFailure(stackTrace));
        return false;
      }
    } finally {
      setBusy(false);
    }
  }
}

/// autoDispose — one visit to the screen, one form state.
final changePasswordFormControllerProvider =
    StateNotifierProvider.autoDispose<
      ChangePasswordFormController,
      AuthFormState
    >((ref) => ChangePasswordFormController(ref));
