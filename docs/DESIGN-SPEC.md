# Medibook Mobile App — Design Spec (extracted from the Claude Design handoff)

Single source of truth for implementation. Everything here was read out of the
handoff bundle; nothing is invented. Read this instead of re-reading the 100 KB
prototype — go back to the prototype only when you need an exact value not listed here.

**Source of truth files**
| What | Path |
|---|---|
| Primary design (all 15 screens + logic) | `project/Medibook App.dc.html` |
| Design-system tokens | `project/_ds/design-system-medibook-mob-40b6326a-b9da-4636-9f81-3f2f78942b98/tokens/*.css` |
| DS component source (readable JSX-compiled) | `project/assets/ds-bundle-patched.js` (lines 202–1119) |
| DS documentation | `project/_ds/design-system-medibook-mob-.../readme.md` |
| Design chat / intent | `chats/chat1.md` |
| Images | `project/assets/images/{doctor-portrait.png,hospital.jpg}` |
| Figma original | `project/uploads/Medibook - Mobile UI - For Claude design.fig` (19 MB, read-only) |

`project/support.js` is the Claude Design runtime (`dc-runtime`) that interprets
`<x-dc>`, `<sc-if>`, `<sc-for>` and `{{ }}` bindings. **It is not app code — do not port it.**
The prototype's internal structure is a prototyping medium; match the *visual output*,
not the markup.

---

## 1. Product

Medibook is a mobile patient app: book doctor appointments, manage appointments,
view lab/health records, manage profile. Voice is *warm, reassuring, plain-spoken* —
title case for titles and buttons, sentence case for body, no emoji.

Scope locked with the user in `chats/chat1.md`:

- **Full auth set** (login, sign-up, forgot password, verify code, new password)
- **Appointments tab** = My Appointments list (Upcoming/Past) + booking from there
- **Bare mobile screen** (no phone-chrome bezel art beyond the frame itself)
- **Unified persona**: Alexandra Johnson
- Polish required: screen transitions, banner auto-rotate, working search, form
  validation, confirmation toasts
- Appointment **detail screen with reschedule/cancel**
- Demo reset code **1234**; demo login **prefilled**
- Start screen: **Login**
- Secondary screens built: **Doctor detail** (about, fee, rating) and **Reschedule flow**
- Explicit user note: *"this is a prototype to visualize the whole app, so no complicated
  backend needed; all functions should work for understanding."*
- Later requirement (added in the UI-audit round): tapping Search opens a **dedicated
  Search page**, not an overlay. The design already reflects this.

---

## 2. Design tokens

All values are CSS custom properties defined in `tokens/`. Port them verbatim to
whatever the target platform's token layer is.

### Color (`tokens/colors.css`)

```
Primary ramp   --primary-100 #E6ECFA   --primary-200 #B0C4EF   --primary-300 #739EE4
               --primary-400 #4979BE   --primary-500 #325689   --primary-600 #1D3557
               --primary-700 #0A172A
Brand          --brand = --primary-600 (#1D3557)   --brand-deep = --primary-700
Accent         --accent-blue #1648CE (links, "Your Token", "View All")
               --info-blue   #006BD5
Grey ramp      --grey-100 #EBECEE  --grey-200 #C1C5C9  --grey-300 #999EA3
               --grey-400 #75797D  --grey-500 #535659  --grey-600 #333537
               --coal #1C1C1C      --ink #141414
Surfaces       --bg-app #F3F3F3    --surface #FFFFFF
               --surface-alt #F7F8FA (input fill)   --surface-tint #E6ECFA
Borders        --border #D1D4DB    --border-subtle #EBECEE
Text           --text-strong #1D3557   --text-primary #141414   --text-body #5E5D5D
               --text-muted #8E98A8    --text-on-brand #FFFFFF  --text-link #1648CE
Semantic       --success #2E9E5B  --success-soft #BFE6CC  --success-text #1B6B3A
               --danger  #E14C4C  --danger-soft  #F3C2C2  --danger-text  #B23535
               --warning #F5A623  --warning-soft #FCE6BE
```

