import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:medibook/app/config/constants.dart';
import 'package:medibook/app/theme/colors.dart';
import 'package:medibook/app/theme/typography.dart';
import 'package:medibook/core/widgets/app_icon.dart';

/// The Login brand mark: a 52px navy rounded square holding the `hospital`
/// glyph, with the "Medibook" wordmark below. Centered; the caller owns the
/// margin beneath it.
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          // Square so it renders as a square regardless of scale factors.
          width: 52.w,
          height: 52.w,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(AppRadius.lg.r),
          ),
          alignment: Alignment.center,
          child: AppIcon(
            MedIcon.hospital,
            size: 28,
            color: AppColors.textOnBrand,
          ),
        ),
        SizedBox(height: 10.h),
        Text(
          'Medibook',
          style: AppText.poppins(
            size: 22,
            weight: AppText.bold,
            color: AppColors.brand,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
