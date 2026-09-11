import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/medical_record.dart';
import '../../../../core/mock_data/models/payment.dart';
import '../../../../core/mock_data/stores/documents_store.dart';
import '../../../../core/mock_data/stores/payments_store.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_rating.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_not_found_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../domain/entities/appointment_status_view.dart';
import '../../domain/entities/appointment_token.dart';
import '../../domain/policies/cancellation_policy.dart';
import '../components/detail_row.dart';
import '../components/enter_animations.dart';
import '../components/policy_notice.dart';
import '../components/status_view_pill.dart';
import '../controllers/appointment_actions_controller.dart';
import '../controllers/appointments_controller.dart';

/// `/appointment/:id` (pushed).
///
/// Header card (doctor + the canonical status and what it means), the detail
/// rows, the payment and refund card (CM-22), the receipt link and attached
/// documents (CM-29), the Call Ambulance entry point (CM-44 / CM-46), and the
/// cancel / reschedule footer with its policy consequence shown up front
/// (CM-25 / CM-26).
class AppointmentDetailScreen extends ConsumerWidget {
  const AppointmentDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = ref.watch(appointmentRowProvider(id));

    if (row == null) {
      return AppNotFoundView(
        headline: 'Appointment not found',
        body:
            'This appointment is no longer in your list. It may have been '
            'cancelled from another device.',
        attemptedPath: AppRoutes.appointmentDetailPath(id),
        iconName: MedIcon.calendar,
        onGoBack: context.canPop() ? () => context.pop() : null,
        onGoHome: () => context.go(AppRoutes.appointments),
      );
    }

    final cancelPolicy = ref.watch(
      appointmentPolicyProvider((
        appointmentId: id,
        change: AppointmentChange.cancel,
      )),
    );
    final reschedulePolicy = ref.watch(
      appointmentPolicyProvider((
        appointmentId: id,
        change: AppointmentChange.reschedule,
      )),
    );
    final busy = ref.watch(
      appointmentActionsProvider(id).select((state) => state.busy),
    );
    final payment = ref.watch(paymentForAppointmentProvider(id));
    final documents = ref.watch(documentsForAppointmentProvider(id));

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
                        _HeaderCard(row: row),
                        SizedBox(height: 14.h),
                        _DetailsCard(row: row),
                        SizedBox(height: 14.h),
                        _PaymentCard(
                          appointmentId: id,
                          payment: payment,
                          status: row.status,
                        ),
                        SizedBox(height: 14.h),
                        _DocumentsCard(documents: documents),
                        SizedBox(height: 14.h),
                        const _EmergencyCard(),
                        if (row.status == AppointmentStatusView.inQueue)
                          DetailActionRow(
                            iconName: MedIcon.clock,
                            title: 'Live queue',
                            subtitle:
                                'See who is being seen and how far your token '
                                'is from the desk.',
                            semanticLabel:
                                'Open the live queue for ${row.doctor.name}',
                            onTap: () => context.push(
                              AppRoutes.queuePath(row.appointment.doctorId),
                            ),
                            margin: EdgeInsets.only(top: 14.h),
                          ),
                        if (cancelPolicy != null && row.status.allowsChange)
                          PolicyNotice(outcome: cancelPolicy),
                      ],
                    ),
                  ),
                ),
              ),
              _Footer(
                row: row,
                busy: busy,
                cancelPolicy: cancelPolicy,
                reschedulePolicy: reschedulePolicy,
                onCancel: () => _confirmCancel(context, ref, cancelPolicy),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Re-derive the appointment's status, queue position and payment state.
  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(appointmentRowProvider(id));
    await Future<void>.delayed(AppConstants.easeShort);
  }

  /// Confirm, then cancel — and report exactly what happened.
  ///
  /// The dialog's required `consequence` is the CM-25 finding: the cut-off, the
  /// window the patient is in and what it does to their money, before they
  /// commit. The result message comes from the controller, which never claims a
  /// refund the ledger refused (`PaymentsStore.refund` returns `bool`).
  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    PolicyOutcome? outcome,
  ) async {
    if (outcome == null || !outcome.isAllowed) return;

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Cancel this appointment?',
      consequence: outcome.consequence,
      confirmLabel: 'Yes, cancel',
      cancelLabel: 'Keep appointment',
      iconName: MedIcon.calendar,
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(appointmentActionsProvider(id).notifier)
        .cancel(outcome);
    if (!context.mounted) return;

    ref.read(toastControllerProvider.notifier).show(result.message);
    // Stay on the screen when nothing changed — sending the patient back to a
    // list that still shows the appointment reads as a silent failure.
    if (result.ok) context.go(AppRoutes.appointments);
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.appointments);
    }
  }
}

