# CLAUDE.md

Project: **Medibook Flutter Mobile App**.

The `docs-flutter/` folder is the authoritative specification for how this app must be
built. Read the relevant document before writing code in the area it covers, and make the
generated code satisfy the audit prompts in `QA.md`.

## docs-flutter/ file index

| File | What it is (one-liner) |
|------|------------------------|
| `Technical_stack.md` | The locked dependency list — Flutter 3.24.5 / Dart 3.5.4 with exact package versions for Riverpod, Hive/Isar, Dio+Retrofit, secure storage, Razorpay, UI packages, codegen and testing; use these versions, don't invent others. |
| `Folder structure - structure.csv` | The canonical `lib/` tree (app / core / features with domain–application–infrastructure–presentation layers per feature), annotated with the purpose of every folder and key file — scaffold and place new files exactly per this layout. |
| `Flutter Coding Standards.md` | Project-wide coding rules: feature-first architecture, naming conventions, Riverpod provider types and best practices, Hive box/adapter rules, ScreenUtil do's and don'ts, error handling and error model, API/token handling, formatting, null-safety, performance, security and Git/commit practices. |
| `HIVE implementation.md` | Production cache specification: SHA-256 cache-key strategy, three-layer Memory(L1)/Hive(L2)/Network(L3) design, and ten step-by-step scenarios (cold start, warm start, offline, navigation, stale cache, HTTP 304 conditional requests, concurrent-request deduplication, eviction/size limits, corruption recovery, invalid-response handling) with the exact error paths to implement. |
| `Flutter Mobile Responsiveness using flutter_screenutil.md` | How to make every screen responsive with `flutter_screenutil` — Figma base size 390×835, `ScreenUtilInit` setup in `main.dart`, and when to use `.w`, `.h`, `.sp`, `.r` instead of hardcoded pixels. |
| `Linting & Analysis(implementation guide)-Flutter.md` | Why and how to wire static analysis: the `analysis_options.yaml` rulebook plus the sibling `naming_conventions_lints` custom lint plugin package (its pubspec, plugin entry points and setup) so `dart analyze` enforces naming and structure rules in dev and CI. |
| `Pre-Commit Hook Setup Guide.md` | Setting up the Git pre-commit hook that blocks bad commits — prerequisites, repo layout, the `setup_structure.sh` folder-scaffold script, the hook script running `dart format` / `flutter analyze` / structure checks, and troubleshooting for the common failures. |
| `QA.md` | The Claude Code audit prompts this codebase must pass — Prompt 1 Riverpod state-management violations, Prompt 2 data-persistence & security, Prompt 3 error handling & performance, Prompt 4 code quality & deployment readiness, Prompt 5 Hive cache correctness across all scenarios, plus a layered architecture-health audit with scoring; write code that comes out clean against these checks. |
| `.DS_Store` | macOS Finder metadata — not documentation, ignore it. |

## How to use these docs

1. `Technical_stack.md` → pick packages/versions.
2. `Folder structure - structure.csv` → decide where a file goes.
3. `Flutter Coding Standards.md` → how to write it (Riverpod, naming, errors, API).
4. `HIVE implementation.md` → any caching/offline behaviour.
5. `Flutter Mobile Responsiveness using flutter_screenutil.md` → any UI sizing.
6. `Linting & Analysis(implementation guide)-Flutter.md` + `Pre-Commit Hook Setup Guide.md` → tooling/CI gates.
7. `QA.md` → self-review before declaring work done.
