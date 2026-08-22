import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';

/// The booking-flow progress stepper. 30px numbered circles joined by 2px
/// connectors. Done/active circles navy + white; pending `surfaceTint` +
/// `primary300`. A connector is navy when `n < current`, else `grey100`.
class AppStepper extends StatelessWidget {
  const AppStepper({super.key, this.steps = 4, required this.current});

  final int steps;

  /// 1-based index of the active step.
  final int current;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var n = 1; n <= steps; n++) {
      children.add(_circle(n));
      if (n < steps) {
        children.add(Expanded(child: _connector(n)));
      }
    }
    return Row(children: children);
  }

  Widget _circle(int n) {
    final done = n <= current;
    return Container(
      width: 30.w,
      height: 30.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? AppColors.brand : AppColors.surfaceTint,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$n',
        style: AppText.poppins(
          size: AppFontSize.sm,
          weight: AppText.semibold,
          color: done ? AppColors.textOnBrand : AppColors.primary300,
        ),
      ),
    );
  }

  Widget _connector(int n) {
    return Container(
      height: 2.h,
      color: n < current ? AppColors.brand : AppColors.grey100,
    );
  }
}
