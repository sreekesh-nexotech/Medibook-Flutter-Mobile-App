import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/doctor.dart';
import '../../../../core/mock_data/models/hospital.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_rating.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/app_stub_notice.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../domain/booking_routes.dart';
import '../components/doctor_card.dart';
import '../components/flow_screen_enter.dart';

/// One facility: its details, the departments it runs, and its doctors
/// (CM-11). Route: `/hospital/:id`.
///
/// This is the hinge of the funnel the audit said did not exist. Picking a
/// doctor here carries the **hospital** into the booking draft
/// (`BookingRoutes.booking(hospital: …)`), so steps 1 and 2 stay narrowed to
/// this facility all the way to the slot grid.
///
/// The address block offers directions and a phone call. Neither
/// `url_launcher` nor a maps package exists in this build and none may be
/// added, so both are declared stubs (THE LAW): they explain themselves
/// instead of pretending to dial or to open a map.
///
/// Router wiring:
/// ```dart
/// GoRoute(
///   path: '${AppRoutes.hospital}/:id',
///   builder: (context, state) =>
///       HospitalDetailScreen(id: state.pathParameters['id']!),
/// )
/// ```
class HospitalDetailScreen extends ConsumerStatefulWidget {
  const HospitalDetailScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<HospitalDetailScreen> createState() =>
      _HospitalDetailScreenState();
}

class _HospitalDetailScreenState extends ConsumerState<HospitalDetailScreen> {
  static const String _allDepartments = 'All';

  String _department = _allDepartments;

  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.hospitals);
  }

  /// Book with one doctor at this facility — step 3 (patient/day/slot),
  /// pre-filled with the hospital, department and doctor.
  void _bookDoctor(Hospital hospital, Doctor doctor) => context.push(
    BookingRoutes.booking(
      step: 3,
      hospital: hospital.id,
      dept: doctor.department,
      doctor: doctor.id,
    ),
  );

  /// Book at this facility without a doctor in mind — step 1, narrowed to the
  /// departments it runs.
  void _bookHere(Hospital hospital) =>
      context.push(BookingRoutes.booking(step: 1, hospital: hospital.id));

  @override
  Widget build(BuildContext context) {
    final hospital = ref.watch(hospitalByIdProvider(widget.id));
    final doctors = ref.watch(doctorsAtHospitalProvider(widget.id));

    final tabs = [_allDepartments, ...hospital.departments];
    final active = tabs.contains(_department) ? _department : _allDepartments;
    final filtered = [
      for (final d in doctors)
        if (active == _allDepartments || d.department == active) d,
    ];

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: FlowScreenEnter(
          child: Column(
            children: [
              AppInnerHeader(title: 'Hospital', onBack: _back),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Hero(hospital: hospital),
                      SizedBox(height: 14.h),
                      _AddressCard(hospital: hospital),
                      SizedBox(height: 18.h),
                      Text(
                        'Doctors here',
                        style: AppText.poppins(
                          size: AppFontSize.body,
                          weight: AppText.semibold,
                          color: AppColors.textStrong,
                        ),
                      ),
                      SizedBox(height: AppSpacing.x3.h),
                      if (tabs.length > 1)
                        AppSegmentedTabs(
                          tabs: tabs,
                          active: active,
                          onChanged: (value) =>
                              setState(() => _department = value),
                        ),
                      SizedBox(height: AppSpacing.x4.h),
                      if (filtered.isEmpty)
                        AppEmptyView(
                          iconName: MedIcon.search,
                          headline: active == _allDepartments
                              ? 'No doctors listed here yet'
                              : 'No $active doctor here',
                          body:
                              '${hospital.name} has not published a '
                              '${active == _allDepartments ? '' : '$active '}'
                              'consulting roster. Other facilities nearby may '
                              'have one.',
                          actionLabel: 'Browse other hospitals',
                          onAction: () => context.push(AppRoutes.hospitals),
                        )
                      else
                        for (final d in filtered) ...[
                          DoctorCard(
                            doctor: d,
                            onTap: () => _bookDoctor(hospital, d),
                          ),
                          SizedBox(height: 12.h),
                        ],
                    ],
                  ),
                ),
              ),
              _Footer(onBookHere: () => _bookHere(hospital)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Name, location, rating, hours and department count.
class _Hero extends StatelessWidget {
  const _Hero({required this.hospital});

  final Hospital hospital;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hospital.imageAsset != null)
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg.r),
              ),
              child: Image.asset(
                hospital.imageAsset!,
                height: 132.h,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => SizedBox(
                  height: 132.h,
                  child: ColoredBox(color: AppColors.surfaceTint),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(18.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hospital.name,
                  style: AppText.poppins(
                    size: AppFontSize.h3,
                    weight: AppText.bold,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${hospital.locationLabel} · ${hospital.distanceLabel}',
                  style: AppText.poppins(
                    size: AppFontSize.sm,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: AppSpacing.x3.h),
                Row(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: AppRating(
                        value: hospital.rating,
                        showValue: true,
                        size: 14,
                      ),
                    ),
                    SizedBox(width: AppSpacing.x3.w),
                    Expanded(
                      child: Text(
                        hospital.departments.length == 1
                            ? '1 department'
                            : '${hospital.departments.length} departments',
                        style: AppText.poppins(
                          size: AppFontSize.xs,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Address, hours and phone, plus the two honestly-stubbed actions.
class _AddressCard extends ConsumerWidget {
  const _AddressCard({required this.hospital});

  final Hospital hospital;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = hospital.phone;
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Line(iconName: MedIcon.location, text: hospital.address),
          SizedBox(height: AppSpacing.x2.h),
          _Line(iconName: MedIcon.clock, text: hospital.openingHours),
          if (phone != null) ...[
            SizedBox(height: AppSpacing.x2.h),
            _Line(iconName: MedIcon.bell, text: phone),
          ],
          SizedBox(height: AppSpacing.x4.h),
          Wrap(
            spacing: AppSpacing.x2.w,
            runSpacing: AppSpacing.x2.h,
            children: [
              if (hospital.hasCoordinates)
                AppButton(
                  label: 'Directions',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  leadingIcon: MedIcon.location,
                  stubbed: true,
                  semanticLabel: 'Directions to ${hospital.name}',
                  onPressed: () => showStubbedToast(context, ref, 'Directions'),
                )
              else
                AppButton(
                  label: 'Directions',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  leadingIcon: MedIcon.location,
                  disabled: true,
                  semanticLabel:
                      'Directions unavailable — this facility has not '
                      'published map coordinates',
                ),
              if (phone != null)
                AppButton(
                  label: 'Call reception',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  stubbed: true,
                  semanticLabel: 'Call ${hospital.name} reception on $phone',
                  onPressed: () => showStubbedToast(context, ref, 'Calling'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.iconName, required this.text});

  final String iconName;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Padding(
            padding: EdgeInsets.only(top: 2.h),
            child: AppIcon(iconName, size: 15, color: AppColors.textMuted),
          ),
        ),
        SizedBox(width: AppSpacing.x2.w),
        Expanded(
          child: Text(
            text,
            style: AppText.poppins(
              size: AppFontSize.base,
              color: AppColors.textBody,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.onBookHere});

  final VoidCallback onBookHere;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 14.h,
        bottom: 22.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.w),
        ),
      ),
      child: AppButton(
        label: 'Book at this hospital',
        fullWidth: true,
        onPressed: onBookHere,
      ),
    );
  }
}
