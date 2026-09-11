import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/config/constants.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';
import '../utils/date_utils.dart';
import 'app_bottom_sheet.dart';
import 'app_icon.dart';
import 'app_icon_button.dart';

/// How a day should be rendered in [AppMonthCalendar].
enum DayAvailability {
  /// Selectable.
  available,

  /// Published, but nothing left to book — greyed with a dot, and distinctly
  /// *not* the same as [unavailable] (CM-12).
  fullyBooked,

  /// No sessions that day (Sunday, leave). Greyed, no dot.
  unavailable,

  /// Before today. Greyed and never selectable.
  past,
}

/// Resolves a day's availability. Supplied by the caller, usually from
/// `slotsForProvider` — see `DaySlots.isFullyBooked` / `isUnavailable`.
typedef DayAvailabilityResolver = DayAvailability Function(DateTime day);

/// Shows the month-calendar sheet and resolves to the chosen day, or null when
/// dismissed.
///
/// CM-12 needs a calendar and the app had none — the booking flow offered only
/// a 5-day chip row, so nothing further out could be booked and the
/// "unavailable day" and "fully booked day" states had nowhere to appear.
///
/// Deliberately **not** `showDatePicker`: the Material default brings its own
/// typography, its own blue and its own OK/Cancel chrome, none of which is in
/// this design system, and it cannot render a third "fully booked" state at
/// all.
///
/// ```dart
/// final day = await showAppDatePickerSheet(
///   context,
///   initialDay: selected,
///   firstDay: DateTime.now(),
///   lastDay: DateTime.now().add(const Duration(days: 60)),
///   availability: (day) {
///     final slots = ref.read(slotsForProvider((doctorId: id, day: day)));
///     if (slots.isUnavailable) return DayAvailability.unavailable;
///     if (slots.isFullyBooked) return DayAvailability.fullyBooked;
///     return DayAvailability.available;
///   },
/// );
/// ```
Future<DateTime?> showAppDatePickerSheet(
  BuildContext context, {
  DateTime? initialDay,
  DateTime? firstDay,
  DateTime? lastDay,
  DayAvailabilityResolver? availability,
  String title = 'Select a date',
}) {
  return showAppSheet<DateTime>(
    context,
    title: title,
    builder: (sheetContext) => AppMonthCalendar(
      initialDay: initialDay,
      firstDay: firstDay,
      lastDay: lastDay,
      availability: availability,
      onDaySelected: (day) => Navigator.of(sheetContext).pop(day),
    ),
  );
}

/// A real month calendar: a 7-column grid with month navigation, weekday
/// headers, disabled/unavailable days and a selected state.
///
/// Design-system styled throughout — Poppins, `brand` for the selected day,
/// `surfaceTint` for today, `textMuted` for out-of-range days, pill-shaped day
/// cells, every dimension `.w`/`.h`/`.sp`-scaled. Each day cell is a 44px tap
/// target inside a 7-across grid, and each is a labelled, selectable
/// semantics node, so the grid is navigable with a screen reader.
class AppMonthCalendar extends StatefulWidget {
  const AppMonthCalendar({
    super.key,
    this.initialDay,
    this.firstDay,
    this.lastDay,
    this.availability,
    this.onDaySelected,
    this.showLegend = true,
  });

  /// Pre-selected day; also decides which month opens.
  final DateTime? initialDay;

  /// Earliest selectable day. Defaults to today.
  final DateTime? firstDay;

  /// Latest selectable day. Defaults to 90 days out.
  final DateTime? lastDay;

  /// Per-day availability. Null → every in-range day is selectable.
  final DayAvailabilityResolver? availability;

  /// Fires when a selectable day is tapped.
  final ValueChanged<DateTime>? onDaySelected;

  /// Whether to show the "Available / Fully booked / Unavailable" key. Worth
  /// keeping: three shades of grey are not self-explanatory.
  final bool showLegend;

  @override
  State<AppMonthCalendar> createState() => _AppMonthCalendarState();
}

class _AppMonthCalendarState extends State<AppMonthCalendar> {
  late DateTime _visibleMonth;
  DateTime? _selected;

  /// Monday-first, matching the Indian convention the design follows.
  static const List<String> _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  DateTime get _firstDay =>
      AppDates.startOfDay(widget.firstDay ?? DateTime.now());

