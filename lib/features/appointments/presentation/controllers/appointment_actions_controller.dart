import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/models/payment.dart';
import '../../../../core/mock_data/stores/payments_store.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../domain/policies/cancellation_policy.dart';
import 'appointments_controller.dart';

/// Whether a cancel / reschedule is in flight, so the button can show
/// `loading:` and refuse a second tap (audit §3.5.6 — "tapping Confirm and Pay
/// twice creates two bookings").
class AppointmentActionState {
  const AppointmentActionState({this.busy = false});

  final bool busy;

  AppointmentActionState copyWith({bool? busy}) =>
      AppointmentActionState(busy: busy ?? this.busy);
}

/// What actually happened, in the words the toast will use.
///
/// [ok] is false whenever the underlying store refused the change — and the
/// message then says so. Nothing here can produce a success line for something
/// that did not happen (THE LAW).
class AppointmentActionResult {
  const AppointmentActionResult({
    required this.ok,
    required this.message,
    this.refundRequested = false,
    this.refundAmount = Money.zero,
  });

  const AppointmentActionResult.rejected(this.message)
    : ok = false,
      refundRequested = false,
      refundAmount = Money.zero;

  final bool ok;

  /// User-facing sentence. Never optimistic: when a refund could not be
  /// started, it says the appointment was cancelled *and* that the refund was
  /// not started.
  final String message;

  /// True only when `PaymentsStore.refund` returned true.
  final bool refundRequested;

  /// The amount the refund was raised for — [Money.zero] when none was.
  final Money refundAmount;
}

/// Runs the two state-changing appointment actions through the policy
/// (CM-25 / CM-26) and the payment ledger (CM-22).
///
/// The screens own none of this logic: they show the policy, ask for
/// confirmation, and call one method. That is what keeps the cut-off, the
/// refund arithmetic and the honest reporting in a single place.
class AppointmentActionsController extends StateNotifier<AppointmentActionState> {
  AppointmentActionsController(this._ref, this._appointmentId)
    : super(const AppointmentActionState());

  final Ref _ref;
  final String _appointmentId;

  /// Cancel the appointment and raise the refund [outcome] promises.
  Future<AppointmentActionResult> cancel(PolicyOutcome outcome) async {
    if (state.busy) {
      return const AppointmentActionResult.rejected(
        'Already working on that cancellation.',
      );
    }
    final blocked = outcome.blockedReason;
    if (!outcome.isAllowed) {
      return AppointmentActionResult.rejected(
        blocked ?? 'This appointment can no longer be cancelled.',
      );
    }

    state = state.copyWith(busy: true);
    try {
      final cancelled = _ref
          .read(appointmentsControllerProvider.notifier)
          .cancel(_appointmentId);
      if (!cancelled) {
        return const AppointmentActionResult.rejected(
          'This appointment could not be cancelled. Please reopen it and try '
          'again.',
        );
      }

      if (outcome.refund.isZero) {
        return const AppointmentActionResult(
          ok: true,
          message: 'Appointment cancelled. No payment to refund.',
        );
      }

      final payment = _ref.read(paymentForAppointmentProvider(_appointmentId));
      // `refund` returns false for an unknown or never-settled payment, and we
      // report exactly that rather than a refund the ledger never accepted.
      final refunded =
          payment != null &&
          _ref.read(paymentsStoreProvider.notifier).refund(
            payment.id,
            amount: outcome.refund,
            status: RefundStatus.requested,
          );

      if (!refunded) {
        return const AppointmentActionResult(
          ok: true,
          message:
              'Appointment cancelled, but the refund could not be started. '
              'Contact support with your booking reference.',
        );
      }

      return AppointmentActionResult(
        ok: true,
        refundRequested: true,
        refundAmount: outcome.refund,
        message:
            'Appointment cancelled · ${outcome.refund.format()} refund '
            'requested',
      );
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }

  /// Move the appointment to [scheduledAt].
  Future<AppointmentActionResult> reschedule({
    required PolicyOutcome outcome,
    required DateTime scheduledAt,
  }) async {
    if (state.busy) {
      return const AppointmentActionResult.rejected(
        'Already working on that change.',
      );
    }
    if (!outcome.isAllowed) {
      return AppointmentActionResult.rejected(
        outcome.blockedReason ?? 'This appointment can no longer be moved.',
      );
    }

    state = state.copyWith(busy: true);
    try {
      final moved = _ref
          .read(appointmentsControllerProvider.notifier)
          .rescheduleTo(_appointmentId, scheduledAt);
      if (!moved) {
        return const AppointmentActionResult.rejected(
          'This appointment could not be moved. Please reopen it and try '
          'again.',
        );
      }
      return AppointmentActionResult(
        ok: true,
        message: 'Moved to ${AppDates.dayAndTime(scheduledAt)}',
      );
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }
}

/// One action controller per appointment. autoDispose family — it is transient
/// UI state for whichever appointment screen is open.
final appointmentActionsProvider = StateNotifierProvider.autoDispose
    .family<AppointmentActionsController, AppointmentActionState, String>(
      (ref, id) => AppointmentActionsController(ref, id),
    );

/// The policy verdict for one appointment and one kind of change (CM-25,
/// CM-26).
///
/// Key: the appointment id plus the change, so the detail screen can ask about
/// a cancellation and the reschedule screen about a reschedule without either
/// duplicating the rule.
typedef PolicyQuery = ({String appointmentId, AppointmentChange change});

/// Evaluates [CancellationPolicy] against live appointment + ledger state.
/// Returns null when the appointment is unknown.
final appointmentPolicyProvider = Provider.autoDispose
    .family<PolicyOutcome?, PolicyQuery>((ref, query) {
      final row = ref.watch(appointmentRowProvider(query.appointmentId));
      if (row == null) return null;
      final payment = ref.watch(
        paymentForAppointmentProvider(query.appointmentId),
      );
      // Only settled money can be refunded, so an unpaid or failed attempt
      // counts as zero — the dialog must not promise it back.
      final paid = payment != null && payment.status.isSettled
          ? payment.amount
          : Money.zero;
      return CancellationPolicy.evaluate(
        appointment: row.appointment,
        paid: paid,
        change: query.change,
        isClosed: !row.status.allowsChange,
      );
    });
