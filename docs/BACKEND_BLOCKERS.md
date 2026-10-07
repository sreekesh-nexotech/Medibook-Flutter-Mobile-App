# Backend blockers — what the mobile app needs from the backend

This file lists the things the Flutter app **cannot finish or test until the backend changes
something**. Each entry says what is blocked, what we saw, and exactly what we need.

- **Server:** the integration server, `https://62.171.151.149:8443`.
- **Tracker:** `docs/Medibook-Production-Readiness-Test-Checklist - Emulator Run.xlsx` — the
  "Known Blockers" sheet uses the `KB-xx` ids quoted below.
- **Only blockers hit while fixing or retesting are listed here.** The tracker's "Known Blockers"
  sheet and `docs/FLUTTER_INTEGRATION_GAPS_ROUND_2.md` hold the full earlier list.
- New entries are added at the bottom. When the backend fixes one, set its status to **Fixed —
  retest pending**; it becomes **Closed** once the app-side retest passes.

## Summary

| # | Blocker | Tracker id | Needed from backend | Status |
|---|---|---|---|---|
| BB-01 | No OTP can be received on the integration server | KB-05 | Real SMS on this server, or a safe test way to get the code | Open |
| BB-02 | No blocked patient account exists to test with | — (row BL-AUTH-027) | One seeded patient account with status `blocked` | Open |
| BB-03 | No throwaway patient account for tests that change the account | — (row BL-AUTH-046) | One patient account that is ours alone to change | Open |
| BB-04 | Live connections (WebSocket) are dropped about 6 seconds after they open | — | Keep the connection open as the contract says (idle limit 5 minutes) | Open |
| BB-05 | Forced-update test needs the minimum app version raised for a short window | — (row BL-AUTH-061) | Raise `min_versions.android` in app-config on request, then put it back | Open — waiting on a Play build first |
| BB-06 | Test data: hospitals in every availability state | — (row BL-BOOK-004) | Two more hospitals: one with online booking off, one with no free slot published | Open |
| BB-07 | Test data: no known coupon code | — (BL-BOOK-037, -040, -041, BL-CORE-002) | Two working coupon codes and their rules | Open |
| BB-08 | Test data: no doctor that cannot be booked | — (BL-BOOK-007) | One doctor on leave and one not bookable online | Open |
| BB-09 | Test data: no hospital outside India time | — (BL-BOOK-005, BL-CORE-005) | One hospital in Dubai time and one in a daylight-saving zone | Open |
| BB-10 | Test data: no list long enough to need a second page | — (BL-BOOK-006, BL-APPT-013, BL-CACHE-020, -021) | 51+ hospitals or doctors, 45+ appointments, 21+ records | Open |
| BB-11 | Test data: no follow-up or date-based pricing | — (BL-BOOK-033, -035) | One follow-up case and one date with a different fee | Open |
| BB-12 | Test data: no appointment in an unusual state | KB-08 for one (BL-APPT-009, -010, -011, -028) | Past-but-open visit, past unpaid booking, booking with Cancel disabled | Open |
| BB-13 | Test data: no account in an unusual state | BB-01 for one (BL-BOOK-029, BL-HOME-009, BL-FAM-012) | Account with no patient record, blank first name, family members that cannot be released | Open |
| BB-14 | Test data: no documents we may delete | KB-01 (BL-REC-019, -020) | Working uploads, or spare documents on our own account | Open |
| BB-15 | Test data: no support ticket waiting on the patient | — (BL-SUP-011) | A staff reply that sets one ticket to "waiting on you" | Open |
| BB-18 | Test data: no unusual notification in the inbox | — (BL-NOTIF-004, -005, -012) | Four test notifications: unknown event with and without an appointment, a refund with only a refund id, an unknown kind | Open |
| BB-19 | Question: what an expired data-export file answers | — (BL-PROF-033) | Confirm the status code of `GET /shared/data-exports/{id}/download-url` once the file has expired | Open |
| BB-20 | Test data: no newer policy version to re-accept | — (BL-PROF-038, -039, -040) | Publish a version 2 of one policy (e.g. Terms) for a short window, then roll it back | Open |
| BB-21 | Insurance switch-off test needs the flag turned off for a short window | — (BL-INS-010) | Set `patient_app.insurance` to `false` in app-config on request, then put it back | Open |
| BB-22 | Question: the files sent with a new support request are not returned | — (BL-SUP-006) | Return `attachment_file_ids` on the Ticket (or as its first message) | Open |
| BB-16 | No online payment can be made on the integration server | KB-02 | Razorpay test-mode keys on this server | Open |
| BB-17 | No file can be uploaded or downloaded on the integration server | KB-01 | A real file storage host on this server | Open |
| BB-23 | The API's TLS certificate is self-signed (CN=localhost) | KB-03 (Checklist ENV-001, SEC-004) | A CA-signed certificate on a real host name | Open |
| BB-24 | No production or pre-production host to build against | KB-07 (Checklist ENV-002, REL-005, SEC-011, REL-022) | The production/pre-prod API URL, with health, monitoring and backups in place | Open |
| BB-25 | https://medibook.app link verification files are missing | — (Checklist NAV-002, REL-009, REL-010) | Serve assetlinks.json and apple-app-site-association at /.well-known/ (no redirect) | Open |
| BB-26 | Departments carry no icon | — (Home audit, Available Services) | An `icon` key on `GET /patient/departments` rows (and filled on hospital departments) | Open |
| BB-27 | Test data: no banner with an image or a button, no hospital logo or cover | KB-01 for images (Home audit) | One banner with `cta_label` + `cta_target`, and logos/covers once file storage works (BB-17) | Open |
| BB-28 | The account-deletion waiting period is not in app-config | — (Profile audit) | `dsr_cooling_off_days` in `GET /shared/app-config` | Open |
| BB-29 | A profile photo can be uploaded but never set | — (Profile audit) | A way to set and remove `avatar_file_id` (e.g. on `PATCH /patient/me`) | Open |
| BB-30 | The policy documents on the server are placeholder text | — (Profile audit) | Publish the real Terms of Service, Privacy Policy and Community Guidelines | Open |
| BB-31 | The integration server shows Django's debug page | — (round-2 retest) | `DEBUG` off on every deployed server | Open |
| BB-32 | The API contract does not describe the round-2 changes | — (round-2 retest) | One committed, current `FLUTTER_API_INTEGRATION.md` with N-1 … N-7 | Open |
| BB-33 | Appointment rows have no patient name, so a removed family member's bookings are unnamed | — (Appointments audit) | `person: { id, name, relation }` on each appointment row | Open |
| BB-34 | Appointment rows have no doctor photo | KB-01 to see it (Appointments audit) | `doctor.photo_file_id` on each appointment row | Open |
| BB-35 | No list of the doctors and hospitals across a patient's appointments | — (Appointments audit, Filters) | An endpoint (or list `meta`) with the distinct doctors, hospitals and persons for the filter | Open |
| BB-36 | `cancellation_reason` / `status_reason` values are not documented | — (Appointments audit) | The list of codes (or a ready-to-show `*_label`) | Open |
| BB-37 | Unpaid bookings stay `pending_payment` for up to a minute after their deadline | — (Home and Appointments audits) | Release the hold at `booking_deadline_at` (or treat a past deadline as expired in every read) | Open |
| BB-38 | The upload size limit is not in app-config | — (Records audit) | `upload_max_bytes` in `GET /shared/app-config` | Open |
| BB-39 | A doctor on leave has no return date | — (Doctor & Hospital details audit) | The current leave's end date on `GET /patient/doctors/{id}` (e.g. `on_leave_until`) | Open |
| BB-40 | How long a slot is held for payment is not sent before booking | — (Home quick links audit) | The hold length (`hold_timeout_seconds`) on `GET /patient/hospitals/{id}` or the fee quote | Open |
| BB-41 | A refused coupon in the fee quote carries only its code | — (Home quick links audit) | The server's message and `meta` (e.g. `min_order_paise`) on the quote's `coupon` | Open |
| BB-42 | Hospital list rows have no time zone | — (Home quick links audit) | `timezone` on each row of `GET /patient/hospitals` (and search) | Open |
| BB-43 | Test data: four of the six areas have no hospitals, two of them "popular" | — (Home quick links and Choose a location audits) | Hospitals in RS Puram, Jubilee Hills, Edappally and Kothrud, or those areas not listed (or not popular) until there are | Open |
| BB-44 | Test data: no account or region where Notifications, Ambulance or FAQ is empty | — (Screen Coverage pass) | A patient with no notifications, an area with no ambulance provider, and a way to see an empty FAQ | Open |
| BB-45 | A patient cannot change their email address | — (Edit Profile audit) | An email-change call (verified with a code to the new address) in the contract | Open |
| BB-46 | Question: can date of birth and gender be cleared once set? | — (Edit Profile audit) | Confirm whether `PATCH /patient/me` accepts `null` for `date_of_birth` and `gender` | Open |

