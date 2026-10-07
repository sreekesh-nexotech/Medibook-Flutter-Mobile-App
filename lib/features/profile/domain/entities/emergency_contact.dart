/// An emergency contact (§6.3) — who the hospital calls; one is primary.
class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.relation,
    required this.phoneE164,
    this.isPrimary = false,
    this.version = 1,
    this.createdAt,
  });

  final String id;
  final String name;

  /// Free text on the wire ("Husband", "Neighbour"), ≤ 50.
  final String relation;
  final String phoneE164;

  /// Exactly one contact holds this; set with `POST /{id}/primary`.
  final bool isPrimary;

  /// Row version — `If-Match` on PATCH (§1.9).
  final int version;
  final DateTime? createdAt;

  EmergencyContact copyWith({bool? isPrimary}) => EmergencyContact(
    id: id,
    name: name,
    relation: relation,
    phoneE164: phoneE164,
    isPrimary: isPrimary ?? this.isPrimary,
    version: version,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is EmergencyContact &&
      other.id == id &&
      other.name == name &&
      other.relation == relation &&
      other.phoneE164 == phoneE164 &&
      other.isPrimary == isPrimary &&
      other.version == version;

  @override
  int get hashCode =>
      Object.hash(id, name, relation, phoneE164, isPrimary, version);

  @override
  String toString() => 'EmergencyContact($id)';
}

/// What `POST`/`PATCH /patient/me/emergency-contacts` takes. `isPrimary` is
/// honoured on POST only (§6.3).
class ContactDraft {
  const ContactDraft({
    required this.name,
    required this.relation,
    required this.phoneE164,
    this.isPrimary = false,
  });

  final String name;
  final String relation;
  final String phoneE164;
  final bool isPrimary;
}
