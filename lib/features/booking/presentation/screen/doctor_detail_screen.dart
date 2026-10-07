import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/route_arrival.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/states/app_error_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../application/providers/availability_providers.dart';
import '../../application/providers/booking_draft_provider.dart';
import '../../application/providers/discovery_providers.dart';
import '../booking_routes.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/slots.dart';
import '../components/cache_status_bar.dart';
import '../components/date_strip.dart';
import '../components/file_image.dart';
import '../components/flow_screen_enter.dart';
import '../components/slot_grid.dart';
import '../components/slot_labels.dart';

/// One doctor, laid out as the design's Doctor Details screen: the photo,
/// name / qualifications / hospital, the figures, "Select Time" (the
/// availability date strip + the slots by session), "About doctor", and the
/// footer that books the chosen time. Route: `/doctor/:id`.
///
/// Data: `GET /patient/doctors/{id}` (§7.8), `…/availability` (§8.1) and
/// `…/slots?date=` (§8.2). Times render in the hospital's zone.
///
/// [returnTo] says where we came from: `booking` (mid-flow — the footer reads
/// "Continue with …" and hands the pick back to the draft), otherwise the
/// footer reads "Book …" and opens the flow at step 3 with the pick set.
class DoctorDetailScreen extends ConsumerStatefulWidget {
  const DoctorDetailScreen({
    super.key,
    required this.id,
    this.returnTo = 'home',
  });

  final String id;

  /// `booking` | `search` | `hospital` | `home`.
  final String returnTo;

  @override
  ConsumerState<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends ConsumerState<DoctorDetailScreen> {
  // Transient picks for this visit; the draft owns the real state.
  String? _date;
  Slot? _slot;
  String? _sessionLabel;

  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(widget.returnTo == 'search' ? AppRoutes.search : AppRoutes.home);
  }

  /// The footer. Mid-flow: hand the pick to the draft and return to the flow
  /// at step 3. Otherwise open the flow at step 3 with the pick in the route.
  void _book(DoctorCard doctor, String date, Slot slot, String? timezone) {
    if (widget.returnTo == 'booking') {
      final notifier = ref.read(bookingDraftProvider.notifier)
        ..pickDoctor(doctor)
        ..setHospitalTimezone(timezone)
        ..pickSlot(slot, date: date, sessionLabel: _sessionLabel);
      if (ref.read(bookingDraftProvider).step < 3) notifier.goToStep(3);
      _back();
      return;
    }
    context.go(
      BookingRoutes.booking(
        step: 3,
        dept: doctor.department.code,
        doctor: doctor.id,
        slot: slot.id,
        hospital: doctor.hospital.id,
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(doctorDetailProvider(widget.id));
    ref.invalidate(doctorAvailabilityProvider(widget.id));
    await ref.read(doctorDetailProvider(widget.id).future);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(doctorDetailProvider(widget.id));
    // The hospital's zone and phone come from its detail; while it loads (or
    // when signed out and offline) the platform default zone applies.
    final hospitalId = detail.valueOrNull?.value.card.hospital.id;
    final hospital = hospitalId == null
        ? null
        : ref.watch(hospitalDetailProvider(hospitalId)).valueOrNull?.value;
    final timezone = hospital?.timezone;

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
                          ? 'This doctor is not listed'
                          : null,
                      onRetry: _refresh,
                      secondaryLabel: 'Go back',
                      onSecondary: _back,
                    ),
                    data: (result) =>
                        _body(result.value, timezone, hospital?.phoneE164),
                  ),
                ),
                _footer(detail.valueOrNull?.value, timezone),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _footer(DoctorDetail? doctor, String? timezone) {
    final slot = _slot;
    final date = _date;
    final canBook = doctor != null && doctor.card.canBook;
    final cta = doctor == null
        ? 'Loading…'
        : !canBook
        ? 'Not bookable online'
        : slot == null || date == null
        ? 'Pick a time to continue'
        : '${widget.returnTo == 'booking' ? 'Continue with' : 'Book'} '
              '${SlotLabels.time(slot.startsAt, timezone: timezone)} '
              '${SlotLabels.dayInSentence(date, timezone: timezone)}';
    return _Footer(
      child: AppButton(
        label: cta,
        fullWidth: true,
        pill: true,
        disabled: !canBook || slot == null || date == null,
        onPressed: !canBook || slot == null || date == null
            ? null
            : () => _book(doctor.card, date, slot, timezone),
      ),
    );
  }

