import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/di/dependencies.dart';
import 'package:medibook/app/di/auth_dependencies.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/core/network/realtime/ws_session.dart';
import 'package:medibook/features/appointments/application/providers/appointments_provider.dart';
import 'package:medibook/features/auth/application/providers/auth_provider.dart';
import 'package:medibook/features/auth/domain/entities/user.dart';
import 'package:medibook/features/auth/infrastructure/data_sources/remote/auth_api.dart';
import 'package:medibook/features/notifications/application/providers/notifications_provider.dart';
import 'package:mocktail/mocktail.dart';

/// DEF-044: after the access token expired, the API client and the inbox
/// socket each refreshed the session at the same moment. Refresh tokens
/// rotate (§1.4), so the server revoked the session and the user was signed
/// out. Every refresh now goes through one in-flight call.
void main() {
  late ProviderContainer container;
  late _MockAuthApi api;
  late int generation;

  Map<String, Object?> tokens(int n) => {
    'access': 'access-$n',
    'refresh': 'refresh-$n',
    'access_expires_in': 900,
    'session_id': 'sess',
  };

  setUp(() async {
    HiveInit.store = InMemoryLocalStore();
    api = _MockAuthApi();
    generation = 1;
    container = ProviderContainer(
      overrides: [...appDependencies(), authApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    await container
        .read(authLocalDataSourceProvider)
        .writeSession(
          const AuthSession(
            accessToken: 'access-1',
            refreshToken: 'refresh-1',
            sessionId: 'sess',
          ),
        );
    // A slow server call, so callers genuinely overlap.
    when(
      () => api.refresh(refreshToken: any(named: 'refreshToken')),
    ).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return tokens(++generation);
    });
  });

  List<String> presentedRefreshTokens() => verify(
    () => api.refresh(refreshToken: captureAny(named: 'refreshToken')),
  ).captured.cast<String>();

  test('overlapping refreshes share one server call', () async {
    final repository = container.read(authRepositoryProvider);

    final sessions = await Future.wait([
      repository.refreshSession(),
      repository.refreshSession(),
      repository.refreshSession(),
    ]);

    expect(presentedRefreshTokens(), ['refresh-1']);
    expect(sessions.map((s) => s.accessToken).toSet(), {'access-2'});
    expect(await repository.accessToken(), 'access-2');
  });

  test('a later refresh is a new call with the rotated token', () async {
    final repository = container.read(authRepositoryProvider);

    await repository.refreshSession();
    await repository.refreshSession();

    expect(presentedRefreshTokens(), ['refresh-1', 'refresh-2']);
    expect(await repository.accessToken(), 'access-3');
  });

  test('a failed refresh reaches every waiting caller, then clears', () async {
    final repository = container.read(authRepositoryProvider);
    when(
      () => api.refresh(refreshToken: any(named: 'refreshToken')),
    ).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      throw StateError('network down');
    });

    final results = await Future.wait([
      repository.refreshSession().then<Object>((s) => s, onError: (e) => e),
      repository.refreshSession().then<Object>((s) => s, onError: (e) => e),
    ]);
    expect(results.whereType<AuthSession>(), isEmpty);
    verify(
      () => api.refresh(refreshToken: any(named: 'refreshToken')),
    ).called(1);

    // The failure is not remembered: the next attempt calls the server again.
    when(
      () => api.refresh(refreshToken: any(named: 'refreshToken')),
    ).thenAnswer((_) async => tokens(2));
    expect((await repository.refreshSession()).accessToken, 'access-2');
  });

  group('the API client and a refused socket at the same moment', () {
    for (final entry in <String, Provider<WsSession>>{
      'inbox': inboxWsSessionProvider,
      'live queue': liveQueueWsSessionProvider,
    }.entries) {
      test('${entry.key}: one refresh call, not two', () async {
        final socket = container.read(entry.value);
        final hooks = container.read(apiSessionHooksProvider);
        // The socket presents the expired token and is refused …
        expect(await socket.accessToken(), 'access-1');

        // … while the API client's requests come back 401.
        final results = await Future.wait<Object?>([
          hooks.refresh(),
          socket.refreshIfStale(),
        ]);

        expect(presentedRefreshTokens(), ['refresh-1']);
        expect(results.first, 'access-2');
        expect(await socket.accessToken(), 'access-2');
      });

      test(
        '${entry.key}: refused after the client already refreshed — no call',
        () async {
          final socket = container.read(entry.value);
          expect(await socket.accessToken(), 'access-1');

          await container.read(apiSessionHooksProvider).refresh();
          await socket.refreshIfStale();

          expect(presentedRefreshTokens(), ['refresh-1']);
        },
      );
    }
  });

  group('WsSession', () {
    test(
      'refreshes when the token it presented is still the current one',
      () async {
        var refreshes = 0;
        final session = WsSession(
          accessToken: () async => 'a1',
          refresh: () async => refreshes++,
        );
        await session.accessToken();
        await session.refreshIfStale();
        expect(refreshes, 1);
      },
    );

    test('refreshes when it has not presented a token yet', () async {
      var refreshes = 0;
      final session = WsSession(
        accessToken: () async => 'a1',
        refresh: () async => refreshes++,
      );
      await session.refreshIfStale();
      expect(refreshes, 1);
    });
  });
}

class _MockAuthApi extends Mock implements AuthApi {}
