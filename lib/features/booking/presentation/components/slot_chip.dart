import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/slot.dart';

/// Booking "Select time" chip, one per published slot (CM-12).
///
/// The old `TimeChipTile` rendered a display string with exactly two states,
/// selected and not, because the data had nothing else in it. A real slot has
/// four:
///
/// | [SlotStatus] | Reads as                                              |
/// |--------------|-------------------------------------------------------|
/// | `available`  | white chip, hairline border — tappable; brand when picked |
/// | `booked`     | inset fill, struck-through time — someone has it       |
/// | `blocked`    | inset fill, muted time, "Unavailable" caption          |
/// | `past`       | inset fill, muted time, no caption — the hour has gone |
///
/// Unbookable slots are **shown, not hidden**: a doctor with two free times at
/// 4pm reads as a busy doctor, whereas a grid with two chips in it reads as a
/// broken screen. Each chip is a labelled semantics node carrying the reason,
/// so the state is not conveyed by colour alone.
///
/// No fixed height — the chip grows with the OS text scale (to 1.3x) instead
/// of clipping the time.
class SlotChipTile extends StatelessWidget {
  const SlotChipTile({
    super.key,
    required this.slot,
    required this.selected,
    this.onTap,
  });

  final Slot slot;
  final bool selected;

  /// Only called for an [SlotStatus.available] slot.
  final VoidCallback? onTap;

  bool get _selectable => slot.isSelectable;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    final Color borderColor;

    if (selected && _selectable) {
      background = AppColors.brand;
      foreground = AppColors.textOnBrand;
      borderColor = AppColors.brand;
    } else if (_selectable) {
      background = AppColors.surface;
      foreground = AppColors.textBody;
      borderColor = AppColors.border;
    } else {
      background = AppColors.surfaceAlt;
      foreground = AppColors.textMuted;
      borderColor = AppColors.borderSubtle;
    }

    final struck = slot.status == SlotStatus.booked;

    return Semantics(
      button: _selectable,
      enabled: _selectable,
      selected: selected && _selectable,
      label: slot.timeLabel,
      hint: _selectable
          ? (selected ? 'Selected' : 'Available')
          : slot.status.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _selectable ? onTap : null,
          child: Container(
            constraints: BoxConstraints(minHeight: 44.h),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              border: Border.all(color: borderColor, width: 1.w),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  slot.timeLabel,
                  style: AppText.poppins(
                    size: 13,
                    weight: AppText.medium,
                    color: foreground,
                  ).copyWith(
                    decoration: struck ? TextDecoration.lineThrough : null,
                    decorationColor: foreground,
                  ),
                ),
                if (slot.status == SlotStatus.blocked) ...[
                  SizedBox(height: 2.h),
                  Text(
                    slot.status.label,
                    style: AppText.poppins(
                      size: AppFontSize.xxs,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
