import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/api_client.dart' show Page;
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/features/booking/domain/entities/hospital.dart';
import 'package:medibook/features/dashboard/application/providers/home_providers.dart';
import 'package:medibook/features/dashboard/presentation/screen/home_screen.dart';

import '../../support/harness.dart';
import '../../support/offline_overrides.dart';

/// Checklist HOME-010: one failed Home request must not blank the screen,
/// and the failed section's Retry must load it again.
void main() {
  testWidgets('the hospitals section fails alone and Retry reloads it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    HiveInit.store = InMemoryLocalStore();

    var calls = 0;
    await tester.pumpWidget(
      screenHarness(
        const HomeScreen(),
        overrides: [
          ...offlineOverrides(),
          homeHospitalsProvider.overrideWith((ref) async* {
            calls++;
            if (calls == 1) throw const ServerFailure();
            yield CachedResult(
              value: const Page(
                results: [
                  HospitalCard(
                    id: 'h1',
                    slug: 'lakeshore',
                    name: 'Lakeshore Multispeciality Hospital',
                    city: 'Kochi',
                    departments: [],
                    onlineBookingEnabled: true,
                  ),
                ],
                page: 1,
                pageSize: 25,
                total: 1,
                hasNext: false,
              ),
              source: CacheSource.network,
              cachedAt: DateTime.now(),
            );
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // The rest of Home is there.
    expect(find.text('Quick Booking'), findsOneWidget);
    expect(find.text('Hospitals Near You'), findsOneWidget);

    final retry = find.text('Try Again').last;
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(calls, 2, reason: 'Retry must reload the section it sits in');
    expect(
      find.textContaining('Lakeshore Multispeciality Hospital'),
      findsWidgets,
    );
  });
}
