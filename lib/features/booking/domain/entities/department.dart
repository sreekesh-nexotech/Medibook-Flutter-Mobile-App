/// A department reference as embedded on hospital and doctor cards
/// (`{id, code, name}`).
class DepartmentRef {
  const DepartmentRef({
    required this.id,
    required this.code,
    required this.name,
  });

  final String id;
  final String code;
  final String name;
}

/// One row of `GET /patient/departments` (§7.5) — the platform-wide "browse by
/// speciality" list. There is no id; the [code] is the filter key for
/// `GET /patient/hospitals?department_code=`.
class DepartmentSummary {
  const DepartmentSummary({
    required this.code,
    required this.name,
    required this.hospitalCount,
  });

  final String code;
  final String name;
  final int hospitalCount;
}

/// One row of `GET /patient/hospitals/{id}/departments` (§7.6).
class HospitalDepartment {
  const HospitalDepartment({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.icon,
    this.sortOrder = 0,
  });

  final String id;
  final String code;
  final String name;
  final String? description;

  /// The backend's icon hint (`"heart"`), or null.
  final String? icon;
  final int sortOrder;
}
