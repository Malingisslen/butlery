# Sprint Backlog

## Sprint: iter-81 — Parallel-agent execution: DI-seam testability — 2026-05-26 (Tue)

Theme: Three independent testability tickets dispatched to 3 parallel agents. All add testability seams (ctor params or rename to `Fake` shape).

### Ship this sprint

#### Agent A — BUT-1063 RecipeParserService cache ctor seam
- [ ] Add `cache:` ctor param to `RecipeParserService` accepting a `LocalRecipeCache` interface (or expose the existing DAO via `@visibleForTesting` ctor).
- [ ] Unlocks ~5 cache-behaviour unit tests in `recipe_parser_service_test.dart`.

#### Agent B — BUT-1062 UnifiedMenuService DI seam
- [ ] Add ctor params: `sharedMenuRepository`, `menuService`, `userService`, `realtimeMenuService` — each with default factory falling back to ServiceLocator/production. Mirrors the existing `firestoreRepository` pattern.
- [ ] Unlocks ~5 currently-skipped tests in `unified_menu_service_test.dart`. No new tests required this sprint — the DI seam is the deliverable.

#### Agent C — BUT-1074 MockAuthRepository rename to FakeAuthRepository
- [ ] Rename `MockAuthRepository` → `FakeAuthRepository` and switch from `extends Mock` to `extends Fake implements AuthRepository` in `test/infrastructure/mocks/production_mocks.dart`.
- [ ] Audit all callers (grep `MockAuthRepository`); update any caller that was relying on `when()` (those tests were already broken — the `when()` was silently overridden by the concrete @override getters).

### Acceptance

- [ ] Each agent reports `flutter analyze --fatal-infos` clean on its touched lib files.
- [ ] Each agent reports its touched tests pass (or, for BUT-1062, that existing tests still pass — no new tests required).
- [ ] Orchestrating session runs full `dart analyze --fatal-infos` after all agents finish.
- [ ] Tier-2 reviewers clean.

### Post-Sprint Steps

- [ ] Orchestrating session does unified commit + push.
- [ ] Close BUT-1063, BUT-1062, BUT-1074 in Linear.

---

## Archived iter-80 (commit `4f6489ea4` — BUT-1087 + BUT-1114 + BUT-1125) — 2026-05-26 (Tue)

Theme: Three P3 tickets dispatched simultaneously to 3 general-purpose agents. Each cluster touches an independent file tree so there's no merge collision. Orchestrating session does the unified commit.

### Ship this sprint

#### Agent A — SocialRecipeService error-state refactor (BUT-1087)
- [ ] **A1. Extract `_setErrorFromException(String message, Object e)` helper + call from every catch block in `social_recipe_service.dart`** (lines 130, 145, 185, 230, 283, 300 cited).
- [ ] **A2. Clear `_error = null` at the entry of each public mutator** (or via `_resetError()` helper at method top).
- [ ] **A3. Flip pinning tests in `social_recipe_service_test.dart`** — undismiss/markAsViewed/import false returns now ALSO populate `service.error`. Add test for "success after failure clears error".

#### Agent B — InstagramPipeline tier-2 source provenance (BUT-1114)
- [ ] **B1. Add `instagramCaption` enum value to `SourceArtefactType`** in `lib/models/recipe/source_artefact.dart`.
- [ ] **B2. In `instagram_pipeline.dart` tier-2 success path: copyWith sourceUrl=input + SourceArtefact(type: instagramCaption, payload: caption)**. Mirror the tiktok_pipeline shape.
- [ ] **B3. Adjust instagram_pipeline_test.dart docstring** to reflect that BUT-1114 is fixed (production-level — full pin requires WebScraper injection seam, deferred).

#### Agent C — SocialShoppingCoordinator perf parallelize (BUT-1125)
- [ ] **C1. `loadStatusForShoppingList`: collapse 3 sequential awaits via `Future.wait([hasViewed, hasEngaged, hasDismissed])`**.
- [ ] **C2. `loadStatusForAllShoppingLists`: parallelise via `Future.wait(shoppingLists.map(...))`**.
- [ ] **C3. Update / add test verifying the parallel-fetch contract** — assert all 3 stat reads are issued before any await on the next list item.

### Step 0 — premise verification

Delegated to each agent's first phase. Each agent must read current code state, classify fits/premise-gone/plan-stale, and report classification before implementing.

### Acceptance

