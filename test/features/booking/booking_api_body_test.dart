import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/api_client.dart';
import 'package:medibook/features/booking/domain/entities/booking_result.dart';
import 'package:medibook/features/booking/infrastructure/data_sources/remote/booking_api.dart';

/// BL-BOOK-030: notes are optional — `patient_notes` is only sent when the
/// patient actually wrote something (§9.1).
void main() {
  late _RecordingClient client;
  late HttpBookingApi api;

  setUp(() {
    client = _RecordingClient();
    api = HttpBookingApi(client);
  });

  Future<Map<String, Object?>> bodyOf(BookingRequest request) async {
    await api.book(request, idempotencyKey: 'key-1');
    return (client.requests.single.body! as Map).cast<String, Object?>();
  }

  test('a booking without notes sends no patient_notes', () async {
    final body = await bodyOf(
      const BookingRequest(slotId: 'slot-1', personId: 'p1'),
    );
    expect(body.containsKey('patient_notes'), isFalse);
    expect(body, {'slot_id': 'slot-1', 'person_id': 'p1'});
  });

  test('empty notes are left out as well', () async {
    final body = await bodyOf(
      const BookingRequest(slotId: 'slot-1', personId: 'p1', patientNotes: ''),
    );
    expect(body.containsKey('patient_notes'), isFalse);
  });

  test('written notes are sent', () async {
    final body = await bodyOf(
      const BookingRequest(
        slotId: 'slot-1',
        personId: 'p1',
        patientNotes: 'Chest pain since Monday',
      ),
    );
    expect(body['patient_notes'], 'Chest pain since Monday');
  });
}

/// Records every request and answers with a minimal booking.
class _RecordingClient with ApiClientVerbs implements ApiClient {
  final List<ApiRequest> requests = [];

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    requests.add(request);
    return ApiResponse(statusCode: 201, data: const {'id': 'appt-1'});
  }
}
