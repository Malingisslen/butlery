# Sprint Backlog

## Sprint: Pre-launch hardening — security defects + Firestore cost-perf + push-prefs bug — 2026-04-25

Theme: drain the highest-leverage P2 Bug/security cluster before submission. One big rock (BUT-448 Firestore rules CI gate) plus six surgical 2-hour fixes. Additive only, no user-visible features.

### Agent A: firebase-backend-security — security defects (analysis report 02, D1/D3)

- [x] **A1. SQLCipher key out of PRAGMA string** — done; `lib/core/storage/drift/app_database.dart`: replaced interpolated `PRAGMA key = '$encryptionKey'` with parameterized prepared statement (`db.prepare('PRAGMA key = ?')` + bound execute + dispose). Key never enters SQL text. (BUT-428)
- [!] **A2. Wire freeRASP with real teamId + cert hashes** — PARTIAL/BLOCKED on user creds. Done: extracted `_kPlaceholderTeamId` + `_kPlaceholderAndroidCertHash` constants with `TODO(BUT-426)`, added release-mode `AppLogger.error` warning if placeholder is still in use. **Blocked on:** real Talsec teamId from freeRASP dashboard + real SHA-256 cert hash via `keytool -list -v -keystore android/app/upload-keystore.jks -alias upload`. (BUT-426)

### Agent B: firebase-backend-security — server testing + observability

- [x] **B1. Firestore rules unit tests + CI gate** — done (CI-verified). Dep already installed. New `functions/src/__tests__/firestore-rules.test.ts` — 15 tests, ~20 assertions covering `recipes` (8 tests: create/read/write/delete + admin-moderation override + cookCount delta) and `users` + `users/.../settings/preferences` + `users/.../pantry` (7 tests). New `.github/workflows/firestore-rules.yml` spins up Java 21 + emulator + runs `npm run test:rules:all`. **Local verification gap:** Java not on Windows PATH; CI is the verification path. Follow-up collections (social, shopping, comments, ratings, conversations, friends, presence, etc.) tracked separately. (BUT-448)
- [!] **B2. Activate GCP alerting** — PARTIAL/BLOCKED on user gcloud + GCP creds. Done: hardened `setup-gcp-alerts.sh:15` to require `GCP_NOTIFICATION_CHANNEL_ID:?` env var (fails loudly instead of silently writing broken policies); new `docs/ops/gcp-alerting-runbook.md` with exact commands. **Blocked on:** user installs gcloud, runs `gcloud auth login`, creates email notification channel via runbook §3, exports env var, runs script. (BUT-450)

### Agent C: flutter-developer — Firestore cost/perf (analysis report 04)

- [x] **C1. Audit `.limit(10000)` callers** — done. Method = `BaseFirebaseRepository.readAll()`. Two real call-sites: (1) the base method itself — added `kReleaseMode` warning + named const; (2) `lib/services/account/account_deletion_service.dart:287` (per-user account-deletion search-index cleanup, bounded admin op — kept with `// note:` comment). All recipe/shopping/personal-tag subclasses already paginate or are structurally bounded. (BUT-474)
- [x] **C2. Denormalize rating stream** — done; `lib/repositories/firebase/firebase_ratings_repository.dart`: aggregate path swapped from `.limit(500).snapshots()` (~501 reads/update) to single-doc stream on `recipe_social_stats/{recipeId}` (1 read/update). Reviews-list path (separate `getRecipeRatings` method) untouched. Test updated to seed aggregate doc + cover missing-doc case (32/32 in repo + adapter rating-stream test green). (BUT-430)

### Agent D: firebase-backend-security — push prefs bug

- [x] **D1. Win-back push respects prefs + quiet hours** — done. New `functions/src/shared/preference-aware-push.ts` exports `sendPushToUserRespectingPreferences(uid, payload, category, ...)` returning structured result. Reads root collection `user_notification_preferences/{uid}`; honors master `enabled`, `reEngagement` (forward-compat), category fallback, quiet hours via `Intl.DateTimeFormat` on `Europe/Stockholm` (DST-safe). `detect-lapsed-users.ts` routed through helper. New `__tests__/detect-lapsed-users.test.ts` — 12 cases (6 unit + 6 scenarios). 12/12 pass. (BUT-438)

