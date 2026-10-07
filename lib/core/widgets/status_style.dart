import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';

/// Presentation styling for status pills. Kept out of the entities (they stay
/// logic-free) — this is a UI-layer lookup. Features fold their own status
/// enums onto these named palettes (`appointments/…/status_pill.dart`,
/// `insurance/…/insurance_policy_card.dart`); core never imports a feature
/// enum.
typedef PillColors = ({Color background, Color foreground});

abstract final class AppStatusStyle {
  AppStatusStyle._();

  /// Appointment status pills (Appointments list, detail).
  static const PillColors completed = (
    background: AppColors.successSoft,
    foreground: AppColors.successText,
  );
  static const PillColors cancelled = (
    background: AppColors.dangerSoft,
    foreground: AppColors.dangerText,
  );
  static const PillColors confirmed = (
    background: AppColors.surfaceTint,
    foreground: AppColors.brand,
  );

  /// Pill colours for the two canonical appointment statuses that are
  /// **derived** rather than stored (`CANONICAL_MASTER_DATA` §4).
  ///
  /// Only the colours live here, so there is exactly one definition of them
  /// and a feature never invents a palette of its own.
  ///
  /// In Queue is warm and active — the patient is at the desk today. No-show is
  /// neutral rather than alarming: the slot simply passed.
  static const PillColors inQueue = (
    background: AppColors.warningSoft,
    foreground: AppColors.warningText,
  );

  /// Scheduled — the design's `warning` badge tone for a visit still to come
  /// (the same tone as [inQueue], which is the other upcoming state).
  static const PillColors scheduled = (
    background: AppColors.warningSoft,
    foreground: AppColors.warningText,
  );

  static const PillColors noShow = (
    background: AppColors.grey100,
    foreground: AppColors.grey500,
  );

  /// Payment status pills (receipt, appointment detail).
  static const PillColors paid = (
    background: AppColors.successSoft,
    foreground: AppColors.successText,
  );
  static const PillColors refunded = (
    background: AppColors.surfaceTint,
    foreground: AppColors.brand,
  );
  static const PillColors paymentPending = (
    background: AppColors.warningSoft,
    foreground: AppColors.grey600,
  );
  static const PillColors paymentFailed = (
    background: AppColors.dangerSoft,
    foreground: AppColors.dangerText,
  );

  /// The navy-on-tint token pill used on appointment cards.
  static const PillColors token = (
    background: AppColors.surfaceTint,
    foreground: AppColors.brand,
  );
}
