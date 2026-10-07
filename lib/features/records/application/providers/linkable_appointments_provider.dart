import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../appointments/application/providers/appointment_filter_controller.dart'
    show statusLabel;
import '../../../appointments/application/providers/appointments_provider.dart';
import '../../../appointments/domain/entities/appointment.dart';

/// An appointment a document can be attached to, pre-resolved for display.
///
/// The document form and the documents filter both need "Dr. Anil Kumar ·
/// 10 Jul 2026" next to an appointment id. The appointments feature owns the
/// data ([appointmentsForLinkingProvider], `GET /patient/appointments`); this
/// file only adapts its record shape to the class the records screens use.
class LinkableAppointment {
  const LinkableAppointment({
    required this.id,
    required this.label,
    required this.doctorName,
    required this.hospitalName,
    required this.scheduledAt,
    required this.when,
    required this.bookingRef,
    required this.statusLabel,
    required this.isClosedWithoutVisit,
    required this.personId,
  });

  final String id;

  /// "Dr. Anil Kumar · 10 Jul 2026".
  final String label;

  final String doctorName;
  final String hospitalName;

  /// The real instant, so callers sort on this and never on [label].
  final DateTime scheduledAt;

  /// "10 Jul 2026 · 10:20 AM", in the hospital's time zone.
  final String when;

  /// "LKSB-2609-00095" — the booking reference the patient also sees on
  /// the appointment and the receipt.
  final String bookingRef;

  /// "Completed", "Confirmed", "Cancelled" …
  final String statusLabel;

  /// Cancelled or a no-show: the visit never happened, so a new document is
  /// not linked to it (an existing link to one still shows).
  final bool isClosedWithoutVisit;

  /// Whose visit — one of the account's persons.
  final String personId;

  /// [label] with the hospital — "Dr. Anil Kumar · 10 Jul 2026 · Lakeshore
  /// Multispeciality Hospital" — for the fields and the filter chip that
  /// name the chosen visit.
  String get fullLabel =>
      hospitalName.isEmpty ? label : '$label · $hospitalName';
}

/// Every appointment on the account, newest first. Empty while the
/// appointments feature is still loading them (the pickers then simply
/// offer "Not linked"). `autoDispose` — only the form and the filter sheet
/// watch it.
final linkableAppointmentsProvider =
    Provider.autoDispose<List<LinkableAppointment>>((ref) {
      final refs = ref.watch(appointmentsForLinkingProvider).valueOrNull;
      if (refs == null) return const <LinkableAppointment>[];
      return [
        for (final item in refs)
          LinkableAppointment(
            id: item.id,
            label: item.label,
            doctorName: item.doctorName,
            hospitalName: item.hospitalName,
            scheduledAt: item.scheduledAt,
            when: item.when,
            bookingRef: item.bookingRef,
            statusLabel: statusLabel(item.status),
            isClosedWithoutVisit:
                item.status == AppointmentStatus.cancelled ||
                item.status == AppointmentStatus.noShow,
            personId: item.personId,
          ),
      ];
    });

/// One linkable appointment by id, or null when it is not (or not yet) in
/// the list — a cancelled visit, or one still loading.
final linkableAppointmentByIdProvider = Provider.autoDispose
    .family<LinkableAppointment?, String>((ref, id) {
      final items = ref.watch(linkableAppointmentsProvider);
      for (final item in items) {
        if (item.id == id) return item;
      }
      return null;
    });

/// The second line of a visit in the pickers — "9 Oct 2026 · 10:20 AM ·
/// Lakeshore Multispeciality Hospital · for Tara Varma · LKSB-2610-00212 ·
/// Cancelled" — so two visits with the same doctor on the same day can be
/// told apart. [patientName] is null while the family list loads.
String linkableAppointmentDetail(
  LinkableAppointment appointment, {
  String? patientName,
}) => [
  appointment.when,
  if (appointment.hospitalName.isNotEmpty) appointment.hospitalName,
  if (patientName != null && patientName.isNotEmpty) 'for $patientName',
  if (appointment.bookingRef.isNotEmpty) appointment.bookingRef,
  appointment.statusLabel,
].join(' · ');

/// The visits a document may be **linked** to: everything but cancelled and
/// no-show visits, which never happened — except [currentId], so an
/// existing link to one is still shown and can be kept.
List<LinkableAppointment> linkTargets(
  List<LinkableAppointment> appointments, {
  String? currentId,
}) => [
  for (final appointment in appointments)
    if (!appointment.isClosedWithoutVisit || appointment.id == currentId)
      appointment,
];
