# Integration gaps — profile, support, content (app-config / legal / FAQ / ambulance)

Slice: `lib/features/profile/`, `lib/features/support/`, `lib/features/common/{cached,mutation}/`.
Verified 2026-09-30 against `https://62.171.151.149:8443` with the test account
(`anita.menon@lakeshore.medibook.example.com`). Every endpoint in §3, §4.9, §5.2–§5.9,
§6.1–§6.3, §13 and §14 was hit with curl first; the shapes matched the doc exactly.

## Not verifiable on the shared account (by instruction) — implemented from the doc + error responses

| Feature | What was sent | What came back | What the app does |
|---|---|---|---|
| Phone change §5.3 | `POST /me/phone/change/start {"new_phone_e164":"12"}` and `{"new_phone_e164":"+919705571090"}` (the account's own number) | `400 VALIDATION_ERROR` on `new_phone_e164` ("Enter a valid E.164 phone number." / "This is already your number."); `POST …/confirm-old {"code":"0000"}` with no open challenge → `401 AUTH_OTP_INVALID`, `meta.attempts_remaining: 0` | Full three-step flow on `/profile/phone` (`PhoneChangeController`), all three calls with `withDeviceFingerprint: true`, 10-minute countdown, resend via `otp/resend`, expiry → back to step 1. The happy path (real OTP delivery) was **not** executed on the test account. |
| Alternate phone §5.4 | `POST /me/alternate-phone {"phone_e164":"abc"}` | `400 VALIDATION_ERROR` on `phone_e164` | Sheet on `/profile/edit`; set/remove merge the returned bare `User` into the session (profile fields kept). Happy path not executed. |
| Release §5.8 | `POST /me/persons/{minor}/release {"phone_e164":"+919812345678"}` + Idempotency-Key; and `{}` | `409 UNDER_AGE` ("The person must be 18 or older to be released."); `400 VALIDATION_ERROR` on `phone_e164` | Two-step sheet on the dependant edit screen for 18+ dependants (`ReleaseController`), Idempotency-Key minted once and reused on retry, `UNDER_AGE`/`STATE_CONFLICT` worded. `release/verify` happy path not executed. |
| Delete account §5.6 | **Not called** (`POST /me/deletion-requests` would freeze the shared account). `DELETE /me/deletion-requests/DSR-0000-000000` → `404 NOT_FOUND`; `POST /me/reactivate` → `409 STATE_CONFLICT` ("There is no pending deletion to cancel."). `GET /me/deletion-requests` → empty page. | see left | `AccountDeletionController`: request (Idempotency-Key reused on retry, cleared on success, then `/me` re-read), cooling-off card on Profile while `status == pending_deletion` with Withdraw + Reactivate. Request/withdraw happy paths not executed. |

## Backend behaviour the UI had to work around

1. **No "self" person on the test account** (`GET /me/persons` → `[]` before probing) and
   `POST /me/persons {"relation":"self"}` → `400 VALIDATION_ERROR` "A dependant cannot have
   relation 'self'." The family-members screen shows an explicit "No patient record for you
   yet" card instead of the account holder's card; `selfPersonIdProvider` is published as
   `null`; dependants can still be added.
2. **`PATCH /patient/me` cannot change email** (§5.2 / §18). Email is shown read-only on
   `/profile/edit` with that said; the old editable email field is gone.
3. **"Available for Donation" toggle removed** from Profile — there is no backend field
   (§18); a switch that persisted nothing was a fake success.
4. **Support `support_contacts` only carries `phone_e164`** (`{"phone_e164":"+914847100000"}`);
   the seeded `support@medibook.app` / `privacy@medibook.app` addresses and "support hours"
   are no longer shown. The model has an optional `email` for when the backend adds one.
5. **Ticket attachments skipped.** `attachment_file_ids` is accepted by the entity/API but no
   picker/upload is wired — file upload lives in `lib/features/common/attachments/` (records
   agent). Tickets and replies are sent without attachments.
6. **Relation labels**: the API has five relations (`spouse|child|parent|sibling|other`) and
   no display-label field. The app's richer labels ("Son", "Mother", "Wife" …) are *derived*
   from relation + gender (`PersonRelation.labelFor`) rather than stored.
7. **Legal `version` is an `int`** on the wire; the seed's `LegalDocument.version` was a
   `String`. The auth consent controller reads `terms?.version ?? ''` from the seed provider —
   repointing it to `legalDocumentProvider(slug).value?.version` needs a `toString()`/int
   change on the auth side.
8. **`GET /patient/faqs`** returns short one-line `answer_md` strings on this server; the
   renderer supports `#`/`##` headings, `-`/`*` bullets, paragraphs and `**bold**` (no
   markdown package).

## Test rows created on the shared account

| Row | Id | State |
|---|---|---|
| Address "Home" → "Home 2" | `01a0f15b-30ca-7000-8a9d-8f3d0763118e` | **deleted** |
| Emergency contact "Ravi Nair" | `01a0f15b-3ffb-7332-b150-99d7ac06ab90` | **deleted** |
| Dependant "Test Dependant" (relation other, DOB 2015-03-02) | `01a0f15b-4563-7be1-a6ab-2cff2f8f3165` | **deleted** |
| Consent `terms` v1 | `01a0f15b-4f6b-7883-9316-a4d59858c9a3` | **left** (no delete endpoint) |
| Support ticket "Integration test ticket" + 1 message | `01a0f15b-55bc-75f3-9c3a-b48ebebc47a2` / `TKT-2026-0019` | **left** (no delete endpoint; safe to close) |
| Sessions | one older curl session `01a0f15a-825d-77b2-9279-52f1c2f64863` | **revoked** (verifying `DELETE /auth/sessions/{id}` → 204) |

`PATCH /patient/me` was **not** used to change anything: the only PATCH probes were
"no If-Match" (→ 400 on `If-Match`), an under-age DOB (→ `409 UNDER_AGE`, nothing written)
and a stale `If-Match: "1"` (→ `409 CONFLICT_VERSION`, `meta.current: 2`). The account is
left at `user.version = 2`, `profile.version = 2`, `gender = female`.

A person `Integration TestDep…` (`01a0f17f-6ff0-7722-96eb-e8e879609108`) exists on the
account that this slice did **not** create; `DELETE` answers `409 PERSON_HAS_APPOINTMENTS`,
so it was left alone (it belongs to the booking slice's verification).

## Wiring other slices must do

- `appConfigProvider` (`lib/features/support/application/providers/app_config_provider.dart`)
  should be read once at launch (`ref.read(appConfigProvider)` in `app.dart`/bootstrap) so the
  fetch starts before the first screen that needs `otp_length` / `legal_versions`.
- `features/auth/presentation/controllers/consent_form_controller.dart` still imports the seed's
  `legalDocumentProvider`; repoint to
  `package:medibook/features/support/application/providers/support_provider.dart` (see gap 7).
- `features/dashboard/presentation/screen/ambulance_screen.dart` still imports the seed's
  `ambulanceProvidersProvider` and `primaryEmergencyContactProvider`; repoint to
  `ambulanceProvidersProvider(AmbulanceFilter)` in `support_provider.dart` and
  `primaryEmergencyContactProvider` in `profile/application/providers/profile_provider.dart`.
- `test/goldens/screens_golden_test.dart` renders `ProfileScreen`; it will now need
  `authRepositoryProvider` + the three profile repository providers overridden with fakes
  (see `test/features/profile/profile_test_support.dart`).
