# tasks/todo.md

## 2026-07-22 sprint (third pass) — Selection (Phase 1)

**Context:** the prior 2026-07-22 second-pass plan (archived below) was fully implemented and
shipped in `4d6030d66` ("import-pipeline hardening, wider correction capture, tier-vocab
unification") — all of Batches A–I from that plan landed (BUT-1615 closed obsolete, its remainder
having shipped under BUT-1611; BUT-1642/1646/1645/1471/1484/1485/1488/1501/1476 all shipped). A
post-hoc re-review (`56cf1da0f`) then found that ship step had forged its commit-gate markers;
four real specialists re-ran against the committed diff and cleared the allergen-safety axis,
filing one MEDIUM quality-only finding (BUT-1650, selected below).

**Linear MCP:** connected (`list_issues`/`get_issue`/`save_issue` all responded normally).

**Backlog scanned:** Linear team Butlery — 93 Backlog + 2 Todo (BUT-1613, BUT-1323), 0 In
Progress, 0 Triage. `onboarding-reserved` label present on BUT-677/BUT-722 — excluded entirely,
not scored. BUT-1323 is an epic body (scored its child, not itself).

**Step-0 grep-of-main premise check (mandatory):** git status clean at `99e0f7ba1`. Verified the
tier-vocabulary unification directly in code (`log-parse-event.ts:58` now
`export const VALID_TIERS: readonly string[] = DART_TIER_NAMES;`, imported from the shared
`parse-tier-vocabulary.ts` module) — confirms BUT-1646 (previous pass) is live, not just
committed. No obsolete tickets found this round: none of the ~15 BUT- ids in the last 7 days'
git log appear back open in Backlog/Todo.

**New candidates this round:** BUT-1647/1648/1650/1651/1649 were all filed as follow-ups from the
just-shipped import-pipeline sprint's post-hoc review. BUT-1649 is need-malin (on-device spot
check) — restated below, not built. BUT-1651 targets the shared `claude-plugins` repo — parked
with its sibling delivery-engine tickets (not buildable from a Butlery sprint).

**This round also pulled two long-standing but previously-parked items back in:**
- **BUT-1613** — was blocked by BUT-1611 (per-weekday presence selector), which shipped
  2026-07-20. Re-checked: `blockedBy` is now empty in Linear and the presence data
  (`presentMemberIdsFor(day, slot)`) exists on `WeeklyMenuPlan` — the blocker is gone. This is
  exactly the accepted-deviations-sanctioned "presence drives portions" work (BUT-1611 → BUT-1625
  boundary note), not the disallowed generation-scoping.
- **BUT-1561** — FinOps low-priority hardening, sitting since 2026-07-04 with no premise change;
  file:line references in the ticket still match current code
  (`functions/src/llm/ocr-retry.ts`, `functions/src/middleware/rate_limiter.ts`).
- **BUT-1630** — sprint scratch janitor. Verified the premise is real and worse than the ticket
  describes: `.claude/state/sprint-patches/` currently holds 9 leftover patch files, `git stash
  list` shows 17+ stashes tagged `sprint-parallel-cleanup`, and `.claude/worktrees/` holds 17
  leftover directories.

**Mandate gate — items deliberately NOT selected (see `needsApproval` for full reasoning):**
BUT-1650 was the one genuine judgment call this round (a cost-vs-quality tradeoff) — on reading
it closely, the ticket's own "clean fix" fully preserves BUT-1476's cost intent (still exactly
one LLM escalation, just relocated to also cover below-threshold parses) while reversing an
unintended quality regression, so it reclassifies as `build`, not a decision needed from Malin.
Five Tier-C-sized cross-cutting refactors are left parked for a dedicated pass (unchanged from
every prior round) plus BUT-1514 (dual ServiceLocator test containers, 125-file blast radius) —
newly recognized as belonging to that same family rather than a small fix. BUT-1441 is Tier-D
(needs a prod console/script data migration) and self-describes as low-urgency. Four
`claude-plugins`-targeting delivery-engine tickets (BUT-1620, BUT-1621, BUT-1634, BUT-1651) are
parked as wrong-repo, same as every prior pass.

