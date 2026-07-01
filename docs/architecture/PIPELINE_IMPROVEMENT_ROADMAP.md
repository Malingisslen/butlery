# Pipeline Improvement Roadmap

> Prioritized output of the 2026-07-01 deep audit of the import→parse→tag→personalize
> pipeline. Every P0/P1 item was **adversarially verified against the code** (zero findings
> refuted). Context and the full system map: `RECIPE_PIPELINE.md`. Raw evidence with
> file:line citations: `tasks/scans/pipeline-audit-2026-07-01/confirmed.json` +
> `minorUnverified.json`.
>
> Working convention: check items off with the commit hash when fixed; this file is the
> single tracker for pipeline health work. Malin decided 2026-07-01: docs only, no Linear
> tickets pre-filed — sessions pick from here.

## P0 — Safety (allergen correctness)

- [ ] **Wire household/present-diner allergen filtering into menu generation** (effort: M)
  `getAvailableRecipesAsync()` (`menu_generator.dart:106`) has zero production callers; all
  generation paths use the sync single-user getter. `useHouseholdAllergens` is inert; its
  test suite calls the dead method directly and stays green. Fix: make
  `generateMenuFromPrompt`/`regenerateMenuSection`/`swapSingleRecipe` await the async pool,
  and add a behavioral test **at the `generateMenuFromPrompt` level** (household allergen X
  → generated menu contains no CONTAINS-X recipe). Note: present-set UI is a known deferral;
  the household-union unwiring is not.
- [ ] **Menu filters must honor user tag overrides + coverage/needsRetagging guards** (M)
  Recipe-list filtering uses `TagEditingService.getEffectiveAllergenStatus` + distrusts
  `coverage<1.0`/`needsRetagging` (`recipe_list_viewmodel.dart:975-1006`); menu generation
  reads raw `tagResult` with none of these (`menu_generator.dart:209-264`, plus
  `_passesGlobals` in `menu_service.dart:500`). A user's manual "this contains gluten"
  correction is ignored by menus. Unify on one filtering helper shared by list + menu.
- [ ] **Gate ingredient master-data writes** (M)
  Three writers on the global `ingredients` collection; the `toAdd` path is full-overwrite
  `batch.set` (wipes `learnedAliasesSv`); no validation between a Sheet cell edit and
  production allergen verdicts; the duplicate `tools/sync_ingredients.dart` can drift from
  the CF. Minimum: preserve learned aliases on add, produce a diff report on every sync,
  and delete one of the two sync implementations.
- [ ] **Add review/revert to alias auto-learning** (M)
  `analyze-corrections.ts`: 3 distinct users auto-write `learnedAliasesSv` onto live
  ingredient docs — allergen-relevant, no human gate, no demotion path. Minimum: hold-for-
  review when the target ingredient carries any allergen property + an admin revoke
  callable + an emulator test driving 3 users through the trigger (none exists).

## P1 — Learning-loop intake (the founder's flywheel goal)

The retrain/measure plumbing mostly exists; the intake is starved. These are connections,
not new systems.

- [ ] **Widen correction capture from 1 of 8 import paths to all** (M) — biggest single win.
  Capture gates on `sourceUrl` + a `ParsedRecipeCache` snapshot only Tier-1 URL imports
  write (`recipe_persistence_manager.dart:475`, `url_import_strategy.dart:454`). Photo/OCR
  (the cookbook use case!), text-paste, Instagram/TikTok/YouTube, and URL tiers 2–7 produce
  zero training data. Attach the pre-edit snapshot per import (keyed by recipe id, tagged
  with source) and diff on any imported recipe.
- [ ] **Log parse events for every import path, not just URL** (S)
  One `ParseEventLogger` call at the end of `ImportManager._parseWithStrategy` (strategy,
  success, needsAssistance, elapsed) covers photo/text/social in one place; reuses the
  existing CF + dashboard.
- [ ] **Fix the CRF retrain deploy+measure links** (M)
  `retrain_with_corrections.sh` stops at writing the weights file: add golden-set eval gate
  (refuse on regression vs `test/golden/crf_ingredients.json`), Storage upload to the
  `RemoteWeightLoader` path + version bump, and print the SHA-256 for the hash registry.
  Also point `export-corrections.ts` at `parse_corrections_v2` (gains the server-side PII
  scrub the current aggregate path skips).
- [ ] **Give `parse_corrections_v2` and `llm_response_samples` a consumer — or turn them off** (S)
  Both are write-only cost sinks; samples expire (30d TTL) before any mining tool exists.
  Cheapest: admin export script mirroring `export-corrections.ts` + a "corrections by
  tier/field" admin-dashboard metric — the only dataset that can answer "did parse quality
  improve after a prompt/model change".
- [ ] **Capture tagging corrections** (M)
  Tag/allergen overrides are display-only; a user removing a wrong CONTAINS badge leaves no
  trace. Mirror the parsing pattern: small `tag_overrides_log` doc on override save
  (tag, direction, triggering ingredients from `TagDecision`); allergen overrides first.
