import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/di/dependencies.dart';
import 'package:medibook/core/network/api_client.dart';
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/core/widgets/app_icon.dart';
import 'package:medibook/features/booking/application/providers/discovery_providers.dart';
import 'package:medibook/features/booking/domain/entities/department.dart';
import 'package:medibook/features/booking/domain/entities/doctor.dart';
import 'package:medibook/features/booking/domain/entities/hospital.dart';
import 'package:medibook/features/booking/domain/entities/location.dart';
import 'package:medibook/features/booking/domain/entities/promo_banner.dart';
import 'package:medibook/features/booking/domain/repositories/discovery_repository.dart';
import 'package:medibook/features/dashboard/presentation/components/department_icon.dart';
import 'package:medibook/features/dashboard/application/providers/home_providers.dart';

/// Home's derived providers against a fake discovery repository: the service
/// tiles come from `GET /patient/departments`, the banner strip from the
/// visible hospitals' banners, and the icon mapping covers the platform's
/// codes.
void main() {
  late _FakeDiscovery discovery;
  late ProviderContainer container;

  setUp(() {
    discovery = _FakeDiscovery();
    container = ProviderContainer(
      overrides: [
        ...appDependencies(),
        discoveryRepositoryProvider.overrideWithValue(discovery),
      ],
    );
    addTearDown(container.dispose);
  });

  test('services are departments, most hospitals first, with a mark', () async {
    final sub = container.listen(homeServicesProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(discoveryDepartmentsProvider.future);
    final services = container.read(homeServicesProvider).value!;
    expect(services.map((s) => s.code), ['general_medicine', 'cardiology']);
    expect(departmentIconFor(services.first.code), DeptIcon.general);
    expect(departmentIconFor(services.last.code), DeptIcon.cardiology);
  });

  test('the banner strip stitches each visible hospital\'s banners', () async {
    final banners = await container.read(homeBannersProvider.future);
    expect(banners.map((b) => b.title), ['Free BP check', 'Skin camp']);
    expect(banners.first.hospitalId, 'h1');
    expect(discovery.bannerRequests, ['h1', 'h2']);
  });

  test('department icons fall back to the generic mark', () {
    expect(departmentIconFor('orthopaedics'), DeptIcon.orthopedics);
    expect(departmentIconFor('gynaecology'), DeptIcon.womensHealth);
    expect(departmentIconFor('something_new'), DeptIcon.general);
  });
}

CachedResult<T> _fresh<T>(T value) => CachedResult<T>(
  value: value,
  source: CacheSource.network,
  cachedAt: DateTime.now(),
);

Page<T> _page<T>(List<T> rows) => Page<T>(
  results: rows,
  page: 1,
  pageSize: rows.length,
  total: rows.length,
  hasNext: false,
);

class _FakeDiscovery implements DiscoveryRepository {
  final List<String> bannerRequests = [];

  @override
  Stream<CachedResult<Page<DepartmentSummary>>> departments({
    bool forceRefresh = false,
  }) => Stream.value(
    _fresh(
      _page(const [
        DepartmentSummary(
          code: 'cardiology',
          name: 'Cardiology',
          hospitalCount: 1,
        ),
        DepartmentSummary(
          code: 'general_medicine',
          name: 'General Medicine',
          hospitalCount: 2,
        ),
      ]),
    ),
  );

  @override
  Stream<CachedResult<Page<HospitalCard>>> hospitals(
    HospitalsQuery query, {
    bool forceRefresh = false,
  }) => Stream.value(
    _fresh(
      _page(const [
        HospitalCard(
          id: 'h1',
          slug: 'a',
          name: 'A',
          city: 'Kochi',
          departments: [],
          onlineBookingEnabled: true,
        ),
        HospitalCard(
          id: 'h2',
          slug: 'b',
          name: 'B',
          city: 'Pune',
          departments: [],
          onlineBookingEnabled: true,
        ),
      ]),
    ),
  );

  @override
  Stream<CachedResult<Page<HospitalBanner>>> hospitalBanners(
    String hospitalId, {
    bool forceRefresh = false,
  }) {
    bannerRequests.add(hospitalId);
    return Stream.value(
      _fresh(
        _page([
          HospitalBanner(
            id: 'b-$hospitalId',
            title: hospitalId == 'h1' ? 'Free BP check' : 'Skin camp',
            hospitalId: hospitalId,
          ),
        ]),
      ),
    );
  }

  @override
  Stream<CachedResult<DoctorDetail>> doctor(
    String doctorId, {
    bool forceRefresh = false,
  }) => const Stream.empty();

  @override
  Stream<CachedResult<HospitalDetail>> hospital(
    String hospitalId, {
    bool forceRefresh = false,
  }) => const Stream.empty();

  @override
  Stream<CachedResult<Page<HospitalDepartment>>> hospitalDepartments(
    String hospitalId, {
    bool forceRefresh = false,
  }) => const Stream.empty();

  @override
  Stream<CachedResult<Page<DoctorCard>>> hospitalDoctors(
    HospitalDoctorsQuery query, {
    bool forceRefresh = false,
  }) => const Stream.empty();

  @override
  Stream<CachedResult<Page<Location>>> locations({
    String? city,
    bool? popular,
    bool forceRefresh = false,
  }) => const Stream.empty();
}
