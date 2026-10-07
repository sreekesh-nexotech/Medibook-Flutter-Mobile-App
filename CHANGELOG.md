# Changelog

## [Unreleased] — Edit Profile audit and Home fixes (2026-10-07)

Edit Profile was tested top to bottom on the emulator against the live server (signed in as Asha
Rao, every change put back afterwards), with the app's own network log. Every field shows the
server's value and every save reaches it. `docs/BACKEND_BLOCKERS.md` gains BB-45 and BB-46, and
BB-01 now names the mobile-number change.

### Fixed
- **A save no longer wipes every saved list.** Clearing the cache "under a path" emptied the
  whole response cache (keys are hashes), so a profile save refetched every list in full —
  hospitals included — and dropped their offline copies. The fetcher now remembers each key's
  path (`invalidatePaths`); a profile save drops only `/patient/me` and the family list (the
  "self" person changes with it), an alternate-number change only `/patient/me`. The other
  lists keep their copy and answer 304. The other callers of `invalidate(pathPrefix:)` still
  clear everything, unchanged.
- **Phone numbers read as `+91 98086 59500`** (`PhoneFormat.display`) on Profile, Edit Profile
  and Change Mobile Number, instead of the stored `+919808659500`.
- **Gender has a person icon** on Edit Profile and the family member form (it was a folder).
- **Home → Available Services** tiles no longer show how many hospitals offer each department.
- **"We could not find your location"** came up whenever network location was unavailable
  (indoors with weak signal, or the emulator): the app asked only for a low-power fix, which never
  uses GPS. It now tries GPS once (20 s) when the low-power fix does not come within 10 s.
- **Home's promo cards sometimes never appeared** until a pull-to-refresh. Once the phone's
  position was found, "Hospitals Near You" rebuilt in an endless loop (~60 times a second): the
  position provider was `autoDispose`, was dropped while the list rebuilt for it, came back still
  loading, and the list restarted without it. The list never settled, so the promo strip waiting
  on it stayed hidden, and the list was never actually sorted by distance. The position provider
  now lives for the session (as the location reading it wraps already did), and the strip stays
  up while it reloads instead of blinking out. A new test catches the loop (640 requests in
  0.2 s before the fix).

## [Unreleased] — Choose a location audit (2026-10-06)

"Choose a location" was tested on the emulator against the live server, online and offline, with
the app's own network log. `docs/BACKEND_BLOCKERS.md` BB-43 now names all four empty areas.

### Fixed
- **Pull-to-refresh asks the server** on Choose a location and the Hospitals list. It re-read
  only the copy already in memory, so a pull right after opening never reached the network; it
  now reads with `forceRefresh` (the saved ETag still makes an unchanged list a cheap 304).
- **No more red error page offline** when the area list — or an area's hospital list — was
  never saved: both screens read the result with `valueOrNull`, so the error view (with Retry)
  shows instead (e.g. Jubilee Hills opened offline).
- **"See every hospital" on the error view** forgets the saved area first, as the same button
  does elsewhere; it opened a list still filtered to that area.
- **Every area is fetched** (`page_size=100`, the server's largest page; the default 25 would
  drop the rest), and "We currently list … areas" counts the server's total, with "1 area" /
  "1 city" in the singular.

## [Unreleased] — Home quick links audit (2026-10-06)

Every screen behind Home's Quick Booking cards (Appointment, Hospitals, Family) and the Available
Services tiles was walked on the emulator against the live server, with the app's own network
log, up to (not through) "Pay". No layout changed. What only the backend can fix is in
`docs/BACKEND_BLOCKERS.md` BB-40 … BB-43.

### Fixed
- **Booking from a service tile** names the department: step 2 reads "Hospitals with a General
  Medicine department." and the strip "Lakeshore … · General Medicine", the name taken from the
  server's department list (the tile passes only its code). It read "Doctors are listed per
  hospital." and dropped the department from the strip.
- **"Call the hospital to book"** on booking's doctor card gives the hospital's number from its
  detail.
