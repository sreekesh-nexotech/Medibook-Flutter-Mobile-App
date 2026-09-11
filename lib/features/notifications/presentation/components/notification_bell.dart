import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/stores/notifications_store.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';

/// The notification bell, with the live unread count on it (CM-41).
///
/// Reads [unreadNotificationCountProvider] itself rather than taking a count,
/// so every bell in the app agrees the moment a notification is read — the
/// badge was the other half of audit §3.1.3: marking things read has to be
/// visible somewhere other than the list you just left.
///
/// ## Accessibility (audit §3.3.1, which names the bell explicitly)
///
/// An icon-only control with a number painted on it is silent to a screen
/// reader unless the number is in the label, so the label is composed from the
/// count: *"Notifications, 3 unread"* / *"Notifications, no unread"*. The
/// numeral itself is wrapped in [ExcludeSemantics] so it is not announced
/// twice.
class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({
    super.key,
    required this.onPressed,
    this.size = 38,
    this.variant = AppIconButtonVariant.plain,
    this.badgeColor,
    this.badgeTextColor,
  });

  final VoidCallback onPressed;

  /// Visual diameter of the button, in raw design px.
  final double size;

  final AppIconButtonVariant variant;

  /// Overrides for the count pill, for a bell sitting on a brand surface.
  final Color? badgeColor;
  final Color? badgeTextColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppIconButton(
          icon: MedIcon.bell,
          variant: variant,
          size: size,
          semanticLabel: unread == 0
              ? 'Notifications, no unread'
              : 'Notifications, $unread unread',
          onPressed: onPressed,
        ),
        if (unread > 0)
          Positioned(
            // The button's hit area is larger than its visual circle, so the
            // badge is offset from the centre of the paint, not the box edge.
            top: (48 - size).h / 2,
            right: (48 - size).w / 2,
            child: ExcludeSemantics(
              child: _CountPill(
                count: unread,
                color: badgeColor,
                textColor: badgeTextColor,
              ),
            ),
          ),
      ],
    );
  }
}

/// The little count pill. Grows with the number ("9", "12", "99+") and has no
/// fixed height, so it survives OS text scaling.
class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, this.color, this.textColor});

  final int count;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';

    return Container(
      constraints: BoxConstraints(minWidth: 18.w, minHeight: 18.h),
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color ?? AppColors.danger,
        borderRadius: AppRadii.pill,
        border: Border.all(color: AppColors.surface, width: 1.5.w),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppText.poppins(
          size: AppFontSize.xxs,
          weight: AppText.bold,
          color: textColor ?? AppColors.textOnBrand,
          height: 1.1,
        ),
      ),
    );
  }
}
