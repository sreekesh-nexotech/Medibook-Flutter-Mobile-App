import '../../core/storage/cache/cached_fetcher.dart';
import '../../features/auth/application/providers/auth_provider.dart';
import '../../features/notifications/application/providers/notifications_provider.dart';
import '../../features/notifications/infrastructure/data_sources/local/push_device_local_ds.dart';
import '../../features/notifications/infrastructure/data_sources/remote/notifications_api.dart';
import '../../features/notifications/infrastructure/repositories/notifications_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dependency wiring for features/notifications: the concrete data sources and
// repositories behind this feature's domain contracts (QA architecture
// audit #5, CL CODE-014). Only app/ imports infrastructure/.

final notificationsApiProvider = Provider<NotificationsApi>(
  (ref) => HttpNotificationsApi(ref.watch(apiClientProvider)),
);

final pushDeviceLocalDataSourceProvider = Provider<PushDeviceLocalDataSource>(
  (ref) => const PushDeviceLocalDataSourceImpl(),
);

/// Overrides that put the real implementations behind this feature's
/// application-layer providers. Applied once, at the root `ProviderScope`.
final List<Override> notificationsDependencies = [
  notificationsRepositoryProvider.overrideWith(
    (ref) => NotificationsRepositoryImpl(
      api: ref.watch(notificationsApiProvider),
      fetcher: ref.watch(cachedFetcherProvider),
      local: ref.watch(pushDeviceLocalDataSourceProvider),
    ),
  ),
];
