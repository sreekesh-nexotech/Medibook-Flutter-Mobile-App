import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/di/dependencies.dart';
import 'package:medibook/app/di/auth_dependencies.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/auth/application/providers/auth_provider.dart';
import 'package:medibook/features/auth/application/states/auth_state.dart';
import 'package:medibook/features/auth/domain/entities/user.dart';
import 'package:medibook/features/auth/infrastructure/data_sources/remote/auth_api.dart';

/// `AuthController` against a scripted [AuthApi], through the real repository
/// and local data source. Pins the contracts the router's guard depends on:
/// a successful sign-in leaves the session authenticated and persisted, a
/// rejected one carries the server's `attempts_remaining`, a server lockout
/// is remembered and refuses further attempts, and logout clears everything.
void main() {
  late ProviderContainer container;
  late _ScriptedAuthApi api;

  setUp(() {
    HiveInit.store = InMemoryLocalStore();
    api = _ScriptedAuthApi();
    container = ProviderContainer(
      overrides: [...appDependencies(), authApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
  });

  AuthController notifier() => container.read(authProvider.notifier);

  test('restore on a fresh device is unauthenticated', () async {
    await notifier().restore();
    expect(container.read(authProvider), isA<AuthUnauthenticated>());
  });

  test('password sign-in authenticates and persists the session', () async {
    await notifier().restore();
    final failure = await notifier().loginWithPassword(
      identifier: 'anita@example.com',
      password: 'seed_password_123',
    );

    expect(failure, isNull);
    expect(container.read(isAuthenticatedProvider), isTrue);
    expect(container.read(currentUserProvider)?.firstName, 'Anita');
    expect(
      await container.read(authRepositoryProvider).hasValidSession(),
      isTrue,
    );
    expect(await container.read(authRepositoryProvider).accessToken(), 'acc-1');
  });

  test('a phone identifier is accepted as well as an email', () async {
    await notifier().restore();
    final failure = await notifier().loginWithPassword(
      identifier: '+919845658525',
      password: 'seed_password_123',
    );
    expect(failure, isNull);
  });

  test('a malformed identifier is a form error, not a request', () async {
    await notifier().restore();
    final failure = await notifier().loginWithPassword(
      identifier: 'not-an-identifier',
      password: 'x',
    );
    expect(failure, isA<ValidationFailure>());
    expect(api.loginCalls, 0);
  });

  test('a wrong password carries attempts_remaining from the server', () async {
    await notifier().restore();
    api.nextLoginError = const UnauthorizedFailure(
      userMessage: 'Invalid credentials.',
      sessionExpired: false,
      apiCode: ApiErrorCodes.authInvalidCredentials,
      meta: {'attempts_remaining': 3},
    );

    final failure = await notifier().loginWithPassword(
      identifier: 'anita@example.com',
      password: 'wrong',
    );

    expect(failure, isA<UnauthorizedFailure>());
    expect(container.read(isAuthenticatedProvider), isFalse);
    expect(container.read(authProvider).attemptsRemaining, 3);
    expect(container.read(authProvider).failedAttempts, 2);
  });

  test('AUTH_LOCKED_OUT is remembered and blocks the next attempt', () async {
    await notifier().restore();
    final until = DateTime.now().add(const Duration(hours: 1));
    api.nextLoginError = UnauthorizedFailure(
      userMessage: 'Locked.',
      sessionExpired: false,
      apiCode: ApiErrorCodes.authLockedOut,
      meta: {'locked_until': until.toUtc().toIso8601String()},
    );

    await notifier().loginWithPassword(
      identifier: 'anita@example.com',
      password: 'wrong',
    );
    expect(container.read(isLockedOutProvider), isTrue);
    expect(api.loginCalls, 1);

    // The device refuses to spend the cooldown on the network.
    await notifier().loginWithPassword(
      identifier: 'anita@example.com',
      password: 'wrong',
    );
    expect(api.loginCalls, 1);
  });

  test('OTP sign-in uses the challenge id from start', () async {
    await notifier().restore();
    final challenge = await notifier().startOtpLogin(
      phoneE164: '+919845658525',
    );
    expect(challenge?.challengeId, 'ch-1');
    expect(challenge?.codeLength, 4);

    final failure = await notifier().verifyOtpLogin(
      challengeId: challenge!.challengeId,
      code: '1234',
    );
    expect(failure, isNull);
    expect(container.read(isAuthenticatedProvider), isTrue);
    expect(api.lastVerifiedChallenge, 'ch-1');
  });

  test('sign-up verify records the self person id', () async {
    await notifier().restore();
    final challenge = await notifier().startSignup(
      SignupRequest(
        firstName: 'Anita',
        phoneE164: '+919845658525',
        dateOfBirth: DateTime(1994, 5, 17),
        acceptedTerms: true,
        acceptedPrivacy: true,
        acceptedGuidelines: true,
      ),
    );
    final failure = await notifier().verifySignup(
      challengeId: challenge!.challengeId,
      code: '1234',
    );
    expect(failure, isNull);
    expect(container.read(selfPersonIdProvider), 'person-self');
  });

  test('a session-ending code signs the user out locally', () async {
    await notifier().restore();
    await notifier().loginWithPassword(
      identifier: 'anita@example.com',
      password: 'seed_password_123',
    );
    await notifier().onSessionLost(
      const UnauthorizedFailure(apiCode: ApiErrorCodes.authSessionRevoked),
    );
    expect(container.read(isAuthenticatedProvider), isFalse);
    expect(
      await container.read(authRepositoryProvider).hasValidSession(),
      isFalse,
    );
    expect(
      container.read(authProvider).failure?.apiCode,
      ApiErrorCodes.authSessionRevoked,
    );
  });

  test('logout clears the session even when the server call fails', () async {
    await notifier().restore();
    await notifier().loginWithPassword(
      identifier: 'anita@example.com',
      password: 'seed_password_123',
    );
    api.failLogout = true;
    await notifier().logout();
    expect(container.read(isAuthenticatedProvider), isFalse);
    expect(
      await container.read(authRepositoryProvider).hasValidSession(),
      isFalse,
    );
  });
}

/// An [AuthApi] that answers with the backend's payload shapes (§4).
class _ScriptedAuthApi implements AuthApi {
  int loginCalls = 0;
  Failure? nextLoginError;
  bool failLogout = false;
  String? lastVerifiedChallenge;
  int _tokenSeq = 0;

  Map<String, Object?> _tokens({bool user = true}) {
    _tokenSeq++;
    return {
      'access': 'acc-$_tokenSeq',
      'refresh': 'ref-$_tokenSeq',
      'access_expires_in': 900,
      'session_id': 'sess-1',
      if (user) 'user': _user(),
    };
  }

  Map<String, Object?> _user() => {
    'id': 'u-1',
    'first_name': 'Anita',
    'last_name': 'Menon',
    'phone_e164': '+919845658525',
    'phone_verified_at': null,
    'alternate_phone_e164': null,
    'email': 'anita@example.com',
    'email_verified_at': '2026-08-06T04:30:00Z',
    'has_password': true,
    'status': 'active',
    'deletion_requested_at': null,
    'locale': 'en-IN',
    'timezone': 'Asia/Kolkata',
    'last_login_at': null,
    'version': 1,
  };

  Map<String, Object?> _challenge() => {
    'challenge_id': 'ch-1',
    'code_length': 4,
    'expires_at': '2026-09-30T10:03:00+00:00',
    'resend_after_seconds': 30,
    'destination_masked': '+91******25',
  };

  @override
  Future<Map<String, Object?>> loginWithPassword({
    required String identifier,
    required String password,
    String? deviceId,
  }) async {
    loginCalls++;
    final error = nextLoginError;
    if (error != null) {
      nextLoginError = null;
      throw error;
    }
    return _tokens();
  }

  @override
  Future<Map<String, Object?>> startOtpLogin({
    required String phoneE164,
  }) async => _challenge();

  @override
  Future<Map<String, Object?>> verifyOtpLogin({
    required String challengeId,
    required String code,
    String? deviceId,
  }) async {
    lastVerifiedChallenge = challengeId;
    return _tokens();
  }

  @override
  Future<Map<String, Object?>> resendOtp({required String challengeId}) async =>
      _challenge();

  @override
  Future<Map<String, Object?>> startSignup(SignupRequest request) async =>
      _challenge();

  @override
  Future<Map<String, Object?>> verifySignup({
    required String challengeId,
    required String code,
  }) async => {
    ..._tokens(),
    'profile': {'date_of_birth': '1994-05-17', 'version': 1},
    'person_self': {'id': 'person-self', 'is_self': true},
  };

  @override
  Future<Map<String, Object?>> startPasswordReset({
    required String identifier,
  }) async => _challenge();

  @override
  Future<Map<String, Object?>> verifyPasswordReset({
    required String challengeId,
    required String code,
  }) async => {'reset_token': 'rt-1', 'expires_at': '2026-09-30T10:18:00Z'};

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {}

  @override
  Future<Map<String, Object?>> refresh({required String refreshToken}) async =>
      _tokens(user: false);

  @override
  Future<void> logout() async {
    if (failLogout) throw const NetworkFailure();
  }

  @override
  Future<void> logoutAll() async {}

  @override
  Future<Map<String, Object?>> me() async => {'user': _user(), 'profile': null};

  @override
  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {}
}
