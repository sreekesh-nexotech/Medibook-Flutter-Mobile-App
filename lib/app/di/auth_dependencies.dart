import '../../features/auth/application/providers/auth_provider.dart';
import '../../features/auth/application/providers/onboarding_provider.dart';
import '../../features/auth/infrastructure/data_sources/local/auth_local_ds.dart';
import '../../features/auth/infrastructure/data_sources/local/onboarding_local_ds.dart';
import '../../features/auth/infrastructure/data_sources/remote/auth_api.dart';
import '../../features/auth/infrastructure/data_sources/remote/demo_auth_api.dart';
import '../../features/auth/infrastructure/repositories/auth_repository_impl.dart';
import '../config/feature_flags.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dependency wiring for features/auth: the concrete data sources and
// repositories behind this feature's domain contracts (QA architecture
// audit #5, CL CODE-014). Only app/ imports infrastructure/.

/// Auth remote data source. In demo mode this is [DemoAuthApi]; otherwise the
/// real endpoints over [apiClientProvider].
final authApiProvider = Provider<AuthApi>(
  (ref) => FeatureFlags.demoMode
      ? const DemoAuthApi()
      : HttpAuthApi(ref.watch(apiClientProvider)),
);

/// Auth local data source (credentials + the server-announced lockout).
final authLocalDataSourceProvider = Provider<AuthLocalDataSource>(
  (ref) => AuthLocalDataSourceImpl(secureStore: ref.watch(secureStoreProvider)),
);

/// Overrides that put the real implementations behind this feature's
/// application-layer providers. Applied once, at the root `ProviderScope`.
final List<Override> authDependencies = [
  authRepositoryProvider.overrideWith(
    (ref) => AuthRepositoryImpl(
      api: ref.watch(authApiProvider),
      local: ref.watch(authLocalDataSourceProvider),
    ),
  ),
  onboardingLocalDataSourceProvider.overrideWith(
    (ref) => const OnboardingLocalDataSourceImpl(),
  ),
];
