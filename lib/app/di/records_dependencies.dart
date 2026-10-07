import '../../core/storage/cache/cached_fetcher.dart';
import '../../features/auth/application/providers/auth_provider.dart';
import '../../features/records/application/providers/records_provider.dart';
import '../../features/records/infrastructure/data_sources/remote/documents_api.dart';
import '../../features/records/infrastructure/repositories/documents_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dependency wiring for features/records: the concrete data sources and
// repositories behind this feature's domain contracts (QA architecture
// audit #5, CL CODE-014). Only app/ imports infrastructure/.

final documentsApiProvider = Provider<DocumentsApi>(
  (ref) => HttpDocumentsApi(ref.watch(apiClientProvider)),
);

/// Overrides that put the real implementations behind this feature's
/// application-layer providers. Applied once, at the root `ProviderScope`.
final List<Override> recordsDependencies = [
  documentsRepositoryProvider.overrideWith(
    (ref) => DocumentsRepositoryImpl(
      api: ref.watch(documentsApiProvider),
      fetcher: ref.watch(cachedFetcherProvider),
    ),
  ),
];
