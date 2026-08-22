import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'medibook_seed.dart';
import 'models/app_notification.dart';
import 'models/department.dart';
import 'models/doctor.dart';
import 'models/medical_record.dart';
import 'models/patient.dart';
import 'models/promo_banner.dart';

/// ============================================================================
/// READ PROVIDERS — API SWAP-POINTS
/// ----------------------------------------------------------------------------
/// Screens read these instead of touching [MedibookSeed] directly. Today each
/// returns static seed; when the data layer lands, change only the body of each
/// provider to `ref.watch(<feature>RepositoryProvider).fetchX()` (a
/// FutureProvider). Screen code does not change.
///
/// These are global read-only config → plain [Provider] (no autoDispose).
/// ============================================================================

final departmentsProvider = Provider<List<Department>>(
  (ref) => MedibookSeed.departments,
);

final doctorsProvider = Provider<List<Doctor>>(
  (ref) => MedibookSeed.doctors,
);

/// A single doctor by id (used by doctor detail, appointment cards, etc.).
final doctorByIdProvider = Provider.family<Doctor, String>(
  (ref, id) => MedibookSeed.doctorById(id),
);

final patientsProvider = Provider<List<Patient>>(
  (ref) => MedibookSeed.patients,
);

final timeSlotsProvider = Provider<List<String>>(
  (ref) => MedibookSeed.timeSlots,
);

final recordsProvider = Provider<List<MedicalRecord>>(
  (ref) => MedibookSeed.records,
);

final notificationsProvider = Provider<List<AppNotification>>(
  (ref) => MedibookSeed.notifications,
);

final promoBannersProvider = Provider<List<PromoBanner>>(
  (ref) => MedibookSeed.banners,
);

final profileInfoProvider = Provider<List<({String key, String value})>>(
  (ref) => MedibookSeed.profileInfo,
);

/// Current user's display name (Profile identity).
final userNameProvider = Provider<String>((ref) => MedibookSeed.userName);

/// Current user's email (Profile identity).
final userEmailProvider = Provider<String>((ref) => MedibookSeed.userEmail);
