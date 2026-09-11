import '../../../../app/monitoring/analytics.dart';
import '../../../../app/monitoring/crash_reporting.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../data_sources/local/auth_local_ds.dart';
import '../data_sources/remote/auth_api.dart';

/// [AuthRepository] over [AuthApi] + [AuthLocalDataSource].
///
/// This is where the layers are joined and where the two cross-cutting
/// promises in the standards are actually kept:
///
/// * **Every throw is a `Failure`.** Transport errors come out of the API as
///   `NetworkException`s and are converted here by
///   `NetworkExceptions.toFailure`, so nothing above this class ever sees a
///   package-specific exception (Coding Standards §5).
/// * **Logout clears everything** (CM-53). [logout] clears secure storage, the
///   session/cache boxes and the analytics/crash identity, and it does so even
///   when the server call fails — the server forgetting the token is a nicety;
///   the device forgetting it is the requirement.
///
/// The JSON→entity mapping lives in the private helpers at the bottom. When
/// codegen (`freezed`/`json_serializable`) is introduced, those are the only
/// methods that change.
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required AuthApi api,
    required AuthLocalDataSource local,
  }) : _api = api,
       _local = local;

  final AuthApi _api;
  final AuthLocalDataSource _local;

  @override
  Future<User?> currentUser() => _local.readUser();

  @override
  Future<bool> hasValidSession() async {
    final session = await _local.readSession();
    return session?.isValid ?? false;
  }

  @override
  Future<AuthResult> login({required String email, required String password}) =>
      _authenticate(
        () => _api.login(email: email, password: password),
        method: AuthMethod.password,
      );

  @override
  Future<AuthResult> loginWithOtp({
    required String phone,
    required String code,
  }) => _authenticate(
    () => _api.loginWithOtp(phone: phone, code: code),
    method: AuthMethod.otp,
  );

  @override
  Future<void> requestOtp({required String phone}) =>
      _run(() => _api.requestOtp(phone: phone));

  @override
  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) => _authenticate(
    () =>
        _api.signUp(name: name, email: email, phone: phone, password: password),
    method: AuthMethod.password,
  );

  @override
  Future<AuthSession> refreshSession() async {
    final existing = await _local.readSession();
    final refreshToken = existing?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const UnauthorizedFailure(
        debugMessage: 'refreshSession called with no stored refresh token',
      );
    }
    final payload = await _run(() => _api.refresh(refreshToken: refreshToken));
    final session = _sessionFrom(payload);
    await _local.writeSession(session);
    return session;
  }

  @override
  Future<void> logout() async {
    // Best-effort server call — a dead network must not strand a signed-in
    // session on the device.
    try {
      await _api.logout();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Server logout failed; clearing local session anyway',
        name: 'auth',
        error: error,
      );
      CrashReporting.recordError(error, stackTrace, reason: 'logout:server');
    }

    // The part that must always happen (CM-53).
    await _local.clear();
    Analytics.track(AnalyticsEvent.loggedOut);
    Analytics.reset();
    CrashReporting.reset();
  }

  @override
  Future<void> requestPasswordReset({required String email}) =>
      _run(() => _api.requestPasswordReset(email: email));

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _run(
    () =>
        _api.resetPassword(email: email, code: code, newPassword: newPassword),
  );

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _run(
    () => _api.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    ),
  );

  // ---- Lockout bookkeeping (CM-05), persisted by the local data source ----

  @override
  Future<int> registerFailedAttempt() => _local.incrementFailedAttempts();

  @override
  Future<int> failedAttempts() => _local.readFailedAttempts();

  @override
  Future<DateTime?> lockedUntil() => _local.readLockedUntil();

  @override
  Future<void> lockOut(DateTime until) async {
    await _local.writeLockedUntil(until);
    Analytics.track(AnalyticsEvent.loginLockedOut, {
      'until': until.toIso8601String(),
    });
  }

  @override
  Future<void> clearFailedAttempts() => _local.clearFailedAttempts();

  // ---- Internals ----

  /// Runs [request], maps any error to a [Failure], and rethrows it.
  Future<T> _run<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (error, stackTrace) {
      final failure = NetworkExceptions.toFailure(error, stackTrace);
      CrashReporting.recordFailure(failure, context: {'layer': 'auth'});
      throw failure;
    }
  }

  /// Sign-in / sign-up: call, map, persist, identify.
  Future<AuthResult> _authenticate(
    Future<Map<String, Object?>> Function() request, {
    required AuthMethod method,
  }) async {
    final payload = await _run(request);
    final user = _userFrom(payload, method: method);
    final session = _sessionFrom(payload);

    await _local.writeSession(session);
    await _local.writeUser(user);
    await _local.clearFailedAttempts();

    Analytics.identify(user.id);
    CrashReporting.identify(user.id);
    Analytics.track(AnalyticsEvent.loginSucceeded, {'method': method.name});

    return (user: user, session: session);
  }

  /// Maps the `user` object out of an auth payload.
  ///
  /// Throws a [ServerFailure] rather than returning a half-built entity when
  /// the response is missing an id — a `User` with no id would corrupt every
  /// cache key that hashes the account (HIVE spec, Scenario 10).
  User _userFrom(Map<String, Object?> payload, {required AuthMethod method}) {
    final raw = payload['user'];
    final map = raw is Map<String, Object?> ? raw : payload;
    final id = map['id'];
    if (id is! String || id.isEmpty) {
      throw const ServerFailure(debugMessage: 'auth payload has no user.id');
    }
    final dob = map['date_of_birth'];
    return User(
      id: id,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      dateOfBirth: dob is String ? DateTime.tryParse(dob) : null,
      gender: map['gender'] as String?,
      bloodGroup: map['blood_group'] as String?,
      authMethod: method,
      emailVerified: map['email_verified'] == true,
      phoneVerified: map['phone_verified'] == true,
    );
  }

  /// Maps the token fields out of an auth payload.
  AuthSession _sessionFrom(Map<String, Object?> payload) {
    final accessToken = payload['access_token'];
    if (accessToken is! String || accessToken.isEmpty) {
      throw const ServerFailure(
        debugMessage: 'auth payload has no access_token',
      );
    }
    final expiresIn = payload['expires_in'];
    final expiresAtRaw = payload['expires_at'];
    return AuthSession(
      accessToken: accessToken,
      refreshToken: payload['refresh_token'] as String?,
      expiresAt: switch (expiresAtRaw) {
        final String iso => DateTime.tryParse(iso),
        _ =>
          expiresIn is int
              ? DateTime.now().add(Duration(seconds: expiresIn))
              : null,
      },
    );
  }
}
