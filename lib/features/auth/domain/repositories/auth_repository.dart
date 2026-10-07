import '../entities/user.dart';

/// The auth contract the application layer depends on
/// (`FLUTTER_API_INTEGRATION.md` §4 and §5.1–5.6).
///
/// Abstract on purpose: the presentation and application layers know only this
/// interface, so they can be tested against an in-memory fake, and the real
/// `AuthRepositoryImpl` (`infrastructure/repositories/`) slots in without a
/// single call-site change (Coding Standards §1.1, §6.1).
///
/// **Error contract:** every method throws a `Failure` from
/// `core/error/failure.dart` — never a raw exception, never a `dio` type.
/// Specifically:
/// * wrong credentials / wrong code → `UnauthorizedFailure(sessionExpired:
///   false)` with `apiCode` set and `attemptsRemaining` / `lockedUntil` from
///   `meta`;
/// * malformed input the server rejected → `ValidationFailure` with
///   `fieldErrors`;
/// * `UNDER_AGE`, `STATE_CONFLICT` … → `ConflictFailure`;
/// * no connection / timeout → `NetworkFailure` / `TimeoutFailure`.
abstract interface class AuthRepository {
  // ---- Local session ----

  /// The cached signed-in user, or null when nobody is signed in.
  ///
  /// Reads local storage only — no network — so app start can decide between
  /// the sign-in screen and the home shell without a round trip.
  Future<User?> currentUser();

  /// Whether a stored session exists (access token present; the refresh
  /// token keeps it alive for up to 30 days).
  Future<bool> hasValidSession();

  /// The current access token, or null. For the HTTP client's bearer header
  /// and the WebSocket subprotocol.
  Future<String?> accessToken();

  // ---- Sign-in (§4.3–4.5) ----

  /// Email-or-phone + password (§4.5). [identifier] is an E.164 number or an
  /// email.
  Future<AuthResult> loginWithPassword({
    required String identifier,
    required String password,
  });

  /// Send a sign-in code to [phoneE164] (§4.3). An unregistered number gets
  /// the same challenge and no SMS.
  Future<OtpChallenge> startOtpLogin({required String phoneE164});

  /// Finish a code sign-in (§4.4).
  Future<AuthResult> verifyOtpLogin({
    required String challengeId,
    required String code,
  });

  /// Re-send the code for any open challenge (§4.6).
  Future<OtpChallenge> resendOtp({required String challengeId});

  // ---- Sign-up (§4.1–4.2) ----

  /// Validate the form and send the code. No account exists until
  /// [verifySignup] succeeds.
  Future<OtpChallenge> startSignup(SignupRequest request);

  /// Create the account, sign in, and return the self person id.
  Future<AuthResult> verifySignup({
    required String challengeId,
    required String code,
  });

  // ---- Password reset, signed out (§4.7) ----

  Future<OtpChallenge> startPasswordReset({required String identifier});

  Future<PasswordResetGrant> verifyPasswordReset({
    required String challengeId,
    required String code,
  });

  /// Sets the new password and revokes every session — the caller sends the
  /// user to sign-in.
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  });

  // ---- Session lifecycle (§4.8–4.9) ----

  /// Exchange the stored refresh token for a new pair (§4.8). Throws
  /// `UnauthorizedFailure(sessionExpired: true)` when the refresh token is
  /// dead — the caller's only correct response to that is [logout].
  ///
  /// Single-flight: calls that overlap share one server call, because the
  /// server revokes the session when a refresh token is presented twice.
  Future<AuthSession> refreshSession();

  /// End this session.
  ///
  /// Implementations must clear **everything** local — tokens, the session
  /// and cache boxes from `HiveBoxes.clearedOnLogout`, the analytics/crash
  /// identity — and must do so even if the server call fails (CM-53).
  Future<void> logout();

  /// End every session of the user (§4.9), then clear local state.
  Future<void> logoutAll();

  /// Drop local state only, without a server call — for a session the server
  /// already ended (`AUTH_SESSION_REVOKED`).
  Future<void> clearLocalSession();

  // ---- Account (§5.1, §5.5) ----

  /// `GET /patient/me` — refresh the cached user from the server.
  Future<User> fetchMe();

  /// Set (OTP-only account) or change the password (§5.5). A wrong
  /// [currentPassword] is an `UnauthorizedFailure(sessionExpired: false)`
  /// with `fieldErrors['current_password']` — not a session expiry.
  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  });

  // ---- Lockout mirror (§4: `AUTH_LOCKED_OUT`, `meta.locked_until`) ----
  //
  // The server owns the rule (5 failures → 1 hour). The device only remembers
  // the deadline the server announced, so the sign-in form can count it down
  // and refuse to spend the cooldown guessing.

  /// The lockout in force for [identifier] (or for any account when null),
  /// or null. The server locks one account, not the phone: a lockout of
  /// another account does not apply (BL-AUTH-035).
  Future<DateTime?> lockedUntil({String? identifier});

  /// The account the remembered lockout belongs to, or null.
  Future<String?> lockedIdentifier();

  Future<void> rememberLockout(DateTime until, {String? identifier});

  Future<void> clearLockout();
}
