import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../appointments/application/providers/appointments_provider.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../booking/application/providers/booking_providers.dart';
import '../../../common/persons/application/providers/persons_read_provider.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../common/mutation/application/providers/mutation_notifier.dart';
import '../../../common/mutation/application/states/mutation_state.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/address.dart';
import '../../domain/entities/emergency_contact.dart';
import '../../domain/entities/person.dart';
import '../../domain/repositories/contacts_repository.dart';
import '../../domain/repositories/family_repository.dart';
import '../../domain/repositories/profile_repository.dart';
import '../states/profile_save_state.dart';
import 'profile_provider.dart';

/// The mutation notifiers of the profile feature. Each one:
/// * depends on the domain **contract**, never the implementation;
/// * returns the outcome (`Failure?`) so the screen can toast from its own
///   callback — no `BuildContext`, toast or navigation in here;
/// * updates the matching cached list in place on success, so the screen
///   changes immediately while the repository has already invalidated the
///   response cache for the next read.

// ---------------------------------------------------------------------------
// PATCH /patient/me (§5.2)
// ---------------------------------------------------------------------------

class ProfileSaveController extends StateNotifier<ProfileSaveState> {
  ProfileSaveController(this._ref, {required ProfileRepository repository})
    : _repository = repository,
      super(const ProfileSaveState());

  final Ref _ref;
  final ProfileRepository _repository;

  /// Sends only the fields that differ from the current user, with
  /// `If-Match: user.version`. On success the session's user is replaced.
  ///
  /// * `409 CONFLICT_VERSION` → the user is reloaded from `/me`,
  ///   [ProfileSaveState.hasConflict] is set, and a `ConflictFailure` is
  ///   returned so the screen can ask the user to review and save again.
  /// * `409 UNDER_AGE` → returned as a `ValidationFailure` on
  ///   `date_of_birth`, so it lands on the field.
  /// * `400 VALIDATION_ERROR` → returned as-is; its `fieldErrors` use the
  ///   wire names (`first_name`, `blood_group` …).
  Future<Failure?> save(ProfileUpdate update) async {
    if (state.isSaving) return null;
    final current = _ref.read(currentUserProvider);
    if (current == null) {
      return const UnauthorizedFailure(
        userMessage: 'Sign in again to change your profile.',
      );
    }
    final changes = update.diffAgainst(current);
    if (changes.isEmpty) return null;

    state = state.copyWith(
      isSaving: true,
      clearFailure: true,
      hasConflict: false,
    );
    try {
      final fresh = await _repository.updateProfile(
        changes,
        ifMatch: current.version,
      );
      if (!mounted) return null;
      _ref
          .read(authProvider.notifier)
          .updateUser(fresh.copyWith(authMethod: current.authMethod));
      state = state.copyWith(isSaving: false);
      return null;
    } catch (error, stackTrace) {
      if (!mounted) return null;
      var failure = error.asFailure(stackTrace);
      if (failure.apiCode == ApiErrorCodes.conflictVersion) {
        // Someone else changed the account: reload so the next attempt
        // carries the live version, then let the user retry.
        await _ref.read(authProvider.notifier).refreshMe();
        if (!mounted) return null;
        failure = ConflictFailure(
          userMessage:
              'Your details were changed elsewhere and have been reloaded. '
              'Review them and save again.',
          apiCode: failure.apiCode,
          meta: failure.meta,
          cause: failure,
        );
        state = state.copyWith(
          isSaving: false,
          failure: failure,
          hasConflict: true,
        );
        return failure;
      }
      if (failure.apiCode == ApiErrorCodes.underAge) {
        failure = ValidationFailure(
          userMessage: failure.userMessage,
          apiCode: failure.apiCode,
          fieldErrors: const {
            'date_of_birth':
                'Account holders must be 18 or older. Add a minor as a '
                'family member instead.',
          },
          cause: failure,
        );
      }
      state = state.copyWith(isSaving: false, failure: failure);
      return failure;
    }
  }

  void clearConflict() => state = state.copyWith(hasConflict: false);
}

/// autoDispose — one visit to `/profile/edit`.
final profileSaveControllerProvider =
    StateNotifierProvider.autoDispose<ProfileSaveController, ProfileSaveState>(
      (ref) => ProfileSaveController(
        ref,
        repository: ref.watch(profileRepositoryProvider),
      ),
    );

// ---------------------------------------------------------------------------
// Session user merge helper
// ---------------------------------------------------------------------------

/// A bare `User` (no `profile`) came back (§5.3, §5.4, §5.6 reactivate):
/// keep the profile fields the session already holds and take the account
/// fields from the response.
void mergeUserIntoSession(Ref ref, User fresh) {
  final current = ref.read(currentUserProvider);
  if (current == null) return;
  ref
      .read(authProvider.notifier)
      .updateUser(
        current.copyWith(
          firstName: fresh.firstName,
          lastName: fresh.lastName,
          email: fresh.email,
          phoneE164: fresh.phoneE164,
          alternatePhoneE164: fresh.alternatePhoneE164,
          clearAlternatePhone: fresh.alternatePhoneE164 == null,
          hasPassword: fresh.hasPassword,
          status: fresh.status,
          locale: fresh.locale,
          timezone: fresh.timezone,
          version: fresh.version,
          emailVerified: fresh.emailVerified,
          phoneVerified: fresh.phoneVerified,
          lastLoginAt: fresh.lastLoginAt,
          deletionRequestedAt: fresh.deletionRequestedAt,
          clearDeletionRequested: fresh.deletionRequestedAt == null,
        ),
      );
}

