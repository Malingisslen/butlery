# The Recipe Pipeline — End-to-End Map

> The USP chain: **any source → import → extraction → parsing → tagging → personalization**,
> plus the learning loop that is supposed to improve it over time.
> Produced by the 2026-07-01 deep audit (24-agent sweep, every claim code-verified).
> Raw subsystem maps: `tasks/scans/pipeline-audit-2026-07-01/` (disposable working copies).
> Prioritized fixes: `PIPELINE_IMPROVEMENT_ROADMAP.md` (sibling file).
> Deeper stage docs: `docs/parser/PARSER_ARCHITECTURE.md`, `docs/tagging/tagging_system.md`,
> skills `tagging-domain-knowledge`, `butlery-architecture`.
> Human-facing visual (Swedish, for Malin/onboarding): `docs/onboarding/pipeline-map.html` —
> keep its status lamps in sync when roadmap items are fixed.

## The chain at a glance

```
  URL │ photo │ pasted text │ file │ Instagram │ TikTok │ YouTube │ OS share sheet
        │
        ▼
┌── IMPORT (lib/services/import/) ─────────────────────────────────────────────┐
│ ImportManager.autoImport = THE entry point: rate-limit → GlobalRecipeCache   │
│ lookup → platform pipelines (YouTube/TikTok/Instagram) → strategy loop       │
│ (Archive, Url, Text, File, Photo). Parse-only; save happens after user review│
│ ⚠ A SECOND, degraded URL pipeline exists: OS share sheet AND the manual      │
│   '/importViaUrl' screen use the legacy WebScraper path (no platform         │
│   pipelines, no cache, no rate limiter, no parse telemetry). Only the        │
│   "Importera länk" tile → /smartImport uses the full pipeline.               │
└──────────────────────────────────────────────────────────────────────────────┘
        │  UrlImportStrategy = 7-tier waterfall (its Tier 1+3 call ↓)
        ▼
┌── PARSING ML CORE (lib/services/parsing/) ───────────────────────────────────┐
│ RecipeParserService: SchemaOrg → SiteConfig → RuleBased → LlmTier, stops at  │
│ quality ≥0.65 (+0.15 for reliable domains). Ingredient lines: CRF (Viterbi)  │
│ → BERT NER (ONNX) → selective LLM enhance (~500 tokens) → full LlmTier.      │
│ Models: bundled assets + Firebase Storage OTA, SHA-256 fail-closed registry. │
│ Output: ParsedRecipe with per-field confidence.                              │
└──────────────────────────────────────────────────────────────────────────────┘
        │  (photo = OCR → TextImportStrategy regex parser, NOT this service)
        ▼
┌── CLOUD LLM (functions/src/llm/) ────────────────────────────────────────────┐
│ structureRecipe + ocrRecipeImage callables → Gemini 2.5 Flash Lite (Vertex,  │
│ eu). PII scrub both sides (shared fixture), kill switches, prompt A/B infra  │
│ (built, no experiment live), per-call sample capture (write-only, 30d TTL).  │
└──────────────────────────────────────────────────────────────────────────────┘
        │  saved Recipe
        ▼
┌── TAGGING (lib/services/tagging/) ───────────────────────────────────────────┐
│ 100% deterministic, zero LLM. Phase 0 ingredient lookup (global ingredients  │
│ DB + aliases + fuzzy) → Phase 1 allergen/dietary/nutrition/method (TriState, │
│ coverage<1.0 ⇒ UNKNOWN) → 2 derived → 3 complex → 4 mood → 5 cuisine.        │
│ Live orchestrator = TaggingPipelineRunner (per-phase timeout budgets, floors)│
│ ⚠ TagGenerator.generate() is a dead duplicate orchestrator (see truth table) │
└──────────────────────────────────────────────────────────────────────────────┘
        │  TagResult (tags + allergen/dietary TriState maps + decisions)
        ▼
┌── PERSONALIZATION (lib/services/menu*, lib/viewmodels/menu/) ────────────────┐
│ MenuGenerator → MenuService: hard filter (allergen/dietary) → multiplicative │
│ weights (recency × season 1.5 × rating ≤1.4 × pantry ≤1.3 × cuisine 1.25 ×   │
│ skill) → weighted random draw → cuisine-diversity cap (2/cuisine).           │
│ Prompt parsing is a deterministic lexicon (MenuConstraintParser), not LLM.   │
│ ⚠ Generation uses the sync single-user pool; household/present-diner        │
│   filtering and user tag overrides are NOT applied (see truth table).        │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Stage guide (key files)

| Stage | Orchestrator | The one file to read first |
|---|---|---|
| Import | `ImportManager` (`lib/services/import/import_manager.dart`) | `url_import_strategy.dart` (the 7-tier waterfall) |
| Extraction (legacy path) | `ExtractionManager` (`lib/services/extraction/`) | `web_scraper.dart` |
| Parsing ML | `RecipeParserService` (`lib/services/parsing/recipe_parser_service.dart`) | `tiers/parsing_context.dart` (cross-tier state) |
| Cloud LLM | `structure-recipe.ts` (`functions/src/llm/`) | `gemini-client.ts` (schema, cost, salvage parser) |
| Tagging | `TaggingService` → `TaggingPipelineRunner` | `tagging_pipeline_runner.dart` (budgets + floors) |
| Personalization | `MenuGenerator` → `MenuService` | `menu_service.dart` `_recipeWeight` + `menu_scoring.dart` |
| Learning loop | no single owner — see table below | `functions/src/analytics/analyze-corrections.ts` |

## Wired vs dormant vs dead (the truth table)

The docs and the code describe more system than actually runs. This table is the
audit's core finding — check it before trusting any description of the pipeline.

| Piece | Status | Reality (verified 2026-07-01) |
|---|---|---|
| 5-tier parse waterfall + ingredient cascade | **LIVE** | Works as documented; short-circuit at 0.65 quality; selective LLM enhance before full LLM. |
| Site-config success counters → routing | **LIVE, closed loop** | `logParseEvent` increments per-domain counters; `computedQualityScore` flips to live data at ≥5 samples; `isReliable` raises the LLM-avoidance threshold. The one fully automatic flywheel. |
| Alias learning (corrections → `learnedAliasesSv`) | **LIVE but dormant** | Auto-writes production ingredient master data at 3 distinct users; unreachable pre-launch; **no review/revert path** (roadmap P1). |
| CRF retrain pipeline | **HALF-BUILT** | Corrections→CoNLL→retrain script works; but no Storage upload step, hash registry forces an app release anyway, and no golden-set eval gate before shipping weights. |
| `parse_corrections_v2` (per-field, scrubbed) | **WRITE-ONLY** | Built by BUT-595 to be queryable; nothing queries it. The CRF export reads the *old* unscrubbed aggregate collection instead. |
| `llm_response_samples` capture | **WRITE-ONLY** | Every paid Gemini call captured "for mining"; no reader exists; 30-day TTL deletes before use. |
| Prompt A/B infrastructure | **BUILT, unused** | Bucketing + per-bucket logging fully threaded; no experiment configured. |
| Correction capture (flywheel intake) | **~1 of 8 paths** | Only Tier-1 URL imports write the ParsedRecipeCache snapshot the diff needs. Photo/OCR, text-paste, Instagram/TikTok/YouTube, and URL tiers 2–7 produce **zero** training data. |
| Parse telemetry (`parse_events`) | **URL path only** | Photo/text/social imports emit no parse events — their success rate is invisible to the admin dashboard. |
| Household/present-diner allergen filtering | **DEAD CODE** | `getAvailableRecipesAsync()` has zero production callers; all menu generation uses the sync single-user getter. Its tests call the dead method directly and stay green. **CRITICAL, roadmap P0.** |
| Menu generation vs user tag overrides | **GAP** | Recipe-list filtering honors overrides + coverage + needsRetagging guards; menu generation reads raw `tagResult` with none of them. A user's manual "this DOES contain gluten" correction is ignored by menus. |
| `TagGenerator.generate()` | **DEAD** | ~175-line duplicate orchestrator, zero production callers; live path is `TaggingPipelineRunner`. Yet `tag_generator_test.dart` (3,300 lines) pins it 142 times, and the "Import → Tagging Integration" test also runs it. |
| Tag-config change → retag | **MISSING LINK** | `needsRetagging` keys only on the code constant `kTagGeneratorVersion`; a remote `tag_configs` change never invalidates existing tags. Conversely, bumping the constant makes every client re-tag everything (no server-side batch path). |
| Tagging correction loop | **MISSING** | User tag/allergen overrides are display-only; "the auto-tagger got an allergen wrong" leaves no queryable trace anywhere. |
| Menu engagement signals | **MISSING** | Swaps/regenerations/rejections not logged at all — menu quality (the monetization linchpin) is unmeasurable. |
| Corpus eval harnesses (`tools/corpus/`, tag scorecard) | **NOT GATED** | Exist and run manually; no CI workflow references them. (CRF golden set IS CI-gated at ≥85%; tagging golden runs in the golden suite.) |

## The learning loop, honestly

| Signal | Captured where | Fed back into | Automatic? |
|---|---|---|---|
| Parse success/tier/cost | `parse_events` (Firestore, **no TTL**) | `site_configs` domain counters → routing | ✅ yes |
| Field corrections (aggregate) | `parsing_corrections` (client-written, unscrubbed) | alias learning + CRF retrain export | alias: ✅ / CRF: manual, deploy link broken |
| Field corrections (per-field, scrubbed) | `parse_corrections_v2` | nothing | ❌ no consumer |
| LLM call samples | `llm_response_samples` (30d TTL) | nothing | ❌ no consumer |
| Tagging health | Firebase Analytics events | dashboards only | observability, not learning |
| Tag/allergen overrides | per-recipe `TagOverrides` | display merge only | ❌ never analyzed |
| Menu behavior | — | — | ❌ not captured |
| Ratings (family/public) | rating subsystem | `_ratingMultiplier` next generation | ✅ (lagging signal) |

**Net:** two loops genuinely close (site-config routing, alias learning-at-scale). Everything
else is either intake-starved (corrections from 1 of 8 paths), write-only (v2, LLM samples),
or missing (tagging corrections, menu engagement). The retrain half is built but the
deploy+measure links are broken. Most fixes are *connections between existing pieces*,
not new systems — see the roadmap.

## Cross-cutting facts worth knowing

- **Allergen safety spine:** global `ingredients` collection (client-write-denied) → `IngredientLookupService` → Phase 1 TriState. Two writers mutate that collection: `sync-ingredients.ts` (Sheet CSV; the duplicate `tools/sync_ingredients.dart` was deleted 2026-07-03, BUT-1467) and alias learning. Since BUT-1467 the sync fails closed on malformed CSV, preserves `learnedAliasesSv`, repairs TTL lifecycle state, and writes a per-run diff report (`docs/tagging/data/sync-reports/`) + `system_events` row highlighting allergen-property removals — the validation gate between a Google-Sheet cell edit and production allergen verdicts.
- **Cost design is real:** deterministic-first everywhere, selective LLM enhance, cross-user GlobalRecipeCache (90–180d TTLs), 4 layers of spend controls, gemini-2.5-flash-lite. Two big leaks: full `ingredients` collection fetched per session + hourly (dominant read cost, roadmap P1), and stale cache hits re-tag on every hit without writing back.
- **Rate-limit asymmetry:** the $0.50/day / $10/month LLM ceilings are client-side only; the server allows ~4,300 structureRecipe calls/user/day via per-minute buckets alone.
- **Cache provenance is fabricated:** every GlobalRecipeCache entry records `tier: 0, confidence: 0.8` — the real winning tier is computed and discarded, so cache ROI and LLM-spend attribution are unmeasurable.
- **`ExtractionMeta`/`ParsingContext` side channels:** `SchemaOrgTier` writes `jsonLdData` that `LlmTier` reads — tier reordering breaks silently.
- **`ingredient_categorizer.dart` is NOT tagging** — it's shopping-list bucketing; relocated to `lib/services/shopping/` (BUT-1487, previously mis-homed under `tagging/` by historical accident).
- **Version keys:** `parserVersion` 2.0.0 (parse cache), `kTagGeneratorVersion` 2.1.0 (retag trigger), `PROMPT_VERSION` 2.1.0 (changelog-guarded), CRF `bundledWeightVersion`, TagResult schema V2 (read-time-only migration, never written back).

## What is genuinely good (preserve these patterns)

- Per-phase timeout budgets with safety floors in tagging (lookup floor, Phase-1 floor, Phase-5-from-Phase-1) — graceful degradation, never silent corruption; tested via an injectable phase-callables seam.
- CI-gated CRF golden set (433 entries, ≥85% all-fields-exact floor) and boundary-pinning parser tests (0.65 stops / 0.649 continues).
- Fail-closed SHA-256 registry on all remote ML artifacts.
- PII defense-in-depth on the LLM boundary (mirrored Dart/TS scrubbers synced via shared fixture vectors).
- The site-config flywheel (capture → measure → behavior change, no human in the loop) — the pattern to replicate for the other loops.
- `menu_personalization_test.dart`'s statistical diversity test and cross-cutting ceiling invariant.
