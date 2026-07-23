# tasks/todo.md — Sprint 2026-07-23 (Selection, session 2)

Three tickets selected (`build`/`build-review`), clustered into 3 disjoint-file batches.
The backlog is genuinely thin on unambiguous build-worthy work right now — most open
tickets are `deferred`/`need-malin` lane (already-decided parking) or large tech-debt that
needs its own scoped plan first. N=3, not padded to fill a target range. Full mandate-gate
reasoning (including everything screened OUT) is in the sprint report.

## Batch A — backend-testing (Agent A)

### [Tier A] BUT-1659 — Test gap: export-llm-samples.ts has no test (BUT-1472 follow-up) — disposition: build
Files: `functions/src/__tests__/export-llm-samples.test.ts` (new)
Router: single (Security Architect, QA/Test Engineer, Vendor/Procurement Manager) — requiresPlanMode: false
- [ ] New test seeds `llm_response_samples` docs (emulator/fake) and asserts the exported field
  set contains ONLY scrubbed fields (no raw PII field introduced)
- [ ] Test asserts the deterministic sort order of the export
- [ ] Mirrors the existing `export-audit-logs.test.ts` pattern (same fixture/assert style) — no
  bespoke test harness
- [ ] No change to `export-llm-samples.ts` production logic — test-only diff

## Batch B — tagging-testing (Agent B)

### [Tier A] BUT-1658 — Test gap: tag configRevision stamping is untested (BUT-1482 AC#4) — disposition: build
Files: `test/unit/services/tagging/tag_generator_test.dart` (extend existing test, ~L3470)
Router: single (Software Architect, Product Manager) — requiresPlanMode: false
- [ ] Extends the existing late-config-arrival test (~L3470) — no new fixture/file added
- [ ] Test builds the generator on a null/boot config, a remote config with a real
  `combinedVersion` arrives, `generate()` is called, and asserts `TagResult.configRevision`
  equals the live `combinedVersion`
- [ ] Test proves the run-start-value freeze (revision stays pinned to the run-start config
  across awaited phases, not a later mid-run swap)
- [ ] No production code changes — `tag_generator.dart` / `tag_result.dart` untouched, test-only diff

## Batch C — deploy-ops (Agent C)

### [Tier B] BUT-1555 — Deploy safety: smoke gate, rollback path, wider health-alert coverage — disposition: build-review
Files: `.github/workflows/deploy-firebase.yml`, `.github/workflows/main-health-alert.yml`
Router: single (DevOps/SRE, Release Manager, QA, Release/App-Store Compliance) — requiresPlanMode: false
Signoff reason: changes to the production deploy/rollback pipeline and alerting coverage —
verify the smoke-gate and rollback step behave correctly (dry run or careful review) before
trusting them on a real deploy; a mis-scripted rollback could brick a release.
- [ ] `deploy-firebase.yml` gains a post-deploy health probe (functions/storage) that fails the
  job on an unhealthy deploy
- [ ] `deploy-firebase.yml` captures the pre-deploy revision/version so a rollback step can
  reference it (a real rollback step, or — if full auto-rollback isn't safely scriptable — a
  clearly documented manual command using the captured revision)
- [ ] `main-health-alert.yml` widens coverage to include the deploy/rules/e2e/dep-audit/golden-llm
  workflows named in the ticket, alongside the existing 3
- [ ] No change to deploy targets/secrets/permissions — workflow-config additions only

## Needs you (Tier D / needs-approval — not built this sprint)
See the sprint report for full reasoning. Highlights:
- BUT-1323 ("Who's eating" per-day presence + per-member preferences, DIFFERENTIATOR epic) —
  stale as written: parts (b) per-day presence toggle and (d) portion adjustment already
  shipped via BUT-1611/BUT-1613; part (c) generation-scoping is a decided-no per
  accepted-deviations (BUT-1625, allergen-safety hold). Only part (a) — per-member disliked
  ingredients + new UI — remains real, unbuilt scope. Recommend: re-scope the ticket down to
  just (a) and have Malin confirm the UI direction before it's built; don't build it as
  currently written.
- BUT-1480 (unify the two URL import pipelines) — already carried to Todo + labeled
  `need-malin` by this morning's sprint after discovering unification would regress shipped
  features (multi-URL batch, index-page expansion, editable-paste); no new action, her call.
- BUT-1616 (property-vocabulary drift: raw-safe/processed) — genuine domain call (what these
  safety-adjacent properties should mean), not a code-obvious fix; touches the tagging
  vocabulary source of truth.
- BUT-1504 (migrate remaining legacy menu_service/social_recipe_service consumers) — clear
  mandate (continues the approved unified-services direction) but 15-20 files, explicitly
  "plan-mode change" per its own body — too large for one autonomous batch, same category as
  the already-parked BUT-1508/1513/1507/1514.
- BUT-1490 (grow the gated corpora) — real value (parsing golden set is thin, site-parser
  fixtures are hand-invented) but a sprawling, judgment-heavy data-curation initiative (which
  hard cases to mine, which sites to snapshot) rather than a single gradeable diff — needs
  its own scoped plan/session.
