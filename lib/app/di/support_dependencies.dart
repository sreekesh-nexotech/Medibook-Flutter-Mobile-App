import '../../core/storage/cache/cached_fetcher.dart';
import '../../features/auth/application/providers/auth_provider.dart';
import '../../features/support/application/providers/support_provider.dart';
import '../../features/support/infrastructure/data_sources/remote/support_content_api.dart';
import '../../features/support/infrastructure/data_sources/remote/support_ticket_api.dart';
import '../../features/support/infrastructure/repositories/support_content_repository_impl.dart';
import '../../features/support/infrastructure/repositories/support_ticket_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dependency wiring for features/support: the concrete data sources and
// repositories behind this feature's domain contracts (QA architecture
// audit #5, CL CODE-014). Only app/ imports infrastructure/.

final supportContentApiProvider = Provider<SupportContentApi>(
  (ref) => const HttpSupportContentApi(),
);

final supportTicketApiProvider = Provider<SupportTicketApi>(
  (ref) => HttpSupportTicketApi(ref.watch(apiClientProvider)),
);

/// Overrides that put the real implementations behind this feature's
/// application-layer providers. Applied once, at the root `ProviderScope`.
final List<Override> supportDependencies = [
  supportContentRepositoryProvider.overrideWith(
    (ref) => SupportContentRepositoryImpl(
      api: ref.watch(supportContentApiProvider),
      fetcher: ref.watch(cachedFetcherProvider),
    ),
  ),
  supportTicketRepositoryProvider.overrideWith(
    (ref) => SupportTicketRepositoryImpl(
      api: ref.watch(supportTicketApiProvider),
      fetcher: ref.watch(cachedFetcherProvider),
    ),
  ),
];
