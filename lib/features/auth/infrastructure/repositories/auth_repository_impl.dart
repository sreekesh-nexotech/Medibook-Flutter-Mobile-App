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
/// The JSON→entity mapping lives in [AuthMappers] at the bottom; it is the
/// only place the wire field names are spelled.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({required AuthApi api, required AuthLocalDataSource local})
    : _api = api,
      _local = local;

  final AuthApi _api;
  final AuthLocalDataSource _local;

  /// The one refresh in flight, shared by every caller — see [refreshSession].
  Future<AuthSession>? _refreshInFlight;

  @override
  Future<User?> currentUser() => _local.readUser();

  @override
  Future<bool> hasValidSession() async {
    final session = await _local.readSession();
    // The access token may have expired; the refresh token keeps the session
    // alive for up to 30 days, so "a session exists" is what matters here.
    return session != null && session.accessToken.isNotEmpty;
  }

  @override
  Future<String?> accessToken() => _local.readAccessToken();

  // ---- Sign-in ----

  @override
  Future<AuthResult> loginWithPassword({
    required String identifier,
    required String password,
  }) => _authenticate(
    () => _api.loginWithPassword(identifier: identifier, password: password),
    method: AuthMethod.password,
  );

  @override
  Future<OtpChallenge> startOtpLogin({required String phoneE164}) =>
      _challenge(() => _api.startOtpLogin(phoneE164: phoneE164));

  @override
  Future<AuthResult> verifyOtpLogin({
    required String challengeId,
    required String code,
  }) => _authenticate(
    () => _api.verifyOtpLogin(challengeId: challengeId, code: code),
    method: AuthMethod.otp,
  );

  @override
  Future<OtpChallenge> resendOtp({required String challengeId}) =>
      _challenge(() => _api.resendOtp(challengeId: challengeId));

  // ---- Sign-up ----

  @override
  Future<OtpChallenge> startSignup(SignupRequest request) =>
      _challenge(() => _api.startSignup(request));

  @override
  Future<AuthResult> verifySignup({
    required String challengeId,
    required String code,
  }) async {
    final result = await _authenticate(
      () => _api.verifySignup(challengeId: challengeId, code: code),
      method: AuthMethod.otp,
    );
    Analytics.track(AnalyticsEvent.signUpCompleted);
    return result;
  }

  // ---- Password reset ----

  @override
  Future<OtpChallenge> startPasswordReset({required String identifier}) =>
      _challenge(() => _api.startPasswordReset(identifier: identifier));

  @override
  Future<PasswordResetGrant> verifyPasswordReset({
    required String challengeId,
    required String code,
  }) async {
    final payload = await _run(
      () => _api.verifyPasswordReset(challengeId: challengeId, code: code),
    );
    final token = payload['reset_token'];
    if (token is! String || token.isEmpty) {
      throw const ServerFailure(
        debugMessage: 'forgot/verify has no reset_token',
      );
    }
    return PasswordResetGrant(
      resetToken: token,
      expiresAt: AuthMappers.dateTime(payload['expires_at']),
    );
  }

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) => _run(
    () => _api.resetPassword(resetToken: resetToken, newPassword: newPassword),
  );

  // ---- Session lifecycle ----

  @override
  Future<AuthSession> refreshSession() {
    // Single-flight (§1.4). The API client and the WebSocket owners all end
    // up here; a second call made while one is in flight would present the
    // same refresh token again, which the server answers by revoking the
    // whole session. Callers that overlap share one server call instead.
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final attempt = _refresh();
    _refreshInFlight = attempt;
    return attempt.whenComplete(() {
      if (identical(_refreshInFlight, attempt)) _refreshInFlight = null;
    });
  }

  Future<AuthSession> _refresh() async {
    final existing = await _local.readSession();
    final refreshToken = existing?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const UnauthorizedFailure(
        apiCode: ApiErrorCodes.authSessionRevoked,
        debugMessage: 'refreshSession called with no stored refresh token',
      );
    }
    final payload = await _run(() => _api.refresh(refreshToken: refreshToken));
    final session = AuthMappers.session(payload);
    // Rotation: the old refresh token is dead the moment this returns (§1.4).
    await _local.writeSession(session);
    return session;
  }

  @override
  Future<void> logout() => _endSession(_api.logout);

  @override
  Future<void> logoutAll() => _endSession(_api.logoutAll);

  @override
  Future<void> clearLocalSession() => _clearLocal();

  Future<void> _endSession(Future<void> Function() serverCall) async {
    // Best-effort server call — a dead network must not strand a signed-in
    // session on the device.
    try {
      await serverCall();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Server logout failed; clearing local session anyway',
        name: 'auth',
        error: error,
      );
      CrashReporting.recordError(error, stackTrace, reason: 'logout:server');
    }
    await _clearLocal();
  }

  Future<void> _clearLocal() async {
    // The part that must always happen (CM-53).
    await _local.clear();
    Analytics.track(AnalyticsEvent.loggedOut);
    Analytics.reset();
    CrashReporting.reset();
  }

  // ---- Account ----

  @override
  Future<User> fetchMe() async {
    final payload = await _run(_api.me);
    final cached = await _local.readUser();
    final user = AuthMappers.account(
      payload,
      method: cached?.authMethod ?? AuthMethod.password,
    );
    await _local.writeUser(user);
    return user;
  }

  @override
  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  }) => _run(
    () => _api.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    ),
  );

  // ---- Lockout mirror ----

  @override
  Future<DateTime?> lockedUntil({String? identifier}) async {
    final until = await _local.readLockedUntil();
    if (until == null || identifier == null) return until;
    final owner = await _local.readLockedIdentifier();
    return owner == null || owner == identifier ? until : null;
  }

  @override
  Future<String?> lockedIdentifier() => _local.readLockedIdentifier();

  @override
  Future<void> rememberLockout(DateTime until, {String? identifier}) async {
    await _local.writeLockedUntil(until, identifier: identifier);
    Analytics.track(AnalyticsEvent.loginLockedOut, {
      'until': until.toIso8601String(),
    });
  }

  @override
  Future<void> clearLockout() => _local.clearLockout();

  // ---- Internals ----

  /// Runs [request], maps any error to a [Failure], and rethrows it.
  Future<T> _run<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (error, stackTrace) {
      final failure = NetworkExceptions.toFailure(error, stackTrace);
      // Credential rejections are expected traffic, not incidents.
      if (failure is! UnauthorizedFailure || failure.sessionExpired) {
        CrashReporting.recordFailure(failure, context: {'layer': 'auth'});
      }
      throw failure;
    }
  }

  Future<OtpChallenge> _challenge(
    Future<Map<String, Object?>> Function() request,
  ) async => AuthMappers.challenge(await _run(request));

  /// Sign-in / sign-up: call, map, persist, identify.
  Future<AuthResult> _authenticate(
    Future<Map<String, Object?>> Function() request, {
    required AuthMethod method,
  }) async {
    final payload = await _run(request);
    final user = AuthMappers.user(
      AuthMappers.requireMap(payload['user'], 'user'),
      method: method,
      profile: payload['profile'],
    );
    final session = AuthMappers.session(payload);
    final self = payload['person_self'];
    final selfPersonId = self is Map ? self['id']?.toString() : null;

    await _local.writeSession(session);
    await _local.writeUser(user);
    await _local.clearLockout();

    Analytics.identify(user.id);
    CrashReporting.identify(user.id);
    Analytics.track(AnalyticsEvent.loginSucceeded, {'method': method.name});

    return AuthResult(user: user, session: session, selfPersonId: selfPersonId);
  }
}

