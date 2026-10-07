import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medibook/app/di/dependencies.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/app/config/constants.dart';
import 'package:medibook/app/router/app_routes.dart';
import 'package:medibook/app/theme/theme.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/storage/hive/boxes.dart';
import 'package:medibook/core/storage/hive/keys.dart';
import 'package:medibook/core/widgets/app_checkbox.dart';
import 'package:medibook/features/auth/application/providers/onboarding_provider.dart';
import 'package:medibook/features/auth/presentation/components/onboarding_slide.dart';
import 'package:medibook/features/auth/application/providers/consent_form_controller.dart';
import 'package:medibook/features/auth/presentation/screen/consent_screen.dart';
import 'package:medibook/features/auth/presentation/screen/onboarding_screen.dart';
import 'package:medibook/features/support/presentation/screen/legal_document_screen.dart';

import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/features/support/application/providers/support_provider.dart';
import 'package:medibook/features/support/domain/entities/ambulance_provider.dart';
import 'package:medibook/features/support/domain/entities/app_config.dart';
import 'package:medibook/features/support/domain/entities/faq.dart';
import 'package:medibook/features/support/domain/entities/legal_document.dart';
import 'package:medibook/features/support/domain/repositories/support_content_repository.dart';

import '../../support/offline_overrides.dart';

/// The first-run intro: slides → consent → ready → sign-in. These pin the
/// two contracts the router depends on — the record is written only when the
/// terms box is ticked, and it lands in the `settings` box so a sign-out
/// cannot replay the intro.
void main() {
  setUp(() {
    HiveInit.store = InMemoryLocalStore();
  });

  group('OnboardingController', () {
    test('starts fresh on a device with no record', () {
      final container = ProviderContainer(overrides: appDependencies());
      addTearDown(container.dispose);

      final state = container.read(onboardingProvider);
      expect(state.isComplete, isFalse);
      expect(state.offersOptIn, isFalse);
      expect(container.read(isOnboardingCompleteProvider), isFalse);
    });

    test('reads a previous record from the settings box', () async {
      await HiveInit.store.write(
        HiveBoxes.settings,
        HiveKeys.onboardingComplete,
        true,
      );
      await HiveInit.store.write(
        HiveBoxes.settings,
        HiveKeys.offersOptIn,
        true,
      );
      final container = ProviderContainer(overrides: appDependencies());
      addTearDown(container.dispose);

      expect(container.read(isOnboardingCompleteProvider), isTrue);
      expect(container.read(onboardingProvider).offersOptIn, isTrue);
    });

    test(
      'complete() persists to settings, which survives a sign-out',
      () async {
        final container = ProviderContainer(overrides: appDependencies());
        addTearDown(container.dispose);

        await container
            .read(onboardingProvider.notifier)
            .complete(offersOptIn: true, acceptedTermsVersion: '2026.2');

        expect(container.read(isOnboardingCompleteProvider), isTrue);
        expect(
          HiveInit.store.read(
            HiveBoxes.settings,
            HiveKeys.acceptedTermsVersion,
          ),
          '2026.2',
        );

        await HiveInit.clearOnLogout();
        expect(
          HiveInit.store.read(HiveBoxes.settings, HiveKeys.onboardingComplete),
          isTrue,
        );
      },
    );
  });

  group('ConsentFormController', () {
    test('refuses accept without the terms box and shows the note', () async {
      final container = ProviderContainer(overrides: _contentOverrides());
      addTearDown(container.dispose);
      final form = container.read(consentFormControllerProvider.notifier);

      expect(await form.accept(), isFalse);
      expect(
        container.read(consentFormControllerProvider).showRequiredNote,
        isTrue,
      );
      expect(container.read(isOnboardingCompleteProvider), isFalse);

      // Ticking the box clears the note before a second press.
      form.setAgreeTerms(true);
      expect(
        container.read(consentFormControllerProvider).showRequiredNote,
        isFalse,
      );
    });

    test('accept with the terms box records the offers choice', () async {
      final container = ProviderContainer(overrides: _contentOverrides());
      addTearDown(container.dispose);
      // Both providers are autoDispose: hold them for the test's lifetime.
      final keepForm = container.listen(
        consentFormControllerProvider,
        (_, _) {},
      );
      final keepTerms = container.listen(
        legalDocumentProvider(AppRoutes.legalTerms),
        (_, _) {},
      );
      addTearDown(keepForm.close);
      addTearDown(keepTerms.close);
      final form = container.read(consentFormControllerProvider.notifier);
      // Let the (fake) terms document land so its version is recorded.
      await Future<void>.delayed(Duration.zero);

      form.setAgreeTerms(true);
      form.setAgreeOffers(true);
      expect(await form.accept(), isTrue);

      final record = container.read(onboardingProvider);
      expect(record.isComplete, isTrue);
      expect(record.offersOptIn, isTrue);
      expect(record.acceptedTermsVersion, '3');
    });

    test('refuses accept while the policies cannot be loaded', () async {
      // Offline, nothing cached: neither document can be shown.
      final container = ProviderContainer(overrides: offlineOverrides());
      addTearDown(container.dispose);
      final keepForm = container.listen(
        consentFormControllerProvider,
        (_, _) {},
      );
      addTearDown(keepForm.close);
      final form = container.read(consentFormControllerProvider.notifier);

      form.setAgreeTerms(true);
      expect(await form.accept(), isFalse);

      final state = container.read(consentFormControllerProvider);
      expect(state.showPoliciesNote, isTrue);
      expect(state.showRequiredNote, isFalse);
      expect(state.isBusy, isFalse);
      expect(container.read(isOnboardingCompleteProvider), isFalse);
      expect(
        HiveInit.store.read(HiveBoxes.settings, HiveKeys.acceptedTermsVersion),
        isNull,
      );

      // Unticking the box takes the note away with it.
      form.setAgreeTerms(false);
      expect(
        container.read(consentFormControllerProvider).showPoliciesNote,
        isFalse,
      );
    });

    test(
      'the same press retries the load once the policies are back',
      () async {
        final content = _FakeSupportContent(available: false);
        final container = ProviderContainer(
          overrides: [
            ...appDependencies(),
            ...offlineOverrides(),
            supportContentRepositoryProvider.overrideWithValue(content),
          ],
        );
        addTearDown(container.dispose);
        final keepForm = container.listen(
          consentFormControllerProvider,
          (_, _) {},
        );
        addTearDown(keepForm.close);
        final form = container.read(consentFormControllerProvider.notifier);

        form.setAgreeTerms(true);
        expect(await form.accept(), isFalse);
        expect(
          container.read(consentFormControllerProvider).showPoliciesNote,
          isTrue,
        );

        content.available = true;
        expect(await form.accept(), isTrue);
        expect(
          container.read(consentFormControllerProvider).showPoliciesNote,
          isFalse,
        );
        expect(container.read(onboardingProvider).acceptedTermsVersion, '3');
      },
    );
  });

  group('screens', () {
    /// Phone-sized surface, like the app's 390×844 design frame.
    void usePhoneSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('slides → consent → note → sign-in', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_flowHarness());
      await tester.pumpAndSettle();

      // Slide 1 offers Continue; the last slide offers Get Started.
      expect(find.text(OnboardingSlides.all.first.title), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text(OnboardingSlides.all.last.title), findsOneWidget);
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Consent: the CTA is live but explains the block.
      expect(find.text('One last thing'), findsOneWidget);
      expect(find.text('Please accept the terms to continue.'), findsNothing);
      await tester.tap(find.text('Agree and Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Please accept the terms to continue.'), findsOneWidget);
      expect(find.text('LOGIN'), findsNothing);

      // Tick the required box (the first of the two) and accept.
      await tester.tap(find.byType(AppCheckbox).first);
      await tester.pumpAndSettle();
      expect(find.text('Please accept the terms to continue.'), findsNothing);
      await tester.tap(find.text('Agree and Continue'));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN'), findsOneWidget);
    });

    testWidgets('consent stays put while the policies cannot be loaded', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _flowHarness(
          initial: AppRoutes.onboardingConsent,
          overrides: offlineOverrides(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AppCheckbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agree and Continue'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('We could not load the Terms & Conditions'),
        findsOneWidget,
      );
      expect(find.text('One last thing'), findsOneWidget);
      expect(find.text('LOGIN'), findsNothing);
    });

    testWidgets('a policy link opens the document with "Back to sign up"', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _flowHarness(initial: AppRoutes.onboardingConsent),
      );
      await tester.pumpAndSettle();

      await tester.tapOnText(find.textRange.ofSubstring('Terms & Conditions'));
      await tester.pumpAndSettle();

      expect(find.byType(LegalDocumentScreen), findsOneWidget);
      expect(find.text('Back to sign up'), findsOneWidget);
      // The fake's document: `GET /patient/legal/terms` → version 3.
      expect(
        find.textContaining('Version 3 · published 12 September 2026'),
        findsOneWidget,
      );
    });
  });
}

