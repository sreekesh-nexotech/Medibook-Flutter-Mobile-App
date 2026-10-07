import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/availability.dart';
import '../../domain/entities/hospital_clock.dart';

/// The availability date strip (§8.1): one chip per day of the booking
/// window, day-of-week over day-of-month. Days without a session are muted
/// and not selectable; full days are marked; the chosen day is brand.
///
/// Presentation only — the days come from `GET …/availability`, so the strip
/// can never offer a day the backend would refuse.
class DateStrip extends StatelessWidget {
  const DateStrip({
    super.key,
    required this.days,
    required this.selectedDate,
    required this.onSelect,
    this.timezone,
  });

  final List<AvailabilityDay> days;

  /// `YYYY-MM-DD`.
  final String? selectedDate;
  final ValueChanged<AvailabilityDay> onSelect;
  final String? timezone;

  @override
  Widget build(BuildContext context) {
    final today = HospitalClock.today(timezone: timezone);
    return SizedBox(
      height: 64.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: days.length,
        separatorBuilder: (_, _) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final day = days[index];
          final parsed = HospitalClock.parseDate(day.date);
          final dow = day.date == today
              ? 'Today'
              : parsed == null
              ? ''
              : AppDates.weekdayLong(parsed).substring(0, 3);
          return _DayChip(
            dow: dow,
            day: parsed?.day.toString() ?? day.date,
            selected: day.date == selectedDate,
            enabled: !day.isUnavailable,
            full: day.isFull,
            onTap: day.isUnavailable ? null : () => onSelect(day),
          );
        },
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.dow,
    required this.day,
    required this.selected,
    required this.enabled,
    required this.full,
    this.onTap,
  });

  final String dow;
  final String day;
  final bool selected;
  final bool enabled;
  final bool full;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? AppColors.textOnBrand
        : enabled
        ? AppColors.textBody
        : AppColors.textInactive;
    return Semantics(
      button: enabled,
      selected: selected,
      label:
          '$dow $day${full ? ', fully booked' : ''}'
          '${enabled ? '' : ', not available'}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 56.w,
            padding: EdgeInsets.symmetric(vertical: 8.h),
            decoration: BoxDecoration(
              color: selected ? AppColors.brand : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              border: Border.all(
                color: selected ? AppColors.brand : AppColors.border,
                width: 1.w,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    size: 11,
                    weight: AppText.medium,
                    color: fg.withValues(alpha: 0.85),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  day,
                  style:
                      AppText.poppins(
                        size: 15,
                        weight: AppText.semibold,
                        color: fg,
                      ).copyWith(
                        decoration: full && !selected
                            ? TextDecoration.lineThrough
                            : null,
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
