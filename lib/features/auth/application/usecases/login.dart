import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

/// What a sign-in attempt produced.
sealed class LoginOutcome {
  const LoginOutcome();
}

/// Signed in. The notifier turns this into `AuthAuthenticated`.
class LoginSucceeded extends LoginOutcome {
  const LoginSucceeded(this.result);

  final AuthResult result;
}

/// The attempt failed.
class LoginRejected extends LoginOutcome {
  const LoginRejected({
    required this.failure,
    this.attemptsRemaining,
    this.lockedUntil,
  });

  final Failure failure;

  /// `meta.attempts_remaining`, when the server sent it.
  final int? attemptsRemaining;

  /// Set when this attempt tripped (or hit) the server lockout.
  final DateTime? lockedUntil;

  bool get lockedOut => lockedUntil != null;
}

/// The attempt was refused without being tried, because a server lockout the
/// device remembers is still in force (CM-05).
class LoginLockedOut extends LoginOutcome {
  const LoginLockedOut({required this.lockedUntil});

  final DateTime lockedUntil;

  Duration get remaining {
    final left = lockedUntil.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }
}

/// The sign-in use case.
///
/// The lockout rule — *five failures lock the account for an hour* — is the
/// **server's** (`AUTH_LOCKED_OUT`, `meta.locked_until`,
/// `FLUTTER_API_INTEGRATION.md` §4). This use case does not count attempts of
/// its own; it forwards the server's `attempts_remaining`, remembers the
/// `locked_until` it announces so the form can count it down, and refuses to
/// spend the cooldown on the network. One rule, one owner.
///
/// ```dart
/// final outcome = await Login(repository)(identifier: e, password: p);
/// ```
class Login {
  const Login(this._repository);

  final AuthRepository _repository;

  /// Attempt an email-or-phone + password sign-in (§4.5).
  ///
  /// Order of operations is deliberate:
  /// 1. **Lockout first.** A locked-out device does not reach the network.
  /// 2. **Validate locally.** A malformed identifier is a form error, not a
  ///    failed attempt.
  /// 3. Call the repository and translate the failure.
  Future<LoginOutcome> call({
    required String identifier,
    required String password,
  }) {
    final trimmed = identifier.trim();
    final identifierError = Validators.isEmail(trimmed)
        ? null
        : Validators.phoneE164(trimmed) == null
        ? null
        : 'Enter the email or mobile number on your account';
    return _attempt(
      subject: lockSubject(trimmed),
      localError: identifierError ?? Validators.requiredPassword(password),
      localField: identifierError == null ? 'password' : 'email',
      request: () => _repository.loginWithPassword(
        identifier: trimmed,
        password: password,
      ),
    );
  }

  /// Finish a mobile/OTP sign-in (§4.4) for an open [challengeId] sent to
  /// [phoneE164] (the account a lockout would belong to).
  Future<LoginOutcome> withOtp({
    required String challengeId,
    required String code,
    String? phoneE164,
  }) => _attempt(
    subject: phoneE164 == null ? null : lockSubject(phoneE164),
    localError: Validators.otp(code),
    localField: 'code',
    request: () =>
        _repository.verifyOtpLogin(challengeId: challengeId, code: code),
  );

  /// Finish a sign-up (§4.2) for an open [challengeId]. No account exists
  /// yet, so no lockout can apply to it.
  Future<LoginOutcome> completeSignup({
    required String challengeId,
    required String code,
  }) => _attempt(
    checkLockout: false,
    localError: Validators.otp(code),
    localField: 'code',
    request: () =>
        _repository.verifySignup(challengeId: challengeId, code: code),
  );

  /// [subject] is the account being signed in to: a remembered lockout
  /// applies only to that account (BL-AUTH-035).
  Future<LoginOutcome> _attempt({
    String? subject,
    bool checkLockout = true,
    required String? localError,
    required String localField,
    required Future<AuthResult> Function() request,
  }) async {
    if (checkLockout) {
      final existingLock = await _repository.lockedUntil(identifier: subject);
      if (existingLock != null && existingLock.isAfter(DateTime.now())) {
        return LoginLockedOut(lockedUntil: existingLock);
      }
    }

    if (localError != null) {
      return LoginRejected(
        failure: ValidationFailure(
          userMessage: localError,
          fieldErrors: {localField: localError},
        ),
      );
    }

    try {
      final result = await request();
      await _repository.clearLockout();
      return LoginSucceeded(result);
    } catch (error, stackTrace) {
      final failure = error.asFailure(stackTrace);
      if (failure is UnauthorizedFailure && !failure.sessionExpired) {
        final until = failure.lockedUntil;
        if (until != null) {
          await _repository.rememberLockout(until, identifier: subject);
        }
        return LoginRejected(
          failure: failure,
          attemptsRemaining: failure.attemptsRemaining,
          lockedUntil: until,
        );
      }
      return LoginRejected(failure: failure);
    }
  }
}

/// Sign-out.
///
/// A separate use case because "log out" is more than dropping a token: the
/// repository must clear secure storage, the session/cache boxes and the
/// monitoring identity, and it must do so **even when the server call fails**.
/// That is CM-53, and it belongs in one place.
class Logout {
  const Logout(this._repository);

  final AuthRepository _repository;

  /// Never throws — a sign-out that fails halfway is worse than one that
  /// reports nothing, so the [Failure] is returned for logging instead.
  Future<Failure?> call({bool everywhere = false}) async {
    try {
      if (everywhere) {
        await _repository.logoutAll();
      } else {
        await _repository.logout();
      }
      return null;
    } catch (error, stackTrace) {
      return error.asFailure(stackTrace);
    }
  }
}

/// The account a sign-in is for, in one spelling: trimmed, lower-case, and a
/// bare 10-digit mobile written as `+91…`. Lockouts are remembered against
/// it.
String lockSubject(String identifier) {
  final trimmed = identifier.trim().toLowerCase();
  if (trimmed.contains('@')) return trimmed;
  final digits = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
  if (RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) return '+91$digits';
  return digits;
}
