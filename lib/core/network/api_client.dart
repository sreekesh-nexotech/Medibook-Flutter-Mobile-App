import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:uuid/uuid.dart';

import '../error/failure.dart';
import '../utils/logger.dart';
import '../utils/server_clock.dart';
import 'endpoints.dart';
import 'network_exceptions.dart';
import 'user_agent.dart';

export 'models/page.dart';

/// HTTP verbs the client supports. Part of the cache key (see
/// `core/storage/hive/keys.dart`), so it is an enum rather than a string.
enum HttpMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  patch('PATCH'),
  delete('DELETE');

  const HttpMethod(this.value);

  final String value;

  /// True for verbs whose responses may be cached (HIVE spec: reads only).
  bool get isCacheable => this == HttpMethod.get;
}

/// One request, described declaratively so it can be logged, hashed into a
/// cache key and replayed on retry without re-deriving anything.
class ApiRequest {
  const ApiRequest({
    required this.path,
    this.method = HttpMethod.get,
    this.query = const <String, Object?>{},
    this.body,
    this.headers = const <String, String>{},
    this.timeout,
    this.requiresAuth = true,
    this.ifNoneMatch,
    this.ifMatch,
    this.idempotencyKey,
    this.withDeviceFingerprint = false,
    this.responseType = ApiResponseType.json,
  });

  /// Path from [Endpoints] — never a full URL.
  final String path;

  final HttpMethod method;

  /// Query parameters; null values are dropped before the request is sent.
  /// Only send parameters the endpoint lists — an unknown one is a
  /// `400 VALIDATION_ERROR` (§1.7).
  final Map<String, Object?> query;

  /// JSON-encodable request body.
  final Object? body;

  /// Extra headers merged over the client's defaults.
  final Map<String, String> headers;

  /// Per-request override of the client's default timeout.
  final Duration? timeout;

  /// When true the client attaches the bearer token and performs the
  /// refresh-once-then-sign-out dance on `AUTH_TOKEN_EXPIRED` (§1.4).
  final bool requiresAuth;

  /// The `ETag` held in cache, sent as `If-None-Match` to invite a 304 (§1.10).
  final String? ifNoneMatch;

  /// The row `version` for optimistic concurrency, sent as
  /// `If-Match: "<version>"` (§1.9).
  final int? ifMatch;

  /// `Idempotency-Key` for the six money/booking mutations (§1.8). Generate one
  /// per user action and reuse it on a retry of that same action.
  final String? idempotencyKey;

  /// Attach `X-Device-Fingerprint` — required on every OTP call (§1.3).
  final bool withDeviceFingerprint;

  final ApiResponseType responseType;

  /// Query with nulls removed and values stringified — the form both the
  /// transport and the cache-key builder consume.
  Map<String, String> get normalisedQuery {
    final result = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null) continue;
      result[entry.key] = value.toString();
    }
    return result;
  }

  ApiRequest copyWith({
    String? path,
    HttpMethod? method,
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    bool? requiresAuth,
    String? ifNoneMatch,
    int? ifMatch,
    String? idempotencyKey,
    bool? withDeviceFingerprint,
    ApiResponseType? responseType,
  }) {
    return ApiRequest(
      path: path ?? this.path,
      method: method ?? this.method,
      query: query ?? this.query,
      body: body ?? this.body,
      headers: headers ?? this.headers,
      timeout: timeout ?? this.timeout,
      requiresAuth: requiresAuth ?? this.requiresAuth,
      ifNoneMatch: ifNoneMatch ?? this.ifNoneMatch,
      ifMatch: ifMatch ?? this.ifMatch,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      withDeviceFingerprint:
          withDeviceFingerprint ?? this.withDeviceFingerprint,
      responseType: responseType ?? this.responseType,
    );
  }

  @override
  String toString() => '${method.value} $path';
}

/// What the client should do with the response body.
enum ApiResponseType {
  /// Decode JSON (the default; every endpoint but two).
  json,

  /// Keep the raw bytes (`calendar.ics`).
  bytes,
}