  DateTime get _lastDay => AppDates.startOfDay(
    widget.lastDay ?? DateTime.now().add(const Duration(days: 90)),
  );

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDay == null
        ? null
        : AppDates.startOfDay(widget.initialDay!);
    _selected = initial;
    _visibleMonth = DateTime(
      (initial ?? _firstDay).year,
      (initial ?? _firstDay).month,
    );
  }

  bool get _canGoBack =>
      _visibleMonth.isAfter(DateTime(_firstDay.year, _firstDay.month));

  bool get _canGoForward =>
      _visibleMonth.isBefore(DateTime(_lastDay.year, _lastDay.month));

  void _shiftMonth(int months) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + months,
      );
    });
  }

  DayAvailability _availabilityOf(DateTime day) {
    if (day.isBefore(_firstDay)) return DayAvailability.past;
    if (day.isAfter(_lastDay)) return DayAvailability.unavailable;
    return widget.availability?.call(day) ?? DayAvailability.available;
  }

  void _select(DateTime day) {
    setState(() => _selected = day);
    widget.onDaySelected?.call(day);
  }

  @override
  Widget build(BuildContext context) {
    final days = AppDates.daysInMonth(_visibleMonth);
    // Monday-first leading blanks so the 1st lands under its real weekday.
    final leadingBlanks = DateUtilsLocal.mondayFirstWeekday(days.first);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ---- Month navigation ----
        Row(
          children: [
            AppIconButton(
              icon: MedIcon.back,
              size: 36,
              semanticLabel: 'Previous month',
              onPressed: _canGoBack ? () => _shiftMonth(-1) : null,
            ),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  AppDates.monthYear(_visibleMonth),
                  textAlign: TextAlign.center,
                  style: AppText.poppins(
                    size: AppFontSize.title,
                    weight: AppText.semibold,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
            ),
            // The back glyph mirrored — the icon set has no forward arrow.
            Transform.flip(
              flipX: true,
              child: AppIconButton(
                icon: MedIcon.back,
                size: 36,
                semanticLabel: 'Next month',
                onPressed: _canGoForward ? () => _shiftMonth(1) : null,
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.x3.h),

        // ---- Weekday headers ----
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppText.poppins(
                      size: AppFontSize.xs,
                      weight: AppText.medium,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: AppSpacing.x2.h),

        // ---- Day grid ----
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4.h,
            crossAxisSpacing: 4.w,
            // Slightly taller than square, so the 44px tap target fits with
            // the availability dot beneath the numeral.
            childAspectRatio: 0.92,
          ),
          itemCount: leadingBlanks + days.length,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = days[index - leadingBlanks];
            return _DayCell(
              day: day,
              availability: _availabilityOf(day),
              isSelected:
                  _selected != null && AppDates.isSameDay(_selected!, day),
              isToday: AppDates.isToday(day),
              onTap: () => _select(day),
            );
          },
        ),

        if (widget.showLegend) ...[
          SizedBox(height: AppSpacing.x4.h),
          const _CalendarLegend(),
        ],
      ],
    );
  }
}

/// One day in the grid.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.availability,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final DayAvailability availability;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  bool get _selectable => availability == DayAvailability.available;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    if (isSelected) {
      background = AppColors.brand;
      foreground = AppColors.textOnBrand;
    } else if (!_selectable) {
      background = Colors.transparent;
      foreground = AppColors.textMuted;
    } else if (isToday) {
      background = AppColors.surfaceTint;
      foreground = AppColors.brand;
    } else {
      background = Colors.transparent;
      foreground = AppColors.textPrimary;
    }

    // The dot below the numeral is what separates "fully booked" from "not
    // consulting" — a greyed day with no explanation reads as a bug.
    final Color? dotColor = switch (availability) {
      DayAvailability.available =>
        isSelected ? AppColors.textOnBrand : AppColors.success,
      DayAvailability.fullyBooked => AppColors.danger,
      DayAvailability.unavailable => null,
      DayAvailability.past => null,
    };

    return Semantics(
      button: _selectable,
      enabled: _selectable,
      selected: isSelected,
      label: AppDates.dayMonthYear(day),
      hint: switch (availability) {
        DayAvailability.available => 'Available',
        DayAvailability.fullyBooked => 'Fully booked',
        DayAvailability.unavailable => 'Not available',
        DayAvailability.past => 'Past',
      },
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _selectable ? onTap : null,
          child: Center(
            child: Container(
              width: 40.w,
              height: 40.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: AppText.poppins(
                      size: AppFontSize.base,
                      weight: isSelected || isToday
                          ? AppText.semibold
                          : AppText.regular,
                      color: foreground,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  // The slot is always reserved, so numerals do not shift
                  // between a day with a dot and one without.
                  SizedBox(
                    height: 4.h,
                    child: dotColor == null
                        ? null
                        : Container(
                            width: 4.w,
                            height: 4.w,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
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

/// The key for the three day states.
class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.x4.w,
      runSpacing: AppSpacing.x2.h,
      children: const [
        _LegendItem(color: AppColors.success, label: 'Available'),
        _LegendItem(color: AppColors.danger, label: 'Fully booked'),
        _LegendItem(color: null, label: 'Not available'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  /// Null renders the hollow marker used for "not available".
  final Color? color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(
            color: color ?? Colors.transparent,
            shape: BoxShape.circle,
            border: color == null
                ? Border.all(color: AppColors.grey200, width: 1.w)
                : null,
          ),
        ),
        SizedBox(width: 6.w),
        Text(
          label,
          style: AppText.poppins(
            size: AppFontSize.xs,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
