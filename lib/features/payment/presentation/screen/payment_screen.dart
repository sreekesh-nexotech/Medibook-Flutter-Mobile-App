import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/connectivity/connectivity_monitor.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../../core/utils/server_clock.dart';
import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_countdown.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_error_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../booking/application/providers/booking_draft_provider.dart';
import '../../../booking/application/providers/booking_providers.dart';
import '../../../booking/presentation/booking_routes.dart';
import '../../../booking/presentation/components/confirm_summary.dart';
import '../../../booking/presentation/components/fee_breakdown_card.dart';
import '../../../booking/presentation/components/flow_screen_enter.dart';
import '../../application/providers/payment_providers.dart';
import '../../application/states/payment_flow_state.dart';
import '../../domain/entities/price_change.dart';

/// In-app payment (§9.2–§9.6). Route: `/booking/payment`.
///
/// The booking already exists when this screen opens (`POST
/// /patient/appointments` ran on the summary step), so it shows the
/// appointment's reference and token, the fee snapshot, the countdown to
/// `booking_deadline_at`, and one button: **Pay ₹amount** — the amount from
/// the payment order, never a quote. Tapping it opens the Razorpay SDK,
/// which offers the payment methods itself; there is no method list here and
/// no pay-at-hospital (§9). On success the order is verified; on failure the
/// result screen offers a retry (a new order, same deadline). Coming back to
/// this screen without a result re-reads the order (§9.5).
///
/// It sits **on top of** `/booking`, so the draft and the booking result are
/// still alive underneath. Opened from an appointment instead
/// (`?appt=<id>&order=<id>`, the detail's "Retry payment"), there is no draft:
/// the booking is re-read from `GET /patient/appointments/{id}` (§9.4).
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, this.appointmentId, this.orderId});

  /// Set when reached from an appointment rather than the booking flow.
  final String? appointmentId;

  /// The order the appointment screen knew about; the detail's own
  /// `payment_order` wins when both exist.
  final String? orderId;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen>
    with WidgetsBindingObserver {
  bool _navigated = false;

  /// Set once the patient has agreed to a changed price, so a retry does not
  /// ask again.
  bool _priceChangeAccepted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (!mounted) return;
      final booking = ref.read(bookingSubmitProvider).result;
      if (booking != null) {
        ref.read(paymentFlowProvider.notifier).start(booking);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the gateway (or a wallet app) with no result: the gateway
    // may have told the backend directly, so re-read the order (§9.5).
    if (state != AppLifecycleState.resumed) return;
    final flow = ref.read(paymentFlowProvider);
    if (flow.phase == PaymentPhase.idle && flow.hasOrder) {
      ref.read(paymentFlowProvider.notifier).refreshOrder();
    }
  }

  /// True while the booking is held and unpaid — the guard's condition,
  /// set by [_shell] on every build.
  bool _holding = false;

  static const String _leaveTitle = 'Leave payment?';
  static const String _leaveConsequence =
      'Your slot is only held for a few more minutes. If you do not pay '
      'in time the booking is released and nothing is charged.';

  /// The header's back arrow. `Navigator.maybePop`, **not** `context.pop()`:
  /// go_router's pop skips the "Leave payment?" guard, so the arrow used to
  /// leave at once while the slot was held (BL-PAY-027).
  Future<void> _leave() async {
    if (context.canPop()) {
      await Navigator.maybePop(context);
      return;
    }
    // Reached directly (no page below): ask the same question, then Home.
    if (_holding) {
      final leave = await showDiscardChangesDialog(
        context,
        title: _leaveTitle,
        consequence: _leaveConsequence,
        discardLabel: 'Leave',
        keepLabel: 'Keep paying',
      );
      if (leave != true || !mounted) return;
    }
    context.go(AppRoutes.home);
  }

  /// The difference between the confirm step's total and what this booking
  /// costs, or null. Only known inside the booking flow.
  PriceChange? _priceChange(int duePaise) => PriceChange.between(
    quotedPaise: ref.read(bookingSubmitProvider).quotedTotalPaise,
    duePaise: duePaise,
  );

  static String _priceChangeMessage(PriceChange change) =>
      'You were shown ${Money.inr(change.quotedPaise)} when you confirmed. '
      'The hospital\'s price for this appointment is '
      '${Money.inr(change.duePaise)}. Nothing has been charged yet.';

  /// Paying needs the connection: say so before anything opens, rather than
  /// letting the gateway fail with an unrelated message (offline audit,
  /// 6 Oct). True when it is fine to go on.
  bool _ensureOnline() {
    final monitor = ref.read(connectivityMonitorProvider);
    if (monitor.isOnline) return true;
    ref
        .read(toastControllerProvider.notifier)
        .show(
          monitor.hasRoute
              ? NetworkFailure.unreachableMessage
              : const NetworkFailure().userMessage,
        );
    return false;
  }

  Future<void> _pay() async {
    if (!_ensureOnline()) return;
    // A changed price is agreed to before any money moves (BL-BOOK-035).
    final flowNow = ref.read(paymentFlowProvider);
    final due =
        (flowNow.order ?? ref.read(bookingSubmitProvider).result?.paymentOrder)
            ?.amountPaise;
    final change = due == null ? null : _priceChange(due);
    if (change != null && !_priceChangeAccepted) {
      final agreed = await showAppConfirmDialog(
        context,
        title: 'The price has changed',
        consequence: _priceChangeMessage(change),
        confirmLabel: 'Pay ${Money.inr(change.duePaise)}',
        cancelLabel: 'Not now',
        isDestructive: false,
        iconName: PhIcon.warningCircleFill,
      );
      if (agreed != true || !mounted) return;
      _priceChangeAccepted = true;
    }

    final user = ref.read(currentUserProvider);
    final phase = await ref
        .read(paymentFlowProvider.notifier)
        .pay(
          contact: (
            name: user?.name,
            phone: user?.phoneE164,
            email: user?.email,
          ),
        );
    if (!mounted) return;
    _routeFor(phase);
  }

  /// Every final phase has a result screen; a cancelled sheet stays here.
  void _routeFor(PaymentPhase phase) {
    final flow = ref.read(paymentFlowProvider);
    final appointmentId = flow.appointment?.id;
    final status = switch (phase) {
      PaymentPhase.paid => PaymentResultStatus.success,
      PaymentPhase.pendingApproval => PaymentResultStatus.pendingApproval,
      PaymentPhase.latePayment => PaymentResultStatus.late,
      PaymentPhase.expired => PaymentResultStatus.expired,
      PaymentPhase.failed =>
        flow.wasCancelled ? null : PaymentResultStatus.failed,
      _ => null,
    };
    if (status == null || _navigated) return;
    _navigated = true;
    // Pushed, not `go`: the failure path's "Try again" pops back to this
    // screen with the order intact.
    context
        .push<void>(
          AppRoutes.bookingPaymentResultPath(
            status,
            appointmentId: appointmentId,
          ),
        )
        .whenComplete(() => _navigated = false);
  }

  ({String appointmentId, String? orderId})? get _resumeKey {
    final id = widget.appointmentId;
    return id == null ? null : (appointmentId: id, orderId: widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    final resumeKey = _resumeKey;
    final resumed = resumeKey == null
        ? null
        : ref.watch(resumedBookingProvider(resumeKey));
    if (resumeKey != null) {
      // The re-read booking enters the flow exactly as a fresh one does.
      ref.listen(resumedBookingProvider(resumeKey), (previous, next) {
        final value = next.valueOrNull;
        if (value != null) {
          ref.read(paymentFlowProvider.notifier).start(value);
        }
      });
    }
    final booking =
        ref.watch(bookingSubmitProvider).result ?? resumed?.valueOrNull;
    final flow = ref.watch(paymentFlowProvider);
    final draft = ref.watch(bookingDraftProvider);

    // A phase reached without going through `_pay` (the countdown expiring,
    // a poll finding the order paid) still gets its result screen.
    ref.listen<PaymentFlowState>(paymentFlowProvider, (previous, next) {
      if (previous?.phase != next.phase && next.phase.isFinal) {
        _routeFor(next.phase);
      }
    });

    if (booking == null && resumed != null) {
      return _shell(
        hasUnsavedChanges: false,
        child: resumed.isLoading
            ? const AppLoadingView(label: 'Loading your booking…')
            : AppErrorView(
                failure: resumed.error is Failure
                    ? resumed.error! as Failure
                    : const UnknownFailure(),
                onRetry: () =>
                    ref.invalidate(resumedBookingProvider(resumeKey!)),
              ),
      );
    }
    if (booking == null) {
      return _shell(
        hasUnsavedChanges: false,
        child: AppEmptyView(
          iconName: MedIcon.bag,
          headline: 'Nothing to pay for yet',
          body:
              'Pick a doctor, a time and a patient, then confirm the booking.',
          actionLabel: 'Back to booking',
          onAction: _leave,
        ),
      );
    }

    final appointment = flow.appointment ?? booking.appointment;
    final order = flow.order ?? booking.paymentOrder;
    final deadline = flow.deadline ?? appointment.bookingDeadlineAt;
    final busy = flow.phase.isBusy;

    if (flow.phase.isSettled) {
      return _shell(
        hasUnsavedChanges: false,
        child: AppEmptyView(
          iconName: MedIcon.bag,
          headline: 'This booking is already paid',
          body:
              'Nothing further is due. Open the appointment for its '
              'reference, token and receipt.',
          actionLabel: 'View appointment',
          onAction: () =>
              context.go(AppRoutes.appointmentDetailPath(appointment.id)),
          secondaryLabel: 'Back to Home',
          onSecondary: () => context.go(AppRoutes.home),
        ),
      );
    }
    if (flow.phase == PaymentPhase.expired ||
        flow.phase == PaymentPhase.latePayment) {
      return _shell(
        hasUnsavedChanges: false,
        child: AppEmptyView(
          iconName: PhIcon.clock,
          headline: flow.phase == PaymentPhase.expired
              ? 'The payment window has closed'
              : 'Payment arrived too late',
          body: flow.phase == PaymentPhase.expired
              ? 'Unpaid bookings are released after 5 minutes so the slot '
                    'goes back to other patients. Nothing has been charged. '
                    'Please book again.'
              : 'The money reached us after the deadline, so this booking '
                    'was cancelled and a full refund has been started.',
          actionLabel: 'Book again',
          onAction: () {
            ref.read(bookingSubmitProvider.notifier).reset();
            ref.read(bookingDraftProvider.notifier).clearSlot();
            _leave();
          },
          secondaryLabel: 'Back to Home',
          onSecondary: () => context.go(AppRoutes.home),
        ),
      );
    }

    return _shell(
      // The backend holds the slot for 5 minutes whether or not the patient
      // stays here; leaving just forfeits the attempt, so the guard says so.
      hasUnsavedChanges: !busy,
      footer: _footer(order: order, busy: busy, phase: flow.phase),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (deadline != null) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppCountdownPill(
                // The server's deadline, as the phone's clock will reach it
                // — right even when the phone's clock is wrong (BL-CORE-007).
                deadline: ServerClock.onDeviceClock(deadline).toLocal(),
                prefix: 'Slot held for',
                onExpired: () =>
                    ref.read(paymentFlowProvider.notifier).expire(),
              ),
            ),
            SizedBox(height: AppSpacing.x4.h),
          ],
          if (flow.failureMessage != null) ...[
            AppErrorBanner(
              message: flow.failureMessage!,
              tone: flow.wasCancelled
                  ? AppBannerTone.warning
                  : AppBannerTone.danger,
              iconName: PhIcon.xCircle,
            ),
            SizedBox(height: AppSpacing.x3.h),
          ],
          if (flow.failure != null && flow.failureMessage == null) ...[
            AppInlineError(
              failure: flow.failure!,
              onRetry: () =>
                  ref.read(paymentFlowProvider.notifier).refreshOrder(),
            ),
            SizedBox(height: AppSpacing.x3.h),
          ],
          if (_priceChange(order.amountPaise) case final change?) ...[
            AppErrorBanner(
              message: 'The price has changed. ${_priceChangeMessage(change)}',
              iconName: PhIcon.warningCircleFill,
            ),
            SizedBox(height: AppSpacing.x3.h),
          ],
          _heading('Order summary'),
          SizedBox(height: AppSpacing.x3.h),
          ConfirmSummary(
            appointment: appointment,
            patientName: draft.person?.fullName ?? 'Patient on file',
            timezone: appointment.hospitalTimezone ?? draft.hospitalTimezone,
          ),
          SizedBox(height: 14.h),
          FeeBreakdownCard(
            rows: FeeRowData.fromAppointment(appointment),
            totalPaise: order.amountPaise,
            title: 'Payment summary',
            footnote:
                'Priced for ${appointment.scheduledDate} by the hospital. '
                'The convenience fee is not refundable.',
          ),
          SizedBox(height: AppSpacing.x5.h),
          _heading('How you pay'),
          SizedBox(height: AppSpacing.x2.h),
          Text(
            'Tap Pay to open the secure Razorpay sheet, which offers UPI, '
            'cards, net banking and wallets. Your booking is confirmed the '
            'moment the payment is verified.',
            style: AppText.poppins(
              size: AppFontSize.sm,
              color: AppColors.textBody,
              height: 1.5,
            ),
          ),
          if (order.attempts > 1) ...[
            SizedBox(height: AppSpacing.x2.h),
            Text(
              'Attempt ${order.attempts} — the deadline above has not '
              'changed.',
              style: AppText.poppins(
                size: AppFontSize.xs,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heading(String text) => Text(
    text,
    style: AppText.poppins(
      size: AppFontSize.body,
      weight: AppText.semibold,
      color: AppColors.textStrong,
    ),
  );

  Widget _footer({
    required PaymentPhase phase,
    required bool busy,
    required dynamic order,
  }) {
    final amount = Money.inr(order.amountPaise as int);
    final retryable =
        phase == PaymentPhase.failed &&
        !ref.read(paymentFlowProvider).wasCancelled;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 14.h,
        bottom: 22.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.w),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: switch (phase) {
              PaymentPhase.checkout => 'Waiting for the payment sheet…',
              PaymentPhase.verifying => 'Confirming payment…',
              PaymentPhase.retrying => 'Starting a new payment…',
              PaymentPhase.polling => 'Checking payment status…',
              _ => retryable ? 'Try again — $amount' : 'Pay $amount',
            },
            fullWidth: true,
            // Both the spinner and the repeat-tap block come from this one
            // flag; the controller refuses a second attempt too.
            loading: busy,
            semanticLabel: busy
                ? 'Payment in progress, please wait'
                : 'Pay $amount with Razorpay',
            onPressed: busy
                ? null
                : retryable
                ? () async {
                    if (!_ensureOnline()) return;
                    final next = await ref
                        .read(paymentFlowProvider.notifier)
                        .retry();
                    if (mounted) _routeFor(next);
                  }
                : _pay,
          ),
          SizedBox(height: AppSpacing.x2.h),
          Text(
            'You will not be charged twice — tapping again while this is '
            'running does nothing.',
            textAlign: TextAlign.center,
            style: AppText.poppins(
              size: AppFontSize.xxs,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// The screen frame: guard → scaffold → header → scrolling body → footer.
  Widget _shell({
    required Widget child,
    required bool hasUnsavedChanges,
    Widget? footer,
  }) {
    _holding = hasUnsavedChanges;
    return AppUnsavedChangesGuard(
      hasUnsavedChanges: hasUnsavedChanges,
      title: _leaveTitle,
      consequence: _leaveConsequence,
      discardLabel: 'Leave',
      keepLabel: 'Keep paying',
      child: Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: FlowScreenEnter(
            child: Column(
              children: [
                AppInnerHeader(title: 'Payment', onBack: _leave),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 24.h),
                    child: child,
                  ),
                ),
                ?footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