/// Doctor identity, the canonical status pill and the one line explaining it.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.row});

  final AppointmentRow row;

  @override
  Widget build(BuildContext context) {
    final doctor = row.doctor;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(
                name: doctor.name,
                imageAsset: doctor.imageAsset,
                size: 56,
              ),
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
                      doctor.spec,
                      style: AppText.poppins(
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    AppRating(value: doctor.rating, showValue: true, size: 12),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              AppointmentStatusViewPill(status: row.status),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            row.status.hint,
            style: AppText.poppins(
              size: 12,
              color: AppColors.textBody,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Patient / department / hospital / date / time / token / booking reference.
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.row});

  final AppointmentRow row;

  @override
  Widget build(BuildContext context) {
    final appointment = row.appointment;
    final bookingRef = appointment.bookingRef;
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailRow(label: 'Patient', value: appointment.patient),
          DetailRow(label: 'Department', value: row.doctor.department),
          DetailRow(label: 'Hospital', value: row.hospitalName),
          DetailRow(
            label: 'Date',
            value: AppDates.dayMonthYear(appointment.scheduledAt),
            caption: appointment.isToday ? 'Today' : null,
          ),
          DetailRow(label: 'Time', value: appointment.time),
          DetailRow(
            label: 'Token',
            // Canonical `T-025`, not the stored `A-25`.
            value: AppointmentToken.normalize(appointment.token),
            valueColor: AppColors.accentBlue,
            valueWeight: AppText.bold,
          ),
          DetailRow(
            label: 'Booking reference',
            value: bookingRef ?? 'Not recorded',
            valueColor: bookingRef == null ? AppColors.textMuted : null,
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

/// Payment status, the refund row (CM-22) and the receipt link (CM-29).
class _PaymentCard extends ConsumerWidget {
  const _PaymentCard({
    required this.appointmentId,
    required this.payment,
    required this.status,
  });

  final String appointmentId;
  final PaymentRecord? payment;
  final AppointmentStatusView status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = payment;
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
          if (record == null)
            AppInlineEmpty(
              message:
                  'No payment has been recorded for this appointment yet. The '
                  'fee is settled at the hospital desk.',
              iconName: MedIcon.bag,
              actionLabel: 'Contact support',
              onAction: () => context.push(AppRoutes.support),
              margin: EdgeInsets.only(top: 8.h),
            )
          else ...[
            DetailRow(label: 'Amount', value: record.amountLabel),
            DetailRow(label: 'Method', value: record.method.label),
            DetailRow(
              label: 'Payment status',
              value: record.status.label,
              caption: record.failureReason,
            ),
            DetailRow(
              label: 'Paid at',
              value: record.paidAtLabel ?? 'Not paid yet',
              valueColor: record.paidAt == null ? AppColors.textMuted : null,
              showDivider: record.hasRefund,
            ),
            // CM-22: the refund row — how much, what state, and when it was
            // raised. Absent entirely when no refund exists, rather than a
            // reassuring "None".
            if (record.hasRefund)
              DetailRow(
                label: 'Refund',
                value: record.refundAmountLabel!,
                caption: _refundCaption(record),
                showDivider: false,
              ),
            DetailActionRow(
              iconName: MedIcon.records,
              title: 'Receipt',
              subtitle: record.hasReceipt
                  ? 'GST invoice with the fee, 18% GST and the total.'
                  : 'A receipt is issued once the payment settles.',
              semanticLabel: record.hasReceipt
                  ? 'Open the GST receipt for this appointment'
                  : 'Receipt unavailable — the payment has not settled',
              trailingLabel: record.hasReceipt ? record.amountLabel : null,
              onTap: record.hasReceipt
                  ? () => context.push(AppRoutes.receiptPath(appointmentId))
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  /// "Refund requested · 12 Aug 2026" — the status and, where the ledger knows
  /// it, when. The ledger stores no refund timestamp of its own in this build,
  /// so the payment date is used and labelled as such.
  String _refundCaption(PaymentRecord record) {
    final paidAt = record.paidAt;
    final label = record.refundStatus!.label;
    if (paidAt == null) return label;
    return '$label · against the payment of ${AppDates.dayMonthYear(paidAt)}';
  }
}

/// Attached documents (CM-29) — prescriptions, reports and bills filed against
/// this appointment.
class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({required this.documents});

  final List<MedicalRecord> documents;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attached documents',
            style: AppText.poppins(
              size: 14,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          if (documents.isEmpty)
            AppInlineEmpty(
              message:
                  'Nothing is filed against this appointment yet. '
                  'Prescriptions and reports appear here.',
              iconName: MedIcon.records,
              actionLabel: 'Upload a document',
              onAction: () => context.push(AppRoutes.documentUpload),
              margin: EdgeInsets.only(top: 10.h),
            )
          else
            for (final document in documents)
              DetailActionRow(
                iconName: MedIcon.records,
                title: document.title,
                subtitle:
                    '${document.type.label} · ${document.date}'
                    '${document.hasFile ? ' · ${document.fileSizeLabel}' : ''}',
                semanticLabel: 'Open document ${document.title}',
                onTap: () => context.push(AppRoutes.documentPath(document.id)),
              ),
        ],
      ),
    );
  }
}

/// The Call Ambulance entry point (audit CM-44 / CM-46 — missing from
/// appointment details).
///
/// Navigates to `/ambulance`, which another feature owns; this screen only
/// provides the door, because "I need an ambulance" happens while you are
/// looking at the appointment you were trying to get to.
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
            iconName: MedIcon.hospital,
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

/// Reschedule + Cancel when the appointment can still change, Book Again when
/// it cannot.
///
/// A blocked action is **disabled with its reason** rather than allowed to fail
/// after the fact (CM-25 / CM-26), and both buttons take `loading:` from the
/// action controller so a double tap cannot run the change twice (§3.5.6).
class _Footer extends StatelessWidget {
  const _Footer({
    required this.row,
    required this.busy,
    required this.cancelPolicy,
    required this.reschedulePolicy,
    required this.onCancel,
  });

  final AppointmentRow row;
  final bool busy;
  final PolicyOutcome? cancelPolicy;
  final PolicyOutcome? reschedulePolicy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final canChange = row.status.allowsChange;
    final canCancel = canChange && (cancelPolicy?.isAllowed ?? false);
    final canReschedule = canChange && (reschedulePolicy?.isAllowed ?? false);

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
      child: canChange
          ? Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Reschedule',
                    variant: AppButtonVariant.soft,
                    fullWidth: true,
                    disabled: !canReschedule,
                    loading: busy,
                    semanticLabel: canReschedule
                        ? 'Reschedule this appointment'
                        : 'Reschedule unavailable — '
                              '${reschedulePolicy?.blockedReason ?? 'this appointment can no longer be moved'}',
                    onPressed: canReschedule
                        ? () => context.push(
                            AppRoutes.reschedulePath(row.appointment.id),
                          )
                        : null,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.danger,
                    fullWidth: true,
                    disabled: !canCancel,
                    loading: busy,
                    semanticLabel: canCancel
                        ? 'Cancel this appointment'
                        : 'Cancel unavailable — '
                              '${cancelPolicy?.blockedReason ?? 'this appointment can no longer be cancelled'}',
                    onPressed: canCancel ? onCancel : null,
                  ),
                ),
              ],
            )
          : AppButton(
              label: 'Book Again',
              fullWidth: true,
              onPressed: () => context.push(
                AppRoutes.bookingPath(
                  step: 3,
                  dept: row.doctor.department,
                  doctor: row.doctor.id,
                  origin: 'appointments',
                ),
              ),
            ),
    );
  }
}