### Type (`tokens/typography.css`)

- `--font-sans`: **Poppins** (all UI) → fallback `-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif`
- `--font-alt`: **Inter** (dense data / tiny meta)
- Weights: 400 / 500 / 600 / 700 (`--fw-regular|medium|semibold|bold`)
- Scale: `--fs-display 40` · `--fs-h1 28` · `--fs-h2 22` · `--fs-h3 20` · `--fs-title 18` ·
  `--fs-body 16` · `--fs-base 14` · `--fs-sm 13` · `--fs-xs 12` · `--fs-xxs 11`
- Line heights: `--lh-tight 1.2` · `--lh-snug 1.35` · `--lh-normal 1.5`
- Letter spacing: `--ls-tight -0.02em` · `--ls-normal 0`
- Fonts load from Google Fonts. For a native/offline target, self-host Poppins + Inter woff2.

### Spacing, radii, shadows (`tokens/spacing.css`)

- Spacing: 4 · 8 · 12 · **16 (default gutter & card padding)** · 20 · 24 · 32 · 40
- Radii: `--radius-sm 8` · `--radius-md 12` (buttons/inputs) · `--radius-lg 16` (cards/banners) ·
  `--radius-xl 24` (sheets, hero bottom) · `--radius-pill 999`
- Borders: `--border-width 1px` · `--border-width-strong 1.5px`
- Shadows: `--shadow-xs 0 1px 2px rgba(29,53,87,.05)` · **`--shadow-sm 0 2px 8px rgba(136,133,133,.18)`** (the card default) ·
  `--shadow-md 0 6px 20px rgba(29,53,87,.10)` · `--shadow-lg 0 12px 32px rgba(29,53,87,.14)`
- Layout: `--screen-max 390px` · `--tap-min 44px`

### Frame

Device frame in the prototype: **390 × 844**, `border-radius: 34px`, `overflow: hidden`,
background `--bg-app`. A faux status bar sits at `top:0`, height 44px, `z-index:60`,
`pointer-events:none`, showing `9:41` + signal/wifi/battery SVGs. Status-bar text is
white on Home (navy header) and `--text-strong` everywhere else. **The status bar is
prototype chrome — on a real device, drop it and use the OS status bar.**

---

## 3. Component library (16 components)

Namespace in the prototype: `DesignSystemMedibookMob_40b632`. Exact props and styling,
read from `project/assets/ds-bundle-patched.js`. Rebuild these as the app's component
layer first — every screen is assembled from them.

