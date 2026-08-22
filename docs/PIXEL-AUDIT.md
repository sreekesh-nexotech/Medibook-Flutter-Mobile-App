# Medibook Presentation — Pixel & Code Audit

How the presentation layer was verified, and the results.

> **Update:** after this document was first written, the Flutter SDK was
> installed in the build environment and a full **rendered pixel-to-pixel QC**
> was run — see the final section, which supersedes the "no SDK" caveats below.
> All findings from that pass are fixed and re-verified.

The initial verification (pre-SDK) was done two complementary ways:

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

---

## Rendered pixel-to-pixel QC (final gate)

The Flutter SDK (3.38.4) was installed into the build environment and the
comparison was re-run **on real rendered pixels**, both sides at 390×844 @2x:

- **Design side:** the original prototype (`Medibook App.dc.html`) served
  locally (React/Babel vendored, fonts swapped to the app's own bundled TTFs so
  both renderers shape identical font binaries) and driven screen-by-screen in
  headless Chromium via Playwright → 21 PNGs. Script: `tool/qc/shoot_prototype.mjs`.
- **App side:** `test/qc/capture_screens_test.dart` boots the real app (router,
  shell, providers), walks every flow through the actual UI (login → … → logout
  sheet), and writes 21 matching PNGs. A `FakeViewPadding(top: 88)` simulates
  the iPhone status inset so SafeArea geometry matches the design's 44px zone.
- **Compare:** `tool/qc/diff_shots.py` builds PROTO|FLUTTER|DIFF composites and
  a ranked %diff table; every composite was also inspected by eye.

### Defects the rendered QC caught (all fixed, all re-verified by re-render)

| # | Sev | Defect | Fix |
|---|-----|--------|-----|
| R1 | **Critical** | `AppCheckbox`'s `Expanded` label crashed the whole Login screen when the checkbox sat in an unbounded `Row` (flex-in-unbounded-width) | Bound it with `Expanded` at the Login call site |
| R2 | **Critical** | `BookingScreen.initState` mutated `bookingControllerProvider` mid-build (Riverpod violation) → the entire booking flow rendered as an error screen | Deferred `configure(...)` to a microtask with a `mounted` guard |
| R3 | High | Confirm bottom-sheet opened inside the shell navigator, floating above the bottom nav with the scrim not covering it (design: sheet + scrim cover everything) | `useRootNavigator: true` |
| R4 | High | Home's navy header did not paint behind the OS status bar (light strip in the status zone; design extends navy under it) | Header owns the top inset (`MediaQuery.paddingOf(context).top + 14.h`); screen-level top `SafeArea` removed |
| R5 | Medium | Auth sub-screen headers painted `bgApp` grey on the design's all-white pages | `AppInnerHeader.background` param; auth screens pass `surface` |
| R6 | Medium | Booking Success centered inside `SafeArea`, design centers on full screen height | `SafeArea(top: false)` |
| R7 | Medium | `AppSegmentedTabs` rendered centered (parent Column's default cross-axis), design left-aligns at the gutter | `Align(centerStart)` inside the component |
| R8 | Low | Appointment-card sub-line ellipsized at 1 line; prototype wraps to 2 | `maxLines: 2` |

Numeric confirmation (%pixels differing >6% channel delta, before → after):
sheet 23.4→6.0 · success 12.5→3.0 · verify 8.4→2.4 · reset 10.8→4.8 ·
home 35.8→10.5 · appointments 13.9→6.6 · forgot 12.4→2.9. Final range across
all 21 screens: **2.4%–14.5%**, where the remaining difference is cross-engine
text rasterization/word-wrap and photo scaling (Chromium vs Skia), not layout,
color, type, copy, or component deviations — confirmed by eye on every
composite.

### Also verified on the real SDK

- `flutter analyze`: **0 errors** (22 info/style notices).
- Full test suite: **31 tests + the capture rig, all passing**.
- Golden baselines generated and committed (`test/goldens/images/`,
  13 component + 6 screen goldens) — CI can now `flutter test` against real
  pixel baselines.

### Reproducing the QC

```
# 1. Prototype side (needs Chromium + Playwright):
node tool/qc/shoot_prototype.mjs           # serve repo/project first, see script header

# 2. App side:
MEDIBOOK_SHOT_DIR=/tmp/shots/flutter flutter test test/qc/capture_screens_test.dart

# 3. Compare:
python3 tool/qc/diff_shots.py /tmp/shots/proto /tmp/shots/flutter /tmp/shots/diff
```
