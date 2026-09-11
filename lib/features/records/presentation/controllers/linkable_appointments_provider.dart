import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/models/appointment.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';

/// An appointment a document can be attached to, pre-resolved for display.
///
/// The document form and the documents filter both need "Dr. Anil Kumar ·
/// 10 Jul 2026" next to an appointment id, plus the doctor and facility names
/// to copy onto a new document. Resolving that here keeps the join out of
/// `build()` and out of the form controller (which then needs no appointments
/// import at all).
class LinkableAppointment {
  const LinkableAppointment({
    required this.id,
    required this.label,
    required this.doctorName,
    required this.hospitalName,
    required this.scheduledAt,
  });

  final String id;

  /// "Dr. Anil Kumar · 10 Jul 2026".
  final String label;

  final String doctorName;
  final String hospitalName;

  /// The real instant, so callers sort on this and never on [label].
  final DateTime scheduledAt;
}

/// Every appointment on the account, newest first, with its doctor and facility
/// resolved. `autoDispose` — only the document form and filter sheet watch it.
final linkableAppointmentsProvider =
    Provider.autoDispose<List<LinkableAppointment>>((ref) {
      final upcoming = ref.watch(
        appointmentsByBucketProvider(AppointmentBucket.upcoming),
      );
      final past = ref.watch(
        appointmentsByBucketProvider(AppointmentBucket.past),
      );

      final items = <LinkableAppointment>[];
      for (final appointment in [...upcoming, ...past]) {
        final doctor = ref.watch(doctorByIdProvider(appointment.doctorId));
        items.add(
          LinkableAppointment(
            id: appointment.id,
            label:
                '${doctor.name} · '
                '${AppDates.dayMonthYear(appointment.scheduledAt)}',
            doctorName: doctor.name,
            hospitalName: doctor.hospital,
            scheduledAt: appointment.scheduledAt,
          ),
        );
      }
      items.sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
      return items;
    });

/// One linkable appointment by id, or null when it is gone (cancelled and
/// removed, or an id from a document whose appointment no longer exists).
final linkableAppointmentByIdProvider = Provider.autoDispose
    .family<LinkableAppointment?, String>((ref, id) {
      final items = ref.watch(linkableAppointmentsProvider);
      for (final item in items) {
        if (item.id == id) return item;
      }
      return null;
    });
