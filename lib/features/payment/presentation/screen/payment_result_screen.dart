import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/payment.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/mock_data/stores/payments_store.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/states/app_not_found_view.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../../../booking/presentation/components/flow_screen_enter.dart';
import '../../../booking/presentation/components/token_actions.dart';
import '../../../booking/presentation/controllers/booking_records_controller.dart';
import '../../domain/counter_payment_window.dart';
import '../controllers/payment_controller.dart';

/// The payment outcome (CM-17, CM-18, CM-20). Route:
/// `/booking/payment/result?status=success|failed|pending&appt=<id>`.
///
/// The audit found *"no failure or retry state"* anywhere in the app, so all
/// three outcomes are first-class here and each has its own next step:
///
/// | status    | What it says                        | Actions                      |
/// |-----------|-------------------------------------|------------------------------|
/// | `success` | paid, with the token card           | view appointment · receipt   |
/// | `failed`  | declined, nothing charged           | **try again** · change method|
/// | `pending` | due at the hospital desk (CM-18)    | view appointment · window    |
///
/// It is **pushed** on top of `/booking/payment`, so "Try again" and "Change
/// payment method" pop back to a payment screen that still has the draft, the
/// held slot and the fee — no state is rebuilt from a query string.
///
/// Router wiring:
/// ```dart
/// GoRoute(
///   path: AppRoutes.bookingPaymentResult,
///   builder: (context, state) => PaymentResultScreen(
///     status: state.uri.queryParameters['status'] ?? '',
///     appointmentId: state.uri.queryParameters['appt'],
///   ),
/// )
/// ```
class PaymentResultScreen extends ConsumerWidget {
  const PaymentResultScreen({
    super.key,
    required this.status,
    this.appointmentId,
  });

  /// One of [AppRoutes.paymentStatusSuccess] / `…Failed` / `…Pending`.
  final String status;

  /// The appointment the attempt was for. Absent only for a declined attempt
  /// that never got as far as creating one.
  final String? appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // An unknown status is a broken link, not something to guess at.
    const known = [
      AppRoutes.paymentStatusSuccess,
      AppRoutes.paymentStatusFailed,
      AppRoutes.paymentStatusPending,
    ];
    if (!known.contains(status)) {
      return AppNotFoundView(
        headline: 'Unknown payment status',
        body: 'This link does not describe a payment outcome we can show.',
        attemptedPath: AppRoutes.bookingPaymentResultPath(status),
        onGoHome: () => context.go(AppRoutes.home),
        onGoBack: context.canPop() ? () => context.pop() : null,
      );
    }

