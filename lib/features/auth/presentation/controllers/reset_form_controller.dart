import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medibook/core/utils/validators.dart';

/// Validation error state for the New Password (reset) form.
class ResetFormState {
  const ResetFormState({
    this.passwordError,
    this.confirmError,
    this.submitted = false,
  });

  final String? passwordError;
  final String? confirmError;
  final bool submitted;

  static const ResetFormState initial = ResetFormState();
}

class ResetFormController extends StateNotifier<ResetFormState> {
  ResetFormController() : super(ResetFormState.initial);

  void clearPasswordError() {
    if (state.passwordError == null) return;
    state = ResetFormState(
      confirmError: state.confirmError,
      submitted: state.submitted,
    );
  }

  void clearConfirmError() {
    if (state.confirmError == null) return;
    state = ResetFormState(
      passwordError: state.passwordError,
      submitted: state.submitted,
    );
  }

  bool validate({required String password, required String confirm}) {
    final passwordError = Validators.password(password);
    // Independent of the length check, mirroring the prototype's doReset.
    final confirmError = Validators.confirmPassword(confirm, password);
    state = ResetFormState(
      passwordError: passwordError,
      confirmError: confirmError,
      submitted: true,
    );
    return passwordError == null && confirmError == null;
  }
}

final resetFormControllerProvider =
    StateNotifierProvider.autoDispose<ResetFormController, ResetFormState>(
      (ref) => ResetFormController(),
    );
