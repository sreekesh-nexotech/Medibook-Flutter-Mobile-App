import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import 'app_icon.dart';

/// The navy circle with a white confirmation tick — the "done" mark on
/// Booking Success (84/42) and the onboarding Ready screen (88/44).
///
/// The tick is the design's Phosphor `check` (bold) glyph. Decorative:
/// callers put the meaning in the headline text, so this excludes itself
/// from semantics.
class AppCheckBadge extends StatelessWidget {
  const AppCheckBadge({super.key, this.size = 84, this.checkSize = 42});

  /// Circle diameter, in design px.
  final double size;

  /// Tick bounding box, in design px.
  final double checkSize;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size.w,
        height: size.w,
        decoration: const BoxDecoration(
          color: AppColors.brand,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: AppIcon(
          PhIcon.checkBold,
          size: checkSize,
          color: AppColors.textOnBrand,
        ),
      ),
    );
  }
}
