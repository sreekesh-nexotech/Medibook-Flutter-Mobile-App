# Medibook — Hospital Booking SaaS
# Business Requirements Document derived from the built front ends

**Version 1.0 · 10 September 2026 · Prepared for Nexotech Solutions (service provider) and Navora Cloud Soft Private Limited (client)**

## 0. Document control

### 0.1 Purpose
1. This document describes, in business language, everything the three Medibook front-end prototypes do today: the Patient Mobile App (Flutter), the Hospital Web App "mbAdmin" (React) and the Operations Console for Medibook Super Admins (React, same code base).
2. It is intended as the single source of truth for designing the backend: database schema, API and server architecture (Agreement Module 1 "Architectural Deliverables").
3. It compares what was built against the contract documents and lists every contractual requirement that is missing or only partly represented in the user interfaces, every prototype feature that goes beyond the contract, every conflict between the documents and the screens, and the open questions the client must answer before the Final FRD (Schedule A) is signed.

### 0.2 Sources and method
1. **Source of truth: the code.** Every statement about behaviour was read from the two repositories (`Medibook-Flutter-Mobile-App`, branch `claude/dazzling-hypatia-jg6r46`, commit 3658546; `Medibook-Webapp-ViteJS`, same branch, commit 4250500). All 121 Dart files and all 209 TypeScript files were read in full; every label, message, rule and constant quoted here was verified against the source. The repositories' own design documents were used only as a cross-check and are flagged where they disagree with the code.
2. **Contract documents compared:** the Project Estimation (quote), the Preliminary FRD / Functional Scope (Schedule B; the two PDFs supplied are identical), and the Software Development Agreement draft V2.1 dated 23 July 2026.
3. **What "as built" means here.** Both prototypes are presentation layers on sample data: there is no backend, no persistence beyond the browser, no authentication, payments or messaging. Where a screen merely simulates an outcome, it is marked **[Prototype-only]**; where behaviour looks unintended or unfinished, it is marked **[Observation]**.

### 0.3 How to read this document
1. **Sections 1–2** give the executive summary, the product, its actors, its business model and the end-to-end journeys.
2. **Sections 3–5** describe each application screen by screen: what the user sees, what they can do, the rules that apply, and what is not yet built. These sections are exhaustive by design.
3. **Sections 6–8** consolidate the business rules, the status lifecycles and the data dictionary for the backend team.
4. **Section 9** lists the integrations and non-functional needs the screens imply.
5. **Section 10** is the gap analysis against the contract. **Section 11** lists the open questions.
6. **Appendices** give the screen inventory, the sample data, the audit-event catalogue, every user-facing message, and the requirement traceability matrix.

### 0.4 Identifier conventions
1. **BR-nnn** business rule · **ST-nn** status lifecycle · **E-nn** data entity · **GAP-nnn** contractual gap · **XTRA-nn** feature beyond the FRD · **CONF-nn** document/UI conflict · **DEF-nn** prototype defect · **DEMO-nn** prototype-only behaviour · **OQ-nn** open question.
2. Contract requirement IDs: **CM-nn** customer mobile app, **HA-nn** hospital admin web, **SA-nn** super admin web, **X-nn** platform/cross-cutting (all from the Preliminary FRD); **Q-nn** quote; **AGR-nn** agreement.
3. Quoted text in "double quotes" is verbatim user-interface copy.


# 1. Executive Summary

## 1.1 What exists
1. Three polished, pixel-faithful front-end prototypes exist and are fully interactive on sample data: a 16-screen patient mobile app, a 14-view hospital desk-and-management web app for one sample hospital, and a 16-view operations console for Medibook covering 13 sample hospitals.
2. Together they demonstrate the intended product: patients book doctor consultations and receive queue tokens; hospital front desks run walk-ins, payments, receipts and a live token queue; hospital administrators manage doctors, departments, staff roles, reports, settings and settlements; Medibook onboards and verifies hospitals, manages subscription plans and billing, records settlement payouts, runs analytics and reports, keeps an audit trail, manages patient accounts and publishes banners and push campaigns.
3. **Nothing behind the screens exists.** There is no server, database, API, login, payment, messaging, file storage or scheduler. Every figure and record is sample data that resets on restart; several dashboards and reports show fixed numbers; dozens of buttons only display a message. Module 1 of the Agreement (architecture) must design the entire backend from this document.

## 1.2 Headline findings for the backend design
1. **Master data is not connected.** The hospital app books against a fixed list of six departments and seven doctors that ignores its own Doctors & Departments catalogue; the mobile app uses a different set of four departments and six doctors; tokens follow two different schemes ("T-001" vs "A-25"); appointment statuses differ; patients are identified by name in the app and by MR number in the hospital. One canonical model is required (Section 8, Section 10.4).
2. **Policies are captured but not enforced.** Hospital Settings holds the FRD's per-tenant rules (slot duration, buffer, capacity, cancellation cut-off, hold timeout, grace period, auto no-show, token generation, fees) and notification preferences, and the Users & Roles screen holds granular permissions — none of them drives any behaviour today. The backend must make them effective (Section 6).
3. **Time is faked everywhere.** The console runs on a fixed date (13 June 2026), the hospital app stores relative labels such as "Today", and the mobile app stores the literal word "Today". Real timestamps, a server clock and scheduled jobs (reminders, overdue statements, no-show automation, statement generation, scheduled pushes) are required (Section 9).
4. **Money flows are partly designed.** A 10% platform commission, weekly settlement statements with release recording and hospital confirmation, GST-inclusive subscription invoices and a monthly booking quota are all visible — but statements are never generated, invoices never change state, receipts have no tax lines or unique numbers, refunds have no slab, and no payment gateway is integrated (Sections 4.7, 4.8, 5.5, 5.6).
5. **Audit exists in outline.** The console logs 23 kinds of action with a fixed actor, IP and "Just now"; the hospital app logs nothing; booking transitions and message attempts are not logged (Section 5.9, Appendix C).

## 1.3 Contract position in numbers
| Area | Count |
|---|---|
| Contract requirements checked | 91 (54 mobile, 13 hospital, 6 super admin, 12 platform, 4 quote, 9 agreement clauses) |
| Requirements absent from all user interfaces | 34 |
| Requirements only partly represented | 34 |
| Requirements present in the UI (on sample data) | 8 |
| Backend-only / not UI-testable / excluded | 15 |
| Prototype features beyond the Preliminary FRD (Change-Request candidates) | 15 groups |
| Conflicts between documents and screens | 12 |
| Prototype defects that must not ship | 14 |
| Open questions for the client | 32 |

## 1.4 The five decisions that shape everything else
1. **Settlements in the application or outside it** (CONF-01). The prototypes build a two-sided settlement ledger the FRD says is out of scope.
2. **Patient identity and discovery** (CONF-02, CONF-04): mobile-number login with OTP and location-first hospital selection per the FRD, or the prototype's email login and department-first flow.
3. **Token and slot model** (CONF-05, OQ-07 to OQ-10): per-doctor-per-day sequential tokens on payment success with slot holds, or the prototype's hospital-wide counter issued at booking.
4. **Payment moment and fee composition** (CONF-06, OQ-12): in-app prepayment with taxes, convenience fee and coupons, versus the mobile prototype's "payment is collected at the hospital desk".
5. **Scope of the beyond-FRD features** (Section 10.2): custom roles, multi-consultation bookings, queue controls, ratings, help centre, KYC workflow, patient-account management, banners and push campaigns, analytics and console reports — each needs an in/out decision under Agreement Clause 2.4.


# 2. Product Overview

## 2.1 The three applications
1. **Patient Mobile App ("Medibook")** — an Android/iOS app (Flutter) for patients: sign in, find a department or doctor, book an appointment for themselves or a family member, see their queue token, reschedule or cancel, view lab records, and manage their profile. Built as 16 screens on sample data.
2. **Hospital Web App ("mbAdmin")** — a browser application (React) used inside one hospital by the front desk (Receptionist) and management (Administrator): appointments and walk-ins, the live token queue, desk payments and receipts, patients, doctors and departments, staff logins and roles, reports, settlements from Medibook, and hospital settings. Built as 14 views on sample data for one sample hospital (Apollo Hospital, Bengaluru).
3. **Operations Console (Medibook Super Admin)** — the same browser application under `/ops`, used by Medibook's own staff: onboard and verify hospitals, manage subscription plans and billing, record settlement payouts, watch usage analytics, generate reports, read the compliance log, manage internal staff, look up patient accounts, publish banners and push notifications, and set platform-wide settings. Built as 16 views on sample data for 13 sample hospitals.
4. **What does not exist yet:** any backend. There is no server, database, API, authentication, payment gateway, messaging provider, file storage or scheduler. Every screen runs on in-memory sample data that resets when the app restarts or the browser reloads (the only exception is the hospital settings form, which the browser remembers locally). The FRD/Agreement scope for the backend (Django + PostgreSQL) is therefore entirely open and must be designed from this document.

## 2.2 Actors and roles
1. **Patient (account holder)** — registers and signs in on the mobile app; books for "Self" or for saved family members (sample: a husband and a daughter). The mobile app has no other role.
2. **Dependent / family member** — a person on the patient's account who can be selected as the patient of a booking; in the prototype they are fixed sample entries with name, age, gender and relationship.
3. **Hospital Receptionist** — front-desk role in mbAdmin: dashboard, appointments (create walk-ins, register online arrivals, check-in, payments, receipts, cancel, reschedule, no-show), patients, token queue, payments, help.
4. **Hospital Administrator** — everything the receptionist can do plus settlements and plan, doctors and departments, staff users and roles, reports, hospital settings.
5. **Custom hospital roles** — the Users & Roles screen lets an administrator define roles with view/add/edit/delete permissions across ten modules (sample: Reception / Billing, Department Front Desk, Accountant). In the prototype these are stored but do not control access; the backend must enforce them.
6. **Medibook Super Admin** — full control of the Operations Console. The console also documents three narrower internal roles — **Finance Admin**, **Support**, **Auditor** — with a permission matrix that the backend must enforce (the prototype enforces nothing inside the console).
7. **Doctors** are **not** system users in any application (consistent with the original quote): they are catalogue records managed by the hospital.
8. **Implied system actors** (needed by the contract but absent from the code): payment gateway (Razorpay), WhatsApp/SMS/push providers, a scheduler for reminders, overdue detection, no-show automation and settlement generation, and file storage for documents and images.

## 2.3 Business model as expressed by the screens
1. **Subscriptions.** Each hospital is on a monthly plan (sample tiers: Starter ₹9,999 / 1,500 online bookings per month / up to 25 staff accounts / email support; Growth ₹24,999 / 5,000 / 120 staff / priority support; Enterprise ₹49,999 / 8,000 / unlimited staff / dedicated success manager; plus hospital-specific negotiated plans). Prices are treated as GST-inclusive at 18% (9% CGST + 9% SGST). Invoices are issued on the 1st, due after 14 days. Only appointments booked through the patient app consume the monthly quota; walk-ins do not.
2. **Commission on online bookings.** For appointments booked and prepaid in the patient app, Medibook collects the consultation fee, keeps a platform commission (10% by default; editable in Platform Settings) and pays the rest to the hospital.
3. **Settlements.** Net amounts are grouped into weekly statements (sample cadence: Wednesday to Tuesday, expected four days after the period ends). Fees become payable only after the appointment is completed. Medibook records each bank transfer (UTR, amount, remark) in the console; the hospital confirms receipt in mbAdmin. Statements can be Pending, Overdue, Released, Received or Payout failed.
4. **Walk-in payments** are collected at the hospital desk (cash, UPI or card), recorded in mbAdmin with a receipt and queue token, and kept entirely by the hospital.
5. **Cancellations.** Online prepaid bookings are refunded by Medibook "per its slab policy (little or none on the day of the visit, near-full if cancelled well in advance)"; the slab itself is not defined anywhere. Desk payments can be refunded at the desk when cancelling.
6. **Tokens.** Every consultation gets a queue token used to call the patient. The hospital app issues hospital-wide tokens T-001, T-002…; the mobile app shows tokens A-25, A-26…; the two schemes are unreconciled prototypes of the same concept.

## 2.4 End-to-end journeys (how the three applications are meant to work together)
Each journey describes the intended flow and, in italics, where the prototype is disconnected. Because the two front ends share no data, none of these journeys currently crosses from the mobile app to the hospital app.

### 2.4.1 Online booking through the patient app
1. The patient chooses a department, opens a doctor, picks the patient (self or dependent), a date within the next five days and one of six time slots, reviews the summary (patient, department, date, time, token preview, consultation fee) and confirms.
2. The app creates the appointment immediately with a token; the Home screen shows "Your Token".
3. At the hospital, the front desk sees the appointment as an **Online** booking (prepaid) and on arrival presses **Check In**; the patient enters the doctor's queue, is called, and the visit is marked Done.
4. *Prototype gaps:* no payment is taken despite "Confirm and Pay"; no hospital or location is chosen; the booking never reaches the hospital app; online bookings for today are placed in the doctor's queue at booking time even before check-in.

### 2.4.2 Walk-in at the front desk
1. The receptionist opens New Appointment, finds or adds the patient (an MR number is generated), picks Walk-in, date, time and one or more consultations (department + doctor), and saves.
2. The combined Record Payment dialog captures Cash/UPI/Card; on confirmation each consultation becomes Paid and In Queue with consecutive tokens, and a receipt with token slips can be printed.
3. The Token Management screen shows the doctor's queue; Call Next, Skip and Done drive the visit.

### 2.4.3 Cancellation, no-show and reschedule
1. Patient side: an upcoming appointment can be cancelled (moves to Past as Cancelled) or rescheduled to another date/slot; the token is kept.
2. Desk side: a Scheduled appointment can be cancelled with a reason (and a desk refund for paid walk-ins), marked No-show, edited (department/doctor/date/time/note, with fee re-pricing) or rescheduled (same doctor only). No-shows and cancellations can be reverted.
3. *Prototype gaps:* no cancellation cut-off, refund slab, reschedule window, notification or audit trail is enforced anywhere.

### 2.4.4 Settlement cycle
1. Online fees for completed appointments accumulate into a weekly statement (gross, 10% commission, net, expected date).
2. The hospital may **Request** release of a pending statement or **Raise a request** on an overdue one; both appear in the console bell.
3. Medibook records the transfer (single release or a payout run) with UTR and remark; the hospital sees Released and confirms **Mark Received**.
4. *Prototype gaps:* statements are never generated, overdue is never detected, payout failures are sample-only, partial releases keep no balance, and the FRD says settlements happen outside the application.

### 2.4.5 Hospital onboarding, verification and access
1. Medibook onboards a hospital (name, admin email, city, plan) → Pending verification with four KYC documents (registration certificate, GST certificate, medical licence, bank account proof).
2. Once all documents are received, Medibook approves ("goes live") or rejects with a reason; active hospitals can be suspended and reactivated. A suspended hospital cannot log in to mbAdmin.
3. The hospital administrator completes Hospital Settings (profile, location, bank details, rules, hours, notifications), builds the doctor and department catalogue and adds staff users.
4. *Prototype gaps:* no admin account or invitation is created, KYC documents cannot be uploaded or verified individually, settings and catalogue do not drive booking.

### 2.4.6 Subscription billing and plan change
1. Medibook issues monthly invoices; payments (UPI/Card/NetBanking) settle them; overdue and failed payments are visible.
2. A hospital requests a plan change from mbAdmin; Medibook approves or declines; the plan on the hospital record changes.
3. *Prototype gaps:* invoices and payments are read-only sample data with no generation, reminders, grace period or auto-suspension.

### 2.4.7 Support and communications
1. A hospital raises a support ticket from Help & Support; it appears in the console bell (and can never be closed).
2. Medibook publishes home-screen banners (scheduled, prioritised, with a default fallback) and push campaigns (audience, send now or 09:00 on a date).
3. *Prototype gaps:* the mobile app does not read banners or receive pushes; no WhatsApp, SMS, reminder or booking-event messaging exists in any application.

## 2.5 How the requirement documents evolved
1. **Project Estimation (quote).** A single-hospital "Patient Booking App for Hospital" for ₹1,00,000 + GST in 60 days: Super Admin, Admins, Staff and Patients; doctor listing, booking, token generation, payment, SMS/app alerts, visit history; doctor and slot management, walk-ins, patient history with filters, payment reports, role-based access; five modules.
2. **Preliminary FRD (Schedule B of the Agreement).** A multi-tenant SaaS with three applications (Super Admin web, Hospital Admin web, Customer mobile), Razorpay payments, WhatsApp Cloud API notifications, location-first discovery, dependents, a medical documents library, an insurance locker, an optional ambulance button, tenant-configurable policies, slot holds with anti-double-booking, plans and billing with auto-suspension, audit logs, and explicit MVP exclusions (tele-consultation, EMR/EHR, insurance claims, offline mode). Settlements to hospitals are stated to happen outside the application.
3. **Software Development Agreement V2.1 (draft, 23 July 2026).** Nexotech Solutions ↔ Navora Cloud Soft Pvt Ltd; ₹6,00,000 + GST; up to six modules over 180 days (+30 contingency) after sign-off of a Final FRD; backend in Python Django with PostgreSQL; Module 1 = architecture (database schema, ER diagrams, API design overview, server architecture); explicit exclusions (tele-consultation, EMR/EHR, insurance claims, offline mode, end-to-end encryption, client-specific WhatsApp Cloud API, data migration, security audits, AMC); and Clause 2.4, under which any design element outside the Final/Preliminary FRD is out of scope unless a Change Request is agreed.
4. **The prototypes** were built from a separate UI/UX design engagement and go beyond the Preliminary FRD in several areas (Section 10.2) while omitting others (Section 10.1). This document is the bridge between the two.

## 2.6 Glossary
1. **Appointment / consultation** — one patient with one doctor at one date and time; in mbAdmin one appointment row per consultation.
2. **Booking source** — Online (booked and prepaid in the patient app) or Walk-in (booked at the desk).
3. **Token** — the queue number shown to the patient and called by the doctor; "T-001" in mbAdmin, "A-25" in the mobile app.
4. **Check-in** — the desk action that confirms an online patient has arrived and puts them in the queue.
5. **MR number (MRN)** — the hospital's patient identifier (sample format AP847201).
6. **Statement / settlement** — a weekly summary of online fees Medibook owes a hospital (gross, commission, net, expected date).
7. **UTR** — the bank transfer reference recorded when Medibook releases a settlement.
8. **Payout run** — a batch of statements released together on the same expected date.
9. **Plan / quota** — the hospital's subscription tier and its monthly allowance of online bookings.
10. **KYC documents** — the four documents a hospital must submit before Medibook approves it.
11. **Compliance log** — the console's audit trail of sensitive actions.
12. **Banner** — a promotional card on the patient app's home screen; **push** — a mobile notification campaign.
13. **Demo mode / prototype-only** — behaviour that exists only to make the prototype usable and must not ship (pre-filled logins, fixed OTP, fixed "today", simulated delays, fixed KPI numbers).


# 3. Patient Mobile App — Functional Specification (as built)

This section describes the Medibook patient app exactly as the Flutter code behaves today. Every label, message and rule below was read from the source code, not from design notes. Where the prototype only pretends to do something (for example shows a message instead of downloading a file), it is marked **[Prototype-only]**. Where a behaviour looks like a defect or an unfinished decision, it is marked **[Observation]** and repeated in Section 11 (Open questions).

## 3.1 How the app is organised

### 3.1.1 Users and access
1. The app has exactly one kind of user: the **patient** (the account holder). There are no staff or admin functions in the mobile app.
2. The app opens on the **Login** screen.
3. **[Prototype-only]** There is no real sign-in. Any well-formed email plus any non-empty password opens the app, and every screen can also be reached directly without logging in. The backend must introduce real authentication and route protection.
4. The signed-in identity is always the sample user **Alexandra Johnson** (email `alexandra.johnson@example.com`), regardless of what was typed at login or sign-up.

### 3.1.2 Navigation model
1. Four main tabs are always available at the bottom of the screen, in this order: **Home**, **Appointments**, **Records**, **Profile**. Tapping the tab you are already on returns that tab to its first screen.
2. Every other screen opens full-screen on top of the tabs (no bottom bar): Search, Notifications, Book Appointment, Doctor Details, Booking Success, Appointment Details, Reschedule, and the five authentication screens (Login, Create Account, Reset Password, Verify Code, New Password).
3. Screens can be opened by direct link with parameters (for example the booking step, the department, the doctor, or an appointment ID). The app does not validate these parameters strictly (see §3.6.6).
4. Screen transitions use a short fade/rise animation (about 0.2 seconds); buttons and cards shrink slightly when pressed.

### 3.1.3 Behaviours shared by all screens
1. **Toast messages.** Short confirmations appear as a dark pill near the bottom of the screen for 2.3 seconds. Only one toast is visible at a time; a new one replaces the previous one. Toasts cannot be tapped or dismissed.
2. **Confirmation sheets.** Destructive actions (Logout, Delete account, Cancel appointment) open a bottom sheet with a title, a message, a **Cancel** button and a confirming button. Tapping the dimmed background dismisses the sheet without doing anything.
3. **Avatars.** Where no photo exists, the app shows the initials of the first two words of the name (for example "AJ" for Alexandra Johnson). **[Observation]** Because doctor names start with "Dr.", every doctor without a photo shows "DR" rather than their initials; only Dr. Anya Sharma has a photo.
4. **Locale.** Amounts are shown in rupees (₹), phone numbers use the +91 format, dates are shown as "12 Aug 2026" style, times as "10:30 AM". The app is English-only, light theme only, and ignores the phone's font-size accessibility setting.
5. **Data persistence.** **[Prototype-only]** Nothing is stored on the device or on a server. Bookings, cancellations, reschedules and toggles live only in memory and are lost when the app is closed. Every launch starts from the same sample data (see Appendix B).
6. **Loading and error states.** Because there is no network, no screen shows a loading indicator or a network error. The only "not found" message in the app is "Appointment not found." on the appointment and reschedule screens.

## 3.2 Authentication screens

### 3.2.1 Login
1. **Purpose.** Entry point of the app.
2. **What you see.** The Medibook logo mark and name; heading "Hi, Welcome Back!"; sub-text "Hope you're doing fine."; an **Email** field (placeholder "Your Email"); a **Password** field (placeholder "Password", masked); a **Remember me** checkbox (ticked by default); a **Forgot password?** link; a **Log In** button; an "OR" divider; three round social buttons labelled **G**, **f** and **X**; and the footer "Don't have an account yet? Sign up".
3. **What you can do.**
   1. **Log In** — validates the two fields (rules below) and opens Home. Nothing is checked against an account.
   2. **Forgot password?** — opens Reset Password (§3.2.3).
   3. **Sign up** — opens Create Account (§3.2.2).
   4. **G / f / X** — all three open Home immediately. **[Prototype-only]** No Google, Facebook or X sign-in is integrated.
   5. **Remember me** — can be ticked or unticked. **[Prototype-only]** It has no effect.
4. **Validation rules.** Email must look like an email address (text@text.text, no spaces) or the field shows "Enter a valid email address". Password must not be empty or the field shows "Enter your password". Validation runs only when Log In is tapped; the error clears as soon as the user types in that field. Errors are shown in red under the field; there is no toast.
5. **[Prototype-only]** In demo mode the fields are pre-filled with `alexandra.johnson@example.com` / `medibook123` and a line reads "Demo login is prefilled — just tap Log In." There is no show/hide-password toggle and no loading state on the button.

### 3.2.2 Create Account (Sign Up)
1. **What you see.** Back arrow; title "Create Account"; sub-text "Book doctors, lab tests and records in one place."; fields **Full Name** ("Your Name"), **Email** ("Your Email"), **Phone Number** ("+91 00000 00000"), **Password** ("Create a password", masked); a checkbox "I agree to the Terms & Conditions, Privacy Policy, and User Guidelines." (unticked by default, plain text with no tappable links); a **Sign Up** button; footer "Already have an account? Log In".
2. **What you can do.** **Sign Up** validates all fields at once and, if valid, shows the toast "Welcome to Medibook, <first name>!" and opens Home. Back and **Log In** return to Login.
3. **Validation rules.** Full Name required ("Enter your name"); Email format ("Enter a valid email address"); Password at least 6 characters ("At least 6 characters"); the agreement checkbox must be ticked (the checkbox and its label turn red, without a message). **[Observation]** The phone number is not validated and is discarded.
4. **[Prototype-only]** No account is created; the app continues to identify the user as Alexandra Johnson. No email or phone verification happens after sign-up.

### 3.2.3 Reset Password (Forgot Password)
1. **What you see.** Back arrow; title "Reset Password"; text "Enter your Email, we will send you a verification code."; an **Email** field; a **Send Code** button.
2. **What you can do.** **Send Code** validates the email format, shows the toast "Code sent to <email>" and opens Verify Code with that email. Back returns to Login.
3. **[Prototype-only]** No code is sent and the app does not check that the email belongs to an account. In demo mode the email is pre-filled.

### 3.2.4 Verify Code
1. **What you see.** Back arrow; title "Verify Code"; text "We sent a 4-digit code to <email>."; four single-digit boxes; a **Verify** button; footer "Didn't get the code? Resend Code". In demo mode an extra line reads "Demo code: 1234".
2. **Rules of the code boxes.** Digits only; one digit per box; typing a digit moves the cursor to the next box automatically; there is no automatic submit after the fourth digit, no countdown timer, no expiry and no attempt limit.
3. **What you can do.**
   1. **Verify** — if the four digits are exactly **1234** the New Password screen opens; otherwise the boxes turn red and the message "Incorrect code — the demo code is 1234" appears. An incomplete code is treated as incorrect.
   2. **Resend Code** — shows the toast "Code re-sent to <email>" and nothing else (no cooldown).
   3. Back returns to Reset Password.
4. **[Prototype-only]** The accepted code is a fixed constant and the error message discloses it. Production needs real OTP delivery, expiry, rate limiting and attempt lockout.

### 3.2.5 New Password
1. **What you see.** Back arrow; title "New Password"; text "Create a new password for your account."; fields **New Password** ("At least 6 characters") and **Confirm Password** ("Repeat the password"), both masked; a **Reset Password** button.
2. **What you can do.** **Reset Password** validates and, if valid, shows the toast "Password reset — please log in" and returns to Login. Back returns to Verify Code (without the email, so it then shows the demo email or nothing).
3. **Validation rules.** New Password at least 6 characters ("At least 6 characters"); Confirm Password must match exactly ("Passwords do not match"). The two checks are independent.
4. **[Prototype-only]** The new password is not stored anywhere and has no effect on the next login.

### 3.2.6 Summary of what authentication does not yet do
1. Create or verify accounts, sessions or tokens; log out server-side; remember the user between launches.
2. Mobile-number login or mobile OTP (the prototype is email-based, whereas the contract specifies mobile number plus password with OTP to the mobile — see GAP list).
3. Lockout or throttling after repeated failures.
4. Password strength rules beyond a 6-character minimum; show/hide password.
5. Social sign-in with a real provider.
6. Tappable Terms & Conditions / Privacy Policy / User Guidelines.
7. Phone-number validation or use.
8. **[Observation]** All authentication screens replace the previous screen rather than stacking, so the phone's hardware back button on Create Account, Reset Password or Verify Code may leave the app instead of returning to the previous screen.

## 3.3 Home

1. **Purpose.** Landing screen after login; the hub for booking and for checking the current token.
2. **Header (navy band).** "Welcome back," followed by the user's first name with an exclamation mark ("Alexandra!"); a **bell** button (opens Notifications; **no unread badge or count**); a ringed **avatar** (opens the Profile tab); and a white search pill reading "Search doctors or departments..." which is not a text field but a button that opens the Search screen.
3. **Promotional banner carousel.**
   1. Two fixed slides: (a) "Want to see a doctor today?" / "Schedule your appointment in just a tap." with a doctor photo; (b) "Lab tests at home" / "Book a sample collection slot now." on a red gradient.
   2. Slides rotate automatically every 4 seconds and loop. Tapping the banner advances to the next slide and restarts the timer. Swiping is disabled. Page dots show the active slide.
   3. **[Observation]** Tapping a banner does not navigate anywhere; banners have no link or call to action and no way to be managed remotely. (The Operations console has a banner manager whose banners do not reach this app — see §5.12 and the gap list.)
4. **"Your Token" card.**
   1. Shown only when the patient has at least one upcoming appointment; hidden otherwise.
   2. Shows the label "Your Token" and the token number in a navy pill (for example "A-25"). It does not show the doctor, date, time, queue position, currently-serving number or estimated wait.
   3. Tapping the card opens the Appointment Details of that appointment.
   4. The card reflects live in-app changes: it disappears or changes when that appointment is cancelled.
   5. **[Observation]** The appointment shown is the **most recently booked** upcoming appointment, not the one that is soonest by date. After booking a new appointment, the card switches from today's token (A-25) to the new token (A-26) even if the new appointment is days away.
5. **"Quick Booking" tiles** (three cards): **Appointment**, **Lab Tests**, **Family**. All three open the booking flow at step 1 (choose department). **[Observation]** There is no separate lab-test or family-member flow; the tiles are labels only.
6. **"Available Services" row** with a **View All** link, then three tiles: **General Physician** (opens booking at step 2 with the General department pre-selected), **Skin & hair Care** (opens step 2 with Dermatology pre-selected), **Women's Health** (opens step 1 — **[Observation]** no such department exists in the data). **View All** opens step 1.
7. There is no pull-to-refresh, loading state or empty state on Home.

## 3.4 Search

