import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/features/auth/application/providers/auth_provider.dart';
import 'package:medibook/features/auth/domain/entities/user.dart';
import 'package:medibook/features/auth/domain/repositories/auth_repository.dart';

/// The server locks one **account** after five wrong passwords, not the
/// phone (BL-AUTH-035); and a wrong sign-in **code** is not a wrong password
/// (BL-AUTH-036).
void main() {
  late _LockingRepository repository;
  late ProviderContainer container;

  setUp(() async {
    repository = _LockingRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.notifier).restore();
  });

  AuthController auth() => container.read(authProvider.notifier);

  test('a locked account does not stop another account on the phone', () async {
    repository.lockNext = true;
    await auth().loginWithPassword(
      identifier: 'anita@example.com',
      password: 'wrong-password',
    );
    final state = container.read(authProvider);
    expect(state.scopedTo('anita@example.com').isLockedOut, isTrue);
    expect(state.scopedTo('ANITA@example.com ').isLockedOut, isTrue);

    // Someone else on the same phone.
    expect(state.scopedTo('ravi@example.com').isLockedOut, isFalse);
    final challenge = await auth().startPasswordReset(
      identifier: '+919876543210',
    );
    expect(challenge, isNotNull, reason: 'reset for another account is sent');
    expect(repository.resetsStarted, 1);

    // The locked account itself is still refused, without a request.
    final refused = await auth().startPasswordReset(
      identifier: 'anita@example.com',
    );
    expect(refused, isNull);
    expect(repository.resetsStarted, 1);
  });

  test('the lockout is remembered with its account', () async {
    repository.lockNext = true;
    await auth().loginWithPassword(
      identifier: 'anita@example.com',
      password: 'wrong-password',
    );
    expect(repository.lockedFor, 'anita@example.com');
    expect(
      await repository.lockedUntil(identifier: 'ravi@example.com'),
      isNull,
    );
  });

  test('a wrong code does not show as password attempts', () async {
    await auth().verifyOtpLogin(
      challengeId: 'ch-1',
      code: '0000',
      phoneE164: '+919876543210',
    );
    final state = container.read(authProvider);
    expect(state.failure, isNotNull);
    expect(state.serverAttemptsRemaining, isNull);
    expect(state.failedAttempts, 0, reason: 'no "attempts left" warning');
  });

  test('a wrong password does count', () async {
    await auth().loginWithPassword(
      identifier: 'anita@example.com',
      password: 'wrong-password',
    );
    final state = container.read(authProvider).scopedTo('anita@example.com');
    expect(state.serverAttemptsRemaining, 2);
  });
}

class _LockingRepository implements AuthRepository {
  bool lockNext = false;
  DateTime? _until;
  String? lockedFor;
  int resetsStarted = 0;

  @override
  Future<bool> hasValidSession() async => false;

  @override
  Future<User?> currentUser() async => null;

  @override
  Future<AuthResult> loginWithPassword({
    required String identifier,
    required String password,
    String? deviceId,
  }) async {
    if (lockNext) {
      throw UnauthorizedFailure(
        userMessage: 'Locked',
        sessionExpired: false,
        apiCode: 'AUTH_LOCKED_OUT',
        meta: {
          'attempts_remaining': 0,
          'locked_until': DateTime.now()
              .add(const Duration(hours: 1))
              .toIso8601String(),
        },
      );
    }
    throw const UnauthorizedFailure(
      userMessage: 'Wrong password',
      sessionExpired: false,
      apiCode: 'AUTH_INVALID_CREDENTIALS',
      meta: {'attempts_remaining': 2},
    );
  }

  @override
  Future<AuthResult> verifyOtpLogin({
    required String challengeId,
    required String code,
    String? deviceId,
  }) async => throw const UnauthorizedFailure(
    userMessage: 'Wrong code',
    sessionExpired: false,
    apiCode: 'AUTH_OTP_INVALID',
    meta: {'attempts_remaining': 2},
  );

  @override
  Future<OtpChallenge> startPasswordReset({required String identifier}) async {
    resetsStarted++;
    return OtpChallenge(
      challengeId: 'ch-reset',
      codeLength: 4,
      expiresAt: DateTime.now().add(const Duration(minutes: 3)),
      resendAfterSeconds: 30,
    );
  }

  @override
  Future<DateTime?> lockedUntil({String? identifier}) async {
    if (_until == null || identifier == null) return _until;
    return lockedFor == null || lockedFor == identifier ? _until : null;
  }

  @override
  Future<String?> lockedIdentifier() async => lockedFor;

  @override
  Future<void> rememberLockout(DateTime until, {String? identifier}) async {
    _until = until;
    lockedFor = identifier;
  }

  @override
  Future<void> clearLockout() async {
    _until = null;
    lockedFor = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
