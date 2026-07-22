# tasks/todo.md

## 2026-07-22 sprint (second pass) — Selection (Phase 1)

**Context:** the prior 2026-07-22 plan (archived below) already ran — its Tier-A batch (BUT-1509,
BUT-1510, BUT-1486, BUT-1644) shipped in `54fe8b9ec` ("salvage session-limited sprint w26hokodz").
Its Tier-B/Tier-A carry-forwards (BUT-1615, BUT-1642) did NOT land (session-limited run only
finished the Tier-A batch) — both re-verified live against current `main` this pass and carried
forward again below.

**Linear MCP:** connected (`list_issues`/`get_issue`/`save_issue` all responded normally).

**Backlog scanned:** Linear team Butlery, states Backlog/Todo/In Progress/Triage — 98 Backlog + 4
Todo, 0 In Progress, 0 Triage. `onboarding-reserved` label present on BUT-677/BUT-722 — excluded
entirely, not scored. Two Todo-state items are epic/blocked, not selectable: BUT-1323 (epic body,
score the children not the epic) and BUT-1613 (blocked by the still-incomplete BUT-1611 UI slice,
i.e. this sprint's own BUT-1615).

**Step-0 grep-of-main premise check (mandatory):** git status clean, `54fe8b9ec` confirmed on
`main`. Re-verified both carried-forward tickets directly against current code, not just the prior
plan's citation:
- BUT-1642 — `functions/scripts/run-ci-unit-tests.js:20` still `EXCLUDE_PREFIXES = ["test:rules",
  "test:integration:"]`, unchanged. Premise live.
- BUT-1615 — grepped for any presence-setting UI/setter (`setPresent`, `togglePresent`,
  `PresenceSelector`, `whosHome`) across `lib/viewmodels/menu`, `lib/widgets/menu`,
  `veckomeny_view.dart` — none found. The generator/VM only have *readers*
  (`presentMemberIdsFor`, `calendar_weekly_menu_widget.dart:369` reading it as a seed) — nothing
  writes it yet. Premise live; still a dead model with no way to populate it.

**No obsolete tickets this round** — none of the ~20 BUT- ids referenced in the last 7 days' git
log (`54fe8b9ec`, `584dceaa2`, `2c2e48f34`, etc.) appear in the current open Backlog/Todo dump;
the prior pass already closed BUT-1558.

**New candidates this round:** BUT-1646 and BUT-1645, both filed by the reviewers of the
just-shipped `54fe8b9ec` batch (BUT-1486's own "unify or file a follow-up" escape hatch, and a
testing-specialist gap on the metric this sprint just added). Both passed the mandate gate clean.

**This round pulled from the pipeline-audit backlog** (`docs/architecture/PIPELINE_IMPROVEMENT_ROADMAP.md`,
2026-07-01) instead of re-scoring the same parked items a sixth time: BUT-1471, BUT-1484, BUT-1485,
BUT-1488, BUT-1501, BUT-1476 — six small/medium, spec-backed (the roadmap doc *is* the mandate),
autonomous-labeled tickets that have sat untouched since 2026-07-02.

**Batching note:** BUT-1501 and BUT-1476 both touch `lib/services/import/url_import_strategy.dart`
— per the skill's disjoint-files rule they cannot be split across two parallel batches, so they are
combined into one batch (Batch I) instead of dropping either.

**Mandate gate — large items deliberately NOT selected (see `needsApproval` for full reasoning):**
five Tier-C-sized cross-cutting refactors (BUT-1508 78-file DI migration, BUT-1507 god-object
split, BUT-1504 legacy-consumer migration+deletion, BUT-1480 import-pipeline unification, BUT-1513
~120-test rewrite) are left for a dedicated pass rather than folded into this incremental batch
model, consistent with every prior pass. BUT-1482 (tag-schema config-invalidation) is safety-
adjacent-schema + open-ended design work, not a clean incremental fix. BUT-1641 (optional
leaf-disposal guards) is explicitly framed by its own ticket as a discretionary call with zero
product impact — parked for Malin rather than auto-built either way.

**Lane convention honored:** `deferred`-lane tickets (~48) left untouched in Backlog, not
individually re-litigated. `need-malin`-lane standing tickets (BUT-1229, BUT-1445, BUT-863,
BUT-1368, BUT-1179, BUT-1502, BUT-1557, BUT-880, BUT-1599, BUT-1361, BUT-1636) restated briefly
below, unchanged from prior passes.

**File-overlap check (mandatory before batching):** all 9 batches below touch disjoint file sets
(menu, CI script, 2 CF event files, 1 test file, CRF tooling, import cache, import adapter, e2e
test, import-pipeline pair) — verified via `python tools/stakeholder_router.py --json <paths>` per
batch (also the source of each batch's tier/panel below — all came back `single`, no
`high_stakes_hits`, so `requiresPlanMode` is `false` across the board per the risk-gate formula
(none is Urgent/High priority or security-labeled)).

### Batch A — presence-selector-ui (build-review: UI/interaction call, 5th carry-forward)
- [ ] **[Tier B] BUT-1615** — Per-day presence selector UI + generator wiring + preview gate (the
  real remainder of BUT-1611 — its own ticket shipped only the dead data-model field). Fifth pass
  carrying this forward; session-limited runs keep finishing only the Tier-A batch before this one
  starts. disposition: build-review. requiresPlanMode: false (router: single, panel: Product
  Manager only). signoffReason: where the per-day "who's present" selector sits in the calendar UI
  and how it's toggled — a visual/interaction call for Malin before it ships.
  Files: `lib/models/menu/weekly_menu_plan.dart` (read/extend save path),
  `lib/viewmodels/menu/menu_generator.dart`, `lib/viewmodels/menu/weekly_menu_plan_viewmodel.dart`,
  `lib/services/menu/weekly_menu_plan_service.dart`, `lib/widgets/menu/calendar_weekly_menu_widget.dart`,
  `lib/views/veckomeny_view.dart`, a `/preview --directions` artifact under `tasks/previews/`, plus
  tests.
  Acceptance:
  1. A per-day "who's present" selector exists in the weekly-menu calendar UI and persists to
     `WeeklyMenuPlan.presenceByDay` via a plan-VM save method.
  2. `menu_generator.dart`'s day-generation path reads that day's own presence selection and sets
     `presentMemberIds` per generated day (wiring only).
  3. A `/preview --directions` marker exists for the new selector before implementation.
  4. **Don't** widen this into allergen-filtering/generation-pool scoping — matches the accepted
     display/portions-safe boundary in `accepted-deviations.md` (BUT-1625's boundary). Existing
     weekly-menu allergen-filtering tests stay unchanged.

### Batch B — ci-alias-wiring (single, config-only, 2nd carry-forward)
- [ ] **[Tier A] BUT-1642** — `run-ci-unit-tests.js`'s `EXCLUDE_PREFIXES` skips the whole
  `test:integration:` prefix, incidentally also skipping `test:integration:analyze-corrections-alias`
  even though that suite needs no emulator. Confirmed still live at Step-0 this pass too.
  disposition: build. requiresPlanMode: false (router: single, panel: Vendor/Procurement).
  Files: `functions/scripts/run-ci-unit-tests.js`.
  Acceptance:
  1. `test:integration:analyze-corrections-alias` actually runs in the CI unit-test job (verified
     via a pushed commit's `gh run list`/logs, not just local reasoning).
  2. Emulator-dependent `test:integration:` suites remain excluded.
  3. **Don't** touch `firestore.rules` or unrelated CI workflow files — naming/filter fix only.

### Batch C — tier-vocab-followup (single, backend)
- [ ] **[Tier A] BUT-1646** — Fold tier-vocabulary copy #3 (`log-parse-event.ts`'s hardcoded
  `VALID_TIERS`) into the shared `parse-tier-vocabulary.ts` module BUT-1486 just created — its own
  filed follow-up. disposition: build. requiresPlanMode: false (router: single, panel: Database
  Administrator/Data-layer Engineer, Vendor/Procurement).
  Files: `functions/src/events/log-parse-event.ts`, `functions/src/shared/parse-tier-vocabulary.ts`
  (read), plus a CF test.
  Acceptance:
  1. Either `log-parse-event.ts`'s `VALID_TIERS` is derived from the shared `DART_TIER_NAMES`
     module with a drift-tripwire test, OR a documented decision states the two vocabularies
     legitimately differ and the ticket closes on that basis.
  2. If unified: a test proves the two tier lists stay equal (fails on future drift).
  3. **Don't** change which tiers are currently accepted by either path — vocabulary
     consolidation only, not a behavior change.

### Batch D — correction-drop-metric-test (single, test-only)
- [ ] **[Tier A] BUT-1645** — Assert `parse_correction_upload_dropped` actually fires at all 4
  silent-drop sites (`unknown_tier`, `payload_error`, `no_salt`, `salt_error`) — the metric BUT-1486
  just shipped has no test proving it fires. disposition: build. requiresPlanMode: false (router:
  single, panel: Software Architect, Product Manager).
  Files: `test/unit/services/parsing/parse_correction_uploader_test.dart` (test-only).
  Acceptance:
  1. A test proves each of the 4 drop sites emits `parse_correction_upload_dropped` with the
     correct `reason` param.
  2. **Don't** modify production code in `parse_correction_uploader.dart` — test-only diff.

### Batch E — crf-retrain-tooling (single, backend/parsing)
- [ ] **[Tier A] BUT-1471** — `retrain_with_corrections.sh` stops at writing weights with no
  golden-set regression gate, no Storage upload/version bump, no hash-registry print; also point
  `export-corrections.ts` at `parse_corrections_v2` for the PII scrub. Spec-backed
  (`docs/architecture/PIPELINE_IMPROVEMENT_ROADMAP.md`, 2026-07-01 audit). disposition: build.
  requiresPlanMode: false (router: single, panel: Data/ML Engineer, Vendor/Procurement).
  Files: `scripts/crf/retrain_with_corrections.sh`, `functions/src/admin/export-corrections.ts`,
  `test/golden/crf_ingredients.json` (read).
  Acceptance:
  1. The retrain script refuses to proceed when eval regresses vs `test/golden/crf_ingredients.json`.
  2. The script uploads to the `RemoteWeightLoader` Storage path with a version bump and prints
     the SHA-256 for the hash registry.
  3. `export-corrections.ts` reads from `parse_corrections_v2` (gaining the server-side PII scrub)
     instead of the current aggregate path.

### Batch F — extraction-meta-tier (single, import/parsing)
- [ ] **[Tier A] BUT-1484** — `ExtractionMeta` hardcodes `tier: 0, confidence: 0.8` even though the
  real values are computed and discarded. Spec-backed (pipeline audit). disposition: build.
  requiresPlanMode: false (router: single, panel: Data/Integrations Engineer, FinOps,
  Monetization Lead).
  Files: `lib/services/import/cache/cache_entry.dart`, the call site that constructs
  `ExtractionMeta`, plus a test.
  Acceptance:
  1. `ExtractionMeta.tier`/`.confidence` reflect the actually-computed values, not the hardcoded
     `tier: 0, confidence: 0.8`.
  2. A test proves a non-default tier/confidence value round-trips through the cache entry.
  3. **Don't** change cache key/expiry logic — data-fidelity fix only.

### Batch G — import-result-adapter (single, import)
- [ ] **[Tier A] BUT-1485** — `ImportResultV2→legacy` adapter logic is copied in 3 pipelines;
  unify into one shared adapter. Spec-backed (pipeline audit). disposition: build.
  requiresPlanMode: false (router: single, panel: Data/Integrations Engineer, FinOps,
  Monetization Lead).
  Files: `lib/services/import/models/import_result_v2.dart`,
  `lib/services/import/llm/llm_enhancement_service.dart`,
  `lib/services/import/photo_llm_vision.dart`,
  `lib/services/import/pipelines/instagram_pipeline.dart`,
  `lib/services/import/pipelines/tiktok_pipeline.dart`,
  `lib/services/import/youtube/youtube_import_strategy.dart`, plus a test.
  Acceptance:
  1. A single shared `ImportResultV2→legacy` adapter exists and all 3 previously-duplicated call
     sites use it.
  2. Existing instagram/tiktok/youtube import pipeline tests still pass unchanged.
  3. **Don't** leave a 4th copy — the duplicated logic is deleted at the original 3 sites, not
     just added alongside.

### Batch H — usp-e2e-test (single, import/tagging, test-only)
- [ ] **[Tier A] BUT-1488** — The pipeline's largest untested seam: no test drives a real import →
  real tagging → real (fixture-seeded) ingredient lookup and asserts allergen TriStates. The
  current "Import → Tagging Integration" test fakes the lookup and drives a dead orchestrator.
  Spec-backed (pipeline audit). disposition: build. requiresPlanMode: false (router: single,
  panel: Data/Integrations Engineer, Data/ML Engineer, FinOps, Monetization Lead).
  Files: new/updated integration test under `test/integration/`, fixture data, reading real
  `ImportManager.autoImport`, `TaggingService`/`TaggingPipelineRunner`, fixture-seeded
  `IngredientLookupService` (no production edits).
  Acceptance:
  1. A new integration test drives real `ImportManager.autoImport` → real
     `TaggingService`/`TaggingPipelineRunner` → a fixture-seeded (not faked) `IngredientLookupService`
     for 3-4 representative raw Swedish recipes, asserting specific allergen TriState outcomes.
  2. The existing fake-lookup/dead-orchestrator test is replaced, not left as a parallel duplicate.
  3. **Don't** weaken any allergen TriState assertion to make the test pass — a failing assertion
     means fixing the pipeline or the fixture data, not loosening the check.

### Batch I — import-pipeline-hardening (single, import/parsing — 2 tickets, combined for file overlap)
- [ ] **[Tier A] BUT-1501** — CRF/NER ingredient cascade + correction capture run ONLY for URL
  imports; photo/paste/assisted flows get regex parsing and feed no active learning
  (workflow-map-traced gap, spec-backed). disposition: build. requiresPlanMode: false.
- [ ] **[Tier A] BUT-1476** — Up to 3 full LLM calls can fire per failed URL import (two nested
  tier waterfalls both escalating to Gemini); pass `useLlm:false` from `_tryEnhancedParser` to keep
  exactly one escalation point (cost-minimization). disposition: build. requiresPlanMode: false.
  Router (run once for the combined file set): single, panel: Data/Integrations Engineer, Data/ML
  Engineer, FinOps, Monetization Lead, Performance Engineer.
  Files: `lib/services/import/text_import_strategy.dart`, `lib/services/import/url_import_strategy.dart`
  (shared by both tickets — why they're one batch), `lib/services/import/fallbacks/llm_extraction_fallback.dart`,
  `lib/services/parsing/tiers/llm_tier.dart`, `lib/viewmodels/assisted_import_viewmodel.dart`,
  `lib/services/import/heuristics/ingredient_line_detector.dart`, `docs/onboarding/workflow-map.html`
  (re-trace the 3 DEAD-marked flows this fixes), plus tests.
  Acceptance:
  1. (1501) A photo-imported recipe's ingredient lines carry structured quantity/unit/name via the
     same CRF/NER cascade URL imports use (unit test on `TextImportStrategy`).
  2. (1501) Completing the assisted-import wizard writes a PII-scrubbed parse-correction record
     (test).
  3. (1476) `_tryEnhancedParser` passes `useLlm:false` so at most one full LLM escalation fires per
     failed import (test/assertion proves call count).
  4. **Don't** reconcile the Firestore `site_configs` vs Dart `SiteParserRegistry` duplication in
     this pass if it balloons scope — file a follow-up ticket instead of expanding scope
     mid-sprint; only re-trace workflow-map flows actually fixed here.

## Needs Malin (speculative / contestable / ops-blocked / wrong-repo / Tier-C-sized — not built)

**Tier-C-sized refactors deliberately left for a dedicated pass** (not an incremental batch):
- **BUT-1508** — Convert ServiceLocator-inside-services to constructor injection (78 files).
  Recommend: worth doing, needs its own dedicated session, not a mixed batch.
- **BUT-1507** — Refactor `user_service`/`unified_friends_service` god-objects into facades.
  Recommend: dedicated pass.
- **BUT-1504** — Migrate remaining legacy `menu_service`/`social_recipe_service` consumers +
  delete. Recommend: dedicated pass with careful consumer-sequencing (deletion risk).
- **BUT-1480** — Unify the two URL import pipelines. Recommend: dedicated pass, foundational
  risk to the core import pipeline.
- **BUT-1513** — Rewrite ~120 bulk-skipped BUT-369 integration tests on the emulator lane.
  Recommend: worth doing, schedule as its own multi-session initiative.

**Fresh judgment calls this round:**
- **BUT-1482** — Config-change invalidation for tags. Schema change to `TagResult` (safety-adjacent
  tagging data) plus an open-ended "design a server-side batch retag path" with no concrete
  acceptance target. Recommend: reframe with a concrete trigger (e.g. "next `kTagGeneratorVersion`
  bump") before building; not urgent today.
- **BUT-1490** — Grow the gated corpora. No measurable "done" stated. Recommend: reframe with a
  concrete corpus-size/coverage target, then it becomes a clean build.
- **BUT-1240** — NER golden corpus real-signal lane via `integration_test` on a device-capable
  runner. Needs infra the loop can't provision. Recommend: revisit once a device-capable runner
  exists (ties to BUT-451 staging infra).
- **BUT-1641** — Leaf-level disposal guards for 5 state-holders (optional). Ticket itself frames
  this as a discretionary call with zero product impact (parent guards already cover the crash
  path per BUT-1628). Recommend: close as "parent guards sufficient" unless you want the extra
  seatbelt — low value either way.

**Standing (repeated from prior passes, unchanged):**
- **BUT-1499** — Collaborative weekly menu wire-up. Ticket's own acceptance #1 is "decide: wire it
  up or park it" — your call.
- **BUT-1472** — `parse_corrections_v2`/`llm_response_samples` consumer-or-turn-off investment
  decision. Recommend: turn off per cost-minimization unless you want the corrections-mining tool.
- **BUT-1625** — Safe present-aware menu generation. Accepted-deviations boundary (children's
  allergen-safety surface) — leave parked unless specifically wanted; BUT-1615 above is the
  prerequisite anyway.
- **BUT-1616** — Reconcile `raw-safe`/`processed` property-vocabulary drift. Safety-adjacent
  tagging vocabulary, not mine to guess which side is canonical.
- **BUT-1617** — Triage 35 stale specialist findings from the 2026-07-14 sprint. Recommend: close
  as stale unless the findings survive somewhere you know of.
- **BUT-1601** — Inline ingredient quantities in cooking-mode steps. Real NLP complexity, no
  mockup, no `autonomous` label.
- **BUT-1452** — 15 large-file facade-extraction candidates. Files are already accepted with
  rationale; benefit unclear without a per-file look.
- **BUT-1555** — Deploy safety hardening. Better sequenced with BUT-451 (staging project) than
  built blind pre-launch.
- **BUT-1176** — Optional custom_lint/AST upgrade. Self-describes conditional; condition unmet.
- **BUT-1636** — Supersede stale accepted-deviations entry (cook_snaps/activity_events age-gating).
  Decision-record edit, genuinely your call.
- **BUT-950** — Investigate grace period before account deletion. Speculative product question.
- **BUT-945** — Easier rejoin after unfriend/leave group. Speculative feature, no spec.
- **BUT-1229, BUT-1445, BUT-863, BUT-1368, BUT-1179, BUT-1502, BUT-1557, BUT-880, BUT-1599,
  BUT-1361** — standing `need-malin`-lane tickets, unchanged from prior passes.
- **BUT-1619, BUT-1620, BUT-1621, BUT-1630, BUT-1634** — delivery-engine (sprint machinery)
  hardening tickets targeting `C:/claude-plugins`, a different repo shipped via
  `node tools/fanout-update.mjs`, not buildable from a Butlery sprint. Recommend: batch into one
  claude-plugins-specific session.

## Deviation log
(none yet — Phase 1 only, no implementation this pass)

---

## Earlier sprints (archived)

Everything below this line is prior-pass history, kept for continuity. Summarized rather than
reproduced in full detail (the full text lives in this file's git history as of commit
`54fe8b9ec` and earlier):

- **2026-07-22 first pass** — selected BUT-1615/1642/1644/1509/1510/1486. BUT-1644/1509/1510/1486
  shipped in `54fe8b9ec`. BUT-1615/1642 did not land (session-limited) — re-carried into the
  second pass above. BUT-1558 closed obsolete (all 5 production items reverified present on
  `main`, shipped in `b7e66bf1a`; tests backfilled via BUT-1635/1639).
- **2026-07-20 second pass** — shipped BUT-1637/1565/1566/1638/1639/1640/1643 in `2c2e48f34`
  (crashed-sprint salvage). BUT-1615/1642 carried forward (did not land that pass either).
- **2026-07-20 first pass** — shipped BUT-1459/1628/1635/1611(-adjacent)/1618/1609/1519/1623 across
  `2a3fcaef4`/`ca4ba8b70`/`20e68a79a`/`f0b046b8e`/`3b0364475`/`919569e1a`. BUT-1629 landed In
  Review (build-review, minor-searchability opt-in UI). BUT-1632/1615/1553 hit a Linear
  archive/reopen tooling artifact — resolved in the 2026-07-22 first pass (1632/1553 confirmed
  Done; 1615 confirmed still open and re-carried).
- **2026-07-18 third pass** — shipped BUT-1458/1631/1633/1564 in `b7e66bf1a`. BUT-1632/1615/1459/
  1629/1553 re-carried (didn't make that salvage). BUT-1558 closed obsolete (production code
  shipped, test residue → BUT-1635).
- **2026-07-18 second pass / first pass / pass-2** — the original crashed/blocked sprint piles;
  fully salvaged across `2c3d2aa31`, `b8da3fb12`, `9eb7155b1`, and the seven-ticket first-pass
  batch (BUT-1518+1624, 1474, 1607, 1454, 1475+1489, 1473, 1469). The systemic ship-phase bug
  (commit-gate false-block) was fixed in `68a400d9f`.
- **2026-07-16 parallel-sprint pile** — shipped BUT-1611 (rebuilt), 1618, 1609, 1519, 1623.
- **2026-07-19 held-batch salvage** — shipped BUT-1458/1631/1633/1564/1558(prod) as `b7e66bf1a`
  after a legitimate stale-review-marker halt.
- **2026-07-21 crashed-sprint salvage (wxe0xnfys)** — shipped BUT-1637/1565/1566/1638/1639/1640/
  1643 as `2c2e48f34` after a usage-limit death mid-ship; diff backed up and re-reviewed against
  live code by 5 opus specialists before shipping. Filed BUT-1644 as a follow-up.
