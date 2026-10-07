import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../components/consent_row.dart';
import '../components/screen_fade_rise.dart';
import '../../application/providers/consent_form_controller.dart';

/// "One last thing" (`/onboarding/consent`) — the last step of the intro.
///
/// One required box (Terms & Conditions + Privacy Policy, both tappable into
/// `/legal/:slug`) and one optional box (hospital offers). The CTA is never
/// disabled: pressing it without the terms box — or before the two policies
/// could be loaded — shows the note that explains the block, which is
/// friendlier than a dead button.
///
/// Form state lives in [consentFormControllerProvider]; the screen only reads
/// it and navigates.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  /// One recogniser per link, created once and disposed — a `TextSpan`
  /// recogniser is a real gesture object, not a callback.
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = () => _openDocument(AppRoutes.legalTerms);
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () => _openDocument(AppRoutes.legalPrivacy);

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  ConsentFormController get _form =>
      ref.read(consentFormControllerProvider.notifier);

  void _openDocument(String slug) => context.push(
    AppRoutes.legalPath(slug, from: AppRoutes.legalFromOnboarding),
  );

  /// Back returns to the last slide; a deep link straight onto this screen
  /// has nothing to pop, so it goes to the intro instead.
  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.onboarding);
  }

  Future<void> _accept() async {
    final accepted = await _form.accept();
    if (!accepted || !mounted) return;
    context.go(AppRoutes.login);
  }

  TextSpan _link(String label, TapGestureRecognizer recogniser) => TextSpan(
    text: label,
    style: AppText.poppins(
      size: AppFontSize.base,
      weight: AppText.semibold,
      height: 1.35,
      color: AppColors.accentBlue,
    ),
    recognizer: recogniser,
    semanticsLabel: '$label, opens the document',
  );

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(consentFormControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: ScreenFadeRise(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(bottom: false, child: _Header(onBack: _back)),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Medibook holds your appointment slot and collects '
                      'payment for the hospital. We do not provide medical '
                      'advice, and we receive no reports from hospitals.',
                      style: AppText.poppins(
                        size: AppFontSize.body,
                        height: 1.5,
                        color: AppColors.textBody,
                      ),
                    ),
                    SizedBox(height: AppSpacing.x6.h),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ConsentRow(
                            value: form.agreeTerms,
                            onChanged: _form.setAgreeTerms,
                            semanticLabel:
                                'Accept the Terms & Conditions and Privacy '
                                'Policy (required)',
                            child: Text.rich(
                              TextSpan(
                                style: ConsentRow.bodyStyle(),
                                children: [
                                  const TextSpan(text: 'I agree to the '),
                                  _link('Terms & Conditions', _termsTap),
                                  const TextSpan(text: ' and '),
                                  _link('Privacy Policy', _privacyTap),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.x5.h,
                            ),
                            child: Container(
                              height: 1.h,
                              color: AppColors.borderSubtle,
                            ),
                          ),
                          ConsentRow(
                            value: form.agreeOffers,
                            onChanged: _form.setAgreeOffers,
                            semanticLabel:
                                'Send me hospital offers and health camp '
                                'updates (optional)',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Send me hospital offers and health camp '
                                  'updates.',
                                  style: ConsentRow.bodyStyle(),
                                ),
                                SizedBox(height: AppSpacing.x1.h),
                                Text(
                                  'Optional — change this later in Profile.',
                                  style: AppText.poppins(
                                    size: AppFontSize.xs,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (form.showRequiredNote) ...[
                      SizedBox(height: AppSpacing.x4.h),
                      const _FormNote('Please accept the terms to continue.'),
                    ] else if (form.showPoliciesNote) ...[
                      SizedBox(height: AppSpacing.x4.h),
                      const _FormNote(
                        'We could not load the Terms & Conditions and '
                        'Privacy Policy. Check your connection, then tap '
                        'Agree and Continue again.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _Footer(
              child: AppButton(
                label: 'Agree and Continue',
                size: AppButtonSize.lg,
                pill: true,
                fullWidth: true,
                loading: form.isBusy,
                onPressed: _accept,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Back button + left-aligned title. Design: `padding 54px 18px 12px` on the
/// 844 frame, i.e. 10px under the status bar.
class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 12.h),
      child: Row(
        children: [
          AppIconButton(
            icon: MedIcon.back,
            size: 46,
            semanticLabel: 'Back to the introduction',
            onPressed: onBack,
          ),
          SizedBox(width: AppSpacing.x1.w),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                'One last thing',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.poppins(
                  size: AppFontSize.h2,
                  weight: AppText.bold,
                  color: AppColors.textStrong,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Why the press was refused — "Please accept the terms to continue." or the
/// policies-could-not-load message. Shown only after a refused press, and
/// announced when it appears.
class _FormNote extends StatelessWidget {
  const _FormNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: AppRadii.md,
        ),
        child: Row(
          children: [
            const _AlertGlyph(),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                message,
                style: AppText.poppins(
                  size: AppFontSize.sm,
                  weight: AppText.medium,
                  height: 1.35,
                  color: AppColors.dangerText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 18px `warning-circle` (fill) mark from the design; decorative, the
/// text carries the meaning.
class _AlertGlyph extends StatelessWidget {
  const _AlertGlyph();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: AppIcon(
        PhIcon.warningCircleFill,
        size: 18,
        color: AppColors.dangerText,
      ),
    );
  }
}

/// The sticky white footer: `padding 12px 20px 20px`, hairline on top.
class _Footer extends StatelessWidget {
  const _Footer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.h),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
          child: child,
        ),
      ),
    );
  }
}
