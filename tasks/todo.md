# Sprint Backlog

## Sprint: iter-62 — BUT-1068 dismissSharedRecipe + sibling VM sweep — 2026-05-25 (Mon)

Theme: Bug fix — three shared-content VMs silently swallow coordinator `bool` results, lying to the UI on partial failure. P2 social/recipe.

### Step 0 — premise verification

- BUT-1068 ticket body matches current `shared_recipe_viewmodel.dart:212-227` exactly. `executeOperation` closure does `await ...; return true;` — coordinator's bool is discarded.
- Ticket calls out sibling VMs: `shared_menu_viewmodel.dart` (dismissSharedMenu line 207 + restoreSharedMenu line 226) and `shared_shopping_viewmodel.dart` (dismissSharedShoppingList line 228 + restoreSharedShoppingList line 248) — verified, same pattern present.
- Test `test/unit/viewmodels/shared_content/shared_recipe_viewmodel_test.dart:243-265` explicitly pins the bug + says "flip when fixed". Test for `dismissSharedRecipe` only; siblings have no equivalent test (filing as gap if not added inline).
- Coordinator returns: SocialRecipeCoordinator.dismissSharedRecipe returns `bool` (false on no-uid / on caught exception).
- Classification: **fits** — implement as written + extend to sibling VMs.

### Design choices

- **Closure forwards bool, not always-true.** Change `await coord.xxx(...); return true;` → `return await coord.xxx(...);`.
- **Local state mutation already gated** on `result == true` outside the closure (line 221). So removing the always-true means the gate now correctly skips removal on coordinator-false. No new code needed for the "do NOT mutate on false" requirement — it falls out of fixing the closure.
- **Sweep all 6 sites across 3 VMs**: dismissSharedRecipe, dismissSharedMenu, restoreSharedMenu (undismiss in recipe is fine — already forwards), dismissSharedShoppingList, restoreSharedShoppingList.
- **Test flip**: invert the BUG assertion in `shared_recipe_viewmodel_test.dart` lines 259-263 + remove the "flip when fixed" reason notes.
- **No new tests for siblings this iter** — file as follow-up ticket. Pattern parity is the contract; if recipe-VM is right, menu+shopping are right via identical fix.

### Ship this sprint

- [ ] **A1. Fix shared_recipe_viewmodel.dart** — forward coordinator bool from `dismissSharedRecipe` closure (line 215-218). (BUT-1068)
- [ ] **A2. Fix shared_menu_viewmodel.dart** — same pattern in dismiss + restore (lines 207, 226). (BUT-1068 sibling)
- [ ] **A3. Fix shared_shopping_viewmodel.dart** — same pattern in dismiss + restore (lines 228, 248). (BUT-1068 sibling)
- [ ] **A4. Flip pin'd-bug test** — `shared_recipe_viewmodel_test.dart:243-265` invert assertions, remove flip-when-fixed reason text. (BUT-1068)

### Acceptance

- [ ] `grep -E "await _.*Coordinator.*\\n.*return true" lib/viewmodels/shared_content/` → 0 hits in dismiss/restore closures (allowed in markAsViewed where the coordinator method returns void or already-viewed short-circuit).
- [ ] `flutter analyze` clean.
- [ ] `flutter test test/unit/viewmodels/shared_content/shared_recipe_viewmodel_test.dart` passes (flipped test now green for the correct behavior).
- [ ] Sibling test gap filed as follow-up Linear ticket.

### Post-Sprint Steps

- [ ] Commit + push
- [ ] Close BUT-1068 with commit hash
- [ ] File follow-up: "Add pin'd-bug tests for shared_menu + shared_shopping dismiss/restore bool-forwarding"

---

## Archived iter-61 (commit `2927ec7f0`) — 2026-05-25 (Mon)

BUT-885 Phase 5 partial — CPI → LoadingIndicator sweep across 15 view files (22 sites). +73 / −139. BUT-885 stays In Progress (Phase 6 widgets/ still residual ~36 files). Linear comment blocked by archived flag — needs UI un-archive.
