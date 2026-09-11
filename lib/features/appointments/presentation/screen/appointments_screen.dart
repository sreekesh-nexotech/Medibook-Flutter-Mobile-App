import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/appointment.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../domain/entities/appointment_filter.dart';
import '../../domain/entities/appointment_status_view.dart';
import '../components/appointment_card.dart';
import '../components/enter_animations.dart';
import '../components/filter_chips_row.dart';
import '../controllers/appointment_filter_controller.dart';
import '../controllers/appointments_controller.dart';
import '../controllers/appt_tab_controller.dart';
import 'appointment_filter_sheet.dart';

/// `/appointments` (a shell tab — the bottom nav is provided by the shell).
///
/// Large title with search / filter / notifications entry points, an
/// Upcoming/Past segmented control driven by the local [apptTabProvider], the
/// active-filter chip row (CM-28), the appointment cards for the active bucket
/// (or an empty state that always offers a way out), and a bottom "Book an
/// appointment" CTA. Pull-to-refresh per §3.9.4.
class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(apptTabProvider);
    final bucket = bucketForTab(tab);
    final rows = ref.watch(filteredAppointmentRowsProvider(bucket));
    final chips = ref.watch(appointmentFilterChipsProvider);
    final activeCount = ref.watch(
      appointmentFilterProvider.select((filter) => filter.activeCount),
    );

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: ScreenEnter(
          rise: false,
          child: Column(
            children: [
              AppTabHeader(
                title: 'Appointments',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIconButton(
                      icon: MedIcon.search,
                      size: 38,
                      semanticLabel: 'Search appointments',
                      onPressed: () =>
                          context.push(AppRoutes.appointmentsSearch),
                    ),
                    _FilterButton(activeCount: activeCount),
                    AppIconButton(
                      icon: MedIcon.bell,
                      size: 38,
                      semanticLabel: 'Notifications',
                      onPressed: () => context.push(AppRoutes.notifications),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.x5.w,
                  0,
                  AppSpacing.x5.w,
                  6.h,
                ),
                child: AppSegmentedTabs(
                  tabs: kAppointmentTabs,
                  active: tab,
                  onChanged: (value) {
                    ref.read(apptTabProvider.notifier).state = value;
                  },
                ),
              ),
              AppointmentFilterChipsRow(
                chips: chips,
                onRemove:
                    (
                      AppointmentFilterField field, {
                      AppointmentStatusView? status,
                    }) => ref
                        .read(appointmentFilterProvider.notifier)
                        .clearField(field, status: status),
                onClearAll: () =>
                    ref.read(appointmentFilterProvider.notifier).clearAll(),
              ),
              Expanded(
                child: AppRefreshIndicator(
                  semanticsLabel: 'Refresh appointments',
                  onRefresh: () => _refresh(ref),
                  child: rows.isEmpty
                      ? _EmptyState(
                          tab: tab,
                          isFiltered: activeCount > 0,
                          onClearFilters: () => ref
                              .read(appointmentFilterProvider.notifier)
                              .clearAll(),
                          onShowUpcoming: () =>
                              ref.read(apptTabProvider.notifier).state =
                                  kAppointmentTabs.first,
                        )
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.x5.w,
                            10.h,
                            AppSpacing.x5.w,
                            24.h,
                          ),
                          physics: appRefreshPhysics,
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => SizedBox(height: 12.h),
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            return AppointmentCard(
                              appointment: row.appointment,
                              doctor: row.doctor,
                              status: row.status,
                              onTap: () => context.push(
                                AppRoutes.appointmentDetailPath(
                                  row.appointment.id,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.x5.w,
                  12.h,
                  AppSpacing.x5.w,
                  14.h,
                ),
                child: AppButton(
                  label: 'Book an appointment',
                  fullWidth: true,
                  onPressed: () => context.push(
                    AppRoutes.bookingPath(step: 1, origin: 'appointments'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Re-derive the list.
  ///
  /// There is no network in this build, so this refreshes what genuinely can
  /// change: the canonical status of every appointment is derived from the
  /// clock and the doctor's live queue, so a pull really can move a row from
  /// Scheduled to In Queue or No-show. It does **not** touch
  /// `appointmentsControllerProvider` — that holds the patient's own bookings
  /// and resetting it would silently delete them.
  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(appointmentRowsProvider);
    // One frame, so the indicator's retraction is not instantaneous and the
    // rebuilt rows are on screen before it disappears.
    await Future<void>.delayed(AppConstants.easeShort);
  }
}

/// The filter entry point, with a count badge when anything is active.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final label = activeCount == 0
        ? 'Filter appointments'
        : 'Filter appointments, $activeCount active';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppIconButton(
          icon: MedIcon.records,
          size: 38,
          semanticLabel: label,
          onPressed: () => showAppointmentFilterSheet(context),
        ),
        if (activeCount > 0)
          Positioned(
            right: 4.w,
            top: 4.h,
            child: IgnorePointer(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                constraints: BoxConstraints(minWidth: 16.w, minHeight: 16.h),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentBlue,
                  borderRadius: AppRadii.pill,
                ),
                child: Text(
                  '$activeCount',
                  style: AppText.poppins(
                    size: 9,
                    weight: AppText.bold,
                    color: AppColors.textOnBrand,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The empty state for the active bucket.
///
/// Always carries an action — the audit's finding was that the Appointments
/// empty state "offers no action". Which action depends on *why* it is empty:
/// a filter that matched nothing needs clearing, a genuinely empty Upcoming tab
/// needs a booking, and an empty Past tab can at least go back to Upcoming.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.tab,
    required this.isFiltered,
    required this.onClearFilters,
    required this.onShowUpcoming,
  });

  final String tab;
  final bool isFiltered;
  final VoidCallback onClearFilters;
  final VoidCallback onShowUpcoming;

  @override
  Widget build(BuildContext context) {
    final isUpcoming = bucketForTab(tab) == AppointmentBucket.upcoming;
    if (isFiltered) {
      return AppEmptyView(
        iconName: MedIcon.search,
        headline: 'No appointments match these filters',
        body:
            'Nothing in ${tab.toLowerCase()} matches. Clear the filters to see '
            'everything, or widen the date range.',
        actionLabel: 'Clear filters',
        onAction: onClearFilters,
        secondaryLabel: 'Book an appointment',
        onSecondary: () => context.push(
          AppRoutes.bookingPath(step: 1, origin: 'appointments'),
        ),
      );
    }
    return AppEmptyView(
      iconName: MedIcon.calendar,
      headline: isUpcoming
          ? 'No upcoming appointments'
          : 'No past appointments',
      body: isUpcoming
          ? 'Book a consultation and it will appear here with your token.'
          : 'Completed, cancelled and missed appointments collect here.',
      actionLabel: 'Book an appointment',
      onAction: () =>
          context.push(AppRoutes.bookingPath(step: 1, origin: 'appointments')),
      secondaryLabel: isUpcoming ? null : 'See upcoming',
      onSecondary: isUpcoming ? null : onShowUpcoming,
    );
  }
}
