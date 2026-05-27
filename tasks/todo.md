# Sprint Backlog

## Sprint: iter-82 — P3 Bug batch: race + diagnostic + silent-throw hygiene — 2026-05-27 (Wed)

Theme: Four P3 Bug tickets dispatched to 2 parallel agents. All small mechanical-fit shape (ticket-then-flip). Same proven pattern as iter-78/79/80. Phase 1.5 expansion fires on BUT-1131 and BUT-894 (Bug+social+recipe combo) — richer plan documented inline, no halt.

### Ship this sprint

#### Agent A — Recipe lifecycle race + orphan hygiene

- [x] **A1. RecipeFormAutoSaveManager.clearCurrentDraft → async + await deleteDraft** — `lib/viewmodels/recipe_form/recipe_auto_save_manager.dart:387-392`. Method becomes `Future<void>` and `await`s `deleteDraft(_currentDraftId!)` before nulling. Update callers — grep all `clearCurrentDraft()` sites and either `await` or `unawaited(...)` per call-site intent. (BUT-1138)
- [x] **A2. Add race-pin test** — `test/unit/viewmodels/recipe_form/recipe_auto_save_manager_test.dart`. New test in clearCurrentDraft group: drive `await mgr.clearCurrentDraft(); await mgr.saveNow(form)`, assert the saved draft's metadata does NOT collide with the just-cleared draft's metadata. (BUT-1138)
- [x] **A3. Extend _cleanupRecipeReferences to delete shared_content (or shared_recipes) records** — `lib/services/unified/modules/service_adapters/recipe_service_adapter.dart:101-...`. Add a paginated batch delete of `FirestoreCollections.sharedContent` (verify exact constant name via grep) where `originalRecipeId == recipeId`. Mirror the existing pattern for comments/ratings/social_stats. Mind: if a `members` subcollection exists, follow the soft-cascade pattern already used elsewhere. (BUT-894)
- [x] **A4. Add BUT-894 orphan-cleanup test** — `test/unit/services/unified/modules/service_adapters/recipe_service_adapter_test.dart` (or its existing test file). Seed Firestore fake with a recipe + 1 shared_content record where `originalRecipeId == recipeId`. Call `deleteRecipe(recipeId)`. Assert: recipe doc gone AND shared_content record gone. (BUT-894)

#### Agent B — Diagnostic + silent-throw error surfacing

- [x] **B1. BackupService per-recipe error: read `core.title` with `title` fallback** — `lib/services/backup_service.dart:235`. One line: `recipeJson['core']?['title'] ?? recipeJson['title'] ?? AppLocale.current.backupUnknownRecipe`. The double fallback handles current nested + any future top-level shape. (BUT-1139)
- [x] **B2. Update test pin in backup_service_test.dart** — the test `'isolates per-recipe repository failures into errors list'` now asserts the error string contains the real recipe title (from `core.title`), not "Okänt recept". (BUT-1139)
- [x] **B3. SocialRecipeSharingService secondary-write: bump log severity warning→error + setError so UI can react** — `lib/services/unified/modules/social_recipe/social_recipe_sharing_service.dart:152-156`. Keep return `true` (primary write succeeded). Change `AppLogger.warning(...)` → `AppLogger.error(...)`. Add `_setError(AppLocale.current.errorSharedRecipeMayNotBeVisible)` (or similar — add l10n key to ARB + @meta; Swedish: "Receptet delades, men mottagaren kanske inte ser det. Försök igen om de inte hittar det."). (BUT-1131)
- [x] **B4. Add BUT-1131 error-surfaced test** — `test/unit/services/unified/modules/social_recipe/social_recipe_sharing_service_test.dart`. Test: primary write succeeds, secondary write throws → `shareRecipe` returns true (primary intent honoured) AND `service.error` is set to the new sanitized message. (BUT-1131)
- [x] **B5. Run `flutter gen-l10n` after B3** to regenerate AppLocalizations.

### Step 0 — premise verification (done)

- **BUT-1138** verified: `recipe_auto_save_manager.dart:387-392` — `deleteDraft(_currentDraftId!)` is unawaited as ticket describes. Method signature is `void clearCurrentDraft()`. Becomes `Future<void>`.
- **BUT-1139** verified: `backup_service.dart:235` — `recipeJson['title'] ?? AppLocale.current.backupUnknownRecipe`. Top-level read.
- **BUT-1131** verified: `social_recipe_sharing_service.dart:152-156` — warning log + comment "// Don't fail the whole operation if this secondary write fails" + no setError. Return path at line 162 returns `true`.
- **BUT-894** verified: `_cleanupRecipeReferences` at `lib/services/unified/modules/service_adapters/recipe_service_adapter.dart:101`. Currently cleans up comments + ratings + social_stats. Called from `deleteRecipe()` at line 76.

