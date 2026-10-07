import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../domain/entities/availability.dart';
import '../../domain/entities/booked_appointment.dart';
import '../../domain/entities/booking_result.dart';
import '../../domain/entities/department.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/fee_quote.dart';
import '../../domain/entities/hospital.dart';
import '../../domain/entities/location.dart';
import '../../domain/entities/payment_order.dart';
import '../../domain/entities/person_summary.dart';
import '../../domain/entities/promo_banner.dart';
import '../../domain/entities/slots.dart';
import '../../domain/entities/token_card.dart';

/// JSON → domain entity mapping for the booking slice. The only place the
/// wire field names of §6–§10 are spelled.
///
/// Every mapper is the Scenario-10 validation pipeline for its shape: a
/// missing required field throws [ResponseFormatException], so nothing
/// malformed is ever cached or rendered.
abstract final class BookingMappers {
  BookingMappers._();

  // ---- Primitives ----

  static Map<String, Object?> obj(Object? json, String what) {
    if (json is Map) return json.cast<String, Object?>();
    throw ResponseFormatException(message: '$what: expected an object');
  }

  static String str(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    throw ResponseFormatException(message: 'missing "$key"');
  }

  static String? optStr(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return null;
    return value.toString();
  }

  static int intOf(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is num) return value.toInt();
    throw ResponseFormatException(message: 'missing number "$key"');
  }

  static int? optInt(Map<String, Object?> json, String key) {
    final value = json[key];
    return value is num ? value.toInt() : null;
  }

  static double? optDouble(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool boolOf(Map<String, Object?> json, String key, {bool? orElse}) {
    final value = json[key];
    if (value is bool) return value;
    if (orElse != null) return orElse;
    throw ResponseFormatException(message: 'missing bool "$key"');
  }

  static DateTime dateTime(Map<String, Object?> json, String key) {
    final parsed = optDateTime(json, key);
    if (parsed == null) {
      throw ResponseFormatException(message: 'missing instant "$key"');
    }
    return parsed;
  }

  static DateTime? optDateTime(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    return parsed?.toUtc();
  }

  static List<Map<String, Object?>> list(Object? value) => [
    if (value is List)
      for (final row in value)
        if (row is Map) row.cast<String, Object?>(),
  ];

  // ---- §7 Discovery ----

  static Location location(Map<String, Object?> json) => Location(
    id: str(json, 'id'),
    city: str(json, 'city'),
    area: optStr(json, 'area') ?? '',
    state: optStr(json, 'state') ?? '',
    lat: optStr(json, 'lat'),
    lng: optStr(json, 'lng'),
    isPopular: boolOf(json, 'is_popular', orElse: false),
  );

  static DepartmentRef departmentRef(Map<String, Object?> json) =>
      DepartmentRef(
        id: optStr(json, 'id') ?? '',
        code: str(json, 'code'),
        name: str(json, 'name'),
      );

  static DepartmentSummary departmentSummary(Map<String, Object?> json) =>
      DepartmentSummary(
        code: str(json, 'code'),
        name: str(json, 'name'),
        hospitalCount: optInt(json, 'hospital_count') ?? 0,
      );

  static HospitalDepartment hospitalDepartment(Map<String, Object?> json) =>
      HospitalDepartment(
        id: str(json, 'id'),
        code: str(json, 'code'),
        name: str(json, 'name'),
        description: optStr(json, 'description'),
        icon: optStr(json, 'icon'),
        sortOrder: optInt(json, 'sort_order') ?? 0,
      );

  static HospitalCard hospitalCard(Map<String, Object?> json) => HospitalCard(
    id: str(json, 'id'),
    slug: optStr(json, 'slug') ?? '',
    name: str(json, 'name'),
    city: optStr(json, 'city') ?? '',
    area: optStr(json, 'area'),
    rating: optStr(json, 'rating'),
    ratingCount: optInt(json, 'rating_count') ?? 0,
    distanceKm: optDouble(json, 'distance_km'),
    departments: [for (final d in list(json['departments'])) departmentRef(d)],
    nextAvailableAt: optDateTime(json, 'next_available_at'),
    onlineBookingEnabled: boolOf(json, 'online_booking_enabled', orElse: true),
    logoFileId: optStr(json, 'logo_file_id'),
    coverFileId: optStr(json, 'cover_file_id'),
  );

  static HospitalBanner banner(
    Map<String, Object?> json, {
    required String hospitalId,
  }) => HospitalBanner(
    id: str(json, 'id'),
    title: str(json, 'title'),
    body: optStr(json, 'body'),
    imageFileId: optStr(json, 'image_file_id'),
    ctaLabel: optStr(json, 'cta_label'),
    ctaTarget: optStr(json, 'cta_target'),
    sortOrder: optInt(json, 'sort_order') ?? 0,
    startsAt: optDateTime(json, 'starts_at'),
    endsAt: optDateTime(json, 'ends_at'),
    hospitalId: hospitalId,
  );

  static HospitalDetail hospitalDetail(Map<String, Object?> json) {
    final card = hospitalCard(json);
    final address = json['address'];
    final policy = json['cancellation_policy'];
    return HospitalDetail(
      card: card,
      legalName: optStr(json, 'legal_name'),
      email: optStr(json, 'email'),
      phoneE164: optStr(json, 'phone_e164'),
      website: optStr(json, 'website'),
      address: address is Map
          ? hospitalAddress(address.cast<String, Object?>())
          : null,
      lat: optStr(json, 'lat'),
      lng: optStr(json, 'lng'),
      timezone: optStr(json, 'timezone') ?? 'Asia/Kolkata',
      hours: [
        for (final h in list(json['hours']))
          HospitalHours(
            weekday: intOf(h, 'weekday'),
            isClosed: boolOf(h, 'is_closed', orElse: false),
            opensAt: optStr(h, 'opens_at'),
            closesAt: optStr(h, 'closes_at'),
          ),
      ],
      holidays: [
        for (final h in list(json['holidays']))
          HospitalHoliday(
            id: str(h, 'id'),
            name: optStr(h, 'name') ?? 'Holiday',
            dateFrom: str(h, 'date_from'),
            dateTo: optStr(h, 'date_to') ?? str(h, 'date_from'),
            departmentId: optStr(h, 'department_id'),
          ),
      ],
      banners: [
        for (final b in list(json['banners'])) banner(b, hospitalId: card.id),
      ],
      cancellationPolicy: policy is Map
          ? cancellationPolicy(policy.cast<String, Object?>())
          : null,
      followUpWindowDays: optInt(json, 'follow_up_window_days') ?? 0,
      bookingWindowDays: optInt(json, 'booking_window_days') ?? 30,
      version: optInt(json, 'version') ?? 0,
    );
  }

  static HospitalAddress hospitalAddress(Map<String, Object?> json) =>
      HospitalAddress(
        addressLine1: optStr(json, 'address_line1') ?? '',
        addressLine2: optStr(json, 'address_line2'),
        addressLine3: optStr(json, 'address_line3'),
        city: optStr(json, 'city') ?? '',
        state: optStr(json, 'state') ?? '',
        pincode: optStr(json, 'pincode') ?? '',
        phoneE164: optStr(json, 'phone_e164'),
      );

  static CancellationPolicy cancellationPolicy(Map<String, Object?> json) =>
      CancellationPolicy(
        cutoffHours: optInt(json, 'cutoff_hours') ?? 0,
        refundBeforeCutoffBp: optInt(json, 'refund_before_cutoff_bp') ?? 0,
        refundAfterCutoffBp: optInt(json, 'refund_after_cutoff_bp') ?? 0,
        refundIncludesConvenienceFee: boolOf(
          json,
          'refund_includes_convenience_fee',
          orElse: false,
        ),
        tokenCancelLimitMin: optInt(json, 'token_cancel_limit_min'),
        hospitalCancellationRefundBp:
            optInt(json, 'hospital_cancellation_refund_bp') ?? 10000,
      );

  static DoctorCard doctorCard(Map<String, Object?> json) => DoctorCard(
    id: str(json, 'id'),
    slug: optStr(json, 'slug') ?? '',
    name: str(json, 'name'),
    title: optStr(json, 'title'),
    qualification: optStr(json, 'qualification'),
    specialisation: optStr(json, 'specialisation'),
    experienceYears: optInt(json, 'experience_years'),
    photoFileId: optStr(json, 'photo_file_id'),
    department: departmentRef(obj(json['department'], 'doctor.department')),
    hospital: _doctorHospital(obj(json['hospital'], 'doctor.hospital')),
    consultationFeePaise: intOf(json, 'consultation_fee_paise'),
    followUpFeePaise: optInt(json, 'follow_up_fee_paise'),
    rating: optStr(json, 'rating'),
    ratingCount: optInt(json, 'rating_count') ?? 0,
    status: DoctorStatus.fromWire(optStr(json, 'status')),
    isBookableOnline: boolOf(json, 'is_bookable_online', orElse: true),
    nextAvailableAt: optDateTime(json, 'next_available_at'),
  );

  static DoctorHospitalRef _doctorHospital(Map<String, Object?> json) =>
      DoctorHospitalRef(
        id: str(json, 'id'),
        name: str(json, 'name'),
        city: optStr(json, 'city') ?? '',
        area: optStr(json, 'area'),
      );

  static DoctorDetail doctorDetail(Map<String, Object?> json) => DoctorDetail(
    card: doctorCard(json),
    bio: optStr(json, 'bio'),
    room: optStr(json, 'room'),
    slotLengthMin: optInt(json, 'slot_length_min') ?? 15,
    expectedConsultMinutes: optInt(json, 'expected_consult_minutes'),
    version: optInt(json, 'version') ?? 0,
  );

  // ---- §8 Availability and slots ----

  static DoctorAvailability availability(Map<String, Object?> json) =>
      DoctorAvailability(
        doctorId: str(json, 'doctor_id'),
        from: optStr(json, 'from') ?? '',
        to: optStr(json, 'to') ?? '',
        dates: [
          for (final d in list(json['dates']))
            AvailabilityDay(
              date: str(d, 'date'),
              sessions: [
                for (final s in list(d['sessions']))
                  AvailabilitySession(
                    sessionId: str(s, 'session_id'),
                    sessionCode: optStr(s, 'session_code') ?? '',
                    label: optStr(s, 'label') ?? 'Session',
                    state: SessionAvailability.fromWire(optStr(s, 'state')),
                    startsAt: dateTime(s, 'starts_at'),
                    endsAt: dateTime(s, 'ends_at'),
                  ),
              ],
            ),
        ],
      );

  static DaySlots daySlots(Map<String, Object?> json) {
    final doctorId = str(json, 'doctor_id');
    return DaySlots(
      doctorId: doctorId,
      date: str(json, 'date'),
      timezone: optStr(json, 'timezone'),
      sessions: [
        for (final s in list(json['sessions']))
          () {
            final sessionId = str(s, 'session_id');
            return SlotSession(
              sessionId: sessionId,
              sessionCode: optStr(s, 'session_code') ?? '',
              label: optStr(s, 'label') ?? 'Session',
              status: SessionStatus.fromWire(optStr(s, 'status')),
              startsAt: dateTime(s, 'starts_at'),
              endsAt: dateTime(s, 'ends_at'),
              slots: [
                for (final slot in list(s['slots']))
                  Slot(
                    id: str(slot, 'id'),
                    sessionId: sessionId,
                    startsAt: dateTime(slot, 'starts_at'),
                    endsAt: dateTime(slot, 'ends_at'),
                    state: SlotState.fromWire(optStr(slot, 'state')),
                  ),
              ],
            );
          }(),
      ],
    );
  }

  // ---- §8.3 Fee quote ----

  static FeeQuote feeQuote(Map<String, Object?> json) {
    final coupon = json['coupon'];
    return FeeQuote(
      doctorId: str(json, 'doctor_id'),
      hospitalId: optStr(json, 'hospital_id') ?? '',
      personId: optStr(json, 'person_id'),
      consultationFeePaise: intOf(json, 'consultation_fee_paise'),
      serviceFeePaise: optInt(json, 'service_fee_paise') ?? 0,
      discountPaise: optInt(json, 'discount_paise') ?? 0,
      convenienceFeePaise: optInt(json, 'convenience_fee_paise') ?? 0,
      taxPaise: optInt(json, 'tax_paise') ?? 0,
      totalPaise: intOf(json, 'total_paise'),
      isFollowUp: boolOf(json, 'is_follow_up', orElse: false),
      currency: optStr(json, 'currency') ?? 'INR',
      coupon: coupon is Map
          ? CouponResult(
              code: optStr(coupon.cast<String, Object?>(), 'code') ?? '',
              valid: boolOf(
                coupon.cast<String, Object?>(),
                'valid',
                orElse: false,
              ),
              reason: optStr(coupon.cast<String, Object?>(), 'reason'),
            )
          : null,
      regularConsultationFeePaise: optInt(
        json,
        'regular_consultation_fee_paise',
      ),
      followUpFeePaise: optInt(json, 'follow_up_fee_paise'),
      lines: [
        for (final line in list(json['lines']))
          FeeLine(
            line: optStr(line, 'line') ?? '',
            description: optStr(line, 'description') ?? '',
            supplier: optStr(line, 'supplier') ?? '',
            amountPaise: intOf(line, 'amount_paise'),
            taxCode: optStr(line, 'tax_code'),
            taxRateBp: optInt(line, 'tax_rate_bp') ?? 0,
            taxPaise: optInt(line, 'tax_paise') ?? 0,
            taxInclusive: boolOf(line, 'tax_inclusive', orElse: false),
          ),
      ],
      quotedForDate: optStr(json, 'quoted_for_date') ?? '',
    );
  }

  // ---- §6.1 Persons ----

  static PersonSummary person(Map<String, Object?> json) => PersonSummary(
    id: str(json, 'id'),
    firstName: str(json, 'first_name'),
    lastName: optStr(json, 'last_name'),
    relation: optStr(json, 'relation') ?? 'other',
    isSelf: boolOf(json, 'is_self', orElse: false),
    dateOfBirth: optStr(json, 'date_of_birth'),
    gender: optStr(json, 'gender'),
  );

  static List<PersonSummary> persons(Object? body) =>
      Page.parse(body, person).results;

  // ---- §9 Booking and payment ----

  static BookedAppointment appointment(Map<String, Object?> json) {
    final hospital = obj(json['hospital'], 'appointment.hospital');
    final department = obj(json['department'], 'appointment.department');
    final doctor = obj(json['doctor'], 'appointment.doctor');
    return BookedAppointment(
      id: str(json, 'id'),
      bookingRef: str(json, 'booking_ref'),
      status: AppointmentStatus.fromWire(optStr(json, 'status')),
      paymentStatus: AppointmentPaymentStatus.fromWire(
        optStr(json, 'payment_status'),
      ),
      hospitalId: str(hospital, 'id'),
      hospitalName: str(hospital, 'name'),
      hospitalCity: optStr(hospital, 'city'),
      hospitalPhoneE164: optStr(hospital, 'phone_e164'),
      hospitalTimezone: optStr(hospital, 'timezone'),
      departmentName: optStr(department, 'name') ?? '',
      doctorId: str(doctor, 'id'),
      doctorName: str(doctor, 'name'),
      doctorTitle: optStr(doctor, 'title'),
      doctorSpecialisation: optStr(doctor, 'specialisation'),
      doctorRoom: optStr(doctor, 'room'),
      personId: optStr(json, 'person_id') ?? '',
      sessionId: optStr(json, 'session_id'),
      slotId: optStr(json, 'slot_id'),
      scheduledDate: str(json, 'scheduled_date'),
      scheduledStartAt: dateTime(json, 'scheduled_start_at'),
      scheduledEndAt: dateTime(json, 'scheduled_end_at'),
      tokenNo: optInt(json, 'token_no'),
      tokenLabel: optStr(json, 'token_label'),
      isFollowUp: boolOf(json, 'is_follow_up', orElse: false),
      patientNotes: optStr(json, 'patient_notes'),
      bookingDeadlineAt: optDateTime(json, 'booking_deadline_at'),
      consultationFeePaise: optInt(json, 'consultation_fee_paise') ?? 0,
      serviceFeePaise: optInt(json, 'service_fee_paise') ?? 0,
      discountPaise: optInt(json, 'discount_paise') ?? 0,
      convenienceFeePaise: optInt(json, 'convenience_fee_paise') ?? 0,
      taxPaise: optInt(json, 'tax_paise') ?? 0,
      totalPaise: optInt(json, 'total_paise') ?? 0,
      currency: optStr(json, 'currency') ?? 'INR',
      cancelledAt: optDateTime(json, 'cancelled_at'),
      cancelledBy: optStr(json, 'cancelled_by'),
      cancellationReason: optStr(json, 'cancellation_reason'),
      createdAt: optDateTime(json, 'created_at'),
      version: optInt(json, 'version') ?? 0,
    );
  }

  static PaymentOrder paymentOrder(Map<String, Object?> json) => PaymentOrder(
    id: str(json, 'id'),
    appointmentId: str(json, 'appointment_id'),
    amountPaise: intOf(json, 'amount_paise'),
    currency: optStr(json, 'currency') ?? 'INR',
    channel: optStr(json, 'channel') ?? 'online',
    gateway: optStr(json, 'gateway') ?? 'razorpay',
    gatewayOrderId: optStr(json, 'gateway_order_id') ?? '',
    keyId: optStr(json, 'key_id') ?? '',
    status: PaymentOrderStatus.fromWire(optStr(json, 'status')),
    attempts: optInt(json, 'attempts') ?? 1,
    expiresAt: optDateTime(json, 'expires_at'),
    createdAt: optDateTime(json, 'created_at'),
  );

  static BookingResult bookingResult(Map<String, Object?> json) =>
      BookingResult(
        appointment: appointment(obj(json['appointment'], 'appointment')),
        paymentOrder: paymentOrder(obj(json['payment_order'], 'payment_order')),
      );

  // ---- §10.4 Token card ----

  static TokenCard tokenCard(Map<String, Object?> json) {
    final hospital = obj(json['hospital'], 'token_card.hospital');
    final doctor = obj(json['doctor'], 'token_card.doctor');
    final department = json['department'];
    final session = json['session'];
    return TokenCard(
      bookingRef: str(json, 'booking_ref'),
      tokenLabel: optStr(json, 'token_label'),
      tokenNo: optInt(json, 'token_no'),
      qrPayload: optStr(json, 'qr_payload') ?? str(json, 'booking_ref'),
      status: optStr(json, 'status') ?? '',
      patientName: optStr(json, 'patient_name') ?? '',
      hospitalName: str(hospital, 'name'),
      hospitalAddressLine1: optStr(hospital, 'address_line1'),
      hospitalCity: optStr(hospital, 'city'),
      hospitalPhoneE164: optStr(hospital, 'phone_e164'),
      doctorName: str(doctor, 'name'),
      doctorTitle: optStr(doctor, 'title'),
      doctorRoom: optStr(doctor, 'room'),
      departmentName: department is Map
          ? optStr(department.cast<String, Object?>(), 'name') ?? ''
          : '',
      date: str(json, 'date'),
      startTime: optStr(json, 'start_time') ?? '',
      endTime: optStr(json, 'end_time') ?? '',
      startsAt: dateTime(json, 'starts_at'),
      endsAt: dateTime(json, 'ends_at'),
      sessionLabel: session is Map
          ? optStr(session.cast<String, Object?>(), 'label')
          : null,
    );
  }
}