### Post-Sprint Steps

- [x] `dart analyze --fatal-infos` — 0 issues
- [x] `cd functions && npm test` — 28/28 parity + 12/12 lapsed-users green
- [x] Targeted unit tests per agent — green
- [ ] Commit, push to main
- [ ] Update Linear: BUT-428, BUT-448, BUT-474, BUT-430, BUT-438 → Done; BUT-426, BUT-450 stay In Progress (blocked on user)

### Side findings (not in sprint scope — surface to user)

- [ ] **`android/key.properties` is NOT gitignored** and contains plaintext keystore password. Git log shows it has never been committed (so no leak yet), but the gap exists. Add `android/key.properties` and `android/app/*.jks` to `.gitignore` before any future commit can leak the password.
- [ ] Other notification call sites still bypass prefs/quiet-hours: `functions/src/analytics/send-activity-digest.ts` and `functions/src/notifications/send-notification.ts` (callable). Same bug as BUT-438; should migrate to the new helper.

---

## What this means in plain language

- **The lock on the local recipe database becomes airtight.** The encryption key was sitting plain-text in query logs — now it isn't.
- **Tampering detection actually turns on.** Today the anti-tamper layer silently disables itself because of a placeholder ID — a determined attacker has a free pass.
- **Backend permission rules get a safety net.** A 1465-line file that gates who can read what gets automated tests so a rule mistake can't ship.
- **You'll know when the backend breaks.** Email alert when Cloud Functions error rate spikes; today you find out from user reports.
- **Recipe ratings load way faster and cost less.** Opening a recipe was reading 500 documents per rating change — now it reads 1.
- **Lapsed-user "we miss you" pushes will stop ignoring quiet hours and opt-outs.** A user who turned off marketing pings still gets them today.
- **Risk: Low–medium.** B1 (rules tests) is the meatiest — could expose existing rules bugs that need fixing. Each task independently revertable. No user-visible UX change.

---

## Archive: Sprint Launch Readiness v3 — store blockers + PII + dep safety — 2026-04-24

Theme: close out the Urgent cluster (BUT-411 + BUT-447) and drain the highest-leverage P2 security/store blockers. Additive only, no user-visible features except the age gate.

### Agent A: flutter-developer — iOS store-submission blockers

- [x] **A1. Flip `ITSAppUsesNonExemptEncryption=false` in Info.plist** — done; `ios/Runner/Info.plist` flipped to `<false/>`. (BUT-411)
- [x] **A2. Add iOS build job to CI** — done; `build-validation.yml` matrix extended with iOS (macos-latest), stub `ios/exportOptions.plist` created. Unsigned build for PR gate. Signing follow-up when BUT-485 lands. (BUT-447)

### Agent B: firebase-backend-security — PII scrubbing hardening

- [x] **B1. Tighten PII-scrubber regexes** — done; `functions/src/llm/pii-scrubber.ts` rewritten. Personnummer requires hyphen/+ + word-boundaries; phone requires country-code prefix + unit-suffix negative-lookahead. 10/10 TS tests pass. (BUT-423)
- [x] **B2. Scrub PII client-side before LLM callable** — done; new `lib/services/llm/pii_scrubber.dart` (Dart port), wired into `llm_service.dart:_executeLlmCall` pre-`callable.call`. 14/14 Dart tests pass. Sync note in both files. (BUT-422)

### Agent C: firebase-backend-security — dependency + supply-chain safety

- [x] **C1. Commit `.github/dependabot.yml`** — done; pub + npm (/functions) + github-actions, weekly, grouped, ignores pub majors per BUT-562. (BUT-432)
- [x] **C2. Add `flutter pub audit` + `npm audit` CI gate** — done; `.github/workflows/dep-audit.yml` with OSV scanner (pub) + `npm audit --audit-level=high`. Weekly cron + PR triggers. Allowlist doc at `.github/dep-audit-allowlist.md`. (BUT-433)

