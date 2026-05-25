# Sprint Backlog

## Sprint: iter-76 — BUT-1094 setError on swallow catches — 2026-05-25 (Mon)

Theme: Banner-UX consistency fix. `BaseSocialCoordinator.markAsViewed` + `getUnreadCount` and 2 sites in `SocialMenuCoordinator` log + swallow without calling `_setError(...)`. UI gates banner on `hasError` → some failure paths surface, others silent. P4 social Bug.

### Step 0 — premise verification

- Confirmed via grep: 6 catches in `base_social_coordinator.dart` already follow the `_setError(sanitizeErrorForUser(e))` convention; the 2 outliers (markAsViewed line 408, getUnreadCount line 424) only AppLogger.
- `SocialMenuCoordinator.getSharedMenusForUser` (line 362) + `getSharedMenuById` (line 377) — same swallow.
- `SocialShoppingCoordinator.getSharedShoppingListsForUser` (line 339) — same pattern. Adding to scope to maintain symmetry across 3 coordinators (per CLAUDE.md "third repetition" rule).
- Recipe coord doesn't have getSharedRecipesForUser at coord level (different layering via SocialRecipeService — that's BUT-1087's separate ticket).
- `social_menu_coordinator_test.dart` captures `lastError` via setError callback (line 189, 220, 228) but never asserts on it. Tests won't break.
- Classification: **fits + scope-expanded** to include shopping for consistency.

### Design choices

- **5 edits**: add `_setError(sanitizeErrorForUser(e))` (in base) or `setError(sanitizeErrorForUser(e))` (in subclasses, via base's public setError method line 457) after the AppLogger.error line.
- **No new tests** in this commit — existing tests still pass (no assertion currently checks `lastError == null` on swallow). Adding pin'd tests for the fixed behavior would be a separate test-hardening iter.
- **Skip BUT-1087 defect 2** (clear-on-success): out of scope; needs a `_resetError()` helper at every public mutator entry. Different commit.
- **Don't refactor to a helper** like `_logAndCaptureError` — only 5 sites, 2 lines each. Premature abstraction.

### Ship this sprint

- [ ] **A1. Base coordinator: markAsViewed + getUnreadCount** — `lib/services/unified/modules/social_coordination/base_social_coordinator.dart:408,424`. (BUT-1094)
- [ ] **A2. Menu coordinator: getSharedMenusForUser + getSharedMenuById** — `lib/services/unified/modules/social_menu/social_menu_coordinator.dart:362,377`. (BUT-1094)
- [ ] **A3. Shopping coordinator: getSharedShoppingListsForUser** — `lib/services/unified/modules/social_shopping/social_shopping_coordinator.dart:339`. (BUT-1094 scope expansion)

### Acceptance

- [ ] `flutter analyze` clean.
- [ ] `flutter test test/unit/services/unified/modules/social_menu/` passes (existing 30 tests).
- [ ] No new banner-firing on happy paths (visual sanity — only swallow paths now setError).

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Close BUT-1094

---

## Archived iter-75 (commit `76732592f` — message hijacked by parallel race) — 2026-05-25 (Mon)

BUT-1081 closed obsolete (parallel `3225954f6` already shipped sibling tests). BUT-1082 docs-only re-scope — 3 docstring touches noting wrappers don't forward errorStream. BUT-1112 filed as trigger-based follow-up.
