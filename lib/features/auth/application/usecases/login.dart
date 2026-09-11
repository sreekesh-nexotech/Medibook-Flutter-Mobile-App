import '../../../../app/config/constants.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/repositories/auth_repository.dart';

/// What a sign-in attempt produced.
sealed class LoginOutcome {
  const LoginOutcome();
}

/// Signed in. The notifier turns this into [AuthAuthenticated].
class LoginSucceeded extends LoginOutcome {
  const LoginSucceeded(this.result);

  final AuthResult result;
}

/// The attempt failed and the counter advanced.
class LoginRejected extends LoginOutcome {
  const LoginRejected({
    required this.failure,
    required this.failedAttempts,
    this.lockedUntil,
  });

  final Failure failure;

  /// Attempts recorded after this one.
  final int failedAttempts;

  /// Set when this attempt tripped the lockout.
  final DateTime? lockedUntil;

  bool get lockedOut => lockedUntil != null;
}

/// The attempt was refused without being tried, because a lockout is already
/// in force (CM-05).
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
/// Coding Standards §1.1 and §6.1: the rule "five failed attempts locks the
/// account for 60 seconds" is *business logic*, so it lives here — not in a
/// screen, not in a Riverpod notifier, and not duplicated across the
/// email/password and mobile/OTP paths. The notifier calls this and only
/// translates the outcome into state.
///
/// ```dart
/// final outcome = await Login(repository)(email: e, password: p);
/// ```
class Login {
  const Login(this._repository);

  final AuthRepository _repository;

  /// Attempt an email/password sign-in.
  ///
  /// Order of operations is deliberate:
  /// 1. **Lockout first.** A locked-out device does not reach the network, so
  ///    the cooldown cannot be brute-forced.
  /// 2. **Validate locally.** A malformed email is a form error, not a failed
  ///    attempt — it must not burn one of the five.
  /// 3. Call the repository; on rejection, advance the persisted counter and
  ///    start a lockout if it reached [AppConstants.maxLoginAttempts].
  Future<LoginOutcome> call({
    required String email,
    required String password,
  }) {
    final emailError = Validators.email(email);
    return _attempt(
      localError: emailError ?? Validators.requiredPassword(password),
      localField: emailError == null ? 'password' : 'email',
      request: () => _repository.login(email: email, password: password),
    );
  }

  /// Attempt a mobile/OTP sign-in (CM-04). Shares the same lockout budget —
  /// two doors into one account cannot each get five tries.
  Future<LoginOutcome> withOtp({
    required String phone,
    required String code,
  }) {
    final phoneError = Validators.phone(phone);
    return _attempt(
      localError: phoneError ?? Validators.otp(code),
      localField: phoneError != null ? 'phone' : 'code',
      request: () => _repository.loginWithOtp(phone: phone, code: code),
    );
  }

  Future<LoginOutcome> _attempt({
    required String? localError,
    required String localField,
    required Future<AuthResult> Function() request,
  }) async {
    final existingLock = await _repository.lockedUntil();
    if (existingLock != null && existingLock.isAfter(DateTime.now())) {
      return LoginLockedOut(lockedUntil: existingLock);
    }

    if (localError != null) {
      // Not a failed *credential* attempt — the counter stays put.
      return LoginRejected(
        failure: ValidationFailure(
          userMessage: localError,
          fieldErrors: {localField: localError},
        ),
        failedAttempts: await _repository.failedAttempts(),
      );
    }

    try {
      final result = await request();
      await _repository.clearFailedAttempts();
      return LoginSucceeded(result);
    } catch (error, stackTrace) {
      final failure = error.asFailure(stackTrace);

      // A network problem is not the user's fault and must not count against
      // them — only a credential rejection does.
      if (failure is! UnauthorizedFailure && failure is! ValidationFailure) {
        return LoginRejected(
          failure: failure,
          failedAttempts: await _repository.failedAttempts(),
        );
      }

      final attempts = await _repository.registerFailedAttempt();
      if (attempts >= AppConstants.maxLoginAttempts) {
        final until = DateTime.now().add(AppConstants.loginLockoutCooldown);
        await _repository.lockOut(until);
        return LoginRejected(
          failure: failure,
          failedAttempts: attempts,
          lockedUntil: until,
        );
      }
      return LoginRejected(failure: failure, failedAttempts: attempts);
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
  Future<Failure?> call() async {
    try {
      await _repository.logout();
      return null;
    } catch (error, stackTrace) {
      return error.asFailure(stackTrace);
    }
  }
}
