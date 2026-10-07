import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/connectivity/connectivity_monitor.dart';
import 'package:medibook/features/common/cached/application/states/cached_state.dart';
import 'package:medibook/features/common/cached/presentation/components/cached_status_bar.dart';

import '../../support/harness.dart';

/// The status bar over every shared cached list (Family Members, Addresses,
/// FAQ, tickets …): offline, a failed refresh is said once.
void main() {
  Widget bar(CachedState<List<int>> state, {required bool online}) =>
      screenHarness(
        Scaffold(
          body: CachedStatusBar(state: state, onRefresh: () {}),
        ),
        overrides: [
          isOnlineProvider.overrideWith((ref) => Stream.value(online)),
        ],
      );

  testWidgets('offline, a failed refresh adds no second offline banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      bar(
        const CachedState(value: [1], failure: NetworkFailure()),
        online: false,
      ),
    );
    await tester.pump();
    // Offline is said once, by the app-wide OfflineBar: this bar adds
    // neither its own offline line nor the red network failure.
    expect(find.textContaining("You're offline"), findsNothing);
    expect(find.text(const NetworkFailure().userMessage), findsNothing);
  });

  testWidgets('online, a failed refresh is still shown', (tester) async {
    await tester.pumpWidget(
      bar(
        const CachedState(value: [1], failure: ServerFailure()),
        online: true,
      ),
    );
    await tester.pump();
    expect(find.text(const ServerFailure().userMessage), findsOneWidget);
  });

  testWidgets('offline, a failure that is not about the network is shown', (
    tester,
  ) async {
    await tester.pumpWidget(
      bar(
        const CachedState(value: [1], failure: ServerFailure()),
        online: false,
      ),
    );
    await tester.pump();
    expect(find.text(const ServerFailure().userMessage), findsOneWidget);
  });
}
