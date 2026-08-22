import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:medibook/app/theme/colors.dart';
import 'package:medibook/app/theme/theme.dart';
import 'package:medibook/app/theme/typography.dart';

/// A single 60×60 OTP digit box, repeated four times on the Verify Code screen
/// (Screen Build Guide rule 8 — extract the repeated piece). The owning screen
/// holds the [controller] + [focusNode] and drives auto-advance from
/// [onChanged]; [hasError] paints the red 1.5px border.
class OtpBox extends StatelessWidget {
  const OtpBox({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.hasError = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    // 1px default / 1.5px strong — the design's --border-width tokens.
    final border = OutlineInputBorder(
      borderRadius: AppRadii.md,
      borderSide: BorderSide(
        color: hasError ? AppColors.danger : AppColors.border,
        width: hasError ? 1.5.w : 1.w,
      ),
    );
    return SizedBox(
      width: 60.w,
      height: 60.h,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        cursorColor: AppColors.brand,
        style: AppText.poppins(
          size: 24,
          weight: AppText.semibold,
          color: AppColors.textStrong,
        ),
        decoration: InputDecoration(
          counterText: '',
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceAlt,
          contentPadding: EdgeInsets.zero,
          enabledBorder: border,
          border: border,
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadii.md,
            borderSide: BorderSide(
              color: hasError ? AppColors.danger : AppColors.brand,
              width: 1.5.w,
            ),
          ),
        ),
      ),
    );
  }
}
