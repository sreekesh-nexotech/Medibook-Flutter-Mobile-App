import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_date_picker_sheet.dart';
import '../../../../core/widgets/app_icon.dart';

/// The booking flow's quick day picker, plus the door to the full month
/// calendar (CM-12).
///
/// This replaces the five hardcoded chips that were "always shown as
/// available". Every chip here is a real day carrying its real state from
/// [availabilityOf], drawn with the same dot vocabulary as
/// [AppMonthCalendar]'s legend so the strip and the sheet agree:
///
/// * green dot — bookable slots left
/// * red dot — published but full
/// * no dot — the doctor does not consult (Sunday, leave)
///
/// A full or closed day is still **selectable** on purpose: tapping it shows
/// the slot panel's explanation of *why* there is nothing, which is more use
/// than a chip that silently refuses the tap. Past days are not selectable.
///
/// The trailing chip opens [showAppDatePickerSheet], so anything beyond the
/// next week is reachable — the old row could not be scrolled past day five.
class BookingDayStrip extends StatelessWidget {
  const BookingDayStrip({
    super.key,
    required this.days,
    required this.selected,
    required this.availabilityOf,
    required this.onDaySelected,
    required this.onOpenCalendar,
  });

  /// The days to offer, in order. Usually `AppDates.daysFrom(today, 7)`.
  final List<DateTime> days;

  /// The chosen day, or null when none is chosen yet.
  final DateTime? selected;

  /// Per-day state — see `controllers/slot_availability.dart`.
  final DayAvailability Function(DateTime day) availabilityOf;

  final ValueChanged<DateTime> onDaySelected;

  /// Opens the month calendar.
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final day in days) ...[
                _DayChip(
                  day: day,
                  availability: availabilityOf(day),
                  selected:
                      selected != null && AppDates.isSameDay(selected!, day),
                  onTap: () => onDaySelected(day),
                ),
                SizedBox(width: 10.w),
              ],
              _CalendarChip(onTap: onOpenCalendar),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.x3.h),
        const _DotLegend(),
      ],
    );
  }
}

/// One day in the strip: weekday over day-of-month over the availability dot.
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.availability,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final DayAvailability availability;
  final bool selected;
  final VoidCallback onTap;

  bool get _selectable => availability != DayAvailability.past;

  @override
  Widget build(BuildContext context) {
    final isToday = AppDates.isToday(day);
    final Color background;
    final Color foreground;
    if (selected) {
      background = AppColors.brand;
      foreground = AppColors.textOnBrand;
    } else if (!_selectable) {
      background = AppColors.surfaceAlt;
      foreground = AppColors.textMuted;
    } else {
      background = AppColors.surface;
      foreground = AppColors.textBody;
    }

    final Color? dot = switch (availability) {
      DayAvailability.available =>
        selected ? AppColors.textOnBrand : AppColors.success,
      DayAvailability.fullyBooked => AppColors.danger,
      DayAvailability.unavailable => null,
      DayAvailability.past => null,
    };

    return Semantics(
      button: _selectable,
      enabled: _selectable,
      selected: selected,
      label: isToday
          ? 'Today, ${AppDates.dayMonth(day)}'
          : AppDates.dayMonthYear(day),
      hint: switch (availability) {
        DayAvailability.available => 'Slots available',
        DayAvailability.fullyBooked => 'Fully booked',
        DayAvailability.unavailable => 'Doctor not consulting',
        DayAvailability.past => 'Past',
      },
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _selectable ? onTap : null,
          child: Container(
            constraints: BoxConstraints(minWidth: 58.w),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: background,
              borderRadius: AppRadii.md,
              border: Border.all(
                color: selected ? AppColors.brand : AppColors.border,
                width: 1.w,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // "Today", else the short weekday ("Mon"). Derived from the
                  // one date formatter rather than a second table of names.
                  isToday ? 'Today' : AppDates.weekdayLong(day).substring(0, 3),
                  style: AppText.poppins(
                    size: AppFontSize.xxs,
                    weight: AppText.medium,
                    color: foreground.withValues(alpha: 0.85),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${day.day}',
                  style: AppText.poppins(
                    size: 15,
                    weight: AppText.semibold,
                    color: foreground,
                  ),
                ),
                SizedBox(height: 4.h),
                // The dot slot is always reserved, so a day without one does
                // not sit 4px taller than its neighbours.
                SizedBox(
                  height: 5.h,
                  child: dot == null
                      ? null
                      : Container(
                          width: 5.w,
                          height: 5.w,
                          decoration: BoxDecoration(
                            color: dot,
                            shape: BoxShape.circle,
                          ),
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

/// The chip that opens the month calendar.
class _CalendarChip extends StatelessWidget {
  const _CalendarChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open the calendar to pick another date',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.surfaceTint,
              borderRadius: AppRadii.md,
              border: Border.all(color: AppColors.surfaceTint, width: 1.w),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(MedIcon.calendar, size: 20, color: AppColors.brand),
                SizedBox(height: 4.h),
                Text(
                  'All dates',
                  style: AppText.poppins(
                    size: AppFontSize.xxs,
                    weight: AppText.medium,
                    color: AppColors.brand,
                  ),
                ),
                SizedBox(height: 5.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The key for the strip's dots. Same three states, same colours and same
/// wording as the calendar sheet's legend.
class _DotLegend extends StatelessWidget {
  const _DotLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.x4.w,
      runSpacing: AppSpacing.x1.h,
      children: const [
        _LegendDot(color: AppColors.success, label: 'Available'),
        _LegendDot(color: AppColors.danger, label: 'Fully booked'),
        _LegendDot(color: null, label: 'Not available'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  /// Null renders the hollow marker used for "not available".
  final Color? color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7.w,
          height: 7.w,
          decoration: BoxDecoration(
            color: color ?? Colors.transparent,
            shape: BoxShape.circle,
            border: color == null
                ? Border.all(color: AppColors.grey200, width: 1.w)
                : null,
          ),
        ),
        SizedBox(width: 5.w),
        Text(
          label,
          style: AppText.poppins(
            size: AppFontSize.xxs,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
