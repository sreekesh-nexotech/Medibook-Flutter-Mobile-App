import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/mock_data/stores/payments_store.dart';
import '../../domain/entities/appointment_receipt.dart';
import 'appointments_controller.dart';

/// Why a receipt cannot be shown — so the screen can say which of the two it
/// is instead of one vague empty state.
enum ReceiptUnavailable {
  /// The appointment id is not in the list at all.
  unknownAppointment,

  /// The appointment exists but nothing has ever been charged against it.
  noPayment,
}

/// The receipt for one appointment (CM-21), or the reason there is none.
///
/// A record rather than a sealed class: it is assembled in a provider and
/// destructured immediately by the one screen that reads it.
typedef ReceiptResult = ({
  AppointmentReceipt? receipt,
  ReceiptUnavailable? unavailable,
});

/// Builds the GST receipt for [appointmentId] from the payment ledger and the
/// quoted fee breakdown.
///
/// The receipt reconciles the two rather than trusting either alone — see
/// [AppointmentReceipt.of]. The quote is read **without a coupon code**,
/// because the coupon that was actually applied at booking is not stored on
/// the payment in this build; any resulting gap becomes one explicit
/// "Adjustment at billing" line rather than a silently wrong total.
///
/// **Backend note:** the payment should carry its own itemisation (fee, GST,
/// convenience fee, discount and coupon code as charged), at which point this
/// provider stops consulting `feeBreakdownProvider` at all.
final appointmentReceiptProvider = Provider.autoDispose
    .family<ReceiptResult, String>((ref, appointmentId) {
      final row = ref.watch(appointmentRowProvider(appointmentId));
      if (row == null) {
        return (
          receipt: null,
          unavailable: ReceiptUnavailable.unknownAppointment,
        );
      }

      final payment = ref.watch(paymentForAppointmentProvider(appointmentId));
      if (payment == null) {
        return (receipt: null, unavailable: ReceiptUnavailable.noPayment);
      }

      final quoted = ref.watch(
        feeBreakdownProvider((
          doctorId: row.appointment.doctorId,
          couponCode: null,
        )),
      );

      return (
        receipt: AppointmentReceipt.of(
          appointment: row.appointment,
          payment: payment,
          quoted: quoted,
          doctorName: row.doctor.name,
          hospitalName: row.hospitalName,
        ),
        unavailable: null,
      );
    });
