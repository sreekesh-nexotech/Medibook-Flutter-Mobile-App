import '../../../../app/config/constants.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/user.dart';

/// The app's authentication state.
///
/// Sealed, so the router's redirect and every guard must handle all three
/// cases — the shape that makes "signed out but the screen still rendered"
/// impossible to write by accident:
///
/// * [AuthUnknown] — app just started, local storage not read yet. The router
///   shows a splash and **does not** redirect, so a returning user never
///   flashes the sign-in screen.
/// * [AuthUnauthenticated] — nobody signed in. Carries the failed-attempt
///   counter and lockout deadline (CM-05), because those outlive any one
///   attempt and the sign-in screen has to render them.
/// * [AuthAuthenticated] — a [User] and a valid session.
///
/// ```dart
/// switch (ref.watch(authProvider)) {
///   AuthUnknown() => const SplashScreen(),
///   AuthUnauthenticated(:final isLockedOut) when isLockedOut => LockoutScreen(),
///   AuthUnauthenticated() => const LoginScreen(),
///   AuthAuthenticated(:final user) => HomeShell(user: user),
/// }
/// ```
sealed class AuthState {
  const AuthState();

  /// True only for [AuthAuthenticated].
  bool get isAuthenticated => this is AuthAuthenticated;

  /// The signed-in user, or null.
  User? get user => switch (this) {
    AuthAuthenticated(:final user) => user,
    _ => null,
  };

  /// Failed sign-in attempts recorded against this device.
  ///
  /// Lives on the state (not just inside a screen's controller) because the
  /// count must survive navigating away from the sign-in screen — otherwise
  /// the lockout is bypassed by a back-and-forth.
  int get failedAttempts => switch (this) {
    AuthUnauthenticated(:final failedAttempts) => failedAttempts,
    _ => 0,
  };

  /// When the current lockout ends, or null when there is none.
  DateTime? get lockedUntil => switch (this) {
    AuthUnauthenticated(:final lockedUntil) => lockedUntil,
    _ => null,
  };

  /// True while a lockout is in force (CM-05).
  ///
  /// Compares against the wall clock rather than trusting a flag, so a lockout
  /// cannot be escaped by force-quitting: the deadline is what matters, and
  /// `AuthRepository` persists it.
  bool get isLockedOut {
    final until = lockedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  /// Time left on the lockout, or [Duration.zero]. Feeds `AppCountdown`.
  Duration get lockoutRemaining {
    final until = lockedUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Attempts left before lockout. Zero once locked out.
  int get attemptsRemaining {
    final left = AppConstants.maxLoginAttempts - failedAttempts;
    return left < 0 ? 0 : left;
  }

  /// True once the user is one failed attempt from a lockout — the point at
  /// which the sign-in screen should warn them.
  bool get isLastAttempt => !isLockedOut && attemptsRemaining == 1;

  /// The most recent auth failure, or null.
  Failure? get failure => switch (this) {
    AuthUnauthenticated(:final failure) => failure,
    _ => null,
  };
}

/// Startup: the stored session has not been read yet. Render a splash, do not
/// redirect.
class AuthUnknown extends AuthState {
  const AuthUnknown();

  @override
  bool operator ==(Object other) => other is AuthUnknown;

  @override
  int get hashCode => (AuthUnknown).hashCode;

  @override
  String toString() => 'AuthUnknown()';
}

/// Nobody is signed in.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({
    this.failedAttempts = 0,
    this.lockedUntil,
    this.failure,
    this.isSubmitting = false,
  });

  @override
  final int failedAttempts;

  @override
  final DateTime? lockedUntil;

  /// Why the last attempt failed, for the form's error slot. Cleared as soon
  /// as the user edits a field.
  @override
  final Failure? failure;

  /// True while a sign-in request is in flight — the sign-in button's
  /// `loading` flag, which is also what blocks a double submit.
  final bool isSubmitting;

  AuthUnauthenticated copyWith({
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLockout = false,
    Failure? failure,
    bool clearFailure = false,
    bool? isSubmitting,
  }) {
    return AuthUnauthenticated(
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: clearLockout ? null : (lockedUntil ?? this.lockedUntil),
      failure: clearFailure ? null : (failure ?? this.failure),
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuthUnauthenticated &&
      other.failedAttempts == failedAttempts &&
      other.lockedUntil == lockedUntil &&
      other.failure == failure &&
      other.isSubmitting == isSubmitting;

  @override
  int get hashCode =>
      Object.hash(failedAttempts, lockedUntil, failure, isSubmitting);

  @override
  String toString() =>
      'AuthUnauthenticated(attempts: $failedAttempts, '
      'lockedUntil: ${lockedUntil?.toIso8601String()}, '
      'failure: ${failure?.code})';
}

/// A user is signed in.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.user, required this.session});

  @override
  final User user;

  /// The live credential. Never rendered; the UI reads [user].
  final AuthSession session;

  AuthAuthenticated copyWith({User? user, AuthSession? session}) =>
      AuthAuthenticated(
        user: user ?? this.user,
        session: session ?? this.session,
      );

  @override
  bool operator ==(Object other) =>
      other is AuthAuthenticated &&
      other.user == user &&
      other.session.accessToken == session.accessToken;

  @override
  int get hashCode => Object.hash(user, session.accessToken);

  @override
  String toString() => 'AuthAuthenticated(${user.id})';
}
