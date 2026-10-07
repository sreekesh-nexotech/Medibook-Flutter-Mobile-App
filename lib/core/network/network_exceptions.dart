import 'dart:async';
import 'dart:io';

import '../error/failure.dart';
import '../utils/file_size.dart';

/// The backend's stable error codes (`FLUTTER_API_INTEGRATION.md` §16).
///
/// Spelled once, here, so a controller branching on a code cannot typo it.
abstract final class ApiErrorCodes {
  ApiErrorCodes._();

  static const String validationError = 'VALIDATION_ERROR';
  static const String paymentSignatureInvalid = 'PAYMENT_SIGNATURE_INVALID';
  static const String authInvalidCredentials = 'AUTH_INVALID_CREDENTIALS';
  static const String authTokenExpired = 'AUTH_TOKEN_EXPIRED';
  static const String authTokenInvalid = 'AUTH_TOKEN_INVALID';
  static const String authSessionRevoked = 'AUTH_SESSION_REVOKED';
  static const String authPrincipalMismatch = 'AUTH_PRINCIPAL_MISMATCH';
  static const String authOtpInvalid = 'AUTH_OTP_INVALID';
  static const String authOtpExpired = 'AUTH_OTP_EXPIRED';
  static const String authLockedOut = 'AUTH_LOCKED_OUT';
  static const String otpAttemptsExceeded = 'OTP_ATTEMPTS_EXCEEDED';
  static const String accountBlocked = 'ACCOUNT_BLOCKED';
  static const String permissionDenied = 'PERMISSION_DENIED';
  static const String notFound = 'NOT_FOUND';
  static const String methodNotAllowed = 'METHOD_NOT_ALLOWED';
  static const String conflictVersion = 'CONFLICT_VERSION';
  static const String idempotencyConflict = 'IDEMPOTENCY_CONFLICT';
  static const String slotUnavailable = 'SLOT_UNAVAILABLE';
  static const String tokenRangeExhausted = 'TOKEN_RANGE_EXHAUSTED';
  static const String appointmentNotActionable = 'APPOINTMENT_NOT_ACTIONABLE';
  static const String tokenAlreadyCalled = 'TOKEN_ALREADY_CALLED';
  static const String tokenCancelWindowClosed = 'TOKEN_CANCEL_WINDOW_CLOSED';
  static const String paymentAlreadyCaptured = 'PAYMENT_ALREADY_CAPTURED';
  static const String couponInvalid = 'COUPON_INVALID';
  static const String couponExpired = 'COUPON_EXPIRED';
  static const String couponMinOrder = 'COUPON_MIN_ORDER';
  static const String couponUsageCap = 'COUPON_USAGE_CAP';
  static const String underAge = 'UNDER_AGE';
  static const String personIsSelf = 'PERSON_IS_SELF';
  static const String personHasAppointments = 'PERSON_HAS_APPOINTMENTS';
  static const String fileInUse = 'FILE_IN_USE';
  static const String stateConflict = 'STATE_CONFLICT';
  static const String fileTooLarge = 'FILE_TOO_LARGE';
  static const String fileTypeNotAllowed = 'FILE_TYPE_NOT_ALLOWED';
  static const String rateLimited = 'RATE_LIMITED';
  static const String notImplementedYet = 'NOT_IMPLEMENTED_YET';
  static const String providerUnavailable = 'PROVIDER_UNAVAILABLE';

  /// Codes that end the session: clear the tokens and go to sign-in (§1.4).
  static const Set<String> sessionEnding = {
    authSessionRevoked,
    authTokenInvalid,
    authPrincipalMismatch,
    accountBlocked,
  };

  /// Codes that are a wrong credential, not a dead session — shown on the
  /// form, never treated as an expiry (§1.4).
  static const Set<String> credentialRejections = {
    authInvalidCredentials,
    authOtpInvalid,
    authOtpExpired,
    authLockedOut,
    otpAttemptsExceeded,
  };
}

/// Transport-level errors, expressed without naming an HTTP package.
///
/// The Dio adapter in `api_client.dart` translates every `DioException` into
/// one of these; nothing above this file ever sees a package type.
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
///
/// Carries the parsed Medibook error envelope (§1.5): [code], [errors] and
/// [meta]. A plain 500 with no envelope leaves [code] null.
class HttpStatusException extends NetworkException {
  const HttpStatusException({
    required this.statusCode,
    this.code,
    this.serverMessage,
    this.errors = const <String, List<String>>{},
    this.meta = const <String, Object?>{},
    this.requestId,
    this.body,
    super.message,
    super.cause,
  });

