import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/profile/domain/entities/account.dart';
import 'package:medibook/features/profile/infrastructure/repositories/profile_mappers.dart';
import 'package:medibook/features/profile/presentation/screen/data_export_screen.dart';

import '../../support/harness.dart';

/// UB-55 / DEF-045: `completed_at` is set for every closed request, rejected
/// ones too, so the "ready" date must come from `ready_at` only; a rejected
/// request shows the server's label, its rejection date and the reason
/// compliance typed.
void main() {
  // The live rows on app-dev (18 Oct 2026), Sanjay's and Asha's.
  const rejected = {
    'id': '01a1411e-1bda-7d91-8b52-5b2d6f3f2dae',
    'request_no': 'DSR-2026-0003',
    'kind': 'export',
    'status': 'rejected',
    'status_label': 'Rejected',
    'requested_at': '2026-10-15T19:50:54.671262Z',
    'due_at': '2026-11-14T19:50:54.671262Z',
    'completed_at': '2026-10-18T08:28:39.480600Z',
    'ready_at': null,
    'rejected_at': '2026-10-18T08:28:39.480600Z',
    'rejection_reason':
        'UAT retest: duplicate test request - please raise a new one if '
        'needed.',
  };
  const completed = {
    'id': '01a12647-e3d0-7dd2-8496-0a706207106f',
    'request_no': 'DSR-2026-0001',
    'kind': 'export',
    'status': 'completed',
    'status_label': 'Ready',
    'requested_at': '2026-10-10T14:46:47.997880Z',
    'due_at': '2026-11-09T14:46:47.997880Z',
    'completed_at': '2026-10-10T14:46:48.028476Z',
    'ready_at': '2026-10-10T14:46:48.028476Z',
    'rejected_at': null,
    'rejection_reason': null,
  };

  test('a rejected request is never "ready"', () {
    final request = ProfileMappers.dataExport(rejected);
    expect(request.label, 'Rejected');
    expect(request.readyOn, isNull);
    expect(request.rejectedOn, DateTime.utc(2026, 10, 18, 8, 28, 39, 480, 600));
    expect(
      request.shownRejectionReason,
      startsWith('UAT retest: duplicate test request'),
    );
    expect(
      DataExportRequestCard.datesLine(request),
      matches(RegExp(r'^Requested 1[56] Oct 2026 · rejected 18 Oct 2026$')),
    );
  });

  test('a completed request is ready on ready_at, with no reason', () {
    final request = ProfileMappers.dataExport(completed);
    expect(request.label, 'Ready');
    expect(request.rejectedOn, isNull);
    expect(request.shownRejectionReason, isNull);
    expect(
      DataExportRequestCard.datesLine(request),
      'Requested 10 Oct 2026 · ready 10 Oct 2026',
    );
  });

  test('an older server without the new fields still reads sensibly', () {
    final request = ProfileMappers.dataExport({
      ...rejected,
      'status_label': null,
      'rejected_at': null,
      'rejection_reason': null,
    });
    expect(request.label, DataExportStatus.rejected.label);
    expect(DataExportRequestCard.datesLine(request), contains('rejected'));
    expect(DataExportRequestCard.datesLine(request), isNot(contains('ready')));
  });

  testWidgets('the card shows Rejected, the date and the reason', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        DataExportRequestCard(
          request: ProfileMappers.dataExport(rejected),
          isLinking: false,
          disabled: false,
          onDownload: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.textContaining('rejected 18 Oct 2026'), findsOneWidget);
    expect(find.textContaining('ready'), findsNothing);
    expect(
      find.text(
        'Reason: UAT retest: duplicate test request - please raise a new one '
        'if needed.',
      ),
      findsOneWidget,
    );
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.text('Download'), findsNothing);
  });
}
