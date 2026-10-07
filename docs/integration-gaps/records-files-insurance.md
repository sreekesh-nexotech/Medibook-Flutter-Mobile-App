# Integration gaps — records, files (attachments) and insurance

Slice: `lib/features/common/attachments/`, `lib/features/common/persons/`,
`lib/features/common/pagination/`, `lib/features/records/`, `lib/features/insurance/`.
Backend: `https://62.171.151.149:8443` (test account `anita.menon@lakeshore…`).
Verified 2026-09-30 with `curl -sk`.

## 1. The presigned storage host does not resolve — the upload round trip cannot complete

**Request** `POST /api/v1/shared/files/uploads`
`{"purpose":"medical_document","mime":"application/pdf","size_bytes":303,"original_name":"test.pdf"}`

**Response** `201`

```json
{"file_id":"01a0f15c-268d-7362-b102-0e4aa7118343",
 "upload_url":"https://storage.fake.local/medibook-private/patient/01a0ee28-…/medical_document/01a0f15c-…?X-Op=put&X-Expires=300",
 "method":"PUT","headers":{"Content-Type":"application/pdf"},
 "expires_at":"2026-09-30T08:14:03.415298+00:00","file":{…"status":"pending"…}}
```

**Step 2** `PUT https://storage.fake.local/…` with exactly `Content-Type: application/pdf` and the
303-byte PDF → curl exit `000` (DNS: `storage.fake.local` does not exist). The same path on the API
host answers nginx `405 Not Allowed`.

**Step 3** `POST /shared/files/{id}/complete` → `400 VALIDATION_ERROR`
`{"errors":{"file":["The object has not been uploaded yet."]}}`. Polling `GET /shared/files/{id}`
for 30 s stayed `pending`.

