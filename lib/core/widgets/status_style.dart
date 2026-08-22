import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../mock_data/models/appointment.dart';

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

  /// The navy-on-tint token pill used on appointment cards.
  static const PillColors token = (
    background: AppColors.surfaceTint,
    foreground: AppColors.brand,
  );
}
