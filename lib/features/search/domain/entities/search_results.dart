import '../../../booking/domain/entities/department.dart';
import '../../../booking/domain/entities/doctor.dart';
import '../../../booking/domain/entities/hospital.dart';

/// `GET /patient/search?q=` (§7.9): up to ten of each, not paginated.
///
/// Grouped rather than one mixed list: a department, a facility and a doctor
/// are different kinds of answer that lead to different next steps.
class SearchResults {
  const SearchResults({
    required this.query,
    required this.hospitals,
    required this.departments,
    required this.doctors,
  });

  /// The empty result for a query that was never sent.
  const SearchResults.empty()
    : query = '',
      hospitals = const [],
      departments = const [],
      doctors = const [];

  final String query;
  final List<HospitalCard> hospitals;
  final List<DepartmentSummary> departments;
  final List<DoctorCard> doctors;

  int get total => hospitals.length + departments.length + doctors.length;

  bool get isEmpty => total == 0;
}
