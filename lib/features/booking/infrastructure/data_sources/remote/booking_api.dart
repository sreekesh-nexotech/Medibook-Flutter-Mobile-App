import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/endpoints.dart';
import '../../../domain/entities/booking_result.dart';

/// The token-required booking endpoints (§8.3, §9.1, §10.4, §6.1) as a typed
/// remote data source.
///
/// HTTP only: each method is a path from [Endpoints] plus a payload, and
/// returns the decoded JSON object. No caching, no mapping, no `try`/`catch`
/// — `NetworkException`s propagate to the repository, which maps them to
/// `Failure`.
abstract interface class BookingApi {
  /// `GET /patient/fee-quotes`.
  Future<Map<String, Object?>> feeQuote({
    required String doctorId,
    String? personId,
    String? couponCode,
  });

  /// `GET /patient/me/persons` → page envelope.
  Future<Map<String, Object?>> persons();

  /// `POST /patient/appointments` → 201 `{appointment, payment_order}`.
  Future<Map<String, Object?>> book(
    BookingRequest request, {
    required String idempotencyKey,
  });

  /// `GET /patient/appointments/{id}/token-card`.
  Future<Map<String, Object?>> tokenCard(String appointmentId);
}

class HttpBookingApi implements BookingApi {
  const HttpBookingApi(this._client);

  final ApiClient _client;

  @override
  Future<Map<String, Object?>> feeQuote({
    required String doctorId,
    String? personId,
    String? couponCode,
  }) async {
    final response = await _client.get(
      Endpoints.feeQuotes,
      query: {
        'doctor_id': doctorId,
        'person_id': personId,
        'coupon_code': couponCode,
      },
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> persons() async {
    final response = await _client.get(
      Endpoints.persons,
      query: const {'page_size': 100},
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> book(
    BookingRequest request, {
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      Endpoints.appointments,
      // Key order is fixed: an idempotent retry must send identical bytes
      // (§1.8), and the same request always serialises the same way.
      body: {
        'slot_id': request.slotId,
        'person_id': request.personId,
        if (request.couponCode != null && request.couponCode!.isNotEmpty)
          'coupon_code': request.couponCode,
        if (request.patientNotes != null && request.patientNotes!.isNotEmpty)
          'patient_notes': request.patientNotes,
      },
      idempotencyKey: idempotencyKey,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> tokenCard(String appointmentId) async {
    final response = await _client.get(
      Endpoints.appointmentTokenCard(appointmentId),
    );
    return response.requireMap;
  }
}