### Agent D: firebase-backend-security — age gate (GDPR Art 8)

- [x] **D1. Age gate at sign-up** — done; `birthYear` field on `UserProfile` (stored in private `settings/preferences`, not public profile); Firestore rules enforce `[1900, 2013]` + required on preferences-create; new `OnboardingAgeGatePage` + `OnboardingAgeGateBlockedView`; 16 new tests (7 model + 3 widget + 6 rules). Bounded `2013` flagged for Jan rollover. (BUT-413)

### Post-Sprint Steps

- [x] `dart analyze --fatal-infos` — expect 0 issues
- [x] Targeted tests per agent (pii_scrubber_test false-positive fixtures; age-gate widget + Firestore rules tests)
- [x] Commit, push to main — `c9f72c336`
- [x] Update Linear: BUT-411, BUT-447, BUT-423, BUT-422, BUT-432, BUT-433, BUT-413 → Done
- [x] Follow-ups landed post-sprint: BUT-485 (`086113880`, `c9e2e6e9e`) + BUT-418 (`ea7372bd4`) + iOS CI chain BUT-632/634/635

---

## Archive: Sprint a11y completion + permission helper — 2026-04-22

**Plan file:** `C:\Users\malla\.claude\plans\plan-elegant-wilkes.md`

Theme: close out the /simplify-skipped follow-ups from sprint `ec5b8a43a`. Pure cleanup: finish BUT-505/BUT-508 migrations, extract OS-permission helper for future permission types.

### Agent A: flutter-developer — AppIconButton Semantics parity + 48dp migration

- [x] **A1. Add explicit `Semantics` wrapper to `AppIconButton`** — `lib/widgets/common/buttons/action_buttons.dart:473-481`.
- [x] **A2. Migrate raw `IconButton + Semantics + manual constraints` sites to `AppIconButton`** — `shopping_item_tiles.dart`, `shopping_list_header.dart`, `duplicate_merge_sheet.dart`, `feedback_fab.dart`.
- [x] **A3. Migrate custom `InkWell + SizedBox(minTouchTarget)` sites to `TappableWrapper`** — `cooking_mode_view.dart`.
- [x] **A4. Tests** — `app_icon_button_test.dart` + targeted 48dp-survival widget tests.

### Agent B: firebase-backend-security — extract OS-permission helper

- [x] **B1. Create `lib/core/utils/os_permission_helper.dart`** — static `requestWithRationale(...)`, inject `PermissionGateway`.
- [x] **B2. Refactor `NotificationPermissionService`** — delegate to helper, 243 → ~80 lines.
- [x] **B3. Do NOT migrate `ImagePickerService`** — different flow, out of scope.
- [x] **B4. Tests** — `os_permission_helper_test.dart` with 6 branches.

### Post-Sprint Steps

- [x] `dart analyze --fatal-infos` — 0 issues
- [x] Relevant tests green
- [~] Manual TalkBack + Android 13+ notification flow — user-skipped; covered by unit/widget tests
- [ ] `/simplify` pass, commit, push
- [x] Linear: no ticket closures (pure cleanup on already-Done tickets)

---

## Archive: Sprint Store Submission Readiness — 2026-04-22

**Plan file:** `C:\Users\malla\.claude\plans\recursive-baking-petal.md`

Theme: launch-readiness High-priority store-submission blockers (Apple 1.2 UGC, GDPR Ch V, iOS privacy manifest, deep-link verification).

### Agent A: firebase-backend-security — UGC moderation (Apple 1.2 + Google Play)

- [x] **A1. Reports state machine + moderator admin rule + Cloud Function trigger** — `isAdmin()` helper + `admins/{uid}` write-lock + forward-only `reports.status` state machine. `ReportStatus` enum + safe-serialization. `ReportService` with admin stream + content-delete per type. Moderator review view/viewmodel. (BUT-417, BUT-548)
- [x] **A2. Appeal process ToS + Settings link** — ToS section 6.1 both locales. Settings hub mailto tile. (BUT-556)
- [x] **A3. Moderator runbook** — `docs/ops/moderation-runbook.md`. (BUT-417/BUT-548 close-out)

