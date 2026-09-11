import '../../core/utils/logger.dart';
import '../config/env.dart';
import '../config/feature_flags.dart';

/// A configuration problem found before the app painted a frame.
class EnvConfigError implements Exception {
  const EnvConfigError(this.message);

  final String message;

  @override
  String toString() => 'EnvConfigError: $message';
}

/// The result of [EnvLoader.validate] — what is wrong, and how badly.
class EnvValidation {
  const EnvValidation({required this.errors, required this.warnings});

  /// Problems that make the build unshippable.
  final List<String> errors;

  /// Problems worth a loud log line but not a refusal.
  final List<String> warnings;

  bool get isValid => errors.isEmpty;

  /// A single friendly paragraph, for the log line or the thrown error.
  String describe() {
    final buffer = StringBuffer('Medibook configuration: ${Env.summary}');
    for (final error in errors) {
      buffer.write('\n  ERROR   $error');
    }
    for (final warning in warnings) {
      buffer.write('\n  WARNING $warning');
    }
    return buffer.toString();
  }
}

/// Validates build-time configuration during bootstrap.
///
/// There is no `.env` file to load — `Env` holds compile-time
/// `--dart-define` constants, which cannot be tampered with at runtime and do
/// not ship a readable secrets file inside the APK. So this "loader" does the
/// half that still matters: **it checks that the values a build was handed make
/// sense, and says so loudly if they do not**, per the structure doc's brief
/// for this file ("validates required vars and logs a friendly error if
/// missing").
///
/// Call [apply] once, from `bootstrap()`, before `runApp`.
abstract final class EnvLoader {
  EnvLoader._();

  /// Validate the current configuration without throwing.
  static EnvValidation validate() {
    final errors = <String>[];
    final warnings = <String>[];

    // ---- API base URL ----
    if (Env.apiBaseUrl.isEmpty) {
      errors.add(
        '${Env.apiBaseUrlDefine} is empty. Pass '
        '--dart-define=${Env.apiBaseUrlDefine}=https://api.example.com',
      );
    } else {
      final uri = Uri.tryParse(Env.apiBaseUrl);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        errors.add(
          '${Env.apiBaseUrlDefine} ("${Env.apiBaseUrl}") is not an absolute '
          'URL with a host.',
        );
      } else if (Env.apiBaseUrl.endsWith('/')) {
        warnings.add(
          '${Env.apiBaseUrlDefine} ends with "/" — paths from Endpoints '
          'already start with one, so requests will contain "//".',
        );
      }
      if (!Env.isSecureTransport) {
        final message =
            '${Env.apiBaseUrlDefine} is not HTTPS. Coding Standards §9 '
            'requires HTTPS everywhere.';
        // Plaintext against a local dev server is normal; shipping it is not.
        if (Env.isProd) {
          errors.add(message);
        } else {
          warnings.add(message);
        }
      }
    }

    // ---- Environment key ----
    final knownKeys = AppEnvironment.values.map((e) => e.key).toList();
    if (!knownKeys.contains(Env.environmentKey) &&
        !AppEnvironment.values.any((e) => e.name == Env.environmentKey)) {
      warnings.add(
        '${Env.envDefine} ("${Env.environmentKey}") is not one of '
        '${knownKeys.join('/')} — falling back to '
        '${AppEnvironment.dev.key}.',
      );
    }

    // ---- Demo mode (audit §3.9.3) ----
    if (Env.isProd && FeatureFlags.demoMode) {
      errors.add(
        'Demo mode is ON in a production build. Pass '
        '--dart-define=${Env.demoDefine}=false. Demo mode prefills real-looking '
        'credentials and shows the OTP hint.',
      );
    }

    // ---- Monitoring ----
    if (Env.crashReportingEnabled && Env.crashReportingDsn.isEmpty) {
      warnings.add(
        '${Env.crashReportingDefine} is on but ${Env.sentryDsnDefine} is empty '
        '— crashes will be logged locally only.',
      );
    }
    if (Env.isProd && !Env.crashReportingEnabled) {
      warnings.add(
        'Crash reporting is off in a production build — field crashes will be '
        'invisible.',
      );
    }

    return EnvValidation(errors: errors, warnings: warnings);
  }

  /// Validate, log the outcome, and apply configuration-derived settings.
  ///
  /// Throws [EnvConfigError] when the configuration is invalid **and** this is
  /// a production build — a misconfigured release should fail at launch, where
  /// it is obvious, rather than silently point at the wrong API. Dev and
  /// staging builds log and continue so the app stays runnable while the
  /// backend is still moving.
  static void apply() {
    final result = validate();

    if (Env.verboseLogging) AppLogger.minimumLevel = LogLevel.debug;

    if (result.isValid && result.warnings.isEmpty) {
      AppLogger.info('Configuration OK — ${Env.summary}', name: 'env');
      return;
    }

    if (!result.isValid) {
      AppLogger.error(result.describe(), name: 'env');
      if (Env.isProd) throw EnvConfigError(result.describe());
      return;
    }

    AppLogger.warning(result.describe(), name: 'env');
  }
}
