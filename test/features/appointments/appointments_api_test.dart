import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/api_client.dart';
import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_filter.dart';
import 'package:medibook/features/appointments/infrastructure/data_sources/remote/appointments_api.dart';

/// The list request builder sends exactly the §10.1 parameters — an unknown
/// or empty one would be a `400 VALIDATION_ERROR`.
void main() {
  const api = HttpAppointmentsApi(UnimplementedApiClient());

  test('Upcoming tab = bucket=upcoming&sort=scheduled_start_at', () {
    final request = api.listRequest(
      const AppointmentListQuery(tab: AppointmentTab.upcoming),
      page: 1,
      pageSize: 20,
    );
    expect(request.path, '/patient/appointments');
    expect(request.normalisedQuery, {
      'page': '1',
      'page_size': '20',
      'bucket': 'upcoming',
      'sort': 'scheduled_start_at',
    });
  });

  test('Completed tab = the past bucket minus cancelled, default sort', () {
    final request = api.listRequest(
      const AppointmentListQuery(tab: AppointmentTab.completed),
      page: 2,
      pageSize: 20,
    );
    expect(request.normalisedQuery, {
      'page': '2',
      'page_size': '20',
      // A past visit the desk never closed stays `scheduled`; it belongs
      // here rather than in no tab.
      'bucket': 'past',
      'status':
          'completed,scheduled,checked_in,in_consultation,pending_approval',
    });
  });

  test('Canceled tab = status=cancelled,no_show', () {
    final request = api.listRequest(
      const AppointmentListQuery(tab: AppointmentTab.cancelled),
      page: 1,
      pageSize: 20,
    );
    expect(request.normalisedQuery['status'], 'cancelled,no_show');
    expect(request.normalisedQuery.containsKey('bucket'), isFalse);
  });

  test('filters map to doctor_id / hospital_id / person_id / dates', () {
    final request = api.listRequest(
      AppointmentListQuery(
        tab: AppointmentTab.upcoming,
        filter: AppointmentFilter(
          from: DateTime(2026, 9, 1),
          to: DateTime(2026, 10, 31),
          doctorId: 'd-1',
          hospitalId: 'h-1',
          personId: 'p-1',
          statuses: const {
            AppointmentStatus.scheduled,
            AppointmentStatus.checkedIn,
          },
        ),
      ),
      page: 1,
      pageSize: 20,
    );
    final q = request.normalisedQuery;
    expect(q['date_from'], '2026-09-01');
    expect(q['date_to'], '2026-10-31');
    expect(q['doctor_id'], 'd-1');
    expect(q['hospital_id'], 'h-1');
    expect(q['person_id'], 'p-1');
    expect(q['bucket'], 'upcoming');
    expect(q['status'], contains('scheduled'));
    expect(q['status'], contains('checked_in'));
  });

  test('search sends q only, no bucket / status', () {
    final request = api.listRequest(
      const AppointmentListQuery(q: '  pillai '),
      page: 1,
      pageSize: 20,
    );
    expect(request.normalisedQuery, {
      'page': '1',
      'page_size': '20',
      'q': 'pillai',
    });
  });

  test('sub-resource paths', () {
    expect(api.detailRequest('x').path, '/patient/appointments/x');
    expect(api.queueRequest('x').path, '/patient/appointments/x/queue');
    expect(
      api.cancellationPreviewRequest('x').path,
      '/patient/appointments/x/cancellation-preview',
    );
    expect(api.receiptRequest('x').path, '/patient/appointments/x/receipt');
    expect(api.paymentsRequest('x').normalisedQuery['appointment_id'], 'x');
    expect(api.refundsRequest('x').normalisedQuery['appointment_id'], 'x');
    expect(api.eventsRequest('x').normalisedQuery['sort'], 'occurred_at');
  });

  test('the calendar file takes the name the server gave it (§10.10)', () {
    expect(
      HttpAppointmentsApi.attachmentFileName(
        'attachment; filename="LKSB-2609-00165.ics"',
      ),
      'LKSB-2609-00165.ics',
    );
    expect(
      HttpAppointmentsApi.attachmentFileName('attachment; filename=a.ics'),
      'a.ics',
    );
    expect(HttpAppointmentsApi.attachmentFileName('attachment'), isNull);
    expect(HttpAppointmentsApi.attachmentFileName(null), isNull);
  });
}
