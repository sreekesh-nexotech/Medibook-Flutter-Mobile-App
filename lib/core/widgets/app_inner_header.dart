import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';
import 'app_icon.dart';
import 'app_icon_button.dart';

/// The repeated inner-screen header: a 38px back button, a centered title, and
/// an optional trailing slot (kept symmetric with a spacer so the title stays
/// centered). Top padding `12.h` (design 56 − 44 status bar), horizontal `18.w`,
/// `bgApp`. Bottom padding defaults to `14` but the prototype varies it per
/// screen (8 on the auth sub-screens, 10 on Search), so it is a parameter.
///
/// ## Touch target (audit §3.3.8)
///
/// The back button's *visual* size is still 38px, exactly as designed, but its
/// *tap target* is now [_slot] = 48px — the platform minimum. The extra 10px of
/// height is taken back out of the header's own vertical padding
/// ([_hitAreaInset] top and bottom), so **the header's overall height, the
/// title's baseline and the glyph's centre are all unchanged**: the screen
/// looks pixel-identical and the button is simply easier to hit.
class AppInnerHeader extends StatelessWidget {
  const AppInnerHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
    this.bottomGap = 14,
    this.background,
    this.backSemanticLabel,
  });

  final String title;

  /// Null → no back button (renders a spacer to keep the title centered).
  final VoidCallback? onBack;

  /// Optional right-side widget (e.g. a bell button).
  final Widget? trailing;

  /// Bottom padding under the title (design px). Prototype: 8 on Sign Up /
  /// Forgot / Verify / New Password, 10 on Search, 14 elsewhere.
  final double bottomGap;

  /// Header band color. Defaults to `bgApp`; the all-white auth sub-screens
  /// pass `AppColors.surface` (their whole page is surface in the design).
  final Color? background;

  /// What a screen reader announces for the back button. Defaults to "Back";
  /// pass something specific where it helps ("Back to Appointments").
  final String? backSemanticLabel;

  /// The design's visual size for the back glyph.
  static const double _visual = 38;

  /// The accessible tap target.
  static const double _slot = 48;

  /// Half the growth, reclaimed from the header's padding at each end so the
  /// band's total height does not change.
  static const double _hitAreaInset = (_slot - _visual) / 2;

  @override
  Widget build(BuildContext context) {
    // Clamped at zero: a caller passing a very small bottomGap still gets a
    // valid (if uncompensated) header rather than negative padding.
    final topPad = (12 - _hitAreaInset).clamp(0.0, double.infinity);
    final bottomPad = (bottomGap - _hitAreaInset).clamp(0.0, double.infinity);

    return Container(
      color: background ?? AppColors.bgApp,
      padding: EdgeInsets.fromLTRB(18.w, topPad.h, 18.w, bottomPad.h),
      child: Row(
        children: [
          SizedBox(
            width: _slot.w,
            height: _slot.w,
            child: onBack == null
                ? null
                : AppIconButton(
                    icon: MedIcon.back,
                    size: _visual,
                    hitAreaSize: _slot,
                    semanticLabel: backSemanticLabel,
                    onPressed: onBack,
                  ),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.poppins(
                  size: AppFontSize.h3,
                  weight: AppText.bold,
                  color: AppColors.textStrong,
                ),
              ),
            ),
          ),
          SizedBox(
            width: _slot.w,
            height: _slot.w,
            child: trailing == null
                ? null
                : Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
  }
}
