import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/connectivity/connectivity_monitor.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../common/cached/application/providers/cached_controller.dart';
import '../../../common/cached/application/states/cached_state.dart';
import '../../../support/application/providers/app_config_provider.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/address.dart';
import '../../domain/entities/emergency_contact.dart';
import '../../domain/entities/person.dart';
import '../../domain/repositories/contacts_repository.dart';
import '../../domain/repositories/family_repository.dart';
import '../../domain/repositories/profile_repository.dart';

// ---------------------------------------------------------------------------
// Wiring
// ---------------------------------------------------------------------------

/// Account-level calls. Tests override this with a fake.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) =>
      throw UnimplementedError('profileRepositoryProvider is wired in app/di'),
);

/// Persons + release.
final familyRepositoryProvider = Provider<FamilyRepository>(
  (ref) =>
      throw UnimplementedError('familyRepositoryProvider is wired in app/di'),
);

/// Addresses + emergency contacts.
final contactsRepositoryProvider = Provider<ContactsRepository>(
  (ref) =>
      throw UnimplementedError('contactsRepositoryProvider is wired in app/di'),
);

/// The signed-in user's id, or null. Every account-scoped cached list below
/// watches this, so signing out (or in as someone else) rebuilds the list
/// controller instead of leaving the previous account's rows on screen.
final _accountIdProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider.select((u) => u?.id)),
);

// ---------------------------------------------------------------------------
// Persons (§6.1)
// ---------------------------------------------------------------------------

/// `GET /patient/me/persons`, cached. **App-lifetime** (not autoDispose): the
/// booking flow needs the "self" person id and the dependant list too.
///
/// Every loaded list publishes the self person's id to the session
/// (`AuthController.setSelfPersonId`) — null when the account has no self
/// person, which the test account does not (INTEGRATION-CORE §3).
final personsProvider =
    StateNotifierProvider<
      CachedController<List<Person>>,
      CachedState<List<Person>>
    >((ref) {
      final accountId = ref.watch(_accountIdProvider);
      final repository = ref.watch(familyRepositoryProvider);
      return CachedController<List<Person>>(
        ({required forceRefresh}) =>
            repository.persons(forceRefresh: forceRefresh),
        loadImmediately: accountId != null,
        reconnects: ref.watch(connectivityMonitorProvider).onReconnect,
        onValue: (persons) {
          final self = persons.where((p) => p.isSelf).firstOrNull;
          ref.read(authProvider.notifier).setSelfPersonId(self?.id);
        },
      );
    });

/// The account holder's own person record, or null when none exists.
final selfPersonProvider = Provider<Person?>(
  (ref) => ref
      .watch(personsProvider.select((s) => s.value))
      ?.where((p) => p.isSelf)
      .firstOrNull,
);

/// Everyone but the account holder, in server order.
final dependantsProvider = Provider<List<Person>>(
  (ref) =>
      ref
          .watch(personsProvider.select((s) => s.value))
          ?.where((p) => !p.isSelf)
          .toList() ??
      const <Person>[],
);

/// One person by id, or null when not (or no longer) on the account.
///
/// autoDispose: keyed by id, so one entry per person ever looked up would
/// otherwise stay for the app's lifetime (QA Prompt 1 #10).
final personByIdProvider = Provider.autoDispose.family<Person?, String>(
  (ref, id) => ref
      .watch(personsProvider.select((s) => s.value))
      ?.where((p) => p.id == id)
      .firstOrNull,
);

// ---------------------------------------------------------------------------
// Addresses (§6.2) and emergency contacts (§6.3)
// ---------------------------------------------------------------------------

/// `GET /patient/me/addresses`, cached; default first.
final addressesProvider =
    StateNotifierProvider.autoDispose<
      CachedController<List<Address>>,
      CachedState<List<Address>>
    >((ref) {
      final accountId = ref.watch(_accountIdProvider);
      final repository = ref.watch(contactsRepositoryProvider);
      return CachedController<List<Address>>(
        ({required forceRefresh}) =>
            repository.addresses(forceRefresh: forceRefresh),
        loadImmediately: accountId != null,
        reconnects: ref.watch(connectivityMonitorProvider).onReconnect,
      );
    });

final defaultAddressProvider = Provider.autoDispose<Address?>(
  (ref) => ref
      .watch(addressesProvider.select((s) => s.value))
      ?.where((a) => a.isDefault)
      .firstOrNull,
);

