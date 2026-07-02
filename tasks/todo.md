# Sprint: BUT-1322 — household size + portion scaling (overridable)

## Step 0 classification: FITS (premise verified 2026-07-02)
- No `householdSize` on UserProfile; no default-servings concept. Ticket premise holds.
- BUT the rule-based scaler ALREADY exists: `PortionScalerLogic.scaleEntries/scaleIngredients`
  (lib/widgets/common/input/portion_scaler_logic.dart, BUT-444 structured-first) drives the
  manual per-recipe scaler in recipe detail + cooking mode, and recipe_detail_actions feeds
  its `_scaledIngredients` into add-to-shopping. So this ticket = capture the default +
  wire it into the existing scaler init, NOT build a scaler.
- ParsedMenuRequest has NO portions/persons field — menu generation is quantity-agnostic.
  The DECIDED SPEC's "explicit amount always overrides" is satisfied by the existing manual
  per-recipe scaler (the override IS the scaler); there is nothing to override at menu-
  generation level. No prompt-parsing scope.

## Stakeholders: single-tier (router). Monetization Lead: approve-with-conditions —
1. (BINDING) Ship analytics with the feature: householdSize set/changed event + a
   scaling-applied event distinguishing household-default vs explicit-override source.
2. (BINDING) No tier/entitlement gate — stays free (trivially satisfied; note in review).

## Design
1. **Model**: `householdSize` (int?, null = use each recipe's own portions) on UserProfile:
   field + fromJson/toJson + copyWith (+ equality if present). Valid range 1–12.
2. **Persistence**: through the existing profile-save path (UserProfileViewModel.saveProfile
   → userService). No new repository code.
3. **Settings UI**: stepper row on the existing Settings > "Meny och smak" screen
   (menu_taste_view.dart, shares UserProfileViewModel) — "Hushållets storlek",
   null state shows "Receptets standard" with a clear way back to null. Butler voice, SV+EN.
4. **Defaulting (the core)**: initial scaler target becomes
   `householdSize ?? recipe.portions ?? 1` in the three init points:
   - cooking_mode_viewmodel `_currentPortions` (+ initial `_scaledIngredients` scaled when
     target != recipe.portions)
   - recipe_detail portionScaler `initial/target` (recipe_detail_content._buildPortionScaler)
   - recipe_detail_actions `_scaledIngredients` init (feeds add-to-shopping)
   The EXISTING manual scaler remains the explicit override (explicit always wins — the
   decided spec). Original recipe portions stay the scaling BASE (originalPortions).
5. **Analytics** (condition 1): log on settings change (old→new incl. null) + on
   scaling-applied (source: household_default | manual_override).
6. **OFF state**: householdSize null ⇒ byte-for-byte today's behaviour.

## Acceptance (gradeable)
- Profile round-trip: householdSize survives toJson→fromJson incl. null and copyWith.
- With householdSize=6 and recipe.portions=4: detail + cooking-mode open showing
  6-portion quantities; add-to-shopping adds 6-portion amounts.
- Manual scaler override to 2 wins over householdSize (explicit wins), incl. shopping add.
- householdSize null ⇒ all three surfaces behave exactly as before (regression tests pass
  unchanged).
- Analytics events fire on set/changed and scaling-applied with correct source.
- No entitlement/tier gate anywhere in the diff.

## Files
lib/models/user_profile.dart · lib/viewmodels/user_profile_viewmodel.dart (if field wiring
needed) · lib/views/settings/menu_taste_view.dart · lib/viewmodels/cooking_mode_viewmodel.dart ·
lib/views/recipe_detail/recipe_detail_content.dart + recipe_detail_actions.dart ·
lib/services/analytics_service.dart (2 events) · l10n ARBs · tests.

## Post-sprint
analyze + suites → code-reviewer + testing-specialist (+ firebase-backend-security if the
user service files are touched) → /code-review → pathspec commit → push → BUT-1322 In Review.

## What this means in plain language
- You can tell Butlery how many people you usually cook for (a "household size" setting on
  the same Settings screen as the menu-taste controls).
- Once set, recipes open already scaled to that many portions — the ingredient amounts on
  the recipe page, in cooking mode, and what goes onto the shopping list. A 4-portion
  recipe with household size 6 shows 6-portion amounts automatically.
- You can still change portions by hand on any recipe — your explicit choice always wins
  over the default.
- If you never set it, nothing changes at all.
- Also records (anonymously) whether people use the default or override it — needed later
  for the grocery-basket accuracy work.
- Low risk: it's a default for numbers already scalable by hand; easy to undo.

## IN FLIGHT 2026-07-02: workflow-map FULL coverage (Malin: current 6/7/5 flows "not remotely full coverage")
Universe per repo: Butlery = docs/feature_inventory.csv (137 IDs, 9 areas) → ~30 flows; binge/synat = functions catalog + routes (enumeration agents running).
Plan: (1) area tracer agents output map-schema JSON fragments (reuse existing node ids); (2) merge into each map's <script id="data"> JSON; (3) engine: grouped sidebar + coverage header; actions get features:[] ; (4) linter upgrade: cross-check CSV IDs ⊆ union(features) → CI enforces coverage forever; (5) lint+browser verify, pathspec-commit+push each repo.
Butlery flow-stamping for existing flows: flow1=IMP-01,03,ENG-01,02,03,07,08,17 · flow2=MENU-01,ENG-12 · flow3=SOC-09,10,11 · flow4=ENG-21 · flow5=AUTH-13 · flow6=AUTH-14,ENG-23.
Deferred: lessons.md commit (parallel-session index); do with final commit.
Fragment protocol: every tracer saves its JSON to scratchpad frags/ (C:\Users\malla\AppData\Local\Temp\claude\C--Butlery-butlery\206cbb25-84cb-4e4c-879f-002d17148d5a\scratchpad\frags\). Expected 16 files: butlery-{auth,cook,grp,rec,imp,menu,soc,set}.json, binge-{library,social,notify,pipelines,ops}.json, synat-{web,intel,cron}.json. When an agent returns JSON in-chat instead, SendMessage it: "save your fenced json verbatim to <path>, reply saved". Merge = script (to write) that splices frags into each map's <script id="data"> JSON: dedupe newNodes by id (skip existing), append actions with area from id prefix, fix unknown step node-ids (linter catches). Universe files written: binge+webbkollen docs/workflow-map-universe.json. Butlery linter already enforces CSV coverage (tools/check_workflow_map.py). Still to do: web-repo linter covers[] check vs universe; engine upgrade (grouped sidebar + coverage header, actions.features/covers render); merge; verify; ship.
