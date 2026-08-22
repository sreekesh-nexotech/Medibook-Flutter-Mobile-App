/// Status of a health record (drives the Badge tone on the Records screen).
enum RecordStatus {
  completed('Completed'),
  pending('Pending');

  const RecordStatus(this.label);

  final String label;
}

/// A lab/health record card on the Records screen.
///
/// Presentation view-model — immutable, no logic.
class MedicalRecord {
  const MedicalRecord({
    required this.title,
    required this.date,
    required this.status,
    required this.patient,
    required this.hospital,
    required this.doctor,
  });

  final String title;

  /// Display date ("10 Jul 2026").
  final String date;

  final RecordStatus status;
  final String patient;
  final String hospital;
  final String doctor;
}
