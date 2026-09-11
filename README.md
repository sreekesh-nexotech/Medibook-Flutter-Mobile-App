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
| `MEDIBOOK_API_BASE_URL` | `https://dev-api.medibook.app` | API origin, no trailing slash |
| `MEDIBOOK_DEMO` | `true` | Demo affordances: prefilled credentials, the "Demo code: 1234" hint, the reviewer screen-jump menu |
| `MEDIBOOK_BANNER_AUTOROTATE` | `true` | Home promo-banner auto-rotation |
| `MEDIBOOK_ANALYTICS` | `false` | Forward analytics events to a backend |
| `MEDIBOOK_CRASH_REPORTING` | `false` | Forward crashes to a backend |
| `MEDIBOOK_SENTRY_DSN` | *(empty)* | Crash-reporter DSN. Supplied by CI from a secret — never committed |
| `MEDIBOOK_VERBOSE_LOGS` | `false` | Raise the log floor to `debug` in a profile build |

### Turning demo mode off for a release

**This build defaults to demo mode on**, because it is the client-review
prototype. A release build must turn it off:

```sh
flutter build apk --release --dart-define=MEDIBOOK_DEMO=false
```

A full production build:

```sh
flutter build apk --release \
  --dart-define=MEDIBOOK_ENV=prod \
  --dart-define=MEDIBOOK_API_BASE_URL=https://api.medibook.app \
  --dart-define=MEDIBOOK_DEMO=false \
  --dart-define=MEDIBOOK_CRASH_REPORTING=true
```

`EnvLoader.validate()` runs during bootstrap and **refuses to start a
production build** that still has demo mode on, or that points at a non-HTTPS
API — so a forgotten flag fails at launch rather than after release.

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
