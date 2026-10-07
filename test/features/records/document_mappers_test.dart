import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/common/attachments/domain/entities/stored_file.dart';
import 'package:medibook/features/records/domain/entities/medical_document.dart';
import 'package:medibook/features/records/infrastructure/repositories/document_mappers.dart';

/// The §11.2 `Document` shape in, the POST / PATCH bodies out.
void main() {
  final sample = <String, Object?>{
    'id': 'doc-1',
    'person_id': 'person-1',
    'appointment_id': null,
    'doc_type': 'vaccination',
    'title': 'CBC — Sept 2026',
    'document_date': '2026-09-21',
    'notes': null,
    'file': {
      'id': 'file-1',
      'original_name': 'blood-test.pdf',
      'mime': 'application/pdf',
      'size_bytes': 182044,
      'status': 'clean',
    },
    'version': 1,
    'created_at': '2026-09-30T08:09:04.204384+00:00',
    'updated_at': '2026-09-30T08:09:04.204384+00:00',
  };

  test('decodes the documented Document shape, including vaccination', () {
    final doc = DocumentMappers.fromJson(sample);
    expect(doc.id, 'doc-1');
    expect(doc.personId, 'person-1');
    expect(doc.docType, DocumentType.vaccination);
    expect(doc.documentDate, DateTime(2026, 9, 21));
    expect(doc.file.id, 'file-1');
    expect(doc.file.status, FileStatus.clean);
    expect(doc.file.sizeBytes, 182044);
    expect(doc.version, 1);
    expect(doc.createdAt, isNotNull);
    expect(doc.hasNotes, isFalse);
  });

  test('an unknown doc_type falls back to other rather than throwing', () {
    final doc = DocumentMappers.fromJson({...sample, 'doc_type': 'xray'});
    expect(doc.docType, DocumentType.other);
  });

  test('a document without a file is a format error (nothing is cached)', () {
    expect(
      () => DocumentMappers.fromJson({...sample, 'file': null}),
      throwsA(isA<ResponseFormatException>()),
    );
  });

  test('every DocumentType round-trips its wire value', () {
    for (final type in DocumentType.values) {
      expect(DocumentType.fromWire(type.wire), type);
    }
    expect(DocumentType.values.map((t) => t.wire), [
      'lab_report',
      'prescription',
      'scan',
      'discharge_summary',
      'invoice',
      'vaccination',
      'other',
    ]);
  });

  test('the POST body sends only the documented fields', () {
    final body = DocumentMappers.draftToJson(
      DocumentDraft(
        fileId: 'file-1',
        personId: 'person-1',
        docType: DocumentType.labReport,
        title: 'CBC',
        documentDate: DateTime(2026, 9, 21),
        notes: '  ',
      ),
    );
    expect(body, {
      'file_id': 'file-1',
      'person_id': 'person-1',
      'doc_type': 'lab_report',
      'title': 'CBC',
      'document_date': '2026-09-21',
    });
  });

  test('the PATCH body carries only the changed subset and explicit nulls', () {
    final body = DocumentMappers.patchToJson(
      const DocumentPatch(
        title: 'New',
        clearNotes: true,
        clearAppointment: true,
      ),
    );
    expect(body, {'title': 'New', 'notes': null, 'appointment_id': null});
    expect(const DocumentPatch().isEmpty, isTrue);
  });

  // BL-REC-014: the filtered heading read "Discharge Summarys".
  test('every document type has a spelled-out plural', () {
    expect(DocumentType.dischargeSummary.pluralLabel, 'Discharge Summaries');
    expect(DocumentType.labReport.pluralLabel, 'Lab Reports');
    expect(DocumentType.other.pluralLabel, 'Other documents');
    for (final type in DocumentType.values) {
      expect(type.pluralLabel, isNot(endsWith('ys')), reason: type.name);
    }
  });
}
