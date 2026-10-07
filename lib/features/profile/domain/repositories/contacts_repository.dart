import '../../../../core/storage/cache/cached_result.dart';
import '../entities/address.dart';
import '../entities/emergency_contact.dart';

/// Saved addresses (§6.2) and emergency contacts (§6.3). The two follow the
/// same pattern — list / create / update-with-If-Match / delete / promote —
/// so they share a contract. Every throw is a `Failure`.
abstract interface class ContactsRepository {
  // ---- Addresses ----

  /// `GET /patient/me/addresses` — default first, cached.
  Stream<CachedResult<List<Address>>> addresses({bool forceRefresh = false});

  /// `POST /patient/me/addresses` → 201. The first address becomes the
  /// default automatically.
  Future<Address> createAddress(AddressDraft draft);

  /// `PATCH /patient/me/addresses/{id}` with `If-Match`. `isDefault` is
  /// ignored by the server here — use [setDefaultAddress].
  Future<Address> updateAddress(
    String id,
    AddressDraft draft, {
    required int ifMatch,
  });

  /// `POST /patient/me/addresses/{id}/default` → now the only default.
  Future<Address> setDefaultAddress(String id);

  /// `DELETE /patient/me/addresses/{id}` → 204.
  Future<void> deleteAddress(String id);

  // ---- Emergency contacts ----

  /// `GET /patient/me/emergency-contacts` — primary first, cached.
  Stream<CachedResult<List<EmergencyContact>>> emergencyContacts({
    bool forceRefresh = false,
  });

  /// `POST /patient/me/emergency-contacts` → 201. The first becomes primary.
  Future<EmergencyContact> createContact(ContactDraft draft);

  /// `PATCH …/{id}` with `If-Match`; `isPrimary` ignored — use
  /// [setPrimaryContact].
  Future<EmergencyContact> updateContact(
    String id,
    ContactDraft draft, {
    required int ifMatch,
  });

  /// `POST …/{id}/primary`.
  Future<EmergencyContact> setPrimaryContact(String id);

  /// `DELETE …/{id}` → 204.
  Future<void> deleteContact(String id);
}
