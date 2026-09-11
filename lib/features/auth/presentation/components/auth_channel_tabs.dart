import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../controllers/auth_flow_draft.dart';

/// The Email / Mobile switch at the top of the sign-in (CM-04) and reset
/// (CM-06) forms.
///
/// The audit found *"login takes an email address. There is no mobile-number
/// field and no country-code control"*, and the same for the reset flow. A
/// second screen per credential would double both forms, so both screens
/// instead choose a channel and swap one field.
///
/// The control is [AppSegmentedTabs] — the pill row the app already uses for
/// Upcoming/Past and the department filters — so the choice reads as the same
/// kind of choice the rest of the app makes, and nothing new had to be
/// designed. It maps onto [ResetChannel] rather than a private enum because
/// that is the enum the flow drafts and `/verify` already speak.
class AuthChannelTabs extends StatelessWidget {
  const AuthChannelTabs({
    super.key,
    required this.value,
    required this.onChanged,
    this.caption,
    this.enabled = true,
  });

  /// The selected channel. [ResetChannel.sms] is the "Mobile" pill.
  final ResetChannel value;

  final ValueChanged<ResetChannel> onChanged;

  /// Optional line above the pills explaining the choice.
  final String? caption;

  final bool enabled;

  static const String _emailLabel = 'Email';
  static const String _mobileLabel = 'Mobile';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (caption != null) ...[
          Text(
            caption!,
            style: AppText.poppins(
              size: AppFontSize.sm,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 8.h),
        ],
        AppSegmentedTabs(
          tabs: const [_emailLabel, _mobileLabel],
          active: value == ResetChannel.sms ? _mobileLabel : _emailLabel,
          onChanged: enabled
              ? (label) => onChanged(
                  label == _mobileLabel ? ResetChannel.sms : ResetChannel.email,
                )
              : null,
        ),
      ],
    );
  }
}
