import '../../../../core/network/models/page.dart';
import '../../../../core/storage/cache/cached_result.dart';
import '../entities/department.dart';
import '../entities/doctor.dart';
import '../entities/hospital.dart';
import '../entities/location.dart';
import '../entities/promo_banner.dart';

/// Sort keys `GET /patient/hospitals` accepts (§7.2).
enum HospitalSort {
  name('name'),
  rating('-rating_avg'),
  nextAvailable('next_available_at'),
  distance('distance_km');

  const HospitalSort(this.wire);

  final String wire;
}

/// The filters and sort for `GET /patient/hospitals` (§7.2). Only the listed
/// parameters exist; anything else is a `400`, so this is a closed shape.
class HospitalsQuery {
  const HospitalsQuery({
    this.city,
    this.area,
    this.departmentCode,
    this.q,
    this.lat,
    this.lng,
    this.radiusKm,
    this.sort,
    this.page = 1,
    this.pageSize,
  });

  final String? city;
  final String? area;
  final String? departmentCode;

  /// Name search.
  final String? q;
  final String? lat;
  final String? lng;
  final double? radiusKm;
  final HospitalSort? sort;
  final int page;
  final int? pageSize;

  bool get hasCoordinates => lat != null && lng != null;

  HospitalsQuery copyWith({
    String? Function()? city,
    String? Function()? area,
    String? Function()? departmentCode,
    String? Function()? q,
    HospitalSort? Function()? sort,
    int? page,
  }) => HospitalsQuery(
    city: city != null ? city() : this.city,
    area: area != null ? area() : this.area,
    departmentCode: departmentCode != null
        ? departmentCode()
        : this.departmentCode,
    q: q != null ? q() : this.q,
    lat: lat,
    lng: lng,
    radiusKm: radiusKm,
    sort: sort != null ? sort() : this.sort,
    page: page ?? this.page,
    pageSize: pageSize,
  );

  @override
  bool operator ==(Object other) =>
      other is HospitalsQuery &&
      other.city == city &&
      other.area == area &&
      other.departmentCode == departmentCode &&
      other.q == q &&
      other.lat == lat &&
      other.lng == lng &&
      other.radiusKm == radiusKm &&
      other.sort == sort &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(
    city,
    area,
    departmentCode,
    q,
    lat,
    lng,
    radiusKm,
    sort,
    page,
    pageSize,
  );
}

/// The filters for `GET /patient/hospitals/{id}/doctors` (§7.7).
class HospitalDoctorsQuery {
  const HospitalDoctorsQuery({
    required this.hospitalId,
    this.departmentCode,
    this.departmentId,
    this.q,
    this.sort,
    this.page = 1,
    this.pageSize,
  });

  final String hospitalId;
  final String? departmentCode;
  final String? departmentId;
  final String? q;

  /// `name` | `sort_order` | `next_available_at` | `consultation_fee_paise`,
  /// optionally `-` prefixed.
  final String? sort;
  final int page;
  final int? pageSize;

  @override
  bool operator ==(Object other) =>
      other is HospitalDoctorsQuery &&
      other.hospitalId == hospitalId &&
      other.departmentCode == departmentCode &&
      other.departmentId == departmentId &&
      other.q == q &&
      other.sort == sort &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(
    hospitalId,
    departmentCode,
    departmentId,
    q,
    sort,
    page,
    pageSize,
  );
}

/// The public discovery contract (§7).
///
/// Every read is a cached GET, so each method returns the three-layer
/// [CachedResult] stream: the cached value first (when there is one), then
/// the network value. Errors surface as `Failure`s; a screen with a cached
/// copy keeps it (`docs-flutter/HIVE implementation.md`, Scenario 2/5).
abstract interface class DiscoveryRepository {
  /// `GET /patient/locations` (§7.1).
  Stream<CachedResult<Page<Location>>> locations({
    String? city,
    bool? popular,
    bool forceRefresh = false,
  });

  /// `GET /patient/hospitals` (§7.2).
  Stream<CachedResult<Page<HospitalCard>>> hospitals(
    HospitalsQuery query, {
    bool forceRefresh = false,
  });

  /// `GET /patient/hospitals/{id}` (§7.3).
  Stream<CachedResult<HospitalDetail>> hospital(
    String hospitalId, {
    bool forceRefresh = false,
  });

  /// `GET /patient/hospitals/{id}/banners` (§7.4).
  Stream<CachedResult<Page<HospitalBanner>>> hospitalBanners(
    String hospitalId, {
    bool forceRefresh = false,
  });

  /// `GET /patient/departments` (§7.5).
  Stream<CachedResult<Page<DepartmentSummary>>> departments({
    bool forceRefresh = false,
  });

  /// `GET /patient/hospitals/{id}/departments` (§7.6).
  Stream<CachedResult<Page<HospitalDepartment>>> hospitalDepartments(
    String hospitalId, {
    bool forceRefresh = false,
  });

  /// `GET /patient/hospitals/{id}/doctors` (§7.7).
  Stream<CachedResult<Page<DoctorCard>>> hospitalDoctors(
    HospitalDoctorsQuery query, {
    bool forceRefresh = false,
  });

  /// `GET /patient/doctors/{id}` (§7.8).
  Stream<CachedResult<DoctorDetail>> doctor(
    String doctorId, {
    bool forceRefresh = false,
  });
}
