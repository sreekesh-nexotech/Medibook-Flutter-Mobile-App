# Medibook patient API — Flutter integration reference

**Date:** 2026-09-30 · **Backend:** this repo at `45cef46` · **App:** `Medibook-Flutter-Mobile-App-1` at `009dcbe`

Every endpoint the patient mobile app needs, with the request it takes and the exact JSON it
returns. Companion to `docs/FLUTTER_INTEGRATION_GAPS.md` (what the app must change); this file is
the contract to code against.

**How this was produced.** Paths and request bodies come from the live URL table and `schema.yml`
(regenerated and found identical to the committed file). Response bodies were read from the
views, serializers and services, because `schema.yml` is not precise enough for them:

- 64 patient/shared responses are typed there as a free-form object;
- list endpoints are shown there as bare arrays, but every list is actually wrapped in the page
  envelope of §1.6;
- `hospital`, `department` and `doctor` on an appointment are shown as strings but are objects.

So where this file and a Dart client generated from `schema.yml` disagree on a **response**, this
file is right. No backend code was changed to write it.

---

## Contents

1. [Conventions](#1-conventions) — base URL, headers, auth, errors, paging, concurrency
2. [Screen → endpoint map](#2-screen--endpoint-map)
3. [App start and content](#3-app-start-and-content)
4. [Authentication](#4-authentication)
5. [Account and profile](#5-account-and-profile)
6. [Family members, addresses, emergency contacts, insurance](#6-family-members-addresses-emergency-contacts-insurance)
7. [Discovery](#7-discovery) — locations, hospitals, departments, doctors, search
8. [Availability, slots and fee quote](#8-availability-slots-and-fee-quote)
9. [Booking and payment](#9-booking-and-payment)
10. [Appointments](#10-appointments) — list, detail, token, queue, cancel, receipt, review
11. [Medical documents and file upload](#11-medical-documents-and-file-upload)
12. [Notifications and push devices](#12-notifications-and-push-devices)
13. [Support tickets](#13-support-tickets)
14. [Ambulance](#14-ambulance)
15. [WebSockets](#15-websockets)
16. [Error codes](#16-error-codes)
17. [Enums](#17-enums)
18. [Not available in the backend](#18-not-available-in-the-backend)

---

## 1. Conventions

### 1.1 Base URL

| | URL |
|---|---|
| Patient API | `https://<host>/api/v1/patient/…` |
| Shared API (files, app config, health) | `https://<host>/api/v1/shared/…` |
| WebSockets | `wss://<host>/ws/patient/…` |
| Local dev | HTTP `http://localhost:8000` (`make run`), WebSockets `ws://localhost:8001` (`make ws`) |
| Swagger UI | `/api/docs/` (schema at `/api/schema/`) |

All paths below are relative to `/api/v1`. There is **no trailing slash** on any path.

The app's `lib/core/network/endpoints.dart` paths do not match; they need the `/patient` or
`/shared` prefix and, in most cases, a different path (see §2).

### 1.2 Request format

- Bodies are JSON only (`Content-Type: application/json`). There is no multipart endpoint; files
  go straight to storage through a presigned URL (§11.1).
- Success bodies are returned **bare** — there is no `{data: …}` wrapper. Only errors have an
  envelope (§1.5).
- Field names are `snake_case`.

### 1.3 Headers

| Header | When | Notes |
|---|---|---|
| `Authorization: Bearer <access>` | every endpoint not marked *public* | see §1.4 |
| `X-Device-Fingerprint: <id>` | **every OTP call** (start, resend, verify) | A stable per-install id, ≤ 256 chars. The code is bound to it: the verify call must send the same value as the start call. May be sent in the body as `device_fingerprint` instead. Missing → `400 VALIDATION_ERROR` on `device_fingerprint`. |
| `Idempotency-Key: <uuid>` | the six calls listed in §1.8 | 1–128 chars |
| `If-Match: "<version>"` | PATCH (and optionally DELETE) on editable rows | see §1.9 |
| `If-None-Match: <etag>` | optional on any GET | `304` when unchanged (§1.10) |
| `X-Request-Id: <id>` | optional | 8–64 chars `[A-Za-z0-9-]`; generated when absent; always echoed on the response and in error bodies |

### 1.4 Authentication and token lifecycle

- Login and signup return `access` (JWT, 15 minutes) and `refresh`.
- A patient session lasts at most **30 days**, and ends after **7 days** without use.
- **Refresh tokens rotate.** Every `POST /patient/auth/token/refresh` returns a new `refresh`;
  store it and discard the old one. Presenting an old refresh token revokes the whole session
  (`401 AUTH_SESSION_REVOKED`). The app must therefore make refresh **single-flight**: if several
  requests get a 401 at once, only one refresh call may go out and the others wait for it.
- Store both tokens in secure storage.

What to do on a 401 / 403, by `code`:

| `code` | Action |
|---|---|
| `AUTH_TOKEN_EXPIRED` | refresh, then retry the request once |
| `AUTH_SESSION_REVOKED`, `AUTH_TOKEN_INVALID`, `AUTH_PRINCIPAL_MISMATCH` | clear tokens, go to sign-in |
| `ACCOUNT_BLOCKED` (403) | clear tokens, show "account blocked" |
| `AUTH_INVALID_CREDENTIALS`, `AUTH_OTP_INVALID`, `AUTH_OTP_EXPIRED` | **not** a session problem — a wrong password or code; show it on the form. `POST /patient/me/password` also answers a wrong current password with `401 AUTH_INVALID_CREDENTIALS`, so the HTTP client must branch on `code`, not on the status alone. |

**Public endpoints** (no token needed): everything in §3, all of §4 except logout and sessions,
and all of §7, §8.1, §8.2 and §14. If an `Authorization` header is sent to a public discovery
endpoint it is still validated, so an expired token there gets a 401 — refresh or drop the header.

### 1.5 Error envelope

Every non-2xx response has this body:

```jsonc
{
  "code": "VALIDATION_ERROR",          // stable, machine-readable — branch on this
  "message": "Some fields are invalid.", // human text, may change
  "errors": {                          // field errors; {} when none
    "pincode": ["This value does not match the required pattern."],
    "address": { "city": ["This field is required."] },   // nested objects nest
    "non_field_errors": ["…"]
  },
  "request_id": "0f3c…",
  "meta": {}                           // code-specific extras, e.g. attempts_remaining
}
```

`meta` values the app should use:

| `code` | `meta` |
|---|---|
| `AUTH_INVALID_CREDENTIALS` | `attempts_remaining` |
| `AUTH_OTP_INVALID` | `attempts_remaining` |
| `AUTH_LOCKED_OUT` (423) | `locked_until` (ISO time), `attempts_remaining: 0` |
| `RATE_LIMITED` (429) | `retry_after_seconds` (also the `Retry-After` header) |
| `CONFLICT_VERSION` | `current` (the row's current version) |
| `COUPON_MIN_ORDER` | `min_order_paise` |
| `FILE_TOO_LARGE` | `max_bytes` |
| `FILE_TYPE_NOT_ALLOWED` | `allowed` (list of MIME types) |
| `FILE_IN_USE` | `referenced_by` |

The full list of codes is in §16.

### 1.6 Pagination

Every list endpoint returns this envelope (written `Page<T>` below):

```jsonc
{
  "results": [ /* T */ ],
  "page": 1,
  "page_size": 25,
  "total": 132,
  "has_next": true
}
```

Query: `page` (from 1) and `page_size` (default 25, maximum 100). The app's `per_page` must
become `page_size`.

The two exceptions, which return a plain object: `GET /patient/faqs` and `GET /patient/search`.

### 1.7 Filters and sorting

- Each list accepts only the query parameters listed for it. **Any other parameter is a
  `400 VALIDATION_ERROR`** ("Unknown query parameter.") — do not send empty or speculative ones.
- Sort with `sort=<field>` or `sort=-<field>` (descending); several fields comma-separated. Only
  the listed fields are sortable.
- Multi-value filters (marked *multi*) accept `status=a,b`, `status=a&status=b` or `status[]=a`.
- Booleans are `true` / `false`. Dates are `YYYY-MM-DD`.

### 1.8 Idempotency

`Idempotency-Key` is **required** on:

| Call | |
|---|---|
| `POST /patient/appointments` | booking |
| `POST /patient/appointments/{id}/cancel` | |
| `POST /patient/payments/orders/{id}/verify` | |
| `POST /patient/payments/orders/{id}/retry` | |
| `POST /patient/me/deletion-requests` | |
| `POST /patient/me/persons/{id}/release` | |

Generate one UUID per user action and **reuse it when retrying that same action** (timeout,
lost connection). Behaviour:

- same key + same request → the original response is replayed, with header
  `Idempotent-Replayed: true`;
- same key + a different path or body → `409 IDEMPOTENCY_CONFLICT`;
- only successful responses are remembered, so after an error the same key may be retried;
- keys are remembered for 24 hours;
- missing header → `400 VALIDATION_ERROR` on `Idempotency-Key`.

The match is on the raw body bytes, so a retry must send the identical JSON.

### 1.9 Optimistic concurrency (`version` / `If-Match`)

Editable rows carry an integer `version`. Send it back as `If-Match: "<version>"` when editing;
the response carries the new version.

| Resource | PATCH | DELETE |
|---|---|---|
| `/patient/me` (uses `user.version`) | required | — |
| `/patient/me/persons/{id}` | required | not used |
| `/patient/me/addresses/{id}` | required | optional |
| `/patient/me/emergency-contacts/{id}` | required | optional |
| `/patient/me/insurance-policies/{id}` | required | not used |
| `/patient/documents/{id}` | optional | optional |
| `/shared/files/{id}` | — | optional |

Missing where required → `400 VALIDATION_ERROR` on `If-Match`. Stale →
`409 CONFLICT_VERSION` with `meta.current`; reload the row and let the user retry.

### 1.10 Caching (ETag)

Every `200` GET carries an `ETag`. Send it back in `If-None-Match` and an unchanged resource
answers `304` with no body — this is what the app's offline cache should key on. Discovery
endpoints (§7, §8.1, §8.2) also send `Cache-Control: public, max-age=60`; slot and availability
data is cached server-side for up to 30 seconds, so **always be ready for `409 SLOT_UNAVAILABLE`
at booking** even when a slot was shown as available.

### 1.11 Data formats

| Kind | Format |
|---|---|
| Ids | UUID strings. They are API handles only — **never show one to the user**. Show `booking_ref`, `token_label`, `receipt_no`, `ticket_no`, `request_no`. Each hospital sets its own number formats, so treat these as opaque text (the values in the examples below are illustrative). |
| Money | integer **paise** in fields ending `_paise` (₹500 = `50000`). Rates ending `_bp` are basis points (`1800` = 18 %, `10000` = 100 %). Never floats. |
| Date-time | ISO-8601 in **UTC**, e.g. `2026-10-02T04:30:00Z` or `2026-10-02T04:30:00+00:00`, sometimes with fractional seconds. `DateTime.parse` handles all of these. |
| Date | `YYYY-MM-DD`. `scheduled_date`, slot `date` and availability dates are in the **hospital's** time zone. |
| Time zone for display | Show appointment and slot times in the hospital's zone (`timezone` on hospital detail; `Asia/Kolkata` by default), not the device's. |
| Phone | E.164 with `+`. Sign-up, OTP login and phone change require an Indian mobile: `^\+91[6-9]\d{9}$`. Spaces, dashes and brackets are stripped. |
| Ratings | decimal **strings** (`"4.6"`) or `null`. |
| Coordinates | decimal **strings** (`"9.9816"`) or `null`. |
| Images | `*_file_id` fields are file ids, not URLs. Resolve with `GET /shared/files/{id}/url` (§11.4). |

### 1.12 Rate limits

| Scope | Limit |
|---|---|
| Signed-in patient | 120 requests / minute |
| Anonymous | 60 / minute per IP |
| Auth endpoints | 10 / minute per IP and 5 / minute per identifier |
| OTP sends | 3 per 10 minutes per number |
| OTP resends | 3 per challenge, at least 30 s apart |

Over the limit → `429 RATE_LIMITED` with `Retry-After` and `meta.retry_after_seconds`.

---

## 2. Screen → endpoint map

<!-- SCREEN-MAP -->

---

## 3. App start and content

All public.

### 3.1 `GET /shared/app-config`

Read once at launch (before login).

```jsonc
{
  "min_versions": { "android": "1.0.0", "ios": "1.0.0" },  // each may be null
  "feature_flags_public": { "some_flag": true },            // key → bool
  "otp_length": 4,                                          // build the OTP boxes from this
  "support_contacts": { "phone_e164": "+914842000000" },    // {} when not configured
  "legal_versions": { "terms": 3, "privacy": 2, "guidelines": 1 }
}
```

Compare `legal_versions` with what the user accepted (§5.9) to decide whether to ask for
re-consent.

### 3.2 `GET /patient/legal/{slug}`

`slug` ∈ `terms` | `privacy` | `guidelines`. `404 NOT_FOUND` when nothing is published.

```jsonc
{
  "slug": "terms",
  "version": 3,
  "title": "Terms of Use",
  "body_md": "# Terms\n…",          // Markdown
  "published_at": "2026-08-01T00:00:00+00:00"   // or null
}
```

### 3.3 `GET /patient/faqs`

Not paginated. Accepts no query parameters.

```jsonc
{
  "categories": [
    {
      "category": "Booking",
      "entries": [
        { "id": "uuid", "question": "How do I cancel?", "answer_md": "…", "sort_order": 1 }
      ]
    }
  ]
}
```

### 3.4 `GET /shared/health`

`{ "status": "ok" }` — connectivity check. (`GET /shared/ready` adds
`"checks": {"db": "ok", "cache": "ok"}` and answers `503 PROVIDER_UNAVAILABLE` when down.)

---

## 4. Authentication

All public except logout and sessions. Send `X-Device-Fingerprint` on every OTP call.

### Shared shapes

**`Challenge`** — returned by every "start" and "resend" call:

```jsonc
{
  "challenge_id": "uuid",
  "code_length": 4,
  "expires_at": "2026-09-30T10:03:00+00:00",   // 180 s after sending
  "resend_after_seconds": 30,
  "destination_masked": "+91******10"          // null when it must not be revealed
}
```

**`User`**:

```jsonc
{
  "id": "uuid",
  "first_name": "Anita",
  "last_name": "Nair",                 // nullable
  "phone_e164": "+919876543210",       // nullable
  "phone_verified_at": "2026-09-30T10:01:12Z",   // nullable
  "alternate_phone_e164": null,
  "email": "anita@example.com",        // nullable
  "email_verified_at": null,
  "has_password": true,                // false = OTP-only account
  "status": "active",                  // active | blocked | deleted | pending_deletion
  "deletion_requested_at": null,
  "locale": "en-IN",
  "timezone": "Asia/Kolkata",
  "last_login_at": "2026-09-30T10:01:12Z",       // nullable
  "version": 1
}
```

**`Tokens`**:

```jsonc
{
  "access": "<jwt>",
  "refresh": "<jwt>",
  "access_expires_in": 900,            // seconds
  "session_id": "uuid",
  "user": { /* User */ }               // present on login and signup; absent on refresh
}
```

**OTP verify errors** (the same for every verify call):

| Status | `code` | Meaning |
|---|---|---|
| 401 | `AUTH_OTP_INVALID` | wrong code (or wrong device); `meta.attempts_remaining` |
| 401 | `AUTH_OTP_EXPIRED` | older than 180 s — resend |
| 422 | `OTP_ATTEMPTS_EXCEEDED` | 3 wrong tries on this code — resend |
| 423 | `AUTH_LOCKED_OUT` | 5 failed logins → locked for 1 hour; `meta.locked_until` |
| 429 | `RATE_LIMITED` | `meta.retry_after_seconds` |

### 4.1 `POST /patient/auth/signup/start`

Validates the form and sends the OTP. No account exists until 4.2 succeeds.

```jsonc
{
  "first_name": "Anita",               // required, ≤ 100
  "last_name": "Nair",                 // optional
  "phone_e164": "+919876543210",       // required, Indian mobile
  "date_of_birth": "1994-05-17",       // required; under 18 → 409 UNDER_AGE
  "email": "anita@example.com",        // optional
  "password": "at-least-10-chars",     // optional (see password rules below)
  "alternate_phone_e164": null,        // optional
  "address": {                         // optional; becomes the default address
    "label": "Home",                   // optional, ≤ 40
    "address_line1": "12 MG Road",     // required
    "address_line2": null,
    "address_line3": null,
    "city": "Kochi",                   // required
    "state": "Kerala",                 // required
    "pincode": "682001",               // required, 6 digits
    "phone_e164": null
  },
  "consents": {                        // required; the first three must be true
    "terms": true, "privacy": true, "guidelines": true,
    "marketing": false                 // optional
  }
}
```

**200** → `Challenge`.

Errors: `400 VALIDATION_ERROR` (`errors.phone_e164` "already registered", `errors.email`,
`errors.password`, `errors.consents`, `errors.device_fingerprint`), `409 UNDER_AGE`, `429`.

**Password rules** (everywhere a password is set): at least **10** characters; must not contain
the user's name, email or phone number; may be rejected if it appears in a known breach list.

### 4.2 `POST /patient/auth/signup/verify`

```json
{ "challenge_id": "uuid", "code": "1234" }
```

**201** → `Tokens` plus two extra keys:

```jsonc
{
  "access": "…", "refresh": "…", "access_expires_in": 900, "session_id": "uuid",
  "user": { /* User */ },
  "profile": { /* Profile, §5.1 */ },
  "person_self": {
    "id": "uuid", "is_self": true, "first_name": "Anita", "last_name": "Nair",
    "relation": "self", "date_of_birth": "1994-05-17",
    "phone_e164": "+919876543210", "version": 1
  }
}
```

Keep `person_self.id` — it is the `person_id` for booking "for myself".

### 4.3 `POST /patient/auth/login/otp/start`

```json
{ "phone_e164": "+919876543210" }
```

**200** → `Challenge`. An unregistered number gets the same response and no SMS (so the app
cannot tell the two apart here; the verify then fails with `AUTH_OTP_INVALID`).

### 4.4 `POST /patient/auth/login/otp/verify`

```jsonc
{ "challenge_id": "uuid", "code": "1234", "device_id": null }   // device_id: optional, from §12.6
```

**200** → `Tokens` (with `user`). Logging in during the account-deletion cooling-off
reactivates the account. Errors: the OTP table above, plus `403 ACCOUNT_BLOCKED`.

### 4.5 `POST /patient/auth/login/password`

```jsonc
{ "identifier": "+919876543210", "password": "…", "device_id": null }
```

`identifier` is the phone in E.164 (**with** `+91`) or the email. **200** → `Tokens`.

Errors: `401 AUTH_INVALID_CREDENTIALS` (`meta.attempts_remaining`; also what an OTP-only account
gets), `423 AUTH_LOCKED_OUT` (`meta.locked_until`), `403 ACCOUNT_BLOCKED`, `429`.

### 4.6 `POST /patient/auth/otp/resend`

Works for any open challenge (signup, login, password reset, phone change, release).

```json
{ "challenge_id": "uuid" }
```

**200** → `Challenge` (same `challenge_id`, new `expires_at`, attempts reset).
Errors: `429 RATE_LIMITED` (sooner than 30 s, or more than 3 resends),
`401 AUTH_OTP_INVALID` (unknown or already used challenge, or a different device).

### 4.7 Forgot password (three calls)

Patients reset by **SMS only**.

1. `POST /patient/auth/password/forgot/start`

   ```jsonc
   { "identifier": "+919876543210" }     // phone or email; optional "channel": "sms"
   ```

   **200** → `Challenge` (`destination_masked` is `null` when the identifier was an email).
   Same response for an unknown account.

2. `POST /patient/auth/password/forgot/verify`

   ```json
   { "challenge_id": "uuid", "code": "1234" }
   ```

   **200** → `{ "reset_token": "…", "expires_at": "2026-09-30T10:18:00+00:00" }` (15 minutes).

3. `POST /patient/auth/password/reset`

   ```json
   { "reset_token": "…", "new_password": "at-least-10-chars" }
   ```

   **204**, no body. Every session is revoked — send the user to sign-in.
   Errors: `401 AUTH_TOKEN_INVALID` (token used or expired), `400 VALIDATION_ERROR` on
   `new_password`.

### 4.8 `POST /patient/auth/token/refresh`

```json
{ "refresh": "<jwt>" }
```

**200** → `Tokens` **without** `user`. Store the new `refresh`. See §1.4 for single-flight.
Errors: `401 AUTH_SESSION_REVOKED` (expired, idle, revoked, or an old token reused),
`401 AUTH_TOKEN_INVALID`, `403 ACCOUNT_BLOCKED`, `429` (5 / minute).

### 4.9 Logout and sessions (token required)

| Call | Result |
|---|---|
| `POST /patient/auth/logout` | **204**; ends this session |
| `POST /patient/auth/logout-all` | **204**; ends every session of the user |
| `GET /patient/auth/sessions` | `Page<Session>`; sort: `last_seen_at`, `created_at` |
| `DELETE /patient/auth/sessions/{session_id}` | **204**; `404` if not one of the user's live sessions |

```jsonc
// Session
{
  "id": "uuid", "principal": "patient", "device_id": null,
  "user_agent": "Medibook/1.0 (Android 14)", "ip": "203.0.113.7",
  "created_at": "…", "last_seen_at": "…", "absolute_expires_at": "…",
  "current": true                      // this is the calling session
}
```

Unregister the push token (§12.6) before logging out.

---

## 5. Account and profile

Token required for everything from here on unless marked public.

### 5.1 `GET /patient/me`

```jsonc
{
  "user": { /* User, §4 */ },
  "profile": {                         // null only for an account with no profile row yet
    "date_of_birth": "1994-05-17",     // nullable
    "gender": "female",                // female | male | other | undisclosed | null
    "blood_group": "O+",               // A+ A- B+ B- AB+ AB- O+ O- | null
    "allergies": ["Penicillin"],       // list of strings, may be empty
    "avatar_file_id": null,            // read-only (see §18)
    "marketing_opt_in": false,
    "version": 1
  }
}
```

### 5.2 `PATCH /patient/me`

`If-Match: "<user.version>"` required. Send only the fields being changed.

```jsonc
{
  "first_name": "Anita", "last_name": "Nair",
  "locale": "en-IN", "timezone": "Asia/Kolkata",
  "date_of_birth": "1994-05-17",       // under 18 → 409 UNDER_AGE
  "gender": "female", "blood_group": "O+",
  "allergies": ["Penicillin"],         // ≤ 50 items, each ≤ 100 chars; replaces the list
  "marketing_opt_in": true
}
```

**200** → same shape as 5.1. Phone and email cannot be changed here. The "self" person (§6.1)
is kept in step automatically.

### 5.3 Change mobile number (three calls)

OTP to the **current** number first, then to the new one; both within 10 minutes.

1. `POST /patient/me/phone/change/start` `{ "new_phone_e164": "+919812345678" }`
   → **200** `Challenge` (sent to the **old** number).
   Errors: `400` on `new_phone_e164` ("already your number", "belongs to another account").
2. `POST /patient/me/phone/change/confirm-old` `{ "challenge_id": "uuid", "code": "1234" }`
   → **200** `Challenge` (sent to the **new** number). `challenge_id` may be omitted here — the
   latest open one is used.
3. `POST /patient/me/phone/change/verify-new` `{ "challenge_id": "uuid", "code": "5678" }`
   → **200** `User` with the new `phone_e164`.

Errors on 2 and 3: the OTP table in §4; `401 AUTH_OTP_EXPIRED` with the message "Both codes must
be confirmed within 10 minutes. Start again."

### 5.4 Alternate phone

A contact number only — never a login.

| Call | Body | Result |
|---|---|---|
| `POST /patient/me/alternate-phone` | `{ "phone_e164": "+91…" }` | **200** `User` |
| `DELETE /patient/me/alternate-phone` | — | **200** `User` |

### 5.5 `POST /patient/me/password`

Sets a password (OTP-only account) or changes it.

```jsonc
{ "current_password": "…", "new_password": "at-least-10-chars" }  // current_password omitted when has_password = false
```

**204**. Every *other* session is signed out; the current one stays.
Errors: `401 AUTH_INVALID_CREDENTIALS` with `errors.current_password` (wrong current password —
do not treat as a session expiry), `400 VALIDATION_ERROR` on `new_password`.

### 5.6 Delete account

| Call | Result |
|---|---|
| `POST /patient/me/deletion-requests` — `Idempotency-Key` required; body `{ "reason": "…" }` optional (≤ 1000) | **202** `DeletionRequest`; account becomes `pending_deletion`; all other sessions end |
| `GET /patient/me/deletion-requests` | `Page<DeletionRequest>`; sort: `requested_at` |
| `GET /patient/me/deletion-requests/{request_no}` | **200** `DeletionRequest` |
| `DELETE /patient/me/deletion-requests/{request_no}` | **200** `DeletionRequest` (withdrawn) |
| `POST /patient/me/reactivate` (no body) | **200** `User`, status back to `active` |

```jsonc
// DeletionRequest
{
  "request_no": "DSR-2026-000012",     // show this to the user
  "kind": "deletion",
  "status": "cooling_off",             // requested | cooling_off | verifying | processing | completed | rejected | no_data | withdrawn
  "requested_at": "2026-09-30T10:00:00Z",
  "cooling_off_ends_at": "2026-10-30T10:00:00Z",   // 30 days
  "completed_at": null
}
```

`409 STATE_CONFLICT` when a request is already open, or when there is nothing to withdraw /
reactivate. Signing in again during the 30 days also reactivates the account.

### 5.7 Personal data export

`GET /shared/data-exports/{dsr_id}/download-url` →

```jsonc
{ "url": "https://…", "expires_at": "…", "file_expires_at": "…" }   // url valid 10 minutes
```

The id arrives in the `dsr.export_ready` notification (`data.dsr_id`, §12.1). The app cannot
*request* an export (§18).

### 5.8 Release a family member to their own account

For a dependant who is now 18+.

1. `POST /patient/me/persons/{person_id}/release` — `Idempotency-Key` required —
   `{ "phone_e164": "+91…" }` (the dependant's own mobile) → **200** `Challenge`.
   Errors: `409 UNDER_AGE`, `409 PERSON_IS_SELF`, `409 STATE_CONFLICT`, `400` on `phone_e164`.
2. `POST /patient/me/persons/{person_id}/release/verify` —
   `{ "challenge_id": "uuid", "code": "1234" }` → **200**

   ```jsonc
   {
     "person_id": "uuid", "user_id": "uuid",
     "moved": { "appointments": 4, "payment_orders": 4, "payments": 4, "refunds": 0,
                "receipts": 4, "hospital_patients": 1 }
   }
   ```

   `moved` counts the records that went with the person. The person and their appointment history
   disappear from the guardian's account.

### 5.9 Consents

| Call | Result |
|---|---|
| `GET /patient/me/consents` — filter `document_slug`; sort `accepted_at` | `Page<Consent>` |
| `POST /patient/me/consents` `{ "document_slug": "terms", "document_version": 3 }` | **201** `Consent` (or **200** if already accepted) |

```json
{ "id": "uuid", "document_slug": "terms", "document_version": 3, "accepted_at": "2026-09-30T10:00:00+00:00" }
```

Only the current published version can be accepted (`400` on `document_version` otherwise).
Marketing consent is not here — it is `marketing_opt_in` on `PATCH /patient/me`.

---

## 6. Family members, addresses, emergency contacts, insurance

### 6.1 Persons (the app's "dependants")

The account holder is a person too (`is_self: true`, `relation: "self"`). Every booking names a
`person_id`.

| Call | Notes |
|---|---|
| `GET /patient/me/persons` | `Page<Person>`; "self" first. Sort: `created_at`, `first_name` |
| `POST /patient/me/persons` | **201** `Person` |
| `GET /patient/me/persons/{id}` | **200** `Person` |
| `PATCH /patient/me/persons/{id}` | `If-Match` required → **200** `Person` |
| `DELETE /patient/me/persons/{id}` | **204**. `409 PERSON_IS_SELF`; `409 PERSON_HAS_APPOINTMENTS` (upcoming bookings) |

Request (POST: `first_name` and `relation` required; PATCH: any subset):

```jsonc
{
  "first_name": "Arjun",               // ≤ 100
  "last_name": "Nair",                 // optional
  "relation": "child",                 // spouse | child | parent | sibling | other  ("self" is refused)
  "date_of_birth": "2015-03-02",       // optional; not in the future; no minimum age
  "gender": "male",                    // optional
  "blood_group": "B+",                 // optional
  "allergies": ["Peanuts"],            // optional
  "phone_e164": null,                  // optional
  "guardian_note": null                // optional, ≤ 1000
}
```

```jsonc
// Person
{
  "id": "uuid", "is_self": false,
  "first_name": "Arjun", "last_name": "Nair",
  "relation": "child",
  "date_of_birth": "2015-03-02",       // nullable
  "gender": "male",                    // nullable
  "blood_group": "B+",                 // nullable
  "allergies": ["Peanuts"],
  "phone_e164": null,
  "guardian_note": null,
  "version": 1,
  "created_at": "…", "updated_at": "…"
}
```

### 6.2 Addresses

| Call | Notes |
|---|---|
| `GET /patient/me/addresses` | `Page<Address>`; default first. Sort: `created_at`, `label` |
| `POST /patient/me/addresses` | **201** `Address`. The first address becomes the default automatically. |
| `GET /patient/me/addresses/{id}` | **200** `Address` |
| `PATCH /patient/me/addresses/{id}` | `If-Match` required → **200**. **`is_default` is ignored here** — use the call below. |
| `POST /patient/me/addresses/{id}/default` | no body → **200** `Address` (now the only default) |
| `DELETE /patient/me/addresses/{id}` | **204** |

```jsonc
// request
{
  "label": "Home",                     // required, ≤ 50
  "address_line1": "12 MG Road",       // required, ≤ 200
  "address_line2": null, "address_line3": null,
  "city": "Kochi", "state": "Kerala",  // required
  "pincode": "682001",                 // required, ^[1-9][0-9]{5}$
  "phone_e164": null,
  "is_default": false                  // POST only
}
// Address
{
  "id": "uuid", "label": "Home",
  "address_line1": "12 MG Road", "address_line2": null, "address_line3": null,
  "city": "Kochi", "state": "Kerala", "pincode": "682001",
  "phone_e164": null, "is_default": true,
  "created_at": "…", "version": 1
}
```

There is no single free-text address field; the app's address form must use these columns.

### 6.3 Emergency contacts

Same pattern as addresses.

| Call | Notes |
|---|---|
| `GET /patient/me/emergency-contacts` | `Page<Contact>`; primary first. Sort: `created_at`, `name` |
| `POST /patient/me/emergency-contacts` | **201**. The first contact becomes primary automatically. |
| `GET` / `PATCH` / `DELETE /patient/me/emergency-contacts/{id}` | PATCH needs `If-Match`; `is_primary` is ignored on PATCH |
| `POST /patient/me/emergency-contacts/{id}/primary` | no body → **200** `Contact` |

```jsonc
// request
{ "name": "Ravi Nair", "relation": "Husband", "phone_e164": "+919800000000", "is_primary": false }
//          ≤ 100             free text ≤ 50          required
// Contact
{ "id": "uuid", "name": "Ravi Nair", "relation": "Husband", "phone_e164": "+919800000000",
  "is_primary": true, "created_at": "…", "version": 1 }
```

### 6.4 Insurance policies

Private to the patient; hospitals never see them.

| Call | Notes |
|---|---|
| `GET /patient/me/insurance-policies` | `Page<Policy>` **without** `documents`. Filter: `person_id`. Sort: `valid_to`, `created_at` |
| `POST /patient/me/insurance-policies` | **201** `Policy` with `documents` |
| `GET /patient/me/insurance-policies/{id}` | **200** `Policy` with `documents` |
| `PATCH /patient/me/insurance-policies/{id}` | `If-Match` required → **200** |
| `DELETE /patient/me/insurance-policies/{id}` | **204** |
| `POST /patient/me/insurance-policies/{id}/documents` `{ "file_id": "uuid" }` | **201** `Policy` with `documents`. The file must be the patient's own upload with purpose `insurance` (§11.1). |
| `DELETE /patient/me/insurance-policies/{id}/documents/{file_id}` | **204** (the file itself is kept) |

```jsonc
// request
{
  "person_id": null,                   // optional; one of the user's persons
  "provider_name": "Star Health",      // required, ≤ 200
  "policy_number": "P/123456/01",      // required, ≤ 100
  "holder_name": "Anita Nair",         // required, ≤ 200
  "plan_name": "Family Optima",        // optional
  "sum_insured_paise": 50000000,       // optional, ≥ 0   (₹5,00,000)
  "valid_from": "2026-04-01",          // required
  "valid_to": "2027-03-31",            // required, ≥ valid_from
  "tpa_name": null, "notes": null      // optional
}
// Policy
{
  "id": "uuid", "person_id": null,
  "provider_name": "Star Health", "policy_number": "P/123456/01", "holder_name": "Anita Nair",
  "plan_name": "Family Optima", "sum_insured_paise": 50000000,
  "valid_from": "2026-04-01", "valid_to": "2027-03-31",
  "tpa_name": null, "notes": null,
  "version": 1, "created_at": "…",
  "documents": [                       // detail / create / update only
    { "file_id": "uuid", "original_name": "policy.pdf", "mime": "application/pdf",
      "size_bytes": 182044, "status": "clean", "attached_at": "…" }
  ]
}
```

To view an attached file: `GET /shared/files/{file_id}/url` (§11.4). "Active / expired" is not a
field — derive it from `valid_to`.

---

## 7. Discovery

All public; cached for 60 s. Only hospitals that are live, visible and accepting patients appear.

### 7.1 `GET /patient/locations`

Filters: `city`, `popular` (bool). Sort: `city`, `area`. → `Page<Location>`

```json
{ "id": "uuid", "city": "Kochi", "area": "Edappally", "state": "Kerala",
  "lat": "10.0261", "lng": "76.3125", "is_popular": true }
```

`lat` / `lng` are strings or `null`.

### 7.2 `GET /patient/hospitals`

Filters: `city`, `area`, `department_code`, `q` (name search), `lat` + `lng` (together),
`radius_km` (needs `lat`/`lng`, 0–500).
Sort: `name` (default), `rating_avg`, `distance_km` (needs `lat`/`lng`), `next_available_at`.
With `lat`/`lng` and no `sort`, nearest first. → `Page<HospitalCard>`

```jsonc
// HospitalCard
{
  "id": "uuid", "slug": "city-care-kochi", "name": "City Care Hospital",
  "city": "Kochi", "area": "Edappally",          // area nullable
  "rating": "4.5",                               // string or null
  "rating_count": 212,
  "distance_km": 3.42,                           // number; null unless lat/lng were sent
  "departments": [ { "id": "uuid", "code": "cardiology", "name": "Cardiology" } ],
  "next_available_at": "2026-10-01T04:30:00+00:00",   // earliest open slot, or null
  "online_booking_enabled": true,
  "logo_file_id": "uuid",                        // nullable
  "cover_file_id": null
}
```

### 7.3 `GET /patient/hospitals/{hospital_id}`

`HospitalCard` plus:

```jsonc
{
  /* …all HospitalCard fields… */
  "legal_name": "City Care Hospitals Pvt Ltd",
  "email": "info@citycare.example", "phone_e164": "+914842000000", "website": null,
  "address": {
    "address_line1": "NH 66", "address_line2": null, "address_line3": null,
    "city": "Kochi", "state": "Kerala", "pincode": "682024", "phone_e164": "+914842000000"
  },
  "lat": "10.0261", "lng": "76.3125",            // strings or null
  "timezone": "Asia/Kolkata",
  "hours": [                                     // one row per weekday; 0 = Monday … 6 = Sunday
    { "weekday": 0, "is_closed": false, "opens_at": "08:00", "closes_at": "20:00" }   // times hospital-local, nullable
  ],
  "holidays": [                                  // upcoming, max 50
    { "id": "uuid", "name": "Onam", "date_from": "2026-10-05", "date_to": "2026-10-05",
      "department_id": null }                    // null = whole hospital
  ],
  "banners": [ /* Banner, §7.4 — max 20 */ ],
  "cancellation_policy": {
    "cutoff_hours": 4,
    "refund_before_cutoff_bp": 10000,            // 100 %
    "refund_after_cutoff_bp": 0,
    "refund_includes_convenience_fee": false,
    "token_cancel_limit_min": null,              // minutes before session start; null = until the token is called
    "hospital_cancellation_refund_bp": 10000     // hospital-side cancel is always 100 %
  },
  "follow_up_window_days": 7,
  "booking_window_days": 30,                     // how far ahead the date picker may go
  "version": 3
}
```

`404 NOT_FOUND` for a hidden or unknown hospital.

### 7.4 `GET /patient/hospitals/{hospital_id}/banners`

→ `Page<Banner>` (active and in date range only)

```json
{ "id": "uuid", "title": "Free health check-up", "body": "This week only",
  "image_file_id": "uuid", "cta_label": "Book now", "cta_target": "medibook://booking",
  "sort_order": 1, "starts_at": null, "ends_at": null }
```

Banners belong to a hospital. There is no platform-wide banner list (§18).

### 7.5 `GET /patient/departments`

The department list across all visible hospitals (for a "browse by speciality" entry).
Sort: `code`, `name`. → `Page<…>`

```json
{ "code": "cardiology", "name": "Cardiology", "hospital_count": 4 }
```

No `id` here — use `code` with `GET /patient/hospitals?department_code=`.

### 7.6 `GET /patient/hospitals/{hospital_id}/departments`

Sort: `name`, `sort_order`. → `Page<Department>`

```json
{ "id": "uuid", "code": "cardiology", "name": "Cardiology",
  "description": "Heart and vascular care", "icon": "heart", "sort_order": 1 }
```

### 7.7 `GET /patient/hospitals/{hospital_id}/doctors`

Filters: `department_code`, `department_id`, `q` (name).
Sort: `name`, `sort_order`, `next_available_at`, `consultation_fee_paise`. → `Page<DoctorCard>`

```jsonc
// DoctorCard
{
  "id": "uuid", "slug": "dr-anya-menon", "name": "Dr. Anya Menon",
  "title": "Senior Consultant",                  // nullable
  "qualification": "MBBS, MD, DM",               // nullable
  "specialisation": "Interventional Cardiology", // nullable
  "experience_years": 14,                        // nullable
  "photo_file_id": "uuid",                       // nullable
  "department": { "id": "uuid", "code": "cardiology", "name": "Cardiology" },
  "hospital": { "id": "uuid", "name": "City Care Hospital", "city": "Kochi", "area": "Edappally" },
  "consultation_fee_paise": 50000,
  "follow_up_fee_paise": 30000,                  // null = same as consultation
  "rating": "4.8",                               // string or null
  "rating_count": 96,
  "status": "active",                            // active | on_leave   (inactive doctors are not listed)
  "is_bookable_online": true,
  "next_available_at": "2026-10-01T04:30:00+00:00"   // or null
}
```

There is no cross-hospital doctor list; use this per hospital, or §7.9.

### 7.8 `GET /patient/doctors/{doctor_id}`

`DoctorCard` plus:

```json
{ "bio": "…", "room": "OP-12", "slot_length_min": 15, "expected_consult_minutes": 10, "version": 2 }
```

(`bio`, `room`, `expected_consult_minutes` nullable.) Fees here are the base fees only; the
payable breakdown is the fee quote (§8.3). Reviews are not returned (§18).

### 7.9 `GET /patient/search?q=`

`q` is required, 2–100 characters. Not paginated; up to 10 of each.

```jsonc
{
  "q": "card",
  "hospitals": [ /* HospitalCard */ ],
  "departments": [ { "code": "cardiology", "name": "Cardiology", "hospital_count": 4 } ],
  "doctors": [ /* DoctorCard */ ]
}
```

---

## 8. Availability, slots and fee quote

### 8.1 `GET /patient/doctors/{doctor_id}/availability` (public)

Query: `from`, `to` (dates; optional). Default range: today → the hospital's booking window.
Maximum 62 days. Use it to enable/disable days in the date strip.

```jsonc
{
  "doctor_id": "uuid",
  "from": "2026-10-01", "to": "2026-10-30",
  "dates": [
    {
      "date": "2026-10-01",
      "sessions": [                              // [] = doctor not sitting that day
        {
          "session_id": "uuid",
          "session_code": "morning",
          "label": "Morning",
          "state": "available",                  // available | full | closed
          "starts_at": "2026-10-01T03:30:00+00:00",
          "ends_at": "2026-10-01T07:30:00+00:00"
        }
      ]
    }
  ]
}
```

### 8.2 `GET /patient/doctors/{doctor_id}/slots?date=YYYY-MM-DD` (public)

`date` is required.

```jsonc
{
  "doctor_id": "uuid",
  "date": "2026-10-01",
  "sessions": [
    {
      "session_id": "uuid", "session_code": "morning", "label": "Morning",
      "status": "scheduled",                     // scheduled | open | paused | closed | cancelled
      "starts_at": "2026-10-01T03:30:00+00:00",
      "ends_at": "2026-10-01T07:30:00+00:00",
      "slots": [
        {
          "id": "uuid",                          // → slot_id for booking
          "starts_at": "2026-10-01T03:30:00+00:00",
          "ends_at": "2026-10-01T03:45:00+00:00",
          "state": "available"                   // available | held | booked | blocked | past
        }
      ]
    }
  ]
}
```

Only `available` slots can be booked. One slot is one patient. The slots come grouped by the
doctor's **session** (the queue unit), not by fixed morning / afternoon / evening buckets — use
the session `label`.

### 8.3 `GET /patient/fee-quotes` (token required)

Query: `doctor_id` (required), `person_id`, `service_id`, `coupon_code` (all optional).
Show this breakdown; **do not compute fees in the app**.

```jsonc
{
  "consultation_fee_paise": 50000,               // already the follow-up fee when is_follow_up
  "service_fee_paise": 0,
  "discount_paise": 5000,
  "convenience_fee_paise": 2500,
  "tax_paise": 500,                              // sum of the per-line taxes that are added on top
  "total_paise": 48000,                          // consultation + service − discount + convenience + tax
  "is_follow_up": false,
  "coupon_error": null,                          // same value as coupon.reason
  "currency": "INR",
  "tax_lines": [
    { "supplier": "hospital", "line": "consultation", "code": "EXEMPT",
      "base_paise": 45000, "rate_bp": 0, "tax_paise": 0, "inclusive": false },
    { "supplier": "platform", "line": "convenience_fee", "code": "CONVENIENCE_FEE_GST",
      "base_paise": 2500, "rate_bp": 1800, "tax_paise": 500, "inclusive": false }
  ],
  "coupon": { "code": "WELCOME10", "valid": true },
      // no coupon sent → null
      // bad coupon     → { "valid": false, "reason": "COUPON_EXPIRED" }
      //                   reason ∈ COUPON_INVALID | COUPON_EXPIRED | COUPON_MIN_ORDER | COUPON_USAGE_CAP
  "doctor_id": "uuid", "hospital_id": "uuid",
  "person_id": "uuid",                           // or null
  "service_id": null,
  "regular_consultation_fee_paise": 50000,
  "follow_up_fee_paise": null,                   // set only when is_follow_up
  "lines": [                                     // ready-to-render rows
    { "line": "consultation", "description": "Consultation", "supplier": "hospital",
      "amount_paise": 50000, "tax_code": "EXEMPT", "tax_rate_bp": 0, "tax_paise": 0, "tax_inclusive": false },
    { "line": "convenience_fee", "description": "Convenience fee", "supplier": "platform",
      "amount_paise": 2500, "tax_code": "CONVENIENCE_FEE_GST", "tax_rate_bp": 1800, "tax_paise": 500, "tax_inclusive": false },
    { "line": "discount", "description": "Discount", "supplier": "hospital",
      "amount_paise": -5000, "tax_code": null, "tax_rate_bp": 0, "tax_paise": 0, "tax_inclusive": false }
  ],
  "quoted_for_date": "2026-09-30"
}
```

Notes:

- A bad coupon does **not** fail the quote — it comes back in `coupon` with `valid: false`, and
  the quote is priced without it. (At booking, a bad coupon **does** fail the call — §9.1.)
- "Apply coupon" is this same call with `coupon_code`; there is no separate coupon endpoint.
- Send `person_id` so the follow-up fee is applied for the right family member.
- The quote is for today; the booking re-prices on the slot date and that figure is final — take
  the amount to pay from the booking response, not from the quote.
- Errors: `404 NOT_FOUND` (unknown doctor or person), `400` on `service_id`.

---

## 9. Booking and payment

One 5-minute timer runs from the booking call. There is no separate "hold" call and no
pay-at-hospital.

```
fee-quotes ──► POST /appointments ──► Razorpay checkout ──► POST …/verify ──► success screen
                    │ status = pending_payment                 │ status = scheduled
                    │ booking_deadline_at = now + 5 min        │ (or pending_approval)
                    └── payment failed? ──► POST …/retry (new order, same deadline)
```

### 9.1 `POST /patient/appointments` — book

`Idempotency-Key` required.

```jsonc
{
  "slot_id": "uuid",                   // required — from §8.2
  "person_id": "uuid",                 // required — one of the user's persons
  "coupon_code": "WELCOME10",          // optional, ≤ 64
  "patient_notes": "Chest pain since Monday"   // optional, ≤ 2000
}
```

**201**:

```jsonc
{
  "appointment": { /* Appointment, §10 — status "pending_payment", payment_status "pending" */ },
  "payment_order": { /* PaymentOrder, below */ }
}
```

The backend creates the booking reference, the token number and the fee snapshot here. Show
`appointment.booking_ref` and `appointment.token_label`; never generate them in the app. Run the
countdown to `appointment.booking_deadline_at`.

| Status | `code` | Meaning |
|---|---|---|
| 409 | `SLOT_UNAVAILABLE` | taken, in the past, or the hospital/doctor is not taking online bookings — reload the slots |
| 409 | `TOKEN_RANGE_EXHAUSTED` | no tokens left in the session |
| 409 | `COUPON_INVALID` / `COUPON_EXPIRED` / `COUPON_MIN_ORDER` / `COUPON_USAGE_CAP` | coupon refused — nothing was booked |
| 404 | `NOT_FOUND` | unknown `person_id` |
| 409 | `IDEMPOTENCY_CONFLICT` | key reused with a different body |
| 503 | `PROVIDER_UNAVAILABLE` | payment gateway down — nothing was booked |

**`PaymentOrder`**:

```jsonc
{
  "id": "uuid",
  "appointment_id": "uuid",
  "amount_paise": 48000,
  "currency": "INR",
  "channel": "online",
  "gateway": "razorpay",
  "gateway_order_id": "order_NXa…",    // → Razorpay checkout "order_id"
  "status": "created",                 // created | attempted | paid | failed | expired | cancelled
  "attempts": 1,
  "expires_at": "2026-09-30T10:05:00Z",   // = booking_deadline_at
  "key_id": "rzp_live_…",              // → Razorpay checkout "key"
  "created_at": "…"
}
```

### 9.2 Razorpay checkout (in the app)

Open the Razorpay SDK with `key = key_id`, `order_id = gateway_order_id`,
`amount = amount_paise`, `currency = currency`. The SDK offers the payment methods; the app does
not list them. On success the SDK returns `razorpay_payment_id` and `razorpay_signature`.

### 9.3 `POST /patient/payments/orders/{order_id}/verify`

`Idempotency-Key` required.

```json
{ "razorpay_payment_id": "pay_NXb…", "razorpay_signature": "…" }
```

**200**:

```jsonc
{
  "status": "paid",                    // = order.status
  "order": { /* PaymentOrder */ },
  "payment": { /* Payment, §10.11 */ },
  "appointment": { /* Appointment */ }
}
```

- **Success** is `status == "paid"`. `appointment.status` is then `scheduled`, or
  `pending_approval` when the hospital approves online bookings manually (tell the user the
  hospital will confirm).
- If the money arrived **after** the 5-minute deadline, `status` is not `paid`, the appointment is
  `cancelled`, and the payment is refunded in full automatically — show "payment received too
  late, refund initiated".
- `400 PAYMENT_SIGNATURE_INVALID` — treat as failed.
- Safe to call again; the capture is recorded once.

### 9.4 `POST /patient/payments/orders/{order_id}/retry`

`Idempotency-Key` required; no body. **201** → a **new** `PaymentOrder` (use its
`gateway_order_id`). The deadline is **not** extended.

| Status | `code` | Meaning |
|---|---|---|
| 409 | `PAYMENT_ALREADY_CAPTURED` | already paid — go to success |
| 409 | `APPOINTMENT_NOT_ACTIONABLE` | the 5 minutes are over — start a new booking |

### 9.5 `GET /patient/payments/orders/{order_id}`

**200** `PaymentOrder`. Poll this (or the appointment) if the app was killed during checkout: the
gateway also notifies the backend directly, so the order can become `paid` without a verify call.

### 9.6 When the timer runs out

An unpaid booking is cancelled within about a minute of `booking_deadline_at`
(`status: "cancelled"`, `cancelled_by: "system"`, `cancellation_reason: "payment_timeout"`); the
slot, token and coupon go back. The user must book again.

---

## 10. Appointments

### The `Appointment` object

```jsonc
{
  "id": "uuid",
  "booking_ref": "MB-2026-000124",     // show this
  "status": "scheduled",               // pending_payment | pending_approval | scheduled | checked_in | in_consultation | completed | cancelled | no_show
  "status_reason": null,
  "source": "online",                  // online | walk_in
  "hospital": { "id": "uuid", "name": "City Care Hospital", "city": "Kochi", "phone_e164": "+914842000000" },
  "department": { "id": "uuid", "code": "cardiology", "name": "Cardiology" },
  "doctor": { "id": "uuid", "name": "Dr. Anya Menon", "title": "Senior Consultant",
              "specialisation": "Interventional Cardiology", "room": "OP-12" },
  "person_id": "uuid",                 // which family member — join with §6.1 for the name
  "session_id": "uuid",
  "slot_id": "uuid",
  "scheduled_date": "2026-10-01",      // hospital-local date
  "scheduled_start_at": "2026-10-01T03:30:00Z",
  "scheduled_end_at": "2026-10-01T03:45:00Z",
  "token_no": 26,                      // nullable
  "token_label": "T-026",              // show this; nullable
  "token_source": "online",            // online | offline
  "is_follow_up": false,
  "patient_notes": "Chest pain since Monday",   // nullable
  "payment_status": "paid",            // unpaid | pending | paid | refunded | failed
  "booking_deadline_at": "2026-09-30T10:05:00Z",   // nullable
  "consultation_fee_paise": 50000,
  "service_fee_paise": 0,
  "discount_paise": 5000,
  "convenience_fee_paise": 2500,
  "tax_paise": 500,
  "tax_lines": [ /* same objects as fee-quote tax_lines */ ],
  "total_paise": 48000,
  "currency": "INR",
  "cancelled_at": null,
  "cancelled_by": null,                // patient | hospital | system | null
  "cancellation_reason": null,
  "checked_in_at": null,
  "called_at": null,
  "completed_at": null,
  "created_at": "2026-09-30T10:00:00Z",
  "version": 2
}
```

The fees are a snapshot taken at booking — display them as they are. The object has no hospital
address or time zone; take those from the token card (§10.4) or hospital detail (§7.3). A walk-in
booked at the desk for a person linked to this account also appears here (`source: "walk_in"`).

### 10.1 `GET /patient/appointments`

→ `Page<Appointment>`. Default order: newest appointment time first.

| Parameter | Values |
|---|---|
| `bucket` | `upcoming` (active and not yet over) · `past` (everything else) |
| `status` | *multi* — any of the eight statuses |
| `doctor_id`, `hospital_id`, `person_id` | UUID |
| `date_from`, `date_to` | on `scheduled_date` |
| `q` | matches booking ref, token label, doctor, hospital, or the person's name |
| `sort` | `scheduled_start_at`, `created_at` |

For the app's tabs: Upcoming = `bucket=upcoming&sort=scheduled_start_at`; Completed =
`status=completed`; Cancelled = `status=cancelled,no_show`.

### 10.2 `GET /patient/appointments/{id}`

All `Appointment` fields plus:

```jsonc
{
  /* …Appointment… */
  "payment_order": { /* latest PaymentOrder, or null */ },
  "receipt": { "receipt_no": "RC/26-27/000311", "issued_at": "…" },   // or null
  "refunds": [ /* Refund, §10.11 */ ],
  "actions": {
    "can_cancel": true,
    "cancel_blocked_reason": null,     // when can_cancel is false: APPOINTMENT_NOT_ACTIONABLE | TOKEN_ALREADY_CALLED | TOKEN_CANCEL_WINDOW_CLOSED
    "can_retry_payment": false,        // pending_payment and the deadline has not passed
    "can_review": false                // completed and not yet reviewed
  },
  "reviewed": false
}
```

Drive the buttons from `actions` instead of re-deriving the rules in the app. There is no
reschedule — offer "Cancel" and "Book again".

### 10.3 `GET /patient/appointments/{id}/events`

History timeline. Sort: `occurred_at`. → `Page<Event>`

```jsonc
{
  "id": "uuid",
  "event_type": "created",             // created | approval_requested | approved | checked_in | called | started | completed | cancelled | no_show | payment_updated | refund_updated | note_added | reminder_sent | token_reassigned
  "actor_kind": "patient",             // patient | staff | system
  "from_status": null,
  "to_status": "pending_payment",
  "occurred_at": "2026-09-30T10:00:00+00:00"
}
```

### 10.4 `GET /patient/appointments/{id}/token-card`

Everything the token / success screen shows, already in hospital-local time.

```jsonc
{
  "booking_ref": "MB-2026-000124",
  "token_label": "T-026",
  "token_no": 26,
  "qr_payload": "MB-2026-000124",      // encode this string as the QR
  "status": "scheduled",
  "patient_name": "Arjun Nair",
  "hospital": { "name": "City Care Hospital", "address_line1": "NH 66", "address_line2": null,
                "address_line3": null, "city": "Kochi", "state": "Kerala", "pincode": "682024",
                "phone_e164": "+914842000000" },
  "doctor": { "name": "Dr. Anya Menon", "title": "Senior Consultant", "room": "OP-12" },
  "department": { "name": "Cardiology" },
  "date": "2026-10-01",
  "start_time": "09:00",               // hospital-local HH:MM
  "end_time": "09:15",
  "starts_at": "2026-10-01T03:30:00+00:00",
  "ends_at": "2026-10-01T03:45:00+00:00",
  "session": { "session_code": "morning", "label": "Morning",
               "starts_at": "2026-10-01T03:30:00+00:00", "ends_at": "2026-10-01T07:30:00+00:00" }
}
```

### 10.5 `GET /patient/appointments/{id}/queue` — live queue

The queue is per **appointment** (the app's `/queue/:doctorId` route must carry the appointment
id instead).

```jsonc
{
  "session_state": "open",             // scheduled | open | paused | closed | cancelled
  "queue_state": "consulting",         // available | consulting | waiting | on_break
  "current_token": "T-021",            // label now being seen; null if none
  "current_token_no": 21,              // nullable
  "last_called_token": 21,             // number, nullable
  "your_token": "T-026",
  "your_token_no": 26,
  "tokens_ahead": 4,
  "estimated_wait_minutes": 40,        // tokens_ahead × the doctor's minutes per patient
  "updated_at": "2026-10-01T04:10:00+00:00"
}
```

For live updates, open the WebSocket in §15.1 and re-fetch this endpoint on each
`session.updated` message.

### 10.6 `GET /patient/appointments/{id}/cancellation-preview`

Call before showing the cancel confirmation.

```jsonc
{
  "allowed": true,
  "reason": null,                      // when not allowed: APPOINTMENT_NOT_ACTIONABLE | TOKEN_ALREADY_CALLED | TOKEN_CANCEL_WINDOW_CLOSED
  "cutoff_at": "2026-09-30T23:30:00+00:00",   // appointment time − the hospital's cutoff hours
  "before_cutoff": true,
  "refund_bp": 10000,                  // 10000 = 100 %; 0 when unpaid
  "refund_paise": 45000,
  "non_refundable_paise": 3000,
  "includes_convenience_fee": false
}
```

Each hospital sets its own two-tier policy; the app's fixed "4 h / 50 %" rule must go. Show
`refund_paise` as the amount the patient gets back.

### 10.7 `POST /patient/appointments/{id}/cancel`

`Idempotency-Key` required.

```jsonc
{ "reason": "Feeling better" }         // optional, ≤ 500
```

**200**:

```jsonc
{
  "appointment": { /* Appointment, status "cancelled", cancelled_by "patient" */ },
  "refunds": [ /* Refund, §10.11 — empty when nothing was paid or the refund is 0 % */ ]
}
```

Refunds go back to the original payment method, in full per payment line; there are no partial
refunds chosen by the user.

| Status | `code` |
|---|---|
| 409 | `APPOINTMENT_NOT_ACTIONABLE` — already over, cancelled, or in consultation |
| 409 | `TOKEN_ALREADY_CALLED` — the token was called; only the hospital can cancel now |
| 409 | `TOKEN_CANCEL_WINDOW_CLOSED` — past the hospital's per-token limit |

### 10.8 `GET /patient/appointments/{id}/receipt`

`404 NOT_FOUND` until the booking is paid.

```jsonc
{
  "id": "uuid",
  "receipt_no": "RC/26-27/000311",     // show this
  "fy_code": "26-27",
  "issued_at": "2026-09-30T10:02:11+00:00",
  "issued_by_name": null,              // staff name on desk receipts
  "counter_code": null,                // desk receipts
  "subtotal_paise": 47500,
  "tax_paise": 500,
  "total_paise": 48000,
  "lines": [
    { "supplier": "hospital", "line": "consultation", "description": "Consultation",
      "qty": 1, "unit_paise": 50000, "amount_paise": 50000,
      "tax_code": "EXEMPT", "tax_rate_bp": 0, "tax_paise": 0, "tax_inclusive": false,
      "appointment_id": "uuid", "booking_ref": "MB-2026-000124" },
    { "supplier": "hospital", "line": "discount", "description": "Discount",
      "qty": 1, "unit_paise": -5000, "amount_paise": -5000,
      "tax_code": null, "tax_rate_bp": 0, "tax_paise": 0, "tax_inclusive": false,
      "appointment_id": "uuid", "booking_ref": "MB-2026-000124" },
    { "supplier": "platform", "line": "convenience_fee", "description": "Convenience fee",
      "qty": 1, "unit_paise": 2500, "amount_paise": 2500,
      "tax_code": "CONVENIENCE_FEE_GST", "tax_rate_bp": 1800, "tax_paise": 500, "tax_inclusive": false,
      "appointment_id": "uuid", "booking_ref": "MB-2026-000124" }
  ],
  "payment_lines": [
    { "method": "upi", "amount_paise": 48000, "reference": "pay_NXb…" }
  ],
  "hospital": {                        // snapshot at issue time
    "id": "uuid", "name": "City Care Hospital", "legal_name": "…", "gstin": "32ABCDE1234F1Z5",
    "address_line1": "NH 66", "address_line2": null, "address_line3": null,
    "city": "Kochi", "state": "Kerala", "pincode": "682024", "phone_e164": "+914842000000",
    "logo_file_id": "uuid", "stamp_file_id": null
  },
  "platform": {                        // Medibook, the seller for online bookings
    "legal_name": "…", "gstin": "…", "address_line1": "…", "address_line2": null,
    "address_line3": null, "city": "…", "state": "…", "pincode": "…"
  },
  "pdf_available": true
}
```

`line` ∈ `consultation` | `service` | `discount` | `convenience_fee`.

### 10.9 `GET /patient/appointments/{id}/receipt.pdf`

Returns JSON, not the PDF:

```json
{ "url": "https://…signed…", "receipt_no": "RC/26-27/000311" }
```

The URL is valid for 10 minutes — download or share from it. `404` while the PDF is still being
generated (`pdf_available: false`); `501 NOT_IMPLEMENTED_YET` if PDF rendering is switched off on
the server.

### 10.10 `GET /patient/appointments/{id}/calendar.ics`

Returns a `text/calendar` file (not JSON) with `Content-Disposition: attachment`. Save it and
hand it to the OS calendar ("Add to calendar").

### 10.11 Payments and refunds

| Call | Filter | Sort | Result |
|---|---|---|---|
| `GET /patient/payments` | `appointment_id` | `created_at`, `captured_at` | `Page<Payment>` |
| `GET /patient/refunds` | `appointment_id` | `requested_at`, `processed_at` | `Page<Refund>` |

```jsonc
// Payment
{
  "id": "uuid", "order_id": "uuid", "appointment_id": "uuid",
  "amount_paise": 48000,
  "method": "upi",                     // upi | card | netbanking | wallet | emi | paylater | cash | pos | other
  "gateway": "razorpay",               // null for desk payments
  "status": "captured",                // captured | failed | refunded
  "captured_at": "2026-09-30T10:02:10+00:00",
  "failure_code": null, "failure_reason": null,
  "created_at": "…"
}
// Refund
{
  "id": "uuid", "payment_id": "uuid", "appointment_id": "uuid",
  "amount_paise": 45000,
  "reason": "patient_cancellation",    // patient_cancellation | hospital_cancellation | payment_after_deadline | amount_mismatch | …
  "status": "processing",              // requested | processing | processed | failed
  "requested_at": "…",
  "processed_at": null
}
```

### 10.12 `POST /patient/appointments/{id}/review`

Only for a `completed` appointment, once.

```jsonc
{ "rating": 5, "comment": "Very thorough." }    // rating 1–5 required; comment optional ≤ 2000
```

**201**:

```jsonc
{
  "id": "uuid", "appointment_id": "uuid", "doctor_id": "uuid",
  "rating": 5, "comment": "Very thorough.",
  "moderation_status": "pending",      // pending | approved | rejected
  "is_published": false,
  "created_at": "…"
}
```

Errors: `409 APPOINTMENT_NOT_ACTIONABLE` (not completed), `409 STATE_CONFLICT` (already reviewed).
Reviews are moderated before they count toward the doctor's rating.

---

## 11. Medical documents and file upload

Medical documents and insurance files are visible to the patient **only**. There is no sharing
with a hospital or anyone else, by design — the app's "Share" action on a document must go.

### 11.1 Upload a file (three steps)

Used for medical documents, insurance files and support attachments.

**Step 1 — `POST /shared/files/uploads`**

```jsonc
{
  "purpose": "medical_document",       // medical_document | insurance | ticket_attachment | avatar
  "mime": "application/pdf",
  "size_bytes": 182044,                // exact size of the file
  "sha256": null,                      // optional hex digest
  "original_name": "blood-test.pdf"    // optional, ≤ 200
}
```

Unknown body fields are rejected.

**201**:

```jsonc
{
  "file_id": "uuid",
  "upload_url": "https://…presigned…",
  "method": "PUT",
  "headers": { "Content-Type": "application/pdf" },   // send exactly these headers
  "expires_at": "…",                   // 5 minutes
  "file": { /* File, below — status "pending" */ }
}
```

| Purpose | Allowed types |
|---|---|
| `medical_document`, `insurance` | PDF, JPEG, PNG, HEIC |
| `ticket_attachment` | PDF, JPEG, PNG |
| `avatar` | JPEG, PNG, HEIC |

Maximum size 10 MB (server-configurable). Errors: `415 FILE_TYPE_NOT_ALLOWED` (`meta.allowed`),
`413 FILE_TOO_LARGE` (`meta.max_bytes`).

**Step 2 — `PUT` the raw bytes to `upload_url`** with the returned `headers`. This request goes
to the storage server, not the API: do **not** send the `Authorization` header or the API base
URL.

**Step 3 — `POST /shared/files/{file_id}/complete`** (no body) → **200** `File` with
`status: "scanning"`.

The file is then virus-scanned in the background. **Poll `GET /shared/files/{file_id}`** until
`status` is `clean` (usually a few seconds) before using the file. `infected` or `scan_failed` →
tell the user the file was rejected.

```jsonc
// File
{
  "id": "uuid",
  "purpose": "medical_document",
  "owner_kind": "patient",
  "hospital_id": null,
  "original_name": "blood-test.pdf",
  "mime": "application/pdf",
  "size_bytes": 182044,
  "sha256": "9f2c…",                   // nullable until scanned
  "status": "clean",                   // pending | uploaded | scanning | clean | infected | sealed | scan_failed
  "uploaded_at": "…", "scanned_at": "…",   // nullable
  "expires_at": null,
  "created_at": "…",
  "version": 1
}
```

Other file calls: `DELETE /shared/files/{id}` → **204** (`409 FILE_IN_USE` while something
references it).

### 11.2 Documents

| Call | Notes |
|---|---|
| `GET /patient/documents` | `Page<Document>` |
| `POST /patient/documents` | **201** `Document`. The file must be `clean` and uploaded with purpose `medical_document`. |
| `GET /patient/documents/{id}` | **200** `Document` |
| `PATCH /patient/documents/{id}` | `If-Match` optional → **200**. The file itself cannot be swapped. |
| `DELETE /patient/documents/{id}` | **204** |
| `GET /patient/documents/{id}/download-url` | see 11.3 |

List filters: `doc_type`, `person_id`, `date_from`, `date_to` (on `document_date`),
`appointment_id`, `q` (title). Sort: `document_date`, `created_at`, `title`
(default newest `document_date` first).

```jsonc
// POST body (PATCH: any subset except file_id). Unknown fields are rejected.
{
  "file_id": "uuid",                   // required
  "person_id": "uuid",                 // required — whose document
  "doc_type": "lab_report",            // lab_report | prescription | scan | discharge_summary | invoice | vaccination | other
  "title": "CBC — Sept 2026",          // required, ≤ 200
  "document_date": "2026-09-21",       // required
  "notes": null,                       // optional, ≤ 2000
  "appointment_id": null               // optional — one of the user's own appointments
}
// Document
{
  "id": "uuid",
  "person_id": "uuid",
  "appointment_id": null,
  "doc_type": "lab_report",
  "title": "CBC — Sept 2026",
  "document_date": "2026-09-21",
  "notes": null,
  "file": { "id": "uuid", "original_name": "blood-test.pdf", "mime": "application/pdf",
            "size_bytes": 182044, "status": "clean" },
  "version": 1,
  "created_at": "…", "updated_at": "…"
}
```

Errors: `400 VALIDATION_ERROR` on `file_id` (not the user's, wrong purpose, or not yet `clean`),
`person_id`, `appointment_id`.

Linking a document to an appointment is the patient's own note; it does not show the document to
the hospital.

### 11.3 `GET /patient/documents/{id}/download-url`

```json
{ "url": "https://…signed…", "expires_at": "2026-09-30T10:10:00+00:00" }
```

Valid 10 minutes. Open it in a viewer or download it; do not cache the URL. `404` if the file is
not `clean`.

### 11.4 `GET /shared/files/{file_id}/url` — resolve any file id

Same response as 11.3. Use it for `logo_file_id`, `cover_file_id`, `photo_file_id`,
`image_file_id` and insurance documents. **A token is required**, so a signed-out user browsing
hospitals cannot load these images (§18). Cache the downloaded image by file id, not by URL.

---

## 12. Notifications and push devices

### 12.1 `GET /patient/notifications`

Filters: `unread` (bool), `kind` (*multi*). Newest first. → `Page<Notification>`

```jsonc
{
  "id": "uuid",
  "kind": "confirmation",              // confirmation | reminder | cancellation | payment | queue | general
  "title": "Appointment confirmed",
  "body": "Your appointment with Dr. Anya Menon on 1 Oct, 9:00 AM is confirmed. Token T-026.",
  "data": {
    "event": "appointment.confirmed",  // always present — what happened
    "appointment_id": "uuid"           // present when relevant; also refund_id, ticket_id, person_id, dsr_id
  },
  "read_at": null,                     // null = unread
  "hospital_id": "uuid",               // nullable
  "created_at": "…"
}
```

`data.event` values and where to take the user:

| `event` | `kind` | Open |
|---|---|---|
| `appointment.confirmed`, `appointment.approved` | confirmation | appointment detail (`appointment_id`) |
| `appointment.reminder` | reminder | appointment detail |
| `appointment.cancelled`, `appointment.rejected` | cancellation | appointment detail |
| `appointment.no_show` | general | appointment detail |
| `token.called` | queue | live queue (`appointment_id`) |
| `payment.captured` | payment | receipt (`appointment_id`) |
| `refund.processed` | payment | appointment detail (`refund_id`) |
| `patient.auto_linked` | general | family members (`person_id`) — a hospital desk registered someone under this phone number |
| `account.deletion_requested` | general | account |
| `dsr.export_ready` | general | data export (`dsr_id`, §5.7) |
| `user.phone_changed` | general | account |
| `support.ticket_updated` | general | ticket (`ticket_id`) |

### 12.2 – 12.5 Read state

| Call | Result |
|---|---|
| `GET /patient/notifications/unread-count` | `{ "unread_count": 3 }` — the bell badge |
| `POST /patient/notifications/{id}/read` | **200** `Notification` |
| `POST /patient/notifications/{id}/unread` | **200** `Notification` |
| `POST /patient/notifications/read-all` | `{ "updated_count": 3 }` |
| `DELETE /patient/notifications/{id}` | **204** (dismiss) |

None take a body. For a live badge, use the inbox WebSocket (§15.2).

### 12.6 Push devices (FCM)

Register after login and whenever FCM rotates the token.

| Call | Result |
|---|---|
| `POST /patient/me/devices` | **201** new, **200** when the token was already registered → `Device` |
| `GET /patient/me/devices` | `Page<Device>` |
| `DELETE /patient/me/devices/{id}` | **204** — call on logout |

```jsonc
// request
{ "platform": "android", "push_token": "<fcm token>", "app_version": "1.0.0", "os_version": "14" }
//            android | ios | web                       optional                optional
// Device
{ "id": "uuid", "platform": "android", "push_token": "…", "app_version": "1.0.0",
  "os_version": "14", "last_seen_at": "…", "created_at": "…" }
```

`Device.id` is the optional `device_id` on the login calls.

There is no notification-preferences endpoint (§18). Reminders are sent 1 week, 48 h, 24 h and
2 h before an appointment; reminder pushes are held back between 21:00 and 08:00 hospital time.

---

## 13. Support tickets

| Call | Notes |
|---|---|
| `GET /patient/support/tickets` | `Page<Ticket>` (no `messages`) |
| `POST /patient/support/tickets` | **201** `Ticket` |
| `GET /patient/support/tickets/{id}` | **200** `Ticket` with `messages` |
| `POST /patient/support/tickets/{id}/messages` | **201** `Message` |

List filters: `status` (*multi*), `category`, `priority` (*multi*), `ticket_no`, `date_from`,
`date_to`. Sort: `created_at`, `updated_at`, `priority`, `status`.

```jsonc
// POST /tickets — unknown fields are rejected
{
  "category": "billing",               // billing | technical | onboarding | feature_request | complaint | other
  "subject": "Charged twice",          // ≤ 200
  "description": "…",                  // ≤ 5000
  "priority": "normal",                // optional: low | normal | high | urgent
  "attachment_file_ids": ["uuid"]      // optional, ≤ 5; clean files with purpose ticket_attachment (§11.1)
}
// Ticket
{
  "id": "uuid",
  "ticket_no": "TKT-2026-000045",      // show this
  "raised_by_kind": "patient",
  "hospital_id": null,
  "category": "billing",
  "subject": "Charged twice",
  "description": "…",
  "priority": "normal",
  "status": "open",                    // open | in_progress | waiting_on_requester | resolved | closed
  "resolved_at": null, "closed_at": null,
  "created_at": "…", "updated_at": "…",
  "version": 1,
  "messages": [                        // detail only
    { "id": "uuid", "author_kind": "requester",     // requester | platform_staff
      "author_name": "Anita Nair", "body": "…",
      "attachment_file_ids": ["uuid"], "occurred_at": "…" }
  ]
}
// POST /tickets/{id}/messages
{ "body": "Any update?", "attachment_file_ids": [] }      // body ≤ 5000
```

`409 STATE_CONFLICT` when replying to a `closed` ticket. A reply on a `resolved` or
`waiting_on_requester` ticket reopens it.

---

## 14. Ambulance

### `GET /patient/ambulance/providers` (public)

Filters: `city`, `area`, `hospital_id` (providers in that hospital's city). → `Page<Provider>`

```json
{ "id": "uuid", "name": "Kochi Rapid Ambulance", "phone_e164": "+919800011122",
  "eta_minutes": 12, "service_area": "Edappally, Kakkanad", "city": "Kochi", "area": "Edappally" }
```

(`eta_minutes`, `service_area`, `city`, `area` nullable.) This is a list to **call** from. There
is no ambulance booking / request endpoint (§18).

---

## 15. WebSockets

Push-only: the server sends, the app listens; every action stays on REST.

**Connecting**

- The access token goes in the **subprotocol**, never in the URL:
  `Sec-WebSocket-Protocol: bearer, <access>`. In Dart:
  `WebSocket.connect(url, protocols: ['bearer', accessToken])`.
- The server answers with subprotocol `bearer`.
- Send `{"type":"ping"}` every 30 seconds; the server replies
  `{"type":"pong","data":{},"ts":"…"}`.
- Close codes: **4401** — token missing, invalid or expired (refresh, then reconnect);
  **4408** — idle for 5 minutes.
- The token is checked only when connecting, but reconnect with a fresh one after any drop.

Every message has this frame:

```json
{ "type": "session.updated", "data": { }, "ts": "2026-10-01T04:10:00+00:00" }
```

### 15.1 `/ws/patient/session/{appointment_id}` — live queue

Only for the user's own appointment (otherwise closed with 4401).

| `type` | `data` |
|---|---|
| `session.updated` | `{ "id": "<session id>", "doctor_id": "uuid", "date": "2026-10-01", "session_code": "morning", "label": "Morning", "status": "open", "queue_state": "consulting", "current_token_no": 21, "current_appointment_id": "uuid", "last_called_token_no": 21, "last_called_at": "…", "served_count": 20, "waiting_count": 9, "completed_count": 19, "no_show_count": 1, "version": 57 }` |
| `token.called` | `{ "token_label": "T-026", "appointment_id": "uuid" }` |

How to use:

- On `session.updated`, re-fetch `GET /patient/appointments/{id}/queue` (§10.5) for
  `tokens_ahead` and the estimated wait — the frame is about the whole session, not this patient.
- `token.called` whose `appointment_id` is this appointment means **"it's your turn"**.
- `status: "paused"` / `queue_state: "on_break"` → show "doctor on a break".

### 15.2 `/ws/patient/inbox` — notifications

| `type` | `data` |
|---|---|
| `notification.created` | `{ "id": "uuid", "kind": "confirmation", "title": "Appointment confirmed" }` |
| `unread_count` | `{ "n": 4 }` |

Update the bell badge from `unread_count`; re-fetch the list for the full notification.

---

## 16. Error codes

Codes the patient app can receive. `code` is the contract; `message` is for display and may
change.

| HTTP | `code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | bad field (`errors`), unknown query parameter, missing `Idempotency-Key` / `If-Match` / device fingerprint |
| 400 | `PAYMENT_SIGNATURE_INVALID` | payment verify failed |
| 401 | `AUTH_INVALID_CREDENTIALS` | wrong password |
| 401 | `AUTH_TOKEN_EXPIRED` | access token expired → refresh |
| 401 | `AUTH_TOKEN_INVALID` | no / malformed token; used or expired reset token |
| 401 | `AUTH_SESSION_REVOKED` | session ended → sign in again |
| 401 | `AUTH_PRINCIPAL_MISMATCH` | token is not a patient token |
| 401 | `AUTH_OTP_INVALID` / `AUTH_OTP_EXPIRED` | wrong / expired code |
| 403 | `ACCOUNT_BLOCKED` | account blocked by Medibook |
| 403 | `PERMISSION_DENIED` | not allowed |
| 404 | `NOT_FOUND` | unknown, or not the user's own |
| 405 | `METHOD_NOT_ALLOWED` | |
| 409 | `CONFLICT_VERSION` | stale `If-Match` |
| 409 | `IDEMPOTENCY_CONFLICT` | key reused for a different request, or the first is still running |
| 409 | `SLOT_UNAVAILABLE` | slot cannot be booked |
| 409 | `TOKEN_RANGE_EXHAUSTED` | no tokens left in the session |
| 409 | `APPOINTMENT_NOT_ACTIONABLE` | action not allowed in the appointment's current state |
| 409 | `TOKEN_ALREADY_CALLED` / `TOKEN_CANCEL_WINDOW_CLOSED` | patient can no longer cancel |
| 409 | `PAYMENT_ALREADY_CAPTURED` | already paid |
| 409 | `COUPON_INVALID` / `COUPON_EXPIRED` / `COUPON_MIN_ORDER` / `COUPON_USAGE_CAP` | coupon refused |
| 409 | `UNDER_AGE` | account holder under 18 |
| 409 | `PERSON_IS_SELF` / `PERSON_HAS_APPOINTMENTS` | family member cannot be removed |
| 409 | `FILE_IN_USE` | file still referenced |
| 409 | `STATE_CONFLICT` | generic "not in a state that allows this" |
| 413 | `FILE_TOO_LARGE` | |
| 415 | `FILE_TYPE_NOT_ALLOWED` | |
| 422 | `OTP_ATTEMPTS_EXCEEDED` | 3 wrong codes — resend |
| 423 | `AUTH_LOCKED_OUT` | 5 failed logins — locked 1 hour |
| 429 | `RATE_LIMITED` | slow down; see `Retry-After` |
| 501 | `NOT_IMPLEMENTED_YET` | feature switched off on the server |
| 503 | `PROVIDER_UNAVAILABLE` | payment gateway / storage down — retry later |

An unexpected server fault is a plain `500` without this envelope; show a generic error.

---

## 17. Enums

| Enum | Values |
|---|---|
| Appointment `status` | `pending_payment`, `pending_approval`, `scheduled`, `checked_in`, `in_consultation`, `completed`, `cancelled`, `no_show` |
| Appointment `payment_status` | `unpaid`, `pending`, `paid`, `refunded`, `failed` |
| Appointment `source` | `online`, `walk_in` |
| `cancelled_by` | `patient`, `hospital`, `system` |
| Payment order `status` | `created`, `attempted`, `paid`, `failed`, `expired`, `cancelled` |
| Payment `method` | `upi`, `card`, `netbanking`, `wallet`, `emi`, `paylater`, `cash`, `pos`, `other` |
| Payment `status` | `captured`, `failed`, `refunded` |
| Refund `status` | `requested`, `processing`, `processed`, `failed` |
| Slot `state` | `available`, `held`, `booked`, `blocked`, `past` |
| Availability session `state` | `available`, `full`, `closed` |
| Session `status` | `scheduled`, `open`, `paused`, `closed`, `cancelled` |
| Session `queue_state` | `available`, `consulting`, `waiting`, `on_break` |
| Doctor `status` | `active`, `on_leave` |
| Person `relation` | `self`, `spouse`, `child`, `parent`, `sibling`, `other` |
| `gender` | `female`, `male`, `other`, `undisclosed` |
| `blood_group` | `A+`, `A-`, `B+`, `B-`, `AB+`, `AB-`, `O+`, `O-` |
| Document `doc_type` | `lab_report`, `prescription`, `scan`, `discharge_summary`, `invoice`, `vaccination`, `other` |
| File `status` | `pending`, `uploaded`, `scanning`, `clean`, `infected`, `sealed`, `scan_failed` |
| Upload `purpose` (patient) | `medical_document`, `insurance`, `ticket_attachment`, `avatar` |
| Notification `kind` | `confirmation`, `reminder`, `cancellation`, `payment`, `queue`, `general` |
| Ticket `category` | `billing`, `technical`, `onboarding`, `feature_request`, `complaint`, `other` |
| Ticket `priority` | `low`, `normal`, `high`, `urgent` |
| Ticket `status` | `open`, `in_progress`, `waiting_on_requester`, `resolved`, `closed` |
| User `status` | `active`, `blocked`, `deleted`, `pending_deletion` |
| Deletion request `status` | `requested`, `cooling_off`, `verifying`, `processing`, `completed`, `rejected`, `no_data`, `withdrawn` |
| Device `platform` | `android`, `ios`, `web` |
| Legal `slug` | `terms`, `privacy`, `guidelines` |

Suggested mapping to the app's three status pills: **Confirmed** ← `scheduled`, `checked_in`,
`in_consultation` (+ `pending_approval` as "Awaiting confirmation", `pending_payment` as "Payment
pending"); **Completed** ← `completed`; **Cancelled** ← `cancelled`, `no_show`.

---

## 18. Not available in the backend

<!-- NOT-AVAILABLE -->
