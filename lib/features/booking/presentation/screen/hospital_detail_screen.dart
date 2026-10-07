import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/external_url.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/route_arrival.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/states/app_error_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../dashboard/presentation/components/department_icon.dart';
import '../../application/providers/discovery_providers.dart';
import '../booking_routes.dart';
import '../../domain/entities/department.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/hospital.dart';
import '../../domain/entities/hospital_clock.dart';
import '../../domain/repositories/discovery_repository.dart';
import '../components/cache_status_bar.dart';
import '../components/file_image.dart';
import '../components/flow_screen_enter.dart';
import '../components/slot_labels.dart';

/// One facility, laid out as the design's Hospital Details screen: the cover
/// photo, name / area, the figures, the speciality chips over a two-column
/// doctor grid ("Select a Doctor to proceed"), opening hours, upcoming
/// holidays, the cancellation policy, and the sticky "Select doctor for
/// appointment" footer. Route: `/hospital/:id`.
///
/// Data: `GET /patient/hospitals/{id}` (§7.3) and
/// `GET /patient/hospitals/{id}/doctors?department_code=` (§7.7). This is
/// the hinge of the location-first funnel (CM-11): confirming a doctor here
/// carries the **hospital** into the booking draft.
class HospitalDetailScreen extends ConsumerStatefulWidget {
  const HospitalDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<HospitalDetailScreen> createState() =>
      _HospitalDetailScreenState();
}

