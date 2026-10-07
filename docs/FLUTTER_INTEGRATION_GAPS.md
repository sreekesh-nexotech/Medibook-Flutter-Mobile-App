# Flutter ↔ backend integration — gaps and decisions

**Verified:** 2026-09-30 against `https://62.171.151.149:8443` with the test account
`anita.menon@lakeshore.medibook.example.com`.
**Contract:** `docs-flutter/FLUTTER_API_INTEGRATION.md`. **App-side plumbing:** `docs/INTEGRATION-CORE.md`.

> **Round 2 (2026-10-01).** The backend reported these gaps fixed and each was re-checked.
> `docs/FLUTTER_INTEGRATION_GAPS_ROUND_2.md` has the result: which rows below are closed (1.3,
> 2.9, receipts, reviews, deletion, alternate phone), which are still open on staging (1.1, 1.2,
> 1.4, 1.5), and what the re-check newly found. This file is kept as the round-1 record.

Every section of the app was built only after its endpoints were hit with the test account and the
response matched the contract. This file is the record of everything that did **not** match, could
not be exercised, or needs a decision from the product/backend owner. The per-slice verification
logs — with the exact requests and responses — are in `docs/integration-gaps/`:

| Slice | Log |
|---|---|
| Auth, session, core network/cache | this file (§1, §6) + `test/integration/live_backend_test.dart` |
| Discovery, booking, payment, dashboard, search | `integration-gaps/booking-payment-discovery.md` |
| Appointments, notifications, live queue | `integration-gaps/appointments-notifications.md` |
| Records, file uploads, insurance | `integration-gaps/records-files-insurance.md` |
| Profile, family, support, legal/FAQ/ambulance | `integration-gaps/profile-support-content.md` |

## 0. What is integrated and live-verified

Password and OTP login, refresh rotation, logout/logout-everywhere, session listing and revocation,
sign-up and password reset challenges, `/me` with ETag/304, profile PATCH with `If-Match`, addresses,
emergency contacts, family members, consents, app-config, legal documents, FAQ, ambulance directory,
support tickets, hospitals/doctors/departments/slots/fee-quote, booking (`POST /appointments` with
idempotency, replay confirmed), payment order read/retry/verify(error path), appointment lists,
detail, events, token card, queue, cancellation preview and cancel, notifications list/read/unread/
delete, push-device register/delete, documents list/filters, upload ticket creation, insurance
policies CRUD with `If-Match`. Every HTTP error envelope, the unknown-query-parameter 400, the
`Idempotent-Replayed` header and the `AUTH_*` session codes behave as documented.

`flutter analyze` is clean and `flutter test` passes (332 tests, 4 opt-in skips; the live suite passes 4/4).

## 1. Blocking — cannot be finished end-to-end against this environment

