import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../common/persons/application/providers/persons_read_provider.dart';
import 'records_provider.dart';
import '../states/documents_list_state.dart';
import '../../domain/entities/medical_document.dart';
import 'linkable_appointments_provider.dart';

/// Which facet of [DocumentFilters] an active chip stands for, so removing
/// a chip drops exactly that facet and leaves the others alone.
enum DocumentFilterField {
  type('Type'),
  patient('Patient'),
  dateRange('Date'),
  appointment('Appointment');

  const DocumentFilterField(this.label);

  final String label;
}

/// One removable chip above the documents list (CM-34).
class DocumentFilterChip {
  const DocumentFilterChip({required this.field, required this.label});

  final DocumentFilterField field;

  /// What the chip shows after the field label ("Lab Report", "Ava Thomas").
  final String label;
}

/// "10 Jul 2026 – 12 Aug 2026", "From 10 Jul 2026", "Until 12 Aug 2026".
String documentDateRangeLabel(DocumentFilters filters) {
  final start = filters.from;
  final end = filters.to;
  if (start != null && end != null) {
    return '${AppDates.dayMonthYear(start)} – ${AppDates.dayMonthYear(end)}';
  }
  if (start != null) return 'From ${AppDates.dayMonthYear(start)}';
  if (end != null) return 'Until ${AppDates.dayMonthYear(end)}';
  return 'Any date';
}

/// Person id → display name, from the read-only persons list. Empty until
/// the list has loaded; the UI falls back to a neutral label meanwhile.
final documentPersonNamesProvider = Provider.autoDispose<Map<String, String>>((
  ref,
) {
  final persons = ref.watch(personSummariesProvider).valueOrNull;
  if (persons == null) return const <String, String>{};
  return {for (final person in persons) person.id: person.fullName};
});

/// The active filters as display chips, with the person name and the
/// appointment label resolved. Empty when nothing is filtered.
final documentFilterChipsProvider =
    Provider.autoDispose<List<DocumentFilterChip>>((ref) {
      final filters = ref.watch(documentsFilterProvider);
      if (!filters.isActive) return const <DocumentFilterChip>[];

      final chips = <DocumentFilterChip>[];
      final type = filters.type;
      if (type != null) {
        chips.add(
          DocumentFilterChip(
            field: DocumentFilterField.type,
            label: type.label,
          ),
        );
      }

      final personId = filters.personId;
      if (personId != null) {
        final names = ref.watch(documentPersonNamesProvider);
        chips.add(
          DocumentFilterChip(
            field: DocumentFilterField.patient,
            label: names[personId] ?? 'One person',
          ),
        );
      }

      if (filters.hasDateRange) {
        chips.add(
          DocumentFilterChip(
            field: DocumentFilterField.dateRange,
            label: documentDateRangeLabel(filters),
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
            label: appointment?.fullLabel ?? 'Linked visit',
          ),
        );
      }

      return chips;
    });

/// The design's two sort pills, in order. The other orders the server offers
/// ("Recently added", "Title A–Z") are in the filter sheet's "Sort by".
const List<DocumentSort> kDocumentSorts = [
  DocumentSort.newestFirst,
  DocumentSort.oldestFirst,
];
