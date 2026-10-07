import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/providers/auth_provider.dart';
import '../../../../core/utils/date_utils.dart';
import 'appointments_provider.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/appointment_filter.dart';
import '../../domain/entities/person_summary.dart';
import 'appt_tab_controller.dart';

/// Holds the appointments-list filter (CM-28).
///
/// Every mutation returns a whole new [AppointmentFilter]; nothing is mutated
/// in place, so the list rebuilds from one immutable value — and, because the
/// filter is part of the list query, from one fresh request.
class AppointmentFilterController extends StateNotifier<AppointmentFilter> {
  AppointmentFilterController() : super(AppointmentFilter.none);

  void setDateRange({DateTime? from, DateTime? to}) {
    // Keep the range ordered whichever end the user picked first.
    final ordered = from != null && to != null && to.isBefore(from)
        ? (from: to, to: from)
        : (from: from, to: to);
    state = AppointmentFilter(
      from: ordered.from,
      to: ordered.to,
      doctorId: state.doctorId,
      hospitalId: state.hospitalId,
      personId: state.personId,
      statuses: state.statuses,
    );
  }

  void setDoctor(String? doctorId) => state = doctorId == null
      ? state.cleared(AppointmentFilterField.doctor)
      : state.copyWith(doctorId: doctorId);

  void setHospital(String? hospitalId) => state = hospitalId == null
      ? state.cleared(AppointmentFilterField.hospital)
      : state.copyWith(hospitalId: hospitalId);

  void setPerson(String? personId) => state = personId == null
      ? state.cleared(AppointmentFilterField.patient)
      : state.copyWith(personId: personId);

  void toggleStatus(AppointmentStatus status) =>
      state = state.toggledStatus(status);

  /// Remove one facet (one chip).
  void clearField(AppointmentFilterField field, {AppointmentStatus? status}) =>
      state = state.cleared(field, status: status);

  void clearAll() => state = AppointmentFilter.none;

  /// Replace the whole filter — what the filter surface's "Apply" does after
  /// editing a working copy.
  void replace(AppointmentFilter filter) => state = filter;
}

/// The live appointments filter.
///
/// **Deliberately not `autoDispose`.** A filter the patient set has to survive
/// opening the filter surface and tapping into an appointment and back; an
/// autoDispose filter silently resets in both cases, which reads as the app
/// losing their input. It is cleared explicitly instead.
final appointmentFilterProvider =
    StateNotifierProvider<AppointmentFilterController, AppointmentFilter>((
      ref,
    ) {
      // Per account: a new sign-in starts with no filter (QA Prompt 2 #21).
      ref.watch(currentUserProvider.select((u) => u?.id));
      return AppointmentFilterController();
    });

/// The statuses the Upcoming tab's status chips offer — the upcoming subset
/// of §17, since Completed and Canceled are fixed sets.
const List<AppointmentStatus> kUpcomingStatusOptions = [
  AppointmentStatus.pendingPayment,
  AppointmentStatus.pendingApproval,
  AppointmentStatus.scheduled,
  AppointmentStatus.checkedIn,
  AppointmentStatus.inConsultation,
];

/// What the filter surface offers in each picker.
///
/// Doctors and hospitals are drawn from the account's own appointments (the
/// rows loaded so far across every tab), not from the whole catalogue: a
/// filter row that can only ever return nothing is worse than no row at all.
typedef AppointmentFilterOptions = ({
  List<DoctorSummary> doctors,
  List<HospitalSummary> hospitals,
  List<PersonSummary> persons,
});

