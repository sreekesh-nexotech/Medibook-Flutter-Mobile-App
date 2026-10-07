# Integration gaps — appointments & notifications

Slice: `lib/features/appointments/`, `lib/features/notifications/` (contract §10, §12, §15).
Verified against `https://62.171.151.149:8443` on 2026-09-30 with the test account
(`anita.menon@lakeshore.medibook.example.com`).

## Test data created during verification

| What | Id | State now |
|---|---|---|
| Dependant `Test Dependant` (relation `other`) | `01a0f15b-4ac4-7241-be2e-d9cd1bce1eb8` | **deleted** (`DELETE /patient/me/persons/{id}` → 204) |
| Booking with Dr. Suresh Pillai, slot `01a0ee29-1dc2-7262-874f-ed7b64f66af8` (2026-10-02 17:00 IST, Evening OPD) | appointment `01a0f15b-bcf6-7b91-a0eb-2d9a1d7ebacf`, booking ref `LKSB-2609-00182`, payment order `01a0f15b-bd1b-7a22-bdb7-76678a633477` | **cancelled** by the patient (`POST …/cancel` → 200, `cancelled_by: patient`). Never paid. It cannot be deleted, so the account now has **one row in the Canceled tab**; `GET /patient/appointments?q=pillai` finds it. |
| Cancellation notification raised by that cancel | `01a0f15c-36dd-7d92-bee4-a4ef0494ddaa` | **deleted** (`DELETE /patient/notifications/{id}` → 204) after exercising `/read`, `/unread`, `read-all` |
| Push device (`platform: android`, token `integration-shape-check-token`) | `01a0f15c-4e5f-71b1-9349-9cce47af3b4d` | **deleted** (`DELETE /patient/me/devices/{id}` → 204) |

The account has **no paid booking**, so `GET …/receipt` and `GET …/receipt.pdf` were only
verified on their 404 path (`NOT_FOUND`, "No receipt has been issued for this appointment.").
The receipt screen and mapper are built and unit-tested against the §10.8 example shape.

## Backend behaviour worth knowing

1. **`booking_ref` and `token_label` formats are per hospital.** The live values are
   `LKSB-2609-00182` and `A002` — not the `MB-2026-000124` / `T-026` from the contract
   examples. The app treats both as opaque text (§1.11) and no longer normalises tokens.
2. **`payment_order.key_id` is an empty string** on the test server (`"key_id": ""`), and
   `gateway_order_id` is `order_fake…`. Razorpay is stubbed server-side; the payment feature
   should not assume a usable key.
3. **`cancellation-preview` on a never-paid booking** returns `refund_bp: 0, refund_paise: 0,
   non_refundable_paise: 0` — the notice reads "Nothing has been paid … nothing to refund".
4. **`cancellation-preview` after cancellation** still returns 200 with `allowed: false,
   reason: APPOINTMENT_NOT_ACTIONABLE` (not a 404). Handled: the button is disabled from
   `actions` and the preview is only fetched when `can_cancel` is true.
5. **`queue` for a future session**: `session_state: scheduled`, every token null,
   `updated_at` is the session's creation time (a day old). The screen shows "The desk has
   not opened yet" and "Last update · updated 1 day ago" honestly.
6. **Cancelling a `pending_payment` booking raises a `cancellation` notification** within a
   second, with `data.event = appointment.cancelled`. Useful for manual QA of the inbox.
7. **`Idempotent-Replayed: true`** is returned on the second `cancel` with the same key; a
   different key on a cancelled appointment is `409 APPOINTMENT_NOT_ACTIONABLE`. The actions
   controller keeps the key across retryable failures and drops it on a 409/404.
