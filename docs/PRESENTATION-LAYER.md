# Medibook — Presentation Layer

What this session built, how it's organised, and exactly where the API/data
layer plugs in later. Scope of this session: **Presentation layer only** — no
domain / infrastructure / application files, no networking, no persistence.

## What exists

A complete, interactive UI for all 15 designed screens, assembled from a shared
design-system component library, driven by presentation-local Riverpod providers
over static seed data. Every control works (booking, cancel, reschedule, search,
form validation, toasts, banner rotation) against in-memory state.

Source of truth for fidelity: `docs/DESIGN-SPEC.md` (extracted from the Claude
Design handoff), with `docs/COMPONENT-CONTRACT.md` (widget APIs) and
`docs/SCREEN-BUILD-GUIDE.md` (screen wiring).

## Structure

```
lib/
├── app/
│   ├── config/        constants.dart (designSize, timings, demo constants),
│   │                  feature_flags.dart (demoMode), env.dart
│   ├── router/        app_routes.dart (paths), app_router.dart (go_router shell)
│   └── theme/         colors.dart, typography.dart, theme.dart (radii/shadows)
├── core/
│   ├── mock_data/     ← STATIC SEED — the API swap-point (see below)
│   │   ├── models/    Doctor, Department, Patient, Appointment, MedicalRecord,
│   │   │              AppNotification, PromoBanner (immutable UI view-models)
│   │   ├── medibook_seed.dart      all static lists (exact from the prototype)
│   │   └── seed_providers.dart     read providers screens consume
│   ├── utils/         validators.dart, date_utils.dart
│   └── widgets/       the design-system components + toast + helpers
└── features/<f>/presentation/
    ├── screen/        full pages
    ├── components/     feature-local pieces
    └── controllers/    autoDispose UI-state + shared controllers
```

Features: `auth`, `dashboard` (home), `search`, `notifications`, `booking`,
`appointments`, `records`, `profile`.

## The API swap-points (for the data-layer session)

The static data is isolated so the future integration touches few files:

1. **Read data** — screens read `core/mock_data/seed_providers.dart`
   (`doctorsProvider`, `departmentsProvider`, `recordsProvider`,
   `notificationsProvider`, `patientsProvider`, `timeSlotsProvider`,
   `promoBannersProvider`, `profileInfoProvider`). Today each returns
   `MedibookSeed.*`. To integrate: change each provider body to read from a
   feature repository (a `FutureProvider`/`AsyncNotifier`), and replace the UI
   models with domain entities. **Screen code does not change.**

2. **Mutable app data** — `features/appointments/.../appointments_controller.dart`
   owns the appointments list + token counter with `book/cancel/reschedule`. To
   integrate: give `AppointmentsController` an `AppointmentRepository` (domain
   contract) and call it from those methods; drop the seed initializer.

3. **In-flight UI state** — `booking_controller.dart` (draft),
   `banner_controller.dart`, `toast_controller.dart`, and the per-screen
   autoDispose providers are pure presentation state and stay as-is.

4. **Assets** — icons in `assets/icons/` are the exact Iconsax path data exported
   from the design system (patched: icon-data now registers; the stray
   full-canvas rect in `star-bold` is removed). Fonts (Poppins/Inter) are bundled.
   Doctor/clinic photos in `assets/images/`. `AppAvatar` already accepts an
   `imageUrl` for network images via `cached_network_image`.

Nothing outside `core/mock_data/` and the three controllers hardcodes data, so
the integration is contained.

## Conventions enforced (per docs-flutter + QA.md)

- **ScreenUtil** on every dimension (`.w/.h/.sp/.r`), design base 390×844, never
  `const` over a scaled subtree.
- **Tokens only** — colors/text/radii/shadows/spacing from `app/theme` +
  `app/config`. No literal hex or magic numbers in screens.
- **Riverpod purity** — `ref.watch` only in `build`, `ref.read` only in callbacks;
  autoDispose on transient UI state; immutable state + `copyWith`; no
  navigation/SnackBar in providers (toasts go through a state channel rendered by
  `ToastHost`).
- **Layer discipline** — presentation imports no infrastructure; no business
  logic in `build`.
- **Demo affordances** (prefilled credentials, `1234` OTP hint, banner
  auto-rotate) gated behind `FeatureFlags.demoMode` — never a production auth path.
  The faux status bar, device frame and reviewer jump-menu are intentionally
  dropped.

## Running & testing

- `flutter pub get` then `flutter run` (needs a Flutter SDK; this build was
  authored in a container without one, so it was not compiled here).
- **Pixel comparison** is done two ways (see `docs/PIXEL-AUDIT.md`):
  1. A **code-level spec audit** — every widget's padding/size/color/font/weight
     diffed against the design values.
  2. **Golden tests** under `test/` (harness in `test/support/harness.dart`) —
     run `flutter test --update-goldens` once to capture baselines in your env,
     then `flutter test` to catch regressions. Golden PNGs are the pixel record.

## Known carry-overs from the design review (need product decisions)

From `chats/chat1.md` / `docs/DESIGN-SPEC.md §7`: only 1 of 6 doctors has a
portrait (rest use initials — a deliberate shipped state); currency is ₹ and phone
is +91 (India locale); no dark mode in the design; accessibility (focus, ARIA,
semantics) was unspecified and should be layered in.
