# tasks/todo.md — Sprint 2026-07-23 (Selection)

Six tickets selected (`build`/`build-review`), clustered into 4 disjoint-file batches.
Full mandate-gate reasoning (including everything screened OUT) is in the sprint report.

## Batch A — import (Agent A)

### [Tier A] BUT-1656 — buildRecipe() hardcodes ImportSource.url (Bug) — disposition: build
Files: `lib/viewmodels/assisted_import_viewmodel.dart` (buildRecipe(), ~L294-327),
`test/unit/import/assisted_import_viewmodel_test.dart`
Router: single (Software Architect, Product Manager) — requiresPlanMode: false
- [ ] `buildRecipe()` derives `ImportSource` from the actual origin strategy (photo/voice/text/url)
  instead of hardcoding `ImportSource.url`
- [ ] The null-`sourceUrl` test case asserts `isNot(ImportSource.url)`, not just `domain == null`
  (currently pins the bug)
- [ ] Full `assisted_import_viewmodel_test.dart` suite passes, no other case regressed
- [ ] No change to allergen/tagging verdict logic — training-data attribution fix only

### [Tier B] BUT-1480 — Unify the two URL import pipelines — disposition: build-review
Files: `lib/core/bootstrap/handlers/incoming_share_handler.dart`,
`lib/viewmodels/url_import_viewmodel.dart`, `lib/views/import_via_url_view.dart`,
`lib/services/import/import_manager.dart` (routing only — do not touch
`lib/viewmodels/assisted_import_viewmodel.dart`, that's Batch A's other ticket)
Router: single (Data/Integrations Engineer, FinOps, Monetization Lead) — requiresPlanMode: false
Signoff reason: YouTube shares changing from a body scrape to transcript extraction, and both
paths gaining cache/rate-limit/telemetry, are user-visible import-quality/behavior changes —
Malin should see a before/after on a couple of real URLs before this closes Done.
- [ ] OS share-sheet path routes into `ImportManager.autoImport` (not the legacy direct
  `WebScraper` path)
- [ ] `/importViaUrl` route routes into `ImportManager.autoImport`
- [ ] YouTube URLs shared via either path get transcript extraction (via the existing
  `youtube_transcript_service.dart`), not a body scrape
- [ ] Both paths inherit `autoImport`'s existing cache/rate-limit/telemetry — no bespoke
  re-implementation; assisted-import (photo/voice/text) paths are untouched

## Batch B — tagging (Agent B)

### [Tier C] BUT-1482 — Config-change invalidation for tags (scoped) — disposition: build
Files: `lib/models/tagging/tag_result.dart`, `lib/services/tagging/tag_generator.dart`
Router: **full-panel** (Data/ML Engineer-tagging, FinOps, Legal, DPO, PM, Security Architect,
Software Architect) — high-stakes hit on `tag_result.dart` — **requiresPlanMode: true**
Risky-ticket plan: this touches the tagging model that ultimately backs allergen verdicts
(accepted-deviations.md "Tagging/Safety" section applies). Scope is deliberately narrowed to a
pure metadata addition — no verdict-logic change — to keep this out of full-panel-required
territory in practice; the router still flags it because the file itself is high-stakes.
- [ ] `TagResult` gains a config-revision field, stamped at generation time from the current
  `tag_configs` state (additive — alongside `generatorVersion`, not replacing it)
- [ ] Hard constraint: NO change to FREE/CONTAINS/UNKNOWN verdict computation anywhere in this
  diff — metadata/versioning only
- [ ] The "design a server-side batch retag path" half of the original ticket is explicitly NOT
  built here — file it as its own follow-up (avoids an unbounded, unreviewed retag-triggering
  behavior change riding on this ticket)
- [ ] A test pins that a `tag_configs` revision bump is reflected in newly-generated
  `TagResult`s' revision field

## Batch C — backend-ops (Agent C)

### [Tier A] BUT-1653 — Confirm corrections-alias rules test executes in CI — disposition: build
Files: none expected (verification task); `.github/workflows/firestore-rules.yml` only if the
suite is found NOT firing
Router: single (DevOps/SRE, Release Manager, QA, Release/App-Store Compliance) — requiresPlanMode: false
- [ ] `gh run list` / the `firestore-rules` workflow's emulator-job logs for the latest push show
  `analyze-corrections-alias.test.ts` actually executing (not skipped/filtered)
- [ ] If it is NOT firing: the path-filter or `test:rules:all` wiring is fixed so it does
- [ ] Evidence (log excerpt / run URL) is quoted in the close-out comment before BUT-1653 closes

