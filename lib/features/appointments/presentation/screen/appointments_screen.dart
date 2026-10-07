import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/hold_deadline.dart';
import '../../../../core/widgets/states/app_error_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../application/providers/appointments_provider.dart';
import '../../application/states/appointments_list_state.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/appointment_filter.dart';
import '../components/appointment_card.dart';
import '../components/enter_animations.dart';
import '../components/filter_chips_row.dart';
import '../components/freshness_bar.dart';
import '../../application/providers/appointment_filter_controller.dart';
import '../../application/providers/appt_tab_controller.dart';
import 'appointment_filter_sheet.dart';

/// `/appointments` (a shell tab — the bottom nav is provided by the shell),
/// laid out exactly as the design's Appointments screen: the title, the
/// Upcoming / Completed / Canceled pill tabs, the "Filters" chip with the
/// visit count, the cards for the active tab (or the "Nothing here yet"
/// state), and the sticky "Book an appointment" footer.
///
/// Each tab is one request (§10.1): Upcoming = `bucket=upcoming&sort=
/// scheduled_start_at`; Completed = `bucket=past` minus the cancelled; Canceled =
/// `status=cancelled,no_show`. Pages append on scroll; pull-to-refresh
/// re-fetches page 1 (§3.9.4).
class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(apptTabProvider);
    final query = ref.watch(activeAppointmentQueryProvider);
    final list = ref.watch(appointmentsListProvider(query));
    final activeFilters = ref.watch(
      appointmentFilterProvider.select(
        (filter) => filter.forTab(tab).activeCount,
      ),
    );
    final chips = ref.watch(appointmentFilterChipsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        bottom: false,
        child: ScreenEnter(
          rise: false,
          child: Column(
            children: [
              // Design `padding: 58px 20px 16px` — 58 includes the 46px status
              // zone, so 12 below the OS inset.
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Appointments',
                        style: AppText.poppins(
                          size: AppFontSize.h2,
                          weight: AppText.bold,
                          color: AppColors.textStrong,
                        ),
                      ),
                    ),
                    _SearchButton(
                      onTap: () async {
                        // Search hands back `true` for "Browse with filters
                        // instead" (BL-APPT-026).
                        final browse = await context.push<bool>(
                          AppRoutes.appointmentsSearch,
                        );
                        if (browse == true && context.mounted) {
                          await showAppointmentFilterSheet(context);
                        }
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
                child: _TabPills(
                  active: tab,
                  onChanged: (value) =>
                      ref.read(apptTabProvider.notifier).update((_) => value),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
                child: Row(
                  children: [
                    _FilterChip(
                      activeCount: activeFilters,
                      onTap: () => showAppointmentFilterSheet(context),
                    ),
                    const Spacer(),
                    Text(
                      _countLabel(list),
                      style: AppText.poppins(
                        size: AppFontSize.sm,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              AppointmentFilterChipsRow(
                chips: chips,
                onRemove: (field, {status}) => ref
                    .read(appointmentFilterProvider.notifier)
                    .clearField(field, status: status),
                onClearAll: () =>
                    ref.read(appointmentFilterProvider.notifier).clearAll(),
              ),
              FreshnessBar(
                isStale: list.isStale,
                revalidating: list.revalidating && list.items.isNotEmpty,
                cachedAt: list.cachedAt,
                failure: list.hasLoadedPage ? list.failure : null,
                onRefresh: () => _refresh(ref, query),
                hasContent: list.hasLoadedPage,
              ),
              Expanded(
                child: AppRefreshIndicator(
                  semanticsLabel: 'Refresh appointments',
                  onRefresh: () => _refresh(ref, query),
                  child: _Body(
                    query: query,
                    list: list,
                    isFiltered: activeFilters > 0,
                    onClearFilters: () =>
                        ref.read(appointmentFilterProvider.notifier).clearAll(),
                  ),
                ),
              ),
              _Footer(
                child: AppButton(
                  label: 'Book an appointment',
                  fullWidth: true,
                  pill: true,
                  leadingIcon: MedIcon.calendar,
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

  /// "3 visits" from the server total — never from the rows loaded so far.
  String _countLabel(AppointmentsListState list) {
    // Nothing loaded yet (or the first load failed): no count, rather than a
    // '0 visits' that reads as "you have none" (CL NET-013).
    if (list.isLoading || !list.hasLoadedPage) return '';
    return list.total == 1 ? '1 visit' : '${list.total} visits';
  }

  /// Re-fetch page 1, skipping the cached copy (the ETag still goes out).
  Future<void> _refresh(WidgetRef ref, AppointmentListQuery query) => ref
      .read(appointmentsListProvider(query).notifier)
      .load(forceRefresh: true);
}

/// The list body in its four states: skeleton, error, empty, rows (with the
/// load-more sentinel at the bottom).
class _Body extends ConsumerWidget {
  const _Body({
    required this.query,
    required this.list,
    required this.isFiltered,
    required this.onClearFilters,
  });

  final AppointmentListQuery query;
  final AppointmentsListState list;
  final bool isFiltered;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (list.isLoading) {
      return const AppSkeletonList(count: 3);
    }
    final failure = list.failure;
    if (failure != null && !list.hasLoadedPage) {
      // Scrollable, so pull-to-refresh works from the error view too
      // (BL-CACHE-017: pulling did nothing).
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: appRefreshPhysics,
          // A fixed height: the error view scrolls inside itself, which an
          // unbounded parent would not allow.
          child: SizedBox(
            height: constraints.maxHeight,
            child: AppErrorView(
              failure: failure,
              onRetry: () => ref
                  .read(appointmentsListProvider(query).notifier)
                  .load(forceRefresh: true),
            ),
          ),
        ),
      );
    }
    if (list.items.isEmpty) {
      return _EmptyState(
        tab: query.tab ?? AppointmentTab.upcoming,
        isFiltered: isFiltered,
        onClearFilters: onClearFilters,
      );
    }

    final showSentinel = list.hasNext || list.loadMoreFailure != null;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 20.h),
      physics: appRefreshPhysics,
      itemCount: list.items.length + (showSentinel ? 1 : 0),
      separatorBuilder: (_, _) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        if (index >= list.items.length) {
          return _LoadMoreSentinel(query: query, list: list);
        }
        return _AppointmentItem(appointment: list.items[index], query: query);
      },
    );
  }
}

/// The last row of a page: asks for the next page as soon as it is built
/// (infinite scroll), and offers a retry when that failed.
class _LoadMoreSentinel extends ConsumerWidget {
  const _LoadMoreSentinel({required this.query, required this.list});

  final AppointmentListQuery query;
  final AppointmentsListState list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failure = list.loadMoreFailure;
    if (failure != null) {
      return AppInlineError(
        failure: failure,
        retryLabel: 'Load more',
        onRetry: () =>
            ref.read(appointmentsListProvider(query).notifier).loadMore(),
      );
    }
    // Reading (not watching) in a post-frame callback: the request is a
    // side effect of the row becoming visible, not of the build itself.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ref.read(appointmentsListProvider(query).notifier).loadMore();
      }
    });
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: const Center(child: AppInlineLoader()),
    );
  }
}