/// Wire → entity mapping for the auth payloads (§4, §5.1). Public so the
/// profile feature can reuse the `/me` shape.
abstract final class AuthMappers {
  AuthMappers._();

  /// `GET /patient/me` → [User] (user + profile merged).
  static User account(
    Map<String, Object?> payload, {
    AuthMethod method = AuthMethod.password,
  }) => user(
    requireMap(payload['user'], 'user'),
    method: method,
    profile: payload['profile'],
  );

  /// A `User` object, optionally merged with a `profile` object.
  ///
  /// Throws a [ServerFailure] rather than returning a half-built entity when
  /// the response is missing an id — a `User` with no id would corrupt every
  /// cache key that hashes the account (HIVE spec, Scenario 10).
  static User user(
    Map<String, Object?> map, {
    required AuthMethod method,
    Object? profile,
  }) {
    final id = map['id'];
    if (id is! String || id.isEmpty) {
      throw const ServerFailure(debugMessage: 'auth payload has no user.id');
    }
    final p = profile is Map ? profile.cast<String, Object?>() : null;
    final allergies = p?['allergies'];
    return User(
      id: id,
      firstName: map['first_name']?.toString() ?? '',
      lastName: map['last_name'] as String?,
      email: map['email'] as String?,
      phoneE164: map['phone_e164'] as String?,
      alternatePhoneE164: map['alternate_phone_e164'] as String?,
      hasPassword: map['has_password'] == true,
      status: UserStatus.fromWire(map['status'] as String?),
      locale: map['locale'] as String? ?? 'en-IN',
      timezone: map['timezone'] as String? ?? 'Asia/Kolkata',
      version: (map['version'] as num?)?.toInt() ?? 1,
      emailVerified: map['email_verified_at'] != null,
      phoneVerified: map['phone_verified_at'] != null,
      lastLoginAt: dateTime(map['last_login_at']),
      deletionRequestedAt: dateTime(map['deletion_requested_at']),
      authMethod: method,
      dateOfBirth: dateTime(p?['date_of_birth']),
      gender: p?['gender'] as String?,
      bloodGroup: p?['blood_group'] as String?,
      allergies: allergies is List
          ? [for (final a in allergies) a.toString()]
          : const <String>[],
      marketingOptIn: p?['marketing_opt_in'] == true,
      avatarFileId: p?['avatar_file_id'] as String?,
      profileVersion: (p?['version'] as num?)?.toInt(),
    );
  }