| Component | Props | Notes |
|---|---|---|
| `Icon` | `name`, `size=24`, …rest | Renders `<svg>` with Iconsax path data, `fill="none"`, paints via `currentColor`. Returns `null` for unknown names. |
| `Avatar` | `src`, `name=''`, `size=44`, `ring=false`, `style` | Circle, `overflow:hidden`, tint bg, brand-colored initials (first 2 words) at `size*0.38` when no `src`. `ring` → `0 0 0 2px var(--surface), 0 0 0 3.5px var(--brand)`. |
| `Badge` | `children`, `tone='neutral'`, `style` | Pill, padding `6px 14px`, `--fs-sm`, weight 500. Tones: `neutral · brand · success · danger · warning`. |
| `Button` | `children`, `variant='primary'`, `size='md'`, `pill=false`, `fullWidth=false`, `leadingIcon`, `trailingIcon`, `disabled=false`, `style` | Sizes `sm{h38,px16,fs13,gap6,icon16} · md{h48,px22,fs16,gap8,icon18} · lg{h54,px26,fs16,gap10,icon20}`. Variants `primary` (navy fill) · `secondary` (1.5px navy outline) · `ghost` · `danger` · `soft` (tint bg, navy text). Radius: pill or `--radius-md`. Disabled → opacity .5, `not-allowed`. Press → `scale(0.98)`. |
| `Card` | `children`, `padding=16`, `radius='lg'`, `shadow='sm'`, `interactive=false`, `style` | White surface. `interactive` lifts to `--shadow-md` on hover. |
| `IconButton` | `icon`, `size=44`, `iconSize`, `variant='plain'`, `style` | Circular. Variants `plain · onBrand · tint · outline`. Icon defaults to `round(size*0.5)`. Press → `scale(0.92)`. |
| `Rating` | `value=0`, `max=5`, `size=16`, `showValue=false`, `onRate`, `style` | Filled stars `--warning`, empty `--grey-200`, `gap 3`. `showValue` appends `value.toFixed(1)` at `--fs-sm`/500/`--text-body`, `marginLeft 6`. |
| `Tag` | `children`, `active=false`, `style` | Pill `4px 12px`, `--fs-xs`/500. Active = navy fill/white; else tint/navy. |
| `Checkbox` | `checked=false`, `onChange`, `label`, `error=false`, `style` | 20×20, `radius 6`, 1.5px border (`--danger` on error, `--brand` when checked, else `--grey-300`), white checkmark path `M5 12l4.5 4.5L19 7`. Label `--fs-sm`, `lh 1.45`. |
| `Input` | `label`, `icon`, `hint`, `error`, `style`, `wrapStyle`, …rest | Label `--fs-base`/500/`--text-strong`, `mb 8`. Field: `h 52`, `padding 0 16`, bg `--surface-alt`, 1px border (`--danger` on error), `--radius-md`. Hint/error line `--fs-xs`, `mt 6`. |
| `Radio` | `checked`, `onChange`, `label`, `style` | 20×20 circle, 10px navy dot. |
| `Select` | `label`, `value`, `placeholder='Select'`, `options=[]`, `onChange`, `style` | Matches `Input` field styling; custom chevron `M6 9l6 6 6-6`. Options accept strings or `{value,label}`. |
| `Switch` | `checked`, `onChange`, `style` | Track 46×26 pill (`--brand` on / `--grey-200` off); 20px white knob, `left 3 → 23`, `.18s ease`. |
| `BottomNav` | `active='home'`, `onChange`, `style` | 4 tabs: `home · appointments · records · profile`. Inline 25×25 glyphs (house/bag/hospital/person), filled when active. Active `--brand` + weight 600; inactive `--grey-300` + 400. Bar padding `12px 8px 18px`, top border `--border-subtle`. |
| `SegmentedTabs` | `tabs=[]`, `active`, `onChange`, `style` | Horizontal scroll pill row, `gap 8`, each `9px 18px`, `--fs-sm`/500. Active navy fill/white; else white + `--border` + `--text-body`. |
| `Stepper` | `steps=4`, `current=1`, `style` | 30px circles + 2px connectors. Done/active navy + white; pending `--surface-tint` + `--primary-300`. Connector navy when `n < current`, else `--grey-100`. |

### Icons

Iconsax (vuesax) 24×24, line + bold. Aliases → canonical keys:

```
calendar · clock · location · search · bell · eye · download · edit · star · video
hospital · bag · records · back · close · close-circle · logout · moon
```

Each has a `-bold` filled variant except `close` (bold only) and `close-circle` (line only).
Glyphs paint with `currentColor`.

**Bundle patch — important.** The DS shipped `_ds_bundle.js` is broken; the app loads
`assets/ds-bundle-patched.js` instead. Two fixes, both must survive any re-import:
1. The icon-data module opened with `void {` instead of `__ds_scope.icons = {`, so no icon
   ever registered and every render crashed.
2. `StarStyleBold` carried a stray full-canvas `<path d="M 24 0 L 0 0 L 0 24 L 24 24 L 24 0 Z">`
   rect, which rendered rating stars as solid orange squares. Removed.

---

## 4. Screen inventory

15 screens + 2 overlays. Names below are the prototype's `data-screen-label`; the
state key is in parentheses.

