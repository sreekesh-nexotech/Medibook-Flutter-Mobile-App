import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/models/appointment.dart';
import '../../../../core/mock_data/models/doctor.dart';
import '../../../../core/mock_data/models/hospital.dart';
import '../../../../core/mock_data/models/patient.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../domain/entities/appointment_filter.dart';
import '../../domain/entities/appointment_status_view.dart';
import 'appointments_controller.dart';

/// Holds the appointments-list filter (CM-28).
///
/// Every mutation returns a whole new [AppointmentFilter]; nothing is mutated
/// in place, so the list rebuilds from one immutable value.
class AppointmentFilterController extends StateNotifier<AppointmentFilter> {
  AppointmentFilterController() : super(AppointmentFilter.none);

  void setDateRange({DateTime? from, DateTime? to}) {
    // Keep the range ordered whichever end the user picked first.
    if (from != null && to != null && to.isBefore(from)) {
      state = AppointmentFilter(
        from: to,
        to: from,
        doctorId: state.doctorId,
        hospitalId: state.hospitalId,
        patientId: state.patientId,
        statuses: state.statuses,
      );
      return;
    }
    state = AppointmentFilter(
      from: from,
      to: to,
      doctorId: state.doctorId,
      hospitalId: state.hospitalId,
      patientId: state.patientId,
      statuses: state.statuses,
    );
  }

  void setDoctor(String? doctorId) => state = doctorId == null
      ? state.cleared(AppointmentFilterField.doctor)
      : state.copyWith(doctorId: doctorId);

  void setHospital(String? hospitalId) => state = hospitalId == null
      ? state.cleared(AppointmentFilterField.hospital)
      : state.copyWith(hospitalId: hospitalId);

  void setPatient(String? patientId) => state = patientId == null
      ? state.cleared(AppointmentFilterField.patient)
      : state.copyWith(patientId: patientId);

  void toggleStatus(AppointmentStatusView status) =>
      state = state.toggledStatus(status);

  /// Remove one facet (one chip).
  void clearField(
    AppointmentFilterField field, {
    AppointmentStatusView? status,
  }) => state = state.cleared(field, status: status);

  void clearAll() => state = AppointmentFilter.none;

  /// Replace the whole filter — what the filter surface's "Apply" does after
  /// editing a working copy.
  void replace(AppointmentFilter filter) => state = filter;
}

/// The live appointments filter.
///
/// **Deliberately not `autoDispose`.** A filter the patient set has to survive
/// the two things they will do next: open the filter surface (a sheet, or the
/// pushed `/appointments/filter` screen, either of which can outlive the list's
/// own subscription) and tap into an appointment and come back. An autoDispose
/// filter silently resets in both cases, which reads as the app losing their
/// input. It is cleared explicitly instead — [AppointmentFilterController.clearAll],
/// wired to the "Clear all" control the chip row always shows.
final appointmentFilterProvider =
    StateNotifierProvider<AppointmentFilterController, AppointmentFilter>(
      (ref) => AppointmentFilterController(),
    );

/// The rows for one bucket, narrowed by the active filter. This is what the
/// list renders.
final filteredAppointmentRowsProvider = Provider.autoDispose
    .family<List<AppointmentRow>, AppointmentBucket>((ref, bucket) {
      final filter = ref.watch(appointmentFilterProvider);
      final rows = ref.watch(appointmentRowsInBucketProvider(bucket));
      if (!filter.isActive) return rows;
      return rows
          .where(
            (row) => filter.matches(
              row.appointment,
              status: row.status,
              resolvedHospitalId: row.hospitalId,
            ),
          )
          .toList();
    });

/// The active facets as removable chips, with ids resolved to names.
final appointmentFilterChipsProvider =
    Provider.autoDispose<List<AppointmentFilterChip>>((ref) {
      final filter = ref.watch(appointmentFilterProvider);
      if (!filter.isActive) return const <AppointmentFilterChip>[];

      final chips = <AppointmentFilterChip>[];

      final dateLabel = filter.dateRangeLabel;
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
            label: ref.watch(doctorByIdProvider(doctorId)).name,
          ),
        );
      }

      final hospitalId = filter.hospitalId;
      if (hospitalId != null) {
        chips.add(
          AppointmentFilterChip(
            field: AppointmentFilterField.hospital,
            label: ref.watch(hospitalByIdProvider(hospitalId)).name,
          ),
        );
      }

      final patientId = filter.patientId;
      if (patientId != null) {
        String? patientName;
        for (final patient in ref.watch(patientsProvider)) {
          if (patient.id == patientId) patientName = patient.name;
        }
        chips.add(
          AppointmentFilterChip(
            field: AppointmentFilterField.patient,
            label: patientName ?? 'Selected patient',
          ),
        );
      }

      for (final status in AppointmentStatusViews.all) {
        if (filter.statuses.contains(status)) {
          chips.add(
            AppointmentFilterChip(
              field: AppointmentFilterField.status,
              label: status.label,
              status: status,
            ),
          );
        }
      }

      return chips;
    });

/// What the filter surface offers in each picker.
///
/// Doctors and hospitals are drawn from the account's own appointments, not
/// from the whole catalogue: a filter row that can only ever return nothing is
/// worse than no row at all.
typedef AppointmentFilterOptions = ({
  List<Doctor> doctors,
  List<Hospital> hospitals,
  List<Patient> patients,
});

final appointmentFilterOptionsProvider =
    Provider.autoDispose<AppointmentFilterOptions>((ref) {
      final rows = ref.watch(appointmentRowsProvider);

      final doctors = <String, Doctor>{};
      final hospitals = <String, Hospital>{};
      final patientIds = <String>{};
      for (final row in rows) {
        doctors[row.doctor.id] = row.doctor;
        hospitals[row.hospitalId] = ref.watch(
          hospitalByIdProvider(row.hospitalId),
        );
        final patientId = row.appointment.patientId;
        if (patientId != null) patientIds.add(patientId);
      }

      final patients = ref
          .watch(patientsProvider)
          .where((patient) => patientIds.contains(patient.id))
          .toList();

      return (
        doctors: doctors.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
        hospitals: hospitals.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
        patients: patients,
      );
    });
