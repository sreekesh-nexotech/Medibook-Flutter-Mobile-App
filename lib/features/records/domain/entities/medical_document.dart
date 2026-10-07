import '../../../common/attachments/domain/entities/stored_file.dart';

/// What kind of document a record is — the backend's seven `doc_type`
/// values (`FLUTTER_API_INTEGRATION.md` §11.2, §17).
enum DocumentType {
  labReport('lab_report', 'Lab Report', 'Lab Reports'),
  prescription('prescription', 'Prescription', 'Prescriptions'),
  scan('scan', 'Scan', 'Scans'),
  dischargeSummary(
    'discharge_summary',
    'Discharge Summary',
    'Discharge Summaries',
  ),
  invoice('invoice', 'Invoice', 'Invoices'),
  vaccination('vaccination', 'Vaccination', 'Vaccinations'),
  other('other', 'Other', 'Other documents');

  const DocumentType(this.wire, this.label, this.pluralLabel);

  /// The value on the wire.
  final String wire;

  /// What the user reads.
  final String label;

  /// The heading for a list of them. Spelled out: adding an "s" gave
  /// "Discharge Summarys" (BL-REC-014).
  final String pluralLabel;

  static DocumentType fromWire(String? value) {
    for (final type in values) {
      if (type.wire == value) return type;
    }
    return DocumentType.other;
  }
}

/// The earliest day a document date can be picked. The server accepts any
/// date; a record can be as old as the person it belongs to (a childhood
/// vaccination card), so the pickers reach back as far as a date of birth
/// does — 120 years.
DateTime earliestDocumentDate(DateTime now) => DateTime(now.year - 120, 1, 1);

/// How the library is ordered — every order the server offers (§11.2:
/// `document_date`, `created_at`, `title`; default newest `document_date`
/// first).
enum DocumentSort {
  newestFirst('-document_date', 'Newest', 'Recent Records'),
  oldestFirst('document_date', 'Oldest', 'Oldest First'),
  recentlyAdded('-created_at', 'Recently added', 'Recently Added'),
  titleAz('title', 'Title A–Z', 'Records A–Z');

  const DocumentSort(this.wire, this.label, this.heading);

  final String wire;
  final String label;

  /// The list heading while this order is on and no type is filtered —
  /// "Recent Records" only when the newest really are first.
  final String heading;
}

/// The file behind a document, as the document endpoints embed it.
class DocumentFile {
  const DocumentFile({
    required this.id,
    required this.originalName,
    required this.mime,
    required this.sizeBytes,
    required this.status,
  });

  final String id;
  final String originalName;
  final String mime;
  final int sizeBytes;
  final FileStatus status;

  /// Lowercase extension without the dot ("pdf", "jpg"), or empty.
  String get extension {
    final dot = originalName.lastIndexOf('.');
    if (dot == -1 || dot == originalName.length - 1) return '';
    return originalName.substring(dot + 1).toLowerCase();
  }

  bool get isImage => mime.startsWith('image/');
}

