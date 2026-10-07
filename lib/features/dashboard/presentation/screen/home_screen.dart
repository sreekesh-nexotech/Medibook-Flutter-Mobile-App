import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/location/device_location.dart';
import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/motion.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/states/app_error_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../appointments/application/providers/appointments_provider.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/application/usecases/hospital_time.dart';
import '../../../booking/application/providers/discovery_providers.dart';
import '../../../booking/presentation/booking_routes.dart';
import '../../../booking/presentation/components/cache_status_bar.dart';
import '../../application/providers/home_providers.dart';
import '../components/home_header.dart';
import '../components/nearby_hospital_card.dart';
import '../components/promo_banner_card.dart';
import '../components/quick_action_grid.dart';
import '../components/token_card.dart';
import '../../application/providers/home_view_providers.dart';
import '../../../booking/application/providers/location_scope_provider.dart';
import '../components/department_icon.dart';
import '../../../../core/utils/external_url.dart';
import '../../../booking/domain/entities/promo_banner.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/hold_deadline.dart';

/// Home (`/home`) — a bottom-nav shell tab, laid out as the design's Home
/// screen: the navy header, then a `24`-gapped scroll of the token card,
/// the promo strip, Quick Booking, Available Services and the nearest
/// hospitals. The shell owns the bottom nav.
///
/// Data: the greeting from the signed-in user; hospitals from
/// `GET /patient/hospitals`; the promo strip from the visible hospitals'
/// banners; the service tiles from `GET /patient/departments`; the "Your
/// Token" card from the appointments feature's next upcoming visit
/// (`GET /patient/appointments?bucket=upcoming`, first row).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(homeGreetingNameProvider);
    final firstUpcoming = ref
        .watch(nextUpcomingAppointmentProvider)
        .valueOrNull;
    final banners = ref.watch(homeBannersProvider);

    // Pull to refresh, and every arrival back at Home (see `RouteArrival`).
    Future<void> refresh() async {
      // The hospitals list Home actually shows, and the "Your token" card —
      // a booking made on another screen must appear here too.
      ref.invalidate(homeHospitalsProvider);
      ref.invalidate(upcomingAppointmentsPeekProvider);
      ref.invalidate(discoveryDepartmentsProvider);
      ref.invalidate(homeBannersProvider);
      await ref.read(homeHospitalsProvider.future);
    }

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: context.motion(AppConstants.fadeIn),
        curve: Curves.easeOut,
        builder: (context, value, child) =>
            Opacity(opacity: value, child: child),
        // No top SafeArea: the navy header paints behind the OS status bar
        // (the design's header block includes the status zone) and applies
        // the inset internally.
        child: Column(
          children: [
            HomeHeader(
              name: name ?? '',
              onBell: () => context.push(AppRoutes.notifications),
              onSearchTap: () => context.push(AppRoutes.search),
            ),
            Expanded(
              child: AppRefreshIndicator(
                semanticsLabel: 'Refresh Home',
                onRefresh: refresh,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(top: 20.h, bottom: 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (firstUpcoming != null) ...[
                        _Gutter(
                          child:
                              firstUpcoming.status ==
                                  AppointmentStatus.pendingPayment
                              // Not paid yet: say so, and lead to the payment.
                              ? HoldDeadline(
                                  // When the hold ends the server releases
                                  // the booking; read the list again then so
                                  // the card does not outlive it.
                                  deadline: firstUpcoming.bookingDeadlineAt,
                                  onDeadline: () => ref.invalidate(
                                    upcomingAppointmentsPeekProvider,
                                  ),
                                  // The gap below travels with the card, so
                                  // a hidden card leaves no hole.
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 24.h),
                                    child: TokenCard.paymentPending(
                                      doctor: firstUpcoming.doctor.name,
                                      note: _payNote(firstUpcoming),
                                      when: HospitalTime.dayAndTime(
                                        firstUpcoming.scheduledStartAt,
                                        timezone:
                                            firstUpcoming.hospital.timezone,
                                      ),
                                      onTap: () => context.push(
                                        '${AppRoutes.bookingPayment}'
                                        '?appt=${firstUpcoming.id}',
                                      ),
                                    ),
                                  ),
                                )
                              : Padding(
                                  padding: EdgeInsets.only(bottom: 24.h),
                                  child: TokenCard(
                                    // Before a token is issued the booking
                                    // reference is the visit's identity (§10.4).
                                    token: firstUpcoming.hasToken
                                        ? firstUpcoming.tokenLabel!
                                        : firstUpcoming.bookingRef,
                                    doctor: firstUpcoming.doctor.name,
                                    when: HospitalTime.dayAndTime(
                                      firstUpcoming.scheduledStartAt,
                                      timezone: firstUpcoming.hospital.timezone,
                                    ),
                                    onTap: () => context.push(
                                      AppRoutes.appointmentDetailPath(
                                        firstUpcoming.id,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                      banners.maybeWhen(
                        // Keep the strip up while it reloads (the list it
                        // comes from re-sorts once the position arrives)
                        // rather than blinking out.
                        skipLoadingOnReload: true,
                        data: (rows) => rows.isEmpty
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: EdgeInsets.only(bottom: 24.h),
                                child: PromoBannerCard(
                                  banners: rows,
                                  onTap: (banner) =>
                                      _openBanner(context, banner),
                                ),
                              ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                      _Gutter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionTitle('Quick Booking'),
                            SizedBox(height: 12.h),
                            QuickActionGrid(
                              actions: [
                                QuickAction(
                                  iconName: PhIcon.calendarBlank,
                                  label: 'Appointment',
                                  onTap: () => context.push(
                                    AppRoutes.bookingPath(step: 1),
                                  ),
                                ),
                                QuickAction(
                                  iconName: PhIcon.buildings,
                                  label: 'Hospitals',
                                  onTap: () =>
                                      context.push(AppRoutes.locations),
                                ),
                                QuickAction(
                                  iconName: PhIcon.firstAid,
                                  label: 'Family',
                                  onTap: () =>
                                      context.push(AppRoutes.dependants),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),
                      const _Gutter(child: _AvailableServices()),
                      SizedBox(height: 24.h),
                      const _Gutter(child: _HospitalsNearYou()),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The unpaid card's line from the server's numbers: the total and the time
/// the hold ends, in the hospital's zone — "Pay ₹524 by 1:42 PM to confirm".
String _payNote(Appointment appointment) {
  final amount = Money.inr(appointment.total.paise);
  final deadline = appointment.bookingDeadlineAt;
  if (deadline == null) return 'Pay $amount to confirm this booking';
  final by = HospitalTime.time(
    deadline,
    timezone: appointment.hospital.timezone,
  );
  return 'Pay $amount by $by to confirm';
}

/// Where a banner tap goes: the banner's own `cta_target` when the server
/// sends one — a Medibook link opens that screen, any other https link opens
/// in the browser — else the banner's hospital, as before.
Future<void> _openBanner(BuildContext context, HospitalBanner banner) async {
  final target = banner.ctaTarget?.trim() ?? '';
  if (target.isNotEmpty) {
    final inApp = AppRoutes.inAppPathFor(target);
    if (inApp != null) {
      await context.push(inApp);
      return;
    }
    if (Uri.tryParse(target)?.scheme == 'https' &&
        await openExternalUrl(target)) {
      return;
    }
  }
  if (context.mounted) {
    await context.push(AppRoutes.hospitalPath(banner.hospitalId));
  }
}

/// "Available Services": the platform's departments as tiles, folded to
/// three behind the design's "View All" / "View Less" link. Each opens
/// booking at that department.
class _AvailableServices extends ConsumerWidget {
  const _AvailableServices();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(homeServicesProvider);
    final expanded = ref.watch(homeServicesExpandedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Available Services',
          linkLabel: expanded ? 'View Less' : 'View All',
          linkSemantics: expanded ? 'Show fewer services' : 'Show all services',
          onLink: () => ref
              .read(homeServicesExpandedProvider.notifier)
              .update((_) => !expanded),
        ),
        SizedBox(height: 12.h),
        services.when(
          loading: () => const AppSkeletonList(count: 1, tile: true),
          error: (error, _) => AppInlineError(
            failure: error.asFailure(),
            onRetry: () => ref.invalidate(discoveryDepartmentsProvider),
          ),
          data: (all) {
            if (all.isEmpty) {
              return Text(
                'No departments are taking bookings right now.',
                style: AppText.poppins(
                  size: AppFontSize.sm,
                  color: AppColors.textMuted,
                ),
              );
            }
            // "View All" means all: capping it at six hid the seventh
            // department (Paediatrics) for good (BL-HOME-006).
            final shown = expanded ? all : all.take(3).toList();
            return QuickActionGrid(
              actions: [
                for (final service in shown)
                  QuickAction(
                    iconName: departmentIconFor(service.code),
                    label: service.label,
                    onTap: () => context.push(
                      BookingRoutes.booking(step: 2, dept: service.code),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// "Hospitals Near You": the first facilities, with "View All" into the
/// full list. Home is a preview — the filters live behind the link.
class _HospitalsNearYou extends ConsumerWidget {
  const _HospitalsNearYou();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hospitals = ref.watch(homeHospitalsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Hospitals Near You',
          linkLabel: 'View All',
          linkSemantics: 'View all hospitals',
          onLink: () => context.push(AppRoutes.hospitals),
        ),
        SizedBox(height: 12.h),
        const _ScopeNote(),
        const _NoLocationNote(),
        CacheStatusBar(
          result: hospitals.valueOrNull,
          onRefresh: () => ref.invalidate(homeHospitalsProvider),
        ),
        // Retry and refresh reload the provider this section shows; they
        // used to invalidate a different one and did nothing (CL HOME-010).
        hospitals.when(
          // Re-sorting by distance once the position arrives keeps the list
          // on screen instead of flashing the skeleton.
          skipLoadingOnReload: true,
          loading: () => const AppSkeletonList(count: 2),
          error: (error, _) => AppInlineError(
            failure: error.asFailure(),
            onRetry: () => ref.invalidate(homeHospitalsProvider),
          ),
          data: (result) {
            final top = result.value.results
                .take(HomeLimits.nearbyHospitals)
                .toList();
            if (top.isEmpty) {
              final scope = ref.watch(locationScopeProvider);
              return Text(
                scope == null
                    ? 'No hospital is live and accepting patients right now.'
                    : 'No hospital in ${scope.label} yet. Tap Change to pick '
                          'another area.',
                style: AppText.poppins(
                  size: AppFontSize.sm,
                  color: AppColors.textMuted,
                ),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < top.length; i++) ...[
                  if (i > 0) SizedBox(height: 12.h),
                  NearbyHospitalCard(
                    hospital: top[i],
                    onTap: () =>
                        context.push(AppRoutes.hospitalPath(top[i].id)),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The design's `padding: 0 20px` section gutter.
class _Gutter extends StatelessWidget {
  const _Gutter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: child,
    );
  }
}

/// A section heading (`18/600`, navy).
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppText.poppins(
        size: AppFontSize.title,
        weight: AppText.semibold,
        color: AppColors.textStrong,
      ),
    );
  }
}

/// A section heading with the design's accent-blue `14/500` link on the
/// right ("View All" / "View Less").
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.linkLabel,
    required this.linkSemantics,
    required this.onLink,
  });

  final String title;
  final String linkLabel;
  final String linkSemantics;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Expanded so a long heading (or a 1.3x text scale) wraps instead of
        // pushing the link off screen.
        Expanded(child: _SectionTitle(title)),
        Semantics(
          button: true,
          label: linkSemantics,
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onLink,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.x1.w,
                  vertical: AppSpacing.x2.h,
                ),
                child: Text(
                  linkLabel,
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
    );
  }
}

/// Under "Hospitals Near You" when the phone's position is not known: says
/// the list is in name order and offers to fix it (CL DISC-015). Nothing is
/// shown while the position is being read or once it is known.
class _NoLocationNote extends ConsumerWidget {
  const _NoLocationNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reason = ref.watch(deviceLocationProvider).valueOrNull?.unavailable;
    if (reason == null) return const SizedBox.shrink();
    final (text, action) = switch (reason) {
      LocationUnavailable.serviceOff => (
        'Location is off, so hospitals are sorted by name.',
        'Try again',
      ),
      LocationUnavailable.denied => (
        'Hospitals are sorted by name. Allow location to see the nearest first.',
        'Allow location',
      ),
      LocationUnavailable.deniedForever => (
        'Location is not allowed for Medibook, so hospitals are sorted by name.',
        'Open settings',
      ),
      LocationUnavailable.noFix => (
        'We could not find your location, so hospitals are sorted by name.',
        'Try again',
      ),
    };
    Future<void> onTap() async {
      if (reason == LocationUnavailable.deniedForever) {
        await ref.read(deviceLocatorProvider).openSettings();
      }
      ref.invalidate(deviceLocationProvider);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Semantics(
        button: true,
        label: '$text $action',
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Text.rich(
              TextSpan(
                text: '$text ',
                children: [
                  TextSpan(
                    text: action,
                    style: AppText.poppins(
                      size: AppFontSize.sm,
                      weight: AppText.semibold,
                      color: AppColors.accentBlue,
                    ),
                  ),
                ],
              ),
              style: AppText.poppins(
                size: AppFontSize.sm,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Under "Hospitals Near You" when a browse location is saved: names it
/// and offers to change it (CL DISC-001), so a short list never looks like
/// missing data.
class _ScopeNote extends ConsumerWidget {
  const _ScopeNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(locationScopeProvider);
    if (scope == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Semantics(
        button: true,
        label: 'Showing hospitals in ${scope.label}. Change location',
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push(AppRoutes.locations),
            child: Row(
              children: [
                AppIcon(PhIcon.mapPin, size: 15, color: AppColors.brand),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    'In ${scope.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(
                      size: AppFontSize.sm,
                      weight: AppText.medium,
                      color: AppColors.textStrong,
                    ),
                  ),
                ),
                Text(
                  'Change',
                  style: AppText.poppins(
                    size: AppFontSize.sm,
                    weight: AppText.semibold,
                    color: AppColors.accentBlue,
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
