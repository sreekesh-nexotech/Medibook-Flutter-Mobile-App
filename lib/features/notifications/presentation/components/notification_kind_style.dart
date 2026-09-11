import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/mock_data/models/app_notification.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_icon.dart';

/// The one place a [NotificationKind] maps to a glyph and a tone.
///
/// The audit's CM-40 … CM-43 finding was that the notifications screen was
/// "four fixed cards" with no way to tell a confirmation from a cancellation.
/// Every kind now reads differently at a glance — icon, tint and badge tone —
/// and it reads the same everywhere, because the card, the filter chips and
/// any future in-app banner all resolve it here.
///
/// Colour carries the tone but never carries it alone: each kind also has its
/// own glyph and its own text label, so the distinction survives both
/// greyscale and colour-blindness.
abstract final class NotificationKindStyle {
  NotificationKindStyle._();

  /// A [MedIcon] name for [kind].
  static String icon(NotificationKind kind) => switch (kind) {
    NotificationKind.confirmation => MedIcon.calendar,
    NotificationKind.reminder => MedIcon.clock,
    NotificationKind.change => MedIcon.edit,
    NotificationKind.cancellation => MedIcon.closeCircle,
    NotificationKind.general => MedIcon.bell,
  };

  /// The glyph colour — also the accent used for the unread marker.
  static Color accent(NotificationKind kind) => switch (kind) {
    NotificationKind.confirmation => AppColors.successText,
    NotificationKind.reminder => AppColors.warning,
    NotificationKind.change => AppColors.infoBlue,
    NotificationKind.cancellation => AppColors.dangerText,
    NotificationKind.general => AppColors.brand,
  };

  /// The soft fill behind the glyph.
  static Color wash(NotificationKind kind) => switch (kind) {
    NotificationKind.confirmation => AppColors.successSoft,
    NotificationKind.reminder => AppColors.warningSoft,
    NotificationKind.change => AppColors.surfaceTint,
    NotificationKind.cancellation => AppColors.dangerSoft,
    NotificationKind.general => AppColors.surfaceTint,
  };

  /// The [AppBadge] tone for the kind pill.
  static AppBadgeTone badgeTone(NotificationKind kind) => switch (kind) {
    NotificationKind.confirmation => AppBadgeTone.success,
    NotificationKind.reminder => AppBadgeTone.warning,
    NotificationKind.change => AppBadgeTone.brand,
    NotificationKind.cancellation => AppBadgeTone.danger,
    NotificationKind.general => AppBadgeTone.neutral,
  };
}
