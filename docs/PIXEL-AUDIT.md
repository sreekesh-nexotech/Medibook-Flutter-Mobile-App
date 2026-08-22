# Medibook Presentation — Pixel & Code Audit

How the presentation layer was verified, and the results. Because the build
environment had **no Flutter SDK**, "pixel-to-pixel comparison" was done two
complementary ways:

1. **Code-level value audit** — every widget's padding, size, gap, font size,
   weight, color token, copy string, component variant and animation was diffed
   against the design values (`docs/DESIGN-SPEC.md`) and the original prototype
   (`Medibook App.dc.html`). This is the primary pixel check.
2. **Golden (image) tests** — `test/goldens/` renders each component and the
   deterministic screens to PNGs. Run in a Flutter environment:
   ```
   flutter pub get
   flutter test --update-goldens        # capture baselines once
   flutter test                          # compare future renders
   ```
   `test/flutter_test_config.dart` loads the bundled Poppins/Inter so golden text
   renders real glyphs. Baselines land in `test/goldens/images/`.

Both audits were run as independent reviewers over all 122 `lib/` files + tests.

## Result: high-fidelity, zero compile-breakers

- **Compile / architecture audit:** zero compile-breaking issues. All imports
  resolve, every screen matches the real component constructors, provider types
  and go_router v14 usage are correct, and the Riverpod/architecture rules from
  `docs-flutter/QA.md` Prompt 6 (presentation section) pass — `ref.watch` only in
  build, `ref.read` only in callbacks, autoDispose on transient state, no
  infrastructure imports, no nav/SnackBar in providers, tokens + ScreenUtil
  throughout.
- **Pixel/spec audit:** a faithful port — correct headline sizes, color tokens,
  typography, copy (em-dashes/ellipses/apostrophes preserved), component variants
  and states, with **no leftover prototype chrome** (no faux status bar, no device
  frame, no reviewer jump-menu) and demo affordances correctly gated behind
  `FeatureFlags.demoMode`.

## Findings fixed in this pass

| # | Sev | Finding | Fix |
|---|-----|---------|-----|
| D1 | Low | Confirm bottom-sheet message was 13px / 10px gap | → 14px, 8px gap (`app_bottom_sheet.dart`) |
| D2 | Low | Inner-header bottom padding hard-coded 14 on every screen | Added `bottomGap` param; 8 on auth sub-screens, 10 on Search (`app_inner_header.dart` + 5 screens) |
| D3 | Low | Stepper connectors abutted the circles (missing 6px gap) | Added 6px padding around connectors (`app_stepper.dart`) |
| D4 | Trivial | Booking Success faded at 220ms vs design 250ms | `AppConstants.successFadeIn` = 250ms |
| A1 | Med | `const AppTabHeader` / `const AppAvatar` froze ScreenUtil sizing on Profile | Dropped `const`; read name/email via new `userNameProvider`/`userEmailProvider` |
| A2 | Med | `appointmentByIdProvider` / `appointmentsByBucketProvider` families not autoDispose | → `Provider.autoDispose.family` |
| A3 | Low | Literal radii `999.r` / `12.r` where a token exists | → `AppRadii.pill` / `AppRadii.md` (home header, search) |
| — | Info | `carousel_slider` + `shimmer` declared but unused | Removed from pubspec (banner uses PageView); re-add with the data/loading layer |
| — | Info | Dead empty `auth/.../header_section.dart` | Deleted |

## Not defects (verified, so they aren't re-raised)

- **Primary CTA height = 48**, not 52. The prototype's `hint-size="…,52px"` is the
  design tool's layout-box hint; the real DS render is 48 (bundle line 349). 48 is
  correct.

## Golden coverage & the one caveat

Component goldens cover every DS widget. Screen goldens cover the deterministic
screens (Login, Notifications, Records, Profile, Appointments, Booking Success).
Deliberately **excluded** from goldens and covered by the code audit instead,
because they are non-deterministic under the test engine:

- **Home** — the promo banner runs a periodic `Timer` (`pumpAndSettle` would
  hang) and paints the doctor portrait asset.
- **Verify Code** — reads `GoRouterState` in build (needs a router ancestor).
- **Booking step 3 / Reschedule / Confirm** — date chips come from
  `DateTime.now()`. To golden-test these, inject a fixed clock (add a `nowProvider`
  the tests override) — a small, recommended follow-up.
- **Doctor Detail / Dr. Anya cards** — load a portrait asset.