---

## BB-01 — No OTP can be received on the integration server

**Status:** Open · **Tracker id:** KB-05 · **Raised:** 2026-10-04 · **Last checked:** 2026-10-07

### What is blocked

Any flow that needs a one-time code cannot be completed from the app:

- Sign-up (the account is only created after the code is verified)
- Sign-in with a mobile number and code
- Forgot password
- Change mobile number
- Releasing a family member to their own account

**Edit Profile audit (7 Oct 2026):** the "Change" button beside the mobile number opens the
three-step change screen with the current number, but the change cannot be finished: step 1 sends
a code to the current number and none arrives.

In the tracker, 11 Business Logic rows are marked Blocked because of this (BL-AUTH-004, -016, -019,
-023, -039, -040, -041, -045, BL-PROF-014, BL-FAM-011, -012) and 17 Checklist rows that need it
have not been run.

### What we saw

On 2026-10-04 we tried a real sign-up from the app (emulator, debug build) with a real phone:

1. About 23:04 IST — the app sent `POST /api/v1/patient/auth/signup/start` for `+919746863592`.
   The server accepted it: the app received a challenge and moved to the "Verify Mobile" screen
   ("We sent a 4-digit code to +91 9746863592").
2. About 23:08 IST — "Resend code" was tapped once.
3. **No SMS reached the phone**, so the code could not be entered and no account was created.

This matches `docs/FLUTTER_INTEGRATION_GAPS_ROUND_2.md` §4: the server runs with
`PROVIDERS_MODE=fake`, so no SMS is sent, and the code is stored encrypted, so nobody can read it.

**Update 2026-10-06 — option 2 is built but not switched on.** Backend commit `b85a87b` adds
`DEV_OTP_FIXED_CODES` (a fixed code for listed test numbers while SMS is faked; refused in
production), with `+919808683257:1234` as its example. On the integration server it is not active:
mobile sign-in for `+919808683257` from the app, code `1234` → "That code is not right. Check it
and try again. 2 attempts left." The new code is deployed (the server already returns the
`timezone` that the same commit added to `/availability`), so only the setting is missing. Note
also that the committed `docker-compose.yml` does not pass `DEV_OTP_FIXED_CODES` (nor
`PROVIDERS_MODE` / `PROVIDERS_LIVE`) into the app containers, so setting it in `.env` alone will
not reach the server.

### What we need from the backend

Either one of these, on the integration server only:

1. **Real SMS delivery** — connect a real SMS provider so codes reach a real phone; or
2. **A safe test way to get the code** — for example a fixed code for a short list of agreed test
   numbers, or a test-only endpoint or log where the code can be read.

Whichever is chosen must stay **off in production**. Please tell us which option was done and, for
option 2, the test numbers and how to read the code.

### What we will do once it is available

- Re-run **BL-AUTH-004**: sign up with the "offers" box ticked in onboarding, then check that
  `GET /patient/me` returns `"marketing_opt_in": true`. The app-side fix is already in and the
  sign-up request now carries `consents.marketing = true`; only this server-side check is left.
- Re-run **BL-AUTH-016** (priority **P0**, a release blocker): enter the correct sign-up code and
  check that the app shows "Welcome to Medibook, <first name>!", opens Home, and lets the new user
  book "for myself" straight away. Nothing is wrong in the app here as far as we know — the test
  simply cannot be run without a code.
- Re-run **BL-AUTH-019** (P1): tap "Resend code", then try the old code and the new one. The
  test expects the old code to fail and the new one to work. So far only the app's "Code re-sent
  to your mobile number" message could be checked.
  **Question for the backend:** the contract (§4.6) says a resend keeps the same `challenge_id`
  with a new expiry, but does not say whether a **new code** is issued and the old one stops
  working. Please confirm, so we know what this test should expect.
- Re-run **BL-AUTH-023** (P1): enter a correct code in each of the three flows and check where the
  app goes — sign-up → Home, mobile sign-in → Home, forgot password → the new-password screen. The
  button labels can be seen without a code; the destinations cannot.
- Re-run **BL-AUTH-039** (P2): in forgot password, verify the reset code, close the app completely
  on the new-password screen, reopen it and submit. The app should say "That reset link has
  expired. Request a new code to continue." and send nothing to the server. The whole
  forgot-password flow stops at the code step today, so nothing after it can be tested.
- Re-run **BL-AUTH-040** (P2): verify the reset code, wait more than 15 minutes on the
  new-password screen, then submit. The app should say "That reset code has expired. Request a
  new one to continue."
- Re-run **BL-AUTH-041** (priority **P0**, a release blocker): complete a password reset and check
  that the app shows "Password reset — please log in", returns to the sign-in screen without
  signing the user in, rejects the old password, and that the user's other devices are signed
  out.
- Re-run **BL-AUTH-045** (P2): sign in to an account that has no password (code-only) and open
  the change-password screen. Such an account can only be signed in to with a code, so it cannot
  be reached today. (The screen itself has an app-side gap — it still shows a "Current Password"
  field for these accounts — which is the mobile team's to fix, not the backend's.)
- Run the other tracker rows listed above and update their status.

---

## BB-02 — No blocked patient account exists to test with

**Status:** Open · **Tracker row:** BL-AUTH-027 (P1) · **Raised:** 2026-10-04 · **Last checked:** 2026-10-04

### What is blocked

The test "sign in to a blocked account" cannot be run. It checks that a patient whose account
Medibook has blocked sees **"This account has been blocked. Contact Medibook support."** when they
try to sign in, and that the wrong-password attempts counter does not change.

