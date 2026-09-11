/// The **one** token scheme (`CANONICAL_MASTER_DATA` §5).
///
/// The hospital console issues a hospital-wide running token zero-padded to
/// three digits — `T-001`, `T-025`, `T-142` — while the patient app minted and
/// displayed `A-25`. Same queue, two spellings, so a patient comparing their
/// phone with the waiting-room screen saw different tokens.
///
/// This is the single formatter for the mobile side. It also *normalises* the
/// legacy shape, because the seeded appointments and the seeded
/// `QueueStatus.currentToken` still carry `A-NN` strings (they live in the
/// frozen core layer): [normalize] renders `A-25` as `T-025` without rewriting
/// the stored value, so the display is canonical today and the storage can
/// follow when the API lands.
abstract final class AppointmentToken {
  AppointmentToken._();

  /// The canonical prefix.
  static const String prefix = 'T';

  /// Digits the sequence is padded to.
  static const int padding = 3;

  /// `AppointmentToken.format(25)` → `'T-025'`.
  static String format(int sequence) =>
      '$prefix-${sequence.toString().padLeft(padding, '0')}';

  /// The numeric sequence inside any token label (`'A-25'` → 25), or null when
  /// there is no number to read — in which case callers must show the raw
  /// label rather than guess.
  static int? sequenceOf(String label) {
    final digits = RegExp(r'\d+').firstMatch(label)?.group(0);
    if (digits == null) return null;
    return int.tryParse(digits);
  }

  /// [label] in the canonical shape, or the label untouched when it carries no
  /// sequence (never invent a token).
  static String normalize(String label) {
    final sequence = sequenceOf(label);
    return sequence == null ? label.trim() : format(sequence);
  }
}
