# Integration core — the contract every feature builds on

**Status:** live against `https://62.171.151.149:8443` (self-signed TLS; `Env.allowBadCertificate` defaults to `true` outside prod).
**Backend contract:** `docs-flutter/FLUTTER_API_INTEGRATION.md` is the source of truth for every path, body and response. This file only describes the app-side plumbing that already exists so a feature never re-implements it.

## 1. What is already built (do not duplicate)

| Concern | Where | Use it as |
|---|---|---|
| HTTP client | `core/network/api_client.dart` → `ApiClient` (interface), `DioApiClient` (prod), `UnimplementedApiClient` (tests) | `ref.watch(apiClientProvider)` (declared in `features/auth/application/providers/auth_provider.dart`) |
| Paths | `core/network/endpoints.dart` → `Endpoints.*` | never spell a path string in a feature |
| Page envelope | `Page<T>.parse(response.data, fromJson)` in `api_client.dart` | every list endpoint (§1.6) |
| Idempotency | `IdempotencyKeys.mint()`; pass `idempotencyKey:` to `client.post(...)` | the six §1.8 calls; reuse the same key when retrying the same action |
| `If-Match` | `client.patch(path, body: …, ifMatch: row.version)` / `client.delete(..., ifMatch:)` | every §1.9 PATCH |
| Device fingerprint | `client.post(..., withDeviceFingerprint: true)` | every OTP call (§1.3) — already done for auth |
| Errors | `core/error/failure.dart` — sealed `Failure` with `apiCode` + `meta`; `ConflictFailure` (409/413/415/422), `RateLimitedFailure` (429), `UnauthorizedFailure(sessionExpired: false)` for wrong credentials | branch on `failure.apiCode == ApiErrorCodes.slotUnavailable` (constants in `core/network/network_exceptions.dart`), never on message text |
| Error mapping | `NetworkExceptions.toFailure(error, stack)` | call it in the repository's `catch`; nothing above the repository sees a `NetworkException` |
| 3-layer cache | `core/storage/cache/cached_fetcher.dart` → `CachedFetcher.fetch(request, decode)` (stream: cached first, then network) / `.get(...)` (one shot) / `.invalidate()` after a mutation | `ref.watch(cachedFetcherProvider)`; GETs only; the `decode` callback is the Scenario-10 validation pipeline — throw on a bad shape and nothing is cached |
| Cache freshness | `CachedResult.source` (memory/hive/network), `.isStale` (>24 h → amber bar), `.revalidating` (→ "updating…") | render the HIVE-spec affordances from these |
| Offline | `core/network/connectivity/connectivity_monitor.dart` → `isOnlineProvider` | persistent offline indicator; the fetcher already waits for reconnect |
| WebSockets | `core/network/realtime/ws_client.dart` → `WsClient(url: '${Env.wsBaseUrl}${Endpoints.wsSession(id)}', accessToken: …)`; frames stream; close reasons 4401/4408 | owned by a Riverpod notifier that reconnects with a fresh token; never reconnect inside `WsClient` |
| Secure store / Hive | `core/storage/secure_store.dart`, `app/bootstrap/hive_init.dart` (`HiveInit.store`, boxes in `core/storage/hive/boxes.dart`) | only `infrastructure/data_sources/local/*_local_ds.dart` may touch them |
| Session | `authProvider`, `currentUserProvider`, `selfPersonIdProvider`, `isAuthenticatedProvider` | the `User` entity now mirrors the backend (`firstName`, `lastName`, `phoneE164`, `hasPassword`, `version`, profile fields merged from `/me`) |
| Money / dates | `core/utils/money.dart` (`Money.paise(int)`), `core/utils/date_utils.dart` | amounts arrive as integer `*_paise`; never compute fees in the app (§8.3) |

The auth feature (`features/auth`) is the reference implementation of the four layers against this core — copy its shape.

## 2. Feature layout (QA Prompt 6, `docs-flutter/Folder structure - structure.csv`)

