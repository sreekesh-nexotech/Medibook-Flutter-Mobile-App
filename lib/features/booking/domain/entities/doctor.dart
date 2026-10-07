import 'department.dart';

/// The hospital a doctor practises at, as embedded on a doctor card.
class DoctorHospitalRef {
  const DoctorHospitalRef({
    required this.id,
    required this.name,
    required this.city,
    this.area,
  });

  final String id;
  final String name;
  final String city;
  final String? area;

  /// "Lakeshore Multispeciality Hospital, Kadavanthra".
  String get label => area == null ? name : '$name, $area';
}

/// Doctor `status` (§17): inactive doctors are never listed.
enum DoctorStatus {
  active('active'),
  onLeave('on_leave');

  const DoctorStatus(this.wire);

  final String wire;

  static DoctorStatus fromWire(String? value) =>
      value == onLeave.wire ? onLeave : active;
}

/// One row of `GET /patient/hospitals/{id}/doctors` (§7.7) and the doctor
/// list inside search results.
class DoctorCard {
  const DoctorCard({
    required this.id,
    required this.slug,
    required this.name,
    required this.department,
    required this.hospital,
    required this.consultationFeePaise,
    required this.isBookableOnline,
    this.title,
    this.qualification,
    this.specialisation,
    this.experienceYears,
    this.photoFileId,
    this.followUpFeePaise,
    this.rating,
    this.ratingCount = 0,
    this.status = DoctorStatus.active,
    this.nextAvailableAt,
  });

  final String id;
  final String slug;
  final String name;
  final String? title;
  final String? qualification;
  final String? specialisation;
  final int? experienceYears;
  final String? photoFileId;
  final DepartmentRef department;
  final DoctorHospitalRef hospital;
  final int consultationFeePaise;

  /// Null means the follow-up fee equals the consultation fee.
  final int? followUpFeePaise;
  final String? rating;
  final int ratingCount;
  final DoctorStatus status;
  final bool isBookableOnline;

  /// Earliest open slot (UTC), or null.
  final DateTime? nextAvailableAt;

  double get ratingValue => double.tryParse(rating ?? '') ?? 0;
  bool get hasRating => rating != null;

  /// "Interventional Cardiology" falling back to the department name.
  String get specialityLabel => specialisation ?? department.name;

  /// "14 yrs", or null when unknown.
  String? get experienceLabel =>
      experienceYears == null ? null : '$experienceYears yrs';

  /// True when a patient can book this doctor online right now.
  bool get canBook => isBookableOnline && status == DoctorStatus.active;
}

/// `GET /patient/doctors/{id}` (§7.8): a [DoctorCard] plus the profile fields.
class DoctorDetail {
  const DoctorDetail({
    required this.card,
    required this.slotLengthMin,
    required this.version,
    this.bio,
    this.room,
    this.expectedConsultMinutes,
  });

  final DoctorCard card;
  final String? bio;
  final String? room;
  final int slotLengthMin;
  final int? expectedConsultMinutes;
  final int version;

  String get id => card.id;
  String get name => card.name;
}
