import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/payment.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../../../core/widgets/app_stub_notice.dart';
import '../../../../core/widgets/status_style.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_not_found_view.dart';
import '../../domain/entities/appointment_receipt.dart';
import '../components/detail_row.dart';
import '../components/enter_animations.dart';
import '../components/receipt_lines.dart';
import '../controllers/appointment_receipt_controller.dart';

/// `/receipt/:appointmentId` (pushed) — CM-21.
///
/// The audit finding was *"Appointment details carry no receipt, no GST entry
/// and no refund status row."* This is the receipt: the itemised lines, **18%
/// GST as its own line**, the convenience fee, any coupon discount, the total
/// actually charged, the payment method, when it was paid, the canonical
/// receipt series number and the hospital's GSTIN.
///
/// ## Download and share
///
/// This build ships no PDF renderer and no share sheet, and may not gain one.
/// Per THE LAW the two controls are therefore honest: **Download** is declared
/// stubbed (`AppButton(stubbed: true)` + [showStubbedToast]) and **Share** is
/// disabled with a reason in its `semanticLabel`. Neither ever claims a file
/// was written.
class AppointmentReceiptScreen extends ConsumerWidget {
  const AppointmentReceiptScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(appointmentReceiptProvider(appointmentId));
    final receipt = result.receipt;

