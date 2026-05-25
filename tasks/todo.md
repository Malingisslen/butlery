# Sprint Backlog

## Sprint: iter-69 — BUT-1073 drop legacyMode dead branch — 2026-05-25 (Mon)

Theme: Tech-debt — `SharedRecipeViewModel.importSharedRecipe` has a `legacyMode` parameter; both branches of `if (legacyMode)` call `joinSharedRecipe` with identical args. Misleading API. P4 recipe/tech-debt.

### Step 0 — premise verification

- Ticket matches `lib/viewmodels/shared_content/shared_recipe_viewmodel.dart:175-195` exactly. Both `if (legacyMode)` and `else` call `_socialRecipeCoordinator.joinSharedRecipe(sharedRecipeId, newTitle)` — same args.
- The `@Deprecated` `coordinator.importSharedRecipe(...)` (line 544 of coordinator) that the legacy branch was supposed to call is on its way out. Ticket recommends **Option B** (delete the parameter).
- Production callers: `lib/widgets/social/groups/group_shared_content_section.dart:226` + `lib/views/social/shared_with_me/shared_content_actions.dart:31`. NEITHER passes `legacyMode` — both rely on the default `false`. Safe to delete.
- Test `test/unit/viewmodels/shared_content/shared_recipe_viewmodel_test.dart:392-411` pins the dead-branch parity. Must update.
- Classification: **fits** — Option B.

### Design choices

- **Delete `bool legacyMode = false` parameter** + collapse the if-else to a single `return await _coordinator.joinSharedRecipe(...)`.
- **Update the API doc comment** — drop the "For legacy compatibility, creates immediate copy with attribution" line that the implementation never honored.
- **Update test** — drop the dual-branch test, replace with a single happy-path test that asserts the call. The throws-on-error test stays as-is (uses no `legacyMode`).
- **Update header docstring** (test file line 19) — drop the legacyMode pin claim.

### Ship this sprint

- [ ] **A1. Drop `legacyMode` parameter** — `lib/viewmodels/shared_content/shared_recipe_viewmodel.dart:175-195`. (BUT-1073)
- [ ] **A2. Update test** — `test/unit/viewmodels/shared_content/shared_recipe_viewmodel_test.dart:385-411`: rewrite to single happy-path assertion + header docstring fix. (BUT-1073)

### Acceptance

- [ ] `flutter analyze` clean.
- [ ] `flutter test test/unit/viewmodels/shared_content/shared_recipe_viewmodel_test.dart` passes (32→31 tests, the dual-branch one collapses to one).
- [ ] No remaining `legacyMode` references in `lib/` or `test/` for this VM.

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Close BUT-1073

---

## Archived iter-68 (commit `e793f426e`) — 2026-05-25 (Mon)

BUT-1060 P4 — dropped 2 stale dispose() methods on StatelessWidget dialog items. -12 lines. 23/23 tests pass.
