# Google Play Data Safety — Submission Runbook

**Status:** ACTIVE — copy-paste-ready answers for the Play Console Data Safety form (BUT-561).

**Cross-reference:** `ios/Runner/PrivacyInfo.xcprivacy` (BUT-568), `assets/legal/privacy_policy_{en,sv}.md` v1.3.0, `docs/ops/backups.md` (Firestore region, BUT-819).

This document is the authoritative answer set. Whenever any of the cross-references change (new SDK, new collection, new region), update this file *first* and re-submit the form.

> **Restored and re-verified 2026-08-25.** This file was deleted in `c79af46c5` (2026-06-24)
> as an "unreferenced ops runbook". The premise was wrong — it is referenced from
> `STORE_SUBMISSION_CHECKLIST.md`, `age-rating-runbook.md`, `app-review-demo.md` and
> `play-data-safety/README.md`. Every factual answer below was re-measured against the code
> on restore; the corrections are marked **(re-verified 2026-08-25)** inline. Items that could
> not be measured from a Windows workstation are marked as such rather than guessed.

---

## 0. How to use this runbook

1. Sign in to Play Console → Select Butlery → **App content** → **Data safety** → **Manage**.
2. Work through the four sections below in order. Each section maps 1:1 to a Play Console step.
3. Section 4 ("Security practices") is the same answer regardless of data type — fill once.
4. Save as draft after each step. Don't submit until Section 5 (verification checklist) passes.

---

## 1. Data Collection and Security (Step 1 of 4)