- **A slot chosen earlier that is no longer free** says why, from the server's state — passed,
  being booked, no longer open, or taken — instead of "has just been taken" for every reason.
- **After a booking exists**, step 4 and the "Leave without paying?" dialog give the hold's end
  from the booking ("Complete the payment by 9:31 PM") instead of "before the hold runs out".
- **Department search** with no match suggests the server's own names ("Try a department name
  like "Cardiology" or "Dermatology""); the old "skin", "heart", "child" never matched.
- **Relations in booking** read as Family Members and Records word them ("Wife", "Son"), from
  the server's relation and gender, instead of "Spouse", "Child".
- **Family Members** opened from Home is announced with "Back", not "Back to profile".

## [Unreleased] — Doctor & Hospital details audit (2026-10-06)

Doctor Details and Hospital Details were walked on the emulator against the live server, with
the app's own network log. Scope set by the owner: no change to the screens' layout — only text
already on screen that showed the app's own words where the server has the real value. What only
the backend can fix is in `docs/BACKEND_BLOCKERS.md` BB-39 (and BB-17 for doctor photos).

### Fixed
- **Holidays** for one department name it — "Foundation day (Cardiology)", from the department
  list in the same response — instead of "(one department)".
- **Speciality chips** on Hospital Details show each department's icon from its code, as Home,
  Search and Booking do, instead of one first-aid mark for every chip.
- **Experience** on Doctor Details is the server's figure ("9 years"), not "9+".
- **"Call the hospital to book"** (a doctor not booked online) gives the hospital's number from
  its detail.
- **Date strip**: a day whose sessions the server marks `closed` (over, or not taken online) reads
  "not available", not "fully booked"; "fully booked" now means the server said `full`. Shared
  with the booking flow's date strip.
- **Slots that cannot be picked** say why, from the server's state: "passed", "being booked", "not
  open for booking" or "taken" — for screen readers and in the tap message ("That time has already
  passed.") — instead of "taken" for all. Shared with the booking slot sheet.

## [Unreleased] — Records audit (2026-10-06)

The Records tab and every screen behind it were walked on the emulator against
the live server, with the app's own network log. What only the backend can
fix is in `docs/BACKEND_BLOCKERS.md` BB-38 (and BB-17 for file storage).

### Fixed
- **Upload limit**: no longer a fixed 10 MB. The check before sending and the
  "up to … MB" lines read `upload_max_bytes` from app-config (10 MB until the
  server sends it, BB-38), and a server refusal names the limit it returned
  in `meta.max_bytes`.
- **Visit pickers** (Filters, Upload, Edit) show each visit's time, patient,
  booking reference and status, so visits with the same doctor on the same
  day can be told apart; screen readers hear the same detail. Cancelled and
  no-show visits are no longer offered as a link target (an existing link to
  one is kept).
- **Document date** pickers reach back as far as a date of birth (120 years,
  was 30): the server takes any date, and an adult's childhood records could
  not be dated.
- **Record cards** show the document type's icon instead of one folder.
- **Linked visit** on the document screen is named from
  `GET /patient/appointments/{id}` alone, instead of loading every appointment
  list to label one link.
- **Sorting**: "Recently added" and "Title A–Z" (the server's other two
  orders) are in the Filters sheet's new "Sort by"; the list heading says the
  order ("Oldest First" no longer reads "Recent Records").