- [ ] Each agent reports `flutter analyze --fatal-infos` clean on its touched lib files.
- [ ] Each agent reports its touched test files pass.
- [ ] Orchestrating session runs full `dart analyze --fatal-infos` after all agents finish.
- [ ] Tier-2 reviewers (code-reviewer + testing-specialist) clean.

### Post-Sprint Steps

- [ ] Orchestrating session does unified `git add` + commit + push.
- [ ] Close BUT-1087, BUT-1114, BUT-1125 in Linear.

---

## Archived iter-79 (commit `0f339ad43` — BUT-1107 + BUT-1108 + BUT-1098 + BUT-1100 + BUT-1124) — 2026-05-26 (Tue)

Theme: Five small mechanical-fit P3 Bug tickets. Two batches with cross-cluster discipline (BUT-1108 = security label, triggers Phase 1.5 expansion). Deferred: BUT-1087 (service-wide refactor — bigger than ticket-then-flip shape), BUT-1106 (Firestore transaction redesign — needs careful blast-radius review).

### Ship this sprint

#### Agent A — Shopping social share-module hardening

- [ ] **A1. ShoppingSocialShareModule.importSharedShoppingList: switch `.update()` → `.set(..., merge:true)`** — `lib/services/unified/operations/modules/shopping_social_share_module.dart:343-351`. (BUT-1107)
- [ ] **A2. Flip "no received pointer" pinning test** — `test/unit/services/unified/operations/modules/shopping_social_share_module_test.dart:916-935`. Now asserts `out == sharedListId` (import succeeds, pointer created) instead of `isNull`. (BUT-1107)
- [ ] **A3. ShoppingSocialShareModule.getShoppingListsSharedWithMe: add `sharedWithUserIds.contains(currentUserId)` check in inbox loop** — same file, around line 256-272 (before the `sharedLists.add({...})` block). Defense-in-depth — implicit access via received_lists pointer is no longer the only gate. (BUT-1108, security)
- [ ] **A4. Add BUT-1108 defense-in-depth test** — same test file. New test in `getShoppingListsSharedWithMe` group: seed a shared doc WITHOUT current user in `sharedWithUserIds`, plus a received_lists pointer, and assert the entry is filtered out of the result. (BUT-1108)

#### Agent B — Presence + legacy social-coord error hygiene

- [ ] **B1. PresenceService.dispose: split set(offline) + cancel into separate try-blocks** — `lib/services/presence_service.dart:171-178`. (BUT-1098)
- [ ] **B2. PresenceService.resetForLogout: same split** — same file, lines 190-197. (BUT-1098)
- [ ] **B3. Add BUT-1098 "cancel-after-set-throws" test** — `test/unit/services/presence_service_test.dart`. New test in dispose() group: when `ref.set(any())` throws, `disconnect.cancel()` MUST still be called. (BUT-1098)
- [ ] **B4. PresenceService.didChangeAppLifecycleState: wrap fire-and-forget RTDB writes in `.catchError`** — `lib/services/presence_service.dart:332-353`. Use `unawaited(_presenceRef?.set(...).catchError((e) { AppLogger.warning(...); }))` for each set/onDisconnect call. (BUT-1100)
- [ ] **B5. Add BUT-1100 "lifecycle-state errors are swallowed" test** — `test/unit/services/presence_service_test.dart`. Drive `didChangeAppLifecycleState(paused)` after stubbing `ref.set(any())` to throw — assert no unhandled async exception escapes. (BUT-1100)
- [ ] **B6. SocialMenuCoordinator legacy `importSharedMenu`: add `setError(sanitizeErrorForUser(e))` to catch** — `lib/services/unified/modules/social_menu/social_menu_coordinator.dart:354-357`. Mirrors the BUT-1094 fix pattern already shipped on the non-legacy paths. (BUT-1124)
- [ ] **B7. Add BUT-1124 setError test for legacy path** — `test/unit/services/unified/modules/social_menu/social_menu_coordinator_test.dart`. New test: legacy `importSharedMenu` repo throw → setError called with sanitised message, lastError populated. (BUT-1124)

### Step 0 — premise verification (done)

