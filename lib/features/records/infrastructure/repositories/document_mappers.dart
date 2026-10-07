import 'package:intl/intl.dart';

import '../../../../core/network/network_exceptions.dart';
import '../../../common/attachments/domain/entities/stored_file.dart';
import '../../domain/entities/medical_document.dart';

/// Wire ↔ entity for `/patient/documents` (§11.2). The only place the field
/// names are spelled. Decoders throw [ResponseFormatException] on a shape
/// that does not match, so the cache never stores a partial document.
abstract final class DocumentMappers {
  DocumentMappers._();

  static final DateFormat _day = DateFormat('yyyy-MM-dd');

  static MedicalDocument fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final personId = json['person_id'];
    final title = json['title'];
    final date = json['document_date'];
    final file = json['file'];
    if (id is! String ||
        id.isEmpty ||
        personId is! String ||
        title is! String ||
        date is! String ||
        file is! Map) {
      throw const ResponseFormatException(
        message:
            'document is missing id / person_id / title / '
            'document_date / file',
      );
    }
    final documentDate = DateTime.tryParse(date);
    if (documentDate == null) {
      throw ResponseFormatException(message: 'bad document_date "$date"');
    }
    return MedicalDocument(
      id: id,
      personId: personId,
      appointmentId: json['appointment_id'] as String?,
      docType: DocumentType.fromWire(json['doc_type'] as String?),
      title: title,
      documentDate: documentDate,
      notes: json['notes'] as String?,
      file: fileFromJson(file.cast<String, Object?>()),
      version: (json['version'] as num?)?.toInt() ?? 1,
      createdAt: _dateTime(json['created_at']),
      updatedAt: _dateTime(json['updated_at']),
    );
  }

  static DocumentFile fileFromJson(Map<String, Object?> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const ResponseFormatException(message: 'document.file has no id');
    }
    return DocumentFile(
      id: id,
      originalName: (json['original_name'] as String?) ?? '',
      mime: (json['mime'] as String?) ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      status: FileStatus.fromWire(json['status'] as String?),
    );
  }

  static Map<String, Object?> draftToJson(DocumentDraft draft) => {
    'file_id': draft.fileId,
    'person_id': draft.personId,
    'doc_type': draft.docType.wire,
    'title': draft.title,
    'document_date': day(draft.documentDate),
    // Unknown fields are rejected; optionals are only sent when present.
    'notes': ?_nullIfBlank(draft.notes),
    'appointment_id': ?draft.appointmentId,
  };

  static Map<String, Object?> patchToJson(DocumentPatch patch) => {
    if (patch.title != null) 'title': patch.title,
    if (patch.docType != null) 'doc_type': patch.docType!.wire,
    if (patch.personId != null) 'person_id': patch.personId,
    if (patch.documentDate != null) 'document_date': day(patch.documentDate!),
    if (patch.clearNotes)
      'notes': null
    else if (patch.notes != null)
      'notes': patch.notes,
    if (patch.clearAppointment)
      'appointment_id': null
    else if (patch.appointmentId != null)
      'appointment_id': patch.appointmentId,
  };

  /// `YYYY-MM-DD` for a date-only field.
  static String day(DateTime value) => _day.format(value);

  static DateTime? _dateTime(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static String? _nullIfBlank(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
