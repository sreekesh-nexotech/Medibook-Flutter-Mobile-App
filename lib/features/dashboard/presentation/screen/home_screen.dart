import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../components/home_header.dart';
import '../components/promo_banner_card.dart';
import '../components/quick_action_grid.dart';
import '../components/token_card.dart';
import '../controllers/home_providers.dart';

/// Home (`/home`) — a bottom-nav shell tab. Navy header + scrolling body of
/// banner, optional "Your Token" card, and the two quick-action rows. The
/// shell owns the bottom nav, so this screen renders none. Enters with a fade
/// (`fadeIn`, tab convention).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(homeUserNameProvider);
    final firstUpcoming = ref.watch(firstUpcomingAppointmentProvider);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: AppConstants.fadeIn,
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(opacity: value, child: child),
        child: SafeArea(
          bottom: false,
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
                          onTap: () => context.push(
                            AppRoutes.appointmentDetailPath(firstUpcoming.id),
                          ),
                        ),
                      ],
                      SizedBox(height: 22.h),
                      _SectionTitle('Quick Booking'),
                      SizedBox(height: 12.h),
                      QuickActionGrid(
                        actions: [
                          QuickAction(
                            iconName: 'calendar',
                            label: 'Appointment',
                            onTap: () =>
                                context.push(AppRoutes.bookingPath(step: 1)),
                          ),
                          QuickAction(
                            iconName: 'records',
                            label: 'Lab Tests',
                            onTap: () =>
                                context.push(AppRoutes.bookingPath(step: 1)),
                          ),
                          QuickAction(
                            iconName: 'hospital',
                            label: 'Family',
                            onTap: () =>
                                context.push(AppRoutes.bookingPath(step: 1)),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SectionTitle('Available Services'),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () =>
                                context.push(AppRoutes.bookingPath(step: 1)),
                            child: Text(
                              'View All',
                              style: AppText.poppins(
                                size: 14,
                                weight: AppText.medium,
                                color: AppColors.accentBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      QuickActionGrid(
                        actions: [
                          QuickAction(
                            iconName: 'records',
                            label: 'General Physician',
                            onTap: () => context.push(
                              AppRoutes.bookingPath(step: 2, dept: 'General'),
                            ),
                          ),
                          QuickAction(
                            iconName: 'star',
                            label: 'Skin & hair Care',
                            onTap: () => context.push(
                              AppRoutes.bookingPath(
                                step: 2,
                                dept: 'Dermatology',
                              ),
                            ),
                          ),
                          QuickAction(
                            iconName: 'hospital',
                            label: "Women's Health",
                            onTap: () =>
                                context.push(AppRoutes.bookingPath(step: 1)),
                          ),
                        ],
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
        size: 18,
        weight: AppText.bold,
        color: AppColors.textStrong,
      ),
    );
  }
}
