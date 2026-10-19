# Flutter ↔ backend integration — round 3: what is still not satisfied

**Verified:** 2026-10-18 against the UAT API `https://app-dev.medibook.co.in/api/v1` (backend source
read at `fix/uat-no-go-2026-10-16`, `70c12a4`).
**Accounts used** (password `seed_password_123`): Sanjay Varma
(`sanjay.varma@patients.medibook.example.com`), Asha Rao (`asha.rao@patients.medibook.example.com`).
Only GETs and fee quotes were sent. No booking, cancel or export request was created.
**Predecessor:** `docs/FLUTTER_INTEGRATION_GAPS_ROUND_2.md` (2026-10-01).

This round covers the UAT items UB-56, UB-27, UB-12, UB-55, UB-20 and UB-38. Each endpoint was hit
first with a seeded account, and the app was wired only to what the server returns. This file records
what was **not** satisfied, what could not be exercised, and where the contract file is now out of
date. What *was* wired is summarised in §1.

## 0. Summary

| | Count | Where |
|---|---|---|
| UAT items wired and verified on the emulator | 4 (UB-56, UB-27, UB-12, UB-55) | §1 |
| UAT items wired and covered by tests only | 1 (UB-20) | §1, §3 |
| UAT items blocked on the owner | 1 (UB-38 / DEF-016, push) | §2 |
| Contract-file gaps (server ahead of `FLUTTER_API_INTEGRATION.md`) | 5 | §4 |

## 1. What the app does now

| Item | Server evidence (2026-10-18) | App change | Verified |
|---|---|---|---|
| UB-56 / DEF-047 campaign banners | `GET /patient/content/banners` (Sanjay) → `200`, one row: `scope: "platform"`, `hospital_id: null`, `title: "Monsoon health check-ups"`, `body`, `image_file_id: null`, `cta_label: null`, `cta_target: null`, `audience: "all_patients_in_city"`. Query: `city`, `hospital_id`, `page`, `page_size` (any other parameter → `400`). | Home's Offers strip now shows the platform feed first, sent with the token (so a patient with bookings also gets `hospital_patients` banners) and the saved browse city. The previewed hospitals' own banners follow, as before. Banners in both lists are shown once. If the feed fails, the hospital banners still show. If both are empty, the strip stays hidden. A banner with no `cta_target` and no hospital does nothing on tap. | Emulator `APPFIX_UB56_home_platform_banner` |
| UB-27 coupon message | `GET /patient/fee-quotes?doctor_id=<Dr. Harish Menon>&coupon_code=LAKE10` → `coupon: {valid: false, reason: "COUPON_NOT_APPLICABLE", message: "This coupon cannot be used for this doctor's department.", meta: {reason: "department"}}`. Unknown code → `COUPON_INVALID`, "This coupon is not valid." | The coupon field shows the server's `coupon.message`. House wording is used only when no message comes. `COUPON_NOT_STARTED` and `COUPON_NOT_APPLICABLE` are now known codes: a `409` at booking with either code removes the coupon and shows the server's sentence. | Emulator `APPFIX_UB27_coupon_department_message` (booking was left before paying) |
| UB-12 desk-booking cancel | Sanjay's walk-in `LKSB-2610-00199`: `source: "walk_in"`, `token_source: "offline"`, `actions: {can_cancel: false, cancel_blocked_reason: "APPOINTMENT_NOT_ACTIONABLE"}`. Cancellation preview → `allowed: false`, same reason. Backend `cancel_by_patient` refuses with `409 APPOINTMENT_NOT_ACTIONABLE`, `meta.reason: "desk_booking"`. | The detail screen reads `source`. When a walk-in has Cancel switched off, the screen now shows "This booking was made at the hospital desk; please ask the hospital to cancel it." above the disabled button, and the button's label says the same. A `409` with `meta.reason: desk_booking` keeps the server's sentence. The other blocked reasons get their own text too. | Emulator `APPFIX_UB12_walkin_cancel_reason` (cancel not attempted) |
| UB-55 / DEF-045 data-export status | Sanjay `DSR-2026-0003`: `status: "rejected"`, `status_label: "Rejected"`, `completed_at` **and** `rejected_at` 18 Oct, `ready_at: null`, `rejection_reason: "UAT retest: duplicate test request - please raise a new one if needed."`. Asha `DSR-2026-0001`: `completed`, `"Ready"`, `ready_at` set. | The badge uses `status_label`. The date line says "ready" only when `ready_at` is set, "rejected" when `rejected_at` is set, and "closed" for no-data or withdrawn requests. The rejection reason is shown as "Reason: …". | Emulator `APPFIX_UB55_data_export_rejected`: "Rejected · Requested 16 Oct 2026 · rejected 18 Oct 2026 · Reason: …" |
| UB-20 rebook prompt | Backend source: `appointment.cancelled` inbox `data` carries `rebook_prompt` (a JSON boolean) and `appointment_id`. Push `data` carries `rebook_prompt` as `"true"`/`"false"`. It is true for a hospital schedule-change cancel. | The notification is parsed for `rebook_prompt` (boolean or `"true"`). A prompted `appointment.cancelled` card shows a **Rebook** button. The button marks the card read, reads the appointment from cache or the server for its doctor and department, and opens booking at the slot step for the same doctor. If the appointment cannot be read, it opens the appointment, where **Book Again** does the same. | Unit and widget tests only (§3) |