### ★ Risky-ticket plan — BUT-1131 ──────────────────
Classification: **fits** (Bug+social+recipe label triggers Phase 1.5 — surfacing a silent throw on a write path warrants the extra plan)
Files: `lib/services/unified/modules/social_recipe/social_recipe_sharing_service.dart` (1 catch-block edit) + `lib/l10n/app_sv.arb` + `lib/l10n/app_en.arb` (new key `errorSharedRecipeMayNotBeVisible`) + test (1 new test) + regen.
Blast radius: catch block behavior changes from silent → setError(...) but return value stays `true`. UI callers that currently rely on `result == true` to mean "fully shared" will now see `service.error` non-null on the rare secondary-failure path. UI is free to read or ignore. No other callers (this is the unified service's public method; SocialMenuCoordinator's mirror was already fixed in iter-79 BUT-1094).
Product-intent flags: I'm choosing option A from the 4 options in the ticket (log+setError+keep returning true). Options B (retry), C (atomic rollback), D (partial-success type) are larger and folded into a follow-up if telemetry shows real frequency.
Rollback: revert the catch block; no schema, no API change. The new l10n key is additive.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

### ★ Risky-ticket plan — BUT-894 ──────────────────
Classification: **fits** (Bug+social+recipe — orphan cleanup on delete path warrants the extra plan)
Files: `lib/services/unified/modules/service_adapters/recipe_service_adapter.dart` (extend `_cleanupRecipeReferences` ~25-line addition mirroring the existing comments/ratings paginated-delete pattern) + test (1 new test).
Blast radius: every recipe delete now also runs a paginated query against the shared_content (or shared_recipes — agent confirms via grep) collection. For users who haven't shared the recipe, the query returns 0 docs and the batch is a no-op. For shared recipes, the recipient's inbox now correctly drops the dead reference. Pre-existing behaviour (graceful degrade on broken refs) means rollback is safe.
Product-intent flags: BUT-894 mentions "soft-delete epic" as a future option — that's NOT this ticket. This ticket is hard-delete cascade; soft-delete would supersede if/when it ships.
Rollback: revert the extension; orphan records remain (current behaviour). No schema effect.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

### Acceptance

- [ ] Each agent reports `flutter analyze --fatal-infos` clean on its touched lib files.
- [ ] Each agent reports its touched test files pass.
- [ ] `flutter gen-l10n` succeeded after BUT-1131 ARB addition.
- [ ] Orchestrating session runs full `dart analyze --fatal-infos` after all agents finish.
- [ ] Tier-2 reviewers (code-reviewer + testing-specialist) clean.

### Post-Sprint Steps

- [ ] Orchestrating session does unified `git add` + commit + push.
- [ ] Close BUT-1138, BUT-1139, BUT-1131, BUT-894 in Linear.

---

## Archived iter-81 (commits `503a05567` + `991a8a653` — BUT-1063 + BUT-1062 + BUT-1074) — 2026-05-27 (Wed)

Theme: Three independent testability tickets dispatched to 3 parallel agents. All add testability seams (ctor params or rename to `Fake` shape).

Theme: Three independent testability tickets dispatched to 3 parallel agents. All add testability seams (ctor params or rename to `Fake` shape).

### Ship this sprint

#### Agent A — BUT-1063 RecipeParserService cache ctor seam
- [x] Add `cache:` ctor param to `RecipeParserService` accepting a `LocalRecipeCache` interface (or expose the existing DAO via `@visibleForTesting` ctor).
- [x] Unlocks ~5 cache-behaviour unit tests in `recipe_parser_service_test.dart`.

#### Agent B — BUT-1062 UnifiedMenuService DI seam
- [x] Add ctor params: `sharedMenuRepository`, `menuService`, `userService`, `realtimeMenuService` — each with default factory falling back to ServiceLocator/production. Mirrors the existing `firestoreRepository` pattern.
- [x] Unlocks ~5 currently-skipped tests in `unified_menu_service_test.dart`. No new tests required this sprint — the DI seam is the deliverable.

#### Agent C — BUT-1074 MockAuthRepository rename to FakeAuthRepository
- [x] Rename `MockAuthRepository` → `FakeAuthRepository` and switch from `extends Mock` to `extends Fake implements AuthRepository` in `test/infrastructure/mocks/production_mocks.dart`.
- [x] Audit all callers (grep `MockAuthRepository`); update any caller that was relying on `when()` (those tests were already broken — the `when()` was silently overridden by the concrete @override getters).

### Acceptance

- [x] Each agent reports `flutter analyze --fatal-infos` clean on its touched lib files.
- [x] Each agent reports its touched tests pass (or, for BUT-1062, that existing tests still pass — no new tests required).
- [x] Orchestrating session runs full `dart analyze --fatal-infos` after all agents finish.
- [x] Tier-2 reviewers clean.

### Post-Sprint Steps

- [x] Orchestrating session does unified commit + push. (commit `503a05567`)
- [x] Close BUT-1063, BUT-1062, BUT-1074 in Linear. (closed 2026-05-27)
- [x] File follow-ups: BUT-1141 (cache tests), BUT-1142 (collaborative-ops DI seam), BUT-1143 (delete dead configureAuthStateStream).

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