class _HospitalDetailScreenState extends ConsumerState<HospitalDetailScreen> {
  // Transient picks for this visit: the chip and the highlighted doctor.
  String? _departmentCode;
  DoctorCard? _selected;

  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.hospitals);
  }

  /// The footer: book with the highlighted doctor at this facility — step 2
  /// ("Doctor & time"), pre-filled with the hospital, department and doctor,
  /// so the patient picks a slot next. Step 3 needs a slot, which this
  /// screen does not have.
  void _confirm(HospitalDetail hospital, DoctorCard doctor) => context.push(
    BookingRoutes.booking(
      step: 2,
      hospital: hospital.id,
      dept: doctor.department.code,
      doctor: doctor.id,
    ),
  );

  Future<void> _refresh() async {
    ref.invalidate(hospitalDetailProvider(widget.id));
    await ref.read(hospitalDetailProvider(widget.id).future);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(hospitalDetailProvider(widget.id));

    return RouteArrival(
      onArrive: () {
        // Nobody awaits this; a failure shows in the screen's own state.
        _refresh().then<void>((_) {}, onError: (Object _) {});
      },
      child: Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          bottom: false,
          child: FlowScreenEnter(
            child: Column(
              children: [
                _Header(onBack: _back),
                Expanded(
                  child: detail.when(
                    loading: () => AppSkeletonList(
                      count: 3,
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                    ),
                    error: (error, _) => AppErrorView(
                      failure: error.asFailure(),
                      headline: error is NotFoundFailure
                          ? 'This hospital is not listed'
                          : null,
                      onRetry: _refresh,
                      secondaryLabel: 'Back to hospitals',
                      onSecondary: _back,
                    ),
                    data: (result) => _Body(
                      hospital: result.value,
                      cache: CacheStatusBar(
                        result: result,
                        onRefresh: _refresh,
                      ),
                      departmentCode: _departmentCode,
                      selected: _selected,
                      onDepartment: (code) => setState(() {
                        _departmentCode = code;
                        _selected = null;
                      }),
                      onSelect: (d) => setState(() => _selected = d),
                    ),
                  ),
                ),
                _Footer(
                  child: AppButton(
                    label: 'Select doctor for appointment',
                    fullWidth: true,
                    pill: true,
                    disabled: _selected == null || detail.valueOrNull == null,
                    semanticLabel: _selected == null
                        ? 'Select doctor for appointment, pick a doctor first'
                        : 'Book an appointment with ${_selected!.name}',
                    onPressed: _selected == null || detail.valueOrNull == null
                        ? null
                        : () => _confirm(detail.requireValue.value, _selected!),
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

class _Body extends ConsumerWidget {
  const _Body({
    required this.hospital,
    required this.cache,
    required this.departmentCode,
    required this.selected,
    required this.onDepartment,
    required this.onSelect,
  });

  final HospitalDetail hospital;
  final Widget cache;
  final String? departmentCode;
  final DoctorCard? selected;
  final ValueChanged<String> onDepartment;
  final ValueChanged<DoctorCard> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chips = hospital.card.departments;
    final active = chips.any((d) => d.code == departmentCode)
        ? departmentCode
        : (chips.isEmpty ? null : chips.first.code);
    final query = HospitalDoctorsQuery(
      hospitalId: hospital.id,
      departmentCode: active,
      sort: 'next_available_at',
      pageSize: 50,
    );
    final doctors = ref.watch(hospitalDoctorsProvider(query));

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 4.h, bottom: 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cache,
                _Cover(hospital: hospital),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hospital.name,
                  style: AppText.poppins(
                    size: AppFontSize.h2,
                    weight: AppText.bold,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                Container(
                  height: 1.h,
                  margin: EdgeInsets.only(top: 12.h, bottom: 16.h),
                  color: AppColors.borderSubtle,
                ),
                Text(
                  hospital.address?.oneLine ?? hospital.card.locationLabel,
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  hospital.card.onlineBookingEnabled
                      ? SlotLabels.nextAvailable(
                          hospital.card.nextAvailableAt,
                          timezone: hospital.timezone,
                        )
                      : 'Online booking is not available here',
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    weight: AppText.medium,
                    color: AppColors.accentBlue,
                  ),
                ),
                SizedBox(height: 24.h),
                _Stats(hospital: hospital),
                SizedBox(height: 24.h),
                Text(
                  'Select a Doctor to proceed',
                  style: AppText.poppins(
                    size: AppFontSize.title,
                    weight: AppText.semibold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
              ],
            ),
          ),
          if (chips.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: EdgeInsets.fromLTRB(20.w, 0, 24.w, 20.h),
              child: Row(
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) SizedBox(width: 12.w),
                    _SpecialityChip(
                      department: chips[i],
                      on: chips[i].code == active,
                      onTap: () => onDepartment(chips[i].code),
                    ),
                  ],
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: doctors.when(
              loading: () => const AppSkeletonList(count: 2, tile: true),
              error: (error, _) => AppInlineError(
                failure: error.asFailure(),
                onRetry: () => ref.invalidate(hospitalDoctorsProvider(query)),
              ),
              data: (result) {
                final shown = result.value.results.take(6).toList();
                if (shown.isEmpty) {
                  return Text(
                    'No doctor listed for this department yet.',
                    style: AppText.poppins(
                      size: AppFontSize.sm,
                      color: AppColors.textMuted,
                    ),
                  );
                }
                return _DoctorGrid(
                  doctors: shown,
                  selectedId: selected?.id,
                  onSelect: onSelect,
                  onInfo: (d) => context.push(
                    AppRoutes.doctorPath(d.id, returnTo: 'hospital'),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(0, 20.h, 0, 4.h),
            child: Center(
              child: _Link(
                label: 'View more doctors',
                size: AppFontSize.body,
                semantics: 'View more doctors at ${hospital.name}',
                onTap: () => context.push(
                  BookingRoutes.booking(
                    step: 2,
                    hospital: hospital.id,
                    dept: active,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Opening hours'),
                SizedBox(height: 8.h),
                _Hours(hours: hospital.hours),
                if (hospital.holidays.isNotEmpty) ...[
                  SizedBox(height: 24.h),
                  _SectionTitle('Upcoming holidays'),
                  SizedBox(height: 8.h),
                  _Holidays(
                    holidays: hospital.holidays,
                    departments: hospital.card.departments,
                  ),
                ],
                if (hospital.cancellationPolicy != null) ...[
                  SizedBox(height: 24.h),
                  _SectionTitle('Cancellation policy'),
                  SizedBox(height: 8.h),
                  _Policy(
                    policy: hospital.cancellationPolicy!,
                    bookingWindowDays: hospital.bookingWindowDays,
                  ),
                ],
                if (hospital.phoneE164 != null ||
                    hospital.email != null ||
                    hospital.website != null) ...[
                  SizedBox(height: 24.h),
                  _SectionTitle('Contact'),
                  SizedBox(height: 8.h),
                  _Contact(hospital: hospital),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Chrome -----------------------------------------------------------------

/// Back · "Hospital Details" (`13/500`, muted, `.02em`) · a 46px spacer so
/// the label stays centred; padded `54px 20px 12px` (8 below the OS inset).
class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
      child: Row(
        children: [
          AppIconButton(
            icon: MedIcon.back,
            size: 38,
            semanticLabel: 'Back',
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              'Hospital Details',
              textAlign: TextAlign.center,
              style: AppText.poppins(
                size: AppFontSize.sm,
                weight: AppText.medium,
                color: AppColors.textMuted,
                letterSpacing: 0.26,
              ),
            ),
          ),
          SizedBox(width: 46.w),
        ],
      ),
    );
  }
}

/// The sticky white footer: `padding 12px 20px 20px`, hairline on top.
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
        20.h + MediaQuery.paddingOf(context).bottom,
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
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// The `196` hero: the cover photo (`cover_file_id`) or the tinted first-aid
/// placeholder with the name.
class _Cover extends StatelessWidget {
  const _Cover({required this.hospital});

  final HospitalDetail hospital;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadii.lg,
      child: SizedBox(
        height: 196.h,
        width: double.infinity,
        child: AppFileImage(
          fileId: hospital.card.coverFileId ?? hospital.card.logoFileId,
          fallback: ColoredBox(
            color: AppColors.surfaceTint,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(PhIcon.firstAid, size: 44, color: AppColors.brand),
                SizedBox(height: 12.h),
                Text(
                  hospital.name,
                  textAlign: TextAlign.center,
                  style: AppText.poppins(
                    size: AppFontSize.sm,
                    weight: AppText.semibold,
                    color: AppColors.brand,
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

/// The figures the backend actually publishes: departments, rating, review
/// count, booking window. Nothing invented.
class _Stats extends StatelessWidget {
  const _Stats({required this.hospital});

  final HospitalDetail hospital;

  @override
  Widget build(BuildContext context) {
    final card = hospital.card;
    final stats = <({String icon, String value, String label})>[
      (
        icon: PhIcon.firstAid,
        value: '${card.departments.length}',
        label: 'departments',
      ),
      (
        icon: PhIcon.starFill,
        value: card.hasRating ? card.ratingValue.toStringAsFixed(1) : '–',
        label: 'rating',
      ),
      (
        icon: PhIcon.pencilSimple,
        value: '${card.ratingCount}',
        label: 'reviews',
      ),
      (
        icon: PhIcon.calendarBlank,
        value: '${hospital.bookingWindowDays}d',
        label: 'booking window',
      ),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) SizedBox(width: 8.w),
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 50.r,
                  height: 50.r,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: AppShadows.sm,
                  ),
                  child: Center(
                    child: AppIcon(
                      stats[i].icon,
                      size: 24,
                      color: AppColors.brand,
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  stats[i].value,
                  style: AppText.poppins(
                    size: AppFontSize.body,
                    weight: AppText.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  stats[i].label,
                  textAlign: TextAlign.center,
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    color: AppColors.textMuted,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A speciality chip: `46` tall, `0 16`, pill, `14/500` label. On: tint fill,
/// brand text; off: white, body text, border.
class _SpecialityChip extends StatelessWidget {
  const _SpecialityChip({
    required this.department,
    required this.on,
    required this.onTap,
  });

  final DepartmentRef department;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = on ? AppColors.brand : AppColors.textBody;
    return Semantics(
      button: true,
      selected: on,
      label: '${department.name} doctors',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 46.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: on ? AppColors.surfaceTint : AppColors.surface,
              borderRadius: AppRadii.pill,
              border: Border.all(
                color: on ? AppColors.surfaceTint : AppColors.border,
                width: 1.w,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The department's own icon, as Home, Search and Booking
                // show it, not one first-aid mark for every chip.
                AppIcon(
                  departmentIconFor(department.code),
                  size: 18,
                  color: fg,
                ),
                SizedBox(width: 8.w),
                Text(
                  department.name,
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    weight: AppText.medium,
                    color: fg,
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

/// The two-column doctor grid (`gap 12`).
class _DoctorGrid extends StatelessWidget {
  const _DoctorGrid({
    required this.doctors,
    required this.selectedId,
    required this.onSelect,
    required this.onInfo,
  });

  final List<DoctorCard> doctors;
  final String? selectedId;
  final ValueChanged<DoctorCard> onSelect;
  final ValueChanged<DoctorCard> onInfo;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < doctors.length; i += 2) {
      if (i > 0) rows.add(SizedBox(height: 12.h));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _tile(doctors[i])),
            SizedBox(width: 12.w),
            Expanded(
              child: i + 1 < doctors.length
                  ? _tile(doctors[i + 1])
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _tile(DoctorCard d) => _DoctorTile(
    doctor: d,
    selected: d.id == selectedId,
    onTap: d.canBook ? () => onSelect(d) : null,
    onInfo: () => onInfo(d),
  );
}

/// One doctor tile: a `112` photo (rating pill top-right, info disc
/// bottom-right), name `14/700`, "8 yrs experience" `12` muted; a `1.5px`
/// brand ring when highlighted.
class _DoctorTile extends StatelessWidget {
  const _DoctorTile({
    required this.doctor,
    required this.selected,
    required this.onTap,
    required this.onInfo,
  });

  final DoctorCard doctor;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final experience = doctor.experienceLabel;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label:
          '${doctor.name}, ${doctor.specialityLabel}'
          '${doctor.hasRating ? ', rated ${doctor.rating}' : ''}'
          '${doctor.canBook ? '' : ', not bookable online'}',
      child: ExcludeSemantics(
        child: Container(
          padding: EdgeInsets.all(1.5.r),
          decoration: BoxDecoration(
            color: selected ? AppColors.brand : Colors.transparent,
            borderRadius: AppRadii.lg,
          ),
          child: AppCard(
            onTap: onTap,
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: AppRadii.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 112.h,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppFileImage(
                          fileId: doctor.photoFileId,
                          fallback: const ColoredBox(
                            color: AppColors.surfaceTint,
                          ),
                          alignment: const Alignment(0, -0.64),
                        ),
                        if (doctor.hasRating)
                          Positioned(
                            top: 6.h,
                            right: 6.w,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 3.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.warning,
                                borderRadius: AppRadii.pill,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppIcon(
                                    PhIcon.starFill,
                                    size: 12,
                                    color: AppColors.textOnBrand,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    doctor.ratingValue.toStringAsFixed(1),
                                    style: AppText.poppins(
                                      size: AppFontSize.xs,
                                      weight: AppText.semibold,
                                      color: AppColors.textOnBrand,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 6.h,
                          right: 6.w,
                          child: Semantics(
                            button: true,
                            label: 'About ${doctor.name}',
                            child: ExcludeSemantics(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onInfo,
                                child: Container(
                                  width: 26.r,
                                  height: 26.r,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    shape: BoxShape.circle,
                                    boxShadow: AppShadows.sm,
                                  ),
                                  child: Center(
                                    child: AppIcon(
                                      PhIcon.eye,
                                      size: 16,
                                      color: AppColors.brand,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 16.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          doctor.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(
                            size: AppFontSize.base,
                            weight: AppText.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          doctor.canBook
                              ? (experience == null
                                    ? doctor.specialityLabel
                                    : '$experience experience')
                              : 'Not bookable online',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }
}

/// Accent-blue underlined text link.
class _Link extends StatelessWidget {
  const _Link({
    required this.label,
    required this.size,
    required this.semantics,
    required this.onTap,
  });

  final String label;
  final double size;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
            child: Text(
              label,
              style: AppText.poppins(
                size: size,
                weight: AppText.semibold,
                color: AppColors.accentBlue,
              ).copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ),
      ),
    );
  }
}

/// One row per weekday, hospital-local times; today in bold.
class _Hours extends StatelessWidget {
  const _Hours({required this.hours});

  final List<HospitalHours> hours;

  static const List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    if (hours.isEmpty) {
      return Text(
        'Opening hours not published.',
        style: AppText.poppins(
          size: AppFontSize.sm,
          color: AppColors.textMuted,
        ),
      );
    }
    final today = DateTime.now().weekday - 1;
    final sorted = hours.toList()
      ..sort((a, b) => a.weekday.compareTo(b.weekday));
    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          for (final h in sorted)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      h.weekday >= 0 && h.weekday < _days.length
                          ? _days[h.weekday]
                          : 'Day ${h.weekday}',
                      style: AppText.poppins(
                        size: AppFontSize.sm,
                        weight: h.weekday == today
                            ? AppText.semibold
                            : AppText.regular,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
                  Text(
                    h.isClosed
                        ? 'Closed'
                        : '${h.opensAt ?? '–'} – ${h.closesAt ?? '–'}',
                    style: AppText.poppins(
                      size: AppFontSize.sm,
                      weight: AppText.medium,
                      color: h.isClosed
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Holidays extends StatelessWidget {
  const _Holidays({required this.holidays, required this.departments});

  final List<HospitalHoliday> holidays;

  /// The hospital's departments, to name the one a holiday closes.
  final List<DepartmentRef> departments;

  @override
  Widget build(BuildContext context) {
    // "Foundation day (Cardiology)"; the department comes in the same
    // response, so "(one department)" only when it is not listed.
    String label(HospitalHoliday h) {
      final id = h.departmentId;
      if (id == null) return h.name;
      final department = departments.where((d) => d.id == id).firstOrNull;
      return '${h.name} (${department?.name ?? 'one department'})';
    }

    String range(HospitalHoliday h) {
      final from = HospitalClock.parseDate(h.dateFrom);
      final to = HospitalClock.parseDate(h.dateTo);
      if (from == null) return h.dateFrom;
      if (to == null || h.dateTo == h.dateFrom) return AppDates.dayMonth(from);
      return '${AppDates.dayMonth(from)} – ${AppDates.dayMonth(to)}';
    }

    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          for (final h in holidays.take(10))
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label(h),
                      style: AppText.poppins(
                        size: AppFontSize.sm,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
                  Text(
                    range(h),
                    style: AppText.poppins(
                      size: AppFontSize.sm,
                      weight: AppText.medium,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The cancellation policy, in sentences (§7.3). Rates are basis points.
class _Policy extends StatelessWidget {
  const _Policy({required this.policy, required this.bookingWindowDays});

  final CancellationPolicy policy;
  final int bookingWindowDays;

  static String _pct(int bp) => '${(bp / 100).toStringAsFixed(0)}%';

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      'Cancel more than ${policy.cutoffHours} hours before your slot for a '
          '${_pct(policy.refundBeforeCutoffBp)} refund; inside that window '
          '${policy.refundAfterCutoffBp == 0 ? 'no refund is given' : 'the refund is ${_pct(policy.refundAfterCutoffBp)}'}.',
      policy.refundIncludesConvenienceFee
          ? 'Refunds include the convenience fee.'
          : 'The convenience fee is not refunded.',
      if (policy.tokenCancelLimitMin != null)
        'Cancellation closes ${policy.tokenCancelLimitMin} minutes before '
            'the session starts.'
      else
        'You can cancel until your token is called.',
      'If the hospital cancels, ${_pct(policy.hospitalCancellationRefundBp)} '
          'is refunded.',
      'Bookings open up to $bookingWindowDays days ahead.',
    ];
    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 3.h),
              child: Text(
                line,
                style: AppText.poppins(
                  size: AppFontSize.sm,
                  color: AppColors.textBody,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Contact extends ConsumerWidget {
  const _Contact({required this.hospital});

  final HospitalDetail hospital;

  /// Where the Directions row points: the pin when the hospital has one,
  /// otherwise its postal address — as a maps search link, which the maps
  /// app (or a browser) opens on both platforms.
  String? get _directionsUrl {
    final lat = hospital.lat;
    final lng = hospital.lng;
    final query = lat != null && lng != null
        ? '$lat,$lng'
        : hospital.address == null
        ? null
        : '${hospital.card.name}, ${hospital.address!.oneLine}';
    if (query == null) return null;
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    }).toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Each row hands off to the OS: the dialler, the mail app, the browser
    // and maps (CL DISC-004 / DISC-005 — they were plain text).
    final directions = _directionsUrl;
    final rows = <({String label, String value, String url, String semantics})>[
      if (hospital.phoneE164 != null)
        (
          label: 'Phone',
          value: hospital.phoneE164!,
          url: 'tel:${hospital.phoneE164}',
          semantics: 'Call ${hospital.card.name}',
        ),
      if (directions != null)
        (
          label: 'Directions',
          value: 'Open in Maps',
          url: directions,
          semantics: 'Get directions to ${hospital.card.name}',
        ),
      if (hospital.email != null)
        (
          label: 'Email',
          value: hospital.email!,
          url: 'mailto:${hospital.email}',
          semantics: 'Email ${hospital.card.name}',
        ),
      if (hospital.website != null)
        (
          label: 'Website',
          value: hospital.website!,
          url: hospital.website!,
          semantics: 'Open the ${hospital.card.name} website',
        ),
    ];

    Future<void> open(String url) async {
      if (await openExternalUrl(url)) return;
      ref
          .read(toastControllerProvider.notifier)
          .show('No app on this phone can open that.');
    }

    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          for (final row in rows)
            Semantics(
              button: true,
              label: '${row.semantics}, ${row.value}',
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: () => open(row.url),
                  borderRadius: AppRadii.sm,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 88.w,
                          child: Text(
                            row.label,
                            style: AppText.poppins(
                              size: AppFontSize.sm,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            row.value,
                            style: AppText.poppins(
                              size: AppFontSize.sm,
                              weight: AppText.medium,
                              color: AppColors.accentBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
