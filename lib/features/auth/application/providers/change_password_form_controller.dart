import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import 'auth_provider.dart';
import 'auth_form_controller.dart';
import 'signup_form_controller.dart';

/// Field keys for the signed-in Change Password form (CM-51).
abstract final class ChangePasswordFields {
  ChangePasswordFields._();

  static const String current = 'currentPassword';
  static const String password = 'newPassword';
  static const String confirm = 'confirmPassword';
}

/// The signed-in change-password form (`POST /patient/me/password`, §5.5).
///
/// The current-password field is required for an account that has one; an
/// OTP-only account (`User.hasPassword == false`) *sets* a password instead
/// and the field is omitted. A wrong current password comes back as
/// `401 AUTH_INVALID_CREDENTIALS` with `errors.current_password` and is
/// reported against that field — never treated as a session expiry.
class ChangePasswordFormController extends AuthFormController {
  ChangePasswordFormController(this._ref, {required this.requiresCurrent});

  final Ref _ref;

  /// False for an OTP-only account, which has no current password.
  final bool requiresCurrent;

  /// The new password as last typed, for live confirm checking.
  String _password = '';

  @override
  String? validateField(String field, String value) => switch (field) {
    ChangePasswordFields.current =>
      requiresCurrent ? Validators.requiredPassword(value) : null,
    ChangePasswordFields.password => Validators.password(
      value,
      min: SignupFormController.passwordMinLength,
    ),
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
    if (valid && requiresCurrent && current == password) {
      setFieldError(
        ChangePasswordFields.password,
        'Choose a password you have not used before',
      );
      return false;
    }
    return valid;
  }

  /// Submit the change. Returns true when the screen should close.
  Future<bool> submit({
    required String current,
    required String password,
  }) async {
    if (state.isBusy) return false;
    setBusy(true);
    try {
      await _ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: requiresCurrent ? current : null,
            newPassword: password,
          );
      setFailure(null);
      // The account now has a password; refresh so Profile stops offering
      // "set a password".
      await _ref.read(authProvider.notifier).refreshMe();
      return true;
    } catch (error, stackTrace) {
      final failure = error.asFailure(stackTrace);
      if (failure is UnauthorizedFailure && !failure.sessionExpired) {
        setFieldError(
          ChangePasswordFields.current,
          'That is not your current password',
        );
        return false;
      }
      if (failure is ValidationFailure &&
          failure.fieldErrors.containsKey('new_password')) {
        setFieldError(
          ChangePasswordFields.password,
          failure.fieldErrors['new_password']!,
        );
        return false;
      }
      setFailure(failure);
      return false;
    } finally {
      setBusy(false);
    }
  }
}

/// autoDispose — one visit to the screen, one form state. Whether the
/// current-password field applies comes from the signed-in user.
final changePasswordFormControllerProvider =
    StateNotifierProvider.autoDispose<
      ChangePasswordFormController,
      AuthFormState
    >(
      (ref) => ChangePasswordFormController(
        ref,
        requiresCurrent: ref.read(currentUserProvider)?.hasPassword ?? true,
      ),
    );
