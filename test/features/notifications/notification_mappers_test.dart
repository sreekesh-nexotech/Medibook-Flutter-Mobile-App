import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/api_client.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/notifications/domain/entities/notification.dart';
import 'package:medibook/features/notifications/domain/entities/push_device.dart';
import 'package:medibook/features/notifications/infrastructure/data_sources/remote/notifications_api.dart';
import 'package:medibook/features/notifications/infrastructure/repositories/notifications_repository_impl.dart';

import 'support/fixtures.dart';

/// §12 shapes → entities, and the list request's query parameters.
void main() {
  group('NotificationMappers', () {
    test('maps the live cancellation notification', () {
      final n = NotificationMappers.notification(NotificationFixtures.json());
      expect(n.id, NotificationFixtures.id);
      expect(n.kind, NotificationKind.cancellation);
      expect(n.event, 'appointment.cancelled');
      expect(n.appointmentId, NotificationFixtures.appointmentId);
      expect(n.unread, isTrue);
      expect(n.createdAt.isUtc, isTrue);
    });

    test('read_at set → read', () {
      final n = NotificationMappers.notification(
        NotificationFixtures.json(readAt: '2026-09-30T08:09:50.202353Z'),
      );
      expect(n.read, isTrue);
    });

    test('every §17 kind parses; an unknown kind falls back to general', () {
      for (final kind in NotificationKind.values) {
        expect(NotificationKind.fromWire(kind.wire), kind);
      }
      expect(NotificationKind.fromWire('change'), NotificationKind.general);
    });

    test('the other data ids are carried', () {
      final n = NotificationMappers.notification(
        NotificationFixtures.json(
          event: 'support.ticket_updated',
          extraData: {'ticket_id': 't-1', 'refund_id': 'r-1'},
        ),
      );
      expect(n.ticketId, 't-1');
      expect(n.refundId, 'r-1');
    });

    test('a row without an id is a format error', () {
      final json = NotificationFixtures.json()..remove('id');
      expect(
        () => NotificationMappers.notification(json),
        throwsA(isA<ResponseFormatException>()),
      );
    });

    test('page, counts and device', () {
      final page = NotificationMappers.page(
        NotificationFixtures.pageJson([NotificationFixtures.json()]),
      );
      expect(page.results.single.title, 'Appointment cancelled');
      expect(NotificationMappers.count({'unread_count': 3}, 'unread_count'), 3);
      expect(
        () => NotificationMappers.count({}, 'updated_count'),
        throwsA(isA<ResponseFormatException>()),
      );
      final device = NotificationMappers.device({
        'id': '01a0f15c-4e5f-71b1-9349-9cce47af3b4d',
        'platform': 'android',
        'push_token': 'tok',
        'app_version': '1.0.0',
        'os_version': '14',
        'last_seen_at': '2026-09-30T08:09:13.563638+00:00',
        'created_at': '2026-09-30T08:09:13.567951+00:00',
      });
      expect(device.platform, DevicePlatform.android);
      expect(device.appVersion, '1.0.0');
    });
  });

  group('HttpNotificationsApi.listRequest', () {
    const api = HttpNotificationsApi(UnimplementedApiClient());

    test('sends only unread / kind / page params', () {
      final request = api.listRequest(
        const NotificationListQuery(
          unread: true,
          kinds: {NotificationKind.confirmation, NotificationKind.reminder},
        ),
        page: 1,
        pageSize: 20,
      );
      expect(request.path, '/patient/notifications');
      final q = request.normalisedQuery;
      expect(q['unread'], 'true');
      expect(q['kind'], contains('confirmation'));
      expect(q['kind'], contains('reminder'));
      expect(q['page'], '1');
    });

    test('no filter → no filter params at all', () {
      final request = api.listRequest(
        const NotificationListQuery(),
        page: 2,
        pageSize: 20,
      );
      expect(request.normalisedQuery, {'page': '2', 'page_size': '20'});
    });
  });
}
