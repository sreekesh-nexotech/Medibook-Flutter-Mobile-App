import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/storage/cache/cached_fetcher.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/route_arrival.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_error_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../application/providers/availability_providers.dart';
import '../../application/providers/booking_draft_provider.dart';
import '../../application/providers/booking_providers.dart';
import '../../application/providers/discovery_providers.dart';
import '../../application/states/booking_draft.dart';
import '../../domain/entities/booking_result.dart';
import '../../domain/entities/department.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/person_summary.dart';
import '../../domain/repositories/discovery_repository.dart';
import '../components/booking_doctor_card.dart';
import '../components/booking_stepper.dart';
import '../components/booking_summary_card.dart';
import '../components/cache_status_bar.dart';
import '../components/coupon_field.dart';
import '../components/department_card.dart';
import '../components/draft_text.dart';
import '../components/fee_breakdown_card.dart';
import '../components/flow_screen_enter.dart';
import '../components/hospital_card.dart';
import '../components/patient_card.dart';
import '../components/slot_labels.dart';
import '../components/slot_sheet.dart';
import '../../application/providers/booking_search_providers.dart';
import '../../../dashboard/presentation/components/department_icon.dart';

/// The 4-step "Book Appointment" flow, laid out as the design's Booking
/// screen: Department → Doctor & time → Patient → Payment.
/// Route: `/booking?step=&dept=&doctor=&hospital=&slot=&origin=`.
///
/// * **Step 1** — departments: the facility's (`GET …/{id}/departments`)
///   when the flow was entered through a hospital, else the platform list
///   (`GET /patient/departments`).
/// * **Step 2** — doctors are listed per hospital (§7.7), so with no hospital
///   yet the step first lists the hospitals running the department, then
///   that hospital's doctors. "Book Appointment" opens the slot sheet
///   (availability + slots by session).
/// * **Step 3** — the chosen slot (with "Change"), then "Appointment for"
///   from `GET /patient/me/persons`. No self person and no dependants →
///   "Add a family member"; nothing is invented.
/// * **Step 4** — the confirmation card with the backend's fee quote
///   (`GET /patient/fee-quotes`, coupon included) and "Pay ₹…", which runs
///   `POST /patient/appointments` and hands over to `/booking/payment` with
///   the returned appointment and order. `409 SLOT_UNAVAILABLE` reloads the
///   slots and returns to the time step.
class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({
    super.key,
    this.step,
    this.dept,
    this.doctor,
    this.hospital,
    this.origin,
    this.slot,
    this.resume = false,
  });

  final String? step;

  /// Department code.
  final String? dept;

  /// Doctor id.
  final String? doctor;

  /// Hospital id the funnel was entered through (CM-11).
  final String? hospital;

  final String? origin;

  /// A slot id picked on Doctor Details before entering the flow.
  final String? slot;

  /// Keep the draft in progress and only move to [step] (BL-PAY-028).
  final bool resume;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  bool _routeApplied = false;

  /// True once [initState]'s `configure` has run. `configure` replaces the
  /// whole draft, so the route's doctor and slot may only be applied after
  /// it — applied before, they were wiped and the flow opened on "Pick a
  /// doctor and a time first" (BL-BOOK-026).
  bool _configured = false;

  @override
  void initState() {
    super.initState();
    // Seed the draft from the route params. Riverpod forbids mutating a
    // provider while the tree is building, so defer one microtask.
    Future.microtask(() {
      if (!mounted) return;
      final notifier = ref.read(bookingDraftProvider.notifier);
      if (widget.resume && ref.read(bookingDraftProvider).doctor != null) {
        // Back into a booking already under way: nothing is reset.
        notifier.goToStep(int.tryParse(widget.step ?? '2') ?? 2);
        setState(() => _configured = true);
        return;
      }
      notifier.configure(
        step: int.tryParse(widget.step ?? '1') ?? 1,
        hospitalId: widget.hospital,
        departmentCode: widget.dept,
        doctorId: widget.doctor,
        origin: widget.origin == 'appointments'
            ? BookingOrigin.appointments
            : BookingOrigin.home,
      );
      setState(() => _configured = true);
    });
  }

  /// A doctor (and slot) named in the route are resolved once the doctor
  /// detail arrives, then handed to the draft.
  void _applyRouteDoctor(DoctorDetail detail) {
    if (_routeApplied) return;
    _routeApplied = true;
    final notifier = ref.read(bookingDraftProvider.notifier)
      ..pickDoctor(detail.card);
    final slotId = widget.slot;
    if (slotId == null) return;
    // The slot's day is unknown from the id alone: look through the
    // availability window's days as they load (bounded, cached reads).
    _findRouteSlot(detail.card.id, slotId, notifier);
  }

  Future<void> _findRouteSlot(
    String doctorId,
    String slotId,
    BookingDraftController notifier,
  ) async {
    try {
      final availability = await ref.read(
        doctorAvailabilityProvider(doctorId).future,
      );
      for (final day in availability.value.dates) {
        if (!day.hasAvailability) continue;
        final slots = await ref.read(
          doctorSlotsProvider((doctorId: doctorId, date: day.date)).future,
        );
        for (final slot in slots.value.allSlots) {
          if (slot.id == slotId) {
            if (!mounted) return;
            notifier.pickSlot(
              slot,
              date: day.date,
              sessionLabel: slots.value.sessionOf(slot)?.label,
            );
            return;
          }
        }
      }
    } catch (_) {
      // The slot could not be re-found (taken, or offline): the patient
      // picks again on step 3, which is what the empty state says.
    }
  }

  // ---- Navigation ---------------------------------------------------------

  void _leaveFlow() {
    final origin = ref.read(bookingDraftProvider).origin;
    context.go(
      origin == BookingOrigin.appointments
          ? AppRoutes.appointments
          : AppRoutes.home,
    );
  }

  void _handleBack() {
    if (ref.read(bookingDraftProvider.notifier).back()) return;
    _leaveFlow();
  }

  Future<void> _exit() async {
    if (ref.read(bookingDraftProvider).step == 1) {
      _leaveFlow();
      return;
    }
    // Once `POST /appointments` has answered, a booking exists and its slot
    // is held until the payment deadline — saying "nothing has been booked"
    // would be false.
    final booked = ref.read(bookingSubmitProvider).result?.appointment;
    final leave = await showAppConfirmDialog(
      context,
      title: booked == null ? 'Leave this booking?' : 'Leave without paying?',
      consequence: booked == null
          ? 'Your choices so far will not be saved. Nothing has been booked '
                'or charged.'
          // The hold's end from the booking itself ("by 10:31 PM").
          : 'Booking ${booked.bookingRef} is held for you and nothing has '
                'been charged. Finish the payment from Appointments '
                '${SlotLabels.payBefore(booked.bookingDeadlineAt, timezone: booked.hospitalTimezone ?? ref.read(bookingDraftProvider).hospitalTimezone)}'
                ', or it is released automatically.',
      confirmLabel: 'Leave',
      cancelLabel: booked == null ? 'Keep booking' : 'Stay',
      iconName: PhIcon.xCircle,
    );
    if (leave == true && mounted) _leaveFlow();
  }

  void _goStep(int step) =>
      ref.read(bookingDraftProvider.notifier).goToStep(step);

  Future<void> _openSlotSheet(DoctorCard doctor, {bool change = false}) async {
    final draft = ref.read(bookingDraftProvider);
    final pick = await showSlotSheet(
      context,
      doctor: doctor,
      timezone: draft.hospitalTimezone,
      initialDate: change ? draft.date : null,
      initial: change ? draft.slot : null,
    );
    if (pick == null || !mounted) return;
    final notifier = ref.read(bookingDraftProvider.notifier)
      ..pickDoctor(doctor)
      ..pickSlot(pick.slot, date: pick.date, sessionLabel: pick.sessionLabel);
    if (ref.read(bookingDraftProvider).step == 2) notifier.nextStep();
  }

  void _openDoctor(DoctorCard doctor) {
    // Record the pick before leaving, so returning from the detail screen
    // with the system back gesture keeps the doctor selected.
    ref.read(bookingDraftProvider.notifier).pickDoctor(doctor);
    context.push(AppRoutes.doctorPath(doctor.id, returnTo: 'booking'));
  }

  /// The footer's Continue / Pay.
  Future<void> _next(BookingDraft draft) async {
    final notifier = ref.read(bookingDraftProvider.notifier);
    switch (draft.step) {
      case 1:
        if (draft.departmentCode == null) return;
        notifier.nextStep();
      case 2:
        final doctor = draft.doctor;
        if (doctor == null) return;
        if (draft.slot == null) {
          await _openSlotSheet(doctor);
          return;
        }
        notifier.nextStep();
      case 3:
        if (draft.slot == null || draft.person == null) return;
        notifier.nextStep();
      default:
        await _book(draft);
    }
  }

  /// `POST /patient/appointments` (§9.1), then the payment screen.
  Future<void> _book(BookingDraft draft) async {
    final slotId = draft.slotId;
    final personId = draft.personId;
    final doctorId = draft.doctorId;
    if (slotId == null || personId == null || doctorId == null) return;

    // Only a coupon the quote accepted is sent; a refused one fails the
    // booking (§9.1) and the quote already told the patient why.
    final quote = ref
        .read(
          feeQuoteProvider(
            FeeQuoteQuery(
              doctorId: doctorId,
              personId: personId,
              couponCode: draft.couponCode,
            ),
          ),
        )
        .valueOrNull;
    final coupon = quote?.hasValidCoupon == true ? draft.couponCode : null;

    final result = await ref
        .read(bookingSubmitProvider.notifier)
        .book(
          BookingRequest(
            slotId: slotId,
            personId: personId,
            couponCode: coupon,
            patientNotes: draft.patientNotes,
          ),
          quotedTotalPaise: quote?.totalPaise,
        );
    if (!mounted) return;
    if (result != null) {
      await context.push<void>(AppRoutes.bookingPayment);
      return;
    }
    final submit = ref.read(bookingSubmitProvider);
    final failure = submit.failure;
    if (failure == null) return;
    if (submit.slotUnavailable) {
      ref.read(bookingDraftProvider.notifier).clearSlot();
      ref.read(bookingSubmitProvider.notifier).clearFailure();
      ref.read(toastControllerProvider.notifier).show(failure.userMessage);
      return;
    }
    if (failure.apiCode == ApiErrorCodes.couponInvalid ||
        failure.apiCode == ApiErrorCodes.couponExpired ||
        failure.apiCode == ApiErrorCodes.couponMinOrder ||
        failure.apiCode == ApiErrorCodes.couponUsageCap) {
      ref.read(bookingDraftProvider.notifier).removeCoupon();
    }
    ref.read(toastControllerProvider.notifier).show(failure.userMessage);
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingDraftProvider);
    final submit = ref.watch(bookingSubmitProvider);

    // A doctor named only by id (route entry) is resolved here.
    final routeDoctorId = widget.doctor;
    if (_configured &&
        routeDoctorId != null &&
        draft.doctor == null &&
        !_routeApplied) {
      final detail = ref.watch(doctorDetailProvider(routeDoctorId)).valueOrNull;
      if (detail != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _applyRouteDoctor(detail.value),
        );
      }
    }
    // A department known only by its code (a Home service tile, a link):
    // its name from the server's list, so step 2 can say it — it read
    // "Doctors are listed per hospital." and dropped it from the strip.
    final departmentCode = draft.departmentCode;
    if (departmentCode != null && draft.departmentName == null) {
      final name = ref
          .watch(discoveryDepartmentsProvider)
          .valueOrNull
          ?.value
          .results
          .where((d) => d.code == departmentCode)
          .firstOrNull
          ?.name;
      if (name != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(bookingDraftProvider.notifier)
              .nameDepartment(code: departmentCode, name: name);
        });
      }
    }
    // The hospital's zone, once its detail is cached.
    final hospitalId = draft.hospitalId;
    if (hospitalId != null && draft.hospitalTimezone == null) {
      final detail = ref.watch(hospitalDetailProvider(hospitalId)).valueOrNull;
      if (detail != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(bookingDraftProvider.notifier)
              .setHospitalTimezone(detail.value.timezone);
        });
      }
    }

    final quoteTotal = _quoteTotal(draft);
    final blocked = switch (draft.step) {
      1 => draft.departmentCode == null,
      2 => draft.doctor == null || !draft.doctor!.canBook,
      3 => draft.slot == null || draft.person == null,
      _ => !draft.isBookable || quoteTotal == null,
    };

    return RouteArrival(
      onArrive: () {
        // Coming back from a doctor's page, a new family member or the
        // payment screen: read the lists and the price again. The draft —
        // what the patient has chosen and typed — is not touched.
        ref.invalidate(discoveryDepartmentsProvider);
        ref.invalidate(hospitalDepartmentsProvider);
        ref.invalidate(discoveryHospitalsProvider);
        ref.invalidate(hospitalDoctorsProvider);
        ref.invalidate(bookingPersonsProvider);
        ref.invalidate(feeQuoteProvider);
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleBack();
        },
        child: Scaffold(
          backgroundColor: AppColors.bgApp,
          body: SafeArea(
            bottom: false,
            child: FlowScreenEnter(
              child: Column(
                children: [
                  _Header(onBack: _handleBack, onExit: _exit),
                  BookingStepper(current: draft.step, onStepTap: _goStep),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
                      child: switch (draft.step) {
                        1 => _Step1Department(draft: draft),
                        2 => _Step2Doctor(
                          draft: draft,
                          onView: _openDoctor,
                          onBook: (d) => _openSlotSheet(d),
                        ),
                        3 => _Step3Patient(
                          draft: draft,
                          onChangeSlot: () {
                            final doctor = draft.doctor;
                            if (doctor != null) {
                              _openSlotSheet(doctor, change: true);
                            }
                          },
                          onChooseDoctor: () => _goStep(2),
                        ),
                        _ => _Step4Confirm(
                          draft: draft,
                          onBackToSlots: () => _goStep(3),
                          onRetryBooking: () => _book(draft),
                        ),
                      },
                    ),
                  ),
                  _Footer(
                    child: AppButton(
                      // After a back-out from the payment screen the booking
                      // already exists: the button resumes its payment rather
                      // than offering to book again.
                      label: draft.step != 4
                          ? 'Continue'
                          : submit.isBooked
                          ? 'Complete payment'
                          : 'Pay ${quoteTotal == null ? '' : Money.inr(quoteTotal)}'
                                .trim(),
                      fullWidth: true,
                      disabled: blocked,
                      loading: submit.isSubmitting,
                      onPressed: blocked ? null : () => _next(draft),
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

  /// The quote's total for the footer label, or null while it loads.
  int? _quoteTotal(BookingDraft draft) {
    final doctorId = draft.doctorId;
    if (draft.step != 4 || doctorId == null) return null;
    return ref
        .watch(
          feeQuoteProvider(
            FeeQuoteQuery(
              doctorId: doctorId,
              personId: draft.personId,
              couponCode: draft.couponCode,
            ),
          ),
        )
        // valueOrNull: `.value` re-throws a failed quote, which replaced the
        // whole app with a red error screen offline (BL-BOOK-034). The quote
        // card shows the failure with Retry; the footer just has no total.
        .valueOrNull
        ?.totalPaise;
  }
}

// ---- Step 1: department -----------------------------------------------------

class _Step1Department extends ConsumerWidget {
  const _Step1Department({required this.draft});

  final BookingDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hospitalId = draft.hospitalId;
    final query = ref.watch(bookingDeptQueryProvider);
    final q = query.trim().toLowerCase();

    // Two shapes, one tile: (code, name, sub).
    final AsyncValue<List<({String code, String name, String sub})>> tiles;
    CachedResult<Object?>? cache;
    if (hospitalId != null) {
      final page = ref.watch(hospitalDepartmentsProvider(hospitalId));
      cache = page.valueOrNull;
      tiles = page.whenData(
        (r) => [
          for (final HospitalDepartment d in r.value.results)
            (code: d.code, name: d.name, sub: d.description ?? 'Department'),
        ],
      );
    } else {
      final page = ref.watch(discoveryDepartmentsProvider);
      cache = page.valueOrNull;
      tiles = page.whenData(
        (r) => [
          for (final DepartmentSummary d in r.value.results)
            (
              code: d.code,
              name: d.name,
              sub: d.hospitalCount == 1
                  ? '1 hospital'
                  : '${d.hospitalCount} hospitals',
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (draft.hospitalName != null) ...[
          _ScopeStrip(
            text: 'At ${draft.hospitalName}',
            actionLabel: 'Change',
            onAction: () =>
                ref.read(bookingDraftProvider.notifier).clearHospital(),
          ),
          SizedBox(height: 12.h),
        ],
        Padding(
          padding: EdgeInsets.only(top: 4.h, bottom: 12.h),
          child: _SearchField(
            hint: 'Search departments',
            value: query,
            onChanged: (v) =>
                ref.read(bookingDeptQueryProvider.notifier).update((_) => v),
            onClear: () =>
                ref.read(bookingDeptQueryProvider.notifier).update((_) => ''),
          ),
        ),
        CacheStatusBar(
          result: cache,
          onRefresh: () => hospitalId == null
              ? ref.invalidate(discoveryDepartmentsProvider)
              : ref.invalidate(hospitalDepartmentsProvider(hospitalId)),
        ),
        tiles.when(
          loading: () => const AppSkeletonList(count: 3, tile: true),
          error: (error, _) => AppInlineError(
            failure: error.asFailure(),
            onRetry: () => hospitalId == null
                ? ref.invalidate(discoveryDepartmentsProvider)
                : ref.invalidate(hospitalDepartmentsProvider(hospitalId)),
          ),
          data: (all) {
            final depts = [
              for (final d in all)
                if (q.isEmpty || '${d.name} ${d.sub}'.toLowerCase().contains(q))
                  d,
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  depts.length == 1
                      ? '1 department'
                      : '${depts.length} departments',
                  style: AppText.poppins(
                    size: AppFontSize.sm,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: 12.h),
                if (all.isEmpty)
                  const _EmptyNote(
                    icon: PhIcon.firstAid,
                    title: 'No departments listed yet',
                    body: 'No facility is taking online bookings right now.',
                  )
                else if (depts.isEmpty)
                  _EmptyNote(
                    icon: PhIcon.magnifyingGlass,
                    title: 'No department matches that',
                    // Examples from the server's own names: "skin", "heart"
                    // and "child" were suggested but never matched — only
                    // names are searched.
                    body:
                        'Try a department name like '
                        '${[for (final d in all.take(2)) '"${d.name}"'].join(' or ')}'
                        ', or clear the search to see all ${all.length}.',
                    linkLabel: 'Clear search',
                    onLink: () => ref
                        .read(bookingDeptQueryProvider.notifier)
                        .update((_) => ''),
                  )
                else
                  _TwoColumnGrid(
                    children: [
                      for (final d in depts)
                        DepartmentCard(
                          name: d.name,
                          sub: d.sub,
                          iconName: departmentIconFor(d.code),
                          selected: draft.departmentCode == d.code,
                          onTap: () => ref
                              .read(bookingDraftProvider.notifier)
                              .pickDepartment(code: d.code, name: d.name),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---- Step 2: hospital + doctor ----------------------------------------------

class _Step2Doctor extends ConsumerWidget {
  const _Step2Doctor({
    required this.draft,
    required this.onView,
    required this.onBook,
  });

  final BookingDraft draft;
  final ValueChanged<DoctorCard> onView;
  final ValueChanged<DoctorCard> onBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hospitalId = draft.hospitalId;
    if (hospitalId == null) {
      return _HospitalPicker(draft: draft);
    }
    final query = ref.watch(bookingDoctorQueryProvider);
    final searching = query.trim().isNotEmpty;
    final doctorsQuery = HospitalDoctorsQuery(
      hospitalId: hospitalId,
      departmentCode: draft.departmentCode,
      q: searching ? query.trim() : null,
      sort: 'next_available_at',
      pageSize: 50,
    );
    final doctors = ref.watch(hospitalDoctorsProvider(doctorsQuery));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Please select the doctor'),
        SizedBox(height: 12.h),
        _ScopeStrip(
          text:
              '${draft.hospitalName ?? 'This hospital'}'
              '${draft.departmentName == null ? '' : ' · ${draft.departmentName}'}',
          actionLabel: 'Change',
          onAction: () =>
              ref.read(bookingDraftProvider.notifier).clearHospital(),
        ),
        SizedBox(height: 16.h),
        _DoctorSearchBar(
          value: query,
          onChanged: (v) =>
              ref.read(bookingDoctorQueryProvider.notifier).update((_) => v),
        ),
        SizedBox(height: 16.h),
        CacheStatusBar(
          result: doctors.valueOrNull,
          onRefresh: () =>
              ref.invalidate(hospitalDoctorsProvider(doctorsQuery)),
        ),
        doctors.when(
          loading: () => const AppSkeletonList(count: 2),
          error: (error, _) => AppInlineError(
            failure: error.asFailure(),
            onRetry: () =>
                ref.invalidate(hospitalDoctorsProvider(doctorsQuery)),
          ),
          data: (result) {
            final rows = result.value.results;
            if (rows.isEmpty) {
              return _EmptyNote(
                icon: PhIcon.magnifyingGlass,
                title: searching
                    ? 'No doctors match that search'
                    : 'No doctors in ${draft.departmentName ?? 'this department'} '
                          'here yet',
                body: searching
                    ? 'Try a name, or clear the search.'
                    : 'Pick another department or another hospital to carry '
                          'on booking.',
                linkLabel: searching ? 'Clear search' : null,
                onLink: searching
                    ? () =>
                          ref.read(bookingDoctorQueryProvider.notifier).state =
                              ''
                    : null,
                actionLabel: searching ? null : 'Choose another hospital',
                onAction: searching
                    ? null
                    : () => ref
                          .read(bookingDraftProvider.notifier)
                          .clearHospital(),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) SizedBox(height: 16.h),
                  BookingDoctorCard(
                    doctor: rows[i],
                    timezone: draft.hospitalTimezone,
                    hospitalPhone: ref
                        .watch(hospitalDetailProvider(hospitalId))
                        .valueOrNull
                        ?.value
                        .phoneE164,
                    selected: draft.doctorId == rows[i].id,
                    onView: () => onView(rows[i]),
                    onBook: () => onBook(rows[i]),
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

/// Step 2 before a hospital is known: the facilities running the chosen
/// department (`GET /patient/hospitals?department_code=`).
class _HospitalPicker extends ConsumerWidget {
  const _HospitalPicker({required this.draft});

  final BookingDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = HospitalsQuery(
      departmentCode: draft.departmentCode,
      sort: HospitalSort.nextAvailable,
      pageSize: 50,
    );
    final hospitals = ref.watch(discoveryHospitalsProvider(query));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Choose a hospital'),
        SizedBox(height: 4.h),
        Text(
          draft.departmentName == null
              ? 'Doctors are listed per hospital.'
              : 'Hospitals with a ${draft.departmentName} department.',
          style: AppText.poppins(
            size: AppFontSize.sm,
            color: AppColors.textMuted,
          ),
        ),
        SizedBox(height: 16.h),
        CacheStatusBar(
          result: hospitals.valueOrNull,
          onRefresh: () => ref.invalidate(discoveryHospitalsProvider(query)),
        ),
        hospitals.when(
          loading: () => const AppSkeletonList(count: 2),
          error: (error, _) => AppInlineError(
            failure: error.asFailure(),
            onRetry: () => ref.invalidate(discoveryHospitalsProvider(query)),
          ),
          data: (result) {
            final rows = result.value.results;
            if (rows.isEmpty) {
              return _EmptyNote(
                icon: PhIcon.firstAid,
                title: 'No hospital runs this department yet',
                body: 'Pick another department to carry on booking.',
                actionLabel: 'Choose another department',
                onAction: () =>
                    ref.read(bookingDraftProvider.notifier).goToStep(1),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) SizedBox(height: 12.h),
                  HospitalListCard(
                    hospital: rows[i],
                    highlightDepartment: draft.departmentCode,
                    onTap: () => ref
                        .read(bookingDraftProvider.notifier)
                        .pickHospital(id: rows[i].id, name: rows[i].name),
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

// ---- Step 3: patient ----------------------------------------------------------

/// Opens the family-member form and, when it pops, re-reads the persons
/// list: the form's POST already invalidated the response cache, but this
/// screen's provider stays alive underneath and would keep its old answer.
Future<void> _addFamilyMember(BuildContext context, WidgetRef ref) async {
  await context.push<void>(AppRoutes.dependantEditPath());
  ref.invalidate(bookingPersonsProvider);
}

class _Step3Patient extends ConsumerWidget {
  const _Step3Patient({
    required this.draft,
    required this.onChangeSlot,
    required this.onChooseDoctor,
  });

  final BookingDraft draft;
  final VoidCallback onChangeSlot;
  final VoidCallback onChooseDoctor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persons = ref.watch(bookingPersonsProvider);
    final selfId = ref.watch(selfPersonIdProvider);
    final doctor = draft.doctor;
    final slot = draft.slot;
    final date = draft.date;

    // Default the pick: the self person, else the only person. Never a
    // guess — with nothing to pick, the empty state asks for one.
    final rows = persons.valueOrNull ?? const <PersonSummary>[];
    if (draft.person == null && rows.isNotEmpty) {
      final self = rows.where((p) => p.isSelf || p.id == selfId).toList();
      final preferred = self.isNotEmpty
          ? self.first
          : (rows.length == 1 ? rows.first : null);
      if (preferred != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(bookingDraftProvider.notifier).pickPerson(preferred),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (doctor != null && slot != null && date != null)
          _ChosenSlotBar(
            text:
                '${SlotLabels.dayLong(date, timezone: draft.hospitalTimezone)} · '
                '${SlotLabels.time(slot.startsAt, timezone: draft.hospitalTimezone)}'
                '${draft.sessionLabel == null || draft.sessionLabel!.isEmpty ? '' : ' · ${draft.sessionLabel}'}'
                ' · ${doctor.name}',
            onChange: onChangeSlot,
          )
        else
          AppInlineEmpty(
            message: 'Pick a doctor and a time first.',
            iconName: PhIcon.clock,
            actionLabel: 'Choose a doctor',
            onAction: onChooseDoctor,
          ),
        SizedBox(height: 20.h),
        Text(
          'Appointment for',
          style: AppText.poppins(
            size: AppFontSize.body,
            weight: AppText.semibold,
            color: AppColors.textStrong,
          ),
        ),
        SizedBox(height: 12.h),
        persons.when(
          loading: () => const AppSkeletonList(count: 2, tile: true),
          error: (error, _) => AppInlineError(
            failure: error.asFailure(),
            onRetry: () => ref.invalidate(bookingPersonsProvider),
          ),
          data: (list) {
            if (list.isEmpty) {
              return AppInlineEmpty(
                message: selfId == null
                    ? 'Your account has no patient record yet, so we cannot '
                          'book "for myself". Add yourself or a family member '
                          'first.'
                    : 'No one on this account yet.',
                iconName: PhIcon.folder,
                actionLabel: 'Add a family member',
                onAction: () => _addFamilyMember(context, ref),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) SizedBox(height: 12.h),
                  PatientCard(
                    person: list[i],
                    selected: draft.personId == list[i].id,
                    onTap: () => ref
                        .read(bookingDraftProvider.notifier)
                        .pickPerson(list[i]),
                  ),
                ],
              ],
            );
          },
        ),
        SizedBox(height: 20.h),
        AppButton(
          label: 'Add family member',
          variant: AppButtonVariant.secondary,
          pill: true,
          fullWidth: true,
          leadingIcon: PhIcon.plus,
          onPressed: () => _addFamilyMember(context, ref),
        ),
        SizedBox(height: 20.h),
        _NotesField(
          value: draft.patientNotes ?? '',
          onChanged: (v) => ref.read(bookingDraftProvider.notifier).setNotes(v),
        ),
        SizedBox(height: 4.h),
      ],
    );
  }
}

// ---- Step 4: confirm --------------------------------------------------------

class _Step4Confirm extends ConsumerWidget {
  const _Step4Confirm({
    required this.draft,
    required this.onBackToSlots,
    required this.onRetryBooking,
  });

  final BookingDraft draft;
  final VoidCallback onBackToSlots;

  /// "Try Again" under a failed booking: sends the same booking again, exactly
  /// as the Pay button does. The retry reuses the attempt's Idempotency-Key
  /// (§1.8), so it cannot book the slot twice.
  final VoidCallback onRetryBooking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctor = draft.doctor;
    final slot = draft.slot;
    final date = draft.date;
    final person = draft.person;
    if (doctor == null || slot == null || date == null || person == null) {
      return AppEmptyView(
        iconName: PhIcon.clock,
        headline: 'Nothing to confirm yet',
        body: 'Pick a doctor, a time and who the visit is for first.',
        actionLabel: 'Back to time and patient',
        onAction: onBackToSlots,
      );
    }
    final quoteQuery = FeeQuoteQuery(
      doctorId: doctor.id,
      personId: person.id,
      couponCode: draft.couponCode,
    );
    final quote = ref.watch(feeQuoteProvider(quoteQuery));
    final submit = ref.watch(bookingSubmitProvider);
    // Set once `POST /appointments` answered and the patient backed out of
    // the payment screen: the booking exists, so the note says so.
    final booked = submit.result?.appointment;
    final tz = draft.hospitalTimezone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Confirm appointment'),
        SizedBox(height: 16.h),
        quote.when(
          loading: () => const AppSkeletonCard(lines: 5),
          error: (error, _) => AppInlineError(
            failure: error.asFailure(),
            onRetry: () => ref.invalidate(feeQuoteProvider(quoteQuery)),
          ),
          data: (fee) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BookingSummaryCard(
                doctor: doctor,
                doctorSub:
                    '${draft.departmentName ?? doctor.department.name} · '
                    '${draft.hospitalName ?? doctor.hospital.name}',
                rows: [
                  (label: 'Patient', value: person.fullName),
                  (
                    label: 'Department',
                    value: draft.departmentName ?? doctor.department.name,
                  ),
                  (
                    label: 'Date',
                    value: SlotLabels.dayLong(date, timezone: tz),
                  ),
                  (
                    label: 'Time',
                    value:
                        '${SlotLabels.time(slot.startsAt, timezone: tz)}'
                        '${draft.sessionLabel == null || draft.sessionLabel!.isEmpty ? '' : ' · ${draft.sessionLabel}'}',
                  ),
                  if (fee.isFollowUp)
                    (label: 'Visit', value: 'Follow-up (reduced fee)'),
                ],
                feeRows: FeeRowData.fromQuote(fee),
                totalPaise: fee.totalPaise,
              ),
              SizedBox(height: 14.h),
              CouponField(
                appliedCode: fee.hasValidCoupon ? fee.coupon!.code : null,
                discountPaise: fee.discountPaise,
                rejectionCode: fee.couponError,
                enabled: !submit.isSubmitting,
                onApply: (code) =>
                    ref.read(bookingDraftProvider.notifier).applyCoupon(code),
                onRemove: () =>
                    ref.read(bookingDraftProvider.notifier).removeCoupon(),
              ),
            ],
          ),
        ),
        if (quote.isLoading && quote.hasValue) ...[
          SizedBox(height: 8.h),
          Row(
            children: [
              const AppInlineLoader(size: 12),
              SizedBox(width: 6.w),
              Text(
                'Updating price…',
                style: AppText.poppins(
                  size: AppFontSize.xxs,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: AppColors.surfaceTint,
            borderRadius: AppRadii.md,
          ),
          child: Row(
            children: [
              AppIcon(PhIcon.clock, size: 18, color: AppColors.brand),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  booked == null
                      ? 'Your booking reference and token are issued when '
                            'you tap Pay. The slot is then held for a few '
                            'minutes while you pay — the next screen counts '
                            'them down.'
                      : 'Booking ${booked.bookingRef} is held for you. '
                            'Complete the payment '
                            '${SlotLabels.payBefore(booked.bookingDeadlineAt, timezone: booked.hospitalTimezone ?? tz)}.',
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    color: AppColors.brand,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (submit.failure != null && !submit.slotUnavailable) ...[
          SizedBox(height: 12.h),
          AppInlineError(
            failure: submit.failure!,
            onRetry: submit.failure!.isRetryable ? onRetryBooking : null,
          ),
        ],
      ],
    );
  }
}

// ---- Chrome -----------------------------------------------------------------

/// Back · "Book Appointment" (`22/700`) · ×, padded `54px 20px 12px`.
class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onExit});

  final VoidCallback onBack;
  final VoidCallback onExit;

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
              'Book Appointment',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.poppins(
                size: AppFontSize.h2,
                weight: AppText.bold,
                color: AppColors.textStrong,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Leave booking',
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onExit,
                child: SizedBox(
                  width: 46.r,
                  height: 46.r,
                  child: Center(
                    child: AppIcon(
                      PhIcon.x,
                      size: 22,
                      color: AppColors.textStrong,
                    ),
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

/// The sticky white footer: `padding 16px 20px 20px`, hairline on top.
class _Footer extends StatelessWidget {
  const _Footer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        20.w,
        16.h,
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

/// The design's `h3` over a step (`18/600`, text-primary).
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

/// "At Lakeshore Hospital · Change" — the scope the step is narrowed to.
class _ScopeStrip extends StatelessWidget {
  const _ScopeStrip({
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIcon(PhIcon.mapPin, size: 15, color: AppColors.brand),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.poppins(
              size: AppFontSize.sm,
              weight: AppText.medium,
              color: AppColors.textStrong,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: '$actionLabel, currently $text',
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
                child: Text(
                  actionLabel,
                  style: AppText.poppins(
                    size: AppFontSize.sm,
                    weight: AppText.medium,
                    color: AppColors.textLink,
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

/// The DS `Input` with a search prefix, plus the design's clear button (a
/// `28` grey disc with an ×) once there is text.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.hint,
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.centerEnd,
      children: [
        DraftText(
          value: value,
          builder: (context, controller) => AppTextField(
            hintText: hint,
            iconName: MedIcon.search,
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
          ),
        ),
        if (value.isNotEmpty)
          Positioned(
            right: 12.w,
            child: Semantics(
              button: true,
              label: 'Clear search',
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClear,
                  child: Container(
                    width: 28.r,
                    height: 28.r,
                    decoration: const BoxDecoration(
                      color: AppColors.grey100,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: AppIcon(
                        PhIcon.x,
                        size: 16,
                        color: AppColors.grey500,
                      ),
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

/// The step-2 search: a white pill with the ambient shadow, the text field
/// inside (`padding 4px 4px 4px 20px`) and a pill "Search" button on the
/// right. Filtering is a server `q` filter; the button closes the keyboard.
class _DoctorSearchBar extends StatelessWidget {
  const _DoctorSearchBar({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 4.w, 4.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.pill,
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: DraftText(
              value: value,
              builder: (context, controller) => TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: AppText.poppins(
                  size: AppFontSize.base,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search doctors..',
                  hintStyle: AppText.poppins(
                    size: AppFontSize.base,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          AppButton(
            label: 'Search',
            pill: true,
            expandHitArea: false,
            onPressed: () => FocusScope.of(context).unfocus(),
          ),
        ],
      ),
    );
  }
}

/// Step 3's chosen-slot strip: `surface-alt`, hairline border, `--radius-md`,
/// `12px 16px`; a `clock` in grey-400, the label (`13`, body) and "Change".
class _ChosenSlotBar extends StatelessWidget {
  const _ChosenSlotBar({required this.text, required this.onChange});

  final String text;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.md,
        border: Border.all(color: AppColors.borderSubtle, width: 1.w),
      ),
      child: Row(
        children: [
          AppIcon(PhIcon.clock, size: 16, color: AppColors.grey400),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: AppText.poppins(
                size: AppFontSize.sm,
                color: AppColors.textBody,
                height: 1.35,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Semantics(
            button: true,
            label: 'Change the slot',
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onChange,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: Text(
                    'Change',
                    style: AppText.poppins(
                      size: AppFontSize.sm,
                      weight: AppText.semibold,
                      color: AppColors.accentBlue,
                    ),
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

/// Optional `patient_notes` (≤ 2000, §9.1).
class _NotesField extends StatelessWidget {
  const _NotesField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DraftText(
      value: value,
      builder: (context, controller) => AppTextField(
        label: 'Notes for the doctor (optional)',
        hintText: 'Symptoms, since when, anything the doctor should know',
        controller: controller,
        maxLength: 2000,
        maxLines: 3,
        onChanged: onChanged,
      ),
    );
  }
}

/// The design's two-column tile grid (`gap 12`, rows aligned to the top).
class _TwoColumnGrid extends StatelessWidget {
  const _TwoColumnGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      if (i > 0) rows.add(SizedBox(height: 12.h));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[i]),
            SizedBox(width: 12.w),
            Expanded(
              child: i + 1 < children.length
                  ? children[i + 1]
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

/// The design's in-step empty note: a tint disc with the mark, a `16/600`
/// title, a `13` muted body, then either an accent-blue text link or a
/// secondary pill.
class _EmptyNote extends StatelessWidget {
  const _EmptyNote({
    required this.icon,
    required this.title,
    required this.body,
    this.linkLabel,
    this.onLink,
    this.actionLabel,
    this.onAction,
  });

  final String icon;
  final String title;
  final String body;
  final String? linkLabel;
  final VoidCallback? onLink;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 44.h),
      child: Column(
        children: [
          Container(
            width: 60.r,
            height: 60.r,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surfaceTint,
              shape: BoxShape.circle,
            ),
            child: AppIcon(icon, size: 28, color: AppColors.brand),
          ),
          SizedBox(height: 12.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.poppins(
              size: AppFontSize.body,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 12.h),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 250.w),
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
          if (linkLabel != null && onLink != null) ...[
            SizedBox(height: 12.h),
            Semantics(
              button: true,
              label: linkLabel,
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onLink,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Text(
                      linkLabel!,
                      style: AppText.poppins(
                        size: AppFontSize.base,
                        weight: AppText.semibold,
                        color: AppColors.accentBlue,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 16.h),
            AppButton(
              label: actionLabel!,
              variant: AppButtonVariant.secondary,
              pill: true,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
