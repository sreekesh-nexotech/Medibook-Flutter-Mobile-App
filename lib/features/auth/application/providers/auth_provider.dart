import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/constants.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/storage/secure_store.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../infrastructure/data_sources/local/auth_local_ds.dart';
import '../../infrastructure/data_sources/remote/auth_api.dart';
import '../../infrastructure/repositories/auth_repository_impl.dart';
import '../states/auth_state.dart';
import '../usecases/login.dart';
import '../../../../core/network/api_client.dart';

/// The process-wide secure store. Override in `app/bootstrap/app_bootstrap.dart`
/// with the keystore-backed implementation when the data layer lands.
final secureStoreProvider = Provider<SecureStore>(
  (ref) => InMemorySecureStore(),
);

/// The HTTP client. Overridden with a real client by bootstrap; the default
/// refuses every call loudly rather than faking a success.
final apiClientProvider = Provider<ApiClient>(
  (ref) => const UnimplementedApiClient(),
);

/// Auth remote data source.
final authApiProvider = Provider<AuthApi>(
  (ref) => HttpAuthApi(ref.watch(apiClientProvider)),
);

/// Auth local data source (credentials + the persisted lockout counters).
final authLocalDataSourceProvider = Provider<AuthLocalDataSource>(
  (ref) => AuthLocalDataSourceImpl(
    secureStore: ref.watch(secureStoreProvider),
  ),
);

/// The auth repository. Every auth caller depends on this, not on the impl,
/// so a test can `overrideWithValue(FakeAuthRepository())`.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    api: ref.watch(authApiProvider),
    local: ref.watch(authLocalDataSourceProvider),
  ),
);

/// The sign-in use case (holds the CM-05 lockout rule).
final loginUseCaseProvider = Provider<Login>(
  (ref) => Login(ref.watch(authRepositoryProvider)),
);

/// The sign-out use case (holds the CM-53 clear-everything rule).
final logoutUseCaseProvider = Provider<Logout>(
  (ref) => Logout(ref.watch(authRepositoryProvider)),
);

/// Owns the session for the whole app.
///
/// A [StateNotifier] over the sealed [AuthState], matching the repo's Riverpod
/// style (`ToastController`, `AppointmentsController`) and Coding Standards
/// §2.1 ("`StateNotifierProvider` for feature-level business logic").
/// Deliberately **not** autoDispose: this is app-lifetime state that the
/// router's redirect reads.
///
/// State starts at [AuthUnknown] and [restore] resolves it, so the router can
/// hold a splash instead of flashing the sign-in screen at a returning user.
///
/// The business rules themselves live in the [Login] / [Logout] use cases;
/// this class only translates their outcomes into state.
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

  /// Resolve [AuthUnknown] by reading local storage. Call once from bootstrap
  /// or the splash route.
  Future<void> restore() async {
    try {
      final hasSession = await _repository.hasValidSession();
      final user = await _repository.currentUser();
      if (hasSession && user != null) {
        state = AuthAuthenticated(
          user: user,
          // The live token is held by SecureStore; the state carries an opaque
          // marker so the UI can tell "signed in" without touching the secret.
          session: const AuthSession(accessToken: '<stored>'),
        );
        return;
      }
      state = AuthUnauthenticated(
        failedAttempts: await _repository.failedAttempts(),
        lockedUntil: await _repository.lockedUntil(),
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

  /// Email + password sign-in. Returns null on success, or the [Failure] that
  /// the form should render.
  Future<Failure?> login({
    required String email,
    required String password,
  }) => _applyOutcome(() => _login(email: email, password: password));

  /// Mobile + OTP sign-in (CM-04). Shares the lockout budget with [login].
  Future<Failure?> loginWithOtp({
    required String phone,
    required String code,
  }) => _applyOutcome(() => _login.withOtp(phone: phone, code: code));

  Future<Failure?> _applyOutcome(
    Future<LoginOutcome> Function() attempt,
  ) async {
    final before = state;
    if (before is AuthUnauthenticated) {
      // Blocks the double-submit the audit found on other forms (§3.5.6).
      if (before.isSubmitting) return before.failure;
      state = before.copyWith(isSubmitting: true, clearFailure: true);
    }

    final outcome = await attempt();

    switch (outcome) {
      case LoginSucceeded(:final result):
        state = AuthAuthenticated(user: result.user, session: result.session);
        return null;

      case LoginLockedOut(:final lockedUntil):
        state = AuthUnauthenticated(
          failedAttempts: AppConstants.maxLoginAttempts,
          lockedUntil: lockedUntil,
          failure: _lockoutFailure(lockedUntil),
        );
        return state.failure;

      case LoginRejected(:final failure, :final failedAttempts, :final lockedUntil):
        state = AuthUnauthenticated(
          failedAttempts: failedAttempts,
          lockedUntil: lockedUntil,
          failure: lockedUntil == null
              ? failure
              : _lockoutFailure(lockedUntil),
        );
        return state.failure;
    }
  }

  /// Record a failed attempt from a path that does not go through [login]
  /// (e.g. a biometric prompt the user failed). Trips the lockout at
  /// [AppConstants.maxLoginAttempts].
  Future<void> registerFailedAttempt() async {
    final attempts = await _repository.registerFailedAttempt();
    if (attempts >= AppConstants.maxLoginAttempts) {
      final until = DateTime.now().add(AppConstants.loginLockoutCooldown);
      await _repository.lockOut(until);
      state = AuthUnauthenticated(
        failedAttempts: attempts,
        lockedUntil: until,
        failure: _lockoutFailure(until),
      );
      return;
    }
    state = AuthUnauthenticated(
      failedAttempts: attempts,
      lockedUntil: await _repository.lockedUntil(),
    );
  }

  /// Called when the lockout countdown reaches zero, so the sign-in form
  /// re-enables without a restart.
  Future<void> clearLockoutIfExpired() async {
    final current = state;
    if (current is! AuthUnauthenticated) return;
    final until = current.lockedUntil;
    if (until == null || until.isAfter(DateTime.now())) return;
    await _repository.clearFailedAttempts();
    state = const AuthUnauthenticated();
  }

  /// Clear the form error as soon as the user edits a field.
  void clearError() {
    final current = state;
    if (current is AuthUnauthenticated && current.failure != null) {
      state = current.copyWith(clearFailure: true);
    }
  }

  /// Sign out and clear **all** session state (CM-53).
  ///
  /// The state flips to [AuthUnauthenticated] unconditionally, even if the
  /// repository reported a problem — a sign-out that leaves the user looking at
  /// a signed-in screen is the worse failure.
  Future<void> logout() async {
    final failure = await _logout();
    if (failure != null) {
      AppLogger.warning(
        'Logout reported ${failure.code}; session cleared regardless',
        name: 'auth',
      );
    }
    state = const AuthUnauthenticated();
  }

  /// Replace the cached user after a profile edit (CM-47).
  void updateUser(User user) {
    final current = state;
    if (current is AuthAuthenticated) {
      state = current.copyWith(user: user);
    }
  }

  Failure _lockoutFailure(DateTime until) {
    final seconds = until.difference(DateTime.now()).inSeconds.clamp(0, 3600);
    return UnauthorizedFailure(
      userMessage:
          'Too many failed attempts. Try again in $seconds seconds.',
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

/// True while a sign-in lockout is in force (CM-05) — what the `/lockout`
/// route and the disabled sign-in button read.
final isLockedOutProvider = Provider<bool>(
  (ref) => ref.watch(authProvider.select((s) => s.isLockedOut)),
);