/// `GET /patient/me/emergency-contacts`, cached; primary first.
final emergencyContactsProvider =
    StateNotifierProvider.autoDispose<
      CachedController<List<EmergencyContact>>,
      CachedState<List<EmergencyContact>>
    >((ref) {
      final accountId = ref.watch(_accountIdProvider);
      final repository = ref.watch(contactsRepositoryProvider);
      return CachedController<List<EmergencyContact>>(
        ({required forceRefresh}) =>
            repository.emergencyContacts(forceRefresh: forceRefresh),
        loadImmediately: accountId != null,
        reconnects: ref.watch(connectivityMonitorProvider).onReconnect,
      );
    });

/// The primary contact, or null — what the ambulance screen shows.
final primaryEmergencyContactProvider = Provider.autoDispose<EmergencyContact?>(
  (ref) => ref
      .watch(emergencyContactsProvider.select((s) => s.value))
      ?.where((c) => c.isPrimary)
      .firstOrNull,
);

// ---------------------------------------------------------------------------
// Consents (§5.9)
// ---------------------------------------------------------------------------

/// `GET /patient/me/consents`, cached.
final consentsProvider =
    StateNotifierProvider.autoDispose<
      CachedController<List<Consent>>,
      CachedState<List<Consent>>
    >((ref) {
      final accountId = ref.watch(_accountIdProvider);
      final repository = ref.watch(profileRepositoryProvider);
      return CachedController<List<Consent>>(
        ({required forceRefresh}) =>
            repository.consents(forceRefresh: forceRefresh),
        loadImmediately: accountId != null,
        reconnects: ref.watch(connectivityMonitorProvider).onReconnect,
      );
    });

/// Documents whose current published version (`app-config.legal_versions`)
/// is newer than anything the user accepted — the re-consent prompt.
///
/// Empty until both the config and the consents have loaded, so the prompt
/// never flashes on a cold start.
final pendingConsentsProvider = Provider.autoDispose<List<PendingConsent>>((
  ref,
) {
  final versions = ref.watch(legalVersionsProvider);
  final consents = ref.watch(consentsProvider.select((s) => s.value));
  if (consents == null || versions.isEmpty) return const <PendingConsent>[];
  return pendingConsentsFor(versions: versions, accepted: consents);
});

/// Pure: which slugs still need acceptance. Exposed for tests.
List<PendingConsent> pendingConsentsFor({
  required Map<String, int> versions,
  required List<Consent> accepted,
}) {
  final latestAccepted = <String, int>{};
  for (final consent in accepted) {
    final current = latestAccepted[consent.documentSlug];
    if (current == null || consent.documentVersion > current) {
      latestAccepted[consent.documentSlug] = consent.documentVersion;
    }
  }
  final pending = <PendingConsent>[];
  for (final entry in versions.entries) {
    final acceptedVersion = latestAccepted[entry.key];
    if (acceptedVersion == null || acceptedVersion < entry.value) {
      pending.add(
        PendingConsent(
          slug: entry.key,
          currentVersion: entry.value,
          acceptedVersion: acceptedVersion,
        ),
      );
    }
  }
  return pending;
}

// ---------------------------------------------------------------------------
// Deletion requests (§5.6) and sessions (§4.9)
// ---------------------------------------------------------------------------

/// `GET /patient/me/deletion-requests`, cached, newest first.
final deletionRequestsProvider =
    StateNotifierProvider.autoDispose<
      CachedController<List<DeletionRequest>>,
      CachedState<List<DeletionRequest>>
    >((ref) {
      final accountId = ref.watch(_accountIdProvider);
      final repository = ref.watch(profileRepositoryProvider);
      return CachedController<List<DeletionRequest>>(
        ({required forceRefresh}) =>
            repository.deletionRequests(forceRefresh: forceRefresh),
        loadImmediately: accountId != null,
        reconnects: ref.watch(connectivityMonitorProvider).onReconnect,
      );
    });

/// The request the user can still withdraw, or null.
final openDeletionRequestProvider = Provider.autoDispose<DeletionRequest?>(
  (ref) => ref
      .watch(deletionRequestsProvider.select((s) => s.value))
      ?.where((r) => r.isOpen)
      .firstOrNull,
);

/// `GET /patient/auth/sessions`, cached; most recently seen first.
final sessionsProvider =
    StateNotifierProvider.autoDispose<
      CachedController<List<AccountSession>>,
      CachedState<List<AccountSession>>
    >((ref) {
      final accountId = ref.watch(_accountIdProvider);
      final repository = ref.watch(profileRepositoryProvider);
      return CachedController<List<AccountSession>>(
        ({required forceRefresh}) =>
            repository.sessions(forceRefresh: forceRefresh),
        loadImmediately: accountId != null,
        reconnects: ref.watch(connectivityMonitorProvider).onReconnect,
      );
    });
