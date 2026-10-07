import '../../../../core/network/endpoints.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/storage/cache/cached_fetcher.dart';
import '../../domain/entities/address.dart';
import '../../domain/entities/emergency_contact.dart';
import '../../domain/repositories/contacts_repository.dart';
import '../data_sources/remote/contacts_api.dart';
import 'profile_mappers.dart';

/// [ContactsRepository] over [ContactsApi] + [CachedFetcher]. Every throw is
/// a `Failure`; every mutation invalidates the response cache.
class ContactsRepositoryImpl implements ContactsRepository {
  const ContactsRepositoryImpl({
    required ContactsApi api,
    required CachedFetcher fetcher,
  }) : _api = api,
       _fetcher = fetcher;

  final ContactsApi _api;
  final CachedFetcher _fetcher;

  // ---- Addresses ----

  @override
  Stream<CachedResult<List<Address>>> addresses({bool forceRefresh = false}) =>
      _fetcher
          .fetch(
            _api.addresses(),
            ProfileMappers.addresses,
            forceRefresh: forceRefresh,
          )
          .handleError(_rethrowAsFailure);

  @override
  Future<Address> createAddress(AddressDraft draft) => _mutate(
    () async => ProfileMappers.addressFromBody(await _api.createAddress(draft)),
    Endpoints.addresses,
  );

  @override
  Future<Address> updateAddress(
    String id,
    AddressDraft draft, {
    required int ifMatch,
  }) => _mutate(
    () async => ProfileMappers.addressFromBody(
      await _api.updateAddress(id, draft, ifMatch: ifMatch),
    ),
    Endpoints.addresses,
  );

  @override
  Future<Address> setDefaultAddress(String id) => _mutate(
    () async =>
        ProfileMappers.addressFromBody(await _api.setDefaultAddress(id)),
    Endpoints.addresses,
  );

  @override
  Future<void> deleteAddress(String id) =>
      _mutate(() => _api.deleteAddress(id), Endpoints.addresses);

  // ---- Emergency contacts ----

  @override
  Stream<CachedResult<List<EmergencyContact>>> emergencyContacts({
    bool forceRefresh = false,
  }) => _fetcher
      .fetch(
        _api.emergencyContacts(),
        ProfileMappers.contacts,
        forceRefresh: forceRefresh,
      )
      .handleError(_rethrowAsFailure);

  @override
  Future<EmergencyContact> createContact(ContactDraft draft) => _mutate(
    () async => ProfileMappers.contactFromBody(await _api.createContact(draft)),
    Endpoints.emergencyContacts,
  );

  @override
  Future<EmergencyContact> updateContact(
    String id,
    ContactDraft draft, {
    required int ifMatch,
  }) => _mutate(
    () async => ProfileMappers.contactFromBody(
      await _api.updateContact(id, draft, ifMatch: ifMatch),
    ),
    Endpoints.emergencyContacts,
  );

  @override
  Future<EmergencyContact> setPrimaryContact(String id) => _mutate(
    () async =>
        ProfileMappers.contactFromBody(await _api.setPrimaryContact(id)),
    Endpoints.emergencyContacts,
  );

  @override
  Future<void> deleteContact(String id) =>
      _mutate(() => _api.deleteContact(id), Endpoints.emergencyContacts);

  // ---- internals ----

  /// Runs a mutation, maps any error to a `Failure`, then invalidates.
  Future<T> _mutate<T>(Future<T> Function() request, String pathPrefix) async {
    final T result;
    try {
      result = await request();
    } catch (error, stackTrace) {
      throw NetworkExceptions.toFailure(error, stackTrace);
    }
    await _fetcher.invalidate(pathPrefix: pathPrefix);
    return result;
  }

  static void _rethrowAsFailure(Object error, StackTrace stackTrace) =>
      throw NetworkExceptions.toFailure(error, stackTrace);
}
