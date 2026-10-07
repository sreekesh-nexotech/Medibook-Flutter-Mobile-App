import '../usecases/login.dart' show lockSubject;
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
/// * [AuthUnauthenticated] — nobody signed in. Carries the server-announced
///   attempts-remaining and lockout deadline (`AUTH_INVALID_CREDENTIALS` /
///   `AUTH_LOCKED_OUT` meta), because those outlive any one attempt and the
///   sign-in screen has to render them.
/// * [AuthAuthenticated] — a [User] and a valid session.
sealed class AuthState {
  const AuthState();

  /// True only for [AuthAuthenticated].
  bool get isAuthenticated => this is AuthAuthenticated;

  /// The signed-in user, or null.
  User? get user => switch (this) {
    AuthAuthenticated(:final user) => user,
    _ => null,
  };

  /// Attempts left before the server locks the account, or null when the
  /// server has not said (no failed attempt yet).
  int? get serverAttemptsRemaining => switch (this) {
    AuthUnauthenticated(:final serverAttemptsRemaining) =>
      serverAttemptsRemaining,
    _ => null,
  };

  /// Failed sign-in attempts, derived from the server's
  /// `attempts_remaining` against [AppConstants.maxLoginAttempts].
  int get failedAttempts {
    final remaining = serverAttemptsRemaining;
    if (remaining == null) return 0;
    final failed = AppConstants.maxLoginAttempts - remaining;
    return failed < 0 ? 0 : failed;
  }

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

  /// Attempts left before lockout. Zero once locked out; the full budget when
  /// the server has not yet reported a failure.
  int get attemptsRemaining {
    if (isLockedOut) return 0;
    return serverAttemptsRemaining ?? AppConstants.maxLoginAttempts;
  }

  /// True once the user is one failed attempt from a lockout — the point at
  /// which the sign-in screen should warn them.
  bool get isLastAttempt => !isLockedOut && attemptsRemaining == 1;

  /// The most recent auth failure, or null.
  Failure? get failure => switch (this) {
    AuthUnauthenticated(:final failure) => failure,
    _ => null,
  };

  /// This state as it applies to signing in to [identifier]: the attempt
  /// count and lockout belong to one account, so for any other account they
  /// are dropped (BL-AUTH-035). A lockout remembered without an account
  /// still applies to all.
  AuthState scopedTo(String identifier) {
    final self = this;
    if (self is! AuthUnauthenticated) return self;
    final subject = self.subject;
    if (subject == null || subject == lockSubject(identifier)) return self;
    return self.copyWith(clearAttempts: true, clearLockout: true);
  }
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
    this.serverAttemptsRemaining,
    this.lockedUntil,
    this.failure,
    this.isSubmitting = false,
    this.subject,
  });

  /// The account ([lockSubject]) that [serverAttemptsRemaining] and
  /// [lockedUntil] belong to, or null when they are not tied to one.
  final String? subject;

  /// `meta.attempts_remaining` from the last rejected attempt, or null.
  @override
  final int? serverAttemptsRemaining;

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
    int? serverAttemptsRemaining,
    bool clearAttempts = false,
    DateTime? lockedUntil,
    bool clearLockout = false,
    Failure? failure,
    bool clearFailure = false,
    bool? isSubmitting,
  }) {
    return AuthUnauthenticated(
      subject: subject,
      serverAttemptsRemaining: clearAttempts
          ? null
          : (serverAttemptsRemaining ?? this.serverAttemptsRemaining),
      lockedUntil: clearLockout ? null : (lockedUntil ?? this.lockedUntil),
      failure: clearFailure ? null : (failure ?? this.failure),
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuthUnauthenticated &&
      other.serverAttemptsRemaining == serverAttemptsRemaining &&
      other.lockedUntil == lockedUntil &&
      other.failure == failure &&
      other.isSubmitting == isSubmitting &&
      other.subject == subject;

  @override
  int get hashCode => Object.hash(
    serverAttemptsRemaining,
    lockedUntil,
    failure,
    isSubmitting,
    subject,
  );

  @override
  String toString() =>
      'AuthUnauthenticated(attemptsRemaining: $serverAttemptsRemaining, '
      'lockedUntil: ${lockedUntil?.toIso8601String()}, '
      'failure: ${failure?.code})';
}

/// A user is signed in.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.user, this.selfPersonId});

  @override
  final User user;

  /// The `person_id` for "book for myself" (§4.2), when known. Null on an
  /// account with no self person (the persons list is empty) — the booking
  /// flow then asks the user to pick or add a family member.
  final String? selfPersonId;

  AuthAuthenticated copyWith({User? user, String? selfPersonId}) =>
      AuthAuthenticated(
        user: user ?? this.user,
        selfPersonId: selfPersonId ?? this.selfPersonId,
      );

  @override
  bool operator ==(Object other) =>
      other is AuthAuthenticated &&
      other.user == user &&
      other.selfPersonId == selfPersonId;

  @override
  int get hashCode => Object.hash(user, selfPersonId);

  @override
  String toString() => 'AuthAuthenticated(${user.id})';
}
