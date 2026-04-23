# Sprint Backlog

## Sprint: a11y completion + permission helper — 2026-04-22

**Plan file:** `C:\Users\malla\.claude\plans\plan-elegant-wilkes.md`

Theme: close out the /simplify-skipped follow-ups from sprint `ec5b8a43a`. Pure cleanup: finish BUT-505/BUT-508 migrations, extract OS-permission helper for future permission types.

### Agent A: flutter-developer — AppIconButton Semantics parity + 48dp migration

- [x] **A1. Add explicit `Semantics` wrapper to `AppIconButton`** — `lib/widgets/common/buttons/action_buttons.dart:473-481`. Match the idiom the other 4 buttons in the file already use (`Semantics(label:, button: true, enabled: onPressed != null, child: IconButton(...))`). Update `app_icon_button_test.dart` finder to `find.bySemanticsLabel(...)`.
- [x] **A2. Migrate raw `IconButton + Semantics + manual constraints` sites to `AppIconButton`** — `shopping_item_tiles.dart:370-430` (3 sites), `shopping_list_header.dart`, `duplicate_merge_sheet.dart:~371`, `feedback_fab.dart`. Each drops ~8 lines.
- [x] **A3. Migrate custom `InkWell + SizedBox(minTouchTarget)` sites to `TappableWrapper`** — `cooking_mode_view.dart` lines 155-172, 179-195, 387, 553-566, 685. If a site genuinely needs Material ink feedback, leave it and flag in the PR.
- [x] **A4. Tests** — re-run `app_icon_button_test.dart` (now uses `bySemanticsLabel`); add 1-2 targeted 48dp-survival widget tests on representative migrated sites.

### Agent B: firebase-backend-security — extract OS-permission helper

- [x] **B1. Create `lib/core/utils/os_permission_helper.dart`** — static `requestWithRationale(...)` method encapsulating rationale-then-request-then-settings-snackbar. Inject `PermissionGateway` (rename from `NotificationPermissionGateway`) so both callers share one interface.
- [x] **B2. Refactor `NotificationPermissionService`** to delegate to the helper — keep the `AndroidSdkVersionProvider` short-circuit, drop inner flow (243 → ~80 lines). Existing 8 tests must pass with minimal gateway-shape changes.
- [x] **B3. Do NOT migrate `ImagePickerService`** — different flow, out of scope. Flag in PR description only.
- [x] **B4. Tests** — `os_permission_helper_test.dart` with 6 branches (granted / first-deny-accept / first-deny-decline / OS-deny-after-rationale / permanently-denied / permanently-denied-after-rationale).

### Post-Sprint Steps

- [x] `dart analyze --fatal-infos` — 0 issues on touched files
- [x] `flutter test test/widget/common/ test/unit/core/utils/ test/unit/services/notifications/` — all green except pre-existing `notification_preference_manager_test.dart` failure unrelated to this sprint
- [~] Manual: TalkBack on migrated cooking-mode + shopping-tile buttons — SKIPPED by user; widget tests cover the contract (semantic-tree label + 48dp hit region)
- [~] Manual: Android 13+ NotificationPermission flow end-to-end — SKIPPED by user; unit tests cover all 6 branches of `OsPermissionHelper` + the service short-circuit
- [ ] `/simplify` pass, commit, push
- [x] Linear: no ticket closures (pure cleanup on already-Done tickets)

---

## What this means in plain language

- Screen readers reliably announce every icon button (fixes a tooltip-only plumbing quirk)
- Consistent 48dp touch targets across cooking mode + shopping rows
- Future permission requests (microphone, location) reuse the notification flow for free
- Risk: Low — drop-in replacements, each migration independently revertable

---

## Archive: Sprint Launch readiness — GDPR + a11y + infra — 2026-04-21

**Plan file:** `C:\Users\malla\.claude\plans\plan-elegant-wilkes.md`

