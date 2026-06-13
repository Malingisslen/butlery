# Sprint Backlog

## Sprint: schemaVersion-foundation + related-recipes-UI — 2026-06-13 (iter-144)

Tight 2-ticket batch (4th sprint this session — quality over volume). Skipped BUT-1011 (premature per its own telemetry gate) and BUT-1169 (constant-drop unsafe before a prod backfill).

### Agent A: schema — forward-compatible schemaVersion `[Tier C]` (always risk-gated; touches firestore.rules + security)
- [x] **A1. Add schemaVersion to the 6 core models + lazy-read + rules allowlist** `[Tier C]` — add `schemaVersion: int` (default 1) to UserProfile, Recipe, Menu, MealPlan, ShoppingList, PersonalTag following the EXISTING `TagResult` versioned pattern (`lib/models/tagging/tag_result.dart`); read it in each repository `fromFirestore` (default 1 when absent — lazy migration handles old docs WITHOUT a backfill); write it on save; extend `firestore.rules` per-collection field allowlists to accept `schemaVersion`; one-paragraph doc. Backfill CF is DEFERRED (lazy-on-read covers old docs) → follow-up. NO speculative migration framework — just the version field + read/write + rules (YAGNI until a real v2 exists). (BUT-648)
  - Acceptance: all 6 models expose `schemaVersion` (default 1), round-tripping through to/fromFirestore (testpinned) · each model's `fromFirestore` defaults to 1 when the field is absent (old-doc compatibility, testpinned) · `firestore.rules` allows `schemaVersion` on all 6 collections AND the rules test suite proves a write WITH it is allowed and the existing constraints still hold · `dart analyze` clean; existing model/repo tests green · NO backfill CF and NO migration-dispatch framework added (deferred — scope discipline)

### Agent B: recipe UI — related-recipes wiring `[Tier B]`
- [x] **B1. Link/unlink picker in editor + Related/Used-in sections on detail** `[Tier B]` — service layer (`RecipeRelationsService.link/unlink` via `unifiedRecipeService`) already exists. Editor (`lib/views/edit_recipe_view.dart` + `lib/viewmodels/recipe_form/recipe_form_coordinator.dart`): "+ Länka relaterat recept" button → multi-select picker → `linkRecipes`; show current `relatedRecipeIds` as removable chips (X → `unlinkRecipes`). Detail (`lib/views/recipe_detail/recipe_detail_content.dart`): "Relaterade recept" grid when non-empty, tappable → navigate; "Används i" section via `recipes.where((r) => r.relatedRecipeIds?.contains(currentId) ?? false)`. Do NOT modify the Recipe model (read existing `relatedRecipeIds`). (BUT-1057)
  - Acceptance: user can link AND unlink related recipes from the editor (chips + picker, widget-testpinned) · detail view renders "Relaterade recept" + "Används i" sections only when populated (testpinned empty→hidden, non-empty→shown) · tapping a related thumbnail navigates to that recipe's detail · square design language + l10n strings (sv+en); HTML preview → In Review

### Needs you (Tier D / deferred-by-design)
- BUT-1011 — async account-deletion polling: build only IF Functions telemetry shows real `deadline-exceeded` timeouts (ticket's own gate). None reported. Not worked.
- BUT-1169 — dropping legacy meat_fish/fruit_veg constants needs a prod backfill of existing docs first (else old docs render blank); backfill needs prod access. Not worked.
- BUT-840 / ops cluster — unchanged.

### Post-Sprint Steps
- [x] Run `dart analyze --fatal-infos` + arch gates (architecture_test + AppColors grep)
- [x] Run relevant unit tests + firestore.rules test suite
- [x] Phase 2.7 outcome-grading per agent group
- [x] Follow-ups → Linear BEFORE commit (schemaVersion backfill CF)
- [x] Commit, push
- [x] Linear: none Tier A this batch; BUT-648 (C) + BUT-1057 (B) → In Review + notify

---
## ARCHIVED — iter-143 (BUT-1245/626 Done; BUT-1244/862 In Review; follow-ups BUT-1246/1247; CI green) · iter-142 (BUT-879/881 Done; BUT-1243/925/1154 In Review; arch-fix 5e04bcabe) · iter-141 (BUT-1238/1005/1237/928/604/954) · äldre i git-historiken