### What we saw

`docs-flutter/users.json` (the seeded accounts, generated 2026-09-29) lists 25 patients: 24 are
`active` and 1 is `pending_deletion`. **None is `blocked`**, and the patient app has no way to
block an account itself. So the server never returns `403 ACCOUNT_BLOCKED`, and the app's message
for it has never been seen on a device.

### What we need from the backend

On the integration server, **one patient account with status `blocked`**, with its phone number or
email and password shared with us (the usual seed password is fine). Either:

1. add a blocked patient to the seed data, or
2. block one existing seeded patient from the platform admin side and tell us which one.

Please keep it blocked — it is needed again for every regression run.

### What we will do once it is available

- Re-run **BL-AUTH-027**: sign in with that account's password and check the message and the
  attempts counter.
- The contract also lists `403 ACCOUNT_BLOCKED` for sign-in with a code and for token refresh.
  Sign-in with a code for this account additionally needs BB-01.

---

## BB-03 — No throwaway patient account for tests that change the account

**Status:** Open · **Tracker row:** BL-AUTH-046 (P1) · **Raised:** 2026-10-04 · **Last checked:** 2026-10-04

### What is blocked

The test "change the password while signed in" was not run. It checks that after a successful
change the app shows "Password updated", the user stays signed in on this device, their other
devices are signed out, and the Profile row reads "Change password".

### What we saw

Every seeded account on the integration server shares one password (`seed_password_123`,
`docs-flutter/users.json`) and is used by everyone who tests against that server. Changing the
password of one of them would lock other testers and the automated live checks out of it, so the
tester did not do it. We also cannot create an account of our own, because sign-up needs a code
(BB-01).

### What we need from the backend

**One patient account on the integration server that only the mobile team uses**, with its sign-in
details, so tests that change the account do not affect anyone else. Fixing BB-01 would also
solve this, because we could then sign up our own accounts.

This is not needed if the project owner is happy for us to change the password of one named
seeded account and change it back afterwards.

### What we will do once it is available

- Re-run **BL-AUTH-046** with that account and update the tracker.
- Use the same account for any other test that changes or deletes an account.

---

## BB-04 — Live connections (WebSocket) are dropped about 6 seconds after they open

**Status:** Open · **Tracker row:** none yet (found while running BL-AUTH-048 and BL-QUEUE-016) · **Raised:** 2026-10-05 · **Last checked:** 2026-10-06

### What is blocked

Nothing is fully blocked, but two live features cannot work as designed on the integration server:

- the notification badge (`/ws/patient/inbox`), and
- the live queue screen (`/ws/patient/session/{appointment_id}`).

Because the connection never stays up, the app reconnects all the time and re-reads the unread
count over REST after each reconnect — about one extra `GET /patient/notifications/unread-count`
every 8 seconds for as long as a signed-in user has the app open. Any message the server would
push in the gap is missed.

### What we saw

On 2026-10-05, with a recorder between the app and the server:

1. The app opens the socket; the server accepts it (`101 Switching Protocols`).
2. The server sends **no message at all** on it.
3. About **6 seconds later the server side closes the connection, with no close code**.
4. The app waits 2 seconds, reconnects, and the same thing repeats.

Both socket paths behave the same way. Without the recorder the emulator still opens a new
connection to the server about every 8 seconds, so this is not caused by the test tool.

The contract (§15) says a socket stays open, the server answers the app's 30-second `ping` with
`pong`, and an idle socket is closed after **5 minutes** with code **4408**. The app never gets
far enough to send its first ping.

**Update 2026-10-06 — still the same after backend commit `b85a87b`.** That commit changed only
how a refused socket ends (accepted, then closed with 4401, instead of an HTTP 403). Read from the
app's own network log on the emulator, an idle signed-in app opened `/ws/patient/inbox` six times
in 39 seconds (`101` each time, about every 7.7 s), each followed by a
`GET /patient/notifications/unread-count`.

### What we need from the backend

Please check why WebSocket connections end after about 6 seconds on the integration server — for
example a proxy (nginx) read timeout in front of the `ws` service, or the consumer closing — and
make them stay open as §15 describes. If a 6-second limit is intended, tell us what the app must
send, and how often, to keep the connection alive.

### What we will do once it is fixed

- Check that the inbox and live-queue sockets stay connected, and that the repeated
  unread-count calls stop.
- Re-run the live-queue and notification rows that depend on pushed messages.

---

## BB-05 — Forced-update test needs the minimum app version raised for a short window

**Status:** Open, but not the first thing in the way · **Tracker row:** BL-AUTH-061 (P0); BL-AUTH-062 to -064 are related · **Raised:** 2026-10-05

### What is blocked

The test "an app older than the minimum version must update before it can be used". The app
reads the minimum from `GET /shared/app-config` (`min_versions.android`) and, when the installed
version is lower, shows Google Play's full-screen update and then a blocking "Update required"
screen.

### What we saw

`min_versions.android` on the integration server is `1.0.0`, the same as the installed app
(1.0.0), so nothing is ever below the minimum.

### What we need from the backend

When the mobile team asks, **raise `min_versions.android` on the integration server above the
test build's version** (for example to `1.0.1`) for the length of the test, then set it back.
Please tell us who can change it and how much notice they need.

**This is the smaller half.** The larger one is ours: the update flow only starts when Google
Play itself reports an update, so the test needs a build installed from Google Play (an internal
testing track) with a newer version published there. The emulator build is installed directly
and never gets that. There is no point changing the value until that build exists.

### What we will do once both are ready

- Re-run **BL-AUTH-061**, then BL-AUTH-062 (version comparison), -063 (optional update) and -064
  (installs that did not come from Google Play).

---

## BB-06 — Test data: hospitals in every availability state

**Status:** Open · **Tracker row:** BL-BOOK-004 (P1) · **Raised:** 2026-10-05

### What is blocked

The test of the line each hospital card shows about availability. The app should show one of:

| Hospital state | What the server sends | Line on the card |
|---|---|---|
| Online booking switched off | `online_booking_enabled: false` | "Online booking not available" |
| Booking on, no open slot | `next_available_at: null` | "No free slot published" |
| Booking on, a slot today | `next_available_at` = a time today | "Next free <time> today" |

### What we saw

`GET /patient/hospitals` on the integration server returns 2 hospitals. Both have online booking
on and their next free slot tomorrow, so only one line could be seen: "Next free 9:00 AM
tomorrow". The other three states cannot be produced from the app.

### What we need from the backend

In the seed data on the integration server:

1. one hospital with **online booking switched off**;
2. one hospital with booking on but **no free slot published**;
3. on one of the existing hospitals, **a free slot on the current day** at the time of testing
   (or tell us when in the day the seeded sessions have free slots).

Please keep them in the seed so every later test run has them.

**Question:** `docs-flutter/users.json` lists three active hospitals (Lakeshore, Sahyadri and
Nilgiri Family Clinic), but the patient list returns only the first two. Why is Nilgiri left
out? If it is the one with online booking off, the app never gets the chance to show "Online
booking not available".

### What we will do once it is available

- Re-run **BL-BOOK-004** and update the tracker.

