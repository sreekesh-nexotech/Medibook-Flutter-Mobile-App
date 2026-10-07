/// Build environment / flavour.
enum AppEnvironment {
  dev('dev', 'Development'),
  staging('stg', 'Staging'),
  prod('prod', 'Production');

  const AppEnvironment(this.key, this.label);

  /// The value passed to `--dart-define=MEDIBOOK_ENV=…`.
  final String key;

  /// Human label, shown in the debug banner / support screen.
  final String label;

  static AppEnvironment fromKey(String value) {
    for (final env in values) {
      if (env.key == value || env.name == value) return env;
    }
    return AppEnvironment.dev;
  }
}

/// The single source of truth for build-time configuration.
///
/// **Every** `--dart-define` the app reads is declared here and nowhere else —
/// `FeatureFlags`, `ApiClient` and the monitoring wrappers all read [Env]
/// rather than calling `String.fromEnvironment` themselves. One seam means one
/// place to audit before a release, and one place a reviewer can read to learn
/// how this build was configured.
///
/// No `.env` file and no `flutter_dotenv`: an asset-bundled `.env` ships inside
/// the APK where anyone can read it, and it cannot be const-folded. These are
/// compile-time constants instead.
///
/// ## Configuring a build
///
/// ```sh
/// flutter build apk --release \
///   --dart-define=MEDIBOOK_ENV=prod \
///   --dart-define=MEDIBOOK_API_BASE_URL=https://api.medibook.app \
///   --dart-define=MEDIBOOK_DEMO=false \
///   --dart-define=MEDIBOOK_ALLOW_BAD_CERT=false
/// ```
///
/// Defaults are the dev values, so `flutter run` with no defines still works
/// against the integration server. Call `EnvLoader.validate()` during
/// bootstrap to fail fast on a release build that was handed nonsense (see
/// `app/bootstrap/env_loader.dart`).
abstract final class Env {
  Env._();

  // ---- Define names (referenced by the loader's error messages) ----

  static const String envDefine = 'MEDIBOOK_ENV';
  static const String apiBaseUrlDefine = 'MEDIBOOK_API_BASE_URL';
  static const String demoDefine = 'MEDIBOOK_DEMO';
  static const String allowBadCertDefine = 'MEDIBOOK_ALLOW_BAD_CERT';
  static const String bannerAutoRotateDefine = 'MEDIBOOK_BANNER_AUTOROTATE';
  static const String analyticsDefine = 'MEDIBOOK_ANALYTICS';
  static const String crashReportingDefine = 'MEDIBOOK_CRASH_REPORTING';
  static const String sentryDsnDefine = 'MEDIBOOK_SENTRY_DSN';
  static const String verboseLoggingDefine = 'MEDIBOOK_VERBOSE_LOGS';

  // ---- Values ----

  /// The raw `MEDIBOOK_ENV` value, resolved to an [AppEnvironment] by
  /// [current]. (Kept separate because `fromEnvironment` only yields
  /// `String`/`bool`/`int`, never an enum.)
  static const String environmentKey = String.fromEnvironment(
    envDefine,
    defaultValue: 'dev',
  );

  /// The environment this build targets.
  static AppEnvironment get current => AppEnvironment.fromKey(environmentKey);

  /// API origin, no trailing slash and **no** `/api/v1` — `ApiClient` adds
  /// the prefix. The default is the integration server this app is being
  /// wired against.
  static const String apiBaseUrl = String.fromEnvironment(
    apiBaseUrlDefine,
    defaultValue: 'https://62.171.151.149:8443',
  );

  /// Whether demo affordances are reachable (prefilled credentials, the
  /// "Demo code" hint, the reviewer screen-jump menu).
  ///
  /// Off by default now that the app runs against the real API; pass
  /// `--dart-define=MEDIBOOK_DEMO=true` for a review build.
  static const bool demoMode = bool.fromEnvironment(
    demoDefine,
    defaultValue: false,
  );

  /// Accept a self-signed TLS certificate from [apiBaseUrl].
  ///
  /// The integration server presents one. Defaults to `true` so `flutter run`
  /// works; `EnvLoader` refuses a **production** build with this on, and it is
  /// never consulted for a host that presents a valid chain.
  static const bool allowBadCertificate = bool.fromEnvironment(
    allowBadCertDefine,
    defaultValue: true,
  );

  /// Home promo-banner auto-rotation. Independent of [demoMode] because it is
  /// a product decision, not a demo affordance — and it is additionally
  /// suppressed at runtime when the viewer asks for reduced motion (see
  /// `core/utils/motion.dart`).
  static const bool bannerAutoRotate = bool.fromEnvironment(
    bannerAutoRotateDefine,
    defaultValue: true,
  );

  /// Whether analytics events are forwarded to a backend.
  static const bool analyticsEnabled = bool.fromEnvironment(
    analyticsDefine,
    defaultValue: false,
  );

  /// Whether crashes are reported to a backend.
  static const bool crashReportingEnabled = bool.fromEnvironment(
    crashReportingDefine,
    defaultValue: false,
  );

  /// Crash-reporter DSN/key. Empty in every build that does not opt in.
  ///
  /// Coding Standards §9: this is a build-time define supplied by CI from a
  /// secret, not a literal checked into the repo.
  static const String crashReportingDsn = String.fromEnvironment(
    sentryDsnDefine,
    defaultValue: '',
  );

  /// Raises the log floor to `debug` in a profile build, for field debugging.
  static const bool verboseLogging = bool.fromEnvironment(
    verboseLoggingDefine,
    defaultValue: false,
  );

  // ---- Derived ----

  static bool get isDev => current == AppEnvironment.dev;
  static bool get isStaging => current == AppEnvironment.staging;
  static bool get isProd => current == AppEnvironment.prod;

  /// True when the API origin is HTTPS (Coding Standards §9: HTTPS everywhere).
  static bool get isSecureTransport => apiBaseUrl.startsWith('https://');

  /// The WebSocket origin derived from [apiBaseUrl] (`https` → `wss`).
  static String get wsBaseUrl => apiBaseUrl.replaceFirst(RegExp('^http'), 'ws');

  /// A one-line, secret-free summary for the support screen and logs.
  static String get summary =>
      'env=${current.key} api=$apiBaseUrl demo=$demoMode '
      'badCert=$allowBadCertificate analytics=$analyticsEnabled '
      'crash=$crashReportingEnabled';
}
