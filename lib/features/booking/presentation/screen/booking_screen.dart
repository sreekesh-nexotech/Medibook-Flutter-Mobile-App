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
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_countdown.dart';
import '../../../../core/widgets/app_date_picker_sheet.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/app_stepper.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../../domain/booking_identifiers.dart';
import '../components/booking_day_strip.dart';
import '../components/confirm_summary.dart';
import '../components/coupon_field.dart';
import '../components/department_card.dart';
import '../components/doctor_card.dart';
import '../components/fee_breakdown_card.dart';
import '../components/flow_screen_enter.dart';
import '../components/patient_card.dart';
import '../components/slot_panel.dart';
import '../controllers/booking_controller.dart';
import '../controllers/booking_records_controller.dart';
import '../controllers/slot_availability.dart';

/// The 4-step "Book Appointment" flow — department → doctor → patient/date/time
/// → summary. Route: `/booking?step=&dept=&doctor=&hospital=&origin=`.
///
/// ## What the audit changed here
///
/// * **CM-11.** A `hospital` param (and [BookingDraft.hospitalId]) makes the
///   discovery funnel location → hospital → department → doctor → slot work end
///   to end. The department-first entry Home and Search use is untouched: with
///   no `hospital` the screen behaves exactly as before, plus a "Browse by
///   hospital" door into `/locations`.
/// * **CM-12.** Step 3's five hardcoded day chips and six hardcoded times are
///   gone. Days come from [BookingDayStrip] carrying real availability, the
///   full month is reachable through [showAppDatePickerSheet], and the times
///   come from `slotsForProvider` with their real available / booked / blocked
///   / past states ([SlotPanel]).
/// * **CM-13 / CM-19.** Step 4 shows the itemised fee ([FeeBreakdownCard]) and
///   a coupon control ([CouponField]) instead of one consultation-fee line.
/// * **CM-14.** The booking reference is minted when the slot hold starts, so
///   it is on screen on the summary — before payment, not after.
/// * **X-02.** Reaching the summary holds the slot for
///   [AppConstants.slotHold] with a visible countdown; on expiry the hold is
///   released and the patient is returned to slot selection.
/// * **CM-17.** The footer no longer books directly. It continues to
///   `/booking/payment`, which is where an appointment is actually created.
///
/// The route params are read once in [initState] and pushed into the shared
/// (autoDispose) [bookingControllerProvider], so the draft resets when the flow
/// is left. System back and the header back both walk the stepper backwards,
/// returning to the origin tab once past step 1 — audit §3.7.2 calls this the
/// app's one correct back example, so it is preserved exactly.
///
/// Router wiring (the orchestrator owns `app_router.dart`):
/// ```dart
/// GoRoute(
///   path: AppRoutes.booking,
///   builder: (context, state) => BookingScreen(
///     step: state.uri.queryParameters['step'],
///     dept: state.uri.queryParameters['dept'],
///     doctor: state.uri.queryParameters['doctor'],
///     hospital: state.uri.queryParameters['hospital'],
///     origin: state.uri.queryParameters['origin'],
///   ),
/// )
/// ```
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({
    super.key,
    this.step,
    this.dept,
    this.doctor,
    this.hospital,
    this.origin,
  });

  final String? step;
  final String? dept;
  final String? doctor;

  /// Hospital id the funnel was entered through (CM-11), or null for the
  /// department-first entry.
  final String? hospital;

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
      ref
          .read(bookingControllerProvider.notifier)
          .configure(
            step: int.tryParse(widget.step ?? '1') ?? 1,
            hospitalId: widget.hospital,
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

  /// Advance a step. Arriving at the summary starts the slot hold and mints the
  /// booking reference + token (X-02, CM-14) — from a callback, never a build.
  void _continue() {
    final notifier = ref.read(bookingControllerProvider.notifier);
    final draft = ref.read(bookingControllerProvider);
    if (!draft.canContinue) return;
    if (draft.step == 3) {
      _startHold();
    }
    notifier.nextStep();
  }

  void _startHold() {
    final draft = ref.read(bookingControllerProvider);
    // One booking attempt, one reference: only mint when there isn't one.
    final reference =
        draft.bookingRef ??
        ref.read(bookingRecordsProvider.notifier).reserveReference();
    final token = AppTokens.normalize(
      ref.read(appointmentsControllerProvider.notifier).nextToken,
    );
    ref
        .read(bookingControllerProvider.notifier)
        .startHold(bookingRef: reference, token: token);
  }

  void _pickPatient(Patient patient) =>
      ref.read(bookingControllerProvider.notifier).pickPatient(patient);

  Future<void> _openCalendar(String doctorId, DateTime? selected) async {
    final today = AppDates.startOfDay(DateTime.now());
    final picked = await showAppDatePickerSheet(
      context,
      initialDay: selected ?? today,
      firstDay: today,
      lastDay: AppDates.addMonths(today, 3),
      availability: dayAvailabilityResolver(ref, doctorId),
      title: 'Pick a date',
    );
    if (picked == null || !mounted) return;
    ref.read(bookingControllerProvider.notifier).pickDay(picked);
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingControllerProvider);

    final Widget stepContent = switch (draft.step) {
      1 => _step1(draft),
      2 => _step2(draft),
      3 => _step3(draft),
      _ => _step4(draft),
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
          child: FlowScreenEnter(
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

  // ---- Step 1: department ------------------------------------------------

  Widget _step1(BookingDraft draft) {
    final all = ref.watch(departmentsProvider);
    final hospitalId = draft.hospitalId;
    final hospital = hospitalId == null
        ? null
        : ref.watch(hospitalByIdProvider(hospitalId));

    // At a chosen facility, only the departments that facility actually runs
    // can be booked (CM-11).
    final List<Department> depts = hospital == null
        ? all
        : [
            for (final d in all)
              if (hospital.offers(d.name)) d,
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hospital != null) ...[
          _HospitalContextRow(
            name: hospital.name,
            locationLabel: hospital.locationLabel,
            onChange: () => context.push(AppRoutes.locations),
            onClear: () =>
                ref.read(bookingControllerProvider.notifier).pickHospital(null),
          ),
          SizedBox(height: AppSpacing.x4.h),
        ],
        _sectionTitle('Please select the department'),
        SizedBox(height: 14.h),
        if (depts.isEmpty)
          AppEmptyView(
            iconName: MedIcon.hospital,
            headline: 'No departments listed here',
            body:
                '${hospital?.name ?? 'This facility'} has not published its '
                'departments yet. Try another hospital.',
            actionLabel: 'Browse hospitals',
            onAction: () => context.push(AppRoutes.hospitals),
          )
        else
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
        if (hospital == null) ...[
          SizedBox(height: AppSpacing.x5.h),
          _StartElsewhereCard(
            onBrowseHospitals: () => context.push(AppRoutes.locations),
          ),
        ],
      ],
    );
  }

  // ---- Step 2: doctor ----------------------------------------------------

  Widget _step2(BookingDraft draft) {
    final depts = ref.watch(departmentsProvider);
    final hospitalId = draft.hospitalId;
    final pool = hospitalId == null
        ? ref.watch(doctorsProvider)
        : ref.watch(doctorsAtHospitalProvider(hospitalId));
    final hospitalName = hospitalId == null
        ? null
        : ref.watch(hospitalByIdProvider(hospitalId)).name;

    final deptNames = [
      for (final d in depts)
        if (hospitalId == null ||
            pool.any((doctor) => doctor.department == d.name))
          d.name,
    ];

    final List<Doctor> filtered = draft.departmentName == null
        ? pool
        : [
            for (final d in pool)
              if (d.department == draft.departmentName) d,
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Select a doctor'),
        if (hospitalName != null) ...[
          SizedBox(height: 4.h),
          Text(
            'At $hospitalName',
            style: AppText.poppins(
              size: AppFontSize.xs,
              color: AppColors.textMuted,
            ),
          ),
        ],
        SizedBox(height: 14.h),
        if (deptNames.isNotEmpty)
          AppSegmentedTabs(
            tabs: deptNames,
            active: draft.departmentName ?? '',
            onChanged: (v) =>
                ref.read(bookingControllerProvider.notifier).pickDepartment(v),
          ),
        SizedBox(height: 16.h),
        if (filtered.isEmpty)
          AppEmptyView(
            iconName: MedIcon.search,
            headline: 'No doctors in this department',
            body: hospitalName == null
                ? 'Try another department.'
                : '$hospitalName does not list a '
                      '${draft.departmentName ?? 'matching'} doctor. Look at '
                      'another hospital, or pick another department.',
            actionLabel: 'Browse hospitals',
            onAction: () => context.push(AppRoutes.hospitals),
          )
        else
          for (final d in filtered) ...[
            DoctorCard(
              doctor: d,
              selected: draft.doctorId == d.id,
              onTap: () => _openDoctor(d),
            ),
            SizedBox(height: 12.h),
          ],
        if (filtered.isNotEmpty) ...[
          SizedBox(height: 4.h),
          Center(
            child: Text(
              'Tap a doctor to view details and book',
              style: AppText.poppins(
                size: AppFontSize.xs,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _openDoctor(Doctor doctor) {
    // Record the pick before leaving, so returning from the detail screen with
    // the system back gesture keeps the doctor selected.
    ref.read(bookingControllerProvider.notifier).pickDoctor(doctor.id);
    context.push(AppRoutes.doctorPath(doctor.id, returnTo: 'booking'));
  }

  // ---- Step 3: patient, day, slot ---------------------------------------

  Widget _step3(BookingDraft draft) {
    final patients = ref.watch(patientsProvider);
    final doctorId = draft.doctorId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: AppSpacing.x1.h,
          children: [
            _sectionTitle('Select patient'),
            AppButton(
              label: 'Add someone',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              leadingIcon: MedIcon.edit,
              semanticLabel: 'Add a family member',
              onPressed: () => context.push(AppRoutes.dependantEditPath()),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        if (patients.isEmpty)
          AppInlineEmpty(
            message: 'No one on this account yet.',
            iconName: MedIcon.records,
            actionLabel: 'Add a family member',
            onAction: () => context.push(AppRoutes.dependantEditPath()),
          )
        else
          for (final p in patients) ...[
            PatientCard(
              patient: p,
              selected: draft.patientId == null
                  ? draft.patientName == p.name
                  : draft.patientId == p.id,
              onTap: () => _pickPatient(p),
            ),
            SizedBox(height: 10.h),
          ],
        SizedBox(height: 10.h),
        _sectionTitle('Select date'),
        SizedBox(height: 12.h),
        if (doctorId == null)
          AppInlineEmpty(
            message: 'Pick a doctor first — the calendar is theirs.',
            iconName: MedIcon.calendar,
            actionLabel: 'Choose a doctor',
            onAction: () => ref.read(bookingControllerProvider.notifier).back(),
          )
        else ...[
          BookingDayStrip(
            days: AppDates.daysFrom(AppDates.startOfDay(DateTime.now()), 7),
            selected: draft.day,
            availabilityOf: dayAvailabilityResolver(ref, doctorId),
            onDaySelected: (day) =>
                ref.read(bookingControllerProvider.notifier).pickDay(day),
            onOpenCalendar: () => _openCalendar(doctorId, draft.day),
          ),
          SizedBox(height: 20.h),
          _sectionTitle('Select time'),
          SizedBox(height: 12.h),
          _slots(draft, doctorId),
        ],
      ],
    );
  }

  Widget _slots(BookingDraft draft, String doctorId) {
    final day = draft.day;
    if (day == null) {
      return AppInlineEmpty(
        message: 'Pick a day to see the times that are open.',
        iconName: MedIcon.clock,
        actionLabel: 'Open the calendar',
        onAction: () => _openCalendar(doctorId, null),
      );
    }
    final slots = ref.watch(slotsForProvider((doctorId: doctorId, day: day)));
    return SlotPanel(
      slots: slots,
      selected: draft.slot,
      emptyMessage: slotEmptyMessage(slots),
      onSlotSelected: (slot) =>
          ref.read(bookingControllerProvider.notifier).pickSlot(slot),
      onOpenCalendar: () => _openCalendar(doctorId, day),
    );
  }

  // ---- Step 4: summary ---------------------------------------------------

  Widget _step4(BookingDraft draft) {
    final doctorId = draft.doctorId;
    final slot = draft.slot;
    if (doctorId == null || slot == null) {
      return AppEmptyView(
        iconName: MedIcon.clock,
        headline: 'Nothing to confirm yet',
        body: 'Pick a doctor, a day and a time first.',
        actionLabel: 'Back to slot selection',
        onAction: () =>
            ref.read(bookingControllerProvider.notifier).backToSlotSelection(),
      );
    }

    if (draft.holdExpired) {
      return _HoldExpiredView(
        slotLabel: slot.rangeLabel,
        onPickAgain: () =>
            ref.read(bookingControllerProvider.notifier).backToSlotSelection(),
      );
    }

    final doctor = ref.watch(doctorByIdProvider(doctorId));
    final fee = ref.watch(
      feeBreakdownProvider((doctorId: doctorId, couponCode: draft.couponCode)),
    );
    final hospitalName = draft.hospitalId == null
        ? doctor.hospital
        : ref.watch(hospitalByIdProvider(draft.hospitalId!)).name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (draft.holdUntil != null) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppCountdownPill(
              deadline: draft.holdUntil!,
              prefix: 'Slot held for',
              onExpired: () =>
                  ref.read(bookingControllerProvider.notifier).expireHold(),
            ),
          ),
          SizedBox(height: AppSpacing.x4.h),
        ],
        _sectionTitle('Confirm appointment'),
        SizedBox(height: 14.h),
        ConfirmSummary(
          doctor: doctor,
          patientName: draft.patientName,
          departmentName: draft.departmentName ?? doctor.department,
          hospitalName: hospitalName,
          scheduledAt: slot.start,
          slotRangeLabel: slot.rangeLabel,
          bookingRef: draft.bookingRef ?? '—',
          token: draft.token ?? '—',
        ),
        SizedBox(height: 14.h),
        CouponField(
          appliedCode: draft.couponCode,
          discount: fee.discount,
          errorText: draft.couponError,
          onApply: (code) => _applyCoupon(doctorId, code),
          onRemove: () =>
              ref.read(bookingControllerProvider.notifier).removeCoupon(),
        ),
        SizedBox(height: 14.h),
        FeeBreakdownCard(
          fee: fee,
          title: 'Payment summary',
          footnote:
              'GST is shown separately, never folded into the consultation '
              'fee. The booking reference above is permanent; the token is '
              'your queue position on the day.',
        ),
        SizedBox(height: 14.h),
        Text(
          'You can reschedule up to 2 hours before your slot.',
          textAlign: TextAlign.center,
          style: AppText.poppins(
            size: AppFontSize.xs,
            color: AppColors.textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  /// Apply a coupon, or report honestly that the catalogue does not know it
  /// (CM-19). The price is only ever moved by a code the fee model accepts.
  void _applyCoupon(String doctorId, String code) {
    final notifier = ref.read(bookingControllerProvider.notifier);
    final candidate = ref.read(
      feeBreakdownProvider((doctorId: doctorId, couponCode: code)),
    );
    if (candidate.couponCode == null || candidate.discount.isZero) {
      notifier.applyCoupon(error: "'$code' is not a valid coupon code.");
      return;
    }
    notifier.applyCoupon(code: code);
  }

  // ---- Chrome ------------------------------------------------------------

  Widget _sectionTitle(String text) => Text(
    text,
    style: AppText.poppins(
      size: AppFontSize.body,
      weight: AppText.semibold,
      color: AppColors.textStrong,
    ),
  );

  Widget _footer(BookingDraft draft) {
    final Widget action;
    if (draft.isLastStep) {
      final blocked = draft.holdExpired || !draft.isPayable;
      action = AppButton(
        label: 'Continue to payment',
        fullWidth: true,
        trailingIcon: MedIcon.bag,
        disabled: blocked,
        semanticLabel: blocked
            ? 'Continue to payment, unavailable — your slot hold ran out'
            : 'Continue to payment',
        onPressed: blocked
            ? null
            : () => context.push(AppRoutes.bookingPayment),
      );
    } else {
      action = AppButton(
        label: 'Continue',
        fullWidth: true,
        disabled: !draft.canContinue,
        onPressed: _continue,
      );
    }

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
      child: action,
    );
  }
}

/// The facility the funnel was entered through, with the two ways out of it
/// (CM-11): pick a different hospital, or drop the filter and browse every
/// department.
class _HospitalContextRow extends StatelessWidget {
  const _HospitalContextRow({
    required this.name,
    required this.locationLabel,
    required this.onChange,
    required this.onClear,
  });

  final String name;
  final String locationLabel;
  final VoidCallback onChange;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(14.w),
      color: AppColors.surfaceTint,
      shadow: AppShadowToken.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(MedIcon.hospital, size: 18, color: AppColors.brand),
              SizedBox(width: AppSpacing.x2.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: AppText.poppins(
                        size: AppFontSize.base,
                        weight: AppText.semibold,
                        color: AppColors.textStrong,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      locationLabel,
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
          SizedBox(height: AppSpacing.x2.h),
          // Wrap, not Row: two ghost buttons plus their 48px hit areas do not
          // fit one line at 390px once the OS text scale passes 1.2x.
          Wrap(
            spacing: AppSpacing.x2.w,
            runSpacing: AppSpacing.x1.h,
            children: [
              AppButton(
                label: 'Change hospital',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                onPressed: onChange,
              ),
              AppButton(
                label: 'All hospitals',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                semanticLabel: 'Clear the hospital filter',
                onPressed: onClear,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The department-first entry's door into discovery (CM-10). The audit's
/// finding was that "discovery begins at a department" with no way to start
/// from a place, so the other starting point is offered here rather than
/// replacing this one.
class _StartElsewhereCard extends StatelessWidget {
  const _StartElsewhereCard({required this.onBrowseHospitals});

  final VoidCallback onBrowseHospitals;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Know where you want to go?',
            style: AppText.poppins(
              size: AppFontSize.base,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Start from a city and area, pick the hospital, then the '
            'department and doctor.',
            style: AppText.poppins(
              size: AppFontSize.xs,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          SizedBox(height: AppSpacing.x3.h),
          // Full width and no leading glyph: the label plus a 48px hit area
          // plus an icon does not fit one line at 1.3x text scale.
          AppButton(
            label: 'Browse locations',
            variant: AppButtonVariant.secondary,
            fullWidth: true,
            onPressed: onBrowseHospitals,
          ),
        ],
      ),
    );
  }
}

/// What the summary shows once the slot hold has run out (X-02).
///
/// The hold is released by the controller before this renders, so the slot is
/// genuinely back in the pool — this screen does not claim anything that has
/// not happened.
class _HoldExpiredView extends StatelessWidget {
  const _HoldExpiredView({required this.slotLabel, required this.onPickAgain});

  final String slotLabel;
  final VoidCallback onPickAgain;

  @override
  Widget build(BuildContext context) {
    return AppEmptyView(
      iconName: MedIcon.clock,
      headline: 'Your slot hold ran out',
      body:
          'We held $slotLabel for '
          '${AppConstants.slotHold.inMinutes} minutes and have now released '
          'it, so someone else can book it. Pick a time again — nothing has '
          'been charged.',
      actionLabel: 'Pick another slot',
      onAction: onPickAgain,
    );
  }
}