    final id = appointmentId;
    final appointment = id == null
        ? null
        : ref.watch(appointmentByIdProvider(id));
    final record = id == null ? null : ref.watch(bookingRecordForProvider(id));
    final payment = id == null
        ? null
        : ref.watch(paymentForAppointmentProvider(id));
    final flow = ref.watch(paymentControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: FlowScreenEnter(
          rise: false,
          child: Column(
            children: [
              AppInnerHeader(
                title: 'Payment',
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.home),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 28.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Headline(status: status, payment: payment),
                      SizedBox(height: AppSpacing.x5.h),
                      if (status == AppRoutes.paymentStatusFailed)
                        _FailureBody(
                          reason:
                              payment?.failureReason ??
                              flow.failureReason ??
                              PaymentController.declinedReason,
                          amountLabel: payment?.amountLabel,
                        )
                      else if (record != null && appointment != null) ...[
                        TokenActionsCard(
                          token: record.token,
                          bookingRef: record.bookingRef,
                          scheduledAt: record.scheduledAt,
                          doctorName: ref
                              .watch(doctorByIdProvider(appointment.doctorId))
                              .name,
                          hospitalName: record.hospitalId == null
                              ? ref
                                    .watch(
                                      doctorByIdProvider(appointment.doctorId),
                                    )
                                    .hospital
                              : ref
                                    .watch(
                                      hospitalByIdProvider(record.hospitalId!),
                                    )
                                    .name,
                          onViewQueue: () => context.push(
                            AppRoutes.queuePath(appointment.doctorId),
                          ),
                        ),
                        SizedBox(height: 14.h),
                        if (status == AppRoutes.paymentStatusPending)
                          _CounterWindowCard(
                            scheduledAt: record.scheduledAt,
                            amountLabel: record.amount.format(),
                          )
                        else
                          _PaidCard(payment: payment),
                      ] else
                        _MissingRecordNotice(status: status),
                    ],
                  ),
                ),
              ),
              _Footer(
                status: status,
                appointmentId: id,
                hasReceipt: payment?.hasReceipt ?? false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The badge, headline and one-line explanation, toned by outcome.
class _Headline extends StatelessWidget {
  const _Headline({required this.status, required this.payment});

  final String status;
  final PaymentRecord? payment;

  @override
  Widget build(BuildContext context) {
    final (
      Color tone,
      Color soft,
      String iconName,
      String title,
      String body,
    ) = switch (status) {
      AppRoutes.paymentStatusSuccess => (
        AppColors.successText,
        AppColors.successSoft,
        MedIcon.bag,
        'Payment successful',
        'Your appointment is confirmed and paid. '
            '${payment?.receiptNumber == null ? '' : 'Receipt '
                      '${payment!.receiptNumber}.'}',
      ),
      AppRoutes.paymentStatusFailed => (
        AppColors.dangerText,
        AppColors.dangerSoft,
        MedIcon.closeCircle,
        'Payment failed',
        'Nothing has been charged. Your slot is still held for a few '
            'more minutes.',
      ),
      _ => (
        AppColors.textStrong,
        AppColors.warningSoft,
        MedIcon.clock,
        'Booked — pay at the hospital',
        'The desk collects the fee when you arrive.',
      ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52.w,
          height: 52.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
          child: AppIcon(iconName, size: 24, color: tone),
        ),
        SizedBox(width: AppSpacing.x4.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppText.poppins(
                  size: AppFontSize.h3,
                  weight: AppText.bold,
                  color: AppColors.textStrong,
                  height: 1.25,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                body.trim(),
                style: AppText.poppins(
                  size: AppFontSize.sm,
                  color: AppColors.textBody,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What a declined attempt says. The reason comes from the ledger entry, so
/// the screen and the payment history cannot disagree.
class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.reason, this.amountLabel});

  final String reason;
  final String? amountLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'What happened',
            style: AppText.poppins(
              size: AppFontSize.base,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: AppSpacing.x2.h),
          Text(
            reason,
            style: AppText.poppins(
              size: AppFontSize.base,
              color: AppColors.textBody,
              height: 1.5,
            ),
          ),
          if (amountLabel != null) ...[
            SizedBox(height: AppSpacing.x3.h),
            Text(
              'Attempted: $amountLabel. This attempt is in your payment '
              'history so support can look it up.',
              style: AppText.poppins(
                size: AppFontSize.xs,
                color: AppColors.textMuted,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The Pay-at-Hospital counter-confirmation window (CM-18).
class _CounterWindowCard extends StatelessWidget {
  const _CounterWindowCard({
    required this.scheduledAt,
    required this.amountLabel,
  });

  final DateTime scheduledAt;
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(18.w),
      color: AppColors.warningSoft,
      shadow: AppShadowToken.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Confirm at reception',
            style: AppText.poppins(
              size: AppFontSize.base,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: AppSpacing.x2.h),
          Text(
            CounterPaymentWindow.noticeFor(scheduledAt),
            style: AppText.poppins(
              size: AppFontSize.base,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          SizedBox(height: AppSpacing.x2.h),
          Text(
            'Amount due at the desk: $amountLabel',
            style: AppText.poppins(
              size: AppFontSize.sm,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
        ],
      ),
    );
  }
}

/// The settled-payment facts: method, amount, receipt series, GSTIN.
class _PaidCard extends StatelessWidget {
  const _PaidCard({required this.payment});

  final PaymentRecord? payment;

  @override
  Widget build(BuildContext context) {
    final payment = this.payment;
    if (payment == null) return const SizedBox.shrink();
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in <({String label, String value})>[
            (label: 'Paid', value: payment.amountLabel),
            (label: 'Method', value: payment.method.label),
            (label: 'Status', value: payment.status.label),
            (label: 'Receipt', value: payment.receiptNumber),
            if (payment.paidAtLabel != null)
              (label: 'On', value: payment.paidAtLabel!),
          ])
            Padding(
              padding: EdgeInsets.symmetric(vertical: 5.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      row.label,
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.x3.w),
                  Expanded(
                    flex: 6,
                    child: Text(
                      row.value,
                      textAlign: TextAlign.end,
                      style: AppText.poppins(
                        size: AppFontSize.sm,
                        weight: AppText.medium,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Shown when the route names an outcome but this session holds no booking for
/// it — a deep link, or a restart. It does not invent a confirmation.
class _MissingRecordNotice extends StatelessWidget {
  const _MissingRecordNotice({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Text(
        status == AppRoutes.paymentStatusSuccess
            ? 'This payment was made in an earlier session, so its token card '
                  'is not held here. Open the appointment to see its '
                  'reference, token and receipt.'
            : 'There is no booking attached to this outcome in this session.',
        style: AppText.poppins(
          size: AppFontSize.base,
          color: AppColors.textBody,
          height: 1.5,
        ),
      ),
    );
  }
}

/// The outcome's actions. Retry and change-method pop back to the payment
/// screen rather than pushing a second copy of it.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.status,
    required this.appointmentId,
    required this.hasReceipt,
  });

  final String status;
  final String? appointmentId;
  final bool hasReceipt;

  @override
  Widget build(BuildContext context) {
    final id = appointmentId;
    final failed = status == AppRoutes.paymentStatusFailed;

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
          if (failed) ...[
            AppButton(
              label: 'Try again',
              fullWidth: true,
              semanticLabel: 'Try the payment again',
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.bookingPayment),
            ),
            SizedBox(height: 10.h),
            AppButton(
              label: 'Use another method',
              variant: AppButtonVariant.soft,
              fullWidth: true,
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.bookingPayment),
            ),
            SizedBox(height: 10.h),
            AppButton(
              label: 'Back to Home',
              variant: AppButtonVariant.ghost,
              fullWidth: true,
              onPressed: () => context.go(AppRoutes.home),
            ),
          ] else ...[
            AppButton(
              label: 'View appointment',
              fullWidth: true,
              disabled: id == null,
              semanticLabel: id == null
                  ? 'View appointment, unavailable — no booking is attached '
                        'to this outcome'
                  : 'View the appointment this payment confirmed',
              onPressed: id == null
                  ? null
                  : () => context.go(AppRoutes.appointmentDetailPath(id)),
            ),
            if (hasReceipt && id != null) ...[
              SizedBox(height: 10.h),
              AppButton(
                label: 'View receipt',
                variant: AppButtonVariant.soft,
                fullWidth: true,
                onPressed: () => context.push(AppRoutes.receiptPath(id)),
              ),
            ],
            SizedBox(height: 10.h),
            AppButton(
              label: 'Back to Home',
              variant: AppButtonVariant.ghost,
              fullWidth: true,
              onPressed: () => context.go(AppRoutes.home),
            ),
          ],
        ],
      ),
    );
  }
}
