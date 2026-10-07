import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/endpoints.dart';
import '../../../domain/entities/address.dart';
import '../../../domain/entities/emergency_contact.dart';

/// Addresses (§6.2) and emergency contacts (§6.3). HTTP only.
abstract interface class ContactsApi {
  ApiRequest addresses();
  Future<Map<String, Object?>> createAddress(AddressDraft draft);
  Future<Map<String, Object?>> updateAddress(
    String id,
    AddressDraft draft, {
    required int ifMatch,
  });
  Future<Map<String, Object?>> setDefaultAddress(String id);
  Future<void> deleteAddress(String id);

  ApiRequest emergencyContacts();
  Future<Map<String, Object?>> createContact(ContactDraft draft);
  Future<Map<String, Object?>> updateContact(
    String id,
    ContactDraft draft, {
    required int ifMatch,
  });
  Future<Map<String, Object?>> setPrimaryContact(String id);
  Future<void> deleteContact(String id);
}

class HttpContactsApi implements ContactsApi {
  const HttpContactsApi(this._client);

  final ApiClient _client;

  // ---- Addresses ----

  @override
  ApiRequest addresses() =>
      const ApiRequest(path: Endpoints.addresses, query: {'page_size': 100});

  @override
  Future<Map<String, Object?>> createAddress(AddressDraft draft) async {
    final response = await _client.post(
      Endpoints.addresses,
      body: {..._addressBody(draft), 'is_default': draft.isDefault},
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> updateAddress(
    String id,
    AddressDraft draft, {
    required int ifMatch,
  }) async {
    final response = await _client.patch(
      Endpoints.address(id),
      body: _addressBody(draft),
      ifMatch: ifMatch,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> setDefaultAddress(String id) async {
    final response = await _client.post(Endpoints.addressDefault(id));
    return response.requireMap;
  }

  @override
  Future<void> deleteAddress(String id) =>
      _client.delete(Endpoints.address(id));

  static Map<String, Object?> _addressBody(AddressDraft draft) => {
    'label': draft.label,
    'address_line1': draft.addressLine1,
    'address_line2': _nullIfBlank(draft.addressLine2),
    'address_line3': _nullIfBlank(draft.addressLine3),
    'city': draft.city,
    'state': draft.state,
    'pincode': draft.pincode,
    'phone_e164': _nullIfBlank(draft.phoneE164),
  };

  // ---- Emergency contacts ----

  @override
  ApiRequest emergencyContacts() => const ApiRequest(
    path: Endpoints.emergencyContacts,
    query: {'page_size': 100},
  );

  @override
  Future<Map<String, Object?>> createContact(ContactDraft draft) async {
    final response = await _client.post(
      Endpoints.emergencyContacts,
      body: {..._contactBody(draft), 'is_primary': draft.isPrimary},
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> updateContact(
    String id,
    ContactDraft draft, {
    required int ifMatch,
  }) async {
    final response = await _client.patch(
      Endpoints.emergencyContact(id),
      body: _contactBody(draft),
      ifMatch: ifMatch,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> setPrimaryContact(String id) async {
    final response = await _client.post(Endpoints.emergencyContactPrimary(id));
    return response.requireMap;
  }

  @override
  Future<void> deleteContact(String id) =>
      _client.delete(Endpoints.emergencyContact(id));

  static Map<String, Object?> _contactBody(ContactDraft draft) => {
    'name': draft.name,
    'relation': draft.relation,
    'phone_e164': draft.phoneE164,
  };

  static String? _nullIfBlank(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
