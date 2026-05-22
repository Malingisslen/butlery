# Sprint Backlog

## Sprint: wave-12 — bug/UX/correctness triple cluster — 2026-05-22 (Fr)

Theme: seven Bug/tech-debt tickets across three independent groups (two deferred during Step 0).

### Agent A — Import / Parse bug cluster
- [x] **BUT-960** — added `.timeout(Duration(seconds: 60))` to `parseTextToRecipe` in `import_base_viewmodel.dart` with localized friendly error `errorImportTimeout`. Matches the OCR pattern at `ocr_extraction_service.dart:421`.
- [x] **BUT-924** — added `preserveOrSetParsedRecipe(recipe)` defensive guard. The actual user-visible bug ("form reverts to empty on parse failure") is already prevented by `executeAsync`'s rethrow behaviour; the new helper locks in the contract for future code paths that might return null instead of throwing.
- [~] **BUT-953** — re-scoped + deferred. Step 0 revealed `uploadHeirloomImage` has **no caller** anywhere in `lib/` (heirloom UI is dead code). Real bug is "wire upload into save flow + persist `HeirloomMetadata`", not "fix race condition." Ticket body rewritten in Linear; re-classified Medium.

### Agent B — Cascade / Undo UX cluster
- [x] **BUT-927** — refactored `recipe_management_handler.deleteRecipe` to do optimistic delete + 5-second snackbar undo + commit-on-timer. Mirrors the bulk-delete pattern from `recipe_delete_manager.dart`. Captures `messenger`, `l10n`, service refs BEFORE popping the route so they survive VM disposal.
- [x] **BUT-929** — added `personalTagDeleteTagMessageWithCount` ICU-plural string. Both delete dialogs (`personal_tag_dialogs.dart`, `tag_detail_view.dart`) now show the affected recipe count from `viewModel.getUsageCount(tag.name)` before commit.
- [x] **BUT-893** — added `WeeklyMenuPlanRepository.removeRecipeFromAllPlans({userId, recipeId})` (doc-ID prefix range + `batch.update` partial write of just the `entries` field). Service wrapper `WeeklyMenuPlanService.removeRecipeFromAllPlans(recipeId)`. Hooked into `PersonalRecipeCrud.deleteRecipe` as fire-and-forget after successful delete. Includes `logPermissionCheck` audit-log entry per repo convention.

### Agent C — Backend correctness cluster
- [x] **BUT-1003** — restructured all three batch methods (`createBatch`, `updateBatch`, `deleteBatch`) in `base_firebase_repository.dart`. Permission-check loop now runs OUTSIDE the outer try/catch; only `batch.commit()` is inside the catch-wrap. Tightened three test assertions from `throwsException` → `throwsA(isA<PermissionDeniedException>())`. 20/20 tests pass.
- [x] **BUT-1006** — added `bindUserContext({onMessageReceived, onMessageOpenedApp, consentService})` to FCMService. Detaches prior user's `_onConsentChanged` listener before swapping. Resets `_pushPermissionsRequested`. Short-circuits when args identical. No-ops post-dispose. Wired into `NotificationService.onInitialize` as the post-`initialize()` re-binder. Added 4 unit tests.
- [~] **BUT-1009** — deferred from sprint. Step 0 found the emulator harness already exists (`@firebase/rules-unit-testing`), so harness wiring is much cheaper than ticket assumed; but the per-step coverage across 24 cascade functions is ~400 LOC and merits its own sprint. Ticket comment + Backlog return done in Linear.

### Tier-2 review findings addressed
- **firebase-backend-security HIGH** — added `logPermissionCheck` audit entry to `removeRecipeFromAllPlans`. Exposed `auditRepository` as `@protected` getter on `BaseFirebaseRepository` so subclasses can call `logPermissionCheck` without separate plumbing.
- **code-reviewer HIGH** — switched `batch.set` → `batch.update({'entries': ...})` to avoid clobbering fields added by concurrent writers; only the `entries` field changes here.
- **code-reviewer MEDIUM** — added clarifying comment on `bindUserContext`'s Function-equality short-circuit (current call sites pass method tear-offs, which Dart guarantees equal; a future closure refactor would silently stop short-circuiting — perf cost, not correctness bug).
- **False-positive criticals from both agents**: the `removeRecipeFromAllPlans` upper bound and the "stray backslash" claims. Both came from reading-tool rendering quirks (U+F8FF PUA char displays as `_`; `///` doc comments displayed without leading `/`). Verified via `od -c` byte dump that source bytes are correct.

### Post-Sprint Steps
- [x] `dart analyze --fatal-infos` clean (1 pre-existing warning in parallel session's `base_storage_repository_test.dart:97` — not my work)
- [x] Impacted tests pass (60 + 27 + 20 + 18 = 125+ tests, all green)
- [x] Tier-2 agent reviews on backend subset (firebase-backend-security + code-reviewer)
- [ ] File follow-ups as Linear tickets (pending MCP re-auth)
- [ ] Commit + push
- [ ] Close Linear tickets to Done (pending MCP re-auth)
- [ ] CI watcher

---

## Archived wave-11 (commits 7551c14c2 + bca2f5bc7) — 2026-05-22 (Fr)

wave-11 — BUT-788 server-side account-deletion. Shipped: new `requestAccountDeletion` CF (re-auth gate, 24-step cascade, audit logs), client wrapper reduced 430→190 lines, 4 deletion modules deleted (~1,050 LOC), tests green. Follow-ups filed: BUT-1009 (integration test, pulled into wave-12), BUT-1010 (App Check blocked on BUT-760), BUT-1011 (async polling for very-large accounts). BUT-788 closed in Linear.

## Archived wave-10 (commit 826dceed1) — 2026-05-22 (Fr)

wave-10 — BUT-782 FCMService static→instance + DI refactor. 660-line rewrite, 23 tests up from 19. Follow-ups: BUT-1006 (re-bind on re-login, pulled into wave-12), BUT-1007 (consent/token stream tests), BUT-1008 (composable MockFirebaseMessaging).

## Archived wave-9 (commits 55d49d993 + 602420b91) — 2026-05-22 (Fr)

wave-9 — LLM golden runners + repo test-coverage. Shipped BUT-888. Follow-ups: BUT-1003 (batch ops catch-swallow, pulled into wave-12), BUT-1004, BUT-1005.

## Archived wave-8 (commit 633595561) — 2026-05-22

wave-8 — BUT-784/886/882/887 shipped.

## Archived wave-7 (commit 5bd98f8e8 / 7ed82246c)

wave-7 — BUT-878/455/811/798 shipped.

## Archived wave-6 (commit 273152149)

wave-6 — BUT-876/802/452 shipped.

## Archived wave-5 (commit b66f5892f)

wave-5 — BUT-660/872/865/866/873 shipped.

## Archived wave-4 (commit 90d88cfca / b115d7519)

wave-3 follow-ups — BUT-868/869/870/871/867/776/864.

## Archived wave-3 (commit 8e54f68f2)

UI consolidation + CI + model integrity tests — BUT-861/579/801/841/825/823.
