import 'dart:async';
import 'dart:io';

import '../error/failure.dart';

/// Transport-level errors, expressed without naming an HTTP package.
///
/// `dio` is deliberately absent from this presentation-layer build (see the
/// note in `pubspec.yaml`), so the client contract in `api_client.dart` throws
/// these instead. When Dio arrives, its interceptor's only job is to translate
/// `DioException` into one of these — nothing above this file changes.
sealed class NetworkException implements Exception {
  const NetworkException({this.message, this.cause});

  /// Technical detail for logs. Never rendered.
  final String? message;

  /// The underlying error (`SocketException`, `TimeoutException`, …).
  final Object? cause;

  @override
  String toString() => '$runtimeType(${message ?? 'no detail'})';
}

/// The device has no usable route to the host.
class NoConnectionException extends NetworkException {
  const NoConnectionException({super.message, super.cause});
}

/// Nothing came back inside the request budget.
class RequestTimeoutException extends NetworkException {
  const RequestTimeoutException({super.message, super.cause});
}

/// The request was abandoned (widget disposed, user navigated away).
class RequestCancelledException extends NetworkException {
  const RequestCancelledException({super.message, super.cause});
}

/// The server answered with a non-success status.
class HttpStatusException extends NetworkException {
  const HttpStatusException({
    required this.statusCode,
    this.body,
    this.fieldErrors = const <String, String>{},
    super.message,
    super.cause,
  });

  final int statusCode;

  /// Raw body, truncated by the client before it gets here.
  final String? body;

  /// Field-level detail parsed out of a 400/422 envelope.
  final Map<String, String> fieldErrors;

  bool get isClientError => statusCode >= 400 && statusCode < 500;
  bool get isServerError => statusCode >= 500;

  /// 304 — the cached copy is still current (HIVE spec, Scenario 6). This is a
  /// *success* for the cache layer, which is why it is modelled but excluded
  /// from [NetworkExceptions.isRetryable].
  bool get isNotModified => statusCode == 304;

  /// 412 — the conditional request's precondition failed; the cache is out of
  /// sync and must be dropped and re-fetched unconditionally.
  bool get isPreconditionFailed => statusCode == 412;
}

/// The response body could not be decoded or did not match the model schema
/// (HIVE spec, Scenario 10).
class ResponseFormatException extends NetworkException {
  const ResponseFormatException({super.message, super.cause});
}

/// TLS/certificate rejection — never retried, never silently ignored.
class TlsException extends NetworkException {
  const TlsException({super.message, super.cause});
}

/// Maps transport errors onto the app's [Failure] model.
///
/// This is the *only* place a status code turns into a sentence a patient
/// reads. Repositories call [toFailure] in their `catch`; controllers and the
/// UI then deal exclusively in [Failure].
abstract final class NetworkExceptions {
  NetworkExceptions._();

  /// Convert any caught error into a [Failure].
  ///
  /// Handles [NetworkException], the `dart:io`/`dart:async` errors that leak
  /// through before an interceptor is installed, and anything else (which
  /// becomes an [UnknownFailure] carrying the original).
  static Failure toFailure(Object error, [StackTrace? stackTrace]) {
    if (error is Failure) return error;

    if (error is NetworkException) {
      return switch (error) {
        NoConnectionException() => NetworkFailure(
          debugMessage: error.message,
          cause: error.cause ?? error,
          stackTrace: stackTrace,
        ),
        RequestTimeoutException() => TimeoutFailure(
          debugMessage: error.message,
          cause: error.cause ?? error,
          stackTrace: stackTrace,
        ),
        RequestCancelledException() => UnknownFailure(
          userMessage: 'That request was cancelled. Please try again.',
          debugMessage: error.message,
          cause: error.cause ?? error,
          stackTrace: stackTrace,
        ),
        ResponseFormatException() => ServerFailure(
          userMessage: 'We could not read the response from our server. '
              'Please try again.',
          debugMessage: error.message,
          cause: error.cause ?? error,
          stackTrace: stackTrace,
        ),
        TlsException() => NetworkFailure(
          userMessage: 'We could not establish a secure connection. Please '
              'try again on a trusted network.',
          debugMessage: error.message,
          cause: error.cause ?? error,
          stackTrace: stackTrace,
        ),
        HttpStatusException() => _fromStatus(error, stackTrace),
      };
    }

    if (error is SocketException) {
      return NetworkFailure(
        debugMessage: error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is HandshakeException) {
      return NetworkFailure(
        userMessage: 'We could not establish a secure connection. Please try '
            'again on a trusted network.',
        debugMessage: error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is TimeoutException) {
      return TimeoutFailure(
        debugMessage: error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is FormatException) {
      return ServerFailure(
        userMessage: 'We could not read the response from our server. Please '
            'try again.',
        debugMessage: error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return UnknownFailure(
      debugMessage: error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }

  static Failure _fromStatus(
    HttpStatusException error,
    StackTrace? stackTrace,
  ) {
    final debug = 'HTTP ${error.statusCode}${error.message == null ? '' : ' — '
        '${error.message}'}';
    return switch (error.statusCode) {
      400 || 422 => ValidationFailure(
        fieldErrors: error.fieldErrors,
        debugMessage: debug,
        cause: error,
        stackTrace: stackTrace,
      ),
      401 || 403 => UnauthorizedFailure(
        sessionExpired: error.statusCode == 401,
        debugMessage: debug,
        cause: error,
        stackTrace: stackTrace,
      ),
      404 => NotFoundFailure(
        debugMessage: debug,
        cause: error,
        stackTrace: stackTrace,
      ),
      408 || 504 => TimeoutFailure(
        debugMessage: debug,
        cause: error,
        stackTrace: stackTrace,
      ),
      409 => ValidationFailure(
        userMessage: 'That slot was just taken. Please pick another time.',
        fieldErrors: error.fieldErrors,
        debugMessage: debug,
        cause: error,
        stackTrace: stackTrace,
      ),
      429 => ServerFailure(
        userMessage: 'Too many attempts. Please wait a moment and try again.',
        statusCode: 429,
        debugMessage: debug,
        cause: error,
        stackTrace: stackTrace,
      ),
      _ => ServerFailure(
        statusCode: error.statusCode,
        debugMessage: debug,
        cause: error,
        stackTrace: stackTrace,
      ),
    };
  }

  /// Whether the operation that raised [error] is worth retrying.
  ///
  /// Mirrors the retry policy in `docs-flutter/HIVE implementation.md`
  /// (Scenario 5): retry connection problems, timeouts and 5xx; never retry a
  /// 4xx, because the request itself is wrong.
  static bool isRetryable(Object error) {
    if (error is HttpStatusException) {
      return error.isServerError || error.statusCode == 408;
    }
    if (error is NoConnectionException || error is RequestTimeoutException) {
      return true;
    }
    if (error is Failure) return error.isRetryable;
    return error is SocketException || error is TimeoutException;
  }

  /// Exponential backoff for attempt [attempt] (1-based): 0s, 2s, 4s, 8s —
  /// the schedule the cache spec fixes at a 15s total budget.
  static Duration backoffFor(int attempt) => attempt <= 1
      ? Duration.zero
      : Duration(seconds: 1 << (attempt - 1));
}
