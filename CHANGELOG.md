# Changelog

## [Unreleased] — Presentation layer

Implements the **Presentation layer** of the Medibook mobile app from the Claude
Design handoff — all 15 designed screens, pixel-faithful, over static seed data
that is cleanly swappable for the API/data layer.

### Added
- **Design system** (`lib/core/widgets/`): 19 shared widgets — Button, IconButton,
  Card, Badge, Tag, Avatar, Rating, TextField, Checkbox, Radio, Select, Switch,
  BottomNav, SegmentedTabs, Stepper, InnerHeader, TabHeader, confirm bottom-sheet,
  StatusPill — plus the icon system (exact Iconsax SVGs) and toast host.
- **Theme + tokens** (`lib/app/theme`, `lib/app/config`): colors, typography
  (Poppins/Inter), radii, shadows, spacing — transcribed from the design system.
- **Screens** across 8 features (auth, dashboard, search, notifications, booking,
  appointments, records, profile) with feature components and autoDispose UI
  controllers; every interaction works against in-memory state.
- **Shared data** (`lib/core/mock_data`): immutable UI models + `MedibookSeed`
  static data + read providers (documented API swap-points); shared controllers
  for appointments, booking draft, banner rotation, and toasts.
- **Routing**: `go_router` with a bottom-nav `StatefulShellRoute` and pushed
  routes; `main.dart` + bootstrap + `ScreenUtilInit` (design base 390×844).
- **Assets**: bundled Poppins/Inter fonts, exact Iconsax + bottom-nav SVG glyphs
  (icon-data + `star-bold` patches applied), doctor/clinic images.
- **Docs**: `docs/DESIGN-SPEC.md`, `COMPONENT-CONTRACT.md`, `SCREEN-BUILD-GUIDE.md`,
  `PRESENTATION-LAYER.md`, `PIXEL-AUDIT.md`; `.claude/agents/` role definitions.
- **Tests**: golden harness + font loader, component behaviour tests, component +
  screen golden suites.

### Notes
- Presentation layer only — no networking/persistence/payments yet. Static seed is
  isolated to `core/mock_data` + three controllers; see `docs/PRESENTATION-LAYER.md`
  for the exact API swap-points.
- Demo affordances (prefilled credentials, `1234` OTP, banner auto-rotate) are
  gated behind `FeatureFlags.demoMode`.
- Built without a local Flutter SDK; verified by a code-level pixel/spec audit and
  an architecture/compile-simulation audit (see `docs/PIXEL-AUDIT.md`). Run
  `flutter pub get && flutter test` in a Flutter environment to compile, test, and
  capture golden baselines.
