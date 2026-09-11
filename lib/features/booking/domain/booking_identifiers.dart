import '../../../core/mock_data/medibook_seed.dart';

/// Canonical token formatting (CANONICAL_MASTER_DATA §5, CM-14).
///
/// Both applications now use **one** scheme: a hospital-wide running token,
/// zero-padded to three digits — `T-001`, `T-025`, `T-142`. The mobile app's
/// old `A-25` shape is retired.
///
/// The token is **not** an identifier. It is the queue position for one day at
/// one desk, so it repeats every morning and two patients on different days
/// share it. The permanent identifier is the booking reference
/// ([BookingRefs]), which is what appointment search matches on (CM-30).
///
/// [normalize] exists because the seeded appointments and
/// `AppointmentsController.book()` still mint the legacy `A-n` label — both
/// live outside this feature. Rendering through [normalize] means every screen
/// in the booking / payment / discovery funnel shows the canonical shape today,
/// and keeps showing it unchanged once the minting side catches up.
abstract final class AppTokens {
  AppTokens._();

  /// The canonical prefix.
  static const String prefix = 'T-';

  /// Digits the sequence is padded to.
  static const int padTo = 3;

  /// `T-001` for 1, `T-142` for 142.
  static String format(int sequence) =>
      '$prefix${sequence.toString().padLeft(padTo, '0')}';

  /// Re-renders any token label in the canonical shape: `A-25` → `T-025`,
  /// `T-9` → `T-009`, `T-025` → `T-025`.
  ///
  /// Returns [token] untouched when it carries no trailing number, so an
  /// unexpected label is passed through rather than mangled into `T-000`.
  static String normalize(String token) {
    final trimmed = token.trim();
    final match = RegExp(r'(\d+)$').firstMatch(trimmed);
    if (match == null) return trimmed;
    final sequence = int.tryParse(match.group(1)!);
    return sequence == null ? trimmed : format(sequence);
  }

  /// The numeric part of [token], or null when it has none. Used to work out
  /// how many patients are ahead of you in the queue (CM-09).
  static int? sequenceOf(String token) {
    final match = RegExp(r'(\d+)$').firstMatch(token.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }
}

/// Booking-reference formatting (CANONICAL_MASTER_DATA §6, CM-14).
///
/// `MB-<year>-<6-digit sequence>` → `MB-2026-000124`. Minted once, when the
/// slot is held (see `BookingRecordsController.reserveReference`), so the
/// reference can be shown on the summary *before* payment — which is what the
/// patient reads out on the phone if something goes wrong mid-payment.
abstract final class BookingRefs {
  BookingRefs._();

  /// Where this build's sequence continues from. The seeded appointments
  /// occupy `…000074` … `…000124`, so a new booking starts at 125 and the
  /// references on screen never collide with the seed.
  static const int firstSequence = 125;

  /// Formats [sequence] through the one shared rule.
  static String format(int sequence) => MedibookSeed.bookingRef(sequence);
}