/// One response. [data] is the decoded JSON payload (`Map`, `List` or a
/// primitive) — or raw bytes for [ApiResponseType.bytes]; mapping it onto a
/// model is the repository's job.
class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    this.data,
    this.headers = const <String, String>{},
  });

  final int statusCode;
  final Object? data;

  /// Lower-cased header names.
  final Map<String, String> headers;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// 304 — the caller's cached copy is current and [data] is empty.
  bool get isNotModified => statusCode == 304;

  /// The `ETag` to store alongside the cached entry (§1.10).
  String? get etag => headers['etag'];

  /// True when the server replayed an earlier idempotent response (§1.8).
  bool get isIdempotentReplay => headers['idempotent-replayed'] == 'true';

  /// `X-Request-Id`, for support tickets.
  String? get requestId => headers['x-request-id'];

  /// [data] as a JSON object, or null when the body was not an object.
  Map<String, Object?>? get asMap {
    final value = data;
    return value is Map ? value.cast<String, Object?>() : null;
  }

  /// [data] as a JSON object; throws [ResponseFormatException] otherwise —
  /// the response-validation pipeline's first gate (HIVE spec, Scenario 10).
  Map<String, Object?> get requireMap {
    final map = asMap;
    if (map == null) {
      throw ResponseFormatException(
        message: 'expected a JSON object, got ${data.runtimeType}',
      );
    }
    return map;
  }

  /// [data] as a JSON array, or an empty list when the body was not an array.
  List<Object?> get asList {
    final value = data;
    return value is List ? value.cast<Object?>() : const <Object?>[];
  }

  /// [data] as raw bytes ([ApiResponseType.bytes]), or empty.
  List<int> get asBytes {
    final value = data;
    return value is List<int> ? value : const <int>[];
  }
}

/// The single HTTP seam for the whole app (Coding Standards §6.1).
///
/// An **interface** so repositories depend on it and not on Dio; the tests
/// override it with a fake. Implementations must:
/// * join [ApiRequest.path] onto the environment's base URL, never accept an
///   absolute URL from a caller;
/// * throw a [NetworkException] — never a package-specific exception — so
///   `NetworkExceptions.toFailure` is the only mapping layer;
/// * honour [ApiRequest.timeout] (default `CacheConfig.apiTimeout`);
/// * return the 304 rather than throwing, so the cache can use it.
abstract interface class ApiClient {
  /// Perform [request].
  Future<ApiResponse> send(ApiRequest request);

  /// Convenience verbs. Implementations get these for free by mixing in
  /// [ApiClientVerbs].
  Future<ApiResponse> get(
    String path, {
    Map<String, Object?> query,
    String? ifNoneMatch,
    bool requiresAuth,
  });

  Future<ApiResponse> post(
    String path, {
    Object? body,
    Map<String, Object?> query,
    bool requiresAuth,
    String? idempotencyKey,
    bool withDeviceFingerprint,
  });

  Future<ApiResponse> put(String path, {Object? body, bool requiresAuth});

  Future<ApiResponse> patch(
    String path, {
    Object? body,
    bool requiresAuth,
    int? ifMatch,
  });

  Future<ApiResponse> delete(
    String path, {
    Object? body,
    bool requiresAuth,
    int? ifMatch,
  });

  /// Abandon in-flight work (screen disposed, user signed out).
  void close();
}

/// Default implementations of the convenience verbs in terms of [send], so an
/// [ApiClient] implementation only has to write one method.
mixin ApiClientVerbs implements ApiClient {
  @override
  Future<ApiResponse> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    String? ifNoneMatch,
    bool requiresAuth = true,
  }) => send(
    ApiRequest(
      path: path,
      query: query,
      ifNoneMatch: ifNoneMatch,
      requiresAuth: requiresAuth,
    ),
  );

  @override
  Future<ApiResponse> post(
    String path, {
    Object? body,
    Map<String, Object?> query = const <String, Object?>{},
    bool requiresAuth = true,
    String? idempotencyKey,
    bool withDeviceFingerprint = false,
  }) => send(
    ApiRequest(
      path: path,
      method: HttpMethod.post,
      body: body,
      query: query,
      requiresAuth: requiresAuth,
      idempotencyKey: idempotencyKey,
      withDeviceFingerprint: withDeviceFingerprint,
    ),
  );

  @override
  Future<ApiResponse> put(
    String path, {
    Object? body,
    bool requiresAuth = true,
  }) => send(
    ApiRequest(
      path: path,
      method: HttpMethod.put,
      body: body,
      requiresAuth: requiresAuth,
    ),
  );

  @override
  Future<ApiResponse> patch(
    String path, {
    Object? body,
    bool requiresAuth = true,
    int? ifMatch,
  }) => send(
    ApiRequest(
      path: path,
      method: HttpMethod.patch,
      body: body,
      requiresAuth: requiresAuth,
      ifMatch: ifMatch,
    ),
  );

  @override
  Future<ApiResponse> delete(
    String path, {
    Object? body,
    bool requiresAuth = true,
    int? ifMatch,
  }) => send(
    ApiRequest(
      path: path,
      method: HttpMethod.delete,
      body: body,
      requiresAuth: requiresAuth,
      ifMatch: ifMatch,
    ),
  );

  @override
  void close() {}
}

