import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/device_identity.dart';
import '../../../../core/storage/secure_store.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../states/auth_state.dart';
import '../usecases/login.dart';

/// The process-wide secure store. Overridden in
/// `app/bootstrap/app_bootstrap.dart` with the keystore-backed implementation.
final secureStoreProvider = Provider<SecureStore>(
  (ref) => InMemorySecureStore(),
);

/// The stable per-install id for `X-Device-Fingerprint` (§1.3).
final deviceIdentityProvider = Provider<DeviceIdentity>(
  (ref) => DeviceIdentity(ref.watch(secureStoreProvider)),
);

/// The HTTP client. Overridden with the Dio client by bootstrap; the default
/// refuses every call loudly rather than faking a success.
final apiClientProvider = Provider<ApiClient>(
  (ref) => const UnimplementedApiClient(),
);

/// The auth repository. Every auth caller depends on this, not on the impl,
/// so a test can `overrideWithValue(FakeAuthRepository())`.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) =>
      throw UnimplementedError('authRepositoryProvider is wired in app/di'),
);

/// The sign-in use case (forwards the server's lockout rule).
final loginUseCaseProvider = Provider<Login>(
  (ref) => Login(ref.watch(authRepositoryProvider)),
);

/// The sign-out use case (holds the CM-53 clear-everything rule).
final logoutUseCaseProvider = Provider<Logout>(
  (ref) => Logout(ref.watch(authRepositoryProvider)),
);

