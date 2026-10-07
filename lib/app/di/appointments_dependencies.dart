import '../../core/storage/cache/cached_fetcher.dart';
import '../../features/appointments/application/providers/appointments_provider.dart';
import '../../features/appointments/infrastructure/data_sources/local/calendar_local_ds.dart';
import '../../features/appointments/infrastructure/data_sources/remote/appointments_api.dart';
import '../../features/appointments/infrastructure/repositories/appointments_repository_impl.dart';
import '../../features/auth/application/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Dependency wiring for features/appointments: the concrete data sources and
// repositories behind this feature's domain contracts (QA architecture
// audit #5, CL CODE-014). Only app/ imports infrastructure/.

/// Appointments remote data source over the app's [ApiClient].
final appointmentsApiProvider = Provider<AppointmentsApi>(
  (ref) => HttpAppointmentsApi(ref.watch(apiClientProvider)),
);

/// Where a downloaded `calendar.ics` is written.
final calendarLocalDataSourceProvider = Provider<CalendarLocalDataSource>(
  (ref) => const CalendarLocalDataSourceImpl(),
);

/// Overrides that put the real implementations behind this feature's
/// application-layer providers. Applied once, at the root `ProviderScope`.
final List<Override> appointmentsDependencies = [
  appointmentsRepositoryProvider.overrideWith(
    (ref) => AppointmentsRepositoryImpl(
      api: ref.watch(appointmentsApiProvider),
      fetcher: ref.watch(cachedFetcherProvider),
      calendar: ref.watch(calendarLocalDataSourceProvider),
    ),
  ),
];
