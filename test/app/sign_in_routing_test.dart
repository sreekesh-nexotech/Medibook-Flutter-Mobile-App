import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medibook/app/di/auth_dependencies.dart';
import 'package:medibook/app/app.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/core/storage/hive/boxes.dart';
import 'package:medibook/core/storage/hive/keys.dart';
import 'package:medibook/core/widgets/app_phone_field.dart';
import 'package:medibook/features/appointments/application/providers/appointments_provider.dart';
import 'package:medibook/features/appointments/presentation/screen/appointments_screen.dart';
import 'package:medibook/features/auth/application/providers/auth_provider.dart';
import 'package:medibook/features/auth/domain/entities/user.dart';
import 'package:medibook/features/auth/infrastructure/data_sources/remote/auth_api.dart';
import 'package:medibook/features/auth/presentation/screen/login_screen.dart';
import 'package:medibook/features/auth/presentation/screen/onboarding_screen.dart';
import 'package:medibook/features/auth/presentation/screen/signup_screen.dart';
import 'package:medibook/features/auth/presentation/screen/verify_code_screen.dart';
import 'package:medibook/features/dashboard/presentation/screen/home_screen.dart';

import '../features/appointments/support/fixtures.dart';
import '../support/offline_overrides.dart';

/// End-to-end through the real router: splash → (intro) → login → home, with
/// the backend replaced by a scripted [AuthApi] that answers in the real
/// payload shapes.
void main() {
  setUp(() async {
    HiveInit.store = InMemoryLocalStore();
  });

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget app() => ProviderScope(
    overrides: [
      ...offlineOverrides(),
      authApiProvider.overrideWithValue(_FakeAuthApi()),
    ],
    child: const MedibookApp(),
  );

  testWidgets('a fresh device lands on the intro', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('email + password Log In routes to Home', (tester) async {
    usePhoneSurface(tester);
    await HiveInit.store.write(
      HiveBoxes.settings,
      HiveKeys.onboardingComplete,
      true,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'anita@example.com');
    await tester.enterText(fields.at(1), 'seed_password_123');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(GestureDetector, 'Log In').first);
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  // BL-AUTH-050: a session ended elsewhere lands on sign-in with a reason.
  testWidgets('a revoked session is explained on the sign-in screen', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await HiveInit.store.write(
      HiveBoxes.settings,
      HiveKeys.onboardingComplete,
      true,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'anita@example.com');
    await tester.enterText(fields.at(1), 'seed_password_123');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(GestureDetector, 'Log In').first);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    await container
        .read(authProvider.notifier)
        .onSessionLost(
          const UnauthorizedFailure(apiCode: ApiErrorCodes.authSessionRevoked),
        );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('this session was ended'), findsOneWidget);
  });

  // BL-AUTH-008: the server takes Indian mobiles only for sign-in, so the
  // country code is +91 and cannot be changed (it used to offer +971 and
  // eight others, every one of which was then refused).
  testWidgets('mobile sign-in is fixed to +91', (tester) async {
    usePhoneSurface(tester);
    await HiveInit.store.write(
      HiveBoxes.settings,
      HiveKeys.onboardingComplete,
      true,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mobile'));
    await tester.pumpAndSettle();

    final chip = find.byType(AppCountryCodeChip);
    expect(find.descendant(of: chip, matching: find.text('+91')), findsOne);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.text('+971'), findsNothing, reason: 'no picker opens');
  });

  testWidgets('Mobile + OTP sign-in carries the challenge and routes to Home', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await HiveInit.store.write(
      HiveBoxes.settings,
      HiveKeys.onboardingComplete,
      true,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mobile'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '9845658525');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(GestureDetector, 'Send Code').first);
    await tester.pumpAndSettle();
    expect(find.byType(VerifyCodeScreen), findsOneWidget);

    // BL-AUTH-020: Resend unlocks only after resend_after_seconds, and the
    // code's own lifetime is counted down.
    expect(find.textContaining('Resend in 00:'), findsOneWidget);
    expect(find.text('Resend Code'), findsNothing);
    expect(find.textContaining('Code expires in'), findsOneWidget);

    // Four OTP boxes (code_length from the challenge).
    final boxes = find.byType(TextField);
    expect(boxes, findsNWidgets(4));
    for (var i = 0; i < 4; i++) {
      await tester.enterText(boxes.at(i), '1234'[i]);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(GestureDetector, 'Verify & Log In').first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  // BL-AUTH-005 (owner decision): links must never skip the intro.
  group('a link opened while the app is running', () {
    /// What the platform sends when a link is opened with the app open.
    Future<void> openLink(WidgetTester tester, String link) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        const JSONMethodCodec().encodeMethodCall(
          MethodCall('pushRouteInformation', <String, Object?>{
            'location': link,
            'state': null,
          }),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
    }

    for (final link in [
      'medibook://signup',
      'medibook://login',
      'https://medibook.app/signup',
      'medibook://faq',
    ]) {
      testWidgets('$link on a fresh device stays on the intro', (tester) async {
        usePhoneSurface(tester);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();

        await openLink(tester, link);

        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(find.byType(SignupScreen), findsNothing);
        expect(find.byType(LoginScreen), findsNothing);
      });
    }

    testWidgets('opens its screen once the intro has been completed', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await HiveInit.store.write(
        HiveBoxes.settings,
        HiveKeys.onboardingComplete,
        true,
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await openLink(tester, 'medibook://signup');

      expect(find.byType(SignupScreen), findsOneWidget);
    });
  });

  // A booking made on another screen was missing from Upcoming until a pull
  // to refresh: arriving at the Appointments tab now reads the list again.
  testWidgets('arriving at the Appointments tab re-reads the list', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await HiveInit.store.write(
      HiveBoxes.settings,
      HiveKeys.onboardingComplete,
      true,
    );
    final appointments = FakeAppointmentsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...offlineOverrides(),
          authApiProvider.overrideWithValue(_FakeAuthApi()),
          appointmentsRepositoryProvider.overrideWithValue(appointments),
        ],
        child: const MedibookApp(),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'anita@example.com');
    await tester.enterText(fields.at(1), 'seed_password_123');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(GestureDetector, 'Log In').first);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    Future<void> openTab(String name) async {
      await tester.tap(find.bySemanticsLabel(RegExp('^$name')).first);
      await tester.pumpAndSettle();
    }

    await openTab('Appointments');
    expect(find.byType(AppointmentsScreen), findsOneWidget);
    final afterFirstVisit = appointments.listCalls;
    expect(afterFirstVisit, greaterThan(0));

    await openTab('Home');
    final whileAway = appointments.listCalls;
    await openTab('Appointments');

    expect(
      appointments.listCalls,
      greaterThan(whileAway),
      reason: 'coming back to the tab must read the list again',
    );
  });

  testWidgets('a fresh device cannot reach sign-up by its path either', (
    tester,
  ) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    GoRouter.of(tester.element(find.byType(OnboardingScreen))).go('/signup');
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(SignupScreen), findsNothing);
  });
}

