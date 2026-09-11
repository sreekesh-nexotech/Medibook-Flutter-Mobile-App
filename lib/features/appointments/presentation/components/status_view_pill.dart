import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/mock_data/models/appointment.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../../../core/widgets/status_style.dart';
import '../../domain/entities/appointment_status_view.dart';

/// Pill colours for the **five canonical statuses**
/// (`CANONICAL_MASTER_DATA` §4).
///
/// `core/widgets/status_style.dart` keys `AppStatusStyle.appointment` off the
/// stored three-value [AppointmentStatus], so it has tokens for Scheduled
/// (`confirmed`), Completed and Cancelled and **none for In Queue or No-show**.
/// Core is frozen this round, so those two are resolved here from existing
/// [AppColors] tokens and the other three delegate to core, which keeps one
/// definition of the colours the rest of the app already uses.
///
/// When core reopens this whole lookup should move into
/// `AppStatusStyle.appointmentView(AppointmentStatusView)` and this file should
/// disappear.
abstract final class AppointmentStatusStyle {
  AppointmentStatusStyle._();

  /// Pill colours for [status].
  static PillColors of(AppointmentStatusView status) => switch (status) {
    // Delegated — the stored status these map to already has core tokens.
    AppointmentStatusView.scheduled => AppStatusStyle.appointment(
      AppointmentStatus.confirmed,
    ),
    AppointmentStatusView.completed => AppStatusStyle.appointment(
      AppointmentStatus.completed,
    ),
    AppointmentStatusView.cancelled => AppStatusStyle.appointment(
      AppointmentStatus.cancelled,
    ),
    // Missing from core: an active-today state, warm rather than final.
    AppointmentStatusView.inQueue => (
      background: AppColors.warningSoft,
      foreground: AppColors.grey600,
    ),
    // Missing from core: closed but not cancelled — neutral, not alarming.
    AppointmentStatusView.noShow => (
      background: AppColors.grey100,
      foreground: AppColors.grey500,
    ),
  };
}

/// The status pill for one appointment, in canonical spelling.
///
/// A thin wrapper over [AppStatusPill] so no screen has to remember to pair the
/// label with the right colours.
class AppointmentStatusViewPill extends StatelessWidget {
  const AppointmentStatusViewPill({super.key, required this.status});

  final AppointmentStatusView status;

  @override
  Widget build(BuildContext context) {
    return AppStatusPill(
      label: status.label,
      colors: AppointmentStatusStyle.of(status),
    );
  }
}