/// An [ApiClient] that refuses every call.
///
/// Used by tests that must not touch the network, and as the provider default
/// so a missing override fails loudly *in the right shape* (a
/// [NetworkException] that maps to a `Failure`) instead of pretending.
class UnimplementedApiClient with ApiClientVerbs implements ApiClient {
  const UnimplementedApiClient();

  @override
  Future<ApiResponse> send(ApiRequest request) {
    AppLogger.warning(
      'No ApiClient is installed; refusing $request',
      name: 'network',
    );
    throw NoConnectionException(
      message:
          'No ApiClient implementation is installed for $request. '
          'Install one in app/bootstrap/app_bootstrap.dart.',
    );
  }
}

/// What the client needs from the auth layer, expressed as callbacks so this
/// file depends on no feature.
///
/// * [accessToken] — the current bearer, or null when signed out.
/// * [deviceFingerprint] — the stable per-install id (§1.3).
/// * [refresh] — exchange the refresh token; must return the new access token
///   or throw. The client makes this **single-flight** (§1.4).
/// * [onSessionLost] — called once when a session-ending code arrives
///   (`AUTH_SESSION_REVOKED`, …) or a refresh fails; the auth layer clears
///   tokens and routes to sign-in.
class ApiSessionHooks {
  const ApiSessionHooks({
    required this.accessToken,
    required this.deviceFingerprint,
    required this.refresh,
    required this.onSessionLost,
  });

  final Future<String?> Function() accessToken;
  final Future<String> Function() deviceFingerprint;
  final Future<String> Function() refresh;
  final Future<void> Function(Failure failure) onSessionLost;
}

