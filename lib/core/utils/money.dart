import 'package:intl/intl.dart';

/// An exact money amount, stored in **minor units** (paise for INR).
///
/// Audit §3.8.2: fees used to be display strings (`Doctor.fee == '₹900'`), so
/// nothing could add a consultation fee to a tax to a convenience fee. [Money]
/// is the fix — it is an integer under the hood, so it is *totalable*,
/// *comparable* and *roundable* with no floating-point drift, and it renders
/// itself only at the edge ([format] / [Money.inr]).
///
/// Never build a money value from a `double` count of rupees except through
/// [Money.rupees], which rounds once, deliberately.
///
/// ```dart
/// final fee = Money.paise(90000);      // ₹900
/// final tax = fee.percent(18);         // ₹162
/// final total = fee + tax;             // ₹1,062
/// total.format();                      // '₹1,062'
/// ```
class Money implements Comparable<Money> {
  /// Primary constructor — [paise] is the amount in minor units.
  const Money.paise(this.paise);

  /// From whole (or fractional) rupees. Rounds to the nearest paisa.
  factory Money.rupees(num rupees) => Money.paise((rupees * 100).round());

  /// Parses a display string back into a [Money] (`'₹1,062.50'` → 106250 p).
  ///
  /// Tolerant of the currency symbol, grouping separators and whitespace.
  /// Returns null when nothing numeric can be found, so callers can tell
  /// "unparseable" apart from "zero".
  static Money? tryParse(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (cleaned.isEmpty) return null;
    final rupees = double.tryParse(cleaned);
    if (rupees == null) return null;
    return Money.rupees(rupees);
  }

  /// The amount in paise. Always an exact integer.
  final int paise;

  /// A zero amount — the identity for [+] and the seed for [total].
  static const Money zero = Money.paise(0);

  /// Whole-rupee part (truncated toward zero).
  int get rupeePart => paise ~/ 100;

  /// Paise remainder, 0-99.
  int get paisePart => paise.remainder(100).abs();

  bool get isZero => paise == 0;
  bool get isNegative => paise < 0;

  Money operator +(Money other) => Money.paise(paise + other.paise);
  Money operator -(Money other) => Money.paise(paise - other.paise);

  /// Scale by a count or factor (`fee * 3`). Rounds once, at the end.
  Money operator *(num factor) => Money.paise((paise * factor).round());

  Money operator -() => Money.paise(-paise);

  bool operator <(Money other) => paise < other.paise;
  bool operator <=(Money other) => paise <= other.paise;
  bool operator >(Money other) => paise > other.paise;
  bool operator >=(Money other) => paise >= other.paise;

  /// [percentage]% of this amount (`Money.rupees(900).percent(18)` → ₹162).
  Money percent(num percentage) =>
      Money.paise((paise * percentage / 100).round());

  /// This amount reduced by [percentage]% (a discount).
  Money lessPercent(num percentage) => this - percent(percentage);

  /// Clamped subtraction — never goes below zero (discounts, refunds).
  Money minusFloored(Money other) {
    final result = paise - other.paise;
    return result < 0 ? zero : Money.paise(result);
  }

  /// Splits into [parts] amounts that sum back to exactly this value; the
  /// leftover paise are spread over the leading entries.
  List<Money> splitInto(int parts) {
    assert(parts > 0, 'parts must be positive');
    final base = paise ~/ parts;
    var remainder = paise.remainder(parts);
    return List<Money>.generate(parts, (_) {
      final extra = remainder > 0 ? 1 : 0;
      if (remainder > 0) remainder--;
      return Money.paise(base + extra);
    });
  }

  /// `₹1,062` — or `₹1,062.50` when paise are non-zero, unless
  /// [alwaysShowPaise] forces two decimals.
  String format({bool alwaysShowPaise = false}) =>
      Money.inr(paise, alwaysShowPaise: alwaysShowPaise);

  /// The canonical INR renderer used across the app.
  ///
  /// Uses `NumberFormat.currency(locale: 'en_IN', symbol: '₹')`, so grouping
  /// follows the Indian lakh/crore convention (`₹1,00,000`). Paise are hidden
  /// when they are zero, because every price in the catalogue is a whole rupee
  /// and `₹900.00` reads as noise.
  static String inr(int paise, {bool alwaysShowPaise = false}) {
    final showPaise = alwaysShowPaise || paise.remainder(100) != 0;
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: showPaise ? 2 : 0,
    );
    return formatter.format(paise / 100);
  }

  /// Sum of [amounts] — the operation the old string fees made impossible.
  static Money total(Iterable<Money> amounts) =>
      amounts.fold(zero, (sum, amount) => sum + amount);

  @override
  int compareTo(Money other) => paise.compareTo(other.paise);

  @override
  bool operator ==(Object other) => other is Money && other.paise == paise;

  @override
  int get hashCode => paise.hashCode;

  @override
  String toString() => format();
}

/// Aggregation helpers for money sequences.
extension MoneyIterable on Iterable<Money> {
  /// Total of the sequence.
  Money get sum => Money.total(this);

  /// Ascending (or [descending]) copy, sorted by value.
  List<Money> sortedByValue({bool descending = false}) {
    final list = toList()
      ..sort((a, b) => descending ? b.compareTo(a) : a.compareTo(b));
    return list;
  }
}