- BUT-1617 (triage 35 non-blocking specialist findings from 2026-07-14) — a meta-triage task
  with no diff-gradeable acceptance criteria; better run as its own `/linear`-style triage
  pass, and the source review artifacts may no longer exist (scan reports get swept).
- BUT-1641 (leaf-level disposal guards, optional) — ticket itself frames it as an optional
  judgment call; the crash risk it would guard against is already closed at the parent-VM
  level (BUT-1628). Recommend closing as "parent guards sufficient" rather than building new
  infrastructure for no active bug.
- BUT-1176 (optional custom_lint/AST upgrade) / BUT-1240 (NER golden corpus device-lane) —
  both explicitly say "pick up only if X" / "deferred, needs new CI infra" in their own body;
  no new trigger since last read.
- BUT-1441 (backfill zoneless feedback.createdAt) — ticket's own text: "not pure autonomous
  work... safe to defer," pre-launch feedback collection is near-empty.
- BUT-1655 / BUT-1652 (shard the global LLM-limit counter) — still premature (traffic ~4x
  under the hotspot threshold), unchanged since this morning's sprint.
- BUT-1625, BUT-950, BUT-1499, BUT-1601 — product/legal calls, her decision, unchanged
  reasoning from this morning's sprint / consistent with prior triage.
- BUT-1634 / BUT-1651 / BUT-1621 / BUT-1620 — delivery-engine/workflow-guards hardening,
  implementation lives in `C:/claude-plugins`, not a fit for a Butlery-repo sprint batch.
- BUT-1507 / BUT-1513 / BUT-1508 / BUT-1514 — real tech debt, still too large for one
  autonomous batch (78 files / ~120 tests / god-object refactor / dual-DI-container unify
  touching 125 test files); need their own scoped plan first. Unchanged from this morning.

## Obsolete (already done, close citing the resolving commit)
- BUT-1657 ("Record: assisted-import Back→Forward edit-preservation fix") — the ticket's own
  body says the change already shipped in the same commit as BUT-1656 (`0ca51843f`) and asks
  only for attribution/closure, not new code. Close citing `0ca51843f`.

## Deviation log
- **BUT-1659 AC#4 deviated** ("No change to export-llm-samples.ts production logic — test-only
  diff" was NOT met). The export script had no testable seam (importing it auto-runs main() +
  admin init + file writes, fatal to a test), unlike export-audit-logs.ts which already exposes
  `runExportAuditLogsWithDb`. Conservatively extracted a minimal, additive, behavior-preserving
  seam (`runExportLlmSamplesWithDb` / `projectSample` / `sortSamples`), guarded the auto-run with
  `require.main === module`, moved admin init + db handle inside main(); no change to what the
  script exports/writes when run for real. Reviewed by cloud-functions-specialist (marker names
  the file). AC#4 grading → **deviated — testability refactor, mirrors export-audit-logs, reviewed
  by cloud-functions-specialist.** Override recorded rather than silent; refactor accepted, no new
  ticket needed.
- **BUT-1659**: also added a `test:export-llm-samples` script to functions/package.json (mirrors
  `test:export-audit-logs`) so scripts/run-all-tests.js auto-discovers the new suite in CI rather
  than leaving it dormant.
- **BUT-1659 / BUT-1658 staging**: ship step said `git add -A`; found `.claude/settings.local.json`
  permission-churn (not this work) that every batch would touch → staged only the reviewed files by
  explicit pathspec to avoid cross-batch apply conflicts.
- **BUT-1555**: plan said implement deploy-safety additions to both workflow files; found both files
  already carry the smoke gate (BUT-1423), pre-deploy capture + auto-rollback (BUT-1424), and the
  widened health-alert list (BUT-1425) → wrote no code, classified obsolete, cited resolving work.

---

# Archived — Sprint 2026-07-23 prior session (import/tagging/backend-ops/analytics batches, now shipped)

Six tickets selected (`build`/`build-review`), clustered into 4 disjoint-file batches.
Landed as commit `0ca51843f` (BUT-1656, BUT-1482, BUT-1472, BUT-1653, BUT-1654) — BUT-1480
was NOT implemented (carried to Todo, `need-malin` label, flagged for founder re-scope).
Follow-ups filed: BUT-1657, BUT-1658, BUT-1659 (all triaged in this session's Selection above).

## What this means in plain language
The earlier sprint today shipped four real fixes: recipes imported by photo/voice/text now
correctly remember how they came in (used to always say "from a web link" even when they
weren't), tag results now remember which safety-rule version made them (so a rules update can
tell old tags apart from new ones), a new admin tool can pull out the AI's saved sample
responses for review, and two pieces of testing/cleanup automation got verified and wired in.
This second pass today looked at what's left in the backlog and found it thin — most
remaining tickets are either already somebody's future decision to make, or too large to
safely build in one sitting. It picked up three small, safe follow-ups: two tests that close
gaps in this morning's work, and a deploy-safety improvement (with a flag that it should get
a careful look before being trusted on a live release, since it touches how the app gets
published).

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
