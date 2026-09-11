import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/models/medical_record.dart';
import '../../../../core/mock_data/stores/dependants_store.dart';
import '../../../../core/mock_data/stores/documents_store.dart';
import '../../../../core/utils/date_utils.dart';
import 'linkable_appointments_provider.dart';

/// The filter set applied to the documents library (CM-34).
///
/// Immutable, and every field is a **typed** value — `Set<DocumentType>`,
/// patient id, real `DateTime` bounds, appointment id. Matching therefore runs
/// against [MedicalRecord.recordedAt] and [MedicalRecord.type], never against
/// the rendered date/type strings, which was audit §3.8.3.
class DocumentFilters {
  const DocumentFilters({
    this.types = const <DocumentType>{},
    this.patientId,
    this.from,
    this.to,
    this.appointmentId,
  });

  /// Selected document types. Empty means "every type".
  final Set<DocumentType> types;

  /// Selected patient (`Patient.id`), or null for "everyone".
  final String? patientId;

  /// Inclusive lower bound on [MedicalRecord.recordedAt] (day granularity).
  final DateTime? from;

  /// Inclusive upper bound on [MedicalRecord.recordedAt] (day granularity).
  final DateTime? to;

  /// Only documents attached to this appointment, or null for "any".
  final String? appointmentId;

  bool get hasDateRange => from != null || to != null;

  bool get isActive =>
      types.isNotEmpty ||
      patientId != null ||
      hasDateRange ||
      appointmentId != null;

  /// How many removable chips the list renders — one per type, plus one each
  /// for patient, date range and appointment.
  int get activeCount =>
      types.length +
      (patientId == null ? 0 : 1) +
      (hasDateRange ? 1 : 0) +
      (appointmentId == null ? 0 : 1);

  /// "10 Jul 2026 – 12 Aug 2026", "From 10 Jul 2026", "Until 12 Aug 2026".
  String get dateRangeLabel {
    final start = from;
    final end = to;
    if (start != null && end != null) {
      return '${AppDates.dayMonthYear(start)} – ${AppDates.dayMonthYear(end)}';
    }
    if (start != null) return 'From ${AppDates.dayMonthYear(start)}';
    if (end != null) return 'Until ${AppDates.dayMonthYear(end)}';
    return 'Any date';
  }

  /// Whether [document] survives this filter set.
  bool matches(MedicalRecord document) {
    if (types.isNotEmpty && !types.contains(document.type)) return false;
    if (patientId != null && document.patientId != patientId) return false;
    if (appointmentId != null && document.appointmentId != appointmentId) {
      return false;
    }
    final start = from;
    if (start != null &&
        document.recordedAt.isBefore(AppDates.startOfDay(start))) {
      return false;
    }
    final end = to;
    if (end != null && document.recordedAt.isAfter(AppDates.endOfDay(end))) {
      return false;
    }
    return true;
  }

  /// [clearPatient] / [clearDateRange] / [clearAppointment] exist because a
  /// null argument cannot distinguish "leave it alone" from "unset it".
  DocumentFilters copyWith({
    Set<DocumentType>? types,
    String? patientId,
    bool clearPatient = false,
    DateTime? from,
    DateTime? to,
    bool clearDateRange = false,
    String? appointmentId,
    bool clearAppointment = false,
  }) {
    return DocumentFilters(
      types: types ?? this.types,
      patientId: clearPatient ? null : (patientId ?? this.patientId),
      from: clearDateRange ? null : (from ?? this.from),
      to: clearDateRange ? null : (to ?? this.to),
      appointmentId: clearAppointment
          ? null
          : (appointmentId ?? this.appointmentId),
    );
  }
}

/// Owns [DocumentFilters] for the Records list. Every mutation produces a new
/// immutable state — nothing is mutated in place.
class DocumentsFilterController extends StateNotifier<DocumentFilters> {
  DocumentsFilterController() : super(const DocumentFilters());

  void toggleType(DocumentType type) {
    final next = {...state.types};
    if (!next.remove(type)) next.add(type);
    state = state.copyWith(types: next);
  }

  void removeType(DocumentType type) {
    if (!state.types.contains(type)) return;
    state = state.copyWith(types: {...state.types}..remove(type));
  }

