import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/models/medical_record.dart';
import '../../../../core/mock_data/models/patient.dart';
import '../../../../core/mock_data/stores/dependants_store.dart';
import '../../../../core/mock_data/stores/documents_store.dart';

/// The fields the document form validates. Used to track which ones the user
/// has actually visited, so a fresh form is not covered in red.
enum DocumentFormField { title, recordedAt }

/// Immutable state of the upload / edit document form (CM-33, CM-35).
class DocumentFormState {
  const DocumentFormState({
    required this.title,
    required this.type,
    required this.patientId,
    required this.recordedAt,
    required this.notes,
    this.appointmentId,
    this.appointmentLabel,
    this.doctorName = '',
    this.hospitalName = '',
    this.touched = const <DocumentFormField>{},
    this.submitAttempted = false,
    this.isSaving = false,
    this.isDirty = false,
  });

  final String title;
  final DocumentType type;

  /// The patient this document belongs to (`Patient.id`).
  final String patientId;

  /// When the test / consultation happened — a real `DateTime`, never a label.
  final DateTime recordedAt;
  final String notes;

  /// The appointment this document is attached to, when the user linked one.
  final String? appointmentId;

  /// Display label for the linked appointment ("Dr. Anil Kumar · 10 Jul 2026").
  final String? appointmentLabel;

  /// Doctor / facility, derived from the linked appointment rather than typed.
  final String doctorName;
  final String hospitalName;

  final Set<DocumentFormField> touched;
  final bool submitAttempted;
  final bool isSaving;

  /// True once the user has changed something — drives the unsaved-work guard.
  final bool isDirty;

  String? get titleError {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return 'Enter a title so you can find this later';
    if (trimmed.length < 3) return 'Use at least 3 characters';
    return null;
  }

  /// A document cannot have been recorded in the future. The picker also caps
  /// at today; this is the belt to that braces.
  String? dateError({DateTime? now}) {
    final reference = now ?? DateTime.now();
    if (recordedAt.isAfter(reference)) {
      return 'A document date cannot be in the future';
    }
    return null;
  }

  bool get isValid => titleError == null && dateError() == null;

  /// Whether [field]'s error should be visible: after a submit attempt, or
  /// once the user has left the field. The error text itself is always
  /// recomputed from the current value, so it clears only when actually fixed
  /// (audit §3.5.4).
  bool showErrorFor(DocumentFormField field) =>
      submitAttempted || touched.contains(field);

  DocumentFormState copyWith({
    String? title,
    DocumentType? type,
    String? patientId,
    DateTime? recordedAt,
    String? notes,
    String? appointmentId,
    String? appointmentLabel,
    bool clearAppointment = false,
    String? doctorName,
    String? hospitalName,
    Set<DocumentFormField>? touched,
    bool? submitAttempted,
    bool? isSaving,
    bool? isDirty,
  }) {
    return DocumentFormState(
      title: title ?? this.title,
      type: type ?? this.type,
      patientId: patientId ?? this.patientId,
      recordedAt: recordedAt ?? this.recordedAt,
      notes: notes ?? this.notes,
      appointmentId: clearAppointment
          ? null
          : (appointmentId ?? this.appointmentId),
      appointmentLabel: clearAppointment
          ? null
          : (appointmentLabel ?? this.appointmentLabel),
      doctorName: clearAppointment ? '' : (doctorName ?? this.doctorName),
      hospitalName: clearAppointment ? '' : (hospitalName ?? this.hospitalName),
      touched: touched ?? this.touched,
      submitAttempted: submitAttempted ?? this.submitAttempted,
      isSaving: isSaving ?? this.isSaving,
      isDirty: isDirty ?? this.isDirty,
    );
  }
}

/// Drives the upload form (`/documents/upload`) and the edit sheet on the
/// document detail screen.
///
/// The UI only reads [state] and calls these methods; validation, defaults and
/// the write to `documentsStoreProvider` all live here. No `BuildContext`
/// crosses this boundary, and nothing here navigates or shows a toast — the
/// screen does that with what [save] returns.
class DocumentFormController extends StateNotifier<DocumentFormState> {
  DocumentFormController(this._ref, {MedicalRecord? existing, Patient? patient})
    : _existingId = existing?.id,
      super(
        DocumentFormState(
          title: existing?.title ?? '',
          type: existing?.type ?? DocumentType.labReport,
          patientId: existing?.patientId ?? patient?.id ?? '',
          recordedAt: existing?.recordedAt ?? DateTime.now(),
          notes: existing?.notes ?? '',
          appointmentId: existing?.appointmentId,
          doctorName: existing?.doctor ?? '',
          hospitalName: existing?.hospital ?? '',
        ),
      );

