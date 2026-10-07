# docs-flutter — Specification Index

Source-of-truth specs for building the Medibook Flutter mobile app. Read the relevant file(s) in full before writing code for that area; this page is only a router.

## Files

| File | One-liner |
|---|---|
| `Technical_stack.md` | Pinned SDK and package versions (Flutter 3.24.5 / Dart 3.5.4, Riverpod, Hive/Isar, Dio+Retrofit, secure_storage, Razorpay, freezed/build_runner, mockito) — use these exact versions in `pubspec.yaml`. |
| `Folder structure - structure.csv` | The full `lib/` tree to scaffold, with a purpose comment per folder/file: `app/` (bootstrap, config, router, theme, l10n, monitoring), `core/` (network, storage, utils, widgets, error), and feature-first `features/<feature>/{domain,application,infrastructure,presentation}` for auth, dashboard, profile, etc. |
| `Flutter Coding Standards.md` | Project-wide rulebook: feature-first layering, naming conventions, Riverpod provider types and best practices, Hive box/adapter rules, ScreenUtil do's and don'ts, error handling + standard error model, API/token handling, formatting, null safety, performance, security, and Git branching. |
| `Flutter Mobile Responsiveness using flutter_screenutil.md` | How to make every screen responsive with `flutter_screenutil`: install it, set `designSize` to the Figma base (390×835), wrap the app in `ScreenUtilInit`, and use `.w/.h/.sp/.r` instead of hardcoded pixels. |
| `HIVE implementation.md` | Production cache specification: SHA256 cache-key formula, three-layer L1 memory / L2 Hive / L3 network design, 10 runtime scenarios with error paths (cold start, warm start, offline, stale >24h, HTTP 304, concurrent-request dedup, eviction, corruption recovery, invalid responses), plus the `CacheConfig` / `CacheEntry` classes, retry logic, and isolate/thread-safety rules. |
| `Linting & Analysis(implementation guide)-Flutter.md` | Why and how to set up static analysis: what `analysis_options.yaml` controls, and step-by-step setup of the custom `naming_conventions_lints` plugin package that sits *next to* the app project and enforces naming rules via `dart analyze` in CI. |
| `Pre-Commit Hook Setup Guide.md` | End-to-end Git pre-commit hook setup that blocks commits failing format/analyze/structure checks, including the repo layout it expects and the `setup_structure.sh` scaffold script that generates the modular `lib/` folders. |
| `QA.md` | The Claude Code audit prompts the code must survive — 6 prompts covering Riverpod state-management violations, security/token storage + Android manifest, performance/dependencies, testing + deployment readiness, Hive cache scenario validation, and architecture compliance. Treat each listed CRITICAL/HIGH violation as a hard build constraint. |
| `.DS_Store` | macOS Finder metadata — not documentation, ignore. |

## Suggested read order when building

1. `Technical_stack.md` → pin dependencies
2. `Folder structure - structure.csv` + `Pre-Commit Hook Setup Guide.md` → scaffold the project
3. `Flutter Coding Standards.md` → architecture and conventions for all code
4. `HIVE implementation.md` → data/caching layer
5. `Flutter Mobile Responsiveness using flutter_screenutil.md` → UI layer
6. `Linting & Analysis(implementation guide)-Flutter.md` + `QA.md` → quality gates to pass
