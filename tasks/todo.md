# Sprint Backlog

## Sprint: iter-70 — BUT-1097 delete deprecated importSharedRecipe — 2026-05-25 (Mon)

Theme: BUT-1073 follow-up. `SocialRecipeCoordinator.importSharedRecipe` (~70 lines, `@Deprecated`) had its last would-be caller deleted in iter-69. Drop the method. P4 backend/tech-debt.

### Step 0 — premise verification

- Method at `lib/services/unified/modules/social_recipe/social_recipe_coordinator.dart:542-611`.
- Already `@Deprecated('Use joinSharedRecipe for true copy-on-write behavior')`.
- Grep for `importSharedRecipe`: zero hits as a coordinator-method call. Only callers are ViewModel methods (different class) and SocialRecipeService.importSharedRecipe (different class, returns `bool`).
- Classification: **fits** — pure deletion.

### Design choices

- Delete the whole `@Deprecated` block (lines 542-611).
- Run analyze to surface any helper-orphans (would indicate code that was used only by this method); file or fix as appropriate.

### Ship this sprint

- [ ] **A1. Delete coordinator.importSharedRecipe** — `lib/services/unified/modules/social_recipe/social_recipe_coordinator.dart:542-611`. (BUT-1097)

### Acceptance

- [ ] `flutter analyze` clean.
- [ ] `grep "importSharedRecipe" lib/services/unified/modules/social_recipe/` → 0 hits.

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Close BUT-1097

---

## Archived iter-69 (commit `c4cdd1eb8`) — 2026-05-25 (Mon)

BUT-1073 P4 — dropped dead `legacyMode` parameter from SharedRecipeViewModel.importSharedRecipe. -45 / +35. 32/32 tests pass. BUT-1097 filed for coordinator-method deletion (this sprint).