  final Ref _ref;

  /// Null when the form is creating a document rather than editing one.
  final String? _existingId;

  bool get isEditing => _existingId != null;

  void setTitle(String value) =>
      state = state.copyWith(title: value, isDirty: true);

  void setType(DocumentType type) =>
      state = state.copyWith(type: type, isDirty: true);

  void setPatient(String patientId) =>
      state = state.copyWith(patientId: patientId, isDirty: true);

  void setRecordedAt(DateTime day) =>
      state = state.copyWith(recordedAt: day, isDirty: true);

  void setNotes(String value) =>
      state = state.copyWith(notes: value, isDirty: true);

  /// Link (or unlink) an appointment. The caller resolves the label, doctor and
  /// facility from the appointment so this controller stays free of the
  /// appointments feature.
  void setAppointment(
    String? appointmentId, {
    String? label,
    String? doctorName,
    String? hospitalName,
  }) {
    if (appointmentId == null) {
      state = state.copyWith(clearAppointment: true, isDirty: true);
      return;
    }
    state = state.copyWith(
      appointmentId: appointmentId,
      appointmentLabel: label,
      doctorName: doctorName ?? '',
      hospitalName: hospitalName ?? '',
      isDirty: true,
    );
  }

  /// Record that the user has left [field], so its error may show.
  void markTouched(DocumentFormField field) {
    if (state.touched.contains(field)) return;
    state = state.copyWith(touched: {...state.touched, field});
  }

  /// Reveal every error. Returns whether the form is submittable.
  bool validate() {
    state = state.copyWith(submitAttempted: true);
    return state.isValid;
  }

  /// Validate and write. Returns the stored document, or null when the form is
  /// invalid or a save is already in flight (so a double tap cannot write
  /// twice — audit §3.5.6).
  ///
  /// Async by contract: when the repository lands, the two store calls below
  /// become awaited repository calls and nothing else changes.
  Future<MedicalRecord?> save() async {
    if (state.isSaving) return null;
    if (!validate()) return null;

    state = state.copyWith(isSaving: true);
    final store = _ref.read(documentsStoreProvider.notifier);
    final patient = _ref
        .read(dependantsStoreProvider.notifier)
        .byId(state.patientId);
    final title = state.title.trim();
    final notes = state.notes.trim();

    final existingId = _existingId;
    final MedicalRecord? saved;
    if (existingId == null) {
      saved = store.add(
        title: title,
        type: state.type,
        patient: patient?.name ?? '',
        patientId: state.patientId.isEmpty ? null : state.patientId,
        hospital: state.hospitalName,
        doctor: state.doctorName,
        appointmentId: state.appointmentId,
        notes: notes.isEmpty ? null : notes,
        recordedAt: state.recordedAt,
      );
    } else {
      // `DocumentsStore.patch` covers title / type / patient / notes only, so
      // the date and appointment link are locked once created — the form
      // renders those two fields disabled with that reason rather than
      // pretending to save them.
      store.patch(
        existingId,
        title: title,
        type: state.type,
        notes: notes,
        patientId: state.patientId,
        patient: patient?.name,
      );
      saved = store.byId(existingId);
    }

    state = state.copyWith(isSaving: false, isDirty: false);
    return saved;
  }
}

/// The document form, keyed by the document id being edited — pass null to
/// create. `autoDispose` because a form is transient UI state: leaving the
/// screen must not leave a half-typed draft behind.
final documentFormProvider = StateNotifierProvider.autoDispose
    .family<DocumentFormController, DocumentFormState, String?>((
      ref,
      documentId,
    ) {
      final existing = documentId == null
          ? null
          : ref.read(documentsStoreProvider.notifier).byId(documentId);
      // Default to the account holder, so "who is this for" starts answered.
      final self = ref.read(selfPatientProvider);
      return DocumentFormController(ref, existing: existing, patient: self);
    });
