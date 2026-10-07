# Integration gaps — discovery, booking, payment (dashboard, search, booking, payment slices)

Verified on 2026-09-30 against `https://62.171.151.149:8443` with the test
account `anita.menon@lakeshore.medibook.example.com`. Every endpoint in the
slice was hit with `curl` before it was built; this file records what the
backend, the seed data or the document did **not** give the app, with the
request sent, the response received and what the UI does instead.

## Test data created (record for clean-up)

To see the real `201` of `POST /patient/appointments` — which the account
could not produce, having no person — one dependant and one booking were
created. The booking is unpaid and self-cancels ~1 minute after its
`booking_deadline_at` (§9.6); the slot goes back.

| What | Id |
|---|---|
| Person (`POST /patient/me/persons`, relation `other`) | `01a0f17f-6ff0-7722-96eb-e8e879609108` ("Integration TestDependant") |
| Appointment (`POST /patient/appointments`) | `01a0f17f-760d-7ef0-bd32-51372f1d883b`, `booking_ref LKSB-2609-00183`, slot `01a0ee29-20a5-7382-9ad0-fa764f0389ee` on `2026-10-29`, Dr. Suresh Pillai |
| Payment orders | `01a0f17f-7619-78e2-b724-08f08fb899dc` (attempt 1), `01a0f180-031f-7ed0-bc27-82ad9a64b7f2` (attempt 2, from `POST …/retry`) |

`DELETE /patient/me/persons/{id}` was attempted after the auto-cancel; see the
last section for the outcome.

## 1. No self person on the test account (seed)

```
GET /patient/me/persons  → 200 {"results":[],"page":1,"page_size":25,"total":0,"has_next":false}
```

`selfPersonIdProvider` is null and the list is empty, so "book for myself" is
impossible. **UI:** step 3 ("Appointment for") shows *"Your account has no
patient record yet, so we cannot book 'for myself'. Add yourself or a family
member first."* with an **Add a family member** button to `/dependants/edit`.
No person id is ever invented. When persons exist, the self person (or the
only person) is pre-selected; otherwise the patient must pick.

## 2. Razorpay `key_id` is empty on the staging backend (backend config)

```
POST /patient/appointments → 201 … "payment_order": { …, "gateway_order_id": "order_fake2e3bb195c9ac4b", "key_id": "", … }
GET  /patient/payments/orders/01a0f17f-7619-78e2-b724-08f08fb899dc → 200 … "key_id": ""
```

The gateway order id is a `order_fake…` stub and `key_id` is `""`, so the
Razorpay SDK cannot be opened (it would fail with `INVALID_OPTIONS`). There
are no Razorpay test keys in the app either. **UI:** `PaymentFlowController.pay`
refuses an order with an empty `key_id`/`gateway_order_id` before touching the
SDK and shows *"Online payment is not set up for this hospital yet…"*; the
SDK path (`RazorpayCheckoutGateway`) is wired and unit-tested through the
`CheckoutGateway` contract but could not be exercised end-to-end.
`POST …/verify` was exercised only with a bogus signature:

```
POST /patient/payments/orders/{id}/verify {"razorpay_payment_id":"pay_test_bogus","razorpay_signature":"deadbeef"}
→ 400 {"code":"PAYMENT_SIGNATURE_INVALID","message":"Payment signature verification failed."}
```

which the app renders as a failed payment with a retry, as §9.3 asks.

## 3. Booking reference and token formats differ from the document (doc)

```
201 … "booking_ref": "LKSB-2609-00183", "token_label": "A001", "token_no": 1
```

The document's examples are `MB-2026-000124` / `T-026`; the live hospital
issues `LKSB-2609-00183` / `A001`. Per §1.11 both are opaque per-hospital
text, so the app now renders them verbatim. The old `AppTokens.normalize`
(which rewrote everything to `T-NNN`) no longer re-spells labels; the
`BookingRefs` minting helper was removed — nothing in this slice mints a
reference or a token any more.

## 4. `GET /patient/search?q=` bounds (doc → enforced)

```
GET /patient/search?q=c        → 400 VALIDATION_ERROR {"q":["Ensure this field has at least 2 characters."]}
GET /patient/search?q=aaaa…(101) → 400 VALIDATION_ERROR {"q":["Ensure this field has no more than 100 characters."]}
```

**UI:** `SearchQueryRules` never sends fewer than 2 characters (the screen
says "Type at least 2 characters") and truncates at 100; input is debounced
300 ms.

## 5. Distance sort needs coordinates the app does not have (product gap)

```
GET /patient/hospitals?sort=distance_km → 400 {"sort":["Sorting by distance requires lat and lng."]}
```

There is no device-location plumbing in this build (no geolocation package,
none may be added by this slice). **UI:** the hospital list offers Name /
Highest rated / Soonest slot; `HospitalsQuery` only sends `sort=distance_km`
when `lat`/`lng` are present. Home's "Hospitals Near You" is therefore the
directory in name order (first two rows), not a distance sort — the label is
the design's, the data is honest. `distance_km` on cards is shown only when
the response carries it.

## 6. Images need a token (doc §11.4, confirmed)

```
GET /shared/files/01a0ee28-84da-7f60-9e22-3323121690fa/url               → 401 AUTH_TOKEN_INVALID
GET /shared/files/01a0ee28-84da-7f60-9e22-3323121690fa/url  (bearer)     → 200 {"url":"https://storage.fake.local/…","expires_at":"…+00:00"}
```