Theme: burn down the Urgent launch-readiness cluster (GDPR Art 7, Firestore RPO, Android 13+ notifications, WCAG) + their High-priority companions. No user-visible features this sprint — pure compliance + cleanup floor for the next product sprint.

### Agent A: firebase-backend-security — consent-gated analytics

Coherent cluster: all three tickets concern data collection happening before/around the consent check.

- [x] **A1. Gate `setAnalyticsCollectionEnabled` behind consent** — `lib/repositories/firebase/firebase_analytics_repository.dart:28`: move `setAnalyticsCollectionEnabled(!kDebugMode)` out of `initialize()` into `_enableCollectionIfConsented()` alongside Crashlytics + Performance. Test asserts collection stays off until `ConsentService` reports granted. (BUT-412)
- [x] **A2. Consent-gate `FirebaseAnalyticsObserver`** — `lib/core/observers/consent_aware_analytics_observer.dart` no-ops when consent denied; wired in `main.dart`. (BUT-570)
- [x] **A3. Strip PII from Analytics event params** — `_sanitize(Map)` gate in repo + salted SHA-256 IDs; `search_query` replaced with length bucket. (BUT-421)

### Agent B: firebase-backend-security — infra + signing verifies

- [!] **B1. Enable Firestore PITR + weekly GCS export** — runbook written to `docs/ops/backups.md`; **blocked: user must install gcloud + run commands** (no CLI in agent shell). (BUT-418)
- [x] **B2. Verify `upload-keystore.jks` is gitignored** — CLEAN. `android/.gitignore:14` matches `**/*.jks`; never in history. Log evidence in Linear comment. (BUT-487)
- [!] **B3. Verify CI release signing** — **TWO DEFECTS FOUND, NOT AUTO-FIXED**: (1) `android/app/build.gradle.kts:11` reads `app/key.properties` but actual file is `android/key.properties` — every local release is debug-signed too; (2) `.github/workflows/build-validation.yml:160-164` never materializes `KEYSTORE_BASE64` or `key.properties` in CI. Both fixes must land together with GitHub secrets; requires user secret-admin access. See Linear comment for paste-ready YAML. (BUT-485)

### Agent C: flutter-developer — Android 13+ notifications

- [x] **C1. Declare `POST_NOTIFICATIONS` permission (Android 13+)** — manifest + `NotificationPermissionService` with rationale dialog + settings snackbar, wired through the settings master-toggle. 8 tests passing. (BUT-414)

### Agent D: flutter-developer — WCAG a11y

- [x] **D1. Semantics labels on icon-only buttons** — `AppIconButton.semanticLabel` required; migrated critical-surface call sites; l10n keys added both locales. (BUT-508)
- [x] **D2. Enforce 48x48dp minimum touch targets** — `AppDimensions.minTouchTarget = 48.0` + `TappableWrapper`; star-rating + tag-status-badge migrated; golden + unit tests green. (BUT-505)

### Cleanup

- [x] **Z1. Delete analysis report files** — removed 11 untracked files under `docs/analysis/reports/`. Linear carries the findings.
- [x] **Z2. Cancel BUT-543** — transitioned to Canceled ("empty-grid first-run is intentional").

### Post-Sprint Steps

- [ ] `dart analyze --fatal-infos` — expect 0 issues
- [ ] Targeted tests per agent (analytics-repo consent test, semantics widget tests, permission manifest parse)
- [ ] Manual verification:
  - A: fresh install → verify no Analytics event fires before consent dialog answered (Firebase DebugView or `adb logcat | grep Analytics`)
  - B1: confirm PITR status via `gcloud firestore databases describe`
  - B2/B3: attach log evidence to Linear tickets
  - C1: Android 13+ device → first notification triggers permission sheet
  - D1/D2: TalkBack sweep on nav + FAB; manual tap on chips feels 48dp-sized
- [ ] Commit, push to main
- [ ] Update Linear: BUT-412, BUT-570, BUT-421, BUT-418, BUT-487, BUT-485, BUT-414, BUT-508, BUT-505 → Done
- [ ] BUT-407 stays In Progress (untouched)

