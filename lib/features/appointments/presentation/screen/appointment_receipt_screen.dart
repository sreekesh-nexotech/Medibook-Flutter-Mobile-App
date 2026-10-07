import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/route_arrival.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../../../core/widgets/status_style.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_error_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../application/providers/appointments_provider.dart';
import '../../application/states/appointment_action_state.dart';
import '../../application/usecases/hospital_time.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/receipt.dart';
import '../components/calendar_action.dart';
import '../components/detail_row.dart';
import '../components/enter_animations.dart';
import '../components/external_links.dart';
import '../components/receipt_lines.dart';

/// `/receipt/:appointmentId` (pushed) — CM-21, from
/// `GET /patient/appointments/{id}/receipt` (§10.8).
///
/// The itemised lines with their supplier and tax, the payment lines, the
/// hospital snapshot with its GSTIN, and the platform (Medibook) as the
/// seller of the convenience fee. "Download PDF" fetches the ten-minute
/// signed URL (§10.9) and opens it; "Add to calendar" downloads the `.ics`
/// (§10.10), saves it and hands it to the OS.
class AppointmentReceiptScreen extends ConsumerWidget {
  const AppointmentReceiptScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = ref.watch(appointmentReceiptProvider(appointmentId));

    return RouteArrival(
      onArrive: () => ref.invalidate(appointmentReceiptProvider(appointmentId)),
      child: Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: ScreenEnter(
            child: Column(
              children: [
                AppInnerHeader(title: 'Receipt', onBack: () => _leave(context)),
                Expanded(
                  child: receipt.when(
                    loading: () => const AppSkeletonList(count: 3),
                    error: (error, _) => _error(context, ref, error),
                    data: (value) => _content(context, ref, value),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `404 NOT_FOUND` until the booking is paid — say so, and point at the
  /// thing that does exist.
  Widget _error(BuildContext context, WidgetRef ref, Object error) {
    final failure = error.asFailure();
    if (failure is NotFoundFailure) {
      return AppEmptyView(
        iconName: MedIcon.bag,
        headline: 'No receipt yet',
        body:
            'A receipt is issued once the consultation fee is paid. Until '
            'then there is nothing to show here.',
        actionLabel: 'Back to appointment',
        onAction: () =>
            context.go(AppRoutes.appointmentDetailPath(appointmentId)),
      );
    }
    return AppErrorView(
      failure: failure,
      onRetry: () => ref.invalidate(appointmentReceiptProvider(appointmentId)),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, Receipt receipt) {
    final actionState = ref.watch(appointmentActionsProvider(appointmentId));
    // The receipt carries no zone of its own; the appointment it settles
    // names the hospital's (§10).
    final timezone = ref.watch(
      appointmentDetailProvider(
        appointmentId,
      ).select((d) => d.valueOrNull?.value.appointment.hospital.timezone),
    );
    // Money later returned on this booking: the receipt still records the
    // payment, but its label must not say only "Paid" (BL-APPT-056).
    final refunds = ref.watch(
      appointmentDetailProvider(
        appointmentId,
      ).select((d) => d.valueOrNull?.value.refunds ?? const <Refund>[]),
    );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(AppSpacing.x5.w, 6.h, AppSpacing.x5.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(receipt, timezone, refunds),
          if (refunds.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _refundNote(refunds, timezone),
          ],
          SizedBox(height: 12.h),
          _lines(receipt),
          SizedBox(height: 12.h),
          _payment(receipt),
          SizedBox(height: 12.h),
          _issuer(receipt),
          SizedBox(height: 16.h),
          _actions(context, ref, receipt, actionState),
        ],
      ),
    );
  }

  /// What came back to the patient, and when.
  Widget _refundNote(List<Refund> refunds, String? timezone) {
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Refund',
            style: AppText.poppins(
              size: AppFontSize.base,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 8.h),
          for (final refund in refunds)
            DetailRow(
              label: switch (refund.status) {
                RefundStatus.processed => 'Refunded',
                RefundStatus.failed => 'Refund failed',
                _ => 'Refund in progress',
              },
              value: refund.amount.format(),
              caption: switch (refund.processedAt ?? refund.requestedAt) {
                final at? => switch (refund.status) {
                  RefundStatus.processed =>
                    'Returned on ${HospitalTime.dayMonthYear(at, timezone: timezone)} '
                        'to the account you paid from',
                  _ =>
                    'Started on ${HospitalTime.dayMonthYear(at, timezone: timezone)}',
                },
                null => null,
              },
            ),
        ],
      ),
    );
  }

  /// The receipt number, when it was issued, and by whom.
  Widget _header(Receipt receipt, String? timezone, List<Refund> refunds) {
    final refunded = refunds.any((r) => r.status == RefundStatus.processed);
    final refunding = refunds.any(
      (r) =>
          r.status == RefundStatus.requested ||
          r.status == RefundStatus.processing,
    );
    final line = receipt.lines.isEmpty ? null : receipt.lines.first;
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
                      receipt.receiptNo,
                      style: AppText.poppins(
                        size: 16,
                        weight: AppText.bold,
                        color: AppColors.textStrong,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Tax invoice · ${receipt.hospital.name}',
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
                label: refunded
                    ? 'Refunded'
                    : refunding
                    ? 'Refund in progress'
                    : 'Paid',
                colors: refunded || refunding
                    ? AppStatusStyle.refunded
                    : AppStatusStyle.paid,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          DetailRow(
            label: 'Issued',
            value: HospitalTime.dateAndTime(
              receipt.issuedAt,
              timezone: timezone,
            ),
          ),
          if (receipt.fyCode != null)
            DetailRow(label: 'Financial year', value: receipt.fyCode!),
          if (receipt.issuedByName != null)
            DetailRow(
              label: 'Issued by',
              value: receipt.issuedByName!,
              caption: receipt.counterCode == null
                  ? null
                  : 'Counter ${receipt.counterCode}',
            ),
          DetailRow(
            label: 'Booking reference',
            value: line?.bookingRef ?? '—',
            showDivider: false,
          ),
        ],
      ),
    );
  }

