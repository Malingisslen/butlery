# tasks/todo.md

## BUT-1613 — "Who's home" sets the serving size (approved plan)

Full approved plan: `~/.claude/plans/tender-tumbling-dahl.md` (ExitPlanMode-approved 2026-07-23,
after a 4-role stakeholder panel — Architect, PM, tagging-integrity, archaeologist — all
approve-with-conditions, allergen independence confirmed). This file mirrors it for the plan gate.

**Slice 1 — shopping list: SHIPPED** (`5ce639e33`, on main). Presence-driven quantity scaling in
`MenuShoppingListGenerator` + `MenuShoppingAggregator` (per-placement `(recipe, factor)` pairs),
`WeeklyMenuPlan.servingsFor`, övrigt exemption, portions>0 guard, single staples pass, `scaledMeals`
snackbar cue. 38 tests incl. the repeated-recipe dedup-removal regression pin.

**Slice 2 — cooking mode: IN PROGRESS (this session).** Opening a planned meal pre-scales cooking
mode to who's home. Panel conditions folded in:
- [ ] Pass a resolved `int? presentServings` (computed via `servingsFor`) into `CookingModeViewModel`
  — NOT the plan model (keep the VM decoupled from the menu domain).
- [ ] Target priority: present count > household default > recipe portions; clamp to
  [minPortions, maxPortions]; only scale when `recipe.portions > 0` (BUT-1322 guard).
- [ ] Extend the boot-race latch (`_onUserServiceChanged`, BUT-1515): a present-count target must
  stick — a late profile load must not clobber it back to household size (`_presenceSourced` latch).
- [ ] De-duplicate the scale-resolve-log block first (constructor + `_onUserServiceChanged` →
  shared `_scaleTo`).
- [ ] Thread additive/optional route args: `calendar_weekly_menu_widget → recipe_detail_view →
  app_router (Routes.cookingMode / Routes.recipeDetail) → CookingModeView → CookingModeViewModel`.
  Keep the 8+ existing bare-`Recipe` callers of `Routes.recipeDetail` compiling untouched.
- [ ] Tests: opening from a planned meal targets the present count; a late profile load does NOT
  clobber a presence-sourced portion; manual override still wins; no-presence → household default.

## Open questions
No architecture-changing unknowns — this is the approved Slice 2 of an already-reviewed plan.
Assumptions (all reversible): route args are additive/optional so no existing caller changes; the VM
receives a plain `int? presentServings` (no menu-model coupling); present count is derived at the
call site via `WeeklyMenuPlan.servingsFor(day, slot, fallback: recipe.portions)`.

## What this means in plain language
Opening a meal you've planned for the week will start cooking mode already set to how many people are
home that day (instead of always the whole household). The shopping-list half already shipped; this is
the cooking half. Nothing else changes; easy to undo.
