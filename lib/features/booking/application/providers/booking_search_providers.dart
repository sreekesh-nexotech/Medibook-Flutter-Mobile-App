import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The step-1 "Search departments" text. Transient, so `autoDispose` — it
/// clears when the flow is left (QA Prompt 6).
final bookingDeptQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// The step-2 "Search doctors.." text. Same lifetime as the department query.
final bookingDoctorQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);