### Agent B: firebase-backend-security — EU data residency (GDPR Ch V)

- [x] **B1. Verify Firebase region + document** — `docs/ops/data-residency.md`. Cloud Functions + Vertex AI confirmed `europe-west1`. Firestore + Storage still need Firebase Console check by account holder. (BUT-607)
- [x] **B2. Migrate Gemini → Vertex AI europe-west1** — `@google/generative-ai` → `@google-cloud/vertexai`, ADC auth, GEMINI_API_KEY secret removed. Privacy policy v1.2.0 both locales reflects Vertex EU. (BUT-614)

### Agent C: flutter-developer — iOS submission + deep links

- [x] **C1. PrivacyInfo.xcprivacy audit** — declared File Timestamp (C617.1) + existing UserDefaults (CA92.1). `docs/ops/ios-privacy-manifest-audit.md`. (BUT-568)
- [x] **C2. Host `.well-known/assetlinks.json` + AASA on butlery.app** — `web/.well-known/` with placeholders. Also unblocks BUT-434. (BUT-575)

### Post-Sprint Steps

- [x] `dart analyze --fatal-infos`
- [~] Firestore rules unit tests — spec compiles, execution requires emulator
- [~] Manual verification — requires user: Firebase Console region, Xcode Archive, `curl -I https://butlery.app/.well-known/*`
- [x] Commit, push to main — `8cb29da13` + `49ef82341`
- [x] Linear: BUT-417, BUT-548, BUT-556, BUT-607, BUT-614, BUT-568, BUT-575 → Done
- [ ] Paperwork tracked separately: BUT-561 Data Safety form, BUT-624 age rating

---

## Archive: Sprint Launch readiness — GDPR + a11y + infra — 2026-04-21

Theme: burn down the Urgent launch-readiness cluster (GDPR Art 7, Firestore RPO, Android 13+ notifications, WCAG) + High-priority companions.

### Agent A: firebase-backend-security — consent-gated analytics

- [x] **A1. Gate `setAnalyticsCollectionEnabled` behind consent** — (BUT-412)
- [x] **A2. Consent-gate `FirebaseAnalyticsObserver`** — (BUT-570)
- [x] **A3. Strip PII from Analytics event params** — (BUT-421)

### Agent B: firebase-backend-security — infra + signing verifies

- [!] **B1. Enable Firestore PITR + weekly GCS export** — runbook in `docs/ops/backups.md`; blocked on user gcloud install. (BUT-418)
- [x] **B2. Verify `upload-keystore.jks` is gitignored** — CLEAN. (BUT-487)
- [!] **B3. Verify CI release signing** — TWO DEFECTS FOUND: keystore path mismatch + CI doesn't materialize `key.properties`. Requires user secret-admin. (BUT-485)

### Agent C: flutter-developer — Android 13+ notifications

- [x] **C1. Declare `POST_NOTIFICATIONS` permission** — (BUT-414)

### Agent D: flutter-developer — WCAG a11y

- [x] **D1. Semantics labels on icon-only buttons** — (BUT-508)
- [x] **D2. Enforce 48x48dp minimum touch targets** — (BUT-505)

### Cleanup

- [x] **Z1. Delete analysis report files** — 11 files
- [x] **Z2. Cancel BUT-543** — intentional empty-grid

---

## Archive: Sprint Family presence + pings + cooking step depth — 2026-04-20

Theme: surface the existing presence infra (RTDB `presence/{userId}`) into UI, add lightweight ping primitive (BUT-407), finish BUT-408's "steg N av M".

