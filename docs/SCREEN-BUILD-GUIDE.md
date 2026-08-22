# Medibook Screen Build Guide (Presentation)

How to build the 15 screens so the parallel feature agents stay consistent. Read
this + `docs/DESIGN-SPEC.md` (§4 screens, §5 nav, §6 behavior) + the widget APIs
in `docs/COMPONENT-CONTRACT.md`. Exact per-screen layout values live in
DESIGN-SPEC §4 — this guide fixes the wiring, file placement, and shared rules.

## Cross-cutting rules (apply to every screen)

1. **ScreenUtil everywhere** — `.w/.h/.sp/.r`, never raw pixels, never `const`
   over a `.sp/.w/.h/.r` subtree. Import `flutter_screenutil`.
2. **Tokens only** — `AppColors`, `AppText`, `AppRadii`, `AppShadows`,
   `AppSpacing`. No literal hex / magic numbers.
3. **No prototype chrome.** Do NOT render the faux 9:41 status bar, the 390×844
   frame, or the reviewer jump-menu. Those are prototyping artifacts.
4. **SafeArea + the −44 rule.** Wrap each screen body in `SafeArea`. The design's
   top paddings include a 44px faux status bar; subtract it. So:
   - inner-screen header (`AppInnerHeader`) top = **12.h** (56−44) — already baked
     into the component.
   - tab-title header (`AppTabHeader`) top = **12.h** — baked in.
   - Home navy header top = **14.h** (58−44).
   - Login content top = **34.h** (78−44).
   All other paddings are the design values as-is.
5. **Screen enter animation** — pushed screens fade+rise (`screenIn`, 220ms,
   opacity + 10px). Tab screens fade (`fadeIn`). Wrap the screen body in a small
   `TweenAnimationBuilder`/`FadeTransition`. Keep it restrained; no bounce.
6. **Navigation** — use `go_router` via `context.go(...)` / `context.push(...)`
   with the constants in `app/router/app_routes.dart`. Tab screens are inside the
   bottom-nav shell; everything else is pushed. Booking entry uses
   `AppRoutes.bookingPath(step:, dept:, doctor:, origin:)`. Doctor detail uses
   `AppRoutes.doctorPath(id, returnTo:)`. Do NOT hardcode path strings.
7. **Toasts** — from a **callback** only: `ref.read(toastControllerProvider.notifier).show('…')`.
   Never from `build`.
8. **Widget type / Riverpod** (QA Prompt 6):
   - `ref.watch(...)` only in `build`; `ref.read(...)` only in callbacks.
   - `ConsumerWidget` when reading a provider; `StatefulWidget`/
     `ConsumerStatefulWidget` only for local visual state + controllers;
     `StatelessWidget` for pure param widgets.
   - Extract any card/list-item repeated on a screen into a component under the
     feature's `presentation/components/`.
9. **Forms** — the screen is a `ConsumerStatefulWidget` owning the
   `TextEditingController`s (input mechanics). Validation **errors** and other
   transient selections live in an **autoDispose** provider/StateNotifier in the
   feature's `presentation/controllers/`. Validate with `Validators`
   (`core/utils/validators.dart`) in the submit callback.
10. **No infrastructure imports.** Presentation reads seed via the providers in
    `core/mock_data/seed_providers.dart` and the shared controllers. No Hive, no
    Dio, no direct `MedibookSeed` access from a screen.

## Feature file layout (per the folder CSV)

```
features/<feature>/presentation/
├── screen/         full pages (ConsumerWidget / ConsumerStatefulWidget)
├── components/     reusable pieces for this feature
└── controllers/    autoDispose StateNotifiers / StateProviders for local UI state
```
Shared controllers already exist — **consume, don't recreate**:
- `features/appointments/presentation/controllers/appointments_controller.dart`
  → `appointmentsControllerProvider`, `appointmentsByBucketProvider(bucket)`,
  `firstUpcomingAppointmentProvider`, `appointmentByIdProvider(id)`.
- `features/booking/presentation/controllers/booking_controller.dart`
  → `bookingControllerProvider` (+ `BookingDraft`, `BookingOrigin`).
- `features/dashboard/presentation/controllers/banner_controller.dart`
  → `bannerControllerProvider`.
- `core/widgets/toast/toast_controller.dart` → `toastControllerProvider`.
Read providers: `core/mock_data/seed_providers.dart`.

---

## Auth feature (`features/auth/…`) — 5 screens

Route/screen files: `login_screen.dart` (`/login`), `signup_screen.dart`
(`/signup`), `forgot_password_screen.dart` (`/forgot`), `verify_code_screen.dart`
(`/verify`), `new_password_screen.dart` (`/reset`).

- All on `AppColors.surface` background. Inner screens use `AppInnerHeader`
  (back → previous auth screen). Login has no header; content top `34.h`.
- Use `AppTextField`, `AppButton(fullWidth)`, `AppCheckbox`. Social buttons are
  three 50px circular bordered buttons (G/f/X) — a small `components/social_row.dart`.
