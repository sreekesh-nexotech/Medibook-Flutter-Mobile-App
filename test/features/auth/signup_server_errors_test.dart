import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/di/dependencies.dart';
import 'package:medibook/app/di/auth_dependencies.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/core/widgets/app_phone_field.dart';
import 'package:medibook/features/auth/application/providers/auth_provider.dart';
import 'package:medibook/features/auth/application/providers/onboarding_provider.dart';
import 'package:medibook/features/auth/domain/entities/user.dart';
import 'package:medibook/features/auth/infrastructure/data_sources/remote/auth_api.dart';
import 'package:medibook/features/auth/application/providers/auth_flow_draft.dart';
import 'package:medibook/features/auth/application/providers/signup_form_controller.dart';
import 'package:mocktail/mocktail.dart';

/// The server's sign-up rejections must land on the form. Seen live:
/// `POST /auth/signup/start` → `400 VALIDATION_ERROR` with
/// `errors.password = ["The password must not contain your name, email or
/// phone number."]` (a rule the contract does not list, so the client cannot
/// pre-validate it).
void main() {
  late ProviderContainer container;
  late _MockAuthApi api;

  setUpAll(() => registerFallbackValue(_FakeSignupRequest()));

  setUp(() async {
    HiveInit.store = InMemoryLocalStore();
    api = _MockAuthApi();
    container = ProviderContainer(
      overrides: [...appDependencies(), authApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    await container.read(authProvider.notifier).restore();
  });

  SignupDraft draft() => SignupDraft(
    firstName: 'Emulator',
    lastName: 'Tester',
    email: 'emulator.tester@example.com',
    countryCode: CountryCodes.india,
    phoneNational: '9876501234',
    dateOfBirth: DateTime(2008, 9, 10),
  );

  test('a server password rule shows on the password field', () async {
    when(() => api.startSignup(any())).thenThrow(
      HttpStatusException.fromBody(400, {
        'code': 'VALIDATION_ERROR',
        'message': 'Some fields are invalid.',
        'errors': {
          'password': [
            'The password must not contain your name, email or phone number.',
          ],
        },
        'request_id': 'r1',
        'meta': <String, Object?>{},
      }),
    );
    final keep = container.listen(signupFormControllerProvider, (_, _) {});
    addTearDown(keep.close);
    final form = container.read(signupFormControllerProvider.notifier);

    final challenge = await form.startMobileVerification(
      draft(),
      password: 'EmulatorPass123',
    );

    expect(challenge, isNull);
    final state = container.read(signupFormControllerProvider);
    expect(
      state.errorOf(SignupFields.password),
      contains('must not contain your name'),
    );
    expect(state.failure, isNull, reason: 'field errors are not form-level');
    expect(state.isBusy, isFalse);
  });

  test(
    'losing focus keeps a server error; editing the field clears it',
    () async {
      when(() => api.startSignup(any())).thenThrow(
        HttpStatusException.fromBody(400, {
          'code': 'VALIDATION_ERROR',
          'errors': {
            'password': ['The password must not contain your name.'],
          },
        }),
      );
      final keep = container.listen(signupFormControllerProvider, (_, _) {});
      addTearDown(keep.close);
      final form = container.read(signupFormControllerProvider.notifier);
      await form.startMobileVerification(draft(), password: 'EmulatorPass123');

      // The request disables the fields, which blurs them (seen on device).
      form.onBlur(SignupFields.password, 'EmulatorPass123');
      expect(
        container
            .read(signupFormControllerProvider)
            .errorOf(SignupFields.password),
        isNotNull,
        reason: 'a blur must not wipe the server message',
      );

      form.onPasswordChanged('Str0ng-Pass-2026', confirm: 'Str0ng-Pass-2026');
      expect(
        container
            .read(signupFormControllerProvider)
            .errorOf(SignupFields.password),
        isNull,
        reason: 'an edit re-validates on the client',
      );
    },
  );

  test('a phone already registered shows on the phone field', () async {
    when(() => api.startSignup(any())).thenThrow(
      HttpStatusException.fromBody(400, {
        'code': 'VALIDATION_ERROR',
        'errors': {
          'phone_e164': ['An account with this number already exists.'],
        },
      }),
    );
    final keep = container.listen(signupFormControllerProvider, (_, _) {});
    addTearDown(keep.close);
    final form = container.read(signupFormControllerProvider.notifier);
    await form.startMobileVerification(draft());
    expect(
      container.read(signupFormControllerProvider).errorOf(SignupFields.phone),
      contains('already exists'),
    );
  });

  // BL-AUTH-004: the offers box ticked in onboarding has to reach the account.
  group('the onboarding offers opt-in is sent as consents.marketing', () {
    Future<SignupRequest> sentAfterOnboarding({
      required bool offersOptIn,
    }) async {
      await container
          .read(onboardingProvider.notifier)
          .complete(offersOptIn: offersOptIn, acceptedTermsVersion: '3');
      when(() => api.startSignup(any())).thenAnswer(
        (_) async => <String, Object?>{
          'challenge_id': 'c1',
          'channel': 'sms',
          'code_length': 4,
          'expires_in_seconds': 300,
          'resend_after_seconds': 30,
        },
      );
      final keep = container.listen(signupFormControllerProvider, (_, _) {});
      addTearDown(keep.close);
      final form = container.read(signupFormControllerProvider.notifier);

      final challenge = await form.startMobileVerification(draft());

      expect(challenge, isNotNull);
      return verify(() => api.startSignup(captureAny())).captured.single
          as SignupRequest;
    }

    test('ticked → marketing is true, and the draft keeps it', () async {
      final sent = await sentAfterOnboarding(offersOptIn: true);
      expect(sent.marketingOptIn, isTrue);
      expect(container.read(signupDraftProvider)?.marketingOptIn, isTrue);
    });

    test('left unticked → marketing is false', () async {
      final sent = await sentAfterOnboarding(offersOptIn: false);
      expect(sent.marketingOptIn, isFalse);
    });
  });
}

class _MockAuthApi extends Mock implements AuthApi {}

class _FakeSignupRequest extends Fake implements SignupRequest {}