Note: the mobile team can check the wording of the lines without this, by altering the server's
answer in a local test tool, but real hospitals in these states are still needed to test what
happens when someone opens one and tries to book.

---

## BB-07 to BB-15 — More test data the integration server does not have

**Raised:** 2026-10-05 · **Status of all:** Open

These are all the same kind of problem as BB-02 and BB-06: the app has a rule, the test needs data
in a particular state to show it, and the seeded data on the integration server has nothing in
that state. Nothing here is known to be wrong in the app. Please keep whatever is added in the
seed, so every later test run has it, and tell us the names, codes or sign-in details.

What we could confirm ourselves: the patient hospital list returns 2 hospitals, the test account
has 2 records and at most 8 appointments in a tab, and every seeded patient has a first name.

### BB-07 — No known coupon code

**Rows:** BL-BOOK-037 (**P0**), BL-BOOK-040 (P1), BL-BOOK-041 (P3), BL-CORE-002 (P2)

- **Blocked:** everything about discounts — applying a coupon, the green "− ₹X" row and reduced
  total, removing it, keeping it when the doctor changes, and the message when a coupon is
  refused at payment time.
- **Seen:** 13 guessed codes all came back `COUPON_INVALID`. The seed summary counts one
  `COUPON_USAGE_CAP` refusal, so coupons do exist — we just do not know the codes.
- **Needed:** (1) one coupon that stays valid for repeated use, with its discount and any
  minimum order; (2) one coupon with a **usage limit of 1**, so we can use it up and test the
  refusal. If codes exist already, just send them.

### BB-08 — No doctor that cannot be booked

**Rows:** BL-BOOK-007 (**P0**)

- **Blocked:** the rule that a doctor can only be booked when active and bookable online. The
  app should show "On leave — not taking bookings right now." or "Not bookable online. Call the
  hospital to book." and hide the Book button.
- **Seen:** all 10 doctors returned are active and bookable.
- **Needed:** one doctor **on leave**, and one doctor **not bookable online**, each visible in a
  hospital's doctor list.

### BB-09 — No hospital outside India time

**Rows:** BL-BOOK-005 (P3), BL-CORE-005 (P3)

- **Blocked:** checking that times are shown in the hospital's own time zone.
- **Seen:** both hospitals are in India time.
- **Needed:** one hospital in **Asia/Dubai**, and one in a zone with daylight saving such as
  **Europe/London**, each with at least one free slot.

### BB-10 — No list long enough to need a second page

**Rows:** BL-BOOK-006 (P2), BL-APPT-013 (P1), BL-CACHE-020 (P1), BL-CACHE-021 (P2)

- **Blocked:** everything about loading more rows — the next page appearing while scrolling, no
  repeated rows, and what happens when a later page fails.
- **Seen:** 2 hospitals, 10 doctors, at most 8 appointments in a tab, 2 records. The app's page
  sizes are 50 (hospitals, doctors) and 20 (appointments, records).
- **Needed:** on one test account: **45 or more appointments in one tab** and **21 or more
  records**; and either **51 or more hospitals in one location** or **51 or more doctors in one
  hospital department**.

### BB-11 — No follow-up or date-based pricing

**Rows:** BL-BOOK-033 (P1), BL-BOOK-035 (P1)

- **Blocked:** the "Visit: Follow-up (reduced fee)" line and reduced total; and comparing the
  quoted amount with the amount charged when a date has a different fee.
- **Seen:** every fee quote tried returned `is_follow_up: false`, and quote and charge were
  always equal (₹424, ₹824, ₹524).
- **Needed:** (1) one patient-and-doctor pair that qualifies for a **follow-up fee**, with the
  doctor having a follow-up price set; (2) one doctor whose **fee differs on a known date**.
- **Update 2026-10-05:** the app now warns the patient and asks them to confirm when the amount
  due differs from the quote (BL-BOOK-035). That was tested by altering the quote in a local
  tool; item (2) is still needed to repeat the test with real pricing.

### BB-12 — No appointment in an unusual state

**Rows:** BL-APPT-009 (P1), BL-APPT-010 (P1), BL-APPT-011 (P2), BL-APPT-028 (P2)

- **Blocked:** how the app lists and treats three kinds of booking.
- **Seen:** the test account has none of them.
- **Needed, on one test account:**
  1. a **paid visit whose time has passed but is still "scheduled"** (the desk never closed it);
  2. an **unpaid booking whose slot time has just passed** and has not been cancelled yet — or
     tell us how long after the slot time the server cancels it, so we can time it ourselves;
  3. an **upcoming booking where Cancel is not allowed** (token called or in consultation). This
     one needs a desk user to run a live session while we test (tracker KB-08).

### BB-13 — No account in an unusual state

**Rows:** BL-BOOK-029 (P2), BL-HOME-009 (P3), BL-FAM-012 (P2)

- **Blocked:** three messages the app shows for unusual accounts.
- **Seen:** every seeded account has a patient record and a first name.
- **Needed:**
  1. an account with **no patient record** (no persons at all);
  2. ~~an account with a blank first name~~ — **no longer needed (2026-10-05):** BL-HOME-009 was
     checked by altering the profile answer in a local test tool, and the greeting was fixed;
  3. for releasing a family member to their own account: one member who is **under 18** and one
     the server **refuses to move**. This test also needs a one-time code, so it waits on BB-01.

### BB-14 — No documents we may delete

**Rows:** BL-REC-019 (P1), BL-REC-020 (P3)

- **Blocked:** deleting a record, and deleting one that was already removed on another device.
- **Seen:** the account has only its 2 seeded documents, which other testers rely on, and a new
  one cannot be uploaded because the storage host does not work on this server (tracker KB-01).
- **Needed:** working uploads (KB-01), so we can add our own documents and delete them — or a
  few spare documents on an account that is ours alone (see BB-03).

### BB-15 — No support ticket waiting on the patient

**Rows:** BL-SUP-011 (P3)

- **Blocked:** checking that the "Waiting on you" badge clears after the patient replies.
- **Seen:** no ticket on the test account is in that status.
- **Needed:** a staff reply on one of the test account's tickets that sets it to **waiting on the
  requester** — or tell us how to do that ourselves from the platform side.

### BB-18 — No unusual notification in the inbox

**Rows:** BL-NOTIF-004 (P2), BL-NOTIF-005 (P3), BL-NOTIF-012 (P3)

- **Blocked:** checking what the app does with a notification it does not fully recognise, and
  where a refund notification leads when it carries no appointment.
- **Seen:** the test account's inbox holds only ordinary notifications, and there is no way for
  us to send one.
- **Needed:** four notifications in the test account's inbox (`GET /patient/notifications`):
  1. an `event` the app does not know (e.g. `test.unknown`) **with** `data.appointment_id`;
  2. the same unknown `event` **without** any appointment id;
  3. a `refund.processed` notification carrying `data.refund_id` but **no** `appointment_id`;
  4. a notification whose `kind` is a value not in §17 (e.g. `promotion`).
- Or tell us whether `refund.processed` is ever sent without an `appointment_id` — if it never
  is, BL-NOTIF-005 can be closed.

### BB-19 — What does an expired data-export file answer?

