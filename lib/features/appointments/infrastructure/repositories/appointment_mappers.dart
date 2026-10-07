import '../../../../core/network/api_client.dart' show Page;
import '../../../../core/network/network_exceptions.dart'
    show ResponseFormatException;
import '../../../../core/utils/money.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/appointment_detail.dart';
import '../../domain/entities/appointment_event.dart';
import '../../domain/entities/appointment_review.dart';
import '../../domain/entities/cancellation_preview.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/person_summary.dart';
import '../../domain/entities/queue_status.dart';
import '../../domain/entities/receipt.dart';
import '../../domain/entities/token_card.dart';
import '../../domain/repositories/appointments_repository.dart';

/// JSON → entity for §10 and §6.1. The only place the wire field names are
/// spelled.
///
/// Every mapper is the Scenario-10 validation pipeline for its shape: a
/// missing required field or an unknown enum value throws a
/// [ResponseFormatException], which `CachedFetcher` treats as "do not cache"
/// and the repository maps to a `ServerFailure`. Optional fields default
/// quietly, so a new nullable column on the backend never breaks the app.
abstract final class AppointmentMappers {
  AppointmentMappers._();

  // ---- Appointment (§10) ----

  static Appointment appointment(Map<String, Object?> json) {
    final status = AppointmentStatus.fromWire(_string(json, 'status'));
    if (status == null) {
      throw ResponseFormatException(
        message: 'unknown appointment status ${json['status']}',
      );
    }
    final paymentStatus =
        AppointmentPaymentStatus.fromWire(json['payment_status'] as String?) ??
        AppointmentPaymentStatus.unpaid;
    return Appointment(
      id: _string(json, 'id'),
      bookingRef: _string(json, 'booking_ref'),
      status: status,
      statusReason: json['status_reason'] as String?,
      source: AppointmentSource.fromWire(json['source'] as String?),
      hospital: hospitalSummary(_map(json, 'hospital')),
      department: departmentSummary(_map(json, 'department')),
      doctor: doctorSummary(_map(json, 'doctor')),
      personId: _string(json, 'person_id'),
      sessionId: json['session_id'] as String?,
      slotId: json['slot_id'] as String?,
      scheduledDate: _string(json, 'scheduled_date'),
      scheduledStartAt: _instant(json, 'scheduled_start_at'),
      scheduledEndAt: _instant(json, 'scheduled_end_at'),
      tokenNo: _int(json['token_no']),
      tokenLabel: json['token_label'] as String?,
      tokenSource: json['token_source'] as String?,
      isFollowUp: json['is_follow_up'] == true,
      patientNotes: json['patient_notes'] as String?,
      paymentStatus: paymentStatus,
      bookingDeadlineAt: _optionalInstant(json['booking_deadline_at']),
      consultationFee: _money(json['consultation_fee_paise']),
      serviceFee: _money(json['service_fee_paise']),
      discount: _money(json['discount_paise']),
      convenienceFee: _money(json['convenience_fee_paise']),
      tax: _money(json['tax_paise']),
      taxLines: [
        for (final row in _list(json['tax_lines']))
          if (row is Map) taxLine(row.cast<String, Object?>()),
      ],
      total: _money(json['total_paise']),
      currency: json['currency'] as String? ?? 'INR',
      cancelledAt: _optionalInstant(json['cancelled_at']),
      cancelledBy: CancelledBy.fromWire(json['cancelled_by'] as String?),
      cancellationReason: json['cancellation_reason'] as String?,
      checkedInAt: _optionalInstant(json['checked_in_at']),
      calledAt: _optionalInstant(json['called_at']),
      completedAt: _optionalInstant(json['completed_at']),
      createdAt: _optionalInstant(json['created_at']) ?? DateTime.now().toUtc(),
      version: _int(json['version']) ?? 1,
    );
  }

  static HospitalSummary hospitalSummary(Map<String, Object?> json) =>
      HospitalSummary(
        id: _string(json, 'id'),
        name: _string(json, 'name'),
        city: json['city'] as String?,
        phoneE164: json['phone_e164'] as String?,
        timezone: json['timezone'] as String?,
      );

  static DepartmentSummary departmentSummary(Map<String, Object?> json) =>
      DepartmentSummary(
        id: _string(json, 'id'),
        name: _string(json, 'name'),
        code: json['code'] as String?,
      );

