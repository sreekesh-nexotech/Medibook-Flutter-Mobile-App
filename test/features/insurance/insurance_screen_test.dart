import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/connectivity/connectivity_monitor.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/features/common/attachments/application/providers/attachments_provider.dart';
import 'package:medibook/features/insurance/application/providers/insurance_provider.dart';
import 'package:medibook/features/insurance/presentation/screen/insurance_screen.dart';

import '../../support/harness.dart';
import '../common/attachments/attachment_upload_controller_test.dart';
import 'insurance_controllers_test.dart';

/// The insurance locker's states: empty, error, content with the expired
/// policy announced, and the feature-flag-off screen.
void main() {
  late FakeInsuranceRepository repository;

  setUp(() {
    repository = FakeInsuranceRepository();
  });

  Widget screen({bool enabled = true}) => screenHarness(
    const InsuranceScreen(),
    overrides: [
      insuranceRepositoryProvider.overrideWithValue(repository),
      insuranceEnabledProvider.overrideWithValue(enabled),
      fileUploadServiceProvider.overrideWithValue(FakeFileUploadService()),
      isOnlineProvider.overrideWith((ref) => Stream.value(true)),
    ],
  );

  testWidgets('no policies shows the empty state', (tester) async {
    await tester.pumpWidget(screen());
    await tester.pump();
    await tester.pump();
    expect(find.text('No insurance saved'), findsOneWidget);
    expect(find.text('Add a Policy'), findsOneWidget);
  });

  testWidgets('a failed load shows the error view', (tester) async {
    repository.watchError = const NetworkFailure();
    await tester.pumpWidget(screen());
    await tester.pump();
    await tester.pump();
    expect(find.text('We could not load your policies'), findsOneWidget);
  });

  testWidgets('the flag off shows the unavailable screen', (tester) async {
    await tester.pumpWidget(screen(enabled: false));
    await tester.pump();
    expect(find.text('Insurance is not available right now'), findsOneWidget);
  });
}
