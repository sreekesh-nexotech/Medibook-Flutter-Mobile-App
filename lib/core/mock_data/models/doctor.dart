/// A doctor shown in booking, search, doctor detail and appointment cards.
///
/// Presentation view-model — immutable, no logic. Maps onto the future
/// `domain/entities` Doctor entity. [imageAsset] is null for doctors without a
/// portrait; the UI falls back to initials (a deliberate, shipped state, since
/// 5 of 6 seeded doctors have no photo).
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
    required this.fee,
    required this.hospital,
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

  /// Consultation fee, display string ("₹900").
  final String fee;

  final String hospital;
  final String about;

  /// Local asset path for the portrait, or null → initials fallback.
  final String? imageAsset;
}
