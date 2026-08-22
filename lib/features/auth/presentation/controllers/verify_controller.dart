import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Transient state for the Verify Code screen. The four digit *values* live in
/// the screen's [TextEditingController]s; only the OTP error message lives here.
/// A non-null [otpError] both shows the error line and drives the red borders.
class VerifyState {
  const VerifyState({this.otpError});

  final String? otpError;

  bool get hasError => otpError != null;

  static const VerifyState initial = VerifyState();
}

class VerifyController extends StateNotifier<VerifyState> {
  VerifyController() : super(VerifyState.initial);

  /// Wrong code (DESIGN-SPEC §6). Exact copy from the prototype.
  static const String incorrectMessage =
      'Incorrect code — the demo code is 1234';

  void showIncorrect() {
    state = const VerifyState(otpError: incorrectMessage);
  }

  /// Errors clear as soon as the user edits any box.
  void clearError() {
    if (state.otpError == null) return;
    state = VerifyState.initial;
  }
}

final verifyControllerProvider =
    StateNotifierProvider.autoDispose<VerifyController, VerifyState>(
      (ref) => VerifyController(),
    );
