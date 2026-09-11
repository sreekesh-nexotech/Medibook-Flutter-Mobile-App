import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/constants.dart';
import '../../../../core/mock_data/medibook_seed.dart';
import '../../../../core/mock_data/models/appointment.dart';
import '../../../../core/mock_data/models/doctor.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../domain/entities/appointment_status_view.dart';
import '../../domain/entities/appointment_token.dart';

/// Immutable appointments state: the list plus the next token number
/// (`T-026`). All updates go through [copyWith] — no field mutation.
class AppointmentsState {
  const AppointmentsState({required this.items, required this.nextTokenNumber});

  final List<Appointment> items;
  final int nextTokenNumber;

  AppointmentsState copyWith({List<Appointment>? items, int? nextTokenNumber}) {
    return AppointmentsState(
      items: items ?? this.items,
      nextTokenNumber: nextTokenNumber ?? this.nextTokenNumber,
    );
  }
}

/// Owns the appointments list for the whole app: seeded appointments plus any
/// the user books, and the reschedule / cancel transitions.
///
/// This is shared app data (Home's "Your Token", the Appointments list, detail,
/// search, filter and reschedule all read it), so it is intentionally NOT
/// autoDispose.
///
/// API swap: when the data layer lands, this controller takes an
/// `AppointmentRepository` (domain contract) in its constructor and its methods
/// call the repository; the seed initializer below is removed.
class AppointmentsController extends StateNotifier<AppointmentsState> {
  AppointmentsController()
    : super(
        AppointmentsState(
          items: MedibookSeed.initialAppointments(),
          nextTokenNumber: AppConstants.tokenCounterStart,
        ),
      );

  /// The next token label a new booking will receive — canonical `T-026`
  /// (`CANONICAL_MASTER_DATA` §5), not the old `A-26`.
  String get nextToken => AppointmentToken.format(state.nextTokenNumber);

  /// Book a new appointment; it lands in Upcoming and takes the next token.
  /// Returns the created appointment (the Success screen shows it).
  Appointment book({
    required String doctorId,
    required String patient,
    required String dateFull,
    required String time,
  }) {
    final token = nextToken;
    final appt = Appointment(
      id: 'b${state.nextTokenNumber}',
      doctorId: doctorId,
      patient: patient,
      date: dateFull,
      time: time,
      token: token,
      status: AppointmentStatus.confirmed,
      bucket: AppointmentBucket.upcoming,
      bookingRef: MedibookSeed.bookingRef(state.nextTokenNumber),
    );
    state = state.copyWith(
      items: [appt, ...state.items],
      nextTokenNumber: state.nextTokenNumber + 1,
    );
    return appt;
  }

  /// Cancel an appointment: marks it Cancelled and moves it to Past.
  ///
  /// Returns **false** when there is no such appointment or it is not in a
  /// cancellable state, so a caller can never report a cancellation that did
  /// not happen (THE LAW on honest controls).
  bool cancel(String id) {
    final existing = byId(id);
    if (existing == null) return false;
    if (existing.status != AppointmentStatus.confirmed) return false;
    state = state.copyWith(
      items: [
        for (final a in state.items)
          if (a.id == id)
            a.copyWith(
              status: AppointmentStatus.cancelled,
              bucket: AppointmentBucket.past,
            )
          else
            a,
      ],
    );
    return true;
  }

  /// Reschedule to a real instant. Returns false when the appointment is
  /// unknown or no longer changeable.
  ///
  /// Takes a [DateTime] rather than the old `dateFull` / `time` strings: the
  /// model stores an instant and derives its labels, so a reschedule that
  /// round-tripped through "Today" / "10:30 AM" was losing information
  /// (audit §3.8.3).
  bool rescheduleTo(String id, DateTime scheduledAt) {
    final existing = byId(id);
    if (existing == null) return false;
    if (existing.status != AppointmentStatus.confirmed) return false;
    state = state.copyWith(
      items: [
        for (final a in state.items)
          if (a.id == id) a.copyWith(scheduledAt: scheduledAt) else a,
      ],
    );
    return true;
  }

  /// Attach the payment that settled [id] — the receipt screen reads it back
  /// through `paymentForAppointmentProvider`.
  bool attachPayment(String id, String paymentId) {
    if (byId(id) == null) return false;
    state = state.copyWith(
      items: [
        for (final a in state.items)
          if (a.id == id) a.copyWith(paymentId: paymentId) else a,
      ],
    );
    return true;
  }

  Appointment? byId(String id) {
    for (final a in state.items) {
      if (a.id == id) return a;
    }
    return null;
  }
}

