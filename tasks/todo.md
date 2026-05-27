# Sprint Backlog

## Sprint: iter-89 — Delete dead @Deprecated configureAuthStateStream (BUT-1143) — 2026-05-27 (Wed)

Theme: Single P4 Low pure-cleanup. Pivot from P4 Bug well (BUT-1132 needs deeper scope — Firestore deterministic doc ID or check-then-write w/ idempotent addMember).

BUT-1143 was filed by iter-81 wrap-up as a follow-up after the BUT-1074 rename made `configureAuthStateStream` Fake-incompatible. The ticket suggested "1 sprint of telemetry watch" before deletion, but the testing-specialist's audit at file-time confirmed zero callers via grep — and the method is `@Deprecated` with a clear migration note. The watch was over-cautious; the static audit is sufficient.

No Phase 1.5 expansion (P4 + pure `tech-debt`/`test-gap` labels — explicitly skipped per the rule).

### Ship this sprint

#### Agent — Delete dead method (direct edit, no agent needed)

- [ ] **A1. Delete `MockConfigurator.configureAuthStateStream`** — `test/test_support/mock_configurator.dart:120-136`. Remove the entire method + its 7-line docstring + `@Deprecated` annotation. Confirm via grep that no other file references it (verified: only the knowledge-file doc references it, that's fine to leave). (BUT-1143)
- [ ] **A2. Verify** — `dart analyze --fatal-infos` clean. Full unit suite still green. (BUT-1143)

### Step 0 — premise verification (done)

- **BUT-1143** verified: `mock_configurator.dart:120-136` has the method as described. Grep across `test/` and `lib/` returns zero non-doc references. The method is already `@Deprecated` with a migration note to the local `_MockAuthRepository extends Mock` pattern.

### Acceptance

- [ ] `flutter analyze --fatal-infos` clean.
- [ ] `flutter test test/unit/` still passes (no behavior change — method had no callers).
- [ ] Tier-2 reviewers clean.

### Post-Sprint Steps

- [ ] Orchestrating session does commit + push.
- [ ] Close BUT-1143 in Linear.

---

## Archived iter-88 (commit `b12b40e3e` — BUT-1129) — 2026-05-27 (Wed)

Theme: Single P4 Low Bug. **Plan-stale rescope** — original ticket proposed `this.disposed` field reads, but `disposed`/`uploadsCanceled` are params, not fields. Re-scoped inline to callback-based fresh-read. Linear ticket body updated.

Theme: Single P4 Low Bug. **Plan-stale rescope** — original ticket proposed `this.disposed` field reads, but `disposed`/`uploadsCanceled` are params, not fields. Re-scoped inline to callback-based fresh-read. Linear ticket body updated.

Phase 1.5 doesn't fire (P4 + plain `Bug` label, no area-label combo). Plan-stale rescope handled in Step 0 + Linear ticket edit per the established pattern.

### Ship this sprint

#### Agent — Soft-cancel fresh-read in ImageUploadCoordinator

- [x] **A1. BUT-1129: replace value-passed bool with callback** — `lib/viewmodels/recipe_form/image_management/image_upload_coordinator.dart`. Change `uploadPendingImagesInBackground` (line 60) and `_uploadSingleImageWithTracking` (line 145) params:
  - `required bool disposed` → `required bool Function() isDisposedNow`
  - `required bool uploadsCanceled` → `required bool Function() isUploadsCanceledNow`
  
  Update all 5 cancellation-check sites to call the closures:
  - `image_upload_coordinator.dart:68` outer guard
  - `image_upload_coordinator.dart:157` single pre-upload check
  - `image_upload_coordinator.dart:167` notifyListeners guard
  - `image_upload_coordinator.dart:173` single state-update check
  - `image_upload_coordinator.dart:182` single post-upload check
  - `image_upload_coordinator.dart:219` catch-block state-update guard
  
  Update internal call site at `image_upload_coordinator.dart:101-102` (the inner `_uploadSingleImageWithTracking` invocation) to forward the closures.
  
  Update caller in `lib/viewmodels/recipe_form/recipe_image_manager.dart:1214-1215`:
  - `disposed: _disposed` → `isDisposedNow: () => _disposed`
  - `uploadsCanceled: _uploadsCanceled` → `isUploadsCanceledNow: () => _uploadsCanceled`
  
  (BUT-1129)

- [x] **A2. Add BUT-1129 mid-flight soft-cancel test** — `test/unit/viewmodels/recipe_form/image_management/image_upload_coordinator_test.dart`. Pin the now-correct behaviour: 
  - Stub a slow `StorageService.uploadRecipeImage` (e.g. delayed Future)
  - Start `uploadPendingImagesInBackground` with `isDisposedNow: () => disposedFlag` where `disposedFlag` is a local `bool` variable
  - Flip `disposedFlag = true` while uploads are in flight
  - Assert the returned list of URLs is empty (uploads short-circuited)
  
  This test would have failed with the old captured-by-value behaviour (mid-flight flip would have been invisible). (BUT-1129)

### Step 0 — premise verification (done)

- **BUT-1129 PLAN STALE**: `image_upload_coordinator.dart:60-67, 145-152` — `disposed`/`uploadsCanceled` are passed-in parameters, NOT fields on ImageUploadCoordinator. Ticket's `this.disposed` fix doesn't apply. Re-scoped to callback-based fresh-read; Linear ticket body updated to reflect new plan.

### Acceptance

- [ ] `flutter analyze --fatal-infos` clean on touched lib files.
- [ ] Touched test file passes (incl. new mid-flight soft-cancel test).
- [ ] Orchestrating session runs full `dart analyze --fatal-infos`.
- [ ] Tier-2 reviewers clean.

### Post-Sprint Steps

- [ ] Orchestrating session does unified `git add` + commit + push.
- [ ] Close BUT-1129 in Linear.

---

## Archived iter-87 (commit `7d37c88ba` — BUT-1093) — 2026-05-27 (Wed)

Theme: Single P4 Low Bug — mirror-existing-pattern fix. Phase 1.5 expansion fires (menu+social+Bug) — richer plan inline, no halt. The remaining easy P4 Bug well is empty; this is the last clean ticket-then-flip fit. The rest (BUT-1132/1129/897) need larger scope changes.

Theme: Single P4 Low Bug — mirror-existing-pattern fix. Phase 1.5 expansion fires (menu+social+Bug) — richer plan inline, no halt. The remaining easy P4 Bug well is empty; this is the last clean ticket-then-flip fit. The rest (BUT-1132/1129/897) need larger scope changes.

### Ship this sprint

#### Agent — SocialMenuCoordinator imported-menu attribution

- [x] **A1. BUT-1093: replace placeholder in `createImportedContent` forEach with real copyWith** — `lib/services/unified/modules/social_menu/social_menu_coordinator.dart:160-183`. The forEach body currently returns the recipe verbatim with a `// Placeholder` comment. Mirror the pattern from `createStaticCopyForOwner` at lines 542-554: apply `recipe.copyWith(title: '${recipe.title} (Min kopia)', lastCookedAt: null)`. Keep the category names as-is (don't mirror the "$category (Min kopia)" category-suffix from createStaticCopyForOwner — that's a different pattern for static copies, not imports). (BUT-1093)
- [x] **A2. BUT-1093 test flip** — `test/unit/services/unified/modules/social_menu/social_menu_coordinator_test.dart`. Find the test that pins the placeholder behavior (likely asserts the recipe title is unchanged after `createImportedContent`). Flip: assert the imported recipe's title ends with "(Min kopia)" AND `lastCookedAt == null`. (BUT-1093)

### Step 0 — premise verification (done)

- **BUT-1093** verified: `social_menu_coordinator.dart:160-183` — `createImportedContent` has `return recipe; // Placeholder - needs actual Recipe.copyWith implementation` on line 176. The mirror pattern at lines 542-554 (`createStaticCopyForOwner`) uses `recipe.copyWith(title: '${recipe.title} (Min kopia)', lastCookedAt: null)`.

### ★ Risky-ticket plan — BUT-1093 ──────────────────
Classification: **fits** (menu+social+Bug — mirror-existing-pattern fix, smallest possible blast radius)
Files: `lib/services/unified/modules/social_menu/social_menu_coordinator.dart` (1 forEach body, ~5 lines) + 1 test flip.
Blast radius: any user who imports a shared menu via the `createImportedContent` path (the new copy-on-write `joinSharedMenu` flow) will now see recipe titles suffixed with "(Min kopia)" and reset `lastCookedAt`. The legacy `importSharedMenu` path already did this via `SharedMenu.createImportMenu` — this fix brings the new path into alignment. UI-visible change: imported menus now show "(Min kopia)" on each recipe title.
Product-intent flags: NONE. The ticket explicitly states this is the intended behavior; the placeholder was a known TODO from the BaseSocialCoordinator template extraction.
Rollback: revert the forEach body to `return recipe;`. No schema, no data effect — only newly-imported menus get the new title shape.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

### Acceptance

- [ ] `flutter analyze --fatal-infos` clean on touched lib file.
- [ ] Touched test file passes.
- [ ] Orchestrating session runs full `dart analyze --fatal-infos`.
- [ ] Tier-2 reviewers clean.

### Post-Sprint Steps

- [ ] Orchestrating session does unified `git add` + commit + push.
- [ ] Close BUT-1093 in Linear.

---

## Archived iter-86 (commit `38a961ec9` — BUT-1117 + BUT-1115 + BUT-1109 + BUT-1096) — 2026-05-27 (Wed)

Theme: Four P4 Low Bugs across 4 unrelated files. Single agent. All ticket-then-flip mechanical fits. BUT-1109 triggers Phase 1.5 expansion (shopping+Bug combo) but the fix is a tiny i18n change — richer plan documented inline, no halt.

Theme: Four P4 Low Bugs across 4 unrelated files. Single agent. All ticket-then-flip mechanical fits. BUT-1109 triggers Phase 1.5 expansion (shopping+Bug combo) but the fix is a tiny i18n change — richer plan documented inline, no halt.

### Ship this sprint

#### Agent — i18n + content-quality polish

- [x] **A1. BUT-1117: YouTube inputExample uses real video ID** — `lib/services/import/youtube/youtube_import_strategy.dart:35`. Change `'https://www.youtube.com/watch?v=VIDEO_ID'` to `'https://www.youtube.com/watch?v=dQw4w9WgXcQ'`. The 8-char placeholder fails the strategy's own 11-char video-ID regex. (BUT-1117)
- [x] **A2. BUT-1117 self-consistency test** — `test/unit/services/import/youtube/youtube_import_strategy_test.dart`. New test: `expect(strategy.canHandle(strategy.inputExample), isTrue, reason: 'BUT-1117: inputExample must satisfy canHandle')`. (BUT-1117)
- [x] **A3. BUT-1115: l10n the delete-confirmation itemTypes** — `lib/core/utils/common_dialog_actions.dart:46,60,74`. Replace literals: `'recept'` → `context.l10n.itemTypeRecipe`, `'grupp'` → `context.l10n.itemTypeGroup`, `'inköpslista'` → `context.l10n.itemTypeShoppingList`. Add 3 new keys to `app_sv.arb` + `app_en.arb` + @meta. (BUT-1115)
- [x] **A4. BUT-1115 test flip** — `test/unit/core/utils/common_dialog_actions_test.dart`. Find the existing test `'english locale → recipe delete title still leaks Swedish "recept"'` that asserts the BROKEN behaviour. Flip it: in English locale the title should contain "recipe" (NOT "recept"). (BUT-1115)
- [x] **A5. BUT-1109: l10n the shopping-list missing-name fallback** — `lib/services/unified/operations/modules/shopping_social_share_module.dart`. Four sites: lines 54, 272, 273, 310 (the ticket cites old line numbers — actual current lines from grep) — replace `?? '?'` with `?? AppLocale.current.shoppingListUnnamed` (or `?? AppLocale.current.unnamedSharedList` — pick the more semantically correct key name). Add the key to both ARBs + @meta. Swedish: "(Namnlös lista)". English: "(Unnamed list)". (BUT-1109)
- [x] **A6. BUT-1109 pinning test** — find or create a test for `shopping_social_share_module` (test path: `test/unit/services/unified/operations/modules/shopping_social_share_module_test.dart`). Seed a shopping list with no `name` field. Assert the resulting title contains the localised "Namnlös lista" / "Unnamed list" string (NOT a literal `?`). (BUT-1109)
- [x] **A7. BUT-1096: YouTube transcript no double-spaces after marker strip** — `lib/services/import/youtube/youtube_transcript_service.dart:417-428`. Reorder `_cleanTranscript` so the marker stripping runs FIRST, then the whitespace normalization. Current order: normalize→strip→trim (leaves double-spaces). New order: strip→normalize→trim. (BUT-1096)
- [x] **A8. BUT-1096 test flip** — `test/unit/services/import/youtube/youtube_transcript_service_test.dart`. Find the existing test that asserts `isNot(contains('   '))` (3 spaces). Tighten to `isNot(contains('  '))` (2 spaces). (BUT-1096)
- [x] **A9. Run `flutter gen-l10n`** after A3 + A5 ARB additions.

### Step 0 — premise verification (done)

- **BUT-1117** verified: `youtube_import_strategy.dart:35` literal `VIDEO_ID` (8 chars). The video-ID regex in `youtube_transcript_service.dart` requires exactly 11 chars.
- **BUT-1115** verified: `common_dialog_actions.dart:46,60,74` hardcode `'recept'`, `'grupp'`, `'inköpslista'`.
- **BUT-1109** verified: `shopping_social_share_module.dart` has 4 sites of `?? '?'` fallback at lines 54, 272, 273, 310 (line numbers shifted slightly from ticket — same shape).
- **BUT-1096** verified: `_cleanTranscript` at line 417-428 normalizes whitespace at line 420 BEFORE stripping markers at lines 422-425. Markers like `[musik] ` become `''` but the trailing space remains, producing double-spaces.

### ★ Risky-ticket plan — BUT-1109 ──────────────────
Classification: **fits** (shopping+Bug — i18n fallback string, smallest possible blast radius)
Files: `lib/services/unified/operations/modules/shopping_social_share_module.dart` (4 fallback sites — same `?? '?'` shape) + `lib/l10n/app_sv.arb` + `lib/l10n/app_en.arb` + 1 new test.
Blast radius: any path that creates a "shared list" card via this module without a `name` field now shows the localised fallback instead of `?`. UI is purely cosmetic — no consumer relies on the literal `?` character. Confirmed via grep: no `'?'` equality check exists anywhere in the consumer paths.
Product-intent flags: ticket says this is only reachable for "legacy/malformed data" — the normal share flow always sets `name`. Localizing keeps the fallback honest for the corner case.
Rollback: revert the 4 `?? '?'` lines + new ARB keys. No schema effect, no behavior change for healthy data.
Proceeding automatically (no approval gate).
─────────────────────────────────────────────────

### Acceptance

- [ ] `flutter analyze --fatal-infos` clean on touched lib files.
- [ ] Touched test files pass.
- [ ] `flutter gen-l10n` succeeded after A3 + A5 ARB additions.
- [ ] Orchestrating session runs full `dart analyze --fatal-infos`.
- [ ] Tier-2 reviewers clean.

### Post-Sprint Steps

- [ ] Orchestrating session does unified `git add` + commit + push.
- [ ] Close BUT-1117 + BUT-1115 + BUT-1109 + BUT-1096 in Linear.

---

## Archived iter-85 (commit `91c22fca3` — BUT-1119 + BUT-1127 + BUT-1103 + BUT-1104) — 2026-05-27 (Wed)

Theme: Four P4 Low Bugs across the upload subsystem (3 sibling files). Single agent. Same `Bug` shape as iter-84, ticket-then-flip. No Phase 1.5 expansion (all P4 + plain `Bug` label, no area-label combo).

Theme: Four P4 Low Bugs across the upload subsystem (3 sibling files). Single agent. Same `Bug` shape as iter-84, ticket-then-flip. No Phase 1.5 expansion (all P4 + plain `Bug` label, no area-label combo).

### Ship this sprint

#### Agent — Upload subsystem fixes

- [x] **A1. BUT-1119: UploadQueueManager.getSummary['uploading'] honest count** — `lib/services/upload/upload_queue_manager.dart:212`. Change `final uploading = activeUploads.length;` to `final uploading = getByState(ImageUploadState.uploading).length;`. Keep `'active'` key set to `activeUploads.length` (alias for in-flight = uploading+retrying). Add new `'retrying'` key = `getByState(ImageUploadState.retrying).length`. So the summary now has honest semantics: `uploading` = strictly uploading, `retrying` = strictly retrying, `active` = both. (BUT-1119)
- [x] **A2. BUT-1119 pinning test** — `test/unit/services/upload/upload_queue_manager_test.dart`. New test: seed queue with 1 uploading + 1 retrying. Assert `summary['uploading'] == 1` (NOT 2), `summary['retrying'] == 1`, `summary['active'] == 2` (unchanged). (BUT-1119)
- [x] **A3. BUT-1127: ImageUploadCoordinator bulk buttons on single-item state** — `lib/viewmodels/recipe_form/image_management/image_upload_coordinator.dart:326-327`. Change `failed > 1` → `failed >= 1` and `active > 1` → `active >= 1` for `canBulkRetry` / `canBulkCancel`. Option A from the ticket — UX consistency over single-vs-bulk distinction. (BUT-1127)
- [x] **A4. BUT-1127 pinning test flip** — `test/unit/viewmodels/recipe_form/image_management/image_upload_coordinator_test.dart`. Existing tests pin both branches at `> 1`. Flip the assertions to `>= 1`: a queue with 1 failed should now have `canBulkRetry == true`; a queue with 1 active should have `canBulkCancel == true`. (BUT-1127)
- [x] **A5. BUT-1103: UploadQueueSummaryCalculator denominator** — `lib/viewmodels/recipe_form/image_management/upload_queue_summary_calculator.dart:158`. Change `return l.uploadStatusAllFailed(failed, total);` to `return l.uploadStatusAllFailed(failed, failed);`. This branch fires when `completed == 0` AND `failed > 0` — denominator should be the count of items that actually attempted, i.e. just `failed` (cancellations didn't attempt). (BUT-1103)
- [x] **A6. BUT-1103 pinning test flip** — `test/unit/viewmodels/recipe_form/image_management/upload_queue_summary_calculator_test.dart`. Existing test pins `uploadStatusAllFailed(3, 5)` (with cancellations inflating total). Flip to expect `uploadStatusAllFailed(3, 3)` and verify the resulting string no longer says "3 av 5" but rather "3 av 3" (or whichever Swedish form `uploadStatusAllFailed(3, 3)` produces). (BUT-1103)
- [x] **A7. BUT-1104: getSpeedDisplayText sub-1 KB/s precision** — `lib/viewmodels/recipe_form/image_management/upload_queue_summary_calculator.dart:190-200`. In the `< 1.0 MB/s` branch, change the KB formatting to use `toStringAsFixed(1)` when `kbPerSecond < 1.0` (sub-KB cases) so 500 B/s shows as "0.5 KB/s" not "0 KB/s". Keep `toStringAsFixed(0)` for `kbPerSecond >= 1.0` (whole-KB cases). (BUT-1104)
- [x] **A8. BUT-1104 pinning test** — same test file. New test: `getSpeedDisplayText(500)` returns "0.5 KB/s" (not "0 KB/s"). `getSpeedDisplayText(2048)` returns "2 KB/s" (whole KB unchanged). `getSpeedDisplayText(0)` returns '' (no-data unchanged). (BUT-1104)

### Step 0 — premise verification (done)

- **BUT-1119** verified: `upload_queue_manager.dart:166-170` `activeUploads` getter explicitly includes both `uploading` AND `retrying`. Line 212 `final uploading = activeUploads.length` — over-counts.
- **BUT-1127** verified: `image_upload_coordinator.dart:326-327` `canBulkRetry: failed > 1` and `canBulkCancel: active > 1`. Comment confirms intent ("multiple"); matches ticket.
- **BUT-1103** verified: `upload_queue_summary_calculator.dart:155-158` — `uploadStatusAllFailed(failed, total)` fires when `failed > 0 && completed > 0` is false. `total` includes cancelled items, inflating denominator.
- **BUT-1104** verified: `upload_queue_summary_calculator.dart:190-200` — `(500/1024).toStringAsFixed(0) == "0"`. The KB-branch always uses `toStringAsFixed(0)`.

### Acceptance

- [ ] `flutter analyze --fatal-infos` clean on touched lib files.
- [ ] Touched test files pass.
- [ ] Orchestrating session runs full `dart analyze --fatal-infos`.
- [ ] Tier-2 reviewers (code-reviewer + testing-specialist) clean.

### Post-Sprint Steps

- [ ] Orchestrating session does unified `git add` + commit + push.
- [ ] Close BUT-1119 + BUT-1127 + BUT-1103 + BUT-1104 in Linear.

---

## Archived iter-84 (commit `0e85b8786` — BUT-1145 + BUT-1146 + BUT-1147) — 2026-05-27 (Wed)

Theme: Three P4 Low Bugs all in `lib/viewmodels/smart_import_viewmodel.dart`, dispatched to a single agent. Same file, no merge collision risk. All mechanical fits. P3 Bug well dried after iter-83 — graduating to P4 batches; the priority just reflects user-visible impact, the shape is identical. No Phase 1.5 expansion (`import` not in expansion-trigger label list).

Theme: Three P4 Low Bugs all in `lib/viewmodels/smart_import_viewmodel.dart`, dispatched to a single agent. Same file, no merge collision risk. All mechanical fits. P3 Bug well dried after iter-83 — graduating to P4 batches; the priority just reflects user-visible impact, the shape is identical. No Phase 1.5 expansion (`import` not in expansion-trigger label list).

### Ship this sprint

#### Agent — SmartImportViewModel hygiene

- [x] **A1. BUT-1145: reorder pattern matches in `_localizeImportError`** — `lib/viewmodels/smart_import_viewmodel.dart:466-502`. The "could not save" and "could not read" specifics must run BEFORE the generic `_isNetworkError(lower)` so that `"could not save: network unreachable"` gets labelled as a save failure, not a network error. Move lines 488-493 (the `'could not read'` + `'could not save'` blocks) ABOVE line 479 (`_isNetworkError(lower)`). (BUT-1145)
- [x] **A2. Add BUT-1145 pinning test** — `test/unit/viewmodels/smart_import_viewmodel_test.dart`. Test: stub `ImportManager.autoImport` to return `ImportManagerResult.failure('could not save: network unreachable')`. Drive `vm.startUrlImport(...)`. Assert the surfaced error string equals `AppLocale.current.importErrorCouldNotSaveRecipe` (NOT `importErrorCouldNotReachPage`). (BUT-1145)
- [x] **A3. BUT-1146: reset `_lastStepBeforeError` in `triggerManualImport`** — `lib/viewmodels/smart_import_viewmodel.dart:451-461`. Add `_lastStepBeforeError = 0;` before the `_setPhase(ImportPhase.needsHelp)` call. Reason: `needsHelp` is a user-initiated state with no "prior step that failed" — leaking the previous import's last-step into the progress strip is meaningless. (BUT-1146)
- [x] **A4. Add BUT-1146 pinning test** — `test/unit/viewmodels/smart_import_viewmodel_test.dart`. Test: drive a successful import to set `_lastStepBeforeError = 3` (via the `creating` phase), then call `vm.triggerManualImport()`, assert `vm.currentStep == 0` (or whatever the contract for `needsHelp` step should be — read the `currentStep` getter to confirm). (BUT-1146)
- [x] **A5. BUT-1147: short-circuit `_loadPendingImport` when user already typed** — `lib/viewmodels/smart_import_viewmodel.dart:534-550`. After the `isDisposed` check (line 537) and after reading the persisted URL (line 538), add `if (_input.isNotEmpty) return;` BEFORE setting `_hasPendingImport = true`. Effect: if the user typed before prefs resolved, neither the flag nor `notifyListeners()` fires. (BUT-1147)
- [x] **A6. Add BUT-1147 pinning test** — `test/unit/viewmodels/smart_import_viewmodel_test.dart`. Test: stub `SharedPreferences` to return a pending URL with a delay. Construct VM (fires `_loadPendingImport` in init). Before the delay completes, drive `vm.input = "https://user-typed.com"`. Wait for prefs to resolve. Assert `vm.hasPendingImport == false`. (BUT-1147)

### Step 0 — premise verification (done)

- **BUT-1145** verified: `smart_import_viewmodel.dart:479` runs `_isNetworkError(lower)` (matches "network" substring) BEFORE line 491 `'could not save'`. `"could not save: network unreachable"` correctly reproduces the bug.
- **BUT-1146** verified: `triggerManualImport()` at line 451 calls `_setPhase(ImportPhase.needsHelp)`. `_setPhase` at lines 508-510 only sets `_lastStepBeforeError` for `fetching/analyzing/creating` — `needsHelp` leaves whatever value was there.
- **BUT-1147** verified: `_loadPendingImport()` at lines 540-545: `_hasPendingImport = true` + `notifyListeners()` fire unconditionally; the `_input.isEmpty` guard only protects `_input` overwrite, not the banner flag.

### Acceptance

- [ ] `flutter analyze --fatal-infos` clean on touched lib file.
- [ ] Touched test file passes.
- [ ] Orchestrating session runs full `dart analyze --fatal-infos`.
- [ ] Tier-2 reviewers (code-reviewer + testing-specialist) clean.

### Post-Sprint Steps

- [ ] Orchestrating session does unified `git add` + commit + push.
- [ ] Close BUT-1145 + BUT-1146 + BUT-1147 in Linear.

---

## Archived iter-83 (commit `ca66e0fce` — BUT-1144 + BUT-1070) — 2026-05-27 (Wed)

Theme: Two P3 import-area Bug tickets, single agent (small clean batch). Both are ticket-then-flip shape. No Phase 1.5 expansion — `import`/`parsing` aren't in the expansion-trigger label list. BUT-953 (heirloom wiring) considered but deferred — it's feature-completion work with product decisions, half-day scope, doesn't fit ticket-then-flip.

Theme: Two P3 import-area Bug tickets, single agent (small clean batch). Both are ticket-then-flip shape. No Phase 1.5 expansion — `import`/`parsing` aren't in the expansion-trigger label list. BUT-953 (heirloom wiring) considered but deferred — it's feature-completion work with product decisions, half-day scope, doesn't fit ticket-then-flip.

### Ship this sprint

#### Agent — Import surface fixes

- [x] **A1. ImportManagerResult: add `rateLimit(RateLimitDenied)` factory + `rateLimitDenied` field** — `lib/services/import/import_manager_result.dart`. New named ctor `ImportManagerResult.rateLimit(RateLimitDenied details)` with `isSuccess=false`, `errorMessage = details.message`, `strategy = 'rate_limited'`, and new field `RateLimitDenied? rateLimitDenied`. Existing `.success`/`.failure`/`.assistance` constructors initialise the field to `null`. (BUT-1144)
- [x] **A2. ImportManager: route rate-limit hit through the new factory** — `lib/services/import/import_manager.dart` around line 204 (and any other `strategy: 'rate_limited'` sites — grep for them). Replace `ImportManagerResult.failure('Importgräns nådd...', strategy: 'rate_limited')` with `ImportManagerResult.rateLimit(rateLimitDenied)` where `rateLimitDenied` is the structured `RateLimitDenied` returned by `rateLimiter.checkLimit(...)`. If checkLimit's current return shape doesn't surface `RateLimitDenied` to this caller, thread it through (read the rate-limiter API). (BUT-1144)
- [x] **A3. SmartImportViewModel: prefer structured rateLimitDenied over string-match synthesis** — `lib/viewmodels/smart_import_viewmodel.dart:330-350`. New shape: if `result.rateLimitDenied != null`, use it verbatim in `ImportRateLimited(...)`. Keep the existing string-match block as a fallback for back-compat — surrounding `if (result.rateLimitDenied != null) { use verbatim } else if (errorMessage contains rate-limit-words) { existing synth }`. (BUT-1144)
- [x] **A4. BUT-1144 pinning test flip** — `test/unit/viewmodels/smart_import_viewmodel_test.dart` (added in iter-81 batch-14 commit `d44509d3b`). Find the test that pins the current "always shows 1 hour retry" synth behaviour. Flip it: when ImportManager returns an `ImportManagerResult.rateLimit(...)` with `retryAfter: Duration(minutes: 5), limitType: perHour, suggestedAction: skipLlm`, the VM's resulting `ImportRateLimited` MUST carry those exact values (no synth override). (BUT-1144)
- [x] **A5. UrlImportStrategy._tryHtmlTextParse: detect non-Recipe JSON-LD + add strong warning** — `lib/services/import/url_import_strategy.dart:252-...`. Before invoking `TextImportStrategy.import`, parse JSON-LD scripts in the HTML. If any have `@type` set AND none of the values are `Recipe` (treating both string and list-of-string), prepend a strong warning to the resulting `ImportResult.warnings`: Swedish "Denna sida verkar vara en nyhetsartikel. Det extraherade innehållet kanske inte är ett riktigt recept." / English "This page appears to be a news article. The extracted content may not be a recipe." (option B from the ticket — keep extraction behaviour, escalate user signal). Add l10n keys `warningUrlImportNotARecipe` to both ARBs + @meta and use `AppLocale.current.warningUrlImportNotARecipe`. (BUT-1070)
- [x] **A6. BUT-1070 test flip** — `test/unit/services/import/url_import_strategy_test.dart:524`. Existing test "JSON-LD @type=Article does NOT trigger Tier 2" already asserts extraction_method is NOT schema.org. Extend it: now also assert `result.warnings` contains the new "news article" warning string (or its l10n key path). (BUT-1070)
- [x] **A7. Run `flutter gen-l10n`** after A5 ARB additions.

### Step 0 — premise verification (done)

- **BUT-1144** verified: `smart_import_viewmodel.dart:330-350` — VM string-matches `errorMessage` for 'rate limit'/'kvot'/'gräns', then synthesises new `RateLimitDenied(retryAfter: 1h, limitType: perDay, suggestedAction: useUserAssisted)`. `ImportManager.basicImport` at line ~204 returns `ImportManagerResult.failure('Importgräns nådd...', strategy: 'rate_limited')` after dropping the `RateLimitDenied` from `_rateLimiter`. The structured details ARE produced but never plumbed through.
- **BUT-1070** verified: `url_import_strategy.dart:252` `_tryHtmlTextParse` runs unconditionally if `bestHtml.length > 100`. No JSON-LD inspection happens at the tier-5 boundary. Existing pinning test at `url_import_strategy_test.dart:524` asserts current "extraction_method is NOT schema.org" behaviour but no warning-shape assertion. Picking option B from the ticket's 3 options — keep behavior, escalate warning copy.

### Acceptance

- [ ] `flutter analyze --fatal-infos` clean on touched lib files.
- [ ] Touched test files pass.
- [ ] `flutter gen-l10n` succeeded after A5 ARB additions.
- [ ] Orchestrating session runs full `dart analyze --fatal-infos`.
- [ ] Tier-2 reviewers (code-reviewer + testing-specialist) clean.

### Post-Sprint Steps

- [ ] Orchestrating session does unified `git add` + commit + push.
- [ ] Close BUT-1144 + BUT-1070 in Linear.

---

## Archived iter-82 (commit `3ea1a5253` — BUT-1138 + BUT-894 + BUT-1139 + BUT-1131) — 2026-05-27 (Wed)

Theme: Four P3 Bug tickets dispatched to 2 parallel agents. All small mechanical-fit shape (ticket-then-flip). Same proven pattern as iter-78/79/80. Phase 1.5 expansion fires on BUT-1131 and BUT-894 (Bug+social+recipe combo) — richer plan documented inline, no halt.

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