/// The production [ApiClient], over Dio.
///
/// Implements the contract in `FLUTTER_API_INTEGRATION.md` §1:
/// * base URL + `/api/v1` prefix, JSON bodies, no trailing slash;
/// * `Authorization: Bearer` from [ApiSessionHooks.accessToken];
/// * `X-Device-Fingerprint` on OTP calls; `Idempotency-Key`; `If-Match`;
///   `If-None-Match`; a generated `X-Request-Id` on every call;
/// * `AUTH_TOKEN_EXPIRED` → one **single-flight** refresh, then one retry;
/// * session-ending codes → [ApiSessionHooks.onSessionLost] once;
/// * 304 returned as a normal [ApiResponse]; every other non-2xx thrown as
///   [HttpStatusException] with the parsed envelope;
/// * every Dio error mapped to a [NetworkException].
class DioApiClient with ApiClientVerbs implements ApiClient {
  DioApiClient({
    required String baseUrl,
    required ApiSessionHooks hooks,
    Duration timeout = const Duration(seconds: 10),
    bool allowBadCertificate = false,
    // Bootstrap passes the real one (`AppUserAgent.resolve`): this build's
    // version and the device, which Signed-in Devices shows (§4.9).
    String userAgent = AppUserAgent.fallback,
    Dio? dio,
    void Function(bool reached)? onReachability,
    bool Function()? isOffline,
  }) : _hooks = hooks,
       _timeout = timeout,
       _onReachability = onReachability,
       _isOffline = isOffline,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: '$baseUrl${Endpoints.apiPrefix}',
               connectTimeout: timeout,
               receiveTimeout: timeout,
               sendTimeout: timeout,
               headers: {
                 HttpHeaders.acceptHeader: 'application/json',
                 HttpHeaders.userAgentHeader: userAgent,
               },
               responseType: ResponseType.json,
               // We branch on the status ourselves so a 304 is not an error.
               validateStatus: (status) => status != null && status < 400,
             ),
           ) {
    if (allowBadCertificate) _trustAllCertificates();
  }

  final Dio _dio;
  final ApiSessionHooks _hooks;
  final Duration _timeout;

  /// Told after every request whether the server was reached — true for any
  /// HTTP answer, false for no connection or a timeout — so the connectivity
  /// monitor can spot a network with no internet (BL-CACHE-019).
  final void Function(bool reached)? _onReachability;

  /// True while the device has no network (airplane mode, no route). A
  /// request that then times out is reported as "no connection", so the
  /// patient reads "You appear to be offline" rather than "This is taking
  /// longer than usual" (Checklist E2E-009).
  final bool Function()? _isOffline;
  final CancelToken _cancel = CancelToken();
  static const Uuid _uuid = Uuid();

  /// The one in-flight refresh, shared by every request that hit a 401 at the
  /// same moment (§1.4: "only one refresh call may go out").
  Future<String>? _refreshInFlight;

  /// Set once a session-ending error has been reported, so ten parallel
  /// requests do not sign the user out ten times.
  bool _sessionLostReported = false;

  @override
  Future<ApiResponse> send(ApiRequest request) =>
      _send(request, retried: false);

  Future<ApiResponse> _send(ApiRequest request, {required bool retried}) async {
    final headers = <String, String>{
      ...request.headers,
      'X-Request-Id': _uuid.v4().replaceAll('-', ''),
    };
    String? sentToken;
    if (request.requiresAuth) {
      final token = await _hooks.accessToken();
      if (token != null && token.isNotEmpty) {
        headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
        sentToken = token;
      }
    }
    if (request.withDeviceFingerprint) {
      headers['X-Device-Fingerprint'] = await _hooks.deviceFingerprint();
    }
    if (request.idempotencyKey != null) {
      headers['Idempotency-Key'] = request.idempotencyKey!;
    }
    if (request.ifMatch != null) headers['If-Match'] = '"${request.ifMatch}"';
    if (request.ifNoneMatch != null) {
      headers['If-None-Match'] = request.ifNoneMatch!;
    }

    final timeout = request.timeout ?? _timeout;
    try {
      final response = await _dio.request<Object?>(
        request.path,
        data: request.body,
        queryParameters: request.normalisedQuery,
        cancelToken: _cancel,
        options: Options(
          method: request.method.value,
          headers: headers,
          contentType: request.body == null ? null : Headers.jsonContentType,
          responseType: request.responseType == ApiResponseType.bytes
              ? ResponseType.bytes
              : ResponseType.json,
          receiveTimeout: timeout,
          sendTimeout: timeout,
        ),
      );
      _onReachability?.call(true);
      return _toApiResponse(response);
    } on DioException catch (error, stackTrace) {
      var mapped = _mapDioError(error);
      if (mapped is RequestTimeoutException && (_isOffline?.call() ?? false)) {
        mapped = NoConnectionException(message: mapped.message, cause: error);
      }
      if (mapped is HttpStatusException) _onReachability?.call(true);
      if (mapped is NoConnectionException ||
          mapped is RequestTimeoutException) {
        _onReachability?.call(false);
      }
      if (mapped is HttpStatusException) {
        // ---- §1.4: refresh once, then retry once ----
        if (mapped.code == ApiErrorCodes.authTokenExpired &&
            request.requiresAuth &&
            !retried) {
          // The token this request carried may already have been replaced
          // (a refresh finished while it was in the air): retry with the
          // current one rather than refreshing a second time.
          final current = await _hooks.accessToken();
          final alreadyReplaced =
              sentToken != null &&
              current != null &&
              current.isNotEmpty &&
              current != sentToken;
          final refreshError = alreadyReplaced ? null : await _refreshOnce();
          if (refreshError == null) return _send(request, retried: true);
          if (_refreshEndsSession(refreshError)) {
            Error.throwWithStackTrace(mapped, stackTrace);
          }
          // A blip on the refresh call: the session is intact, so this
          // request fails with what actually went wrong (offline, timeout,
          // server error) rather than as an expired session.
          Error.throwWithStackTrace(refreshError, stackTrace);
        }
        if (request.requiresAuth &&
            mapped.code != null &&
            (ApiErrorCodes.sessionEnding.contains(mapped.code) ||
                (mapped.code == ApiErrorCodes.authTokenExpired && retried))) {
          await _reportSessionLost(mapped, stackTrace);
        }
      }
      Error.throwWithStackTrace(mapped, stackTrace);
    }
  }

  /// Runs — or joins — the single refresh. Null when a new token is in place;
  /// otherwise the error the waiting request should fail with.
  ///
  /// Only a refresh the server *refused* ends the session. A refresh that
  /// could not be completed — no signal, a timeout, a 5xx, a 429 — leaves the
  /// stored session alone, so the next request simply tries again.
  Future<Object?> _refreshOnce() async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      try {
        await inFlight;
        return null;
      } catch (error) {
        return error;
      }
    }
    final attempt = _hooks.refresh();
    _refreshInFlight = attempt;
    try {
      await attempt;
      AppLogger.debug('Access token refreshed', name: 'network');
      return null;
    } catch (error, stackTrace) {
      AppLogger.warning('Token refresh failed', name: 'network', error: error);
      if (_refreshEndsSession(error)) {
        await _reportSessionLost(error, stackTrace);
      }
      return error;
    } finally {
      _refreshInFlight = null;
    }
  }

  /// Whether a failed refresh means the session is really over (§1.4).
  static bool _refreshEndsSession(Object error) {
    if (error is UnauthorizedFailure) return error.sessionExpired;
    if (error is Failure) {
      return ApiErrorCodes.sessionEnding.contains(error.apiCode);
    }
    if (error is HttpStatusException) {
      return error.statusCode == 401 ||
          error.statusCode == 403 ||
          ApiErrorCodes.sessionEnding.contains(error.code);
    }
    return false;
  }

  Future<void> _reportSessionLost(Object error, StackTrace stackTrace) async {
    if (_sessionLostReported) return;
    _sessionLostReported = true;
    try {
      await _hooks.onSessionLost(
        NetworkExceptions.toFailure(error, stackTrace),
      );
    } finally {
      // A later sign-in must be able to report a *new* loss.
      _sessionLostReported = false;
    }
  }

  ApiResponse _toApiResponse(Response<Object?> response) {
    final headers = <String, String>{
      for (final entry in response.headers.map.entries)
        entry.key.toLowerCase(): entry.value.join(', '),
    };
    // Keeps the server's time for deadlines it sets (BL-CORE-007).
    ServerClock.observe(headers['date']);
    final status = response.statusCode ?? 0;
    if (status == 304) {
      return ApiResponse(statusCode: status, headers: headers);
    }
    Object? data = response.data;
    // Dio hands back a String when the server did not label the body as JSON
    // (or the body is empty); normalise so repositories only see decoded data.
    if (data is String) {
      data = data.isEmpty ? null : _decodeLenient(data);
    }
    return ApiResponse(statusCode: status, data: data, headers: headers);
  }

  static Object? _decodeLenient(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return raw;
    }
  }

  NetworkException _mapDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return RequestTimeoutException(message: error.message, cause: error);
      case DioExceptionType.cancel:
        return RequestCancelledException(message: error.message, cause: error);
      case DioExceptionType.badCertificate:
        return TlsException(message: error.message, cause: error);
      case DioExceptionType.connectionError:
        return NoConnectionException(message: error.message, cause: error);
      case DioExceptionType.badResponse:
        final response = error.response;
        final status = response?.statusCode ?? 0;
        Object? body = response?.data;
        String? raw;
        if (body is String) {
          raw = body.length > 2000 ? body.substring(0, 2000) : body;
          body = _decodeLenient(body);
        } else if (body is List<int>) {
          raw = null;
          body = _decodeLenient(utf8.decode(body, allowMalformed: true));
        }
        return HttpStatusException.fromBody(
          status,
          body,
          retryAfterSeconds: int.tryParse(
            error.response?.headers.value('retry-after') ?? '',
          ),
          rawBody: raw,
          message:
              '${error.requestOptions.method} '
              '${error.requestOptions.path} → $status',
          cause: error,
        );
      case DioExceptionType.unknown:
        final cause = error.error;
        if (cause is SocketException) {
          return NoConnectionException(message: cause.message, cause: cause);
        }
        if (cause is HandshakeException) {
          return TlsException(message: cause.message, cause: cause);
        }
        if (cause is TimeoutException) {
          return RequestTimeoutException(message: cause.message, cause: cause);
        }
        if (cause is FormatException) {
          return ResponseFormatException(message: cause.message, cause: cause);
        }
        return NoConnectionException(message: error.message, cause: error);
    }
  }

  /// Dev/staging only: accept the test server's self-signed certificate.
  /// `EnvLoader` refuses to let a production build enable this.
  void _trustAllCertificates() {
    final adapter = _dio.httpClientAdapter;
    if (adapter is IOHttpClientAdapter) {
      adapter.createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };
    }
    AppLogger.warning(
      'TLS certificate validation is DISABLED for this build',
      name: 'network',
    );
  }

  @override
  void close() {
    _cancel.cancel('client closed');
    _dio.close(force: true);
  }
}

