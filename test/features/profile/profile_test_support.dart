import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/features/auth/application/providers/auth_provider.dart';
import 'package:medibook/features/auth/domain/entities/user.dart';
import 'package:medibook/features/auth/domain/repositories/auth_repository.dart';
import 'package:medibook/features/profile/application/providers/profile_provider.dart';
import 'package:medibook/features/profile/domain/entities/account.dart';
import 'package:medibook/features/profile/domain/entities/address.dart';
import 'package:medibook/features/profile/domain/entities/emergency_contact.dart';
import 'package:medibook/features/profile/domain/entities/person.dart';
import 'package:medibook/features/profile/domain/repositories/contacts_repository.dart';
import 'package:medibook/features/profile/domain/repositories/family_repository.dart';
import 'package:medibook/features/profile/domain/repositories/profile_repository.dart';

/// Fakes for the profile feature's controllers: a scripted session, and
/// repositories that record calls and answer from queues.

const User testUser = User(
  id: 'user-1',
  firstName: 'Anita',
  lastName: 'Menon',
  email: 'anita@example.com',
  phoneE164: '+919705571090',
  hasPassword: true,
  version: 2,
  gender: 'female',
  allergies: <String>[],
  profileVersion: 2,
);

/// A network-shaped [CachedResult].
CachedResult<T> fresh<T>(T value) => CachedResult<T>(
  value: value,
  source: CacheSource.network,
  cachedAt: DateTime.now(),
);

/// Only the members the controllers under test reach; everything else
/// throws through [noSuchMethod], which is what we want — an unexpected auth
/// call in a profile test is a bug.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.user = testUser});

  User? user;
  int fetchMeCalls = 0;
  OtpChallenge? nextResend;

  @override
  Future<User?> currentUser() async => user;

  @override
  Future<bool> hasValidSession() async => user != null;

  @override
  Future<String?> accessToken() async => user == null ? null : 'token';

  @override
  Future<User> fetchMe() async {
    fetchMeCalls++;
    final u = user;
    if (u == null) throw const UnauthorizedFailure();
    return u;
  }

  @override
  Future<DateTime?> lockedUntil({String? identifier}) async => null;

  @override
  Future<String?> lockedIdentifier() async => null;

  @override
  Future<void> clearLockout() async {}

  @override
  Future<void> clearLocalSession() async => user = null;

  @override
  Future<OtpChallenge> resendOtp({required String challengeId}) async =>
      nextResend ??
      OtpChallenge(
        challengeId: 'resent-$challengeId',
        codeLength: 4,
        expiresAt: DateTime.now().add(const Duration(minutes: 3)),
        resendAfterSeconds: 30,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeAuthRepository: ${invocation.memberName}');
}

class FakeProfileRepository implements ProfileRepository {
  final List<String> calls = <String>[];
  final List<ProfileUpdate> updates = <ProfileUpdate>[];
  final List<int> ifMatches = <int>[];
  final List<String> idempotencyKeys = <String>[];

  /// Thrown by the next mutation, then cleared.
  Failure? nextFailure;
  User Function(ProfileUpdate update)? onUpdate;
  List<Consent> consentRows = const <Consent>[];
  List<DeletionRequest> deletionRows = const <DeletionRequest>[];
  List<AccountSession> sessionRows = const <AccountSession>[];
  List<DataExportRequest> exportRows = const <DataExportRequest>[];

  Future<T> _answer<T>(String call, T Function() value) async {
    calls.add(call);
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
    return value();
  }

  @override
  Stream<CachedResult<List<DataExportRequest>>> dataExports({
    bool forceRefresh = false,
  }) => Stream.value(fresh(exportRows));

