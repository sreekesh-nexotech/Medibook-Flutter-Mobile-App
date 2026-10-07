import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/booking/domain/entities/promo_banner.dart';
import 'package:medibook/features/dashboard/presentation/components/promo_banner_card.dart';

import '../../support/harness.dart';

/// Checklist HOME-006 (owner decision 6 Oct 2026): the promo strip
/// auto-rotates, but never against reduced motion or the patient's finger.
void main() {
  final banners = [
    for (var i = 0; i < 3; i++)
      HospitalBanner(id: 'b$i', title: 'Offer $i', hospitalId: 'h$i'),
  ];

  Widget strip({bool reduceMotion = false}) => harness(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: PromoBannerCard(banners: banners, onTap: (_) {}),
      ),
    ),
  );

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  double offset(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

  testWidgets('moves to the next card every 4 s and wraps to the first', (
    tester,
  ) async {
    await tester.pumpWidget(strip());
    await tester.pumpAndSettle();
    expect(offset(tester), 0);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(offset(tester), greaterThan(0));
    final first = offset(tester);

    // Keep going until the end, then it must come back to the start.
    var wrapped = false;
    for (var i = 0; i < 4 && !wrapped; i++) {
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      wrapped = offset(tester) == 0;
    }
    expect(first, greaterThan(0));
    expect(wrapped, isTrue);
  });

  testWidgets('stays still when the phone asks for reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(strip(reduceMotion: true));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();
    expect(offset(tester), 0);
  });

  testWidgets('does not move while the patient is holding it', (tester) async {
    await tester.pumpWidget(strip());
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Offer 0')),
    );
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(offset(tester), 0);
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
