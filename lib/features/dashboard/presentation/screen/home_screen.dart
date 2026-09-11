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
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../../../booking/domain/booking_routes.dart';
import '../components/home_header.dart';
import '../components/promo_banner_card.dart';
import '../components/quick_action_grid.dart';
import '../components/token_card.dart';
import '../controllers/home_providers.dart';

/// Home (`/home`) — a bottom-nav shell tab. Navy header over a scrolling body
/// of banner, token card, emergency row, and the two quick-action rows. The
/// shell owns the bottom nav, so this screen renders none.
///
/// ## What the audit changed here
///
/// * **CM-09/CM-24.** The token card now carries the desk's live progress
///   (`queueStatusProvider`) and a door into `/queue/:doctorId`, not just the
///   patient's own number.
/// * **CM-10.** "Start from a location" is a first-class entry
///   (`/locations`), beside the department-first entries that already existed.
///   Both are kept: the finding was that discovery *only* began at a
///   department, not that beginning there was wrong.
/// * **CM-44.** An emergency row sits above the quick actions, because
///   "prominent" for an ambulance means "not behind two taps".
/// * **§3.3.8.** The banner's autoplay moved into [PromoBannerCard], where the
///   reduce-motion check and pause-on-touch can actually be applied.
///
/// Enters with a fade ([AppConstants.fadeIn], tab convention), collapsed to
/// zero when the OS asks for reduced motion.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(homeUserNameProvider);
    final firstUpcoming = ref.watch(firstUpcomingAppointmentProvider);
    final queue = firstUpcoming == null
        ? null
        : ref.watch(queueStatusProvider(firstUpcoming.doctorId));

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: context.motion(AppConstants.fadeIn),
        curve: Curves.easeOut,
        builder: (context, value, child) =>
            Opacity(opacity: value, child: child),
        // No top SafeArea: the navy header paints behind the OS status bar
        // (the design's header block includes the status zone) and applies the
        // inset internally.
        child: Column(
          children: [
            HomeHeader(
              name: name,
              onBell: () => context.push(AppRoutes.notifications),
              onAvatar: () => context.go(AppRoutes.profile),
              onSearchTap: () => context.push(AppRoutes.search),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PromoBannerCard(),
                    if (firstUpcoming != null) ...[
                      SizedBox(height: 18.h),
                      TokenCard(
                        token: firstUpcoming.token,
                        bookingRef: firstUpcoming.bookingRef,
                        queue: queue,
                        onTap: () => context.push(
                          AppRoutes.appointmentDetailPath(firstUpcoming.id),
                        ),
                        onViewQueue: queue == null
                            ? null
                            : () => context.push(
                                AppRoutes.queuePath(firstUpcoming.doctorId),
                              ),
                      ),
                    ],
                    SizedBox(height: 18.h),
                    _EmergencyRow(
                      onTap: () => context.push(AppRoutes.ambulance),
                    ),
                    SizedBox(height: 22.h),
                    const _SectionTitle('Quick Booking'),
                    SizedBox(height: 12.h),
                    QuickActionGrid(
                      actions: [
                        QuickAction(
                          iconName: MedIcon.calendar,
                          label: 'Appointment',
                          onTap: () =>
                              context.push(AppRoutes.bookingPath(step: 1)),
                        ),
                        QuickAction(
                          iconName: MedIcon.location,
                          label: 'Near me',
                          onTap: () => context.push(AppRoutes.locations),
                        ),
                        QuickAction(
                          iconName: MedIcon.hospital,
                          label: 'Hospitals',
                          onTap: () => context.push(AppRoutes.hospitals),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Expanded so a long heading (or a 1.3x text scale)
                        // wraps instead of pushing "View All" off screen.
                        const Expanded(
                          child: _SectionTitle('Available Services'),
                        ),
                        Semantics(
                          button: true,
                          label: 'View all departments',
                          child: ExcludeSemantics(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  context.push(AppRoutes.bookingPath(step: 1)),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.x1.w,
                                  vertical: AppSpacing.x2.h,
                                ),
                                child: Text(
                                  'View All',
                                  style: AppText.poppins(
                                    size: AppFontSize.base,
                                    weight: AppText.medium,
                                    color: AppColors.accentBlue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    const _DepartmentShortcuts(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The first three departments as quick entries into booking step 2.
///
/// Read from `departmentsProvider` rather than hardcoded, so a shortcut can
/// never name a department the booking screen does not offer — which is the
/// class of drift CANONICAL_MASTER_DATA §2.6.3 is about.
class _DepartmentShortcuts extends ConsumerWidget {
  const _DepartmentShortcuts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departments = ref.watch(departmentsProvider).take(3).toList();
    if (departments.isEmpty) return const SizedBox.shrink();

    return QuickActionGrid(
      actions: [
        for (final department in departments)
          QuickAction(
            iconName: department.iconName,
            label: department.name,
            onTap: () => context.push(
              BookingRoutes.booking(step: 2, dept: department.name),
            ),
          ),
      ],
    );
  }
}

/// Call an ambulance (CM-44). Danger-toned and above the fold, because an
/// emergency entry point that has to be hunted for is not one.
class _EmergencyRow extends StatelessWidget {
  const _EmergencyRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Call an ambulance',
      hint: 'Opens the emergency numbers',
      child: ExcludeSemantics(
        child: AppCard(
          onTap: onTap,
          padding: EdgeInsets.all(14.w),
          color: AppColors.dangerSoft,
          shadow: AppShadowToken.none,
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: AppIcon(
                  MedIcon.bell,
                  size: 19,
                  color: AppColors.dangerText,
                ),
              ),
              SizedBox(width: AppSpacing.x3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Call an ambulance',
                      style: AppText.poppins(
                        size: AppFontSize.base,
                        weight: AppText.semibold,
                        color: AppColors.textStrong,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Emergency numbers and nearby operators',
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A left-aligned section heading (18/700, navy).
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppText.poppins(
        size: AppFontSize.title,
        weight: AppText.bold,
        color: AppColors.textStrong,
      ),
    );
  }
}