  @override
  Future<DataExportRequest> requestDataExport({
    required String idempotencyKey,
  }) {
    idempotencyKeys.add(idempotencyKey);
    return _answer(
      'requestDataExport',
      () => DataExportRequest(
        id: 'dsr-new',
        requestNo: 'DSR-2026-0002',
        status: DataExportStatus.requested,
        requestedAt: DateTime.utc(2026, 10, 1, 13),
        dueAt: DateTime.utc(2026, 10, 31, 13),
      ),
    );
  }

  @override
  Future<DataExportLink> dataExportLink(String id) => _answer(
    'dataExportLink:$id',
    () => DataExportLink(
      url: 'https://files.example/$id.zip',
      requestNo: 'DSR-2026-0001',
    ),
  );

  /// When set, a profile save waits for it — a request still in the air.
  Future<void>? holdUpdate;

  @override
  Future<User> updateProfile(
    ProfileUpdate update, {
    required int ifMatch,
  }) async {
    updates.add(update);
    ifMatches.add(ifMatch);
    final hold = holdUpdate;
    if (hold != null) await hold;
    return _answer('updateProfile', () {
      final builder = onUpdate;
      if (builder != null) return builder(update);
      return testUser.copyWith(
        firstName: update.firstName,
        lastName: update.lastName,
        version: ifMatch + 1,
      );
    });
  }

  @override
  Future<OtpChallenge> startPhoneChange({required String newPhoneE164}) =>
      _answer(
        'startPhoneChange',
        () => _challenge('old-challenge', '+91******90'),
      );

  @override
  Future<OtpChallenge> confirmOldPhone({
    required String challengeId,
    required String code,
  }) => _answer(
    'confirmOldPhone:$challengeId:$code',
    () => _challenge('new-challenge', '+91******78'),
  );

  @override
  Future<User> verifyNewPhone({
    required String challengeId,
    required String code,
  }) => _answer(
    'verifyNewPhone:$challengeId:$code',
    () => testUser.copyWith(phoneE164: '+919812345678', version: 3),
  );

  @override
  Future<User> setAlternatePhone({required String phoneE164}) => _answer(
    'setAlternatePhone',
    () => testUser.copyWith(alternatePhoneE164: phoneE164, version: 3),
  );

  @override
  Future<User> removeAlternatePhone() => _answer(
    'removeAlternatePhone',
    () => testUser.copyWith(clearAlternatePhone: true, version: 3),
  );

  @override
  Future<DeletionRequest> requestDeletion({
    String? reason,
    required String idempotencyKey,
  }) {
    idempotencyKeys.add(idempotencyKey);
    return _answer(
      'requestDeletion',
      () => DeletionRequest(
        requestNo: 'DSR-2026-000001',
        status: DeletionStatus.coolingOff,
        requestedAt: DateTime.now(),
        coolingOffEndsAt: DateTime.now().add(const Duration(days: 30)),
      ),
    );
  }

  @override
  Stream<CachedResult<List<DeletionRequest>>> deletionRequests({
    bool forceRefresh = false,
  }) => Stream.value(fresh(deletionRows));

  @override
  Future<DeletionRequest> withdrawDeletion(String requestNo) => _answer(
    'withdrawDeletion:$requestNo',
    () => DeletionRequest(
      requestNo: requestNo,
      status: DeletionStatus.withdrawn,
      requestedAt: DateTime.now(),
    ),
  );

  @override
  Future<User> reactivate() =>
      _answer('reactivate', () => testUser.copyWith(version: 4));

  @override
  Stream<CachedResult<List<Consent>>> consents({bool forceRefresh = false}) =>
      Stream.value(fresh(consentRows));

  @override
  Future<Consent> acceptConsent({
    required String documentSlug,
    required int documentVersion,
  }) => _answer(
    'acceptConsent:$documentSlug:$documentVersion',
    () => Consent(
      id: 'consent-$documentSlug-$documentVersion',
      documentSlug: documentSlug,
      documentVersion: documentVersion,
      acceptedAt: DateTime.now(),
    ),
  );

  @override
  Stream<CachedResult<List<AccountSession>>> sessions({
    bool forceRefresh = false,
  }) => Stream.value(fresh(sessionRows));