/// Request de-duplication pool (HIVE spec, Scenario 7).
///
/// Two widgets asking for the same endpoint in the same frame must produce one
/// network call, not two. Keyed by cache key, so it composes with the caching
/// layer: `pool.dedupe(cacheKey, () => client.send(request))`.
class RequestPool {
  final Map<String, Future<Object?>> _inFlight = <String, Future<Object?>>{};

  /// Number of requests currently in flight (diagnostics / tests).
  int get inFlightCount => _inFlight.length;

  /// Run [request] unless an identical [key] is already running, in which case
  /// the existing future is shared with this caller.
  Future<T> dedupe<T>(String key, Future<T> Function() request) {
    final existing = _inFlight[key];
    if (existing != null) return existing.then((value) => value as T);

    final future = request();
    _inFlight[key] = future;
    // Clear the slot whether the request succeeds or fails, so a failure does
    // not poison the key for the rest of the session.
    future.whenComplete(() => _inFlight.remove(key)).ignore();
    return future;
  }

  /// Drop all tracking (sign-out, cache wipe). In-flight futures still
  /// complete for their existing listeners.
  void clear() => _inFlight.clear();
}

/// Retry with exponential backoff (HIVE spec, Scenario 5).
///
/// 4 attempts, 0s/2s/4s/8s, never retrying a 4xx — the exact policy the cache
/// specification fixes. Pure orchestration, so it is unit-testable without a
/// network.
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 4,
    this.maxTotalWait = const Duration(seconds: 15),
  });

  final int maxAttempts;

  /// Total sleeping budget across all attempts; once spent, the last error is
  /// rethrown rather than waiting longer.
  final Duration maxTotalWait;

  Future<T> execute<T>(Future<T> Function() operation) async {
    var waited = Duration.zero;
    Object? lastError;
    StackTrace? lastStack;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await operation();
      } catch (error, stackTrace) {
        lastError = error;
        lastStack = stackTrace;
        final isLast = attempt == maxAttempts;
        if (isLast || !NetworkExceptions.isRetryable(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        final delay = NetworkExceptions.backoffFor(attempt + 1);
        if (waited + delay > maxTotalWait) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        waited += delay;
        AppLogger.debug(
          'Retry $attempt/$maxAttempts in ${delay.inSeconds}s after $error',
          name: 'network',
        );
        await Future<void>.delayed(delay);
      }
    }

    Error.throwWithStackTrace(
      lastError ?? const RequestTimeoutException(message: 'retries exhausted'),
      lastStack ?? StackTrace.current,
    );
  }
}

/// Mints `Idempotency-Key` values (§1.8): one UUID per user action, reused on
/// a retry of that same action. Kept here so every caller spells it the same.
abstract final class IdempotencyKeys {
  IdempotencyKeys._();

  static const Uuid _uuid = Uuid();

  static String mint() => _uuid.v4();
}

/// Runs a provider's read with explicit error handling (QA Prompt 3 #1, CL
/// CODE-011): whatever is thrown is turned into a typed `Failure`, logged
/// once with [what], and rethrown with its stack, so the provider's
/// `AsyncError` always carries a `Failure` the UI knows how to word.
///
/// ```dart
/// final receiptProvider = FutureProvider.autoDispose.family<Receipt, String>(
///   (ref, id) => guardedRead('receipt', () => repository.receipt(id)),
/// );
/// ```
Future<T> guardedRead<T>(String what, Future<T> Function() read) async {
  try {
    return await read();
  } catch (error, stackTrace) {
    final failure = NetworkExceptions.toFailure(error, stackTrace);
    AppLogger.warning(
      '$what failed (${failure.runtimeType})',
      name: 'provider',
      error: error,
    );
    Error.throwWithStackTrace(failure, stackTrace);
  }
}
