/// The app-wide error model (Coding Standards §5.2).
///
/// Every layer below the UI reports problems as a [Failure] — never as a raw
/// `Exception`, a `DioException`, a `HiveError` or a string. The UI then only
/// ever needs one thing from an error: [Failure.userMessage], which is written
/// to be shown to a patient, in a sentence, with a next step.
///
/// Sealed, so `switch` over a failure is exhaustive and adding a new kind is a
/// compile error at every site that cares.
///
/// ## The backend's `code` and `meta`
///
/// Every non-2xx response from the Medibook API carries a stable
/// machine-readable `code` (`FLUTTER_API_INTEGRATION.md` §1.5) and a
/// code-specific `meta` map (`attempts_remaining`, `locked_until`,
/// `retry_after_seconds`, `current` …). Both are preserved on the failure as
/// [apiCode] and [meta], so a controller can branch on the contract
/// (`failure.apiCode == ApiErrorCodes.slotUnavailable`) instead of on a
/// sentence that may change.
///
/// ```dart
/// switch (failure) {
///   case NetworkFailure():    showOfflineBanner();
///   case UnauthorizedFailure(sessionExpired: true):
///     ref.read(authProvider.notifier).logout();
///   case _:                   AppErrorView(failure: failure, onRetry: reload);
/// }
/// ```
sealed class Failure implements Exception {
  const Failure({
    required this.userMessage,
    this.apiCode,
    this.meta = const <String, Object?>{},
    this.debugMessage,
    this.cause,
    this.stackTrace,
  });

  /// What the patient reads. Plain language, no codes, no jargon, and it says
  /// what they can do next.
  final String userMessage;

  /// The backend's stable error `code`, when the failure came from the API
  /// (`VALIDATION_ERROR`, `SLOT_UNAVAILABLE`, …). Null for local failures.
  final String? apiCode;

  /// The backend's `meta` object for [apiCode], verbatim. Empty when none.
  final Map<String, Object?> meta;

  /// Developer-facing detail — endpoint, status line, validation path. Logged,
  /// never rendered. Must not contain PHI or tokens.
  final String? debugMessage;

  /// The original error this failure was mapped from, if any.
  final Object? cause;

  final StackTrace? stackTrace;

  /// Whether retrying the same operation could plausibly succeed. Drives
  /// whether an error view shows its Retry button.
  bool get isRetryable => switch (this) {
    NetworkFailure() => true,
    TimeoutFailure() => true,
    ServerFailure() => true,
    CacheFailure() => true,
    NotFoundFailure() => false,
    UnauthorizedFailure() => false,
    ValidationFailure() => false,
    ConflictFailure() => false,
    RateLimitedFailure() => true,
    UnknownFailure() => true,
  };

  /// A short, stable tag for logs and analytics (never shown to the user).
  String get code => switch (this) {
    NetworkFailure() => 'network',
    TimeoutFailure() => 'timeout',
    ServerFailure() => 'server',
    CacheFailure() => 'cache',
    NotFoundFailure() => 'not_found',
    UnauthorizedFailure() => 'unauthorized',
    ValidationFailure() => 'validation',
    ConflictFailure() => 'conflict',
    RateLimitedFailure() => 'rate_limited',
    UnknownFailure() => 'unknown',
  };

  /// True when the backend named this [apiCode].
  bool hasApiCode(String value) => apiCode == value;

  /// A typed read of a `meta` value, or null when absent / the wrong type.
  T? metaValue<T>(String key) {
    final value = meta[key];
    return value is T ? value : null;
  }

  @override
  String toString() =>
      '$runtimeType($code${apiCode == null ? '' : '/$apiCode'}): '
      '${debugMessage ?? userMessage}'
      '${cause == null ? '' : ' <- $cause'}';
}

/// No usable connection: request never left the device, or DNS/socket failed.
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.userMessage =
        'You appear to be offline. Check your connection and '
        'try again.',
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });

  /// The phone has a network, but requests are not getting through (a slow
  /// or captive network, the server down): "offline" would be untrue
  /// (Screen Coverage pass, 6 Oct 2026).
  const NetworkFailure.unreachable({super.debugMessage, super.cause})
    : super(userMessage: unreachableMessage);

  static const String unreachableMessage =
      "Can't reach Medibook right now. Check your connection and try again.";

  /// True for [NetworkFailure.unreachable].
  bool get isUnreachable => userMessage == unreachableMessage;
}

/// The request left but nothing came back inside the budget
/// (`CacheConfig.apiTimeout`).
class TimeoutFailure extends Failure {
  const TimeoutFailure({
    super.userMessage = 'This is taking longer than usual. Please try again.',
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });
}

/// The server answered with 5xx / 501 / 503, or with a body we could not make
/// sense of.
class ServerFailure extends Failure {
  const ServerFailure({
    super.userMessage =
        "Something went wrong on our side. We're on it — "
        'please try again in a moment.',
    this.statusCode,
    super.apiCode,
    super.meta,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });

  /// HTTP status, when there was one.
  final int? statusCode;
}

/// Local persistence failed: Hive read/write error, corrupt box, decode error.
///
/// Per `docs-flutter/HIVE implementation.md` (Scenario 9) a cache failure is
/// almost never fatal — the caller should fall back to the network — so this
/// failure usually gets logged rather than shown.
class CacheFailure extends Failure {
  const CacheFailure({
    super.userMessage =
        'We could not read your saved data. Pull to refresh to '
        'load it again.',
    this.cacheKey,
    this.isCorruption = false,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });

