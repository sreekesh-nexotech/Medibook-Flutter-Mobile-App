import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/connectivity/connectivity_monitor.dart';
import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/states/app_error_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../application/providers/appointments_provider.dart';
import '../../application/states/live_queue_state.dart';
import '../../domain/entities/queue_status.dart';
import '../components/enter_animations.dart';
import '../components/freshness_bar.dart';

/// Live token progress for one **appointment** (CM-09, CM-24). Route:
/// `/queue/:appointmentId`.
///
/// Reads `GET /patient/appointments/{id}/queue` (§10.5) and subscribes to
/// `/ws/patient/session/{appointment_id}` (§15.1): every `session.updated`
/// re-fetches the endpoint, a `token.called` for this appointment flips the
/// screen to "it's your turn", and a paused session / `on_break` queue reads
/// as "doctor on a break". The estimated wait is the backend's number.
///
/// Pull to refresh re-reads the endpoint; the socket is owned by
/// [liveQueueProvider] and closes with the screen.
class LiveQueueScreen extends ConsumerWidget {
  const LiveQueueScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveQueueProvider(appointmentId));
    final detail = ref.watch(appointmentDetailProvider(appointmentId));
    final appointment = detail.valueOrNull?.value.appointment;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: ScreenEnter(
          child: Column(
            children: [
              AppInnerHeader(
                title: 'Live queue',
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go(
                        AppRoutes.appointmentDetailPath(appointmentId),
                      ),
              ),
              _ConnectionBar(state: state),
              FreshnessBar(
                failure: state.queue != null ? state.failure : null,
                onRefresh: () => ref
                    .read(liveQueueProvider(appointmentId).notifier)
                    .pullToRefresh(),
              ),
              Expanded(
                child: AppRefreshIndicator(
                  semanticsLabel: 'Refresh the queue',
                  onRefresh: () => ref
                      .read(liveQueueProvider(appointmentId).notifier)
                      .pullToRefresh(),
                  child: SingleChildScrollView(
                    physics: appRefreshPhysics,
                    padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 28.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (appointment != null)
                          _DeskHeader(
                            doctorName: appointment.doctor.name,
                            roomLabel:
                                appointment.doctor.room ??
                                appointment.department.name,
                            hospitalName: appointment.hospital.name,
                          )
                        else
                          const _DeskHeaderSkeleton(),
                        SizedBox(height: 14.h),
                        _body(context, ref, state),
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

  Widget _body(BuildContext context, WidgetRef ref, LiveQueueState state) {
    final queue = state.queue;
    if (state.isLoading && queue == null) {
      return const AppSkeletonCard(hasAvatar: false, lines: 4);
    }
    final failure = state.failure;
    if (queue == null && failure != null) {
      return AppErrorView(
        failure: failure,
        onRetry: () =>
            ref.read(liveQueueProvider(appointmentId).notifier).pullToRefresh(),
        padding: EdgeInsets.symmetric(vertical: 24.h),
      );
    }
    if (queue == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.isYourTurn) ...[
          _YourTurnCard(queue: queue, calledAt: state.calledAt),
          SizedBox(height: 14.h),
        ],
        _QueueCard(queue: queue, isLive: state.isLive),
        SizedBox(height: 14.h),
        const _HowItWorks(),
      ],
    );
  }
}

/// A thin strip saying whether the numbers are live (§15.1) — quiet when
/// they are, explicit when the socket is reconnecting or gave up.
class _ConnectionBar extends ConsumerWidget {
  const _ConnectionBar({required this.state});

  final LiveQueueState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // With the phone offline the app-wide OfflineBar already says why live
    // updates stopped; this line is for drops while the phone is online.
    if (!(ref.watch(isOnlineProvider).valueOrNull ?? true)) {
      return const SizedBox.shrink();
    }
    return switch (state.connection) {
      LiveQueueConnection.live => const SizedBox.shrink(),
      LiveQueueConnection.connecting => const AppErrorBanner(
        message: 'Connecting to live updates…',
        tone: AppBannerTone.info,
      ),
      LiveQueueConnection.reconnecting => const AppErrorBanner(
        message: 'Live updates dropped — reconnecting…',
        tone: AppBannerTone.warning,
      ),
      LiveQueueConnection.offline => const AppErrorBanner(
        message: 'Live updates unavailable. Pull down to refresh.',
        tone: AppBannerTone.warning,
        iconName: PhIcon.warningCircleFill,
      ),
    };
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

class _DeskHeaderSkeleton extends StatelessWidget {
  const _DeskHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSkeletonLine(width: 180, height: 18),
        SizedBox(height: 6.h),
        const AppSkeletonLine(width: 220, height: 12),
      ],
    );
  }
}

/// "It's your turn" — a `token.called` frame for this appointment (§15.1).
class _YourTurnCard extends StatelessWidget {
  const _YourTurnCard({required this.queue, this.calledAt});

  final QueueStatus queue;
  final DateTime? calledAt;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: AppCard(
        color: AppColors.successSoft,
        border: Border.all(color: AppColors.success, width: 1.w),
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            AppIcon(PhIcon.checkBold, size: 24, color: AppColors.successText),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "It's your turn",
                    style: AppText.poppins(
                      size: AppFontSize.title,
                      weight: AppText.bold,
                      color: AppColors.successText,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Token ${queue.yourToken ?? ''} has been called — please '
                    'go to the doctor\'s room now.'
                    '${calledAt == null ? '' : ' Called ${AppDates.relativeAgo(calledAt!)}.'}',
                    style: AppText.poppins(
                      size: AppFontSize.sm,
                      color: AppColors.textBody,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The queue reading (§10.5): now serving, your token, tokens ahead, the
/// backend's wait estimate, and when the desk last published.
class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.queue, required this.isLive});

  final QueueStatus queue;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final (String headline, Color headlineColor) = _headline;
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: AppText.poppins(
              size: AppFontSize.title,
              weight: AppText.bold,
              color: headlineColor,
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Now seeing',
                  value: queue.currentToken ?? '—',
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _Stat(
                  label: 'Your token',
                  value: queue.yourToken ?? '—',
                  accent: true,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Ahead of you',
                  value: '${queue.tokensAhead}',
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _Stat(
                  label: 'Estimated wait',
                  // "Next" only while the session is running: before it opens
                  // or after it ends there is no wait to be next for
                  // (BL-QUEUE-003).
                  value: queue.isOver
                      ? 'Session ended'
                      : queue.isNotOpenYet
                      ? 'Not started'
                      : queue.isOnBreak
                      ? 'Paused'
                      : queue.estimatedWaitMinutes <= 0
                      ? 'Next'
                      : '~${queue.estimatedWaitMinutes} min',
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              AppIcon(
                PhIcon.clock,
                size: 14,
                color: isLive ? AppColors.success : AppColors.textMuted,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  '${isLive ? 'Live' : 'Last update'} · '
                  'updated ${AppDates.relativeAgo(queue.updatedAt)}',
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (String, Color) get _headline {
    if (queue.isOnBreak) return ('Doctor on a break', AppColors.warningText);
    if (queue.isOver) return ('This session has ended', AppColors.textMuted);
    if (queue.isNotOpenYet) {
      return ('The desk has not opened yet', AppColors.textStrong);
    }
    if (queue.isBeingSeen) return ('You are being seen', AppColors.successText);
    return switch (queue.queueState) {
      QueueState.consulting => ('Queue is moving', AppColors.textStrong),
      QueueState.waiting => (
        'Waiting for the next patient',
        AppColors.textStrong,
      ),
      QueueState.available => ('Desk is open', AppColors.textStrong),
      QueueState.onBreak => ('Doctor on a break', AppColors.warningText),
    };
  }
}

/// One labelled number in the queue card.
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.accent = false});

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: accent ? AppColors.surfaceTint : AppColors.surfaceAlt,
        borderRadius: AppRadii.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.poppins(
              size: AppFontSize.xxs,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.poppins(
              size: AppFontSize.h3,
              weight: AppText.bold,
              color: accent ? AppColors.accentBlue : AppColors.textStrong,
            ),
          ),
        ],
      ),
    );
  }
}

/// The two-sentence explanation of what a token is (CM-14).
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

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
            'Your token is your position in the queue for one session. It is '
            'reissued every session, so quote your booking reference — not '
            'the token — to support. The wait estimate is the hospital\'s, '
            'from the tokens ahead of you and the doctor\'s usual time per '
            'patient.',
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
