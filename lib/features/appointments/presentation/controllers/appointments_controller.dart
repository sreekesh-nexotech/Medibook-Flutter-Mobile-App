import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/constants.dart';
import '../../../../core/mock_data/medibook_seed.dart';
import '../../../../core/mock_data/models/appointment.dart';

/// Immutable appointments state: the list plus the next token number
/// (`A-{n}`). All updates go through [copyWith] — no field mutation.
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
/// This is shared app data (Home's "Your Token", the Appointments list, detail
/// and reschedule all read it), so it is intentionally NOT autoDispose.
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

  /// The next token label that a new booking will receive ("A-26").
  String get nextToken => 'A-${state.nextTokenNumber}';

  /// Book a new appointment; it lands at the top of Upcoming and takes the next
  /// token. Returns the created appointment (the Success screen shows it).
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
    );
    state = state.copyWith(
      items: [appt, ...state.items],
      nextTokenNumber: state.nextTokenNumber + 1,
    );
    return appt;
  }

  /// Cancel an appointment: marks it Cancelled and moves it to Past.
  void cancel(String id) {
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
  }

  /// Reschedule: write the new date/time back onto the appointment.
  void reschedule(String id, {required String dateFull, required String time}) {
    state = state.copyWith(
      items: [
        for (final a in state.items)
          if (a.id == id) a.copyWith(date: dateFull, time: time) else a,
      ],
    );
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

/// Appointments in the given bucket (Upcoming / Past).
final appointmentsByBucketProvider =
    Provider.family<List<Appointment>, AppointmentBucket>((ref, bucket) {
      final items = ref.watch(
        appointmentsControllerProvider.select((s) => s.items),
      );
      return items.where((a) => a.bucket == bucket).toList();
    });

/// The first upcoming appointment (drives Home's "Your Token" card), or null.
final firstUpcomingAppointmentProvider = Provider<Appointment?>((ref) {
  final upcoming = ref.watch(
    appointmentsByBucketProvider(AppointmentBucket.upcoming),
  );
  return upcoming.isEmpty ? null : upcoming.first;
});

/// A single appointment by id (detail / reschedule).
final appointmentByIdProvider = Provider.family<Appointment?, String>((ref, id) {
  ref.watch(appointmentsControllerProvider.select((s) => s.items));
  return ref.read(appointmentsControllerProvider.notifier).byId(id);
});