- Validation per DESIGN-SPEC §6: email regex, password ≥6, confirm match, terms
  required. Errors via an autoDispose form controller; clear on next keystroke.
- **Demo affordances gated behind `FeatureFlags.demoMode`**: prefill
  `AppConstants.demoEmail`/`demoPassword` on login, show the "Demo login is
  prefilled" line and "Demo code: 1234" line, and prefill the forgot email.
- Verify: 4 × 60×60 OTP boxes, digits-only, auto-advance, only `1234` passes
  (`AppConstants.demoOtpCode`) → `/reset`. Wrong → error + red borders.
- Login "Log In"/social → `/home`. Signup success → `/home` + welcome toast.
  Reset → `/login` + toast. Send Code → `/verify` + toast.
- Components: `components/auth_logo.dart` (login brand mark), `components/social_row.dart`.

## Dashboard/Home (`features/dashboard/…`) — `/home` (tab)

`screen/home_screen.dart`. Navy header (top `14.h`) + scrolling body + it sits in
the bottom-nav shell (nav provided by the shell, not this screen).
- Header: "Welcome back," + `MedibookSeed.userFirstName` via a small greeting;
  bell `AppIconButton(onBrand,40)` → `/notifications`; 42px ringed `AppAvatar` →
  `/profile`; white pill search bar (tap → `/search`). Use `userFirstName` from a
  provider is fine, or read `MedibookSeed.userFirstName` is data — expose via a
  tiny provider if you prefer; a const greeting string is acceptable here.
- Banner: `promoBannersProvider` + `bannerControllerProvider`. 150px card,
  `AppRadii.lg`, gradient (135°), dot indicator (active 18w/white, inactive
  7w/white50), tap → `ref.read(bannerControllerProvider.notifier).next()`. Slide
  0 shows the right-masked `doctor-portrait.png` (linear mask, right 46%). Use
  `carousel_slider` OR a `PageView` synced to the controller.
- "Your Token" card: only when `firstUpcomingAppointmentProvider != null`; shows
  its token; tap → `AppRoutes.appointmentDetailPath(appt.id)`.
