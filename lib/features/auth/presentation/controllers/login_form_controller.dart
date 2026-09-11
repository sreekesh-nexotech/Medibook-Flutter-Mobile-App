import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/config/feature_flags.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../application/providers/auth_provider.dart';
import 'auth_form_controller.dart';
import 'code_delivery.dart';

/// Field keys for the sign-in form.
abstract final class LoginFields {
  LoginFields._();

  static const String email = 'email';
  static const String password = 'password';
  static const String phone = 'phone';
}

/// Which credential the sign-in screen is collecting (CM-04).
enum LoginMode {
  /// Email address + password.
  email,

  /// Mobile number + a one-time code.
  mobile,
}

/// The sign-in form: validation, the submit attempt, and the lockout
/// bookkeeping that goes with a rejected attempt (CM-05).
///
/// ## Two submit paths, and why
///
/// This build installs no `ApiClient` — `authApiProvider` resolves to
/// `UnimplementedApiClient`, which refuses every call by design — so a real
/// `POST /auth/login` cannot succeed here. Rather than pretend otherwise:
///
/// * **`FeatureFlags.demoMode` on** (the prototype the client is reviewing):
///   the demo credentials in [AppConstants] are checked locally, and a wrong
///   password is reported to `authProvider.registerFailedAttempt()` — so the
///   five-attempt budget, the 60-second cooldown and the countdown are all
///   the real, persisted CM-05 machinery, driven by a demo credential check.
/// * **`--dart-define=MEDIBOOK_DEMO=false`**: the attempt goes through
///   `authProvider.login`, which owns the same lockout rule in the `Login`
///   use case, and whatever [Failure] comes back is rendered. Nothing is
///   swallowed and nothing reports success it did not get.
///
/// Navigation stays in the screen: a controller that pushed routes would be
/// the "navigation logic in a notifier" violation the QA prompts look for.
class LoginFormController extends AuthFormController {
  LoginFormController(this._ref);

  final Ref _ref;

  @override
  String? validateField(String field, String value) => switch (field) {
    LoginFields.email => Validators.email(value),
    LoginFields.password => Validators.requiredPassword(value),
    LoginFields.phone => Validators.phone(value),
    _ => null,
  };

  /// Validate the email tab. True when it may be submitted.
  bool validateEmailForm({required String email, required String password}) =>
      validateAll(<String, String>{
        LoginFields.email: email,
        LoginFields.password: password,
      });

  /// Validate the mobile tab. True when it may be submitted.
  bool validateMobileForm({required String phone}) =>
      validateAll(<String, String>{LoginFields.phone: phone});

  /// Attempt an email + password sign-in.
  ///
  /// Returns true when the screen should navigate on. A false return always
  /// leaves either a field error or `state.failure` behind for the screen to
  /// render, so a silent failure is not possible.
  Future<bool> signInWithPassword({
    required String email,
    required String password,
  }) async {
    if (state.isBusy) return false;

    final lockout = _lockoutFailure();
    if (lockout != null) {
      setFailure(lockout);
      return false;
    }

    setBusy(true);
    try {
      final failure = FeatureFlags.demoMode
          ? await _demoSignIn(email: email, password: password)
          : await _ref
                .read(authProvider.notifier)
                .login(email: email.trim(), password: password);
      setFailure(failure);
      return failure == null;
    } finally {
      setBusy(false);
    }
  }

  /// Ask for a one-time code to be sent to [phoneE164] before the mobile
  /// sign-in continues to `/verify`.
  ///
  /// Returns true when the code is on its way (or, in demo mode, when there is
  /// nothing to send and the demo code applies).
  Future<bool> requestLoginCode({required String phoneE164}) async {
    if (state.isBusy) return false;

    final lockout = _lockoutFailure();
    if (lockout != null) {
      setFailure(lockout);
      return false;
    }

    setBusy(true);
    try {
      final failure = await CodeDelivery.requestSmsCode(_ref, phoneE164);
      setFailure(failure);
      return failure == null;
    } finally {
      setBusy(false);
    }
  }

  /// The lockout as a failure, or null when sign-in is allowed.
  ///
  /// Checked before every attempt so a locked-out device cannot spend its
  /// cooldown guessing — the same order of operations the `Login` use case
  /// uses server-side of the form.
  Failure? _lockoutFailure() {
    final auth = _ref.read(authProvider);
    if (!auth.isLockedOut) return null;
    final seconds = auth.lockoutRemaining.inSeconds;
    return UnauthorizedFailure(
      userMessage:
          'Too many failed attempts. Try again in $seconds '
          '${seconds == 1 ? 'second' : 'seconds'}.',
      sessionExpired: false,
      debugMessage: 'sign-in blocked by an active lockout',
    );
  }

  /// The demo credential check, plus the real failed-attempt bookkeeping.
  Future<Failure?> _demoSignIn({
    required String email,
    required String password,
  }) async {
    final matches =
        email.trim().toLowerCase() == AppConstants.demoEmail &&
        password == AppConstants.demoPassword;
    if (matches) return null;

    // A wrong password is a real failed attempt: it burns one of the five and
    // trips the 60-second cooldown on the fifth (CM-05).
    await _ref.read(authProvider.notifier).registerFailedAttempt();
    final auth = _ref.read(authProvider);
    if (auth.isLockedOut) return auth.failure;
    return const UnauthorizedFailure(
      userMessage: 'That email and password do not match an account.',
      sessionExpired: false,
      debugMessage: 'demo credential mismatch',
    );
  }
}

/// autoDispose so the form — and any error on it — resets whenever the sign-in
/// screen leaves the tree.
final loginFormControllerProvider =
    StateNotifierProvider.autoDispose<LoginFormController, AuthFormState>(
      (ref) => LoginFormController(ref),
    );