class _FakeAuthApi implements AuthApi {
  Map<String, Object?> _tokens() => {
    'access': 'acc',
    'refresh': 'ref',
    'access_expires_in': 900,
    'session_id': 'sess',
    'user': {
      'id': 'u-1',
      'first_name': 'Anita',
      'last_name': 'Menon',
      'phone_e164': '+919845658525',
      'email': 'anita@example.com',
      'has_password': true,
      'status': 'active',
      'locale': 'en-IN',
      'timezone': 'Asia/Kolkata',
      'version': 1,
    },
  };

  Map<String, Object?> _challenge() => {
    'challenge_id': 'ch-1',
    'code_length': 4,
    'expires_at': DateTime.now()
        .add(const Duration(seconds: 180))
        .toUtc()
        .toIso8601String(),
    'resend_after_seconds': 30,
    'destination_masked': '+91******25',
  };

  @override
  Future<Map<String, Object?>> loginWithPassword({
    required String identifier,
    required String password,
    String? deviceId,
  }) async => _tokens();

  @override
  Future<Map<String, Object?>> startOtpLogin({
    required String phoneE164,
  }) async => _challenge();

  @override
  Future<Map<String, Object?>> verifyOtpLogin({
    required String challengeId,
    required String code,
    String? deviceId,
  }) async => _tokens();

  @override
  Future<Map<String, Object?>> resendOtp({required String challengeId}) async =>
      _challenge();

  @override
  Future<Map<String, Object?>> startSignup(SignupRequest request) async =>
      _challenge();

  @override
  Future<Map<String, Object?>> verifySignup({
    required String challengeId,
    required String code,
  }) async => _tokens();

  @override
  Future<Map<String, Object?>> startPasswordReset({
    required String identifier,
  }) async => _challenge();

  @override
  Future<Map<String, Object?>> verifyPasswordReset({
    required String challengeId,
    required String code,
  }) async => {'reset_token': 'rt'};

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {}

  @override
  Future<Map<String, Object?>> refresh({required String refreshToken}) async =>
      _tokens();

  @override
  Future<void> logout() async {}

  @override
  Future<void> logoutAll() async {}

  @override
  Future<Map<String, Object?>> me() async => {
    'user': _tokens()['user'],
    'profile': null,
  };

  @override
  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  }) async {}
}