  /// Builds the exception from a decoded JSON error body, tolerating any
  /// shape — a non-envelope 500 still becomes a usable exception.
  factory HttpStatusException.fromBody(
    int statusCode,
    Object? decoded, {
    String? rawBody,
    String? message,
    Object? cause,
    int? retryAfterSeconds,
  }) {
    // `Retry-After` (seconds) fills in `meta.retry_after_seconds` when the
    // body does not carry it: the integration server sends only the header
    // (Checklist AUTH-026).
    Map<String, Object?> withRetry(Map<String, Object?> meta) =>
        retryAfterSeconds == null || meta.containsKey('retry_after_seconds')
        ? meta
        : {...meta, 'retry_after_seconds': retryAfterSeconds};
    if (decoded is! Map) {
      return HttpStatusException(
        statusCode: statusCode,
        meta: withRetry(const {}),
        body: rawBody,
        message: message,
        cause: cause,
      );
    }
    final envelope = decoded.cast<String, Object?>();
    final code = envelope['code'];
    final serverMessage = envelope['message'];
    final requestId = envelope['request_id'];
    final meta = envelope['meta'];
    return HttpStatusException(
      statusCode: statusCode,
      code: code is String ? code : null,
      serverMessage: serverMessage is String ? serverMessage : null,
      errors: flattenErrors(envelope['errors']),
      meta: withRetry(meta is Map ? meta.cast<String, Object?>() : const {}),
      requestId: requestId is String ? requestId : null,
      body: rawBody,
      message: message,
      cause: cause,
    );
  }

  final int statusCode;

  /// The stable `code` from the envelope, or null for a non-envelope error.
  final String? code;

  /// The human `message` from the envelope. May change; used only when the
  /// app has nothing better to say.
  final String? serverMessage;

  /// Field → messages, flattened (`address.city` for a nested object).
  final Map<String, List<String>> errors;

  /// Code-specific extras (`attempts_remaining`, `locked_until`, …).
  final Map<String, Object?> meta;

  /// `X-Request-Id`, for support tickets. Never PHI.
  final String? requestId;

  /// Raw body, truncated by the client before it gets here.
  final String? body;

  bool get isClientError => statusCode >= 400 && statusCode < 500;
  bool get isServerError => statusCode >= 500;

  /// 304 — the cached copy is still current (HIVE spec, Scenario 6). Modelled
  /// but excluded from [NetworkExceptions.isRetryable]; the client returns a
  /// 304 as a normal response rather than throwing it.
  bool get isNotModified => statusCode == 304;

  /// 412 — the conditional request's precondition failed; the cache is out of
  /// sync and must be dropped and re-fetched unconditionally.
  bool get isPreconditionFailed => statusCode == 412;

  /// First message per field — the shape a form's `errorText` slot takes.
  Map<String, String> get fieldErrors => {
    for (final entry in errors.entries)
      if (entry.value.isNotEmpty) entry.key: entry.value.first,
  };

