import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/config/constants.dart';
import 'package:medibook/core/widgets/app_switch.dart';

/// UAT UX-009: TalkBack must hear a switch and whether it is on.
void main() {
  Future<void> pump(WidgetTester tester, bool value, {bool enabled = true}) {
    return tester.pumpWidget(
      ScreenUtilInit(
        designSize: AppConstants.designSize,
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: AppSwitch(
              value: value,
              onChanged: enabled ? (_) {} : null,
              semanticLabel: 'Receive offers',
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('announces its on/off state', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, true);
    expect(
      tester.getSemantics(find.byType(AppSwitch)),
      isSemantics(
        label: 'Receive offers',
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    await pump(tester, false);
    expect(
      tester.getSemantics(find.byType(AppSwitch)),
      isSemantics(hasToggledState: true, isToggled: false),
    );
    handle.dispose();
  });

  testWidgets('a switch without onChanged reads as disabled', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, true, enabled: false);
    expect(
      tester.getSemantics(find.byType(AppSwitch)),
      isSemantics(hasEnabledState: true, isEnabled: false),
    );
    handle.dispose();
  });
}
