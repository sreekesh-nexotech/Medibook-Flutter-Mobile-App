import '../../../../core/widgets/app_icon.dart';
import '../../domain/entities/medical_document.dart';

/// The one place a [DocumentType] maps to a glyph, so the record card, the
/// type picker, the filter chips and the document detail all show the same
/// icon for the same kind of document.
abstract final class DocumentTypeIcon {
  DocumentTypeIcon._();

  /// A [MedIcon] name for [type].
  static String of(DocumentType type) => switch (type) {
    DocumentType.labReport => PhIcon.folder,
    DocumentType.prescription => PhIcon.pencilSimple,
    DocumentType.scan => PhIcon.eye,
    DocumentType.dischargeSummary => PhIcon.firstAid,
    DocumentType.invoice => MedIcon.bag,
    DocumentType.vaccination => PhIcon.checkBold,
    DocumentType.other => PhIcon.folder,
  };
}