**Consequence.** No client can obtain a `clean` file against this environment, so:
* the ClamAV scan time could not be measured;
* `POST /patient/documents` could not be exercised with a real file (it answers
  `400 VALIDATION_ERROR` on `file_id`: "Must be your own medical_document upload that passed the
  scan." — verified with the pending id);
* `POST /patient/me/insurance-policies/{id}/documents` likewise answers `400` on `file_id`
  ("Must be one of your own insurance files.");
* `GET /shared/files/{id}/url` on the pending file → `404 NOT_FOUND` (documented: not `clean`);
* the document detail / download-url / edit / delete screens are wired per contract but were
  verified only with `404` on unknown ids and with the scripted-client tests.

**What the app does.** The full 3-step flow is implemented in
`FileUploadServiceImpl` (`infrastructure/repositories/file_upload_service_impl.dart`): client-side
allowlist + 10 MB cap → `POST uploads` → `PUT` through a **separate plain Dio** (`DioStorageUploader`,
no bearer, no base URL, exactly the ticket's headers) → `complete` → poll with 1 s, 2 s, 3 s, 4 s,
5 s… steps capped at 30 s → typed `UploadClean` / `UploadRejected` / `UploadScanTimedOut`. A DNS
failure on step 2 surfaces as `NetworkFailure` in the attachment tile with "Try again". The
backend must expose a reachable storage host (or a signed-PUT proxy on the API host) before this can
work end to end.

**Cleanup.** The pending file was deleted: `DELETE /shared/files/01a0f15c-268d-7362-b102-0e4aa7118343`
→ `204`; `GET` afterwards → `404`. Nothing was left behind.

## 2. Verified endpoints (all matched the contract)

| Call | Result |
|---|---|
| `GET /patient/documents` | `200` empty page `{results:[],page:1,page_size:25,total:0,has_next:false}` |
| `GET /patient/documents?sort=-document_date&page=1&page_size=25` | `200` |
| `GET /patient/documents?doc_type=lab_report&q=x&date_from=…&date_to=…` | `200` |
| `GET /patient/documents?per_page=5` | `400 VALIDATION_ERROR` `per_page: Unknown query parameter.` (as documented) |
| `GET /patient/documents?doc_type=xray` | `400` "Must be one of: lab_report, prescription, scan, discharge_summary, invoice, vaccination, other." |
| `GET /patient/documents/{unknown}` / `…/download-url` | `404 NOT_FOUND` |
| `POST /shared/files/uploads` mime `text/plain` | `415 FILE_TYPE_NOT_ALLOWED` `meta.allowed=[pdf,jpeg,png,heic]` |
| `POST /shared/files/uploads` 20 MB | `413 FILE_TOO_LARGE` `meta.max_bytes=10485760` |
| `GET /patient/me/persons` | `200`, 2 persons (both `is_self:false` — the account has **no self person**) |
| `GET /shared/app-config` | `200`, `feature_flags_public: {"patient_app.insurance": true, …}` |
| `POST /patient/me/insurance-policies` (full §6.4 body) | `201` with `documents: []`, `version: 1` |
| `GET /patient/me/insurance-policies?sort=-valid_to` | `200`, rows **without** `documents` |
| `GET /patient/me/insurance-policies?person_id=…&sort=valid_to` | `200` |
| `GET /patient/me/insurance-policies/{id}` | `200` with `documents` |
| `PATCH …/{id}` without `If-Match` | `400 VALIDATION_ERROR` on `If-Match` (required, as documented) |
| `PATCH …/{id}` with `If-Match: "1"` | `200`, `version: 2` |
| `DELETE …/{id}` | `204`; list empty afterwards |

Test rows created and removed: policies `01a0f15c-29cc-7521-bccd-905f75abaa29` and
`01a0f15e-0b15-7233-9c76-30663fcf21ab` (both deleted, `204`); file
`01a0f15c-268d-7362-b102-0e4aa7118343` (deleted, `204`). No test dependant was created: without a
`clean` file a document cannot be created, so there was nothing to file under one. The two
"Test Dependant" persons on the account (`01a0f15b-4563-…`, `01a0f15b-4ac4-…`) pre-existed and were
left untouched.

## 3. Behavioural gaps and decisions

* **`doc_type` is single-valued.** §11.2 lists it as a plain filter (not *multi*), so the type
  facet in the filter sheet is single-select (tapping the active chip clears it). The former
  multi-select set could not be expressed on the wire.
* **No self person on the test account.** Every document needs a `person_id`; the upload form
  defaults to the self person when `selfPersonIdProvider` is set, otherwise to the only person on
  the account, and shows "Add a family member first" (linking to `/dependants`) when
  `GET /patient/me/persons` is empty. Persons are read through the new read-only
  `features/common/persons` subfeature (`personSummariesProvider`), not the profile feature.
* **Linking to an appointment.** Wired to the appointments slice's
  `appointmentsForLinkingProvider` (`FutureProvider<List<LinkableAppointmentRef>>`);
  `records/presentation/controllers/linkable_appointments_provider.dart` adapts it to the
  `LinkableAppointment` class the form and filter use and yields an empty list while it loads (the
  pickers then only offer "Not linked"). No `core/mock_data` import remains in this slice. Not
  verified live: the test account's appointments list belongs to the appointments slice.
* **Insurance feature flag.** `insuranceEnabledProvider` reads the support slice's
  `appConfigProvider` (`feature_flags_public['patient_app.insurance']`). Deliberately **enabled**
  while the config has not loaded and when the server omits the key — the support slice's own
  `publicFeatureFlagProvider` answers `false` in both cases, which would hide the locker for the
  first moments of every launch. The live server returns `true`.
* **Share removed.** The document detail screen has View and Download only (both fetch a fresh
  10-minute `download-url` and hand it to `url_launcher` with `LaunchMode.externalApplication`);
  documents are patient-only by design (§11).
* **Signed URLs are never cached.** `FileUrlResolverImpl` memoises in memory only until 30 s before
  `expires_at`; `download-url` is fetched on every tap and not memoised at all (§11.3).
* **Cache invalidation is coarse.** `CachedFetcher.invalidate(pathPrefix:)` clears the whole
  response cache (keys are hashes); every mutation in this slice therefore drops all cached GETs.
  They rebuild at 304 cost.
* **Documents used by other features.** `appointments/presentation/screen/appointment_detail_screen.dart`
  and `profile/presentation/screen/profile_screen.dart` still import the mock
  `documentsStoreProvider` / `insuranceStoreProvider`; those belong to other slices. Nothing in
  `core/mock_data` was deleted.

## 4. Platform permissions needed (not edited — platform folders are out of scope)

`image_picker` (camera / photo library) needs, in `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Medibook uses the camera to photograph a report or policy document you want to save.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Medibook needs access to your photos to attach a report or policy document.</string>
```

`ios/Runner/Info.plist` currently has neither key (checked). `file_picker` needs no iOS key.

On Android, `image_picker` needs nothing for API 21+ (it uses the system picker). `url_launcher`
needs the browser to be queryable on Android 11+: the existing `<queries>` block in
`android/app/src/main/AndroidManifest.xml` lists only `PROCESS_TEXT` and `DIAL`, so add inside it:

```xml
<intent>
    <action android:name="android.intent.action.VIEW"/>
    <data android:scheme="https"/>
</intent>
```

Without it `launchUrl(mode: LaunchMode.externalApplication)` returns `false` on Android 11+ and the
app shows "No app on this device could open the file".
