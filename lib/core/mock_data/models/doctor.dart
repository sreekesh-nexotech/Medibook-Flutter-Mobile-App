import '../../utils/money.dart';
import 'hospital.dart';

/// A doctor shown in booking, search, doctor detail and appointment cards.
///
/// Presentation view-model — immutable, no logic. Maps onto the future
/// `domain/entities` Doctor entity. [imageAsset] is null for doctors without a
/// portrait; the UI falls back to initials (a deliberate, shipped state, since
/// 5 of 6 seeded doctors have no photo).
///
/// ## Two storage fixes, no display changes
///
/// * **Money** (audit §3.8.2). The fee is stored as [feePaise] — an integer in
///   minor units — so it can be added to a tax and a convenience fee
///   ([FeeBreakdown]). The old display API survives as `String get fee`, so
///   every existing call site (`doctor.fee` on the doctor card, the confirm
///   summary and the detail stat row) compiles and renders identically.
/// * **Hospital identity.** The facility is stored as [hospitalId] and the
///   name is derived through [Hospitals.nameOf], so one facility has one name.
///   `String get hospital` is unchanged for callers.
class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    required this.department,
    required this.spec,
    required this.title,
    required this.experience,
    required this.patients,
    required this.rating,
    required this.feePaise,
    required this.hospitalId,
    required this.about,
    this.imageAsset,
  });

  final String id;
  final String name;

  /// Department key (matches a [Department.name]).
  final String department;

  /// Specialty label ("Cardiologist").
  final String spec;

  /// Role/title ("Head of Cardiology").
  final String title;

  /// Years of experience, display string ("12 yrs").
  final String experience;

  /// Patients treated, display string ("6,000+").
  final String patients;

  /// Rating out of 5.
  final double rating;

  /// Consultation fee in **paise** — real money, totalable and comparable.
  final int feePaise;

  /// Id of the facility this doctor practises at (see [Hospitals]).
  final String hospitalId;

  final String about;

  /// Local asset path for the portrait, or null → initials fallback.
  final String? imageAsset;

  /// The consultation fee as a [Money] value — use this for arithmetic.
  Money get consultationFee => Money.paise(feePaise);

  /// Consultation fee, display string ("₹900").
  ///
  /// Unchanged public API: screens that rendered `doctor.fee` keep working.
  String get fee => Money.inr(feePaise);

  /// The facility's display name, derived from [hospitalId].
  String get hospital => Hospitals.nameOf(hospitalId);

  /// The full facility record, for the hospital detail link (CM-25).
  Hospital get hospitalDetails => Hospitals.byId(hospitalId);

  Doctor copyWith({
    String? id,
    String? name,
    String? department,
    String? spec,
    String? title,
    String? experience,
    String? patients,
    double? rating,
    int? feePaise,
    String? hospitalId,
    String? about,
    String? imageAsset,
  }) {
    return Doctor(
      id: id ?? this.id,
      name: name ?? this.name,
      department: department ?? this.department,
      spec: spec ?? this.spec,
      title: title ?? this.title,
      experience: experience ?? this.experience,
      patients: patients ?? this.patients,
      rating: rating ?? this.rating,
      feePaise: feePaise ?? this.feePaise,
      hospitalId: hospitalId ?? this.hospitalId,
      about: about ?? this.about,
      imageAsset: imageAsset ?? this.imageAsset,
    );
  }
}
