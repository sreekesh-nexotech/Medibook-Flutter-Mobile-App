import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/app_notification.dart';
import '../../../../core/mock_data/models/appointment.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../components/notification_card.dart';

/// Notifications (`/notifications`, pushed). Header + a "Recent Notifications /
/// Mark all as read" row over the notification cards. Each card's actions map
/// to navigation or a toast in [_handleAction]. Enters with `screenIn`.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: AppConstants.screenIn,
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10.h),
            child: child,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppInnerHeader(
                title: 'Notifications',
                onBack: () => _goBack(context),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 10.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Notifications',
                      style: AppText.poppins(
                        size: 15,
                        weight: AppText.semibold,
                        color: AppColors.textStrong,
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => ref
                          .read(toastControllerProvider.notifier)
                          .show('All notifications marked as read'),
                      child: Text(
                        'Mark all as read',
                        style: AppText.poppins(
                          size: 13,
                          weight: AppText.medium,
                          color: AppColors.accentBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 24.h),
                  child: Column(
                    children: [
                      for (final notification in notifications)
                        Padding(
                          padding: EdgeInsets.only(bottom: 14.h),
                          child: NotificationCard(
                            notification: notification,
                            onAction: (action) =>
                                _handleAction(context, ref, action),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _handleAction(
    BuildContext context,
    WidgetRef ref,
    NotificationAction action,
  ) {
    void toast(String message) =>
        ref.read(toastControllerProvider.notifier).show(message);

    // Today's appointment ('1') may have been cancelled since the notification
    // was raised; the reschedule/view actions guard on it still being upcoming.
    bool todayApptLive() {
      final appt = ref.read(appointmentByIdProvider('1'));
      return appt != null && appt.bucket == AppointmentBucket.upcoming;
    }

    switch (action) {
      case NotificationAction.rescheduleTodayAppt:
        if (todayApptLive()) {
          context.push(AppRoutes.reschedulePath('1'));
        } else {
          toast('That appointment was cancelled');
        }
      case NotificationAction.viewTodayApptDetail:
        if (todayApptLive()) {
          context.push(AppRoutes.appointmentDetailPath('1'));
        } else {
          toast('That appointment was cancelled');
        }
      case NotificationAction.viewRecords:
        context.go(AppRoutes.records);
      case NotificationAction.downloadPrescription:
        toast('Downloading prescription…');
      case NotificationAction.remindLater:
        toast("We'll remind you tomorrow");
      case NotificationAction.scheduleBooking:
        context.push(AppRoutes.bookingPath(step: 1));
    }
  }
}
