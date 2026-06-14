# Sprint Backlog

## Sprint: menu — finish the menu→shopping loop + menu-plan ergonomics + onboarding sample — 2026-06-14 (iter-152)

Focus = `menu` area label. The menu pool is genuinely thin and UX-heavy: the marquee menu→shopping loop already shipped (BUT-956 + BUT-999 Done; aggregator + idempotent regeneration live). What's left is the BUT-1157 epic's two hard remainders (decomposed into new child tickets BUT-1278/BUT-1279 at selection), one menu-plan UI follow-up (BUT-1043), and an onboarding sample seed (BUT-930). Only one Tier-A clean `build` exists (the unit-merge math); everything else is build-review because it changes user-visible behavior or is a UX surface — that's expected for this area, not padded.

Selected 4 buildable tickets. Batches touch disjoint files so they run in parallel worktrees without patch collisions. The two shopping-aggregation tickets (BUT-1278/1279) MUST share one batch because they edit the same aggregator/generator files.

### Agent A: shopping-aggregation — finish the menu→shopping merge math + staples exclusion `[Tier A/B]`
- [ ] **A1. Merge compatible units across families in the menu aggregator** `[Tier A]` — `lib/utils/text/unit_converter.dart` (add a canonical-base reducer: unit → (baseAmount, baseUnit) | null), `lib/services/shopping/menu_shopping_aggregator.dart` (post-sum merge step grouping same-name lines by base family), `test/unit/services/shopping/menu_shopping_aggregator_test.dart`. (BUT-1278)
  - Acceptance: "3 dl X" + "200 ml X" across two recipes aggregate to ONE line of 500 ml (or 5 dl), not two · same ingredient in incompatible units ("2 dl" + "3 st") stays as two adjacent lines, never wrong-summed · amount-less entries ("efter smak", ranges) still aggregate by name into a single un-summed line (no BUT-956 regression) · a pure unit test covers volume-merge, mass-merge, mixed-family-no-merge, and amount-less pass-through
- [ ] **A2. Exclude isStaple pantry items from the generated shopping list** `[Tier B]` — `lib/services/shopping/menu_shopping_list_generator.dart` (drop aggregated lines matching an isStaple pantry item, carry an `excludedStaples` count), `lib/services/shopping/menu_shopping_aggregator.dart` (only if the exclusion belongs at the aggregation seam), `test/unit/services/shopping/menu_shopping_list_generator_test.dart`. (BUT-1279)
  - Acceptance: an aggregated ingredient whose normalized name matches an `isStaple: true` pantry item is omitted from the generated list · non-staple ingredients are unaffected; a user with no pantry staples gets the identical list to today (no regression) · the number of excluded staples is surfaced (result field, not silently swallowed) · regeneration idempotency (BUT-956) still holds — bought-status preserved on remaining lines
  - Sign-off: the "we removed N items you already have" behavior + affordance wording ("Hoppade över N skafferivaror" / a "visa ändå" path) — this silently omits items, so it needs Malin's eyes.

### Agent B: menu-plan-ui — copy-week action + bulk-move multi-select on the weekly menu `[Tier B]`
- [ ] **B1. Copy-week trigger + bulk-move via long-press selection on the weekly menu view** `[Tier B]` — `lib/views/veckomeny_view.dart` (copy-week action + selection-mode UI), `lib/viewmodels/menu/weekly_menu_plan_viewmodel.dart` (selection state + bulk-move wrapper looping the existing `moveEntry`, single save), `lib/services/menu/weekly_menu_plan_service.dart` (bulk-move loop wrapper only if the VM can't compose it from existing `copyWeek`/`moveEntry`). (BUT-1043)
  - Acceptance: a "Copy this week → next week" action is reachable from the weekly menu view and calls the existing `copyWeek` service primitive · long-press an entry enters selection mode; selecting N + choosing a (day, slot) moves all N in one batched save · each interaction shows feedback (snackbar: "{count} kopierade" / "inget att kopiera"; move confirmation) · drag-to-reorder (already shipped via calendar_drag.dart) is NOT re-implemented or regressed
  - Sign-off: the copy-week affordance placement (overflow menu vs header long-press vs FAB substate) and the selection-mode visual treatment — both are open UX choices in the ticket.

### Agent C: onboarding-seed — seed a sample week-menu + shopping list for new users `[Tier B]`
- [ ] **C1. Seed one sample week-of-menu (and its shopping list) during onboarding** `[Tier B]` — `lib/viewmodels/onboarding_viewmodel.dart` (after the existing `RecipeSeeds.allRecipes` seed at ~line 263, create one sample weekly-menu plan from the seeded recipes, then generate its shopping list via the existing `MenuShoppingListGenerator`), seed data source for the sample plan. Does NOT touch the aggregator/generator internals (Agent A owns those) — calls the generator as a black box. (BUT-930)
  - Acceptance: a brand-new user finishes onboarding with one example weekly-menu plan populated from the seeded recipes · that sample menu has a matching generated shopping list (reusing the live generator, not a hand-built list) · the seed is idempotent — re-running onboarding does not create duplicate sample menus/lists · a user who skips/has-no seed recipes does not crash or get a half-built menu
  - Sign-off: whether new users should get a pre-filled sample menu at all (vs an empty planner they fill themselves) and how many days the sample covers — onboarding first-impression decision.

### Needs you (not built — flagged for your call)
- **BUT-1179** — manual QA reminder: live concurrent-edit ConflictBanner verification across recipe-edit / menu-plan / shopping-list surfaces + UX polish checklist. Tier D — this is real-device, two-users-editing-at-once manual testing that can't be covered by unit/widget tests or automated from the loop. Recommend: **keep open as a QA checklist** for your own testing pass; nothing to build.

### Obsolete (done in git, still open in Linear)
- None new. (BUT-956 and BUT-999 — the menu→shopping core loop and multi-day add — are already correctly marked Done in Linear and shipped in git; not re-selected.)

### Post-Sprint Steps
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run relevant unit tests (menu_shopping_aggregator, menu_shopping_list_generator, weekly_menu_plan_service/vm, onboarding)
- [ ] Phase 2.7 outcome-grading (fresh-context verifier per agent group)
- [ ] Commit, push
- [ ] Linear: BUT-1278 is Tier A → Done if all criteria pass; BUT-1279/BUT-1043/BUT-930 are build-review (Tier B) → In Review + notify, none auto-close

---
## ARCHIVED — iter-151 (import flow: BUT-1040/931 text-import, BUT-947 multi-URL, BUT-903 multi-photo, BUT-1205 re-extract — all shipped, commits 673f80c87 + 10325a5bb; BUT-653/656/684/941 flagged needsApproval) · iter-150 (social conflict-cleanup + activity/sharing UI: BUT-1267/1266 Tier A, BUT-1220/1000/949 Tier B; BUT-1265 obsolete-closed) · iter-149 (BUT-1265 conflictStream end-to-end delivery test — landed `f37c9af03`) · iter-148 (BUT-1263/1264 recoverLocalVersion test-gaps — HEAD d4ee51b0f) · iter-147 (BUT-1262 realtime data-loss-path sign-off) · iter-146 (BUT-1053/1247/1250) · iter-145 (BUT-1251/1246/1249 Done) · iter-144 (BUT-648/1057 In Review) · iter-143 (BUT-1245/626 Done) · äldre i git-historiken
