import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medibook/core/utils/validators.dart';

/// Validation error state for the Sign Up form. Field *text* + the terms
/// checkbox value live in the screen; only error strings / flags live here.
class SignupFormState {
  const SignupFormState({
    this.nameError,
    this.emailError,
    this.passwordError,
    this.termsError = false,
    this.submitted = false,
  });

  final String? nameError;
  final String? emailError;
  final String? passwordError;
  final bool termsError;
  final bool submitted;

  static const SignupFormState initial = SignupFormState();

  SignupFormState _copy({
    String? nameError,
    String? emailError,
    String? passwordError,
    bool? termsError,
    bool? submitted,
  }) => SignupFormState(
    nameError: nameError,
    emailError: emailError,
    passwordError: passwordError,
    termsError: termsError ?? this.termsError,
    submitted: submitted ?? this.submitted,
  );
}

class SignupFormController extends StateNotifier<SignupFormState> {
  SignupFormController() : super(SignupFormState.initial);

  void clearNameError() {
    if (state.nameError == null) return;
    state = state._copy(
      emailError: state.emailError,
      passwordError: state.passwordError,
    );
  }

  void clearEmailError() {
    if (state.emailError == null) return;
    state = state._copy(
      nameError: state.nameError,
      passwordError: state.passwordError,
    );
  }

  void clearPasswordError() {
    if (state.passwordError == null) return;
    state = state._copy(
      nameError: state.nameError,
      emailError: state.emailError,
    );
  }

  /// Toggling the terms checkbox clears its error (DESIGN-SPEC §6).
  void clearTermsError() {
    if (!state.termsError) return;
    state = state._copy(
      nameError: state.nameError,
      emailError: state.emailError,
      passwordError: state.passwordError,
      termsError: false,
    );
  }

  bool validate({
    required String name,
    required String email,
    required String password,
    required bool acceptedTerms,
  }) {
    final nameError = Validators.name(name);
    final emailError = Validators.email(email);
    final passwordError = Validators.password(password);
    final termsError = !acceptedTerms;
    state = SignupFormState(
      nameError: nameError,
      emailError: emailError,
      passwordError: passwordError,
      termsError: termsError,
      submitted: true,
    );
    return nameError == null &&
        emailError == null &&
        passwordError == null &&
        !termsError;
  }
}

final signupFormControllerProvider =
    StateNotifierProvider.autoDispose<SignupFormController, SignupFormState>(
      (ref) => SignupFormController(),
    );
