import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/states/app_not_found_view.dart';
import '../../../appointments/presentation/components/calendar_action.dart';
import '../../../booking/application/providers/booking_draft_provider.dart';
import '../../../booking/application/providers/booking_providers.dart';
import '../../../booking/application/states/booking_draft.dart';
import '../../../booking/presentation/booking_routes.dart';
import '../../../booking/domain/entities/booked_appointment.dart';
import '../../../booking/presentation/components/flow_screen_enter.dart';
import '../../../booking/presentation/components/slot_labels.dart';
import '../../../booking/presentation/components/token_actions.dart';
import '../../application/providers/payment_providers.dart';
import '../../domain/entities/payment_record.dart';

/// The payment outcome (§9.3–§9.6). Route:
/// `/booking/payment/result?status=success|pending|failed|late|expired&appt=<id>`.
///
/// | status    | What it says                                  | Actions                    |
/// |-----------|-----------------------------------------------|----------------------------|
/// | `success` | paid; the token card                          | view appointment · home    |
/// | `pending` | paid; the hospital will confirm               | view appointment · home    |
/// | `failed`  | declined / unverified; nothing charged        | **try again** · home       |
/// | `late`    | paid after the deadline; cancelled, refunded  | book again · home          |
/// | `expired` | the 5 minutes ran out; nothing charged        | book again · home          |
///
/// It is **pushed** on top of `/booking/payment`, so "Try again" pops back
/// to a payment screen that still has the order. The facts come from the
/// verify response held in `paymentFlowProvider`; a deep link with no flow
/// state says so and points at the appointment.
class PaymentResultScreen extends ConsumerWidget {
  const PaymentResultScreen({
    super.key,
    required this.status,
    this.appointmentId,
  });

  /// One of [PaymentResultStatus.all].
  final String status;

  final String? appointmentId;

  /// The zone the booked times are shown in: the appointment names its
  /// hospital's (§10); the draft's is the fallback.
  static String? _zone(BookedAppointment appointment, BookingDraft draft) =>
      appointment.hospitalTimezone ?? draft.hospitalTimezone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // An unknown status is a broken link, not something to guess at.
    if (!PaymentResultStatus.all.contains(status)) {
      return AppNotFoundView(
        headline: 'Unknown payment status',
        body: 'This link does not describe a payment outcome we can show.',
        attemptedPath: AppRoutes.bookingPaymentResultPath(status),
        onGoHome: () => context.go(AppRoutes.home),
        onGoBack: context.canPop() ? () => context.pop() : null,
      );
    }

