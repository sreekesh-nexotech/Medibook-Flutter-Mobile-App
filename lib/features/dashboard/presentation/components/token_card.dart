import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';

/// Home "Your Token" card — shown only when there is an upcoming appointment.
/// Left label in accent blue, right pill showing the token. Tapping opens the
/// appointment's detail (the screen wires [onTap]).
class TokenCard extends StatelessWidget {
  const TokenCard({super.key, required this.token, this.onTap});

  /// Token label, e.g. "A-25".
  final String token;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(18.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Your Token',
            style: AppText.poppins(
              size: 18,
              weight: AppText.bold,
              color: AppColors.accentBlue,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: AppRadii.pill,
            ),
            child: Text(
              token,
              style: AppText.poppins(
                size: 16,
                weight: AppText.bold,
                color: AppColors.textOnBrand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
