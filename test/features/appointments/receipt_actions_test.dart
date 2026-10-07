import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/widgets/toast/toast_controller.dart';
import 'package:medibook/features/appointments/application/providers/appointments_provider.dart';
import 'package:medibook/features/appointments/domain/entities/receipt.dart';
import 'package:medibook/features/appointments/presentation/components/calendar_action.dart';

import 'support/fixtures.dart';

/// BL-APPT-058: tapping "Add to calendar" while the receipt PDF is still
/// being fetched used to be refused quietly by the controller and then
/// reported as "Could not download the calendar file." — a false error.
void main() {
  const id = Fixtures.appointmentId;

  testWidgets('a tap while another receipt action runs is ignored, not an '
      'error', (tester) async {
    final repository = _SlowReceiptRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appointmentsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              // Keeps the (autoDispose) actions controller alive, as the
              // receipt screen does.
              ref.watch(appointmentActionsProvider(id));
              return TextButton(
                onPressed: () => addAppointmentToCalendar(context, ref, id),
                child: const Text('Add to calendar'),
              );
            },
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TextButton)),
    );

    // "Download PDF" is in flight …
    final pdf = container
        .read(appointmentActionsProvider(id).notifier)
        .receiptPdfLink();
    await tester.pump();
    expect(container.read(appointmentActionsProvider(id)).isBusy, isTrue);

    // … and the patient taps "Add to calendar".
    await tester.tap(find.text('Add to calendar'));
    await tester.pump();

    expect(
      container.read(toastControllerProvider),
      isNull,
      reason: 'nothing failed, so nothing is reported',
    );
    expect(repository.calendarCalls, 0);

    repository.gate.complete();
    expect(await pdf, isNotNull);
  });

  // BL-APPT-063: when the file downloads but nothing on the device takes
  // it, the message is about the device, not the download.
  testWidgets('no app to take the calendar file says so', (tester) async {
    final repository = _SlowReceiptRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appointmentsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              ref.watch(appointmentActionsProvider(id));
              return TextButton(
                onPressed: () => addAppointmentToCalendar(context, ref, id),
                child: const Text('Add to calendar'),
              );
            },
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TextButton)),
    );

    // The download succeeds; the share sheet is unavailable (as in a test
    // run, where the platform has no share plugin).
    await tester.runAsync(() async {
      await tester.tap(find.text('Add to calendar'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    expect(repository.calendarCalls, 1);
    expect(
      container.read(toastControllerProvider)?.text,
      'No app on this device could take the calendar file.',
    );
    // Let the toast's auto-dismiss timer finish.
    await tester.pump(const Duration(seconds: 10));
  });
}

/// A repository whose receipt PDF link takes as long as the test wants.
class _SlowReceiptRepository extends FakeAppointmentsRepository {
  final Completer<void> gate = Completer<void>();
  int calendarCalls = 0;

  @override
  Future<ReceiptPdfLink> receiptPdfLink(String id) async {
    await gate.future;
    return super.receiptPdfLink(id);
  }

  @override
  Future<String> saveCalendarFile(String id) {
    calendarCalls++;
    return super.saveCalendarFile(id);
  }
}
