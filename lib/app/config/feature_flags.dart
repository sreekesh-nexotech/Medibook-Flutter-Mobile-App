import 'env.dart';

/// Central switches for staged rollouts / demo behaviour.
///
/// Every flag here is a **thin read of [Env]**, which is the one place
/// `--dart-define` values are declared. Nothing in this file calls
/// `bool.fromEnvironment` itself: one seam means a reviewer can read `env.dart`
/// alone to know how a build was configured, and a release checklist has one
/// file to audit.
///
/// ## Turning demo mode off for a release
///
/// ```sh
/// flutter build apk --release --dart-define=MEDIBOOK_DEMO=false
/// # or, with the rest of the production config:
/// flutter build apk --release \
///   --dart-define=MEDIBOOK_ENV=prod \
///   --dart-define=MEDIBOOK_API_BASE_URL=https://api.medibook.app \
///   --dart-define=MEDIBOOK_DEMO=false
/// ```
///
/// The default is `true` because this build *is* the client-review prototype
/// (audit §3.9.3) — but it is now a build-time decision rather than a source
/// edit, so shipping the demo path is an omission a CI flag can catch instead
/// of something discovered after release. `EnvLoader.validate()` refuses a
/// release build that still has [demoMode] on.
abstract final class FeatureFlags {
  FeatureFlags._();

  /// Enables demo affordances: prefilled credentials
  /// (`DemoCredentials.email` / `DemoCredentials.password`), the
  /// "Demo code: 1234" hint and the reviewer screen-jump menu.
  ///
  /// The demo constants themselves stay in `AppConstants` — gating them is the
  /// fix, and the prototype the client is reviewing still needs them.
  static const bool demoMode = Env.demoMode;

  /// Home promo banner auto-rotation (every `AppConstants.bannerInterval`).
  ///
  /// Also gate on `reduceMotion(context)` from `core/utils/motion.dart` at the
  /// call site — this flag is the product decision, that check is the
  /// accessibility one, and both must pass before a timer starts (audit
  /// §3.3.8).
  static const bool bannerAutoRotate = Env.bannerAutoRotate;

  /// Whether analytics events leave the device.
  static const bool analyticsEnabled = Env.analyticsEnabled;

  /// Whether crashes are reported to a backend.
  static const bool crashReportingEnabled = Env.crashReportingEnabled;
}

/// The client-review build's sign-in (CL CODE-010). Every reference sits
/// behind the compile-time constant `FeatureFlags.demoMode`, which is false
/// unless the build passes `--dart-define=MEDIBOOK_DEMO=true`, so a normal
/// release build compiles these strings out entirely (checked by searching
/// the release `libapp.so`); `EnvLoader` also refuses a production build
/// with demo mode on. They are not real accounts on any server.
abstract final class DemoCredentials {
  DemoCredentials._();

  static const String otpCode = '1234';
  static const String email = 'alexandra.johnson@example.com';
  static const String password = 'medibook123';
}
