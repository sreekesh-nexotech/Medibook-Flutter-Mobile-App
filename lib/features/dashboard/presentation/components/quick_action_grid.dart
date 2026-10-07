import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';

/// One tile in a [QuickActionGrid]: an icon glyph over a label, tappable.
class QuickAction {
  const QuickAction({
    required this.iconName,
    required this.label,
    required this.onTap,
    this.caption,
  });

  /// [PhIcon] / [DeptIcon] name for the tile mark.
  final String iconName;
  final String label;
  final VoidCallback onTap;

  /// A muted line under the label ("2 hospitals"), or null.
  final String? caption;
}

/// The design's three-column tile grid — used by both "Quick Booking" and
/// "Available Services" on Home. `gap 12` both ways; any count wraps into
/// rows of three, the last row padded so tiles keep their width.
///
/// Each tile is a `Card` (16 padding, `--radius-lg`, `--shadow-sm`) holding a
/// centred column (`gap 12`, `padding 4px 0`): a `30` brand-coloured mark over
/// a `13/500` text-primary label.
class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key, required this.actions});

  final List<QuickAction> actions;

  static const int _columns = 3;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < actions.length; start += _columns) {
      final row = <Widget>[];
      for (var i = 0; i < _columns; i++) {
        if (i > 0) row.add(SizedBox(width: 12.w));
        final index = start + i;
        row.add(
          Expanded(
            child: index < actions.length
                ? _Tile(action: actions[index])
                : const SizedBox.shrink(),
          ),
        );
      }
      if (rows.isNotEmpty) rows.add(SizedBox(height: 12.h));
      // Stretch inside an intrinsic-height row, so the three tiles share the
      // tallest label's height like grid cells do.
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: row,
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: action.onTap,
      // The design's 16px card padding, narrowed at the sides so a one-word
      // label ("Appointment") stays on one line in a 109px tile — the browser
      // lets it spill into the padding; Flutter would break the word.
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 16.h),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(action.iconName, size: 30, color: AppColors.brand),
            SizedBox(height: 12.h),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: AppText.poppins(
                size: AppFontSize.sm,
                weight: AppText.medium,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
            if (action.caption != null) ...[
              SizedBox(height: 2.h),
              Text(
                action.caption!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.poppins(
                  size: AppFontSize.xs,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
