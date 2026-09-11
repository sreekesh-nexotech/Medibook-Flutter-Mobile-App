import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'medibook_seed.dart';
import 'models/app_notification.dart';
import 'models/department.dart';
import 'models/doctor.dart';
import 'models/fee_breakdown.dart';
import 'models/hospital.dart';
import 'models/insurance_policy.dart';
import 'models/location.dart';
import 'models/medical_record.dart';
import 'models/patient.dart';
import 'models/payment.dart';
import 'models/promo_banner.dart';
import 'models/queue_status.dart';
import 'models/slot.dart';
import 'models/support_content.dart';
import 'stores/dependants_store.dart';
import 'stores/documents_store.dart';
import 'stores/insurance_store.dart';
import 'stores/notifications_store.dart';
import 'stores/payments_store.dart';

/// ============================================================================
/// READ PROVIDERS — API SWAP-POINTS
/// ----------------------------------------------------------------------------
/// Screens read these instead of touching [MedibookSeed] directly. Today each
/// returns static seed; when the data layer lands, change only the body of each
/// provider to `ref.watch(<feature>RepositoryProvider).fetchX()` (a
/// FutureProvider). Screen code does not change.
///
/// These are global read-only config → plain [Provider] (no autoDispose).
///
/// **Mutable data lives elsewhere.** Anything a user can change is owned by a
/// `Notifier` store under `stores/`, because more than one feature reads it:
///
/// | Data                  | Store                                            |
/// |-----------------------|--------------------------------------------------|
/// | notifications + read  | `stores/notifications_store.dart`                |
/// | patients / dependants | `stores/dependants_store.dart`                   |
/// | health documents      | `stores/documents_store.dart`                    |
/// | emergency contacts    | `stores/profile_store.dart`                      |
/// | addresses             | `stores/profile_store.dart`                      |
/// | insurance policies    | `stores/insurance_store.dart`                    |
/// | payments / refunds    | `stores/payments_store.dart`                     |
///
/// The read providers below that cover the same data
/// ([patientsProvider], [recordsProvider], [notificationsProvider],
/// [insurancePoliciesProvider], [paymentsProvider]) now delegate to their
/// store, so a screen still reading the old provider sees live edits instead of
/// frozen seed. Prefer the store for anything that writes.
/// ============================================================================

// ---- Catalogue (read-only) ----

final departmentsProvider = Provider<List<Department>>(
  (ref) => MedibookSeed.departments,
);

final doctorsProvider = Provider<List<Doctor>>((ref) => MedibookSeed.doctors);

/// A single doctor by id (used by doctor detail, appointment cards, etc.).
final doctorByIdProvider = Provider.family<Doctor, String>(
  (ref, id) => MedibookSeed.doctorById(id),
);

/// Every hospital / clinic (CM-11, CM-25).
final hospitalsProvider = Provider<List<Hospital>>(
  (ref) => MedibookSeed.hospitals,
);

/// A single hospital by id. Falls back to the first facility for an unknown id,
/// matching [doctorByIdProvider]'s behaviour.
final hospitalByIdProvider = Provider.family<Hospital, String>(
  (ref, id) => MedibookSeed.hospitalById(id),
);

/// Doctors practising at one facility. autoDispose family — a hospital detail
/// screen should not hold its list after it closes.
final doctorsAtHospitalProvider = Provider.autoDispose
    .family<List<Doctor>, String>(
      (ref, hospitalId) => MedibookSeed.doctorsAtHospital(hospitalId),
    );

/// Selectable city/area pairs — the top of discovery (CM-10).
final locationsProvider = Provider<List<Location>>(
  (ref) => MedibookSeed.locations,
);

/// The "Popular" shortcut row above the full location list.
final popularLocationsProvider = Provider<List<Location>>(
  (ref) => MedibookSeed.locations.where((l) => l.isPopular).toList(),
);

/// Distinct cities, in seed order — the location picker's section headers.
final citiesProvider = Provider<List<String>>((ref) {
  final seen = <String>[];
  for (final location in MedibookSeed.locations) {
    if (!seen.contains(location.city)) seen.add(location.city);
  }
  return seen;
});

/// Hospitals in one city (and optionally one area). autoDispose family.
final hospitalsInLocationProvider = Provider.autoDispose
    .family<List<Hospital>, Location>(
      (ref, location) =>
          MedibookSeed.hospitalsIn(location.city, area: location.area),
    );

// ---- Slots (CM-12) ----

/// The legacy display-string slot list. Kept because the current booking and
/// reschedule screens compare against it; new work should use
/// [slotsForProvider], which carries real times and availability states.
final timeSlotsProvider = Provider<List<String>>(
  (ref) => MedibookSeed.timeSlots,
);

/// Key for [slotsForProvider] — a doctor and a day.
typedef SlotQuery = ({String doctorId, DateTime day});

