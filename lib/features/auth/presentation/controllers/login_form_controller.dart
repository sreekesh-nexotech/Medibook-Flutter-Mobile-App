import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medibook/core/utils/validators.dart';

/// Validation error state for the Login form. Field *text* lives in the
/// screen's [TextEditingController]s; only the transient error strings and the
/// "was a submit attempted" flag live here (see the Screen Build Guide's Forms
/// rule).
class LoginFormState {
  const LoginFormState({
    this.emailError,
    this.passwordError,
    this.submitted = false,
  });

  final String? emailError;
  final String? passwordError;
  final bool submitted;

  static const LoginFormState initial = LoginFormState();
}

/// autoDispose so the form resets whenever the Login screen leaves the tree.
class LoginFormController extends StateNotifier<LoginFormState> {
  LoginFormController() : super(LoginFormState.initial);

  /// Errors clear on the next keystroke (DESIGN-SPEC §6).
  void clearEmailError() {
    if (state.emailError == null) return;
    state = LoginFormState(
      passwordError: state.passwordError,
      submitted: state.submitted,
    );
  }

  void clearPasswordError() {
    if (state.passwordError == null) return;
    state = LoginFormState(
      emailError: state.emailError,
      submitted: state.submitted,
    );
  }

  /// Validates in the submit callback; returns `true` when the form is valid.
  bool validate({required String email, required String password}) {
    final emailError = Validators.email(email);
    final passwordError = Validators.requiredPassword(password);
    state = LoginFormState(
      emailError: emailError,
      passwordError: passwordError,
      submitted: true,
    );
    return emailError == null && passwordError == null;
  }
}

final loginFormControllerProvider =
    StateNotifierProvider.autoDispose<LoginFormController, LoginFormState>(
      (ref) => LoginFormController(),
    );