---

## What this means in plain language

- **No analytics data is collected until you tap "Agree".** Fixed a GDPR Art 7 violation where basic usage stats started before consent.
- **Firestore backups turn on.** Today, a bad delete is unrecoverable. After this sprint we can roll back to any point in the last 7 days.
- **Accessibility.** Every icon-only button announces itself to VoiceOver/TalkBack; no tappable area smaller than a fingertip.
- **Android notifications work on Android 13+.** Today those devices silently drop every notification because we never ask for permission.
- **Safety checks on release signing.** Confirm the signing key isn't committed; confirm CI builds with the real key, not the debug one.
- **Cleanup.** 11 analysis-report markdown files deleted (digested into Linear). BUT-543 (sample recipes) cancelled.
- **Risk: Low.** No user-visible features; additive or constraint-only changes.

---

## Queued Sprint: Store Submission Readiness — 2026-04-22

**Plan file:** `C:\Users\malla\.claude\plans\recursive-baking-petal.md`

Theme: continue launch-readiness with remaining High-priority store-submission blockers (Apple 1.2 UGC, GDPR Ch V, iOS privacy manifest, deep-link verification). Runs after current sprint completes. No user-visible features.

### Agent A: firebase-backend-security — UGC moderation (Apple 1.2 + Google Play)

- [ ] **A1. Reports state machine + moderator admin rule + Cloud Function trigger** — `firestore.rules:1272`: add forward-only `reports/{reportId}.status` state machine (`new → in_review → actioned → closed`). `isAdmin()` helper reads `admins/{uid}`; `admins/` rule-locked vs client writes. Allow admin update on reports + update/delete on reportable collections. New `onReportCreated` Cloud Function in `functions/src/triggers/` → moderator email. Extend report-abuse UI to groups + messages + comments + ratings. Admin-gated in-app moderator screen. Safe-serialization for new field. Tests: 5 named rule+emulator behaviors. (BUT-417, BUT-548)
- [ ] **A2. Appeal process ToS + Settings link** — `lib/views/legal/terms_of_service_view.dart` appeal section + `appeals@butlery.app` mailto. `lib/views/settings/...` "Appeal a removal" entry. ARB keys both locales: `appealProcessTitle`, `appealProcessBody`, `appealEmailLinkLabel`. (BUT-556)
- [ ] **A3. Moderator runbook** — `docs/ops/moderation-runbook.md` (1 page): admin UID seeding, action-a-report flow, rollback, 24h SLA. (BUT-417/BUT-548 close-out)

### Agent B: firebase-backend-security — EU data residency (GDPR Ch V)

- [ ] **B1. Verify Firebase region + document** — Console check Firestore + Storage region; record in `firebase.json` comment + `docs/ops/data-residency.md`. If non-EU → **STOP + escalate** (immutable, migration = days). (BUT-607)
- [ ] **B2. Migrate Gemini → Vertex AI europe-west1** — `functions/src/llm/gemini-client.ts`: swap Google AI Studio endpoint for Vertex AI `@google-cloud/vertexai` in `europe-west1`. Service-account auth. Golden-fixture round-trip test asserts parsed shape unchanged. Update privacy policy data-processor inventory. (BUT-614)

### Agent C: flutter-developer — iOS submission + deep links

- [ ] **C1. PrivacyInfo.xcprivacy audit** — enumerate third-party SDKs from `pubspec.yaml` + `ios/Podfile.lock`; verify `NSPrivacyAccessedAPITypes` matches actual usage. Output: updated `ios/Runner/PrivacyInfo.xcprivacy` + `docs/ops/ios-privacy-manifest-audit.md`. (BUT-568)
- [ ] **C2. Host `.well-known/assetlinks.json` + AASA on butlery.app** — SHA-256 cert fingerprint (from BUT-487/485) + Team ID/bundle/paths. Host with correct Content-Type. Verify via Google + Apple validators. Also unblocks BUT-434. (BUT-575)

