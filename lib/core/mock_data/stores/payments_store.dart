import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/money.dart';
import '../medibook_seed.dart';
import '../models/payment.dart';

/// Owns the account's payment records (CM-17, CM-20 … CM-22).
///
/// **Why this is a shared store:** the booking flow *creates* a payment, the
/// Appointment detail and the receipt screen *read* it, and the cancellation
/// flow *refunds* it. Three features, one ledger.
///
/// There is no payment SDK in this build (Razorpay is deliberately absent —
/// see `pubspec.yaml`), so [record] writes a record for a payment that did not
/// actually move money. The payment screen must therefore be explicit about
/// being a demo (`showStubbedToast` / `AppStubBanner` from
/// `core/widgets/app_stub_notice.dart`) rather than showing a plain success —
/// audit §4.1.
class PaymentsStore extends Notifier<List<PaymentRecord>> {
  @override
  List<PaymentRecord> build() => MedibookSeed.payments;

  PaymentRecord? byId(String id) {
    for (final payment in state) {
      if (payment.id == id) return payment;
    }
    return null;
  }

  /// Every attempt against [appointmentId], newest first.
  List<PaymentRecord> forAppointment(String appointmentId) =>
      state.where((p) => p.appointmentId == appointmentId).toList();

  /// The payment that matters for [appointmentId]: the settled or refunded one
  /// if there is one, otherwise the most recent attempt.
  PaymentRecord? settledFor(String appointmentId) {
    PaymentRecord? fallback;
    for (final payment in state) {
      if (payment.appointmentId != appointmentId) continue;
      if (payment.status.isSettled ||
          payment.status == PaymentStatus.refunded) {
        return payment;
      }
      fallback ??= payment;
    }
    return fallback;
  }

  /// Record a payment attempt. [sequence] drives the receipt number so it
  /// reads like a real ledger entry rather than a timestamp.
  PaymentRecord record({
    required String appointmentId,
    required PaymentMethod method,
    required Money amount,
    required int sequence,
    PaymentStatus status = PaymentStatus.paid,
    String? gstNumber,
    String? failureReason,
  }) {
    final payment = PaymentRecord(
      id: 'pay-${DateTime.now().microsecondsSinceEpoch}',
      appointmentId: appointmentId,
      method: method,
      amount: amount,
      status: status,
      receiptNumber: MedibookSeed.receiptNumber(sequence),
      gstNumber: gstNumber,
      paidAt: status.isSettled ? DateTime.now() : null,
      failureReason: failureReason,
    );
    state = [payment, ...state];
    return payment;
  }

  /// Mark a pending payment settled (a Pay-at-Hospital collection).
  void markPaid(String id) {
    state = [
      for (final p in state)
        if (p.id == id)
          p.copyWith(status: PaymentStatus.paid, paidAt: DateTime.now())
        else
          p,
    ];
  }

  /// Mark an attempt failed, with the gateway's reason (CM-20).
  void markFailed(String id, String reason) {
    state = [
      for (final p in state)
        if (p.id == id)
          p.copyWith(status: PaymentStatus.failed, failureReason: reason)
        else
          p,
    ];
  }

  /// Start a refund (CM-22). [amount] defaults to the full payment.
  ///
  /// Returns false — and changes nothing — when the payment is unknown or was
  /// never settled, so a cancellation flow cannot claim to have refunded a
  /// payment that never happened.
  bool refund(String id, {Money? amount, RefundStatus? status}) {
    final payment = byId(id);
    if (payment == null || !payment.status.isRefundable) return false;
    final refundAmount = amount ?? payment.amount;
    final refundStatus = status ?? RefundStatus.requested;
    state = [
      for (final p in state)
        if (p.id == id)
          p.copyWith(
            status: refundStatus == RefundStatus.completed
                ? PaymentStatus.refunded
                : p.status,
            refundAmount: refundAmount,
            refundStatus: refundStatus,
          )
        else
          p,
    ];
    return true;
  }

  /// Advance a refund's status (requested → processing → completed).
  void setRefundStatus(String id, RefundStatus status) {
    state = [
      for (final p in state)
        if (p.id == id)
          p.copyWith(
            refundStatus: status,
            status: status == RefundStatus.completed
                ? PaymentStatus.refunded
                : p.status,
          )
        else
          p,
    ];
  }

  /// Total actually paid across the account — the arithmetic the old string
  /// fees made impossible (audit §3.8.2).
  Money get totalPaid => state
      .where((p) => p.status.isSettled)
      .map((p) => p.amount)
      .sum;
}

/// The account's payment ledger. Not autoDispose — booking writes it and
/// appointments/receipts read it.
final paymentsStoreProvider =
    NotifierProvider<PaymentsStore, List<PaymentRecord>>(PaymentsStore.new);

/// The payment that matters for one appointment. autoDispose family — the
/// appointment id space is unbounded.
final paymentForAppointmentProvider = Provider.autoDispose
    .family<PaymentRecord?, String>((ref, appointmentId) {
      final payments = ref.watch(paymentsStoreProvider);
      PaymentRecord? fallback;
      for (final payment in payments) {
        if (payment.appointmentId != appointmentId) continue;
        if (payment.status.isSettled ||
            payment.status == PaymentStatus.refunded) {
          return payment;
        }
        fallback ??= payment;
      }
      return fallback;
    });

/// One payment by id. autoDispose family.
final paymentByIdProvider = Provider.autoDispose
    .family<PaymentRecord?, String>((ref, id) {
      final payments = ref.watch(paymentsStoreProvider);
      for (final payment in payments) {
        if (payment.id == id) return payment;
      }
      return null;
    });
