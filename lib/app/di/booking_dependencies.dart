import '../../core/storage/cache/cached_fetcher.dart';
import '../../features/auth/application/providers/auth_provider.dart';
import '../../features/booking/application/providers/booking_providers.dart';
import '../../features/booking/application/providers/discovery_providers.dart';
import '../../features/booking/application/providers/location_scope_provider.dart';
import '../../features/booking/infrastructure/data_sources/local/location_scope_local_ds.dart';
import '../../features/booking/infrastructure/data_sources/remote/booking_api.dart';
import '../../features/booking/infrastructure/repositories/booking_repository_impl.dart';
import '../../features/booking/infrastructure/repositories/discovery_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dependency wiring for features/booking: the concrete data sources and
// repositories behind this feature's domain contracts (QA architecture
// audit #5, CL CODE-014). Only app/ imports infrastructure/.

/// Booking remote data source over the shared HTTP client.
final bookingApiProvider = Provider<BookingApi>(
  (ref) => HttpBookingApi(ref.watch(apiClientProvider)),
);

/// The one discovery/availability implementation, exposed under both
/// contracts so a test can fake either independently.
final _discoveryImplProvider = Provider<DiscoveryRepositoryImpl>(
  (ref) => DiscoveryRepositoryImpl(fetcher: ref.watch(cachedFetcherProvider)),
);

/// Overrides that put the real implementations behind this feature's
/// application-layer providers. Applied once, at the root `ProviderScope`.
final List<Override> bookingDependencies = [
  discoveryRepositoryProvider.overrideWith(
    (ref) => ref.watch(_discoveryImplProvider),
  ),
  availabilityRepositoryProvider.overrideWith(
    (ref) => ref.watch(_discoveryImplProvider),
  ),
  bookingRepositoryProvider.overrideWith(
    (ref) => BookingRepositoryImpl(api: ref.watch(bookingApiProvider)),
  ),
  locationScopeLocalDataSourceProvider.overrideWith(
    (ref) => const LocationScopeLocalDataSourceImpl(),
  ),
];
