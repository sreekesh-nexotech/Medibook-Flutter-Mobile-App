import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../domain/entities/notification.dart';

/// The one place a [NotificationKind] (§17: the six backend kinds) maps to a
/// glyph and a tone.
///
/// Every kind reads differently at a glance — icon, tint and badge tone —
/// and it reads the same everywhere, because the card and the filter chips
/// both resolve it here. Colour carries the tone but never carries it alone:
/// each kind also has its own glyph and its own text label.
abstract final class NotificationKindStyle {
  NotificationKindStyle._();

  /// A [MedIcon] name for [kind].
  static String icon(NotificationKind kind) => switch (kind) {
    NotificationKind.confirmation => PhIcon.calendarBlank,
    NotificationKind.reminder => PhIcon.clock,
    NotificationKind.cancellation => PhIcon.xCircle,
    NotificationKind.payment => MedIcon.bag,
    NotificationKind.queue => PhIcon.buildings,
    NotificationKind.general => PhIcon.bell,
  };

  /// The glyph colour — also the accent used for the unread marker.
  static Color accent(NotificationKind kind) => switch (kind) {
    NotificationKind.confirmation => AppColors.successText,
    NotificationKind.reminder => AppColors.warning,
    NotificationKind.cancellation => AppColors.dangerText,
    NotificationKind.payment => AppColors.infoBlue,
    NotificationKind.queue => AppColors.accentBlue,
    NotificationKind.general => AppColors.brand,
  };

  /// The soft fill behind the glyph.
  static Color wash(NotificationKind kind) => switch (kind) {
    NotificationKind.confirmation => AppColors.successSoft,
    NotificationKind.reminder => AppColors.warningSoft,
    NotificationKind.cancellation => AppColors.dangerSoft,
    NotificationKind.payment ||
    NotificationKind.queue ||
    NotificationKind.general => AppColors.surfaceTint,
  };

  /// The [AppBadge] tone for the kind pill.
  static AppBadgeTone badgeTone(NotificationKind kind) => switch (kind) {
    NotificationKind.confirmation => AppBadgeTone.success,
    NotificationKind.reminder => AppBadgeTone.warning,
    NotificationKind.cancellation => AppBadgeTone.danger,
    NotificationKind.payment || NotificationKind.queue => AppBadgeTone.brand,
    NotificationKind.general => AppBadgeTone.neutral,
  };
}
