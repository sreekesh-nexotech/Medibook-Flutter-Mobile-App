import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/theme.dart';
import '../../app/theme/typography.dart';
import 'status_style.dart';

/// The compact appointment status / token pill. Colors come from
/// [AppStatusStyle] (e.g. `AppStatusStyle.appointment(status)` or
/// `AppStatusStyle.token`). Pill, `--fs-xxs`/semibold, padding `4x10`.
class AppStatusPill extends StatelessWidget {
  const AppStatusPill({super.key, required this.label, required this.colors});

  final String label;

  /// `({Color background, Color foreground})` from [AppStatusStyle].
  final PillColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 10.w),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadii.pill,
      ),
      child: Text(
        label,
        style: AppText.poppins(
          size: AppFontSize.xxs,
          weight: AppText.semibold,
          color: colors.foreground,
        ),
      ),
    );
  }
}