/// Owns the session for the whole app.
///
/// A [StateNotifier] over the sealed [AuthState]. Deliberately **not**
/// autoDispose: this is app-lifetime state that the router's redirect reads.
///
/// State starts at [AuthUnknown] and [restore] resolves it, so the router can
/// hold a splash instead of flashing the sign-in screen at a returning user.
///
/// The business rules live in the [Login] / [Logout] use cases; this class
/// only translates their outcomes into state. Every OTP "start" call returns
/// the [OtpChallenge] the matching "verify" needs — the screen carries its id
/// to `/verify` (see `VerifyRequest`).
class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthRepository repository,
    required Login login,
    required Logout logout,
  }) : _repository = repository,
       _login = login,
       _logout = logout,
       super(const AuthUnknown());

  final AuthRepository _repository;
  final Login _login;
  final Logout _logout;

  /// Resolve [AuthUnknown] by reading local storage, then refresh the cached
  /// user from `GET /patient/me` in the background. Call once at start.
  Future<void> restore() async {
    try {
      final hasSession = await _repository.hasValidSession();
      final user = await _repository.currentUser();
      if (hasSession && user != null) {
        state = AuthAuthenticated(user: user);
        _refreshMe();
        return;
      }
      state = AuthUnauthenticated(
        lockedUntil: await _repository.lockedUntil(),
        subject: await _repository.lockedIdentifier(),
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        'Session restore failed; treating as signed out',
        name: 'auth',
        error: error,
        stackTrace: stackTrace,
      );
      state = const AuthUnauthenticated();
    }
  }

  /// `GET /patient/me`. A session-ending failure signs the user out (the
  /// HTTP client also reports it through [onSessionLost]); anything else is
  /// logged and the cached user stays.
  Future<void> _refreshMe() async {
    try {
      final fresh = await _repository.fetchMe();
      final current = state;
      if (current is AuthAuthenticated) state = current.copyWith(user: fresh);
    } on UnauthorizedFailure catch (failure) {
      if (failure.sessionExpired) await onSessionLost(failure);
    } catch (error) {
      AppLogger.warning('/me refresh failed', name: 'auth', error: error);
    }
  }

  /// Public form of the `/me` refresh, for pull-to-refresh on Profile.
  Future<void> refreshMe() => _refreshMe();

  // ---- Password ----

  /// Email-or-phone + password sign-in. Returns null on success, or the
  /// [Failure] the form should render.
  Future<Failure?> loginWithPassword({
    required String identifier,
    required String password,
  }) => _applyOutcome(
    () => _login(identifier: identifier, password: password),
    subject: lockSubject(identifier),
    passwordAttempt: true,
  );

  // ---- OTP ----

  /// Send a sign-in code (§4.3). Returns the challenge, or null with the
  /// failure left in [AuthState.failure].
  Future<OtpChallenge?> startOtpLogin({required String phoneE164}) =>
      _startChallenge(
        () => _repository.startOtpLogin(phoneE164: phoneE164),
        subject: lockSubject(phoneE164),
      );

  /// Finish a code sign-in (§4.4).
  ///
  /// A wrong code is not a wrong password: its attempts are shown on the
  /// code screen, never as the sign-in form's password warning (BL-AUTH-036).
  Future<Failure?> verifyOtpLogin({
    required String challengeId,
    required String code,
    String? phoneE164,
  }) => _applyOutcome(
    () => _login.withOtp(
      challengeId: challengeId,
      code: code,
      phoneE164: phoneE164,
    ),
    subject: phoneE164 == null ? null : lockSubject(phoneE164),
  );

  /// Re-send the code for any open challenge (§4.6).
  Future<OtpChallenge?> resendOtp({required String challengeId}) =>
      _startChallenge(() => _repository.resendOtp(challengeId: challengeId));

  // ---- Sign-up ----

  /// Validate and send the sign-up code (§4.1). No account exists yet.
  Future<OtpChallenge?> startSignup(SignupRequest request) =>
      _startChallenge(() => _repository.startSignup(request));

  /// Create the account and sign in (§4.2).
  Future<Failure?> verifySignup({
    required String challengeId,
    required String code,
  }) => _applyOutcome(
    () => _login.completeSignup(challengeId: challengeId, code: code),
  );

  // ---- Password reset ----

  Future<OtpChallenge?> startPasswordReset({required String identifier}) =>
      _startChallenge(
        () => _repository.startPasswordReset(identifier: identifier),
        subject: lockSubject(identifier),
      );

  /// Returns the grant, or null with the failure left in the state.
  Future<PasswordResetGrant?> verifyPasswordReset({
    required String challengeId,
    required String code,
  }) async {
    try {
      final grant = await _repository.verifyPasswordReset(
        challengeId: challengeId,
        code: code,
      );
      _setFailure(null);
      return grant;
    } catch (error, stackTrace) {
      _setFailure(error.asFailure(stackTrace));
      return null;
    }
  }

  /// Sets the new password. Every session is revoked; the caller goes to
  /// sign-in. Returns null on success.
  Future<Failure?> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      await _repository.resetPassword(
        resetToken: resetToken,
        newPassword: newPassword,
      );
      return null;
    } catch (error, stackTrace) {
      return error.asFailure(stackTrace);
    }
  }

  // ---- Session ----

  /// [subject] is the account the attempt is for; [passwordAttempt] says
  /// whether the server's `attempts_remaining` is the password budget the
  /// sign-in form warns about.
  Future<Failure?> _applyOutcome(
    Future<LoginOutcome> Function() attempt, {
    String? subject,
    bool passwordAttempt = false,
  }) async {
    final before = state;
    if (before is AuthUnauthenticated) {
      // Blocks the double-submit the audit found on other forms (§3.5.6).
      if (before.isSubmitting) return before.failure;
      state = before.copyWith(isSubmitting: true, clearFailure: true);
    }

    final outcome = await attempt();

    switch (outcome) {
      case LoginSucceeded(:final result):
        state = AuthAuthenticated(
          user: result.user,
          selfPersonId: result.selfPersonId,
        );
        // The sign-in body carries the bare `user`; the profile fields
        // (gender, DOB, blood group…) only come with `GET /me`.
        _refreshMe();
        return null;

      case LoginLockedOut(:final lockedUntil):
        state = AuthUnauthenticated(
          serverAttemptsRemaining: 0,
          lockedUntil: lockedUntil,
          failure: _lockoutFailure(lockedUntil),
          subject: subject,
        );
        return state.failure;

      case LoginRejected(
        :final failure,
        :final attemptsRemaining,
        :final lockedUntil,
      ):
        state = AuthUnauthenticated(
          serverAttemptsRemaining: lockedUntil != null
              ? 0
              : passwordAttempt
              ? attemptsRemaining
              : null,
          lockedUntil: lockedUntil,
          failure: lockedUntil == null ? failure : _lockoutFailure(lockedUntil),
          subject: subject,
        );
        return state.failure;
    }
  }

  /// [subject]: the account the code is for. Only that account's lockout
  /// stops it — another account locked on this phone does not (BL-AUTH-035).
  Future<OtpChallenge?> _startChallenge(
    Future<OtpChallenge> Function() request, {
    String? subject,
  }) async {
    final before = subject == null ? null : state.scopedTo(subject);
    if (before is AuthUnauthenticated && before.isLockedOut) {
      _setFailure(_lockoutFailure(before.lockedUntil!));
      return null;
    }
    try {
      final challenge = await request();
      _setFailure(null);
      return challenge;
    } catch (error, stackTrace) {
      _setFailure(error.asFailure(stackTrace));
      return null;
    }
  }

  void _setFailure(Failure? failure) {
    final current = state;
    if (current is! AuthUnauthenticated) return;
    state = failure == null
        ? current.copyWith(clearFailure: true)
        : current.copyWith(failure: failure);
  }

  /// Called when the lockout countdown reaches zero, so the sign-in form
  /// re-enables without a restart.
  Future<void> clearLockoutIfExpired() async {
    final current = state;
    if (current is! AuthUnauthenticated) return;
    final until = current.lockedUntil;
    if (until == null || until.isAfter(DateTime.now())) return;
    await _repository.clearLockout();
    state = const AuthUnauthenticated();
  }

  /// Clear the form error as soon as the user edits a field.
  void clearError() {
    final current = state;
    if (current is AuthUnauthenticated && current.failure != null) {
      state = current.copyWith(clearFailure: true);
    }
  }

  /// Sign out and clear **all** session state (CM-53). With [everywhere],
  /// every session of the user is ended (§4.9).
  ///
  /// The state flips to [AuthUnauthenticated] unconditionally, even if the
  /// repository reported a problem — a sign-out that leaves the user looking
  /// at a signed-in screen is the worse failure.
  Future<void> logout({bool everywhere = false}) async {
    final failure = await _logout(everywhere: everywhere);
    if (failure != null) {
      AppLogger.warning(
        'Logout reported ${failure.code}; session cleared regardless',
        name: 'auth',
      );
    }
    state = const AuthUnauthenticated();
  }

  /// The server ended this session (`AUTH_SESSION_REVOKED` and friends, or a
  /// failed refresh). Drop local state without a server call and route to
  /// sign-in with the reason.
  Future<void> onSessionLost(Failure failure) async {
    if (state is! AuthAuthenticated) return;
    AppLogger.info('Session lost: ${failure.apiCode}', name: 'auth');
    await _repository.clearLocalSession();
    state = AuthUnauthenticated(failure: failure);
  }

  /// Replace the cached user after a profile edit (CM-47).
  void updateUser(User user) {
    final current = state;
    if (current is AuthAuthenticated) {
      state = current.copyWith(user: user);
    }
  }

  /// Record the "self" person id once the persons list has been read.
  void setSelfPersonId(String? id) {
    final current = state;
    if (current is AuthAuthenticated && current.selfPersonId != id) {
      state = current.copyWith(selfPersonId: id);
    }
  }

  Failure _lockoutFailure(DateTime until) {
    final minutes = (until.difference(DateTime.now()).inSeconds / 60).ceil();
    return UnauthorizedFailure(
      userMessage: minutes <= 1
          ? 'Too many failed attempts. Try again in a minute.'
          : 'Too many failed attempts. Try again in $minutes minutes.',
      sessionExpired: false,
      debugMessage: 'locked until ${until.toIso8601String()}',
    );
  }
}