### Post-Sprint Steps

- [ ] `dart analyze --fatal-infos` — 0 issues
- [ ] Firestore rules unit tests green
- [ ] `firebase deploy --only functions --dry-run`
- [ ] Manual verification per plan file section
- [ ] Commit, push to main
- [ ] Update Linear: BUT-417, BUT-548, BUT-556, BUT-607, BUT-614, BUT-568, BUT-575 → Done
- [ ] Paperwork tracked separately (do NOT move to Todo): BUT-561 Data Safety form, BUT-624 age rating

---

## What this means in plain language (queued sprint)

- **Apple and Google require a moderator who can remove bad content within 24 hours.** After this sprint, you can review reports and delete offending content in one tap.
- **Users get a way to appeal removals** — required by Google Play.
- **All data stays in Europe.** Recipe parsing currently routes through US AI servers; this sprint moves it to Vertex AI europe-west1.
- **iOS knows exactly what each library touches** — Apple's been rejecting apps for vague declarations; this sprint matches reality.
- **Recipe share links open the app, not Safari.** Two tiny well-known files unlock Android auto-verify + iOS universal links.
- **Risk: Low.** Additive rules + one Cloud Function + config files. Escalation path if Firebase region is non-EU.

---

## Archive: Sprint Family presence + pings + cooking step depth — 2026-04-20

Theme: surface the existing presence infra (RTDB `presence/{userId}`) into UI, add a lightweight ping primitive for in-the-moment family signaling (BUT-407), and finish BUT-408's "steg N av M" promise now that BUT-406's step timer landed. All additive — no schema migrations, no runtime LLM cost.

- [x] Agent A (flutter-developer): `FamilyPresenceBar` widget + header integration in `mina_recept_view`, `veckomeny_view`, `group_detail_view`; tests + l10n (BUT-407)
- [x] Agent B (firebase-backend-security): `Ping` model + `PingService` with 5/h client rate-limit + 60s rules burst guard, `ActivityEventType` extension, DI, GDPR cascade via `deletePingsByUser` (BUT-407)
- [x] Agent C (flutter-developer): `ActivityPingsFeed` in `group_detail_view` body, `PingComposeSheet` long-press bottom sheet with haptic + snackbar (BUT-407)
- [x] Agent D (flutter-developer): `CookingSession.currentStep/totalSteps`, module-owned debounced `updateStep` with change-detection guard, " · steg N av M" suffix on the presence card (BUT-408 follow-up)
- [x] `/simplify` pass — dropped `dynamic` casts, inline `unawaited` shim, minute-only time-ago reinvention; reused `TimeAgoFormatter`, `firstWhereOrNull`; stripped ticket refs from source
- [x] Tests: 80/80 green in sprint scope; analyze clean
- [x] Commit + push to main

Follow-ups filed:
- Cloud Function sweeper for strict hourly ping cap
- Dedicated `ping` NotificationStrategy with Swedish copy
- `FamilyPresenceBar` StatefulWidget conversion (avoid re-subscribing on rebuild)
- `ActivityPingsFeed` pause-while-backgrounded via RouteObserver
- `AvatarWidgets` reuse to de-dupe `_Avatar` + `_AvatarThumb`

---

## Archive: Sprint Cooking depth + presence + heirloom — 2026-04-19

**Plan file:** `C:\Users\malla\.claude\plans\ja-prancy-toast.md`

Theme: three independent, user-visible slices advancing *Smart Cooking Mode first* (`memory/strategic-feature-analysis.md`) without runtime LLM cost or schema migrations. All additive.

### Agent A: flutter-developer — BUT-406 long-press timer in cooking mode

No LLM. No model change. Regex parses visible instruction line on long-press; timer runs locally.