/// One card, wired to navigation. A widget of its own so each row watches
/// only its own person label.
class _AppointmentItem extends ConsumerWidget {
  const _AppointmentItem({required this.appointment, required this.query});

  final Appointment appointment;

  /// The list this row belongs to, re-read when its hold runs out.
  final AppointmentListQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forLabel = ref.watch(personForLabelProvider(appointment.personId));
    final card = AppointmentCard(
      appointment: appointment,
      forLabel: forLabel,
      onTap: () =>
          context.push(AppRoutes.appointmentDetailPath(appointment.id)),
      onBookAgain: () => context.push(
        AppRoutes.bookingPath(
          step: 3,
          dept: appointment.department.code ?? appointment.department.id,
          doctor: appointment.doctor.id,
          origin: 'appointments',
        ),
      ),
    );
    if (appointment.status != AppointmentStatus.pendingPayment) return card;
    // An unpaid hold that runs out while the list is open: hide the card at
    // the deadline and re-read the list until the server has released it,
    // so neither the card nor the count outlives the booking.
    return HoldDeadline(
      deadline: appointment.bookingDeadlineAt,
      onDeadline: () => ref
          .read(appointmentsListProvider(query).notifier)
          .load(forceRefresh: true),
      child: card,
    );
  }
}

/// The search glyph beside the title — `/appointments/search` (CM-30).
class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Search appointments',
      child: ExcludeSemantics(
        child: Material(
          color: AppColors.surface,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 40.w,
              height: 40.w,
              child: Center(
                child: AppIcon(
                  PhIcon.magnifyingGlass,
                  size: 18,
                  color: AppColors.textStrong,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The design's three equal pill tabs: `height 46`, `gap 8`, `14/600`; the
/// active one is brand on white, the rest white on `--text-body`.
class _TabPills extends StatelessWidget {
  const _TabPills({required this.active, required this.onChanged});

  final AppointmentTab active;
  final ValueChanged<AppointmentTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < kAppointmentTabs.length; i++) ...[
          if (i > 0) SizedBox(width: 8.w),
          Expanded(
            child: _TabPill(
              label: kAppointmentTabs[i].label,
              on: kAppointmentTabs[i] == active,
              onTap: () => onChanged(kAppointmentTabs[i]),
            ),
          ),
        ],
      ],
    );
  }
}

