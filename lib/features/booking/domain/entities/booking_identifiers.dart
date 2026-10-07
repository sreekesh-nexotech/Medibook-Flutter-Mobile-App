/// Token label helpers.
///
/// Every identifier the patient sees — the booking reference
/// (`MB-2026-000124`) and the token label (`T-026`) — is minted by the
/// backend at booking time (§9.1) and each hospital sets its own format
/// (§1.11), so the app treats both as **opaque text**: it never generates,
/// pads or re-spells one. What remains here is the one read-only helper the
/// live-queue card uses to count positions.
abstract final class AppTokens {
  AppTokens._();

  /// The canonical prefix the platform uses by default.
  static const String prefix = 'T-';

  /// Digits the default scheme pads to.
  static const int padTo = 3;

  /// `T-001` for 1 — only for labels the backend did not supply.
  static String format(int sequence) =>
      '$prefix${sequence.toString().padLeft(padTo, '0')}';

  /// A label exactly as the backend sent it, trimmed. Kept so callers that
  /// used to "normalise" tokens compile unchanged; hospital formats are
  /// opaque, so nothing is rewritten.
  static String normalize(String token) => token.trim();

  /// The numeric part of [token], or null when it has none. Used to work out
  /// how many patients are ahead of you in the queue.
  static int? sequenceOf(String token) {
    final match = RegExp(r'(\d+)$').firstMatch(token.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }
}