// ---------------------------------------------------------------------------
// Alternate phone (§5.4)
// ---------------------------------------------------------------------------

class AlternatePhoneController extends MutationNotifier {
  AlternatePhoneController(this._ref, {required ProfileRepository repository})
    : _repository = repository;

  final Ref _ref;
  final ProfileRepository _repository;

  Future<Failure?> set(String phoneE164) => apply(() async {
    mergeUserIntoSession(
      _ref,
      await _repository.setAlternatePhone(phoneE164: phoneE164),
    );
  });

  Future<Failure?> remove() => apply(() async {
    mergeUserIntoSession(_ref, await _repository.removeAlternatePhone());
  });
}

final alternatePhoneControllerProvider =
    StateNotifierProvider.autoDispose<AlternatePhoneController, MutationState>(
      (ref) => AlternatePhoneController(
        ref,
        repository: ref.watch(profileRepositoryProvider),
      ),
    );

// ---------------------------------------------------------------------------
// Persons (§6.1)
// ---------------------------------------------------------------------------

class PersonMutationController extends MutationNotifier {
  PersonMutationController(this._ref, {required FamilyRepository repository})
    : _repository = repository;

  final Ref _ref;
  final FamilyRepository _repository;

  /// `POST` — returns the failure, or null with the list updated.
  Future<Failure?> create(PersonDraft draft) => apply(() async {
    final person = await _repository.create(draft);
    _ref.read(personsProvider.notifier).update((list) => [...list, person]);
    _dropOtherReaders();
  });

  /// The booking picker, the appointments "For …" label and the records
  /// form each read `/me/persons` through their own provider; the response
  /// cache is already dropped by the repository, but a provider that is
  /// alive keeps its old answer until told otherwise.
  void _dropOtherReaders() {
    _ref.invalidate(bookingPersonsProvider);
    _ref.invalidate(appointmentPersonsProvider);
    _ref.invalidate(personSummariesProvider);
  }

  /// `PATCH` with `If-Match`. A `CONFLICT_VERSION` reloads the list.
  Future<Failure?> update(
    String id,
    PersonDraft draft, {
    required int ifMatch,
  }) => apply(() async {
    final person = await _repository.update(id, draft, ifMatch: ifMatch);
    _ref
        .read(personsProvider.notifier)
        .update((list) => [for (final p in list) p.id == id ? person : p]);
    _dropOtherReaders();
  }, onConflict: _reload);

  /// `DELETE`. `PERSON_IS_SELF` / `PERSON_HAS_APPOINTMENTS` come back as a
  /// `ConflictFailure` with that `apiCode`.
  Future<Failure?> delete(String id) => apply(() async {
    await _repository.delete(id);
    _ref
        .read(personsProvider.notifier)
        .update((list) => list.where((p) => p.id != id).toList());
    _dropOtherReaders();
  });

  Future<void> _reload() =>
      _ref.read(personsProvider.notifier).refresh(force: true);
}

final personMutationControllerProvider =
    StateNotifierProvider.autoDispose<PersonMutationController, MutationState>(
      (ref) => PersonMutationController(
        ref,
        repository: ref.watch(familyRepositoryProvider),
      ),
    );

// ---------------------------------------------------------------------------
// Addresses (§6.2)
// ---------------------------------------------------------------------------

class AddressMutationController extends MutationNotifier {
  AddressMutationController(this._ref, {required ContactsRepository repository})
    : _repository = repository;

  final Ref _ref;
  final ContactsRepository _repository;

  Future<Failure?> create(AddressDraft draft) => apply(() async {
    final created = await _repository.createAddress(draft);
    _ref
        .read(addressesProvider.notifier)
        .update(
          (list) => _withDefault([
            ...list,
            created,
          ], created.isDefault ? created.id : null),
        );
  });

  /// `PATCH` never changes the default (§6.2); when [makeDefault] is set the
  /// dedicated call follows.
  Future<Failure?> update(
    String id,
    AddressDraft draft, {
    required int ifMatch,
    bool makeDefault = false,
  }) => apply(() async {
    var updated = await _repository.updateAddress(id, draft, ifMatch: ifMatch);
    if (makeDefault && !updated.isDefault) {
      updated = await _repository.setDefaultAddress(id);
    }
    _replace(updated);
  }, onConflict: _reload);

  Future<Failure?> setDefault(String id) => apply(() async {
    _replace(await _repository.setDefaultAddress(id));
  });

  Future<Failure?> delete(String id) => apply(() async {
    await _repository.deleteAddress(id);
    _ref
        .read(addressesProvider.notifier)
        .update((list) => list.where((a) => a.id != id).toList());
    // The server may have promoted another address; make the list truthful.
    await _reload();
  });

