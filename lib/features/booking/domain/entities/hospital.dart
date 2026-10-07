import 'department.dart';
import 'promo_banner.dart';

/// One row of `GET /patient/hospitals` (§7.2).
///
/// Domain entity: immutable, no JSON. [rating] is a decimal string or null
/// (§1.11); [distanceKm] is only set when the query carried `lat`/`lng`.
class HospitalCard {
  const HospitalCard({
    required this.id,
    required this.slug,
    required this.name,
    required this.city,
    required this.departments,
    required this.onlineBookingEnabled,
    this.area,
    this.rating,
    this.ratingCount = 0,
    this.distanceKm,
    this.nextAvailableAt,
    this.logoFileId,
    this.coverFileId,
  });

  final String id;
  final String slug;
  final String name;
  final String city;
  final String? area;
  final String? rating;
  final int ratingCount;
  final double? distanceKm;
  final List<DepartmentRef> departments;

  /// Earliest open slot across the hospital (UTC), or null.
  final DateTime? nextAvailableAt;
  final bool onlineBookingEnabled;
  final String? logoFileId;
  final String? coverFileId;

  /// "Kadavanthra, Kochi" / "Kochi".
  String get locationLabel => area == null ? city : '$area, $city';

  /// [rating] as a number for the star widget, or 0 when unrated.
  double get ratingValue => double.tryParse(rating ?? '') ?? 0;

  bool get hasRating => rating != null;

  /// Whether this facility offers the department [code].
  bool offers(String code) => departments.any((d) => d.code == code);
}

/// The hospital's postal address (§7.3).
class HospitalAddress {
  const HospitalAddress({
    required this.addressLine1,
    required this.city,
    required this.state,
    required this.pincode,
    this.addressLine2,
    this.addressLine3,
    this.phoneE164,
  });

  final String addressLine1;
  final String? addressLine2;
  final String? addressLine3;
  final String city;
  final String state;
  final String pincode;
  final String? phoneE164;

  /// The lines that exist, joined for a single label.
  String get oneLine => [
    addressLine1,
    if (addressLine2 != null && addressLine2!.isNotEmpty) addressLine2,
    if (addressLine3 != null && addressLine3!.isNotEmpty) addressLine3,
    city,
    pincode,
  ].join(', ');
}

/// One weekday row of the hospital's opening hours. `weekday` is 0 = Monday …
/// 6 = Sunday; times are hospital-local `HH:MM` strings.
class HospitalHours {
  const HospitalHours({
    required this.weekday,
    required this.isClosed,
    this.opensAt,
    this.closesAt,
  });

  final int weekday;
  final bool isClosed;
  final String? opensAt;
  final String? closesAt;
}

/// An upcoming holiday. [departmentId] null means the whole hospital.
class HospitalHoliday {
  const HospitalHoliday({
    required this.id,
    required this.name,
    required this.dateFrom,
    required this.dateTo,
    this.departmentId,
  });

  final String id;
  final String name;

  /// Hospital-local `YYYY-MM-DD`.
  final String dateFrom;
  final String dateTo;
  final String? departmentId;
}

/// The hospital's cancellation policy (§7.3). Rates are basis points.
class CancellationPolicy {
  const CancellationPolicy({
    required this.cutoffHours,
    required this.refundBeforeCutoffBp,
    required this.refundAfterCutoffBp,
    required this.refundIncludesConvenienceFee,
    required this.hospitalCancellationRefundBp,
    this.tokenCancelLimitMin,
  });

  final int cutoffHours;
  final int refundBeforeCutoffBp;
  final int refundAfterCutoffBp;
  final bool refundIncludesConvenienceFee;
  final int? tokenCancelLimitMin;
  final int hospitalCancellationRefundBp;
}

/// `GET /patient/hospitals/{id}` (§7.3): a [HospitalCard] plus everything the
/// detail screen and the booking flow need.
class HospitalDetail {
  const HospitalDetail({
    required this.card,
    required this.timezone,
    required this.hours,
    required this.holidays,
    required this.banners,
    required this.bookingWindowDays,
    required this.followUpWindowDays,
    required this.version,
    this.legalName,
    this.email,
    this.phoneE164,
    this.website,
    this.address,
    this.lat,
    this.lng,
    this.cancellationPolicy,
  });

  final HospitalCard card;
  final String? legalName;
  final String? email;
  final String? phoneE164;
  final String? website;
  final HospitalAddress? address;
  final String? lat;
  final String? lng;

  /// IANA zone name (`Asia/Kolkata`) — slot and appointment times are shown
  /// in this zone, never the device's (§1.11).
  final String timezone;
  final List<HospitalHours> hours;
  final List<HospitalHoliday> holidays;
  final List<HospitalBanner> banners;
  final CancellationPolicy? cancellationPolicy;
  final int followUpWindowDays;

  /// How far ahead the date picker may go.
  final int bookingWindowDays;
  final int version;

  String get id => card.id;
  String get name => card.name;
}