  static DoctorSummary doctorSummary(Map<String, Object?> json) =>
      DoctorSummary(
        id: _string(json, 'id'),
        name: _string(json, 'name'),
        title: json['title'] as String?,
        specialisation: json['specialisation'] as String?,
        room: json['room'] as String?,
      );

  static TaxLine taxLine(Map<String, Object?> json) => TaxLine(
    code: json['code'] as String? ?? '',
    line: json['line'] as String? ?? '',
    supplier: json['supplier'] as String? ?? '',
    rateBp: _int(json['rate_bp']) ?? 0,
    tax: _money(json['tax_paise']),
    base: _money(json['base_paise']),
    inclusive: json['inclusive'] == true,
  );

  // ---- Detail (§10.2) ----

  static AppointmentDetail detail(Map<String, Object?> json) {
    final actionsJson = json['actions'];
    final receiptJson = json['receipt'];
    final orderJson = json['payment_order'];
    return AppointmentDetail(
      appointment: appointment(json),
      actions: actionsJson is Map
          ? actions(actionsJson.cast<String, Object?>())
          : const AppointmentActions(),
      paymentOrder: orderJson is Map
          ? paymentOrder(orderJson.cast<String, Object?>())
          : null,
      receipt: receiptJson is Map
          ? ReceiptSummary(
              receiptNo: receiptJson['receipt_no'] as String? ?? '',
              issuedAt: _optionalInstant(receiptJson['issued_at']),
            )
          : null,
      refunds: [
        for (final row in _list(json['refunds']))
          if (row is Map) refund(row.cast<String, Object?>()),
      ],
      reviewed: json['reviewed'] == true,
    );
  }

  static AppointmentActions actions(Map<String, Object?> json) =>
      AppointmentActions(
        canCancel: json['can_cancel'] == true,
        cancelBlockedReason: json['cancel_blocked_reason'] as String?,
        canRetryPayment: json['can_retry_payment'] == true,
        canReview: json['can_review'] == true,
      );

  static PaymentOrder paymentOrder(Map<String, Object?> json) => PaymentOrder(
    id: _string(json, 'id'),
    appointmentId: json['appointment_id'] as String? ?? '',
    amount: _money(json['amount_paise']),
    currency: json['currency'] as String? ?? 'INR',
    gateway: json['gateway'] as String?,
    gatewayOrderId: json['gateway_order_id'] as String?,
    keyId: json['key_id'] as String?,
    status: json['status'] as String? ?? 'created',
    attempts: _int(json['attempts']) ?? 1,
    expiresAt: _optionalInstant(json['expires_at']),
    createdAt: _optionalInstant(json['created_at']),
  );

  static CancelOutcome cancelOutcome(Map<String, Object?> json) =>
      CancelOutcome(
        appointment: appointment(_map(json, 'appointment')),
        refunds: [
          for (final row in _list(json['refunds']))
            if (row is Map) refund(row.cast<String, Object?>()),
        ],
      );

  // ---- Events (§10.3) ----

  static AppointmentEvent event(Map<String, Object?> json) => AppointmentEvent(
    id: _string(json, 'id'),
    eventType: _string(json, 'event_type'),
    actorKind: json['actor_kind'] as String? ?? 'system',
    fromStatus: json['from_status'] as String?,
    toStatus: json['to_status'] as String?,
    occurredAt: _instant(json, 'occurred_at'),
  );

  // ---- Token card (§10.4) ----

  static TokenCard tokenCard(Map<String, Object?> json) {
    final hospital = _map(json, 'hospital');
    final doctor = _map(json, 'doctor');
    final department = json['department'];
    final session = json['session'];
    return TokenCard(
      bookingRef: _string(json, 'booking_ref'),
      tokenLabel: json['token_label'] as String?,
      tokenNo: _int(json['token_no']),
      qrPayload: json['qr_payload'] as String? ?? _string(json, 'booking_ref'),
      status: json['status'] as String? ?? '',
      patientName: json['patient_name'] as String? ?? '',
      hospitalName: _string(hospital, 'name'),
      hospitalAddress: address(hospital),
      doctorName: _string(doctor, 'name'),
      doctorTitle: doctor['title'] as String?,
      doctorRoom: doctor['room'] as String?,
      departmentName: department is Map
          ? department['name'] as String? ?? ''
          : '',
      date: _string(json, 'date'),
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      startsAt: _optionalInstant(json['starts_at']),
      endsAt: _optionalInstant(json['ends_at']),
      session: session is Map
          ? SessionSummary(
              sessionCode: session['session_code'] as String? ?? '',
              label: session['label'] as String? ?? '',
              startsAt: _optionalInstant(session['starts_at']),
              endsAt: _optionalInstant(session['ends_at']),
            )
          : null,
    );
  }

