import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_date_picker_sheet.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_select.dart';
import '../../domain/entities/appointment_filter.dart';
import '../../domain/entities/appointment_status_view.dart';
import '../components/enter_animations.dart';
import '../controllers/appointment_filter_controller.dart';
import '../controllers/appointments_controller.dart';

/// Open the appointments filter as a bottom sheet (CM-28).
///
/// ## Sheet, not a pushed screen
///
/// `/appointments/filter` exists as a route and [AppointmentFilterScreen]
/// serves it (deep links and the back button have to work), but the sheet is
/// the primary surface, for three reasons:
///
/// 1. **The list is the context.** Filtering is a narrowing gesture on
///    something you are looking at; a sheet keeps the list and its active
///    chips visible behind the scrim, so the patient sees what they are
///    narrowing. A pushed screen replaces the thing being filtered.
/// 2. **It matches the design language already in place.** Every other
///    "choose something and come back" surface in this app is a sheet — the
///    country-code picker, the month calendar, the confirm sheets — all
///    through `showAppSheet`.
/// 3. **Dismissal is cheap and obvious.** A half-set filter is abandoned with
///    a swipe, which is what people do when they change their mind mid-filter.
///
/// Returns nothing: the filter is applied to [appointmentFilterProvider], which
/// the list watches.
Future<void> showAppointmentFilterSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    title: 'Filter appointments',
    builder: (sheetContext) =>
        AppointmentFilterBody(onDone: () => Navigator.of(sheetContext).pop()),
  );
}

/// `/appointments/filter` (pushed) — the same body as the sheet, for the route
/// and for deep links. The sheet is the surface people normally see; see
/// [showAppointmentFilterSheet] for why.
class AppointmentFilterScreen extends StatelessWidget {
  const AppointmentFilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: ScreenEnter(
          child: Column(
            children: [
              AppInnerHeader(
                title: 'Filter appointments',
                onBack: () => _leave(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.x5.w,
                    6.h,
                    AppSpacing.x5.w,
                    24.h,
                  ),
                  child: AppointmentFilterBody(onDone: () => _leave(context)),
                ),
              ),
            ],
          ),
        ),
      ),
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

/// The filter controls themselves: date range, doctor, hospital, status and
/// patient (CM-28).
///
/// Edits a **working copy** and commits it on "Show results", so a patient who
/// dismisses the sheet half-way leaves the live list alone. "Clear all" is
/// immediate on the working copy and equally committed by the same button.
class AppointmentFilterBody extends ConsumerStatefulWidget {
  const AppointmentFilterBody({super.key, required this.onDone});

  /// Called after the filter is committed — pops the sheet or the screen.
  final VoidCallback onDone;

  @override
  ConsumerState<AppointmentFilterBody> createState() =>
      _AppointmentFilterBodyState();
}