### [Tier A] BUT-1654 — Prove clean_sprint_scratch.sh dry-run + wire into /janitor — disposition: build
Files: `tools/clean_sprint_scratch.sh` (proof only, no logic change expected),
`.claude/shared-plugin.json` (roleOrg wiring — e.g. `healthChecks` entry)
Router: single (Claude AI-Harness Owner/Agent-Ops Lead, Release Manager) — requiresPlanMode: false
- [ ] `--dry-run` run against real scratch (existing patch dirs / tagged stashes) with at least
  one untagged human stash present shows the human stash listed as NOT removed
- [ ] That dry-run output is captured as evidence (attached/quoted in the close-out), not just
  asserted
- [ ] The script gets a mechanical firing path into `/janitor` (config wiring, not a manual habit)
- [ ] No change to the STASH_MARKER/PATCH_SUBDIR matching logic itself — proof + wiring only

## Batch D — backend-analytics (Agent D)

### [Tier A] BUT-1472 — Give llm_response_samples a consumer (rescoped) — disposition: build
Files: new `functions/src/admin/export-llm-samples.ts` (mirrors `export-corrections.ts`),
maybe a test
Router: single (Vendor/Procurement Manager) — requiresPlanMode: false
Step-0 discovery: the original ticket's premise is stale for HALF its scope —
`parse_corrections_v2` already has a live consumer (`export-corrections.ts`, confirmed on
main) — so this ticket is rescoped to `llm_response_samples` only.
- [ ] A new admin export script (mirroring `export-corrections.ts`'s pattern) reads
  `llm_response_samples` and writes a usable JSON/CSV export
- [ ] `parse_corrections_v2` / `export-corrections.ts` are left untouched — already solved,
  out of scope here
- [ ] No change to the `captureLlmSample` write path or its enable flag — this ticket only adds
  a reader
- [ ] Script only reads already-scrubbed fields (`scrubbedInput`/`scrubbedOutput`) — no raw PII
  fields introduced

## Needs you (Tier D / needs-approval — not built this sprint)
See the sprint report for the full reasoning per ticket. Highlights:
- BUT-950 (account-deletion grace period) — ticket itself says "needs legal/GDPR review" — her/legal call.
- BUT-1499 (wire up dormant collaborative-menu UI) — ticket itself frames it as "decide: wire or park" — product call.
- BUT-1625 (safe present-aware menu generation) — spec is ready but the ticket says "IF product wants" this — whether to build it at all is undecided.
- BUT-1652 / BUT-1655 (shard the global LLM-limit counter) — both explicitly premature (current traffic is ~4x under the hotspot threshold); revisit when the stated trigger fires.
- BUT-1620 / BUT-1621 / BUT-1634 / BUT-1651 (delivery-engine / workflow-guards hardening) — implementation lives in `C:/claude-plugins`, a different repo; not a fit for a Butlery-repo sprint batch.
- BUT-1508 / BUT-1513 / BUT-1507 / BUT-1514 — real tech debt but too large (78 files / ~120 tests / god-object refactor / 125-file blast radius) for one autonomous batch; need their own scoped plan first.

## Deviation log
- discovery BUT-1472: `parse_corrections_v2` already has a working consumer (`export-corrections.ts`) — ticket rescoped to `llm_response_samples` only, kept conservative (no touch to the already-solved half).
- discovery BUT-1613: already shipped and Done in Linear (completed 2026-07-23) — the unchecked slice-2 checklist below (archived) was stale bookkeeping, not real remaining work.

---

# Archived — Sprint 2026-07-23 prior session (BUT-1613 slice 2, now Done)

## BUT-1613 — "Who's home" sets the serving size (approved plan)

Full approved plan: `~/.claude/plans/tender-tumbling-dahl.md` (ExitPlanMode-approved 2026-07-23,
after a 4-role stakeholder panel — Architect, PM, tagging-integrity, archaeologist — all
approve-with-conditions, allergen independence confirmed). This file mirrors it for the plan gate.

**Slice 1 — shopping list: SHIPPED** (`5ce639e33`, on main). Presence-driven quantity scaling in
`MenuShoppingListGenerator` + `MenuShoppingAggregator` (per-placement `(recipe, factor)` pairs),
`WeeklyMenuPlan.servingsFor`, övrigt exemption, portions>0 guard, single staples pass, `scaledMeals`
snackbar cue. 38 tests incl. the repeated-recipe dedup-removal regression pin.

**Slice 2 — cooking mode: SHIPPED** (`506157f56`, on main; BUT-1613 completed in Linear
2026-07-23). Opening a planned meal pre-scales cooking mode to who's home.

## What this means in plain language
Opening a meal you've planned for the week starts cooking mode already set to how many people are
home that day (instead of always the whole household). Both halves — the shopping list and the
cooking-mode screen — are live on main now.
