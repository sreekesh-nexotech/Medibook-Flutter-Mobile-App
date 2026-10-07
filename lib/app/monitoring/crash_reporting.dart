import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../core/error/failure.dart';
import '../../core/utils/logger.dart';
import '../config/env.dart';

/// Where crashes and non-fatal errors go. Sentry is one implementation
/// ([SentryCrashSink]); nothing above it changes.
abstract interface class CrashSink {
  /// True when the sink's SDK hooks `FlutterError.onError` and
  /// `PlatformDispatcher.onError` itself. [CrashReporting.install] then leaves
  /// uncaught errors to it, so each one is reported once rather than twice.
  bool get capturesUncaughtErrors;

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
/// await CrashReporting.install();
/// runApp(const ProviderScope(child: MedibookApp()));
/// ```
///
/// Two deliberate properties:
/// * **Off by default.** Nothing leaves the device unless
///   `--dart-define=MEDIBOOK_CRASH_REPORTING=true` **and** a
///   `MEDIBOOK_SENTRY_DSN` is supplied. Until then reports go to [AppLogger]
///   (silent in release), so the seam is exercised without a vendor.
/// * **No PHI.** Only [Failure.code], [Failure.debugMessage] and non-PHI
///   context are ever attached. `userMessage` is safe by construction, but
///   patient data (names, numbers, document contents) must never be put into
///   [recordFailure]'s context map.
abstract final class CrashReporting {
  CrashReporting._();

  /// Swapped for [SentryCrashSink] by [install] when this build opted in.
  static CrashSink sink = const LoggingCrashSink();

  static bool get enabled => Env.crashReportingEnabled;

  static bool _installed = false;

  /// Start the reporter this build opted into, and route Flutter's and the
  /// isolate's uncaught errors into [sink].
  ///
  /// Idempotent. Preserves the previous `FlutterError.onError`, so the
  /// framework's own red-screen/console reporting still happens in debug.
  static Future<void> install() async {
    if (_installed) return;
    _installed = true;

    if (enabled && Env.crashReportingDsn.isNotEmpty) {
      sink = await SentryCrashSink.start() ?? sink;
    }

    if (!sink.capturesUncaughtErrors) {
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
    }

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
  bool get capturesUncaughtErrors => false;

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

/// Forwards to Sentry. Installed by [CrashReporting.install] when the build
/// passes `MEDIBOOK_CRASH_REPORTING=true` and a `MEDIBOOK_SENTRY_DSN`.
///
/// The SDK's own Flutter and native hooks capture uncaught errors and native
/// crashes; this sink carries the app's *handled* reports, breadcrumbs and
/// the user id.
class SentryCrashSink implements CrashSink {
  const SentryCrashSink();

  /// Starts the SDK and returns the sink, or null when it could not start —
  /// a monitoring failure must never stop the app from launching.
  static Future<CrashSink?> start() async {
    try {
      await SentryFlutter.init((options) {
        options
          ..dsn = Env.crashReportingDsn
          ..environment = Env.current.key
          // No PHI: this is a patient app, so nothing that could carry a
          // name, a number or a screen's contents is attached. Stated rather
          // than left to the SDK's defaults — and Session Replay stays off.
          ..sendDefaultPii = false
          ..attachScreenshot = false
          ..enablePrintBreadcrumbs = false;
      });
      return const SentryCrashSink();
    } catch (error, stackTrace) {
      AppLogger.error(
        'Sentry failed to start — crashes are logged locally only',
        name: 'crash',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  bool get capturesUncaughtErrors => true;

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    unawaited(
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) async {
          if (fatal) scope.level = SentryLevel.fatal;
          if (reason != null) await scope.setTag('reason', reason);
          if (context.isNotEmpty) await scope.setContexts('medibook', context);
        },
      ),
    );
  }

  @override
  void log(String message) =>
      unawaited(Sentry.addBreadcrumb(Breadcrumb(message: message)));

  @override
  void setUserIdentifier(String? userId) => Sentry.configureScope(
    (scope) => scope.setUser(userId == null ? null : SentryUser(id: userId)),
  );

  @override
  void setCustomKey(String key, Object? value) =>
      Sentry.configureScope((scope) => scope.setTag(key, '$value'));
}
