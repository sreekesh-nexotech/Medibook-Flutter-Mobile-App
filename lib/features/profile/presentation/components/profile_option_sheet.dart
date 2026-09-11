import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';

/// One row of [showProfileOptionSheet].
@immutable
class ProfileOption<T> {
  const ProfileOption({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;

  /// A quiet second line — "Self · cannot be changed", "Most common".
  final String? subtitle;
}

/// A single-choice picker sheet for the short, fixed option lists these forms
/// use: gender, blood group, relation, an insurance provider.
///
/// Rows rather than a native dropdown, because the lists are short and a 48px
/// row is a reliable touch target where a dropdown item is not. The current
/// value is both ticked and announced as selected, so the state is not
/// colour-only.
///
/// Returns the chosen value, or null when the sheet was dismissed — so a
/// caller must treat null as "unchanged", never as a clear.
Future<T?> showProfileOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<ProfileOption<T>> options,
  T? selected,
}) {
  return showAppSheet<T>(
    context,
    title: title,
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < options.length; i++)
          _OptionRow<T>(
            option: options[i],
            isSelected: options[i].value == selected,
            showDivider: i < options.length - 1,
            onTap: () => Navigator.of(sheetContext).pop(options[i].value),
          ),
      ],
    ),
  );
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.isSelected,
    required this.showDivider,
    required this.onTap,
  });

  final ProfileOption<T> option;
  final bool isSelected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: option.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: AppButton.minTapHeight.h),
            padding: EdgeInsets.symmetric(vertical: AppSpacing.x3.h),
            decoration: showDivider
                ? BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.borderSubtle,
                        width: 1.w,
                      ),
                    ),
                  )
                : null,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.label,
                        style: AppText.poppins(
                          size: AppFontSize.body,
                          weight: isSelected
                              ? AppText.semibold
                              : AppText.regular,
                          color: isSelected
                              ? AppColors.brand
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (option.subtitle != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          option.subtitle!,
                          style: AppText.poppins(
                            size: AppFontSize.xs,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected) ...[
                  SizedBox(width: AppSpacing.x3.w),
                  const SelectedTick(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The brand tick that marks a chosen row, a selected policy or a primary
/// contact. Painted rather than an [AppIcon] because the icon set has no
/// check glyph — `AppCheckbox` paints the same path the same way.
class SelectedTick extends StatelessWidget {
  const SelectedTick({super.key, this.size = 22, this.color});

  /// Diameter of the filled circle, in design px.
  final double size;

  /// Circle fill; defaults to the brand navy.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.r,
      height: size.r,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color ?? AppColors.brand,
        shape: BoxShape.circle,
      ),
      child: CustomPaint(
        size: Size(size.r * 0.55, size.r * 0.55),
        painter: _TickPainter(color: AppColors.textOnBrand, strokeWidth: 2.w),
      ),
    );
  }
}

/// `M5 13l4 4L19 7`, authored in a 24x24 box.
class _TickPainter extends CustomPainter {
  _TickPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(5 * s, 13 * s)
      ..lineTo(9 * s, 17 * s)
      ..lineTo(19 * s, 7 * s);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
