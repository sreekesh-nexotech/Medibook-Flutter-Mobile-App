import '../../features/app_update/application/providers/app_update_provider.dart';
import '../../features/app_update/infrastructure/data_sources/local/play_update_ds.dart';
import '../../features/app_update/infrastructure/repositories/app_update_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dependency wiring for features/app_update: the concrete data sources and
// repositories behind this feature's domain contracts (QA architecture
// audit #5, CL CODE-014). Only app/ imports infrastructure/.

final playUpdateDataSourceProvider = Provider<PlayUpdateDataSource>(
  (ref) => const PlatformPlayUpdateDataSource(),
);

/// Overrides that put the real implementations behind this feature's
/// application-layer providers. Applied once, at the root `ProviderScope`.
final List<Override> appUpdateDependencies = [
  appUpdateRepositoryProvider.overrideWith(
    (ref) => AppUpdateRepositoryImpl(
      dataSource: ref.watch(playUpdateDataSourceProvider),
    ),
  ),
];
