import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/cache/cached_fetcher.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../domain/entities/department.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/hospital.dart';
import '../../domain/entities/location.dart';
import '../../domain/entities/promo_banner.dart';
import '../../domain/repositories/availability_repository.dart';
import '../../domain/repositories/discovery_repository.dart';

/// Public discovery (§7). Returns the abstract type; override in tests.
final discoveryRepositoryProvider = Provider<DiscoveryRepository>(
  (ref) => throw UnimplementedError(
    'discoveryRepositoryProvider is wired in app/di',
  ),
);

/// Availability and slots (§8.1, §8.2).
final availabilityRepositoryProvider = Provider<AvailabilityRepository>(
  (ref) => throw UnimplementedError(
    'availabilityRepositoryProvider is wired in app/di',
  ),
);

// ---- Reads. Every one is autoDispose: discovery data is per-screen and the
// three-layer cache already keeps it warm across navigation (Scenario 4). ----

/// `GET /patient/locations`, every city and area.
final discoveryLocationsProvider =
    StreamProvider.autoDispose<CachedResult<Page<Location>>>(
      (ref) => ref.watch(discoveryRepositoryProvider).locations(),
    );

/// `GET /patient/hospitals` for one [HospitalsQuery].
final discoveryHospitalsProvider = StreamProvider.autoDispose
    .family<CachedResult<Page<HospitalCard>>, HospitalsQuery>(
      (ref, query) => ref.watch(discoveryRepositoryProvider).hospitals(query),
    );

/// `GET /patient/hospitals/{id}`.
final hospitalDetailProvider = StreamProvider.autoDispose
    .family<CachedResult<HospitalDetail>, String>(
      (ref, id) => ref.watch(discoveryRepositoryProvider).hospital(id),
    );

/// `GET /patient/hospitals/{id}/banners`.
final hospitalBannersProvider = StreamProvider.autoDispose
    .family<CachedResult<Page<HospitalBanner>>, String>(
      (ref, id) => ref.watch(discoveryRepositoryProvider).hospitalBanners(id),
    );

/// `GET /patient/departments` — the platform-wide speciality list.
final discoveryDepartmentsProvider =
    StreamProvider.autoDispose<CachedResult<Page<DepartmentSummary>>>(
      (ref) => ref.watch(discoveryRepositoryProvider).departments(),
    );

/// `GET /patient/hospitals/{id}/departments`.
final hospitalDepartmentsProvider = StreamProvider.autoDispose
    .family<CachedResult<Page<HospitalDepartment>>, String>(
      (ref, id) =>
          ref.watch(discoveryRepositoryProvider).hospitalDepartments(id),
    );

/// `GET /patient/hospitals/{id}/doctors` for one [HospitalDoctorsQuery].
final hospitalDoctorsProvider = StreamProvider.autoDispose
    .family<CachedResult<Page<DoctorCard>>, HospitalDoctorsQuery>(
      (ref, query) =>
          ref.watch(discoveryRepositoryProvider).hospitalDoctors(query),
    );

/// `GET /patient/doctors/{id}`.
final doctorDetailProvider = StreamProvider.autoDispose
    .family<CachedResult<DoctorDetail>, String>(
      (ref, id) => ref.watch(discoveryRepositoryProvider).doctor(id),
    );

/// Whether the viewer can resolve `*_file_id` images. Discovery is public,
/// but `GET /shared/files/{id}/url` needs a token (§11.4), so a signed-out
/// browser gets initials and tinted placeholders instead.
final canLoadImagesProvider = Provider<bool>(
  (ref) => ref.watch(isAuthenticatedProvider),
);