The signed URL points at `storage.fake.local`, which does not resolve, so no
image actually loads on staging even when signed in. **UI:** `AppFileImage`
resolves `*_file_id` through the shared `fileUrlResolverProvider`
(`features/common/attachments`, created by the records agent — this slice
did not add a second resolver) and falls back to tinted initials / a
first-aid glyph on any failure or when signed out. All seed hospitals have
`logo_file_id: null` and `cover_file_id: null`; two of four Lakeshore doctors
have a `photo_file_id`.

## 7. Banners: no platform-wide list, seed has one per hospital (doc §18)

```
GET /patient/hospitals/01a0ee28-80b3-7162-9efe-032fb9e1b6af/banners → 200 1 banner, "image_file_id": null, "cta_label": null, "cta_target": null
```

**UI:** Home stitches the first five visible hospitals' banners
(`homeBannersProvider`); a banner opens its hospital. Banners have no colour
on the wire, so the design's gradients are alternated per card. `cta_target`
deep links are not followed yet (no banner in the seed has one).

## 8. `GET /patient/departments` has no icon; hospital departments' `icon` is null (seed/doc)

```
GET /patient/departments → {"code":"cardiology","name":"Cardiology","hospital_count":1}, …
GET /patient/hospitals/{id}/departments → … "icon": null …
```

**UI:** `departmentIconFor(code)` maps the known codes (`cardiology`,
`orthopaedics`, `dermatology`, `gynaecology`, `paediatrics`, `ent`, …) to the
design-system marks and falls back to the generic mark.

## 9. Hospital time zone is only on the detail (doc §1.11)

Slot and availability instants are UTC; the zone comes from
`GET /patient/hospitals/{id}` (`"timezone": "Asia/Kolkata"`). `core/utils/
date_utils.dart` has no zone helper and no timezone package is in the build,
so `features/booking/domain/hospital_clock.dart` shifts a handful of
fixed-offset zones (`Asia/Kolkata` and neighbours) exactly and falls back to
the device zone for anything else. **Core request:** a zone-aware formatter
in `core/utils/date_utils.dart` (or the `timezone` package) so every feature
formats hospital-local time the same way.

## 10. The token-card `date`/`start_time` are hospital-local strings (doc, fine)

```
GET /patient/appointments/{id}/token-card → "date":"2026-10-29","start_time":"11:45","end_time":"12:00","session":{"label":"Morning OPD",…}
```

Rendered verbatim on `/success`. `qr_payload` equals the booking reference;
no QR package is in the build, so it is shown as the "Desk code" text.

## 11. Idempotent replay and retry behave as documented (confirmed, no gap)

```
POST /patient/appointments (same key, same body) → 201, header idempotent-replayed: true
POST /patient/payments/orders/{id}/retry         → 201 new order, attempts: 2, same expires_at
GET  /patient/doctors/{id}/slots?date=2026-10-29 → the booked slot now "held"
```

## 12. Home "Your Token" card still reads the appointments feature's mock provider (handover)

`lib/features/appointments/application/providers/appointments_provider.dart`
with `nextUpcomingAppointmentProvider` did not exist when this slice was
finished, so `HomeScreen` still reads `firstUpcomingAppointmentProvider` from
`features/appointments/presentation/controllers/appointments_controller.dart`
(seeded data). The card takes plain strings (`token`, `doctor`, `when`), so
the appointments agent only has to swap the provider read in
`home_screen.dart` (one `ref.watch`).

## 13. Live queue screen left to the appointments agent

`features/booking/presentation/screen/queue_screen.dart` and
`components/queue_progress_card.dart` still read the seeded
`queueStatusProvider`; the live queue is `GET /patient/appointments/{id}/queue`
(keyed by appointment, not doctor) and the `/ws/patient/session/{id}` socket,
both §10.5/§15.1 and owned by the appointments slice. The `/queue/:doctorId`
route is untouched. `features/dashboard/presentation/screen/ambulance_screen.dart`
likewise still reads the seeded ambulance providers (§14 is not in this slice).

## 14. Pay-at-hospital and the simulated gateway are gone (v2 alignment)

Removed: `payment/domain/counter_payment_window.dart`,
`payment/presentation/components/payment_method_tile.dart`, the simulated
`PaymentController`, the local `DemoCoupons` table, `BookingRecordsController`
(local reference minting) and the seeded slot calendar. The payment screen
has one button — **Pay ₹amount** from `payment_order.amount_paise` — and the
SDK offers the methods.

## 15. Discovery caches are keyed per query; `invalidate(pathPrefix:)` clears everything (core note)

`CachedFetcher.invalidate(pathPrefix:)` documents that keys are hashes and a
prefix clears the whole response cache. After a `409 SLOT_UNAVAILABLE` the
booking controller calls `invalidateSlots()`, which therefore drops every
cached GET (rebuilt from ETags at 304 cost). Acceptable, but a per-path
invalidation in core would keep the hospital list warm.

## Clean-up outcome (§9.6 confirmed)

Polled `GET /patient/appointments/01a0f17f-760d-7ef0-bd32-51372f1d883b` every
20 s after the booking:

```
08:52:28Z  status pending_payment
08:52:48Z  status cancelled, cancelled_by system, cancellation_reason payment_timeout, cancelled_at 2026-09-30T08:52:43Z
GET /patient/doctors/{id}/slots?date=2026-10-29 → the slot is "available" again
GET /patient/payments/orders/01a0f17f-7619-78e2-b724-08f08fb899dc → status "expired"
DELETE /patient/me/persons/01a0f17f-6ff0-7722-96eb-e8e879609108 → 204
```

The deadline was `08:52:37Z`; cancellation landed 6 s later. Nothing created
by this verification remains except the cancelled appointment row (a
cancelled appointment cannot be deleted through the patient API), which now
shows in the test account's history as `LKSB-2609-00183 · cancelled`.
