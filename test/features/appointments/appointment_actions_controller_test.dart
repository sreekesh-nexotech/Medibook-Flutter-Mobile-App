import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/appointments/application/providers/appointments_provider.dart';
import 'package:medibook/features/appointments/application/states/appointment_action_state.dart';
import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/appointments/infrastructure/repositories/appointment_mappers.dart';

import 'support/fixtures.dart';

/// Cancel / review / receipt actions: the Idempotency-Key contract (§1.8)
/// and the honest outcome reporting.
void main() {
  late FakeAppointmentsRepository repository;
  late ProviderContainer container;
  const id = Fixtures.appointmentId;

  setUp(() {
    repository = FakeAppointmentsRepository();
    container = ProviderContainer(
      overrides: [appointmentsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  AppointmentActionsController notifier() =>
      container.read(appointmentActionsProvider(id).notifier);

  test('preview is fetched and kept in state for the dialog', () async {
    final sub = container.listen(appointmentActionsProvider(id), (_, _) {});
    addTearDown(sub.close);
    final preview = await notifier().previewCancellation();
    expect(preview?.allowed, isTrue);
    expect(sub.read().preview?.refund.paise, 45000);
    expect(sub.read().isBusy, isFalse);
  });

  test('cancel mints one key, sends it, and clears it on success', () async {
    final sub = container.listen(appointmentActionsProvider(id), (_, _) {});
    addTearDown(sub.close);
    final outcome = await notifier().cancel(reason: 'Feeling better');
    expect(outcome?.appointment.status, AppointmentStatus.cancelled);
    expect(repository.cancelKeys, hasLength(1));
    expect(repository.cancelKeys.single, isNotEmpty);
    expect(repository.cancelReasons.single, 'Feeling better');
    expect(sub.read().failure, isNull);

    // A second, separate cancellation attempt gets a fresh key.
    await notifier().cancel();
    expect(repository.cancelKeys.toSet(), hasLength(2));
  });

  test('the same key is reused when a retryable failure is retried', () async {
    final sub = container.listen(appointmentActionsProvider(id), (_, _) {});
    addTearDown(sub.close);
    repository.cancelFailure = const TimeoutFailure();
    expect(await notifier().cancel(), isNull);
    expect(sub.read().failure, isA<TimeoutFailure>());

    repository.cancelFailure = null;
    expect(await notifier().cancel(), isNotNull);
    expect(repository.cancelKeys, hasLength(2));
    expect(repository.cancelKeys.first, repository.cancelKeys.last);
  });

  test('a 409 drops the key — the action is over, not retryable', () async {
    final sub = container.listen(appointmentActionsProvider(id), (_, _) {});
    addTearDown(sub.close);
    repository.cancelFailure = const ConflictFailure(
      apiCode: ApiErrorCodes.tokenAlreadyCalled,
    );
    expect(await notifier().cancel(), isNull);
    expect(sub.read().failure?.apiCode, ApiErrorCodes.tokenAlreadyCalled);

    repository.cancelFailure = null;
    await notifier().cancel();
    expect(repository.cancelKeys.toSet(), hasLength(2));
  });

  test('busy state blocks a double tap and clears afterwards', () async {
    final sub = container.listen(appointmentActionsProvider(id), (_, _) {});
    addTearDown(sub.close);
    final first = notifier().cancel();
    final second = notifier().cancel();
    expect(await second, isNull, reason: 'refused while busy');
    expect(await first, isNotNull);
    expect(repository.cancelKeys, hasLength(1));
    expect(sub.read().busy, isNull);
  });

  test('review returns the created review and invalidates the cache', () async {
    final review = await notifier().submitReview(rating: 5, comment: 'Great');
    expect(review?.rating, 5);
    expect(repository.invalidations, 1);
  });

  test('receipt PDF link and calendar file come back as values', () async {
    final sub = container.listen(appointmentActionsProvider(id), (_, _) {});
    addTearDown(sub.close);
    final link = await notifier().receiptPdfLink();
    expect(link?.url, startsWith('https://'));
    final path = await notifier().saveCalendar();
    expect(path, endsWith('.ics'));
    expect(sub.read().isRunning(AppointmentActionKind.calendar), isFalse);
  });

  test('a blocked preview is reported, not applied', () {
    final blocked = AppointmentMappers.cancellationPreview(
      Fixtures.previewJson(allowed: false),
    );
    expect(blocked.allowed, isFalse);
    expect(blocked.reason, 'APPOINTMENT_NOT_ACTIONABLE');
  });
}
