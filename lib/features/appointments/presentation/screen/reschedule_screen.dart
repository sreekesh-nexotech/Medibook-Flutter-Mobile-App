import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/slot.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_date_picker_sheet.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_not_found_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../domain/policies/cancellation_policy.dart';
import '../components/date_chip.dart';
import '../components/enter_animations.dart';
import '../components/policy_notice.dart';
import '../components/time_chip.dart';
import '../controllers/appointment_actions_controller.dart';
import '../controllers/appointments_controller.dart';
import '../controllers/reschedule_controller.dart';

/// `/reschedule/:id` (pushed).
///
/// Shows the current appointment, the reschedule policy (CM-26 — the cut-off,
/// which side of it the patient is on and what it means for their money), a
/// day row backed by the real month calendar, and the doctor's actual slots for
/// the chosen day — including its fully-booked and closed states.
///
/// Every value is typed: the confirmed change is a [DateTime] taken from the
/// chosen [Slot], never a re-parsed `"Today" / "10:30 AM"` pair (audit §3.8.3).
class RescheduleScreen extends ConsumerWidget {
  const RescheduleScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = ref.watch(appointmentRowProvider(id));

    if (row == null) {
      return AppNotFoundView(
        headline: 'Appointment not found',
        body: 'There is nothing left to reschedule.',
        attemptedPath: AppRoutes.reschedulePath(id),
        iconName: MedIcon.calendar,
        onGoBack: context.canPop() ? () => context.pop() : null,
        onGoHome: () => context.go(AppRoutes.appointments),
      );
    }