  /// Flattens the envelope's `errors` object (§1.5): lists of strings per
  /// field, nested objects joined with a dot.
  static Map<String, List<String>> flattenErrors(
    Object? raw, [
    String prefix = '',
  ]) {
    final result = <String, List<String>>{};
    if (raw is! Map) return result;
    raw.forEach((key, value) {
      final field = prefix.isEmpty ? '$key' : '$prefix.$key';
      if (value is List) {
        result[field] = [for (final v in value) v.toString()];
      } else if (value is Map) {
        result.addAll(flattenErrors(value, field));
      } else if (value != null) {
        result[field] = [value.toString()];
      }
    });
    return result;
  }
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
          userMessage:
              'We could not read the response from our server. '
              'Please try again.',
          debugMessage: error.message,
          cause: error.cause ?? error,
          stackTrace: stackTrace,
        ),
        TlsException() => NetworkFailure(
          userMessage:
              'We could not establish a secure connection. Please '
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
        userMessage:
            'We could not establish a secure connection. Please try '
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
        userMessage:
            'We could not read the response from our server. Please '
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

  /// Status + envelope → [Failure]. The envelope's `code` wins over the
  /// status where the two disagree (§1.4: a wrong password is a 401 that is
  /// *not* a session problem).
  static Failure _fromStatus(HttpStatusException error, StackTrace? stack) {
    final code = error.code;
    final meta = error.meta;
    final debug =
        'HTTP ${error.statusCode}${code == null ? '' : ' $code'}'
        '${error.requestId == null ? '' : ' rid=${error.requestId}'}';
    final serverMessage = error.serverMessage;

    // ---- Code-driven branches first ----
    if (code != null) {
      if (ApiErrorCodes.credentialRejections.contains(code)) {
        return UnauthorizedFailure(
          userMessage: _credentialMessage(code, meta, serverMessage),
          sessionExpired: false,
          apiCode: code,
          meta: meta,
          debugMessage: debug,
          cause: error,
          stackTrace: stack,
        );
      }
      if (ApiErrorCodes.sessionEnding.contains(code) ||
          code == ApiErrorCodes.authTokenExpired) {
        return UnauthorizedFailure(
          userMessage: code == ApiErrorCodes.accountBlocked
              ? 'This account has been blocked. Contact Medibook support.'
              : 'Your session has expired. Please sign in again.',
          sessionExpired: true,
          apiCode: code,
          meta: meta,
          debugMessage: debug,
          cause: error,
          stackTrace: stack,
        );
      }
      if (code == ApiErrorCodes.rateLimited) {
        return RateLimitedFailure(
          userMessage: RateLimitedFailure.messageFor(meta),
          apiCode: code,
          meta: meta,
          debugMessage: debug,
          cause: error,
          stackTrace: stack,
        );
      }
      if (code == ApiErrorCodes.validationError) {
        final fields = error.fieldErrors;
        final nonField = fields['non_field_errors'];
        return ValidationFailure(
          userMessage:
              nonField ??
              (fields.isEmpty
                  ? (serverMessage ?? 'Please check your details.')
                  : 'Please check the highlighted fields and try again.'),
          fieldErrors: fields,
          apiCode: code,
          meta: meta,
          debugMessage: debug,
          cause: error,
          stackTrace: stack,
        );
      }
      if (code == ApiErrorCodes.notFound) {
        return NotFoundFailure(
          apiCode: code,
          meta: meta,
          debugMessage: debug,
          cause: error,
          stackTrace: stack,
        );
      }
      if (code == ApiErrorCodes.permissionDenied) {
        return UnauthorizedFailure(
          userMessage: 'You do not have access to that.',
          sessionExpired: false,
          apiCode: code,
          meta: meta,
          debugMessage: debug,
          cause: error,
          stackTrace: stack,
        );
      }
      if (code == ApiErrorCodes.providerUnavailable ||
          code == ApiErrorCodes.notImplementedYet) {
        return ServerFailure(
          userMessage: code == ApiErrorCodes.notImplementedYet
              ? 'That feature is not available right now.'
              : 'A service we depend on is temporarily unavailable. '
                    'Please try again in a moment.',
          statusCode: error.statusCode,
          apiCode: code,
          meta: meta,
          debugMessage: debug,
          cause: error,
          stackTrace: stack,
        );
      }
    }

    // ---- Status-driven fallbacks ----
    return switch (error.statusCode) {
      400 => ValidationFailure(
        userMessage: serverMessage ?? 'Please check your details.',
        fieldErrors: error.fieldErrors,
        apiCode: code,
        meta: meta,
        debugMessage: debug,
        cause: error,
        stackTrace: stack,
      ),
      401 || 403 => UnauthorizedFailure(
        sessionExpired: error.statusCode == 401,
        apiCode: code,
        meta: meta,
        debugMessage: debug,
        cause: error,
        stackTrace: stack,
      ),
      404 => NotFoundFailure(
        apiCode: code,
        meta: meta,
        debugMessage: debug,
        cause: error,
        stackTrace: stack,
      ),
      408 || 504 => TimeoutFailure(
        debugMessage: debug,
        cause: error,
        stackTrace: stack,
      ),
      409 || 413 || 415 || 422 => ConflictFailure(
        userMessage: _conflictMessage(code, serverMessage, meta),
        statusCode: error.statusCode,
        apiCode: code,
        meta: meta,
        debugMessage: debug,
        cause: error,
        stackTrace: stack,
      ),
      429 => RateLimitedFailure(
        userMessage: RateLimitedFailure.messageFor(meta),
        apiCode: code,
        meta: meta,
        debugMessage: debug,
        cause: error,
        stackTrace: stack,
      ),
      _ => ServerFailure(
        statusCode: error.statusCode,
        apiCode: code,
        meta: meta,
        debugMessage: debug,
        cause: error,
        stackTrace: stack,
      ),
    };
  }

  /// House wording for the credential rejections, using `meta` where it
  /// carries something the patient should know.
  static String _credentialMessage(
    String code,
    Map<String, Object?> meta,
    String? serverMessage,
  ) {
    final remaining = meta['attempts_remaining'];
    final remainingNote = remaining is int && remaining > 0
        ? ' $remaining ${remaining == 1 ? 'attempt' : 'attempts'} left.'
        : '';
    return switch (code) {
      ApiErrorCodes.authInvalidCredentials =>
        'That email or number and password do not match an account.'
            '$remainingNote',
      ApiErrorCodes.authOtpInvalid =>
        'That code is not right. Check it and try again.$remainingNote',
      ApiErrorCodes.authOtpExpired =>
        serverMessage ?? 'That code has expired. Request a new one.',
      ApiErrorCodes.otpAttemptsExceeded =>
        'Too many wrong codes. Request a new code to continue.',
      ApiErrorCodes.authLockedOut =>
        'Too many failed attempts. This account is locked for a while — '
            'try again later.',
      _ => serverMessage ?? 'Sign-in failed. Please try again.',
    };
  }

  /// House wording for the 409-family codes the patient app can receive,
  /// using `meta` where it says something the patient needs (the upload
  /// limit on `FILE_TOO_LARGE`).
  static String _conflictMessage(
    String? code,
    String? serverMessage,
    Map<String, Object?> meta,
  ) => switch (code) {
    ApiErrorCodes.slotUnavailable =>
      'That slot was just taken or is no longer open. Please pick '
          'another time.',
    ApiErrorCodes.tokenRangeExhausted =>
      'No tokens are left for that session. Please pick another '
          'session.',
    ApiErrorCodes.appointmentNotActionable =>
      'This appointment can no longer be changed.',
    ApiErrorCodes.tokenAlreadyCalled =>
      'Your token has already been called, so only the hospital can '
          'cancel this appointment now.',
    ApiErrorCodes.tokenCancelWindowClosed =>
      'The cancellation window for this token has closed.',
    ApiErrorCodes.paymentAlreadyCaptured => 'This booking is already paid for.',
    ApiErrorCodes.couponInvalid => 'That coupon code is not valid.',
    ApiErrorCodes.couponExpired => 'That coupon has expired.',
    ApiErrorCodes.couponMinOrder =>
      'The order is below the minimum for that coupon.',
    ApiErrorCodes.couponUsageCap => 'That coupon has been used up.',
    ApiErrorCodes.underAge =>
      'Account holders must be 18 or older. Add a minor as a family '
          'member instead.',
    ApiErrorCodes.personIsSelf =>
      'You cannot remove yourself from your own account.',
    ApiErrorCodes.personHasAppointments =>
      'This family member has upcoming appointments. Cancel those '
          'first.',
    ApiErrorCodes.conflictVersion =>
      'This was changed elsewhere. Reload and try again.',
    ApiErrorCodes.idempotencyConflict =>
      'That request is already being processed. Please wait a moment.',
    ApiErrorCodes.fileTooLarge => switch (meta['max_bytes']) {
      final int limit when limit > 0 =>
        'That file is too large. The limit is ${formatSizeLimit(limit)}.',
      _ => 'That file is too large.',
    },
    ApiErrorCodes.fileTypeNotAllowed => 'That file type is not allowed.',
    ApiErrorCodes.fileInUse => 'That file is still in use.',
    _ =>
      serverMessage ??
          'That is no longer possible. Please refresh and try again.',
  };

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
  static Duration backoffFor(int attempt) =>
      attempt <= 1 ? Duration.zero : Duration(seconds: 1 << (attempt - 1));
}
