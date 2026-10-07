# Flutter ↔ backend integration — round 2: what is still not satisfied

**Verified:** 2026-10-01 against `https://62.171.151.149:8443` (backend at `81ceed7`, "enhance patient
data export and appointment handling").
**Accounts used** (from `docs-flutter/users.json`, password `seed_password_123`): Sanjay Varma
(`+919808683257`), Asha Rao (`asha.rao@patients.medibook.example.com`); Priya Nair (`+919808675338`)
for one OTP send; the staff account `anita.menon@…` for one comparison read.
**Predecessor:** `docs/FLUTTER_INTEGRATION_GAPS.md` (round 1, 2026-09-30). Section numbers such as
"1.1" below are that document's.

The backend team reported every round-1 gap as fixed. Each one was re-checked the same way as
before: the endpoint was hit with a seeded patient account first, and the app section was wired
only where the requirement was strictly met. This file records what was **not** met, what could
still not be exercised, and what the re-check newly turned up. What *was* wired is in
`CHANGELOG.md`; the emulator run that confirmed it is §6.

## Backend response (2026-10-05)

Every item below was checked against the code, fixed where it was a backend gap, and covered by a
test. The full suite passes (571 passed, 1 skipped), and ruff and mypy are clean. Where an item needs
the **staging deployment** changed, the exact settings are listed. The code for them is in place,
but nothing on 62.171.151.149 has been changed yet. `docs/OPERATIONS.md` → *Staging* has the same
list.

### What the staging deployment needs (one change set, then `docker compose up -d`)

| For | Set on staging |
|---|---|
| R-1 uploads and downloads | `PROVIDERS_LIVE=storage,clamav` · `S3_PUBLIC_ENDPOINT=https://62.171.151.149:9443` · open port 9443 (nginx now serves the object store there) |
| R-2 payments | Razorpay **test-mode** `RAZORPAY_KEY_ID` / `_KEY_SECRET` / `_WEBHOOK_SECRET`, and add `razorpay` to `PROVIDERS_LIVE` (needs the owner's keys) |
| §4 OTP flows | `DEV_OTP_FIXED_CODES=+919808683257:1234,+919808675338:1234,…` — the testers' numbers |

### Item by item

| # | Status | What changed / what to do |
|---|---|---|
| R-1 | **Fixed in code; staging config pending** | There were two causes. First, `PROVIDERS_MODE=fake` swapped every provider, storage included; the new `PROVIDERS_LIVE` setting keeps named providers real. Second, even with real storage, presigned URLs were signed for `http://minio:9000`, a host only the server can reach. URLs are now signed for `S3_PUBLIC_ENDPOINT`, and nginx forwards port 9443 to MinIO without changing the Host header, so the signature still matches. Verified on a local stack: presigned `PUT` → 200, the server-side size/sha256 check passes, presigned `GET` returns the same bytes as an attachment, and a tampered or unsigned URL → 403. Port 9443 uses the same certificate as the API, so a browser download will show the self-signed warning until R-3 is done. |
| R-2 | **Code ready; needs keys** | `PROVIDERS_LIVE` lets Razorpay go live on its own while SMS and email stay fake. `payment_order.key_id` is then the test key. |
| R-3 | Unchanged (ops) | Needs a CA-signed certificate. Covers port 9443 too. |
| R-4 | Unchanged (decision D-1) | — |
| N-1 | **Fixed** | A missing, bad or expired token, or another account's appointment, is now **accepted and then closed with 4401**. The client always receives the code. `bearer` is selected only when the client offered it. Keep `WsHandshakeRefused` for real network failures. |
| N-2 | **Decided** (no code change) | No automatic no-show (Q27, Q87) and no automatic completion. A past visit the desk never closed **keeps its status** (`scheduled`, `checked_in`, …). `bucket=past` returns it whatever its status, and `bucket=upcoming` never includes a visit whose end time has passed. A "past" tab can use `bucket=past` with no status filter. The app's current Completed query is also correct. |
| N-3 | Contract text | `POST /patient/me/data-exports` needs an `Idempotency-Key` and returns `202` with the row. `GET` lists your own requests. Row: `{id, request_no, kind: "export", status, requested_at, due_at, completed_at}`; `status` is `requested`, `verifying`, `processing`, `completed`, `no_data` or `rejected`. Only one open export at a time, else `409 STATE_CONFLICT`. When `completed`, call `GET /shared/data-exports/{id}/download-url`, which returns `{url, expires_at, file_expires_at, request_no}`. The file is kept 7 days. The `dsr.export_ready` notification carries `data.dsr_id`. |
| N-4 | Contract text | `If-Match` is **required** on `PATCH /patient/documents/{id}`. Missing → `400 VALIDATION_ERROR` with `errors["If-Match"]`; stale → `409 CONFLICT_VERSION` with `meta.current`. On DELETE it is checked only when sent. |
| N-5 | **Fixed** + contract text | `GET /patient/doctors/{id}/availability` now carries top-level `timezone`, as `…/slots` does. Appointments carry `hospital.timezone`. |
| N-6 | Contract text (keep the row) | The `marketing` row records that the user opted in **at sign-up**; there is none if they did not. `document_version: 0` means no marketing text is published. It is history, not the current setting: the current choice is `profile.marketing_opt_in`, changed with `PATCH /me`, and `POST /me/consents` does not accept `marketing`. Compare only `terms`, `privacy` and `guidelines` with `legal_versions`, as the app already does. |
| N-7 | Contract text | `fy_code` is `"FY2026-27"`. The `"26-27"` example is wrong. |
| Contract file | Owner | `FLUTTER_API_INTEGRATION.md` is not in this repository's history, so no copy here could be updated. The owner should commit one current copy and fold in N-1 … N-7 from this table. |

### §4 flows

| Flow | Now |
|---|---|
| Sign-up, OTP login, forgot password, phone change, dependant release | With `DEV_OTP_FIXED_CODES` set, a listed number always gets its fixed code. Only how the code is chosen changes: the 180 s validity, 3 attempts, resend and per-IP limits and the device binding all still apply. It is ignored once SMS is real, and the server refuses to start with it in prod. |
| Pay → success → receipt | Needs R-2. Separately, a crash in **receipt PDF rendering** was fixed: WeasyPrint 70 failed on the first external URL in a template, and such URLs are now skipped. |
| Documents, insurance, attachments, receipt PDF | Needs R-1. |
| A finished data export | Processing is daily at 04:00 by design (30-day deadline, §5.13). On staging, compliance staff can finish one at once with `POST /platform/compliance/data-requests/{id}/process`. |
| A moving live queue | No backend gap. A desk user (`dept_front_desk`) has to open the session and call tokens while the app watches. |

## 0. Summary

| | Count | Where |
|---|---|---|
| Round-1 gaps now closed and wired | 6 | §1 |
| Round-1 blocking gaps **still open on staging** | 4 | §2 |
| New mismatches between the contract and the live server | 7 | §3 |
| Flows that still cannot be run end to end | 5 | §4 |
| Owner decisions still open (one more closed, one narrowed) | 7 | §5 |

The two gaps that block the most — the upload/download storage host and the Razorpay key — are
**configuration of the staging deployment**, not code: the backend code paths answer correctly,
but the server behaves as a `PROVIDERS_MODE=fake` deployment (a storage host that does not
resolve, `order_fake…` payment orders with an empty key).

## 1. Round-1 gaps that are now closed

| # | Round-1 gap | Evidence it is fixed | What the app does now |
|---|---|---|---|
| 1.3 | No "self" person | `GET /patient/me/persons` on both patient accounts returns an `is_self: true`, `relation: "self"` row first (Sanjay `01a0ee28-acd5…`, Asha `01a0ee28-a927…`). | "Book for myself" works: the booking in §6 was made for *Sanjay Varma, You*. The upload form defaults the patient to the account holder. (The staff account `anita.menon@…` still has no persons — it never signed up as a patient; that is expected, not a gap.) |
| 2.9 | Appointment carries no time zone | `GET /patient/appointments` → `hospital: {…, "timezone": "Asia/Kolkata"}`; `GET /patient/doctors/{id}/slots` → top-level `"timezone": "Asia/Kolkata"`. | Every appointment, receipt, cancellation cut-off and history stamp is rendered in `appointment.hospital.timezone`; the slot grid uses its own `timezone`. One offset table (`HospitalZones`, `core/utils/date_utils.dart`) replaces the two per-feature shims. See §5 D-4 for the remaining limit. |
| §3 | Receipts never seen | `GET …/{id}/receipt` → `200` with lines, `payment_lines`, hospital and platform GST blocks (`LKSR/26-27/00087`, `LKSR/26-27/00153`). | Receipt screen verified on the emulator with real paid bookings. |
| §3 | Review never sent | `POST …/{id}/review` from the app on `LKSB-2609-00095` → server now `reviewed: true`, `can_review: false`. | "Rate visit" verified end to end; the button disappears afterwards. |
| §3 | Deletion and alternate phone never run | From the app: `POST /me/deletion-requests` → `DSR-2026-0004`, account `pending_deletion`; `POST /me/reactivate` → `active`, request `withdrawn`. `POST` / `DELETE /me/alternate-phone` → `200`. | Both flows verified on the emulator (the alternate number was removed again afterwards). |
| new | Patient could not start a data export | `POST /patient/me/data-exports` (`Idempotency-Key`) → `202`; `GET` lists; `GET /shared/data-exports/{id}/download-url` → `200`. | New screen **Profile → Download my data** (`/profile/data-export`); the `dsr.export_ready` notification opens it. Verified: request `DSR-2026-0003` created from the app. The file itself cannot be fetched — §2 R-1. |

Also confirmed and already handled by the app: `PATCH /patient/documents/{id}` now **requires**
`If-Match` (`400` without it; the app always sent the row version — a note was saved from the app,
version 1 → 2); a lock on one identifier now blocks the other (no app change needed); a cancelled
unpaid booking returns its coupon (no app change needed).

## 2. Round-1 blocking gaps that are still open on staging

| # | Gap | Evidence (2026-10-01) | What the app does | Needs |
|---|---|---|---|---|
| R-1 (was 1.1) | **The storage host does not exist.** Every presigned URL the server mints points at `https://storage.fake.local/…`. | `POST /shared/files/uploads` → `201`, `upload_url: https://storage.fake.local/medibook-private/patient/…?X-Op=put&X-Expires=300`; the `PUT` fails DNS; `POST …/complete` → `400 "The object has not been uploaded yet."` The same host is returned by `GET /patient/documents/{id}/download-url`, `GET /shared/files/{id}/url`, `GET …/receipt.pdf` and `GET /shared/data-exports/{id}/download-url`. On the emulator Chrome shows "This site can't be reached — storage.fake.local". | Uploads stop after step 1 with "The file could not be sent to our storage…" and *Try again*. Downloads (document, receipt PDF, insurance file, data export) fetch the signed link and hand it to the browser, which cannot resolve it. Doctor/hospital photos fall back to initials. Nothing is faked. | A reachable object store behind staging (`PROVIDERS_MODE` real for storage, or MinIO exposed on the API host). **Blocks:** adding a medical document, insurance files, ticket attachments, every file download, receipt PDFs, the data-export file. |
| R-2 (was 1.2) | **Razorpay is still the in-process fake.** | Booking `LKSB-2610-00185` created from the app: `payment_order.key_id: ""`, `gateway_order_id: "order_fake8cbc7141d89e41"`. | The payment screen refuses to open the SDK without a key: "Online payment is not set up for this hospital yet… Nothing has been charged." The booking stays `pending_payment` and was cancelled from the app. | Razorpay test-mode keys on staging. **Blocks:** paying, `verify` with a real signature, retry-to-success, the booking-success screen after payment, a new receipt, refunds on cancel. |
| R-3 (was 1.4) | **Self-signed TLS.** | `curl` without `-k` → exit 60. | `MEDIBOOK_ALLOW_BAD_CERT` (default on outside prod; a prod build refuses to start with it). | A CA-signed certificate before any external tester build. |
| R-4 (was 1.5) | **No push token source.** | Unchanged: no Firebase SDK in `Technical_stack.md`; backend `POST /me/devices` is ready. | Device register/unregister is wired; nothing calls `register`. | Decision §5 D-1. |

## 3. New mismatches found in this round

| # | Contract (`docs-flutter/FLUTTER_API_INTEGRATION.md`) | Live server | App | Suggested owner action |
|---|---|---|---|---|
| N-1 | §15: a bad or expired token closes the socket with code **4401**. | The upgrade is refused with **HTTP 403** (the consumer rejects before accepting), so no close code is ever delivered. Verified with a bad token on `/ws/patient/inbox`. A good token connects, negotiates `bearer`, and `{"type":"ping"}` → `pong`. | `WsClient` raises `WsHandshakeRefused`; the live-queue and inbox controllers refresh the session once and reconnect, then back off. 4401 is still handled. | Document the 403, or accept-then-close with 4401. |
| N-2 | §10.1: tabs are Upcoming = `bucket=upcoming`, Completed = `status=completed`, Cancelled = `status=cancelled,no_show`. | A paid visit whose time has passed but that the desk never closed stays `scheduled`, drops out of `bucket=upcoming`, and matches **none** of the three queries. Asha's `LKSB-2609-00165` (paid, 30 Sep) was invisible in the app. | The Completed tab now asks for `bucket=past&status=completed,scheduled,checked_in,in_consultation,pending_approval` (the server accepts the combination) and shows each row's real status pill — that booking appears as *Confirmed*. | Decide what a past, never-closed visit is (auto-complete, auto no-show, or a "past" tab) and state it in §10.1. |
| N-3 | §5.7 and §18.2: "the app cannot request an export — contact support". | `POST` / `GET /patient/me/data-exports` exist. Row: `id, request_no, kind, status, requested_at, due_at, completed_at`; `download-url` also returns `request_no`. | Wired (§1). | Add the two calls to the contract. |
| N-4 | §1.9: `If-Match` on document PATCH is "optional". | Required (`400` on `If-Match`). | Always sent. | Update the table. |
| N-5 | §10 and §8.2 list no `timezone`; §10 says "the object has no hospital address or time zone". | Both carry it (§1). `GET …/availability` (§8.1) still has none. | Uses the fields; the date strip falls back to the hospital detail's zone. | Update §8.2 / §10; consider adding it to §8.1. |
| N-6 | §5.9: "Marketing consent is not here". | `GET /patient/me/consents` returns a row `document_slug: "marketing", document_version: 0`. | Ignored — only `terms`, `privacy`, `guidelines` are compared with `legal_versions`, so no false re-consent prompt. | Document the row or stop returning it. |
| N-7 | §10.8 example: `fy_code: "26-27"`. | `"FY2026-27"`. | Rendered verbatim. | Cosmetic; fix the example. |

**Contract file is stale in this repo.** `docs-flutter/FLUTTER_API_INTEGRATION.md` still has the
placeholders `<!-- SCREEN-MAP -->` (§2) and `<!-- NOT-AVAILABLE -->` (§18). The backend repo holds a
newer, filled-in copy (`Medibook-backend-django/docs/FLUTTER_API_INTEGRATION.md`, untracked there),
and neither copy yet describes N-3 … N-6. The spec folder was not overwritten; the owner should
publish one current copy.

Round-1 mismatches re-probed and unchanged (the app already matches the server): 2.2
(`kind=change` → `400`), 2.3 (`doc_type` is single-valued: a comma list is `400`, and a repeated
parameter filters on one value only), 2.4 (`sort=distance_km` needs coordinates), 2.5 (`q` ≥ 2
characters), 2.6 (departments have no icon), 2.7 (banners per hospital only), 2.8
(`support_contacts` is a phone only).

## 4. Flows that still cannot be run end to end

| Flow | What was exercised this round | What stops the rest |
|---|---|---|
| Sign-up, OTP login, forgot password, phone change, release a dependant | `POST /patient/auth/login/otp/start` from the app → verify screen ("We sent a 4-digit code to +919808675338"). | Staging never exposes an OTP (it is encrypted into the SMS outbox, and no SMS is sent in `fake` mode). Round 1 ran sign-up against a local backend; nothing changed here. Needs a dev OTP hook or a real SMS provider on staging. |
| Pay → success → receipt for a **new** booking | Book (`201`), countdown, "Retry payment", leave/resume, cancel. | R-2. |
| Add / download a document, insurance file, ticket attachment, receipt PDF | Ticket creation (`201`), the storage `PUT` attempt, every `download-url` call. | R-1. |
| A finished data export for a request made in the app | Request (`202`), list, the download link of a *seeded* completed export. | Exports are processed by the nightly run or by compliance staff — `DSR-2026-0003` is still `requested` — and the file is behind R-1. |
| A moving live queue (`session.updated`, `token.called`, "your turn") | The queue screen for `LKSB-2609-00165` (reading from `GET …/queue`, socket connected, "Live"). | Neither account has a booking in an open session: the seeded "today" bookings are now in the past and their sessions never opened. Needs a desk user to run a session while the app watches. |

## 5. Decisions still needed from the owner

| # | Decision | State after this round |
|---|---|---|
| D-1 (was 4.1) | Push provider (FCM) and its platform config. | Unchanged — R-4. |
| D-2 (was 4.2) | Storage host on staging. | Unchanged — R-1. |
| D-3 (was 4.3) | Geolocation package for "Hospitals near you". | Unchanged: the list is name-ordered under that heading. |
| D-4 (was 4.4) | Full IANA time zones (`timezone` package). | **Narrowed.** The zone now comes from the server and is honoured for the fixed-offset zones in `HospitalZones` (India, UAE, Singapore, Nepal, Sri Lanka, Bangladesh, UTC). A zone with daylight saving falls back to the device's zone. Add the package only if a hospital outside those zones is onboarded. |
| D-5 (was 4.5) | "Add to calendar". | **Closed.** `share_plus` (listed in `Technical_stack.md`; resolved at `^13.3.0`) hands the `.ics` to the OS share sheet, named by the booking reference (`LKSB-2609-00165.ics`). |
| D-6 (was 4.6) | QR package for the token card; "Save token card". | Unchanged: `qr_payload` is shown as "Desk code"; "Save token card" is the one control still marked as not available. |
| D-7 (was 4.7, 4.8) | `naming_conventions_lints` package; toolchain pins. | Unchanged. |
| D-8 (was 4.10) | Ticket attachments. | Unchanged, and blocked by R-1. |

Removed from the app this round because the backend documents say they have no endpoint and the
client removed them (backend `FLUTTER_INTEGRATION_GAPS.md` §2–§3, contract §18): the Google /
Facebook / X buttons on sign-in, and Home's "Health Checkup Package — 40 % discount" banner (an
offer no API backs).

## 6. Emulator run (emulator-5554, Android 14, debug build, live server)

| Area | What was done | Result |
|---|---|---|
| First run | Intro → consent (legal documents loaded from the server) → sign-in | ✅ |
| Sign-in | Phone + password (Sanjay); email + password (Asha); OTP send (Priya); session restore after reinstall and after an offline cold start; logout | ✅ |
| Home | Greeting, unread badge (40 / 33 — per account), hospital banners, departments, hospitals, token card after booking and its removal after cancel | ✅ |
| Booking | Cardiology → Lakeshore → Dr. Harish Menon → Mon 5 Oct 6:40 PM → *for myself* → fee quote ₹900 + ₹20 + ₹4 → invalid coupon verdict → Pay → `LKSB-2610-00185`, token `A001`, countdown | ✅ up to payment; payment ❌ R-2 |
| Booking back-out | Back from payment: button reads "Complete payment", the leave dialog names the held booking | ✅ |
| Appointments | Upcoming / Completed / Cancelled tabs, detail (times in the hospital's zone), history, cancellation preview, cancel (`cancelled`, `patient_request` on the server) | ✅ |
| Receipt | Lines, tax, payment line, hospital and platform GST blocks; "Add to calendar" → share sheet with `LKSB-2609-00165.ics`; "Download PDF" → browser | ✅; PDF ❌ R-1 |
| Review | Five stars + comment on `LKSB-2609-00095` | ✅ |
| Live queue | Queue reading and "Live" socket state | ✅ static; moving queue not observable (§4) |
| Records | List, detail, edit a note (`If-Match`), plain date picker with year stepping; upload attempt | ✅; upload ❌ R-1 |
| Notifications | List, filters, tap → support ticket thread, read state, badge | ✅ |
| Support | Ticket thread, reply posted (`TKT-2026-0015`) | ✅ |
| Profile | Details, family (self + dependants), edit (`PATCH /me`, blood group), alternate number, signed-in devices + revoke one, insurance list | ✅ |
| Data export | Request (`DSR-2026-0003`), list, Download on a completed export | ✅ request/list; file ❌ R-1 |
| Delete account | Request → cooling-off card → Reactivate | ✅ |
| Ambulance | Provider list, "Call now" → dialler with the number filled in | ✅ |
| Search | "menon" → doctor → doctor detail with the slot grid | ✅ |
| Account switch | Sanjay → logout → Asha: no data of the first account shown | ✅ |
| Offline | Airplane mode + cold start: session kept, cached lists with the offline banner; back online: lists, badge and `/me` refresh | ✅ |

`flutter analyze`: no issues. `flutter test`: 355 passing, 4 opt-in skips.

Bugs found by this run and fixed in the same change set are listed in `CHANGELOG.md` (a paid past
visit missing from every tab, the unread badge and `/me` not refreshing after an offline start,
sheets hidden behind the keyboard, truncated button labels, the calendar file never reaching a
calendar app, and others).

## 7. Rows left on the seeded accounts

State changed by the run was put back where the API allows (Sanjay's blood group and document
note cleared; Asha's alternate number removed; probe sessions ended). What remains:

| Account | Row | Why it remains |
|---|---|---|
| Sanjay Varma | Cancelled appointment `LKSB-2610-00185` (Dr. Harish Menon, 5 Oct 18:40, never paid) | cancelled appointments cannot be deleted |
| Sanjay Varma | Review on `LKSB-2609-00095` (5★, moderation `pending`) | no delete endpoint |
| Sanjay Varma | Reply "Thanks, the code arrives quickly now." on `TKT-2026-0015` | no delete endpoint |
| Sanjay Varma | Export request `DSR-2026-0003` (`requested`) | no withdraw endpoint for exports |
| Sanjay Varma | `user.version` 3; document "Blood test — CBC" at version 3 | edits bump the version |
| Asha Rao | Deletion request `DSR-2026-0004` (`withdrawn`) | history row |
| Asha Rao | `user.version` 5; two `pending` upload tickets (never completed, expire on their own) | — |
| Priya Nair | One login OTP challenge sent, never verified | expires in 180 s |
