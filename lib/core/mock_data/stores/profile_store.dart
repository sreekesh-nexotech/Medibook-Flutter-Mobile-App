import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../medibook_seed.dart';
import '../models/support_content.dart';

/// Owns the account's emergency contacts (CM-49).
///
/// **Why this is a shared store:** Profile → Emergency Contacts edits the list,
/// and the ambulance/emergency screen (CM-44 … CM-46) reads it so it can offer
/// "call Michael" beside "call 108". Two features, one list.
///
/// Exactly one contact may be primary; [setPrimary] and [add] maintain that,
/// so no screen has to.
class EmergencyContactsStore extends Notifier<List<EmergencyContact>> {
  @override
  List<EmergencyContact> build() => MedibookSeed.emergencyContacts;

  /// The contact to call first, or null when the list is empty.
  EmergencyContact? get primary {
    for (final contact in state) {
      if (contact.isPrimary) return contact;
    }
    return state.isEmpty ? null : state.first;
  }

  EmergencyContact? byId(String id) {
    for (final contact in state) {
      if (contact.id == id) return contact;
    }
    return null;
  }

  /// Add a contact. The first contact added is automatically primary.
  EmergencyContact add({
    required String name,
    required String relation,
    required String phone,
    bool isPrimary = false,
  }) {
    final makePrimary = isPrimary || state.isEmpty;
    final contact = EmergencyContact(
      id: 'ec-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      relation: relation,
      phone: phone,
      isPrimary: makePrimary,
    );
    state = [
      if (makePrimary)
        for (final c in state) c.copyWith(isPrimary: false)
      else
        ...state,
      contact,
    ];
    return contact;
  }

  void patch(String id, {String? name, String? relation, String? phone}) {
    state = [
      for (final c in state)
        if (c.id == id)
          c.copyWith(name: name, relation: relation, phone: phone)
        else
          c,
    ];
  }

  /// Make [id] the primary contact, demoting the previous one.
  void setPrimary(String id) {
    if (byId(id) == null) return;
    state = [for (final c in state) c.copyWith(isPrimary: c.id == id)];
  }

  /// Remove a contact; promotes the first remaining one if the primary went.
  ///
  /// Returns false for an unknown id, so the caller does not report success.
  bool remove(String id) {
    final contact = byId(id);
    if (contact == null) return false;
    final remaining = state.where((c) => c.id != id).toList();
    if (contact.isPrimary && remaining.isNotEmpty) {
      remaining[0] = remaining.first.copyWith(isPrimary: true);
    }
    state = remaining;
    return true;
  }
}

/// Owns the account's saved addresses (CM-50).
///
/// **Why this is a shared store:** Profile edits them, and the booking flow
/// reads them when a home sample collection needs a destination.
///
/// Exactly one address may be the default; [setDefault] and [add] maintain it.
class AddressesStore extends Notifier<List<Address>> {
  @override
  List<Address> build() => MedibookSeed.addresses;

  /// The address used unless another is chosen, or null when there are none.
  Address? get defaultAddress {
    for (final address in state) {
      if (address.isDefault) return address;
    }
    return state.isEmpty ? null : state.first;
  }

  Address? byId(String id) {
    for (final address in state) {
      if (address.id == id) return address;
    }
    return null;
  }

  /// Add an address. The first one added becomes the default.
  Address add({
    required String label,
    required String line1,
    required String city,
    required String stateName,
    required String pincode,
    String? line2,
    bool isDefault = false,
  }) {
    final makeDefault = isDefault || state.isEmpty;
    final address = Address(
      id: 'addr-${DateTime.now().microsecondsSinceEpoch}',
      label: label,
      line1: line1,
      line2: line2,
      city: city,
      state: stateName,
      pincode: pincode,
      isDefault: makeDefault,
    );
    state = [
      if (makeDefault)
        for (final a in state) a.copyWith(isDefault: false)
      else
        ...state,
      address,
    ];
    return address;
  }

  void update(Address address) {
    state = [
      for (final a in state)
        if (a.id == address.id) address else a,
    ];
  }

  /// Make [id] the default address.
  void setDefault(String id) {
    if (byId(id) == null) return;
    state = [for (final a in state) a.copyWith(isDefault: a.id == id)];
  }

  /// Remove an address; promotes the first remaining one if the default went.
  bool remove(String id) {
    final address = byId(id);
    if (address == null) return false;
    final remaining = state.where((a) => a.id != id).toList();
    if (address.isDefault && remaining.isNotEmpty) {
      remaining[0] = remaining.first.copyWith(isDefault: true);
    }
    state = remaining;
    return true;
  }
}

/// The account's emergency contacts. Not autoDispose — Profile and the
/// emergency screen both read it.
final emergencyContactsStoreProvider =
    NotifierProvider<EmergencyContactsStore, List<EmergencyContact>>(
      EmergencyContactsStore.new,
    );

/// The contact to call first (CM-45), or null.
final primaryEmergencyContactProvider = Provider<EmergencyContact?>((ref) {
  final contacts = ref.watch(emergencyContactsStoreProvider);
  if (contacts.isEmpty) return null;
  for (final contact in contacts) {
    if (contact.isPrimary) return contact;
  }
  return contacts.first;
});

/// The account's saved addresses. Not autoDispose — Profile and booking both
/// read it.
final addressesStoreProvider = NotifierProvider<AddressesStore, List<Address>>(
  AddressesStore.new,
);

/// The default address, or null when none is saved.
final defaultAddressProvider = Provider<Address?>((ref) {
  final addresses = ref.watch(addressesStoreProvider);
  if (addresses.isEmpty) return null;
  for (final address in addresses) {
    if (address.isDefault) return address;
  }
  return addresses.first;
});