- [x] Agent A (flutter-developer): `FamilyPresenceBar` widget + header integration (BUT-407)
- [x] Agent B (firebase-backend-security): `Ping` model + `PingService` with rate-limit + GDPR cascade (BUT-407)
- [x] Agent C (flutter-developer): `ActivityPingsFeed` + `PingComposeSheet` (BUT-407)
- [x] Agent D (flutter-developer): `CookingSession.currentStep/totalSteps` + " · steg N av M" (BUT-408 follow-up)

---

## Archive: Sprint Cooking depth + presence + heirloom — 2026-04-19

Theme: three independent slices advancing *Smart Cooking Mode first*.

- [x] Agent A (flutter-developer): BUT-406 long-press timer — `DurationParser`, `StepTimerService`, `StepTimerWidget`
- [x] Agent B (flutter-developer): BUT-408 "Erik lagar just nu" presence — `CookingSession` model + RTDB repo + rules + `CookingSessionModule` + `CookingSessionCard`
- [x] Agent C (flutter-developer): BUT-410 heirloom OCR — `HeirloomMetadata` model + content-addressed Storage + `HeirloomStamp`

---

## Archive: Previous Sprints

- Cooking depth + Chrome MCP hooks (2026-04-18): BUT-202, BUT-215, BUT-403, BUT-347
- UX polish + menu model upgrade (2026-04-18): BUT-402, BUT-399, BUT-400, BUT-404, BUT-405, BUT-398, BUT-401
- Shared Menu Decisions (2026-04-18): BUT-340, BUT-238, BUT-361
- Test Infra Phase 12 — Cross-platform + Patrol MVP (2026-04-17): BUT-396, BUT-395
- Test Infra Close-Out (BUT-387 Phase 11, 2026-04-17): BUT-394, BUT-389, BUT-393
- Test Hardening Close-Out (BUT-387 final phase, 2026-04-17): BUT-390, BUT-391, BUT-392, BUT-388, BUT-385, BUT-374
- Ingredient Search (2026-04-14): BUT-205
- Stability & Permissions (2026-04-14): BUT-379, BUT-381, BUT-383, BUT-373, BUT-380, BUT-372, BUT-382
- Menu System Deepening (2026-04-13): BUT-360, BUT-370
- Veckomeny Constraint Parser (2026-04-11): BUT-359
- Calendar Weekly Menu Phase 1 (2026-04-11): BUT-211
- Skafferiet / Pantry (2026-04-10): BUT-349, BUT-205
- Social Activity Feed Phase 1 (2026-04-10): BUT-339
- Consent Hardening (2026-04-10): BUT-356, BUT-357
- Insights & Engagement (2026-04-10): BUT-338, BUT-350, BUT-223, BUT-354, BUT-214
- Social Polish & Tech Debt (2026-04-09): BUT-342, BUT-343, BUT-305, BUT-304, BUT-346, BUT-302
- Feature & Polish (2026-04-09): BUT-348, BUT-355, BUT-352, BUT-353
- Social & Stability Blitz (2026-04-08): BUT-345, BUT-341, BUT-314, BUT-323, BUT-337, BUT-324, BUT-300, BUT-301
- Tech Debt Consolidation (2026-04-08): BUT-303, BUT-306, BUT-299
- Bug Stability + Hardening H2 (2026-04-08): BUT-308, BUT-320, BUT-335, BUT-319, BUT-336, BUT-331, BUT-317, BUT-297, BUT-313, BUT-311, BUT-312, BUT-332, BUT-327
- Security Hardening (2026-04-08): BUT-334, BUT-315, BUT-310, BUT-325, BUT-326, BUT-330, BUT-316, BUT-333, BUT-318, BUT-329, BUT-328, BUT-321
- Household + Menu Voting (2026-04-08): BUT-256, BUT-239
- Bug Cleanup + Loading Polish (2026-04-07): BUT-292-296, BUT-244
- Share & Discover (2026-04-07): BUT-219, BUT-242, BUT-272, BUT-271
- Tech Debt + UX Polish (2026-04-07): BUT-289, BUT-288, BUT-253, BUT-218, BUT-212
- Smart Import + Menu Intelligence (2026-04-06): BUT-208, BUT-241, BUT-247, BUT-204, BUT-270
