import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import 'auth_provider.dart';
import '../../domain/entities/user.dart';
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
/// Every attempt goes through `authProvider`, which forwards the server's
/// lockout rule and — on success — mints the session that the router's
/// sign-in guard checks. Navigation stays in the screen.
class LoginFormController extends AuthFormController {
  LoginFormController(this._ref);

  final Ref _ref;

  @override
  String? validateField(String field, String value) => switch (field) {
    LoginFields.email => _identifierError(value),
    LoginFields.password => Validators.requiredPassword(value),
    LoginFields.phone => Validators.phone(value),
    _ => null,
  };

  /// The email tab accepts an email **or** an E.164 number, because the
  /// backend's `identifier` does (§4.5).
  static String? _identifierError(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Enter your email or mobile number';
    if (Validators.isEmail(trimmed)) return null;
    if (Validators.phoneE164(trimmed) == null) return null;
    return 'Enter a valid email address or mobile number';
  }

  /// Validate the email tab. True when it may be submitted.
  bool validateEmailForm({required String email, required String password}) =>
      validateAll(<String, String>{
        LoginFields.email: email,
        LoginFields.password: password,
      });

  /// Validate the mobile tab. True when it may be submitted.
  bool validateMobileForm({required String phone}) =>
      validateAll(<String, String>{LoginFields.phone: phone});

  /// Attempt an email/phone + password sign-in.
  ///
  /// Returns true when the screen should navigate on. A false return always
  /// leaves either a field error or `state.failure` behind for the screen to
  /// render, so a silent failure is not possible.
  Future<bool> signInWithPassword({
    required String identifier,
    required String password,
  }) async {
    if (state.isBusy) return false;

    final lockout = _lockoutFailure(identifier);
    if (lockout != null) {
      setFailure(lockout);
      return false;
    }

    setBusy(true);
    try {
      final failure = await _ref
          .read(authProvider.notifier)
          .loginWithPassword(identifier: identifier.trim(), password: password);
      _render(failure);
      return failure == null;
    } finally {
      setBusy(false);
    }
  }

  /// Ask for a one-time code to be sent to [phoneE164] before the mobile
  /// sign-in continues to `/verify`. Returns the challenge, or null with the
  /// failure rendered.
  Future<OtpChallenge?> requestLoginCode({required String phoneE164}) async {
    if (state.isBusy) return null;

    final lockout = _lockoutFailure(phoneE164);
    if (lockout != null) {
      setFailure(lockout);
      return null;
    }

    setBusy(true);
    try {
      final challenge = await CodeDelivery.requestLoginCode(_ref, phoneE164);
      _render(challenge == null ? CodeDelivery.lastFailure(_ref) : null);
      return challenge;
    } finally {
      setBusy(false);
    }
  }

  /// A server field error lands on its field; anything else is form-level.
  void _render(Failure? failure) {
    if (failure is ValidationFailure && failure.fieldErrors.isNotEmpty) {
      for (final entry in failure.fieldErrors.entries) {
        final field = switch (entry.key) {
          'identifier' => LoginFields.email,
          'phone_e164' => LoginFields.phone,
          'password' => LoginFields.password,
          _ => entry.key,
        };
        setFieldError(field, entry.value);
      }
      setFailure(null);
      return;
    }
    setFailure(failure);
  }

  /// The lockout of [identifier]'s account as a failure, or null when
  /// sign-in is allowed. Another account's lockout does not count.
  Failure? _lockoutFailure(String identifier) {
    final auth = _ref.read(authProvider).scopedTo(identifier);
    if (!auth.isLockedOut) return null;
    final minutes = (auth.lockoutRemaining.inSeconds / 60).ceil();
    return UnauthorizedFailure(
      userMessage: minutes <= 1
          ? 'Too many failed attempts. Try again in a minute.'
          : 'Too many failed attempts. Try again in $minutes minutes.',
      sessionExpired: false,
      debugMessage: 'sign-in blocked by an active lockout',
    );
  }
}

/// autoDispose so the form — and any error on it — resets whenever the sign-in
/// screen leaves the tree.
final loginFormControllerProvider =
    StateNotifierProvider.autoDispose<LoginFormController, AuthFormState>(
      (ref) => LoginFormController(ref),
    );
