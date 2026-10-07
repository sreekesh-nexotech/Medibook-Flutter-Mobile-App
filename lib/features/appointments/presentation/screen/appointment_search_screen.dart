import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/appointment.dart';
import '../../../../core/widgets/hold_deadline.dart';
import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/route_arrival.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_error_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../application/providers/appointments_provider.dart';
import '../../domain/entities/appointment_filter.dart';
import '../components/appointment_card.dart';
import '../components/enter_animations.dart';
import '../../application/providers/appointment_search_controller.dart';

/// `/appointments/search` (pushed) — CM-30.
///
/// One request per settled term: `GET /patient/appointments?q=` (§10.1),
/// which the backend matches against booking ref, token label, doctor,
/// hospital and the person's name — across every bucket. Debounced by
/// [AppConstants.searchDebounce].
///
/// Both no-input and no-results states are real states and both carry an
/// action, because a dead end in search is how a patient concludes their
/// booking is gone.
class AppointmentSearchScreen extends ConsumerStatefulWidget {
  const AppointmentSearchScreen({super.key});

  @override
  ConsumerState<AppointmentSearchScreen> createState() =>
      _AppointmentSearchScreenState();
}

class _AppointmentSearchScreenState
    extends ConsumerState<AppointmentSearchScreen> {
  final TextEditingController _field = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Filters narrow the appointments list, not the search results, so they
  /// are applied where that list is visible: back on it with the filter
  /// sheet open (BL-APPT-026). The list opens the sheet when this screen
  /// returns `true`; reached from a link, the filter screen takes over and
  /// lands on the list after Apply.
  void _browseWithFilters() {
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go(AppRoutes.appointmentsFilter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(appointmentSearchProvider);
    final query = ref.watch(appointmentSearchQueryProvider);

    return RouteArrival(
      onArrive: () {
        // Only once something has been searched for.
        final active = query;
        if (active == null) return;
        ref
            .read(appointmentsListProvider(active).notifier)
            .load(forceRefresh: true);
      },
      child: Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: ScreenEnter(
            child: Column(
              children: [
                AppInnerHeader(
                  title: 'Search appointments',
                  onBack: () => _leave(context),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.x5.w,
                    0,
                    AppSpacing.x5.w,
                    10.h,
                  ),
                  child: AppTextField(
                    controller: _field,
                    focusNode: _focus,
                    iconName: MedIcon.search,
                    hintText: 'Doctor, hospital, booking ID or token',
                    semanticLabel:
                        'Search your appointments by doctor, hospital, booking '
                        'reference, patient or token',
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => ref
                        .read(appointmentSearchProvider.notifier)
                        .onInput(value),
                    suffix: search.hasInput
                        ? AppIconButton(
                            icon: PhIcon.x,
                            size: 22,
                            semanticLabel: 'Clear search',
                            onPressed: _clear,
                          )
                        : null,
                  ),
                ),
                Expanded(child: _body(search, query)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(AppointmentSearchState search, AppointmentListQuery? query) {
    // Nothing typed yet: say what can be searched, and offer the filter
    // surface, which is the better tool when browsing rather than looking
    // for one booking.
    if (!search.hasInput) {
      return AppEmptyView(
        iconName: PhIcon.magnifyingGlass,
        headline: 'Find a past or upcoming appointment',
        body:
            'Search by doctor, hospital, booking reference, patient name or '
            'token.',
        actionLabel: 'Browse with filters instead',
        onAction: _browseWithFilters,
      );
    }

    // The debounce has not caught up. A quiet loader, never "no results" —
    // showing an empty state for a term that has not been searched yet is a
    // lie about the data.
    if (search.isSettling || query == null) {
      return const AppLoadingView(label: 'Searching…');
    }

    return _Results(query: query, term: search.query, onClear: _clear);
  }

  void _clear() {
    _field.clear();
    ref.read(appointmentSearchProvider.notifier).clear();
    _focus.requestFocus();
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.appointments);
    }
  }
}

/// The result list for one settled term, with its own load / error / empty
/// states and load-more at the bottom.
class _Results extends ConsumerWidget {
  const _Results({
    required this.query,
    required this.term,
    required this.onClear,
  });

  final AppointmentListQuery query;
  final String term;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(appointmentsListProvider(query));

    if (list.isLoading) return const AppLoadingView(label: 'Searching…');

    final failure = list.failure;
    if (failure != null && list.items.isEmpty) {
      return AppErrorView(
        failure: failure,
        onRetry: () => ref
            .read(appointmentsListProvider(query).notifier)
            .load(forceRefresh: true),
      );
    }

    if (list.items.isEmpty) {
      return AppEmptyView(
        iconName: PhIcon.xCircle,
        headline: 'No appointments for "$term"',
        body:
            'Check the spelling, or try just the booking reference or the '
            "doctor's surname.",
        actionLabel: 'Clear search',
        onAction: onClear,
        secondaryLabel: 'Book an appointment',
        onSecondary: () => context.push(
          AppRoutes.bookingPath(step: 1, origin: 'appointments'),
        ),
      );
    }

    final showSentinel = list.hasNext || list.loadMoreFailure != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.x5.w,
            0,
            AppSpacing.x5.w,
            8.h,
          ),
          child: Text(
            list.total == 1 ? '1 appointment' : '${list.total} appointments',
            style: AppText.poppins(size: 12, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.x5.w,
              4.h,
              AppSpacing.x5.w,
              24.h,
            ),
            itemCount: list.items.length + (showSentinel ? 1 : 0),
            separatorBuilder: (_, _) => SizedBox(height: 12.h),
            itemBuilder: (context, index) {
              if (index >= list.items.length) {
                final loadFailure = list.loadMoreFailure;
                if (loadFailure != null) {
                  return AppInlineError(
                    failure: loadFailure,
                    retryLabel: 'Load more',
                    onRetry: () => ref
                        .read(appointmentsListProvider(query).notifier)
                        .loadMore(),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    ref
                        .read(appointmentsListProvider(query).notifier)
                        .loadMore();
                  }
                });
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  child: const Center(child: AppInlineLoader()),
                );
              }
              final appointment = list.items[index];
              final card = AppointmentCard(
                appointment: appointment,
                forLabel: ref.watch(
                  personForLabelProvider(appointment.personId),
                ),
                onTap: () => context.push(
                  AppRoutes.appointmentDetailPath(appointment.id),
                ),
                onBookAgain: () => context.push(
                  AppRoutes.bookingPath(
                    step: 3,
                    dept:
                        appointment.department.code ??
                        appointment.department.id,
                    doctor: appointment.doctor.id,
                    origin: 'appointments',
                  ),
                ),
              );
              if (appointment.status != AppointmentStatus.pendingPayment) {
                return card;
              }
              // Same as the tab: an unpaid hold leaves when it runs out.
              return HoldDeadline(
                deadline: appointment.bookingDeadlineAt,
                onDeadline: () => ref
                    .read(appointmentsListProvider(query).notifier)
                    .load(forceRefresh: true),
                child: card,
              );
            },
          ),
        ),
      ],
    );
  }
}
