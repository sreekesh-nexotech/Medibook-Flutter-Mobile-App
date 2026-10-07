import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart' show Hive;

import '../di/dependencies.dart';
import '../../core/network/connectivity/connectivity_monitor.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../../core/network/network_exceptions.dart';
import '../../core/network/user_agent.dart';
import '../../core/storage/cache/cached_fetcher.dart';
import '../../core/storage/hive/boxes.dart';
import '../../core/storage/hive_local_store.dart';
import '../../core/storage/secure_store.dart';
import '../../core/utils/logger.dart';
import '../../features/auth/application/providers/auth_provider.dart';
import '../app.dart';
import '../config/env.dart';
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
///    itself reported rather than lost. Starts Sentry when the build opted in.
/// 3. **Configuration.** [EnvLoader.apply] validates the `--dart-define`
///    values and refuses to continue on a misconfigured *release* build
///    (wrong API host, demo mode or bad-cert left on).
/// 4. **Local storage.** Hive opened (adapters registered) before the first
///    frame so the router can read the stored session and decide between
///    splash, sign-in and home without flashing the wrong screen.
/// 5. **Connectivity.** The monitor starts before any repository can ask it.
/// 6. **Chrome.** Portrait lock and the status-bar style.
/// 7. **Run**, with the production implementations injected as provider
///    overrides ([_overrides]).
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();

  await CrashReporting.install();
  try {
    EnvLoader.apply();
  } on EnvConfigError catch (error) {
    // A misconfigured production build must fail where it is obvious: the
    // error goes to the device log and the screen says why, instead of the
    // app hanging on its splash (CL INS-007).
    AppLogger.fatal('Medibook cannot start: $error', name: 'bootstrap');
    runApp(_ConfigErrorApp(error.message));
    return;
  }

  // Every box is encrypted with a key kept in the platform keystore.
  HiveInit.store = HiveLocalStore(
    encryptionKey: () => _localStorageKey(FlutterSecureStorageStore()),
  );
  final cacheFailure = await HiveInit.open();
  if (cacheFailure != null) {
    // Not fatal: the app runs network-only. Logged by HiveInit; recorded here
    // so it is visible in crash reporting as a non-fatal.
    CrashReporting.recordFailure(cacheFailure);
  }

  final connectivity = ConnectivityMonitor();
  await connectivity.start();

  // Names this phone and build on every request, so Signed-in Devices can
  // tell one session from another (§4.9).
  final userAgent = await AppUserAgent.resolve();

  await _applySystemChrome();

  Analytics.track(AnalyticsEvent.appOpened);
  AppLogger.info('Medibook starting', name: 'bootstrap');

  runApp(
    ProviderScope(
      overrides: _overrides(connectivity: connectivity, userAgent: userAgent),
      child: const MedibookApp(),
    ),
  );
}

/// The install's Hive key from secure storage, created on first launch.
///
/// Boxes written before encryption was added cannot be read with it; Hive
/// drops their entries as corrupt, so that upgrade starts with an empty cache
/// and asks the patient to sign in once (the session record lives there).
Future<List<int>> _localStorageKey(SecureStore secureStore) async {
  final saved = await secureStore.read(SecureKeys.localStorageKey);
  if (saved != null && saved.isNotEmpty) return base64Decode(saved);
  final key = Hive.generateSecureKey();
  await secureStore.write(SecureKeys.localStorageKey, base64Encode(key));
  return key;
}

