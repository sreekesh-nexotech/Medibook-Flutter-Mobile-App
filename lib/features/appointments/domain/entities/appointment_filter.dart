import 'appointment.dart';

/// The three Appointments tabs (§10.1): Upcoming = `bucket=upcoming`;
/// Completed = the past bucket minus the cancelled ones; Cancelled =
/// `status=cancelled,no_show`.
///
/// "Completed" is deliberately wider than `status=completed`: a paid visit
/// whose time has passed but that the desk never closed stays `scheduled`
/// on the server, is no longer in `bucket=upcoming`, and would otherwise be
/// in no tab at all. It is listed here with its real status on the pill.
enum AppointmentTab {
  upcoming('Upcoming'),
  completed('Completed'),
  cancelled('Canceled');

  const AppointmentTab(this.label);

  /// The pill label, as the design spells it.
  final String label;

  static AppointmentTab fromLabel(String label) {
    for (final tab in values) {
      if (tab.label == label) return tab;
    }
    return upcoming;
  }
}

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

  /// Set only for [AppointmentFilterField.status] chips, so removing one
  /// status does not drop the rest.
  final AppointmentStatus? status;
}

/// The appointments list filter (CM-28), expressed in the backend's own
/// query parameters (§10.1): `date_from` / `date_to` (on `scheduled_date`),
/// `doctor_id`, `hospital_id`, `person_id` and a `status` sub-set.
///
/// The Upcoming / Completed / Canceled tabs are deliberately **not** part of
/// this — the tab picks the bucket, the filter narrows within it, and both
/// stay usable together. Dates are calendar days, never display strings.
class AppointmentFilter {
  const AppointmentFilter({
    this.from,
    this.to,
    this.doctorId,
    this.hospitalId,
    this.personId,
    this.statuses = const <AppointmentStatus>{},
  });

  /// Nothing selected — the default the list opens with.
  static const AppointmentFilter none = AppointmentFilter();

  /// Inclusive start of the date range (hospital-local calendar day).
  final DateTime? from;

  /// Inclusive end of the date range.
  final DateTime? to;

  final String? doctorId;
  final String? hospitalId;

  /// `person_id` — the family member the appointment was booked for.
  final String? personId;

  /// Statuses to keep within the tab's own set. Empty means "any".
  final Set<AppointmentStatus> statuses;

  bool get hasDateRange => from != null || to != null;

  bool get isActive =>
      hasDateRange ||
      doctorId != null ||
      hospitalId != null ||
      personId != null ||
      statuses.isNotEmpty;

  /// How many facets are active — the badge on the Filters button.
  int get activeCount =>
      (hasDateRange ? 1 : 0) +
      (doctorId == null ? 0 : 1) +
      (hospitalId == null ? 0 : 1) +
      (personId == null ? 0 : 1) +
      statuses.length;

  /// This filter as it applies on [tab]. Status filters belong to the
  /// Upcoming tab only: elsewhere they are neither applied, shown as chips
  /// nor counted — and they come back on Upcoming (BL-APPT-022).
  AppointmentFilter forTab(AppointmentTab tab) {
    if (tab == AppointmentTab.upcoming || statuses.isEmpty) return this;
    return AppointmentFilter(
      from: from,
      to: to,
      doctorId: doctorId,
      hospitalId: hospitalId,
      personId: personId,
    );
  }

  AppointmentFilter copyWith({
    DateTime? from,
    DateTime? to,
    String? doctorId,
    String? hospitalId,
    String? personId,
    Set<AppointmentStatus>? statuses,
  }) {
    return AppointmentFilter(
      from: from ?? this.from,
      to: to ?? this.to,
      doctorId: doctorId ?? this.doctorId,
      hospitalId: hospitalId ?? this.hospitalId,
      personId: personId ?? this.personId,
      statuses: statuses ?? this.statuses,
    );
  }

  /// This filter with [field] removed. For [AppointmentFilterField.status],
  /// [status] removes one status and null removes them all.
  AppointmentFilter cleared(
    AppointmentFilterField field, {
    AppointmentStatus? status,
  }) {
    return switch (field) {
      AppointmentFilterField.dateRange => AppointmentFilter(
        doctorId: doctorId,
        hospitalId: hospitalId,
        personId: personId,
        statuses: statuses,
      ),
      AppointmentFilterField.doctor => AppointmentFilter(
        from: from,
        to: to,
        hospitalId: hospitalId,
        personId: personId,
        statuses: statuses,
      ),
      AppointmentFilterField.hospital => AppointmentFilter(
        from: from,
        to: to,
        doctorId: doctorId,
        personId: personId,
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
        personId: personId,
        statuses: status == null
            ? const <AppointmentStatus>{}
            : ({...statuses}..remove(status)),
      ),
    };
  }

  /// [status] toggled in or out of the status set.
  AppointmentFilter toggledStatus(AppointmentStatus status) {
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
      other.personId == personId &&
      other.statuses.length == statuses.length &&
      other.statuses.containsAll(statuses);

  @override
  int get hashCode => Object.hash(
    from,
    to,
    doctorId,
    hospitalId,
    personId,
    Object.hashAllUnordered(statuses),
  );
}

/// One list request (§10.1): a tab (or none, for a free-text search) plus the
/// narrowing filter and an optional `q`.
///
/// Value-equal, so it can key a provider family: two screens asking for the
/// same query share one list.
class AppointmentListQuery {
  const AppointmentListQuery({
    this.tab,
    this.filter = AppointmentFilter.none,
    this.q,
  });

  /// Null → no bucket / status constraint (search across everything).
  final AppointmentTab? tab;
  final AppointmentFilter filter;

  /// Free-text: booking ref, token, doctor, hospital or person name.
  final String? q;

  /// The statuses the request asks for, honouring the tab's own set.
  ///
  /// Completed and Canceled are fixed sets; Upcoming uses the bucket and
  /// lets the filter narrow by status within it.
  Set<AppointmentStatus> get statuses => switch (tab) {
    // With `bucket=past`: every visit that is over and was not cancelled —
    // completed ones, and any the desk left in an active status.
    AppointmentTab.completed => const {
      AppointmentStatus.completed,
      AppointmentStatus.scheduled,
      AppointmentStatus.checkedIn,
      AppointmentStatus.inConsultation,
      AppointmentStatus.pendingApproval,
    },
    AppointmentTab.cancelled => const {
      AppointmentStatus.cancelled,
      AppointmentStatus.noShow,
    },
    AppointmentTab.upcoming || null => filter.statuses,
  };

  /// `bucket=upcoming` for Upcoming, `bucket=past` for Completed (whose
  /// status set also names active statuses, which only the bucket keeps to
  /// visits that are over); none for Canceled or a search.
  String? get bucket => switch (tab) {
    AppointmentTab.upcoming => 'upcoming',
    AppointmentTab.completed => 'past',
    AppointmentTab.cancelled || null => null,
  };

  /// Upcoming is soonest-first; everything else newest-first (the default).
  String? get sort => switch (tab) {
    AppointmentTab.upcoming => 'scheduled_start_at',
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is AppointmentListQuery &&
      other.tab == tab &&
      other.filter == filter &&
      other.q == q;

  @override
  int get hashCode => Object.hash(tab, filter, q);
}
