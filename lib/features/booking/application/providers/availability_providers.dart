import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/cache/cached_fetcher.dart';
import '../../domain/entities/availability.dart';
import '../../domain/entities/slots.dart';
import 'discovery_providers.dart';

/// Key for [doctorSlotsProvider]: a doctor and a hospital-local day.
typedef SlotQuery = ({String doctorId, String date});

/// `GET /patient/doctors/{id}/availability` — today to the booking window.
/// autoDispose family: the doctor id space is unbounded.
final doctorAvailabilityProvider = StreamProvider.autoDispose
    .family<CachedResult<DoctorAvailability>, String>(
      (ref, doctorId) =>
          ref.watch(availabilityRepositoryProvider).availability(doctorId),
    );

/// `GET /patient/doctors/{id}/slots?date=`. autoDispose family: (doctor, day)
/// is a large key space, and slot data goes stale in 30 s anyway.
final doctorSlotsProvider = StreamProvider.autoDispose
    .family<CachedResult<DaySlots>, SlotQuery>(
      (ref, query) => ref
          .watch(availabilityRepositoryProvider)
          .slots(query.doctorId, date: query.date),
    );
