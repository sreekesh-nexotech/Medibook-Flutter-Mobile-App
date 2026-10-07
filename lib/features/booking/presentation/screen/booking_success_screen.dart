import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/motion.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/route_arrival.dart';
import '../../../../core/widgets/app_check_badge.dart';
import '../../../../core/widgets/states/app_error_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../appointments/presentation/components/calendar_action.dart';
import '../../application/providers/booking_providers.dart';
import '../../domain/entities/token_card.dart';
import '../components/token_actions.dart';

/// Booking confirmation: `/success?appt=<appointmentId>`.
///
/// Everything on the card comes from `GET /patient/appointments/{id}/token-card`
/// (§10.4) — the booking reference, the token label, hospital, doctor, date
/// and time, already in hospital-local time. Nothing is minted here. An
/// appointment the account cannot see (`404`) says so rather than inventing
/// a confirmation.
class BookingSuccessScreen extends ConsumerWidget {
  const BookingSuccessScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = appointmentId.isEmpty
        ? const AsyncValue<TokenCard>.error(
            NotFoundFailure(resource: 'appointment'),
            StackTrace.empty,
          )
        : ref.watch(tokenCardProvider(appointmentId));

    return RouteArrival(
      onArrive: () => ref.invalidate(tokenCardProvider(appointmentId)),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        // top:false — the design centers this screen's content on the full
        // screen height (the status zone is part of the white canvas).
        body: SafeArea(
          top: false,
          child: _FadeEnter(
            child: card.when(
              loading: () => Padding(
                padding: EdgeInsets.all(28.w),
                child: const AppLoadingView(label: 'Fetching your token card'),
              ),
              error: (error, _) => Padding(
                padding: EdgeInsets.all(28.w),
                child: AppErrorView(
                  failure: error.asFailure(),
                  headline: error is NotFoundFailure
                      ? 'That booking is not on this account'
                      : null,
                  onRetry: appointmentId.isEmpty
                      ? null
                      : () => ref.invalidate(tokenCardProvider(appointmentId)),
                  secondaryLabel: 'See my appointments',
                  onSecondary: () => context.go(AppRoutes.appointments),
                ),
              ),
              data: (token) => SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 28.h),
                child: Column(
                  children: [
                    const AppCheckBadge(),
                    SizedBox(height: 22.h),
                    Text(
                      token.status == 'pending_approval'
                          ? 'Booked — awaiting hospital confirmation'
                          : 'Appointment booked successfully',
                      textAlign: TextAlign.center,
                      style: AppText.poppins(
                        size: AppFontSize.h2,
                        weight: AppText.bold,
                        color: AppColors.textStrong,
                        height: 1.3,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    TokenActionsCard(
                      token: token.tokenLabel ?? 'Assigned by the hospital',
                      bookingRef: token.bookingRef,
                      dateLabel: token.date,
                      whenLabel:
                          '${token.date} · ${token.timeRangeLabel}'
                          '${token.sessionLabel == null ? '' : ' · ${token.sessionLabel}'}',
                      doctorName: token.doctorName,
                      hospitalName: token.hospitalName,
                      patientName: token.patientName,
                      qrPayload: token.qrPayload,
                      calendarBusy: watchCalendarBusy(ref, appointmentId),
                      onAddToCalendar: () =>
                          addAppointmentToCalendar(context, ref, appointmentId),
                    ),
                    SizedBox(height: 24.h),
                    AppButton(
                      label: 'View Appointment',
                      fullWidth: true,
                      onPressed: () => context.go(
                        AppRoutes.appointmentDetailPath(appointmentId),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    AppButton(
                      label: 'Back to Home',
                      variant: AppButtonVariant.soft,
                      fullWidth: true,
                      onPressed: () => context.go(AppRoutes.home),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Success-screen enter: a plain fade over [AppConstants.successFadeIn],
/// collapsed to nothing when the OS asks for reduced motion (§3.3.8).
class _FadeEnter extends StatelessWidget {
  const _FadeEnter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: context.motion(AppConstants.successFadeIn),
      curve: Curves.easeOut,
      builder: (context, t, child) =>
          Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      child: child,
    );
  }
}