```
features/<name>/
  domain/entities/*.dart            plain immutable classes, final fields, no JSON, no Flutter
  domain/repositories/*_repository.dart   abstract interface class … (no bodies)
  infrastructure/data_sources/remote/*_api.dart    HTTP only: Endpoints + ApiClient → decoded JSON (Map/Page)
  infrastructure/data_sources/local/*_local_ds.dart Hive/secure store only (if the feature caches anything beyond CachedFetcher)
  infrastructure/repositories/*_repository_impl.dart  implements the contract; JSON→entity mapping lives here (or a *_mappers.dart beside it); wraps errors with NetworkExceptions.toFailure
  application/states/*_state.dart   immutable, copyWith
  application/providers/*_provider.dart   <feature>ApiProvider, <feature>RepositoryProvider (returns the abstract type), StateNotifier/AsyncNotifier providers
  application/usecases/*.dart       optional
  presentation/screen|components (controllers live in application/providers) — rewire, keep the design
```

Rules the audits enforce: `FutureProvider`/`AsyncNotifier` for reads, `StateNotifier`/`Notifier` for mutations; `autoDispose` on per-screen state, not on app-lifetime stores; no `ref.watch` in callbacks; no `BuildContext`/navigation/toast in a notifier; no `Hive`/`Dio`/`*Api` import outside `infrastructure/`; no hardcoded pixels (`.w .h .sp .r`); every async provider catches and maps to `Failure`.

## 3. Wire facts that trip people up

- Success bodies are bare (no `{data:}`); only errors have the envelope. Lists are `Page<T>`; `GET /patient/faqs` and `GET /patient/search` are plain objects.
- **Unknown query parameters are a 400.** Send only what the endpoint lists; drop nulls (the client already strips `null` values).
- Dates: `scheduled_date`, slot `date`, availability dates are **hospital-local** `YYYY-MM-DD`; instants are UTC ISO — show them in the hospital's `timezone` (`Asia/Kolkata`), not the device's.
- `*_file_id` are ids; resolve with `GET /shared/files/{id}/url` (token required). Cache images by file id.
- Ratings/coordinates are decimal **strings** or null.
- Patient accounts have a **self person** (`is_self: true`, first in `GET /me/persons`). The staff account `anita.menon@…` has none — "book for myself" must still handle `selfPersonIdProvider == null` by asking the user to add a family member; never invent a person id.
- The hospital's zone is on the appointment (`hospital.timezone`) and on the slot grid (`timezone`). Pass it to `HospitalTime.*(…, timezone:)` / `SlotLabels.*(…, timezone:)`; offsets come from `HospitalZones`.
- A bad or expired token is refused at the WebSocket **handshake with HTTP 403** (`WsHandshakeRefused`), not closed with 4401: refresh the session once, then reconnect.
- §10.1's tab queries lose a past visit the desk never closed (`scheduled`, not in `bucket=upcoming`). The Completed tab is `bucket=past` + the non-cancelled statuses (`AppointmentListQuery`).
- `PATCH /patient/documents/{id}` requires `If-Match`.
- Backend sends `ETag`, not `Last-Modified`; the fetcher uses `If-None-Match`.

## 4. Verify before you build

For each section: hit the endpoint with `curl -sk … -H "Authorization: Bearer $T"` using a seeded **patient** account from `docs-flutter/users.json` (password `seed_password_123`, `POST /api/v1/patient/auth/login/password {identifier,password}` — e.g. `+919808683257` or `asha.rao@patients.medibook.example.com`), confirm the response matches the doc, then implement. If the backend does not satisfy a requirement (missing endpoint, wrong shape, seed data absent, blocked by a business rule), do **not** work around it silently: record it in your slice's gaps file under `docs/integration-gaps/` (round 2: `docs/FLUTTER_INTEGRATION_GAPS_ROUND_2.md`) with the request you sent, the response you got, and what the UI does instead.

Do not create test data you cannot remove (bookings on real slots, paid orders, uploaded files) unless the section cannot be verified otherwise; if you must, note the ids in the gaps file.

## 5. Tests

- Widget/golden tests that pump a real screen use `test/support/offline_overrides.dart`
  (`ProviderScope(overrides: offlineOverrides())`): an offline `CachedFetcher` over an in-memory
  store and no-op WebSocket factories, so reads fail fast with `NetworkFailure` and no timers are
  left for `pumpAndSettle`. Set `HiveInit.store = InMemoryLocalStore()` in `setUp` yourself.
- Tests that assert on loaded data override the feature's `*RepositoryProvider` with a fake
  (`test/features/*/support`), never the fetcher.
- Read `AsyncValue`s with `valueOrNull`; Riverpod 2's `.value` rethrows on `AsyncError` and
  crashes the build.
- The live suite is `test/integration/live_backend_test.dart` (opt-in, see README).