class _AppointmentFilterBodyState extends ConsumerState<AppointmentFilterBody> {
  late AppointmentFilter _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(appointmentFilterProvider);
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(appointmentFilterOptionsProvider);
    final matchCount = _matchCount();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Date range'),
        _DateRangeField(
          from: _draft.from,
          to: _draft.to,
          onPickFrom: () => _pickDay(isStart: true),
          onPickTo: () => _pickDay(isStart: false),
          onClear: _draft.hasDateRange
              ? () => setState(() {
                  _draft = _draft.cleared(AppointmentFilterField.dateRange);
                })
              : null,
        ),
        _SectionLabel('Status'),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            for (final status in AppointmentStatusViews.all)
              _StatusToggle(
                status: status,
                selected: _draft.statuses.contains(status),
                onTap: () => setState(() {
                  _draft = _draft.toggledStatus(status);
                }),
              ),
          ],
        ),
        _SectionLabel('Doctor'),
        AppSelect<String?>(
          value: _resolve(
            _draft.doctorId,
            options.doctors.map((doctor) => doctor.id),
          ),
          placeholder: _anyDoctor,
          options: [
            const AppSelectOption<String?>(null, _anyDoctor),
            for (final doctor in options.doctors)
              AppSelectOption<String?>(doctor.id, doctor.name),
          ],
          onChanged: (value) => setState(() {
            _draft = value == null
                ? _draft.cleared(AppointmentFilterField.doctor)
                : _draft.copyWith(doctorId: value);
          }),
        ),
        _SectionLabel('Hospital'),
        AppSelect<String?>(
          value: _resolve(
            _draft.hospitalId,
            options.hospitals.map((hospital) => hospital.id),
          ),
          placeholder: _anyHospital,
          options: [
            const AppSelectOption<String?>(null, _anyHospital),
            for (final hospital in options.hospitals)
              AppSelectOption<String?>(hospital.id, hospital.name),
          ],
          onChanged: (value) => setState(() {
            _draft = value == null
                ? _draft.cleared(AppointmentFilterField.hospital)
                : _draft.copyWith(hospitalId: value);
          }),
        ),
        _SectionLabel('Patient'),
        AppSelect<String?>(
          value: _resolve(
            _draft.patientId,
            options.patients.map((patient) => patient.id),
          ),
          placeholder: _anyPatient,
          options: [
            const AppSelectOption<String?>(null, _anyPatient),
            for (final patient in options.patients)
              AppSelectOption<String?>(
                patient.id,
                patient.isSelf
                    ? '${patient.name} (you)'
                    : '${patient.name} · ${patient.relation}',
              ),
          ],
          onChanged: (value) => setState(() {
            _draft = value == null
                ? _draft.cleared(AppointmentFilterField.patient)
                : _draft.copyWith(patientId: value);
          }),
        ),
        SizedBox(height: 18.h),
        Text(
          matchCount == 1
              ? '1 appointment matches'
              : '$matchCount appointments match',
          style: AppText.poppins(size: 12, color: AppColors.textMuted),
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Clear all',
                variant: AppButtonVariant.secondary,
                fullWidth: true,
                disabled: !_draft.isActive,
                semanticLabel: _draft.isActive
                    ? 'Clear all filters'
                    : 'Clear all filters — nothing is filtered yet',
                onPressed: () => setState(() {
                  _draft = AppointmentFilter.none;
                }),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: AppButton(
                label: 'Show results',
                fullWidth: true,
                onPressed: _apply,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The "any" rows carry a null value, which is how the dropdown offers a way
  /// back to unfiltered — a select with no empty option is a one-way door.
  static const String _anyDoctor = 'Any doctor';
  static const String _anyHospital = 'Any hospital';
  static const String _anyPatient = 'Anyone in the family';

  /// [id] only if it is still one of [available].
  ///
  /// The options come from the account's own appointments, so a filter set
  /// before a booking changed could name an id that is no longer offered;
  /// handing that to a dropdown is an assertion failure, not a filter.
  String? _resolve(String? id, Iterable<String> available) =>
      id != null && available.contains(id) ? id : null;

  /// How many appointments the working copy would leave — shown before the
  /// patient commits, so "Show results" never leads to a blank list by
  /// surprise.
  int _matchCount() {
    final rows = ref.watch(appointmentRowsProvider);
    if (!_draft.isActive) return rows.length;
    return rows
        .where(
          (row) => _draft.matches(
            row.appointment,
            status: row.status,
            resolvedHospitalId: row.hospitalId,
          ),
        )
        .length;
  }

  Future<void> _pickDay({required bool isStart}) async {
    final initial = isStart ? _draft.from : _draft.to;
    final picked = await showAppDatePickerSheet(
      context,
      title: isStart ? 'From date' : 'To date',
      initialDay: initial ?? DateTime.now(),
      // Appointments span the past (Completed / Cancelled / No-show) as well as
      // the future, so the range must reach backwards too.
      firstDay: AppDates.addMonths(DateTime.now(), -24),
      lastDay: AppDates.addMonths(DateTime.now(), 12),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final from = isStart ? picked : _draft.from;
      final to = isStart ? _draft.to : picked;
      // Keep the range ordered whichever end was picked first.
      final ordered = from != null && to != null && to.isBefore(from)
          ? (from: to, to: from)
          : (from: from, to: to);
      _draft = AppointmentFilter(
        from: ordered.from,
        to: ordered.to,
        doctorId: _draft.doctorId,
        hospitalId: _draft.hospitalId,
        patientId: _draft.patientId,
        statuses: _draft.statuses,
      );
    });
  }

  void _apply() {
    ref.read(appointmentFilterProvider.notifier).replace(_draft);
    widget.onDone();
  }
}

/// A small caps-free section label above each control group.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 16.h, bottom: 8.h),
      child: Text(
        text,
        style: AppText.poppins(
          size: 13,
          weight: AppText.semibold,
          color: AppColors.textStrong,
        ),
      ),
    );
  }
}

/// The two ends of the date range, each opening the real month calendar
/// (`showAppDatePickerSheet`) rather than a text field.
class _DateRangeField extends StatelessWidget {
  const _DateRangeField({
    required this.from,
    required this.to,
    required this.onPickFrom,
    required this.onPickTo,
    this.onClear,
  });

  final DateTime? from;
  final DateTime? to;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;

  /// Null when there is no range set — the control is then disabled rather
  /// than a no-op.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _DayButton(label: 'From', value: from, onTap: onPickFrom),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _DayButton(label: 'To', value: to, onTap: onPickTo),
            ),
          ],
        ),
        if (onClear != null) ...[
          SizedBox(height: 8.h),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Clear dates',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              onPressed: onClear,
            ),
          ),
        ],
      ],
    );
  }
}

/// One end of the range: its label, the chosen day (or "Any"), a calendar
/// glyph, and a 48px-tall target.
class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final day = value;
    final text = day == null ? 'Any' : AppDates.dayMonthYear(day);
    return Semantics(
      button: true,
      label: '$label date, currently $text. Opens a calendar.',
      child: ExcludeSemantics(
        child: Material(
          color: AppColors.surfaceAlt,
          borderRadius: AppRadii.md,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadii.md,
            child: Container(
              constraints: BoxConstraints(minHeight: 48.h),
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.x3.w,
                vertical: 8.h,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadii.md,
                border: Border.all(color: AppColors.border, width: 1.w),
              ),
              child: Row(
                children: [
                  AppIcon(
                    MedIcon.calendar,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: AppText.poppins(
                            size: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                        Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(
                            size: 13,
                            weight: AppText.medium,
                            color: day == null
                                ? AppColors.textInactive
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A selectable status chip — all five canonical statuses are offered.
class _StatusToggle extends StatelessWidget {
  const _StatusToggle({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final AppointmentStatusView status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Status ${status.label}',
      child: ExcludeSemantics(
        child: Material(
          color: selected ? AppColors.brand : AppColors.surface,
          borderRadius: AppRadii.pill,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadii.pill,
            child: Container(
              constraints: BoxConstraints(minHeight: 38.h),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                borderRadius: AppRadii.pill,
                border: Border.all(
                  color: selected ? AppColors.brand : AppColors.border,
                  width: 1.w,
                ),
              ),
              child: Text(
                status.label,
                style: AppText.poppins(
                  size: 12,
                  weight: AppText.medium,
                  color: selected ? AppColors.textOnBrand : AppColors.textBody,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