8. **`GET /patient/notifications?kind=change` → 400** ("Must be one of: confirmation,
   reminder, cancellation, payment, queue, general"). The app's former `change` kind is gone.

## Gaps and decisions needed

### Push token acquisition (§12.6) — needs an FCM decision
There is no Firebase / FCM SDK in `pubspec.yaml`. `NotificationsRepository.registerDevice(...)`,
`deleteDevice(id)` and `pushDeviceProvider` (`register` / `unregister`) are implemented and
tested against the live endpoints, but **nothing calls `register`** because there is no
token to send. Decision needed: add `firebase_core` + `firebase_messaging` (and the platform
config files), or use a different push provider. Once a token exists:
`ref.read(pushDeviceProvider.notifier).register(platform:, pushToken:, appVersion:,
osVersion:)` after login and on token rotation.

### Device de-registration on logout — needs one call in the auth slice
`DELETE /patient/me/devices/{id}` must run **before** the session is cleared (it needs the
bearer). The auth feature owns logout; add
`await ref.read(pushDeviceProvider.notifier).unregister();` at the start of the logout use
case (or in the profile screen's sign-out handler). Not wired from this slice (auth is
frozen for me). Local clean-up is covered regardless: the device id lives in the `auth` Hive
box, which `HiveBoxes.clearedOnLogout` wipes.

### "Add to calendar" (§10.10) — no share sheet in the stack
`calendar.ics` is downloaded (bytes), saved to the temp directory via `path_provider`
(`CalendarLocalDataSourceImpl`) and handed to the OS with `url_launcher`'s `Uri.file(...)`.
On iOS `launchUrl` on a `file://` URI is generally refused and on Android it depends on a
registered handler; when it fails the screen shows the saved path in a toast. A proper
"open with / share" needs `share_plus` (or `open_filex`) — a pubspec change I cannot make.

### Hospital time zone
The appointment object carries no `timezone` (§10). Times are rendered in `Asia/Kolkata`
via a fixed `+05:30` (`HospitalTime` in `application/usecases/hospital_time.dart`). If a
hospital outside IST is ever added, `HospitalTime.offset` must come from
`GET /patient/hospitals/{id}` (§7.3) — no `timezone` package is in the stack.

### Person names on appointments (§6.1 join)
`Appointment.person_id` needs the persons list for "For Aarav (Son)". The appointments
feature reads `GET /patient/me/persons?page_size=100` itself (`appointmentPersonsProvider`)
through the cache rather than importing the profile feature. Once the profile slice exposes
a persons provider, `personForLabelProvider` can be repointed to it and
`AppointmentsRepository.persons()` removed.

### Filter options
The filter sheet's doctor / hospital pickers are built from the rows already loaded in the
three tabs' first pages (there is no "distinct doctors on my appointments" endpoint). On a
long history a doctor beyond page 1 is not offered; the search screen (`q=`) covers that.

### Retry payment (§9.4)
"Retry payment" navigates to `AppRoutes.bookingPayment?appt=<id>&order=<payment_order.id>`.
The payment feature owns `POST /payments/orders/{id}/retry` and Razorpay; it must read those
two query parameters.

### WebSocket verification
The two sockets (`/ws/patient/session/{id}`, `/ws/patient/inbox`) could not be exercised
from the shell (no `websockets` module on this machine); the handshake path (`bearer,
<access>` subprotocol, 4401/4408 close codes) is the existing `WsClient`. Reconnect / 4401 /
`token.called` / `unread_count` handling is unit-tested with a scripted socket.

### Legacy mock shim still present
`lib/features/appointments/presentation/controllers/appointments_controller.dart` is now a
**deprecated, self-contained mock shim** kept only because booking, payment, search, records
and dashboard still import it (`appointmentsControllerProvider`, `appointmentByIdProvider`,
`appointmentsByBucketProvider`, `firstUpcomingAppointmentProvider`). Nothing in the
appointments or notifications features imports it. Delete it once those slices move to
`nextUpcomingAppointmentProvider` / `appointmentsForLinkingProvider` /
`appointmentDetailProvider`.

`lib/features/booking/presentation/screen/queue_screen.dart` (doctor-keyed, mock-backed) is
no longer routed — `/queue/:appointmentId` now renders
`features/appointments/presentation/screen/live_queue_screen.dart`. The booking slice can
delete its copy.

### Golden tests
`test/goldens/screens_golden_test.dart` pumps `AppointmentsScreen` and `NotificationsScreen`
with no provider overrides; both screens now read real providers (`cachedFetcherProvider`
throws when not overridden) so those two goldens need `appointmentsRepositoryProvider` /
`notificationsRepositoryProvider` overrides (the fakes in `test/features/*/support/fixtures.dart`
work) and new baselines. Not in this slice's test scope.