  void _replace(Address updated) {
    _ref
        .read(addressesProvider.notifier)
        .update(
          (list) => _withDefault([
            for (final a in list) a.id == updated.id ? updated : a,
          ], updated.isDefault ? updated.id : null),
        );
  }

  /// Exactly one default: when [defaultId] is set, every other row loses it.
  static List<Address> _withDefault(List<Address> list, String? defaultId) =>
      defaultId == null
      ? list
      : [for (final a in list) a.copyWith(isDefault: a.id == defaultId)];

  Future<void> _reload() =>
      _ref.read(addressesProvider.notifier).refresh(force: true);
}

final addressMutationControllerProvider =
    StateNotifierProvider.autoDispose<AddressMutationController, MutationState>(
      (ref) => AddressMutationController(
        ref,
        repository: ref.watch(contactsRepositoryProvider),
      ),
    );

// ---------------------------------------------------------------------------
// Emergency contacts (§6.3)
// ---------------------------------------------------------------------------

class ContactMutationController extends MutationNotifier {
  ContactMutationController(this._ref, {required ContactsRepository repository})
    : _repository = repository;

  final Ref _ref;
  final ContactsRepository _repository;

  Future<Failure?> create(ContactDraft draft) => apply(() async {
    final created = await _repository.createContact(draft);
    _ref
        .read(emergencyContactsProvider.notifier)
        .update(
          (list) => _withPrimary([
            ...list,
            created,
          ], created.isPrimary ? created.id : null),
        );
  });

  Future<Failure?> update(
    String id,
    ContactDraft draft, {
    required int ifMatch,
    bool makePrimary = false,
  }) => apply(() async {
    var updated = await _repository.updateContact(id, draft, ifMatch: ifMatch);
    if (makePrimary && !updated.isPrimary) {
      updated = await _repository.setPrimaryContact(id);
    }
    _replace(updated);
  }, onConflict: _reload);

  Future<Failure?> setPrimary(String id) => apply(() async {
    _replace(await _repository.setPrimaryContact(id));
  });

  Future<Failure?> delete(String id) => apply(() async {
    await _repository.deleteContact(id);
    _ref
        .read(emergencyContactsProvider.notifier)
        .update((list) => list.where((c) => c.id != id).toList());
    await _reload();
  });

  void _replace(EmergencyContact updated) {
    _ref
        .read(emergencyContactsProvider.notifier)
        .update(
          (list) => _withPrimary([
            for (final c in list) c.id == updated.id ? updated : c,
          ], updated.isPrimary ? updated.id : null),
        );
  }

  static List<EmergencyContact> _withPrimary(
    List<EmergencyContact> list,
    String? primaryId,
  ) => primaryId == null
      ? list
      : [for (final c in list) c.copyWith(isPrimary: c.id == primaryId)];

  Future<void> _reload() =>
      _ref.read(emergencyContactsProvider.notifier).refresh(force: true);
}

final contactMutationControllerProvider =
    StateNotifierProvider.autoDispose<ContactMutationController, MutationState>(
      (ref) => ContactMutationController(
        ref,
        repository: ref.watch(contactsRepositoryProvider),
      ),
    );

// ---------------------------------------------------------------------------
// Consents (§5.9)
// ---------------------------------------------------------------------------

class ConsentController extends MutationNotifier {
  ConsentController(this._ref, {required ProfileRepository repository})
    : _repository = repository;

  final Ref _ref;
  final ProfileRepository _repository;

  /// Accepts every pending document at its current version. Stops at the
  /// first failure and returns it.
  Future<Failure?> acceptAll(List<PendingConsent> pending) => apply(() async {
    for (final item in pending) {
      final consent = await _repository.acceptConsent(
        documentSlug: item.slug,
        documentVersion: item.currentVersion,
      );
      _ref
          .read(consentsProvider.notifier)
          .update(
            (list) => [consent, ...list.where((c) => c.id != consent.id)],
          );
    }
  });
}

final consentControllerProvider =
    StateNotifierProvider.autoDispose<ConsentController, MutationState>(
      (ref) => ConsentController(
        ref,
        repository: ref.watch(profileRepositoryProvider),
      ),
    );

// ---------------------------------------------------------------------------
// Sessions (§4.9)
// ---------------------------------------------------------------------------

class SessionsController extends MutationNotifier {
  SessionsController(this._ref, {required ProfileRepository repository})
    : _repository = repository;

  final Ref _ref;
  final ProfileRepository _repository;

  /// Ends one other session. The current one is ended with
  /// `AuthController.logout()`, not here.
  Future<Failure?> revoke(String sessionId) => apply(() async {
    await _repository.revokeSession(sessionId);
    _ref
        .read(sessionsProvider.notifier)
        .update((list) => list.where((s) => s.id != sessionId).toList());
  });
}

final sessionsControllerProvider =
    StateNotifierProvider.autoDispose<SessionsController, MutationState>(
      (ref) => SessionsController(
        ref,
        repository: ref.watch(profileRepositoryProvider),
      ),
    );