/// Global appointments controller.
final appointmentsControllerProvider =
    StateNotifierProvider<AppointmentsController, AppointmentsState>(
      (ref) => AppointmentsController(),
    );

/// One appointment plus everything the list, search and detail screens need to
/// render it without re-resolving lookups per widget.
///
/// A record rather than a class: it is a read-model assembled in a provider and
/// consumed immediately, so it needs no identity, no `copyWith` and no
/// equality of its own.
typedef AppointmentRow = ({
  Appointment appointment,
  Doctor doctor,
  AppointmentStatusView status,
  String hospitalId,
  String hospitalName,
});

/// Every appointment as a resolved row, newest slot first.
///
/// Sorted on [Appointment.scheduledAt] — a real instant. Sorting on the display
/// strings ("Today", "12 Aug 2026") was audit §3.8.3.
final appointmentRowsProvider = Provider.autoDispose<List<AppointmentRow>>((
  ref,
) {
  final items = ref.watch(
    appointmentsControllerProvider.select((s) => s.items),
  );
  final rows =
      <AppointmentRow>[
        for (final appointment in items) _rowFor(ref, appointment),
      ]..sort(
        (a, b) =>
            b.appointment.scheduledAt.compareTo(a.appointment.scheduledAt),
      );
  return rows;
});

/// Rows in one canonical bucket.
///
/// The bucket comes from the **canonical status** (upcoming = {Scheduled, In
/// Queue}; past = {Completed, Cancelled, No-show}), not from the stored
/// `Appointment.bucket` field — which is why a confirmed appointment whose slot
/// has passed drops out of Upcoming instead of sitting there forever.
///
/// Upcoming is ordered soonest-first (the next thing you must attend); Past is
/// ordered most-recent-first.
final appointmentRowsInBucketProvider = Provider.autoDispose
    .family<List<AppointmentRow>, AppointmentBucket>((ref, bucket) {
      final rows = ref
          .watch(appointmentRowsProvider)
          .where((row) => row.status.bucket == bucket)
          .toList();
      if (bucket == AppointmentBucket.upcoming) {
        rows.sort(
          (a, b) =>
              a.appointment.scheduledAt.compareTo(b.appointment.scheduledAt),
        );
      }
      return rows;
    });

/// Appointments in the given bucket (Upcoming / Past), bucketed canonically.
/// Kept under its original name and shape — Home and the notifications screen
/// read it.
final appointmentsByBucketProvider = Provider.autoDispose
    .family<List<Appointment>, AppointmentBucket>((ref, bucket) {
      return [
        for (final row in ref.watch(appointmentRowsInBucketProvider(bucket)))
          row.appointment,
      ];
    });

/// The next upcoming appointment (drives Home's "Your Token" card), or null.
final firstUpcomingAppointmentProvider = Provider<Appointment?>((ref) {
  final upcoming = ref.watch(
    appointmentsByBucketProvider(AppointmentBucket.upcoming),
  );
  return upcoming.isEmpty ? null : upcoming.first;
});

/// A single appointment by id (detail / reschedule / receipt). autoDispose
/// family — the id space is unbounded (new bookings mint b26, b27, …), so keyed
/// caches must not outlive their watchers.
final appointmentByIdProvider = Provider.autoDispose
    .family<Appointment?, String>((ref, id) {
      final items = ref.watch(
        appointmentsControllerProvider.select((s) => s.items),
      );
      for (final appointment in items) {
        if (appointment.id == id) return appointment;
      }
      return null;
    });

/// One resolved row by appointment id, or null when the id is unknown.
final appointmentRowProvider = Provider.autoDispose
    .family<AppointmentRow?, String>((ref, id) {
      final appointment = ref.watch(appointmentByIdProvider(id));
      if (appointment == null) return null;
      return _rowFor(ref, appointment);
    });

/// The canonical status of one appointment.
final appointmentStatusProvider = Provider.autoDispose
    .family<AppointmentStatusView?, String>(
      (ref, id) => ref.watch(appointmentRowProvider(id))?.status,
    );

/// Resolves the doctor, the facility and the canonical status for one
/// appointment. Shared by the list and the single-row providers so both agree.
AppointmentRow _rowFor(Ref ref, Appointment appointment) {
  final doctor = ref.watch(doctorByIdProvider(appointment.doctorId));
  final queue = ref.watch(queueStatusProvider(appointment.doctorId));
  final hospitalId = appointment.hospitalId ?? doctor.hospitalId;
  return (
    appointment: appointment,
    doctor: doctor,
    status: AppointmentStatusViews.of(appointment, queue: queue),
    hospitalId: hospitalId,
    hospitalName: ref.watch(hospitalByIdProvider(hospitalId)).name,
  );
}