/// A doctor's availability for one day, including the booked, blocked and past
/// slots (CM-12). autoDispose family — the (doctor, day) key space is large.
///
/// The seed deliberately contains a **fully booked** day (today + 2), a day
/// with **no slots at all** (today + 3), and closed Sundays, so the
/// unavailable and fully-booked states have real data behind them.
final slotsForProvider = Provider.autoDispose.family<DaySlots, SlotQuery>(
  (ref, query) => MedibookSeed.slotsFor(query.doctorId, query.day),
);

// ---- Patients / dependants (delegates to the store) ----

/// The account's patients. Delegates to `dependantsStoreProvider` so edits made
/// in Profile show up in the booking picker.
///
/// Kept under its original name so existing screens compile; new code may read
/// either.
final patientsProvider = Provider<List<Patient>>(
  (ref) => ref.watch(dependantsStoreProvider),
);

// ---- Records / documents (delegates to the store) ----

/// The account's health documents. Delegates to `documentsStoreProvider`.
final recordsProvider = Provider<List<MedicalRecord>>(
  (ref) => ref.watch(documentsStoreProvider),
);

/// Documents of one type — the Records filter chips. autoDispose family.
final recordsOfTypeProvider = Provider.autoDispose
    .family<List<MedicalRecord>, DocumentType>((ref, type) {
      final documents = ref.watch(documentsStoreProvider);
      return documents.where((d) => d.type == type).toList();
    });

// ---- Notifications (delegates to the store) ----

/// The account's notifications. Delegates to `notificationsStoreProvider`, so
/// "mark all as read" is visible here too (audit §3.1.3).
final notificationsProvider = Provider<List<AppNotification>>(
  (ref) => ref.watch(notificationsStoreProvider),
);

// ---- Payments / fees (CM-13, CM-17 … CM-22) ----

/// The account's payment ledger. Delegates to `paymentsStoreProvider`.
final paymentsProvider = Provider<List<PaymentRecord>>(
  (ref) => ref.watch(paymentsStoreProvider),
);

/// Key for [feeBreakdownProvider] — a doctor, and an optional coupon.
typedef FeeQuery = ({String doctorId, String? couponCode});

/// The itemised fee for a doctor, with GST and the convenience fee (CM-13,
/// CM-19). autoDispose family — it is scoped to one booking.
final feeBreakdownProvider = Provider.autoDispose
    .family<FeeBreakdown, FeeQuery>(
      (ref, query) =>
          MedibookSeed.feeFor(query.doctorId, couponCode: query.couponCode),
    );

/// The payment methods the payment screen offers (CM-17).
final paymentMethodsProvider = Provider<List<PaymentMethod>>(
  (ref) => PaymentMethod.values,
);

// ---- Insurance (delegates to the store) ----

/// The account's insurance policies. Delegates to `insuranceStoreProvider`.
final insurancePoliciesProvider = Provider<List<InsurancePolicy>>(
  (ref) => ref.watch(insuranceStoreProvider),
);

// ---- Live queue (CM-09, CM-24) ----

/// Token progress at a doctor's desk, or null when the clinic publishes none.
/// autoDispose family — it is only interesting while a queue screen is open.
final queueStatusProvider = Provider.autoDispose.family<QueueStatus?, String>(
  (ref, doctorId) => MedibookSeed.queueFor(doctorId),
);

// ---- Emergency / addresses (delegate to the store) ----

/// Ambulance operators the emergency screen can dial (CM-44 … CM-46).
final ambulanceProvidersProvider = Provider<List<AmbulanceProvider>>(
  (ref) => MedibookSeed.ambulanceProviders,
);

// ---- Content (CM-02, CM-52) ----

/// Help / FAQ entries.
final faqsProvider = Provider<List<FaqEntry>>((ref) => MedibookSeed.faqs);

/// FAQ categories, in seed order — the FAQ screen's section headers.
final faqCategoriesProvider = Provider<List<String>>((ref) {
  final seen = <String>[];
  for (final faq in MedibookSeed.faqs) {
    if (!seen.contains(faq.category)) seen.add(faq.category);
  }
  return seen;
});

/// Terms / Privacy / Guidelines.
final legalDocumentsProvider = Provider<List<LegalDocument>>(
  (ref) => MedibookSeed.legalDocuments,
);

/// One legal document by slug, or null for an unknown slug — which is what the
/// `/legal/:slug` route renders `AppNotFoundView` for.
final legalDocumentProvider = Provider.family<LegalDocument?, String>(
  (ref, slug) => MedibookSeed.legalBySlug(slug),
);

final promoBannersProvider = Provider<List<PromoBanner>>(
  (ref) => MedibookSeed.banners,
);

// ---- Current user ----

final profileInfoProvider = Provider<List<({String key, String value})>>(
  (ref) => MedibookSeed.profileInfo,
);

/// Current user's display name (Profile identity).
final userNameProvider = Provider<String>((ref) => MedibookSeed.userName);

/// Current user's email (Profile identity).
final userEmailProvider = Provider<String>((ref) => MedibookSeed.userEmail);

/// Current user's phone (Profile identity).
final userPhoneProvider = Provider<String>((ref) => MedibookSeed.userPhone);