## 2. Blocked on the owner

| # | Gap | Evidence | What the app has | Needs |
|---|---|---|---|---|
| R3-1 (UB-38, DEF-016; was R-4 / D-1) | **The app cannot get a push token.** FCM tokens come only from the Firebase SDK. | `pubspec.yaml` has no `firebase_core` or `firebase_messaging`. `docs-flutter/Technical_stack.md` does not list them. There is no `android/app/google-services.json` and no `ios/Runner/GoogleService-Info.plist`. The backend is ready: `POST/GET/DELETE /patient/me/devices` works (`GET` as Sanjay → `200`, one seeded row `fcm-demo-token-003`). | Already in place since round 2, and not duplicated: `NotificationsRepository.registerDevice` / `deleteDevice` and `PushDeviceController.register` / `unregister` (`pushDeviceProvider`). Logout already calls `unregister`. Nothing calls `register`, because there is no token to send. No Firebase code was added. | **Owner:** (1) create or name the Firebase project; (2) register Android app `com.navoracloudsoft.medibook` and add `android/app/google-services.json`; (3) for iOS, register the bundle id, add `ios/Runner/GoogleService-Info.plist` and upload an APNs key to Firebase; (4) approve adding `firebase_core` and `firebase_messaging` to `Technical_stack.md` (exact versions); (5) **server:** mount the service-account JSON and set `FCM_SERVICE_ACCOUNT_PATH` (backend `settings/base.py`; `docs/OPERATIONS.md` → `SECRETS_DIR/fcm_service_account.json`), and add `fcm` to `PROVIDERS_LIVE` on app-dev. After that, the app work is to get the token after sign-in, call `register` (send `Device.id` as `device_id` on login, §12.6), handle `onTokenRefresh`, and route push taps through `NotificationTargets` (including `rebook_prompt`). |

## 3. Could not be exercised live

| Flow | Why | Covered by |
|---|---|---|
| UB-20 "Rebook" on a real notification | No inbox row on either account carries `rebook_prompt` (Sanjay 40 rows, Asha 50, none with the key). Message workers on app-dev are stopped, so no new notifications are created. Making one would need a hospital schedule-change cancel on shared data. | `test/features/notifications/rebook_prompt_test.dart`: parsing (`true`, `"true"`, `false`, missing); only `appointment.cancelled` offers Rebook; the provider resolves the doctor; the card button; the inbox screen → booking route with the same doctor and department at step 3, card marked read. |
| Push delivery of `rebook_prompt` | R3-1. | Same parser (the `"true"` string case). |
| UB-12 refused cancel (`409 desk_booking`) from the UI | The server already sends `can_cancel: false` for walk-ins, so the app never offers Cancel and the `409` path is not reachable from the screen. | `test/features/appointments/desk_booking_cancel_test.dart` (error mapping, sentence, detail screen). |
| UB-56 banner image and CTA | The only live campaign banner has no image and no `cta_target`. | Existing `cta_target` routing; `test/features/dashboard/home_providers_test.dart`. |