- Quick Booking row (Appointment/Lab Tests/Family) + Available Services row
  (General Physician/Skin & hair Care/Women's Health) + "View All". Taps →
  booking: General → `bookingPath(step:2, dept:'General')`; Skin & hair →
  `bookingPath(step:2, dept:'Dermatology')`; others → `bookingPath(step:1)`.
- Components: `components/home_header.dart`, `components/promo_banner_card.dart`,
  `components/token_card.dart`, `components/quick_action_grid.dart` (reused by
  both the Quick Booking and Services rows).

## Search (`features/search/…`) — `/search` (pushed)

`screen/search_screen.dart`. `AppInnerHeader('Search', onBack→/home)` + pill
input (autofocus after `AppConstants.searchAutoFocusDelay`). Local
`searchQueryProvider` (autoDispose `StateProvider<String>`). Derive filtered
Departments and Doctors from `departmentsProvider`/`doctorsProvider` (match name +
spec + dept + descriptor, per §6, so "skin" finds Dr. Sara Ali). Dept row →
`bookingPath(step:2, dept: name)`; doctor row → `doctorPath(id, returnTo:'search')`.
Empty state when both lists empty. Components: `components/search_result_row.dart`.

## Notifications (`features/notifications/…`) — `/notifications` (pushed)

`screen/notifications_screen.dart`. `AppInnerHeader('Notifications', onBack→/home)`
+ "Recent Notifications" / "Mark all as read" row. Cards from
`notificationsProvider`; map `NotificationAction` → handlers in a callback:
- `rescheduleTodayAppt` → `reschedulePath('1')` (guard: if appt 1 no longer
  upcoming, toast "That appointment was cancelled").
- `viewTodayApptDetail` → `appointmentDetailPath('1')` (same guard).
- `viewRecords` → `/records`. `downloadPrescription` → toast "Downloading
  prescription…". `remindLater` → toast "We'll remind you tomorrow".
  `scheduleBooking` → `bookingPath(step:1)`.
Action buttons: secondary pill + primary pill (`AppButton size:sm, pill:true`).
Component: `components/notification_card.dart`.

## Booking (`features/booking/…`) — booking + doctor + success

`screen/booking_screen.dart` (`/booking`), `screen/doctor_detail_screen.dart`
(`/doctor/:id`), `screen/booking_success_screen.dart` (`/success`).

- **Booking**: `ConsumerStatefulWidget`. In `initState`, read query params
  (`step`,`dept`,`doctor`,`origin`) and call
  `ref.read(bookingControllerProvider.notifier).configure(...)`. `AppInnerHeader`
  ('Book Appointment', back = a callback that calls `controller.back()`; if it
  returns false, pop the route to origin). `AppStepper(current: draft.step)`.
  Sticky footer button (Continue on 1-3, disabled until `draft.canContinue`;
  "Confirm and Pay" on step 4). Steps per DESIGN-SPEC §4:
  - Step 1: 2-col dept grid from `departmentsProvider`, selected border 1.5px brand,
    tap → `controller.pickDepartment`.
  - Step 2: `AppSegmentedTabs(tabs: dept names, active: draft.departmentName)` +
    doctor cards (filtered by dept from `doctorsProvider`), card tap →
    `doctorPath(id, returnTo:'booking')`.
  - Step 3: patient cards (`patientsProvider`, relation `AppTag`), date chip row
    (`AppDates.upcomingChips()`), time chip grid (`timeSlotsProvider`). Selection
    → controller.
  - Step 4: confirm card (doctor header + rows Patient/Department/Date/Time/
    **Token** (accent-blue,700)/**Consultation Fee** (navy,700)). Token =
    `ref.read(appointmentsControllerProvider.notifier).nextToken`.
  - Confirm and Pay → `appointmentsController.book(...)` → returns Appointment →
    `context.go(AppRoutes.successPath(appt.id))`.
  - Components: `components/department_card.dart`, `components/doctor_card.dart`,
    `components/patient_card.dart`, `components/date_chip.dart`,
    `components/time_chip.dart`, `components/confirm_summary.dart`.
- **Doctor detail**: reads `doctorByIdProvider(id)` and `return` query. Hero card
  (88px avatar, name, spec·hospital, `AppRating` showValue, 3-up stat grid),
  About card, clinic card (`hospital.jpg` 54px thumb + location). Footer "Book an
  appointment" → `bookingPath(step:3, dept: doctor.department, doctor: id,
  origin:'home')` (origin = booking's origin if returnTo=='booking', else 'home').
  Back → returnTo (booking/search/home).
- **Success**: reads `appointmentByIdProvider(query 'appt')`. 84px navy check
  circle, "Appointment Booked successfully", token (accent-blue), date·time·doctor
  line, "View Appointment" → `appointmentDetailPath(id)`, soft "Back to Home" →
  `/home`.

## Appointments (`features/appointments/…`) — list + detail + reschedule

`screen/appointments_screen.dart` (`/appointments`, tab),
`screen/appointment_detail_screen.dart` (`/appointment/:id`),
`screen/reschedule_screen.dart` (`/reschedule/:id`).

- **List**: `AppTabHeader('Appointments', trailing: bell→/notifications)` +
  `AppSegmentedTabs(['Upcoming','Past'])` (local autoDispose
  `apptTabProvider`). Cards from `appointmentsByBucketProvider(bucket)`: 48px
  avatar (doctor via `doctorByIdProvider`), doctor name, `spec · patientFirst`,
  status `AppStatusPill(AppStatusStyle.appointment(status))`, hairline, calendar+
  date, clock+time, token pill (`AppStatusStyle.token`). Empty state. Bottom
  "Book an appointment" → `bookingPath(step:1, origin:'appointments')`. In the
  bottom-nav shell. Component: `components/appointment_card.dart`.
- **Detail**: `appointmentByIdProvider(id)` + `doctorByIdProvider`. Header card,
  detail rows Patient/Department/Hospital/Date/Time/**Token**, arrival note.
  Upcoming footer: "Reschedule" (soft → `reschedulePath(id)`) + "Cancel" (danger →
  `showMedibookSheet` confirm → `appointmentsController.cancel(id)` → go
  `/appointments` + toast). Past footer: "Book Again" →
  `bookingPath(step:3, dept, doctor:doctorId, origin:'appointments')`.
- **Reschedule**: current appt card ("Currently: date · time"), new date chips,
  new time chips (local autoDispose selection controller in
  `controllers/reschedule_controller.dart`), "Confirm New Time" →
  `appointmentsController.reschedule(id, ...)` → go `/appointment/:id` + toast.

## Records (`features/records/…`) — `/records` (tab)

`screen/records_screen.dart`. `AppTabHeader('Records', trailing: bell)` +
"Recent Records" + record cards from `recordsProvider`: title, date, status
`AppBadge(tone: completed→success / pending→danger)`, 3 meta rows
(records/hospital/records icons), "View Report" (secondary pill, eye → toast
"… preview stubbed") + "Download" (primary pill, download → toast "Downloading
…"). In the shell. Component: `components/record_card.dart`.

## Profile (`features/profile/…`) — `/profile` (tab)

`screen/profile_screen.dart`. `AppTabHeader('Profile')` (no trailing). Identity
card (56px avatar initials, name, email ellipsis, `edit` `AppIconButton(tint)` →
toast "Profile editing is stubbed"), Personal Information card + Edit link from
`profileInfoProvider`, "Available for Donation" card with `AppSwitch` (local
autoDispose `donationProvider`, seeded true; toggle → toast), Logout + Delete rows
→ `showMedibookSheet` (logout confirm → `/login`; delete confirm → toast + stay).
In the shell. Component: `components/profile_info_card.dart`.