| # | Gap | Evidence | What the app does now | Needs |
|---|---|---|---|---|
| 1.1 | **Presigned upload host does not resolve.** `POST /shared/files/uploads` returns `upload_url` on `https://storage.fake.local/…`; the `PUT` never lands, so `complete` answers `400 "The object has not been uploaded yet."` and no file ever reaches `clean`. Every feature that needs a file — medical documents, insurance documents, ticket attachments, profile photo — is therefore blocked after step 1. | records log §1 | The full 3-step flow (`FileUploadServiceImpl`) is implemented and unit-tested; a DNS failure surfaces as `NetworkFailure` with "Try again". | A reachable object store (or a signed-PUT proxy on the API host) on staging. |
| 1.2 | **Razorpay is stubbed server-side.** Every order has `key_id: ""` and `gateway_order_id: "order_fake…"`; the SDK cannot open (`INVALID_OPTIONS`). | booking log §2; re-confirmed on `GET /appointments/{id}` → `payment_order.key_id: ""` | `PaymentFlowController.pay` refuses an order with an empty key and says online payment is not set up for this hospital. `verify` was exercised only with a bogus signature (`400 PAYMENT_SIGNATURE_INVALID` → failed + retry, as §9.3). | Razorpay test-mode keys on the server (and the hospital's key in `payment_order.key_id`). |
| 1.3 | **The test account has no "self" person.** `GET /me/persons` lists only dependants; `POST /me/persons {"relation":"self"}` → `400 "A dependant cannot have relation 'self'."` | profile log §1, booking log §1 | `selfPersonIdProvider` is `null`; "book for myself", the records upload form and the family screen all say so and offer "Add a family member". No person id is ever invented. | Seed a self person for patient accounts (or a `POST /me/persons/self`). |
| 1.4 | **Self-signed TLS on staging.** | curl needs `-k`; Dart refuses the chain | `Env.allowBadCertificate` (`MEDIBOOK_ALLOW_BAD_CERT`, default `true` outside prod) installs a trust-all callback; `EnvLoader` refuses a prod build with it on. | A CA-signed certificate before any external tester build. |
| 1.5 | **No push token source.** There is no Firebase/FCM SDK in the stack (`Technical_stack.md` lists none). | — | `pushDeviceProvider.register/unregister` and `DELETE /me/devices/{id}` are wired and live-verified; **nothing calls `register`** because there is no token. Unregister runs before logout. | Decide FCM (`firebase_core` + `firebase_messaging` + platform config) or another provider. |

## 2. Contract ≠ live server (document the doc should be updated to match)

| # | Doc says | Server does | App |
|---|---|---|---|
| 2.1 | `booking_ref` `MB-2026-000124`, `token_label` `T-026` | `LKSB-2609-00183`, `A001` (per hospital) | Both rendered verbatim as opaque text (§1.11); the old `T-NNN` normaliser is gone. |
| 2.2 | `GET /notifications?kind=change` | `400 Must be one of: confirmation, reminder, cancellation, payment, queue, general` | `change` kind removed. |
| 2.3 | `doc_type` filter (§11.2) reads as multi-select in the design | single-valued (`?doc_type=a&doc_type=b` is not accepted) | Filter sheet is single-select. |
| 2.4 | `sort=distance_km` on hospitals | `400 "Sorting by distance requires lat and lng."` | Sent only when coordinates exist; there is no geolocation package (decision §4.3). |
| 2.5 | `GET /search?q=` | `q` must be 2–100 characters (`400` otherwise) | Debounced 300 ms, never sends <2, truncates at 100. |
| 2.6 | Departments carry an `icon` | `GET /departments` has no icon; hospital departments' `icon` is `null` | `departmentIconFor(code)` maps known codes to design marks. |
| 2.7 | Platform banner list | Only `GET /hospitals/{id}/banners` (one banner per seeded hospital, no image, no CTA) | Home stitches the first five visible hospitals' banners; `cta_target` deep links not followed (none in seed). |
| 2.8 | `support_contacts` with email/hours | `{"phone_e164": "+914847100000"}` only | Email/hours no longer shown; model has an optional `email`. |
| 2.9 | Appointment object carries the hospital `timezone` | It does not; only `GET /hospitals/{id}` has it | `HospitalTime` renders `Asia/Kolkata` via a fixed `+05:30`; booking uses `hospital_clock.dart` for the detail's zone (decision §4.4). |
| 2.10 | `PATCH /me` edits email | Email is immutable (§18) | Read-only on `/profile/edit`. |
| 2.11 | Rich relation labels ("Son", "Mother") | Five relations, no label field | Labels derived from relation + gender. |
| 2.12 | Legal `version` string | `int` | Consent records `version.toString()`. |
| 2.13 | `cancellation-preview` after cancel → 404 | `200 {allowed:false, reason:APPOINTMENT_NOT_ACTIONABLE}` | Button driven by `actions.can_cancel`; preview fetched only when allowed. |
| 2.14 | `Last-Modified` conditional GETs (HIVE spec) | Server sends `ETag` only | `CachedFetcher` uses `If-None-Match`; 304 verified on public and authed reads. |
| 2.15 | `GET /faqs` rich Markdown | One-line `answer_md` strings | Renderer supports `#`/`##`, bullets, paragraphs, `**bold**` (no markdown package). |
| 2.16 | "Available for donation" toggle on Profile (design) | No backend field | Toggle removed rather than persisting nothing. |
| 2.17 | Sign-up password rule: doc says ≥10 characters | Server also rejects a password containing the first/last name, email or phone (`400 VALIDATION_ERROR` on `password`: "The password must not contain your name, email or phone number.") | Server message shown on the field; the doc should list the rule so the client can pre-validate. |

## 3. Not verifiable on the shared account — built from the contract and the error paths only

These flows would have changed or frozen the shared account, or need data the account cannot get:

| Flow | What was exercised | Not exercised |
|---|---|---|
| **Sign-up (§4.1–4.2)** | **Verified end-to-end from the emulator against a local copy of the backend** (same code, `PROVIDERS_MODE=fake`; the OTP was read from the local `outbox_events.code_enc`): form → `signup/start` → wrong code (`AUTH_OTP_INVALID`, "2 attempts left") → real code → `201` → `/me` → Home; DB has the user, a `self` person and the three consents. Against **staging** only `signup/start` and its rejections are verifiable — the code is never exposed. | a real SMS on staging |
| Phone change (§5.3) | validation errors, `AUTH_OTP_INVALID` on confirm-old | real OTP delivery / happy path |
| Alternate phone (§5.4) | validation | happy path |
| Release a dependant (§5.8) | `409 UNDER_AGE`, validation | `release/verify` happy path |
| Account deletion (§5.6) | `GET` empty, `DELETE` 404, `reactivate` 409 | `POST /me/deletion-requests` (would freeze the account) |
| Receipts (§10.8) | `404 NOT_FOUND` (no paid booking exists) | receipt JSON / PDF on a paid booking |
| Payment verify (§9.3) | bogus signature → `400 PAYMENT_SIGNATURE_INVALID` | a real capture |
| Medical documents / insurance documents (§11, §6.4) | list, filters, 404s, `415`/`413` on upload tickets, `400` on unclean `file_id` | create/edit/delete a real document (blocked by §1.1) |
| WebSockets (§15) | handshake path (`bearer,<token>` subprotocol, 4401/4408) unit-tested with a scripted socket | a live frame (no `websockets` client on the build machine) |
| Retry payment from an appointment (§9.4) | `GET /appointments/{id}` embeds the latest `payment_order` (`expired`, attempts 2) — the resume path decodes it | a retry that reaches the SDK (blocked by §1.2) |

## 4. Decisions needed from the owner

| # | Decision | Why |
|---|---|---|
| 4.1 | **Push provider** (FCM or other) and its platform config. | §1.5 — device registration is wired but there is no token. |
| 4.2 | **Storage host on staging** (or a proxy). | §1.1 — no upload can complete. |
| 4.3 | **Geolocation package** (`geolocator`) for "Hospitals near you" distance sort. | §2.4 — without coordinates the list is name-ordered under the design's "near you" label. |
| 4.4 | **Time zones:** add the `timezone` package, or a zone-aware formatter in `core/utils/date_utils.dart`. | §2.9 — two features carry their own fixed-offset shims. |
| 4.5 | **"Add to calendar":** add `share_plus` / `open_filex`. | `calendar.ics` is downloaded and handed to `url_launcher` with a `file://` URI, which iOS generally refuses; the fallback shows the saved path. |
| 4.6 | **QR package** for the token card's `qr_payload`. | Shown as "Desk code" text today (`qr_payload == booking_ref`). |
| 4.7 | **`naming_conventions_lints` custom lint package** (Linting guide) — it is not in the repo or on pub. | `dart run custom_lint` cannot run; the pre-commit hook skips step 3 when the package is absent. `analysis_options.yaml` still carries only `flutter_lints`; the guide's stricter rule set is deferred so as not to break `flutter analyze` mid-integration. |
| 4.8 | **Toolchain pins.** `Technical_stack.md` pins Flutter 3.24.5 / Dart 3.5.4, `flutter_secure_storage ^9.2.2`, `razorpay_flutter ^1.3.7`, `dio ^5.7.0`, and lists `retrofit`, `isar`, `pretty_dio_logger`, `riverpod_annotation`. | The app builds on Flutter 3.44.8 / Dart 3.12.2 with `flutter_secure_storage ^11.2.0` (the v9 `encryptedSharedPreferences` option no longer exists), `razorpay_flutter ^1.4.7`, `dio ^5.11.1`; Retrofit/Isar/logger/codegen are not used (hand-written `*Api` classes and mappers, no build_runner). Either update the stack document or pin the SDK with FVM. |
| 4.9 | **Demo mode default.** `MEDIBOOK_DEMO` now defaults to `false` (the app talks to the server); the demo auth API remains for reviewer builds. | The QC capture rig (`test/qc/capture_screens_test.dart`) drove the seeded flows and is now opt-in (`MEDIBOOK_SHOT_DIR`); it needs a demo-data pass to be revived. |
| 4.10 | **Ticket attachments.** `attachment_file_ids` is accepted by the model/API but no picker is wired on the support ticket form. | Blocked by §1.1 anyway; decide whether tickets need attachments at launch. |

## 5. App-side follow-ups (no backend change needed)

Seen on the emulator run (2026-09-30, Android 14, live server) and **not yet fixed**:

- Long button labels truncate with an ellipsis on a 390-dp frame: "Sign Out Device" in the
  session-revoke dialog, "Keep booking" in the leave-booking dialog, "Retry payment" on the
  appointment detail footer (`AppButton` is single-line).
- The date-of-birth picker (family member / profile edit) reuses the slot calendar sheet, so it
  shows green "Available" dots and the *Available / Fully booked / Not available* legend.
- After `POST /appointments` succeeds and the patient backs out of the payment screen, booking
  step 4 still shows "Pay ₹…" as if nothing was booked, and the leave dialog says "Nothing has been
  booked or charged" although the booking exists and the slot is held for 5 minutes. The
  Appointments tab does show it as *Payment pending* with "Complete payment".
- The ambulance screen's "Call now" is still the pre-integration `demo` stub; `url_launcher` is now
  in the build, so it can dial `tel:` (the `DIAL` query intent is already in the manifest).

- `CachedFetcher.invalidate(pathPrefix:)` clears the whole response cache (keys are hashes); every
  mutation therefore drops all cached GETs, which rebuild at 304 cost. A per-path index would keep
  the hospital list warm after a booking.
- Appointments reads persons through its own `appointmentPersonsProvider`; records through
  `features/common/persons`; profile through `personsProvider`. Three readers of one endpoint —
  fold onto `common/persons` when convenient.
- Riverpod 2's `AsyncValue.value` **rethrows** on `AsyncError`. Every screen read was moved to
  `valueOrNull`; keep it that way (a future lint candidate).
- Golden baselines (`test/goldens/images`) were regenerated on this engine and, for the screens,
  capture the **offline/empty** design states behind `test/support/offline_overrides.dart`.
  Loaded-data rendering is covered by the per-feature widget tests with fake repositories.
- Banner `cta_target` deep links are not followed (no seeded banner has one).
- The filter sheet's doctor/hospital pickers come from the loaded pages, not a distinct-values
  endpoint; search (`q=`) covers a long history.

## 6. Rows left on the shared test account

Everything created during verification was removed where the API allows. What remains:

| Row | Id | Why it remains |
|---|---|---|
| Cancelled appointment `LKSB-2609-00182` (patient-cancelled, never paid) | `01a0f15b-bcf6-7b91-a0eb-2d9a1d7ebacf` | cancelled appointments cannot be deleted |
| Cancelled appointment `LKSB-2609-00183` (auto-cancelled `payment_timeout`, 2 expired orders) | `01a0f17f-760d-7ef0-bd32-51372f1d883b` | same; its person was deleted afterwards, so the detail shows "Family member" |
| Cancelled appointment `LKSB-2609-00184` (booked and cancelled **from the app** during the emulator run, Dr. Harish Menon, 30 Sep 17:00; its person "Testperson" was removed from the app afterwards — the server allows deleting a person whose only appointment is cancelled) | — | cancelled appointments cannot be deleted |
| Consent `terms` v1 | `01a0f15b-4f6b-7883-9316-a4d59858c9a3` | no delete endpoint |
| Support ticket `TKT-2026-0019` ("Integration test ticket") | `01a0f15b-55bc-75f3-9c3a-b48ebebc47a2` | no delete endpoint — safe to close |
| `user.version = 2`, `profile.version = 2`, `gender = female` | — | a profile row was created by the first `PATCH /me` probe |

## 7. Platform entries added for the new packages

- `ios/Runner/Info.plist`: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`
  (image_picker); `https` in `LSApplicationQueriesSchemes`.
- `android/app/src/main/AndroidManifest.xml`: `INTERNET`, `ACCESS_NETWORK_STATE`, a `VIEW https`
  query intent (url_launcher on Android 11+), backups disabled (`allowBackup=false`,
  `data_extraction_rules.xml`) so tokens never leave the device.