**Rows:** BL-PROF-033 (P1)

- **Question:** once an export file's 7 days are over, what does
  `GET /shared/data-exports/{dsr_id}/download-url` return? The API document (§5.7) does not say.
- **Why it matters:** the app shows "This file is no longer available. Request a new copy." only
  for **404**. Simulated on 5 Oct 2026: a **410 Gone** answer shows "Something went wrong on our
  side. We're on it — please try again in a moment.", which is wrong for an expired file.
- **Needed:** the status code and error `code` used for an expired file — and, if it is not 404,
  we change the app to match.

### BB-20 — No newer policy version to re-accept

**Rows:** BL-PROF-038 (P1), BL-PROF-039 (P1), BL-PROF-040 (P1)

- **Blocked:** the "Our policies have changed" card on Profile, accepting it (online and offline),
  and confirming that the rest of the app keeps working while a policy is still pending.
- **Seen:** Terms, Privacy Policy and User Guidelines are all at version 1 and already accepted by
  the test account, so the card never appears. The app cannot publish a policy.
- **Needed:** publish a **version 2 of one policy** (Terms is enough) for a short window while we
  test, then roll it back — or tell us how to do that ourselves.

### BB-21 — Insurance switch-off test needs the flag turned off

**Rows:** BL-INS-010 (P2)

- **Blocked:** checking that the hospital can switch insurance off for the app remotely — the
  Insurance screens should then say "Insurance is not available right now".
- **Seen:** `GET /shared/app-config` returns `patient_app.insurance: true`, and Insurance works.
  The app cannot change this value.
- **Needed:** set `patient_app.insurance` to **false** for a short window while we test, then put
  it back to true. (Like BB-05, it affects every user of the integration server while it is off.)

### BB-22 — Files sent with a new support request are not returned

**Rows:** BL-SUP-006 (P3)

- **Seen in the API document (§13):** `POST /patient/support/tickets` accepts
  `attachment_file_ids`, and each reply (`messages[]`) returns its `attachment_file_ids` — but
  the `Ticket` itself does not. So the files a patient attaches when **raising** a request can
  never be shown back to them; only files on later replies can.
- **Needed:** return `attachment_file_ids` on the `Ticket` (or include the opening description
  as the first message, with its files). The app shows a message's files as "Attachment 1, 2…"
  links and will show the request's files the same way.

---

## BB-16 — No online payment can be made on the integration server

**Status:** Open · **Tracker id:** KB-02 · **Raised:** 2026-10-05 · **Last checked:** 2026-10-06

### What is blocked

Everything after the booking is created: paying, the success screen, the receipt, retrying a
failed payment through to success, late and expired payments, and refunds after a paid booking is
cancelled.

In the tracker this is the largest single blocker: **29 Business Logic rows** (BL-PAY-005 to
-024 except -008, and BL-APPT-008, -037, -039 to -043, -045, -048, -049) — **15 of them
priority P0** — plus 28 Checklist rows.

### What we saw

A booking made from the app is created correctly, but its payment order comes back with an empty
Razorpay key and a fake order id (`key_id: ""`, `gateway_order_id: "order_fake…"`). The app
rightly refuses to open the payment sheet without a key and shows: "Online payment is not set up
for this hospital yet, so this booking cannot be paid in the app. Nothing has been charged."
Seen again on 2026-10-05 with bookings LKSB-2610-00194 and -00195.

This matches `docs/FLUTTER_INTEGRATION_GAPS_ROUND_2.md` §2 R-2: the server runs Razorpay as an
in-process fake (`PROVIDERS_MODE=fake`).