/// Doctors / hospitals seen in the three tabs' first pages, and the account's
/// family members (§6.1).
final appointmentFilterOptionsProvider =
    Provider.autoDispose<AppointmentFilterOptions>((ref) {
      final doctors = <String, DoctorSummary>{};
      final hospitals = <String, HospitalSummary>{};
      for (final tab in AppointmentTab.values) {
        final rows = ref.watch(
          appointmentsListProvider(
            AppointmentListQuery(tab: tab),
          ).select((s) => s.items),
        );
        for (final row in rows) {
          doctors[row.doctor.id] = row.doctor;
          hospitals[row.hospital.id] = row.hospital;
        }
      }
      final persons =
          ref.watch(appointmentPersonsProvider).valueOrNull ??
          const <PersonSummary>[];
      return (
        doctors: doctors.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
        hospitals: hospitals.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
        persons: persons,
      );
    });

/// The active facets as removable chips, with ids resolved to names where
/// the options list knows them.
final appointmentFilterChipsProvider =
    Provider.autoDispose<List<AppointmentFilterChip>>((ref) {
      // Only what applies on the open tab (BL-APPT-022).
      final filter = ref
          .watch(appointmentFilterProvider)
          .forTab(ref.watch(apptTabProvider));
      if (!filter.isActive) return const <AppointmentFilterChip>[];
      final options = ref.watch(appointmentFilterOptionsProvider);

      final chips = <AppointmentFilterChip>[];
      final dateLabel = dateRangeLabel(filter);
      if (dateLabel != null) {
        chips.add(
          AppointmentFilterChip(
            field: AppointmentFilterField.dateRange,
            label: dateLabel,
          ),
        );
      }
      final doctorId = filter.doctorId;
      if (doctorId != null) {
        chips.add(
          AppointmentFilterChip(
            field: AppointmentFilterField.doctor,
            label:
                options.doctors
                    .where((d) => d.id == doctorId)
                    .map((d) => d.name)
                    .firstOrNull ??
                'Selected doctor',
          ),
        );
      }
      final hospitalId = filter.hospitalId;
      if (hospitalId != null) {
        chips.add(
          AppointmentFilterChip(
            field: AppointmentFilterField.hospital,
            label:
                options.hospitals
                    .where((h) => h.id == hospitalId)
                    .map((h) => h.name)
                    .firstOrNull ??
                'Selected hospital',
          ),
        );
      }
      final personId = filter.personId;
      if (personId != null) {
        chips.add(
          AppointmentFilterChip(
            field: AppointmentFilterField.patient,
            label:
                options.persons
                    .where((p) => p.id == personId)
                    .map((p) => p.name)
                    .firstOrNull ??
                'Selected patient',
          ),
        );
      }
      for (final status in kUpcomingStatusOptions) {
        if (filter.statuses.contains(status)) {
          chips.add(
            AppointmentFilterChip(
              field: AppointmentFilterField.status,
              label: statusLabel(status),
              status: status,
            ),
          );
        }
      }
      return chips;
    });

/// `'12 Aug 2026 – 19 Aug 2026'`, or an open-ended variant, or null.
String? dateRangeLabel(AppointmentFilter filter) {
  final start = filter.from;
  final end = filter.to;
  if (start == null && end == null) return null;
  if (start != null && end != null) {
    if (AppDates.isSameDay(start, end)) return AppDates.dayMonthYear(start);
    return '${AppDates.dayMonth(start)} – ${AppDates.dayMonthYear(end)}';
  }
  if (start != null) return 'From ${AppDates.dayMonthYear(start)}';
  return 'Until ${AppDates.dayMonthYear(end!)}';
}

/// The design's pill wording for a backend status (§17's suggested mapping):
/// Confirmed ← scheduled / checked_in / in_consultation, plus the two
/// pre-confirmation states spelled out, and the three closed states.
String statusLabel(AppointmentStatus status) => switch (status) {
  AppointmentStatus.pendingPayment => 'Payment pending',
  AppointmentStatus.pendingApproval => 'Awaiting confirmation',
  AppointmentStatus.scheduled => 'Confirmed',
  AppointmentStatus.checkedIn => 'Checked in',
  AppointmentStatus.inConsultation => 'In consultation',
  AppointmentStatus.completed => 'Completed',
  AppointmentStatus.cancelled => 'Cancelled',
  AppointmentStatus.noShow => 'No-show',
};
