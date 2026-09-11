import 'dart:async';

import '../utils/logger.dart';
import 'network_exceptions.dart';

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
    this.ifModifiedSince,
  });

  /// Path from [Endpoints] — never a full URL.
  final String path;

  final HttpMethod method;

  /// Query parameters; null values are dropped before the request is sent.
  final Map<String, Object?> query;

  /// JSON-encodable request body.
  final Object? body;

  /// Extra headers merged over the client's defaults.
  final Map<String, String> headers;

  /// Per-request override of the client's default timeout.
  final Duration? timeout;

  /// When true the client attaches the bearer token and performs the
  /// refresh-once-then-logout dance on 401 (Coding Standards §6.2).
  final bool requiresAuth;

  /// `Last-Modified` value held in cache, sent as `If-Modified-Since` to invite
  /// a 304 (HIVE spec, Scenario 6).
  final String? ifModifiedSince;

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
    String? ifModifiedSince,
  }) {
    return ApiRequest(
      path: path ?? this.path,
      method: method ?? this.method,
      query: query ?? this.query,
      body: body ?? this.body,
      headers: headers ?? this.headers,
      timeout: timeout ?? this.timeout,
      requiresAuth: requiresAuth ?? this.requiresAuth,
      ifModifiedSince: ifModifiedSince ?? this.ifModifiedSince,
    );
  }

  @override
  String toString() => '${method.value} $path';
}

/// One response. [data] is the decoded JSON payload (`Map`, `List` or a
/// primitive); mapping it onto a model is the repository's job.
class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    this.data,
    this.headers = const <String, String>{},
  });

  final int statusCode;
  final Object? data;
  final Map<String, String> headers;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// 304 — the caller's cached copy is current and [data] is empty.
  bool get isNotModified => statusCode == 304;

  /// `Last-Modified`, to be stored alongside the cached entry.
  String? get lastModified =>
      headers['last-modified'] ?? headers['Last-Modified'];

  /// [data] as a JSON object, or null when the body was not an object.
  Map<String, Object?>? get asMap {
    final value = data;
    return value is Map<String, Object?> ? value : null;
  }

  /// [data] as a JSON array, or an empty list when the body was not an array.
  List<Object?> get asList {
    final value = data;
    return value is List<Object?> ? value : const <Object?>[];
  }
}

/// The single HTTP seam for the whole app (Coding Standards §6.1).
///
/// Deliberately an **interface**: this presentation-layer build ships no HTTP
/// package (`dio`/`retrofit` are absent by design — see `pubspec.yaml`). When
/// the data layer lands, `DioApiClient implements ApiClient` and wires
/// interceptors for auth, the refresh-once-on-401 retry, logging and the
/// `If-Modified-Since` conditional requests; *nothing above this interface
/// changes*, because repositories already depend on it and not on Dio.
///
/// Implementations must:
/// * join [ApiRequest.path] onto the environment's base URL, never accept an
///   absolute URL from a caller;
/// * throw a [NetworkException] — never a package-specific exception — so
///   `NetworkExceptions.toFailure` is the only mapping layer;
/// * honour [ApiRequest.timeout] (default `AppConstants.apiTimeout`);
/// * return the 304 rather than throwing, so the cache can use it.
abstract interface class ApiClient {
  /// Perform [request].
  Future<ApiResponse> send(ApiRequest request);

  /// Convenience verbs. Implementations get these for free by mixing in
  /// [ApiClientVerbs].
  Future<ApiResponse> get(
    String path, {
    Map<String, Object?> query,
    String? ifModifiedSince,
    bool requiresAuth,
  });

  Future<ApiResponse> post(
    String path, {
    Object? body,
    Map<String, Object?> query,
    bool requiresAuth,
  });

  Future<ApiResponse> put(String path, {Object? body, bool requiresAuth});

  Future<ApiResponse> patch(String path, {Object? body, bool requiresAuth});

  Future<ApiResponse> delete(String path, {Object? body, bool requiresAuth});

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
    String? ifModifiedSince,
    bool requiresAuth = true,
  }) => send(
    ApiRequest(
      path: path,
      query: query,
      ifModifiedSince: ifModifiedSince,
      requiresAuth: requiresAuth,
    ),
  );

  @override
  Future<ApiResponse> post(
    String path, {
    Object? body,
    Map<String, Object?> query = const <String, Object?>{},
    bool requiresAuth = true,
  }) => send(
    ApiRequest(
      path: path,
      method: HttpMethod.post,
      body: body,
      query: query,
      requiresAuth: requiresAuth,
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
  }) => send(
    ApiRequest(
      path: path,
      method: HttpMethod.patch,
      body: body,
      requiresAuth: requiresAuth,
    ),
  );

  @override
  Future<ApiResponse> delete(
    String path, {
    Object? body,
    bool requiresAuth = true,
  }) => send(
    ApiRequest(
      path: path,
      method: HttpMethod.delete,
      body: body,
      requiresAuth: requiresAuth,
    ),
  );

  @override
  void close() {}
}

/// An [ApiClient] that refuses every call.
///
/// This is what the app is wired to until the data layer exists: it fails
/// loudly *in the right shape* (a [NetworkException] that maps to a
/// [Failure]) instead of pretending to succeed, so any screen accidentally
/// wired to the network shows the real error view rather than a fake success.
/// Swap it out in `app/bootstrap/app_bootstrap.dart`.
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
