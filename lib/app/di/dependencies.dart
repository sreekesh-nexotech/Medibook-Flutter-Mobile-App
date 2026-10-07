import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_update_dependencies.dart';
import 'appointments_dependencies.dart';
import 'auth_dependencies.dart';
import 'booking_dependencies.dart';
import 'common_attachments_dependencies.dart';
import 'common_persons_dependencies.dart';
import 'insurance_dependencies.dart';
import 'notifications_dependencies.dart';
import 'payment_dependencies.dart';
import 'profile_dependencies.dart';
import 'records_dependencies.dart';
import 'search_dependencies.dart';
import 'support_dependencies.dart';

/// Every feature's dependency wiring, for the root `ProviderScope`
/// (`app_bootstrap.dart`) and the test harnesses. Application-layer
/// repository providers default to throwing; these overrides supply the
/// infrastructure implementations, so no application file imports
/// `infrastructure/` (CL CODE-014).
List<Override> appDependencies() => [
  ...appUpdateDependencies,
  ...appointmentsDependencies,
  ...authDependencies,
  ...bookingDependencies,
  ...commonAttachmentsDependencies,
  ...commonPersonsDependencies,
  ...insuranceDependencies,
  ...notificationsDependencies,
  ...paymentDependencies,
  ...profileDependencies,
  ...recordsDependencies,
  ...searchDependencies,
  ...supportDependencies,
];