- **BUT-1107** verified: `shopping_social_share_module.dart:343-351` — `.update()` on missing received_lists doc throws `FirebaseException(not-found)`, swallowed at line 355-358. Pinning test at line 916-935 in test file.
- **BUT-1108** verified: `getShoppingListsSharedWithMe` lines 254-272 build result map WITHOUT `sharedWithUserIds` membership check. `importSharedShoppingList` already has this check at line 335-340 — adding the same shape to the inbox read.
- **BUT-1098** verified: `presence_service.dart:172-178` (dispose) and 190-197 (resetForLogout) both have `set` + `cancel` in same try block. Existing test at line 428 only asserts `dispose() completes` — doesn't pin the "cancel still runs after set throws" contract.
- **BUT-1100** verified: `presence_service.dart:332-353` — `didChangeAppLifecycleState` fires off 3 RTDB calls (`paused`-branch set, `resumed`-branch onDisconnect.set + set) with no await + no catch.
- **BUT-1124** verified: `social_menu_coordinator.dart:354-358` — legacy `importSharedMenu` catch logs but does NOT call `setError(sanitizeErrorForUser(e))`. Diverges from the BUT-1094 pattern shipped on the non-legacy paths (line 376 reference).

### ★ Risky-ticket plan — BUT-1108 ──────────────────
Classification: **fits** (security label on a defense-in-depth fix — mechanical but matters)
Files: `lib/services/unified/operations/modules/shopping_social_share_module.dart` (1 inserted check in loop) + test (1 new test).
Blast radius: `getShoppingListsSharedWithMe` becomes stricter. Any list where the user has a `received_lists` pointer but is NOT in the canonical `sharedWithUserIds` is now invisible. Practically this should never happen under correct Firestore rules — the implicit gate (rules + pointer creation) already prevents it. The new check is belt-and-suspenders for rule regressions. Verified: no test depends on the "stranger pointer succeeds" path (would be a security test failure if it did).
Rollback: revert the one-line `continue`; no schema or data effect.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

### Acceptance

- [ ] `flutter analyze --fatal-infos` clean.
- [ ] Each touched test file passes.

### Post-Sprint Steps

- [ ] Run code-reviewer + testing-specialist agents per Tier-2 gate.
- [ ] Commit + push.
- [ ] Close BUT-1107, BUT-1108, BUT-1098, BUT-1100, BUT-1124 in Linear.

---

## Archived iter-78 (commit `1a07a77a7` — BUT-1092 + BUT-1113 + BUT-1116 + BUT-1091 + BUT-1118 + BUT-1128 + BUT-1102) — 2026-05-26 (Tue)

Theme: Seven P3 Bug tickets from intent-test sprint batches 5–10, all "ticket-then-flip" shape. Two coherent batches: Agent A (4 import-regex bugs) + Agent B (3 upload-status bugs). Same proven pattern as iter-76/77.

### Ship this sprint

#### Agent A — Imports: case-sensitivity + host-anchoring (regex hardening)

- [x] **A1. TikTokPipeline: add `caseSensitive: false` to 4 patterns** — `lib/services/import/pipelines/tiktok_pipeline.dart:56-65`. (BUT-1092)
- [x] **A2. Flip tiktok pinning test** — `test/unit/services/import/pipelines/tiktok_pipeline_test.dart`. `isFalse` → `isTrue` on mixed-case host case. (BUT-1092)
- [x] **A3. InstagramPipeline: add `caseSensitive: false` to 4 patterns** — `lib/services/import/pipelines/instagram_pipeline.dart:22-26`. (BUT-1113)
- [x] **A4. Flip instagram pinning test** — `test/unit/services/import/pipelines/instagram_pipeline_test.dart`. Mixed-case host PINNED→passes. (BUT-1113)
- [x] **A5. YouTubeTranscriptService: add `caseSensitive: false` to 6 video-ID patterns** — `lib/services/import/youtube/youtube_transcript_service.dart:20-32`. (BUT-1116)
- [x] **A6. Flip youtube_import_strategy_test sibling-hunt assertion** — `test/unit/services/import/youtube/youtube_import_strategy_test.dart`. (BUT-1116)
- [x] **A7. YouTubeTranscriptService: anchor host regex (typosquat fix)** — `lib/services/import/youtube/youtube_transcript_service.dart:20-32`. Add `^https?://(?:www\.|m\.)?` prefix to youtube.com patterns, `^https?://` to youtu.be. Keep bare-ID pattern unchanged. (BUT-1091)
- [x] **A8. Flip youtube_transcript_service_test CHARACTERIZATION** — `test/unit/services/import/youtube/youtube_transcript_service_test.dart`. `equals(_vid)` → `isNull` for typosquat cases. (BUT-1091)

#### Agent B — Upload status bugs