  static AddressSnapshot address(Map<String, Object?> json) => AddressSnapshot(
    line1: json['address_line1'] as String?,
    line2: json['address_line2'] as String?,
    line3: json['address_line3'] as String?,
    city: json['city'] as String?,
    state: json['state'] as String?,
    pincode: json['pincode'] as String?,
    phoneE164: json['phone_e164'] as String?,
  );

  // ---- Queue (§10.5) ----

  static QueueStatus queue(Map<String, Object?> json) => QueueStatus(
    sessionState: SessionState.fromWire(json['session_state'] as String?),
    queueState: QueueState.fromWire(json['queue_state'] as String?),
    currentToken: json['current_token'] as String?,
    currentTokenNo: _int(json['current_token_no']),
    lastCalledToken: _int(json['last_called_token']),
    yourToken: json['your_token'] as String?,
    yourTokenNo: _int(json['your_token_no']),
    tokensAhead: _int(json['tokens_ahead']) ?? 0,
    estimatedWaitMinutes: _int(json['estimated_wait_minutes']) ?? 0,
    updatedAt: _optionalInstant(json['updated_at']) ?? DateTime.now().toUtc(),
  );

  // ---- Cancellation preview (§10.6) ----

  static CancellationPreview cancellationPreview(Map<String, Object?> json) =>
      CancellationPreview(
        allowed: json['allowed'] == true,
        reason: json['reason'] as String?,
        cutoffAt: _optionalInstant(json['cutoff_at']),
        beforeCutoff: json['before_cutoff'] != false,
        refundBp: _int(json['refund_bp']) ?? 0,
        refund: _money(json['refund_paise']),
        nonRefundable: _money(json['non_refundable_paise']),
        includesConvenienceFee: json['includes_convenience_fee'] == true,
      );

  // ---- Receipt (§10.8–10.9) ----

  static Receipt receipt(Map<String, Object?> json) {
    final platform = json['platform'];
    return Receipt(
      id: _string(json, 'id'),
      receiptNo: _string(json, 'receipt_no'),
      fyCode: json['fy_code'] as String?,
      issuedAt: _instant(json, 'issued_at'),
      issuedByName: json['issued_by_name'] as String?,
      counterCode: json['counter_code'] as String?,
      subtotal: _money(json['subtotal_paise']),
      tax: _money(json['tax_paise']),
      total: _money(json['total_paise']),
      lines: [
        for (final row in _list(json['lines']))
          if (row is Map) receiptLine(row.cast<String, Object?>()),
      ],
      paymentLines: [
        for (final row in _list(json['payment_lines']))
          if (row is Map)
            PaymentLine(
              method: row['method'] as String? ?? 'other',
              amount: _money(row['amount_paise']),
              reference: row['reference'] as String?,
            ),
      ],
      hospital: receiptHospital(_map(json, 'hospital')),
      platform: platform is Map
          ? ReceiptPlatform(
              legalName: platform['legal_name'] as String?,
              gstin: platform['gstin'] as String?,
              address: address(platform.cast<String, Object?>()),
            )
          : null,
      pdfAvailable: json['pdf_available'] == true,
    );
  }

  static ReceiptLine receiptLine(Map<String, Object?> json) => ReceiptLine(
    supplier: json['supplier'] as String? ?? '',
    line: json['line'] as String? ?? '',
    description: json['description'] as String? ?? '',
    qty: _int(json['qty']) ?? 1,
    unit: _money(json['unit_paise']),
    amount: _money(json['amount_paise']),
    taxCode: json['tax_code'] as String?,
    rateBp: _int(json['tax_rate_bp']) ?? 0,
    tax: _money(json['tax_paise']),
    taxInclusive: json['tax_inclusive'] == true,
    appointmentId: json['appointment_id'] as String?,
    bookingRef: json['booking_ref'] as String?,
  );