/// The app's auth state. Read this from the router redirect and any guard.
final authProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    repository: ref.watch(authRepositoryProvider),
    login: ref.watch(loginUseCaseProvider),
    logout: ref.watch(logoutUseCaseProvider),
  ),
);

/// True when a user is signed in — the sign-in guard's condition.
///
/// A narrow `select` so a screen watching "am I signed in" does not rebuild
/// when the failed-attempt counter changes (Coding Standards §8).
final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(authProvider.select((s) => s.isAuthenticated)),
);

/// The signed-in user, or null.
final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authProvider.select((s) => s.user)),
);

/// The `person_id` for "book for myself", or null when the account has no
/// self person yet.
final selfPersonIdProvider = Provider<String?>(
  (ref) => ref.watch(
    authProvider.select((s) => s is AuthAuthenticated ? s.selfPersonId : null),
  ),
);

/// True while a sign-in lockout is in force (CM-05) — what the disabled
/// sign-in button reads.
final isLockedOutProvider = Provider<bool>(
  (ref) => ref.watch(authProvider.select((s) => s.isLockedOut)),
);

/// The cache's tenant scope: the signed-in account's id, or null when nobody
/// is signed in. Bootstrap hands it to `CachedFetcher`.
///
/// The account, not the access token: the token is replaced every 15 minutes,
/// and keys built from it lost everything saved before the last refresh to
/// offline use (DEF-065). Local reads only.
final cacheScopeProvider = Provider<Future<String?> Function()>((ref) {
  return () async {
    final repository = ref.read(authRepositoryProvider);
    final token = await repository.accessToken();
    if (token == null || token.isEmpty) return null;
    return (await repository.currentUser())?.id;
  };
});

/// The callbacks the HTTP client needs from this feature. Bootstrap hands
/// them to `DioApiClient`; nothing in `core/` imports the feature.
final apiSessionHooksProvider = Provider<ApiSessionHooks>(
  (ref) => ApiSessionHooks(
    accessToken: () => ref.read(authRepositoryProvider).accessToken(),
    deviceFingerprint: () => ref.read(deviceIdentityProvider).fingerprint(),
    refresh: () async =>
        (await ref.read(authRepositoryProvider).refreshSession()).accessToken,
    onSessionLost: (failure) =>
        ref.read(authProvider.notifier).onSessionLost(failure),
  ),
);
