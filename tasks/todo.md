# Sprint Backlog

## Sprint: import cost-guard — "doesn't look like a recipe" warn dialog — 2026-06-04 (iter-108)

Carried from iter-107. Clean tree on main (prior commits 9c8946120, ba7c7a4e3). Focused single
multi-file ticket: stop paid LLM calls on clearly-non-recipe pasted text.

### Agent A: import-quality
- [ ] **A1. BUT-1037** `[Tier A heuristic + Tier B dialog]` — (BUT-973 follow-up)
      - **Step 0:** fits. `parseText()` user-trigger is `fran_sociala_medier_view._parseAndNavigate`
        (button gated on `canParse`); VM exposes `inputText`; telemetry via
        `AnalyticsService.import` (ImportEventsTracker, mirrors `logImportCancelled`).
      - Pure `RecipeTextHeuristic.looksLikeRecipe(String)` — measurement words (sv `gram|g|dl|ml|tsk|
        msk|kopp|krm|stycken|st…` + en `cup|tbsp|tsp|oz|lb…`, extended past the ticket's sv-only
        list so a typical EN recipe passes) + cooking verbs (sv+en). Threshold: ≥1 measure AND
        ≥1 verb, OR ≥3 total hits. Unit tests (sv recipe / en recipe / ingredient-only / conversation
        / article / gibberish).
      - Warn dialog in `_parseAndNavigate` when heuristic fails → cancel (log
        `import_warn_dialog_cancelled`, no LLM) / import-anyway (proceed). Auto-parse path
        (initState, URL-shared content) is NOT gated.
      - l10n sv/en for dialog. New `AnalyticsEvents.importWarnDialogCancelled` + tracker method.

### Needs you (Tier D / deferred — carried)
- BUT-1169 — legacy shopping-constant drop (needs prod backfill CF first).
- BUT-838 — recipe_cook_events log (rules+index+CF, dedicated Tier-C sprint).
- BUT-1187 — phone import runtime-verify. onRecipeDeleted gen-2 deploy ticket.

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos`
- [ ] heuristic unit tests green
- [ ] Commit, push
- [ ] Linear: In Review + notify (dialog UX needs eyes)

---

## ARCHIVED — iter-107: gesture-hint discoverability (2026-06-04, shipped ba7c7a4e3)

BUT-1199 → In Review. Generalized SwipeHintBanner + cooking-step + shopping-claim hints, 6 tests.

## ARCHIVED — iter-106: post-refactor testability + import-UX (shipped 9c8946120)

5 Tier-A Done (1194/1195/1196/1197/1028) + BUT-1198 allergen banner In Review. Follow-up BUT-1200.