  /// The `Tokens` fields (§4).
  static AuthSession session(Map<String, Object?> payload) {
    final access = payload['access'];
    if (access is! String || access.isEmpty) {
      throw const ServerFailure(debugMessage: 'auth payload has no access');
    }
    final expiresIn = payload['access_expires_in'];
    return AuthSession(
      accessToken: access,
      refreshToken: payload['refresh'] as String?,
      expiresAt: expiresIn is num
          ? DateTime.now().add(Duration(seconds: expiresIn.toInt()))
          : null,
      sessionId: payload['session_id'] as String?,
    );
  }

  /// The `Challenge` shape (§4).
  static OtpChallenge challenge(Map<String, Object?> payload) {
    final id = payload['challenge_id'];
    if (id is! String || id.isEmpty) {
      throw const ServerFailure(debugMessage: 'challenge has no challenge_id');
    }
    return OtpChallenge(
      challengeId: id,
      codeLength: (payload['code_length'] as num?)?.toInt() ?? 4,
      expiresAt: dateTime(payload['expires_at']),
      resendAfterSeconds:
          (payload['resend_after_seconds'] as num?)?.toInt() ?? 30,
      destinationMasked: payload['destination_masked'] as String?,
    );
  }

  static Map<String, Object?> requireMap(Object? value, String name) {
    if (value is Map) return value.cast<String, Object?>();
    throw ServerFailure(debugMessage: 'auth payload has no $name object');
  }

  /// ISO-8601 (UTC, with or without fractional seconds) or `YYYY-MM-DD`.
  static DateTime? dateTime(Object? value) =>
      value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;
}