## 4. Contract file (`docs-flutter/FLUTTER_API_INTEGRATION.md`) behind the server

The spec folder was not edited. The owner should fold these in:

| # | Contract says | Server does |
|---|---|---|
| C-1 | §7.4: "Banners belong to a hospital. There is no platform-wide banner list (§18)." | `GET /patient/content/banners?city&hospital_id&page&page_size` (anonymous allowed). Row: `id, scope (platform\|hospital), hospital_id, hospital_name, title, body, image_file_id, image_url, image_url_expires_at, cta_label, cta_target, audience, sort_order, starts_at, ends_at`. `image_url` is a short-lived signed URL. `cta_target` is a `medibook://` link or an approved `https://` host. |
| C-2 | §8.3: `coupon` is `{code, valid}` or `{valid, reason}`, with reason ∈ `COUPON_INVALID \| COUPON_EXPIRED \| COUPON_MIN_ORDER \| COUPON_USAGE_CAP`. | `{valid, reason, message, meta}`, with no `code` key. Reasons also include `COUPON_NOT_STARTED` (`meta.valid_from`) and `COUPON_NOT_APPLICABLE` (`meta.reason` = `department` \| `online_only`). The same two codes can come as a `409` at booking (§9.1). |
| C-3 | §10.2: `cancel_blocked_reason` is one of three codes. | A desk walk-in also returns `APPOINTMENT_NOT_ACTIONABLE`. The only sign of the desk case before the `409` is `source: "walk_in"`, because `meta.reason: desk_booking` arrives only on the refused `POST …/cancel`. **Suggestion (backend):** a distinct `cancel_blocked_reason` such as `DESK_BOOKING` (or `actions.cancel_blocked_message`), so the app does not have to infer the case. |
| C-4 | §5.7 / round 2 N-3: export row `{id, request_no, kind, status, requested_at, due_at, completed_at}`. | Also `status_label`, `ready_at` (completed only), `rejected_at`, `rejection_reason`. `completed_at` is set for every closed request, including rejected ones. |
| C-5 | §12.1: `data` ids only. | `appointment.cancelled` also carries `data.rebook_prompt` (boolean in the inbox, `"true"`/`"false"` in push). |

## 5. Noticed this round, not changed

- After **Apply**, the coupon text box is empty again while the refusal sentence shows under it,
  because the field is rebuilt when the new quote loads. The patient can still read the reason but
  no longer sees the code they typed. This behaviour already existed and is outside this round's
  items.
- UB-12: a walk-in whose time has passed but that the desk never closed (`LKSB-2610-00199`,
  16 Oct, still `scheduled`) still shows the desk sentence. The server gives the same reason code for
  "past" and for "desk", so the app takes `source` as the deciding signal. The sentence is still
  true.

## Addendum — 19 Oct 2026: UB-13 closed (no reschedule)

- **Decision:** the client workbook (`Medibook Updates and Reports-2.xlsx`, Architecture Q85, Q32/Q73) confirms there is no reschedule: cancel, then book again. The backend has no reschedule endpoint (`POST /patient/appointments/{id}/reschedule` → 404).
- **Fixed in the app:** every "Book Again" / "Rebook" entry point (appointment detail, appointments list card, appointment search, notification Rebook) opened booking at step 3 with a doctor but no slot, which can only show "Pick a doctor and a time first". They now share `AppRoutes.rebookPath`, which opens step 2 (Doctor & time) with the doctor chosen. Test: `test/app/rebook_path_test.dart`.
- **Removed dead code** from the old reschedule screen: the unused `bookingRescheduled` analytics event and the reschedule-only `combine` helper in `lib/core/utils/date_utils.dart`.
- **Verified on emulator-5554 against app-dev:** hospital-cancelled booking → Book Again → new slot → Razorpay test payment → confirmed; patient cancel → Book Again → step 2.
