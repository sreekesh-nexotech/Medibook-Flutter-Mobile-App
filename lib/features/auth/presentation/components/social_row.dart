import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:medibook/app/config/constants.dart';
import 'package:medibook/app/theme/colors.dart';
import 'package:medibook/app/theme/typography.dart';

/// The Login social-sign-in row: three 50px circular bordered buttons (G / f /
/// X). All three fire the same [onTap] (the prototype routes every provider to
/// the same demo login). Not a design-system component — kept local to Auth.
class SocialRow extends StatelessWidget {
  const SocialRow({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SocialButton(label: 'G', onTap: onTap),
        SizedBox(width: 18.w),
        _SocialButton(label: 'f', onTap: onTap),
        SizedBox(width: 18.w),
        _SocialButton(label: 'X', onTap: onTap),
      ],
    );
  }
}

/// StatefulWidget only for the local press-scale (0.94) feedback.
class _SocialButton extends StatefulWidget {
  const _SocialButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) {
        _set(false);
        widget.onTap?.call();
      },
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: AppConstants.pressScale,
        child: Container(
          // Equal width/height keeps a true circle across scale factors.
          width: 50.w,
          height: 50.w,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 1.w),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: AppText.poppins(
              size: 20,
              weight: AppText.bold,
              color: AppColors.textStrong,
            ),
          ),
        ),
      ),
    );
  }
}
