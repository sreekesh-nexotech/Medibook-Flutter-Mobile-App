import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';

/// A labelled radio. `20x20` circle, 1.5px border (brand when [selected], else
/// grey300), 10px brand dot. Tapping reports selection via [onChanged].
class AppRadio extends StatelessWidget {
  const AppRadio({
    super.key,
    required this.selected,
    this.onChanged,
    this.label,
  });

  final bool selected;

  /// Fires `true` when the row is tapped (a radio tap selects it).
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: 20.w,
      height: 20.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.brand : AppColors.grey300,
          width: 1.5.w,
        ),
      ),
      child: selected
          ? Container(
              width: 10.w,
              height: 10.w,
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(true),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          circle,
          if (label != null) ...[
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                label!,
                style: AppText.poppins(
                  size: AppFontSize.sm,
                  height: 1.45,
                  color: AppColors.textBody,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