- **Document screen**: a file that is not ready reads in words ("File: Could
  not be checked", not `scan_failed`), and an edited document shows "Last
  edited" from `updated_at`.

### Fixed after the second pass
- **Patient pickers** (Filters, Upload, Edit) name each person's relation
  from the server — "Wife", "Son", "You" — the way Family Members does,
  instead of "Family member" for everyone; so does the line under the chosen
  patient on the form.
- **Linked visit** names the hospital as well: on the document screen, in the
  Filters and form fields, in the visit pickers and on the filter chip, which
  now wraps instead of running off the screen.
- **Missing document**: the not-found screen's button says "Go to Records",
  where it goes (it said "Go to Home").
- **Offline**: the saved list shows one offline note; the red "You appear to
  be offline" banner no longer repeats it.
- **Refused file** (too large, a type not accepted, empty): only "Choose
  another" is offered; "Try again" could only fail the same way.
- **Pull-to-refresh offline** stops at once instead of spinning until the
  connection is back. A list opened offline shows the saved copy and waits
  for the network; the refresh waited for that wait to end before starting.
  Fixed in Records, the insurance list and count, and the shared cached
  controller (Family Members, Addresses, Emergency contacts, Sessions, Data
  export, FAQ, Support tickets, Ambulance, the policy pages, app config).
  A read that failed offline now loads again once the network returns, and
  the shared status bar no longer repeats the offline line in red.
- **Edit document** asks "Discard your changes?" before closing with an
  unsaved edit — from the close button, back or a tap outside — and can no
  longer be swiped away. Every sheet's close button now lets a form's
  unsaved-changes guard ask first.

## [Unreleased] — Profile audit (2026-10-06)

Every row of the Profile tab and the screens behind it was opened on the
emulator against the live server, with the app's own network log, to find
text written into the app where the server has (or should have) the value.
What only the backend can fix is in `docs/BACKEND_BLOCKERS.md` BB-28 … BB-32.

### Fixed
- **Delete account** no longer has "30 days" written in: the row, the sheet
  and the confirm dialog read `dsr_cooling_off_days` from app-config, with the
  platform default (30) until the server sends it (BB-28).
- **Signed-in Devices** can tell phones apart: the app's User-Agent is now
  `Medibook/<build version> (<maker model>; <OS version>)` instead of a fixed
  `Medibook/1.0`, read once at start-up through a small `medibook/device`
  platform channel (Android `Build`, iOS `UIDevice`; no new package). The list
  shows "Google Pixel 7 · Android 14" and "Medibook 1.0.0"; older app sessions
  read "Medibook app".
- **Family members**: `guardian_note` was read from the server but never
  shown or editable. It is now on each dependant's card and in the edit form
  (optional, up to 1000 characters; emptying it clears it).
- **Insurance**: the policy screen names who the policy covers (`person_id`),
  and the Profile row shows how many policies are saved, like the other rows.
- **Profile photo**: `avatar_file_id` is shown on Profile and on the account
  holder's Family Members card when set; initials otherwise (BB-29).
- **FAQs**: the Profile row and Help & Support summary name the server's FAQ
  categories instead of a fixed "Booking, payments, records and account".
- **Saved addresses**: the address's own contact number (`phone_e164`) can be
  added, changed and removed; it was shown but not editable.
- **Pull to refresh on Profile** now also re-reads app-config (policy
  versions, support number, feature switches), the FAQ and the policy count.

## [Unreleased] — Backend round 2 (2026-10-01)

The backend closed the round-1 gaps (`81ceed7`). Each one was re-checked on
the live server with seeded patient accounts before its section was wired;
what is still not satisfied is in `docs/FLUTTER_INTEGRATION_GAPS_ROUND_2.md`
(storage host, Razorpay key, TLS and OTP delivery are staging configuration,
not code). The whole app was then run on an Android 14 emulator against the
live server with two patient accounts.

### Added
- **Download my data** (`/profile/data-export`): `POST` / `GET
  /patient/me/data-exports` (idempotent request, one open export at a time)
  and the signed download link of a finished one; reachable from Profile and
  from the `dsr.export_ready` notification.
- **Hospital time zone from the server**: `appointment.hospital.timezone` and
  the slot grid's `timezone` drive every time shown for an appointment,
  receipt, cancellation cut-off and history entry. `HospitalZones`
  (`core/utils/date_utils.dart`) is the single offset table behind
  `HospitalTime` and `HospitalClock`.
- **Ambulance "Call now"** opens the dialler with the operator's number.
- **Add to calendar** on the booking-success and payment-result cards, and a
  working hand-off everywhere: the `.ics` goes to the OS share sheet
  (`share_plus`), named by the booking reference.
- Date picker: a plain mode for dates of birth and document dates (no slot
  availability dots or legend) with a year stepper for long ranges.
- Rating stars are labelled buttons for screen readers.

### Fixed (found by the emulator run)
- A paid visit whose time had passed but that the desk never closed
  (`scheduled`) appeared in **no** Appointments tab. "Completed" now lists
  the past bucket minus cancelled visits, each with its real status.
- After a cold start offline the unread badge stayed at zero and the account
  stayed without email, date of birth and gender after the network returned.
  Both are re-read once on reconnect.
- The live server refuses an expired token at the WebSocket handshake with
  HTTP 403, not a 4401 close: the queue and inbox sockets now refresh the
  session once and reconnect instead of backing off with the stale token.
- Bottom sheets with a text field were hidden behind the keyboard.
- Full-width button labels were cut off with an ellipsis ("Sign Out Device",
  "Retry payment"); they now scale to fit.
- Booking step 4 after backing out of the payment screen: the button reads
  "Complete payment" and the leave dialog names the held booking instead of
  saying nothing was booked. The "held for 5 minutes" wording no longer
  hard-codes the hospital's deadline.
- The record-upload form did not default the patient when the family list was
  already loaded; a storage failure during upload no longer claims the
  patient is offline.
- A support-ticket notification opens its thread, not the support home.
- Five `AsyncValue.value` reads that would rethrow on a failed load
  (hospitals, hospital detail, doctor detail).

### Removed
- Google / Facebook / X sign-in buttons (the backend has no social login).
- Home's "Health Checkup Package — 40 % discount" banner (no API backs it).

### Changed
- `share_plus ^13.3.0` added (in `Technical_stack.md`).
- Goldens regenerated: `button_primary`, `button_soft`, `screen_login`.

## [Unreleased] — Backend integration (`FLUTTER_API_INTEGRATION.md`)

The app now runs against the Medibook patient API. Every section was verified
with the test account before it was wired; what the server could not satisfy
is recorded in `docs/FLUTTER_INTEGRATION_GAPS.md` (blocking gaps, contract
mismatches, owner decisions, rows left on the test account).

### Added
- **Core network**: `DioApiClient` (bearer, `X-Request-Id`, `Idempotency-Key`,
  `If-Match`, `X-Device-Fingerprint`, error-envelope parsing, single-flight
  refresh with one retry on `AUTH_TOKEN_EXPIRED`, session-ending codes reported
  once, 304 pass-through, dev-only self-signed TLS trust), `Endpoints` registry,
  `Page<T>`, `RetryPolicy`, `RequestPool`, `IdempotencyKeys`.
- **Cache** (`HIVE implementation.md`): `CachedFetcher` L1 memory / L2 Hive /
  L3 network with `If-None-Match`, 12 h valid / 24 h stale, request dedupe,
  corruption quarantine; `HiveLocalStore` + `CacheEntry` adapter;
  `ConnectivityMonitor` / `isOnlineProvider`.
- **Realtime**: `WsClient` (`bearer,<token>` subprotocol, 4401/4408 close
  reasons) behind the inbox and live-queue controllers.
- **Secure storage**: `FlutterSecureStorageStore`, `DeviceIdentity`
  fingerprint; Android backups disabled.
- **Features rewired to the API** (4-layer, per feature): auth (password/OTP
  login, sign-up with DOB, password reset, sessions, logout everywhere),
  dashboard, search, discovery, booking (idempotent `POST /appointments`, fee
  quote, coupons), payment (Razorpay SDK gateway, order verify/retry/poll,
  resume from an appointment via `/booking/payment?appt=&order=`),
  appointments (buckets, detail, events, token card, live queue over WS,
  cancellation preview/cancel, receipt, `.ics`), notifications (list, read/
  unread, inbox WS badge, push-device register/unregister), records (documents,
  3-step file upload with scan polling), insurance, profile (edit with
  `If-Match`, phone change, alternate phone, addresses, emergency contacts,
  family + release, consents, account deletion), support (tickets, FAQ, legal,
  ambulance, app-config).
- Live suite `test/integration/live_backend_test.dart` (opt-in via
  `MEDIBOOK_LIVE_*`); `test/support/offline_overrides.dart` for widget tests.
- Platform: iOS camera/photo usage strings, `https` query scheme; Android
  `VIEW https` query intent.

### Fixed (end-to-end run on an Android 14 emulator against the live server)
- Launch crashed with a Riverpod `CircularDependencyError`: bootstrap resolved
  the shared `AuthController` from inside the app container's provider build.
  The shared instances are now resolved eagerly.
- Sign-in did not refresh `GET /me`, so Gender / DOB / blood group showed
  "Not set" until a restart.
- Hospital detail's "Select doctor for appointment" entered the booking flow
  at step 3 without a slot; it now opens step 2 (Doctor & time).
- Stale lists after mutations: the booking patient picker, the appointments
  "For …" label and the records form after adding/editing/removing a family
  member; Home's token card after a booking; the Appointments tabs after an
  in-app cancellation.
- Two more `AsyncValue.value` reads (booking picker, records form) that would
  rethrow on a failed fetch.
- Auth forms wiped a **server** field error (e.g. the sign-up password rule
  "must not contain your name…") the moment the field lost focus — the
  request disables the fields, which blurs them, and the client validator
  then passed. Server messages now survive a blur and clear on the next edit
  (`AuthFormController`, regression test in
  `test/features/auth/signup_server_errors_test.dart`).
- Sign-up verified end to end (form → OTP → `201` → Home) against a local
  backend; `android/app/src/debug` now carries a network-security-config
  that allows cleartext to `10.0.2.2`/`localhost` in **debug builds only**,
  so `--dart-define=MEDIBOOK_API_BASE_URL=http://10.0.2.2:8000` works on
  the emulator.

### Changed
- `MEDIBOOK_DEMO` defaults to `false`; `MEDIBOOK_ALLOW_BAD_CERT` added
  (refused in prod by `EnvLoader`).
- `User` mirrors the backend (`firstName`/`lastName`, `phoneE164`,
  `hasPassword`, `version`, profile fields); lockout is server-driven
  (`meta.attempts_remaining` / `locked_until`).
- Booking references and tokens are rendered verbatim (per-hospital formats).
- `AppStatusStyle` exposes named palettes; features fold their own enums onto
  them. `AsyncValue` reads use `valueOrNull` (Riverpod 2 rethrows on `.value`).
- Golden baselines regenerated on Flutter 3.44; screen goldens capture the
  offline/empty states.

### Removed
- `lib/core/mock_data/**`, the seeded controllers, pay-at-hospital and the
  simulated gateway, the local reference/token minting, the doctor-keyed queue
  screen, the `change` notification kind, the "available for donation" toggle.

## [Unreleased] — Onboarding (`Medibook Onboarding.dc.html`)

### Added
- **First-run intro** under `features/auth`: two slides (`/onboarding`), the
  consent screen (`/onboarding/consent` — Terms + Privacy required, hospital
  offers optional, CTA never disabled, hands off straight to `/login`). Shown
  once per device; the record lives in the `settings` box so a sign-out does
  not replay it.
- `onboardingProvider` + `OnboardingLocalDataSource`; `HiveKeys.offersOptIn`;
  `AppCheckBadge` (Booking Success); `AppCarouselDots`
  size/gap parameters; `AppDates.dayMonthLongYear`.

### Changed
- **Router**: a signed-out visitor lands on the intro until it is completed,
  then on sign-in. `/onboarding/*` is public and signed-out-only.
- **Legal documents** (`/legal/:slug`): restyled to the design's dense policy
  page (left-aligned title, "Last updated" line, footnote, footer button —
  "Back to sign up" when opened from consent or sign-up). Terms & Conditions
  and Privacy Policy now carry the design's copy (v2026.2, 12 Sep 2026); the
  "Draft copy" banner is gone.

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
