import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/slot.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import 'slot_chip.dart';

/// The "Select time" panel: a day's published slots, or an honest explanation
/// of why there are none (CM-12).
///
/// The audit's finding was "six fixed times, always shown as available", so
/// there was no unavailable state to render and no reason for the screen to
/// explain anything. Three things follow from real slot data:
///
/// 1. Unbookable slots are **shown**, struck through or greyed, so a busy
///    doctor reads as busy rather than as a broken screen.
/// 2. A day with nothing bookable gets an [AppEmptyView] whose body says
///    *which* of the three reasons applies (closed / full / gone by) and
///    always carries a way out — the calendar.
/// 3. A count of what is actually open sits above the grid, because "4 slots"
///    is the fastest way to see that the day is worth looking at.
class SlotPanel extends StatelessWidget {
  const SlotPanel({
    super.key,
    required this.slots,
    required this.selected,
    required this.onSlotSelected,
    required this.onOpenCalendar,
    this.emptyMessage,
  });

  final DaySlots slots;

  /// The slot in the draft, or null.
  final Slot? selected;

  /// Only ever called with an [SlotStatus.available] slot.
  final ValueChanged<Slot> onSlotSelected;

  /// Opens the month calendar — the way out of an empty day.
  final VoidCallback onOpenCalendar;

  /// Why this day has nothing bookable, from `slotEmptyMessage`. Null when it
  /// does.
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (slots.isUnavailable) {
      return AppEmptyView(
        iconName: MedIcon.calendar,
        headline: 'No consulting hours this day',
        body: emptyMessage,
        actionLabel: 'Pick another date',
        onAction: onOpenCalendar,
        padding: EdgeInsets.symmetric(vertical: AppSpacing.x5.h),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _CountRow(slots: slots),
        SizedBox(height: AppSpacing.x3.h),
        Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
          children: [
            for (final slot in slots.slots)
              SlotChipTile(
                slot: slot,
                selected: selected != null && selected!.start == slot.start,
                onTap: () => onSlotSelected(slot),
              ),
          ],
        ),
        if (emptyMessage != null) ...[
          SizedBox(height: AppSpacing.x4.h),
          _FullDayNotice(
            message: emptyMessage!,
            onOpenCalendar: onOpenCalendar,
          ),
        ],
      ],
    );
  }
}

/// "4 slots open" / "Fully booked" — [DaySlots.summaryLabel] with the state's
/// dot, matching the day strip's vocabulary.
class _CountRow extends StatelessWidget {
  const _CountRow({required this.slots});

  final DaySlots slots;

  @override
  Widget build(BuildContext context) {
    final open = slots.hasAvailability;
    return Row(
      children: [
        Container(
          width: 7.w,
          height: 7.w,
          decoration: BoxDecoration(
            color: open ? AppColors.success : AppColors.danger,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: AppSpacing.x2.w),
        Expanded(
          child: Text(
            open ? '${slots.summaryLabel} open' : slots.summaryLabel,
            style: AppText.poppins(
              size: AppFontSize.xs,
              weight: AppText.medium,
              color: open ? AppColors.successText : AppColors.dangerText,
            ),
          ),
        ),
      ],
    );
  }
}

/// The inset note under a published-but-full day. Not an [AppEmptyView],
/// because the grid above it is worth reading: the patient can see the doctor
/// is booked solid, which is different information from "nothing here".
class _FullDayNotice extends StatelessWidget {
  const _FullDayNotice({required this.message, required this.onOpenCalendar});

  final String message;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    return AppInlineEmpty(
      message: message,
      iconName: MedIcon.calendar,
      actionLabel: 'Pick another date',
      onAction: onOpenCalendar,
      margin: EdgeInsets.zero,
    );
  }
}
