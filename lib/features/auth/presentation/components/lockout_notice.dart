import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_countdown.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../application/states/auth_state.dart';

/// The sign-in attempt budget, made visible (CM-05).
///
/// The audit's finding was *"no lockout message, no cooldown, no 'too many
/// attempts' state"* — the five-attempt rule existed underneath and the form
/// simply never mentioned it, so the fifth wrong password looked identical to
/// the first and then the form stopped working for no stated reason.
///
/// This renders whatever the [AuthState] currently says, in three escalating
/// steps, and nothing at all before the first failure:
///
/// | State | What is shown |
/// |---|---|
/// | no failures yet | nothing |
/// | 2+ attempts left | amber: how many are left |
/// | last attempt | red: what happens next, named |
/// | locked out | red: a live `mm:ss` [AppCountdown] to [AuthState.lockedUntil] |
///
/// The countdown is deadline-driven, so a backgrounded app cannot sit out its
/// cooldown, and [onExpired] fires once when it reaches zero — that is where
/// the screen calls `clearLockoutIfExpired()` and the form re-enables itself
/// without a restart.
///
/// Nothing here has a fixed height: at 1.3× OS text scaling the box grows
/// instead of clipping the sentence that explains the lockout.
class LockoutNotice extends StatelessWidget {
  const LockoutNotice({super.key, required this.state, this.onExpired});

  /// The live auth state — `failedAttempts`, `lockedUntil` and the getters
  /// derived from them.
  final AuthState state;

  /// Called once when the cooldown reaches zero.
  final VoidCallback? onExpired;

  /// Whether this widget will render anything for [state] — so a caller can
  /// decide about the gap below it without duplicating the three conditions.
  ///
  /// Every branch below needs at least one failed attempt, so this is the one
  /// question worth asking.
  static bool showsFor(AuthState state) => state.failedAttempts > 0;

  /// The cooldown in words ("60 seconds"), for the copy that warns about it.
  static String get _cooldownLabel {
    final seconds = AppConstants.loginLockoutCooldown.inSeconds;
    return '$seconds ${seconds == 1 ? 'second' : 'seconds'}';
  }

  @override
  Widget build(BuildContext context) {
    final lockedUntil = state.lockedUntil;
    if (state.isLockedOut && lockedUntil != null) {
      return _NoticeBox(
        tone: _NoticeTone.danger,
        iconName: MedIcon.clock,
        headline: 'Too many failed attempts',
        body: Text.rich(
          TextSpan(
            style: _bodyStyle(_NoticeTone.danger),
            children: [
              const TextSpan(text: 'Sign-in is paused for your security. '),
              const TextSpan(text: 'Try again in '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: AppCountdown(
                  deadline: lockedUntil,
                  onExpired: onExpired,
                  style: _bodyStyle(
                    _NoticeTone.danger,
                  ).copyWith(fontWeight: AppText.semibold),
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
      );
    }

    if (state.isLastAttempt) {
      return _NoticeBox(
        tone: _NoticeTone.danger,
        iconName: MedIcon.closeCircle,
        headline: 'One attempt left',
        body: Text(
          'The next wrong password pauses sign-in for $_cooldownLabel. '
          'Use "Forgot password?" if you are not sure.',
          style: _bodyStyle(_NoticeTone.danger),
        ),
      );
    }

    final remaining = state.attemptsRemaining;
    if (state.failedAttempts > 0 && remaining > 1) {
      return _NoticeBox(
        tone: _NoticeTone.warning,
        iconName: MedIcon.closeCircle,
        // Deliberately not "that did not match" — the rejected credential is
        // already reported in its own error box, and saying it twice is
        // louder, not clearer. This box's job is the budget.
        headline: 'Sign-in attempts',
        body: Text(
          '$remaining attempts left before sign-in is paused for '
          '$_cooldownLabel.',
          style: _bodyStyle(_NoticeTone.warning),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  static TextStyle _bodyStyle(_NoticeTone tone) => AppText.poppins(
    size: AppFontSize.sm,
    height: 1.45,
    color: tone == _NoticeTone.danger
        ? AppColors.dangerText
        : AppColors.textPrimary,
  );
}

/// How loud the notice is. Mirrors `AppBannerTone`'s two used tones, but this
/// box carries a headline and a rich body, which that bar does not.
enum _NoticeTone { warning, danger }

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({
    required this.tone,
    required this.iconName,
    required this.headline,
    required this.body,
  });

  final _NoticeTone tone;
  final String iconName;
  final String headline;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      _NoticeTone.danger => (AppColors.dangerSoft, AppColors.dangerText),
      _NoticeTone.warning => (AppColors.warningSoft, AppColors.textPrimary),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.x4.w,
          vertical: AppSpacing.x3.h,
        ),
        decoration: BoxDecoration(color: background, borderRadius: AppRadii.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: AppIcon(iconName, size: 16, color: foreground),
            ),
            SizedBox(width: AppSpacing.x3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    headline,
                    style: AppText.poppins(
                      size: AppFontSize.sm,
                      weight: AppText.semibold,
                      color: foreground,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  body,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
