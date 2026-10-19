import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../usecases/rebook.dart';
import 'appointments_provider.dart';

/// "Rebook" on a hospital-cancel notification (UB-20): the notification
/// carries only the appointment id, so the appointment is read (cache first)
/// for its doctor and department.
final rebookRequestProvider = FutureProvider.autoDispose
    .family<RebookRequest, String>((ref, appointmentId) async {
      final detail = await ref.watch(
        appointmentDetailProvider(appointmentId).future,
      );
      return RebookRequest.of(detail.value.appointment);
    });
