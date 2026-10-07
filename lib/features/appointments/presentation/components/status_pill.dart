import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../../../core/widgets/status_style.dart' show PillColors;
import '../../domain/entities/appointment.dart';
import '../../application/providers/appointment_filter_controller.dart'
    show statusLabel;

/// Maps the eight backend statuses (§17) onto the design's pills.
///
/// Confirmed ← `scheduled` / `checked_in` / `in_consultation` (the two
/// in-clinic states get their own wording but the same warm tone);
/// "Awaiting confirmation" ← `pending_approval`; "Payment pending" ←
/// `pending_payment`; Completed / Cancelled / No-show as themselves. Every
/// colour is a design token — nothing here invents a palette.
abstract final class AppointmentStatusStyle {
  AppointmentStatusStyle._();

  static PillColors of(AppointmentStatus status) => switch (status) {
    AppointmentStatus.pendingPayment => (
      background: AppColors.dangerSoft,
      foreground: AppColors.dangerText,
    ),
    AppointmentStatus.pendingApproval => (
      background: AppColors.surfaceTint,
      foreground: AppColors.brand,
    ),
    AppointmentStatus.scheduled ||
    AppointmentStatus.checkedIn ||
    AppointmentStatus.inConsultation => (
      background: AppColors.warningSoft,
      foreground: AppColors.warningText,
    ),
    AppointmentStatus.completed => (
      background: AppColors.successSoft,
      foreground: AppColors.successText,
    ),
    AppointmentStatus.cancelled => (
      background: AppColors.dangerSoft,
      foreground: AppColors.dangerText,
    ),
    AppointmentStatus.noShow => (
      background: AppColors.grey100,
      foreground: AppColors.grey500,
    ),
  };

  /// One line of context under the pill on the detail screen.
  static String hint(Appointment appointment) {
    final base = switch (appointment.status) {
      AppointmentStatus.pendingPayment =>
        'Complete the payment to confirm this booking.',
      AppointmentStatus.pendingApproval =>
        'The hospital will confirm this booking shortly.',
      AppointmentStatus.scheduled => 'Confirmed for the slot below.',
      AppointmentStatus.checkedIn =>
        "You are checked in — watch your token on the live queue.",
      AppointmentStatus.inConsultation => 'The doctor is seeing you now.',
      AppointmentStatus.completed => 'This consultation is closed.',
      AppointmentStatus.cancelled => switch (appointment.cancelledBy) {
        CancelledBy.hospital => 'The hospital cancelled this appointment.',
        CancelledBy.system =>
          'This booking lapsed before payment and was cancelled.',
        CancelledBy.patient => 'You cancelled this appointment.',
        // Not said by the server: do not guess who did it.
        null => 'This appointment was cancelled.',
      },
      AppointmentStatus.noShow => 'The slot passed without a consultation.',
    };
    // The server's own reason (`cancellation_reason`, or `status_reason`),
    // unless it only repeats what the line above already says.
    final reason = reasonText(
      appointment.status == AppointmentStatus.cancelled
          ? appointment.cancellationReason
          : appointment.statusReason,
    );
    return reason == null ? base : '$base Reason: $reason.';
  }

  /// The server's reason in words, or null when there is nothing to add.
  ///
  /// `patient_request` and `payment_timeout` are what the "You cancelled" /
  /// "lapsed before payment" lines already say. Any other code
  /// (`doctor_unavailable`) is spelt out ("Doctor unavailable"); free text
  /// the patient typed when cancelling ("Feeling better") is shown as is.
  static String? reasonText(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    const alreadySaid = {'patient_request', 'payment_timeout'};
    if (alreadySaid.contains(value.toLowerCase())) return null;
    final isCode = RegExp(r'^[a-z0-9]+(_[a-z0-9]+)+$').hasMatch(value);
    final text = isCode ? value.replaceAll('_', ' ') : value;
    final clean = text.endsWith('.')
        ? text.substring(0, text.length - 1)
        : text;
    return isCode ? clean[0].toUpperCase() + clean.substring(1) : clean;
  }
}

/// The status pill for one appointment, in the design's spelling.
class AppointmentStatusPill extends StatelessWidget {
  const AppointmentStatusPill({super.key, required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    return AppStatusPill(
      label: statusLabel(status),
      colors: AppointmentStatusStyle.of(status),
    );
  }
}
