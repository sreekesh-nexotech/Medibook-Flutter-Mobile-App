import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';

/// Booking success: a navy check badge over the confirmation copy, the token,
/// the date·time·doctor line, and the two exit actions. Route:
/// `/success?appt=<appointmentId>`.
///
/// The router builder wires the constructor from the query, e.g.:
/// ```dart
/// BookingSuccessScreen(
///   appointmentId: state.uri.queryParameters['appt'] ?? '',
/// )
/// ```
class BookingSuccessScreen extends ConsumerWidget {
  const BookingSuccessScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appt = ref.watch(appointmentByIdProvider(appointmentId));
    String? line;
    if (appt != null) {
      final doctor = ref.watch(doctorByIdProvider(appt.doctorId));
      line = '${appt.date} · ${appt.time} with ${doctor.name}';
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: _FadeEnter(
          child: Padding(
            padding: EdgeInsets.all(28.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 84.w,
                  height: 84.w,
                  decoration: const BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: CustomPaint(
                    size: Size(42.w, 42.w),
                    painter: _CheckPainter(),
                  ),
                ),
                SizedBox(height: 22.h),
                Text(
                  'Appointment Booked successfully',
                  textAlign: TextAlign.center,
                  style: AppText.poppins(
                    size: 22,
                    weight: AppText.bold,
                    color: AppColors.textStrong,
                    height: 1.3,
                  ),
                ),
                if (appt != null) ...[
                  SizedBox(height: 12.h),
                  Text.rich(
                    TextSpan(
                      text: 'Token: ',
                      style: AppText.poppins(size: 15, color: AppColors.textBody),
                      children: [
                        TextSpan(
                          text: appt.token,
                          style: AppText.poppins(
                            size: 15,
                            weight: AppText.bold,
                            color: AppColors.accentBlue,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    line!,
                    textAlign: TextAlign.center,
                    style: AppText.poppins(size: 13, color: AppColors.textMuted),
                  ),
                ],
                SizedBox(height: 30.h),
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
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
              ],
            ),
          ),
        ),
      ),
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

/// Success-screen enter: a plain fade over [AppConstants.successFadeIn] (0.25s,
/// slightly slower than the standard fade, per the design).
class _FadeEnter extends StatelessWidget {
  const _FadeEnter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppConstants.successFadeIn,
      curve: Curves.easeOut,
      builder: (context, t, child) =>
          Opacity(opacity: t.clamp(0.0, 1.0), child: child),
      child: child,
    );
  }
}
