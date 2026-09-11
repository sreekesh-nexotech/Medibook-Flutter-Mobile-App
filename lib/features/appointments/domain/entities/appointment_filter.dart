import '../../../../core/mock_data/models/appointment.dart';
import '../../../../core/utils/date_utils.dart';
import 'appointment_status_view.dart';

/// Which part of the filter a chip stands for — so a chip can remove exactly
/// the facet it shows, instead of clearing everything.
enum AppointmentFilterField {
  dateRange('Dates'),
  doctor('Doctor'),
  hospital('Hospital'),
  status('Status'),
  patient('Patient');

  const AppointmentFilterField(this.label);

  final String label;
}

/// An active facet, ready to render as a removable chip.
class AppointmentFilterChip {
  const AppointmentFilterChip({
    required this.field,
    required this.label,
    this.status,
  });

  final AppointmentFilterField field;

  /// What the chip reads ("Dr. Anya Sharma", "12 Aug – 19 Aug").
  final String label;

  /// Set only for [AppointmentFilterField.status] chips, so removing one status
  /// does not drop the rest.
  final AppointmentStatusView? status;
}

/// The appointments list filter (CM-28).
///
/// The audit found *"Only Upcoming and Past. No filter by date range, doctor,
/// hospital, status or patient."* This is the missing state: an immutable value
/// object with one [matches] predicate, so the list, the filter surface and the
/// chip row can never disagree about what is being filtered.
///
/// The Upcoming/Past segmented tabs are deliberately **not** part of this — the
/// tab picks the bucket, the filter narrows within it, and both stay usable
/// together.
///
/// Dates are real [DateTime] day bounds, never display strings (audit §3.8.3).
class AppointmentFilter {
  const AppointmentFilter({
    this.from,
    this.to,
    this.doctorId,
    this.hospitalId,
    this.patientId,
    this.statuses = const <AppointmentStatusView>{},
  });

  /// Nothing selected — the default the list opens with.
  static const AppointmentFilter none = AppointmentFilter();

  /// Inclusive start of the date range (any time on that day counts).
  final DateTime? from;

  /// Inclusive end of the date range.
  final DateTime? to;

  final String? doctorId;
  final String? hospitalId;

  /// `Patient.id` — the dependant the appointment was booked for (CM-16).
  final String? patientId;

  /// Canonical statuses to keep. Empty means "any status in this bucket".
  final Set<AppointmentStatusView> statuses;

  bool get hasDateRange => from != null || to != null;

  bool get isActive =>
      hasDateRange ||
      doctorId != null ||
      hospitalId != null ||
      patientId != null ||
      statuses.isNotEmpty;

  /// How many facets are active — the badge on the Filters button.
  int get activeCount =>
      (hasDateRange ? 1 : 0) +
      (doctorId == null ? 0 : 1) +
      (hospitalId == null ? 0 : 1) +
      (patientId == null ? 0 : 1) +
      statuses.length;

  /// `'12 Aug 2026 – 19 Aug 2026'`, or an open-ended variant, or null.
  String? get dateRangeLabel {
    final start = from;
    final end = to;
    if (start == null && end == null) return null;
    if (start != null && end != null) {
      if (AppDates.isSameDay(start, end)) return AppDates.dayMonthYear(start);
      return '${AppDates.dayMonth(start)} – ${AppDates.dayMonthYear(end)}';
    }
    if (start != null) return 'From ${AppDates.dayMonthYear(start)}';
    return 'Until ${AppDates.dayMonthYear(end!)}';
  }

  /// Whether [appointment] (already resolved to [status] and [hospitalId])
  /// survives this filter.
  ///
  /// [resolvedHospitalId] is passed in because an appointment may carry its own
  /// `hospitalId` or inherit the doctor's — resolving that is the caller's job,
  /// and doing it here would drag the doctor catalogue into the domain.
  bool matches(
    Appointment appointment, {
    required AppointmentStatusView status,
    required String resolvedHospitalId,
  }) {
    if (statuses.isNotEmpty && !statuses.contains(status)) return false;
    if (doctorId != null && appointment.doctorId != doctorId) return false;
    if (hospitalId != null && resolvedHospitalId != hospitalId) return false;
    if (patientId != null && appointment.patientId != patientId) return false;

    final day = appointment.day;
    final start = from;
    final end = to;
    if (start != null && day.isBefore(AppDates.startOfDay(start))) return false;
    if (end != null && day.isAfter(AppDates.startOfDay(end))) return false;
    return true;
  }

  /// `copyWith` cannot clear a field, so clearing is explicit: pass the field
  /// to [cleared] (or use [clearAll]).
  AppointmentFilter copyWith({
    DateTime? from,
    DateTime? to,
    String? doctorId,
    String? hospitalId,
    String? patientId,
    Set<AppointmentStatusView>? statuses,
  }) {
    return AppointmentFilter(
      from: from ?? this.from,
      to: to ?? this.to,
      doctorId: doctorId ?? this.doctorId,
      hospitalId: hospitalId ?? this.hospitalId,
      patientId: patientId ?? this.patientId,
      statuses: statuses ?? this.statuses,
    );
  }

  /// This filter with [field] removed. For [AppointmentFilterField.status],
  /// [status] removes one status and null removes them all.
  AppointmentFilter cleared(
    AppointmentFilterField field, {
    AppointmentStatusView? status,
  }) {
    return switch (field) {
      AppointmentFilterField.dateRange => AppointmentFilter(
        doctorId: doctorId,
        hospitalId: hospitalId,
        patientId: patientId,
        statuses: statuses,
      ),
      AppointmentFilterField.doctor => AppointmentFilter(
        from: from,
        to: to,
        hospitalId: hospitalId,
        patientId: patientId,
        statuses: statuses,
      ),
      AppointmentFilterField.hospital => AppointmentFilter(
        from: from,
        to: to,
        doctorId: doctorId,
        patientId: patientId,
        statuses: statuses,
      ),
      AppointmentFilterField.patient => AppointmentFilter(
        from: from,
        to: to,
        doctorId: doctorId,
        hospitalId: hospitalId,
        statuses: statuses,
      ),
      AppointmentFilterField.status => AppointmentFilter(
        from: from,
        to: to,
        doctorId: doctorId,
        hospitalId: hospitalId,
        patientId: patientId,
        statuses:
            status == null ? const <AppointmentStatusView>{} : {...statuses}
              ..remove(status),
      ),
    };
  }

  /// [status] toggled in or out of the status set.
  AppointmentFilter toggledStatus(AppointmentStatusView status) {
    final next = {...statuses};
    if (!next.remove(status)) next.add(status);
    return copyWith(statuses: next);
  }

  @override
  bool operator ==(Object other) =>
      other is AppointmentFilter &&
      other.from == from &&
      other.to == to &&
      other.doctorId == doctorId &&
      other.hospitalId == hospitalId &&
      other.patientId == patientId &&
      other.statuses.length == statuses.length &&
      other.statuses.containsAll(statuses);

  @override
  int get hashCode => Object.hash(
    from,
    to,
    doctorId,
    hospitalId,
    patientId,
    Object.hashAllUnordered(statuses),
  );
}
