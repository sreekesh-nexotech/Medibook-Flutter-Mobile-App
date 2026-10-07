import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/api_client.dart';
import 'package:medibook/core/network/network_exceptions.dart';

/// `DioApiClient` against a scripted adapter: headers, envelope parsing, the
/// 304 pass-through, and the §1.4 refresh rules (single-flight, retry once,
/// session-ending codes reported once).
void main() {
  late _ScriptedAdapter adapter;
  late List<String> events;
  late String token;
  late int refreshes;

  /// When set, the refresh hook throws it instead of minting a token.
  Object? refreshError;
  late DioApiClient client;

  setUp(() {
    adapter = _ScriptedAdapter();
    events = [];
    token = 'access-1';
    refreshes = 0;
    refreshError = null;
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://api.test/api/v1',
        validateStatus: (s) => s != null && s < 400,
      ),
    )..httpClientAdapter = adapter;
    client = DioApiClient(
      baseUrl: 'https://api.test',
      dio: dio,
      hooks: ApiSessionHooks(
        accessToken: () async => token,
        deviceFingerprint: () async => 'fp-1',
        refresh: () async {
          refreshes++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          final error = refreshError;
          if (error != null) throw error;
          token = 'access-${refreshes + 1}';
          return token;
        },
        onSessionLost: (failure) async => events.add('lost:${failure.apiCode}'),
      ),
    );
  });

  test(
    'sends bearer, request id, idempotency, If-Match and fingerprint',
    () async {
      adapter.enqueue(200, {'ok': true});
      await client.send(
        const ApiRequest(
          path: '/patient/appointments',
          method: HttpMethod.post,
          body: {'slot_id': 's'},
          idempotencyKey: 'idem-1',
          ifMatch: 3,
          withDeviceFingerprint: true,
        ),
      );
      final headers = adapter.requests.single.headers;
      expect(headers['authorization'], 'Bearer access-1');
      expect(headers['idempotency-key'], 'idem-1');
      expect(headers['if-match'], '"3"');
      expect(headers['x-device-fingerprint'], 'fp-1');
      expect(headers['x-request-id'], isNotEmpty);
      expect(adapter.requests.single.uri.path, '/api/v1/patient/appointments');
    },
  );

  test('null query values are dropped', () async {
    adapter.enqueue(200, {'results': []});
    await client.get('/patient/hospitals', query: {'city': null, 'page': 1});
    expect(adapter.requests.single.uri.query, 'page=1');
  });

  test('a 304 is returned, not thrown', () async {
    adapter.enqueue(304, null, headers: {'etag': '"v1"'});
    final response = await client.get('/patient/me', ifNoneMatch: '"v1"');
    expect(response.isNotModified, isTrue);
    expect(adapter.requests.single.headers['if-none-match'], '"v1"');
  });

  test('the error envelope is parsed onto HttpStatusException', () async {
    adapter.enqueue(400, {
      'code': 'VALIDATION_ERROR',
      'message': 'Some fields are invalid.',
      'errors': {
        'pincode': ['bad'],
        'address': {
          'city': ['This field is required.'],
        },
      },
      'request_id': 'rid-1',
      'meta': {},
    });
    await expectLater(
      client.post('/patient/me/addresses', body: {}),
      throwsA(
        isA<HttpStatusException>()
            .having((e) => e.code, 'code', ApiErrorCodes.validationError)
            .having(
              (e) => e.fieldErrors['address.city'],
              'nested',
              'This field is required.',
            )
            .having((e) => e.requestId, 'rid', 'rid-1'),
      ),
    );
  });

  test('AUTH_TOKEN_EXPIRED refreshes once and retries once', () async {
    adapter.enqueue(401, {'code': 'AUTH_TOKEN_EXPIRED', 'errors': {}});
    adapter.enqueue(200, {'ok': true});
    final response = await client.get('/patient/me');
    expect(response.isSuccess, isTrue);
    expect(refreshes, 1);
    expect(adapter.requests.length, 2);
    expect(adapter.requests.last.headers['authorization'], 'Bearer access-2');
    expect(events, isEmpty);
  });

  test('parallel 401s share one refresh (single-flight)', () async {
    for (var i = 0; i < 3; i++) {
      adapter.enqueue(401, {'code': 'AUTH_TOKEN_EXPIRED', 'errors': {}});
    }
    for (var i = 0; i < 3; i++) {
      adapter.enqueue(200, {'ok': i});
    }
    await Future.wait([
      client.get('/patient/me'),
      client.get('/patient/appointments'),
      client.get('/patient/notifications'),
    ]);
    expect(refreshes, 1);
  });

  test(
    'a 401 for a token that was already replaced retries without refreshing',
    () async {
      adapter.enqueue(401, {'code': 'AUTH_TOKEN_EXPIRED', 'errors': {}});
      adapter.enqueue(200, {'ok': true});
      // Another caller (a socket, say) rotates the token while this request
      // is in the air.
      adapter.onFetch = (options) {
        if (adapter.requests.length == 1) token = 'access-9';
      };

      final response = await client.get('/patient/me');

      expect(response.isSuccess, isTrue);
      expect(refreshes, 0);
      expect(
        adapter.requests.first.headers['authorization'],
        'Bearer access-1',
      );
      expect(adapter.requests.last.headers['authorization'], 'Bearer access-9');
      expect(events, isEmpty);
    },
  );

  // BL-AUTH-051: a blip on the refresh call must not sign the user out.
  for (final blip in <String, Object>{
    'no connection': const NetworkFailure(),
    'a timeout': const TimeoutFailure(),
    'a server error': const ServerFailure(),
    'a 500 from the refresh endpoint': const HttpStatusException(
      statusCode: 500,
      code: 'SERVER_ERROR',
      message: 'boom',
    ),
  }.entries) {
    test('a refresh that fails with ${blip.key} keeps the session', () async {
      refreshError = blip.value;
      for (var i = 0; i < 3; i++) {
        adapter.enqueue(401, {'code': 'AUTH_TOKEN_EXPIRED', 'errors': {}});
      }

      final results = await Future.wait([
        for (final path in ['/patient/me', '/patient/appointments', '/x'])
          client.get(path).then<Object?>((r) => r, onError: (Object e) => e),
      ]);

      expect(results, everyElement(same(blip.value)));
      expect(refreshes, 1);
      expect(events, isEmpty, reason: 'the session must survive');

      // Once the network is back the next request refreshes and succeeds.
      refreshError = null;
      adapter.enqueue(401, {'code': 'AUTH_TOKEN_EXPIRED', 'errors': {}});
      adapter.enqueue(200, {'ok': true});
      expect((await client.get('/patient/me')).isSuccess, isTrue);
      expect(events, isEmpty);
    });
  }

  test('a refresh the server refuses ends the session, once', () async {
    refreshError = const UnauthorizedFailure(apiCode: 'AUTH_SESSION_REVOKED');
    for (var i = 0; i < 3; i++) {
      adapter.enqueue(401, {'code': 'AUTH_TOKEN_EXPIRED', 'errors': {}});
    }

    final results = await Future.wait([
      for (final path in ['/patient/me', '/patient/appointments', '/x'])
        client.get(path).then<Object?>((r) => r, onError: (Object e) => e),
    ]);

    expect(results, everyElement(isA<HttpStatusException>()));
    expect(refreshes, 1);
    expect(events, ['lost:AUTH_SESSION_REVOKED']);
  });

  test(
    'a second AUTH_TOKEN_EXPIRED after refresh reports the session lost',
    () async {
      adapter.enqueue(401, {'code': 'AUTH_TOKEN_EXPIRED', 'errors': {}});
      adapter.enqueue(401, {'code': 'AUTH_TOKEN_EXPIRED', 'errors': {}});
      await expectLater(
        client.get('/patient/me'),
        throwsA(isA<HttpStatusException>()),
      );
      expect(refreshes, 1);
      expect(events, ['lost:AUTH_TOKEN_EXPIRED']);
    },
  );

  test(
    'AUTH_SESSION_REVOKED reports the session lost without refreshing',
    () async {
      adapter.enqueue(401, {'code': 'AUTH_SESSION_REVOKED', 'errors': {}});
      await expectLater(
        client.get('/patient/me'),
        throwsA(isA<HttpStatusException>()),
      );
      expect(refreshes, 0);
      expect(events, ['lost:AUTH_SESSION_REVOKED']);
    },
  );

  test(
    'AUTH_INVALID_CREDENTIALS is a form error, never a session loss',
    () async {
      adapter.enqueue(401, {
        'code': 'AUTH_INVALID_CREDENTIALS',
        'errors': {},
        'meta': {'attempts_remaining': 4},
      });
      Object? caught;
      try {
        await client.post(
          '/patient/auth/login/password',
          body: {},
          requiresAuth: false,
        );
      } catch (error) {
        caught = error;
      }
      final failure = NetworkExceptions.toFailure(caught!);
      expect(failure, isA<UnauthorizedFailure>());
      expect((failure as UnauthorizedFailure).sessionExpired, isFalse);
      expect(failure.attemptsRemaining, 4);
      expect(refreshes, 0);
      expect(events, isEmpty);
    },
  );

  test('429 maps to RateLimitedFailure with retry_after_seconds', () async {
    adapter.enqueue(429, {
      'code': 'RATE_LIMITED',
      'errors': {},
      'meta': {'retry_after_seconds': 7},
    });
    Object? caught;
    try {
      await client.get('/patient/me');
    } catch (error) {
      caught = error;
    }
    final failure = NetworkExceptions.toFailure(caught!);
    expect(failure, isA<RateLimitedFailure>());
    expect(
      (failure as RateLimitedFailure).retryAfter,
      const Duration(seconds: 7),
    );
  });

  test('409 SLOT_UNAVAILABLE maps to ConflictFailure with the code', () async {
    adapter.enqueue(409, {
      'code': 'SLOT_UNAVAILABLE',
      'errors': {},
      'meta': {},
    });
    Object? caught;
    try {
      await client.post('/patient/appointments', body: {});
    } catch (error) {
      caught = error;
    }
    final failure = NetworkExceptions.toFailure(caught!);
    expect(failure, isA<ConflictFailure>());
    expect(failure.apiCode, ApiErrorCodes.slotUnavailable);
  });

  test('Page.parse reads the envelope and rejects a bare list', () {
    final page = Page.parse({
      'results': [
        {'id': 'a'},
        {'id': 'b'},
      ],
      'page': 2,
      'page_size': 25,
      'total': 27,
      'has_next': false,
    }, (json) => json['id'] as String);
    expect(page.results, ['a', 'b']);
    expect(page.page, 2);
    expect(page.hasNext, isFalse);
    expect(
      () => Page.parse([1, 2], (json) => json),
      throwsA(isA<ResponseFormatException>()),
    );
  });

  // BL-CACHE-019: the monitor learns from each request whether the server
  // was reached, to spot Wi-Fi with no internet.
  test('reports whether each request reached the server', () async {
    final reached = <bool>[];
    final reporting = DioApiClient(
      baseUrl: 'https://api.test',
      dio: Dio(
        BaseOptions(
          baseUrl: 'https://api.test/api/v1',
          validateStatus: (s) => s != null && s < 400,
        ),
      )..httpClientAdapter = adapter,
      hooks: ApiSessionHooks(
        accessToken: () async => token,
        deviceFingerprint: () async => 'fp-1',
        refresh: () async => token,
        onSessionLost: (_) async {},
      ),
      onReachability: reached.add,
    );

    adapter.enqueue(200, {'ok': true});
    await reporting.send(const ApiRequest(path: '/a'));
    adapter.enqueue(404, {
      'error': {'code': 'NOT_FOUND', 'message': 'x'},
    });
    await expectLater(
      reporting.send(const ApiRequest(path: '/b')),
      throwsA(isA<HttpStatusException>()),
    );
    adapter.onFetch = (options) => throw DioException.connectionError(
      requestOptions: options,
      reason: 'no internet',
    );
    await expectLater(
      reporting.send(const ApiRequest(path: '/c')),
      throwsA(isA<NoConnectionException>()),
    );

    expect(reached, [true, true, false]);
  });

  // Checklist AUTH-026: the server sends the wait only as `Retry-After`;
  // the message names it.
  test('a 429 carries Retry-After into the message', () async {
    adapter.enqueue(
      429,
      {'code': 'RATE_LIMITED', 'message': 'Too many requests.', 'meta': {}},
      headers: {'retry-after': '17'},
    );
    final error = await client
        .send(const ApiRequest(path: '/a'))
        .then<Object?>((_) => null, onError: (Object e) => e);
    final failure = NetworkExceptions.toFailure(error!, StackTrace.empty);
    expect(failure, isA<RateLimitedFailure>());
    expect(
      (failure as RateLimitedFailure).retryAfter,
      const Duration(seconds: 17),
    );
    expect(
      failure.userMessage,
      'Too many attempts. Please wait 17 seconds and try again.',
    );
    expect(
      RateLimitedFailure.messageFor(const {'retry_after_seconds': 60}),
      'Too many attempts. Please wait about 1 minute and try again.',
    );
  });

  // Checklist E2E-009: offline, Pay said "This is taking longer than usual".
  // With no network at all a timeout is reported as no connection.
  test('a timeout with no network is reported as no connection', () async {
    var offline = true;
    final client = DioApiClient(
      baseUrl: 'https://api.test',
      dio: Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
        ..httpClientAdapter = adapter,
      hooks: ApiSessionHooks(
        accessToken: () async => token,
        deviceFingerprint: () async => 'fp-1',
        refresh: () async => token,
        onSessionLost: (_) async {},
      ),
      isOffline: () => offline,
    );
    adapter.onFetch = (options) => throw DioException.connectionTimeout(
      requestOptions: options,
      timeout: const Duration(seconds: 1),
    );

    await expectLater(
      client.send(const ApiRequest(path: '/a')),
      throwsA(isA<NoConnectionException>()),
    );
    offline = false;
    await expectLater(
      client.send(const ApiRequest(path: '/a')),
      throwsA(isA<RequestTimeoutException>()),
      reason: 'with a network, a slow server is still a timeout',
    );
  });
}

/// Replays scripted responses in order and records every request.
class _ScriptedAdapter implements HttpClientAdapter {
  final List<_Scripted> _queue = [];
  final List<RequestOptions> requests = [];

  /// Runs as each request leaves, after it has been recorded.
  void Function(RequestOptions options)? onFetch;

  void enqueue(int status, Object? body, {Map<String, String>? headers}) =>
      _queue.add(_Scripted(status, body, headers ?? const {}));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    onFetch?.call(options);
    if (_queue.isEmpty) throw StateError('no scripted response for $options');
    final next = _queue.removeAt(0);
    final bytes = next.body == null
        ? <int>[]
        : utf8.encode(jsonEncode(next.body));
    return ResponseBody.fromBytes(
      bytes,
      next.status,
      headers: {
        if (next.body != null) 'content-type': ['application/json'],
        for (final e in next.headers.entries) e.key: [e.value],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Scripted {
  const _Scripted(this.status, this.body, this.headers);

  final int status;
  final Object? body;
  final Map<String, String> headers;
}
