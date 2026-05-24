# Sprint Backlog

## Sprint: wave-18 — Visibility + perf + FCM coverage — 2026-05-23 (Sa)

Theme: Scope cut after Step 0 surfaced two stale ticket premises (BUT-1030 cites wrong class, BUT-1031 cites wrong file) and confirmed the heavier items (A1 sync-conflict banner ~2-3 days, B2 multi-file UI sweep, C1 heavy mock setup) are too broad for this session. Shipping the 3 bounded items + deferring the 5 heavier ones into Linear with re-verified scope. Wave-17 verified all 8/8 Done in Linear at sprint start.

### Ship this sprint
- [ ] **A2. BUT-909 (High)** — Visibility icons on recipe cards. `lib/widgets/recipe/recipe_card.dart` + lock/world/friends icons + l10n tooltips.
- [ ] **B1. BUT-951 (Medium)** — `ListView.builder` for ingredients + instructions in recipe detail; same for shopping_list_content.
- [ ] **C3. BUT-1007 (Medium)** — FCMService consent-change + token-refresh stream tests.

### Deferred (file follow-up tickets with scope captured in Phase 3)
- [~] **A1. BUT-1031 (High)** — Sync-conflict banner. **Plan-stale:** cited `realtime_sync_service.dart:315-347` doesn't exist; real instrumentation site is `lib/services/realtime/conflict_resolution_module.dart:49-81`. Updated scope: emit on `resolveConflict<T>`, but realistically 2-3 days work — defer.
- [~] **A3. BUT-953 (Medium)** — heirloom wiring. Bounded but half-day, defer to keep this sprint small.
- [~] **B2. BUT-1004 (Medium)** — IngredientCategorizer. Multi-file UI sweep (8+ callsites for category constant rename). Defer.
- [~] **C1. BUT-1033 (Medium)** — RecipePersistenceManager save-flow test. Heavy mock setup needed (full RecipeFormState bootstrapping). Defer.
- [~] **C2. BUT-1030 (Medium)** — **Plan-stale:** ticket cites `MockUnifiedRecipeService.updateRecipe at line 2400-2405` — but line 2400 is `MockRecipeServiceAdapter` (different class). `MockUnifiedRecipeService` has no `updateRecipe` override at all; real mutation gap is on `personal.updateUnifiedRecipe` via injected `_personalOperations`. Re-scope before picking next sprint.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` clean across all changed files
- [ ] `dart format --set-exit-if-changed lib test` clean
- [ ] Tier-2 reviews: `code-reviewer` + `testing-specialist` + `firebase-backend-security` (A1, A3 touch services)
- [ ] File follow-ups in Linear (anything deferred / reviewer findings / test gaps)
- [ ] Commit + push to main
- [ ] Close Linear tickets to Done
- [ ] CI watcher

---

## Archived wave-17 (commit 27e8ee6df) — 2026-05-23 (Sa)

Theme: 8 tickets across Settings UX, bulk recipe→menu, photo-delete undo. Parallel-session pattern: `todo.md` showed unchecked, Linear showed all Done — wave-17 actually shipped. Two structural deferrals re-filed during sprint (BUT-1031 for BUT-958 realtime, BUT-1032 for BUT-995 Vertex caching) + two polish follow-ups (BUT-1033, BUT-1034).

### Batch A — Settings/Account UX
- [x] **BUT-913 (High)** — Surface Sign-out + Delete-Account in Settings UI (GDPR).
- [~] **BUT-958 (High)** — Sync conflict resolution: deferred → BUT-1031 (realtime path risk).
- [x] **BUT-932 (Medium)** — Recipe photo deletion undo.

### Batch B — Bulk recipe→menu suite
- [x] **BUT-1029 (Medium)** — SlotPickerDialog widget.
- [x] **BUT-1013 (High)** — Bulk add-to-menu on selection.
- [x] **BUT-1014 (Medium)** — Bulk export selected recipes.

### Batch C — Backend hygiene
- [~] **BUT-995 (High)** — Prompt caching: deferred → BUT-1032 (Vertex Gemini context caching, larger surface).
- [x] **BUT-970 (High)** — Wire backup_service into Settings → Konto.

## Archived wave-16 (commit ae7cc297e + tier-2 follow-ups) — 2026-05-23 (Sa)

Theme: 2 High tickets + 1 obsoletion. BUT-1012 bulk-tag, BUT-992 image compression. BUT-1013 deferred → wave-17 (after BUT-1029 prereq).

## Archived wave-15 (parallel-session ships) — 2026-05-23 (Sa)

wave-15 — 8 tickets planned (BUT-1022, 1026, 1020, 1015, 1017, 1019, 1018, 1027). Parallel session shipped 8/8.

## Archived wave-14 (parallel-session ships) — 2026-05-23 (Sa)

wave-14 — 7 planned, 5 shipped by parallel session (BUT-1024, 1025, 1021, 1023, 1016).

## Archived wave-13 (commits 3fc2d1edc + 66a786479 + 3f7d40412) — 2026-05-22 (Fr)

wave-13 — 9 Bug/UX tickets. 7 shipped, 2 obsoleted/rescoped. Follow-ups BUT-1012–1017.

## Archived wave-12 (commits 185ba807e + eb4562bc6) — 2026-05-22 (Fr)

wave-12 — 7 done + 2 deferred.

## Archived wave-11 (commits 7551c14c2 + bca2f5bc7) — 2026-05-22 (Fr)

wave-11 — BUT-788 server-side account-deletion.

## Archived wave-10 (commit 826dceed1) — 2026-05-22 (Fr)

wave-10 — BUT-782 FCMService static→instance + DI refactor.

## Archived wave-9 (commits 55d49d993 + 602420b91) — 2026-05-22 (Fr)

wave-9 — LLM golden runners + repo test-coverage. BUT-888.

## Archived wave-8 (commit 633595561) — 2026-05-22

wave-8 — BUT-784/886/882/887.

## Archived wave-7 (commit 5bd98f8e8 / 7ed82246c)

wave-7 — BUT-878/455/811/798.

## Archived wave-6 (commit 273152149)

wave-6 — BUT-876/802/452.

## Archived wave-5 (commit b66f5892f)

wave-5 — BUT-660/872/865/866/873.

## Archived wave-4 (commit 90d88cfca / b115d7519)

wave-3 follow-ups — BUT-868/869/870/871/867/776/864.

## Archived wave-3 (commit 8e54f68f2)

UI consolidation + CI + model integrity tests — BUT-861/579/801/841/825/823.
