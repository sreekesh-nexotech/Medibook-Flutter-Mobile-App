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
/// ```dart
/// switch (failure) {
///   case NetworkFailure():    showOfflineBanner();
///   case UnauthorizedFailure(): ref.read(authProvider.notifier).logout();
///   case _:                   AppErrorView(failure: failure, onRetry: reload);
/// }
/// ```
sealed class Failure implements Exception {
  const Failure({
    required this.userMessage,
    this.debugMessage,
    this.cause,
    this.stackTrace,
  });

  /// What the patient reads. Plain language, no codes, no jargon, and it says
  /// what they can do next.
  final String userMessage;

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
    UnknownFailure() => 'unknown',
  };

  @override
  String toString() =>
      '$runtimeType($code): ${debugMessage ?? userMessage}'
      '${cause == null ? '' : ' <- $cause'}';
}

/// No usable connection: request never left the device, or DNS/socket failed.
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.userMessage = 'You appear to be offline. Check your connection and '
        'try again.',
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });
}

/// The request left but nothing came back inside the budget
/// (`AppConstants.apiTimeout`).
class TimeoutFailure extends Failure {
  const TimeoutFailure({
    super.userMessage = 'This is taking longer than usual. Please try again.',
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });
}

/// The server answered with 5xx, or with a body we could not make sense of.
class ServerFailure extends Failure {
  const ServerFailure({
    super.userMessage = "Something went wrong on our side. We're on it — "
        'please try again in a moment.',
    this.statusCode,
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
    super.userMessage = 'We could not read your saved data. Pull to refresh to '
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
    super.userMessage = "We couldn't find what you were looking for. It may "
        'have been moved or removed.',
    this.resource,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });

  /// What was missing ('appointment', 'doctor') — used to word the error view.
  final String? resource;
}

/// 401/403, an expired session, or a refresh that failed.
///
/// Coding Standards §6.2: on 401 the client refreshes once and retries; only
/// when *that* fails does this reach the UI, and the UI's response is to log
/// the user out.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({
    super.userMessage = 'Your session has expired. Please sign in again.',
    this.sessionExpired = true,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });

  /// True when the credential was once valid (expiry) rather than wrong.
  final bool sessionExpired;
}

/// 422/400 with field-level detail, or a client-side rule that failed.
class ValidationFailure extends Failure {
  const ValidationFailure({
    super.userMessage = 'Please check the highlighted fields and try again.',
    this.fieldErrors = const <String, String>{},
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });

  /// Field name → message, so a form can paint its own inline errors.
  final Map<String, String> fieldErrors;

  /// The message for [field], if the server named it.
  String? forField(String field) => fieldErrors[field];
}

/// Anything unmapped. If this reaches a user, the mapping is incomplete —
/// [debugMessage] should carry enough to fix that.
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.userMessage = 'Something went wrong. Please try again.',
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