- [x] **B1. UploadQueueManager.addCompletedUpload: add containsKey guard** — `lib/services/upload/upload_queue_manager.dart:58-69`. Mirror `addUpload` warning+no-op shape. (BUT-1118)
- [x] **B2. Flip upload_queue_manager_test "asymmetry" pinning test** — `test/unit/services/upload/upload_queue_manager_test.dart:168-186`. Assert pre-existing entry is PRESERVED (state == uploading, progress == 0.4) and warning is logged. (BUT-1118)
- [x] **B3. ImageUploadCoordinator: replace errorGeneric with sanitizeErrorForUser(e)** — `lib/viewmodels/recipe_form/image_management/image_upload_coordinator.dart:120-123`. Import `error_sanitizer.dart` if needed. (BUT-1128)
- [x] **B4. Add image_upload_coordinator fatal-batch test** — `test/unit/viewmodels/recipe_form/image_management/image_upload_coordinator_test.dart`. New test in "fatal-batch" group: when storage throws a typed exception (e.g. FormatException with message), assert errorsSet contains a sanitised message (NOT "Ett fel uppstod"). (BUT-1128)
- [x] **B5. UploadQueueSummaryCalculator: thread cancelled through + add all-cancelled branch** — `lib/viewmodels/recipe_form/image_management/upload_queue_summary_calculator.dart`. Add `cancelled` param to `getEnhancedQueueStatusText` (positional, after total). Call site at line 123 passes `cancelled`. Branch before final `else`: `if (cancelled > 0 && active == 0 && pending == 0 && failed == 0 && completed == 0) return l.uploadStatusAllCancelled(cancelled);`. Add l10n key `uploadStatusAllCancelled` to `app_sv.arb` + `app_en.arb` + `@meta`. (BUT-1102)
- [x] **B6. Update upload_queue_summary_calculator_test all-cancelled pin** — `test/unit/viewmodels/recipe_form/image_management/upload_queue_summary_calculator_test.dart:445-450`. Assert text contains '2' and the Swedish/English "alla avbrutna" substring (or just non-empty + cancelled count). Update positional args to include `cancelled`. (BUT-1102)

### Step 0 — premise verification (done)

- **BUT-1092** verified: `tiktok_pipeline.dart:56-65` — 4 `RegExp` lack `caseSensitive: false`. `_isTikTokUrl` lowercases for substring check, then matches original-case `url` against case-sensitive regex.
- **BUT-1113** verified: `instagram_pipeline.dart:21-26` — same shape as BUT-1092, 4 patterns.
- **BUT-1116** verified: `youtube_transcript_service.dart:20-32` — 6 patterns, all case-sensitive.
- **BUT-1091** verified: `youtube_transcript_service.dart:22-30` — no host anchoring; `iyoutube.com/watch?v=...` would match.
- **BUT-1118** verified: `upload_queue_manager.dart:58-69` — unconditional `_queue[key] = ...`. Note ticket says `_uploads` but file uses `_queue` (cosmetic).
- **BUT-1128** verified: `image_upload_coordinator.dart:120-123` — `_setError(AppLocale.current.errorGeneric)`. `sanitizeErrorForUser` exists in `lib/core/utils/error_sanitizer.dart`.
- **BUT-1102** verified: `upload_queue_summary_calculator.dart:155-157` — final `else` returns `''`. Function signature does NOT take `cancelled` — needs threading.

### ★ Risky-ticket plan — BUT-1091 ──────────────────
Classification: **fits** (security label on a regex-validation gate — caution warranted but mechanical)
Files: `lib/services/import/youtube/youtube_transcript_service.dart` (5 regex prefix additions) + test (typosquat assertion flips).
Blast radius: `isYouTubeUrl` becomes stricter. Any legitimate URL caller (share-sheet, paste, channel-watch) MUST start with `http(s)://(www.|m.)?youtube.com` or `http(s)://youtu.be`. Verified: production callers all originate from URL-import flows where the source is already a full URL. The bare-ID pattern is preserved for direct ID entry.
Rollback: revert the prefix additions; no schema or data effect.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

### Acceptance

- [x] `flutter analyze --fatal-infos` clean.
- [x] Each touched test file passes.
- [x] `flutter gen-l10n` succeeded after BUT-1102 ARB additions.

### Post-Sprint Steps

- [ ] Run code-reviewer + testing-specialist agents per Tier-2 gate.
- [ ] Commit + push.
- [ ] Close BUT-1092, BUT-1113, BUT-1116, BUT-1091, BUT-1118, BUT-1128, BUT-1102 in Linear.

---

## Archived iter-77 (commit `7b2d25b35` — BUT-1085 + BUT-1090) — 2026-05-25 (Mon)

Both P2 High social-bug fixes shipped via ticket-then-flip. Acceptance met. BUT-1086 stays open (deferred — needs product decision).
