/// `GET /patient/ambulance/providers` (§14) — a public directory to **call**
/// from. There is no booking endpoint (§18).
class AmbulanceProvider {
  const AmbulanceProvider({
    required this.id,
    required this.name,
    required this.phoneE164,
    this.etaMinutes,
    this.serviceArea,
    this.city,
    this.area,
  });

  final String id;
  final String name;
  final String phoneE164;

  /// Nullable on the wire.
  final int? etaMinutes;
  final String? serviceArea;
  final String? city;
  final String? area;

  /// "~12 min", or null when the operator gave no estimate.
  String? get etaLabel => etaMinutes == null ? null : '~$etaMinutes min';

  /// "Edappally, Kochi" — the best available locality line.
  String get localityLabel {
    final parts = <String>[
      if (area != null && area!.isNotEmpty) area!,
      if (city != null && city!.isNotEmpty) city!,
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    return serviceArea ?? '';
  }

  @override
  bool operator ==(Object other) =>
      other is AmbulanceProvider &&
      other.id == id &&
      other.name == name &&
      other.phoneE164 == phoneE164 &&
      other.etaMinutes == etaMinutes &&
      other.serviceArea == serviceArea &&
      other.city == city &&
      other.area == area;

  @override
  int get hashCode =>
      Object.hash(id, name, phoneE164, etaMinutes, serviceArea, city, area);
}

/// The filters `GET /patient/ambulance/providers` accepts. Only the listed
/// parameters are ever sent — an unknown one is a `400` (§1.7).
class AmbulanceFilter {
  const AmbulanceFilter({this.city, this.area, this.hospitalId});

  static const AmbulanceFilter none = AmbulanceFilter();

  final String? city;
  final String? area;

  /// Providers in that hospital's city.
  final String? hospitalId;

  @override
  bool operator ==(Object other) =>
      other is AmbulanceFilter &&
      other.city == city &&
      other.area == area &&
      other.hospitalId == hospitalId;

  @override
  int get hashCode => Object.hash(city, area, hospitalId);
}