/// One tab pill.
class _TabPill extends StatelessWidget {
  const _TabPill({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      label: '$label appointments',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 46.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppColors.brand : AppColors.surface,
              borderRadius: AppRadii.pill,
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.poppins(
                size: AppFontSize.base,
                weight: AppText.semibold,
                color: on ? AppColors.textOnBrand : AppColors.textBody,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Filters" chip: `funnel-simple` + label, `height 46`, `padding 0 16`,
/// `13/500`, pill with a 1px border. Turns brand when any filter is active and
/// reads "Filters · n".
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.activeCount, required this.onTap});

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = activeCount > 0;
    final label = on ? 'Filters · $activeCount' : 'Filters';
    return Semantics(
      button: true,
      label: on
          ? 'Filter appointments, $activeCount active'
          : 'Filter appointments',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 46.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: on ? AppColors.brand : AppColors.surface,
              borderRadius: AppRadii.pill,
              border: Border.all(
                color: on ? AppColors.brand : AppColors.border,
                width: 1.w,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  PhIcon.funnelSimple,
                  size: 16,
                  color: on ? AppColors.textOnBrand : AppColors.textBody,
                ),
                SizedBox(width: 8.w),
                Text(
                  label,
                  style: AppText.poppins(
                    size: AppFontSize.sm,
                    weight: AppText.medium,
                    color: on ? AppColors.textOnBrand : AppColors.textBody,
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

/// "Nothing here yet" — the design's empty state: a 64px tint disc with the
/// calendar mark, 16/600 headline, 13 muted body (max 240 wide), and a
/// "Clear filters" pill only when a filter emptied the tab.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.tab,
    required this.isFiltered,
    required this.onClearFilters,
  });

  final AppointmentTab tab;
  final bool isFiltered;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final body = isFiltered
        ? 'No appointments match these filters.'
        : switch (tab) {
            AppointmentTab.upcoming =>
              'Appointments you book will show up in this tab.',
            AppointmentTab.completed =>
              'Visits whose time has passed will show up here.',
            AppointmentTab.cancelled =>
              'Cancelled and missed appointments will show up here.',
          };
    return SingleChildScrollView(
      physics: appRefreshPhysics,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 60.h),
      child: Column(
        children: [
          Container(
            width: 64.r,
            height: 64.r,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surfaceTint,
              shape: BoxShape.circle,
            ),
            child: AppIcon(
              PhIcon.calendarBlank,
              size: 30,
              color: AppColors.brand,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Nothing here yet',
            textAlign: TextAlign.center,
            style: AppText.poppins(
              size: AppFontSize.body,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 12.h),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 240.w),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: AppText.poppins(
                size: AppFontSize.sm,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ),
          if (isFiltered) ...[
            SizedBox(height: 16.h),
            AppButton(
              label: 'Clear filters',
              variant: AppButtonVariant.secondary,
              pill: true,
              onPressed: onClearFilters,
            ),
          ],
        ],
      ),
    );
  }
}

/// The sticky white footer: `padding 12px 20px 16px`, hairline on top; the
/// bottom inset is added inside so the button clears the home indicator.
class _Footer extends StatelessWidget {
  const _Footer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20.w,
        12.h,
        20.w,
        16.h + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.h),
        ),
      ),
      child: child,
    );
  }
}