| Play Console question | Answer | Why |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes** | Account email, recipes, FCM tokens, analytics events, crash data — see Section 2. |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | All Firebase SDK traffic is HTTPS/TLS. Vertex AI calls go through Cloud Functions (also TLS). No plaintext network calls in `lib/`. |
| Do you provide a way for users to request that their data is deleted? | **Yes** | In-app: **Profile > Account Management > Delete account** (immediate, irreversible). Out-of-band: integritet@butlery.se **(re-verified 2026-08-25 — the address is `integritet@`, not `privacy@`; see `assets/legal/privacy_policy_sv.md:23`)**. Documented in privacy policy section 9.3. |
| Do you commit to following the [Play Families Policy](https://support.google.com/googleplay/android-developer/answer/9893335)? | **No** | Butlery's age floor is **15** (UGC + messaging). **(re-verified 2026-08-25 — was documented as 13+ / `birthYear > 2013`; that is stale.)** The gate is server-authoritative: `verifySignupAge` sets an `ageCompliant` custom claim, and `firestore.rules → isAgeCompliant()` requires `request.auth.token.ageCompliant == true`, failing CLOSED on a missing, false or stale claim (BUT-1386 / ADR-0002). Not a children's app. |

---

## 2. Data Types — what is collected and why

For each row below, in the Play Console **Data types** step:

1. Tick the box for the data type.
2. Select **Collected** (always Yes for us — we don't share with advertisers).
3. Select **Shared = No** for everything (we use processors, not third-party recipients — see §3).
4. Mark **Processing = Processed ephemerally** only where listed; otherwise **Not processed ephemerally** (i.e., stored).
5. Mark **Optional = Yes** for everything *except* Email Address, User ID, and User-generated content (those are required for the service per privacy-policy §4 contract basis).
6. Pick the purposes listed.

### 2.1 Personal info

| Play Console data type | Collected | Required | Purposes | Cross-ref (iOS) |
|---|---|---|---|---|
| **Name** | Yes (display name) | Optional | App functionality | `NSPrivacyCollectedDataTypeName` |
| **Email address** | Yes | **Required** | Account management, App functionality | `NSPrivacyCollectedDataTypeEmailAddress` |
| **User IDs** | Yes (Firebase Auth UID) | **Required** | App functionality, Account management, Analytics | `NSPrivacyCollectedDataTypeUserID` |
| **Address** | No | — | — | — |
| **Phone number** | No | — | — | — |
| **Race and ethnicity** | No | — | — | — |
| **Political or religious beliefs** | No | — | — | — |
| **Sexual orientation** | No | — | — | — |
| **Other personal info** | Yes (`birthYear` only — age gate, GDPR Art 8) | **Required** | App functionality (legal age verification) | Not in PrivacyInfo (not a separate Apple category — `birthYear` rolled into "Other user content" on iOS). **(re-verified 2026-08-25)** `birthYear` is dual-located — the private `users/{uid}/settings/preferences` doc *and* the profile doc — and is written ONLY by the `verifySignupAge` Cloud Function; `firestore.rules` makes it immutable to the client on both create and update (BUT-1386 / ADR-0002). Never in the public profile. |

### 2.2 Financial info

**None.** Butlery has no monetization yet — no payments, no purchase history, no credit info. Tick **No** across the row.

### 2.3 Health and fitness

**UNDECIDED — do not fill this row from memory. Malin decides it at filing time (her call, 2026-08-23).**

The two stores are answered differently today, and that asymmetry is not yet a decision:

- **iOS says YES.** `ios/Runner/PrivacyInfo.xcprivacy` declares
  `NSPrivacyCollectedDataTypeHealthAndFitness` for the allergen + dietary-preference data the
  user supplies at onboarding (BUT-811 / HIGH-LEGAL7). Apple's category is broad and explicitly
  covers dietary data.
- **This runbook has said NO** since it was written, on the argument that allergens are dietary
  *preferences*, not health data under Play's narrower definition.

Both readings are defensible; pick one when the form is actually filled in:

| Answer | Argument for | Cost |
|---|---|---|
| **No** (keep current) | Play's definition is narrower than Apple's; the two forms are separate declarations and may legitimately differ. | The Play answer rests on our own interpretation, and a reviewer comparing the two store listings sees an inconsistency. |
| **Yes** (match iOS) | Conservative — nobody can argue under-declaration, and the two listings agree. | Marks Butlery as collecting health data in the Play listing, which can pull in additional Play health-app policy requirements. |

Whichever is chosen, record the decision here and in §8 so the next filing does not re-open it.

**(re-verified 2026-08-25 — the restored file said a flat "None"; that contradicted the shipped iOS manifest, which is why the row is now explicitly open.)**

### 2.4 Messages

| Play Console data type | Collected | Required | Purposes | Cross-ref |
|---|---|---|---|---|
| **Emails** | No | — | — | We do not collect email message bodies. |
| **SMS or MMS** | No | — | — | — |
| **Other in-app messages** | Yes (recipe comments, direct messages, group chat, poll votes, pings) | Optional | App functionality | `NSPrivacyCollectedDataTypeOtherUserContent`. **(re-verified 2026-08-25 — the messaging surface grew well past "comments, group chat, pings".)** Stored in Firestore `recipe_comments/`, `conversations/{id}/messages/`, `chat_groups/`, `messages/{id}/poll_votes/`, `pings/{groupId}/pings/`. |

### 2.5 Photos and videos

| Play Console data type | Collected | Required | Purposes | Cross-ref |
|---|---|---|---|---|
| **Photos** | Yes (recipe images, heirloom OCR images, profile picture, cook snaps) | Optional | App functionality | `NSPrivacyCollectedDataTypePhotos`. **(re-verified 2026-08-25 — `cook_snaps` is a photo surface that postdates the original list.)** Stored in Firebase Storage `users/{uid}/recipes/...`; snap metadata in Firestore `cook_snaps/`. |
| **Videos** | No | — | — | — |

### 2.6 Audio

**None — tick No across the row. But the reason changed: voice input has SHIPPED.**

**(re-verified 2026-08-25 — the restored file said "voice control is post-beta (BUT-625)". That
is false; the voice menu prompt is built and the microphone permission is live.)**

The answer is still "not collected", because the audio never leaves the device:

- `record` captures a 16 kHz mono WAV to a temp file; `whisper_ggml_plus` (whisper.cpp FFI)
  transcribes it **on-device**. No upload, no Firebase write, no third-party call.
- `lib/services/voice/voice_capture_service.dart` deletes the WAV in a `finally` on **every**
  exit path — success, cap-reached, error and explicit cancel — and deletes both candidate
  paths where a stop can produce two.
- `ios/Runner/Info.plist` carries `NSMicrophoneUsageDescription` with on-device-only wording;
  Android declares `RECORD_AUDIO`.

**Play Console:** the microphone still needs a **Permissions declaration** even though Data
Safety says no audio collection. Use the wording already agreed in
`docs/store-submission/STORE_SUBMISSION_CHECKLIST.md` (RECORD_AUDIO row) so the permission
declaration, the Data Safety form and the privacy policy say the same thing.

**Apple:** no `NSPrivacyCollectedDataType` entry is required for audio, for the same reason —
verify against Guideline 5.1.1 at submission. A typed-input fallback exists for permission denial.

### 2.7 Files and docs

**None as a separate category** — recipe content is "User-generated content" (§2.10). Tick **No**.

### 2.8 Calendar

**None.** Tick **No**.

### 2.9 Contacts

**None.** Friends are added by username/email lookup, not by reading the device address book. Tick **No**.

### 2.10 App activity

| Play Console data type | Collected | Required | Purposes | Cross-ref |
|---|---|---|---|---|
| **App interactions** | Yes (Firebase Analytics events: `screen_view`, `recipe_created`, `recipe_shared`, milestone events, etc. — consent-gated per BUT-412) | Optional | Analytics, App functionality | `NSPrivacyCollectedDataTypeProductInteraction`. PII-scrubbed (BUT-421). **(re-verified 2026-08-25)** Firestore-side behavioural records now also exist and are collected regardless of the Analytics consent toggle, because they are app functionality rather than analytics: `activity_events/`, `recipe_cook_events/{uid}/events/`, `presence/` (plus per-document `presence` subcollections on `realtime_recipes`/`realtime_menus`), `parse_events` (30-day TTL, BUT-1570), and the `analytics/feature_retention/` per-user flags + daily aggregates (BUT-1789). Declare them here, not as a separate data type. |
| **In-app search history** | Yes (consent-gated; logged as analytics event only when user opts in) | Optional | Analytics | Same as above. No persistent search history stored against user. |
| **Installed apps** | No | — | — | — |
| **Other user-generated content** | Yes (recipes, menus, shopping lists, ratings, group memberships, cooking sessions, pantry items, allergen list, age `birthYear`) | **Required** for account, Optional for shared/social content | App functionality | `NSPrivacyCollectedDataTypeOtherUserContent`. Stored in Firestore. **(re-verified 2026-08-25)** Also covers the rating surfaces added since: `family_ratings/`, `recipe_ratings/` and `diner_profiles/`. |
| **Other actions** | No | — | — | — |

### 2.11 Web browsing

**None.** No browsing history collection. Tick **No**.

### 2.12 App info and performance

| Play Console data type | Collected | Required | Purposes | Cross-ref |
|---|---|---|---|---|
| **Crash logs** | Yes (Firebase Crashlytics) | Required | App functionality, Analytics | `NSPrivacyCollectedDataTypeCrashData`. Anonymous (not linked to user) per privacy-info `Linked=false`. |
| **Diagnostics** | Yes (Firebase Performance Monitoring traces) | Required | App functionality, Analytics | `NSPrivacyCollectedDataTypePerformanceData`. Anonymous. |
| **Other app performance data** | No | — | — | — |

### 2.13 Device or other IDs

| Play Console data type | Collected | Required | Purposes | Cross-ref |
|---|---|---|---|---|
| **Device or other IDs** | Yes (Firebase Installations ID for FCM push routing + App Check attestation) | Required | App functionality (push notifications, abuse prevention) | `NSPrivacyCollectedDataTypeDeviceID`. NOT advertising ID — `NSPrivacyTracking=false`. |

**Important:** Butlery does **NOT** collect Android Advertising ID (AAID). The app does not use ads. If Play Console asks "Does your app use Advertising ID?" → **No**.

---

## 3. Data Sharing (Step 2 of 4)

**Set Sharing = No for ALL data types.**

Rationale: every external party listed in privacy-policy §6.1 is a **data processor** acting on Butlery's instructions under a DPA, not a "third-party recipient" in Play's sense. Per Play's definition:

> "Sharing" refers to transferring user data collected from your app to a third party. ... It does NOT include transfers to a "service provider" who processes data on the developer's behalf and as instructed.

Processors (no sharing flag triggered):

| Processor | Function | Region | DPA |
|---|---|---|---|
| **Google Firebase** (Auth, Firestore, Storage, FCM, Analytics, Crashlytics, Performance, Installations, App Check, Realtime Database) | Backend infrastructure | Firestore data: **`europe-west3` (Frankfurt)** — resolved in BUT-819, 2026-06-14. Compute (Cloud Functions) pinned to `europe-west1`. Auth: global (managed). Both regions are EU. Verify live: `gcloud firestore backups list --location=europe-west3` (see `docs/ops/backups.md`) | Google Cloud DPA |
| **Google Cloud Vertex AI** (Gemini models for recipe parsing + OCR) | LLM-based recipe extraction | `europe-west1` (Belgium) | Google Cloud DPA |
| **OCR.space** (a]o Software GmbH) | OCR tier 2 for recipe-photo import | EU/EEA (Austria) | OCR.space privacy policy |
| **Google Cloud Vision** | OCR tier 3 fallback | **Global endpoint `vision.googleapis.com` — NOT EU-pinned.** Dormant: gated on a build-time `--dart-define GOOGLE_VISION_API_KEY` that is set nowhere in this repo | Google Cloud DPA — **but see the warning below** |
| **Tesseract** (self-hosted) | OCR tier 4 fallback | Wherever the endpoint is hosted. Dormant: gated on a build-time `--dart-define TESSERACT_API_URL`, set nowhere in this repo | Self-hosted — no third party |
| **Algolia** (currently inactive — feature flag `enable_algolia_search`, default false) | Recipe search indexing | EU (France primary, US backup) | Algolia DPA + EU-US DPF |

**(re-verified 2026-08-25 — the restored list named only Firebase, Vertex AI, OCR.space and
Algolia. The OCR chain is four tiers, not one.)** `lib/services/ocr_extraction_service.dart`
falls back on-device ML Kit → OCR.space → Google Vision → Tesseract, each behind its own
circuit breaker. On-device ML Kit is not a processor at all: it runs locally and sends nothing.

> **Blocker before ticking any box on this page.** Two of those tiers are shipped code that
> today's builds cannot reach (no key / no URL configured), and **neither is named in
> `assets/legal/privacy_policy_{sv,en}.md` §6.2**. One `--dart-define` at build time turns
> Google Vision on and starts sending recipe photos to a non-EU-pinned endpoint that the
> privacy policy does not disclose. Before submitting: either confirm both stay unconfigured
> (and say so here), or add them to the policy first. Own ticket — the policy is legal text
> and is not edited from this runbook.

If Play Console UI insists on declaring transfers when the data leaves the EU/EEA, file under "App functionality" with no Sharing flag. The Vertex AI Belgium region is EU, so no Chapter V transfer occurs for recipe text/images sent for parsing.

**Open conflict, not resolved here:** `assets/legal/privacy_policy_{sv,en}.md` §6.2 still states
`europe-west1` for Firestore, while `docs/ops/backups.md` records `europe-west3` as the resolved
region (BUT-819). Both are EU so GDPR is satisfied either way, but the two documents disagree
and the Play form should carry the measured region. Own ticket.

---

## 4. Security Practices (Step 3 of 4)

Same answers regardless of data type — fill in the global section once.

| Play Console question | Answer | Evidence |
|---|---|---|
| Is all of the user data collected by your app encrypted in transit? | **Yes** | All Firebase SDKs use TLS. Cloud Functions endpoints HTTPS-only (App Check enforced). Local SQLCipher AES-256 at rest. |
| Do you provide a way for users to request that their data is deleted? | **Yes — in-app** | Profile > Account Management > Delete account. Triggers `accountDeletionService` cascade across Firestore + Storage + Auth (privacy-policy §9.3). |
| Has your app been independently validated against a global security standard? | **No** (leave unticked) | We're not MASA-validated. Not yet pursued. Future ticket if needed for store priority. |

---

## 5. Data deletion request (Step 4 of 4)

| Play Console question | Answer |
|---|---|
| External URL where users can request data deletion | `https://butlery.app/data-deletion` (planned — confirm hosting before submitting) OR `mailto:integritet@butlery.se` **(re-verified 2026-08-25 — was `privacy@`, which appears nowhere outside stale `build/` artefacts)** (acceptable per Play guidance for small apps). |
| In-app account deletion | **Yes** — settings deep-link path: `Profile > Account Management > Delete account`. |

If `butlery.app/data-deletion` is not yet hosted at submission time, use the `mailto:integritet@butlery.se` link — Play accepts email-based deletion requests for apps with in-app deletion already available. Add the URL later as a non-blocking update.

---

## 6. Submission Checklist (do this in order)

- [ ] **Re-read** `ios/Runner/PrivacyInfo.xcprivacy` to confirm no new `NSPrivacyCollectedDataType` entries since last audit (`docs/ops/ios-privacy-manifest-audit.md`). If any are new, add them to §2 here and to the Play Console form.
- [ ] **Re-read** `assets/legal/privacy_policy_en.md` and confirm §6.1 third-party processor list matches §3 of this runbook.
- [ ] **Verify** the Firestore region against `docs/ops/backups.md` (recorded region is `europe-west3`, Frankfurt; compute stays on `europe-west1`). Run `gcloud firestore backups list --location=europe-west3 --project=butlery-app-1` to confirm the live database matches — `--location=eur3` returns an empty list and looks exactly like "no backups exist". If non-EU, declare cross-border transfer in §3.
- [ ] **Verify** Algolia is still inactive (`enable_algolia_search` in `lib/services/feature_flags/feature_flag_service.dart`, plus the Remote Config value). If activated since last submission, set Algolia search-context purpose in §2.10 "In-app search history".
- [ ] **Verify** the OCR fallback tiers (§3): confirm `GOOGLE_VISION_API_KEY` and `TESSERACT_API_URL` are still undefined in the release build's `--dart-define` set. If either is configured, the privacy policy must name that processor **before** the form is submitted.
- [ ] **Cross-check** Play Console field labels against this runbook — Google occasionally renames categories (e.g., "Other in-app messages" was "Messages" before 2025). If a label has changed, look at the field's tooltip rather than the column header.
- [ ] **Save as draft.** Walk away for 30 minutes. Re-read for typos and inconsistencies between the iOS manifest and Play form.
- [ ] **Submit.** Take a PDF screenshot of every page of the form before pressing Submit. Save to `docs/ops/play-data-safety-submission-{YYYY-MM-DD}.pdf` for the audit trail.
- [ ] **Record submission date in this file.**

---

## 7. Common rejection causes — pre-flight check

Google rejects ~30% of Data Safety submissions on first try. Common reasons + how to avoid:

| Reason | Pre-flight check |
|---|---|
| Email collected but not declared | §2.1 "Email address" is **Yes**. |
| User ID collected but not declared | §2.1 "User IDs" is **Yes** (Firebase UID). |
| Crash data declared as "Not collected" | §2.12 "Crash logs" is **Yes** (Crashlytics is bundled). |
| FCM tokens declared but Device ID not | §2.13 "Device or other IDs" is **Yes** (Firebase Installations ID). |
| "Shared with third parties" left blank when it should be No | §3 — explicitly tick No, with rationale. |
| Encryption-in-transit declared No | §4 first row — Yes (TLS via Firebase SDK). |
| Account deletion missing | §1 "Do you provide a way for users to request that their data is deleted?" — Yes. §5 must point to either in-app flow or `integritet@butlery.se`. |
| Privacy policy URL doesn't load | Privacy policy is in `assets/legal/privacy_policy_en.md` — must be hosted at a public URL before Play submission. **TODO before submission:** confirm `butlery.app/privacy` (or wherever) returns 200 and matches the in-repo file. |

---

## 8. Submission History

| Date | Submitter | Form version | Outcome | Notes |
|---|---|---|---|---|
| _(not yet submitted)_ | — | v1 | — | First submission pending — see §6. |

---

## 9. Maintenance triggers

Update this file (and re-submit Data Safety form) whenever any of the following lands:

- A new Firebase product is added to `pubspec.yaml` (e.g., Remote Config, In-App Messaging, ML Kit) — usually adds a new collected-data type.
- A new third-party SDK with its own data collection is added (e.g., Sentry, Mixpanel, Amplitude, RevenueCat).
- A new analytics event tracks a new field that didn't exist before (especially anything with location, contact, or device-fingerprinting characteristics).
- Firestore region changes (`docs/ops/backups.md`).
- Vertex AI region changes.
- Algolia is activated (currently inactive — feature flag).
- An OCR fallback tier is configured — a release build that defines `GOOGLE_VISION_API_KEY` or `TESSERACT_API_URL` adds a processor (§3).
- The age floor moves, or `verifySignupAge` / `isAgeCompliant()` changes shape (§1).
- Voice input starts sending audio off-device for any reason (§2.6 flips from No to Yes).
- Privacy policy version bumps in `assets/legal/privacy_policy_en.md`.
- App Store Privacy Manifest (`PrivacyInfo.xcprivacy`) is updated.

The maintenance trigger list maps 1:1 to the audit cross-references at the top of this file. If any of those files change without this runbook being updated, treat the iOS manifest / Play Data Safety declarations as drift and reconcile before the next release.

---

## 10. Filing status

**Status (2026-04-26):** Pending user action — form to be filed via Play
Console using the answers below; screenshot to be saved at
`docs/store-submission/play-data-safety/2026-04-26-submitted.png`
(or substitute the actual submission date if it slips). After filing,
update §8 (Submission History) with the date and outcome, and flip this
status line to "Submitted YYYY-MM-DD".

The runbook content (sections 1–7) is the authoritative answer set; this
is purely a tracker of whether the form has been submitted. Filing
instructions live at `docs/store-submission/play-data-safety/README.md`,
and the top-level tracker at
`docs/store-submission/STORE_SUBMISSION_CHECKLIST.md` mirrors this state.

Cross-reference: BUT-646 (filing — awaiting user) tracks the
console-side action; BUT-561 (runbook authoring) is closed.
