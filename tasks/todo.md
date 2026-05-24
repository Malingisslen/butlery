# Sprint Backlog

## Sprint: wave-20 — Visibility-icon widget tests (BUT-1036) — 2026-05-24 (Sun) — autonomous /loop iter 4

Theme: Todo state has 3 remaining tickets all too-large for autonomous iter (BUT-1031/953/1004). Pivoted to Backlog state — found BUT-1036 (Low, test-gap), the wave-18 testing-specialist's filed follow-up for `_buildVisibilityIcon` three-branch coverage. Perfect autonomous-iter scope: tests for already-shipped production code (wave-18 commit c5abf24b7).

### Ship this sprint

- [ ] **A1. BUT-1036 (Low, test-gap)** — Widget tests for `lib/widgets/recipe/recipe_card.dart` `_buildVisibilityIcon`. Cover the three-branch switch: `isCollaborative→people_outline`, `isPublic→public`, default→`lock_outline`. Plus precedence test (collab wins over public when both true). File: extend `test/widget/recipe/recipe_card_test.dart` with a new group.

### Skipped this iter (left open in Linear)

- [~] **BUT-1031 (High)** — Sync-conflict banner. 2-3 days; needs multi-iter.
- [~] **BUT-953 (Medium, Bug)** — Heirloom wiring. Needs architectural scope-cut (see iter-3 Linear comment).
- [~] **BUT-1004 (Medium)** — IngredientCategorizer multi-file sweep. Skip.

### Post-Sprint Steps

- [ ] `dart analyze --fatal-infos` on changed files
- [ ] Run new widget tests
- [ ] Tier-2: `code-reviewer` (no lib/ touched → testing-specialist skipped)
- [ ] `/code-review high` (simplify marker)
- [ ] Commit + push to main
- [ ] Close BUT-1036 in Linear to Done

---

## Archived wave-19 (commit 2fcc4a10d) — 2026-05-24 (Sun)

Theme: Pivoted from BUT-953 mid-iter via Step 0 architectural scope-assessment. Shipped BUT-1033 instead (RecipePersistenceManager save-flow test using BUT-1030 helpers). 2 tests (success/failure for commitPendingStorageDeletes wiring), both pass.

### Shipped
- [x] **BUT-1033 (Medium, test-gap)** — save-flow test for `commitPendingStorageDeletes`.

### Deferred mid-iter
- [~] **BUT-953 (Medium, Bug)** — architectural assessment posted as Linear comment; needs heirloom-wave dedicated scope.

---

## Archived wave-18 (commit c5abf24b7) — 2026-05-24 (Sun)

Theme: 3 bounded ship-items + 5 deferred (scope captured as Linear comments). Stale-premise cleanup on BUT-1030 / BUT-1031 surfaced via Step 0.

### Shipped
- [x] **BUT-909 (High)** — Visibility icons on recipe cards.
- [x] **BUT-951 (Medium)** — ListView.builder migration for ingredients + instructions in recipe detail.
- [x] **BUT-1007 (Medium, partial)** — FCM getNotificationSettings rethrow test added. Larger consent-change + token-refresh coverage carried as follow-up; ticket closed since core rethrow gap landed and remaining branches require non-trivial fake plumbing.

### Deferred (left open in Linear)
- [~] **BUT-1031 (High)** — Sync-conflict banner. Plan-stale rescope captured in Linear comment.
- [~] **BUT-953 (Medium)** — heirloom wiring.
- [~] **BUT-1004 (Medium)** — IngredientCategorizer multi-file UI sweep.
- [~] **BUT-1033 (Medium)** — RecipePersistenceManager save-flow test.
- [~] **BUT-1030 (Medium)** — Plan-stale rescope captured in Linear comment.

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