  /// The itemised lines, each with its supplier and tax, and the totals.
  Widget _lines(Receipt receipt) {
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
            label: 'Subtotal',
            amount: receipt.subtotal,
            caption: receipt.tax.isZero
                ? 'No tax applies'
                : 'Plus ${receipt.tax.format()} tax',
          ),
          ReceiptTotalRow(label: 'Total paid', amount: receipt.total),
        ],
      ),
    );
  }

  /// How it was paid.
  Widget _payment(Receipt receipt) {
    final lines = receipt.paymentLines;
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment',
            style: AppText.poppins(
              size: 14,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 4.h),
          if (lines.isEmpty)
            AppInlineEmpty(
              message: 'No payment lines were recorded on this receipt.',
              margin: EdgeInsets.only(top: 8.h),
            )
          else
            for (final (index, line) in lines.indexed)
              DetailRow(
                label: _methodLabel(line.method),
                value: line.amount.format(),
                caption: line.reference,
                showDivider: index < lines.length - 1,
              ),
        ],
      ),
    );
  }

  /// The GST identities the invoice is raised under: the hospital for the
  /// consultation, Medibook for the convenience fee.
  Widget _issuer(Receipt receipt) {
    final hospital = receipt.hospital;
    final platform = receipt.platform;
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailRow(
            label: 'Billed by',
            value: hospital.legalName ?? hospital.name,
            caption: hospital.address.oneLine.isEmpty
                ? null
                : hospital.address.oneLine,
          ),
          DetailRow(
            label: 'GSTIN',
            value: hospital.gstin ?? 'Not registered',
            valueColor: hospital.gstin == null ? AppColors.textMuted : null,
            showDivider: platform != null,
          ),
          if (platform != null) ...[
            DetailRow(
              label: 'Convenience fee by',
              value: platform.legalName ?? 'Medibook',
              caption: platform.address.oneLine.isEmpty
                  ? null
                  : platform.address.oneLine,
            ),
            DetailRow(
              label: 'GSTIN',
              value: platform.gstin ?? 'Not registered',
              valueColor: platform.gstin == null ? AppColors.textMuted : null,
              showDivider: false,
            ),
          ],
        ],
      ),
    );
  }

  /// Download PDF (§10.9) and Add to calendar (§10.10).
  Widget _actions(
    BuildContext context,
    WidgetRef ref,
    Receipt receipt,
    AppointmentActionState actionState,
  ) {
    return Column(
      children: [
        AppButton(
          label: 'Download PDF',
          fullWidth: true,
          leadingIcon: MedIcon.download,
          disabled: !receipt.pdfAvailable,
          loading: actionState.isRunning(AppointmentActionKind.receiptPdf),
          semanticLabel: receipt.pdfAvailable
              ? 'Download the receipt PDF'
              : 'Download PDF — still being generated, try again shortly',
          onPressed: receipt.pdfAvailable
              ? () => _downloadPdf(context, ref)
              : null,
        ),
        SizedBox(height: 10.h),
        AppButton(
          label: 'Add to calendar',
          variant: AppButtonVariant.secondary,
          fullWidth: true,
          leadingIcon: MedIcon.calendar,
          loading: actionState.isRunning(AppointmentActionKind.calendar),
          onPressed: () =>
              addAppointmentToCalendar(context, ref, appointmentId),
        ),
        SizedBox(height: 8.h),
        Text(
          'Quote ${receipt.receiptNo} to support for anything about this '
          'payment.',
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

  Future<void> _downloadPdf(BuildContext context, WidgetRef ref) async {
    // Another action on this appointment (Add to calendar, say) is still
    // running: this tap is ignored, not answered with an error (BL-APPT-058).
    if (ref.read(appointmentActionsProvider(appointmentId)).isBusy) return;
    final link = await ref
        .read(appointmentActionsProvider(appointmentId).notifier)
        .receiptPdfLink();
    if (!context.mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    if (link == null) {
      final failure = ref
          .read(appointmentActionsProvider(appointmentId))
          .failure;
      toast.show(
        failure is NotFoundFailure
            ? 'The PDF is still being generated. Try again in a moment.'
            : failure?.userMessage ?? 'Could not fetch the PDF.',
      );
      return;
    }
    final opened = await ExternalLinks.openUrl(link.url);
    if (!context.mounted) return;
    if (!opened) toast.show('Nothing on this phone can open the PDF link.');
  }

  static String _methodLabel(String method) => switch (method) {
    'upi' => 'UPI',
    'card' => 'Card',
    'netbanking' => 'Net banking',
    'wallet' => 'Wallet',
    'emi' => 'EMI',
    'paylater' => 'Pay later',
    'cash' => 'Cash',
    'pos' => 'Card (desk)',
    _ => 'Other',
  };

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.appointmentDetailPath(appointmentId));
    }
  }
}
