import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_stepper.dart';

/// The design's step block under the booking header: the DS `Stepper`
/// (1-2-3-4) with the four labels beneath (`12`, `mt 8`), the active one in
/// brand `600`, the others muted; steps already passed are tappable so the
/// patient can jump back. Padded `8px 20px 16px` inside a reserved `84px`.
class BookingStepper extends StatelessWidget {
  const BookingStepper({
    super.key,
    required this.current,
    required this.onStepTap,
  });

  static const List<String> labels = [
    'Department',
    'Doctor & time',
    'Patient',
    'Payment',
  ];

  /// 1-based active step.
  final int current;

  /// Called with a 1-based step that is *before* [current].
  final ValueChanged<int> onStepTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84.h,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppStepper(current: current),
            SizedBox(height: 8.h),
            Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: _StepLabel(
                      label: labels[i],
                      active: i + 1 == current,
                      onTap: i + 1 < current ? () => onStepTap(i + 1) : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.label, required this.active, this.onTap});

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.poppins(
        size: AppFontSize.xs,
        weight: active ? AppText.semibold : AppText.regular,
        color: active ? AppColors.brand : AppColors.textMuted,
      ),
    );
    if (onTap == null) return text;
    return Semantics(
      button: true,
      label: 'Back to $label',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: text,
        ),
      ),
    );
  }
}
