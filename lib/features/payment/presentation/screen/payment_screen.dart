import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/config/feature_flags.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/fee_breakdown.dart';
import '../../../../core/mock_data/models/payment.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_countdown.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/app_stub_notice.dart';
import '../../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../booking/presentation/components/confirm_summary.dart';
import '../../../booking/presentation/components/coupon_field.dart';
import '../../../booking/presentation/components/fee_breakdown_card.dart';
import '../../../booking/presentation/components/flow_screen_enter.dart';
import '../../../booking/presentation/controllers/booking_controller.dart';
import '../../domain/counter_payment_window.dart';
import '../components/payment_method_tile.dart';
import '../controllers/payment_controller.dart';

/// In-app payment (CM-17, CM-18, CM-20, CM-23). Route: `/booking/payment`.
///
/// The audit's finding was the bluntest one in §2.2: *"No payment screen of any
/// kind: no method choice, no order summary, no failure or retry state."* This
/// screen is all four —
///
/// * the order summary is the same [ConfirmSummary] the booking step shows,
///   plus the full [FeeBreakdownCard] (CM-13) and a live coupon control
///   (CM-19);
/// * every method in `paymentMethodsProvider` is a selectable row, with Pay at
///   Hospital a peer of the online ones and its counter-confirmation window on
///   screen (CM-18);
/// * the slot stays held with a visible countdown and is released on expiry
///   (X-02);
/// * the pay button is bound to `AppButton(loading:)`, which blocks the repeat
///   tap that audit §3.5.6 says *"creates two bookings"*, and the controller
///   refuses a second attempt as well;
/// * failure lands on `/booking/payment/result?status=failed`, which offers
///   retry and change-method.
///
/// **No gateway.** There is no payment SDK in this build and none may be
/// added, so authorisation is simulated — stated on screen with an
/// [AppStubBanner], and in demo mode the outcome is selectable so the failure
/// and pending paths are reachable. Nothing here reports a collection that did
/// not happen.
///
/// It sits **on top of** `/booking`, so the booking draft is still alive
/// underneath; leaving through back releases the hold.
///
/// Router wiring:
/// ```dart
/// GoRoute(
///   path: AppRoutes.bookingPayment,
///   builder: (_, __) => const PaymentScreen(),
/// )
/// ```
class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  @override
  void initState() {
    super.initState();
    // A payment screen opened for a booking that has not been attempted yet
    // starts clean, so a previous booking's failure cannot colour this one.
    Future.microtask(() {
      if (!mounted) return;
      final flow = ref.read(paymentControllerProvider);
      if (flow.appointmentId == null) {
        ref.read(paymentControllerProvider.notifier).reset();
      }
      // Default the method so the pay button is never disabled for want of a
      // choice the patient did not know they had to make.
      final draft = ref.read(bookingControllerProvider);
      if (draft.method == null) {
        final methods = ref.read(paymentMethodsProvider);
        if (methods.isNotEmpty) {
          ref
              .read(bookingControllerProvider.notifier)
              .pickMethod(methods.first);
        }
      }
    });
  }

  void _leave() {
    // Walking out of the payment step gives the slot back — holding a slot for
    // someone who has left is the other half of X-02.
    ref.read(bookingControllerProvider.notifier).releaseHold();
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.home);
  }

  Future<void> _pay(FeeBreakdown fee, PaymentMethod method) async {
    final draft = ref.read(bookingControllerProvider);
    final outcome = await ref
        .read(paymentControllerProvider.notifier)
        .pay(draft: draft, fee: fee, method: method);
    // null means the attempt was refused (one already in flight, or the hold
    // has gone) — there is nothing to navigate to.
    if (outcome == null || !mounted) return;

    final appointmentId = ref.read(paymentControllerProvider).appointmentId;
    final status = switch (outcome) {
      PaymentOutcome.success => AppRoutes.paymentStatusSuccess,
      PaymentOutcome.failed => AppRoutes.paymentStatusFailed,
      PaymentOutcome.pending => AppRoutes.paymentStatusPending,
    };
    // Pushed, not `go`: the failure path's "Try again" pops straight back to
    // this screen with the draft, the method and the hold intact.
    await context.push<void>(
      AppRoutes.bookingPaymentResultPath(status, appointmentId: appointmentId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingControllerProvider);
    final flow = ref.watch(paymentControllerProvider);
    final doctorId = draft.doctorId;
    final slot = draft.slot;

    if (doctorId == null || slot == null) {
      return _shell(
        child: AppEmptyView(
          iconName: MedIcon.bag,
          headline: 'Nothing to pay for yet',
          body: 'Pick a doctor, a day and a time first.',
          actionLabel: 'Back to booking',
          onAction: _leave,
        ),
        hasUnsavedChanges: false,
      );
    }

    if (draft.holdExpired) {
      return _shell(
        child: AppEmptyView(
          iconName: MedIcon.clock,
          headline: 'Your slot hold ran out',
          body:
              'We released ${slot.rangeLabel} so another patient could book '
              'it. Nothing has been charged. Pick a time again.',
          actionLabel: 'Pick another slot',
          onAction: () {
            ref.read(bookingControllerProvider.notifier).backToSlotSelection();
            _leave();
          },
        ),
        hasUnsavedChanges: false,
      );
    }

    // Returning here with the back gesture after a settled attempt must not
    // offer to pay a second time. The appointment already exists and the
    // ledger already has its entry; a second tap would add a second charge to
    // the same booking.
    final settled = flow.outcome != null && !flow.outcome!.isFailure;
    if (settled) {
      final settledId = flow.appointmentId;
      return _shell(
        hasUnsavedChanges: false,
        child: AppEmptyView(
          iconName: MedIcon.bag,
          headline: flow.outcome == PaymentOutcome.pending
              ? 'Already confirmed — pay at the desk'
              : 'This booking is already paid',
          body:
              'Nothing further is due here. Open the appointment for its '
              'reference, token and receipt.',
          // The action is only offered when there is something to open —
          // never a label with nothing behind it (THE LAW).
          actionLabel: settledId == null ? 'Back to Home' : 'View appointment',
          onAction: settledId == null
              ? () => context.go(AppRoutes.home)
              : () => context.go(AppRoutes.appointmentDetailPath(settledId)),
          secondaryLabel: settledId == null ? null : 'Back to Home',
          onSecondary: settledId == null
              ? null
              : () => context.go(AppRoutes.home),
        ),
      );
    }

    final doctor = ref.watch(doctorByIdProvider(doctorId));
    final fee = ref.watch(
      feeBreakdownProvider((doctorId: doctorId, couponCode: draft.couponCode)),
    );
    final methods = ref.watch(paymentMethodsProvider);
    final hospitalName = draft.hospitalId == null
        ? doctor.hospital
        : ref.watch(hospitalByIdProvider(draft.hospitalId!)).name;
    final method = draft.method ?? methods.first;
    final submitting = flow.isSubmitting;

    return _shell(
      // Once a booking exists there is nothing left to lose by leaving, so the
      // guard stands down rather than nagging.
      hasUnsavedChanges: flow.appointmentId == null,
      onDiscard: () =>
          ref.read(bookingControllerProvider.notifier).releaseHold(),
      footer: _footer(fee: fee, method: method, submitting: submitting),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (draft.holdUntil != null) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppCountdownPill(
                deadline: draft.holdUntil!,
                prefix: 'Slot held for',
                onExpired: () =>
                    ref.read(bookingControllerProvider.notifier).expireHold(),
              ),
            ),
            SizedBox(height: AppSpacing.x4.h),
          ],
          const AppStubBanner(
            title: 'Simulated payment',
            body:
                'This build has no payment gateway, so the authorisation step '
                'is simulated. Everything else — the booking, the reference, '
                'the receipt entry — is real.',
            margin: EdgeInsets.zero,
          ),
          if (FeatureFlags.demoMode) ...[
            SizedBox(height: AppSpacing.x3.h),
            _OutcomePicker(
              value: flow.simulatedOutcome,
              enabled: !submitting,
              onChanged: (outcome) => ref
                  .read(paymentControllerProvider.notifier)
                  .chooseSimulatedOutcome(outcome),
            ),
          ],
          SizedBox(height: AppSpacing.x5.h),
          _heading('Order summary'),
          SizedBox(height: AppSpacing.x3.h),
          ConfirmSummary(
            doctor: doctor,
            patientName: draft.patientName,
            departmentName: draft.departmentName ?? doctor.department,
            hospitalName: hospitalName,
            scheduledAt: slot.start,
            slotRangeLabel: slot.rangeLabel,
            bookingRef: draft.bookingRef ?? '—',
            token: draft.token ?? '—',
          ),
          SizedBox(height: 14.h),
          CouponField(
            appliedCode: draft.couponCode,
            discount: fee.discount,
            errorText: draft.couponError,
            enabled: !submitting,
            onApply: (code) => _applyCoupon(doctorId, code),
            onRemove: () =>
                ref.read(bookingControllerProvider.notifier).removeCoupon(),
          ),
          SizedBox(height: 14.h),
          FeeBreakdownCard(
            fee: fee,
            title: 'Payment summary',
            footnote:
                'GST at ${fee.taxLabel} is charged on the consultation fee '
                'after any discount. The convenience fee is not refundable.',
          ),
          SizedBox(height: AppSpacing.x6.h),
          _heading('How would you like to pay?'),
          SizedBox(height: AppSpacing.x3.h),
          for (final m in methods) ...[
            PaymentMethodTile(
              method: m,
              selected: m == method,
              enabled: !submitting,
              note: m.isOnline
                  ? null
                  : CounterPaymentWindow.noticeFor(slot.start),
              onSelected: () =>
                  ref.read(bookingControllerProvider.notifier).pickMethod(m),
            ),
            SizedBox(height: AppSpacing.x3.h),
          ],
        ],
      ),
    );
  }

  void _applyCoupon(String doctorId, String code) {
    final notifier = ref.read(bookingControllerProvider.notifier);
    final candidate = ref.read(
      feeBreakdownProvider((doctorId: doctorId, couponCode: code)),
    );
    if (candidate.couponCode == null || candidate.discount.isZero) {
      notifier.applyCoupon(error: "'$code' is not a valid coupon code.");
      return;
    }
    notifier.applyCoupon(code: code);
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
    required FeeBreakdown fee,
    required PaymentMethod method,
    required bool submitting,
  }) {
    final online = method.isOnline;
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
            label: online ? 'Pay ${fee.total.format()}' : 'Confirm booking',
            fullWidth: true,
            // Both the spinner and the repeat-tap block come from this one
            // flag (audit §3.5.6). The controller refuses a second attempt
            // too, so the guard does not depend on the widget alone.
            loading: submitting,
            semanticLabel: submitting
                ? 'Payment in progress, please wait'
                : (online
                      ? 'Pay ${fee.total.format()} by ${method.label}'
                      : 'Confirm the booking and pay ${fee.total.format()} '
                            'at the hospital desk'),
            onPressed: () => _pay(fee, method),
          ),
          SizedBox(height: AppSpacing.x2.h),
          Text(
            online
                ? 'You will not be charged twice — tapping again while this '
                      'is running does nothing.'
                : 'Nothing is charged now. The desk collects '
                      '${fee.total.format()}.',
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
    VoidCallback? onDiscard,
    Widget? footer,
  }) {
    return AppUnsavedChangesGuard(
      hasUnsavedChanges: hasUnsavedChanges,
      onDiscard: onDiscard,
      title: 'Leave payment?',
      consequence:
          'Your slot is only held for a few more minutes. Leaving releases '
          'it and nothing is booked.',
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

/// Demo-only: which outcome the simulated gateway returns.
///
/// This exists so the **failure** and **pending** screens the audit asked for
/// can actually be reached in a build with no gateway. It is gated on
/// [FeatureFlags.demoMode] and labelled as a simulation, rather than hidden —
/// a reviewer should be able to see the decline path without a card that
/// declines.
class _OutcomePicker extends StatelessWidget {
  const _OutcomePicker({
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final PaymentOutcome value;
  final ValueChanged<PaymentOutcome> onChanged;
  final bool enabled;

  static const Map<String, PaymentOutcome> _byLabel = {
    'Approve': PaymentOutcome.success,
    'Decline': PaymentOutcome.failed,
    'Leave pending': PaymentOutcome.pending,
  };

  String get _activeLabel => _byLabel.entries
      .firstWhere(
        (entry) => entry.value == value,
        orElse: () => _byLabel.entries.first,
      )
      .key;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(14.w),
      color: AppColors.surfaceAlt,
      shadow: AppShadowToken.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Simulated gateway result',
            style: AppText.poppins(
              size: AppFontSize.xs,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: AppSpacing.x2.h),
          AppSegmentedTabs(
            tabs: _byLabel.keys.toList(),
            active: _activeLabel,
            onChanged: enabled
                ? (label) {
                    final outcome = _byLabel[label];
                    if (outcome != null) onChanged(outcome);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
