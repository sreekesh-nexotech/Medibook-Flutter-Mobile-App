import '../../../../core/utils/money.dart';

/// `GET /patient/appointments/{id}/cancellation-preview` (§10.6).
///
/// Each hospital sets its own two-tier policy; the app shows the numbers
/// the backend computed and never applies a rule of its own.
class CancellationPreview {
  const CancellationPreview({
    required this.allowed,
    required this.refundBp,
    required this.refund,
    required this.nonRefundable,
    this.reason,
    this.cutoffAt,
    this.beforeCutoff = true,
    this.includesConvenienceFee = false,
  });

  final bool allowed;

  /// When not allowed: `APPOINTMENT_NOT_ACTIONABLE` | `TOKEN_ALREADY_CALLED`
  /// | `TOKEN_CANCEL_WINDOW_CLOSED`.
  final String? reason;

  /// Appointment time minus the hospital's cutoff hours (UTC).
  final DateTime? cutoffAt;
  final bool beforeCutoff;

  /// `10000` = 100 %; `0` when unpaid.
  final int refundBp;

  /// What the patient gets back — the number to show.
  final Money refund;
  final Money nonRefundable;
  final bool includesConvenienceFee;

  /// "100%" / "50%".
  String get refundPercentLabel {
    final percent = refundBp / 100;
    return percent == percent.roundToDouble()
        ? '${percent.round()}%'
        : '${percent.toStringAsFixed(1)}%';
  }
}