    if (result.unavailable == ReceiptUnavailable.unknownAppointment) {
      return AppNotFoundView(
        headline: 'Receipt not found',
        body:
            'That appointment is no longer in your list, so there is no '
            'receipt to show.',
        attemptedPath: AppRoutes.receiptPath(appointmentId),
        onGoBack: context.canPop() ? () => context.pop() : null,
        onGoHome: () => context.go(AppRoutes.appointments),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: ScreenEnter(
          child: Column(
            children: [
              AppInnerHeader(title: 'Receipt', onBack: () => _leave(context)),
              Expanded(
                child: receipt == null
                    ? _noPayment(context)
                    : _content(context, ref, receipt),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The appointment exists but nothing was ever charged — a "Pay at Hospital"
  /// booking, for instance. Say so, and point at the thing that does exist.
  Widget _noPayment(BuildContext context) {
    return AppEmptyView(
      iconName: MedIcon.bag,
      headline: 'No payment recorded yet',
      body:
          'A receipt is issued once the consultation fee is settled. If you '
          'chose to pay at the hospital, the front desk issues it there.',
      actionLabel: 'Back to appointment',
      onAction: () =>
          context.go(AppRoutes.appointmentDetailPath(appointmentId)),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    AppointmentReceipt receipt,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(AppSpacing.x5.w, 6.h, AppSpacing.x5.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (receipt.isProvisional)
            AppStubBanner(
              title: 'Provisional — not a paid invoice',
              body:
                  'This payment has not settled (${receipt.status.label}), so '
                  'the amounts below are an estimate. The final receipt is '
                  'issued once the money moves.',
              iconName: MedIcon.closeCircle,
              margin: EdgeInsets.only(bottom: 12.h),
            ),
          _header(receipt),
          SizedBox(height: 12.h),
          _lines(receipt),
          SizedBox(height: 12.h),
          _payment(receipt),
          SizedBox(height: 12.h),
          _issuer(receipt),
          SizedBox(height: 16.h),
          _actions(context, ref, receipt),
        ],
      ),
    );
  }

  /// Who the receipt is for and which appointment it covers.
  Widget _header(AppointmentReceipt receipt) {
    final bookingRef = receipt.bookingRef;
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receipt.receiptNumber,
                      style: AppText.poppins(
                        size: 16,
                        weight: AppText.bold,
                        color: AppColors.textStrong,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Tax invoice · ${receipt.hospitalName}',
                      style: AppText.poppins(
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              AppStatusPill(
                label: receipt.status.label,
                colors: _paymentPill(receipt.status),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          DetailRow(label: 'Patient', value: receipt.patientName),
          DetailRow(label: 'Doctor', value: receipt.doctorName),
          DetailRow(
            label: 'Appointment',
            value: AppDates.dayAndTime(receipt.scheduledAt),
          ),
          DetailRow(
            label: 'Token',
            value: receipt.tokenLabel,
            valueColor: AppColors.accentBlue,
            valueWeight: AppText.bold,
          ),
          DetailRow(
            label: 'Booking reference',
            value: bookingRef ?? 'Not recorded',
            valueColor: bookingRef == null ? AppColors.textMuted : null,
            showDivider: false,
          ),
        ],
      ),
    );
  }

  /// The itemised lines, GST included as its own row, and the total.
  Widget _lines(AppointmentReceipt receipt) {
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Charges',
            style: AppText.poppins(
              size: 14,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 4.h),
          for (final line in receipt.lines) ReceiptLineRow(line: line),
          ReceiptTotalRow(
            label: 'Total paid',
            amount: receipt.total,
            caption: receipt.isSettled
                ? 'Settled by ${receipt.method.label}'
                : 'Not settled — ${receipt.status.label.toLowerCase()}',
          ),
          SizedBox(height: 8.h),
          Text(
            '${receipt.taxLabel} of ${receipt.taxAmount.format()} is included '
            'above and charged on the consultation fee after any discount.',
            style: AppText.poppins(
              size: 11,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// How and when it was paid, plus any refund.
  Widget _payment(AppointmentReceipt receipt) {
    final paidAt = receipt.paidAtLabel;
    final refundAmount = receipt.refundAmount;
    final refundStatus = receipt.refundStatus;
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailRow(label: 'Payment method', value: receipt.method.label),
          DetailRow(label: 'Payment status', value: receipt.status.label),
          DetailRow(
            label: 'Paid at',
            value: paidAt ?? 'Not paid yet',
            valueColor: paidAt == null ? AppColors.textMuted : null,
          ),
          DetailRow(
            label: 'Ledger reference',
            value: receipt.ledgerReference,
            showDivider: refundAmount != null && refundStatus != null,
          ),
          if (refundAmount != null && refundStatus != null)
            DetailRow(
              label: 'Refund',
              value: refundAmount.format(),
              caption: refundStatus.label,
              showDivider: false,
            ),
        ],
      ),
    );
  }

  /// The GST identity the invoice is raised under.
  Widget _issuer(AppointmentReceipt receipt) {
    final patientGstin = receipt.patientGstin;
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailRow(
            label: 'Billed by',
            value: AppointmentReceipt.billingEntity,
          ),
          DetailRow(
            label: 'GSTIN',
            value: AppointmentReceipt.hospitalGstin,
            showDivider: patientGstin != null,
          ),
          if (patientGstin != null)
            DetailRow(
              label: 'Your GSTIN',
              value: patientGstin,
              showDivider: false,
            ),
        ],
      ),
    );
  }

  /// Download and Share, both honest (see the class doc).
  Widget _actions(
    BuildContext context,
    WidgetRef ref,
    AppointmentReceipt receipt,
  ) {
    return Column(
      children: [
        AppButton(
          label: 'Download PDF',
          fullWidth: true,
          leadingIcon: MedIcon.download,
          stubbed: true,
          semanticLabel: 'Download receipt PDF — stubbed in this demo',
          onPressed: () => showStubbedToast(context, ref, 'Download'),
        ),
        SizedBox(height: 10.h),
        AppButton(
          label: 'Share receipt',
          variant: AppButtonVariant.secondary,
          fullWidth: true,
          disabled: true,
          semanticLabel:
              'Share receipt — unavailable, this build has no share sheet',
          onPressed: () {},
        ),
        SizedBox(height: 8.h),
        Text(
          'Sharing needs a system share sheet, which this build does not '
          'include. Quote ${receipt.receiptNumber} to support instead.',
          textAlign: TextAlign.center,
          style: AppText.poppins(
            size: 11,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  /// Pill colours for a payment status. Local to this screen because
  /// `core/widgets/status_style.dart` has no payment-status lookup and core is
  /// frozen this round.
  PillColors _paymentPill(PaymentStatus status) => switch (status) {
    PaymentStatus.paid => (
      background: AppColors.successSoft,
      foreground: AppColors.successText,
    ),
    PaymentStatus.refunded => (
      background: AppColors.surfaceTint,
      foreground: AppColors.brand,
    ),
    PaymentStatus.pending => (
      background: AppColors.warningSoft,
      foreground: AppColors.grey600,
    ),
    PaymentStatus.failed => (
      background: AppColors.dangerSoft,
      foreground: AppColors.dangerText,
    ),
  };

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.appointmentDetailPath(appointmentId));
    }
  }
}
