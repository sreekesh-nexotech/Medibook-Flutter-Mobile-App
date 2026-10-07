import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/config/constants.dart';
import 'package:medibook/core/widgets/toast/toast_controller.dart';
import 'package:medibook/core/widgets/toast/toast_host.dart';

/// The toast host sits above every Scaffold (it wraps the app's pages in
/// `MaterialApp.builder`). Its text used to be drawn with Flutter's "no text
/// style" fallback — a yellow double underline.
void main() {
  testWidgets('toast text is not underlined', (tester) async {
    // Mounted exactly as `app/app.dart` mounts it: above the navigator, where
    // no Material supplies a text style.
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: AppConstants.designSize,
          builder: (_, _) => MaterialApp(
            builder: (context, page) => ToastHost(child: page!),
            home: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ToastHost)),
    );

    container
        .read(toastControllerProvider.notifier)
        .show('Appointment cancelled.');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final text = tester.widget<RichText>(
      find.byWidgetPredicate(
        (w) =>
            w is RichText && w.text.toPlainText() == 'Appointment cancelled.',
      ),
    );
    expect(text.text.style?.decoration, isNot(TextDecoration.underline));
    expect(text.text.style?.color, Colors.white);

    // Let the auto-dismiss timer run out so nothing is left pending.
    await tester.pump(const Duration(seconds: 10));
  });
}