1. **How you get here.** From the Home search pill only. Back returns to Home.
2. **What you see.** Title "Search"; a search box with the placeholder "Search doctors or departments..." that receives focus automatically about a quarter-second after the screen opens (so the keyboard slides up after the transition); results below in two groups: **Departments** and **Doctors**.
3. **How matching works.**
   1. Results update on every keystroke (no minimum length, no delay, no search button; the keyboard's Search key does nothing extra).
   2. Matching is case-insensitive "contains" on: department name + department descriptor (for example "Dermatology Skin specialists"); doctor name + specialty + department name + department descriptor. So typing "skin" finds both the Dermatology department and Dr. Sara Ali.
   3. The hospital name is displayed under each doctor but is **not searchable** (typing "Apollo" finds nothing). Fees, experience, ratings and bios are not searchable either.
   4. With an empty box, all 4 departments and all 6 doctors are listed.
   5. No ranking, sorting, paging, recent searches or suggestions.
4. **Result rows.**
   1. Department row: department icon, name, descriptor, and a **Book** link → opens booking at step 2 for that department.
   2. Doctor row: avatar, name, "specialty · hospital" (for example "Cardiologist · Apollo Hospital"), and a **View** link → opens Doctor Details; Back from there returns to Search.
5. **Empty state.** A search icon with the text: No matches for "<what was typed>".

## 3.5 Notifications

1. **How you get here.** From the bell on Home, Appointments or Records. Back returns to the previous screen.
2. **What you see.** Title "Notifications"; a row with "Recent Notifications" and a **Mark all as read** link; then notification cards, each with a title, a body, a clock icon with a relative time ("2 hours ago"), and, for some, two action buttons (a secondary one on the left, a primary one on the right).
3. **Sample notifications and their actions** (the only four that exist; there is no read/unread state, grouping, swipe-to-dismiss, or tap-on-card action):
   1. **Fasting Reminder** — "Your Full Body Checkup requires fasting. Please avoid food and drinks (except water) for 8–12 hours before your sample collection at 8:00 AM tomorrow." — no buttons.
   2. **Appointment Reminder** — "Your appointment with Dr. Priya Mehta is scheduled for today at 10:30 AM." — **Reschedule** opens the Reschedule screen for today's appointment; **View Details** opens its Appointment Details. If that appointment has been cancelled in the meantime, both buttons instead show the toast "That appointment was cancelled". **[Observation]** Both buttons are hard-wired to the sample appointment with ID 1, not derived from the notification.
   3. **Prescription Ready** — "Your prescription from Dr. Anil Kumar is now available for download." — **View Details** switches to the Records tab; **Download** shows the toast "Downloading prescription…" **[Prototype-only]** (nothing is downloaded).
   4. **Vaccination Due** — "Ava's next vaccination is due in 2 weeks. Schedule an appointment now." — **Remind Later** shows the toast "We'll remind you tomorrow" **[Prototype-only]**; **Schedule** opens booking at step 1 (not pre-filtered for the child or paediatrics).
4. **Mark all as read** shows the toast "All notifications marked as read" and changes nothing **[Prototype-only]**.
5. No push notifications are integrated; the list is fixed sample content.

## 3.6 Book Appointment (four-step flow)

### 3.6.1 Entry points and the draft
1. The flow can be entered at different steps with information pre-filled: from Home tiles (step 1 or step 2 with a department), from Search (step 2 with a department), from the Appointments tab's **Book an appointment** button (step 1), from Doctor Details' **Book an appointment** (step 3 with the doctor and department filled), from a past appointment's **Book Again** (step 3 with the same doctor), and from the vaccination notification (step 1).
2. Every time the flow is entered, the draft resets to: patient = the account holder (Self), date = Today, time = 10:00 AM. Department and doctor come from the entry point if provided.
3. The screen shows a back arrow, the title "Book Appointment", a four-circle step indicator (completed and current steps in navy), the step content, and a sticky footer button: **Continue** on steps 1–3 (greyed out until the step's requirement is met) and **Confirm and Pay** on step 4.
4. **Back behaviour.** On steps 2–4 the back arrow (and the phone's back button) goes to the previous step, keeping the selections. On step 1 it leaves the flow and returns to the tab the flow was started from (Home or Appointments) — never to Search or Notifications, even if the flow was started there.

### 3.6.2 Step 1 — "Please select the department"
1. A two-column grid of department cards: **General** ("Primary healthcare"), **Cardiology** ("Heart specialists"), **Orthopedics** ("Bone & joint care"), **Dermatology** ("Skin specialists"), each with an icon. The selected card gets a navy border.
2. Tapping a card selects it (single choice; cannot be unselected) and clears any previously chosen doctor.
3. **Continue** is enabled only when a department is selected.

### 3.6.3 Step 2 — "Select a doctor"
1. A row of pill tabs, one per department (all four, horizontally scrollable), with the chosen department active. Tapping another tab switches department and clears the chosen doctor.
2. The list of doctors in that department. Each card shows the avatar, name, "specialty · experience" (for example "Cardiologist · 12 yrs"), a five-star rating with the numeric value (for example 4.8), the fee (for example ₹900) and the caption "per visit". Sample distribution: General — Dr. Anil Kumar, Dr. Meera Nair; Cardiology — Dr. Anya Sharma, Dr. Rohan Kapoor; Orthopedics — Dr. Priya Mehta; Dermatology — Dr. Sara Ali.
3. A hint under the list: "Tap a doctor to view details and book".
4. **Rule.** Tapping a doctor card does **not** select the doctor in place; it opens Doctor Details (§3.7). The doctor is chosen by pressing **Book an appointment** there, which re-enters the flow at step 3. Consequently **Continue** on step 2 is disabled on first arrival and becomes enabled only if the user reaches step 3 via Doctor Details and then goes back to step 2 (the chosen doctor's card is then highlighted).
5. **[Observation]** The star display rounds to the nearest whole star, so every sample doctor (ratings 4.5–4.9) shows five full stars.
6. If the flow is opened at step 2 without a department, all six doctors are listed with no active tab. If an unknown department is passed, the list is empty with no message.

### 3.6.4 Step 3 — patient, date and time
1. **"Select patient".** A list of the account's people, each with avatar, name, "age years · gender" and a relation tag: **Alexandra Johnson** (29 years · Female, **Self**), **Michael Johnson** (34 years · Male, **Husband**), **Ava Johnson** (6 years · Female, **Daughter**). Single choice; Self is pre-selected. There is no way to add, edit or remove a family member.
2. **"Select date".** A horizontal row of exactly five day chips: today (labelled "Today") and the next four days (labelled by weekday, for example "Fri 11"). Rules: no date is ever disabled (weekends included); there is no calendar, no dates beyond five days, no cut-off for slots already in the past today, and no doctor-availability logic. Today is pre-selected.
3. **"Select time".** A grid of six fixed time chips for every doctor and date: **09:00 AM, 10:00 AM, 11:30 AM, 12:15 PM, 02:00 PM, 04:30 PM**. 10:00 AM is pre-selected. Rules: every slot is always selectable; there is no booked/unavailable state, no capacity, no duplicate check.
4. **Continue** is always enabled on this step (something is always selected).

### 3.6.5 Step 4 — "Confirm appointment"
1. A summary card with the doctor's avatar, name and title (for example "Head of Cardiology"), then these rows: **Patient**; **Department**; **Date** ("Today" or "11 Sep 2026"); **Time**; **Token** (highlighted in blue — a preview of the token that will be issued, for example "A-26"); **Consultation Fee** (the doctor's fee, for example ₹900).
2. Footer note: "Payment is collected at the hospital desk." and "You can reschedule up to 2 hours before your slot."
3. **Confirm and Pay** immediately creates the appointment and opens Booking Success. There is no confirmation dialog and nothing can fail.
4. **What is not here.** No taxes/GST, convenience fee, discount or coupon, total amount, payment-method choice, online payment step or terms acceptance. **[Observation]** Despite the button label, no payment is taken; the note says payment happens at the desk. The "2 hours" reschedule rule is copy only and is not enforced anywhere (see §3.11).

### 3.6.6 Booking rules (as implemented)
1. A confirmed booking creates an appointment with status **Confirmed** in the **Upcoming** list, placed at the top of the list.
2. **Token numbering.** One app-wide counter starts at 26 and increases by one per booking; the token is "A-" followed by the number (A-26, A-27, …). Tokens are never re-used and cancellation does not free a token. Sample tokens are zero-padded ("A-08") whereas generated ones are not ("A-26"). The counter is not per doctor, per day or per hospital, and it resets to 26 when the app restarts. **[Observation]** The FRD requires sequential tokens per doctor per date issued after payment — the prototype cannot express this; the server must own token issuance.
3. The appointment's internal ID is "b" plus the same number (b26).
4. The stored date is the literal text "Today" when today is chosen (it never rolls over to a real date), otherwise a text such as "11 Sep 2026". Times are stored as text ("10:00 AM").
5. Direct links: the step number is not limited to 1–4 (other values show the confirm step with a Continue button), an unknown doctor ID silently resolves to Dr. Anya Sharma, and opening step 4 without a doctor shows an empty page whose button does nothing.

## 3.7 Doctor Details

1. **How you get here.** From a doctor card in booking step 2, or from a doctor row in Search. Back returns to where you came from.
2. **What you see.**
   1. Title "Doctor Details".
   2. Hero card: avatar (88 px), name, "specialty · hospital", star rating with value, and three statistics: **Experience** (for example "12 yrs"), **Patients** (for example "6,000+"), **Consultation** (fee, for example "₹900").
   3. **About** card with the doctor's biography.
   4. Clinic card: a hospital photo, the hospital name and the caption "Multi-speciality center". **[Observation]** The photo and caption are the same for every doctor and are not real data; there is no address, map, phone or directions.
   5. Sticky footer button **Book an appointment** → enters the booking flow at step 3 with this doctor and department filled in (patient/date/time reset to defaults).
3. There is no favourite, share, call, chat or availability calendar; the rating is display-only.

## 3.8 Booking Success

1. **How you get here.** Only after **Confirm and Pay**. It replaces the whole navigation stack, so there is no back arrow. **[Observation]** The phone's back button is not handled here and may exit the app.
2. **What you see.** A large navy circle with a tick; "Appointment Booked successfully"; "Token: A-26"; a line "<date> · <time> with <doctor>" (for example "Today · 10:00 AM with Dr. Anil Kumar"); buttons **View Appointment** (opens Appointment Details) and **Back to Home**.
3. **What is not here.** No receipt or booking ID, no download/print of a token card, no add-to-calendar, no share, no QR code, no fee or payment summary.

## 3.9 Appointments tab

1. **What you see.** Title "Appointments" with a bell button; two pill tabs **Upcoming** (default) and **Past**; a list of appointment cards; a full-width **Book an appointment** button at the bottom (always visible).
2. **Appointment card.** Doctor avatar and name; "specialty · patient first name" (for example "Orthopedic Surgeon · Alexandra"); a status pill; then a calendar icon with the date, a clock icon with the time, and a token pill (for example "A-25"). Tapping the card opens Appointment Details. Cards have no buttons or swipe actions.
3. **Status pills.** **Confirmed** (navy on light blue), **Completed** (green), **Cancelled** (red).
4. **List rules.** Upcoming and Past are separate lists defined by a stored flag, not by the date; nothing moves from Upcoming to Past with the passage of time. Newest bookings appear first; a cancelled appointment keeps its position in the Past list. There is no search, filter, sort, date grouping, paging or pull-to-refresh.
5. **Empty states.** "No upcoming appointments" / "No past appointments" with a calendar icon; the Book button remains.
6. **Sample data on first launch.** Upcoming: Dr. Priya Mehta for Alexandra, Today 10:30 AM, A-25; Dr. Anil Kumar for Michael, 12 Aug 2026 09:00 AM, A-12. Past: Dr. Anya Sharma, 21 Jul 2026, A-08, Completed; Dr. Anil Kumar for Ava, 02 Jun 2026, A-19, Cancelled.

## 3.10 Appointment Details

1. **How you get here.** From an appointment card, the Home token card, Booking Success, the Reschedule confirmation, or the appointment-reminder notification. Back returns to the previous screen, or to the Appointments tab when there is nothing to return to.
2. **What you see.**
   1. Title "Appointment Details".
   2. Header card: doctor avatar, name, specialty, star rating, and the status pill.
   3. Detail rows: **Patient**, **Department**, **Hospital**, **Date**, **Time**, **Token** (blue, bold).
   4. Note: "Please arrive 15 minutes early and carry any previous reports."
   5. Footer for upcoming appointments: **Reschedule** (light) and **Cancel** (red). Footer for past appointments (completed or cancelled): **Book Again**.
3. **What you can do.**
   1. **Reschedule** → opens the Reschedule screen (§3.11).
   2. **Cancel** → confirmation sheet titled "Cancel Appointment" with the message "Are you sure you want to cancel your appointment with <doctor>?" and buttons **Cancel** (keeps the appointment) and **Yes, Cancel** (red). Confirming sets the status to **Cancelled**, moves the appointment to the Past list, returns to the Appointments tab and shows the toast "Appointment cancelled". No reason is captured, no cut-off time is checked, no refund or charge is mentioned, and it cannot be undone.
   3. **Book Again** → starts a new booking at step 3 with the same doctor and department (the original appointment is untouched).
4. **What is not here.** Payment status, fee, receipt or invoice download, refund status, directions or map, call/chat, add-to-calendar, share, attached documents, live queue position, QR/check-in.
5. **Not found.** Opening an unknown appointment ID shows "Appointment not found." with no buttons.

## 3.11 Reschedule

1. **How you get here.** From **Reschedule** on an upcoming appointment, or from the appointment-reminder notification. Back returns to Appointment Details.
2. **What you see.** Title "Reschedule"; a card showing the doctor and "Currently: <date> · <time>"; "Select new date" with the same five-day chip row as booking; "Select new time" with the same six time chips; a **Confirm New Time** button (always enabled).
3. **What happens on confirm.** Only the date and time of the appointment are overwritten; the token, status, patient and doctor stay the same. The app shows the toast "Appointment rescheduled" and opens Appointment Details.
4. **Rules and observations.**
   1. No validation: the new slot may equal the old one, the 2-hour rule is not checked, there is no availability check, no limit on the number of reschedules and no reason capture.
   2. The date chips start with "Today" pre-selected regardless of the appointment's current date, so confirming without changing anything rewrites the date to "Today".
   3. If the current time is not one of the six slots (the sample appointment is at 10:30 AM), no time chip is highlighted until one is tapped.
   4. By direct link the screen also works on past or cancelled appointments.

## 3.12 Records tab

1. **What you see.** Title "Records" with a bell button; heading "Recent Records"; one card per record.
2. **Record card.** Title (for example "Blood Test Report"); date; a status badge — **Completed** (green) or **Pending** (red); three rows: **Patient Name**, **Center/Hospital**, **Consulted Doctor**; two buttons: **View Report** and **Download**.
3. **What you can do.** **[Prototype-only]** **View Report** shows the toast "<title> — preview stubbed in this demo"; **Download** shows the toast "Downloading <title>…". Nothing is viewed or downloaded; both buttons are shown even for Pending records.
4. **Rules.** There is no filtering, search, sorting, grouping, paging, record detail screen, upload, or link to an appointment. Records are fixed sample data: Blood Test Report (10 Jul 2026, Completed, Alexandra, Apollo Hospital, Dr. Anil Kumar); Full Body Checkup (02 Jul 2026, Pending, Michael, Apollo Hospital, Dr. Meera Nair); Lipid Profile (21 Jun 2026, Completed, Alexandra, City Care Clinic, Dr. Rohan Kapoor).
5. **Gap note.** The contract's Documents Library (uploads of prescriptions, lab reports, imaging, discharge summaries with title/type/patient/date/notes, links to appointments, secure expiring links, sharing) and the Insurance Locker do not exist in the app. See Section 10.

## 3.13 Profile tab

1. **What you see.**
   1. Title "Profile".
   2. Identity card: avatar, name "Alexandra Johnson", email, and an **edit** pencil button.
   3. "Personal Information" card with an **Edit** link and rows: **Phone** (+91 98456 58525), **Date of Birth** (15/05/1997), **Gender** (Female), **Blood Group** (O+).
   4. "Available for Donation" card with the helper text "Hospitals can contact you for rare blood needs." and a switch (on by default).
   5. Account card with **Logout** and **Delete account** (red).
2. **What you can do.**
   1. Either edit control → toast "Profile editing is stubbed in this demo" **[Prototype-only]**. No edit form exists.
   2. Donation switch → toggles a blood-donation contact consent; toast "You are now available for donation" or "Donation availability turned off". Not saved anywhere. **[Observation]** Consent is on by default, which is unusual for a privacy consent.
   3. **Logout** → sheet "Logout" / "Are you sure you want to log out?" / **Cancel** / **Yes, Logout** → returns to Login. Nothing is cleared; in-memory bookings survive until the app restarts.
   4. **Delete account** → sheet "Delete Account" / "This will permanently remove your records and appointments." / **Cancel** / **Yes, Delete** (red) → toast "Account deletion is stubbed in this demo" **[Prototype-only]**; the user stays on Profile.
3. **What is not on Profile.** Family-member management, address, emergency contacts, insurance, change password, notification/language settings, help/support/FAQ, Terms/Privacy links, payment methods, app version, avatar upload. Several of these are contract requirements (see Section 10).

## 3.14 Platform and delivery readiness of the mobile app

1. **App identity.** The Android package is still the Flutter template value `com.example.my_app` with the display name "my_app"; the iOS bundle is `com.example.myApp` with the display name "My App". Launcher icons and splash screens are the unbranded template.
2. **Permissions and capabilities.** The release Android build declares no permissions at all — not even internet access (internet is enabled only in debug builds). iOS declares no usage descriptions (camera, photos, location, calendar), no URL schemes and no background modes. No deep-link or universal-link scheme exists on either platform.
3. **Third-party services.** No payment SDK (Razorpay), no push notifications (Firebase), no analytics or crash reporting, no maps/location, no file picker, no calendar, no share, no phone-dialler integration is present in the project.
4. **Local storage and offline.** No local database or secure storage exists; the caching design described in the repository's own documentation is not implemented.
5. **Signing and build.** The release build is signed with the debug key; version 1.0.0 (build 1); minimum iOS 13.0; requires Flutter 3.38 or newer (the repository's stack document says 3.24.5).
6. **Tests.** 30 automated widget/golden tests and one screenshot-capture rig exist, all UI-level; no tests exist for validation rules or booking logic; there is no CI pipeline or pre-commit hook.


# 4. Hospital Web App (mbAdmin) — Functional Specification (as built)

The hospital web application ("mbAdmin") is the desk-and-management tool for one hospital. Everything below was read from the React source code. The prototype is configured for a single sample hospital, **Apollo Hospital** (tenant number 13 in the Operations console), whose name, GSTIN and bank details it also shares with the Operations console.

## 4.1 Access, roles and navigation

### 4.1.1 Roles
1. Two roles exist inside a hospital: **Receptionist** (front desk) and **Administrator** (full access). They are fixed roles built into the application, not the custom roles created on the Users & Roles screen (those custom roles are stored but do not control anything — see §4.10).
2. The address of every page carries the role: `/receptionist/…` or `/admin/…`. A user whose role does not match the address is redirected to their own dashboard without any "access denied" message.
3. The Receptionist can open: Dashboard (Front Desk), Appointments, New Appointment, Patients, Patient Profile, Token Management, Payments, Help & Support.
4. The Administrator can additionally open: Billing & Settlements, Doctors & Departments, Doctor Profile, Users & Roles, Reports, Hospital Settings.
5. **[Prototype-only]** Logging in on the "Hospital Login" tab always lands on the Administrator role; the Receptionist role can only be reached through the "Switch Role" menu in the top bar, which changes role without re-authentication. The sample identities are "Dr. S. Nair" (Administrator) and "Riya Menon" (Receptionist).

### 4.1.2 Screen frame
1. **Left sidebar** (fixed width): the hospital logo and name (the name comes from Hospital Settings and updates live), the caption "Medibook · mbAdmin", and menu sections: **Overview** (Dashboard) · **Front Desk** (Appointments, Patients, Token Management) · **Billing** (Payments; Billing & Settlements for admins) · **Management** (Doctors & Departments, Users & Roles, Reports — admins only; the whole section is hidden for receptionists) · **System** (Hospital Settings for admins; Help & Support).
2. **Top bar:** an in-app back arrow (shown when there is a previous screen in the session's own history of up to 24 screens), the page title and subtitle, a notification bell with an unread count, and the user menu (avatar initials, name, role) containing **Switch Role** (Receptionist / Administrator) and **Log Out**.
3. The layout is a fixed desktop layout (no tablet or phone breakpoints exist). The browser tab title is always "Medibook · mbAdmin — Hospital Admin Panel", even in the Operations console.
4. If a screen crashes, a card reads "This screen hit a snag" / "Something didn't load right. You can retry, or head back to the dashboard — your data is safe." with **Retry** and **Back to Dashboard**.

### 4.1.3 Notification bell (hospital)
1. The bell's content is computed on the fly from data; nothing is stored as a notification and nothing can be marked read (**Mark all read** only shows "All caught up" and changes nothing **[Prototype-only]**).
2. **Administrator sees:** "n settlement(s) overdue — ₹x due from Medibook" (when any settlement is overdue; unread) · "Settlement released — MB-ST-2404 — ₹ 97,380 sent · mark received once credited" (fixed sample text; unread) · "Plan quota at 62% — 3,120 of 5,000 bookings this month" (fixed sample text) · "n walk-in payment(s) pending — Awaiting collection at the desk" (when any payment is pending).
3. **Receptionist sees:** "n walk-in payment(s) pending — Collect at the desk to issue tokens" (unread, when any) · "Token queue active — Patients waiting across departments" (fixed text).
4. Clicking an item opens the related screen (Settlements, Appointments or Token Management).
5. **Gap:** the FRD expects staff-facing alerts for message delivery and payment-callback failures and a real notification centre; none exists.

### 4.1.4 Session behaviour
1. **[Prototype-only]** Nothing about the session is remembered: reloading the browser logs the user out and restores all sample data. Bookmarked pages therefore always open the login page, and after login the user lands on the dashboard, not on the bookmarked page.
2. The only data saved in the browser is Hospital Settings (see §4.12).

## 4.2 Login and password recovery

### 4.2.1 Login
1. **Layout.** Left brand panel with the hospital logo, "Medibook", the headline "Hospital operations, in one calm place.", a paragraph describing the panel, and three fixed statistics (288 appointments/day, 12 departments, 99.9% uptime). Right column: a toggle **Hospital Login | Operations Login**; heading "Welcome Back"; sub-text "Sign in to your hospital's mbAdmin panel." or "Sign in to the Medibook operations console."; **Email Address**; **Password** with a show/hide eye; **Remember me** (hospital tab; ticked by default) or the note "Sessions aren't remembered — sign in each time." (operations tab); a **Forgot Password?** link; a **Login** button; footer "Trouble signing in? Contact your hospital administrator." or "Restricted to Medibook operations staff."
2. **Validation and messages:** empty email or password → "Enter your email and password to continue."; malformed email → "Enter a valid email address."
3. **Suspension rule:** if the Operations console has suspended this hospital (within the same browser session), hospital login is refused with "This hospital's Medibook instance is suspended by operations. Contact support@medibook.in to reactivate."
4. **Outcome:** Hospital tab → Administrator dashboard; Operations tab → Operations dashboard.
5. **[Prototype-only]** No password is checked (any non-blank password works); the email is pre-filled (`s.nair@apollo.med` / `a.rao@medibook.com`) and the password field is pre-filled with bullet characters; "Remember me" does nothing; pressing Enter does not submit; no lockout, throttling or two-factor exists.
6. **Gap:** the FRD requires login with mobile number or email plus password, OTP verification and password reset via OTP for hospital admins (see Section 10).

### 4.2.2 Forgot Password
1. Heading "Forgot Password?"; text "Enter the email linked to your staff account and we'll send a reset link."; **Email Address**; **Send Mail**; link "Back to login".
2. After **Send Mail** (no validation, nothing sent **[Prototype-only]**): "Check your inbox" / "We've sent a password reset link to <email>. The link expires in 30 minutes." and **Back to Login**.
3. No OTP entry, reset link handling or new-password screen exists on the web side.

## 4.3 Dashboards

### 4.3.1 Front Desk dashboard (Receptionist)
1. **Title/subtitle:** "Front Desk" / "Welcome back, Riya" (the greeting is fixed text).
2. **KPI tiles** (clickable): **Appointments Today** ("Across all departments") → Appointments · **In Queue** ("Currently waiting / serving") → Token Management · **Pending Payment** ("Walk-ins to collect") → Appointments · **Walk-ins Today** ("Booked at the desk") → Appointments. Definitions: appointments dated today; appointments with status In Queue (any date); payments pending (any date); today's walk-ins.
3. **Quick Actions:** New Appointment · Department Queue · Find Patient.
4. **Live Queue Snapshot** (link "Open Queue"): "Waiting across depts" (today's tokened, unfinished appointments not currently being served) and "Now serving" (doctors currently consulting); then one row per department showing "serving T-0xx" or "idle" and "n waiting"; clicking a row opens Token Management pre-filtered to that department.
5. **Today's Appointments** (link "View All"): the first five of today's appointments in list order (newest first, not by time) with time, patient, doctor · department, source badge and status badge; clicking opens the Appointments list.
6. **Today's Collection** (link "Open Payments"): **Desk Cash**, **Desk UPI / Card**, **Collected at Desk** (walk-in payments recorded today; payments with no recorded mode count as cash), and the note "Online prepaid today (collected by Medibook): ₹x — settled to the hospital later, not handled at the desk."
7. No date, refresh, loading or empty states.

### 4.3.2 Hospital Dashboard (Administrator)
1. **Title/subtitle:** "Hospital Dashboard" / "Hospital-wide overview". A period selector **Today · Yesterday · This Week · This Month** (default Today) sits in the "Hospital Overview" header.
2. **KPI tiles** (not clickable): **Appointments Today / Appointments** · **Active Doctors** ("of 7 on roster": doctors not on break) · **Total Patients** (fixed "12,480" **[Prototype-only]**) · **Revenue Today / Revenue** ("Desk + online prepaid").
3. **Appointments by Department — <period>**: a bar chart per department. **[Prototype-only]** The bars are fixed sample numbers scaled by the period, not computed from appointments.
4. **Requires Attention:** "n walk-in payment(s) pending" → Appointments · "n settlement(s) overdue — ₹x due from Medibook" → Settlements · always "n settlements awaiting transfer — ₹x expected from Medibook" → Settlements.
5. **Doctor Performance** (link "Manage Staff" → Doctors & Departments): top five doctors by today's appointment count with department, rating and status (Active / On Leave — "On Leave" here means the live-queue "On Break" state).
6. **Patient Footfall — <period>**: a line chart. **[Prototype-only]** Fixed sample series.
7. **[Prototype-only]** For periods other than Today, appointment and revenue totals are fixed sample values; the Today revenue adds a fixed ₹1,12,000 to the real paid total; ratings are fixed.
8. **Gap:** the FRD dashboard KPIs for cancellations and slot utilisation do not exist; live token boards by department exist only as the Front Desk snapshot.

## 4.4 Appointments (front desk)

### 4.4.1 Purpose and access
1. The Appointments screen is the front desk's working list of every consultation booked at this hospital, whether booked online through the patient app or walked in. Both hospital roles (Receptionist and Administrator) can use it.
2. It is reached from the sidebar item **Appointments**, from the receptionist dashboard tiles ("Appointments Today", "Pending Payment", "Walk-ins Today", "View All"), from the admin dashboard alert about pending walk-in payments, and from the notification bell.
3. **Key modelling fact.** One appointment row equals one patient–doctor consultation. Payment facts (paid/pending/refunded, mode, reference) and queue facts (token, called-at time, queue order) are attributes of the appointment; there is no separate payment, receipt or queue-event record in the prototype.

### 4.4.2 What you see
1. **Tabs with live counts:** All · Online (n) · Walk-in (n) · Pending Payment (n) · In Queue (n). Counts are hospital-wide totals over all dates and ignore the filters below. A **New Appointment** button sits on the right.
2. **Search box:** "Search by patient name, MR number or token".
3. **Filters:** Date (Today · Tomorrow · This Week; default Today) · an exact date picker ("Pick a specific date") · Department (All Departments + the six departments) · Doctor (All Doctors + the seven doctors; not narrowed by department) · Status (All Status · Scheduled · In Queue · Completed · Cancelled · No-show) · a **Clear all** link when anything is non-default · a refresh icon that does nothing **[Prototype-only]**.
4. **Table columns:** MR Number · Patient (avatar + name) · Doctor / Dept · Source (badge "Online" or "Walk-in") · Time (slot time with the date label beneath) · Payment (badge Paid/Pending/Refunded with the amount beneath) · Status (badge; the token number is shown beneath when one exists) · Action.
5. **Action column:** one context button (rules in §4.4.4) plus an eye icon ("Details") that opens the appointment drawer. Clicking anywhere else on the row also opens the drawer.
6. **Empty state:** "No appointments match your filters." **Paging:** 8 rows per page with "Showing m–n of T appointments".

### 4.4.3 Search, filter and sort rules
1. Search matches patient name, MR number and token as a case-insensitive "contains"; it does not search phone or doctor.
2. Date filter: "Today" and "Tomorrow" match the appointment's date label exactly; **"This Week" applies no date filter at all** (it shows every date). The exact date picker, when set, overrides the dropdown.
3. Department, Doctor and Status are exact-match filters. Changing a tab or filter returns to page 1.
4. Any column except Action can be sorted by clicking its header (ascending, then descending). There is no default sort: rows appear newest-first (new bookings are placed at the top).
5. **[Observation]** Appointment dates are stored as the labels "Today", "Tomorrow" or "14 Jun", not as real dates, and they never roll forward. A booking made for today stays "Today" forever. This is a prototype shortcut; the backend must store real dates and times.

### 4.4.4 Row action button (what the desk is prompted to do next)
1. Status Cancelled or No-show → no button.
2. Status Completed → **Receipt** (opens the receipt/token print view).
3. Status In Queue → no button (the patient is already in the doctor's queue).
4. Walk-in with payment Pending → **Mark Payment** (opens the Record Payment dialog).
5. Otherwise (Scheduled and paid, or an online booking) → **Check In** for online bookings or **Issue Token** for walk-ins. Either immediately gives the patient a token (or keeps the one already issued), sets the status to **In Queue**, and shows "<patient> checked in · Token T-0xx". There is no confirmation step.

### 4.4.5 Appointment drawer (details panel)
1. **Header:** patient name; "MR number · age yrs · gender".
2. **Badges:** source, status, payment.
3. **Details:** Doctor · Department · Date & Time · Booking Source ("Medibook App (online)" or "Walk-in (at desk)") · Consultation Fee · Payment · Token (or "—").
4. **Booking Remark** card when a remark exists; **Cancellation Reason** card when the appointment is cancelled and a reason was recorded.
5. **View Patient Profile** button → opens the patient's profile.
6. **What is not shown:** any history/timeline of actions, who did what and when, payment mode or reference, waiting time. The FRD expects audit trails of booking state transitions (see Section 10).
7. **Footer buttons and when they appear:**
   1. **Mark Payment** — walk-in with payment pending.
   2. **Check In / Issue Token** — status Scheduled and not awaiting payment.
   3. **Receipt** — whenever the payment is Paid, in any status (including cancelled online bookings, which remain "Paid").
   4. **Edit** — status Scheduled only.
   5. **Reschedule** — status Scheduled only.
   6. **No-show** — status Scheduled only; confirmation "Mark <patient> as a no-show? You can undo this afterwards." → status No-show; token and payment untouched; message "Marked as no-show".
   7. **Cancel** — status Scheduled only (see §4.4.7).
   8. **Undo check-in** — status In Queue; confirmation (red) "Send <patient> back to Scheduled and remove their token from the queue?" → status Scheduled; the token is removed for walk-ins but **kept for online bookings** (so, contrary to the dialog text, an online patient remains in the doctor's waiting list); if the doctor was serving that token, the "now serving" slot is cleared but the doctor's status is not changed. Message "Check-in undone · back to Scheduled".
   9. **Undo no-show** — status No-show → back to Scheduled immediately ("Reverted to Scheduled").
   10. **Reinstate** — status Cancelled → back to Scheduled immediately ("Reverted to Scheduled"); payment state is left as it was, so a refunded walk-in can be reinstated and then offered a token without paying again **[Observation]**.
   11. A Completed appointment has no actions other than Receipt; it cannot be reopened.

### 4.4.6 Record Payment dialog (walk-ins)
1. Title "Record Payment". Shows the patient (name, MR number, doctor, department, a "Walk-in" badge), a line "Consultation — <department>" with the fee, "Total Payable", and the note "Payment is collected externally — record the mode here to generate the bill & token."
2. **Payment Mode:** Cash (default), UPI, Card. For UPI or Card an optional free-text "<mode> Reference No. (optional)" (placeholder "e.g. UPI txn id / last 4 digits") — no validation.
3. **Mark Paid & Issue Token** → payment becomes Paid, a token is issued (or the existing one kept), status becomes In Queue, mode and reference are stored, message "Payment recorded · Token T-0xx issued". The receipt view then opens automatically.
4. **Rules and gaps:** the amount cannot be edited; no partial or split payments, discounts, taxes, payer name or payment date/time are captured. Recording a payment for a walk-in dated tomorrow still puts them In Queue today with a token **[Observation]**. The previously chosen mode/reference stays pre-filled for the next patient on the same screen **[Observation]**.

### 4.4.7 Cancel Appointment dialog
1. Text "Cancel the appointment for <patient> with <doctor>?"; a **Reason (optional)** dropdown: Patient request · Doctor unavailable · Duplicate booking · Scheduling error · Other (no free text).
2. Information note depends on the case: online → "Prepaid online — Medibook processes any refund to the patient per its slab policy (little or none on the day of the visit, near-full if cancelled well in advance)."; walk-in paid → "Payment was collected at the desk. Handle any refund directly with the patient."; walk-in unpaid → "No payment was collected for this walk-in."
3. For a paid walk-in only: a switch **Record desk refund of ₹<fee>** (on by default) with the caption "Marks the payment Refunded so desk collections reconcile."
4. **Cancel Appointment** → status Cancelled, the reason (if chosen) is stored, and, if the switch is on, the payment becomes Refunded via "Desk". Messages: "Appointment cancelled · desk refund recorded" or "Appointment cancelled".
5. **Rules and gaps:** no cancellation cut-off is enforced (the Hospital Settings "cancel before" rule is never read); refunds are always for the full fee with no reference or date; an online cancellation leaves the payment as "Paid" (the refund is assumed to happen on Medibook's side, and no refund slab calculation exists); the token is not released; a cancelled appointment still counts toward the patient's visits.

### 4.4.8 Edit Appointment dialog (status Scheduled only)
1. Fields: Department (required; changing it clears the doctor) · Doctor (required; list depends on department) · Date (date picker; today or later) · Time (11 fixed slots: 9:00 am, 9:30 am, 10:00 am, 10:30 am, 11:00 am, 11:30 am, 12:00 pm, 2:00 pm, 3:00 pm, 4:00 pm, 5:00 pm) · Note (free text).
2. Shows "Consultation fee: ₹<fee of the chosen department>" and, if it differs from the fee already charged, "(was ₹<old>)" plus the warning "Fee changed after payment — settle the difference at the desk." when already paid.
3. **Save Changes** → validation "Select department and doctor"; then the appointment is updated and the fee is re-priced to the new department's fee even if already paid (no adjustment record). Message "Appointment updated". Patient, source, payment, token and status cannot be edited here.
4. No availability, clash, leave or capacity check is performed.

### 4.4.9 Reschedule dialog (status Scheduled only)
1. Shows the patient chip, **New Date** (today or later) and **New Time** (the same 11 slots), and the note "Same doctor only. Need a different doctor? Cancel & rebook." where the link opens the Cancel dialog.
2. **Save Changes** → only date and time change; token, payment and status are untouched. Message "Appointment rescheduled".
3. **[Observation]** Moving a tokened same-day appointment to another date silently removes it from the live queue while it keeps its token; no reschedule window, limit or availability check exists.

### 4.4.10 Receipt & Token print view
1. Opened from Receipt buttons and automatically after recording a payment. Buttons: **Print** (opens the browser print dialog; only the receipt and slip print) and **Done**.
2. **Receipt block:** the hospital logo and the name "Apollo Hospital" (hard-coded, not taken from Hospital Settings **[Prototype-only]**); caption "Payment Receipt · Prepaid via Medibook" (online) or "Payment Receipt · Collected at Desk" (walk-in); a "Paid" badge; fields Receipt No. · Date (the appointment slot, not the payment time) · Patient · MR Number · Payment Mode (online receipts print "Cash" because no mode is recorded for them **[Observation]**) · Reference; one line "Consultation — <doctor> (<department>)" with the amount; "Total Paid"; and a footer sentence about the receipt being computer-generated.
3. **Receipt number rule (as built):** "RCPT-" + the last five characters of the MR number + "-" + today's day of the month (for example RCPT-47202-10). **[Observation]** It is generated at display time, never stored, and is not unique (the same patient on the 10th of any month, two consultations on one day, or a reprint all give the same number). A real receipt series must be designed server-side.
4. **What is missing for the contract:** GST/tax lines, hospital GSTIN, patient GST details, receipt series, digital download/PDF, refund receipts.
5. **Token slip block:** "Apollo Hospital", "Queue Token", the token in large type (blank when no token, for example a future-dated online booking), Patient, Doctor, Dept, Time, and "Please wait for your token to be called." No room number, QR code or issue time.

### 4.4.11 New Appointment (walk-in booking or registering an online arrival)
1. **Reached from** the Appointments screen, the receptionist dashboard quick action, and from a patient's row/profile (in which case the patient is pre-selected).
2. **Patient details card** — one of three modes:
   1. **Search** (default): a box "Search by name, phone number or MRN" showing up to six matching patients (name, MR number, phone) from the hospital's patient list; pick one to select. A button **Add new patient** switches to the form.
   2. **Adding a new patient:** Full Name (required), Phone Number (required; the "10-digit mobile" hint is not enforced), Age (free text; non-numbers become 0), Gender (Male/Female/Other, default Male); **Back to search**. There is no MR number field: the system generates it. Email and address are not captured here.
   3. **Picked:** a blue chip with name, MR number, age, gender, phone and a **Change** button.
3. **Appointment Information card:**
   1. **Appointment type:** Walk-in (default) or Online, with the explanation "Walk-in = booked at the desk (collect payment & issue token now, even for a future date). Online = booked & prepaid via the Medibook app."
   2. **Date:** date picker, default today, today or later, no upper limit.
   3. **Appointment time:** 10 fixed slots (9:00 am to 12:00 pm every 30 minutes, then 2:00, 3:00 and 4:00 pm), default 10:00 am. **[Observation]** The Edit/Reschedule dialogs offer 11 slots (adds 5:00 pm) and the sample data uses 15-minute times that appear in neither list.
   4. **Consultations:** one or more rows of Department + Doctor ("One consultation = one doctor, one fee, one token. Add more to book several doctors for the same patient in a single visit — you collect one combined payment."). **Add another consultation** adds a row; rows can be removed down to one. The doctor list depends on the department.
   5. **Note (Optional)** shared by all consultations.
   6. **Fee line:** "Consultation fee: ₹x" or "Total for n consultations: ₹x" (sum of the departments' fees); for Online a green "Prepaid online" badge.
   7. **Doctor capacity hint** per consultation (§4.4.12).
4. **Buttons:** Cancel; for walk-ins **Save & Record Payment**, for online **Create Appointment(s)**.
5. **Validation:** a patient must be selected or a new patient must have a name and phone, and at least one consultation must have both department and doctor; otherwise the message "Select a patient and at least one department + doctor".
6. **What happens on save (business rules):**
   1. One appointment is created per consultation, all with the same date, time and note, status **Scheduled**, placed at the top of the list.
   2. Fee = the department's fee (Cardiology ₹800, Orthopedics ₹700, Pediatrics ₹600, Neurology ₹1,000, ENT ₹500, Dermatology ₹650); the doctor does not affect the fee. A department without a fee would default to ₹600.
   3. Payment = **Paid** for Online (assumed prepaid in the app; no booking reference is captured) and **Pending** for Walk-in.
   4. Token: an **online appointment for today receives a token immediately** at creation (before the patient arrives); online future dates and all walk-ins get no token yet.
   5. If the patient is new, a patient record is created with a generated MR number ("AP" + a running number, for example AP800001).
   6. Walk-in → the combined **Record Payment** dialog opens (Cash/UPI/Card + optional reference; "Mark Paid & Issue Token(s)"); on confirmation each consultation becomes Paid and In Queue with consecutive tokens, and the combined receipt opens (one receipt, one token slip per consultation). Cancelling the payment dialog leaves the appointments as Pending.
   7. Online → message "Online appointment saved" / "n online appointments saved" and return to the list.
7. **Defects observed in code:**
   1. **[Observation]** Because of a timezone bug in the date helper, in India the date picker defaults to *yesterday*; an untouched walk-in/online booking is then labelled with yesterday's date, hidden by the default "Today" filter, given no token, and never enters the queue.
   2. **[Observation]** Booking two or more consultations for a *new* patient creates a separate MR number and patient record per consultation.
8. **Not implemented:** slot generation from doctor or department hours, slot duration/buffer, per-slot capacity, double-booking checks (the same slot can be booked any number of times and several doctors at the same time), doctor leave or inactive checks, opening-hours checks, past-time checks for today, holds/expiry.

### 4.4.12 Doctor capacity hint
1. Shown under each completed consultation row: "Today's load — <doctor>" with a progress bar.
2. Rule: bookings counted for that doctor **today** (regardless of the date chosen) excluding cancelled and no-show, against a fixed cap of **16 per doctor per day**. Green up to 75%, amber above 75% (13 or more), red at 16 with the text "Doctor is fully booked for today — consider another slot or doctor."; if the doctor is on a break: "<Name> is on a break today — avoid booking new walk-ins."
3. The hint is advisory only; booking is never blocked.

## 4.5 Patients

### 4.5.1 Purpose and access
1. The hospital's patient register: identity and contact details only. The screen itself states the principle: "Medibook stores identity & contact only — no clinical data." Both roles.
2. Reached from the sidebar item **Patients** and from the receptionist quick action "Find Patient".

### 4.5.2 Patients list
1. **Search** "Search by patient name, MR number or phone" (case-insensitive "contains" over name, MR number and phone).
2. **Filters:** Department (All Departments + the six fixed booking departments; a patient matches if they have any appointment in that department) · Status (All Status · Active · Inactive) · Sort (Sort: Recent — newest record first · Sort: Name — A to Z) · **Clear all** · refresh icon (does nothing **[Prototype-only]**).
3. **Columns:** MR Number · Patient Name (avatar + name) · Age ("—" when unknown) · Gender · Phone · Visits · Status · Action (eye "View" → profile; calendar-plus "Book appointment" → New Appointment with this patient pre-selected). The whole row opens the profile. Column headers sort.
4. **Rules:** **Visits** counts every appointment of that MR number including cancelled and no-show ones. Patients who exist only on appointments (no register record) are synthesised into the list. 8 rows per page. Empty state "No patients match your filters."
5. **[Observation]** There is no **Add Patient** button anywhere in the app (an add-patient dialog exists in the code but cannot be opened); patients are created only as a side effect of booking an appointment at the desk. There is no delete, merge or export.

### 4.5.3 Patient Profile
1. **Header:** avatar, name, status badge, "MR: <number>", "<age> yrs · <gender>", phone; buttons **Edit** and **New Appointment** (pre-selects this patient).
2. **Booking History** table: Date (with time) · Doctor / Dept · Source (Online / Walk-in) · Payment (Paid / Pending / Refunded) · Token · Status; or "No appointments yet for this patient."
3. **Contact Details:** Phone · Email · Gender · Age · Address.
4. **Billing Summary:** Total Visits (all appointments) · Total Paid (sum of Paid amounts) · Outstanding (sum of Pending amounts, red when above zero). Refunded amounts count in neither.
5. **[Observation]** Opening an unknown MR number does not show "not found"; it shows the first sample patient's header with an empty history.

### 4.5.4 Edit Patient dialog
1. Fields: Full Name (required) · Phone Number (required; the "10-digit mobile" hint is not enforced) · Age · Gender (Male / Female / Other) · Email · Status (Active / Inactive) · Address ("Area, City").
2. **Save Changes:** validation "Name and phone are required"; then "Patient details updated". Editing the register does **not** update the name/age/gender/phone copies stored on that patient's existing appointments **[Observation]**.
3. **Rules:** an Inactive patient still appears everywhere and can still be booked (no effect). MR numbers are generated as "AP" plus a running number (sample records AP847201–AP847212; new ones from AP800001).

## 4.6 Token Management (Live Token Queue)

### 4.6.1 Purpose and access
1. The front desk's control panel for calling patients to consultation, one card per doctor. Both roles. Reached from the sidebar (**Token Management**; page title "Live Token Queue"), the receptionist dashboard ("In Queue", "Department Queue", "Open Queue", and the per-department rows of the queue snapshot, which pre-select that department) and the bell.
2. **[Observation]** There is no separate public display board or TV view, and nothing is pushed from a server; the screen simply re-renders every 30 seconds to update elapsed minutes. The FRD's "live token boards by department" and the patient app's live token progress both need a server-driven queue feed.

### 4.6.2 What you see
1. **Toolbar:** search "Search by doctor" (doctor name only) · Department filter (remembered while you move around the app; changing it resets the doctor filter) · Doctor filter (doctors of the selected department) · a refresh icon that does nothing **[Prototype-only]** · four live figures: **Serving** (doctors currently consulting), **Waiting** (total patients waiting), **On break**, **Longest** (longest current consultation in minutes, red above 20 minutes).
2. **Doctor cards** (seven fixed doctors; fixed rooms 101, 102, 201, 301, 401, 501, 601):
   1. Name, "department · Room n", and a status pill: **Available** (blue), **Consulting** (green), **Waiting** (amber), **On Break** (grey).
   2. **Now serving** box: the token in large blue type, the patient name and the elapsed time ("just now" / "n min", red above 20 minutes); or "On a break" / "Ready to call next" / "No patients waiting".
   3. **Up next:** the first three waiting tokens as chips (hover shows the patient) and "+n" for the rest; "n waiting".
   4. **Controls:** **Call Next**; when serving also **Done** and a **Skip** icon ("Skip — move to end of queue"); always a pause/play icon ("Take a break" / "Resume").
3. **Empty state:** "No doctors match your search."

### 4.6.3 Queue rules (as implemented)
1. A patient is in a doctor's waiting list when: the appointment is with that doctor, dated **Today**, has a token, is not Completed/Cancelled/No-show, and is not the token currently being served. Consequently an **online booking for today is waiting from the moment it is booked**, before the patient checks in.
2. Order: never-skipped patients first in token order; skipped patients go to the back in the order they were skipped. There is no priority or emergency lane and no estimated wait time.
3. **Call Next:** takes the first waiting patient, sets status In Queue, records the call time, marks the doctor **Consulting** and shows "Now consulting T-0xx · <patient>". **[Observation]** Calling next while someone is still being served neither completes nor skips them: the previous patient silently returns to the waiting list at their original position.
4. **Done:** the served appointment becomes **Completed**; the doctor becomes Waiting (if others wait) or Available; message "T-0xx completed". No completion time, duration or notes are recorded.
5. **Skip:** the served patient is put at the back of the queue with status In Queue and message "T-0xx skipped · moved to the end of the queue". Skips are unlimited and a skipped patient is never automatically marked no-show; in fact the No-show action is only available while the appointment is still Scheduled, not once In Queue **[Observation]**.
6. **Break:** toggles the doctor between Available and On Break. Taking a break does not clear the patient being served; the buttons still work while on break.
7. Doctor status here (Available/Consulting/Waiting/On Break) is completely separate from the doctor status in the Doctors & Departments catalogue (Active/On Leave/Inactive) and from leave dates; a doctor recorded as on leave in the catalogue is still bookable and can be consulting here **[Observation]**.
8. Tokens are hospital-wide "T-" plus a three-digit running number (T-001…); they never reset per day, doctor or department, and are never reused, even when a check-in is undone. (A per-department prefix scheme C/O/P/N/E/D exists in the code but is unused.) **[Observation]** The FRD requires sequential tokens per doctor per day; the token scheme must be decided (see Open questions).

## 4.7 Payments

### 4.7.1 Purpose and access
1. A finance view over the same appointment rows (there is no separate payments ledger). Both roles. Reached from the sidebar item **Payments** (section Billing) and from the receptionist dashboard link "Open Payments".

### 4.7.2 What you see
1. **Four KPI cards** (always computed over all appointments, ignoring the filters below):
   1. **Collected at Desk** — total of walk-in payments marked Paid for today, with "n walk-in payment(s)".
   2. **Desk Cash** — the part of that total whose mode is Cash (payments with no recorded mode count as Cash).
   3. **Prepaid Online** — total of online, Paid appointments for today (including cancelled or no-show online bookings, which stay Paid), "via Medibook · settled later".
   4. **Pending Collection** — the **number** (not the amount) of pending payments across all dates, "Walk-ins to collect".
2. **Tabs:** All · Paid (n) · Pending (n) · Refunded (n). **[Observation]** "All" excludes refunded rows.
3. **Export** button (§4.7.4).
4. **Search** "Search by patient name or MR number"; filters Date (Today · This Week · This Month — only "Today" actually filters; the other two show everything **[Observation]**) · Source (All Sources · Walk-in · Online) · Department · Doctor · Mode (All Modes · Cash · UPI · Card; selecting a mode hides online and pending rows) · Clear all · an information tooltip explaining that walk-in payments are collected at the desk while online bookings are prepaid through Medibook and settled to the hospital later.
5. **Table columns:** Patient (name + MR number) · Doctor / Dept · Source · Mode ("Prepaid" for online, Cash/UPI/Card for desk, "—" when unpaid) · Amount · Status (Paid/Pending/Refunded) · Action.
6. **Action:** Pending → **Record** (opens the Record Payment dialog; on success the receipt opens); Paid → **Receipt**; Refunded → the text "Refunded by Medibook" (online) or "Refunded at desk" (walk-in).
7. **Paging:** 9 rows per page; the pager also shows "Desk collected: ₹x" (same figure as the first KPI). Empty state: "No payments match your filters."

### 4.7.3 Rules and gaps
1. Recording a payment here has the same effect as from Appointments: token issued, status In Queue.
2. There is no refund action on this screen (refunds are only recorded through the Cancel dialog), no partial payment, no void/reversal, no reprint counter, no refunds KPI, no date-range totals, no payment timestamps.
3. **Gap versus the contract:** "Payment Reports – view payments, refunds, cancellations" exists only as this filtered list plus CSV; the FRD's revenue/refund reporting with date ranges is not built (see Section 10).

### 4.7.4 Export
1. **Export** downloads a real CSV file named `medibook-payments.csv` containing the currently filtered rows (all pages) with the columns Patient, MR Number, Doctor, Department, Source, Mode, Amount, Status; message "Exported medibook-payments.csv". It contains no date, token, reference number or timestamp.

## 4.8 Billing & Settlements (Administrator)

### 4.8.1 Business context
1. Medibook collects the consultation fee for every **online** booking made through the patient app, keeps a **10% platform commission**, and transfers the net amount to the hospital by an expected date. Walk-in payments are collected at the desk and kept 100% by the hospital. The hospital reconciles each transfer here and marks it received.
2. The screen's own explanation (tooltip): "Medibook collects online booking fees upfront, keeps a 10% commission, and transfers the net amount to the hospital by the expected date. Fees become payable only after the appointment is completed — pre-visit cancellations are refunded to the patient per Medibook's slab policy. Mark a transfer Received once it reaches your account."
3. **Contract conflict to resolve:** the Preliminary FRD states that settlements from the SaaS owner to hospitals are done **outside** the application, with only helper reports inside it. The prototype instead implements an in-app settlement workflow on both the hospital and operations sides (see Section 10).

### 4.8.2 Settlements tab
1. **Tabs:** Settlements | Plan & Billing; an **Export CSV** button on the Settlements tab.
2. **KPI cards** (computed over all statements): **Total Settlement Amount** (sum of net; "n statements") · **Received Amount** (sum of net for Received; "x% of total") · **Overdue Settlements** (sum of net for Overdue; "n settlement(s)") · **Held by Medibook (Upcoming)** — a fixed ₹37,800 with the caption "payable after appointments complete" **[Prototype-only]**.
3. **Filter:** "Expected between" a date range (inclusive) with a **Clear** link; caption "10% platform commission applies".
4. **Settlement Records** table with a search box "Search by statement, date or status" (searches statement number, period text and status; not the expected date or UTR despite the placeholder **[Observation]**). Columns: **Settlement Period** (period text, statement number beneath, and any Medibook remark in quotes) · **Gross Amount** · **Commission** (with "10%") · **Net Payable** (with "released ₹x" beneath when a partial amount was released) · **Expected Date** · **Status** (badge; the bank reference UTR beneath when present) · **Action**. Sortable columns; 7 rows per page; footer "Net due: ₹x" (sum of net for statements not yet Received). Empty state "No settlements match your filters."
5. **Statuses and the action shown:**
   1. **Pending** (amber) → **Request** button (or "Requested · awaiting Medibook" once requested).
   2. **Overdue** (red) → **Raise a request** link (or "Follow-up raised · awaiting Medibook").
   3. **Released** (green) → **Mark Received** button.
   4. **Received** (green) → tick with the received date.
   5. **Payout failed** (red) → "Payout failed · Medibook is retrying".
6. **Confirmation dialogs** (each shows the period, the amount — the released amount if partial, with "partial release · statement net ₹y" — the expected date, the transfer reference and any remark):
   1. **Confirm Transfer Received** — "Confirm the hospital has received the bank transfer for <statement>." → **Mark Received** → status Received with today's date; message "Marked as received". No UTR entry or verification by the hospital; cannot be reversed; the Operations console is not notified but sees the status.
   2. **Raise Settlement Request** — "This settlement is overdue. Raise a follow-up request with Medibook for <statement>." → **Raise Request** → the statement is flagged as requested and an open **Settlement** request appears in the Operations console inbox with the subject "Overdue settlement follow-up — <statement>"; message "Follow-up raised with Medibook for the overdue transfer".
   3. **Request Settlement** — "Request Medibook to release the settlement for <statement>." → **Send Request** → same mechanism with the subject "Settlement release requested — <statement>"; message "Settlement requested from Medibook".
   4. **[Observation]** There is no free-text field in any of these dialogs; the hospital cannot describe a dispute, attach evidence, or withdraw a request.
7. **Export CSV** downloads `medibook-settlements.csv` with the filtered rows: Statement, Period, Gross, Commission %, Commission, Net Payable, Expected, Status, Transfer Ref, Received On; message "Exported medibook-settlements.csv". No statement PDF exists.
8. **Rules observed in the sample data (not generated by code):** statement numbers are platform-wide "MB-ST-####"; periods are weekly, Wednesday to Tuesday; the expected date is the period end plus four days; commission = 10% of gross rounded, net = gross − commission; a statement whose expected date equals today is Overdue. **[Observation]** No code creates statements, computes commission, detects overdue or records payout failures; these must be backend jobs.
9. **Sample ledger:** 14 statements for Apollo Hospital (MB-ST-2393 to MB-ST-2406), gross ₹13,50,800, commission ₹1,35,080, net ₹12,15,720; one Pending (MB-ST-2406, ₹92,160 net, expected 20 Jun 2026), one Overdue (MB-ST-2405, ₹88,740, expected 13 Jun 2026), one Released (MB-ST-2404, ₹97,380, UTR26-2404K, remark "Released in full after bank re-verification."), eleven Received.

### 4.8.3 Plan & Billing tab
1. **Plan card:** "<Plan> Plan" with an "Active" pill and "Billed monthly · managed by Medibook"; the monthly price (sample: Growth, ₹24,999/mo). The plan name comes from the Operations console's hospital registry and the price and quota from its plan catalogue.
2. **Online Bookings This Month:** a progress bar "3,120 used (62%)" of "5,000 / month". Tooltip: "Each appointment booked through the Medibook patient app uses one booking from the monthly plan quota. Walk-ins booked at the desk do not count. The quota resets on the 1st." The bar turns red above 85%. **[Prototype-only]** The used figure is a fixed 3,120; nothing counts real bookings.
3. **Billing cycle** "Monthly · invoiced on the 1st"; **Next invoice** "01 Jul 2026" (fixed); **Status** Active.
4. Footer: "Plan tiers and pricing are managed by Medibook operations." and **Request Plan Change** (or, once requested, the pill "Change to <plan> requested · pending Medibook review").
5. **Request Plan Change dialog:** "Current plan: <plan>. Medibook operations reviews and applies plan changes — you'll see the result here." with **Requested Plan** (every other plan in the catalogue, including other hospitals' custom plans **[Observation]**). **Send Request** → validation "Pick the plan you want"; then a Pending plan-change record and an open **Plan** request are created for the Operations console; message "Plan change request sent to Medibook". The hospital receives no notification of the outcome; the pill simply disappears when operations approves or declines.
6. **Plan Invoices:** caption "Billed to GSTIN <hospital GSTIN> · Medibook GSTIN 27AABCM9407L1ZK · 18% GST included"; three fixed sample invoices (INV-2026-0244 01 Jun 2026, INV-2026-0219 01 May 2026, INV-2026-0198 01 Apr 2026; Growth · Monthly; ₹24,999; Paid) with a "PDF" link that does nothing **[Prototype-only]**. There is no pay-now, upgrade, card on file, GST breakdown or invoice status other than Paid.

## 4.9 Doctors & Departments (Administrator)

### 4.9.1 Purpose and access
1. The hospital's catalogue of departments and doctors. The screen states: "Doctors and departments you add here become searchable and bookable in the Medibook patient app."
2. **Critical observation for the backend:** in the prototype this catalogue is **not** the source used for booking. The Appointments, New Appointment and Token Management screens use a separate fixed list of six departments, seven doctors, rooms and fees. Adding, renaming, deactivating or putting a doctor on leave in this catalogue changes nothing in booking or the queue. The only consumer of the catalogue is the Operations console's read-only roster for this hospital. The backend must have one source of truth.

### 4.9.2 Doctors tab
1. **Search** "Search doctors by name or specialization"; **filters** Department (All Departments + every catalogue department, including inactive ones) · Status (All Status · Active · On Leave · Inactive) · Clear all. Button **Add Doctor**.
2. **Columns:** Doctor (photo or initials + name) · Department(s) · Fee · Working Hours (a summary such as "Mon–Fri · 9:00 am–5:00 pm" built from the first and last enabled weekday and the first day's times) · Rating ("4.9 (128)") · Status badge (Active green, On Leave amber, Inactive grey) · Action (pencil "Edit" → profile; red trash "Remove").
3. **Remove** → confirmation "Remove Doctor" / "Are you sure you want to remove <name>? This can't be undone." / **Delete** → the doctor is deleted ("Doctor removed"); existing appointments referencing the doctor are untouched. No paging on this table.
4. **Sample doctors:** Dr. Thomas K. (Cardiology, ₹800, 4.9, 128 reviews, leave 18–20 Jun "Conference"); Dr. Anil R. (Cardiology, ₹800); Dr. Geetha R. (Orthopedics, ₹700, leave 25 Jun "Personal"); Dr. Kumar V. (Pediatrics, ₹600, **On Leave**, 10–16 Jun "Medical leave"); Dr. Maya S. (Neurology, ₹1,000); Dr. Arun B. (ENT, ₹500); Dr. Leela P. (Dermatology, ₹650).

### 4.9.3 Doctor Profile (create and edit)
1. **Header:** photo/initials, name (or "New Doctor Profile"), status badge, "specialty · departments · ★ rating (reviews)"; a **Profile status** toggle Active | On Leave | Inactive with captions "Live & bookable in the app" / "Visible, booking paused" / "Disabled — hidden from the patient app" (captions only; nothing enforces them **[Observation]**).
2. **Profile tab fields:** Photo (Upload/Change Photo — works, kept in memory) · Full Name (required) · Specialization · Room Number · Phone Number · Email · Qualification ("MBBS, MD") · Experience (years) · Registration No. ("KMC/…") · Status · Consultation Fee ("Overrides the department's base fee. This is what patients pay & see in the app.") · Departments (required; multi-select chips; "A doctor can belong to more than one department.") · About ("Short bio shown in the patient app"). Rating and review count are not editable.
3. **Availability tab:**
   1. **Consultation Settings:** Consultation duration (10/15/20/30 mins) · Max appointments per slot (5/10/15 slots) · Online appointment booking (switch) · Buffer time between appointments (0/5/10/15 mins). **[Prototype-only]** None of these controls can actually be changed or saved.
   2. **Working Hours** grid: Mon–Sun, each with an on/off switch and From/To times (options 8:00 am, 9:00 am, 10:00 am, 11:00 am, 12:00 pm, 1:00 pm, 2:00 pm, 4:00 pm, 5:00 pm, 6:00 pm, 8:00 pm). Caption: "The Medibook app only offers booking slots during these hours. Outside them, patients can't book." **[Observation]** Edits to this grid are displayed but **discarded on save** (for departments too); no validation that To is after From.
   3. **Shifts:** two fixed sample shifts (9:30 AM–1:00 PM, 2:00 PM–5:00 PM); Add Shift and delete only show messages **[Prototype-only]**.
   4. **Leave / Unavailability** ("Block dates the doctor is unavailable. Booking is disabled in the app for these dates."): lists sample leave entries (date range + reason); **Add Leave** and delete only show messages **[Prototype-only]**. Leave dates are free text ("18 Jun"), not real dates; the On Leave status is set manually and never derived from leave.
4. **Reviews tab** (existing doctors): "Reviews come from patients in the Medibook app and are read-only."; average rating, star display, "Based on n patient reviews", and review cards (author, stars, text, relative date). No moderation actions.
5. **Save (Add Doctor / Save Changes):** validation "Doctor name is required", then "Assign at least one department"; new doctors are added at the top of the list ("Doctor added"); edits show "Doctor profile saved". **Delete Profile** → "Delete Doctor Profile" / "Delete <name>'s profile? This removes them from the patient app and can't be undone." → "Doctor profile deleted".
6. **Gap versus contract:** the FRD requires session time ranges, slot size (10/15/20 min), buffer times, leaves and exceptions per date, and slot generation with open/block/bulk actions that reflect instantly in the app. Only the visual shells of these exist.

### 4.9.4 Departments tab
1. A grid of department cards: image or colour band with a stethoscope icon, status badge, name, description, "n doctors", base fee, and hours summary (a stored text such as "Mon–Sat · 9am–6pm"). Button **Add Department**.
2. **Sample departments:** Cardiology ₹800; Orthopedics ₹700; Pediatrics ₹600; Neurology ₹1,000 (Tue–Sat); ENT ₹500 (Mon–Fri); Dermatology ₹650 (**Inactive**).
3. Clicking a card opens a side panel with the department's image, status, hours, description ("No description yet." when empty), the list of its doctors with status, and buttons **Delete**, **Close**, **Edit**.
4. **Add / Edit Department dialog:** Department Name (required) · Base Consultation Fee (digits only are kept) · About ("Short description shown in the patient app") · Department Image ("Shown on the department's page in the Medibook patient app.", hint "Optional · 800×450"; the upload placeholder only shows "Image upload — demo" **[Prototype-only]**) · Working Hours grid ("Department hours override hospital hours. Doctors can narrow this further." — edits discarded on save **[Observation]**) · Status (Active / Inactive). Validation "Department name is required"; messages "Department added" / "Department updated". New departments receive a colour automatically; the hours text is never recomputed from the grid.
5. **Delete** → "Delete Department" / "Are you sure you want to delete <name>? This can't be undone." → "Department deleted". **[Observation]** Doctors are linked to departments by name; deleting or deactivating a department has no effect on its doctors, and an Inactive department still appears in every doctor filter and stays bookable.
6. **Gap versus contract:** services with optional pricing, taxes and coupons per department (FRD) do not exist.

## 4.10 Users & Roles (Administrator)

### 4.10.1 Purpose and access
1. Management of the hospital's staff logins and of custom roles with module-level permissions.
2. **Critical observation:** the roles and permission grids are **data only**. Nothing in the application reads them; what a user can see is decided solely by the two built-in roles (Receptionist / Administrator) in the page address. The footnote "Users see only the modules they can at least view" is not implemented. The FRD requires role-based access control on every screen and action, so the backend must enforce these permissions.

### 4.10.2 Users tab
1. **KPI cards:** Total Users · Active · Roles · Pending Invites (sample: 7, 6, 4, 1).
2. **Search** "Search users by name, email or username"; **filters** Role (All Roles + role names) · Status (All Status · Active · Inactive) · Clear all. Button **Add User**.
3. **Columns:** User (avatar, name, email) · Username · Role (coloured dot + name; blank if the role was deleted) · Last Active (fixed text such as "5 min ago" **[Prototype-only]**) · Status (Active / Inactive) · Action (eye "View" → user panel; key "Reset password"). No paging. Empty state "No users match your filters."
4. **Sample users:** Dr. S. Nair (Administrator); Riya Menon and Karthik Rao (Reception / Billing); Sunita Joseph (Department Front Desk); Mahesh Pillai (Department Front Desk, invite **Pending**); Anand Pillai (Accountant); Fatima Sheikh (Department Front Desk, **Inactive**). Emails use the hospital's domain (`@apollo.med`).

### 4.10.3 Add User dialog
1. Fields: Full Name (required) · Role (required; pick from the roles) · Email (required) · Phone · Username ("Auto from email if blank") · Password ("Set a password" / "Sent via invite").
2. Once a role is picked, a card shows the role's description and an access summary (Full access / Limited (some actions) / View only / No access to n other modules).
3. **How should they get access?** Email invite (default) · Mobile OTP · Set password now.
4. **Add User:** validation "Name, email and role are required" (no email-format, uniqueness or password-strength checks); the user is created Active with invite status **Pending** (email/OTP) or **Accepted** (set password now); username defaults to the part of the email before "@"; messages "Email invite sent" / "OTP sent for confirmation" / "User created with password". **[Prototype-only]** Nothing is sent and the password is discarded.

### 4.10.4 User panel (drawer)
1. Shows avatar, name, status, role and description, access summary, Username, Email, Phone, Role, Invite status (Accepted / Pending), Last active.
2. Buttons: **Edit Details** → "Edit user — demo" **[Prototype-only]**; **Resend Invite** (Pending only) → "Invite resent" with no state change **[Prototype-only]**; **Reset Password** → reset dialog; **Deactivate** / **Activate** → status toggles with "User deactivated" / "User activated".
3. **[Observation]** No user can be deleted; a user's role, name or contact cannot be changed after creation; there is no protection against deactivating oneself or the last administrator; invites never move from Pending to Accepted.

### 4.10.5 Reset Password dialog
1. "Reset the password for <name>. Choose how:" — Email reset link · Mobile OTP · Set temporary password (with a Temporary Password field that cannot be typed into **[Observation]**).
2. **Send / Set Password** → messages "Reset link sent to <email>" / "OTP sent to <phone>" / "Temporary password set". **[Prototype-only]** Nothing happens.

### 4.10.6 Roles & Permissions tab and Role editor
1. Role cards: colour, name, "System" lock (Administrator) or pencil, description, "n users", "n/10 modules". A dashed **Create Role** card.
2. **Role editor (side panel):** Role Name (required) · Description · a **Module Permissions** grid of ten modules (Dashboard, Appointments, Patients, Token Management, Payments, Billing & Settlements, Doctors & Departments, Reports, Hospital Settings, Users & Roles) × four actions (View, Add, Edit, Delete). Clicking a module name toggles its whole row. Each box is independent: enabling Add/Edit/Delete does not automatically enable View. A live "What this role can do" summary; when nothing is granted: "Nothing yet — grant at least View on one module."
3. **Administrator** is locked: "The Administrator role always has full access and can't be edited."
4. **Sample roles:** Administrator (everything); Reception / Billing ("Front desk — books walk-ins, records payments, issues tokens."): Dashboard view; Appointments view/add/edit; Patients view/add/edit; Token Management view; Payments view/add/edit; Department Front Desk ("Manages a department's live token queue and its appointments."): Dashboard view; Appointments view/edit; Patients view; Token Management view/add/edit; Accountant ("Payments, settlements and financial reports."): Dashboard view; Payments view/add/edit; Billing & Settlements view/add/edit; Reports view.
5. **Create Role / Save Role:** validation "Give the role a name" (no uniqueness check); messages "Role "<name>" created" / "Role updated". **Delete** (custom roles) deletes immediately with no confirmation ("Role deleted"); users holding that role keep a dangling reference **[Observation]**.

## 4.11 Reports (Administrator)

1. **Layout:** a header card for the selected report (name, one-line brief, **Export CSV**, **Export PDF**); a filter card showing only the filters that report declares; four KPI tiles; a picker with category tabs **All · Operations · Finance · People** and one card per report.
2. **Filters available:** date range (From/To with "Clear dates") · Department (the six fixed departments) · Doctor (the seven fixed doctors, not narrowed by department) · Status (appointment statuses, even on the Settlement Report **[Observation]**) · Mode (Cash/UPI/Card) · Source (Online/Walk-in) · User (fixed at "All Users" and cannot be changed **[Prototype-only]**). **[Observation]** No filter changes any figure on screen; they only appear in the CSV's "Range" column.
3. **Report catalogue (14 reports):**
   1. Appointment Report (Operations) — "Track appointments across doctors and departments." — filters date, dept, doctor, status.
   2. Booking Report (Operations) — "Track bookings by channel and slot." — date, dept, doctor, source.
   3. Revenue Report (Finance) — "Track hospital earnings over time." — date, dept.
   4. Payment Report (Finance) — "Track payments received at the desk and online." — date, mode, source.
   5. Refund Report (Finance) — "Track refunds processed by Medibook." — date.
   6. Settlement Report (Finance) — "Track payouts received from Medibook." — date, status.
   7. Commission Report (Finance) — "Track commission deducted on online bookings." — date.
   8. Doctor Performance Report (People) — "Track per-doctor load and ratings." — date, dept, doctor.
   9. Department Report (People) — "Track department-level performance." — date, dept.
   10. Cancellation / No-show Report (Operations) — "Track cancellations and no-shows." — date, dept, doctor.
   11. Patient Report (People) — "Track patient registrations and visits." — date, dept.
   12. User Activity Report (People) — "Track staff logins and actions." — date, user.
   13. Booking Source Report (Operations) — "Track online vs walk-in mix." — date.
   14. Time-based Revenue Report (Finance) — "Track revenue trends across the range." — date.
4. **What each report shows:** exactly four KPI tiles and nothing else (no table, columns or chart). Only the Settlement and Commission reports compute their tiles from the settlement ledger (Total Net Payable / Received / Overdue / Gross Collected; Commission (10%) / Online Gross / Net to Hospital / Walk-in Commission ₹0). All other tiles are fixed sample numbers (for example "Total Appointments 1,996", "Completed 1,742 (87.3%)", "Cancelled 142", "No-shows 84", "Total Revenue ₹ 12.5L", "Refunds Processed 38", "Top Rated Dr. Thomas K.", "Peak Day Friday") **[Prototype-only]**.
5. **Export CSV** downloads `<report>-report.csv` containing the four tiles as rows (Report, Range, Metric, Value); message "Exported <report>-report.csv". **Export PDF** only shows "Preparing PDF…" **[Prototype-only]**.
6. **Gap versus contract:** the FRD requires filterable, exportable (CSV/PDF) reports for bookings, cancellations, no-shows, revenue and slot utilisation by date range, department or doctor, and the quote requires patient history filtered by doctor/date/visit type/transaction mode and payment reports with refunds/cancellations. The prototype defines the report list and filters but no datasets; every report needs a real definition (see Section 10).

## 4.12 Hospital Settings (Administrator)

### 4.12.1 Structure and behaviour
1. Five sections in a left menu: **General · Management · System Rules · Working Hours · Notifications**. One draft holds all sections; whichever Save button is pressed saves everything. Only General has a **Cancel** (which reverts all sections). There is no validation of any field, no dirty tracking and no unsaved-changes warning.
2. **[Prototype-only]** Settings are saved in the browser's local storage (key `mb_settings`), so they survive a reload on that browser but are shared by every user of that browser and are not tied to a hospital account. Message on save: "Settings saved".
3. **Which settings actually do anything today:** only the hospital **name** (sidebar and support-ticket subject), **GSTIN** (invoice caption), **email** (plan-change request) and **bank details** (shown masked to operations and used as the payout guard). Every other field, all System Rules, Working Hours and Notification toggles are stored and displayed but read by nothing **[Observation]**. The backend must make these rules effective.

### 4.12.2 General
1. **Hospital Profile** ("Your logo, name and details appear on the hospital's profile in the Medibook patient app."): Logo (Change Logo; "PNG or JPG, up to 1MB" — not enforced; logos over about 400,000 characters are not persisted) · Hospital Name · Registration No. · GSTIN · Phone · Email · About. Sample: Apollo Hospital, KA-HOSP-20194, 29AAACA4033H1Z5, 080 4567 8900, contact@apollo.med.
2. **Photo Gallery** ("These photos show in your hospital's gallery when patients browse in the Medibook app."): Cover photo (1280×720), Reception, Add photo. **[Prototype-only]** Uploads only show messages and nothing is stored.
3. **Location** ("Patients see your location and get directions in the Medibook app. Click the map to drop the pin."): Address, Latitude, Longitude, and a decorative map where clicking drops a pin and derives coordinates from the click position (a formula covering south Bengaluru only) **[Prototype-only]**. Sample: 154 Bannerghatta Road, Bengaluru 560076; 12.9088, 77.5975.
4. **Bank & Payouts** ("Medibook releases online-booking settlements to this account. Operations sees these details (masked) on your hospital profile."): Account Holder Name · Bank · Account Number · IFSC Code · Settlement UPI ID (optional); note "Settlement payouts pause if these details are missing or invalid — keep them current." (not enforced for this hospital). Sample: Apollo Hospital Pvt Ltd, HDFC Bank, 50200048112233, HDFC0001234, apollohospital@hdfcbank.
5. Buttons **Cancel** / **Save Changes**.

### 4.12.3 Management
1. Link rows: **Manage Doctors** ("Add doctors, schedules, availability") and **Manage Departments** → Doctors & Departments · **User Management** ("Manage admin, receptionist, accountant access") and **Role Management** → Users & Roles · **Subscription & Plan** ("Manage subscription plan and payments") → Billing & Settlements.

### 4.12.4 System Rules ("Hospital-wide defaults. A doctor's custom availability or fee settings override these.")
1. **Appointment Rules** ("Applies to all new appointments"): Default consultation duration (10 / 15 / 20 / 30 mins; default 15) · Online appointment booking (on) · Max appointments per slot (5 / 10 / 15 / 20 slots; default 15) · Buffer time between appointments (0 / 5 / 10 / 15 mins; default 15).
2. **Cancellation & No-show Rules:** Allow patient cancellation (on) · Cancellation allowed before (1 hour / 2 hours / 4 hours / 24 hours; default 2 hours) · Auto mark No-show after (30 mins / 1 hour / 2 hours; default 1 hour).
3. **Token Queue Behaviour** ("Applies to all departments"): Token generation (Auto / Manual; default Auto) · Show token number to patient (on) · Allow hold token (on) · Hold timeout (15 / 30 / 45 mins; default 30) · Grace period (15 / 30 / 45 mins; default 30) · After grace (Auto Mark No-show / Keep waiting; default Auto Mark No-show).
4. **Consultation Fees** ("Default OP fee for doctors without a custom fee"): OP Consultation Fee (₹, digits only; default 500) · Validity (days) (default 10) · Apply to all departments (on).
5. Button **Save Rules**. These rules map directly onto the FRD's per-tenant policies (slot size, buffer, cancellation cut-off, hold duration, token logic); none is enforced yet.

### 4.12.5 Working Hours ("Hospital-level hours. Department and doctor schedules override these — the app uses the most specific (Doctor → Department → Hospital).")
1. Default open (7:00 am / 8:00 am / 9:00 am; default 8:00 am) to close (6:00 pm / 8:00 pm / 10:00 pm; default 8:00 pm); Monday to Sunday switches (default Sunday closed). Per-day custom times are not supported; no holidays. Button **Save Hours**.
2. **Gap versus contract:** holidays and branches (FRD) do not exist.

### 4.12.6 Notifications
1. **Patient Communications** ("Messages the hospital sends to patients via the Medibook app."): Appointment Confirmation ("Notify the patient when a booking is confirmed") · Visit Reminder ("Remind patients before their appointment").
2. **Admin Alerts** ("Alerts for the hospital admin about billing & settlements."): Settlement Received · Settlement Overdue · Plan Quota Low ("When online-appointment credits are running out"). All default on. Button **Save Preferences**.
3. **Gap versus contract:** message templates with placeholders, WhatsApp/push triggering, and announcement banners published by the hospital (FRD) do not exist in the hospital app.

## 4.13 Help & Support (both roles)
1. **Hero:** "How can we help?" / "Search our help center or browse common topics." with a search box that does nothing **[Prototype-only]**.
2. **Category tiles** (no action **[Prototype-only]**): Getting Started · Appointments · Billing · Settlements.
3. **Frequently Asked Questions** (accordion, first open): how to add a walk-in appointment; how the token queue is updated ("Token numbers are issued as a hospital-wide running sequence."); how settlements work ("Medibook collects the fee, keeps a 10% commission, and transfers the net to the hospital by the expected date… Walk-in payments are collected at the desk and kept 100% by the hospital."); can I export reports ("Yes — every report supports CSV and PDF export" — **[Observation]** PDF export is only a message in the code).
4. **Still need help?** Email Support `support@medibook.app` · Call Us `1800 200 4567` · Live Chat "Mon–Sat, 9am–7pm" (plain text, not links; note the login screen uses `support@medibook.in`).
5. **Raise a Ticket** → dialog "Raise a Support Ticket": **Topic** (Billing & settlements · Appointments & queue · Plan & subscription · Technical issue · Other) and **Describe the issue** (free text, optional), caption "Tickets go straight to the Medibook operations team — they appear in their console notifications.", buttons Cancel / **Send to Medibook**. Sending creates an open **Support** request in the Operations console inbox with the subject "<Topic> — <hospital name>" and shows "Ticket raised with Medibook support". No ticket number is shown and there is no list of the hospital's own tickets.


# 5. Operations Console (Medibook Super Admin) — Functional Specification (as built)

## 5.1 Access and navigation
1. Reached from the **Operations Login** tab. One identity exists: **Riya Sharma, Super Admin** (`riya.sharma@medibook.in`). **[Prototype-only]** Any valid email plus a non-blank password signs in. There is no per-screen permission check inside the console: the internal roles defined on its Users & Roles screen are descriptive only (§5.10).
2. **Sidebar** ("Medibook · Operations Console"): **Overview** (Dashboard) · **Network** (Hospitals, Subscription Plans) · **Finance** (Billing, Hospital Settlements) · **Insights** (Usage Analytics, Reports, Compliance Logs) · **Platform** (Users & Roles, Platform Users, Notifications) · **System** (Platform Settings).
3. **Top bar:** back arrow (session history), page title and subtitle, notification bell, account menu (Platform Settings, Log Out).
4. **Page titles and subtitles:** Operations Dashboard ("Platform performance and critical alerts across all hospital instances") · Hospital Management ("Onboard, monitor and manage every hospital instance on the platform") · Hospital Profile ("Instance health, plan and verification") · Subscription Plans ("Plan tiers, pricing and feature limits") · Billing ("Invoices and payment transactions across hospitals") · Invoice Detail ("Line items, taxes and payment attempts") · Payment Detail ("Transaction reference and status history") · Hospital Settlements ("Review and release pending settlements to hospitals") · Usage Analytics ("Booking and platform usage across all instances") · Reports ("Generate and download platform reports") · Compliance Logs ("Audit trail of every sensitive action on the platform") · Users & Roles ("Internal Medibook users and their access roles") · Platform Users ("Patient accounts from the Medibook mobile app") · Patient Account ("Read-only account view — access is logged") · Notifications ("Home-screen banners and push notifications in the Medibook patient app") · Platform Settings ("Platform-wide preferences and defaults").
5. **[Prototype-only]** Every screen change shows a grey loading skeleton for about half a second to simulate server latency, and most actions complete after a simulated 0.7-second delay followed by a green success message.
6. **Notification bell (operations):** lists every **open hospital request** (support ticket, plan-change request, settlement request) with the hospital name and date; every **critical alert** from the dashboard (danger alerts count as unread); and, when any settlement is awaiting release, "n settlements awaiting release — Next payout run: 20 Jun 2026" (fixed date). Clicking an item opens the related screen or hospital. There is no mark-as-read and no empty-state text.
7. **Demo clock.** The console's "today" is fixed at **13 June 2026**; every date it stamps (onboarding dates, request dates, received dates, banner schedules) uses that date. The hospital app, by contrast, uses relative labels and the real browser date. The backend must replace both with real server time in the Asia/Kolkata timezone.
8. **Tenant link.** The hospital app's data is joined to the console as hospital number **13 (Apollo Hospital)**. For that one hospital the console reads live data from the hospital app (name, GSTIN, bank details, departments, doctors, recent bookings, settlements); every other hospital in the console is fixed sample data.

## 5.2 Operations Dashboard

1. **KPI tiles (clickable):** **Total Hospitals** (live count of every hospital record, all statuses; caption "+2 this quarter" is fixed) → Hospitals · **Active Users** ("24,580 — Staff and admins across instances", fixed **[Prototype-only]**) → Platform Users · **Monthly Revenue** ("₹ 3.7L — subscriptions · +8.2% vs last month", fixed **[Prototype-only]**) → Billing · **Bookings Today** ("1,842 — −2.1% vs last week", fixed **[Prototype-only]**) → Usage Analytics.
2. **Booking Usage** ("Last 7 days"): a bar per weekday with fixed sample values (Mon 1,240 … Fri 1,842 … Sun 760) and a hover tooltip "n bookings" **[Prototype-only]**.
3. **Critical Alerts** ("n open"): each alert has a severity (danger or warning), a title, a sub-line and a target screen; clicking the text opens the target; **Resolve Now** deletes the alert ("Alert resolved"). Sample alerts: "Settlement failure — Lotus Heart Institute / UPI payout bounced twice" → Settlements; "Plan limit reached — Kaveri General / Booking quota at 98% of Starter plan" → that hospital; "Compliance log gap — Nirmal Ortho / No audit entries for 48 hrs" → Compliance Logs. Empty state: "No critical alerts. All instances healthy." **[Observation]** Nothing creates alerts; they are sample data only. The FRD expects dashboards to surface message-delivery and payment-callback failures and error rates — this is the natural home for them.
4. **Recent Hospital Onboardings** (link "View All"): the first five hospital records (newest onboarded first) with Hospital (name, admin email), Plan, Location, Onboarded date, Status and a view button.
5. **Hospital requests inbox.** Support tickets, plan-change requests and settlement requests raised by hospitals are stored as "requests" (Open/Closed) but **are not shown on the dashboard**; they appear only in the bell. Plan requests close when operations approves or declines any plan change for that hospital; settlement requests close when the statement is released; **support requests can never be closed** and there is no ticket screen **[Observation]**.

## 5.3 Hospitals (tenant management)

### 5.3.1 Hospital list
1. **KPI tiles:** Total Hospitals · Active Instances ("Live and serving bookings") · Pending Verification ("Awaiting document review") · Suspended ("Access paused by platform"). Sample: 13 hospitals — 7 active, 3 pending, 2 suspended, 1 rejected.
2. **Tabs:** All Hospitals | Pending verification (n). Button **Onboard Hospital**.
3. **Search** "Search hospital or city" (name or city); **filters** Plan (all plans in the catalogue, including hospital-specific ones) · Status (Active · Pending verification · Suspended · Rejected) · Clear all · a refresh icon that does nothing.
4. **Columns:** Hospital (name + admin email) · Plan · Location (city, state) · Bookings / Mo · Onboarded · Status · Action (view). Sortable; 6 per page; empty state "No results match your filters." with **Clear filters**.
5. Opening the Plans screen's "View Hospitals" pre-filters this list by plan.

### 5.3.2 Onboard Hospital dialog
1. Fields: **Hospital Name** (required — "Hospital name is required.") · **Admin Email** (required, format checked — "Enter a valid email address.") · **City** (required — "City is required.") · **Subscription Plan** (default Starter).
2. Note: "The hospital lands in Pending verification. KYC documents (registration, GST, licence, bank proof) are requested from the admin email and must all be submitted before approval."
3. **Onboard Hospital** → after the simulated delay: a new hospital record with status **Pending verification**, the four KYC documents marked Missing, a placeholder phone (+91 90000 00000), no state, zero bookings, onboarded today; message "<name> onboarded. KYC verification pending."; audit log "Hospital onboarded — <name>".
4. **[Observation]** No admin user or invitation is created, no email or KYC request is sent, no duplicate check exists, and no state/GSTIN/phone is captured. The FRD requires provisioning an initial Admin user and default settings at onboarding (see Section 10).

### 5.3.3 Hospital Profile (hub)
1. **Header:** name, status badge, "admin email · phone · city, state"; action buttons by status: Pending → **Reject** and **Approve & Go Live**; Rejected → **Re-review & Approve**; Active/Suspended → **Suspend Instance** / **Reactivate Instance** and **Manage Plan** (opens the plan catalogue; it does not change the hospital's plan directly).
2. **Tabs:** Overview · Departments · Doctors · Billing & Settlements · Activity.
3. **Overview tab:**
   1. Details: Admin Email · Phone · Location · Plan · Onboarded · Instance ID (derived "MB-HOSP-01nn") · GSTIN ("Not on file" when absent) · Payout Account (bank name and last four digits, or "Not added — hospital adds it in Hospital Settings") · IFSC · Settlement UPI · Rejection Reason (when rejected).
   2. **Verification & KYC:** four document tiles — Registration certificate · GST certificate · Medical licence · Bank account proof — each Missing ("Not received"), Submitted ("Received · awaiting review") or Verified ("Verified at approval"); a badge "Ready for review" or "Documents incomplete" while pending. **[Observation]** There is no way to upload, request or verify an individual document; documents only become Verified all at once on approval, so a hospital with a missing document can never be approved in the prototype.
   3. **KPI tiles:** Bookings This Month (the registry figure; for Apollo a fixed 3,120, not the live count) · Monthly Revenue (bookings × ₹45, an invented constant **[Prototype-only]**) · Active Staff (derived **[Prototype-only]**) · Booking Quota ("x% — n of limit bookings used"; orange at 90% or more; limit from the plan, default 1,500).
   4. **Recent Bookings:** five rows (Patient, Department, Date, Status) — live from the hospital app for Apollo ("Live from the hospital instance"), generated sample rows for every other hospital.
4. **Departments tab** (read-only): Department · Doctors · Base Fee · Working Hours · Status, with "n departments · n doctors on the roster". Live from Apollo's catalogue; generated for others.
5. **Doctors tab** (read-only): department filter; columns Doctor (name, specialty) · Department · Room · Fee · Rating · Availability ("n days/wk", "On leave <from> – <to>") · Status (Active / On Leave / Inactive).
6. **Billing & Settlements tab:** plan card ("<plan> · ₹x/mo", "n of limit monthly bookings used (x%)", **Plan Catalog**); Invoices (Invoice, Amount, Issued, Due, Status; "Open Billing"; empty "No invoices issued to this hospital yet."); Payment Transactions (Transaction, Invoice, Method, Amount, Date, Status); Settlements (Statement + period, Net Payable, Expected, Status + UTR; "Open Hospital Settlements"; empty "No settlement statements for this hospital yet."). For hospitals other than Apollo, net is recomputed from the commission rate in Platform Settings.
7. **Activity tab:** the last eight audit-log entries referencing this hospital (Action + actor, Module, Timestamp, Severity) with "Open Compliance Logs"; empty "No logged actions reference <name> yet. Approvals, suspensions and settlement releases will appear here."
8. **Lifecycle actions and dialogs:**
   1. **Approve** — allowed only when no KYC document is Missing; otherwise the message "Cannot approve — <documents> not received." Dialog "Approve this hospital?" / "<name> goes live immediately and can start taking bookings on Medibook." → status Active, all documents Verified, rejection reason cleared; message "<name> approved and live."; log "Hospital approved — <name>" (Info).
   2. **Reject** (Pending only) — dialog "Reject this hospital?" with a required **Reason for rejection**: Incomplete KYC documents · Invalid GST or licence details · Failed physical verification · Duplicate registration; text "<name> is notified by email and cannot take bookings. This decision is final." → status Rejected with the reason; message "<name> rejected. The hospital has been notified." (no email is sent **[Prototype-only]**); log "Hospital rejected — <name>" (Critical). **[Observation]** Despite "This decision is final", a rejected hospital can later be approved via Re-review & Approve.
   3. **Suspend** — "Suspend this hospital?" / "<name> staff lose access immediately. Existing bookings are kept, but no new bookings can be made until reactivation." → status Suspended; log (Critical). For Apollo this blocks the hospital login; nothing else is enforced.
   4. **Reactivate** — "Reactivate this hospital?" / "<name> regains access immediately and can take new bookings right away." → status Active; log (Critical).
9. **Not available:** editing hospital details, deleting a hospital, changing the plan directly, impersonating/logging in as the hospital, inviting or resetting the hospital admin, per-document KYC actions, quota alerts.

## 5.4 Subscription Plans

1. **Header:** "n plan tiers · standard plans are public; hospital-specific plans are negotiated per tenant"; button **Create Plan**.
2. **Plan cards:** name; pills "MOST POPULAR" (at most one plan) and "HOSPITAL-SPECIFIC"; price "/ month"; "n hospitals on this plan" or "No hospitals on this plan yet"; feature lines: "n bookings / month", staff accounts, support level, extra feature; buttons **View Hospitals**, edit, delete (blocked with the message "n hospital(s) are on this plan — move them to another plan first." when any hospital uses it).
3. **Sample catalogue:** Starter ₹9,999 · 1,500 bookings/month · Up to 25 staff accounts · Email support · Standard reports; Growth ₹24,999 · 5,000 · Up to 120 staff accounts · Priority support · Advanced analytics (Most Popular); Enterprise ₹49,999 · 8,000 · Unlimited staff accounts · Dedicated success manager · Custom integrations; Custom — Trinity Care ₹59,999 · 10,000 (hospital-specific).
4. **Create / Edit Plan dialog:** Standard | Hospital-specific toggle; **Mark as Most Popular** switch; Plan Name (required; "Plan name is required."; unique — "A plan with this name already exists."); Monthly Price (₹) (digits only, must be > 0 — "Enter a monthly price."); Bookings / Month (> 0 — "Enter a monthly booking quota."); Staff Accounts (Up to 25 / Up to 120 / Unlimited staff accounts); Support Level (Email support / Priority support / Dedicated success manager); Extra Feature Line (optional). Messages "Plan "<name>" created." / "Plan "<name>" updated."; logs "Plan created — <name>" / "Plan updated — <name>". Renaming a plan renames it on every hospital that uses it.
5. **Delete Plan** dialog: "Delete this plan?" / ""<name>" is removed from the catalog. No hospitals are on it, so nothing else changes." → "Plan deleted."; log "Plan deleted — <name>" (Critical).
6. **Recent Plan Changes** ("Last 30 days" is a label only): Hospital (name, email) · Plan Change ("Starter → Growth") · Requested date · Status (Pending / Completed / Cancelled) · Action: **Approve** / **Decline** for pending requests. Approve moves the hospital to the requested plan (if that plan still exists) and marks the request Completed; Decline marks it Cancelled; either outcome closes the hospital's open plan requests and clears the hospital's "requested" banner; messages "Plan change applied — <hospital> moved to <plan>." / "Plan change declined for <hospital>."; logs "Plan change applied/declined — <hospital>: <change>".
7. **Gap versus contract:** the FRD describes monthly/yearly plans with feature limits for doctors, branches, storage and message credits; the prototype has monthly plans limited by bookings, staff accounts and support level only. No plan history, effective date, proration or billing consequence exists.

## 5.5 Billing (subscription invoices and payments)

1. **KPI tiles (all fixed sample values [Prototype-only]):** Collected This Month ₹18.4L · Outstanding Dues ₹2.6L ("9 invoices open") · Invoices Issued 214 · Failed Payments 6.
2. **Tabs:** Invoices | Payments (the tab can be pre-selected by link). Search "Search invoice or hospital" / "Search transaction, invoice or hospital"; date range (issued dates / paid dates); Method filter (UPI / Card / NetBanking) on Payments; Status filter (Invoices: Completed · Pending · Overdue · Payment failed; Payments: Success · Pending · Payment failed); Clear all; inert refresh icon. 6 rows per page.
3. **Invoices table:** Invoice (number "INV-YYYY-NNNN" + hospital) · Amount · Issued · Due · Status · Action (view; **Download PDF** → only the message "Invoice <no> downloaded." **[Prototype-only]**). Sample: 15 invoices, amounts equal to the plan prices (GST-inclusive), due 14 days after issue.
4. **Payments table:** Transaction ("TXN-NNNNN" + hospital) · Invoice · Method (UPI / Card / NetBanking) · Amount · Date · Status · Action (view). Sample: 11 transactions.
5. **Invoice Detail:** header (number, status, "hospital · Issued · Due", **View Hospital**, **Download PDF** stub); details Hospital · Billing Period (fixed "June 01 – June 30, 2026" for every invoice **[Prototype-only]**) · Plan (the hospital's current plan, not the plan at invoice time **[Observation]**) · Issued · Due · Amount · Hospital GSTIN · Medibook GSTIN (from Platform Settings) · Tax Treatment "18% GST (9% CGST + 9% SGST)"; one line item "<plan> Plan — Monthly subscription" with Subtotal, CGST (9%), SGST (9%), Total (the amount is treated as GST-inclusive; independent rounding can make the lines exceed the total by ₹1 **[Observation]**); Payment Attempts (Transaction, Method, Date, Status; empty "No payment attempts yet.").
6. **Payment Detail:** header (transaction, status, "hospital · method · date", **View Hospital**, **View Invoice**); details Amount · Method · Reference · Gateway Ref (derived **[Prototype-only]**) · Date · Linked Invoice; a Status History timeline synthesised from the status (Payment initiated → Authorized by gateway → Captured / Awaiting confirmation / Payment failed — declined by bank).
7. **[Observation]** No billing action exists at all: no invoice generation, reminders, mark-as-paid, void, retry, refund, grace period or auto-suspension. The FRD requires invoice/payment review, grace periods and auto-suspend for non-payment (see Section 10).

## 5.6 Hospital Settlements (payouts to hospitals)

### 5.6.1 Business context as stated on screen
1. Tooltip: "Online booking fees are collected by Medibook at booking time and become payable to the hospital only after the appointment is completed. Pre-visit cancellations are refunded per the slab policy — Medibook keeps the cancellation fee. Statements are net of the 10% platform commission (set in Platform Settings). Transfers themselves happen outside Medibook — releases here are the shared record of them."
2. So the console does not move money; it **records** bank transfers made outside the system, and that record is visible to the hospital immediately. This is consistent with the FRD statement that settlements happen outside the application, but the recording workflow itself goes beyond "helper reports" (see Section 10).

### 5.6.2 What you see
1. **KPI tiles:** **Payable Now** (sum of net for every Pending or Overdue statement; "n statements pending release") · **Held in Advance** (₹4.2L, fixed; "upcoming bookings · payable after completion") · **Released This Month** (₹9.8L, fixed) · **Platform Earnings** (₹1.1L, fixed; "10% commission + cancellation fees") **[Prototype-only for the three fixed values]**.
2. **Toolbar:** view toggle **By Payout Run | Flat List**; Hospital filter (all hospitals with statements); Status filter (Pending · Released · Received · Overdue · Payout failed); Expected-from / Expected-to dates; Clear all; caption "<Weekly> payout runs · next: 20 Jun 2026" (the cadence word comes from Platform Settings; the date is fixed).
3. **Settlement Queue** with "n statements match".
4. **By Payout Run view:** statements are grouped by expected date into "Payout run · <date>" cards ("n statements · net ₹x", plus "k not releasable (no payout account)"); a run whose date is on or before today is marked "— due"; a **Release Run (n · ₹x)** button when at least one statement can be released; a table per run: Statement (hospital, number · period, remark) · Gross · Commission (10%) · Net Payable ("released ₹x" when partial) · Status (UTR beneath; "Requested by hospital" when the hospital asked) · Action.
5. **Flat List view:** the same columns plus Expected date, sortable, 7 per page ("statements").
6. **Row actions:** Pending or Overdue → **Release**; Payout failed → **Retry**; Released → "Awaiting hospital confirmation"; Received → tick and date.
7. **Sample queue:** 22 statements across nine hospitals (the 14 Apollo statements plus 8 others), for example Meridian City Hospital MB-ST-2408 gross ₹1,86,000 net ₹1,67,400 Pending; Sunrise Multispeciality MB-ST-2410 Released with a partial release of ₹80,000 and the remark "Part release — balance held pending dispute #418."; Charak Institute MB-ST-2413 Payout failed; Kaveri General MB-ST-2415 Pending with no payout account.

### 5.6.3 Rules (as implemented)
1. A statement can be released when its status is Pending or Overdue **and** the hospital has a payout account on file; otherwise the message "No payout account on file for <hospital> — the hospital adds it under Hospital Settings." (The Retry path for failed payouts skips this check **[Observation]**.)
2. Commission for non-Apollo statements is computed live from the **Platform Commission (%)** setting (default 10); Apollo's statements keep the 10% stored in the hospital ledger, so changing the platform rate re-prices some rows and not others **[Observation]**. The rate must be snapshotted per statement in the backend.
3. Payout runs are buckets by expected date, not by statement period; a run is "due" when its date is on or before the demo date 13 June 2026.
4. **Record Settlement Release dialog:** shows Statement, Hospital, Period, Net Payable, Destination (bank and last four digits); note "The transfer itself happens outside Medibook (bank / NEFT / UPI). This records it on the shared ledger — the reference and remark are visible to the hospital."; fields **Amount Released (₹)** (required, digits only, must be greater than zero; pre-filled with the net; no upper limit) · **Transfer Reference (UTR)** (required, pre-filled "UTR26-<last four>R"; no format check) · **Remark (visible to the hospital)** (optional). **Record Release** → status Released, UTR/amount/remark stored, any hospital request for this statement closed; message "Release recorded — visible to <hospital>."; audit log "Settlement release recorded — <statement> · ₹x to <hospital>". A partial amount still sets the status to Released and no balance is tracked **[Observation]**. There is no release-date field.
5. **Record Run Release dialog:** lists every releasable statement in the run with hospital, number, destination and UTR, "Total to release ₹x", a warning "Skipped — no payout account on file: <hospitals>. Release them individually once the hospital adds bank details.", and a **Remark for this run (optional · visible to every hospital in it)**. **Record n Release(s)** releases each statement for its full net with an auto-generated UTR; message "Payout run recorded — n settlement(s) released."; one audit log "Payout run recorded — <date> · n statements · ₹x".
6. **Not implemented:** creation of statements, the Pending → Overdue transition, the Payout failed state (seed only), payout-gateway integration, statement PDF/export on the console side, a settlement-request list (requests are visible only in the bell and as a "Requested by hospital" caption).

## 5.7 Usage Analytics
1. **KPI tiles (fixed sample values [Prototype-only]):** Total Bookings 48,240 · Avg Daily Bookings 1,608 · Booking Success Rate 94.2% ("Completed vs total bookings") · Cancellation Rate 3.1%.
2. **Bookings by Month** ("Last 12 months"): twelve bars with hover tooltips; fixed values.
3. **Department Split:** seven percentage bars — Cardiology 24%, General Medicine 19%, Orthopaedics 16%, Paediatrics 12%, Gynaecology 9%, ENT 7%, Others 13%; fixed values.
4. **Top Hospitals by Usage** (link "View All" → Hospitals): six hospitals with booking counts and bars; fixed values matching the registry.
5. There are no period filters, hospital filters or refresh. **Gap versus contract:** the FRD asks for tenant, active-user, booking, revenue, provider-usage and error-rate dashboards; all analytics must be computed server-side.

## 5.8 Reports (console)
1. Six report cards, each with a description, "Last generated <date>" and a **Download CSV** button:
   1. **Revenue Report** — "Platform revenue by hospital, plan and period."
   2. **Bookings Report** — "All bookings with department and outcome detail."
   3. **Onboarding Report** — "Hospital onboarding funnel and KYC status."
   4. **Settlement Statement** — "Payout history with commission breakdown."
   5. **Compliance Audit** — "Full audit trail of sensitive platform actions."
   6. **Platform Users Report** — "Registered end users, activity and growth."
2. **Download CSV** shows "Preparing…" for a moment, stamps "Last generated just now" and shows "<Report> ready." — **no file is produced**, no parameters are collected and no audit entry is written **[Prototype-only]**. The FRD's "settlement helper reports built to the UI/UX template" and "data export on request" therefore have no working implementation.

## 5.9 Compliance Logs (audit trail)
1. **Toolbar:** search "Search action or user" (action text or actor); Severity filter (Info · Warning · Critical); Module filter (Hospitals · Settlements · Billing · Subscription Plans · Users & Roles · Platform Users · Reports · Settings · Auth · Media — note "Notifications" is missing although notification actions are logged **[Observation]**); From/To dates; Clear all; caption "Retention: 365 days" (text only); inert refresh icon.
2. **Columns:** Action (with the actor beneath) · Module · IP Address · Timestamp · Severity (Info blue, Warning amber, Critical red). Sortable except Action; 7 per page ("log entries"); empty state "No results match your filters."; no hospital column, no detail view, no export.
3. **Sample entries** illustrate intended event types: "Hospital suspended — Nirmal Ortho & Spine" (Critical), "Settlement released — ₹ 1,28,250", "Role permissions changed — Finance Admin" (Critical), "Failed login attempt (3x)" (Auth, Warning), "Invoice regenerated — INV-2026-0234", "Platform user deleted — dev.trivedi@gmail.com" (Critical), "Data export — bookings FY 2025-26" (Warning), "Media purged — 214 orphaned files" (system), "API key rotated — payments gateway", "Settings updated — payout schedule".
4. **Events actually written by the prototype** (all with the fixed actor riya.sharma@medibook.in, IP 10.42.8.11 and time "Just now" **[Prototype-only]**): the 23 event templates in Appendix C — hospital onboarded/approved/rejected/suspended/reactivated; plan created/updated/deleted; plan change applied/declined; platform settings updated; banner added/updated/deleted/paused/resumed and default banner updated; push sent/scheduled/cancelled; patient account viewed/blocked/unblocked; settlement release recorded; payout run recorded.
5. **Sensitive actions not logged today:** API-key rotation, report downloads, invoice downloads, internal user add/delete, alert resolution, every hospital-side action (mark received, requests, settings and bank changes), login/logout. The FRD requires access logs, configuration-change logs, booking state transitions and outbound-message attempts (see Section 10).

## 5.10 Users & Roles (internal Medibook staff)

1. **KPI tiles (live counts):** Super Admins ("Full platform control") · Finance Admins ("Billing and settlements") · Support ("Hospital assistance") · Auditors ("Read-only compliance access"). Sample: 2 · 2 · 2 · 1.
2. **Search** "Search name, email or role"; button **Add User**.
3. **Users table:** User (avatar, name, email) · Role · 2FA (Enabled / Pending) · Last Active (fixed text **[Prototype-only]**) · Status (Active / Pending / Suspended) · Action (edit → "Edit user — demo" **[Prototype-only]**; delete). No sorting, filtering or paging. Empty state "No results match your search."
4. **Sample staff:** Riya Sharma and Anil Kapoor (Super Admin); Meera Pillai and Nisha Verma (Finance Admin; Nisha Pending/2FA pending); Dev Trivedi and Kavya Reddy (Support; Kavya Suspended, 2FA pending); Sameer Joshi (Auditor). All `@medibook.in`.
5. **Add User dialog:** Full Name (required — "Full name is required.") · Work Email (required, format checked — "Enter a valid email address."; no domain or uniqueness rule) · Role (Super Admin / Finance Admin / Support / Auditor; default Support) with a live description of what the role can and cannot do; note "An invite email is sent. The account stays Pending until they set a password and enable 2FA." → the user is created with status Pending and 2FA Pending; message "<name> added." **[Prototype-only]** No invitation is sent and there is no way for the account to become Active.
6. **Delete user:** "Delete this user?" / "This permanently removes <name> and their access. You won't be able to recover it later." → "User deleted." **[Observation]** No safeguards (the signed-in user or the last Super Admin can be deleted) and no audit entry is written.
7. **Role Permissions** (read-only reference; caption: "Roles are fixed platform profiles — assign the narrowest one that covers the job. Patient account detail requires its own permission, separate from the account list. Every detail view is written to Compliance Logs."):
   1. **Super Admin** — "Full platform control." Can: Hospitals, KYC & suspension; Plans, billing, settlements & payout runs; Patient accounts including detail views; Notifications, logs, users & platform settings.
   2. **Finance Admin** — "Money operations only." Can: Subscription billing & invoices; Settlement releases & payout runs. No access: Hospital management & KYC; Patient accounts; Platform settings.
   3. **Support** — "Front line for hospital assistance." Can: Hospitals & their requests (view); Patient account list — not detail; App banners & push notifications. No access: Billing & settlements; Platform settings.
   4. **Auditor** — "Read-only compliance access." Can: Compliance logs & audit trail. No access: Everything else — no write access anywhere.
   5. **Permission matrix:** Manage hospitals & verification (Super Admin only) · Billing & settlements (Super Admin, Finance Admin) · App banners & push notifications (Super Admin, Support) · View patient accounts (list) (Super Admin, Support) · View patient account detail (Super Admin only) · View compliance logs (Super Admin, Auditor) · Manage settings (Super Admin only).
8. **[Observation]** The console has a single technical role; none of the above is enforced anywhere. The backend must enforce it per endpoint.

## 5.11 Platform Users (patient accounts from the mobile app)

1. **KPI tiles (fixed sample values [Prototype-only]):** Registered Users 2,41,300 · Monthly Active 86,400 · New This Week 4,120 · Blocked Accounts 214 ("Fraud or abuse reports").
2. **Search** "Search user, email or city"; Status filter (Active / Blocked); Clear all; inert refresh icon.
3. **Columns:** User (avatar, name, email) · Phone · City · Bookings · Joined · Status (Active green / Blocked grey) · Action (eye "View account (logged)"). Sortable; 6 per page; empty state "No results match your filters."
4. **Opening an account** writes the audit entry "Patient account viewed — <email>" (Info) and opens the detail page. **[Observation]** The entry is written by the list click only; opening the page by direct link or browser back is not logged.
5. **Patient Account (detail; "Read-only account view — access is logged"):** header (avatar, name, status, "phone · email · city") with **Block Account** (red) or **Unblock Account**; details Name · Mobile · Email · Registered · Status · City; **Family Members** (Name · Relationship · Age · Gender; empty "No family members added to this account."); **Booking History** ("Read-only · no clinical data": Hospital · Department · Date · Status; empty "No bookings made from this account yet.").
6. **Block / Unblock dialogs:** "Block this account?" / "Existing upcoming bookings are unaffected. <name> cannot make new bookings until unblocked." → **Block**; "Unblock this account?" / "<name> can make new bookings again immediately." → **Unblock**. Messages "<name> blocked." / "<name> unblocked."; audit "Patient account blocked/unblocked — <email>" (Critical). No reason is captured and nothing enforces the block in the mobile app **[Observation]**.
7. **Sample accounts:** eight patients (for example Aarav Mehta, Mumbai, 12 bookings, three family members — Spouse, Son, Father; Meera Nair, Kochi, Blocked; Farhan Sheikh, Pune, Blocked). Family relationships seen: Spouse, Son, Daughter, Father, Mother.
8. **Not available:** export, delete or anonymise an account, PII masking, contacting the patient, linking a booking to the hospital record (hospital names are plain text). The FRD's OTP-gated account deletion and data-export-on-request have no console counterpart.

## 5.12 Notifications (patient-app banners and push)

### 5.12.1 App Banners tab
1. **Showing now:** "Showing in the app right now: “<title>”" (the first Live banner in order) or "…default banner — “<title>”"; caption "Live banners rotate on the patient app home screen in the order below. When none is live, the default banner shows."
2. **Default Banner:** a single always-on banner ("Always on — shown whenever no campaign banner is live. Cannot be deleted."; sample "Book trusted doctors near you — Medibook") with **Edit**.
3. **Campaign Banners** ("Order sets rotation priority in the app — use the arrows. Pause takes a banner out of rotation without losing its schedule. Expired banners stay here for reference until deleted."; "n live · n total"): each row has move up/down arrows, a rank, a thumbnail, the title and date range, a state badge — **Live** (green), **Scheduled** (blue), **Paused** (grey), **Expired** (grey) — a **Pause/Resume** button (hidden when expired), edit and delete.
4. **State rule (as implemented):** Paused if switched off; otherwise Expired when the end date is before today, Scheduled when the start date is after today, else Live (both dates inclusive). "Today" is the fixed demo date **[Prototype-only]**. A paused banner past its dates still shows Paused **[Observation]**.
5. **Sample banners:** "Monsoon Health Camp — full-body checkups at 20% off" (10–24 Jun 2026, Live); "Free tele-consult week with top cardiologists" (15–22 Jun, Scheduled); "World Yoga Day — wellness packages near you" (18–21 Jun, Paused); "Summer vaccination drive for kids" (20 May–5 Jun, Expired).
6. **Add / Edit Banner dialog:** Banner Title (required — "Give the banner a title.") · Banner Image (optional; "PNG or JPG · 1200×600 (2:1) recommended · title shows as overlay text if no image"; kept in browser memory only **[Prototype-only]**; no size or format enforcement) · Live From (required — "Set a start date.") · Live Until (required, on or after the start — "Set an end date on or after the start."). Messages "Banner added — it goes live on its start date." / "Banner updated." / "Default banner saved."; audit "App banner added/updated — <title>", "Default app banner updated". New banners are appended with the lowest priority and are active.
7. **Pause/Resume** flips the banner immediately (audit "App banner paused/resumed — <title>"). **Delete:** "Delete this banner?" / "“<title>” is removed from the app immediately. This cannot be undone." → "Banner deleted." (audit, Warning).
8. **[Observation]** The mobile app has its own two fixed banners and no connection to this manager (see §3.3); the contract's "configurable banners" require an API and image hosting.

### 5.12.2 Push Notifications tab
1. **Compose Push Notification** ("Delivered to the Medibook patient app on the chosen devices. Booking and queue updates are sent automatically by the system — this composer is for offers and announcements only."): Title (required, maximum 40 characters — "Add a title.") · Message (required, maximum 120 characters — "Add a message.") · Audience (All users ~2,41,300 · Android only ~1,48,200 · iOS only ~93,100 · Inactive 30+ days ~38,400; reach figures fixed **[Prototype-only]**) · Timing (Send now | Schedule; scheduled sends always go at 09:00 on the chosen date — "Pick a date." when missing; no past-date check).
2. **Confirmation:** "Send this notification now?" / "Schedule this notification?" — "“<title>” goes to <audience> (~n users)[ on <date> at 09:00]. Push notifications can't be recalled after delivery." → **Send Now** / **Schedule**. Outcome: a **Queued** or **Scheduled** entry; messages "Notification queued for delivery." / "Notification scheduled."; audit "Push notification sent/scheduled — “<title>” to <audience>" (Warning).
3. **Sent & Scheduled table:** Notification (title, message) · Audience · When · Delivered · Open Rate · Status (Sent green / Scheduled blue / Queued blue / Cancelled red) · **Cancel** (Scheduled entries only; immediate; "Scheduled notification cancelled."; audit Info).
4. **Sample:** "20% off health checkups" (All users, Sent, 2,28,400 delivered, 18% opened); "Live queue updates are here" (Android only, Sent, 1,41,050, 22%); "Father's Day heart camp" (All users, Scheduled 21 Jun 2026 09:00).
5. **[Observation]** No push provider is integrated; nothing ever moves Queued or Scheduled to Sent; the mobile app has no push capability. Booking/queue notifications "sent automatically by the system" do not exist anywhere.

## 5.13 Platform Settings

1. **Organisation:** Platform Name (Medibook) · Support Email (format checked — "Enter a valid email address."; sample support@medibook.in) · Helpline Number (1800 220 440).
2. **Payouts & Billing:** Payout Schedule (Weekly / Fortnightly / Monthly; default Weekly) · Platform Commission (%) (0–100 — "Enter a value between 0 and 100."; default 10) · GST Number (the platform's 15-character GSTIN — "GST number must be 15 characters."; default 27AABCM9407L1ZK). **[Observation]** This is a GSTIN, not a tax rate; the invoice tax rate (9% CGST + 9% SGST) is fixed in code.
3. **Notifications:** Settlement alerts ("Notify when a payout fails or is on hold.", on) · Compliance alerts ("Notify on critical audit events in real time.", on) · Weekly digest ("Platform summary every Monday at 09:00.", off).
4. **Security:** Require 2FA for all admins ("Admins without 2FA are prompted at next sign-in.", on) · Session Timeout (15 / 30 / 60 min; default 30) · API Key (masked `mb_live_9f42••••••••7d1c`) with **Rotate Key** → only the message "API key rotated. Update your gateway config." **[Prototype-only]**.
5. **Footer:** "Unsaved changes" / "All changes saved" status; **Discard**; **Save Changes** → "Settings saved."; audit "Settings updated — platform preferences".
6. **Which settings have an effect today:** the commission rate is used to compute commission and net for non-Apollo statements on the Hospital Settlements and Hospital Profile screens; the payout schedule only changes a caption; the GSTIN prints on invoices. Organisation fields, notification toggles, 2FA requirement and session timeout are stored but never read **[Observation]**.


# 6. Business Rules Catalogue (consolidated)

Every rule below was read from the code. **Status** tells the backend team how far the rule is real today: **Implemented** (the prototype enforces it), **Copy only** (stated on screen but not enforced), **Setting only** (configurable in a settings screen but read by nothing), **Sample only** (visible in sample data but no logic produces it), **Absent** (required by the contract, nothing in the UI). Rules marked Copy/Setting/Sample/Absent must be implemented server-side.

## 6.1 Identity, access and sessions
1. **BR-001** Patient login is by email and password; sign-up captures full name, email, phone, password and acceptance of terms. — Implemented (format checks only). *Contract asks for mobile number + password with OTP activation.*
2. **BR-002** Passwords must be at least 6 characters; confirmation must match exactly. — Implemented (client only).
3. **BR-003** OTP is 4 digits, entered one per box. — Implemented; expiry, resend cooldown, attempt limit and lockout — Absent.
4. **BR-004** Hospital staff log in with email and password; a suspended hospital cannot log in ("This hospital's Medibook instance is suspended by operations…"). — Implemented (suspension gate only; no credential check).
5. **BR-005** Receptionists cannot open admin-only views (Settlements, Doctors & Departments, Users & Roles, Reports, Hospital Settings); attempts redirect to their dashboard. — Implemented by URL role.
6. **BR-006** Custom hospital roles carry view/add/edit/delete permissions per module (Dashboard, Appointments, Patients, Token Management, Payments, Billing & Settlements, Doctors & Departments, Reports, Hospital Settings, Users & Roles); the Administrator role always has full access and cannot be edited; a role must have a name. — Data captured; enforcement Absent.
7. **BR-007** New hospital users start Active with invite status Pending (email invite / mobile OTP) or Accepted (password set now); username defaults to the email's local part. — Implemented (no invite is sent).
8. **BR-008** Internal Medibook staff have one of four fixed roles (Super Admin, Finance Admin, Support, Auditor) with the permission matrix in §5.10; new staff start Pending with 2FA Pending. — Data captured; enforcement Absent.
9. **BR-009** Platform-wide security settings: require 2FA for all admins; session timeout 15/30/60 minutes. — Setting only.
10. **BR-010** Sessions are not remembered ("Sessions aren't remembered — sign in each time" on the operations tab; "Remember me" on the hospital tab). — Prototype only; production session policy Absent.
11. **BR-011** Every screen of every application must be tenant-scoped (hospital records join on the tenant id, never on the display name). — Design intent (constant tenant 13); Absent.

## 6.2 Catalogue: hospitals, departments, doctors
1. **BR-020** Hospital profile fields: name, registration number, GSTIN, phone, email, about, logo, gallery photos, address, latitude/longitude with a map pin, bank/payout details (account holder, bank, account number, IFSC, UPI). — Implemented as a form; validation Absent.
2. **BR-021** Hospital working hours: default open/close times (7–9 am / 6–10 pm options) and open days Monday–Sunday. Department and doctor hours override hospital hours ("the app uses the most specific: Doctor → Department → Hospital"). — Setting only.
3. **BR-022** Departments have a name (required), base consultation fee, description, image, weekly hours grid, Active/Inactive status. — Implemented (hours grid edits are discarded).
4. **BR-023** Doctors have a name (required), one or more departments (at least one required), specialisation, room, phone, email, qualification, experience, registration number, photo, bio, consultation fee (overrides the department fee), status Active / On Leave / Inactive, weekly hours, leave periods, ratings and reviews (read-only, from patients). — Implemented as a form; leave add/remove, hours persistence, availability settings Absent.
5. **BR-024** Doctor status semantics: Active = live and bookable; On Leave = visible, booking paused; Inactive = hidden from the patient app. — Copy only.
6. **BR-025** Booking uses a fixed roster of six departments and seven doctors with per-department fees (Cardiology ₹800, Orthopedics ₹700, Pediatrics ₹600, Neurology ₹1,000, ENT ₹500, Dermatology ₹650; fallback ₹600) and rooms. — Implemented as constants; must become the catalogue.
7. **BR-026** Deleting or deactivating a department has no effect on its doctors; deleting a doctor leaves past appointments intact. — Implemented (as a gap: cascade rules Absent).

## 6.3 Slots, availability and booking
1. **BR-030** Patient app booking window: today plus the next four days; six fixed slots (09:00 AM, 10:00 AM, 11:30 AM, 12:15 PM, 02:00 PM, 04:30 PM); no slot is ever unavailable. — Implemented (as a placeholder).
2. **BR-031** Desk booking slots: 10 fixed half-hour slots 9:00 am–12:00 pm plus 2:00, 3:00, 4:00 pm (Edit/Reschedule also offer 5:00 pm); date today or later, no upper limit. — Implemented (as a placeholder).
3. **BR-032** Slot generation from doctor/department/hospital hours, consultation duration (10/15/20/30 min), buffer (0–15 min), max appointments per slot (5–20), online booking on/off. — Setting only.
4. **BR-033** Doctor daily capacity hint: 16 bookings per doctor per day; amber above 75%, red at capacity or when the doctor is on a break; advisory, never blocks. — Implemented.
5. **BR-034** Booking defaults in the patient app: patient = self, date = today, time = 10:00 AM; changing the department clears the doctor; a doctor is chosen only from the Doctor Details screen. — Implemented.
6. **BR-035** One desk booking can contain several consultations (different doctors, same date/time) for one patient with one combined payment and one token per consultation. — Implemented.
7. **BR-036** Slot hold during payment with expiry on failure/timeout; optimistic locking and unique constraints to prevent double booking; hold token allowed with a 15/30/45-minute timeout. — Setting only / Absent.
8. **BR-037** "Pay at Hospital" as a per-hospital option with a confirmation window at the counter. — Absent (the mobile prototype behaves as if every booking is paid at the desk).
9. **BR-038** A new desk patient receives a generated MR number ("AP" + running number); patients are created only through booking. — Implemented.

## 6.4 Tokens and queue
1. **BR-040** mbAdmin tokens are hospital-wide, sequential, three-digit ("T-001"), never reset and never reused; issued when an online booking for today is created, when a walk-in payment is recorded, or at check-in. — Implemented.
2. **BR-041** Mobile tokens are app-wide, sequential ("A-26" onwards), issued at confirmation, never reused. — Implemented (placeholder).
3. **BR-042** Contract rule: sequential token per doctor per date, assigned on payment success. — Absent (a per-department prefix scheme C/O/P/N/E/D exists unused).
4. **BR-043** Queue membership: today's tokened appointments for that doctor that are not Completed/Cancelled/No-show and not currently being served; order = never-skipped first in token order, then skipped in skip order. — Implemented.
5. **BR-044** Call Next marks the patient In Queue, records the call time and sets the doctor Consulting; Done marks Completed; Skip sends the patient to the back; consultation longer than 20 minutes is highlighted. — Implemented.
6. **BR-045** Token queue settings: token generation Auto/Manual; show token to patient; grace period 15/30/45 min; after grace Auto Mark No-show / Keep waiting; auto no-show after 30 min / 1 h / 2 h. — Setting only.
7. **BR-046** Patient-facing live queue: current token, last called number, estimated wait, refresh indicator. — Absent (the mobile card shows only the patient's own token).

## 6.5 Payments, fees, receipts and refunds
1. **BR-050** Fee = the department's fee at creation; re-priced when the department is edited even if already paid (with the warning "Fee changed after payment — settle the difference at the desk."). — Implemented.
2. **BR-051** Online bookings are created Paid (prepaid in the app); walk-ins are created Pending and become Paid only when the desk records Cash/UPI/Card with an optional reference. — Implemented.
3. **BR-052** Payments with no recorded mode are treated as Cash in every total. — Implemented.
4. **BR-053** Receipt number = "RCPT-" + last five characters of the MR number + "-" + day of month; generated at display time, not stored, not unique. — Implemented (must be replaced by a server-side receipt series).
5. **BR-054** Receipts and token slips print the hospital name "Apollo Hospital" and logo regardless of settings; receipts contain one line item and no tax. — Implemented (placeholder).
6. **BR-055** Fee components before payment: consultation fee, taxes, convenience fee, coupons; GST details on receipts. — Absent.
7. **BR-056** Desk refund: full fee, only when cancelling a paid walk-in, recorded as Refunded via Desk. Online refunds are handled by Medibook "per its slab policy" and the appointment stays Paid. — Implemented / Copy only.
8. **BR-057** Cancellation window: patient cancellation allowed/not allowed; cut-off 1/2/4/24 hours before; reschedule "up to 2 hours before your slot". — Setting only / Copy only.
9. **BR-058** Default OP consultation fee (₹500), fee validity in days (10), apply to all departments. — Setting only.
10. **BR-059** Reinstating a cancelled walk-in whose payment was refunded offers a token without re-collecting payment. — Implemented (defect; rule Absent).

## 6.6 Commission, settlements and payouts
1. **BR-060** Platform commission = 10% of gross online fees (Platform Settings, 0–100%); commission = round(gross × rate); net = gross − commission. — Implemented for non-Apollo statements; Apollo statements carry a stored 10%.
2. **BR-061** Statements are weekly (sample: Wednesday–Tuesday), numbered platform-wide "MB-ST-####", with an expected date four days after the period ends; fees become payable only after the appointment is completed. — Sample only / Copy only.
3. **BR-062** A statement whose expected date has passed without release is Overdue; a failed bank transfer is Payout failed and "Medibook is retrying". — Sample only.
4. **BR-063** Release requires status Pending or Overdue and a payout account on file; a release records amount (>0), UTR (required) and remark; a payout run releases every eligible statement with the same expected date for its full net. — Implemented.
5. **BR-064** The hospital confirms receipt (Released → Received, dated) and can request release of a pending statement or raise a follow-up on an overdue one; requests close when the statement is released. — Implemented.
6. **BR-065** Partial releases are allowed with no outstanding-balance tracking. — Implemented (as a gap).
7. **BR-066** Payout schedule Weekly / Fortnightly / Monthly; "next payout run" date. — Setting only / fixed text.
8. **BR-067** Walk-in revenue is kept 100% by the hospital and never appears in settlements. — Copy only (consistent).
9. **BR-068** Contract: settlements are performed outside the application; the app provides helper reports. — Conflicts with BR-063/064 (Section 10.3).

## 6.7 Subscription plans and billing
1. **BR-070** Plan attributes: name (unique), monthly price (>0), bookings per month (>0), staff-account tier, support tier, extra feature line, Most Popular (at most one), hospital-specific flag. — Implemented.
2. **BR-071** A plan used by any hospital cannot be deleted; renaming a plan renames it on every hospital. — Implemented.
3. **BR-072** Quota = online bookings in the calendar month; walk-ins excluded; resets on the 1st; warning colour above 85% (hospital) / 90% (console); "Plan quota low" alerts. — Copy only / fixed values.
4. **BR-073** Invoices: monthly, on the 1st, due in 14 days, amount = plan price GST-inclusive, 9% CGST + 9% SGST, Medibook GSTIN on the invoice; statuses Completed / Pending / Overdue / Payment failed; payments UPI / Card / NetBanking with Success / Pending / Payment failed. — Sample only.
5. **BR-074** Grace period and auto-suspension for non-payment; reminders; retry. — Absent.
6. **BR-075** Plan change: the hospital requests a target plan; Medibook approves (plan applied if it still exists) or declines; the hospital is not notified. — Implemented.
7. **BR-076** Contract plan limits: doctors, branches, storage, message credits; monthly or yearly billing. — Absent.

## 6.8 Hospital lifecycle and verification
1. **BR-080** New hospitals start Pending verification with four KYC documents Missing; approval requires none Missing; approval verifies all documents; rejection needs a reason (Incomplete KYC documents / Invalid GST or licence details / Failed physical verification / Duplicate registration); active hospitals can be suspended and reactivated; a rejected hospital can be re-reviewed and approved. — Implemented.
2. **BR-081** Suspension: staff lose access immediately, existing bookings kept, no new bookings. — Implemented for login only; the rest Copy only.
3. **BR-082** Onboarding provisions an initial Admin user and default settings, and requests KYC documents by email. — Copy only / Absent.
4. **BR-083** Hospital instance ID "MB-HOSP-01nn" is derived from the record number. — Implemented (placeholder).

## 6.9 Notifications and communications
1. **BR-090** Booking confirmation, reminders (day before and day of), reschedule and cancellation notices over in-app, push and WhatsApp with hospital, department, doctor, date/time, token and location link; retry on failure; unread messages stay in the notification centre. — Absent (four fixed sample notifications in the app; toggles in hospital settings are Setting only).
2. **BR-091** Banners: a default always-on banner plus scheduled campaign banners (title, image, live-from, live-until ≥ from), state Paused → Expired → Scheduled → Live, ordered by priority, paused banners leave rotation. — Implemented in the console; not consumed by the app.
3. **BR-092** Push campaigns: title ≤ 40 characters, message ≤ 120, audience (All users / Android only / iOS only / Inactive 30+ days), send now or scheduled at 09:00 on a date; scheduled pushes can be cancelled; "can't be recalled after delivery". — Implemented in the console; delivery Absent.
4. **BR-093** Hospital-triggered confirmations/reminders, message templates with placeholders, hospital-published announcement banners. — Absent.
5. **BR-094** Support tickets from hospitals carry a topic and description and appear in the console; ticket lifecycle. — Implemented (creation only); closure Absent.

## 6.10 Data, privacy and audit
1. **BR-100** Hospital patient records hold identity and contact only — no clinical data ("Medibook stores identity & contact only — no clinical data"; "Read-only · no clinical data"). — Implemented principle.
2. **BR-101** Every view of a patient account by Medibook staff is written to the compliance log; blocks/unblocks are Critical events. — Implemented (client-side).
3. **BR-102** The compliance log records actor, module, IP, timestamp and severity (Info / Warning / Critical) with 365-day retention. — Partially implemented (fixed actor/IP/time; retention text only).
4. **BR-103** Blood-donation contact consent on the patient profile ("Hospitals can contact you for rare blood needs."), default on. — Implemented (not persisted).
5. **BR-104** Account deletion is OTP-gated and follows a retention policy; data export on request. — Absent.
6. **BR-105** Files (documents, receipts, token cards, images) are served from secure storage with expiring links. — Absent.

## 6.11 Prototype behaviours that must not ship (DEMO)
1. **DEMO-01** Pre-filled credentials on all logins; any valid email plus any password signs in; fixed OTP 1234 disclosed in the error message.
2. **DEMO-02** The operations console's "today" is 13 June 2026; the hospital app stores relative date labels; the mobile app stores the word "Today".
3. **DEMO-03** Simulated latency (0.7 s) and loading skeletons (0.45 s) in the console; always-green success messages.
4. **DEMO-04** Fixed KPI numbers, charts, reach figures and "vs last week" captions on dashboards, analytics, billing, platform users and reports.
5. **DEMO-05** Role switcher in the hospital top bar; hospital login always lands on Administrator.
6. **DEMO-06** Audit entries always attributed to riya.sharma@medibook.in / 10.42.8.11 / "Just now".
7. **DEMO-07** Hard-coded "Apollo Hospital" on receipts and slips; tenant constant 13; hospital settings stored in the browser.
8. **DEMO-08** Token counter seeds (A-26, T-008), MR/appointment/plan ids minted in the browser, unknown ids falling back to the first record instead of "not found".
9. **DEMO-09** Mobile platform identity (`com.example.my_app`, "My App"), debug signing, missing release internet permission.


# 7. Status and Lifecycle Reference

Each list gives the statuses (with the badge colour used on screen), the transitions the prototype actually performs, and the transitions the contract expects but the prototype does not perform.

## ST-01 Appointment — hospital app
1. **Statuses:** Scheduled (blue) · In Queue (amber) · Completed (green) · Cancelled (red) · No-show (orange).
2. **Implemented transitions:** create → Scheduled; Scheduled → In Queue (Check In / Issue Token, Mark Payment, or Call Next of a tokened online booking); In Queue → Completed (Done); In Queue → In Queue (Skip, Call Next); In Queue → Scheduled (Undo check-in); Scheduled → Cancelled (Cancel, optional desk refund); Scheduled → No-show (No-show); Cancelled → Scheduled (Reinstate); No-show → Scheduled (Undo no-show). Completed is terminal.
3. **Not possible in the UI:** cancelling or no-showing an appointment that is already In Queue; approving an appointment (FRD "approve"); automatic no-show after the grace period; marking "visited" separately from Completed.

## ST-02 Appointment — patient app
1. **Statuses:** Confirmed (navy) · Completed (green) · Cancelled (red), in two lists Upcoming / Past.
2. **Implemented:** book → Confirmed/Upcoming; Confirmed → Cancelled/Past (Cancel); Confirmed → Confirmed with new date/time (Reschedule). Completed exists only in sample data.
3. **Expected but absent:** payment pending/paid/refund states, check-in, no-show, hold/expiry, automatic move to Past by date.

## ST-03 Payment state of an appointment (hospital app)
1. **Statuses:** Paid (green) · Pending (amber) · Refunded (red).
2. **Implemented:** Online → Paid at creation; Walk-in → Pending at creation; Pending → Paid (Record Payment, single or combined); Paid → Refunded (Cancel with desk-refund switch, walk-ins only). Online cancellations stay Paid.
3. **Absent:** partial refund, refund reference/date, online refund status visible to the patient (FRD), payment failure/retry.

## ST-04 Token
1. None → "T-nnn" (online booking for today at creation; walk-in payment; check-in) → kept through Completed/Cancelled/No-show → removed only by Undo check-in on a walk-in.

## ST-05 Doctor live queue status (hospital app)
1. **Statuses:** Available (blue) · Consulting (green) · Waiting (amber) · On Break (grey).
2. **Implemented:** any → Consulting (Call Next); Consulting → Waiting (others waiting) or Available (Done / Skip); Available ↔ On Break (pause/resume).
3. **Note:** independent from the catalogue status Active / On Leave / Inactive (ST-13).

## ST-06 Settlement statement
1. **Statuses:** Pending (amber) · Overdue (red) · Released (green) · Received (green) · Payout failed (red); plus a "requested" flag.
2. **Implemented:** Pending/Overdue → Released (console Release or payout run); Payout failed → Released (Retry); Released → Received (hospital Mark Received); requested false → true (hospital Request / Raise) → false (any release).
3. **Absent:** creation of statements; Pending → Overdue by date; any → Payout failed; Received is terminal with no reversal; partial-release balance.

## ST-07 Hospital request (support / plan / settlement)
1. **Statuses:** Open · Closed.
2. **Implemented:** Plan requests close when any plan change for that hospital is approved or declined; Settlement requests close when the referenced statement is released; Support requests never close.

## ST-08 Plan change request
1. **Statuses:** Pending (amber) · Completed (green) · Cancelled (red).
2. **Implemented:** hospital request → Pending; Approve → Completed (hospital's plan updated when the target plan exists); Decline → Cancelled. Terminal thereafter.

## ST-09 Hospital (tenant)
1. **Statuses:** Pending verification (amber) · Active (green) · Suspended (grey) · Rejected (red).
2. **Implemented:** onboard → Pending verification; Pending → Active (Approve, requires no KYC document Missing); Pending → Rejected (Reject with reason); Rejected → Active (Re-review & Approve); Active → Suspended; Suspended → Active.
3. **Absent:** deletion/archival; Rejected → Pending; auto-suspension for non-payment.

## ST-10 KYC document (per document, four per hospital)
1. **Statuses:** Missing (red) · Submitted (amber) · Verified (green).
2. **Implemented:** onboarding → Missing; approval → all Verified. **Absent:** Missing → Submitted (upload) and per-document verification/rejection.

## ST-11 Subscription invoice and payment (console)
1. **Invoice statuses:** Completed · Pending · Overdue · Payment failed. **Payment statuses:** Success · Pending · Payment failed. **Methods:** UPI · Card · NetBanking.
2. **Implemented:** none (read-only sample data). **Absent:** issue, pay, fail, retry, overdue detection, void, grace period, auto-suspension.

## ST-12 Patient (hospital register) · Department · Hospital staff user
1. **Patient:** Active ↔ Inactive (Edit Patient); no effect on booking.
2. **Department:** Active ↔ Inactive (Edit Department); no effect on doctors or booking.
3. **Hospital staff user:** Active → Inactive (Deactivate) and back (Activate); invite Pending/Accepted set at creation, never changes; no deletion.

## ST-13 Doctor (catalogue)
1. **Statuses:** Active (green) · On Leave (amber) · Inactive (grey); set manually on the profile; never derived from leave dates; no effect on booking or queue.

## ST-14 Internal Medibook user
1. **Statuses:** Pending (amber) · Active (green) · Suspended (grey); 2FA Enabled / Pending.
2. **Implemented:** Add → Pending; any → deleted. **Absent:** Pending → Active (invite acceptance), suspend/reactivate, 2FA enrolment.

## ST-15 Patient account (platform user)
1. Active (green) ↔ Blocked (grey) via Block / Unblock with a Critical audit entry; no deletion or anonymisation.

## ST-16 Banner
1. **Derived states:** Paused (switched off) → Expired (end date before today) → Scheduled (start after today) → Live; plus position (priority).
2. **Implemented:** create (active) → date-driven state; Pause/Resume; Move up/down; delete.

## ST-17 Push notification
1. **Statuses:** Queued (blue) · Scheduled (blue) · Sent (green) · Cancelled (red).
2. **Implemented:** Send now → Queued; Schedule → Scheduled; Scheduled → Cancelled. **Absent:** Queued/Scheduled → Sent (delivery), edit, resend.

## ST-18 Dashboard alert (console)
1. Exists → deleted by Resolve Now; no creation path.

## ST-19 Health record (patient app)
1. Completed (green) · Pending (red); read-only sample data; no transitions.


# 8. Data Dictionary (what the screens imply for the schema)

This section lists every business entity the three front ends display or edit, with the fields the screens actually use, their observed formats and sample values, and the fields the backend must add (identifiers, timestamps, foreign keys) because the prototypes join on names or store display strings. Formats in quotes are what the prototype shows today; they are inputs to the schema decision, not the decision itself.

## 8.1 Tenancy and platform
1. **E-01 Hospital (tenant).** Fields seen: id (console number; Apollo = 13), name, admin email, phone, GSTIN, plan (by plan name), city, state (2-letter), bookings this month, onboarded date ("April 12, 2025"), status (Active / Pending verification / Suspended / Rejected), KYC record (registration certificate, GST certificate, medical licence, bank account proof — each Missing / Submitted / Verified), payout bank (bank, account number, IFSC, UPI), rejection reason, derived instance ID ("MB-HOSP-0113"). From Hospital Settings the same tenant also owns: registration number, about, logo, gallery photos, address, latitude, longitude, map pin, working hours (open, close, open days), account holder name, rules and notification preferences (see E-04). *Backend must add:* branch support (FRD), holidays, creation/verification timestamps, verified-by, KYC document files and per-document review history, subscription history.
2. **E-02 Subscription plan.** id, name (unique), monthly price (₹, GST-inclusive as displayed), bookings per month, staff-account tier ("Up to 25 staff accounts" / "Up to 120 staff accounts" / "Unlimited staff accounts"), support tier ("Email support" / "Priority support" / "Dedicated success manager"), extra feature line, most-popular flag (exclusive), hospital-specific flag. *Backend must add:* yearly billing option, limits for doctors/branches/storage/message credits (FRD), effective dates, price history.
3. **E-03 Plan-change request.** id, hospital, hospital email, change text ("Growth → Enterprise"), requested date, status (Pending / Completed / Cancelled). *Add:* from-plan and to-plan ids, decided by/at, effective date.
4. **E-04 Hospital settings (per tenant).** Booking rules: default consultation duration (10/15/20/30 mins), online booking on/off, max appointments per slot (5/10/15/20), buffer (0/5/10/15 mins), allow patient cancellation, cancellation cut-off (1/2/4/24 hours), auto no-show after (30 mins/1 hour/2 hours), token generation (Auto/Manual), show token to patient, allow hold token, hold timeout (15/30/45 mins), grace period (15/30/45 mins), after grace (Auto Mark No-show / Keep waiting), OP consultation fee, fee validity days, apply to all departments. Notification preferences: appointment confirmation, visit reminder, settlement received, settlement overdue, plan quota low. *Add:* reschedule window, cancellation fee/refund slab, token numbering scheme, message templates, banner placements (all FRD policies).
5. **E-05 Platform settings (singleton).** Platform name, support email, helpline number, payout schedule (Weekly / Fortnightly / Monthly), platform commission % (0–100), platform GSTIN (15 characters), settlement alerts, compliance alerts, weekly digest, require 2FA, session timeout (15/30/60 min), API key (masked). *Add:* GST rate, next payout date logic.
6. **E-06 Internal Medibook user.** id, name, work email, role (Super Admin / Finance Admin / Support / Auditor), 2FA state (Enabled / Pending), last active, status (Active / Pending / Suspended), avatar. *Add:* password/credentials, invite token and acceptance, real last-active timestamp.

## 8.2 Hospital operations
1. **E-10 Department.** id ("dp0"), name (used as the join key today), about, base fee (₹ integer), hours text ("Mon–Sat · 9am–6pm"), status (Active / Inactive), colour, weekly grid (7 × {day, on, from, to} with times from "8:00 am" to "8:00 pm"), image. *Add:* hospital id, tax/coupon settings if the FRD's "services" concept is adopted.
2. **E-11 Doctor.** id ("dc0"), name, departments (names, one or more), specialisation, room, fee, rating (one decimal), review count, status (Active / On Leave / Inactive), weekly grid, leave list ({from, to, reason} as free text "18 Jun"), reviews ({author, rating 1–5, relative date, text}), phone, email, qualification, experience, registration number, photo, about. *Add:* hospital id, department ids, real leave dates, session/shift definitions, slot size/buffer/capacity per doctor, online-booking flag.
3. **E-12 Slot (implied, not modelled).** The FRD requires generated slots per doctor per date with open/blocked state, capacity, hold and booking references. Nothing in the prototypes stores slots; both apps use fixed time labels.
4. **E-13 Patient (hospital register).** MR number ("AP847201"; generated "AP800001"), name, age (integer; 0 = unknown), gender (Male / Female / Other), phone, email, address, status (Active / Inactive). Principle: identity and contact only, no clinical data. *Add:* hospital id, date of birth, created/updated timestamps, link to the platform patient account when the patient came from the app.
5. **E-14 Appointment / consultation (hospital).** id ("AP1000"), MR number, denormalised patient name/age/gender/phone, department, doctor (name), source (Online / Walk-in), date (label: "Today" / "Tomorrow" / "14 Jun"), time (slot label "8:30 am"), amount (₹), payment state (Paid / Pending / Refunded), token ("T-001" or none), status (Scheduled / In Queue / Completed / Cancelled / No-show), remark, payment mode (Cash / UPI / Card), payment reference, called-at time, queue order, cancellation reason (Patient request / Doctor unavailable / Duplicate booking / Scheduling error / Other), refund via (Desk). *Add:* hospital id, real date/time and timezone, slot id, created/updated/checked-in/called/completed timestamps, created-by user, booking id shown to the patient, link to the mobile booking, refund amount/reference/date, receipt id, visit outcome.
6. **E-15 Payment / receipt (implied).** Today embedded in the appointment; the receipt number is derived ("RCPT-47202-10"). *Backend must create:* a payment record (amount, mode, reference, timestamp, cashier, appointment(s) covered, status) and a receipt series with tax lines (consultation fee, taxes, convenience fee), hospital GSTIN and the patient's GST details where applicable.
7. **E-16 Live queue state.** Per doctor: currently serving token, live status (Available / Consulting / Waiting / On Break); hospital-wide token counter; the department filter last used by the desk. *Add:* per-day/per-doctor sequences (FRD), queue events for audit and for the patient-facing "last called" and estimated wait.
8. **E-17 Hospital staff user.** id ("u1"), name, email, phone, username, role id, status (Active / Inactive), last active label, invite status (Accepted / Pending). *Add:* credentials, hospital id, invite tokens, real timestamps.
9. **E-18 Hospital role.** id ("r-admin", "r-new-1"), name, colour, description, system flag, permission grid (ten modules × view/add/edit/delete). *Add:* hospital id; enforcement mapping to API endpoints.
10. **E-19 Settlement statement (hospital view).** Statement number ("MB-ST-2406"), period text ("10 – 16 Jun 2026"), gross, commission, net, expected date (ISO), status (Pending / Overdue / Released / Received / Payout failed), UTR, remark, received-on date, released amount, requested flag and date. *Add:* hospital id, period start/end dates, commission rate snapshot, the list of appointments/payments the statement covers, release history, outstanding balance for partial releases.
11. **E-20 Support ticket / hospital request.** id, type (Support / Plan / Settlement), hospital, subject ("Technical issue — Apollo Hospital", "Plan change requested — Enterprise", "Settlement release requested — MB-ST-2406"), detail (message or statement number), date, status (Open / Closed). *Add:* raised-by user, replies, assignment, resolution timestamps, closure of support tickets.
12. **E-21 Report definition (hospital).** id, name, brief, category (Operations / Finance / People), applicable filters (date, department, doctor, status, mode, source, user), four KPI tiles. *Backend must define* the dataset and columns of each of the 14 reports (Section 10.1).

## 8.3 Patient side
1. **E-30 Patient account.** From the mobile app: name, email, phone ("+91 98456 58525"), date of birth ("15/05/1997"), gender, blood group, blood-donation consent, password. From the console: id, name, email, phone, city, bookings count, joined date, status (Active / Blocked), avatar. *Add:* mobile-number verification state, address (FRD), emergency contacts (FRD), push registration tokens, terms acceptance, deletion/retention state.
2. **E-31 Dependent / family member.** name, relationship (Self / Husband / Daughter in the app; Spouse / Son / Daughter / Father / Mother in the console), age (or date of birth), gender. *Add:* optional blood group and allergies (FRD), id, link to the account.
3. **E-32 Appointment (mobile view).** id ("1", "b26"), doctor id, patient name, date ("Today" / "12 Aug 2026"), time ("10:30 AM"), token ("A-25"), status (Confirmed / Completed / Cancelled), list bucket (Upcoming / Past). *Add:* hospital, booking id, payment status and receipt (FRD), fee breakdown, documents, cancellation/refund status, real timestamps.
4. **E-33 Doctor (mobile view).** id slug ("anya"), name, department, specialty, title, experience ("12 yrs"), patients treated ("6,000+"), rating, fee ("₹900"), hospital name, about, photo. *Backend:* these are the hospital catalogue doctors (E-11) exposed to patients with numeric fields.
5. **E-34 Department (mobile view).** name, descriptor, icon. *Backend:* E-10 with an icon/illustration asset.
6. **E-35 Health record (mobile).** title, date, status (Completed / Pending), patient name, hospital name, doctor name. *Backend:* the FRD's document library — title, type (prescription / lab report / imaging / discharge summary / other), patient (self or dependent), date, notes, file, optional appointment link, sharing links with expiry.
7. **E-36 Notification (mobile).** title, body, relative time, up to two actions. *Add:* id, type, read state, timestamp, target (appointment/record id), channel delivery records.
8. **E-37 Banner (console) / promo banner (mobile).** Console: id, title, image, live-from, live-until, active flag, priority position, plus one default banner (title, image). Mobile: title, body, gradient, has-image. *Backend:* one banner model with image URL, schedule, priority, hospital or platform scope, optional link.
9. **E-38 Push notification campaign.** id, title (≤ 40), body (≤ 120), audience (All users / Android only / iOS only / Inactive 30+ days), when, status (Sent / Scheduled / Queued / Cancelled), delivered count, open rate. *Add:* creator, provider message ids, per-device delivery results.

## 8.4 Finance (console)
1. **E-40 Invoice.** id, number ("INV-2026-0231"), hospital, amount (GST-inclusive), issued date, due date, status (Completed / Pending / Overdue / Payment failed); displayed but not stored: billing period, plan, subtotal, CGST 9%, SGST 9%. *Add:* line items, tax breakdown stored at issue time, plan snapshot, PDF.
2. **E-41 Subscription payment.** id, transaction id ("TXN-88412"), invoice number, hospital, method (UPI / Card / NetBanking), amount, date, status (Success / Pending / Payment failed); displayed but derived: gateway reference, status timeline. *Add:* gateway payload, attempts, refunds.
3. **E-42 Settlement statement (console view).** Same as E-19 plus hospital id and, for non-Apollo rows, commission/net computed from the platform rate.
4. **E-43 Payout run.** Derived grouping of statements by expected date with totals; recorded run remark. *Add:* run id, executed-by/at, bank batch reference.
5. **E-44 Compliance log entry.** id, hospital id (optional), action text, actor, module (Hospitals / Settlements / Billing / Subscription Plans / Users & Roles / Platform Users / Reports / Settings / Auth / Media / Notifications), IP address, timestamp, severity (Info / Warning / Critical). *Add:* structured event type (Appendix C), target entity id, before/after values for configuration changes.
6. **E-45 Dashboard alert.** id, severity (danger / warning), title, sub-text, target (settlements / logs / hospital:id). *Add:* generation rules (payout failure, quota, log gap, message-delivery failures, payment-callback failures).

## 8.5 Relationships the backend must make explicit
1. Hospital 1—n Departments, Doctors, Patients, Appointments, Staff users, Roles, Settlements, Invoices, Payments, Requests, Log entries; Hospital n—1 Plan.
2. Doctor n—n Department (by id, not name); Doctor 1—n Slots (generated); Slot 1—n Appointments (capacity); Appointment n—1 Patient; Appointment 1—1 Token; Appointment 1—n Payments/Refunds; Appointment n—1 Settlement statement (for online, completed bookings).
3. Patient account 1—n Dependents; Patient account 1—n Bookings (mobile) which map 1—1 to hospital Appointments; Patient account 1—n Documents; Patient account 1—n Notifications and device registrations.
4. Plan 1—n Hospitals; Plan-change request n—1 Hospital; Invoice n—1 Hospital; Payment n—1 Invoice.
5. Banner / Push campaign — platform-scoped in the console (no hospital link); the FRD also expects hospital-published banners.
6. Every identifier in the prototypes that is minted in the browser (MR number, appointment id, token, statement number, invoice number, receipt number, plan id, user id) must be issued by the server.


# 9. Integrations and Non-Functional Needs Implied by the Screens

## 9.1 External services the screens assume
1. **Payment gateway (Razorpay per the FRD and Agreement).** Required for online consultation fees (mobile) and subscription invoice payments (console). No SDK, order creation, webhook handling, hold/expiry or refund call exists in either code base; the mobile app's "Confirm and Pay" takes no payment.
2. **WhatsApp Cloud API, SMS and push (Firebase).** Required for booking confirmations, reminders, reschedule/cancel notices and campaign pushes. No provider integration exists; the mobile app has no push registration; the console's push composer only records campaigns.
3. **File storage with expiring links.** Required for KYC documents, patient documents, lab reports, token cards, receipts, hospital logos/gallery, department images, doctor photos and banner images. Today images are kept as browser data (base64) and documents do not exist.
4. **Maps / geocoding.** Hospital Settings has a decorative map and free-text latitude/longitude; the FRD expects patients to see the hospital location and get directions; the mobile app shows no map. A geocoding and map provider is required.
5. **Device calendar.** The FRD's "add the visit to the device calendar" has no implementation.
6. **Printing / PDF.** mbAdmin prints receipts and token slips through the browser; PDF export of reports, invoices and statements is a message only. A server-side PDF service is implied.
7. **Telephony.** The optional ambulance call and support "Call Us" links need dialler integration; none exists.

## 9.2 Time, locale and money
1. All three apps assume India: rupees with Indian digit grouping ("₹ 1,02,400"), +91 phone numbers, GSTIN, 18% GST split 9%/9%, IFSC/UPI bank details.
2. The backend must own the clock: the console runs on a fixed demo date, the hospital app on relative labels evaluated by the browser, the mobile app on the device date. All dates must be stored as timestamps in Asia/Kolkata.
3. Time slots, tokens, reminders, overdue detection, banner windows and scheduled pushes are all time-driven and need a server scheduler.

## 9.3 Multi-tenancy and data isolation
1. One hospital app instance corresponds to one tenant; the console reads live data of one tenant (Apollo, id 13) and sample data for the rest. The backend must scope every hospital record by tenant id and expose only the tenant's own data to its staff, while the console reads across tenants with per-role limits.
2. Patient accounts are platform-wide (a patient books across hospitals); their appointments, documents and notifications must be linked to both the patient and the hospital.

## 9.4 Security expectations from the contract (none implemented in the UI)
1. Mobile number/email plus password login with OTP verification; short-lived JWT access tokens with rotating refresh tokens; OTP time limits and rate limits; lockout after repeated failures; password hashing; encryption at rest for sensitive fields; HTTPS only.
2. Role-based access control on every screen and action for hospital roles (including the custom permission grids) and console roles (four-role matrix).
3. Audit trail for administrative actions, configuration changes, booking state transitions and outbound message attempts, with real actor, IP and timestamp.
4. Account deletion gated by OTP and governed by a retention policy; notification opt-ins; consent capture (the blood-donation consent defaults to on today).

## 9.5 Performance and volume expectations from the contract
1. Login under 1 second on warm paths; OTP verification under 2 seconds; search and slot fetches under 2 seconds; 100+ concurrent bookings without double booking (slot hold plus optimistic locking and unique constraints), contingent on the recommended server.
2. The screens imply pagination sizes of 6–9 rows and client-side search; production lists (patients, appointments, logs, invoices) need server-side search, filtering, sorting and paging.

## 9.6 Reporting and exports
1. Real CSV downloads exist for payments and settlements (hospital); every other export is a stub. The FRD requires CSV/PDF exports of bookings, cancellations, no-shows, revenue and slot utilisation filtered by date, department and doctor, and console exports for audit/BI.

## 9.7 Mobile release readiness
1. Application identifiers, display name, icons, splash screens, signing keys, release internet permission, iOS usage descriptions (camera/photos for document upload, calendar, location if used), deep-link schemes and store listings are all still template defaults and must be produced before any store submission (client prerequisites in Agreement 7.4: Play Store, Apple Developer, Razorpay, Firebase, CDN, WhatsApp provider).


# 10. Gap Analysis Against the Contract Documents

Legend: **Present** — the user interface implements the requirement (possibly on sample data); **Partial** — the screen exists but the requirement is only partly represented; **Absent** — nothing in any user interface; **Backend** — a server-side requirement with no user-interface expectation; **Excluded** — expressly out of scope in the Agreement. IDs refer to the Preliminary FRD (CM = customer mobile, HA = hospital admin, SA = super admin, X = platform), the Quote (Q) and the Agreement (AGR); the full checklist is Appendix E.

## 10.1 Contract requirements missing or partial in the user interfaces (mandatory list)

### 10.1.1 Patient mobile app — registration and access
1. **GAP-001 (CM-01, Partial).** Sign-up captures one "Full Name" field, email, an unvalidated phone number and a password. The FRD requires first name, last name, address, email, mobile number, password and confirm password.
2. **GAP-002 (CM-02, Partial).** The policy checkbox exists but the Terms & Conditions, Privacy Policy and User Guidelines are not tappable documents.
3. **GAP-003 (CM-03, Absent).** No OTP is sent to the mobile number at sign-up; accounts are never "activated".
4. **GAP-004 (CM-04, Absent).** Login is by email, not mobile number.
5. **GAP-005 (CM-05, Absent).** No lockout or throttling after repeated failures.
6. **GAP-006 (CM-06, Partial).** Forgot-password uses email, not mobile; the OTP is a fixed demo code; the new password is not stored.
7. **GAP-007 (CM-47, CM-51, Absent).** Profile editing and phone re-verification are stubs; there is no change-password flow after OTP.
8. **GAP-008 (CM-53, Partial).** Logout only navigates; nothing is cleared and push registrations do not exist.
9. **GAP-009 (CM-54, Partial).** Account deletion shows a confirmation sheet and a "stubbed" message; no OTP gate, retention handling or impact notice.

### 10.1.2 Patient mobile app — home, discovery and booking
10. **GAP-010 (CM-07, Partial).** Banners are two fixed slides with no link and no remote configuration; the console's banner manager is not connected.
11. **GAP-011 (CM-08, Partial).** Navigation is Home / Appointments / Records / Profile; there is no "Services" tab (services appear as home tiles that all lead to the same booking flow).
12. **GAP-012 (CM-09, CM-24, Partial).** The token widget shows only the patient's own token; current token being served, last called number, estimated wait and a refresh indicator are absent.
13. **GAP-013 (CM-10, Absent).** No location selection and no hospital list; discovery starts at the department.
14. **GAP-014 (CM-11, Partial).** Hospital → department → doctor becomes department → doctor; the hospital is a label on the doctor and cannot be chosen or searched.
15. **GAP-015 (CM-12, Partial).** Instead of a calendar with bookable slots, the app offers five fixed days and six fixed times that are always available; there is no availability, capacity, hold or "only bookable slots" rule.
16. **GAP-016 (CM-13, CM-19, Partial).** The booking summary lacks the hospital row, taxes, convenience fee, coupons and a total.
17. **GAP-017 (CM-14, Partial).** A token is issued but no booking ID is shown, and nothing is conditional on payment.
18. **GAP-018 (CM-15, CM-27, Absent).** No token card to view or download, no add-to-calendar.
19. **GAP-019 (CM-16, CM-48, Partial).** Three fixed dependents can be selected; dependents cannot be added, edited or removed, and blood group/allergy flags do not exist.
20. **GAP-020 (CM-17, CM-20, CM-23, Absent).** No in-app payment (UPI, cards, net-banking, wallets), no payment order, hold, failure/retry, no Razorpay.
21. **GAP-021 (CM-18, Partial).** The app behaves as if every booking is paid at the hospital desk; "Pay at Hospital" is not a configurable per-hospital option with a counter-confirmation window.
22. **GAP-022 (CM-21, CM-22, Absent).** No receipt in the appointment details, no GST details, no refund status.
23. **GAP-023 (CM-25, CM-26, Partial).** Cancel and reschedule exist but no cut-off, policy window or hospital permission is enforced (the "2 hours" text is copy only).
24. **GAP-024 (CM-28, Partial).** My Appointments has Upcoming/Past only; no filters by time range, doctor, hospital, status or patient.
25. **GAP-025 (CM-29, Partial).** Details show token and appointment status but not payment status, receipt download or attached documents.
26. **GAP-026 (CM-30, Absent).** Appointments cannot be searched by doctor name, hospital name or booking ID (search covers departments and doctors only).

### 10.1.3 Patient mobile app — documents, insurance, notifications, emergency, support
27. **GAP-027 (CM-32 to CM-36, Absent).** The Documents Library (upload PDF/JPG/PNG/DOC/PPT, title, type, patient, date, notes, appointment link, filters, secure expiring links, external sharing) does not exist; the Records tab lists three fixed lab records with stub View/Download buttons.
28. **GAP-028 (CM-37 to CM-39, Absent).** The Insurance Locker does not exist.
29. **GAP-029 (CM-40 to CM-43, Absent).** No WhatsApp, push or in-app confirmations, reminders, reschedule/cancel notices, retries or read state; the notification screen is four fixed cards.
30. **GAP-030 (CM-44 to CM-46, Absent).** The optional Call Ambulance feature does not exist.
31. **GAP-031 (CM-49, CM-50, Absent).** Emergency contacts and address management do not exist.
32. **GAP-032 (CM-52, Absent).** Privacy Policy, Terms, FAQs and Support (call/email/chat) are not reachable from the app.

### 10.1.4 Hospital web app
33. **GAP-033 (HA-01, Partial).** Login is simulated; password reset has no OTP step; mobile-number login is absent.
34. **GAP-034 (HA-02, Partial).** Dashboards lack cancellation and slot-utilisation KPIs; department token boards exist only as the Front Desk snapshot; admin revenue and charts are fixed sample values.
35. **GAP-035 (HA-03, Partial).** Hospital profile and working hours exist as forms; branches and holidays do not exist; hospital-published banners/ads for the patient app do not exist.
36. **GAP-036 (HA-04, Partial).** Departments have a base fee only; services with pricing, taxes and coupons do not exist.
37. **GAP-037 (HA-06, HA-07, Partial).** Weekly hours are shown but not saved; consultation duration, max per slot, buffer and online-booking are display-only; shifts and leave add/remove are stubs; exceptions per date do not exist.
38. **GAP-038 (HA-08, Absent).** No slot generation, no open/block/bulk-update of slots, no instant reflection in the app.
39. **GAP-039 (HA-09, Partial).** Appointments desk covers view, reschedule, cancel, walk-in, no-show and completion; "approve" and "waivers" do not exist; refunds are desk-only full refunds.
40. **GAP-040 (HA-10, Partial).** Token cards and receipts print through the browser; no download/PDF, no tax lines, no unique receipt series.
41. **GAP-041 (HA-11, HA-12, Absent).** Hospitals cannot trigger confirmations/reminders or publish announcement banners; message templates with placeholders do not exist (only on/off preferences).
42. **GAP-042 (HA-13, Partial).** Fourteen report templates with filters are defined, but reports contain fixed KPI tiles, no data tables, cosmetic filters, CSV of four rows and a stub PDF.
43. **GAP-043 (Q-03, Partial).** Patient history is a table on the patient profile without filters; "visit type" and "transaction mode" filters exist only on the Payments list.
44. **GAP-044 (X-01, Absent).** Custom role permissions are captured but enforced nowhere; the FRD requires RBAC on every screen and action.

### 10.1.5 Operations console
45. **GAP-045 (SA-01, Partial).** Onboarding does not provision the initial Admin user or default settings; no invitation or KYC request is sent; documents cannot be uploaded or verified individually.
46. **GAP-046 (SA-02, Partial).** Plans are monthly only, limited by bookings, staff accounts and support tier; the FRD's monthly/yearly plans with doctor, branch, storage and message-credit limits are absent.
47. **GAP-047 (SA-03, Partial).** Invoices and payments are read-only; no reminders, mark-as-paid, retry, grace period or auto-suspension for non-payment.
48. **GAP-048 (SA-04, Partial / conflict).** Settlement helper reports are a stub card; instead a full in-app settlement workflow exists (see 10.3).
49. **GAP-049 (SA-05, Partial).** Dashboard and analytics KPIs are fixed sample numbers; provider usage and error rates do not exist.
50. **GAP-050 (SA-06, Partial).** Compliance logs exist for a subset of console actions with a fixed actor/IP/time; access logs for staff logins, configuration-change details and data export on request do not exist.

### 10.1.6 Platform and cross-cutting
51. **GAP-051 (X-02, Absent).** Slot hold during payment, hold expiry, optimistic locking and unique constraints — nothing in any UI.
52. **GAP-052 (X-03, Absent).** Tokens are not sequential per doctor per date and are not tied to payment success (hospital-wide T-nnn at booking/payment/check-in; app-wide A-nn at confirmation).
53. **GAP-053 (X-04, Absent).** Payment orders, gateway webhooks, stored receipts and refund audit trails do not exist.
54. **GAP-054 (X-05, Absent).** Notification content with hospital, department, doctor, date/time, token and location link — no messaging exists.
55. **GAP-055 (X-08, Partial).** Per-tenant policies: slot sizes/buffers, hold duration, cancellation cut-off, working days, token logic are captured as settings but unenforced; reschedule windows, cancellation fees, refund rules, holidays, message templates and banner placements are absent.
56. **GAP-056 (X-09, Partial).** Downloads of token cards, receipts and documents with expiring URLs do not exist.
57. **GAP-057 (X-10, Partial).** Booking state transitions, outbound message attempts, hospital-side actions and delivery/payment-callback failures are not logged or surfaced.
58. **GAP-058 (AGR-01 backend, Absent).** No Django/PostgreSQL backend, API or deployment exists; both repositories contain empty placeholder files where networking, storage and authentication code would go.

## 10.2 User-interface features beyond the Preliminary FRD (Change-Request candidates under Agreement Clause 2.4)
The Agreement states that design elements outside the Final/Preliminary FRD are not covered unless a Change Request is agreed. The following exist in the prototypes and are not in the FRD; each needs an explicit "in / out" decision before the Final FRD.
1. **XTRA-01** In-app settlement workflow on both sides: weekly statements, hospital request/raise, Medibook release with UTR/amount/remark, payout runs, partial releases, hospital "Mark Received", overdue and payout-failed states. (The FRD says settlements are handled outside the application.)
2. **XTRA-02** Hospital-defined custom roles with a ten-module × four-action permission grid, invite methods (email / mobile OTP / set password), reset-password options.
3. **XTRA-03** Two built-in hospital roles (Receptionist and Administrator) with different menus; the FRD names only "Hospital Admin" (the Quote names Admins and Staff).
4. **XTRA-04** Multi-consultation booking for one patient with one combined payment and one token per consultation.
5. **XTRA-05** Live token queue controls: Skip to end of queue, Undo check-in, Undo no-show, Reinstate cancelled, doctor On Break, consultation-duration timer with a 20-minute highlight, doctor daily capacity hint (16/day).
6. **XTRA-06** Doctor ratings and patient reviews (read-only in the hospital app).
7. **XTRA-07** Patient billing summary (visits, total paid, outstanding) and CSV exports of payments and settlements.
8. **XTRA-08** Hospital Help & Support centre with FAQs and support tickets routed to the console.
9. **XTRA-09** Hospital photo gallery and map pin; blood-donation consent on the patient profile; "Lab Tests", "Family" and "Women's Health" quick actions and a "Lab tests at home" banner in the mobile app.
10. **XTRA-10** Console: KYC document workflow with four documents and rejection reasons; instance IDs; hospital-specific negotiated plans and "Most Popular" flag; plan-change request/approve/decline workflow; plan rename cascade.
11. **XTRA-11** Console: four internal roles (Super Admin, Finance Admin, Support, Auditor) with a permission matrix; internal user management; 2FA requirement; session timeout; API key rotation; weekly digest.
12. **XTRA-12** Console: patient-account management (search, block/unblock, family members, booking history) with access logging.
13. **XTRA-13** Console: banner manager (default banner, scheduled campaign banners, priority, pause) and push-notification campaigns with audience segments and scheduling.
14. **XTRA-14** Console: usage analytics dashboards, six console reports, and a compliance-log screen with severity/module filters.
15. **XTRA-15** Hospital-side subscription page (quota bar, invoices list, request plan change) and platform commission configurable per platform.

## 10.3 Conflicts between the documents and the user interfaces
1. **CONF-01 Settlements.** FRD: outside the application, helper reports only. UI: full two-sided workflow (10.2 XTRA-01). Decide which governs.
2. **CONF-02 Patient login identity.** FRD: mobile number + password with mobile OTP. UI: email + password with email OTP.
3. **CONF-03 Mobile navigation.** FRD: Home, Services, Profile. UI: Home, Appointments, Records, Profile.
4. **CONF-04 Discovery order.** FRD: location → hospital → department → doctor. UI: department → doctor, with a search box; no hospital choice.
5. **CONF-05 Token scheme.** FRD: sequential per doctor per date, assigned on payment success. UI: hospital-wide "T-nnn" issued at booking/payment/check-in (web) and app-wide "A-nn" issued at confirmation (mobile); an unused per-department prefix scheme also exists in code.
6. **CONF-06 Payment moment.** FRD: pay in the app before the booking is finalised (or "Pay at Hospital" where allowed). Mobile UI: "Confirm and Pay" with the note "Payment is collected at the hospital desk." Web UI: online bookings are "prepaid via Medibook".
7. **CONF-07 Plan limits.** FRD: doctors, branches, storage, message credits; monthly or yearly. UI: online bookings per month, staff accounts, support tier; monthly only.
8. **CONF-08 Commission.** FRD is silent; UI applies a 10% platform commission on online bookings and mentions Medibook keeping cancellation fees.
9. **CONF-09 GST.** FRD: GST details entered and printed on patient receipts. UI: GST only on subscription invoices (Medibook GSTIN and hospital GSTIN); consultation receipts have no tax.
10. **CONF-10 Documents and records.** FRD: a patient documents library with uploads and sharing. Mobile UI: a read-only "Records" list of lab reports. Hospital UI principle: "no clinical data" stored. The backend needs a single decision on who stores what.
11. **CONF-11 Excluded feature in marketing copy.** The console's sample banner "Free tele-consult week with top cardiologists" promotes tele-consultation, which the Agreement excludes.
12. **CONF-12 Repository documentation vs code.** The mobile repository's technical stack (Flutter 3.24.5, Hive cache, Dio, Razorpay, secure storage) and linting/pre-commit guides describe a build that does not exist; the code targets Flutter ≥ 3.38 with none of those packages.

## 10.4 Cross-application inconsistencies the backend must reconcile
1. **Departments.** Mobile: General, Cardiology, Orthopedics, Dermatology. Hospital app: Cardiology, Orthopedics, Pediatrics, Neurology, ENT, Dermatology (Dermatology inactive in the catalogue but bookable). Console sample pools add General Medicine, Gynaecology, Ophthalmology.
2. **Doctors and fees.** Mobile: six doctors across two hospitals with per-doctor fees (₹450–₹900). Hospital app: seven doctors with per-department fees (₹500–₹1,000) in booking and per-doctor fees in the catalogue.
3. **Hospitals.** Mobile: "Apollo Hospital" and "City Care Clinic" as labels. Hospital app: Apollo Hospital only. Console: 13 hospitals, Apollo = 13.
4. **Statuses.** Mobile: Confirmed / Completed / Cancelled. Web: Scheduled / In Queue / Completed / Cancelled / No-show plus payment Paid / Pending / Refunded.
5. **Patient identity.** Mobile: patients by name with a relationship. Web: MR numbers per hospital. Console: platform user ids with family members. A patient booking across hospitals needs one platform identity mapped to per-hospital MR numbers.
6. **Time slots.** Mobile: six fixed labels. Web: 10 or 11 fixed half-hour labels; sample data uses 15-minute times in neither list.
7. **Dates.** Mobile stores the word "Today"; web stores relative labels; console stores long dates and ISO dates on a fixed demo day.
8. **Banners and notifications.** Console manages banners and pushes; the mobile app has its own fixed banners and notifications.
9. **Commission rate.** Hospital app fixed at 10%; console editable; Apollo statements keep a stored 10% while others follow the setting.

## 10.5 Defects observed in the prototypes (must not be carried into production)
1. **DEF-01** New Appointment date defaults to yesterday in Indian time (UTC conversion bug); such bookings are hidden by the default filter, get no token and never enter the queue.
2. **DEF-02** Booking two or more consultations for a new patient creates a separate MR number and patient record per consultation.
3. **DEF-03** Undo check-in keeps an online patient's token, so they remain in the waiting queue contrary to the dialog text.
4. **DEF-04** Call Next while a patient is being served silently returns that patient to the queue instead of completing or skipping.
5. **DEF-05** Online receipts print "Payment Mode: Cash"; receipt numbers are non-unique and regenerate on every view.
6. **DEF-06** Editing the department of a paid appointment re-prices it with only a warning; reinstating a refunded walk-in offers a token without payment.
7. **DEF-07** Weekly-hours edits for doctors and departments are discarded on save; the department hours text never updates.
8. **DEF-08** Deleting a custom role has no confirmation and leaves users with a dangling role.
9. **DEF-09** Invoice CGST/SGST rounding can exceed the invoice total by ₹1; the invoice shows the hospital's current plan rather than the plan at invoice time.
10. **DEF-10** The Compliance Logs module filter omits "Notifications" although those actions are logged; a paused banner past its end date shows "Paused".
11. **DEF-11** Unknown record ids (patient, doctor, appointment, hospital, invoice, payment, platform user) show the first record instead of "not found".
12. **DEF-12** Mobile: hardware back on authentication screens may exit the app; the reschedule screen pre-selects "Today" regardless of the current date; the Home token card shows the newest booking rather than the next one; every doctor without a photo shows the initials "DR".
13. **DEF-13** Hospital settings are saved per browser, not per hospital account; the sidebar logo ignores the uploaded logo.
14. **DEF-14** The mobile release build declares no internet permission and uses template application identifiers.


# 11. Open Questions for the Client (to be settled in the Final FRD)

## 11.1 Scope decisions
1. **OQ-01** Settlements: keep the in-app settlement workflow built in the prototypes (statements, release recording with UTR, payout runs, hospital confirmation) or follow the Preliminary FRD (outside the application, helper reports only)? If kept, is it a Change Request?
2. **OQ-02** Which of the "beyond FRD" features in Section 10.2 (XTRA-01 to XTRA-15) are in scope for the Final FRD, and which are deferred?
3. **OQ-03** Which of the absent FRD features (documents library, insurance locker, ambulance button, emergency contacts, WhatsApp notifications, add-to-calendar, token card download, coupons/convenience fee) remain in scope for the first release?
4. **OQ-04** Hospital roles: confirm the two built-in roles (Receptionist, Administrator), whether hospital-defined custom roles with granular permissions are required, and whether the Quote's "Staff" role maps to Receptionist.
5. **OQ-05** Console roles: confirm the four internal roles and that the permission matrix must be enforced per endpoint; who may manage internal users.

## 11.2 Booking, slots and tokens
6. **OQ-06** Discovery: is location → hospital → department → doctor mandatory (FRD), or is the prototype's department-first flow acceptable? Is a hospital selector required in the app?
7. **OQ-07** Slot model: slot size, buffer, capacity per slot, doctor sessions/shifts, leave and per-date exceptions, hospital/department/doctor hour precedence, booking horizon (the app shows five days), cut-off for same-day past slots, and open/block/bulk operations for staff.
8. **OQ-08** Slot hold: hold duration during payment, behaviour on failure/timeout, and whether "Pay at Hospital" bookings are held until counter confirmation and for how long.
9. **OQ-09** Token scheme: per doctor per date (FRD) or hospital-wide (prototype)? Format and zero-padding; daily reset; issue moment (payment success vs booking vs check-in); whether online same-day bookings queue before check-in; whether cancellation or undo check-in frees a token.
10. **OQ-10** Queue rules: skip limits, automatic no-show after the grace period, behaviour of Call Next while a patient is being served, break handling, priority/emergency lanes, and the patient-facing "current token / last called / estimated wait" feed.
11. **OQ-11** Multi-consultation bookings (several doctors in one visit, one payment): required or not?

## 11.3 Money
12. **OQ-12** Fee composition for online bookings: consultation fee, taxes/GST, convenience fee, coupons; who bears GST; receipt content and numbering; GST details on patient receipts.
13. **OQ-13** Refund slab policy for online cancellations (amounts by cut-off), desk refund rules, partial refunds, refund references, and visibility of refund status to the patient.
14. **OQ-14** Commission: rate (10% default?), whether it is snapshotted per statement, cancellation fees kept by Medibook, and treatment of walk-ins (excluded).
15. **OQ-15** Statement cadence and boundaries (weekly Wednesday–Tuesday with expected date +4 days in the sample), what counts (completed online appointments only?), overdue definition, payout failure handling, partial-release balance tracking, payout schedule options.
16. **OQ-16** Subscription billing: yearly plans, invoice generation date and due days, GST-inclusive vs exclusive pricing, CGST/SGST vs IGST by state, reminders, grace period and auto-suspension, online payment of invoices, proration on plan change.
17. **OQ-17** Quota: which bookings consume it, reset date, thresholds for warnings and alerts, behaviour when exhausted.

## 11.4 Identity, security and privacy
18. **OQ-18** Patient identity: mobile number vs email as the login id; OTP length and expiry; social sign-in providers (Google/Facebook/X buttons exist); remember-me policy; biometric login.
19. **OQ-19** Patient account deletion policy, data retention for bookings/documents, consent defaults (blood-donation consent is on by default), notification opt-ins.
20. **OQ-20** Staff onboarding: invite flows (email link / mobile OTP / temporary password), password policy, 2FA for hospital admins, session timeout, "cannot deactivate self / last admin" rules.
21. **OQ-21** Console access to patient data: PII masking for Support/Auditor roles, reason capture on block/unblock, export and anonymisation requests.

## 11.5 Content and communications
22. **OQ-22** Notifications: channels (in-app, push, WhatsApp, SMS), events (confirmation, reminders day-before/day-of, reschedule, cancel, queue calls, settlement and quota alerts), templates with placeholders, who can trigger them, retry policy.
23. **OQ-23** Banners: platform-managed only (console) or also hospital-published (FRD); rotation rules; image constraints and hosting; links/deep links; hospital-specific targeting.
24. **OQ-24** Push campaigns: provider, audience definitions ("Inactive 30+ days"), send time (fixed 09:00?), editing/cancelling queued sends, metrics.
25. **OQ-25** Support tickets: lifecycle (open → in progress → resolved), replies visible to the hospital, SLA.

## 11.6 Data and reporting
26. **OQ-26** Report definitions: for each of the 14 hospital reports and 6 console reports, the dataset, columns, filters, date presets, formats (CSV/PDF/XLSX), scheduling and retention; which reports are settlement "helper reports".
27. **OQ-27** Patient records: source of lab records/prescriptions (hospital upload? lab integration?), file types and sizes, linking to appointments, sharing links, and the hospital-side "no clinical data" principle.
28. **OQ-28** Master data reconciliation: single department and doctor catalogue per hospital exposed to the app; numeric fee/experience fields; doctor status semantics (hidden/paused/live); department deactivation effects.
29. **OQ-29** Audit event catalogue: confirm the events in Appendix C plus hospital-side events, booking transitions and message attempts; retention (365 days shown); export for BI.
30. **OQ-30** Locale: single timezone (Asia/Kolkata), English only or multilingual, accessibility requirements (the mobile app disables system font scaling).

## 11.7 Delivery
31. **OQ-31** Confirm the client prerequisites in Agreement 7.4 (Play Store, Apple Developer, Razorpay, Firebase, CDN, WhatsApp provider) and the target application identifiers, names, icons and store listings.
32. **OQ-32** Confirm the recommended server specification tied to the performance benchmarks in Agreement 10.3.


# Appendix A. Screen and Route Inventory

## A.1 Patient Mobile App (16 screens, 2 overlays)
| # | Screen | Route | Reached from | Notes |
|---|---|---|---|---|
| 1 | Login | `/login` | app start; logout; sign-up "Log In"; reset done | initial screen |
| 2 | Create Account | `/signup` | Login "Sign up" | |
| 3 | Reset Password (forgot) | `/forgot` | Login "Forgot password?" | |
| 4 | Verify Code | `/verify?email=` | Send Code | fixed OTP 1234 |
| 5 | New Password | `/reset` | Verify | |
| 6 | Home | `/home` (tab 1) | login; tabs | banner, token card, quick actions |
| 7 | Appointments | `/appointments` (tab 2) | tabs; cancel; booking back | Upcoming / Past |
| 8 | Records | `/records` (tab 3) | tabs; notification | 3 sample records |
| 9 | Profile | `/profile` (tab 4) | tabs; home avatar | logout / delete |
| 10 | Search | `/search` | home search pill | departments + doctors |
| 11 | Notifications | `/notifications` | bell on Home/Appointments/Records | 4 sample cards |
| 12 | Book Appointment (steps 1–4) | `/booking?step&dept&doctor&origin` | home tiles, search, appointments, doctor detail, book again | |
| 13 | Doctor Details | `/doctor/:id?return=` | booking step 2; search | |
| 14 | Booking Success | `/success?appt=` | Confirm and Pay | |
| 15 | Appointment Details | `/appointment/:id` | cards; token card; success; reschedule; notification | |
| 16 | Reschedule | `/reschedule/:id` | appointment details; notification | |
| — | Confirmation sheet | overlay | Logout, Delete account, Cancel appointment | |
| — | Toast | overlay | many actions | 2.3 s |

## A.2 Hospital Web App "mbAdmin" (14 views + 2 auth screens)
| # | View | URL | Receptionist | Administrator |
|---|---|---|---|---|
| 1 | Login | `/auth/login` | public | public |
| 2 | Forgot Password | `/auth/forgot` | public | public |
| 3 | Dashboard (Front Desk / Hospital Dashboard) | `/:role/dashboard` | ✔ | ✔ |
| 4 | Appointments | `/:role/appointments` | ✔ | ✔ |
| 5 | New Appointment | `/:role/appointments/new` | ✔ | ✔ |
| 6 | Patients | `/:role/patients` | ✔ | ✔ |
| 7 | Patient Profile | `/:role/patients/:mrn` | ✔ | ✔ |
| 8 | Token Management (Live Token Queue) | `/:role/token` | ✔ | ✔ |
| 9 | Payments | `/:role/payments` | ✔ | ✔ |
| 10 | Billing & Settlements (Settlements · Plan & Billing) | `/admin/settlements` | ✗ | ✔ |
| 11 | Doctors & Departments | `/admin/doctors` | ✗ | ✔ |
| 12 | Doctor Profile (view/create/edit) | `/admin/doctors/:id` | ✗ | ✔ |
| 13 | Users & Roles | `/admin/users` | ✗ | ✔ |
| 14 | Reports & Analytics | `/admin/reports` | ✗ | ✔ |
| 15 | Hospital Settings | `/admin/settings` | ✗ | ✔ |
| 16 | Help & Support | `/:role/help` | ✔ | ✔ |

Dialogs and panels: Appointment drawer; Record Payment; Record Payment (multiple); Receipt & Token; Receipt & Tokens; Cancel Appointment; Edit Appointment; Reschedule Appointment; Mark as No-show; Undo Check-in; Edit Patient; Add/Edit Department; Department panel; Remove Doctor / Delete Department / Delete Doctor Profile; Add User; User panel; Reset Password; Role editor; Confirm Transfer Received; Request Settlement; Raise Settlement Request; Request Plan Change; Raise a Support Ticket; notification bell; Switch Role menu.

## A.3 Operations Console (16 views)
| # | View | URL |
|---|---|---|
| 1 | Operations Dashboard | `/ops/dashboard` |
| 2 | Hospital Management | `/ops/hospitals` |
| 3 | Hospital Profile (Overview · Departments · Doctors · Billing & Settlements · Activity) | `/ops/hospitals/:id` |
| 4 | Subscription Plans | `/ops/plans` |
| 5 | Billing (Invoices · Payments) | `/ops/billing?tab=` |
| 6 | Invoice Detail | `/ops/billing/invoices/:id` |
| 7 | Payment Detail | `/ops/billing/payments/:id` |
| 8 | Hospital Settlements (By Payout Run · Flat List) | `/ops/settlements` |
| 9 | Usage Analytics | `/ops/analytics` |
| 10 | Reports | `/ops/reports` |
| 11 | Compliance Logs | `/ops/logs` |
| 12 | Users & Roles (internal) | `/ops/users` |
| 13 | Platform Users | `/ops/platform-users` |
| 14 | Patient Account | `/ops/platform-users/:id` |
| 15 | Notifications (App Banners · Push Notifications) | `/ops/notifications` |
| 16 | Platform Settings | `/ops/settings` |

Dialogs: Onboard Hospital; Approve this hospital?; Suspend/Reactivate this hospital?; Reject this hospital?; Create/Edit Plan; Delete this plan?; Record Settlement Release; Record Run Release; Add User (internal); Delete this user?; Block/Unblock this account?; Add/Edit Banner; Edit Default Banner; Delete this banner?; Send/Schedule this notification?; notification bell; account menu.


# Appendix B. Sample Data Reference (what the prototypes are seeded with)

The sample data defines the vocabulary the client has already seen in demos. It is listed here so that test data, migrations and acceptance scenarios can reuse it, and so that seed-only states (statuses no code produces) are recognisable.

## B.1 Patient mobile app
1. **Account holder:** Alexandra Johnson · alexandra.johnson@example.com · +91 98456 58525 · born 15/05/1997 · Female · blood group O+ · donation consent on.
2. **Family:** Alexandra Johnson (29 years · Female · Self), Michael Johnson (34 years · Male · Husband), Ava Johnson (6 years · Female · Daughter).
3. **Departments:** General ("Primary healthcare"), Cardiology ("Heart specialists"), Orthopedics ("Bone & joint care"), Dermatology ("Skin specialists").
4. **Doctors:** Dr. Anya Sharma (Cardiology, Head of Cardiology, 12 yrs, 6,000+ patients, 4.8, ₹900, Apollo Hospital, photo); Dr. Rohan Kapoor (Cardiology, 8 yrs, 3,200+, 4.6, ₹700, City Care Clinic); Dr. Anil Kumar (General, Senior General Physician, 15 yrs, 9,500+, 4.7, ₹500, Apollo Hospital); Dr. Meera Nair (General, 6 yrs, 2,100+, 4.5, ₹450, City Care Clinic); Dr. Priya Mehta (Orthopedics, Lead, Day-care Orthopedics, 10 yrs, 4,800+, 4.9, ₹800, Apollo Hospital); Dr. Sara Ali (Dermatology, 7 yrs, 2,900+, 4.6, ₹650, City Care Clinic).
5. **Time slots:** 09:00 AM, 10:00 AM, 11:30 AM, 12:15 PM, 02:00 PM, 04:30 PM.
6. **Appointments:** Today 10:30 AM Dr. Priya Mehta for Alexandra, token A-25, Confirmed; 12 Aug 2026 09:00 AM Dr. Anil Kumar for Michael, A-12, Confirmed; 21 Jul 2026 11:30 AM Dr. Anya Sharma for Alexandra, A-08, Completed; 02 Jun 2026 02:00 PM Dr. Anil Kumar for Ava, A-19, Cancelled. Next token A-26.
7. **Records:** Blood Test Report (10 Jul 2026, Completed, Alexandra, Apollo Hospital, Dr. Anil Kumar); Full Body Checkup (02 Jul 2026, Pending, Michael, Apollo Hospital, Dr. Meera Nair); Lipid Profile (21 Jun 2026, Completed, Alexandra, City Care Clinic, Dr. Rohan Kapoor).
8. **Notifications:** Fasting Reminder; Appointment Reminder (Dr. Priya Mehta, today 10:30 AM); Prescription Ready (Dr. Anil Kumar); Vaccination Due (Ava).
9. **Banners:** "Want to see a doctor today?" / "Schedule your appointment in just a tap."; "Lab tests at home" / "Book a sample collection slot now."

## B.2 Hospital web app (Apollo Hospital, Bengaluru; tenant 13)
1. **Hospital:** Apollo Hospital · KA-HOSP-20194 · GSTIN 29AAACA4033H1Z5 · 080 4567 8900 · contact@apollo.med · 154 Bannerghatta Road, Bengaluru 560076 (12.9088, 77.5975) · HDFC Bank 50200048112233 / HDFC0001234 / apollohospital@hdfcbank · open 8:00 am–8:00 pm Mon–Sat · plan Growth.
2. **Booking roster (fixed):** Cardiology ₹800 — Dr. Thomas K. (room 101), Dr. Anil R. (102); Orthopedics ₹700 — Dr. Geetha R. (201); Pediatrics ₹600 — Dr. Kumar V. (301); Neurology ₹1,000 — Dr. Maya S. (401); ENT ₹500 — Dr. Arun B. (501); Dermatology ₹650 — Dr. Leela P. (601).
3. **Catalogue departments:** the same six, with Dermatology Inactive; hours "Mon–Sat · 9am–6pm" style texts.
4. **Catalogue doctors:** the same seven with ratings 4.4–4.9, reviews 38–142, Dr. Kumar V. On Leave (10–16 Jun "Medical leave"), leaves for Dr. Thomas K. (18–20 Jun "Conference") and Dr. Geetha R. (25 Jun "Personal").
5. **Appointments (12, ids AP1000–AP1011):** eleven today and one tomorrow; six online, six walk-in; tokens T-001 to T-007 issued; two In Queue being served (T-003 Dr. Geetha R., T-002 Dr. Kumar V.); one Completed (Imran Sheikh, ENT); one No-show (Nisha Roy); one Cancelled/Refunded (Daniel Joseph); four payments pending; next token T-008.
6. **Patients (12):** one per appointment, MR numbers AP847201–AP847212 (Ellen Kinderson, John Miller, Maya Rao, Arun Patel, Sara Iqbal, Vikram Das, Nisha Roy, Imran Sheikh, Priya Nair, George Thomas, Fatima Begum, Daniel Joseph), phones 9876543210–21, Bengaluru addresses, all Active.
7. **Staff:** Dr. S. Nair (Administrator), Riya Menon and Karthik Rao (Reception / Billing), Sunita Joseph (Department Front Desk), Mahesh Pillai (Department Front Desk, invite Pending), Anand Pillai (Accountant), Fatima Sheikh (Department Front Desk, Inactive). Roles: Administrator, Reception / Billing, Department Front Desk, Accountant.
8. **Settlements (14):** MB-ST-2393 to MB-ST-2406, weekly periods 11 Mar–16 Jun 2026, gross ₹87,200–₹1,08,200; MB-ST-2406 Pending (expected 20 Jun), MB-ST-2405 Overdue (13 Jun), MB-ST-2404 Released (UTR26-2404K), the rest Received.
9. **Plan page:** Growth ₹24,999/month, 3,120 of 5,000 bookings used, invoices INV-2026-0244/0219/0198.

## B.3 Operations console
1. **Hospitals (13):** 1 Sunrise Multispeciality (Pune, Growth, 4,280 bookings, Active); 2 Lotus Heart Institute (Chennai, Enterprise, 6,120, Pending verification); 3 Kaveri General Hospital (Mysuru, Starter, 1,240, Active, no bank); 4 Nirmal Ortho & Spine (Indore, Growth, 2,860, Suspended); 5 Ashwini Children's Care (Kochi, Starter, 980, Pending verification, GST certificate missing); 6 Meridian City Hospital (Mumbai, Enterprise, 7,450, Active); 7 Vasudha Medical Centre (Hyderabad, Growth, 3,320, Active); 8 Trinity Care & Research (Bengaluru, Custom — Trinity Care, 5,210, Active); 9 Girnar Multispeciality (Rajkot, Starter, 860, Suspended); 10 Padma Eye Foundation (Vijayawada, Starter, 640, Rejected — "Incomplete KYC documents"); 11 Himgiri Wellness Hospital (Dehradun, Growth, 1,980, Active); 12 Charak Institute of Medicine (Lucknow, Enterprise, 4,890, Pending verification); 13 Apollo Hospital (Bengaluru, Growth, 3,120, Active, onboarded April 12, 2025).
2. **Plans (4):** Starter ₹9,999 / 1,500; Growth ₹24,999 / 5,000 (Most Popular); Enterprise ₹49,999 / 8,000; Custom — Trinity Care ₹59,999 / 10,000.
3. **Plan changes (4):** Vasudha Starter → Growth (Completed); Charak Growth → Enterprise (Pending); Padma Growth → Starter (Completed); Girnar Starter → Growth (Cancelled).
4. **Invoices (15):** INV-2026-0231 to 0244 plus Apollo's 0198 and 0219; 9 Completed, 3 Pending, 2 Overdue, 1 Payment failed. **Payments (11):** TXN-88077 to TXN-88501; 7 Success, 2 Pending, 2 Payment failed; methods UPI / Card / NetBanking.
5. **Console settlements (8, non-Apollo):** MB-ST-2408 Meridian, 2409 Trinity, 2411 Lotus, 2415 Kaveri (Pending, expected 20 Jun); 2410 Sunrise (Released, partial ₹80,000, "Part release — balance held pending dispute #418."); 2413 Charak (Payout failed); 2412 Vasudha and 2414 Himgiri (Received).
6. **Alerts (3):** Settlement failure — Lotus Heart Institute; Plan limit reached — Kaveri General; Compliance log gap — Nirmal Ortho. **Requests (1):** Support ticket from Sunrise Multispeciality — "unable to update doctor schedule".
7. **Internal users (7):** Riya Sharma, Anil Kapoor (Super Admin); Meera Pillai, Nisha Verma (Finance Admin); Dev Trivedi, Kavya Reddy (Support); Sameer Joshi (Auditor).
8. **Patient accounts (8):** Aarav Mehta (Mumbai; family Rhea, Kabir, Suresh Mehta), Sana Qureshi (Hyderabad; Imran Qureshi), Vikram Rao (Bengaluru; Lakshmi Rao + one more), Meera Nair (Kochi, Blocked), Rohit Bansal (Delhi), Ananya Iyer (Chennai), Farhan Sheikh (Pune, Blocked), Divya Kulkarni (Nagpur).
9. **Banners:** default "Book trusted doctors near you — Medibook"; Monsoon Health Camp (Live); Free tele-consult week (Scheduled); World Yoga Day (Paused); Summer vaccination drive (Expired). **Pushes:** "20% off health checkups" (Sent); "Live queue updates are here" (Sent, Android); "Father's Day heart camp" (Scheduled 21 Jun 2026).
10. **Compliance log (10 seed entries):** see Appendix C.2. **Platform settings:** Medibook · support@medibook.in · 1800 220 440 · Weekly payouts · 10% commission · GSTIN 27AABCM9407L1ZK · 2FA required · 30-minute session.


# Appendix C. Audit-Event Catalogue

## C.1 Events the console writes today (fixed actor riya.sharma@medibook.in, IP 10.42.8.11, time "Just now")
| # | Module | Severity | Event text (template) | Trigger |
|---|---|---|---|---|
| 1 | Hospitals | Info | Hospital onboarded — <name> | Onboard Hospital |
| 2 | Hospitals | Info | Hospital approved — <name> | Approve & Go Live / Re-review & Approve |
| 3 | Hospitals | Critical | Hospital rejected — <name> | Reject with reason |
| 4 | Hospitals | Critical | Hospital suspended — <name> | Suspend Instance |
| 5 | Hospitals | Critical | Hospital reactivated — <name> | Reactivate Instance |
| 6 | Subscription Plans | Info | Plan created — <name> | Create Plan |
| 7 | Subscription Plans | Info | Plan updated — <name> | Save Plan |
| 8 | Subscription Plans | Critical | Plan deleted — <name> | Delete Plan |
| 9 | Subscription Plans | Info | Plan change applied — <hospital>: <from → to> | Approve plan change |
| 10 | Subscription Plans | Info | Plan change declined — <hospital>: <from → to> | Decline plan change |
| 11 | Settings | Info | Settings updated — platform preferences | Save Changes (Platform Settings) |
| 12 | Notifications | Info | Default app banner updated | Save default banner |
| 13 | Notifications | Info | App banner updated — <title> | Save banner (edit) |
| 14 | Notifications | Info | App banner added — <title> | Add Banner |
| 15 | Notifications | Warning | App banner deleted — <title> | Delete Banner |
| 16 | Notifications | Info | App banner paused — <title> / App banner resumed — <title> | Pause / Resume |
| 17 | Notifications | Warning | Push notification sent — “<title>” to <audience> | Send Now |
| 18 | Notifications | Warning | Push notification scheduled — “<title>” to <audience> | Schedule |
| 19 | Notifications | Info | Scheduled push cancelled — “<title>” | Cancel scheduled push |
| 20 | Platform Users | Critical | Patient account blocked — <email> / unblocked — <email> | Block / Unblock |
| 21 | Platform Users | Info | Patient account viewed — <email> | Open a patient account from the list |
| 22 | Settlements | Info | Settlement release recorded — <statement> · ₹<amount> to <hospital> | Record Release |
| 23 | Settlements | Info | Payout run recorded — <date> · <n> statements · ₹<total> | Record Run Release |

## C.2 Event types present only in sample data (no code writes them)
1. Users & Roles — "Role permissions changed — Finance Admin" (Critical).
2. Auth — "Failed login attempt (3x)" (Warning, actor "unknown@23.94.61.2").
3. Billing — "Invoice regenerated — INV-2026-0234" (Info).
4. Platform Users — "Platform user deleted — dev.trivedi@gmail.com" (Critical).
5. Reports — "Data export — bookings FY 2025-26" (Warning).
6. Media — "Media purged — 214 orphaned files" (Warning, actor system@medibook.in).
7. Settings — "API key rotated — payments gateway" (Info); "Settings updated — payout schedule" (Info).
8. Settlements — "Settlement released — ₹ 1,28,250" (Info).

## C.3 Events the contract requires that nobody writes
1. Staff login/logout and failed attempts (hospital and console); password resets; invite acceptance; 2FA changes.
2. Hospital-side configuration changes (settings, bank details, working hours, rules, notification preferences), catalogue changes (departments, doctors, leave), role and user changes.
3. Booking state transitions (created, checked in, called, skipped, completed, no-show, cancelled, reinstated, edited, rescheduled), payments, refunds, receipt prints.
4. Outbound message attempts and delivery results (push, WhatsApp, SMS); payment-gateway callbacks and failures.
5. Console actions currently unlogged: internal user add/delete, API-key rotation, report and invoice downloads, alert resolution, settlement request handling, hospital "Mark Received".


# Appendix D. User-Facing Message Catalogue

Messages are quoted verbatim. Toasts are transient confirmations; validation messages appear under fields or as red toasts; confirmations are dialog titles and bodies.

## D.1 Patient mobile app
### Validation
1. "Enter a valid email address" · "Enter your password" · "At least 6 characters" · "Enter your name" · "Passwords do not match" · "Incorrect code — the demo code is 1234".
### Toasts
2. "Welcome to Medibook, <first name>!" · "Code sent to <email>" · "Code re-sent to <email>" · "Password reset — please log in".
3. "All notifications marked as read" · "That appointment was cancelled" · "Downloading prescription…" · "We'll remind you tomorrow".
4. "Appointment cancelled" · "Appointment rescheduled".
5. "<record title> — preview stubbed in this demo" · "Downloading <record title>…".
6. "Profile editing is stubbed in this demo" · "You are now available for donation" · "Donation availability turned off" · "Account deletion is stubbed in this demo".
### Confirmation sheets
7. "Logout" — "Are you sure you want to log out?" — Cancel / Yes, Logout.
8. "Delete Account" — "This will permanently remove your records and appointments." — Cancel / Yes, Delete.
9. "Cancel Appointment" — "Are you sure you want to cancel your appointment with <doctor>?" — Cancel / Yes, Cancel.
### Static notes
10. "Payment is collected at the hospital desk." · "You can reschedule up to 2 hours before your slot." · "Please arrive 15 minutes early and carry any previous reports." · "Tap a doctor to view details and book" · "No matches for “<query>”" · "No upcoming appointments" / "No past appointments" · "Appointment not found." · "Demo login is prefilled — just tap Log In." · "Demo code: 1234".

## D.2 Hospital web app
### Login and recovery
1. "Enter your email and password to continue." · "Enter a valid email address." · "This hospital's Medibook instance is suspended by operations. Contact support@medibook.in to reactivate." · "Check your inbox" / "We've sent a password reset link to <email>. The link expires in 30 minutes."
### Appointments, queue and payments
2. "<patient> checked in · Token <token>" · "Payment recorded · Token <token> issued" · "Payment recorded · <n> token(s) issued" · "Token <token> issued for <patient>" · "Appointment cancelled · desk refund recorded" · "Appointment cancelled" · "Marked as no-show" · "Appointment rescheduled" · "Appointment updated" · "Check-in undone · back to Scheduled" · "Reverted to Scheduled" · "Now consulting <token> · <patient>" · "<token> completed" · "<token> skipped · moved to the end of the queue" · "No one waiting for <doctor>" · "No active patient for <doctor>" · "No patient is being seen".
3. "Select department and doctor" · "Select a patient and at least one department + doctor" · "Online appointment saved" · "<n> online appointments saved" · "Exported medibook-payments.csv".
4. Confirmations: "Mark as No-show" — "Mark <patient> as a no-show? You can undo this afterwards."; "Undo Check-in" — "Send <patient> back to Scheduled and remove their token from the queue?"; Cancel dialog — "Cancel the appointment for <patient> with <doctor>?" with the online/desk refund notes quoted in §4.4.7.
### Patients, doctors, users
5. "Name and phone are required" · "Patient added" · "Patient details updated" · "Department name is required" · "Department added" · "Department updated" · "Doctor name is required" · "Assign at least one department" · "Doctor added" · "Doctor profile saved" · "Doctor profile deleted" · "Doctor removed" · "Department deleted" · "Add shift — demo" · "Shift removed" · "Add leave — demo" · "Leave removed" · "Image upload — demo" · "Photo added".
6. "Name, email and role are required" · "Email invite sent" · "OTP sent for confirmation" · "User created with password" · "User deactivated" · "User activated" · "Edit user — demo" · "Invite resent" · "Reset link sent to <email>" · "OTP sent to <phone>" · "Temporary password set" · "Give the role a name" · "Role "<name>" created" · "Role updated" · "Role deleted".
7. Confirmations: "Remove Doctor" / "Delete Department" — "Are you sure you want to remove/delete <name>? This can't be undone."; "Delete Doctor Profile" — "Delete <name>'s profile? This removes them from the patient app and can't be undone."
### Settlements, plan, reports, settings, help
8. "Marked as received" · "Follow-up raised with Medibook for the overdue transfer" · "Settlement requested from Medibook" · "Exported medibook-settlements.csv" · "Pick the plan you want" · "Plan change request sent to Medibook" · "Exported <report>-report.csv" · "Preparing PDF…" · "Settings saved" · "Ticket raised with Medibook support" · "All caught up".
9. Confirmations: "Confirm Transfer Received" — "Confirm the hospital has received the bank transfer for <statement>."; "Raise Settlement Request" — "This settlement is overdue. Raise a follow-up request with Medibook for <statement>."; "Request Settlement" — "Request Medibook to release the settlement for <statement>."
### Error card
10. "This screen hit a snag" — "Something didn't load right. You can retry, or head back to the dashboard — your data is safe."

## D.3 Operations console
### Hospitals and plans
1. "Hospital name is required." · "Enter a valid email address." · "City is required." · "<name> onboarded. KYC verification pending." · "Cannot approve — <documents> not received." · "<name> approved and live." · "<name> suspended." · "<name> reactivated." · "<name> rejected. The hospital has been notified."
2. "Plan name is required." · "A plan with this name already exists." · "Enter a monthly price." · "Enter a monthly booking quota." · "Plan "<name>" created." · "Plan "<name>" updated." · "Plan deleted." · "<n> hospital(s) is/are on this plan — move them to another plan first." · "Plan change applied — <hospital> moved to <plan>." · "Plan change declined for <hospital>."
3. Confirmations: "Approve this hospital?" — "<name> goes live immediately and can start taking bookings on Medibook."; "Suspend this hospital?" — "<name> staff lose access immediately. Existing bookings are kept, but no new bookings can be made until reactivation."; "Reactivate this hospital?" — "<name> regains access immediately and can take new bookings right away."; "Reject this hospital?" — "<name> is notified by email and cannot take bookings. This decision is final."; "Delete this plan?" — ""<name>" is removed from the catalog. No hospitals are on it, so nothing else changes."
### Billing, settlements, reports, alerts
4. "Invoice <no> downloaded." · "No payout account on file for <hospital> — the hospital adds it under Hospital Settings." · "Enter the released amount." · "Enter the bank transfer reference." · "Release recorded — visible to <hospital>." · "Payout run recorded — <n> settlement(s) released." · "<Report> ready." · "Alert resolved".
### Users, patient accounts, notifications, settings
5. "Full name is required." · "<name> added." · "User deleted." · "Edit user — demo" · "<name> blocked." · "<name> unblocked." · "Give the banner a title." · "Set a start date." · "Set an end date on or after the start." · "Banner added — it goes live on its start date." · "Banner updated." · "Default banner saved." · "Banner deleted." · "Add a title." · "Add a message." · "Pick a date." · "Notification queued for delivery." · "Notification scheduled." · "Scheduled notification cancelled." · "Enter a value between 0 and 100." · "GST number must be 15 characters." · "Settings saved." · "API key rotated. Update your gateway config."
6. Confirmations: "Delete this user?" — "This permanently removes <name> and their access. You won't be able to recover it later."; "Block this account?" — "Existing upcoming bookings are unaffected. <name> cannot make new bookings until unblocked."; "Unblock this account?" — "<name> can make new bookings again immediately."; "Delete this banner?" — "“<title>” is removed from the app immediately. This cannot be undone."; "Send this notification now?" / "Schedule this notification?" — "“<title>” goes to <audience> (~<n> users) [on <date> at 09:00]. Push notifications can't be recalled after delivery."


# Appendix E. Requirement Traceability Matrix

Status: **Present** · **Partial** · **Absent** · **Backend** (no UI expectation) · **Excluded** (Agreement 2.5) · **n/a** (commercial clause).

## E.1 Preliminary FRD — Customer Mobile App
| ID | Requirement (short) | Status | Where in this document |
|---|---|---|---|
| CM-01 | Registration fields | Partial | 3.2.2, GAP-001 |
| CM-02 | Accept policies | Partial | 3.2.2, GAP-002 |
| CM-03 | Mobile OTP activation | Absent | GAP-003 |
| CM-04 | Login by mobile + password | Absent | 3.2.1, GAP-004 |
| CM-05 | Lockout / throttling | Absent | GAP-005 |
| CM-06 | Forgot password via mobile OTP | Partial | 3.2.3–3.2.5, GAP-006 |
| CM-07 | Home brand, configurable banners, notifications | Partial | 3.3, 3.5, GAP-010 |
| CM-08 | Home / Services / Profile navigation | Partial | 3.1.2, GAP-011 |
| CM-09 | Live token widget | Partial | 3.3, GAP-012 |
| CM-10 | Location → hospital list | Absent | GAP-013 |
| CM-11 | Hospital → departments → doctors | Partial | 3.6.2–3.6.3, GAP-014 |
| CM-12 | Calendar and bookable slots | Partial | 3.6.4, GAP-015 |
| CM-13 | Booking summary with fee components | Partial | 3.6.5, GAP-016 |
| CM-14 | Booking ID + token on payment | Partial | 3.6.6, GAP-017 |
| CM-15 | Token card download, add to calendar | Absent | 3.8, GAP-018 |
| CM-16 | Dependents with health flags | Partial | 3.6.4, GAP-019 |
| CM-17 | In-app payment methods | Absent | GAP-020 |
| CM-18 | Pay at Hospital option | Partial | GAP-021 |
| CM-19 | Amount breakdown before payment | Partial | GAP-016 |
| CM-20 | Payment order / hold / retry | Absent | GAP-020 |
| CM-21 | Digital receipts with GST | Absent | GAP-022 |
| CM-22 | Refund status | Absent | GAP-022 |
| CM-23 | Razorpay | Absent | GAP-020 |
| CM-24 | Live token progress | Absent | GAP-012 |
| CM-25 | Cancel within cut-off | Partial | 3.10, GAP-023 |
| CM-26 | Reschedule per policy | Partial | 3.11, GAP-023 |
| CM-27 | Token card view/download | Absent | GAP-018 |
| CM-28 | Appointment filters | Partial | 3.9, GAP-024 |
| CM-29 | Details with payment status, receipt, documents | Partial | 3.10, GAP-025 |
| CM-30 | Search appointments | Absent | 3.4, GAP-026 |
| CM-31 | Book again | Present | 3.10 |
| CM-32 | Documents library | Absent | 3.12, GAP-027 |
| CM-33 | Add files from device | Absent | GAP-027 |
| CM-34 | Document fields | Absent | GAP-027 |
| CM-35 | Filter / view documents | Absent | GAP-027 |
| CM-36 | Secure links and sharing | Absent | GAP-027 |
| CM-37 | Insurance locker | Absent | GAP-028 |
| CM-38 | Renewal reminders, default policy | Absent | GAP-028 |
| CM-39 | Reference-only insurance | Absent | GAP-028 |
| CM-40 | WhatsApp + in-app + push confirmation | Absent | GAP-029 |
| CM-41 | Reminders | Absent | GAP-029 |
| CM-42 | Reschedule/cancel notices | Absent | GAP-029 |
| CM-43 | Retry, unread persistence | Absent | GAP-029 |
| CM-44 | Call Ambulance | Absent | GAP-030 |
| CM-45 | Location in emergency message | Absent | GAP-030 |
| CM-46 | Ambulance from home/details | Absent | GAP-030 |
| CM-47 | Edit profile, phone re-verify | Absent | 3.13, GAP-007 |
| CM-48 | Manage dependents | Absent | GAP-019 |
| CM-49 | Emergency contacts | Absent | GAP-031 |
| CM-50 | Update address | Absent | GAP-031 |
| CM-51 | Change password after OTP | Absent | GAP-007 |
| CM-52 | Privacy, Terms, FAQs, Support | Absent | GAP-032 |
| CM-53 | Logout clears tokens/push | Partial | GAP-008 |
| CM-54 | OTP-gated deletion | Partial | GAP-009 |

## E.2 Preliminary FRD — Hospital Admin Web
| ID | Requirement | Status | Where |
|---|---|---|---|
| HA-01 | Login + OTP reset | Partial | 4.2, GAP-033 |
| HA-02 | Dashboard KPIs and token boards | Partial | 4.3, GAP-034 |
| HA-03 | Profile, branches, hours, holidays, banners | Partial | 4.12, GAP-035 |
| HA-04 | Departments and services with pricing/taxes/coupons | Partial | 4.9.4, GAP-036 |
| HA-05 | Doctor profiles | Present | 4.9.3 |
| HA-06 | Days, sessions, slot size, buffer | Partial | 4.9.3, GAP-037 |
| HA-07 | Leaves and exceptions | Partial | 4.9.3, GAP-037 |
| HA-08 | Slot generation and control | Absent | GAP-038 |
| HA-09 | Appointments desk actions | Partial | 4.4, GAP-039 |
| HA-10 | Print/download token cards and receipts | Partial | 4.4.10, GAP-040 |
| HA-11 | Trigger confirmations/reminders, banners | Absent | GAP-041 |
| HA-12 | Message templates | Absent | GAP-041 |
| HA-13 | Reports with exports | Partial | 4.11, GAP-042 |

## E.3 Preliminary FRD — Super Admin Web
| ID | Requirement | Status | Where |
|---|---|---|---|
| SA-01 | Onboard/activate/suspend; provision admin; defaults | Partial | 5.3, GAP-045 |
| SA-02 | Plans with feature limits | Partial | 5.4, GAP-046 |
| SA-03 | Invoices, payments, grace, auto-suspend | Partial | 5.5, GAP-047 |
| SA-04 | Settlement helper reports (outside app) | Partial / conflict | 5.6, 5.8, GAP-048, CONF-01 |
| SA-05 | Platform dashboards | Partial | 5.2, 5.7, GAP-049 |
| SA-06 | Access/config logs, export | Partial | 5.9, GAP-050 |

## E.4 Preliminary FRD — Platform
| ID | Requirement | Status | Where |
|---|---|---|---|
| X-01 | Users, auth, JWT, RBAC | Absent (UI data only) | 4.10, 5.10, GAP-044 |
| X-02 | Slot hold, anti-double-booking | Absent | GAP-051 |
| X-03 | Sequential token per doctor/date | Absent | GAP-052 |
| X-04 | Payment orders, webhooks, receipts, refund audit | Absent | GAP-053 |
| X-05 | Notification content | Absent | GAP-054 |
| X-06 | Performance | Backend | 9.5 |
| X-07 | Security | Backend | 9.4 |
| X-08 | Per-tenant policies | Partial | 4.12.4, GAP-055 |
| X-09 | Content and downloads | Partial | 5.12, GAP-056 |
| X-10 | Audit and supportability | Partial | 5.9, GAP-057 |
| X-11 | MVP exclusions | Excluded | 10.3 CONF-11 |
| X-12 | Deliverables | n/a | — |

## E.5 Quote
| ID | Requirement | Status | Where |
|---|---|---|---|
| Q-01 | Super Admin, Admins, Staff, Patients | Partial (Staff = Receptionist) | 2.2, OQ-04 |
| Q-02 | Patient functions | Partial | Section 3 |
| Q-03 | Staff/admin functions incl. filtered patient history | Partial | 4.5.3, 4.7, GAP-043 |
| Q-04 | Five modules | n/a | 2.5 |

## E.6 Agreement
| ID | Clause | Status | Where |
|---|---|---|---|
| AGR-01 | Components incl. Django/PostgreSQL backend | Absent (backend) | GAP-058 |
| AGR-02 | Final FRD binding | n/a | 0.1 |
| AGR-03 | UI/UX boundary → Change Requests | applies | 10.2 |
| AGR-04 | Exclusions | Excluded | 10.3 |
| AGR-05 | Module 1 architecture deliverables | this document is the input | 0.1 |
| AGR-06 | Timeline | n/a | — |
| AGR-07 | Client prerequisites | open | 9.7, OQ-31 |
| AGR-08 | Performance contingent on server | Backend | OQ-32 |
| AGR-09 | Unit testing only by provider | note: 30 UI tests exist in the mobile repo, none in the web repo | 3.14 |