/// The onboarding routes on a real `GoRouter`, so `context.push` / `go`
/// behave as in the app. `/login` is a stand-in.
Widget _flowHarness({
  String initial = AppRoutes.onboarding,
  List<Override>? overrides,
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingConsent,
        builder: (_, _) => const ConsentScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.legal}/:slug',
        builder: (_, _) => const LegalDocumentScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const Scaffold(body: Center(child: Text('LOGIN'))),
      ),
    ],
  );
  return ProviderScope(
    overrides: overrides ?? _contentOverrides(),
    child: ScreenUtilInit(
      designSize: AppConstants.designSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, widget) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.noScaling),
          child: widget!,
        ),
      ),
    ),
  );
}

/// Offline everywhere except the legal documents, which the consent screen
/// links to and the consent controller records the version of.
List<Override> _contentOverrides() => [
  ...offlineOverrides(),
  supportContentRepositoryProvider.overrideWithValue(_FakeSupportContent()),
];

class _FakeSupportContent implements SupportContentRepository {
  _FakeSupportContent({this.available = true});

  /// False plays a device that cannot reach the documents.
  bool available;

  @override
  Stream<CachedResult<LegalDocument>> legalDocument(
    String slug, {
    bool forceRefresh = false,
  }) => !available
      ? Stream.error(const NetworkFailure())
      : Stream.value(
          CachedResult(
            value: LegalDocument(
              slug: slug,
              version: 3,
              title: slug == 'privacy'
                  ? 'Privacy Policy'
                  : 'Terms & Conditions',
              bodyMd: '## Using Medibook\n\nBe kind to the desk.',
              publishedAt: DateTime.utc(2026, 9, 12, 6),
            ),
            source: CacheSource.network,
            cachedAt: DateTime.now(),
          ),
        );

  @override
  Stream<CachedResult<AppConfig>> appConfig({bool forceRefresh = false}) =>
      const Stream.empty();

  @override
  Stream<CachedResult<List<FaqCategory>>> faqs({bool forceRefresh = false}) =>
      const Stream.empty();

  @override
  Stream<CachedResult<List<AmbulanceProvider>>> ambulanceProviders(
    AmbulanceFilter filter, {
    bool forceRefresh = false,
  }) => const Stream.empty();
}