  /// The cache key involved, for targeted eviction.
  final String? cacheKey;

  /// True when the entry was unreadable rather than merely absent — the caller
  /// should delete it (Scenario 9: corruption recovery).
  final bool isCorruption;
}

/// 404, or a valid response that contained none of the requested resource.
class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.userMessage =
        "We couldn't find what you were looking for. It may "
        'have been moved or removed.',
    this.resource,
    super.apiCode,
    super.meta,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });

  /// What was missing ('appointment', 'doctor') — used to word the error view.
  final String? resource;
}

/// 401/403 — a wrong credential, an expired or revoked session, a blocked
/// account, or a refresh that failed.
///
/// `FLUTTER_API_INTEGRATION.md` §1.4: the HTTP client branches on `code`, not
/// on the status. [sessionExpired] is true only for the session-ending codes
/// (`AUTH_TOKEN_EXPIRED` after a failed refresh, `AUTH_SESSION_REVOKED`,
/// `AUTH_TOKEN_INVALID`, `AUTH_PRINCIPAL_MISMATCH`, `ACCOUNT_BLOCKED`); a wrong
/// password or OTP is a form error and leaves it false.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({
    super.userMessage = 'Your session has expired. Please sign in again.',
    this.sessionExpired = true,
    super.apiCode,
    super.meta,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });

  /// True when the credential was once valid (expiry / revocation) rather
  /// than wrong.
  final bool sessionExpired;

  /// `meta.attempts_remaining`, when the backend sent it.
  int? get attemptsRemaining => metaValue<int>('attempts_remaining');

  /// `meta.locked_until` parsed, when the backend sent it (`AUTH_LOCKED_OUT`).
  DateTime? get lockedUntil {
    final raw = metaValue<String>('locked_until');
    return raw == null ? null : DateTime.tryParse(raw);
  }
}

/// 400 `VALIDATION_ERROR` with field-level detail, or a client-side rule that
/// failed.
class ValidationFailure extends Failure {
  const ValidationFailure({
    super.userMessage = 'Please check the highlighted fields and try again.',
    this.fieldErrors = const <String, String>{},
    super.apiCode,
    super.meta,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });

  /// Field name → first message, so a form can paint its own inline errors.
  ///
  /// Nested envelopes are flattened with a dot (`address.city`), and
  /// `non_field_errors` is kept under that key.
  final Map<String, String> fieldErrors;

  /// The message for [field], if the server named it.
  String? forField(String field) => fieldErrors[field];
}

/// 409 — the request was well-formed but the resource is not in a state that
/// allows it (`SLOT_UNAVAILABLE`, `APPOINTMENT_NOT_ACTIONABLE`,
/// `CONFLICT_VERSION`, `IDEMPOTENCY_CONFLICT`, `UNDER_AGE`, `STATE_CONFLICT`,
/// the coupon codes, …). Also 413 / 415 / 422 file and OTP rejections, which
/// are "this input cannot be accepted" rather than "this field is malformed".
///
/// Never retried blindly: the caller reloads the resource and lets the user
/// decide.
class ConflictFailure extends Failure {
  const ConflictFailure({
    super.userMessage =
        'That is no longer possible. Please refresh and try again.',
    this.statusCode = 409,
    super.apiCode,
    super.meta,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });

  final int statusCode;

  /// `meta.current` for `CONFLICT_VERSION` — the row's live version.
  int? get currentVersion => metaValue<int>('current');
}

/// 429 `RATE_LIMITED`. [retryAfter] comes from `meta.retry_after_seconds`.
class RateLimitedFailure extends Failure {
  const RateLimitedFailure({
    super.userMessage =
        'Too many attempts. Please wait a moment and try again.',
    super.apiCode,
    super.meta,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });

  Duration? get retryAfter {
    final seconds = metaValue<int>('retry_after_seconds');
    return seconds == null ? null : Duration(seconds: seconds);
  }

  /// The message for a 429, naming the wait when the server gave one.
  static String messageFor(Map<String, Object?> meta) {
    final seconds = meta['retry_after_seconds'];
    if (seconds is! int || seconds <= 0) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    final minutes = (seconds / 60).ceil();
    final wait = seconds < 60
        ? '$seconds ${seconds == 1 ? 'second' : 'seconds'}'
        : 'about $minutes ${minutes == 1 ? 'minute' : 'minutes'}';
    return 'Too many attempts. Please wait $wait and try again.';
  }
}

/// Anything unmapped. If this reaches a user, the mapping is incomplete —
/// [debugMessage] should carry enough to fix that.
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.userMessage = 'Something went wrong. Please try again.',
    super.apiCode,
    super.meta,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });
}

/// Convenience constructors for the places that only have a `catch (e, s)`.
extension FailureFromError on Object {
  /// Wrap an arbitrary caught error as a [Failure] without losing it.
  ///
  /// Prefer a specific mapper (`NetworkExceptions.toFailure`) when the error's
  /// shape is known; this is the last-resort branch of a `catch`.
  Failure asFailure([StackTrace? stackTrace]) {
    final self = this;
    if (self is Failure) return self;
    return UnknownFailure(
      debugMessage: self.toString(),
      cause: self,
      stackTrace: stackTrace,
    );
  }
}