**Update 2026-10-06 — still no key.** Backend commit `b85a87b` adds `PROVIDERS_LIVE`, so Razorpay
can be live while SMS and email stay fake, but the keys are not set. Booking `LKSB-2610-00210`
made from the app ended on the same "Online payment is not set up for this hospital yet"
message (the order's `key_id` is empty); it was cancelled afterwards.

### What we need from the backend

**Razorpay test-mode keys configured on the integration server**, so that a booking's payment
order carries a real test `key_id` and order id and the test payment sheet can open. Production
needs the live keys, as a separate step.

Please also tell us which test cards or UPI ids to use, and whether test payments reach the
server by webhook on this deployment.

### What we will do once it is available

- Run the 29 Business Logic rows and 28 Checklist rows above and update the tracker.
- First among them **BL-PAY-005** (P0): the tracker suspects that if the hold timer runs out while
  the payment sheet is open and the patient then pays, the app can end on "The payment window
  closed" even though money was taken. That can only be checked once a real payment is possible.

---

## BB-17 — No file can be uploaded or downloaded on the integration server

**Status:** Open · **Tracker id:** KB-01 · **Raised:** 2026-10-05 · **Last checked:** 2026-10-06

### What is blocked

Everything that moves a file:

- uploading a medical record, an insurance document or a support-ticket attachment;
- opening or downloading a saved record;
- downloading a receipt PDF;
- downloading a finished data export.
- showing doctor photos on Hospital Details and Doctor Details (Doctor & Hospital details
  audit, 6 Oct 2026): four Lakeshore and Sahyadri doctors have a `photo_file_id`, and
  `GET /shared/files/{id}/url` answers `200`, but the image link is on
  `storage.fake.local`, so the tiles stay blank and the profile shows initials.

In the tracker, **15 Business Logic rows** are Blocked by this (BL-APPT-057, BL-REC-007, -008,
-019, -026, -027, -028, -029, -031, -033, -034, BL-PROF-033, BL-INS-004, -005, -011) — two of
them priority P0 — plus 14 Checklist rows. BL-SUP-006 joined them on 5 Oct 2026: the support
request form and reply box now have an Attach control (owner decision), which cannot be tried
until uploads work.

### What we saw

Every file link the server hands out points at `https://storage.fake.local/…`, a host that does
not exist. An upload gets as far as asking for the link (`POST /shared/files/uploads` → `201`)
and then fails when the app tries to send the file there. A download opens the browser, which
shows "This site can't be reached" (`DNS_PROBE_FINISHED_NXDOMAIN`). The app's side of the
hand-off works; the file host is missing.

This matches `docs/FLUTTER_INTEGRATION_GAPS_ROUND_2.md` §2 R-1: the server runs storage as a
fake (`PROVIDERS_MODE=fake`).

**Update 2026-10-05 — no workaround on our side.** We pointed the upload at a stand-in storage
host on the test machine, and the file was accepted there. The server then refused the next
step: `POST /shared/files/{id}/complete` → `400 VALIDATION_ERROR`, `errors.file`: "The object
has not been uploaded yet." So the server checks its own storage, and only the backend can
unblock a real upload.

What we could check anyway, by simulating the server's answers for the complete and scan steps
(BL-REC-026, -027, -028, -029): the app's upload stages, the infected / scan-failed refusals,
the 30-second slow-scan message and the retry all behave as specified. These four rows are
marked Pass *with simulated answers* and must be repeated once on real storage. BL-REC-031
(replaced and retried files left on the server) was an app defect, DEF-061, now fixed: the app
sends `DELETE /shared/files/{id}` for every file it no longer wants. BL-REC-033 (a new link on
every View / Download, and the app's messages) also passes; opening the file itself still waits
on real storage.

**Update 2026-10-06 — the fix is in the code but not on the server, and part of it is not
committed.** Backend commit `b85a87b` signs links for `S3_PUBLIC_ENDPOINT` and lets storage stay
real under `PROVIDERS_LIVE=storage,clamav`; their notes say nginx now serves the store on port
9443. What we saw:

- **Download my data → Download** (`GET /shared/data-exports/{id}/download-url` → `200`) still
  opens `https://storage.fake.local/…`, and Chrome shows `DNS_PROBE_FINISHED_NXDOMAIN`.
- **Records → a document → Open file** (`GET /patient/documents/{id}/download-url` → `200`): the
  same `storage.fake.local` link, the same browser error (Records audit, 6 Oct).
- Port **9443** on the integration server refuses connections.
- The committed `deploy/nginx/nginx.conf` listens only on 80 and 443, and `docker-compose.yml`
  publishes only those two ports. Neither file has the 9443 listener, and the compose file does
  not pass `PROVIDERS_LIVE` or `S3_PUBLIC_ENDPOINT` into the app containers.

So the server needs the settings **and** the nginx/compose change committed and deployed.

### What we need from the backend

**Real object storage on the integration server**, so that upload and download links point at a
host a phone can reach. Please confirm that a file uploaded there passes the virus scan and
becomes `clean`, since a record can only be saved with a clean file.

### What we will do once it is available

- Run the 15 Business Logic rows and 14 Checklist rows above and update the tracker.
- This also clears BB-14 (documents we may delete), because we can then upload our own.

---

## BB-23 — The API's TLS certificate is self-signed

**Rows:** Checklist ENV-001 (P0), SEC-004 (P0) · Known Blockers KB-03

- **Seen (6 Oct 2026):** `curl https://62.171.151.149:8443/api/v1/shared/health` without `-k` fails;
  the certificate's subject and issuer are both `CN=localhost` (valid to 1 Jan 2029).
- **App side:** non-production builds accept this certificate on purpose; a production build
  refuses `MEDIBOOK_ALLOW_BAD_CERT=true` and will not start with it (Checklist INS-007).
- **Needed:** a CA-signed certificate on a real host name for pre-production and production, so the
  app can run with normal certificate checking and the MITM test (SEC-004) can be done.

## BB-24 — No production or pre-production host

**Rows:** Checklist ENV-002 (P0), REL-005 (P0), SEC-011 (P0), REL-022 (P0) · Known Blockers KB-07

- **Seen:** there is no host to pass as `MEDIBOOK_API_BASE_URL`, so the app's default — the
  integration server's IP — is what a release build contains today.
- **App side (done 6 Oct):** a production build now refuses to start when its API address is a bare
  IP address, and says why on screen and in the device log (DEF-078).
- **Needed:** the pre-production and production API URLs (behind BB-23's certificate), with the
  health endpoint, monitoring, backups, rate limits and on-call in place (REL-022).

## BB-25 — https://medibook.app link verification files are missing

**Rows:** Checklist NAV-002 (P1), REL-009 (P1), REL-010 (P1)

- **Seen (6 Oct 2026):** the Android app declares `https://medibook.app` links with
  `autoVerify`, but Android's verification failed (`pm get-app-links`: medibook.app = 1024).
  `https://medibook.app/.well-known/assetlinks.json` and `/.well-known/apple-app-site-association`
  both answer **307** (a redirect) instead of the files, so a medibook.app link opens in Chrome.
- **Needed (website owner):** serve both files directly at those paths (no redirect, JSON content
  type): `assetlinks.json` with the package `com.navoracloudsoft.medibook` and the **release**
  signing certificate's SHA-256 fingerprint (the release key is still to be created, KB-06), and the
  Apple file with the app id for Universal Links.
- **What we will do:** re-check `pm get-app-links` (should read `verified`) and open
  `https://medibook.app/appointment/<id>` from Messages; it must open the app directly.

## BB-26 — Departments carry no icon

**Rows:** Home audit (6 Oct 2026), "Available Services" tiles; also the booking department step.

- **Seen (6 Oct 2026):** `GET /patient/departments` returns only `code`, `name` and
  `hospital_count` (7 rows: cardiology … paediatrics). The contract has no icon there, and the
  hospital-level department rows carry `icon: null` (`docs/integration-gaps/booking-payment-discovery.md` §8).
- **App side:** the app picks an icon from the department `code` with its own table
  (`department_icon.dart`): 15 known codes; anything else gets the generic mark. So a department
  the backend adds tomorrow (say `oncology`) shows a generic icon until an app release.
- **Needed:** an `icon` key per department (a name from the design's icon set, e.g. `heart`,
  `bone`), on `GET /patient/departments` and filled on the hospital department rows. The app would
  use it when present and keep its table as the fallback.

## BB-27 — Test data: no banner with an image or a button, no hospital logo or cover

**Rows:** Home audit (6 Oct 2026), offers strip and "Hospitals Near You".

- **Seen (6 Oct 2026):** both seeded banners have `image_file_id`, `cta_label` and `cta_target`
  all `null`; both hospitals have `logo_file_id` and `cover_file_id` `null`. On Home every banner
  is a plain gradient and every hospital shows its initials.
- **App side (done 6 Oct):** a banner now shows its `cta_label` as a button and a tap follows
  `cta_target` (a `medibook://…` or `https://medibook.app/…` link opens that screen; another
  `https` link opens in the browser; otherwise the banner's hospital). Images and logos were
  already wired. None of this can be seen on the device without data.
- **Needed:** one banner with `cta_label: "Book now"` and `cta_target: "medibook://booking"`
  (and one with an `https` target), and — once file storage works (BB-17) — an image on one
  banner and a logo and cover on one hospital.

## BB-28 — The account-deletion waiting period is not in app-config

**Rows:** Profile audit (6 Oct 2026), "Delete account".

- **Seen (6 Oct 2026):** how long a deleted account can still be reactivated is a platform
  setting staff can change (`platform_settings.dsr_cooling_off_days`, default 30, D-24); the
  server uses it to set a request's `cooling_off_ends_at`. `GET /shared/app-config` does not
  include it: it returns only `min_versions`, `feature_flags_public`, `otp_length`,
  `support_contacts` and `legal_versions`. So before a request exists, the app cannot know the
  real number.
- **App side (done 6 Oct):** the Delete account row, sheet and confirm dialog no longer have "30"
  written in. They read `dsr_cooling_off_days` from app-config and fall back to 30 while it is
  missing. Once a request exists, the card already shows its real `cooling_off_ends_at`.
- **Needed:** add `"dsr_cooling_off_days": <int>` to `GET /shared/app-config` (it is already in
  the public settings view), and to the contract (§3.1).

## BB-29 — A profile photo can be uploaded but never set

**Rows:** Profile audit (6 Oct 2026), the photo on Profile and on the account holder's card in
Family Members.

- **Seen (6 Oct 2026):** `GET /patient/me` returns `profile.avatar_file_id`, and
  `POST /shared/files/uploads` accepts purpose `avatar` (JPEG, PNG, HEIC). But nothing can put a
  file there: `PATCH /patient/me` does not accept `avatar_file_id`, and no other endpoint sets it.
  So every patient has initials and no way to add a photo.
- **App side (done 6 Oct):** Profile and the "You" card now show the photo whenever
  `avatar_file_id` is set (through `GET /shared/files/{id}/url`), and initials otherwise. A
  "change photo" control is not added, because there is nothing to send it to.
- **Needed:** a way to set and remove the photo — for example `avatar_file_id` (the patient's own
  clean `avatar` upload) and `null` accepted on `PATCH /patient/me` — written into the contract.
  The image will only load once file storage works (BB-17).

## BB-30 — The policy documents on the server are placeholder text

**Rows:** Profile audit (6 Oct 2026), Terms of Service, Privacy Policy, Community Guidelines (also
shown at sign-up and in Help & Support).

- **Seen (6 Oct 2026):** all three are version 1, published 31 July 2026, and their whole text is
  a placeholder: `GET /patient/legal/terms` → "Demo terms for the Medibook app.", `privacy` →
  "Demo privacy policy.", `guidelines` → "Be kind to hospital staff.". Every patient accepts
  these at sign-up.
- **App side:** nothing to change — the screens show whatever the server publishes, including the
  title and version.
- **Needed:** publish the real Terms of Service, Privacy Policy and Community Guidelines before
  any external release. Publishing them as version 2 also gives the re-consent test (BB-20) its
  data.

## BB-31 — The integration server shows Django's debug page

**Rows:** round-2 retest (6 Oct 2026).

- **Seen (6 Oct 2026):** a request to a path that does not exist (`GET /api/v1/patient/doctors`)
  returns Django's yellow "Page not found" debug page, which lists the server's URL patterns. That
  page appears only when `DEBUG` is on; with `DEBUG` on, a server error would also show settings
  and stack traces.
- **App side:** nothing to change; the app only reads JSON.
- **Needed:** `DEBUG=False` on the integration server and on every server that will be deployed,
  with JSON error bodies for unknown paths.

## BB-32 — The API contract does not describe the round-2 changes

**Rows:** round-2 retest (6 Oct 2026); `docs/FLUTTER_INTEGRATION_GAPS_ROUND_2.md` N-1 … N-7.

- **Seen (6 Oct 2026):** the backend team answered N-1 … N-7 in
  `docs/FLUTTER_INTEGRATION_GAPS_ROUND_2.md`, but `FLUTTER_API_INTEGRATION.md` is still not
  committed in the backend repo (`origin/main` at `b85a87b`). Both copies we have are dated
  30 Sep and still say `If-Match` is optional on document PATCH, use `fy_code: "26-27"`, have no
  note that a refused socket is now accepted and closed with 4401, no `timezone` on
  `/availability`, no data-export calls and no `marketing` consent row.
- **Needed:** one committed, current copy of the contract with N-1 … N-7 folded in, so the app is
  checked against what the server really does.

## BB-33 — Appointment rows have no patient name

**Rows:** Appointments audit (6 Oct 2026), the "For …" line on cards and the Patient filter.

- **Seen (6 Oct 2026):** booking `LKSB-2610-00191` has `person_id 01a10601-…-252bc1`. That person is
  no longer in `GET /patient/me/persons` (a released family member) and
  `GET /patient/me/persons/{id}` answers **404**. The appointment row itself carries only `person_id`.
- **Effect:** the card shows no "For …" line for that booking, and the Patient filter cannot offer
  that person, so their past bookings cannot be found by patient.
- **Needed:** the patient on each appointment row — `person: { id, name, relation }` — kept even after
  the family member is released (as the hospital's record of who was seen).

## BB-34 — Appointment rows have no doctor photo

**Rows:** Appointments audit (6 Oct 2026), the avatar on every card.

- **Seen:** the row's `doctor` has `id, name, title, specialisation, room` only; the doctor's own
  record (`GET /patient/hospitals/{id}/doctors`) has `photo_file_id`. Every card shows initials.
- **Needed:** `doctor.photo_file_id` on the appointment row (seeing the photo also needs file storage,
  BB-17).

## BB-35 — No list of the doctors and hospitals across a patient's appointments

**Rows:** Appointments audit (6 Oct 2026), the Filters sheet.

- **Seen:** there is no endpoint for "the doctors / hospitals I have appointments with". The app
  builds the Doctor and Hospital choices from the appointment pages it has loaded so far, so a
  patient with more appointments than are loaded (20 per page, 3 tabs) is not offered every doctor.
- **Needed:** either `GET /patient/appointments/facets` →
  `{ doctors: [{id, name}], hospitals: [{id, name}], persons: [{id, name, relation}] }`, or the same
  in the list response's `meta`.

## BB-36 — `cancellation_reason` / `status_reason` values are not documented

**Rows:** Appointments audit (6 Oct 2026), the reason line on cancelled cards and the detail screen.

- **Seen:** `cancellation_reason` holds codes (`payment_timeout`, `patient_request`) or the patient's
  own text ("Test notification"); the hospital-side codes and every `status_reason` value are not
  listed in `FLUTTER_API_INTEGRATION.md`.
- **App side (done 6 Oct):** the two known codes add nothing (the status line already says it), any
  other `snake_case` code is spelt out ("Doctor unavailable"), and free text is shown as typed.
- **Needed:** the full list of codes, or a ready-to-show `cancellation_reason_label` /
  `status_reason_label`, so hospital reasons read properly.

## BB-37 — Unpaid bookings stay `pending_payment` for up to a minute after their deadline

**Rows:** Home audit and Appointments audit (6 Oct 2026), the unpaid booking's card.

- **Seen (6 Oct 2026):** after `booking_deadline_at`, `GET /patient/appointments?bucket=upcoming` kept
  returning the booking as `pending_payment` until a later sweep cancelled it (`cancelled_by:
  system`, `payment_timeout`): LKSB-2610-00213 deadline 08:57:38, cancelled 08:57:49 (11 s);
  LKSB-2610-00212 deadline 08:12:57, cancelled 08:13:49 (52 s); LKSB-2610-00216 deadline 10:59:17,
  cancelled 10:59:50 (33 s); LKSB-2610-00218 deadline 11:25:57, cancelled 11:26:50 (53 s).
- **Effect:** in that window the booking still counts in "Upcoming" and its slot is still held,
  although it can no longer be paid.
- **App side (done 6 Oct):** Home and the Appointments tab hide the card at the deadline (server
  clock) and re-read the list every 15 s until the server has released it, so the patient never sees
  a payable-looking card after its deadline; the count catches up when the server releases it.
- **Needed:** release the hold at the deadline itself (or have every read treat
  `pending_payment` with a past `booking_deadline_at` as expired), so lists, counts and slot
  availability agree with the deadline the app was given.

## BB-38 — The upload size limit is not in app-config

**Rows:** Records audit (6 Oct 2026), "Upload document" — and every other upload (insurance files,
support attachments), which share the same limit.

- **Seen (6 Oct 2026):** the largest file the server accepts is a platform setting staff can
  change (`platform_settings.upload_max_bytes`, default 10 MB, Q117). `POST /shared/files/uploads`
  enforces it (`413 FILE_TOO_LARGE` with `meta.max_bytes`), but `GET /shared/app-config` does not
  include it, so before an upload the app cannot know the real limit.
- **App side (done 6 Oct):** "10 MB" is no longer written into the app. The check before sending
  and the "up to … MB" line read `upload_max_bytes` from app-config and fall back to 10 MB while
  it is missing. A refusal from the server now names the limit from `meta.max_bytes` ("That file
  is too large. The limit is 5 MB.").
- **Needed:** add `"upload_max_bytes": <int>` to `GET /shared/app-config` (it is already in the
  public settings view), and to the contract (§3.1, §11.1).

## BB-39 — A doctor on leave has no return date

**Rows:** Doctor & Hospital details audit (6 Oct 2026), Doctor Details — "This doctor is on leave
and not taking bookings."

- **Seen (6 Oct 2026):** `GET /patient/doctors/{id}` sends `status: "on_leave"` but nothing about
  the leave itself. The hospital enters leaves with their dates
  (`/hospital/doctors/{id}/leaves`), so the server knows when the doctor is back; the patient
  app does not, and can only say "on leave". No staging doctor is on leave (BB-08), so the
  screen was checked in code and in tests.
- **App side:** the line stays as it is until a date is sent; it will read "On leave until
  20 Oct" from the server's date, with no other change to the screen.
- **Needed:** the end date of the current (or next) leave on the doctor payload — e.g.
  `"on_leave_until": "2026-10-20"` (hospital-local date) on `GET /patient/doctors/{id}` and on the
  doctor cards — and in the contract (§7.8, §17).

## BB-40 — How long a slot is held for payment is not sent before booking

**Rows:** Home quick links audit (6 Oct 2026), Book Appointment step 4 — "The slot is then held
for a few minutes while you pay — the next screen counts them down."

- **Seen:** the hold is a per-hospital setting (`hold_timeout_seconds`, 300 s by default, Q80–81)
  that sets `booking_deadline_at` when `POST /patient/appointments` books. Nothing the app reads
  before booking carries it — not `GET /patient/hospitals/{id}`, not `GET /patient/fee-quotes` —
  so step 4 can only say "a few minutes".
- **App side (done 6 Oct):** once a booking exists, the step-4 note and the "Leave without
  paying?" dialog give its deadline ("Complete the payment by 9:31 PM"). Before booking, "a few
  minutes" stays until the length is sent.
- **Needed:** `"hold_timeout_seconds": 300` (or a minutes field) on `GET /patient/hospitals/{id}`
  — or on the fee quote — and in the contract (§7.3 / §8.3).

## BB-41 — A refused coupon in the fee quote carries only its code

**Rows:** Home quick links audit (6 Oct 2026), Book Appointment step 4 — "Have a coupon?".

- **Seen:** `GET /patient/fee-quotes?coupon_code=` answers
  `coupon: {code, valid: false, reason: "COUPON_…"}` — the error code only. The server knows
  more and drops it here: its own message for two `COUPON_INVALID` cases ("This coupon is valid
  for online bookings only.", "This coupon does not apply to this booking.") and the minimum for
  `COUPON_MIN_ORDER` (`meta.min_order_paise`). So the app can only say "That coupon code is not
  valid." or "The order is below the minimum for that coupon." with no amount.
  `COUPON_USAGE_CAP` is raised for both the overall and the per-patient limit, so "used up" and
  "you have already used it" cannot be told apart (seen with `LAKE10` on staging).
- **Needed:** on the quote's `coupon`, the server's `message` and `meta` (at least
  `min_order_paise`); ideally a distinct code or a meta flag for the per-patient limit.

## BB-42 — Hospital list rows have no time zone

**Rows:** Home quick links audit (6 Oct 2026) — "Next free 9:00 AM tomorrow" on the hospital cards
(Home, the Hospitals list, booking's "Choose a hospital").

- **Seen:** `next_available_at` is UTC. `GET /patient/hospitals/{id}` sends `timezone`, but the
  rows of `GET /patient/hospitals` do not, so the cards turn the instant into a clock time in the
  phone's zone: right on a phone set to IST, off by the difference anywhere else.
- **Needed:** `"timezone": "Asia/Kolkata"` on each row of `GET /patient/hospitals` (and on the
  hospital rows of `GET /patient/search`).

## BB-43 — Test data: four of the six areas have no hospitals

**Rows:** Home quick links audit and Choose a location audit (6 Oct 2026), Hospitals → "Choose a
location".

- **Seen:** `GET /patient/locations` lists six areas, but only Kadavanthra (Lakeshore) and
  Shivajinagar (Sahyadri) have a hospital. RS Puram (Coimbatore), Jubilee Hills (Hyderabad),
  Edappally (Kochi) and Kothrud (Pune) each open "0 hospitals — We have not partnered with a
  facility here yet." Two of them, RS Puram and Jubilee Hills, are also marked
  `is_popular: true`, so half of "Popular right now" leads nowhere.
- **Needed:** hospitals in those areas, or those areas left out of `GET /patient/locations` (or
  at least not popular) until there are. A `hospital_count` on each location would also let
  the app say so on the row.

## BB-44 — Test data: no account or region where Notifications, Ambulance or FAQ is empty

**Rows:** Screen Coverage sheet — Notifications, Ambulance and FAQ, "Empty state" column (7 Oct 2026).

- **Seen:** every seeded patient has notifications (Sanjay 29 unread, Jacob 52, Vivek 36); the
  ambulance directory returns the same providers for every account and area; the FAQ always has
  entries. The empty screens exist in the app ("No notifications yet", an empty directory, an empty
  FAQ) but cannot be shown on this server.
- **Needed (any one per screen):** a patient account with no notifications (BB-03's throwaway account
  would do, if it starts with none); an area or filter whose ambulance directory is empty; the FAQ
  unpublished for a short window (or a test category with no entries).

## BB-45 — A patient cannot change their email address

**Rows:** Edit Profile audit (7 Oct 2026), "How we reach you" → Email.

- **Seen:** `PATCH /patient/me` takes no `email` (§5.2: "Phone and email cannot be changed
  here"), and no other call changes it. Edit Profile therefore shows the email read-only with
  "Changing the email address is not available yet." A patient who mistyped it at sign-up, or
  lost access to it, keeps getting receipts and reminders at the wrong address with no way to
  fix it in the app.
- **Needed:** a way to change the email, for example the same shape as the mobile number
  (§5.3): start with the new address, confirm with a code sent to it, then `200 User` with the
  new `email`; plus a way to add one when the account has none. Written into the contract.
- **App side:** once it exists, the Email row gets a "Change" button like the mobile number's.

## BB-46 — Question: can date of birth and gender be cleared once set?

**Rows:** Edit Profile audit (7 Oct 2026), Date of birth and Gender.

- **Seen:** `GET /patient/me` documents both as nullable, and blood group and last name can be
  cleared by sending `null`. For `date_of_birth` and `gender` the contract does not say whether
  `null` is accepted on `PATCH /patient/me`. In the app, once set they can only be changed, not
  removed (Gender can be set to "Prefer not to say", `undisclosed`).
- **Needed:** confirm whether `null` is accepted for each (and that `date_of_birth: null` is not
  refused by the 18+ check), and write it into §5.2. If it is, the app can offer a "Clear"
  option; if not, nothing changes.
