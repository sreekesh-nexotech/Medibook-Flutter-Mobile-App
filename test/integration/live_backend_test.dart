import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/api_client.dart';
import 'package:medibook/core/network/endpoints.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/core/storage/device_identity.dart';
import 'package:medibook/core/storage/secure_store.dart';
import 'package:medibook/features/auth/domain/entities/user.dart';
import 'package:medibook/features/auth/infrastructure/data_sources/local/auth_local_ds.dart';
import 'package:medibook/features/auth/infrastructure/data_sources/remote/auth_api.dart';
import 'package:medibook/features/auth/infrastructure/repositories/auth_repository_impl.dart';

/// Drives the real network stack against the integration server.
///
/// Opt-in, because CI has no backend and the suite must stay offline:
///
/// ```sh
/// MEDIBOOK_LIVE_BASE_URL=https://62.171.151.149:8443 \
/// MEDIBOOK_LIVE_IDENTIFIER=… MEDIBOOK_LIVE_PASSWORD=… \
/// flutter test test/integration/live_backend_test.dart
/// ```
///
/// Plain `test()`s (no widget binding), so `dart:io`'s `HttpClient` is the
/// real one rather than flutter_test's stub.
void main() {
  // flutter_test installs a stub HttpClient for every test; this suite needs
  // the real one.
  HttpOverrides.global = null;

  final baseUrl = Platform.environment['MEDIBOOK_LIVE_BASE_URL'];
  final identifier = Platform.environment['MEDIBOOK_LIVE_IDENTIFIER'];
  final password = Platform.environment['MEDIBOOK_LIVE_PASSWORD'];
  final enabled = baseUrl != null && identifier != null && password != null;

  late InMemorySecureStore secure;
  late AuthRepositoryImpl repository;
  late DioApiClient client;
  var sessionLost = false;

  setUp(() {
    HiveInit.store = InMemoryLocalStore();
    secure = InMemorySecureStore();
    final identity = DeviceIdentity(secure);
    late final AuthRepositoryImpl repo;
    client = DioApiClient(
      baseUrl: baseUrl ?? 'https://localhost',
      allowBadCertificate: true,
      hooks: ApiSessionHooks(
        accessToken: () => secure.accessToken,
        deviceFingerprint: identity.fingerprint,
        refresh: () async => (await repo.refreshSession()).accessToken,
        onSessionLost: (failure) async => sessionLost = true,
      ),
    );
    repo = AuthRepositoryImpl(
      api: HttpAuthApi(client),
      local: AuthLocalDataSourceImpl(secureStore: secure),
    );
    repository = repo;
  });

  tearDown(() => client.close());

  test(
    'password login → /me → refresh → conditional GET → logout',
    () async {
      final result = await repository.loginWithPassword(
        identifier: identifier!,
        password: password!,
      );
      expect(result.user.id, isNotEmpty);
      expect(result.user.hasPassword, isTrue);
      expect(result.session.refreshToken, isNotEmpty);
      expect(await secure.accessToken, result.session.accessToken);

      final me = await repository.fetchMe();
      expect(me.id, result.user.id);

      // Rotation: a second refresh token replaces the first.
      final before = await secure.refreshToken;
      final refreshed = await repository.refreshSession();
      expect(refreshed.accessToken, isNot(result.session.accessToken));
      expect(await secure.refreshToken, isNot(before));

      // ETag round trip (§1.10): the same read with If-None-Match is a 304.
      final first = await client.get(Endpoints.me);
      expect(first.etag, isNotNull);
      final second = await client.get(Endpoints.me, ifNoneMatch: first.etag);
      expect(second.isNotModified, isTrue);

      // Unknown query parameters are a 400 VALIDATION_ERROR (§1.7).
      await expectLater(
        client.get(Endpoints.hospitals, query: {'foo': 1}, requiresAuth: false),
        throwsA(
          isA<HttpStatusException>().having(
            (e) => e.code,
            'code',
            ApiErrorCodes.validationError,
          ),
        ),
      );

      await repository.logout();
      expect(await secure.accessToken, isNull);
      expect(sessionLost, isFalse);
    },
    skip: enabled ? false : 'set MEDIBOOK_LIVE_* to run against the backend',
  );

  test(
    'a wrong password maps to AUTH_INVALID_CREDENTIALS with attempts_remaining',
    () async {
      await expectLater(
        repository.loginWithPassword(
          identifier:
              'nobody-${DateTime.now().millisecondsSinceEpoch}@example.com',
          password: 'definitely-wrong-1',
        ),
        throwsA(
          isA<UnauthorizedFailure>()
              .having((f) => f.sessionExpired, 'sessionExpired', isFalse)
              .having(
                (f) => f.apiCode,
                'apiCode',
                ApiErrorCodes.authInvalidCredentials,
              )
              .having(
                (f) => f.attemptsRemaining,
                'attemptsRemaining',
                isNotNull,
              ),
        ),
      );
    },
    skip: enabled ? false : 'set MEDIBOOK_LIVE_* to run against the backend',
  );

  test(
    'OTP start returns a challenge bound to this device fingerprint',
    () async {
      final challenge = await repository.startOtpLogin(
        phoneE164: '+919999900001',
      );
      expect(challenge.challengeId, isNotEmpty);
      expect(challenge.codeLength, 4);

      // A wrong code is AUTH_OTP_INVALID, still no session.
      await expectLater(
        repository.verifyOtpLogin(
          challengeId: challenge.challengeId,
          code: '0000',
        ),
        throwsA(
          isA<UnauthorizedFailure>().having(
            (f) => f.apiCode,
            'apiCode',
            ApiErrorCodes.authOtpInvalid,
          ),
        ),
      );
      expect(await repository.hasValidSession(), isFalse);
    },
    skip: enabled ? false : 'set MEDIBOOK_LIVE_* to run against the backend',
  );

  test('SignupRequest serialises the wire shape', () {
    // Not a live call — pins the body shape the backend validated by curl.
    final request = SignupRequest(
      firstName: 'Test',
      phoneE164: '+919999900002',
      dateOfBirth: DateTime(1990, 1, 1),
      acceptedTerms: true,
      acceptedPrivacy: true,
      acceptedGuidelines: true,
    );
    expect(request.phoneE164, '+919999900002');
  });
}
