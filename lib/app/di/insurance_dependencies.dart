import '../../core/storage/cache/cached_fetcher.dart';
import '../../features/auth/application/providers/auth_provider.dart';
import '../../features/insurance/application/providers/insurance_provider.dart';
import '../../features/insurance/infrastructure/data_sources/remote/insurance_api.dart';
import '../../features/insurance/infrastructure/repositories/insurance_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dependency wiring for features/insurance: the concrete data sources and
// repositories behind this feature's domain contracts (QA architecture
// audit #5, CL CODE-014). Only app/ imports infrastructure/.

final insuranceApiProvider = Provider<InsuranceApi>(
  (ref) => HttpInsuranceApi(ref.watch(apiClientProvider)),
);

/// Overrides that put the real implementations behind this feature's
/// application-layer providers. Applied once, at the root `ProviderScope`.
final List<Override> insuranceDependencies = [
  insuranceRepositoryProvider.overrideWith(
    (ref) => InsuranceRepositoryImpl(
      api: ref.watch(insuranceApiProvider),
      fetcher: ref.watch(cachedFetcherProvider),
    ),
  ),
];
