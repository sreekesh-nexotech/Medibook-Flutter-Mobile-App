import '../../utils/date_utils.dart';

/// Status of a health record (drives the Badge tone on the Records screen).
enum RecordStatus {
  completed('Completed'),
  pending('Pending');

  const RecordStatus(this.label);

  final String label;
}

/// What kind of document a record is (CM-32 … CM-36). Drives the leading icon
/// and the Records screen's filter chips.
enum DocumentType {
  labReport('Lab Report'),
  prescription('Prescription'),
  scan('Scan'),
  dischargeSummary('Discharge Summary'),
  invoice('Invoice'),
  other('Other');

  const DocumentType(this.label);

  final String label;
}

/// A lab/health record card on the Records screen, and the document behind it.
///
/// Presentation view-model — immutable, no logic.
///
/// ## Extended into a real document (CM-32 … CM-36)
///
/// The card used to be five display strings with a typed-in date. It now
/// carries the fields an upload/preview/download flow needs — [id], [type],
/// [patientId], [fileName], [fileSizeBytes], [uploadedAt], the optional
/// [notes] and [appointmentId] — and stores [recordedAt] as a real
/// [DateTime]. Every previously existing field and getter is unchanged,
/// `String get date` included, so `record_card.dart` and the Records screen
/// compile untouched.
///
/// [MedicalDocument] is a type alias for this class: the two names the audit
/// uses refer to one record, and aliasing avoids a parallel model that would
/// drift.
class MedicalRecord {
  const MedicalRecord({
    required this.id,
    required this.title,
    required this.recordedAt,
    required this.status,
    required this.patient,
    required this.hospital,
    required this.doctor,
    this.type = DocumentType.labReport,
    this.patientId,
    this.appointmentId,
    this.notes,
    this.fileName = '',
    this.fileSizeBytes = 0,
    DateTime? uploadedAt,
  }) : uploadedAt = uploadedAt ?? recordedAt;

  /// Stable id — what the document detail route and download address.
  final String id;

  final String title;

  /// When the test/consultation happened. Real instant, so the list sorts.
  final DateTime recordedAt;

  final RecordStatus status;

  /// Patient display name (unchanged; the screens render it directly).
  final String patient;

  /// The [Patient.id] this document belongs to, when known.
  final String? patientId;

  final String hospital;
  final String doctor;

  final DocumentType type;

  /// The appointment that produced this document, when there was one.
  final String? appointmentId;

  /// Free-text note the patient added on upload.
  final String? notes;

  /// Original file name ("blood-test-10jul2026.pdf"). Empty for records that
  /// exist as data rather than as a file.
  final String fileName;

  /// Size in bytes; 0 when there is no file.
  final int fileSizeBytes;

  /// When the file was added to the account (may differ from [recordedAt]).
  final DateTime uploadedAt;

  /// Display date ("10 Jul 2026"). Unchanged public API, now derived.
  String get date => AppDates.dayMonthYear(recordedAt);

  /// "10 Jul 2026" for the upload date.
  String get uploadedLabel => AppDates.dayMonthYear(uploadedAt);

  /// True when there is a file to preview or download.
  bool get hasFile => fileName.isNotEmpty && fileSizeBytes > 0;

  /// "1.2 MB" / "420 KB" / "—".
  String get fileSizeLabel {
    if (fileSizeBytes <= 0) return '—';
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).round()} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Lowercase extension without the dot ("pdf", "jpg"), or empty.
  String get fileExtension {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  MedicalRecord copyWith({
    String? id,
    String? title,
    DateTime? recordedAt,
    RecordStatus? status,
    String? patient,
    String? patientId,
    String? hospital,
    String? doctor,
    DocumentType? type,
    String? appointmentId,
    String? notes,
    String? fileName,
    int? fileSizeBytes,
    DateTime? uploadedAt,
  }) {
    return MedicalRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      recordedAt: recordedAt ?? this.recordedAt,
      status: status ?? this.status,
      patient: patient ?? this.patient,
      patientId: patientId ?? this.patientId,
      hospital: hospital ?? this.hospital,
      doctor: doctor ?? this.doctor,
      type: type ?? this.type,
      appointmentId: appointmentId ?? this.appointmentId,
      notes: notes ?? this.notes,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }
}

/// The name the audit and the CM-32 … CM-36 requirements use for a health
/// record. Same class — one record type, two names, no parallel model.
typedef MedicalDocument = MedicalRecord;
