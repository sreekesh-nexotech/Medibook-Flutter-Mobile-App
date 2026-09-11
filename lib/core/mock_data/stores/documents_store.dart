import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../medibook_seed.dart';
import '../models/medical_record.dart';

/// Owns the account's health documents (CM-32 … CM-36).
///
/// **Why this is a shared store rather than a feature controller:** the Records
/// tab lists and uploads them, and the Appointment detail screen shows the
/// prescription and invoice attached to that visit. One list, two features.
///
/// Note the honesty boundary: this store manages document *records*. There is
/// no file picker, no PDF renderer and no share sheet in this build, so the
/// upload flow records metadata and the preview/download controls must use
/// `showStubbedToast` from `core/widgets/app_stub_notice.dart` rather than
/// pretend (audit §4.1).
class DocumentsStore extends Notifier<List<MedicalRecord>> {
  @override
  List<MedicalRecord> build() => MedibookSeed.records;

  /// Newest first — the order the Records list renders.
  List<MedicalRecord> get sorted {
    final items = [...state]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return items;
  }

  MedicalRecord? byId(String id) {
    for (final document in state) {
      if (document.id == id) return document;
    }
    return null;
  }

  /// Documents for one patient.
  List<MedicalRecord> forPatient(String patientId) =>
      state.where((d) => d.patientId == patientId).toList();

  /// Documents of one type — the filter chips.
  List<MedicalRecord> ofType(DocumentType type) =>
      state.where((d) => d.type == type).toList();

  /// Documents attached to one appointment (prescription, invoice).
  List<MedicalRecord> forAppointment(String appointmentId) =>
      state.where((d) => d.appointmentId == appointmentId).toList();

  /// Record an uploaded document (CM-33). Returns the stored record.
  ///
  /// [fileSizeBytes] and [fileName] come from whatever picked the file; pass
  /// `0` / `''` when there is no file, and the record correctly reports
  /// `hasFile == false` rather than offering a download that cannot work.
  MedicalRecord add({
    required String title,
    required DocumentType type,
    required String patient,
    String? patientId,
    String hospital = '',
    String doctor = '',
    String? appointmentId,
    String? notes,
    String fileName = '',
    int fileSizeBytes = 0,
    DateTime? recordedAt,
  }) {
    final now = DateTime.now();
    final document = MedicalRecord(
      id: 'doc-${now.microsecondsSinceEpoch}',
      title: title,
      recordedAt: recordedAt ?? now,
      status: RecordStatus.completed,
      type: type,
      patient: patient,
      patientId: patientId,
      hospital: hospital,
      doctor: doctor,
      appointmentId: appointmentId,
      notes: notes,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      uploadedAt: now,
    );
    state = [document, ...state];
    return document;
  }

  /// Rename / re-file an existing document (CM-35).
  void patch(
    String id, {
    String? title,
    DocumentType? type,
    String? notes,
    String? patientId,
    String? patient,
  }) {
    state = [
      for (final d in state)
        if (d.id == id)
          d.copyWith(
            title: title,
            type: type,
            notes: notes,
            patientId: patientId,
            patient: patient,
          )
        else
          d,
    ];
  }

  /// Delete a document (CM-36). Returns false for an unknown id, so the caller
  /// does not report a success that did not happen.
  bool remove(String id) {
    if (byId(id) == null) return false;
    state = state.where((d) => d.id != id).toList();
    return true;
  }
}

/// The account's health documents. Not autoDispose — Records and Appointment
/// detail both read it.
final documentsStoreProvider =
    NotifierProvider<DocumentsStore, List<MedicalRecord>>(DocumentsStore.new);

/// Documents newest-first — what the Records list renders.
final sortedDocumentsProvider = Provider<List<MedicalRecord>>((ref) {
  final items = ref.watch(documentsStoreProvider);
  final sorted = [...items]
    ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  return sorted;
});

/// One document by id. autoDispose family — ids are minted at runtime.
final documentByIdProvider = Provider.autoDispose
    .family<MedicalRecord?, String>((ref, id) {
      final items = ref.watch(documentsStoreProvider);
      for (final document in items) {
        if (document.id == id) return document;
      }
      return null;
    });

/// Documents attached to one appointment. autoDispose family.
final documentsForAppointmentProvider = Provider.autoDispose
    .family<List<MedicalRecord>, String>((ref, appointmentId) {
      final items = ref.watch(documentsStoreProvider);
      return items.where((d) => d.appointmentId == appointmentId).toList();
    });

/// Documents for one patient. autoDispose family.
final documentsForPatientProvider = Provider.autoDispose
    .family<List<MedicalRecord>, String>((ref, patientId) {
      final items = ref.watch(documentsStoreProvider);
      return items.where((d) => d.patientId == patientId).toList();
    });
