/// A saved address (§6.2) — structured lines, one default per account.
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.addressLine1,
    required this.city,
    required this.state,
    required this.pincode,
    this.addressLine2,
    this.addressLine3,
    this.phoneE164,
    this.isDefault = false,
    this.version = 1,
    this.createdAt,
  });

  final String id;
  final String label;
  final String addressLine1;
  final String? addressLine2;
  final String? addressLine3;
  final String city;
  final String state;

  /// `^[1-9][0-9]{5}$`.
  final String pincode;
  final String? phoneE164;

  /// Exactly one address holds this; set with `POST /{id}/default`.
  final bool isDefault;

  /// Row version — `If-Match` on PATCH (§1.9).
  final int version;
  final DateTime? createdAt;

  /// The lines as written on a parcel, blanks dropped.
  List<String> get lines => [
    addressLine1,
    if (addressLine2 != null && addressLine2!.trim().isNotEmpty) addressLine2!,
    if (addressLine3 != null && addressLine3!.trim().isNotEmpty) addressLine3!,
    '$city, $state $pincode',
  ];

  String get singleLine => lines.join(', ');

  Address copyWith({bool? isDefault}) => Address(
    id: id,
    label: label,
    addressLine1: addressLine1,
    addressLine2: addressLine2,
    addressLine3: addressLine3,
    city: city,
    state: state,
    pincode: pincode,
    phoneE164: phoneE164,
    isDefault: isDefault ?? this.isDefault,
    version: version,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Address &&
      other.id == id &&
      other.label == label &&
      other.addressLine1 == addressLine1 &&
      other.addressLine2 == addressLine2 &&
      other.addressLine3 == addressLine3 &&
      other.city == city &&
      other.state == state &&
      other.pincode == pincode &&
      other.phoneE164 == phoneE164 &&
      other.isDefault == isDefault &&
      other.version == version;

  @override
  int get hashCode => Object.hash(
    id,
    label,
    addressLine1,
    addressLine2,
    addressLine3,
    city,
    state,
    pincode,
    phoneE164,
    isDefault,
    version,
  );

  @override
  String toString() => 'Address($id)';
}

/// What `POST`/`PATCH /patient/me/addresses` takes. `isDefault` is honoured on
/// POST only — on PATCH the server ignores it (§6.2), so the repository uses
/// the separate default call.
class AddressDraft {
  const AddressDraft({
    required this.label,
    required this.addressLine1,
    required this.city,
    required this.state,
    required this.pincode,
    this.addressLine2,
    this.addressLine3,
    this.phoneE164,
    this.isDefault = false,
  });

  final String label;
  final String addressLine1;
  final String? addressLine2;
  final String? addressLine3;
  final String city;
  final String state;
  final String pincode;
  final String? phoneE164;
  final bool isDefault;
}
