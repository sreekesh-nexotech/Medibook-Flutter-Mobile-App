import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/utils/motion.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../../domain/booking_identifiers.dart';
import '../components/token_actions.dart';
import '../controllers/booking_records_controller.dart';

/// Booking confirmation: `/success?appt=<appointmentId>`.
///
/// ## What the audit changed here
///
/// * **CM-14.** The screen showed a token and nothing else — *"A token is
///   shown. A booking reference number appears nowhere."* The card now leads
///   with both, labelled for what each is: the reference is permanent and is
///   what appointment search matches, the token is the day's queue position.
/// * **CM-15/CM-27.** "Save token card" and "Add to calendar" now exist. There
///   is no file-save, share or calendar package in this build and none may be
///   added, so both are declared stubs rather than fake successes — see
///   [TokenActionsCard].
/// * **CANONICAL_MASTER_DATA §5.** The token renders through
///   [AppTokens.normalize], so it reads `T-026`, never `A-26`.
///
/// The in-app payment flow ends on `/booking/payment/result` instead; this
/// screen stays as the confirmation for any entry that books without a payment
/// step, and as the target of the existing `/success` route.
///
/// Router wiring (unchanged):
/// ```dart
/// GoRoute(
///   path: AppRoutes.success,
///   builder: (context, state) => BookingSuccessScreen(
///     appointmentId: state.uri.queryParameters['appt'] ?? '',
///   ),
/// )
/// ```
class BookingSuccessScreen extends ConsumerWidget {
  const BookingSuccessScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointment = ref.watch(appointmentByIdProvider(appointmentId));
    final record = ref.watch(bookingRecordForProvider(appointmentId));

    return Scaffold(
      backgroundColor: AppColors.surface,
      // top:false — the design centers this screen's content on the full
      // screen height (the status zone is part of the white canvas).
      body: SafeArea(
        top: false,
        child: _FadeEnter(
          child: appointment == null
              ? Padding(
                  padding: EdgeInsets.all(28.w),
                  child: AppEmptyView(
                    iconName: MedIcon.calendar,
                    headline: 'That booking is not on this device',
                    body:
                        'We could not find appointment "$appointmentId". It '
                        'may have been made in another session.',
                    actionLabel: 'See my appointments',
                    onAction: () => context.go(AppRoutes.appointments),
                    secondaryLabel: 'Back to Home',
                    onSecondary: () => context.go(AppRoutes.home),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 28.h),
                  child: Column(
                    children: [
                      _CheckBadge(),
                      SizedBox(height: 22.h),
                      Text(
                        'Appointment booked successfully',
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
                        token: AppTokens.normalize(appointment.token),
                        bookingRef:
                            record?.bookingRef ??
                            appointment.bookingRef ??
                            'Not issued',
                        scheduledAt: appointment.scheduledAt,
                        doctorName: ref
                            .watch(doctorByIdProvider(appointment.doctorId))
                            .name,
                        hospitalName: record?.hospitalId == null
                            ? ref
                                  .watch(
                                    doctorByIdProvider(appointment.doctorId),
                                  )
                                  .hospital
                            : ref
                                  .watch(
                                    hospitalByIdProvider(record!.hospitalId!),
                                  )
                                  .name,
                        onViewQueue: () => context.push(
                          AppRoutes.queuePath(appointment.doctorId),
                        ),
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
    );
  }
}

/// The navy circle with the confirmation tick.
class _CheckBadge extends StatelessWidget {
  const _CheckBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84.w,
      height: 84.w,
      decoration: const BoxDecoration(
        color: AppColors.brand,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: CustomPaint(size: Size(42.w, 42.w), painter: _CheckPainter()),
    );
  }
}

/// The white confirmation tick (`M5 12l4.5 4.5L19 7` in a 24-unit box). Drawn
/// rather than iconised because the DS icon set has no `check` glyph.
class _CheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final paint = Paint()
      ..color = AppColors.textOnBrand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(5 * s, 12 * s)
      ..lineTo(9.5 * s, 16.5 * s)
      ..lineTo(19 * s, 7 * s);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => false;
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
