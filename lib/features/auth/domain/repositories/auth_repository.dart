import '../entities/user.dart';

/// A signed-in user plus the credential that proves it.
typedef AuthResult = ({User user, AuthSession session});

/// The auth contract the application layer depends on.
///
/// Abstract on purpose: the presentation and application layers know only this
/// interface, so they can be built and tested against an in-memory fake while
/// the API is still being written, and the real
/// `AuthRepositoryImpl` (`infrastructure/repositories/`) slots in without a
/// single call-site change (Coding Standards §1.1, §6.1).
///
/// **Error contract:** every method throws a `Failure` from
/// `core/error/failure.dart` — never a raw exception, never a `dio` type.
/// Callers therefore only ever `catch (e)` and switch on the failure kind.
/// Specifically:
/// * wrong credentials → `UnauthorizedFailure(sessionExpired: false)`
/// * malformed input the server rejected → `ValidationFailure`
/// * no connection / timeout → `NetworkFailure` / `TimeoutFailure`
abstract interface class AuthRepository {
  /// The cached signed-in user, or null when nobody is signed in.
  ///
  /// Reads local storage only — no network — so app start can decide between
  /// the sign-in screen and the home shell without a round trip.
  Future<User?> currentUser();

  /// Whether a stored session exists and has not expired.
  Future<bool> hasValidSession();

  /// Email + password sign-in (CM-03).
  Future<AuthResult> login({required String email, required String password});

  /// Mobile + OTP sign-in (CM-04). [phone] is the 10-digit national number.
  Future<AuthResult> loginWithOtp({
    required String phone,
    required String code,
  });

  /// Send (or resend) an OTP to [phone].
  Future<void> requestOtp({required String phone});

  /// Create an account (CM-01).
  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  });

  /// Exchange the stored refresh token for a new session (Coding Standards
  /// §6.2). Throws `UnauthorizedFailure` when the refresh token is dead — the
  /// caller's only correct response to that is [logout].
  Future<AuthSession> refreshSession();

  /// End the session.
  ///
  /// Implementations must clear **everything** — access and refresh tokens
  /// from `SecureStore`, the session and cache boxes from
  /// `HiveBoxes.clearedOnLogout`, and the analytics/crash identity — and must
  /// do so even if the server call fails. A logout that leaves data behind is
  /// the CM-53 bug.
  Future<void> logout();

  /// Start a password reset (CM-06): emails/SMSes a code to [email].
  Future<void> requestPasswordReset({required String email});

  /// Finish a password reset with the code from [requestPasswordReset]
  /// (CM-07/CM-08).
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  /// Change the password of the signed-in user (CM-51). Requires the current
  /// password; a wrong one is a `ValidationFailure` on `currentPassword`.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Persistently record a failed sign-in attempt and return the new count.
  ///
  /// Persistent because CM-05's lockout must survive a force-quit — an
  /// in-memory counter is trivially defeated by killing the app.
  Future<int> registerFailedAttempt();

  /// Failed attempts recorded so far.
  Future<int> failedAttempts();

  /// When the current lockout expires, or null when not locked out.
  Future<DateTime?> lockedUntil();

  /// Begin a lockout that ends at [until].
  Future<void> lockOut(DateTime until);

  /// Clear the attempt counter and any lockout (a successful sign-in).
  Future<void> clearFailedAttempts();
}