### Auth
1. **Login** (`login`) — logo mark (52px navy rounded square, `hospital` icon 28px) + "Medibook" 22/700; "Hi, Welcome Back!" 24/700; "Hope you're doing fine." 14 muted. Email + Password inputs, "Remember me" checkbox + "Forgot password?" link, full-width **Log In**, "OR" divider, three 50px circular social buttons (G/f/X), "Don't have an account yet? Sign up". Demo credentials prefilled (`alexandra.johnson@example.com` / `medibook123`). Padding `78px 24px 32px`.
2. **Sign Up** (`signup`) — back + "Create Account". Full Name, Email, Phone (`+91 00000 00000`), Password; terms checkbox; **Sign Up**; "Already have an account? Log In".
3. **Forgot Password** (`forgot`) — back + "Reset Password". Copy: *"Enter your Email, we will send you a verification code."* Email field, **Send Code**.
4. **Verify Code** (`verify`) — back + "Verify Code". Four 60×60 OTP boxes (`gap 14`, 24/600, `--surface-alt`, `--radius-md`, focus `1.5px solid var(--brand)`), auto-advance on entry, error line under, "Demo code: 1234", **Verify**, "Didn't get the code? Resend Code".
5. **New Password** (`reset`) — back + "New Password". New Password (≥6) + Confirm Password, **Reset Password**.