  @override
  Future<void> revokeSession(String sessionId) =>
      _answer('revokeSession:$sessionId', () {});

  static OtpChallenge _challenge(String id, String masked) => OtpChallenge(
    challengeId: id,
    codeLength: 4,
    expiresAt: DateTime.now().add(const Duration(minutes: 3)),
    resendAfterSeconds: 30,
    destinationMasked: masked,
  );
}

class FakeFamilyRepository implements FamilyRepository {
  FakeFamilyRepository({this.rows = const <Person>[]});

  List<Person> rows;
  final List<String> calls = <String>[];
  final List<PersonDraft> drafts = <PersonDraft>[];
  final List<int> ifMatches = <int>[];
  final List<String> idempotencyKeys = <String>[];
  Failure? nextFailure;
  int nextId = 1;

  Future<T> _answer<T>(String call, T Function() value) async {
    calls.add(call);
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
    return value();
  }

  @override
  Stream<CachedResult<List<Person>>> persons({bool forceRefresh = false}) =>
      Stream.value(fresh(rows));

  @override
  Future<Person> create(PersonDraft draft) {
    drafts.add(draft);
    return _answer(
      'create',
      () => Person(
        id: 'person-${nextId++}',
        firstName: draft.firstName ?? '',
        lastName: draft.lastName,
        relation: draft.relation ?? PersonRelation.other,
        dateOfBirth: draft.dateOfBirth,
        gender: draft.gender,
        bloodGroup: draft.bloodGroup,
        allergies: draft.allergies ?? const <String>[],
        phoneE164: draft.phoneE164,
      ),
    );
  }

  @override
  Future<Person> update(String id, PersonDraft draft, {required int ifMatch}) {
    drafts.add(draft);
    ifMatches.add(ifMatch);
    return _answer('update:$id', () {
      final current = rows.firstWhere((p) => p.id == id);
      return Person(
        id: id,
        firstName: draft.firstName ?? current.firstName,
        lastName: draft.lastName ?? current.lastName,
        relation: draft.relation ?? current.relation,
        dateOfBirth: draft.dateOfBirth ?? current.dateOfBirth,
        gender: draft.gender ?? current.gender,
        bloodGroup: draft.bloodGroup ?? current.bloodGroup,
        allergies: draft.allergies ?? current.allergies,
        phoneE164: draft.phoneE164 ?? current.phoneE164,
        version: ifMatch + 1,
      );
    });
  }

  @override
  Future<void> delete(String id) => _answer('delete:$id', () {});

  @override
  Future<OtpChallenge> startRelease({
    required String personId,
    required String phoneE164,
    required String idempotencyKey,
  }) {
    idempotencyKeys.add(idempotencyKey);
    return _answer(
      'startRelease:$personId',
      () => OtpChallenge(
        challengeId: 'release-challenge',
        codeLength: 4,
        expiresAt: DateTime.now().add(const Duration(minutes: 3)),
        resendAfterSeconds: 30,
        destinationMasked: '+91******78',
      ),
    );
  }

  @override
  Future<ReleaseResult> verifyRelease({
    required String personId,
    required String challengeId,
    required String code,
  }) => _answer(
    'verifyRelease:$personId:$challengeId:$code',
    () => ReleaseResult(
      personId: personId,
      userId: 'new-user',
      moved: const {'appointments': 2},
    ),
  );
}

class FakeContactsRepository implements ContactsRepository {
  List<Address> addressRows = const <Address>[];
  List<EmergencyContact> contactRows = const <EmergencyContact>[];
  final List<String> calls = <String>[];
  final List<int> ifMatches = <int>[];
  Failure? nextFailure;

