# Medibook

Patient mobile app for booking doctor appointments, lab tests and health
records. Flutter, feature-first architecture, Riverpod.

`docs-flutter/` is the authoritative specification — read the relevant document
before writing code in the area it covers, and check your work against the
audit prompts in `docs-flutter/QA.md`. `CLAUDE.md` indexes those documents.

## Running

```sh
flutter pub get
flutter run
```

The defaults are the development configuration, so `flutter run` needs no
flags.

## Build configuration (`--dart-define`)

Every build-time setting is declared in `lib/app/config/env.dart` and read from
there by `FeatureFlags`, `ApiClient` and the monitoring wrappers. That file is
the one place to look to know how a build was configured.

| Define | Default | What it does |
|---|---|---|
| `MEDIBOOK_ENV` | `dev` | Environment/flavour: `dev` \| `stg` \| `prod` |
| `MEDIBOOK_API_BASE_URL` | `https://62.171.151.149:8443` | API origin, no trailing slash and no `/api/v1` (the client adds it). Default is the integration server |
| `MEDIBOOK_DEMO` | `false` | Demo affordances (prefilled credentials, the "Demo code" hint). Off: the app talks to the real API |
| `MEDIBOOK_ALLOW_BAD_CERT` | `true` | Accept the integration server's self-signed certificate. A production build refuses to start with this on |
| `MEDIBOOK_BANNER_AUTOROTATE` | `true` | Home promo-banner auto-rotation |
| `MEDIBOOK_ANALYTICS` | `false` | Forward analytics events to a backend |
| `MEDIBOOK_CRASH_REPORTING` | `false` | Forward crashes to Sentry. Needs `MEDIBOOK_SENTRY_DSN` as well |
| `MEDIBOOK_SENTRY_DSN` | *(empty)* | Sentry DSN. Supplied by CI from a secret, or locally from `dart_defines.local.json` — never committed |
| `MEDIBOOK_VERBOSE_LOGS` | `false` | Raise the log floor to `debug` in a profile build |

### Backend

The app is wired to the Medibook patient API (`docs-flutter/FLUTTER_API_INTEGRATION.md`
is the contract; `docs/INTEGRATION-CORE.md` describes the app-side plumbing;
`docs/FLUTTER_INTEGRATION_GAPS.md` lists what the staging server could not
satisfy in round 1, and `docs/FLUTTER_INTEGRATION_GAPS_ROUND_2.md` what is
still open after the backend's fixes of 2026-10-01).
`flutter run` with no defines talks to the integration server. A review build
that must work without a backend passes `--dart-define=MEDIBOOK_DEMO=true`.

A full production build:

```sh
flutter build apk --release \
  --dart-define=MEDIBOOK_ENV=prod \
  --dart-define=MEDIBOOK_API_BASE_URL=https://api.medibook.app \
  --dart-define=MEDIBOOK_DEMO=false \
  --dart-define=MEDIBOOK_ALLOW_BAD_CERT=false \
  --dart-define=MEDIBOOK_CRASH_REPORTING=true \
  --dart-define=MEDIBOOK_SENTRY_DSN="$SENTRY_DSN" \
  --obfuscate \
  --split-debug-info=build/symbols
```

`--obfuscate` hides Dart class and method names in the binary; the symbols it
writes to `build/symbols` are needed to read crash stack traces, so archive
them privately with each release (never ship or commit them). Android's R8
shrinking and obfuscation are already on for release builds.

`EnvLoader.validate()` runs during bootstrap and **refuses to start a
production build** that still has demo mode or certificate bypass on, or that
points at a non-HTTPS API — so a forgotten flag fails at launch rather than
after release.

To run against a backend on this machine from the Android emulator (debug builds
allow cleartext to the host — `android/app/src/debug/res/xml/network_security_config.xml`):

```sh
flutter run -d emulator-5554 --dart-define=MEDIBOOK_API_BASE_URL=http://10.0.2.2:8000
```

Live end-to-end checks against the server (opt-in, needs the test account):

```sh
MEDIBOOK_LIVE_BASE_URL=https://62.171.151.149:8443 \
MEDIBOOK_LIVE_IDENTIFIER=<email or +91…> MEDIBOOK_LIVE_PASSWORD=<password> \
flutter test test/integration/live_backend_test.dart
```

## Crash reporting (Sentry)

`lib/app/monitoring/crash_reporting.dart` owns it. Sentry starts during
bootstrap only when a build passes **both** `MEDIBOOK_CRASH_REPORTING=true` and
a `MEDIBOOK_SENTRY_DSN`; otherwise reports go to the local logger and nothing
leaves the device. Events are tagged with `MEDIBOOK_ENV`, and screenshots,
default PII and Session Replay are off — this is a patient app.

The DSN is not committed. Locally it lives in `dart_defines.local.json`
(git-ignored) at the repo root:

```json
{
  "MEDIBOOK_CRASH_REPORTING": true,
  "MEDIBOOK_SENTRY_DSN": "https://<key>@<org>.ingest.us.sentry.io/<project>"
}
```

```sh
flutter run --dart-define-from-file=dart_defines.local.json
```

CI passes the same two defines from its secret store.

## In-app updates (Android)

`lib/features/app_update/` drives Google Play's in-app update API. It checks at
launch and whenever the app returns to the foreground:

* An install **below `min_versions.android`** from `GET /shared/app-config`
  gets Play's full-screen *immediate* update. Backing out leaves the app behind
  an "Update required" screen.
* Any other update is *flexible*: it downloads in the background, then a
  dialog offers the restart. "Later" holds until the next launch.

Play only answers for a build installed from Google Play (internal testing
track or above), so debug and sideloaded builds skip the check silently. iOS
has no equivalent API and is not covered.

## Platform identity

| | Value |
|---|---|
| App name | Medibook |
| Android `applicationId` / `namespace` | `com.navoracloudsoft.medibook` |
| iOS `PRODUCT_BUNDLE_IDENTIFIER` | `com.navoracloudsoft.medibook` |
| Deep-link scheme | `medibook://` |
| App / Universal Links host | `medibook.app` |

Deep links are mapped to in-app routes by `AppRoutes.fromDeepLink`
(`lib/app/router/app_routes.dart`).

Two deployment steps are still outstanding for verified https links:

* **Android** — publish `assetlinks.json` at
  `https://medibook.app/.well-known/assetlinks.json` listing the package name
  and the release signing certificate fingerprint.
* **iOS** — add the `Associated Domains` capability (`applinks:medibook.app`)
  in Xcode and publish
  `https://medibook.app/.well-known/apple-app-site-association`. The capability
  needs a provisioning profile, so it cannot be added from the repo.

## Launcher icon & splash

The Android mipmaps, the adaptive icon, the iOS `AppIcon.appiconset` and the
launch images are generated from the brand mark and **committed**, so no build
step is needed. `assets/images/brand_mark.png` and
`brand_mark_foreground.png` are the sources, and the `flutter_launcher_icons` /
`flutter_native_splash` blocks in `pubspec.yaml` are configured to reproduce
exactly what is committed:

```sh
dart pub add --dev flutter_launcher_icons flutter_native_splash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Those two packages are intentionally **not** installed — they are only needed
when the brand mark changes.

## Checks

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Widget and golden tests pump real screens behind `test/support/offline_overrides.dart`
(an offline `CachedFetcher`, no-op WebSockets), so they never touch the network;
screen goldens are the offline/empty states. The QC capture rig
(`test/qc/capture_screens_test.dart`) is opt-in via `MEDIBOOK_SHOT_DIR`.
