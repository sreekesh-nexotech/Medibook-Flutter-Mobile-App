import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';

/// One federated sign-in provider offered on the sign-in screen.
enum SocialProvider {
  google('G', 'Google'),
  facebook('f', 'Facebook'),
  x('X', 'X');

  const SocialProvider(this.glyph, this.label);

  /// The single character the design draws in the circle.
  final String glyph;

  /// The provider's name — the screen-reader label, and the `<Action>` in the
  /// house "stubbed" wording.
  final String label;

  /// "Sign in with Google" — what the button announces and what a stubbed
  /// toast names.
  String get actionLabel => 'Sign in with $label';
}

/// The sign-in social row: three 50px circular bordered buttons (G / f / X).
///
/// [onProviderTap] receives the [SocialProvider] that was tapped rather than a
/// bare `VoidCallback`, because the three are not interchangeable: no OAuth
/// client is configured in this build, so the screen has to say *which*
/// provider is not wired up rather than quietly land on Home as though a
/// Google sign-in had succeeded (the contract's rule on honest controls).
///
/// Each circle is a labelled button of at least 48px, so it is reachable by
/// touch and announced as "Sign in with Google" rather than "G".
class SocialRow extends StatelessWidget {
  const SocialRow({super.key, this.onProviderTap});

  final ValueChanged<SocialProvider>? onProviderTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < SocialProvider.values.length; i++) ...[
          if (i > 0) SizedBox(width: 18.w),
          _SocialButton(
            provider: SocialProvider.values[i],
            onTap: onProviderTap == null
                ? null
                : () => onProviderTap!(SocialProvider.values[i]),
          ),
        ],
      ],
    );
  }
}

/// StatefulWidget only for the local press-scale (0.94) feedback.
class _SocialButton extends StatefulWidget {
  const _SocialButton({required this.provider, this.onTap});

  final SocialProvider provider;
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
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.provider.actionLabel,
      child: ExcludeSemantics(
        child: GestureDetector(
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
                widget.provider.glyph,
                style: AppText.poppins(
                  size: 20,
                  weight: AppText.bold,
                  color: AppColors.textStrong,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