  Future<T> _answer<T>(String call, T Function() value) async {
    calls.add(call);
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw failure;
    }
    return value();
  }

  @override
  Stream<CachedResult<List<Address>>> addresses({bool forceRefresh = false}) =>
      Stream.value(fresh(addressRows));

  @override
  Future<Address> createAddress(AddressDraft draft) => _answer(
    'createAddress',
    () => Address(
      id: 'addr-${calls.length}',
      label: draft.label,
      addressLine1: draft.addressLine1,
      city: draft.city,
      state: draft.state,
      pincode: draft.pincode,
      isDefault: draft.isDefault || addressRows.isEmpty,
    ),
  );

  @override
  Future<Address> updateAddress(
    String id,
    AddressDraft draft, {
    required int ifMatch,
  }) {
    ifMatches.add(ifMatch);
    return _answer(
      'updateAddress:$id',
      () => Address(
        id: id,
        label: draft.label,
        addressLine1: draft.addressLine1,
        city: draft.city,
        state: draft.state,
        pincode: draft.pincode,
        isDefault: addressRows.firstWhere((a) => a.id == id).isDefault,
        version: ifMatch + 1,
      ),
    );
  }

  @override
  Future<Address> setDefaultAddress(String id) => _answer(
    'setDefaultAddress:$id',
    () => addressRows.firstWhere((a) => a.id == id).copyWith(isDefault: true),
  );

  @override
  Future<void> deleteAddress(String id) => _answer('deleteAddress:$id', () {});

  @override
  Stream<CachedResult<List<EmergencyContact>>> emergencyContacts({
    bool forceRefresh = false,
  }) => Stream.value(fresh(contactRows));

  @override
  Future<EmergencyContact> createContact(ContactDraft draft) => _answer(
    'createContact',
    () => EmergencyContact(
      id: 'contact-${calls.length}',
      name: draft.name,
      relation: draft.relation,
      phoneE164: draft.phoneE164,
      isPrimary: draft.isPrimary || contactRows.isEmpty,
    ),
  );

  @override
  Future<EmergencyContact> updateContact(
    String id,
    ContactDraft draft, {
    required int ifMatch,
  }) {
    ifMatches.add(ifMatch);
    return _answer(
      'updateContact:$id',
      () => EmergencyContact(
        id: id,
        name: draft.name,
        relation: draft.relation,
        phoneE164: draft.phoneE164,
        isPrimary: contactRows.firstWhere((c) => c.id == id).isPrimary,
        version: ifMatch + 1,
      ),
    );
  }

  @override
  Future<EmergencyContact> setPrimaryContact(String id) => _answer(
    'setPrimaryContact:$id',
    () => contactRows.firstWhere((c) => c.id == id).copyWith(isPrimary: true),
  );

  @override
  Future<void> deleteContact(String id) => _answer('deleteContact:$id', () {});
}

/// A container with the fakes installed and the session already restored
/// to [FakeAuthRepository.user].
Future<ProviderContainer> authenticatedContainer({
  required FakeAuthRepository auth,
  FakeProfileRepository? profile,
  FakeFamilyRepository? family,
  FakeContactsRepository? contacts,
}) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      profileRepositoryProvider.overrideWithValue(
        profile ?? FakeProfileRepository(),
      ),
      familyRepositoryProvider.overrideWithValue(
        family ?? FakeFamilyRepository(),
      ),
      contactsRepositoryProvider.overrideWithValue(
        contacts ?? FakeContactsRepository(),
      ),
    ],
  );
  await container.read(authProvider.notifier).restore();
  // Let the background /me refresh settle.
  await Future<void>.delayed(Duration.zero);
  return container;
}

/// Holds an `autoDispose` provider alive for the test's lifetime, the way a
/// watching screen would; without a listener a bare `read` disposes it at
/// once and the next read sees a fresh loading state.
void keepAlive(
  ProviderContainer container,
  ProviderListenable<Object?> provider,
) {
  container.listen<Object?>(provider, (_, _) {});
}

/// Pumps the microtask queue a few times so stream-fed controllers settle.
Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
