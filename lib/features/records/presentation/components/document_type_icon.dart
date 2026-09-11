import '../../../../core/mock_data/models/medical_record.dart';
import '../../../../core/widgets/app_icon.dart';

/// The one place a [DocumentType] maps to a glyph, so the record card, the
/// type picker, the filter chips and the document detail all show the same
/// icon for the same kind of document.
abstract final class DocumentTypeIcon {
  DocumentTypeIcon._();

  /// A [MedIcon] name for [type].
  static String of(DocumentType type) => switch (type) {
    DocumentType.labReport => MedIcon.records,
    DocumentType.prescription => MedIcon.edit,
    DocumentType.scan => MedIcon.eye,
    DocumentType.dischargeSummary => MedIcon.hospital,
    DocumentType.invoice => MedIcon.bag,
    DocumentType.other => MedIcon.records,
  };
}