/// Global provider overrides — the one place the production implementations
/// are injected. Tests build their own `ProviderScope` with fakes.
///
/// The HTTP client needs the auth feature's callbacks (token, fingerprint,
/// refresh, session-lost) and the auth feature needs the client: the cycle is
/// broken by giving the client a **lazy** container read, so the feature's
/// providers are only resolved on the first request.
List<Override> _overrides({
  required ConnectivityMonitor connectivity,
  required String userAgent,
}) {
  final secureStore = FlutterSecureStorageStore();

  // A private container that shares the same overrides, used only to reach
  // the auth providers lazily from inside the client hooks.
  late final ProviderContainer hooksContainer;

  final client = DioApiClient(
    baseUrl: Env.apiBaseUrl,
    timeout: CacheConfig.apiTimeout,
    userAgent: userAgent,
    allowBadCertificate: Env.allowBadCertificate && !Env.isProd,
    hooks: ApiSessionHooks(
      accessToken: () =>
          hooksContainer.read(apiSessionHooksProvider).accessToken(),
      deviceFingerprint: () =>
          hooksContainer.read(apiSessionHooksProvider).deviceFingerprint(),
      refresh: () => hooksContainer.read(apiSessionHooksProvider).refresh(),
      onSessionLost: (failure) =>
          hooksContainer.read(apiSessionHooksProvider).onSessionLost(failure),
    ),
    onReachability: (reached) => reached
        ? connectivity.reportReachable()
        : connectivity.reportUnreachable(),
    isOffline: () => !connectivity.hasRoute,
  );

  // Wi-Fi with no internet (BL-CACHE-019): while requests cannot get
  // through, a light public call checks whether they can again.
  connectivity.reachabilityProbe = () async {
    try {
      await client.send(
        const ApiRequest(
          path: Endpoints.health,
          requiresAuth: false,
          timeout: Duration(seconds: 5),
        ),
      );
      return true;
    } on HttpStatusException {
      return true;
    } catch (_) {
      return false;
    }
  };

  final overrides = <Override>[
    // Each feature's real data sources and repositories (app/di). Later
    // entries replace earlier ones, so the shared instances below win.
    ...appDependencies(),
    secureStoreProvider.overrideWithValue(secureStore),
    apiClientProvider.overrideWithValue(client),
    connectivityMonitorProvider.overrideWithValue(connectivity),
  ];

  hooksContainer = ProviderContainer(overrides: overrides);

  final fetcher = CachedFetcher(
    client: client,
    connectivity: connectivity,
    cacheScope: () => hooksContainer.read(cacheScopeProvider)(),
  );

  // The app's own scope must resolve the auth providers to the *same*
  // instances the hooks container does, so the state the router watches is
  // the state the client signs out. Sharing the notifier instance does that.
  // Resolved here, eagerly: a `container.read` from inside another
  // container's provider build trips Riverpod's circular-dependency check.
  final authRepository = hooksContainer.read(authRepositoryProvider);
  final deviceIdentity = hooksContainer.read(deviceIdentityProvider);
  final authController = hooksContainer.read(authProvider.notifier);
  return [
    ...overrides,
    cachedFetcherProvider.overrideWithValue(fetcher),
    authRepositoryProvider.overrideWithValue(authRepository),
    deviceIdentityProvider.overrideWithValue(deviceIdentity),
    authProvider.overrideWith((ref) => authController),
  ];
}

/// Portrait lock and status-bar styling.
///
/// Every screen in this design is authored against a 390x844 portrait
/// artboard, with fixed-height headers, a bottom-nav shell and hero cards that
/// assume a tall viewport. Both portrait orientations are allowed, so a phone
/// held upside-down (common while charging) still works.
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

/// Shown instead of the app when the build's configuration is invalid.
/// Plain sizes: it runs before ScreenUtil (and the rest of the app) exists.
class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: AppColors.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'This build of Medibook is misconfigured and cannot start.\n\n'
            '$message',
            style: const TextStyle(color: AppColors.textStrong, fontSize: 15),
          ),
        ),
      ),
    ),
  );
}

/// Adds the bundled fonts' licences to Flutter's licence page (Profile >
/// Open-source licences, CL REL-026). Packages register their own; fonts
/// shipped as assets do not, and the SIL OFL requires the notice to ship
/// with the font.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in const [
      ('Poppins', 'assets/licenses/OFL-Poppins.txt'),
      ('Inter', 'assets/licenses/OFL-Inter.txt'),
    ]) {
      final text = await rootBundle.loadString(file);
      yield LicenseEntryWithLineBreaks([family], text);
    }
  });
}
