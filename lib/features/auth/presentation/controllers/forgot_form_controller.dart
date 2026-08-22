import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medibook/core/utils/validators.dart';

/// Validation error state for the Forgot Password form.
class ForgotFormState {
  const ForgotFormState({this.emailError, this.submitted = false});

  final String? emailError;
  final bool submitted;

  static const ForgotFormState initial = ForgotFormState();
}

class ForgotFormController extends StateNotifier<ForgotFormState> {
  ForgotFormController() : super(ForgotFormState.initial);

  void clearEmailError() {
    if (state.emailError == null) return;
    state = ForgotFormState(submitted: state.submitted);
  }

  bool validate({required String email}) {
    final emailError = Validators.email(email);
    state = ForgotFormState(emailError: emailError, submitted: true);
    return emailError == null;
  }
}

final forgotFormControllerProvider =
    StateNotifierProvider.autoDispose<ForgotFormController, ForgotFormState>(
      (ref) => ForgotFormController(),
    );