  Widget _body(DoctorDetail doctor, String? timezone, String? hospitalPhone) {
    final card = doctor.card;
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
                CacheStatusBar(
                  result: ref
                      .watch(doctorDetailProvider(widget.id))
                      .valueOrNull,
                  onRefresh: _refresh,
                ),
                _Photo(doctor: card),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.name,
                  style: AppText.poppins(
                    size: AppFontSize.h2,
                    weight: AppText.bold,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  [?card.qualification, card.specialityLabel].join(' · '),
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    color: AppColors.textMuted,
                  ),
                ),
                Container(
                  height: 1.h,
                  margin: EdgeInsets.symmetric(vertical: 16.h),
                  color: AppColors.borderSubtle,
                ),
                Text(
                  '${card.hospital.label}'
                  '${doctor.room == null ? '' : ' · Room ${doctor.room}'}',
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: 24.h),
                _Stats(doctor: doctor),
                SizedBox(height: 24.h),
                Text(
                  'Select Time',
                  style: AppText.poppins(
                    size: AppFontSize.title,
                    weight: AppText.semibold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
                if (!card.canBook)
                  Text(
                    card.status == DoctorStatus.onLeave
                        ? 'This doctor is on leave and not taking bookings.'
                        // The number from the hospital's detail, which
                        // "Call the hospital" used to leave out.
                        : 'This doctor does not take online bookings. Call '
                              'the hospital'
                              '${hospitalPhone == null ? '' : ' on $hospitalPhone'}'
                              ' to book.',
                    style: AppText.poppins(
                      size: AppFontSize.sm,
                      color: AppColors.textMuted,
                    ),
                  )
                else
                  _Availability(
                    doctorId: card.id,
                    timezone: timezone,
                    date: _date,
                    slot: _slot,
                    onDate: (date) => setState(() {
                      _date = date;
                      _slot = null;
                      _sessionLabel = null;
                    }),
                    onSlot: (slot, session, date) => setState(() {
                      _date = date;
                      _slot = slot;
                      _sessionLabel = session.label;
                    }),
                  ),
                SizedBox(height: 24.h),
                Text(
                  'About doctor',
                  style: AppText.poppins(
                    size: AppFontSize.title,
                    weight: AppText.semibold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  doctor.bio ??
                      '${card.name} has not added a profile yet.'
                          '${card.experienceLabel == null ? '' : ' ${card.experienceLabel} of experience.'}',
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    color: AppColors.textBody,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'Consultation ${Money.inr(card.consultationFeePaise)}'
                  '${card.followUpFeePaise == null ? '' : ' · Follow-up ${Money.inr(card.followUpFeePaise!)}'}'
                  ' · ${doctor.slotLengthMin}-minute slots',
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
    );
  }
}

/// The date strip and the slots for the chosen day, from §8.1 and §8.2.
class _Availability extends ConsumerWidget {
  const _Availability({
    required this.doctorId,
    required this.timezone,
    required this.date,
    required this.slot,
    required this.onDate,
    required this.onSlot,
  });

  final String doctorId;
  final String? timezone;
  final String? date;
  final Slot? slot;
  final ValueChanged<String> onDate;
  final void Function(Slot slot, SlotSession session, String date) onSlot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(doctorAvailabilityProvider(doctorId));
    return availability.when(
      loading: () => const AppSkeletonList(count: 2, tile: true),
      error: (error, _) => AppInlineError(
        failure: error.asFailure(),
        onRetry: () => ref.invalidate(doctorAvailabilityProvider(doctorId)),
      ),
      data: (result) {
        final days = result.value.dates;
        final effectiveDate =
            date ??
            result.value.firstAvailable?.date ??
            (days.isEmpty ? null : days.first.date);
        if (effectiveDate == null) {
          return Text(
            'No sessions are published in the booking window.',
            style: AppText.poppins(
              size: AppFontSize.sm,
              color: AppColors.textMuted,
            ),
          );
        }
        final slots = ref.watch(
          doctorSlotsProvider((doctorId: doctorId, date: effectiveDate)),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DateStrip(
              days: days,
              selectedDate: effectiveDate,
              timezone: timezone,
              onSelect: (day) => onDate(day.date),
            ),
            SizedBox(height: 16.h),
            slots.when(
              loading: () => const AppSkeletonList(count: 1, tile: true),
              error: (error, _) => AppInlineError(
                failure: error.asFailure(),
                onRetry: () => ref.invalidate(
                  doctorSlotsProvider((
                    doctorId: doctorId,
                    date: effectiveDate,
                  )),
                ),
              ),
              data: (slotResult) {
                final day = slotResult.value;
                return SlotGrid(
                  sessions: day.sessions,
                  selected: slot,
                  // The grid names its own zone (§8.2); the hospital
                  // detail's is the fallback.
                  timezone: day.timezone ?? timezone,
                  emptyMessage: day.isFullyBooked
                      ? 'Every slot on this day is taken. Pick another day.'
                      : 'The doctor does not consult on this day.',
                  onPick: (s, session) => onSlot(s, session, effectiveDate),
                  onUnavailable: (s) => ref
                      .read(toastControllerProvider.notifier)
                      .show(SlotLabels.unavailableMessage(s.state)),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ---- Chrome -----------------------------------------------------------------

/// Back · "Doctor Details" (`13/500`, muted, `.02em`) · a 46px spacer.
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
              'Doctor Details',
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

/// The `250` hero (photo cropped high, `50% 22%`), or tinted initials.
class _Photo extends StatelessWidget {
  const _Photo({required this.doctor});

  final DoctorCard doctor;

  @override
  Widget build(BuildContext context) {
    final initials = doctor.name
        .replaceAll(RegExp(r'^Dr\.?\s+'), '')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return ClipRRect(
      borderRadius: AppRadii.lg,
      child: SizedBox(
        height: 250.h,
        width: double.infinity,
        child: AppFileImage(
          fileId: doctor.photoFileId,
          alignment: const Alignment(0, -0.56),
          fallback: ColoredBox(
            color: AppColors.surfaceTint,
            child: Center(
              child: Text(
                initials,
                style: AppText.poppins(
                  size: AppFontSize.h1,
                  weight: AppText.bold,
                  color: AppColors.brand,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The figures the backend publishes: experience · rating · reviews · fee.
class _Stats extends StatelessWidget {
  const _Stats({required this.doctor});

  final DoctorDetail doctor;

  @override
  Widget build(BuildContext context) {
    final card = doctor.card;
    final stats = <({String icon, String value, String label})>[
      (
        icon: PhIcon.firstAid,
        // The server's figure as it is; "9+" claimed more than its 9.
        value: card.experienceYears == null ? '–' : '${card.experienceYears}',
        label: 'years',
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
        icon: MedIcon.bag,
        value: Money.inr(card.consultationFeePaise),
        label: 'consultation',
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    stats[i].value,
                    style: AppText.poppins(
                      size: AppFontSize.body,
                      weight: AppText.bold,
                      color: AppColors.textPrimary,
                    ),
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
