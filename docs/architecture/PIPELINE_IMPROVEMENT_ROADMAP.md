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

## How to work this roadmap (model routing — decided 2026-07-01)

Route by blast radius, not task size (per `~/.claude/CLAUDE.md` + `CLAUDE.local.md`):
- **Script first, AI second.** Data validation, register diffs, bulk checks → deterministic
  scripts (the audits' pre-passes found half the findings for ~$0). Sheet edits are Malin's.
- **Sonnet, low effort** for the mechanical items (marked S with no safety domain): sync
  comma-split, `.trim()`/plural normalization fixes, TTL fields, telemetry one-liners,
  cache write-back, doc updates, all Explore/scan subagents.
- **Opus (session model), plan-first** for anything touching allergen verdicts, menu
  filtering, `allergen_config`/`dietary_config`, draft policy, Firestore rules/repos —
  and ALWAYS for the commit-gate reviewers regardless of diff size.
- **Workflows only for fan-out** (re-audits, multi-file sweeps): sonnet finders → opus
  verifiers. Single-session for everything else — orchestration overhead isn't free.
- Effort knob is separate from model: subagents run low effort even on opus.

## P0 — Safety (allergen correctness)

- [x] **Wire household/present-diner allergen filtering into menu generation** — DONE 2026-07-02 (`820e89b76`, BUT-1464 In Review)
  `getAvailableRecipesAsync()` (`menu_generator.dart:106`) has zero production callers; all
  generation paths use the sync single-user getter. `useHouseholdAllergens` is inert; its
  test suite calls the dead method directly and stays green. Fix: make
  `generateMenuFromPrompt`/`regenerateMenuSection`/`swapSingleRecipe` await the async pool,
  and add a behavioral test **at the `generateMenuFromPrompt` level** (household allergen X
  → generated menu contains no CONTAINS-X recipe). Note: present-set UI is a known deferral;
  the household-union unwiring is not.
- [x] **Menu filters must honor user tag overrides + coverage/needsRetagging guards** — DONE 2026-07-02 (`820e89b76` via MenuAllergenTrust; per-slot remainder = BUT-1466)
  Recipe-list filtering uses `TagEditingService.getEffectiveAllergenStatus` + distrusts
  `coverage<1.0`/`needsRetagging` (`recipe_list_viewmodel.dart:975-1006`); menu generation
  reads raw `tagResult` with none of these (`menu_generator.dart:209-264`, plus
  `_passesGlobals` in `menu_service.dart:500`). A user's manual "this contains gluten"
  correction is ignored by menus. Unify on one filtering helper shared by list + menu.
- [ ] **Gate ingredient master-data writes** (M) → BUT-1467
  Three writers on the global `ingredients` collection; the `toAdd` path is full-overwrite
  `batch.set` (wipes `learnedAliasesSv`); no validation between a Sheet cell edit and
  production allergen verdicts; the duplicate `tools/sync_ingredients.dart` can drift from
  the CF. Minimum: preserve learned aliases on add, produce a diff report on every sync,
  and delete one of the two sync implementations.
- [ ] **Add review/revert to alias auto-learning** (M) → BUT-1468
  `analyze-corrections.ts`: 3 distinct users auto-write `learnedAliasesSv` onto live
  ingredient docs — allergen-relevant, no human gate, no demotion path. Minimum: hold-for-
  review when the target ingredient carries any allergen property + an admin revoke
  callable + an emulator test driving 3 users through the trigger (none exists).

## P1 — Learning-loop intake (the founder's flywheel goal)

The retrain/measure plumbing mostly exists; the intake is starved. These are connections,
not new systems.

- [ ] **Widen correction capture from 1 of 8 import paths to all** (M) — biggest single win. → BUT-1469
  Capture gates on `sourceUrl` + a `ParsedRecipeCache` snapshot only Tier-1 URL imports
  write (`recipe_persistence_manager.dart:475`, `url_import_strategy.dart:454`). Photo/OCR
  (the cookbook use case!), text-paste, Instagram/TikTok/YouTube, and URL tiers 2–7 produce
  zero training data. Attach the pre-edit snapshot per import (keyed by recipe id, tagged
  with source) and diff on any imported recipe.
- [ ] **Log parse events for every import path, not just URL** (S) → BUT-1470
  One `ParseEventLogger` call at the end of `ImportManager._parseWithStrategy` (strategy,
  success, needsAssistance, elapsed) covers photo/text/social in one place; reuses the
  existing CF + dashboard.
- [ ] **Fix the CRF retrain deploy+measure links** (M) → BUT-1471
  `retrain_with_corrections.sh` stops at writing the weights file: add golden-set eval gate
  (refuse on regression vs `test/golden/crf_ingredients.json`), Storage upload to the
  `RemoteWeightLoader` path + version bump, and print the SHA-256 for the hash registry.
  Also point `export-corrections.ts` at `parse_corrections_v2` (gains the server-side PII
  scrub the current aggregate path skips).
- [ ] **Give `parse_corrections_v2` and `llm_response_samples` a consumer — or turn them off** (S) → BUT-1472
  Both are write-only cost sinks; samples expire (30d TTL) before any mining tool exists.
  Cheapest: admin export script mirroring `export-corrections.ts` + a "corrections by
  tier/field" admin-dashboard metric — the only dataset that can answer "did parse quality
  improve after a prompt/model change".
- [ ] **Capture tagging corrections** (M) → BUT-1473
  Tag/allergen overrides are display-only; a user removing a wrong CONTAINS badge leaves no
  trace. Mirror the parsing pattern: small `tag_overrides_log` doc on override save
  (tag, direction, triggering ingredients from `TagDecision`); allergen overrides first.
- [ ] **Log menu engagement** (S) → BUT-1474
  Zero signals from the monetization linchpin. Two Firebase Analytics events close most of
  it: `menu_generated` and `menu_recipe_swapped` (swap-rate per menu = the one "is the menu
  getting better" number).

## P1 — Cost (grows with users)

- [ ] **Stop full-collection `ingredients` fetch per session + hourly** (M) → BUT-1475
  `firebase_ingredient_repository.dart:153` fetches all ~5.6k docs on first use each
  session, re-fetches hourly. Dominant per-user read cost, grows on two axes. Fix: version-
  stamped JSON snapshot in Storage + one version-doc read (export pipeline already exists),
  or bundled snapshot + delta fetch. ~99% read reduction.
- [ ] **Single LLM escalation owner for URL imports** (L) → BUT-1476
  Two nested tier waterfalls each end in Gemini: inner `LlmTier` can fire on HTTP HTML and
  again on scraper HTML, then the outer `LlmExtractionFallback` fires too — up to 3 full
  LLM calls per failed import (+selective-enhance calls). Pass `useLlm:false` from
  `_tryEnhancedParser` and keep exactly one escalation point; reconcile the duplicated
  structured-extraction and per-site-selector systems (Firestore `site_configs` vs Dart
  `SiteParserRegistry`).
- [ ] **Server-side daily LLM cap** (S) → BUT-1477
  Cost ceilings are client-only; server per-minute buckets allow ~4.3k calls/user/day. Add
  a per-day counter in the existing rate-limiter transaction.
- [ ] **Write retagged results back to GlobalRecipeCache** (was S — actually L)
  ATTEMPTED + REVERTED 2026-07-02: a client-side write-back is **impossible by design** —
  firestore.rules restricts cache updates to access stats as a deliberate cache-poisoning
  defense (code review confirmed: loosening it would let one client's tags, incl. per-user
  ingredient overrides and partial timeout results, become canonical shared allergen data).
  Real fix requires a server-side path (Cloud Function re-running the tagging engine —
  which is Dart client code, so this means a TS port or a headless tagging service) OR
  accepting per-hit client retag cost. Accepted for now (pre-launch scale, pennies);
  revisit before user growth. The 2.2.0 retag bump shipped WITHOUT it (Legal condition —
  known-wrong FREE verdicts must not persist — outweighed the FinOps deferral at ~1 user).
- [ ] **TTL on `parse_events`** (S) → BUT-1478 — grows unbounded, one doc per import attempt, stores raw
  userId+URL forever (also a quiet GDPR surface). Mirror the `llm_response_samples` TTL.
- [ ] **Confirm Gemini pricing constants** (S) → BUT-1479 — BUT-1187 TODO; all cost telemetry and the
  spend ceilings derive from two unverified constants (`gemini-client.ts:833`).

## P2 — Flow consolidation & dead code

- [ ] **Unify the two URL import pipelines** (M) → BUT-1480 — OS share sheet AND '/importViaUrl' use the
  legacy WebScraper path (no platform pipelines/cache/rate-limit/telemetry; YouTube shares
  get a body scrape instead of transcripts). Route both into `ImportManager.autoImport`.
- [ ] **Delete `TagGenerator.generate()`** (L, mostly test re-homing) → BUT-1481 — ~175-line dead
  duplicate orchestrator; `tag_generator_test.dart` pins it 142×; re-home phase tests onto
  phase calculators / `TaggingPipelineRunner`.
- [ ] **Config-change invalidation for tags** (M) → BUT-1482 — stamp a config revision into `TagResult`
  so remote `tag_configs` changes trigger retag; design a server-side batch retag before
  ever bumping `kTagGeneratorVersion` at scale (currently: every client re-tags everything).
- [ ] **Rebuild `TagGenerator` when config loads late** (S) → BUT-1483 — constructed once from
  `configOrNull`; a slow/failed config fetch pins the session to static fallback rules.
- [ ] **Thread real tier/confidence into cache `ExtractionMeta`** (S) → BUT-1484 — currently hardcoded
  `tier: 0, confidence: 0.8`; the real tier is computed and discarded.
- [ ] **One `ImportResultV2→legacy` adapter** (S) → BUT-1485 — currently copied in 3 pipelines.
- [ ] **Correction-upload failure metric** (S) → BUT-1486 — unknown-tier and salt-not-loaded drops are
  silent (return 0, debug log); mirror `parseEventLogFailed` (BUT-616 pattern). Also
  unify the 3 hand-synced tier vocabularies (client map + 2 server allowlists).
- [ ] **Misc dead code** (S) → BUT-1487 — `FileImportStrategy` unreachable in the autoImport loop;
  `InstagramContentExtractor.extractWithResult` dead; `ingredient_categorizer.dart`
  mis-homed in tagging/.

## P2 — Test quality

- [ ] **One true end-to-end USP test** (M) → BUT-1488 — raw Swedish recipe text → real
  `ImportManager.autoImport` → real `TaggingService`/`TaggingPipelineRunner` → real (fixture-
  seeded) `IngredientLookupService` → assert specific allergen TriStates. The current
  "Import → Tagging Integration" test runs no import, fakes the lookup, and drives the dead
  orchestrator. 3–4 representative recipes close the pipeline's largest untested seam.
- [ ] **CI-gate the tag scorecard** (S) → BUT-1489 — `test/corpus/tag_scorecard_test.dart` (the allergen
  accuracy metric) runs only manually; add to the suite matrix in `test.yml` with a numeric
  floor, like the CRF golden gate (BUT-1443 pattern).
- [ ] **Grow the gated corpora** (M) → BUT-1490 — parsing golden set has 4 recipes; site-parser fixtures
  are hand-invented HTML (real ICA markup drift is invisible). Capture real HTML snapshots
  per supported domain; mine `llm_response_samples`/corrections for hard cases before TTL.
- [ ] **`reserved_tags.dart` consistency test** (S) → BUT-1491 — ~120 hand-copied tag literals, nothing
  asserts they match what the phases emit; a new auto-tag can be silently shadowed by a
  personal tag.
- [ ] **TagResult serialization/migration round-trip tests** (S) → BUT-1492 — read-time-only V0→V2
  migration, never written back; cross-user cache ships one user's TagResult to others;
  zero migration-correctness coverage.
- [ ] **Strengthen `import_manager_test` happy path** (S) → BUT-1493 — asserts only
  `isSuccess`/strategy-not-null; add title + ingredient-count assertions.

## P0 — Register & config data quality (added 2026-07-01, second audit)

Source: 23-agent semantic audit of the full 2,230-row ingredient register + tag configs.
Evidence: `tasks/scans/register-audit-2026-07-01/` (fix-list CSV + config/drift/coverage reports).
Register fixes happen in the **Google Sheet** then re-sync — they are Malin's data edits, not code.

- [x] **CONFIG: `seafood` property fires no allergen verdict** — DONE 2026-07-02.
  Panel-reviewed (7× approve-with-conditions). `seafood` added to the skaldjur combined
  trigger + vegetarisk/kosheranpassad exclusions + vegansk hardened, in BOTH the static
  fallback AND the Firestore `tag_configs` docs (seeded to production at version 2 —
  which turned out to have never been seeded before: production ran on static fallback
  all along, and the un-seeded script copy even had a DIFFERENT vegetarisk rule; now
  unified). NOT added to fisk (PM condition). Sync-time warning added for seafood-only
  rows. 18 behavioral tests on both config branches + vocabulary lockstep test.
  kTagGeneratorVersion 2.1.0→2.2.0 forces organic retag of all stale verdicts.
- [ ] **REGISTER: gelatin still passes as vegetarian — 2 Sheet cells for Malin** (S) → BUT-1494
  `gelatin` + `gelatinblad` carry only `animal-product` (verified in synced register
  2026-07-02); vegetarisk correctly doesn't exclude animal-product (dairy/egg carry it),
  so gelatin needs `meat,pork` added to its properties in the Sheet + re-sync. (`pork`
  also fixes halalanpassad — Swedish gelatin is overwhelmingly pork-derived.) The
  config half is DONE: vegetarisk now also excludes `seafood`, so seafood-only animals
  (jellyfish etc.) can't pass as vegetarian; the audit's original suggestion (exclude
  `animal-product` wholesale) was wrong and is documented in dietary_config.dart.
- [x] **POLICY: draft ingredients produce authoritative FREE verdicts** — DECIDED 2026-07-01:
  Malin keeps status quo (drafts retain full verdict authority incl. FREE). Recorded in
  `.claude/rules/accepted-deviations.md`; mitigations = draft banner + fix-list + hygiene.
  Do not reopen in reviews.
- [x] **DATA: apply the 87 confirmed register fixes** — DONE 2026-07-02. Malin's session
  fixed the Sheet (84 sweep + 7 judgment calls; before/after verified, no allergen ever
  removed); export diffed independently (87 rows, 4 intended removals only) and synced to
  production Firestore (2,230 docs updated — also backfilled the Sprint-1 metadata fields
  the Dec-27 sync predated). Live-verified: öl+gluten, hazelnut-cream=nutella+dairy,
  chicken-oyster "ostron" alias gone, liver-pate+dairy.
  NOTE: existing recipes keep pre-fix verdicts until the retag bump ships (part of the
  seafood config fix plan below).
- [ ] **SYNC BUG: comma-separated aliases not split** (S, code) → BUT-1495
  `sync-ingredients.ts` splits aliases on `;` only; rows using commas sync as one
  comma-joined array element (seen live on `vegofärs`, `tartar-sauce`). Split on both.
- [ ] **NORMALIZATION defects blocking whole word classes** (S, code) → BUT-1496
  (a) no `-erna`/`-orna` definite-plural stripping ("morötterna" never matches),
  (b) `_generateLookupVariations` never trims → trailing-space misses ("halloumi ost"),
  (c) "och"-conjunction lines not split ("salt och peppar"). `ingredient_lookup_service.dart`.
- [ ] **DATA: add missing staples** (Sheet) → BUT-1497 — skorpmjöl, generic korv (+korvar), vaniljyoghurt,
  sour cream→gräddfil alias, glutenfritt mjöl, yoggi→yoghurt alias, kokos alias, bare fläsk.
- [ ] **Cleanup** (S) → BUT-1498 — retire dead `excludes_tags` CSV column or wire it; reconcile
  `shellfish`/`wheat` vocabulary drift between PROPERTIES.csv and `property_registry.dart`;
  log (or status-prioritize) silent doc-ID-order collision wins on duplicate names/aliases.

Drift check verdict: live Firestore matches the CSV (16 docs sampled, zero learned aliases
yet) — the Sheet→CSV→Firestore chain is trustworthy; last sync 2025-12-27.

## Deliberately NOT flagged

- Alias-learning 3-user threshold is the right anti-poisoning bar (add review/revert, don't raise it).
- Error-swallowing in telemetry paths is by design ("never block the user") — the ask is failure *metrics*, not throwing.
- Prompt A/B machinery being unused is fine pre-launch; it's measure-ready.
- Everything in `.claude/rules/accepted-deviations.md` was excluded from findings.