    final policy = ref.watch(
      appointmentPolicyProvider((
        appointmentId: id,
        change: AppointmentChange.reschedule,
      )),
    );
    final selection = ref.watch(rescheduleControllerProvider(id));
    final busy = ref.watch(
      appointmentActionsProvider(id).select((state) => state.busy),
    );
    final daySlots = ref.watch(
      slotsForProvider((
        doctorId: row.appointment.doctorId,
        day: selection.day,
      )),
    );
    final allowed = policy?.isAllowed ?? false;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: ScreenEnter(
          child: Column(
            children: [
              AppInnerHeader(
                title: 'Reschedule',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _currentCard(row),
                      if (policy != null) PolicyNotice(outcome: policy),
                      if (allowed) ...[
                        _sectionTitle('Select new date'),
                        _dayRow(context, ref, row, selection),
                        _sectionTitle('Select new time'),
                        _slotGrid(context, ref, daySlots, selection),
                      ],
                    ],
                  ),
                ),
              ),
              _footer(context, ref, row, selection, policy, busy: busy),
            ],
          ),
        ),
      ),
    );
  }

  /// The appointment as it stands, so the patient can compare.
  Widget _currentCard(AppointmentRow row) {
    return AppCard(
      padding: EdgeInsets.all(14.w),
      child: Row(
        children: [
          AppAvatar(
            name: row.doctor.name,
            imageAsset: row.doctor.imageAsset,
            size: 44,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.doctor.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    size: 14,
                    weight: AppText.semibold,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Currently: ${row.appointment.dateTimeLabel}',
                  style: AppText.poppins(size: 12, color: AppColors.textMuted),
                ),
                SizedBox(height: 1.h),
                Text(
                  row.hospitalName,
                  style: AppText.poppins(size: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Five day chips plus a "Pick a date" button opening the real month
  /// calendar — five fixed days was audit CM-12.
  Widget _dayRow(
    BuildContext context,
    WidgetRef ref,
    AppointmentRow row,
    RescheduleSelection selection,
  ) {
    final chips = AppDates.upcomingChips();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(bottom: 4.h),
          child: Row(
            children: [
              for (var i = 0; i < chips.length; i++) ...[
                if (i > 0) SizedBox(width: 10.w),
                ApptDateChip(
                  dow: chips[i].dow,
                  day: chips[i].day,
                  selected: AppDates.isSameDay(chips[i].date, selection.day),
                  onTap: () => ref
                      .read(rescheduleControllerProvider(id).notifier)
                      .pickDay(chips[i].date),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 10.h),
        AppButton(
          label: 'Pick another date',
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.sm,
          leadingIcon: MedIcon.calendar,
          onPressed: () => _pickDay(context, ref, row, selection),
        ),
      ],
    );
  }

  /// The doctor's real slots for the selected day, with their unavailable and
  /// fully-booked states rather than a blank grid.
  Widget _slotGrid(
    BuildContext context,
    WidgetRef ref,
    DaySlots daySlots,
    RescheduleSelection selection,
  ) {
    if (daySlots.isUnavailable) {
      return AppInlineEmpty(
        message:
            '${_dayLabel(selection.day)} — the doctor is not consulting on '
            'this day. Pick another date.',
        iconName: MedIcon.calendar,
        actionLabel: 'Pick another date',
        onAction: () => _openCalendar(context, ref, selection),
      );
    }
    if (daySlots.isFullyBooked) {
      return AppInlineEmpty(
        message:
            '${_dayLabel(selection.day)} is fully booked — every slot is '
            'taken. Pick another date.',
        iconName: MedIcon.clock,
        actionLabel: 'Pick another date',
        onAction: () => _openCalendar(context, ref, selection),
      );
    }

    return Wrap(
      spacing: 10.w,
      runSpacing: 10.h,
      children: [
        for (final slot in daySlots.slots)
          Semantics(
            button: slot.isSelectable,
            enabled: slot.isSelectable,
            selected: selection.slot?.start == slot.start,
            label: slot.isSelectable
                ? slot.timeLabel
                : '${slot.timeLabel} — ${slot.status.label}',
            child: ExcludeSemantics(
              child: Opacity(
                // An unavailable slot stays visible (so the day reads as a real
                // calendar) but is plainly not pickable.
                opacity: slot.isSelectable ? 1 : 0.45,
                child: ApptTimeChip(
                  label: slot.timeLabel,
                  selected: selection.slot?.start == slot.start,
                  onTap: slot.isSelectable
                      ? () => ref
                            .read(rescheduleControllerProvider(id).notifier)
                            .pickSlot(slot)
                      : () {},
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: EdgeInsets.only(top: 20.h, bottom: 12.h),
      child: Text(
        text,
        style: AppText.poppins(
          size: 16,
          weight: AppText.semibold,
          color: AppColors.textStrong,
        ),
      ),
    );
  }

  Widget _footer(
    BuildContext context,
    WidgetRef ref,
    AppointmentRow row,
    RescheduleSelection selection,
    PolicyOutcome? policy, {
    required bool busy,
  }) {
    final allowed = policy?.isAllowed ?? false;
    final ready = allowed && selection.isComplete;
    final reason = !allowed
        ? (policy?.blockedReason ?? 'This appointment can no longer be moved.')
        : 'Pick a new time slot first';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x5.w,
        14.h,
        AppSpacing.x5.w,
        22.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.w),
        ),
      ),
      child: Column(
        children: [
          if (selection.scheduledAt != null && allowed) ...[
            Text(
              'Moving to ${AppDates.dayAndTime(selection.scheduledAt!)}',
              textAlign: TextAlign.center,
              style: AppText.poppins(
                size: 12,
                weight: AppText.medium,
                color: AppColors.textBody,
              ),
            ),
            SizedBox(height: 10.h),
          ],
          AppButton(
            label: 'Confirm New Time',
            fullWidth: true,
            disabled: !ready,
            loading: busy,
            semanticLabel: ready
                ? 'Confirm the new appointment time'
                : 'Confirm new time — unavailable, $reason',
            onPressed: ready
                ? () => _confirm(context, ref, row, selection, policy!)
                : null,
          ),
        ],
      ),
    );
  }

  /// Open the month calendar, with each day resolved against the doctor's real
  /// availability so closed and fully-booked days are visible before tapping.
  Future<void> _pickDay(
    BuildContext context,
    WidgetRef ref,
    AppointmentRow row,
    RescheduleSelection selection,
  ) async {
    final doctorId = row.appointment.doctorId;
    final today = AppDates.startOfDay(DateTime.now());
    final picked = await showAppDatePickerSheet(
      context,
      title: 'Select a new date',
      initialDay: selection.day,
      firstDay: today,
      lastDay: AppDates.addMonths(today, 3),
      availability: (day) {
        if (day.isBefore(today)) return DayAvailability.past;
        final slots = ref.read(
          slotsForProvider((doctorId: doctorId, day: day)),
        );
        if (slots.isUnavailable) return DayAvailability.unavailable;
        if (slots.isFullyBooked) return DayAvailability.fullyBooked;
        return DayAvailability.available;
      },
    );
    if (picked == null) return;
    ref.read(rescheduleControllerProvider(id).notifier).pickDay(picked);
  }

  /// [_pickDay] without the row — used from the empty states, which already
  /// know the appointment is valid.
  Future<void> _openCalendar(
    BuildContext context,
    WidgetRef ref,
    RescheduleSelection selection,
  ) async {
    final row = ref.read(appointmentRowProvider(id));
    if (row == null) return;
    await _pickDay(context, ref, row, selection);
  }

  /// Confirm the move, then report exactly what the controller did.
  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    AppointmentRow row,
    RescheduleSelection selection,
    PolicyOutcome policy,
  ) async {
    final scheduledAt = selection.scheduledAt;
    if (scheduledAt == null) return;

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Move to ${AppDates.dayAndTime(scheduledAt)}?',
      // CM-26: the policy consequence, in full, before the change happens.
      consequence: policy.consequence,
      confirmLabel: 'Move appointment',
      cancelLabel: 'Keep current time',
      isDestructive: false,
      iconName: MedIcon.calendar,
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref
        .read(appointmentActionsProvider(id).notifier)
        .reschedule(outcome: policy, scheduledAt: scheduledAt);
    if (!context.mounted) return;

    ref.read(toastControllerProvider.notifier).show(result.message);
    // Only leave the screen when the move actually happened.
    if (result.ok) context.go(AppRoutes.appointmentDetailPath(id));
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.appointmentDetailPath(id));
    }
  }
}

/// "Today" / "12 Aug 2026" for a day — the empty-state sentences name the day
/// they are talking about, so "fully booked" is never ambiguous.
String _dayLabel(DateTime day) => AppDates.relativeDay(day);