  void setTypes(Set<DocumentType> types) =>
      state = state.copyWith(types: {...types});

  void setPatient(String? patientId) => patientId == null
      ? state = state.copyWith(clearPatient: true)
      : state = state.copyWith(patientId: patientId);

  void setDateRange({DateTime? from, DateTime? to}) {
    // Both null means "clear"; a single bound is a valid open-ended range.
    if (from == null && to == null) {
      state = state.copyWith(clearDateRange: true);
      return;
    }
    state = state.copyWith(clearDateRange: true).copyWith(from: from, to: to);
  }

  void clearDateRange() => state = state.copyWith(clearDateRange: true);

  void setAppointment(String? appointmentId) => appointmentId == null
      ? state = state.copyWith(clearAppointment: true)
      : state = state.copyWith(appointmentId: appointmentId);

  void clearAll() => state = const DocumentFilters();
}

/// The Records list's filter state. `autoDispose` — it is transient UI state
/// scoped to the screen, not account data.
final documentsFilterProvider =
    StateNotifierProvider.autoDispose<
      DocumentsFilterController,
      DocumentFilters
    >((ref) => DocumentsFilterController());

/// The documents the Records list renders: newest first (on `recordedAt`) with
/// [documentsFilterProvider] applied. Filtering lives here rather than in
/// `build()` so the screen only reads state.
final filteredDocumentsProvider = Provider.autoDispose<List<MedicalRecord>>((
  ref,
) {
  final documents = ref.watch(sortedDocumentsProvider);
  final filters = ref.watch(documentsFilterProvider);
  if (!filters.isActive) return documents;
  return documents.where(filters.matches).toList();
});

/// Which facet of [DocumentFilters] an active chip stands for, so removing a
/// chip drops exactly that facet and leaves the others alone.
enum DocumentFilterField {
  type('Type'),
  patient('Patient'),
  dateRange('Date'),
  appointment('Appointment');

  const DocumentFilterField(this.label);

  final String label;
}

/// One removable chip above the documents list (CM-34).
///
/// [type] is set only on a type chip — the type set can hold several values and
/// each gets its own chip, so the row needs to know which one to remove.
class DocumentFilterChip {
  const DocumentFilterChip({
    required this.field,
    required this.label,
    this.type,
  });

  final DocumentFilterField field;

  /// What the chip shows after the field label ("Lab Report", "Ava Thomas").
  final String label;

  /// The single type this chip removes, for [DocumentFilterField.type].
  final DocumentType? type;
}

/// The active filters as display chips, with the patient name and appointment
/// label resolved. Empty when nothing is filtered, so the row costs no space.
///
/// Resolving the names here rather than in `build()` keeps the screen reading
/// state only, and keeps the chip labels in step with the stores they came
/// from (a renamed dependant renames its chip).
final documentFilterChipsProvider =
    Provider.autoDispose<List<DocumentFilterChip>>((ref) {
      final filters = ref.watch(documentsFilterProvider);
      if (!filters.isActive) return const <DocumentFilterChip>[];

      final chips = <DocumentFilterChip>[
        for (final type in DocumentType.values)
          if (filters.types.contains(type))
            DocumentFilterChip(
              field: DocumentFilterField.type,
              label: type.label,
              type: type,
            ),
      ];

      final patientId = filters.patientId;
      if (patientId != null) {
        final patient = ref.watch(patientByIdProvider(patientId));
        chips.add(
          DocumentFilterChip(
            field: DocumentFilterField.patient,
            label: patient?.name ?? 'Unknown patient',
          ),
        );
      }

      if (filters.hasDateRange) {
        chips.add(
          DocumentFilterChip(
            field: DocumentFilterField.dateRange,
            label: filters.dateRangeLabel,
          ),
        );
      }

      final appointmentId = filters.appointmentId;
      if (appointmentId != null) {
        final appointment = ref.watch(
          linkableAppointmentByIdProvider(appointmentId),
        );
        chips.add(
          DocumentFilterChip(
            field: DocumentFilterField.appointment,
            label: appointment?.label ?? 'Linked visit',
          ),
        );
      }

      return chips;
    });
