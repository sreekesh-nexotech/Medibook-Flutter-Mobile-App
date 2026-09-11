import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_checkbox.dart';

/// The sign-up consent row: the checkbox plus the three document names as
/// **tappable inline links** (CM-02).
///
/// The audit found *"the checkbox exists, but Terms, Privacy Policy and User
/// Guidelines are not tappable and no document screen exists"* — a consent
/// control that cannot show what is being consented to. The three names are
/// now links into `/legal/:slug`, styled with [AppColors.textLink] and
/// underlined so they read as links rather than emphasis.
///
/// This widget only reports the tap; the screen navigates, so no navigation
/// logic sits below the screen layer. The document screen itself belongs to
/// the feature that owns `/legal/:slug`.
///
/// The checkbox's own tap target is padded to [AppButton.minTapHeight],
/// because the design's box is 20px (audit §3.3.8), and the whole paragraph
/// outside the links toggles it too.
class LegalConsentCheckbox extends StatefulWidget {
  const LegalConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onOpenDocument,
    this.errorText,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Called with a slug from [AppRoutes.legalSlugs] when a link is tapped.
  final void Function(String slug) onOpenDocument;

  /// The "you have to accept this" message, shown under the row.
  final String? errorText;

  final bool enabled;

  @override
  State<LegalConsentCheckbox> createState() => _LegalConsentCheckboxState();
}

class _LegalConsentCheckboxState extends State<LegalConsentCheckbox> {
  /// One recogniser per link, created once and disposed — a `TextSpan`
  /// recogniser is a real gesture object, not a callback, so it leaks if it is
  /// rebuilt on every frame.
  late final Map<String, TapGestureRecognizer> _recognisers = {
    for (final slug in AppRoutes.legalSlugs)
      slug: TapGestureRecognizer()..onTap = () => widget.onOpenDocument(slug),
  };

  @override
  void dispose() {
    for (final recogniser in _recognisers.values) {
      recogniser.dispose();
    }
    super.dispose();
  }

  void _toggle() {
    if (!widget.enabled) return;
    widget.onChanged(!widget.value);
  }

  TextSpan _link(String label, String slug) {
    return TextSpan(
      text: label,
      style:
          AppText.poppins(
            size: AppFontSize.sm,
            weight: AppText.medium,
            height: 1.45,
            color: AppColors.textLink,
          ).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: AppColors.textLink,
          ),
      recognizer: _recognisers[slug],
      semanticsLabel: '$label, opens the document',
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final bodyStyle = AppText.poppins(
      size: AppFontSize.sm,
      height: 1.45,
      color: hasError ? AppColors.danger : AppColors.textBody,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              checked: widget.value,
              enabled: widget.enabled,
              label:
                  'Accept the Terms & Conditions, Privacy Policy and '
                  'User Guidelines',
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                  child: SizedBox(
                    width: AppButton.minTapHeight.w,
                    height: AppButton.minTapHeight.h,
                    child: Center(
                      child: AppCheckbox(
                        value: widget.value,
                        error: hasError,
                        onChanged: widget.enabled ? (_) => _toggle() : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                // Tapping the sentence toggles the box; the three links take
                // their own taps first.
                onTap: _toggle,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 13.h),
                  child: Text.rich(
                    TextSpan(
                      style: bodyStyle,
                      children: [
                        const TextSpan(text: 'I agree to the '),
                        _link('Terms & Conditions', AppRoutes.legalTerms),
                        const TextSpan(text: ', '),
                        _link('Privacy Policy', AppRoutes.legalPrivacy),
                        const TextSpan(text: ', and '),
                        _link('User Guidelines', AppRoutes.legalGuidelines),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (hasError) ...[
          SizedBox(height: 4.h),
          Text(
            widget.errorText ?? '',
            style: AppText.poppins(
              size: AppFontSize.xs,
              color: AppColors.danger,
            ),
          ),
        ],
      ],
    );
  }
}