- [x] **A1. `DurationParser` utility** — `lib/utils/duration_parser.dart`: pure `parseSwedishDuration(String) → Duration?`. Handles `10 min`, `10-15 min`, `ca 20 minuter`, `1 timme`, `låt koka i 10 min`. Clamps to 0 < x ≤ 12h. 15+ unit tests including negative cases using real fixtures from `test/fixtures/arla_test_data.dart` + `ica_test_data.dart`. (BUT-406)
- [x] **A2. `StepTimerService`** — `lib/services/cooking/step_timer_service.dart` extending project `BaseService`. Local-only `Stopwatch` + `Timer.periodic`. `start/pause/resume/reset`, `Stream<Duration> remaining`. Uses `package:clock` for backgrounding + tests. DI: `registerLazySingleton<StepTimerService>` in `content_module.dart:~320` next to `SubstitutionSuggestionService`. (BUT-406)
- [x] **A3. `StepTimerWidget` + cooking-mode wiring** — `lib/widgets/cooking/step_timer_widget.dart`. `AppColors.cream` bg, `forestGreenDark` text, `starGold` expiry-pulse. Spacing via `AppDimensions`. `showModalBottomSheet` from `GestureDetector(onLongPress)` on each instruction in `cooking_mode_view.dart:532`. Pre-fills via `DurationParser`; fallback editable 5-min default bounded 00:10 ≤ x ≤ 2:00:00. Haptic + snackbar on expiry (skip local-notifications on web). States: running/paused/expired/re-entry. (BUT-406)
- [x] **A4. Tests + Swedish l10n** — 15 parser + 7 service (`fakeAsync` + `withClock`) + 4 widget pump tests. Keys: `startTimer`, `timerExpired`, `pauseTimer`, `resumeTimer`, `resetTimer`, `timerDurationHint(source)`. `gen-l10n` clean. (BUT-406)

### Agent B: flutter-developer — BUT-408 "Erik lagar just nu" presence

HTML preview approval gate before Flutter code. Broadcasts to all `FriendCategory` groups user is a member of.

- [x] **B0. HTML preview** — `docs/design/previews/cooking-session-card-preview.html` on `_butlery-template.html`: idle/single/merge + placement mock. Chrome MCP → user sign-off. After approval: add to `_butlery-components.html`. (BUT-408)
- [x] **B1. `CookingSession` model + RTDB repo + security rules** — `lib/models/cooking/cooking_session.dart` + `lib/repositories/firebase/firebase_cooking_session_repository.dart` using safe-serialization utilities + project base repo. RTDB path `cooking_sessions/{groupId}/{userId}` with `onDisconnect().remove()`. `database.rules.json` block: read=group member, write=`auth.uid == userId`. `firebase deploy --only database:rules --dry-run` compile-check. (BUT-408)
- [x] **B2. `CookingSessionModule` + DI** — `lib/services/unified/operations/cooking/cooking_session_module.dart` mirroring `ShoppingPresenceModule` (interface + impl). `startSession/endSession/watchGroupSessions`. Errors swallowed silently. Registered as **interface type** in `collaboration_module.dart:96-101` as lazy singleton. (BUT-408)
- [x] **B3. Lifecycle hooks** — `onEnter/onExit` on `cooking_mode_viewmodel.dart`, called from view's `initState/dispose`. Resolves user's `FriendCategory` memberships via `UnifiedFriendsService` (cached → offline-safe). Offline writes swallowed. (BUT-408)
- [x] **B4. `PulseDot` shared widget + `CookingSessionCard` + header integration** — extract pulse from `edit_indicator_widget.dart:34-64` → new `lib/widgets/common/indicators/pulse_dot.dart` (respects `MediaQuery.disableAnimations`). `forestGreenDark` square card + `starGold` `PulseDot`. `StreamBuilder` under `MainViewHeader` in `mina_recept_view.dart:42` + `veckomeny_view.dart:24`. Hidden when empty. Tap → `recipe_detail_view`. (BUT-408)
- [x] **B5. Tests** — 5 model + 6 repo (`FakeFirebaseDatabase`: write, merge-view, `onDisconnect`, multi-group, offline-swallow) + widget pump (idle/single/merge/reduce-motion) + ServiceLocator-bridged lifecycle test. L10n: `cookingNowSingle(name, recipe)`, `cookingNowMerge(names, recipe)`. (BUT-408)
- [x] **B6. GDPR note** — Inline comment in repo: RTDB is ephemeral via `onDisconnect`; no account-deletion cascade needed, nothing to export. (BUT-408)

