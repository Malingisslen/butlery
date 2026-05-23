# Sprint Backlog

## Sprint: wave-16 — fresh batch (wave-15 fully shipped by parallel session) — 2026-05-23 (Sa)

Theme: 2 High tickets + 1 obsoletion. Wave-15 was found 8/8 Done in Linear at sprint start (parallel session shipped without checking off `todo.md`). BUT-1013 was deferred mid-sprint after Step 0 verification revealed the prereq picker dialog doesn't exist; filed BUT-1029 for the prereq.

### Batch A — Recipe-list bulk tag (`flutter-developer`)
- [x] **A1. BUT-1012 (High)** — `lib/views/mina_recept/selection_app_bar.dart` + `lib/viewmodels/recipe_list_viewmodel.dart`: new bulk-tag IconButton + inline `_BulkTagPicker` modal sheet + `bulkApplyPersonalTag` (merge, skip already-tagged) + `undoBulkApplyPersonalTag` with per-recipe snapshot. l10n: 5 new bulk-tag keys (sv + en + generated). Tests: 5 new VM unit tests covering modified-count, already-tagged skip, empty selection, undo safety.

### Batch B — Image upload size reduction (`flutter-developer`)
- [x] **B1. BUT-992 (High)** — `lib/services/image_picker_service.dart`: defaults `2400→1600`, `quality 90→80` across `pickImage`, `pickMultipleImages`, `cropImage.compressQuality`. Existing tests updated + 2 regression-guard assertions added that the new literals are passed through.

### Batch C — Obsoletion housekeeping
- [x] **BUT-938** — closed as obsolete (multi-image carousel already shipped via `UniversalImageManager.recipeDetail` at `recipe_detail_content.dart:560-567`).

### Mid-sprint scope changes
- [~] **BUT-1013** — deferred. Plan-stale: ticket assumed a single-recipe slot picker existed for reuse, but no such picker exists. Filed prereq BUT-1029 (SlotPickerDialog widget), blocked BUT-1013 on it.

### Post-Sprint Steps
- [x] `dart analyze --fatal-infos` clean across all changed files
- [x] `dart format --set-exit-if-changed` clean
- [x] Tier-2 agent reviews: `code-reviewer` PASS + `testing-specialist` PASS (non-blocker polish applied inline, marker re-touched)
- [ ] Commit + push to main
- [ ] Close Linear tickets to Done
- [ ] CI watcher

### Known follow-ups (filed in Linear)
- **BUT-1029** (Medium) — SlotPickerDialog widget, prereq for BUT-1013 bulk-add-to-menu
- **BUT-1030** (Medium) — Test harness: make `MockUnifiedRecipeService.updateRecipe` actually mutate `_recipes` (blocks "restoration after undo" tests for BUT-1012)

---

## Archived wave-15 (parallel-session ships) — 2026-05-23 (Sa)

wave-15 — 8 tickets planned (BUT-1022, 1026, 1020, 1015, 1017, 1019, 1018, 1027). A parallel Claude session shipped all 8 in a single window at 2026-05-23T17:59:51–17:59:57 without checking off this file. Pattern escalated from wave-14's 5/7 to 8/8. Lesson re-reinforced: Linear state is authoritative; local `todo.md` lies when two sessions run concurrently. `/sprint-execute` Step 0 verification caught this before wave-16 wasted any implementation time.

## Archived wave-14 (parallel-session ships) — 2026-05-23 (Sa)

wave-14 — 7 tickets planned (3 CI + 4 test-debt). A parallel Claude session shipped 5/7 today **without checking off this file**: BUT-1024 (SHA-pin), BUT-1025 (account_deletion `FirebaseAuth.instance` → `AuthRepository`), BUT-1021 (AuthService stream-error tests), BUT-1023 (Storage upload exception tests), BUT-1016 (typed-exception in `uploadImageBytes`). All five moved to Linear Done at 2026-05-23T11:06. Carry-over to wave-15: **BUT-1022** (OCR error-chain tests) + **BUT-1026** (E2E `_FocusInheritedScope` investigation). Lesson reinforced: trust Linear state over local todo.md when they disagree.

## Archived wave-13 (commits 3fc2d1edc + 66a786479 + 3f7d40412) — 2026-05-22 (Fr)

wave-13 — 9 Bug/UX tickets across onboarding/error-UX/import/recipe-list. 7 shipped (BUT-926, 971, 968, 966, 963, 959, 921), 2 marked obsolete/rescoped ([~] BUT-942 premise gone, [~] BUT-933 split into 1012/1013/1014). Follow-ups filed: BUT-1012, 1013, 1014, 1015, 1016, 1017. Per backlog dump, all wave-13 BUT-IDs already absent from Backlog — confirming Linear-Done state was reached.

## Archived wave-12 (commits 185ba807e + eb4562bc6) — 2026-05-22 (Fr)

wave-12 — 7 done + 2 deferred. Implementation bundled into 185ba807e (parallel session ate the message); tier-2 review findings in eb4562bc6. Linear tickets closed at 2026-05-22T20:13 (BUT-960/924/927/929/893/1003/1006 → Done; BUT-953/1009 → Backlog with re-scoped bodies).

## Archived wave-11 (commits 7551c14c2 + bca2f5bc7) — 2026-05-22 (Fr)

wave-11 — BUT-788 server-side account-deletion. Shipped: new `requestAccountDeletion` CF (re-auth gate, 24-step cascade, audit logs), client wrapper reduced 430→190 lines, 4 deletion modules deleted (~1,050 LOC), tests green. Follow-ups filed: BUT-1009 (integration test), BUT-1010 (App Check blocked on BUT-760), BUT-1011 (async polling for very-large accounts). BUT-788 closed in Linear.

## Archived wave-10 (commit 826dceed1) — 2026-05-22 (Fr)

wave-10 — BUT-782 FCMService static→instance + DI refactor. 660-line rewrite, 23 tests up from 19. Follow-ups: BUT-1006 (re-bind on re-login, completed in wave-12), BUT-1007 (consent/token stream tests), BUT-1008 (composable MockFirebaseMessaging).

## Archived wave-9 (commits 55d49d993 + 602420b91) — 2026-05-22 (Fr)

wave-9 — LLM golden runners + repo test-coverage. Shipped BUT-888. Follow-ups: BUT-1003 (batch ops catch-swallow, completed in wave-12), BUT-1004, BUT-1005.

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
