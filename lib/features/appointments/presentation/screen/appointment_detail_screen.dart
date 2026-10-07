import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/server_clock.dart';
import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/storage/cache/cached_fetcher.dart' show CachedResult;
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_countdown.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_rating.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_error_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../../core/widgets/states/app_not_found_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../application/providers/appointments_provider.dart';
import '../../application/states/appointment_action_state.dart';
import '../../application/usecases/hospital_time.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/appointment_detail.dart';
import '../../domain/entities/appointment_event.dart';
import '../../domain/entities/payment.dart';
import '../components/cancellation_notice.dart';
import '../components/detail_row.dart';
import '../components/enter_animations.dart';
import '../components/freshness_bar.dart';
import '../components/status_pill.dart';
import '../../application/providers/appointment_filter_controller.dart'
    show statusLabel;

/// `/appointment/:id` (pushed).
///
/// Header card (doctor + the backend status and what it means), the detail
/// rows, the money card (fee snapshot, payment order, refunds, receipt link),
/// the history timeline, the Call Ambulance entry point, and the footer whose
/// buttons come straight from `actions` (§10.2): Cancel (via the
/// cancellation preview, §10.6–10.7), Retry payment, Review, Book again.
///
/// There is no reschedule in v2 — the backend offers Cancel + Book again.
class AppointmentDetailScreen extends ConsumerWidget {
  const AppointmentDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(appointmentDetailProvider(id));
    final actionState = ref.watch(appointmentActionsProvider(id));

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: ScreenEnter(
          child: Column(
            children: [
              AppInnerHeader(
                title: 'Appointment Details',
                onBack: () => _leave(context),
              ),
              Expanded(
                child: detail.when(
                  loading: () => const AppSkeletonList(count: 3),
                  error: (error, _) => _error(context, ref, error),
                  data: (result) => _content(context, ref, result, actionState),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _error(BuildContext context, WidgetRef ref, Object error) {
    final failure = error.asFailure();
    if (failure is NotFoundFailure) {
      return AppNotFoundView(
        headline: 'Appointment not found',
        body:
            'This appointment is not on your account. It may have been '
            'booked under another sign-in.',
        attemptedPath: AppRoutes.appointmentDetailPath(id),
        iconName: PhIcon.calendarBlank,
        onGoBack: context.canPop() ? () => context.pop() : null,
        onGoHome: () => context.go(AppRoutes.appointments),
      );
    }
    return AppErrorView(
      failure: failure,
      onRetry: () => ref.invalidate(appointmentDetailProvider(id)),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    CachedResult<AppointmentDetail> result,
    AppointmentActionState actionState,
  ) {
    final detail = result.value;
    final appointment = detail.appointment;
    return Column(
      children: [
        FreshnessBar(
          isStale: result.isStale,
          revalidating: result.revalidating,
          cachedAt: result.cachedAt,
          onRefresh: () => _refresh(ref),
        ),
        Expanded(
          child: AppRefreshIndicator(
            semanticsLabel: 'Refresh appointment',
            onRefresh: () => _refresh(ref),
            child: SingleChildScrollView(
              physics: appRefreshPhysics,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.x5.w,
                6.h,
                AppSpacing.x5.w,
                24.h,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderCard(appointment: appointment),
                  SizedBox(height: 14.h),
                  _DetailsCard(appointment: appointment),
                  SizedBox(height: 14.h),
                  _MoneyCard(detail: detail),
                  SizedBox(height: 14.h),
                  _HistoryCard(
                    appointmentId: id,
                    timezone: appointment.hospital.timezone,
                  ),
                  SizedBox(height: 14.h),
                  const _EmergencyCard(),
                  if (appointment.status.hasTokenCard)
                    DetailActionRow(
                      iconName: PhIcon.eye,
                      title: 'View token',
                      subtitle:
                          'Your token card and booking reference, to show '
                          'at the hospital desk.',
                      semanticLabel: 'View the token card for this appointment',
                      onTap: () =>
                          context.push(AppRoutes.successPath(appointment.id)),
                      margin: EdgeInsets.only(top: 14.h),
                    ),
                  if (appointment.status.offersLiveQueue)
                    DetailActionRow(
                      iconName: PhIcon.clock,
                      title: 'Live queue',
                      subtitle: appointment.status.isInQueue
                          ? 'See who is being seen and how far your token '
                                'is from the desk.'
                          : 'Opens on the day — see the desk move in real '
                                'time once the session starts.',
                      semanticLabel:
                          'Open the live queue for ${appointment.doctor.name}',
                      onTap: () =>
                          context.push(AppRoutes.queuePath(appointment.id)),
                      margin: EdgeInsets.only(top: 14.h),
                    ),
                  if (actionState.preview != null && detail.actions.canCancel)
                    CancellationNotice(
                      preview: actionState.preview!,
                      timezone: appointment.hospital.timezone,
                    ),
                ],
              ),
            ),
          ),
        ),
        _Footer(
          detail: detail,
          actionState: actionState,
          onCancel: () => _confirmCancel(context, ref, detail),
          onRetryPayment: () => _retryPayment(context, detail),
          onReview: () => _review(context, ref, detail),
          onBookAgain: () => context.push(
            AppRoutes.bookingPath(
              step: 3,
              dept: appointment.department.code ?? appointment.department.id,
              doctor: appointment.doctor.id,
              origin: 'appointments',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(appointmentDetailProvider(id));
    ref.invalidate(appointmentEventsProvider(id));
    await ref.read(appointmentDetailProvider(id).future);
  }

  /// `GET cancellation-preview` → confirm dialog showing `refund_paise` →
  /// `POST cancel` with one Idempotency-Key per attempt (§10.6–10.7).
  ///
  /// The controller never claims a cancellation that did not happen: the
  /// toast is built from its outcome, and a failure is its `userMessage`.
  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    AppointmentDetail detail,
  ) async {
    final actions = ref.read(appointmentActionsProvider(id).notifier);
    final toast = ref.read(toastControllerProvider.notifier);

    final preview = await actions.previewCancellation();
    if (!context.mounted) return;
    if (preview == null) {
      toast.show(
        ref.read(appointmentActionsProvider(id)).failure?.userMessage ??
            'Could not check the cancellation policy. Please try again.',
      );
      return;
    }
    if (!preview.allowed) {
      toast.show(CancellationNotice.consequence(preview));
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Cancel this appointment?',
      consequence: CancellationNotice.consequence(preview),
      confirmLabel: 'Yes, cancel',
      cancelLabel: 'Keep appointment',
      iconName: PhIcon.calendarBlank,
    );
    if (confirmed != true || !context.mounted) return;

    final outcome = await actions.cancel();
    if (!context.mounted) return;
    if (outcome == null) {
      final failure = ref.read(appointmentActionsProvider(id)).failure;
      toast.show(
        failure?.userMessage ??
            'The appointment could not be cancelled. Please try again.',
      );
      // The server refused (the token was called, the booking was cancelled
      // elsewhere …): what is on screen is out of date, so read it again
      // rather than leave a Cancel button that can only fail (BL-APPT-049).
      // A blip is different — nothing changed, and the retry keeps its key.
      if (failure != null && !failure.isRetryable) {
        // Drop the saved copy first, or the re-read is answered from memory.
        await ref.read(appointmentsRepositoryProvider).invalidate();
        if (!context.mounted) return;
        ref.invalidate(appointmentDetailProvider(id));
        ref.invalidate(appointmentEventsProvider(id));
      }
      return;
    }

    final refunded = Money.total(outcome.refunds.map((r) => r.amount));
    toast.show(
      refunded.isZero
          ? 'Appointment cancelled.'
          : 'Appointment cancelled · ${refunded.format()} refund requested',
    );
    // The repository already invalidated the cache; re-read so every list
    // and the Home card agree, then leave the screen. The tab lists live
    // under this screen (shell tab), so they are invalidated explicitly.
    ref.invalidate(upcomingAppointmentsPeekProvider);
    ref.invalidate(appointmentDetailProvider(id));
    ref.invalidate(appointmentsListProvider);
    context.go(AppRoutes.appointments);
  }

  /// "Retry payment": hands the order to the payment feature (which owns
  /// Razorpay and §9.4 `retry`), addressed by appointment + order id.
  void _retryPayment(BuildContext context, AppointmentDetail detail) {
    final order = detail.paymentOrder;
    final query = <String>[
      'appt=${detail.appointment.id}',
      if (order != null) 'order=${order.id}',
    ];
    context.push('${AppRoutes.bookingPayment}?${query.join('&')}');
  }

  /// Rating + optional comment → `POST review` (§10.12).
  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    AppointmentDetail detail,
  ) async {
    final input = await showDialog<({int rating, String comment})>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _ReviewDialog(doctorName: detail.appointment.doctor.name),
    );
    if (input == null || !context.mounted) return;

    final review = await ref
        .read(appointmentActionsProvider(id).notifier)
        .submitReview(rating: input.rating, comment: input.comment);
    if (!context.mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    if (review == null) {
      toast.show(
        ref.read(appointmentActionsProvider(id)).failure?.userMessage ??
            'Your review could not be sent. Please try again.',
      );
      return;
    }
    toast.show('Thanks — your review is with the hospital for moderation.');
    ref.invalidate(appointmentDetailProvider(id));
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.appointments);
    }
  }
}

/// Doctor identity, the backend status pill and the one line explaining it.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final doctor = appointment.doctor;
    final deadline = appointment.bookingDeadlineAt;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: doctor.name, size: 56),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.poppins(
                        size: 16,
                        weight: AppText.bold,
                        color: AppColors.textStrong,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      [
                        doctor.title,
                        doctor.specialisation ?? appointment.department.name,
                      ].whereType<String>().join(' · '),
                      style: AppText.poppins(
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              AppointmentStatusPill(status: appointment.status),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            AppointmentStatusStyle.hint(appointment),
            style: AppText.poppins(
              size: 12,
              color: AppColors.textBody,
              height: 1.5,
            ),
          ),
          if (appointment.status == AppointmentStatus.pendingPayment &&
              deadline != null &&
              deadline.isAfter(DateTime.now())) ...[
            SizedBox(height: 8.h),
            Row(
              children: [
                AppIcon(PhIcon.clock, size: 14, color: AppColors.dangerText),
                SizedBox(width: 6.w),
                Text(
                  'Pay within ',
                  style: AppText.poppins(size: 12, color: AppColors.dangerText),
                ),
                AppCountdown(deadline: ServerClock.onDeviceClock(deadline)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Patient / department / hospital / date / time / token / booking reference.
class _DetailsCard extends ConsumerWidget {
  const _DetailsCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(personForLabelProvider(appointment.personId));
    final token = appointment.tokenLabel;
    final start = appointment.scheduledStartAt;
    final zone = appointment.hospital.timezone;
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailRow(
            label: 'Patient',
            value: person ?? 'Family member',
            valueColor: person == null ? AppColors.textMuted : null,
          ),
          DetailRow(label: 'Department', value: appointment.department.name),
          DetailRow(
            label: 'Hospital',
            value: appointment.hospital.name,
            caption: appointment.hospital.city,
          ),
          if (appointment.doctor.room != null)
            DetailRow(label: 'Room', value: appointment.doctor.room!),
          DetailRow(
            label: 'Date',
            value: HospitalTime.dayMonthYear(start, timezone: zone),
            caption: HospitalTime.isToday(start, timezone: zone)
                ? 'Today'
                : null,
          ),
          DetailRow(
            label: 'Time',
            value:
                '${HospitalTime.time(start, timezone: zone)} – '
                '${HospitalTime.time(appointment.scheduledEndAt, timezone: zone)}',
          ),
          DetailRow(
            label: 'Token',
            value: token ?? 'Issued at the desk',
            valueColor: token == null
                ? AppColors.textMuted
                : AppColors.accentBlue,
            valueWeight: token == null ? null : AppText.bold,
          ),
          DetailRow(
            label: 'Booking reference',
            value: appointment.bookingRef,
            showDivider: appointment.patientNotes != null,
          ),
          if (appointment.patientNotes != null)
            DetailRow(
              label: 'Your notes',
              value: appointment.patientNotes!,
              showDivider: false,
            ),
          Padding(
            padding: EdgeInsets.only(top: 12.h),
            child: Text(
              'Please arrive 15 minutes early and carry any previous reports.',
              style: AppText.poppins(
                size: 12,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The fee snapshot (§8.3: displayed as booked, never recomputed), the
/// payment status, refunds (CM-22) and the receipt link (CM-29).
class _MoneyCard extends StatelessWidget {
  const _MoneyCard({required this.detail});

  final AppointmentDetail detail;

  @override
  Widget build(BuildContext context) {
    final appointment = detail.appointment;
    final receipt = detail.receipt;
    final refunds = detail.refunds;
    final zone = appointment.hospital.timezone;
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
          DetailRow(
            label: 'Consultation fee',
            value: appointment.consultationFee.format(),
          ),
          if (!appointment.serviceFee.isZero)
            DetailRow(
              label: 'Service fee',
              value: appointment.serviceFee.format(),
            ),
          if (!appointment.discount.isZero)
            DetailRow(
              label: 'Discount',
              value: '−${appointment.discount.format()}',
              valueColor: AppColors.successText,
            ),
          if (!appointment.convenienceFee.isZero)
            DetailRow(
              label: 'Convenience fee',
              value: appointment.convenienceFee.format(),
            ),
          if (!appointment.tax.isZero)
            DetailRow(label: 'Taxes', value: appointment.tax.format()),
          DetailRow(
            label: 'Total',
            value: appointment.total.format(),
            valueWeight: AppText.bold,
          ),
          DetailRow(
            label: 'Payment status',
            value: _paymentStatusLabel(appointment.paymentStatus),
            caption: detail.paymentOrder == null
                ? null
                : 'Order ${detail.paymentOrder!.status}',
            showDivider: refunds.isNotEmpty,
          ),
          // CM-22: the refund rows — how much, what state, and when. Absent
          // entirely when no refund exists, rather than a reassuring "None".
          for (final (index, refund) in refunds.indexed)
            DetailRow(
              label: 'Refund',
              value: refund.amount.format(),
              caption: _refundCaption(refund, zone),
              showDivider: index < refunds.length - 1,
            ),
          DetailActionRow(
            iconName: PhIcon.folder,
            title: 'Receipt',
            subtitle: receipt != null
                ? 'Receipt ${receipt.receiptNo}'
                      '${receipt.issuedAt == null ? '' : ' · issued ${HospitalTime.dayMonthYear(receipt.issuedAt!, timezone: zone)}'}'
                : 'A receipt is issued once the payment settles.',
            semanticLabel: receipt != null
                ? 'Open the receipt for this appointment'
                : 'Receipt unavailable — the payment has not settled',
            trailingLabel: receipt != null ? appointment.total.format() : null,
            onTap: receipt != null
                ? () => context.push(AppRoutes.receiptPath(appointment.id))
                : null,
          ),
        ],
      ),
    );
  }

  static String _paymentStatusLabel(AppointmentPaymentStatus status) =>
      switch (status) {
        AppointmentPaymentStatus.unpaid => 'Not paid',
        AppointmentPaymentStatus.pending => 'Payment pending',
        AppointmentPaymentStatus.paid => 'Paid',
        AppointmentPaymentStatus.refunded => 'Refunded',
        AppointmentPaymentStatus.failed => 'Payment failed',
      };

  /// "Processing · requested 12 Aug 2026".
  static String _refundCaption(Refund refund, String? zone) {
    final status = switch (refund.status) {
      RefundStatus.requested => 'Requested',
      RefundStatus.processing => 'Processing',
      RefundStatus.processed => 'Processed',
      RefundStatus.failed => 'Failed',
    };
    final when = refund.processedAt ?? refund.requestedAt;
    return when == null
        ? status
        : '$status · ${HospitalTime.dayMonthYear(when, timezone: zone)}';
  }
}

/// The history timeline (§10.3).
class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.appointmentId, this.timezone});

  final String appointmentId;

  /// The hospital's zone, for the event stamps.
  final String? timezone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(appointmentEventsProvider(appointmentId));
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'History',
            style: AppText.poppins(
              size: 14,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          events.when(
            loading: () => Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: const AppSkeletonLine(height: 12),
            ),
            error: (error, _) => AppInlineError(
              failure: error.asFailure(),
              onRetry: () =>
                  ref.invalidate(appointmentEventsProvider(appointmentId)),
              margin: EdgeInsets.only(top: 10.h),
            ),
            data: (rows) => rows.isEmpty
                ? AppInlineEmpty(
                    message: 'No events recorded yet.',
                    margin: EdgeInsets.only(top: 10.h),
                  )
                : Column(
                    children: [
                      for (final (index, event) in rows.indexed)
                        DetailRow(
                          label: HospitalTime.dateAndTime(
                            event.occurredAt,
                            timezone: timezone,
                          ),
                          value: _eventLabel(event),
                          caption: 'by ${event.actorKind}',
                          showDivider: index < rows.length - 1,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static String _eventLabel(AppointmentEvent event) {
    final to = AppointmentStatus.fromWire(event.toStatus);
    final base = switch (event.eventType) {
      'created' => 'Booked',
      'approval_requested' => 'Sent for approval',
      'approved' => 'Approved',
      'checked_in' => 'Checked in',
      'called' => 'Token called',
      'started' => 'Consultation started',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      'no_show' => 'Marked no-show',
      'payment_updated' => 'Payment updated',
      'refund_updated' => 'Refund updated',
      'note_added' => 'Note added',
      'reminder_sent' => 'Reminder sent',
      'token_reassigned' => 'Token reassigned',
      _ => event.eventType.replaceAll('_', ' '),
    };
    return to == null ? base : '$base → ${statusLabel(to)}';
  }
}

/// The Call Ambulance entry point (audit CM-44 / CM-46).
class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Emergency',
            style: AppText.poppins(
              size: 14,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          DetailActionRow(
            iconName: PhIcon.firstAid,
            title: 'Call an ambulance',
            subtitle:
                'Request an ambulance to your location, or see the emergency '
                'numbers for this hospital.',
            semanticLabel: 'Open ambulance request',
            tone: DetailActionTone.emergency,
            onTap: () => context.push(AppRoutes.ambulance),
            margin: EdgeInsets.only(top: 10.h),
          ),
        ],
      ),
    );
  }
}

/// The footer, driven entirely by `actions` (§10.2): Cancel when
/// `can_cancel`, Retry payment when `can_retry_payment`, Review when
/// `can_review`, and Book again for anything closed. A blocked cancel is
/// disabled with the backend's reason in its label rather than allowed to
/// fail after the fact.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.detail,
    required this.actionState,
    required this.onCancel,
    required this.onRetryPayment,
    required this.onReview,
    required this.onBookAgain,
  });

  final AppointmentDetail detail;
  final AppointmentActionState actionState;
  final VoidCallback onCancel;
  final VoidCallback onRetryPayment;
  final VoidCallback onReview;
  final VoidCallback onBookAgain;

  @override
  Widget build(BuildContext context) {
    final actions = detail.actions;
    final upcoming = detail.appointment.status.isUpcoming;
    final busy = actionState.isBusy;

    final Widget body;
    if (upcoming) {
      body = Row(
        children: [
          if (actions.canRetryPayment) ...[
            Expanded(
              child: AppButton(
                label: 'Retry payment',
                fullWidth: true,
                disabled: busy,
                onPressed: onRetryPayment,
              ),
            ),
            SizedBox(width: 12.w),
          ],
          Expanded(
            child: AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.danger,
              fullWidth: true,
              disabled: !actions.canCancel,
              loading: actionState.isRunning(AppointmentActionKind.cancel),
              semanticLabel: actions.canCancel
                  ? 'Cancel this appointment'
                  : 'Cancel unavailable — '
                        '${_blockedReason(actions.cancelBlockedReason)}',
              onPressed: actions.canCancel ? onCancel : null,
            ),
          ),
        ],
      );
    } else {
      body = Row(
        children: [
          if (actions.canReview) ...[
            Expanded(
              child: AppButton(
                label: 'Rate visit',
                variant: AppButtonVariant.soft,
                fullWidth: true,
                loading: actionState.isRunning(AppointmentActionKind.review),
                onPressed: onReview,
              ),
            ),
            SizedBox(width: 12.w),
          ],
          Expanded(
            child: AppButton(
              label: 'Book Again',
              fullWidth: true,
              disabled: busy,
              onPressed: onBookAgain,
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x5.w,
        14.h,
        AppSpacing.x5.w,
        22.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.w),
        ),
      ),
      child: body,
    );
  }

  static String _blockedReason(String? code) => switch (code) {
    'TOKEN_ALREADY_CALLED' => 'your token has already been called',
    'TOKEN_CANCEL_WINDOW_CLOSED' => 'the cancellation window has closed',
    _ => 'this appointment can no longer be cancelled',
  };
}

/// Rating stars + optional comment (§10.12: rating 1–5 required, comment
/// ≤ 2000). Returns the pair, or null when dismissed.
class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.doctorName});

  final String doctorName;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  int _rating = 0;
  final TextEditingController _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        'How was your visit?',
        style: AppText.poppins(
          size: 16,
          weight: AppText.bold,
          color: AppColors.textStrong,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rate ${widget.doctorName}. Reviews are moderated before they '
            'count toward the doctor\'s rating.',
            style: AppText.poppins(
              size: 12,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          SizedBox(height: 12.h),
          AppRating(
            value: _rating.toDouble(),
            size: 28,
            onRate: (value) => setState(() => _rating = value),
          ),
          SizedBox(height: 12.h),
          AppTextField(
            controller: _comment,
            hintText: 'Anything to add? (optional)',
            maxLines: 3,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            semanticLabel: 'Review comment',
          ),
        ],
      ),
      actions: [
        AppButton(
          label: 'Not now',
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.sm,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: 'Send review',
          size: AppButtonSize.sm,
          disabled: _rating == 0,
          semanticLabel: _rating == 0
              ? 'Send review — pick a star rating first'
              : 'Send review',
          onPressed: _rating == 0
              ? null
              : () => Navigator.of(
                  context,
                ).pop((rating: _rating, comment: _comment.text)),
        ),
      ],
    );
  }
}
