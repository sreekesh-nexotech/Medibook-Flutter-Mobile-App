import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/error/failure.dart';
import '../../core/utils/logger.dart';
import '../config/env.dart';

/// Where crashes and non-fatal errors go. Crashlytics / Sentry becomes one
/// implementation; nothing above it changes.
abstract interface class CrashSink {
  /// Report a caught error. [fatal] marks a crash rather than a handled error.
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal,
    Map<String, Object?> context,
  });

  /// A breadcrumb attached to the next report (route change, tap, API call).
  void log(String message);

  /// Associate reports with a user. **Id only** — never a name, phone or email.
  void setUserIdentifier(String? userId);

  /// A sticky key/value shown on every report (env, build, route).
  void setCustomKey(String key, Object? value);
}

/// Crash reporting hooks.
///
/// Wired from `app/bootstrap/app_bootstrap.dart`, which installs [install]
/// before `runApp` so a failure during the first frame is still captured:
///
/// ```dart
/// CrashReporting.install();
/// runApp(const ProviderScope(child: MedibookApp()));
/// ```
///
/// Two deliberate properties:
/// * **Off by default.** Nothing leaves the device unless
///   `--dart-define=MEDIBOOK_CRASH_REPORTING=true`. Until then reports go to
///   [AppLogger] (silent in release), so the seam is exercised without a
///   vendor.
/// * **No PHI.** Only [Failure.code], [Failure.debugMessage] and non-PHI
///   context are ever attached. `userMessage` is safe by construction, but
///   patient data (names, numbers, document contents) must never be put into
///   [recordFailure]'s context map.
abstract final class CrashReporting {
  CrashReporting._();

  /// Swap during bootstrap to install a real reporter.
  static CrashSink sink = const LoggingCrashSink();

  static bool get enabled => Env.crashReportingEnabled;

  static bool _installed = false;

  /// Route Flutter's and the isolate's uncaught errors into [sink].
  ///
  /// Idempotent. Preserves the previous `FlutterError.onError`, so the
  /// framework's own red-screen/console reporting still happens in debug.
  static void install() {
    if (_installed) return;
    _installed = true;

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      recordError(
        details.exception,
        details.stack,
        reason: details.context?.toDescription(),
        fatal: false,
      );
      previousOnError?.call(details);
    };

    // Errors from outside the Flutter callback stack (isolate-level).
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      recordError(error, stackTrace, fatal: true);
      return true;
    };

    setCustomKey('environment', Env.current.key);
    setCustomKey('demo_mode', Env.demoMode);
    AppLogger.info(
      'Crash reporting installed (forwarding=${enabled ? 'on' : 'off'})',
      name: 'crash',
    );
  }

  /// Report an arbitrary error.
  static void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    if (!enabled) {
      AppLogger.error(
        'crash (not forwarded)${reason == null ? '' : ' [$reason]'}',
        name: 'crash',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
    sink.recordError(
      error,
      stackTrace,
      reason: reason,
      fatal: fatal,
      context: context,
    );
  }

  /// Report a [Failure] as a non-fatal, tagged with its [Failure.code] so the
  /// dashboard groups by *kind of problem* rather than by stack.
  ///
  /// Pass only non-PHI [context] (ids, status codes, route names).
  static void recordFailure(
    Failure failure, {
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    recordError(
      failure,
      failure.stackTrace,
      reason: 'failure:${failure.code}',
      context: {
        'failure_code': failure.code,
        'retryable': failure.isRetryable,
        if (failure.debugMessage != null) 'detail': failure.debugMessage,
        ...context,
      },
    );
  }

  /// Add a breadcrumb. Cheap; call it on route changes and before risky work.
  static void breadcrumb(String message) {
    if (!enabled) {
      AppLogger.debug('breadcrumb $message', name: 'crash');
      return;
    }
    sink.log(message);
  }

  /// Identify the signed-in user by id only.
  static void identify(String? userId) {
    if (!enabled) return;
    sink.setUserIdentifier(userId);
  }

  /// Clear identity (CM-53: logout clears session).
  static void reset() {
    if (!enabled) return;
    sink.setUserIdentifier(null);
  }

  static void setCustomKey(String key, Object? value) {
    if (!enabled) return;
    sink.setCustomKey(key, value);
  }

  /// Run [body] inside an error zone that reports anything it throws.
  ///
  /// Use for fire-and-forget async work (a cache write, an analytics flush)
  /// whose failure must be visible but must not surface to the user.
  static Future<T?> guard<T>(
    Future<T> Function() body, {
    String? reason,
  }) async {
    try {
      return await body();
    } catch (error, stackTrace) {
      recordError(error, stackTrace, reason: reason);
      return null;
    }
  }
}

/// The default sink: writes through [AppLogger] (silent in release). Exercises
/// the seam with no vendor SDK and no network.
class LoggingCrashSink implements CrashSink {
  const LoggingCrashSink();

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Map<String, Object?> context = const <String, Object?>{},
  }) => AppLogger.error(
    '${fatal ? 'FATAL' : 'non-fatal'}'
    '${reason == null ? '' : ' [$reason]'} $context',
    name: 'crash',
    error: error,
    stackTrace: stackTrace,
  );

  @override
  void log(String message) => AppLogger.debug(message, name: 'crash');

  @override
  void setUserIdentifier(String? userId) =>
      AppLogger.debug('crash userId=${userId ?? '<cleared>'}', name: 'crash');

  @override
  void setCustomKey(String key, Object? value) =>
      AppLogger.debug('crash key $key=$value', name: 'crash');
}