  static ReceiptHospital receiptHospital(Map<String, Object?> json) =>
      ReceiptHospital(
        id: json['id'] as String? ?? '',
        name: _string(json, 'name'),
        legalName: json['legal_name'] as String?,
        gstin: json['gstin'] as String?,
        address: address(json),
        logoFileId: json['logo_file_id'] as String?,
        stampFileId: json['stamp_file_id'] as String?,
      );

  static ReceiptPdfLink receiptPdfLink(Map<String, Object?> json) =>
      ReceiptPdfLink(
        url: _string(json, 'url'),
        receiptNo: json['receipt_no'] as String?,
      );

  // ---- Payments and refunds (§10.11) ----

  static Payment payment(Map<String, Object?> json) => Payment(
    id: _string(json, 'id'),
    orderId: json['order_id'] as String? ?? '',
    appointmentId: json['appointment_id'] as String? ?? '',
    amount: _money(json['amount_paise']),
    method: json['method'] as String? ?? 'other',
    gateway: json['gateway'] as String?,
    status:
        PaymentStatus.fromWire(json['status'] as String?) ??
        PaymentStatus.captured,
    capturedAt: _optionalInstant(json['captured_at']),
    failureCode: json['failure_code'] as String?,
    failureReason: json['failure_reason'] as String?,
    createdAt: _optionalInstant(json['created_at']),
  );

  static Refund refund(Map<String, Object?> json) => Refund(
    id: _string(json, 'id'),
    paymentId: json['payment_id'] as String? ?? '',
    appointmentId: json['appointment_id'] as String? ?? '',
    amount: _money(json['amount_paise']),
    reason: json['reason'] as String?,
    status:
        RefundStatus.fromWire(json['status'] as String?) ??
        RefundStatus.requested,
    requestedAt: _optionalInstant(json['requested_at']),
    processedAt: _optionalInstant(json['processed_at']),
  );

  // ---- Review (§10.12) ----

  static AppointmentReview review(Map<String, Object?> json) =>
      AppointmentReview(
        id: _string(json, 'id'),
        appointmentId: json['appointment_id'] as String? ?? '',
        doctorId: json['doctor_id'] as String? ?? '',
        rating: _int(json['rating']) ?? 0,
        comment: json['comment'] as String?,
        moderationStatus: json['moderation_status'] as String? ?? 'pending',
        isPublished: json['is_published'] == true,
        createdAt: _optionalInstant(json['created_at']),
      );

  // ---- Persons (§6.1) ----

  static PersonSummary person(Map<String, Object?> json) {
    final first = json['first_name'] as String? ?? '';
    final last = json['last_name'] as String? ?? '';
    return PersonSummary(
      id: _string(json, 'id'),
      name: [first, last].where((p) => p.isNotEmpty).join(' '),
      relation: json['relation'] as String? ?? 'other',
      isSelf: json['is_self'] == true,
    );
  }

  // ---- Page decoders for CachedFetcher ----

  static Page<Appointment> appointmentPage(Object? body) =>
      Page.parse(body, appointment);

  static Page<AppointmentEvent> eventPage(Object? body) =>
      Page.parse(body, event);

  static Page<Payment> paymentPage(Object? body) => Page.parse(body, payment);

  static Page<Refund> refundPage(Object? body) => Page.parse(body, refund);

  static List<PersonSummary> personList(Object? body) =>
      Page.parse(body, person).results;

  /// [body] as a JSON object, or a format error (never cached).
  static Map<String, Object?> requireMap(Object? body) {
    if (body is Map) return body.cast<String, Object?>();
    throw ResponseFormatException(
      message: 'expected a JSON object, got ${body.runtimeType}',
    );
  }

  // ---- Field helpers ----

  static String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    throw ResponseFormatException(message: 'missing required field "$key"');
  }

  static Map<String, Object?> _map(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is Map) return value.cast<String, Object?>();
    throw ResponseFormatException(message: 'missing required object "$key"');
  }

  static List<Object?> _list(Object? value) =>
      value is List ? value.cast<Object?>() : const <Object?>[];

  static int? _int(Object? value) => switch (value) {
    int() => value,
    num() => value.toInt(),
    String() => int.tryParse(value),
    _ => null,
  };

  static Money _money(Object? value) => Money.paise(_int(value) ?? 0);

  static DateTime _instant(Map<String, Object?> json, String key) {
    final parsed = _optionalInstant(json[key]);
    if (parsed == null) {
      throw ResponseFormatException(message: 'missing required instant "$key"');
    }
    return parsed;
  }

  static DateTime? _optionalInstant(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}
