import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/appointment.dart';
import '../../../../core/mock_data/models/doctor.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_rating.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../../../core/widgets/status_style.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../components/detail_row.dart';
import '../components/enter_animations.dart';
import '../controllers/appointments_controller.dart';

/// `/appointment/:id` (pushed). Header card (doctor + status), the detail rows
/// (Patient / Department / Hospital / Date / Time / Token) and the arrival note.
/// Footer switches on the bucket: Reschedule + Cancel when Upcoming, Book Again
/// when Past.
class AppointmentDetailScreen extends ConsumerWidget {
  const AppointmentDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointment = ref.watch(appointmentByIdProvider(id));

    final Widget body;
    if (appointment == null) {
      body = _notFound(context);
    } else {
      final doctor = ref.watch(doctorByIdProvider(appointment.doctorId));
      body = _content(context, ref, appointment, doctor);
    }

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(child: ScreenEnter(child: body)),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    Appointment appt,
    Doctor doctor,
  ) {
    final isUpcoming = appt.bucket == AppointmentBucket.upcoming;
    return Column(
      children: [
        AppInnerHeader(
          title: 'Appointment Details',
          onBack: () => _back(context),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerCard(appt, doctor),
                SizedBox(height: 14.h),
                _rowsCard(appt, doctor),
              ],
            ),
          ),
        ),
        _footer(context, ref, appt, doctor, isUpcoming),
      ],
    );
  }

  Widget _headerCard(Appointment appt, Doctor doctor) {
    return AppCard(
      child: Row(
        children: [
          AppAvatar(name: doctor.name, imageAsset: doctor.imageAsset, size: 56),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  maxLines: 1,
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
                  style: AppText.poppins(size: 12, color: AppColors.textMuted),
                ),
                SizedBox(height: 4.h),
                AppRating(value: doctor.rating, showValue: true, size: 12),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          AppStatusPill(
            label: appt.status.label,
            colors: AppStatusStyle.appointment(appt.status),
          ),
        ],
      ),
    );
  }

  Widget _rowsCard(Appointment appt, Doctor doctor) {
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailRow(label: 'Patient', value: appt.patient),
          DetailRow(label: 'Department', value: doctor.department),
          DetailRow(label: 'Hospital', value: doctor.hospital),
          DetailRow(label: 'Date', value: appt.date),
          DetailRow(label: 'Time', value: appt.time),
          DetailRow(
            label: 'Token',
            value: appt.token,
            valueColor: AppColors.accentBlue,
            valueWeight: AppText.bold,
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

  Widget _footer(
    BuildContext context,
    WidgetRef ref,
    Appointment appt,
    Doctor doctor,
    bool isUpcoming,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 22.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.w),
        ),
      ),
      child: isUpcoming
          ? Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Reschedule',
                    variant: AppButtonVariant.soft,
                    fullWidth: true,
                    onPressed: () =>
                        context.push(AppRoutes.reschedulePath(appt.id)),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.danger,
                    fullWidth: true,
                    onPressed: () => _confirmCancel(context, ref, appt, doctor),
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
                  dept: doctor.department,
                  doctor: doctor.id,
                  origin: 'appointments',
                ),
              ),
            ),
    );
  }

  void _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    Appointment appt,
    Doctor doctor,
  ) {
    showMedibookSheet(
      context,
      title: 'Cancel Appointment',
      message:
          'Are you sure you want to cancel your appointment with '
          '${doctor.name}?',
      confirmLabel: 'Yes, Cancel',
      confirmVariant: AppButtonVariant.danger,
      onConfirm: () {
        ref.read(appointmentsControllerProvider.notifier).cancel(appt.id);
        context.go(AppRoutes.appointments);
        ref
            .read(toastControllerProvider.notifier)
            .show('Appointment cancelled');
      },
    );
  }

  Widget _notFound(BuildContext context) {
    return Column(
      children: [
        AppInnerHeader(
          title: 'Appointment Details',
          onBack: () => _back(context),
        ),
        Expanded(
          child: Center(
            child: Text(
              'Appointment not found.',
              style: AppText.poppins(size: 14, color: AppColors.textMuted),
            ),
          ),
        ),
      ],
    );
  }

  /// Back to wherever the detail was opened from; falls back to the
  /// Appointments tab when there is nothing to pop (e.g. after a reschedule
  /// `context.go` reset the stack).
  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.appointments);
    }
  }
}
