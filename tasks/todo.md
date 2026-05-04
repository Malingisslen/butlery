# Sprint Backlog

## Sprint: parsing/social tech-debt + dependency hygiene — 2026-05-04 (F)

Theme: cluster of 7 P4 tech-debt tickets across parsing (compound splitter doc + LLM few-shots), social widget consolidation, OCR persistence, and dependency hygiene. **7 implementations + 1 obsolete close. 3 batches.**

**In Progress carry-overs (NOT in this sprint):**
- BUT-442 — repo migrations (4 candidates remaining; deserves own focused sprint).
- BUT-760 — App Check enforcement; awaiting Firebase Console flip.

**Step 0 verification — done:**
- **BUT-698** premise-gone (closed as Duplicate) — `compound_splitter.dart:19` already has `_maxCacheSize = 200` + FIFO eviction (`_cache.remove(_cache.keys.first)`) + `clearCache()` exposed at line 75. Ticket assumed unbounded growth. Two cosmetic follow-ups absorbed into BUT-700: rename "LRU cache" comment to "FIFO cache" (matches code), and full doc-comment on `_minWordLength`.
- **BUT-700** valid — `_minWordLength = 6` at `compound_splitter.dart:32` has minimal comment. Add full tradeoff doc + test reference.
- **BUT-682** valid — `OCRUsageTracker` (`ocr_usage_tracker.dart`) is in-memory only. Add SharedPreferences persistence keyed by `YYYY-MM-DD`.
- **BUT-676** plan-stale (path) — Lives in TS at `functions/src/llm/gemini-client.ts:355`, NOT lib/Dart. Cloud Functions change. Linear ticket re-scoped.
- **BUT-631** valid — `_Avatar` (size 32) at `activity_pings_feed.dart:418`, `_AvatarThumb`+`_InitialsSquare`+`_OnlineDot` at `family_presence_bar.dart:266+`, both bypass `CachedNetworkImage`. `UserAvatarWidgets.avatar` exists with `showStatus`/`isOnline`. ImageSize enum has 16/48 — add `explicitSize` override.
- **BUT-630** plan-stale (path) — No `lib/services/notifications/strategies/` dir; strategies are static const fields on `NotificationStrategy` in `notification_types.dart`. l10n keys `pingNudgeFrom`/`pingTimerAlertFrom`/`pingHelpMeFrom` already exist. Linear ticket re-scoped.
- **BUT-513** valid — `google_sign_in_mocks: ^0.4.1` at `pubspec.yaml:120`. No production `google_sign_in` dep; social-login deferred post-beta. Trivial removal.
- **BUT-529** valid — `pubspec.yaml:113` has `# Downgraded for drift_dev compatibility` but doesn't reference the specific drift_dev version. Improve to `# Pinned to match drift_dev 2.29.0 — bump together.` and add reciprocal note on drift_dev line.

### Agent A: parsing tech-debt — flutter-developer + cloud-functions-specialist

- [ ] **A1. BUT-700 — Document _minWordLength + correct LRU/FIFO comment** —
  - `lib/utils/text/compound_splitter.dart`:
    - Line 17 doc: change "LRU cache" → "FIFO cache" (matches the `_cache.keys.first` eviction policy actually implemented).
    - Line 32 `_minWordLength`: expand doc-comment to cover (1) what it gates, (2) tradeoff direction (lower = more aggressive splitting → over-splits like "salt" → "sa"+"lt"; higher = more conservative → "potatisgratäng" stays whole), (3) chosen value rationale (shortest meaningful Swedish noun where compound-splitting starts paying off — verified via the `_minComponentLength = 3` floor + Swedish-vocabulary scan), (4) reference `test/unit/utils/text/compound_splitter_test.dart` to re-run if tweaked.
    - Line 28-29 `_minComponentLength`: while there, add a one-line note that this is a stricter sub-floor (component must be ≥3 chars regardless of word length).
  - No behavior change. No new test needed — existing suite covers behavior. (BUT-700)