### Agent C: flutter-developer — BUT-410 heirloom OCR ("Farmors lapp")

- [x] **C1. `HeirloomMetadata` model + `RecipeCore.heirloom` field** — `lib/models/recipe/heirloom_metadata.dart` using safe-serialization utilities. Nullable `HeirloomMetadata? heirloom` on `RecipeCore` (`recipe_unified.dart:220-228`) + sentinel `copyWith` mirroring `tagResult` at line 470-473. Update `recipe_serialization.dart`. Validation at construction: `year` ∈ [1800, current], `writerName` ≤ 100, `note` ≤ 200. (BUT-410)
- [x] **C2. Content-addressed Storage upload + Cache-Control** — extend `firebase_storage_repository.dart:198-232` `uploadImage()` with optional `cacheControl` param → `SettableMetadata`. Heirloom path `users/{userId}/recipes/{recipeId}/heirloom/{sha256().substring(0,16)}.jpg`. `public, max-age=31536000, immutable`. Reuses existing `compressImage` helper. (BUT-410)
- [x] **C3. Photo-import toggle + form + UI states** — `photo_import_view.dart`: "Detta är ett arvegods" toggle reveals form (writerName 100ch, year `TextInputFormatter` 1800–2026, note 200ch with counter). States handled: `saving` (spinner), `uploadError` (contextual error engine + "Försök igen"), `offline` (banner "Sparas när du är online igen"). On save: compress → upload(cacheControl) → write `recipe.heirloom`. (BUT-410)
- [x] **C4. `HeirloomStamp` widget + side-by-side detail** — `lib/widgets/recipe/heirloom_stamp.dart` (`AppColors.rust` corner stamp). `HeirloomSection` in `recipe_detail_view.dart` conditionally rendered. Mobile: `PageView` swipe-toggle scan↔parsed + page indicator. Tablet+: reuse Row(flex: 4, 6) from `recipe_detail_tablet_content.dart:51-131`. Tap image → existing image viewer (check `lib/widgets/recipe/` before creating). Add spec to `_butlery-components.html`. (BUT-410)
- [x] **C5. Tests + l10n** — 6 model round-trip incl. validation rejections + widget (stamp, conditional detail render, swipe-toggle, tablet two-col, form validation) + upload cache-control test + GDPR cascade test. Keys: `heirloomToggle`, `heirloomWriterLabel`, `heirloomYearLabel`, `heirloomNoteLabel`, `heirloomFrom(name, year)`, `heirloomUploadOffline`, `heirloomUploadError`. Both arb files. GDPR covered by existing `storage_deletion_operations.dart:26-69` via `users/{userId}/` prefix. (BUT-410)

### Post-Sprint Steps

- [x] BUT-409 → Done (shipped today in `bea402831`)
- [x] `dart analyze --fatal-infos` — expect 0 issues
- [x] Targeted tests per agent batch
- [ ] Manual verification (pending user smoke-test):
  - BUT-406: open cooking mode, long-press "koka 10 min" line → timer pre-filled at 10:00; background → resume accurate; haptic+snackbar on expiry
  - BUT-408: `firebase emulators:start`; two sessions same group → Session A enters cooking, Session B sees "Anna lagar X" card with amber pulse; session end → card disappears within 60s
  - BUT-410: import heirloom photo, verify content-addressed Storage path + `Cache-Control` header; detail view side-by-side on tablet, swipe-toggle on mobile
- [x] Commit, push to main — `ba08da618` + `272b5bd4b` + `fc8d5062f`
- [ ] Update Linear: BUT-406, BUT-408, BUT-410 → Done

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
