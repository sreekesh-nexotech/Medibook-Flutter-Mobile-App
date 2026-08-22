import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/department.dart';
import '../../../../core/mock_data/models/doctor.dart';
import '../../../../core/mock_data/models/patient.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/app_stepper.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../components/confirm_summary.dart';
import '../components/date_chip.dart';
import '../components/department_card.dart';
import '../components/doctor_card.dart';
import '../components/patient_card.dart';
import '../components/time_chip.dart';
import '../controllers/booking_controller.dart';

/// The 4-step "Book Appointment" flow (department → doctor → patient/date/time →
/// confirm). Route: `/booking?step=&dept=&doctor=&origin=`.
///
/// The route params are read once in [initState] and pushed into the shared
/// [bookingControllerProvider]; every selection thereafter flows through that
/// (autoDispose) controller so the draft resets when the flow is left. System
/// back and the header back both walk the stepper backwards, returning to the
/// origin tab once past step 1.
///
/// The router builder wires the constructor from the query string, e.g.:
/// ```dart
/// BookingScreen(
///   step: state.uri.queryParameters['step'],
///   dept: state.uri.queryParameters['dept'],
///   doctor: state.uri.queryParameters['doctor'],
///   origin: state.uri.queryParameters['origin'],
/// )
/// ```
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({
    super.key,
    this.step,
    this.dept,
    this.doctor,
    this.origin,
  });

  final String? step;
  final String? dept;
  final String? doctor;
  final String? origin;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  @override
  void initState() {
    super.initState();
    // Seed the draft from the route params. Riverpod forbids mutating a
    // provider while the tree is building (initState runs mid-build on
    // navigation), so defer one microtask; the autoDispose draft starts on
    // step 1, making the pre-configure frame visually correct for a fresh
    // flow and imperceptible (<1 frame) for deep links.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(bookingControllerProvider.notifier).configure(
            step: int.tryParse(widget.step ?? '1') ?? 1,
            departmentName: widget.dept,
            doctorId: widget.doctor,
            origin: widget.origin == 'appointments'
                ? BookingOrigin.appointments
                : BookingOrigin.home,
          );
    });
  }

  /// Header + system back: consume a step if possible, otherwise leave the flow
  /// and return to the origin tab.
  void _handleBack() {
    final notifier = ref.read(bookingControllerProvider.notifier);
    if (notifier.back()) return;
    final origin = ref.read(bookingControllerProvider).origin;
    context.go(
      origin == BookingOrigin.appointments
          ? AppRoutes.appointments
          : AppRoutes.home,
    );
  }

  void _confirmAndPay() {
    final draft = ref.read(bookingControllerProvider);
    final doctorId = draft.doctorId;
    if (doctorId == null) return;
    final dates = AppDates.upcomingChips();
    final dateFull = dates[draft.dateIndex.clamp(0, dates.length - 1)].full;
    final appt = ref
        .read(appointmentsControllerProvider.notifier)
        .book(
          doctorId: doctorId,
          patient: draft.patientName,
          dateFull: dateFull,
          time: draft.time,
        );
    context.go(AppRoutes.successPath(appt.id));
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingControllerProvider);
    final depts = ref.watch(departmentsProvider);
    final doctors = ref.watch(doctorsProvider);
    final patients = ref.watch(patientsProvider);
    final times = ref.watch(timeSlotsProvider);
    final dates = AppDates.upcomingChips();

    final selectedDoctor = draft.doctorId == null
        ? null
        : ref.watch(doctorByIdProvider(draft.doctorId!));
    final tokenNumber = ref.watch(
      appointmentsControllerProvider.select((s) => s.nextTokenNumber),
    );
    final dateFull = dates[draft.dateIndex.clamp(0, dates.length - 1)].full;

    final Widget stepContent = switch (draft.step) {
      1 => _step1(depts, draft),
      2 => _step2(doctors, [for (final d in depts) d.name], draft),
      3 => _step3(patients, times, dates, draft),
      _ => selectedDoctor == null
          ? const SizedBox.shrink()
          : _step4(selectedDoctor, dateFull, 'A-$tokenNumber', draft),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: _ScreenEnter(
            child: Column(
              children: [
                AppInnerHeader(title: 'Book Appointment', onBack: _handleBack),
                Padding(
                  padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 4.h),
                  child: AppStepper(current: draft.step),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
                    child: stepContent,
                  ),
                ),
                _footer(draft),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Steps -------------------------------------------------------------

  Widget _step1(List<Department> depts, BookingDraft draft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Please select the department'),
        SizedBox(height: 14.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = (constraints.maxWidth - 12.w) / 2;
            return Wrap(
              spacing: 12.w,
              runSpacing: 12.h,
              children: [
                for (final d in depts)
                  SizedBox(
                    width: cellWidth,
                    child: DepartmentCard(
                      department: d,
                      selected: draft.departmentName == d.name,
                      onTap: () => ref
                          .read(bookingControllerProvider.notifier)
                          .pickDepartment(d.name),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _step2(List<Doctor> doctors, List<String> deptNames, BookingDraft draft) {
    final filtered = draft.departmentName == null
        ? doctors
        : [for (final d in doctors) if (d.department == draft.departmentName) d];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Select a doctor'),
        SizedBox(height: 14.h),
        AppSegmentedTabs(
          tabs: deptNames,
          active: draft.departmentName ?? '',
          onChanged: (v) =>
              ref.read(bookingControllerProvider.notifier).pickDepartment(v),
        ),
        SizedBox(height: 16.h),
        for (final d in filtered) ...[
          DoctorCard(
            doctor: d,
            selected: draft.doctorId == d.id,
            onTap: () =>
                context.push(AppRoutes.doctorPath(d.id, returnTo: 'booking')),
          ),
          SizedBox(height: 12.h),
        ],
        SizedBox(height: 4.h),
        Center(
          child: Text(
            'Tap a doctor to view details and book',
            style: AppText.poppins(size: 12, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _step3(
    List<Patient> patients,
    List<String> times,
    List<DateChip> dates,
    BookingDraft draft,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Select patient'),
        SizedBox(height: 12.h),
        for (final p in patients) ...[
          PatientCard(
            patient: p,
            selected: draft.patientName == p.name,
            onTap: () =>
                ref.read(bookingControllerProvider.notifier).pickPatient(p.name),
          ),
          SizedBox(height: 10.h),
        ],
        SizedBox(height: 10.h),
        _sectionTitle('Select date'),
        SizedBox(height: 12.h),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < dates.length; i++) ...[
                DateChipTile(
                  data: dates[i],
                  selected: draft.dateIndex == i,
                  onTap: () =>
                      ref.read(bookingControllerProvider.notifier).pickDate(i),
                ),
                if (i < dates.length - 1) SizedBox(width: 10.w),
              ],
            ],
          ),
        ),
        SizedBox(height: 20.h),
        _sectionTitle('Select time'),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
          children: [
            for (final t in times)
              TimeChipTile(
                label: t,
                selected: draft.time == t,
                onTap: () =>
                    ref.read(bookingControllerProvider.notifier).pickTime(t),
              ),
          ],
        ),
      ],
    );
  }

  Widget _step4(Doctor doctor, String dateFull, String token, BookingDraft draft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Confirm appointment'),
        SizedBox(height: 14.h),
        ConfirmSummary(
          doctor: doctor,
          patientName: draft.patientName,
          departmentName: draft.departmentName ?? doctor.department,
          dateFull: dateFull,
          time: draft.time,
          token: token,
        ),
        SizedBox(height: 14.h),
        Text(
          'Payment is collected at the hospital desk.\n'
          'You can reschedule up to 2 hours before your slot.',
          textAlign: TextAlign.center,
          style: AppText.poppins(
            size: 12,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ---- Chrome ------------------------------------------------------------

  Widget _sectionTitle(String text) => Text(
    text,
    style: AppText.poppins(
      size: 16,
      weight: AppText.semibold,
      color: AppColors.textStrong,
    ),
  );

  Widget _footer(BookingDraft draft) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 14.h, bottom: 22.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.w),
        ),
      ),
      child: draft.isLastStep
          ? AppButton(
              label: 'Confirm and Pay',
              fullWidth: true,
              onPressed: _confirmAndPay,
            )
          : AppButton(
              label: 'Continue',
              fullWidth: true,
              disabled: !draft.canContinue,
              onPressed: () =>
                  ref.read(bookingControllerProvider.notifier).nextStep(),
            ),
    );
  }
}

/// Pushed-screen enter: fade + 10px rise over [AppConstants.screenIn].
class _ScreenEnter extends StatelessWidget {
  const _ScreenEnter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppConstants.screenIn,
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10.h),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
