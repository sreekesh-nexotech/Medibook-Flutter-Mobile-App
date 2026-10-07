import '../../core/storage/cache/cached_fetcher.dart';
import '../../features/common/persons/application/providers/persons_read_provider.dart';
import '../../features/common/persons/infrastructure/data_sources/remote/persons_read_api.dart';
import '../../features/common/persons/infrastructure/repositories/persons_read_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dependency wiring for features/common/persons: the concrete data sources and
// repositories behind this feature's domain contracts (QA architecture
// audit #5, CL CODE-014). Only app/ imports infrastructure/.

final personsReadApiProvider = Provider<PersonsReadApi>(
  (ref) => const HttpPersonsReadApi(),
);

/// Overrides that put the real implementations behind this feature's
/// application-layer providers. Applied once, at the root `ProviderScope`.
final List<Override> commonPersonsDependencies = [
  personsReadRepositoryProvider.overrideWith(
    (ref) => PersonsReadRepositoryImpl(
      api: ref.watch(personsReadApiProvider),
      fetcher: ref.watch(cachedFetcherProvider),
    ),
  ),
];
