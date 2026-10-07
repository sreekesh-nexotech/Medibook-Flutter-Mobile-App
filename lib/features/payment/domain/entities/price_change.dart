/// A difference between the total the patient was shown when they confirmed
/// the booking and the total the booking actually costs.
///
/// The confirm step shows the fee *quote*; the payment screen charges the
/// booking's own fee snapshot, which the hospital prices for the appointment
/// date. When the two differ the patient must be told, and must agree to the
/// new amount, before any money moves (owner decision, BL-BOOK-035).
class PriceChange {
  const PriceChange._({required this.quotedPaise, required this.duePaise});

  /// The total shown on the confirm step.
  final int quotedPaise;

  /// The total the payment will charge.
  final int duePaise;

  /// True when the booking costs more than the patient was shown.
  bool get isIncrease => duePaise > quotedPaise;

  /// The change to tell the patient about, or null when there is none.
  ///
  /// [quotedPaise] is null when no quote was shown in this session — a
  /// booking opened again from Appointments — so there is nothing to compare.
  static PriceChange? between({
    required int? quotedPaise,
    required int duePaise,
  }) {
    if (quotedPaise == null || quotedPaise == duePaise) return null;
    return PriceChange._(quotedPaise: quotedPaise, duePaise: duePaise);
  }
}
