import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/config/constants.dart';
import 'package:medibook/core/widgets/app_date_picker_sheet.dart';

/// UAT 16 Oct (DEF-003): reaching a parent's 1958 birth year took 58 taps on
/// "Previous year". The year label now opens a list of every year.
void main() {
  Future<void> pumpCalendar(
    WidgetTester tester,
    ValueChanged<DateTime> onPick,
  ) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      ScreenUtilInit(
        designSize: AppConstants.designSize,
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppMonthCalendar(
                initialDay: DateTime(2016, 10, 15),
                firstDay: DateTime(1900),
                lastDay: DateTime(2026, 10, 16),
                onDaySelected: onPick,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the year label opens a list and jumps to the chosen year', (
    tester,
  ) async {
    DateTime? picked;
    await pumpCalendar(tester, (d) => picked = d);

    expect(find.text('October 2016'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Choose a year, currently 2016'));
    await tester.pumpAndSettle();

    // Month grid gives way to the year list.
    expect(find.text('October 2016'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('1958'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(find.text('1958'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1958'));
    await tester.pumpAndSettle();

    expect(find.text('October 1958'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('15 Oct 1958'));
    await tester.pumpAndSettle();
    expect(picked, DateTime(1958, 10, 15));
  });

  testWidgets('a short range has no year list', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: AppConstants.designSize,
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: AppMonthCalendar(
              firstDay: DateTime(2026, 10, 16),
              lastDay: DateTime(2026, 11, 14),
            ),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel(RegExp('Choose a year')), findsNothing);
  });
}
