import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_checkbox.dart';

/// One row of the onboarding consent card: a checkbox and its sentence.
///
/// The whole row is the tap target, and the box itself sits inside a 44px
/// target of its own so a thumb landing on the box registers exactly once
/// (the inner detector wins, so the row does not toggle it straight back).
///
/// ## The 44px box in a 16px-padded card
///
/// The design pulls the box's target 11px out into the card padding on three
/// sides (`margin: -11px 0 -11px -11px`) so the *visible* 20px box lines up
/// with the card's 16px inset while the target stays a full 44px. Flutter
/// cannot hit-test outside a widget's bounds, so the target is laid out as a
/// 33×22 slot and an [OverflowBox] paints and hit-tests the 44×44 target
/// hanging 11px above and left of it — same geometry, same paint.
class ConsentRow extends StatelessWidget {
  const ConsentRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    required this.child,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// What a screen reader announces for the whole row.
  final String semanticLabel;

  /// The sentence (and any helper line) beside the box.
  final Widget child;

  /// The body style the consent sentences share: 14px, 1.35 line-height.
  static TextStyle bodyStyle() => AppText.poppins(
    size: AppFontSize.base,
    height: 1.35,
    color: AppColors.textBody,
  );

  /// The accessible target around the 20px box.
  static const double _target = 44;

  /// How far the target hangs out of the row on the top and left.
  static const double _overhang = 11;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: semanticLabel,
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: _target.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: (_target - _overhang).w,
                  height: (_target - 2 * _overhang).h,
                  child: OverflowBox(
                    // Right- and centre-aligned in the slot, which places the
                    // 44px child at (-11, -11) — see the class doc.
                    alignment: const Alignment(1, 0),
                    minWidth: _target.w,
                    maxWidth: _target.w,
                    minHeight: _target.h,
                    maxHeight: _target.h,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(!value),
                      child: Center(child: AppCheckbox(value: value)),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