    final flow = ref.watch(paymentFlowProvider);
    final draft = ref.watch(bookingDraftProvider);
    final appointment = flow.appointment;
    final id = appointmentId ?? appointment?.id;
    final settled =
        status == PaymentResultStatus.success ||
        status == PaymentResultStatus.pendingApproval;

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
                      _Headline(status: status, payment: flow.payment),
                      SizedBox(height: AppSpacing.x5.h),
                      if (status == PaymentResultStatus.failed)
                        _FailureBody(
                          reason:
                              flow.failureMessage ??
                              'The payment did not go through. No money has '
                                  'left your account.',
                          amountPaise: flow.order?.amountPaise,
                        )
                      else if (settled && appointment != null) ...[
                        TokenActionsCard(
                          token:
                              appointment.tokenLabel ??
                              'Assigned by the hospital',
                          bookingRef: appointment.bookingRef,
                          dateLabel: SlotLabels.dayShort(
                            appointment.scheduledDate,
                            timezone: _zone(appointment, draft),
                          ),
                          whenLabel:
                              '${SlotLabels.dayLong(appointment.scheduledDate, timezone: _zone(appointment, draft))} · '
                              '${SlotLabels.time(appointment.scheduledStartAt, timezone: _zone(appointment, draft))}',
                          doctorName: appointment.doctorName,
                          hospitalName: appointment.hospitalName,
                          patientName: draft.person?.fullName,
                          calendarBusy: watchCalendarBusy(ref, appointment.id),
                          onAddToCalendar: () => addAppointmentToCalendar(
                            context,
                            ref,
                            appointment.id,
                          ),
                        ),
                        SizedBox(height: 14.h),
                        _PaidCard(
                          payment: flow.payment,
                          appointment: appointment,
                        ),
                      ] else if (status == PaymentResultStatus.late &&
                          appointment != null)
                        _LateCard(
                          appointment: appointment,
                          payment: flow.payment,
                        )
                      else if (status == PaymentResultStatus.expired &&
                          appointment != null)
                        _ExpiredCard(
                          bookingRef: appointment.bookingRef,
                          doctorName: appointment.doctorName,
                          whenLabel:
                              '${SlotLabels.dayLong(appointment.scheduledDate, timezone: _zone(appointment, draft))} · '
                              '${SlotLabels.time(appointment.scheduledStartAt, timezone: _zone(appointment, draft))}',
                        )
                      else
                        _MissingRecordNotice(status: status),
                    ],
                  ),
                ),
              ),
              _Footer(status: status, appointmentId: id),
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
      PaymentResultStatus.success => (
        AppColors.successText,
        AppColors.successSoft,
        PhIcon.checkBold,
        'Payment successful',
        'Your appointment is confirmed and paid.',
      ),
      PaymentResultStatus.pendingApproval => (
        AppColors.successText,
        AppColors.successSoft,
        PhIcon.checkBold,
        'Paid — awaiting hospital confirmation',
        'This hospital confirms online bookings by hand. You will be '
            'notified once it is approved.',
      ),
      PaymentResultStatus.late => (
        AppColors.dangerText,
        AppColors.dangerSoft,
        PhIcon.clock,
        'Payment received too late',
        'The money arrived after the 5-minute window, so the booking was '
            'cancelled and a full refund has been initiated.',
      ),
      PaymentResultStatus.expired => (
        AppColors.textStrong,
        AppColors.warningSoft,
        PhIcon.clock,
        'The payment window closed',
        'Unpaid bookings are released after 5 minutes. Nothing has been '
            'charged.',
      ),
      _ => (
        AppColors.dangerText,
        AppColors.dangerSoft,
        PhIcon.xCircle,
        'Payment failed',
        'Nothing has been charged. Your slot is still held until the timer '
            'runs out.',
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
                body,
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

/// What a declined attempt says, from the gateway's or the backend's words.
class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.reason, this.amountPaise});

  final String reason;
  final int? amountPaise;

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
          if (amountPaise != null) ...[
            SizedBox(height: AppSpacing.x3.h),
            Text(
              'Attempted: ${Money.inr(amountPaise!)}. Trying again starts a '
              'new payment for the same booking; the deadline does not move.',
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

/// The settled-payment facts from the verify response: amount, method,
/// captured time, appointment status.
class _PaidCard extends StatelessWidget {
  const _PaidCard({required this.payment, required this.appointment});

  final PaymentRecord? payment;
  final BookedAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final rows = <({String label, String value})>[
      (
        label: 'Paid',
        value: Money.inr(p?.amountPaise ?? appointment.totalPaise),
      ),
      if (p?.methodLabel != null) (label: 'Method', value: p!.methodLabel!),
      if (p?.capturedAt != null)
        (label: 'On', value: AppDates.dayAndTime(p!.capturedAt!.toLocal())),
      (
        label: 'Status',
        value: switch (appointment.status) {
          AppointmentStatus.pendingApproval => 'Awaiting confirmation',
          AppointmentStatus.scheduled => 'Confirmed',
          final s => s.wire.replaceAll('_', ' '),
        },
      ),
    ];
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows)
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

/// A late payment: cancelled by the system, refund on its way (§9.3).
class _LateCard extends StatelessWidget {
  const _LateCard({required this.appointment, required this.payment});

  final BookedAppointment appointment;
  final PaymentRecord? payment;

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
            'Refund initiated',
            style: AppText.poppins(
              size: AppFontSize.base,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: AppSpacing.x2.h),
          Text(
            '${Money.inr(payment?.amountPaise ?? appointment.totalPaise)} '
            'will be returned to the account you paid from. Booking '
            '${appointment.bookingRef} is cancelled'
            '${appointment.cancellationReason == null ? '' : ' (${appointment.cancellationReason!.replaceAll('_', ' ')})'}.',
            style: AppText.poppins(
              size: AppFontSize.base,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The lapsed booking, by name (BL-PAY-003): what was released and that
/// nothing was charged.
class _ExpiredCard extends StatelessWidget {
  const _ExpiredCard({
    required this.bookingRef,
    required this.doctorName,
    required this.whenLabel,
  });

  final String bookingRef;
  final String doctorName;
  final String whenLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Text(
        'Booking $bookingRef with $doctorName ($whenLabel) was not paid in '
        'time, so it has been released and the slot is free again. Nothing '
        'was charged. Book again to choose a time.',
        style: AppText.poppins(
          size: AppFontSize.base,
          color: AppColors.textBody,
          height: 1.5,
        ),
      ),
    );
  }
}

/// Shown when the route names an outcome but this session holds no booking
/// for it — a deep link, or a restart. It does not invent a confirmation.
class _MissingRecordNotice extends StatelessWidget {
  const _MissingRecordNotice({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Text(
        status == PaymentResultStatus.success ||
                status == PaymentResultStatus.pendingApproval
            ? 'This payment was made in an earlier session, so its details '
                  'are not held here. Open the appointment to see its '
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

/// The outcome's actions. Retry pops back to the payment screen rather than
/// pushing a second copy of it.
class _Footer extends ConsumerWidget {
  const _Footer({required this.status, required this.appointmentId});

  final String status;
  final String? appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = appointmentId;
    final failed = status == PaymentResultStatus.failed;
    final over =
        status == PaymentResultStatus.late ||
        status == PaymentResultStatus.expired;

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
          ] else if (over) ...[
            AppButton(
              label: 'Book again',
              fullWidth: true,
              // Back to the same doctor to pick a new time: the department,
              // hospital, doctor, patient and notes are kept (BL-PAY-028).
              onPressed: () {
                ref.read(bookingSubmitProvider.notifier).reset();
                final lapsed = ref.read(paymentFlowProvider).appointment;
                final draft = ref.read(bookingDraftProvider);
                if (draft.doctor == null && lapsed != null) {
                  // Paid from Appointments, not the booking flow: there is
                  // no draft to keep, so start again from the same doctor.
                  context.go(
                    BookingRoutes.booking(
                      step: 2,
                      doctor: lapsed.doctorId,
                      hospital: lapsed.hospitalId,
                    ),
                  );
                  return;
                }
                ref.read(bookingDraftProvider.notifier)
                  ..clearSlot()
                  ..goToStep(2);
                // The booking screen may still be under this one (reused,
                // no new set-up) or be built afresh (resume keeps the
                // draft); either way it opens on Doctor & time.
                context.go(BookingRoutes.booking(step: 2, resume: true));
              },
            ),
            SizedBox(height: 10.h),
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
            SizedBox(height: 10.h),
            // The booking is confirmed (or awaiting the hospital): its token
            // card is one tap away, and Back returns here.
            if (id != null) ...[
              AppButton(
                label: 'View token',
                variant: AppButtonVariant.soft,
                fullWidth: true,
                semanticLabel: 'View the token card for this booking',
                onPressed: () => context.push(AppRoutes.successPath(id)),
              ),
              SizedBox(height: 10.h),
            ],
          ],
          AppButton(
            label: 'Back to Home',
            variant: AppButtonVariant.ghost,
            fullWidth: true,
            onPressed: () => context.go(AppRoutes.home),
          ),
        ],
      ),
    );
  }
}
