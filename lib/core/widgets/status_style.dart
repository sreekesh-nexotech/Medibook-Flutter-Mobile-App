import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../mock_data/models/appointment.dart';
import '../mock_data/models/payment.dart';

/// Presentation styling for status pills. Kept out of the data models (models
/// stay logic-free) — this is a UI-layer lookup.
typedef PillColors = ({Color background, Color foreground});

abstract final class AppStatusStyle {
  AppStatusStyle._();

  /// Appointment status pill (Appointments list, detail).
  static PillColors appointment(AppointmentStatus status) => switch (status) {
    AppointmentStatus.completed => (
      background: AppColors.successSoft,
      foreground: AppColors.successText,
    ),
    AppointmentStatus.cancelled => (
      background: AppColors.dangerSoft,
      foreground: AppColors.dangerText,
    ),
    AppointmentStatus.confirmed => (
      background: AppColors.surfaceTint,
      foreground: AppColors.brand,
    ),
  };

  /// Pill colours for the two canonical appointment statuses that are
  /// **derived** rather than stored (`CANONICAL_MASTER_DATA` §4).
  ///
  /// The stored [AppointmentStatus] has three values; In Queue and No-show are
  /// inferred from the slot time and the clinic's live queue, so the derivation
  /// itself belongs to the appointments feature. Only the colours live here, so
  /// there is exactly one definition of them and a feature never invents a
  /// palette of its own.
  ///
  /// In Queue is warm and active — the patient is at the desk today. No-show is
  /// neutral rather than alarming: the slot simply passed.
  static const PillColors inQueue = (
    background: AppColors.warningSoft,
    foreground: AppColors.grey600,
  );

  static const PillColors noShow = (
    background: AppColors.grey100,
    foreground: AppColors.grey500,
  );

  /// Payment status pill (receipt, appointment detail).
  static PillColors payment(PaymentStatus status) => switch (status) {
    PaymentStatus.paid => (
      background: AppColors.successSoft,
      foreground: AppColors.successText,
    ),
    PaymentStatus.refunded => (
      background: AppColors.surfaceTint,
      foreground: AppColors.brand,
    ),
    PaymentStatus.pending => (
      background: AppColors.warningSoft,
      foreground: AppColors.grey600,
    ),
    PaymentStatus.failed => (
      background: AppColors.dangerSoft,
      foreground: AppColors.dangerText,
    ),
  };

  /// The navy-on-tint token pill used on appointment cards.
  static const PillColors token = (
    background: AppColors.surfaceTint,
    foreground: AppColors.brand,
  );
}
