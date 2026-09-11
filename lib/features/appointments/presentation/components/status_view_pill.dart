import 'package:flutter/material.dart';

import '../../../../core/mock_data/models/appointment.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../../../core/widgets/status_style.dart';
import '../../domain/entities/appointment_status_view.dart';

/// Maps the **five canonical statuses** (`CANONICAL_MASTER_DATA` §4) onto their
/// pill colours.
///
/// Every colour comes from `core/widgets/status_style.dart` — this file holds
/// none of its own. The split is deliberate: In Queue and No-show are *derived*
/// from the slot time and the clinic's live queue (see [AppointmentStatusViews]),
/// so the derivation is a presentation concern and belongs to this feature,
/// while the palette stays in core where every other status pill reads it. Core
/// must not import a feature's enum, so the mapping lives on this side of that
/// line rather than inverting the dependency.
abstract final class AppointmentStatusStyle {
  AppointmentStatusStyle._();

  /// Pill colours for [status].
  static PillColors of(AppointmentStatusView status) => switch (status) {
    AppointmentStatusView.scheduled => AppStatusStyle.appointment(
      AppointmentStatus.confirmed,
    ),
    AppointmentStatusView.completed => AppStatusStyle.appointment(
      AppointmentStatus.completed,
    ),
    AppointmentStatusView.cancelled => AppStatusStyle.appointment(
      AppointmentStatus.cancelled,
    ),
    AppointmentStatusView.inQueue => AppStatusStyle.inQueue,
    AppointmentStatusView.noShow => AppStatusStyle.noShow,
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