/// A medical document in the patient's library (§11.2 `Document`).
///
/// Immutable value object; the JSON mapping lives in the infrastructure
/// layer and presentation formatting in the screens.
class MedicalDocument {
  const MedicalDocument({
    required this.id,
    required this.personId,
    required this.docType,
    required this.title,
    required this.documentDate,
    required this.file,
    required this.version,
    this.appointmentId,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;

  /// Whose document — one of the account's persons.
  final String personId;

  /// The patient's own link to a visit; the hospital never sees it.
  final String? appointmentId;

  final DocumentType docType;
  final String title;

  /// The day on the document (`document_date`), at local midnight.
  final DateTime documentDate;
  final String? notes;
  final DocumentFile file;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasNotes => notes != null && notes!.trim().isNotEmpty;

  /// `updated_at`, when the document was changed after it was added — null
  /// for one never edited (the two stamps then sit within a minute).
  DateTime? get lastEditedAt {
    final updated = updatedAt;
    final created = createdAt;
    if (updated == null || created == null) return null;
    return updated.difference(created) > const Duration(minutes: 1)
        ? updated
        : null;
  }

  MedicalDocument copyWith({
    String? personId,
    String? appointmentId,
    bool clearAppointment = false,
    DocumentType? docType,
    String? title,
    DateTime? documentDate,
    String? notes,
    bool clearNotes = false,
    int? version,
  }) {
    return MedicalDocument(
      id: id,
      personId: personId ?? this.personId,
      appointmentId: clearAppointment
          ? null
          : (appointmentId ?? this.appointmentId),
      docType: docType ?? this.docType,
      title: title ?? this.title,
      documentDate: documentDate ?? this.documentDate,
      notes: clearNotes ? null : (notes ?? this.notes),
      file: file,
      version: version ?? this.version,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// The body of `POST /patient/documents`. The file must already be `clean`.
class DocumentDraft {
  const DocumentDraft({
    required this.fileId,
    required this.personId,
    required this.docType,
    required this.title,
    required this.documentDate,
    this.notes,
    this.appointmentId,
  });

  final String fileId;
  final String personId;
  final DocumentType docType;
  final String title;
  final DateTime documentDate;
  final String? notes;
  final String? appointmentId;
}

/// The body of `PATCH /patient/documents/{id}` — any subset except the file.
/// A null field means "leave it"; the `clear*` flags send an explicit null.
class DocumentPatch {
  const DocumentPatch({
    this.title,
    this.docType,
    this.personId,
    this.documentDate,
    this.notes,
    this.clearNotes = false,
    this.appointmentId,
    this.clearAppointment = false,
  });

  final String? title;
  final DocumentType? docType;
  final String? personId;
  final DateTime? documentDate;
  final String? notes;
  final bool clearNotes;
  final String? appointmentId;
  final bool clearAppointment;

  bool get isEmpty =>
      title == null &&
      docType == null &&
      personId == null &&
      documentDate == null &&
      notes == null &&
      !clearNotes &&
      appointmentId == null &&
      !clearAppointment;
}

/// The query behind `GET /patient/documents` (§11.2 filters + sort + page).
/// Only fields the endpoint lists exist here, so an unknown parameter can
/// never be sent (§1.7).
class DocumentQuery {
  const DocumentQuery({
    this.docType,
    this.personId,
    this.dateFrom,
    this.dateTo,
    this.appointmentId,
    this.search,
    this.sort = DocumentSort.newestFirst,
    this.page = 1,
    this.pageSize = 20,
  });

  final DocumentType? docType;
  final String? personId;

  /// Inclusive bounds on `document_date`, day granularity.
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? appointmentId;

  /// `q` — title search.
  final String? search;
  final DocumentSort sort;
  final int page;
  final int pageSize;

  bool get hasFilters =>
      docType != null ||
      personId != null ||
      dateFrom != null ||
      dateTo != null ||
      appointmentId != null ||
      (search != null && search!.isNotEmpty);

  DocumentQuery copyWith({int? page}) => DocumentQuery(
    docType: docType,
    personId: personId,
    dateFrom: dateFrom,
    dateTo: dateTo,
    appointmentId: appointmentId,
    search: search,
    sort: sort,
    page: page ?? this.page,
    pageSize: pageSize,
  );

  @override
  bool operator ==(Object other) =>
      other is DocumentQuery &&
      other.docType == docType &&
      other.personId == personId &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo &&
      other.appointmentId == appointmentId &&
      other.search == search &&
      other.sort == sort &&
      other.page == page &&
      other.pageSize == pageSize;

  @override
  int get hashCode => Object.hash(
    docType,
    personId,
    dateFrom,
    dateTo,
    appointmentId,
    search,
    sort,
    page,
    pageSize,
  );
}
