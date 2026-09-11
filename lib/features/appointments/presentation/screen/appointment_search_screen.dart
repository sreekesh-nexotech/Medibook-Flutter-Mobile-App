import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../components/appointment_card.dart';
import '../components/enter_animations.dart';
import '../controllers/appointment_search_controller.dart';
import '../controllers/appointments_controller.dart';
import 'appointment_filter_sheet.dart';

/// `/appointments/search` (pushed) — CM-30.
///
/// The audit finding was *"Appointments cannot be searched by doctor, hospital
/// or booking ID."* This screen matches all of those plus the patient name and
/// the token, debounced by [AppConstants.searchDebounce].
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

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(appointmentSearchProvider);
    final results = ref.watch(appointmentSearchResultsProvider);

    return Scaffold(
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
                          icon: MedIcon.close,
                          size: 22,
                          semanticLabel: 'Clear search',
                          onPressed: () {
                            _field.clear();
                            ref
                                .read(appointmentSearchProvider.notifier)
                                .clear();
                          },
                        )
                      : null,
                ),
              ),
              if (search.hasQuery && !search.isSettling)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.x5.w,
                    0,
                    AppSpacing.x5.w,
                    8.h,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      results.length == 1
                          ? '1 appointment'
                          : '${results.length} appointments',
                      style: AppText.poppins(
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              Expanded(child: _body(search, results)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AppointmentSearchState search, List<AppointmentRow> results) {
    // Nothing typed yet: say what can be searched, and offer the filter
    // surface, which is the better tool when you are browsing rather than
    // looking for one booking.
    if (!search.hasInput) {
      return AppEmptyView(
        iconName: MedIcon.search,
        headline: 'Find a past or upcoming appointment',
        body:
            'Search by doctor, hospital, booking reference (MB-2026-000124), '
            'patient name or token (T-025).',
        actionLabel: 'Browse with filters instead',
        onAction: () => showAppointmentFilterSheet(context),
      );
    }

    // The debounce has not caught up. A quiet loader, never "no results" —
    // showing an empty state for a term that has not been searched yet is a
    // lie about the data.
    if (search.isSettling) {
      return const AppLoadingView(label: 'Searching…');
    }

    if (results.isEmpty) {
      return AppEmptyView(
        iconName: MedIcon.closeCircle,
        headline: 'No appointments for "${search.query}"',
        body:
            'Check the spelling, or try just the booking reference or the '
            'doctor\'s surname.',
        actionLabel: 'Clear search',
        onAction: () {
          _field.clear();
          ref.read(appointmentSearchProvider.notifier).clear();
          _focus.requestFocus();
        },
        secondaryLabel: 'Book an appointment',
        onSecondary: () => context.push(
          AppRoutes.bookingPath(step: 1, origin: 'appointments'),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(AppSpacing.x5.w, 4.h, AppSpacing.x5.w, 24.h),
      itemCount: results.length,
      separatorBuilder: (_, _) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final row = results[index];
        return AppointmentCard(
          appointment: row.appointment,
          doctor: row.doctor,
          status: row.status,
          hospitalName: row.hospitalName,
          onTap: () =>
              context.push(AppRoutes.appointmentDetailPath(row.appointment.id)),
        );
      },
    );
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.appointments);
    }
  }
}
