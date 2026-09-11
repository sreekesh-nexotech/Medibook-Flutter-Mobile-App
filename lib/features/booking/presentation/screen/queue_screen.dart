import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/appointment.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../components/flow_screen_enter.dart';
import '../components/queue_progress_card.dart';

/// Live token progress for one doctor's desk (CM-09, CM-24). Route:
/// `/queue/:doctorId`.
///
/// Reached from the Home token card, the payment confirmation and the
/// appointment's token card. Pull to refresh re-reads the published status —
/// [AppRefreshIndicator] bakes in always-scrollable physics so the gesture
/// works on this short page (audit §3.9.4).
///
/// The refresh is honest: it invalidates `queueStatusProvider` and re-reads
/// it. This build has no live feed, so a re-read of a stable published status
/// returns the same numbers with the same "updated" stamp — which the card
/// shows, rather than pretending the reading is newer than it is.
///
/// Router wiring:
/// ```dart
/// GoRoute(
///   path: '${AppRoutes.queue}/:doctorId',
///   builder: (context, state) =>
///       QueueScreen(doctorId: state.pathParameters['doctorId']!),
/// )
/// ```
class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key, required this.doctorId});

  final String doctorId;

  /// This patient's token at this desk, if they hold one — the upcoming
  /// appointment with this doctor.
  Appointment? _myAppointment(WidgetRef ref) {
    final upcoming = ref.watch(
      appointmentsByBucketProvider(AppointmentBucket.upcoming),
    );
    for (final appointment in upcoming) {
      if (appointment.doctorId == doctorId) return appointment;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctor = ref.watch(doctorByIdProvider(doctorId));
    final status = ref.watch(queueStatusProvider(doctorId));
    final mine = _myAppointment(ref);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: FlowScreenEnter(
          child: Column(
            children: [
              AppInnerHeader(
                title: 'Live queue',
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.home),
              ),
              Expanded(
                child: AppRefreshIndicator(
                  semanticsLabel: 'Refresh the queue',
                  onRefresh: () async {
                    ref.invalidate(queueStatusProvider(doctorId));
                    // Let the indicator complete a visible cycle; the read
                    // itself is synchronous.
                    await Future<void>.delayed(AppConstants.easeShort);
                  },
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 28.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DeskHeader(
                          doctorName: doctor.name,
                          roomLabel: doctor.spec,
                          hospitalName: doctor.hospital,
                        ),
                        SizedBox(height: 14.h),
                        if (status == null)
                          AppEmptyView(
                            iconName: MedIcon.clock,
                            headline: 'This desk publishes no live queue',
                            body:
                                '${doctor.name} does not run a token display, '
                                'so there is no number to follow. Your '
                                'appointment time still stands.',
                            actionLabel: mine == null
                                ? 'Back to Home'
                                : 'Open my appointment',
                            onAction: mine == null
                                ? () => context.go(AppRoutes.home)
                                : () => context.push(
                                    AppRoutes.appointmentDetailPath(mine.id),
                                  ),
                          )
                        else ...[
                          QueueProgressCard(
                            status: status,
                            myToken: mine?.token,
                          ),
                          SizedBox(height: 14.h),
                          _HowItWorks(hasToken: mine != null),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Whose desk this is.
class _DeskHeader extends StatelessWidget {
  const _DeskHeader({
    required this.doctorName,
    required this.roomLabel,
    required this.hospitalName,
  });

  final String doctorName;
  final String roomLabel;
  final String hospitalName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          doctorName,
          style: AppText.poppins(
            size: AppFontSize.h3,
            weight: AppText.bold,
            color: AppColors.textStrong,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          '$roomLabel · $hospitalName',
          style: AppText.poppins(
            size: AppFontSize.sm,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// The two-sentence explanation of what a token is, because the token and the
/// booking reference are different things and the audit found the app using
/// one where it meant the other (CM-14).
class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.hasToken});

  final bool hasToken;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'About tokens',
            style: AppText.poppins(
              size: AppFontSize.base,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: AppSpacing.x2.h),
          Text(
            hasToken
                ? 'Your token is your position in the queue for one day. It '
                      'is reissued every morning, so quote your booking '
                      'reference — not the token — to support.'
                : 'A token is a queue position for one day at one desk. You '
                      'are given one when you book an appointment with this '
                      'doctor.',
            style: AppText.poppins(
              size: AppFontSize.base,
              color: AppColors.textBody,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