### Main
6. **Home** (`home`) — navy header (`padding 58px 20px 22px`, bottom radius 26px): "Welcome back," 16/400 @.9 opacity + "Alexandra!" 26/700; bell IconButton (`onBrand`, 40) + 42px ringed avatar → Profile; white pill search bar (h52) → Search screen. Body: 150px rotating banner card (`--radius-lg`), "Your Token" card (shown only when an upcoming appointment exists) → appointment detail, **Quick Booking** row (Appointment / Lab Tests / Family), **Available Services** row with "View All" (General Physician / Skin & hair Care / Women's Health). BottomNav active `home`.
7. **Search** (`search`) — back + "Search", pill input (autofocus ~260 ms after nav), live-filtered **Departments** list (row → booking step 2 for that dept) and **Doctors** list (row → Doctor Details), empty state *No matches for "…"*. Matching spans doctor name + specialty + dept + the dept's descriptor, so "skin" finds Dr. Sara Ali.
8. **Notifications** (`notifs`) — back + "Notifications"; "Recent Notifications" + "Mark all as read"; cards with title, body, clock + relative time, and an optional 2-button action row (secondary pill + primary pill).
9. **Book Appointment** (`booking`) — back + title + 4-step `Stepper`, sticky footer button.
   - Step 1 "Please select the department" — 2-col grid of 4 dept cards, selected card gets a `1.5px solid var(--brand)` border.
   - Step 2 "Select a doctor" — `SegmentedTabs` of dept names + doctor cards (56px avatar, name, `spec · exp`, `Rating` with value, fee + "per visit"). Hint: *Tap a doctor to view details and book*.
   - Step 3 — "Select patient" cards (avatar, name, meta, relation `Tag`), "Select date" horizontal chip row (5 days from today, first labelled *Today*), "Select time" wrapped chip grid.
   - Step 4 "Confirm appointment" — doctor header + rows Patient / Department / Date / Time / **Token** (accent blue, 700) / **Consultation Fee** (navy, 700); footnote about desk payment and the 2-hour reschedule window.
   - Footer: **Continue** (disabled until step 1 dept / step 2 doctor chosen) on steps 1–3; **Confirm and Pay** on step 4.
10. **Doctor Details** (`doctor`) — back + title. Hero card: 88px avatar, name 19/700, `spec · hospital`, `Rating` w/ value, and a 3-up stat grid (Experience / Patients / Consultation) above a hairline. "About" card. Clinic card (54px `hospital.jpg` thumb, name, location icon + "Multi-speciality center"). Footer **Book an appointment** → booking step 3 pre-filled with that doctor.
11. **Booking Success** (`success`) — centered 84px navy circle with white check, "Appointment Booked successfully" 22/700, `Token: A-nn` (accent blue), date · time · doctor line, **View Appointment** + soft **Back to Home**.
12. **Appointments** (`appointments`) — title 22/700 + bell; `SegmentedTabs` Upcoming/Past; appointment cards (48px avatar, doctor, `spec · patient first name`, status pill; hairline; calendar+date, clock+time, token pill); empty state; **Book an appointment**; BottomNav active `appointments`.
13. **Appointment Details** (`apptDetail`) — header card (56px avatar, doctor, spec, rating, status pill), detail rows Patient / Department / Hospital / Date / Time / **Token**, note *"Please arrive 15 minutes early and carry any previous reports."* Footer: **Reschedule** (soft) + **Cancel** (danger) when Upcoming; **Book Again** when Past.
14. **Reschedule** (`resched`) — current-appointment card ("Currently: …"), "Select new date" chips, "Select new time" chips, **Confirm New Time** → toast *Appointment rescheduled*.
15. **Records** (`records`) — title + bell; "Recent Records"; per-record card with title, date, status `Badge` (`success`/`danger`), three meta rows (Patient Name / Center-Hospital / Consulted Doctor), and **View Report** (secondary pill, `eye`) + **Download** (primary pill, `download`). BottomNav active `records`.
16. **Profile** (`profile`) — "Profile" title; identity card (56px avatar, name 17/700, email with ellipsis, `edit` IconButton `tint`); "Personal Information" card + Edit link, rows Phone / Date of Birth / Gender / Blood Group; "Available for Donation" card with `Switch` and helper *"Hospitals can contact you for rare blood needs."*; Logout + Delete account rows (delete in `--danger`). BottomNav active `profile`.

### Overlays
- **Bottom sheet** — scrim `rgba(20,20,20,0.45)`, sheet `--surface`, top radius 24px, padding `26px 22px 30px`, centered title 18/700 + message, Cancel (soft) + confirm button. Used for Logout, Delete Account, Cancel Appointment. Clicking the scrim closes; clicks inside are swallowed.
- **Toast** — bottom 104px, `--coal` pill, white 13/500, `max-width 320px`, auto-dismiss after **2300 ms**.

---

## 5. Navigation graph

```
login ──Log In / social──▶ home
  ├─ Sign up ──▶ signup ──Sign Up──▶ home (+ welcome toast)
  └─ Forgot password ──▶ forgot ──Send Code──▶ verify ──1234──▶ reset ──▶ login (+ toast)

home ─ search bar ─▶ search ─ dept ─▶ booking(step 2)
                            └ doctor ─▶ doctor (back → search)
     ─ bell ─▶ notifs
     ─ avatar ─▶ profile
     ─ Your Token card ─▶ apptDetail(first upcoming)
     ─ Quick Booking / View All / Women's Health ─▶ booking(step 1)
     ─ General Physician ─▶ booking(step 2, dept=General)
     ─ Skin & hair Care ─▶ booking(step 2, dept=Dermatology)

booking 1 ▶ 2 ▶ 3 ▶ 4 ──Confirm and Pay──▶ success ─▶ apptDetail | home
   back on step>1 = previous step; on step 1 = origin (home or appointments)
   step 2 doctor card ─▶ doctor ──Book an appointment──▶ booking(step 3, that doctor)

appointments ─ card ─▶ apptDetail ─ Reschedule ─▶ resched ─▶ apptDetail (+ toast)
                                  └ Cancel ─▶ sheet ─▶ appointments (status Cancelled, moves to Past)
                                  └ Book Again (past) ─▶ booking(step 3)

BottomNav: home · appointments · records · profile (available on those 4 screens only)
```

---

## 6. Behavior and state

Prototype-level logic — port the behavior, not the implementation.

**Seed data** (`project/Medibook App.dc.html`, lines 780–823)
- 4 departments: General (`Primary healthcare`), Cardiology (`Heart specialists`),
  Orthopedics (`Bone & joint care`), Dermatology (`Skin specialists`).
- 6 doctors: Anya Sharma, Rohan Kapoor (Cardiology); Anil Kumar, Meera Nair (General);
  Priya Mehta (Orthopedics); Sara Ali (Dermatology). Each has spec, title, exp, patients,
  rating, fee (₹450–₹900), hospital (Apollo Hospital / City Care Clinic), and an About
  paragraph. Only Anya Sharma has a photo (`doctor-portrait.png`); the rest fall back to
  Avatar initials.
- 3 patients: Alexandra Johnson (Self), Michael Johnson (Husband), Ava Johnson (Daughter).
- 6 time slots: 09:00 AM, 10:00 AM, 11:30 AM, 12:15 PM, 02:00 PM, 04:30 PM.
- 3 records; 4 seeded appointments (2 Upcoming, 1 Completed, 1 Cancelled).
- Dates are generated live: 5 chips from today, first labelled "Today".

**Rules**
- Validation: email regex `/^[^\s@]+@[^\s@]+\.[^\s@]+$/`; password ≥ 6 chars; confirm must
  match; terms checkbox required on sign-up. Errors clear on the next keystroke.
- OTP: digits only, one char per box, auto-advance; only `1234` passes; wrong code →
  *"Incorrect code — the demo code is 1234"* and red borders.
- Banner: 2 banners, auto-rotates every **4000 ms** on Home only, pauses while a search
  query is active, tap advances manually. Dots: active 18px wide / white, inactive 7px / white @50 %.
- Token counter starts at 26; each confirmed booking takes `A-{n}` and increments.
  Newly booked appointments are prepended to Upcoming; Home's "Your Token" shows the
  first upcoming token.
- Cancelling sets status `Cancelled` and moves the appointment to the Past bucket.
- Status pills: `Completed` → success-soft/success-text, `Cancelled` → danger-soft/danger-text,
  anything else (`Confirmed`) → surface-tint/brand.
- Toasts fire on: sign-up welcome, code sent/resent, password reset, booking cancelled,
  rescheduled, record view/download, notification actions, donation toggle, and the two
  stubs (profile editing, account deletion).
- Animations: `screenIn` (opacity + 10px rise, .22s), `fadeIn` (.22s), `sheetUp`
  (48px rise, .25s), `toastIn` (10px rise, .22s). Restrained, 150 ms easing, no bounce.

**Prototype-only affordances** (drop or gate behind a debug flag in the real app)
- Prefilled demo credentials + "Demo login is prefilled" line
- "Demo code: 1234" hint and the hard-coded OTP
- `screenMenu` reviewer jump-menu prop and the `startScreen` / `autoRotate` props
- The faux 9:41 status bar and the 390×844 frame chrome

---

## 7. Known gaps carried over from the design review

From the UI audit at the end of `chats/chat1.md` — unresolved, listed by the designer in
priority order. These need decisions before or during implementation:

1. **High — user avatar photo.** Figma's header shows a real portrait, but the DS's
   `avatar-user.jpg` is a miscast blood-pressure photo, so Alexandra renders as initials.
   Needs the correct portrait re-exported from Figma.
2. **Medium — missing icon glyphs.** The DS bundle omitted Figma's colorful
   department/doctor illustration icons; booking dept tiles and records meta rows reuse
   approximate line glyphs (`records` / `star` / `hospital` / `eye`). Re-import to match Figma.
3. **Low — 4 department tabs overflow** the segmented row on booking step 2 (horizontal
   scroll; Figma showed 3). A wrap/compact variant needs a DS component change.

Additional notes for implementers:
- 5 of 6 doctors have no photo. Either source portraits or keep initials deliberately.
- Currency is ₹ (INR) and the phone placeholder is `+91`. Locale is India.
- No dark mode exists in the design. `moon` is in the icon set but unused.
- Accessibility was not specified: no focus rings beyond the OTP inputs, no ARIA, and
  `*::-webkit-scrollbar { display: none }` hides all scrollbars. Expect to add these.

---

## 8. Also in the bundle (not the current target)

`project/uploads/Medibook - Super Admin v1 (7)/` is a **separate, complete design** — a
desktop Super Admin console (254px sidebar, 87px topbar, its own design system
`medibook-super-admin-ds-…` / `design-system-medibook-hosp-admin-…`, Open Sans + Poppins).
It was uploaded into this project as reference, not exported as the target. Treat it as
out of scope unless the user says otherwise; it is the likely phase 2.