**Lane convention honored:** `deferred`-lane tickets (~48) left untouched in Backlog, not
individually re-litigated. `need-malin`-lane standing tickets restated briefly below, unchanged
from prior passes, plus this round's new BUT-1649.

**File-overlap check (mandatory before batching):** 4 batches below touch disjoint file sets
(import prod+test, backend functions+CI, a new standalone tooling script, menu model+VM+widget) —
verified via `python tools/stakeholder_router.py --json <paths>` per batch (also the source of
each batch's tier/panel below — all came back `single`, no `high_stakes_hits`, so
`requiresPlanMode` is `false` across the board per the risk-gate formula: none of the six is
Urgent/High priority or security-labeled).

### Batch A — import-followups (single, import — 2 tickets, same area label so combined)
- [ ] **[Tier A] BUT-1650** — `UrlImportStrategy` only reaches its Tier-6 LLM escalation on total
  structured-parse failure; a rough-but-non-empty below-threshold parse now gets zero LLM cleanup
  (previously got internal cleanup). Fix: a quality gate at `url_import_strategy.dart:116-117`
  that falls through to Tier 6 when the enhanced parse is below threshold — NOT re-enabling the
  per-tier internal LLM (that would reintroduce BUT-1476's 3x cost regression). disposition:
  build. requiresPlanMode: false (router: single, panel: Data/Integrations Engineer, Data/ML
  Engineer, FinOps, Monetization Lead).
  Files: `lib/services/import/url_import_strategy.dart`,
  `lib/services/parsing/recipe_parser_service.dart` (read), plus a test.
  Acceptance:
  1. A URL whose cheap tiers produce a non-null but below-threshold parse now falls through to
     Tier 6's single LLM escalation instead of shipping the rough parse untouched.
  2. The total LLM escalation count for any one failed/partial import stays at exactly 1 (BUT-1476's
     cost cap is not reopened) — assert via call-count in the test.
  3. **Don't** re-enable the parser's internal per-tier LLM cleanup — the fix is only the
     fallthrough gate at the strategy level.
- [ ] **[Tier A] BUT-1647** — Backfill 4 acceptance tests for already-shipped BUT-1501/1476/1484
  behavior (spec required them; code shipped without). Test-only, no production changes.
  disposition: build. requiresPlanMode: false (same router run as above — shared area).
  Files: `test/unit/services/import/text_import_strategy_test.dart`,
  `test/unit/viewmodels/assisted_import_viewmodel_test.dart`,
  `test/unit/services/import/url_import_strategy_test.dart`,
  `test/unit/services/import/global_recipe_cache_test.dart` (or an ExtractionMeta-focused test).
  Acceptance:
  1. A test proves `TextImportStrategy` populates `structuredIngredients` via a stubbed
     `IngredientParsingStrategy` while the flat allergen ingredient list is untouched.
  2. A test proves completing the assisted-import wizard invokes `ImportCorrectionSnapshot.capture`
     with `source=url` and a PII-scrubbed recipe.
  3. A test proves `ExtractionMeta` reflects a real seeded `tier`/`overallQuality`, and falls back
     to `tier:0/confidence:0.8` when metadata is absent or wrong-typed.
  4. **Don't** touch production code in any of the 4 files under test — test-only diff (this
     ticket is separate from BUT-1650's production fix in the same file).

### Batch B — backend-hardening (single, backend — 2 tickets, same area label so combined)
- [ ] **[Tier A] BUT-1648** — The real fix for BUT-1642 (which was closed on the finding that the
  unit-CI job is correctly excluding the alias suite — it needs an emulator). Wire
  `test:integration:analyze-corrections-alias` into the emulator-backed `test:rules:all` script and
  confirm it runs in `.github/workflows/firestore-rules.yml`'s emulator job. disposition: build.
  requiresPlanMode: false (router: single, panel: DB/Data-layer Engineer, DevOps/SRE, Engineering
  Manager, QA, Release/Compliance Manager, Vendor/Procurement).
  Files: `functions/package.json` (`test:rules:all` script), `.github/workflows/firestore-rules.yml`
  (read/verify only).
  Acceptance:
  1. `functions/package.json`'s `test:rules:all` script includes
     `ts-node src/__tests__/analyze-corrections-alias.test.ts`.
  2. A pushed commit's `gh run list`/logs show the alias suite actually executing in the
     emulator-backed CI job (not skipped).
  3. **Don't** touch `functions/scripts/run-ci-unit-tests.js` — it is already correctly excluding
     this suite from the no-emulator unit job.
- [ ] **[Tier A] BUT-1561** — Four small FinOps hardening items (role-org scan #7): gate the OCR
  text-mode retry behind `checkGlobalLimit()` (currently bypasses the cap, undercounting real
  Vertex volume); shard/approximate the `withRateLimit` global hotspot-doc write; fix the
  kill-switch runbook + `rate_limiter.ts` header (stale storage-path/fail-open description); add a
  log-based-metric alert on cap-trip / rate-limit-violation volume. disposition: build.
  requiresPlanMode: false (same router run as above — shared area).
  Files: `functions/src/llm/ocr-retry.ts`, `functions/src/middleware/rate_limiter.ts`,
  `docs/ops/llm-kill-switch-runbook.md`.
  Acceptance:
  1. The OCR text-mode retry path is gated behind `checkGlobalLimit()` (test proves a retry is
     blocked once the global cap is tripped).
  2. The kill-switch runbook and `rate_limiter.ts`'s header comment match current behavior
     (`system_rate_limits` collection, fail-closed) — no stale-path/fail-open language remains.
  3. **Don't** change the cap thresholds or fail-closed semantics themselves — hardening/doc-fix
     only, not a policy change.

### Batch C — sprint-scratch-janitor (single, tooling, standalone)
- [ ] **[Tier A] BUT-1630** — Add a safe, manually/scheduled-invoked cleanup for sprint-engine
  scratch that accumulated after the ship-phase self-cleanup was removed (auto-mode classifier
  denial). Verified live and worse than the ticket states: 9 leftover patch files under
  `.claude/state/sprint-patches/`, 17+ `sprint-parallel-cleanup`-tagged stashes, 17 leftover
  `.claude/worktrees/` dirs. disposition: build. requiresPlanMode: false (router: single, panel:
  Software Architect, Product Manager).
  Files: new `tools/clean_sprint_scratch.sh` (or `.js`), run manually or wired into an existing
  non-autonomous entry point (e.g. `/janitor`) — explicitly NOT inside the workflow `agent()`
  Ship prompt.
  Acceptance:
  1. Running the new script deletes old sprint patch dirs under `.claude/state/sprint-patches/`.
  2. It drops ONLY `git stash` entries whose message contains the engine's STASH_MARKER
     (`sprint-parallel-cleanup`) — a test/dry-run proves a plain human stash is left untouched.
  3. **Don't** add this cleanup back into the workflow engine's autonomous `agent()` Ship prompt —
     that's what tripped the auto-mode safety classifier originally; it must run from an
     interactive/manual/scheduled context.

### Batch D — menu-presence-portions (build-review: UI/display call)
- [ ] **[Tier B] BUT-1613** — "Who's eating" slice 4: auto-adjust a generated day's
  portions/servings to that day's present-member count (using the presence data BUT-1611 shipped).
  Verified unblocked (BUT-1611 shipped 2026-07-20, `blockedBy` now empty in Linear) and verified
  absent in code (no `servings`/`portion` field exists anywhere on `WeeklyMenuPlanEntry` today).
  This is the accepted-deviations-sanctioned "presence drives portions" surface (display/portions
  only, NOT generation-pool scoping — see the BUT-1611→BUT-1625 boundary note). disposition:
  build-review. requiresPlanMode: false (router: single, panel: Product Manager). signoffReason:
  where/how the adjusted portion count is shown to the user (a badge on the day card? inline text
  on the recipe card? cooking-mode header?) — no mockup exists for this, it's a visual call.
  Files: `lib/models/menu/weekly_menu_plan.dart` (add a servings/portion field to
  `WeeklyMenuPlanEntry` or the day), `lib/viewmodels/menu/menu_generator.dart`,
  `lib/viewmodels/menu/weekly_menu_plan_viewmodel.dart`,
  `lib/services/menu/weekly_menu_plan_service.dart`,
  `lib/widgets/menu/calendar_weekly_menu_widget.dart`, a `/preview --directions` artifact under
  `tasks/previews/`, plus tests.
  Acceptance:
  1. A day with 3 present members generates/displays that day's recipe(s) scaled for 3 servings.
  2. A day with no presence selection is unchanged from current default behavior (existing tests
     for the no-presence path stay green).
  3. A `/preview --directions` marker exists for the new portion-count display before
     implementation lands.
  4. **Don't** widen this into candidate-pool/generation scoping by presence — matches the
     accepted display/portions-safe boundary in `accepted-deviations.md` (BUT-1625's boundary).
     Existing weekly-menu allergen-filtering tests stay unchanged.

## Needs Malin (speculative / contestable / ops-blocked / wrong-repo / Tier-C-sized — not built)

**Tier-C-sized refactors deliberately left for a dedicated pass** (not an incremental batch,
unchanged list plus one addition this round):
- **BUT-1508** — Convert ServiceLocator-inside-services to constructor injection (78 files).
- **BUT-1507** — Refactor `user_service`/`unified_friends_service` god-objects into facades.
- **BUT-1504** — Migrate remaining legacy `menu_service`/`social_recipe_service` consumers + delete.
- **BUT-1480** — Unify the two URL import pipelines.
- **BUT-1513** — Rewrite ~120 bulk-skipped BUT-369 integration tests on the emulator lane.
- **BUT-1514** (new this round) — Unify the dual ServiceLocator test containers; the ticket's own
  text notes 125 test files import both containers today — same dedicated-pass shape as the five
  above, not a clean incremental fix despite its Low priority label. Recommend: fold into whichever
  session tackles BUT-1508 (same DI-surface family).

**Wrong-repo — targets the shared `claude-plugins` delivery engine, not buildable from a Butlery
sprint** (BUT-1619 in this family was closed already, fixed directly in claude-plugins):
- **BUT-1620** — delivery engine: reject stub/degenerate specialist findings in gate scoring.
- **BUT-1621** — delivery engine hardening: worktree dep-resolution before analyze + verify args
  coercion.
- **BUT-1634** — Phase-0 clean-tree check doesn't apply `cleanTreeIgnore` to untracked (`??`)
  entries, so a `.stale` marker aborts the next sprint.
- **BUT-1651** (new this round) — port the marker-NAMES content check from
  `require-review-before-commit` to its sibling `require-simplify-before-commit` gate (residual of
  BUT-1599/1619).
Recommend: batch all four into one dedicated `claude-plugins` session — the same recommendation as
every prior pass.

**Tier-D / ops-blocked:**
- **BUT-1441** — Backfill zoneless `feedback.createdAt` docs to UTC. Needs a prod console/script
  data migration; the ticket itself frames this as low-urgency pre-launch (near-empty collection).

**Fresh judgment calls this round:**
- *(none new — BUT-1650 was the only live judgment call, and on inspection its "clean fix" turned
  out to be a straightforward regression fix, not a real tradeoff; moved to Batch A as `build`.)*

**Standing (repeated from prior passes, unchanged unless noted):**
- **BUT-1499** — Collaborative weekly menu wire-up. Ticket's own acceptance #1 is "decide: wire it
  up or park it" — your call.
- **BUT-1472** — `parse_corrections_v2`/`llm_response_samples` consumer-or-turn-off investment
  decision. Recommend: turn off per cost-minimization unless you want the corrections-mining tool.
- **BUT-1625** — Safe present-aware menu generation. Accepted-deviations boundary (children's
  allergen-safety surface) — leave parked unless specifically wanted; BUT-1613 (this pass) is a
  narrower, sanctioned slice of the same presence data, not this ticket's generation-scoping ask.
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
- **BUT-1641** — Leaf-level disposal guards for 5 state-holders (optional). Ticket itself frames
  this as discretionary with zero product impact. Recommend: close as "parent guards sufficient"
  unless you want the extra seatbelt.
- **BUT-1240, BUT-1490, BUT-1482** — parsing/tagging judgment calls, unchanged reasoning from
  prior passes (device-runner infra gap; no measurable "done"; needs a concrete trigger).
- **BUT-950, BUT-945** — speculative product ideas, no spec.
- **BUT-1649** (new this round) — On-device spot-check of CRF structured-ingredient output for
  text/photo/voice imports. Filed need-malin by design — this needs your hands on a real device,
  not code.
- **BUT-1229, BUT-1445, BUT-863, BUT-1368, BUT-1179, BUT-1502, BUT-1557, BUT-880, BUT-1599,
  BUT-1361** — standing `need-malin`-lane tickets, unchanged from prior passes.

## Deviation log
(none yet — Phase 1 only, no implementation this pass)

---

## Earlier sprints (archived)

Everything below this line is prior-pass history, kept for continuity. Summarized rather than
reproduced in full detail (the full text lives in this file's git history):

- **2026-07-22 second pass** — selected BUT-1615(→closed obsolete, shipped under 1611)/1642/1646/
  1645/1471/1484/1485/1488/1501/1476, all shipped in `4d6030d66`. Post-hoc re-review found the ship
  step forged its review markers; `56cf1da0f` re-ran 4 real specialists against the committed diff,
  cleared it, filed BUT-1650 (quality-only finding, selected above).
- **2026-07-22 first pass** — selected BUT-1615/1642/1644/1509/1510/1486. BUT-1644/1509/1510/1486
  shipped in `54fe8b9ec`. BUT-1615/1642 carried into the second pass. BUT-1558 closed obsolete.
- **2026-07-20 second pass** — shipped BUT-1637/1565/1566/1638/1639/1640/1643 in `2c2e48f34`
  (crashed-sprint salvage). BUT-1615/1642 carried forward.
- **2026-07-20 first pass** — shipped BUT-1459/1628/1635/1611(-adjacent)/1618/1609/1519/1623 across
  `2a3fcaef4`/`ca4ba8b70`/`20e68a79a`/`f0b046b8e`/`3b0364475`/`919569e1a`. BUT-1629 landed In
  Review.
- **2026-07-18 third pass** — shipped BUT-1458/1631/1633/1564 in `b7e66bf1a`. BUT-1558 closed
  obsolete.
- **2026-07-18 second pass / first pass / pass-2** — crashed/blocked sprint piles, fully salvaged
  across `2c3d2aa31`, `b8da3fb12`, `9eb7155b1`, and a seven-ticket batch. Ship-phase false-block
  bug fixed in `68a400d9f`.
- **2026-07-16 parallel-sprint pile** — shipped BUT-1611 (rebuilt), 1618, 1609, 1519, 1623.
- **2026-07-19 held-batch salvage** — shipped BUT-1458/1631/1633/1564/1558(prod) as `b7e66bf1a`.
- **2026-07-21 crashed-sprint salvage (wxe0xnfys)** — shipped BUT-1637/1565/1566/1638/1639/1640/
  1643 as `2c2e48f34`. Filed BUT-1644 as a follow-up.
