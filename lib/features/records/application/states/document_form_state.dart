import '../../../../core/error/failure.dart';
import '../../domain/entities/medical_document.dart';

/// The fields the document form validates, so a fresh form is not covered
/// in red before the user has visited anything.
enum DocumentFormField { title, documentDate, person, file }

/// Immutable state of the upload / edit document form (CM-33, CM-35).
class DocumentFormState {
  const DocumentFormState({
    required this.title,
    required this.docType,
    required this.personId,
    required this.documentDate,
    required this.notes,
    this.appointmentId,
    this.appointmentLabel,
    this.touched = const <DocumentFormField>{},
    this.submitAttempted = false,
    this.isSaving = false,
    this.isDirty = false,
    this.failure,
    this.serverErrors = const <String, String>{},
  });

  final String title;
  final DocumentType docType;

  /// Whose document — empty until chosen.
  final String personId;

  /// The day on the document — a real `DateTime`, never a label.
  final DateTime documentDate;
  final String notes;

  /// The appointment this document is attached to, when the user linked one.
  final String? appointmentId;

  /// Display label for the linked appointment ("Dr. Anil Kumar · 10 Jul").
  final String? appointmentLabel;

  final Set<DocumentFormField> touched;
  final bool submitAttempted;
  final bool isSaving;

  /// True once the user has changed something — drives the unsaved guard.
  final bool isDirty;

  /// The last save's failure, for the screen to show.
  final Failure? failure;

  /// Field errors the server returned (`file_id`, `person_id`,
  /// `appointment_id`, `title`…), keyed by wire name.
  final Map<String, String> serverErrors;

  String? get titleError {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return 'Enter a title so you can find this later';
    if (trimmed.length < 3) return 'Use at least 3 characters';
    if (trimmed.length > 200) return 'Keep the title under 200 characters';
    return serverErrors['title'];
  }

  String? get notesError =>
      notes.trim().length > 2000 ? 'Keep notes under 2000 characters' : null;

  /// A document cannot be dated in the future.
  String? dateError({DateTime? now}) {
    final reference = now ?? DateTime.now();
    if (documentDate.isAfter(reference)) {
      return 'A document date cannot be in the future';
    }
    return serverErrors['document_date'];
  }

  String? get personError {
    if (personId.isEmpty) return 'Choose who this document is for';
    return serverErrors['person_id'];
  }

  String? get appointmentError => serverErrors['appointment_id'];

  /// The file slot's error (create mode only). Passed in by the caller of
  /// [isValidWith] because the file lives in the attachment slot, not here.
  String? fileError({required bool hasFile, required bool needsFile}) {
    if (needsFile && !hasFile) return 'Choose a file to upload';
    return serverErrors['file_id'];
  }

  bool isValidWith({required bool hasFile, required bool needsFile}) =>
      titleError == null &&
      notesError == null &&
      dateError() == null &&
      personError == null &&
      appointmentError == null &&
      fileError(hasFile: hasFile, needsFile: needsFile) == null;

  /// Whether [field]'s error should be visible: after a submit attempt, or
  /// once the user has left the field.
  bool showErrorFor(DocumentFormField field) =>
      submitAttempted || touched.contains(field);

  DocumentFormState copyWith({
    String? title,
    DocumentType? docType,
    String? personId,
    DateTime? documentDate,
    String? notes,
    String? appointmentId,
    String? appointmentLabel,
    bool clearAppointment = false,
    Set<DocumentFormField>? touched,
    bool? submitAttempted,
    bool? isSaving,
    bool? isDirty,
    Failure? failure,
    bool clearFailure = false,
    Map<String, String>? serverErrors,
  }) {
    return DocumentFormState(
      title: title ?? this.title,
      docType: docType ?? this.docType,
      personId: personId ?? this.personId,
      documentDate: documentDate ?? this.documentDate,
      notes: notes ?? this.notes,
      appointmentId: clearAppointment
          ? null
          : (appointmentId ?? this.appointmentId),
      appointmentLabel: clearAppointment
          ? null
          : (appointmentLabel ?? this.appointmentLabel),
      touched: touched ?? this.touched,
      submitAttempted: submitAttempted ?? this.submitAttempted,
      isSaving: isSaving ?? this.isSaving,
      isDirty: isDirty ?? this.isDirty,
      failure: clearFailure ? null : (failure ?? this.failure),
      serverErrors: serverErrors ?? this.serverErrors,
    );
  }
}

/// State of the per-document actions (delete, open) on the detail screen.
class DocumentActionsState {
  const DocumentActionsState({
    this.isDeleting = false,
    this.isResolvingUrl = false,
    this.failure,
  });

  final bool isDeleting;
  final bool isResolvingUrl;
  final Failure? failure;

  bool get isBusy => isDeleting || isResolvingUrl;

  DocumentActionsState copyWith({
    bool? isDeleting,
    bool? isResolvingUrl,
    Failure? failure,
    bool clearFailure = false,
  }) => DocumentActionsState(
    isDeleting: isDeleting ?? this.isDeleting,
    isResolvingUrl: isResolvingUrl ?? this.isResolvingUrl,
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}
