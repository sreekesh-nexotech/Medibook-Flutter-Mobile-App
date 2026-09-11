import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/logger.dart';
import '../app.dart';
import '../monitoring/analytics.dart';
import '../monitoring/crash_reporting.dart';
import '../theme/colors.dart';
import 'env_loader.dart';
import 'hive_init.dart';

/// Starts the app.
///
/// Order matters and each step is here for a reason:
///
/// 1. **Bind.** `ensureInitialized` before anything touches a platform channel.
/// 2. **Crash reporting.** Installed first, so a failure in any later step is
///    itself reported rather than lost.
/// 3. **Configuration.** [EnvLoader.apply] validates the `--dart-define`
///    values and refuses to continue on a misconfigured *release* build
///    (wrong API host, demo mode left on) — failing at launch, where it is
///    obvious, instead of silently pointing at the wrong backend.
/// 4. **Local storage.** Opened before the first frame so the router can read
///    the stored session and decide between splash, sign-in and home without
///    flashing the wrong screen.
/// 5. **Chrome.** Portrait lock and the status-bar style.
/// 6. **Run.**
///
/// This is also the single place to inject global provider overrides (the real
/// `ApiClient`, the keystore-backed `SecureStore`) when the data layer arrives
/// — see the commented block in [_overrides].
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  CrashReporting.install();
  EnvLoader.apply();

  final cacheFailure = await HiveInit.open();
  if (cacheFailure != null) {
    // Not fatal: the app runs network-only. Logged by HiveInit; recorded here
    // so it is visible in crash reporting as a non-fatal.
    CrashReporting.recordFailure(cacheFailure);
  }

  await _applySystemChrome();

  Analytics.track(AnalyticsEvent.appOpened);
  AppLogger.info('Medibook starting', name: 'bootstrap');

  runApp(ProviderScope(overrides: _overrides(), child: const MedibookApp()));
}

/// Global provider overrides.
///
/// Empty today — every provider's default is a real, honest implementation
/// (`UnimplementedApiClient` refuses loudly, `InMemorySecureStore` keeps
/// nothing on disk). When the data layer lands, this is where the production
/// implementations are injected:
///
/// ```dart
/// List<Override> _overrides() => [
///   apiClientProvider.overrideWithValue(DioApiClient(Env.apiBaseUrl)),
///   secureStoreProvider.overrideWithValue(KeystoreSecureStore()),
/// ];
/// ```
///
/// Keeping it a function rather than a constant means a test can call
/// `bootstrap()`-equivalent wiring with its own overrides.
List<Override> _overrides() => const <Override>[];

/// Portrait lock and status-bar styling.
///
/// **Orientation** (audit §3.4.3 — "rotating the phone breaks the patient
/// app"): every screen in this design is authored against a 390x844 portrait
/// artboard, with fixed-height headers, a bottom-nav shell and hero cards that
/// assume a tall viewport. In landscape they overflow. Locking portrait is the
/// honest fix for *this* design; proper landscape and tablet layouts are a
/// separate scope decision (audit §5.4) that needs the fixed-height controls
/// reworked and a two-pane variant of the shell — not something to fake with a
/// scroll view.
///
/// Both portrait orientations are allowed, so a phone held upside-down (common
/// while charging) still works.
///
/// **Status bar**: the app's top band is either `bgApp` (light) or the brand
/// hero header; in both cases dark icons on a light band is correct, so the
/// brightness is pinned rather than left to the platform default.
Future<void> _applySystemChrome() async {
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      // Transparent: the page's own top band paints behind the status bar.
      statusBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.dark, // Android
      statusBarBrightness: Brightness.light, // iOS
      // Matches the bottom-nav surface so the gesture bar blends into it.
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Color(0x00000000),
    ),
  );
}
