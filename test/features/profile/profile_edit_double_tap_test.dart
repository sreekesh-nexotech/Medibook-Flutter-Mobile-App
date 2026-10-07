import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medibook/app/config/constants.dart';
import 'package:medibook/app/router/app_routes.dart';
import 'package:medibook/app/theme/theme.dart';
import 'package:medibook/core/widgets/app_text_field.dart';
import 'package:medibook/core/widgets/toast/toast_controller.dart';
import 'package:medibook/features/profile/presentation/screen/profile_edit_screen.dart';

import 'profile_test_support.dart';

/// BL-CACHE-024: a second tap on Save in the same frame — before the button
/// shows its spinner — used to come back as "nothing to report", which the
/// screen read as success: 'Profile updated' and the screen closed while the
/// real save was still running.
void main() {
  testWidgets('a double tap on Save sends one save and no early success', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = FakeAuthRepository();
    final profile = FakeProfileRepository();
    final release = Completer<void>();
    profile.holdUpdate = release.future;
    final container = (await tester.runAsync(
      () => authenticatedContainer(auth: auth, profile: profile),
    ))!;
    addTearDown(container.dispose);
    final toasts = <String>[];
    container.listen<ToastMessage?>(toastControllerProvider, (_, next) {
      if (next != null) toasts.add(next.text);
    });

    final router = GoRouter(
      initialLocation: '${AppRoutes.profile}/edit',
      routes: [
        GoRoute(
          path: AppRoutes.profile,
          builder: (_, _) => const Scaffold(body: Text('Profile page')),
          routes: [
            GoRoute(path: 'edit', builder: (_, _) => const ProfileEditScreen()),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: AppConstants.designSize,
          builder: (_, _) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            builder: (context, page) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.noScaling),
              child: page!,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final lastName = find.descendant(
      of: find.widgetWithText(AppTextField, 'Last name'),
      matching: find.byType(EditableText),
    );
    expect(lastName, findsOneWidget);
    await tester.enterText(lastName, 'Nair');
    await tester.pump();

    final save = find.text('Save Changes');
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    // Two taps in the same frame: no pump in between.
    await tester.tap(save);
    await tester.tap(save);
    await tester.pump();

    expect(profile.updates, hasLength(1), reason: 'one save request');
    expect(toasts, isEmpty, reason: 'nothing is saved yet');
    expect(find.byType(ProfileEditScreen), findsOneWidget);

    release.complete();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(toasts, ['Profile updated']);
    expect(find.text('Profile page'), findsOneWidget);
    // Let the toast's display timer run out.
    await tester.pump(AppConstants.toastLifetime);
  });
}
