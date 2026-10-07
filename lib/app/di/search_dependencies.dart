import '../../features/auth/application/providers/auth_provider.dart';
import '../../features/search/application/providers/search_providers.dart';
import '../../features/search/infrastructure/data_sources/remote/search_api.dart';
import '../../features/search/infrastructure/repositories/search_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dependency wiring for features/search: the concrete data sources and
// repositories behind this feature's domain contracts (QA architecture
// audit #5, CL CODE-014). Only app/ imports infrastructure/.

final searchApiProvider = Provider<SearchApi>(
  (ref) => HttpSearchApi(ref.watch(apiClientProvider)),
);

/// Overrides that put the real implementations behind this feature's
/// application-layer providers. Applied once, at the root `ProviderScope`.
final List<Override> searchDependencies = [
  searchRepositoryProvider.overrideWith(
    (ref) => SearchRepositoryImpl(api: ref.watch(searchApiProvider)),
  ),
];