- [ ] **A2. BUT-682 — Persist OCR daily counter to SharedPreferences** —
  - `lib/services/ocr/ocr_usage_tracker.dart`:
    - Add async `init({SharedPreferences? prefs})` factory or method that loads stored daily count if its date key matches today; otherwise zero. Keep monthly count in-memory (already auto-resets per month from existing logic; persistence isn't critical for monthly).
    - Storage keys: `ocr_usage_daily_count` (int) + `ocr_usage_daily_date` (string `YYYY-MM-DD`). On read, drop count if date != today.
    - In `recordUsage(provider)` after the existing increment, write `_dailyRequestCount` + today's date back to SharedPreferences. Best-effort fire-and-forget — don't block the OCR call path.
    - Constructor stays sync; call sites that want persistence call `await tracker.loadFromPersistence()` (additive, opt-in to keep DI graph simple).
  - Wire-up: find OCRUsageTracker construction site (likely DI module); add the load call in service init. Grep `OCRUsageTracker(` to locate.
  - Tests: `test/unit/services/ocr/ocr_usage_tracker_test.dart` — extend or add: persisted-count survives reconstruction, stale-date entry is dropped, write-after-record happens. Use `SharedPreferences.setMockInitialValues({})`. (BUT-682)

- [ ] **A3. BUT-676 — Expand INGREDIENT_LINE_SYSTEM_PROMPT with 4 more few-shots** —
  - `functions/src/llm/gemini-client.ts:355` — add 4 new EXEMPEL blocks (numbered 3–6) covering uncovered edge cases:
    - **EXEMPEL 3** (fraction unicode): `["½ tsk salt", "¼ kopp socker"]` → fractions parsed numerically (0.5 / 0.25).
    - **EXEMPEL 4** (parenthetical weight): `["1 paket kycklingfilé (ca 600 g)", "2 burkar krossade tomater (à 400 g)"]` → numeric amount captured, weight in preparation.
    - **EXEMPEL 5** (cirka/ca): `["ca 2 dl mjölk", "cirka 200 g pasta"]` → amount captured, "cirka"/"ca" tagged in preparation.
    - **EXEMPEL 6** (instruction-leak / multi-ingredient): `["stek löken tills den blir gyllenbrun", "salt och peppar efter smak"]` → first line yields null parse (or sentinel), second splits to two ingredients.
  - Bump `PROMPT_VERSION` at line 26: `2.0.0` → `2.1.0` so analytics correlates parse-quality changes to this revision.
  - Update `functions/src/llm/PROMPT_CHANGELOG.md` with a 2026-05-04 entry noting the 4 new examples + version bump.
  - Tests: `functions/src/__tests__/gemini-client.test.ts` (or wherever the prompt is referenced) — verify the prompt string contains the new EXEMPEL markers + new PROMPT_VERSION exported.
  - No Firestore prompts-config bump needed — fallback constants are the source of truth, and the live Firestore doc (if any) will pick up the new compiled-in fallback on next deploy. (BUT-676)

### Agent B: social widget + notification consolidation — flutter-developer

- [ ] **B1. BUT-631 — Avatar consolidation onto UserAvatarWidgets.avatar** —
  - `lib/widgets/user/user_avatar_widgets.dart`:
    - Add optional `double? explicitSize` parameter to `avatar(...)`. When non-null, it overrides `_getAvatarSize(size)`.
  - `lib/widgets/social/activity_pings_feed.dart`:
    - Delete private `_Avatar` class (~58 lines) + `_deriveInitials` static helper.
    - At line 324, replace `_Avatar(profile: profile, fallbackName: actorName)` with `UserAvatarWidgets.avatar(imageUrl: profile?.avatarUrl, displayName: actorName, explicitSize: 32.0)`.
  - `lib/widgets/social/family_presence_bar.dart`:
    - Delete `_AvatarThumb` + `_InitialsSquare` + `_OnlineDot` (~70 lines).
    - At lines 240-249 inside `_PresenceAvatar.build`, replace the Stack with a single `UserAvatarWidgets.avatar(imageUrl: profile.avatarUrl, displayName: profile.displayName, explicitSize: 40.0, showStatus: true, isOnline: true)`. The shared widget already renders the bottom-right status dot.
    - Keep `_kAvatarSize = 40.0` constant (still used for `SizedBox` sizing in the parent + `_OverflowChip`).
  - Widget tests: scan `test/widget/widgets/social/` for any `find.byType(_Avatar)` / `find.byType(_AvatarThumb)` probes — those become invalid (private types deleted). Replace with `find.byType(CachedNetworkImage)` or label-based finds.
  - Tests: `test/widget/widgets/social/avatar_consolidation_test.dart` (new, lightweight) — verify `ActivityPingsFeed` and `FamilyPresenceBar` both render `UserAvatarWidgets`-built avatars (look for `Semantics` label `a11yProfileImage(name)` baked into the shared widget). (BUT-631)

- [ ] **B2. BUT-630 — Dedicated ping NotificationStrategy + display-name resolution** —
  - `lib/services/notifications/notification_types.dart`:
    - Add 3 new static const fields on `NotificationStrategy`: `pingNudge`, `pingTimerAlert`, `pingHelpMe`. All `type: immediate`, `priority: high`, `category: social`, with sv/en title+body templates using `{senderName}` (and `{recipeTitle}` placeholder support — left as no-op when not provided).
      - `pingNudge`: title "Knuff från {senderName}" / "Nudge from {senderName}", body "{senderName} puttar på dig" / "{senderName} is nudging you".
      - `pingTimerAlert`: title "Timer-alarm från {senderName}", body "Tid att kolla på maten".
      - `pingHelpMe`: title "{senderName} behöver hjälp", body "Tryck för att svara".
    - Add `static const String ping = 'ping';` to `NotificationPayloadType` for FCM data['type'] consistency.
  - `lib/services/social/ping_service.dart`:
    - Rewrite `_sendPush(ping)`: switch on `ping.type` to pick the matching strategy (`PingType.unknown` → fall back to `pingNudge`).
    - Resolve sender display name: `_friendsService.friends.firstWhereOrNull((f) => f.uid == ping.fromUserId)?.displayName ?? ping.fromUserId`. Pass that as `senderName` instead of the raw UID.
    - Update doc-comment at line 213-215 (the "reuses friendRequest as closest match" note) since that's no longer true.
  - Tests: `test/unit/services/social/ping_service_test.dart` — add cases verifying:
    - `PingType.nudge` routes to `NotificationStrategy.pingNudge`.
    - `PingType.timerAlert` routes to `pingTimerAlert`.
    - `PingType.helpMe` routes to `pingHelpMe`.
    - Display name from `UnifiedFriendsService.friends` is used (mock the service to return a `UserProfile` with `displayName: 'Anna'` for the sender UID).
    - Fallback to UID if friend not found (e.g. ex-friend / cross-group ping).
  - No l10n changes — Swedish text lives directly in the strategy templates (consistent with all other strategies in the file). (BUT-630)

### Agent C: dependency hygiene — no specialist (direct edits)

- [ ] **C1. BUT-513 — Remove unused google_sign_in_mocks** —
  - `pubspec.yaml`: delete line 120 `google_sign_in_mocks: ^0.4.1` from `dev_dependencies`.
  - Run `flutter pub get`.
  - Run `flutter test` smoke (or at least `flutter analyze`) to confirm no transitive use.
  - Grep `google_sign_in_mocks` and `GoogleSignInMocks` across `test/` to be thorough — if any test file imports it, that's the signal to revert. (Verified during Step 0 — no usages.) (BUT-513)

- [ ] **C2. BUT-529 — Document build_runner pin rationale** —
  - `pubspec.yaml`:
    - Line 113: replace existing `# Downgraded for drift_dev compatibility` with `# Pinned to match drift_dev 2.29.0 — bump together (codegen breaks otherwise).`
    - Line 114: replace existing `# Code generator for Drift database (compatible version)` with `# Code generator for Drift — stays in lockstep with build_runner 2.7.1 above.`
  - Doc-only. (BUT-529)

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` — 0 issues
- [ ] Functions: `cd functions && npm run build && npm test -- --testPathPattern='gemini-client'`
- [ ] Affected Dart unit tests: `compound_splitter_test`, `ocr_usage_tracker_test`, `ping_service_test`, plus widget test for avatar consolidation
- [ ] `flutter pub get` (clean)
- [ ] Tier-2 specialist gates: `code-reviewer` (any .dart), `testing-specialist` (any lib/), `firebase-backend-security` (ping_service.dart touched — auth/permission boundary)
- [ ] Commit, push to main
- [ ] CI watcher monitors green
- [ ] Update Linear: BUT-700/682/676/631/630/513/529 → Done

### Continued blockers (NOT in scope per memory)
- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred (Apple Dev enrollment gated)
- BUT-549 — post-beta (Sign in with Apple lands when social login does)
- BUT-579 — held for button-system sprint
- BUT-444 / BUT-445 — own product-design sprints
- BUT-498 / BUT-697 — explicitly skipped
- BUT-686 / BUT-660 / BUT-694 — feature-level brainstorming first
- BUT-674 / BUT-721 — own scoped sprints
- BUT-626 — bucket-based A/B infra; own sprint
- BUT-420 / BUT-451 / BUT-452 / BUT-486 — deploy-pipeline / staging cluster; focused infra sprint
- BUT-550 / BUT-536 / BUT-441 — ACCEPTED_LARGE_FILES drift sprint
- BUT-558 — DCM install (own sprint)
- BUT-554 — tracking ticket (blocked on drift_dev upstream)
- BUT-594 — macOS sandbox audit needs hardware-exercise step
- BUT-701 — focus traversal (2-day a11y sprint)
- BUT-479 — cursor-pagination half is non-trivial; needs design ticket
- BUT-435 + BUT-502/503/507/509 — Dart SDK 3.10 bump cluster (one focused sprint)
- All `idea`-labeled monetization scaffolding — post-beta

---

## Archived prior sprint (completed in commit 75873d1e1)

Pre-beta moderation + anti-spam + UGC compliance — 2026-05-04 (E) — shipped BUT-537/544/649/651/654/659. See git log for full task breakdown.
