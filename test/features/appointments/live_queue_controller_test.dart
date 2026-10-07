import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/realtime/ws_client.dart';
import 'package:medibook/features/appointments/application/providers/appointments_provider.dart';
import 'package:medibook/features/appointments/application/states/live_queue_state.dart';
import 'package:medibook/features/appointments/infrastructure/repositories/appointment_mappers.dart';

import 'support/fixtures.dart';

/// The live-queue owner (§10.5 + §15.1): REST first, socket frames drive
/// re-fetches and "your turn", 4401 refreshes the token, disposal closes.
void main() {
  late FakeAppointmentsRepository repository;
  late List<FakeWsClient> sockets;
  late int refreshes;
  late bool failRefresh;
  const id = Fixtures.appointmentId;

  setUp(() {
    repository = FakeAppointmentsRepository();
    sockets = [];
    refreshes = 0;
    failRefresh = false;
  });

  LiveQueueController build({int refuseHandshakes = 0}) => LiveQueueController(
    repository: repository,
    appointmentId: id,
    openSocket: (path) {
      final socket = FakeWsClient(path)
        ..refuseHandshake = sockets.length < refuseHandshakes;
      sockets.add(socket);
      return socket;
    },
    refreshSession: () async {
      refreshes++;
      if (failRefresh) throw const UnauthorizedFailure();
    },
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('fetches the queue and opens the session socket', () async {
    final controller = build();
    addTearDown(controller.dispose);
    await settle();
    expect(controller.state.isLoading, isFalse);
    expect(controller.state.queue?.yourToken, 'A002');
    expect(sockets.single.path, '/ws/patient/session/$id');
    expect(sockets.single.connectCalls, 1);
    expect(controller.state.connection, LiveQueueConnection.live);
    expect(repository.queueCalls, 1);
  });

  // Checklist QUEUE-009: leaving the screen closes the socket for good.
  test('dispose closes the socket and nothing reconnects', () async {
    final controller = build();
    await settle();
    expect(sockets.single.disposed, isFalse);

    controller.dispose();
    await settle();
    expect(sockets.single.disposed, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(sockets, hasLength(1), reason: 'no new socket after leaving');
  });

  test('session.updated re-fetches the endpoint', () async {
    final controller = build();
    addTearDown(controller.dispose);
    await settle();
    sockets.single.emit('session.updated', {'status': 'open'});
    await settle();
    expect(repository.queueCalls, 2);
  });

  test('token.called for this appointment is "your turn"', () async {
    final controller = build();
    addTearDown(controller.dispose);
    await settle();
    sockets.single.emit('token.called', {
      'token_label': 'A001',
      'appointment_id': 'someone-else',
    });
    await settle();
    expect(controller.state.isYourTurn, isFalse);

    sockets.single.emit('token.called', {
      'token_label': 'A002',
      'appointment_id': id,
    });
    await settle();
    expect(controller.state.isYourTurn, isTrue);
    expect(controller.state.calledAt, isNotNull);
  });

  test('a 4401 close refreshes the session and reconnects', () async {
    final controller = build();
    addTearDown(controller.dispose);
    await settle();
    sockets.first.close(WsCloseReason.unauthorized);
    await settle();
    await settle();
    expect(refreshes, 1);
    expect(sockets, hasLength(2));
    expect(sockets.first.disposed, isTrue);
    expect(controller.state.connection, LiveQueueConnection.live);
  });

  test(
    'a failed token refresh leaves the REST reading and goes offline',
    () async {
      failRefresh = true;
      final controller = build();
      addTearDown(controller.dispose);
      await settle();
      sockets.first.close(WsCloseReason.unauthorized);
      await settle();
      await settle();
      expect(controller.state.connection, LiveQueueConnection.offline);
      expect(controller.state.queue, isNotNull);
      expect(sockets, hasLength(1));
    },
  );

  test('a handshake refused with 403 (an expired token on the live server) '
      'refreshes the session once and reconnects', () async {
    final controller = build(refuseHandshakes: 1);
    addTearDown(controller.dispose);
    await settle();
    await settle();
    expect(refreshes, 1);
    expect(sockets, hasLength(2));
    expect(sockets.first.disposed, isTrue);
    expect(controller.state.connection, LiveQueueConnection.live);
  });

  test('a handshake refused again after the refresh backs off instead of '
      'refreshing in a loop', () async {
    final controller = build(refuseHandshakes: 2);
    addTearDown(controller.dispose);
    await settle();
    await settle();
    expect(refreshes, 1);
    expect(sockets, hasLength(2));
    expect(controller.state.connection, LiveQueueConnection.reconnecting);
  });

  // BL-QUEUE-015: another patient's appointment is refused whatever the
  // token; six rounds of retries used to mean six session refreshes.
  test(
    'later retries do not refresh again once a fresh token was refused',
    () async {
      final controller = build(refuseHandshakes: 99);
      addTearDown(controller.dispose);
      await settle();
      await settle();
      expect(refreshes, 1);
      expect(sockets, hasLength(2));

      // The first backoff (2 s) fires and the handshake is refused again.
      await Future<void>.delayed(const Duration(milliseconds: 2400));
      await settle();

      expect(sockets.length, greaterThan(2), reason: 'it did retry');
      expect(refreshes, 1, reason: 'without refreshing the session again');
    },
  );

  // BL-QUEUE-013: "Live updates unavailable. Pull down to refresh." — the
  // pull used to re-read the queue only, so live updates stayed off.
  test('pull to refresh restarts live updates after they gave up', () async {
    final controller = build();
    addTearDown(controller.dispose);
    await settle();
    for (var i = 0; i <= LiveQueueController.maxReconnects; i++) {
      sockets.first.close(WsCloseReason.other);
      await settle();
    }
    expect(controller.state.connection, LiveQueueConnection.offline);
    final socketsBefore = sockets.length;

    await controller.pullToRefresh();
    await settle();

    expect(sockets.length, socketsBefore + 1, reason: 'a new socket');
    expect(controller.state.connection, LiveQueueConnection.live);
  });

  test('pull to refresh while live does not open another socket', () async {
    final controller = build();
    addTearDown(controller.dispose);
    await settle();
    await controller.pullToRefresh();
    await settle();
    expect(sockets, hasLength(1));
  });

  test('an idle close schedules a reconnect', () async {
    final controller = build();
    addTearDown(controller.dispose);
    await settle();
    sockets.first.close(WsCloseReason.idle);
    await settle();
    expect(controller.state.connection, LiveQueueConnection.reconnecting);
  });

  test('a REST failure with a reading already shown is a banner, not a '
      'blank screen', () async {
    final controller = build();
    addTearDown(controller.dispose);
    await settle();
    repository.queueFailure = const NetworkFailure();
    await controller.refresh();
    expect(controller.state.queue, isNotNull);
    expect(controller.state.failure, isA<NetworkFailure>());
  });

  test('the queue over clears "your turn"', () async {
    final controller = build();
    addTearDown(controller.dispose);
    await settle();
    sockets.single.emit('token.called', {'appointment_id': id});
    await settle();
    repository.queueValue = AppointmentMappers.queue({
      ...Fixtures.queueJson(),
      'session_state': 'closed',
    });
    await controller.refresh();
    expect(controller.state.isYourTurn, isFalse);
  });

  test('dispose closes the socket', () async {
    final controller = build();
    await settle();
    controller.dispose();
    await settle();
    expect(sockets.single.disposed, isTrue);
  });
}
