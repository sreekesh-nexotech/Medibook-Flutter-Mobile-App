import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';

/// A toggle switch. Track `46x26` pill (`brand` on / `grey200` off); 20px white
/// knob slides `left 3 → 23` over 180ms with a subtle shadow. Stateless — the
/// slide animates as [value] flips on rebuild.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const Duration _slide = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: _slide,
        curve: Curves.easeInOut,
        width: 46.w,
        height: 26.h,
        decoration: BoxDecoration(
          color: value ? AppColors.brand : AppColors.grey200,
          borderRadius: AppRadii.pill,
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: _slide,
              curve: Curves.easeInOut,
              left: value ? 23.w : 3.w,
              top: 3.h,
              child: Container(
                width: 20.w,
                height: 20.w,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.xs,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
