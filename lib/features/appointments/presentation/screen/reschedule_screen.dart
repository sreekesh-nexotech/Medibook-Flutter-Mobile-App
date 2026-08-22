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
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../components/date_chip.dart';
import '../components/enter_animations.dart';
import '../components/time_chip.dart';
import '../controllers/appointments_controller.dart';
import '../controllers/reschedule_controller.dart';

/// `/reschedule/:id` (pushed). Shows the current appointment, a new-date chip
/// row and a new-time chip grid (both driven by the local
/// [rescheduleControllerProvider]), and confirms the change back onto the
/// appointment.
class RescheduleScreen extends ConsumerWidget {
  const RescheduleScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointment = ref.watch(appointmentByIdProvider(id));

    final Widget body;
    if (appointment == null) {
      body = _notFound(context);
    } else {
      final doctor = ref.watch(doctorByIdProvider(appointment.doctorId));
      final selection = ref.watch(rescheduleControllerProvider(id));
      final dateChips = AppDates.upcomingChips();
      final timeSlots = ref.watch(timeSlotsProvider);
      body = _content(
        context,
        ref,
        appointment,
        doctor,
        selection,
        dateChips,
        timeSlots,
      );
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
    RescheduleSelection selection,
    List<DateChip> dateChips,
    List<String> timeSlots,
  ) {
    return Column(
      children: [
        AppInnerHeader(title: 'Reschedule', onBack: () => _back(context)),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _currentCard(appt, doctor),
                _sectionTitle('Select new date'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.only(bottom: 4.h),
                  child: Row(
                    children: [
                      for (var i = 0; i < dateChips.length; i++) ...[
                        if (i > 0) SizedBox(width: 10.w),
                        ApptDateChip(
                          dow: dateChips[i].dow,
                          day: dateChips[i].day,
                          selected: selection.dateIndex == i,
                          onTap: () => ref
                              .read(rescheduleControllerProvider(id).notifier)
                              .pickDate(i),
                        ),
                      ],
                    ],
                  ),
                ),
                _sectionTitle('Select new time'),
                Wrap(
                  spacing: 10.w,
                  runSpacing: 10.h,
                  children: [
                    for (final slot in timeSlots)
                      ApptTimeChip(
                        label: slot,
                        selected: selection.time == slot,
                        onTap: () => ref
                            .read(rescheduleControllerProvider(id).notifier)
                            .pickTime(slot),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _footer(context, ref, appt, dateChips),
      ],
    );
  }

  Widget _currentCard(Appointment appt, Doctor doctor) {
    return AppCard(
      padding: EdgeInsets.all(14.w),
      child: Row(
        children: [
          AppAvatar(name: doctor.name, imageAsset: doctor.imageAsset, size: 44),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    size: 14,
                    weight: AppText.semibold,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Currently: ${appt.date} · ${appt.time}',
                  style: AppText.poppins(size: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: EdgeInsets.only(top: 20.h, bottom: 12.h),
      child: Text(
        text,
        style: AppText.poppins(
          size: 16,
          weight: AppText.semibold,
          color: AppColors.textStrong,
        ),
      ),
    );
  }

  Widget _footer(
    BuildContext context,
    WidgetRef ref,
    Appointment appt,
    List<DateChip> dateChips,
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
      child: AppButton(
        label: 'Confirm New Time',
        fullWidth: true,
        onPressed: () => _confirm(context, ref, appt, dateChips),
      ),
    );
  }

  void _confirm(
    BuildContext context,
    WidgetRef ref,
    Appointment appt,
    List<DateChip> dateChips,
  ) {
    final selection = ref.read(rescheduleControllerProvider(id));
    final index = selection.dateIndex.clamp(0, dateChips.length - 1);
    final dateFull = dateChips[index].full;
    ref
        .read(appointmentsControllerProvider.notifier)
        .reschedule(appt.id, dateFull: dateFull, time: selection.time);
    context.go(AppRoutes.appointmentDetailPath(appt.id));
    ref.read(toastControllerProvider.notifier).show('Appointment rescheduled');
  }

  Widget _notFound(BuildContext context) {
    return Column(
      children: [
        AppInnerHeader(title: 'Reschedule', onBack: () => _back(context)),
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

  /// Back to the appointment detail this flow was opened from; falls back to the
  /// detail path when there is nothing to pop.
  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.appointmentDetailPath(id));
    }
  }
}