- [ ] **Log menu engagement** (S)
  Zero signals from the monetization linchpin. Two Firebase Analytics events close most of
  it: `menu_generated` and `menu_recipe_swapped` (swap-rate per menu = the one "is the menu
  getting better" number).

## P1 — Cost (grows with users)

- [ ] **Stop full-collection `ingredients` fetch per session + hourly** (M)
  `firebase_ingredient_repository.dart:153` fetches all ~5.6k docs on first use each
  session, re-fetches hourly. Dominant per-user read cost, grows on two axes. Fix: version-
  stamped JSON snapshot in Storage + one version-doc read (export pipeline already exists),
  or bundled snapshot + delta fetch. ~99% read reduction.
- [ ] **Single LLM escalation owner for URL imports** (L)
  Two nested tier waterfalls each end in Gemini: inner `LlmTier` can fire on HTTP HTML and
  again on scraper HTML, then the outer `LlmExtractionFallback` fires too — up to 3 full
  LLM calls per failed import (+selective-enhance calls). Pass `useLlm:false` from
  `_tryEnhancedParser` and keep exactly one escalation point; reconcile the duplicated
  structured-extraction and per-site-selector systems (Firestore `site_configs` vs Dart
  `SiteParserRegistry`).
- [ ] **Server-side daily LLM cap** (S)
  Cost ceilings are client-only; server per-minute buckets allow ~4.3k calls/user/day. Add
  a per-day counter in the existing rate-limiter transaction.
- [ ] **Write retagged results back to GlobalRecipeCache** (S)
  Cache hits re-run the full 35s tagging pipeline on *every* hit after a version bump and
  never write back (`import_manager.dart:773`). One `update` on the doc already read.
- [ ] **TTL on `parse_events`** (S) — grows unbounded, one doc per import attempt, stores raw
  userId+URL forever (also a quiet GDPR surface). Mirror the `llm_response_samples` TTL.
- [ ] **Confirm Gemini pricing constants** (S) — BUT-1187 TODO; all cost telemetry and the
  spend ceilings derive from two unverified constants (`gemini-client.ts:833`).

## P2 — Flow consolidation & dead code

- [ ] **Unify the two URL import pipelines** (M) — OS share sheet AND '/importViaUrl' use the
  legacy WebScraper path (no platform pipelines/cache/rate-limit/telemetry; YouTube shares
  get a body scrape instead of transcripts). Route both into `ImportManager.autoImport`.
- [ ] **Delete `TagGenerator.generate()`** (L, mostly test re-homing) — ~175-line dead
  duplicate orchestrator; `tag_generator_test.dart` pins it 142×; re-home phase tests onto
  phase calculators / `TaggingPipelineRunner`.
- [ ] **Config-change invalidation for tags** (M) — stamp a config revision into `TagResult`
  so remote `tag_configs` changes trigger retag; design a server-side batch retag before
  ever bumping `kTagGeneratorVersion` at scale (currently: every client re-tags everything).
- [ ] **Rebuild `TagGenerator` when config loads late** (S) — constructed once from
  `configOrNull`; a slow/failed config fetch pins the session to static fallback rules.
- [ ] **Thread real tier/confidence into cache `ExtractionMeta`** (S) — currently hardcoded
  `tier: 0, confidence: 0.8`; the real tier is computed and discarded.
- [ ] **One `ImportResultV2→legacy` adapter** (S) — currently copied in 3 pipelines.
- [ ] **Correction-upload failure metric** (S) — unknown-tier and salt-not-loaded drops are
  silent (return 0, debug log); mirror `parseEventLogFailed` (BUT-616 pattern). Also
  unify the 3 hand-synced tier vocabularies (client map + 2 server allowlists).
- [ ] **Misc dead code** (S) — `FileImportStrategy` unreachable in the autoImport loop;
  `InstagramContentExtractor.extractWithResult` dead; `ingredient_categorizer.dart`
  mis-homed in tagging/.

## P2 — Test quality

- [ ] **One true end-to-end USP test** (M) — raw Swedish recipe text → real
  `ImportManager.autoImport` → real `TaggingService`/`TaggingPipelineRunner` → real (fixture-
  seeded) `IngredientLookupService` → assert specific allergen TriStates. The current
  "Import → Tagging Integration" test runs no import, fakes the lookup, and drives the dead
  orchestrator. 3–4 representative recipes close the pipeline's largest untested seam.
- [ ] **CI-gate the tag scorecard** (S) — `test/corpus/tag_scorecard_test.dart` (the allergen
  accuracy metric) runs only manually; add to the suite matrix in `test.yml` with a numeric
  floor, like the CRF golden gate (BUT-1443 pattern).
- [ ] **Grow the gated corpora** (M) — parsing golden set has 4 recipes; site-parser fixtures
  are hand-invented HTML (real ICA markup drift is invisible). Capture real HTML snapshots
  per supported domain; mine `llm_response_samples`/corrections for hard cases before TTL.
- [ ] **`reserved_tags.dart` consistency test** (S) — ~120 hand-copied tag literals, nothing
  asserts they match what the phases emit; a new auto-tag can be silently shadowed by a
  personal tag.
- [ ] **TagResult serialization/migration round-trip tests** (S) — read-time-only V0→V2
  migration, never written back; cross-user cache ships one user's TagResult to others;
  zero migration-correctness coverage.
- [ ] **Strengthen `import_manager_test` happy path** (S) — asserts only
  `isSuccess`/strategy-not-null; add title + ingredient-count assertions.

## Deliberately NOT flagged

- Alias-learning 3-user threshold is the right anti-poisoning bar (add review/revert, don't raise it).
- Error-swallowing in telemetry paths is by design ("never block the user") — the ask is failure *metrics*, not throwing.
- Prompt A/B machinery being unused is fine pre-launch; it's measure-ready.
- Everything in `.claude/rules/accepted-deviations.md` was excluded from findings.
