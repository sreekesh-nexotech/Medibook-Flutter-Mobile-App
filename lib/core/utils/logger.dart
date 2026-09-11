import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Severity of a log record. Ordered, so a level can be compared against
/// [AppLogger.minimumLevel].
enum LogLevel {
  debug('DEBUG'),
  info('INFO'),
  warning('WARN'),
  error('ERROR');

  const LogLevel(this.label);

  /// Four-character tag used in the printed line.
  final String label;

  bool operator >=(LogLevel other) => index >= other.index;
}

/// A log sink. The default implementation writes to `dart:developer`, but the
/// real backends (Crashlytics breadcrumbs, a file sink, a test spy) plug in
/// here without touching call sites — see [AppLogger.sink].
abstract interface class LogSink {
  void write(
    LogLevel level,
    String message, {
    String? name,
    Object? error,
    StackTrace? stackTrace,
  });
}

/// Unified logging.
///
/// Audit / coding-standards §5: one logging seam for the whole app, and
/// **nothing is written in release builds**. `kReleaseMode` short-circuits
/// every call, so no PHI, token or endpoint leaks to `adb logcat` or the device
/// console in a shipped build; crash reporting (which is release-safe by
/// design) goes through `app/monitoring/crash_reporting.dart` instead.
///
/// ```dart
/// AppLogger.info('Booking confirmed', name: 'booking');
/// AppLogger.error('Slot hold expired', error: e, stackTrace: s);
/// ```
abstract final class AppLogger {
  AppLogger._();

  /// Where records go. Swap once, during bootstrap, before anything logs.
  static LogSink sink = const DeveloperLogSink();

  /// Records below this level are dropped. Debug builds keep everything;
  /// profile builds keep info and up.
  static LogLevel minimumLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  /// True when logging can produce output at all.
  ///
  /// Release builds are silent by policy. This is the single guard — do not
  /// call `print`/`debugPrint` anywhere else in the app.
  static bool get enabled => !kReleaseMode;

  static void debug(String message, {String? name}) =>
      log(LogLevel.debug, message, name: name);

  static void info(String message, {String? name}) =>
      log(LogLevel.info, message, name: name);

  static void warning(String message, {String? name, Object? error}) =>
      log(LogLevel.warning, message, name: name, error: error);

  static void error(
    String message, {
    String? name,
    Object? error,
    StackTrace? stackTrace,
  }) => log(
    LogLevel.error,
    message,
    name: name,
    error: error,
    stackTrace: stackTrace,
  );

  /// The single funnel every helper above routes through.
  static void log(
    LogLevel level,
    String message, {
    String? name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled) return;
    if (!(level >= minimumLevel)) return;
    sink.write(
      level,
      message,
      name: name,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// The default sink: `dart:developer`'s `log`, which the IDE and DevTools
/// render with their own severity styling and which is a no-op in AOT release
/// builds even if it were reached.
class DeveloperLogSink implements LogSink {
  const DeveloperLogSink();

  @override
  void write(
    LogLevel level,
    String message, {
    String? name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      '[${level.label}] $message',
      name: name == null ? 'medibook' : 'medibook.$name',
      error: error,
      stackTrace: stackTrace,
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
    );
  }
}

/// A sink that keeps records in memory — for widget tests and for the
/// "send diagnostics" affordance the support screen will offer.
class MemoryLogSink implements LogSink {
  MemoryLogSink({this.capacity = 200});

  /// Ring-buffer size; the oldest record is dropped once it is exceeded.
  final int capacity;

  final List<String> _records = <String>[];

  /// The retained records, oldest first.
  List<String> get records => List.unmodifiable(_records);

  void clear() => _records.clear();

  @override
  void write(
    LogLevel level,
    String message, {
    String? name,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final suffix = error == null ? '' : ' | $error';
    _records.add('${level.label} ${name ?? '-'}: $message$suffix');
    if (_records.length > capacity) _records.removeAt(0);
  }
}
