# tasks/todo.md

## 2026-07-20 sprint (second pass) — Selection (Phase 1)

**Backlog scanned:** Linear team Butlery, states Backlog/Todo/In Progress/Triage (107 Backlog +
2 Todo, 0 In Progress, 0 Triage). `onboarding-reserved` label: BUT-677, BUT-722 present —
excluded entirely, not scored.

**Context — the prior "2026-07-20 sprint" pass below already ran.** Its commit `2a3fcaef4`
("minor-searchability opt-in writer + disposed-guard sweep + perf-cleanup tests") shipped 4 of
its 7 selected tickets clean: BUT-1459, BUT-1628, BUT-1635 all closed **Done**; BUT-1629 (the
minor-searchability opt-in toggle) is **In Review** awaiting Malin's copy/placement sign-off
(build-review, as planned). Its Phase-3 follow-ups are already filed and visible in this
round's backlog: BUT-1637–1643. The remaining three selected tickets (BUT-1632, BUT-1615,
BUT-1553) do **not** appear in this round's live Backlog/Todo/Triage scan — Linear shows them
**archived** despite a `status` of Todo/Backlog (a Canceled→reopened bounce in their state
history around 18:06–18:11 today). That doesn't match any documented ship outcome for them
(no commit references them), so this is very likely a mid-flight artifact of concurrent
tooling rather than a deliberate close. **Not resurrected here** — archived issues are outside
this round's live-backlog scope by definition, and touching another pass's in-flight ticket
lifecycle without knowing what produced the bounce risks fighting a parallel process. Flagged
under Needs Malin below as a data-hygiene check, not re-selected.

**Step-0 grep-of-main premise check:** git status is clean; `2a3fcaef4` is confirmed on `main`
via `git show --stat`. `docs/onboarding/workflow-map.stale` exists (mandatory re-trace per
CLAUDE.md — the exact scope BUT-1643 already carries).

**Lane convention honored:** `deferred`-lane tickets (~85, epics/launch-gated/nice-to-haves)
left untouched in Backlog. `need-malin`-lane tickets stay parked; live-relevance ones surfaced
under Needs Malin below (mostly unchanged from the prior pass — not re-litigated).

**New candidates this round (all filed by the prior pass's own Phase-3 follow-up rule):**
BUT-1637–1643 (7 tickets, all follow-ups to the batch that shipped in `2a3fcaef4`). Also
re-considered two previously-deprioritized-but-valid `autonomous`/`tech-debt` tickets from the
"Not selected" pool (BUT-1566, BUT-1565) to round out the batch — both re-verified clean at
Step-0 (files still match, no overlap with anything else selected this round).

**File-overlap check (mandatory before batching):** BUT-1637 (Flutter client) and BUT-1638 (CF
test-only) both trace back to the same BUT-1629 feature but touch disjoint files
(`lib/services/user_service.dart` + `lib/services/social/profile_searchability_service.dart` +
`lib/viewmodels/user_profile_viewmodel.dart` vs. `functions/src/__tests__/set-profile-searchability.test.ts`
only) — batched together as one cohesive area, not split, since neither touches the other's
files. No other candidate this round shares a file with any other. Router
(`tools/stakeholder_router.py`) run for real on every batch's touched paths — tiers below are
its actual output.

### Batch A — minor-searchability-hardening (single: security label on BUT-1637)
- [ ] **[Tier A] BUT-1637** — Fix 4 real defects the review caught in the just-shipped minor
  "sökbarhet" (searchability) opt-in client path: swallowed error feedback, an unconditional
  local-state sync on re-assert (UI can show ON while server holds OFF), no in-flight guard on
  the toggle (rate-limiter risk), and a cross-device stale-revert where an unrelated profile
  save on one device can silently re-grant discoverability a minor turned off on another device
  (the data-safety-relevant one). disposition: build. requiresPlanMode: **true** (router:
  single, panel: QA/Test, Security Architect, Vendor/Procurement — priority High=2 triggers the
  `single + priority ≤ 2` clause; also carries the `Bug`+`security` labels).
  Files: `lib/services/user_service.dart`, `lib/services/social/profile_searchability_service.dart`,
  `lib/viewmodels/user_profile_viewmodel.dart`, plus new Dart tests.
  Acceptance:
  1. A failed opt-in call surfaces a user-visible error (`viewModel.hasError` test on the
     failure path) instead of silently snapping the switch back.
  2. Local UI state only flips to "searchable: true" when the re-assert call actually succeeds
     (gated, not unconditional) — test proves a failed re-assert leaves state unchanged.
  3. `setSearchableOptIn` has an in-flight guard preventing a rapid double-toggle from firing
     the Cloud Function's rate limiter twice.
  4. A cross-device regression test proves: minor opts out on device A, then an unrelated
     profile save (e.g. avatar edit) on device B never re-grants `isSearchable:true` — the
     re-assert reads the persisted/authoritative value, not a possibly-stale in-memory copy.
- [ ] **[Tier A] BUT-1638** — Cover 4 untested branches of the `setProfileSearchability` Cloud
  Function's `onCall` wrapper (only the internal `WithDeps` function had tests). disposition:
  build. requiresPlanMode: false (router: single, panel: QA/Test, Security Architect,
  Vendor/Procurement — priority Medium, no security label on this ticket itself).
  Files: `functions/src/__tests__/set-profile-searchability.test.ts` only (test-only).
  Acceptance:
  1. An unauthenticated call is rejected (test).
  2. A non-boolean `searchable` argument returns `invalid-argument` (test) — guards against a
     string `"true"` silently merging into `public_profiles`.
  3. The rate-limit-exhausted path is rejected (test).
  4. The idempotent-write case asserts `writes.length` (not just end-state convergence) so it
     can actually distinguish "wrote once" from "wrote twice".

### Batch B — perf-cache-test-backfill (single, no production files)
- [ ] **[Tier A] BUT-1639** — Add the one BUT-1635 acceptance criterion that didn't land: a
  regression test proving repeated rebuilds of an already-loaded image record exactly one cache
  HIT, not N. disposition: build. requiresPlanMode: false (router: single, panel: Performance
  Engineer; priority Medium, no security label).
  Files: `test/unit/services/performance/optimized_image_loader_test.dart` (new) or
  `intelligent_cache_manager_test.dart`; a minimal `@visibleForTesting` seam on
  `OptimizedImageLoader` only if genuinely required for the HIT path to be observable.
  Acceptance:
  1. A test asserts exactly one cache HIT across N rebuilds of a loaded image, OR — if the
     seam is judged not worth adding pre-launch — a dated `accepted-deviations.md` entry
     explains why, per the ticket's own fallback.
  2. **Don't** change `OptimizedImageLoader`'s production cache-hit behavior — test-only (a
     testability seam is fine; a behavior change is not).

### Batch C — viewmodel-dispose-test-backfill (single, test-only)
- [ ] **[Tier A] BUT-1640** — Backfill the two-quadrant disposed-guard regression tests for the
  2 of 11 viewmodels that landed the guard without one in the prior pass's sweep
  (`add_members_to_group_viewmodel.dart`, `recipe_detail_viewmodel.dart`). disposition: build.
  requiresPlanMode: false (router: single, panel: Software Architect, Product Manager; priority
  Low).
  Files: `test/unit/viewmodels/add_members_to_group_viewmodel_test.dart`,
  `test/unit/viewmodels/recipe_detail_viewmodel_test.dart` (test-only, no production changes —
  the guards already shipped).
  Acceptance:
  1. `add_members_to_group_viewmodel.dart`'s disposed-guard has a
     delegate-disposed-returns-normally + `notified == 0` test.
  2. `recipe_detail_viewmodel.dart`'s disposed-guard has the same two-quadrant coverage
     (including a shared-service-error-survives case if applicable).
  3. **Don't** touch production code — this is a test-only backfill.

### Batch D — ci-alias-wiring (single, config-only)
- [ ] **[Tier A] BUT-1642** — `run-ci-unit-tests.js`'s `EXCLUDE_PREFIXES` skips the whole
  `test:integration:` prefix, which incidentally also skips `test:integration:analyze-corrections-alias`
  even though that suite needs no emulator. disposition: build. requiresPlanMode: false (router:
  single, panel: DevOps/SRE, Engineering Manager, QA/Test, Release Compliance; priority Low).
  Files: `functions/scripts/run-ci-unit-tests.js` (rename the alias or tighten the exclude
  match — implementer's call which is cleaner).
  Acceptance:
  1. `test:integration:analyze-corrections-alias` actually runs in the CI unit-test job
     (verified via a pushed commit's `gh run list`/logs, not just local reasoning).
  2. Emulator-dependent `test:integration:` suites remain excluded — the fix doesn't
     over-include and break CI by trying to run something that needs the emulator.

### Batch E — workflow-map-retrace (skip tier, mechanical, mandatory per CLAUDE.md)
- [ ] **[Tier A] BUT-1643** — Re-trace the workflow-map flows the stale marker names (privacy/
  profile-edit + searchability, and the storage-repository image path) — the mandatory
  maintenance CLAUDE.md's workflow-map-freshness rule requires whenever the marker exists.
  disposition: build. requiresPlanMode: false (router: skip — pure docs file).
  Files: `docs/onboarding/workflow-map.html` (`<script id="data">` JSON only),
  `docs/onboarding/workflow-map.stale` (deleted at the end).
  Acceptance:
  1. Only the 4 flagged-trigger flows are re-traced (`lib/services/user_service.dart`,
     `lib/viewmodels/user_profile_viewmodel.dart`,
     `lib/views/social/user_profile_edit/privacy_section.dart`,
     `lib/repositories/firebase/firebase_storage_repository.dart`) — not a full map rebuild.
  2. `python tools/check_workflow_map.py` passes.
  3. The stale marker file is deleted in the same commit.

### Batch F — widget-housekeeping (single, broad low-stakes panel)
- [ ] **[Tier A] BUT-1566** — Housekeeping micro-cleanups from 6 role-org scans: a dead
  `centerContent` branch + `Icons.clear`-sentinel empty-state suppression hack, a hardcoded
  Swedish a11y label, a tap-target audit-script regex gap, an unversioned review-prompt storage
  key, stale CLAUDE.md/docs references, and a mockup-reference color drift. disposition: build.
  requiresPlanMode: false (router: single, wide low-stakes panel — no high-stakes hit; priority
  Low, no security label).
  Files: `lib/widgets/state_widget.dart`, `lib/widgets/empty_states.dart`,
  `lib/widgets/styled_input.dart`, `tools/audit_unwrapped_tap_targets.dart`,
  `lib/services/in_app_review_service.dart`, `CLAUDE.md`,
  `docs/design/butlery-mockup-reference.md`, `docs/architecture/ROLE_RESPONSIBILITY_MAP.md`.
  Acceptance:
  1. The dead `centerContent` no-op branch in `state_widget.dart` is removed or made to
     actually do something — no orphan dead code left behind.
  2. Empty-state illustration suppression routes through `useIllustration` instead of the
     `Icons.clear` sentinel hack.
  3. The hardcoded Swedish "(obligatorisk)" label in `styled_input.dart` is localized (ARB key,
     both `en` and `sv`).
  4. **Don't** expand into unrelated widget redesign — this is a cleanup batch, not a visual
     change; existing widget tests stay green.

### Batch G — import-retry-consolidation (single, no security hit)
- [ ] **[Tier A] BUT-1565** — Consolidate 3 competing retry helpers onto the jittered
  rethrow-on-unknown `retry_policy.dart#withRetry`, and trim `ExtractionManager`'s full headless
  scrape retry from 3 attempts (~45s) down to 2 (or skip the retry after an already-handled 15s
  timeout). disposition: build. requiresPlanMode: false (router: single, panel: Data/
  Integrations Engineer, FinOps, Monetization — no high-stakes hit; priority Low).
  Files: `lib/utils/retry_policy.dart`, `lib/core/utils/retry_helper.dart`,
  `lib/services/upload/upload_retry_manager.dart`, `lib/services/extraction/extraction_manager.dart`.
  Acceptance:
  1. The three retry helpers are consolidated onto `retry_policy.dart#withRetry`'s
     jittered/rethrow-on-unknown behavior — callers migrated, no regression on
     known-retryable-error handling.
  2. `ExtractionManager`'s full-scrape retry count drops from 3 to 2, or skips the retry when
     the failure was already an explicit 15s timeout.
  3. **Don't** change retry behavior for import paths outside this scope — existing import
     tests stay green.

## Needs Malin (speculative / contestable / ops-blocked / wrong-repo / data-hygiene — not built)
- **Data hygiene: BUT-1632, BUT-1615, BUT-1553 archived-but-not-closed.** These three were
  selected+scoped by the prior "2026-07-20 sprint" pass but never shipped. They're absent from
  this round's live Backlog/Todo/Triage Linear scan (archived), yet their raw `status` field
  reads Todo/Backlog with a Canceled→reopened bounce in their history around 18:06–18:11 today —
  no commit references any of the three. This doesn't match a normal ship outcome and looks like
  a mid-flight artifact of concurrent tooling rather than a deliberate close. Recommend: check
  Linear directly for these three IDs — if they're sitting in an odd archived-but-open limbo,
  either unarchive them for a future pass or confirm they were meant to be cancelled.
- **BUT-1636** — Supersede the stale `accepted-deviations.md` entry saying cook_snaps/
  activity_events aren't age-gated (they ARE, since BUT-1418). Decision-record edit, genuinely
  Malin's call per the doc's own contract. Recommend: quick confirm-and-edit, low effort.
- **BUT-1616** — Reconcile `raw-safe`/`processed` property-vocabulary drift. Tagging vocabulary
  is safety-adjacent, not mine to guess which side is canonical. Recommend: a 2-minute decision,
  then a trivial follow-up build.
- **BUT-1617** — Triage 35 non-blocking specialist findings from the 2026-07-14 sprint; that
  sprint's scratch review artifacts are very likely gone. Recommend: close as stale unless the
  findings survive somewhere you know of.
- **BUT-1601** — Inline ingredient quantities in cooking-mode steps. No `autonomous` label,
  tagged `idea`; real NLP complexity, no mockup. Recommend: worth doing eventually, needs a
  product/UX pass first.
- **BUT-1499** — Collaborative weekly menu fully coded but never wired to a live view. The
  ticket's own acceptance #1 is "decide: wire it up or park it" — genuinely your call.
- **BUT-1472** — `parse_corrections_v2`/`llm_response_samples` have no consumer. A real
  investment decision (build a consumer vs turn off the write path). Recommend the cheap
  "turn off" path per cost-minimization, unless you want the corrections-mining tool.
- **BUT-1176** — Optional custom_lint/AST upgrade. Self-describes "pick up only if custom_lint
  is being added for other reasons" — condition unmet. Recommend: drop or leave parked.
- **BUT-1555** — Deploy safety hardening (post-deploy smoke gate, rollback path, wider
  health-alert coverage). Real DevOps investment better done alongside BUT-451 (staging
  project) than built blind against prod pre-launch. Recommend: revisit before first real
  release, not urgent now.
- **BUT-1619 / BUT-1620 / BUT-1621 / BUT-1634 / BUT-1630 / BUT-1599** — Delivery-engine (sprint
  machinery) hardening tickets targeting `C:/claude-plugins/...`, a different git repo shipped
  via `node tools/fanout-update.mjs`, not buildable from a Butlery sprint. Recommend: batch into
  one claude-plugins-specific session.
- **BUT-880** — PITR restore drill against a non-prod project. Already `need-malin`-labeled;
  ops-blocked. Recommend: do it, but it's an ops task for you.
- **9 other standing `need-malin`-labeled tickets** (BUT-1557, BUT-1502, BUT-1179, BUT-1368,
  BUT-863, BUT-1445, BUT-1229, BUT-1608, BUT-1453) remain parked in Backlog — no new judgment
  added this round.

## Not selected this round — needs-approval judgment call (not built, not a Malin decision either)
- **BUT-1641** — "Leaf-level disposal guards for 5 state-holders (optional)." The ticket's own
  text says this is a judgement call, not a required fix — the crash risk is already handled at
  the parent-viewmodel level (per BUT-1628's deliberate design), and it names its own
  no-code resolution ("close as parent guards sufficient"). Speculative defense-in-depth with
  no concrete failure it currently prevents. Recommend: close as "parent guards sufficient"
  unless you specifically want the extra layer — not selected as build this round.

## Excluded from scoring entirely
- **BUT-677, BUT-722** — carry the `onboarding-reserved` label; per standing instruction, never
  scored, selected, transitioned, or implemented.
- **~85 `deferred`-labeled tickets** (epics, launch-gated, tablet/macOS, monetization ideas,
  etc.) — left untouched in Backlog per the lane convention; deliberately parked, not re-scored.

## Not selected this round (scored but below the cut / lower urgency)
Low-priority `autonomous` batches that remain valid, clean-build candidates for a future sprint:
BUT-1504, BUT-1501, BUT-1476, BUT-1488, BUT-1508 (78-file ServiceLocator→constructor-injection
refactor — large, Tier C candidate on its own), BUT-1507 (god-object refactor — large, Tier C
candidate on its own), BUT-1513 (rewrite ~120 bulk-skipped integration tests — large, Tier C
candidate on its own), BUT-1510, BUT-1509, BUT-1514, BUT-1480, BUT-1486, BUT-1485, BUT-1484,
BUT-1482, BUT-1471, BUT-1490, BUT-1240, BUT-945, BUT-1441, BUT-1452, BUT-1561 (its "cap-trip
alert" sub-item may need console access, scope down at Step-0).

## Deviation log
(none yet — Phase 1 only, no implementation this pass)

---

## 2026-07-20 sprint — Selection (Phase 1)

**Backlog scanned:** Linear team Butlery, states Backlog/Todo/In Progress/Triage (102 Backlog +
8 Todo, 0 In Progress, 0 Triage). `onboarding-reserved` label: BUT-677, BUT-722 present —
excluded entirely, not scored.

**Prior sprint now fully landed.** The 2026-07-19 held-batch salvage (documented at the bottom
of the prior pass, below) completed and pushed as commit `b7e66bf1a` — child-safety CF hardening
(BUT-1633), protein-tag accuracy (BUT-1458, BUT-1631), and perf cleanup (BUT-1564, and BUT-1558's
production code). `git log` (7 days) + a grep-of-main Step-0 check confirmed all four are truly
resolved on `main` and correctly absent from the open backlog.

**Step-0 grep-of-main premise check surfaced one obsolete ticket the git-log scan alone would
have missed the scope of:** BUT-1558 — its four production-code acceptance criteria are all in
`b7e66bf1a` (subscription-cancel, permission-check dedup + regression test, cache-HIT-once gate,
frame-timing fix). Two residual test gaps were explicitly deferred by that commit to an
already-filed follow-up, BUT-1635. Closed BUT-1558 (Canceled) citing the commit + BUT-1635; see
Obsolete below.

**Carry-forward tickets re-verified.** Five tickets were selected+scoped by the 2026-07-18 third
pass but never implemented (their batches — C/D/E/G — didn't make it into the salvage, which only
covered A/B/F/H). Re-ran Step-0 against current `main`: none of their target files were touched by
`b7e66bf1a` or any commit since, so all five premises still hold unchanged. Carried forward as-is
below (Batches A–D).

**New candidates this round:** BUT-1635 (BUT-1558's test-backfill follow-up, already filed) and
BUT-1628 (the BaseViewModel disposed-guard sweep BUT-1462 deferred) both passed the mandate gate
as clear follow-ups to already-approved work. BUT-1555 (deploy-safety CI/CD hardening) was
evaluated and parked — see Needs Malin.

**Lane convention honored:** `deferred`-lane tickets (~85, epics/launch-gated/nice-to-haves) left
untouched in Backlog. `need-malin`-lane tickets stay parked; the ones with live decision
relevance this round are surfaced under Needs Malin below.

**File-overlap merge (mandatory before batching):** BUT-1459 and BUT-1629 both edit
`lib/viewmodels/user_profile_viewmodel.dart` — merged into one batch (unchanged from the prior
pass's finding). New this round: BUT-1628's sweep would also touch
`lib/viewmodels/user_profile_viewmodel.dart` (it has `clearError`/`setError` overrides) — since
that file is already in the profile-viewmodel-cluster batch this same sprint, BUT-1628 explicitly
excludes it from this pass's scope (acceptance criterion #3) rather than creating a third batch
touching the same file. Router (`tools/stakeholder_router.py`) run for real on every batch's
touched paths — tiers below are its actual output, not estimated.

### Batch A — observability-remainder (full-panel: firestore.rules touch)
- [ ] **[Tier C] BUT-1632** — Observability remainder of BUT-1560 (which shipped only 1 of 4
  criteria — the dead RC-flag removal, commit `b8da3fb12`). Three independent, clean-build fixes.
  disposition: build. requiresPlanMode: **true** (router: full-panel — high_stakes_hits:
  `firestore.rules`; panel: Security Architect, Trust & Safety, Legal, Privacy/DPO, Product
  Manager, Software Architect, FinOps, Customer Support/Ops, DB Admin, Vendor/Procurement).
  Files: `functions/src/feedback/on-feedback-created.ts`, `firestore.rules`,
  `lib/services/monitoring/app_monitoring_service.dart`, plus tests
  (`functions/src/__tests__/*-rules.test.ts` for the rule, a forced-failure CF test, a
  `kIsWeb`-forwarding widget/unit test).
  Acceptance:
  1. Feedback-email send failure writes a `system_events` doc (test: forced failure asserts the
     doc).
  2. `feedback` create rule has `keys().hasOnly([...])` + per-field size caps (rules test: valid
     shape allowed, oversized/extra-field payload denied).
  3. `AppMonitoringService.recordError` forwards to `WebErrorReporter` specifically when `kIsWeb`
     is true (test proves it does NOT double-forward on non-web).
  4. **Don't** touch the already-shipped `audit_log_retention_days` removal (BUT-1560 criterion
     1) — that's done, this ticket is criteria 2-4 only.

### Batch B — presence-selector-ui (build-review: UI/interaction call)
- [ ] **[Tier B] BUT-1615** — Per-day presence selector UI + generator wiring + preview gate
  (the real remainder of BUT-1611 — its own ticket shipped only the dead data-model field).
  disposition: build-review. requiresPlanMode: false (router: single, panel: Product Manager
  only — no high-stakes hit — but flagged manually as substantial: new UI + generator wiring +
  preview gate).
  signoffReason: where the per-day "who's present" selector sits in the calendar UI and how it's
  toggled — a visual/interaction call for Malin before it ships.
  Files: `lib/viewmodels/menu/menu_generator.dart`, `lib/viewmodels/menu/weekly_menu_plan_viewmodel.dart`,
  `lib/services/menu/weekly_menu_plan_service.dart`, `lib/widgets/menu/calendar_weekly_menu_widget.dart`,
  `lib/views/veckomeny_view.dart`, a `/preview --directions` artifact under `tasks/previews/`,
  plus tests.
  Acceptance:
  1. A per-day "who's present" selector exists in the weekly-menu calendar UI and persists to
     `WeeklyMenuPlan.presenceByDay` via a plan-VM save method.
  2. `menu_generator.dart`'s day-generation path reads that day's own presence selection and sets
     `presentMemberIds` per generated day (wiring only).
  3. A `/preview --directions` marker exists for the new selector before implementation, per the
     repo's preview gate.
  4. **Don't** widen this into allergen-filtering/generation-pool scoping — matches the accepted
     display/portions-safe boundary in `accepted-deviations.md` (BUT-1625's boundary). Existing
     weekly-menu allergen-filtering tests stay unchanged.

### Batch C — profile-viewmodel-cluster (file overlap on user_profile_viewmodel.dart)
- [ ] **[Tier A] BUT-1459** — Hoist save-in-flight flag into `UserProfileViewModel.saveProfile()`
  (today only avatar-upload is tracked by `isLoading`; `household_size_view.dart` re-implements a
  local `_saving` bool band-aid). disposition: build. requiresPlanMode: false (router: single,
  panel: Software Architect, Product Manager — no security/high-priority hit).
  **Note:** the back-nav/unsaved-changes widget test this ticket originally also wanted is
  already covered by `test/widget/views/settings/household_size_view_test.dart` (confirmed at the
  ticket's own plan-stale note, 2026-07-18) — re-verify at Step-0 that it still passes; only the
  flag-hoist half remains live.
  Files: `lib/viewmodels/user_profile_viewmodel.dart`, `lib/views/settings/household_size_view.dart`,
  plus tests.
  Acceptance:
  1. `UserProfileViewModel.saveProfile()` exposes an in-flight `isSaving` flag.
  2. `household_size_view.dart`'s local `_saving` bool is replaced with the VM's flag (double-tap
     double-write guard behavior unchanged — test: two rapid taps produce one write).
  3. **Don't** re-add a back-nav/unsaved-changes widget test if Step-0 confirms one already exists
     and passes — this pass is the save-in-flight hoist only, not a redo of already-shipped work.
- [ ] **[Tier B] BUT-1629** — Minor searchable opt-in: a callable CF (`setProfileSearchability`,
  auth + App Check + rate-limited, admin-SDK write) is the ONLY path a minor can become
  discoverable now that BUT-1626 hard-denies the client write; pair it with a dedicated Flutter
  opt-in toggle (privacy section) that routes a minor's request through the CF instead of the
  ordinary profile save. disposition: build-review. requiresPlanMode: false (router: single,
  panel: Vendor/Procurement — no high-stakes hit on the CF-only path since it bypasses rules via
  admin SDK; flagged build-review regardless because it's the exact UI/copy/placement decision
  BUT-1626's own signoff note deferred).
  signoffReason: where the "sökbarhet" toggle sits in the privacy settings and its copy — same
  open decision BUT-1626 explicitly deferred to this ticket.
  Files: new `functions/src/social/set-profile-searchability.ts`, `lib/viewmodels/user_profile_viewmodel.dart`,
  a privacy-settings view (TBD exact file at Step-0), plus tests.
  Acceptance:
  1. The callable CF requires auth + App Check, is rate-limited, and idempotent-merge-sets
     `public_profiles/{uid}.isSearchable` via the admin SDK.
  2. A minor's opt-in flows through the CF, never the ordinary profile-save path (test: a
     minor's normal `saveProfile()` call never sets `isSearchable:true`, only the dedicated
     toggle's CF call does).
  3. A rules test proves the CF-written `isSearchable:true` survives while a client-written one
     for the same minor is still denied (regression guard on BUT-1626's hard-deny).
  4. Adults keep the existing client-write path unchanged.

### Batch D — ci-coverage-wiring (CI config only)
- [ ] **[Tier A] BUT-1553** — Wire three existing-but-ungated test suites into CI: ~52 Cloud
  Functions TS unit tests (currently run in no workflow), `acquisition-rules.test.ts` (currently
  fully ungated), and the CRF 85% F1 golden eval (production ingredient parser — runs nowhere).
  disposition: build. requiresPlanMode: false (router: single, panel: DevOps/SRE, Engineering
  Manager, QA/Test, Release/App-Store Compliance).
  Files: `.github/workflows/test.yml`, `.github/workflows/firestore-rules.yml`, `functions/package.json`
  (if a script needs adding), no `firestore.rules` content change (config/path wiring only).
  Acceptance:
  1. A CI run (`gh run list` or a pushed commit) shows the ~52 CF unit tests actually executing.
  2. `acquisition-rules.test.ts` runs as part of `test:rules:all` in the firestore-rules workflow.
  3. `test/evaluation` (the CRF golden eval) runs in the `test.yml` matrix and its 85% F1 floor is
     enforced (job fails below it).
  4. **Don't** edit `firestore.rules` content itself — this ticket only wires existing tests into
     CI triggers/paths.

### Batch E — perf-test-backfill (test-only, no production files)
- [ ] **[Tier A] BUT-1635** — Backfill the tests BUT-1558 shipped with zero of (all 4 of its
  production-code criteria are done in `b7e66bf1a`, but shipped untested). disposition: build.
  requiresPlanMode: **true** (router: single + priority High → the `single + priority ≤ 2` clause
  fires; panel: Data Analyst/BI, Performance Engineer, Trust & Safety).
  Files: `test/unit/repositories/firebase/firebase_storage_repository_test.dart`,
  `test/unit/services/performance/intelligent_cache_manager_test.dart`,
  `test/unit/services/performance/optimized_image_loader_test.dart` — production files touched
  only if a minimal testability seam is genuinely required (e.g. an injectable clock/subscription
  hook), never a behavior change.
  Acceptance:
  1. A test proves the upload-progress subscription is cancelled (no leak) when upload completes.
  2. A test proves `uploadImage`'s permission-denied case still rejects after the duplicate check
     was removed (security-adjacent regression guard — prioritise this one).
  3. A test proves multiple rebuilds of the same loaded image record exactly one cache HIT, not N.
  4. **Don't** change BUT-1558's shipped production behavior — this is a test-only backfill ticket.

### Batch F — viewmodel-dispose-guard-sweep (mechanical, contained to lib/viewmodels)
- [ ] **[Tier A] BUT-1628** — Sweep BaseViewModel subclasses for consistent disposed-guard /
  `clearError` overrides (the deferred sweep BUT-1462 documented but didn't attempt). disposition:
  build. requiresPlanMode: false (router: single, panel: Software Architect, Product Manager, no
  high-stakes hit; priority Low).
  Files: the 21 `lib/viewmodels/**` files (of 37 `BaseViewModel` subclasses) that override
  `clearError`/`setError`/`setLoading`/`clearState`, EXCLUDING `user_profile_viewmodel.dart`
  (file-overlap with Batch C, out of scope this pass) — `lib/viewmodels/base_viewmodel.dart` read
  as reference, not edited unless a real gap forces it.
  Acceptance:
  1. Every override of a base state-mutation method in the audited scope carries the
     `if (isDisposed) return;` guard (or a comment explaining why it must not).
  2. No production caller of `executeAsync` in the audited scope relies on it returning `null` on
     a disposed VM (grep-verified; any real gap found gets a focused test, not a blanket rewrite).
  3. `lib/viewmodels/user_profile_viewmodel.dart` is explicitly noted OUT OF SCOPE this pass
     (file-overlap with Batch C shipping the same sprint) — filed as a one-line follow-up note,
     not silently dropped.
  4. **Don't** manufacture a fix where none is needed — if the audit finds the scope already
     consistent, close citing the audit result, don't pad the diff.

## Obsolete (Step-0 grep-of-main this round — closed in Linear with resolving evidence)
- **BUT-1558** — CLOSED (Canceled). All 4 production-code acceptance criteria confirmed present
  in `b7e66bf1a` (subscription-cancel-in-finally, permission-check dedup + regression test,
  cache-HIT-once gate, frame-timing fabricated-`0.0` fix). Residual test gaps tracked by the
  already-filed BUT-1635 (selected above). Comment posted citing the commit + BUT-1635.

## Needs Malin (speculative / contestable / ops-blocked / wrong-repo — not built)
- **BUT-1555** — Deploy safety: post-deploy smoke gate, rollback path, health-alert workflow
  coverage (3/14 → more). Real DevOps investment (new CI steps that need to be exercised against
  a real deploy to trust, a rollback-target decision, and workflow-coverage tradeoffs) on a
  pre-launch app with no live users yet depending on prod uptime. Recommend: worth doing before
  the first real release, not urgent now — revisit alongside BUT-451 (staging project) rather
  than building blind against prod.
- **BUT-1636** — Supersede the stale `accepted-deviations.md` entry saying cook_snaps/
  activity_events aren't age-gated (they ARE, since BUT-1418). It's a decision-record edit
  (ADR supersession), genuinely Malin's call per the doc's own contract ("reopening one needs a
  new decision"). Recommend: quick confirm-and-edit, low effort once you say go.
- **BUT-1616** — Reconcile `raw-safe`/`processed` property-vocabulary drift. Needs a decision on
  which side is canonical per property — tagging vocabulary is safety-adjacent, not mine to
  guess. Recommend: a 2-minute decision from you, then this becomes a trivial follow-up build.
- **BUT-1617** — Triage 35 non-blocking specialist findings from the 2026-07-14 sprint. That
  sprint's scratch review artifacts are very likely gone (scratch space is disposable). Recommend:
  close as stale unless you know the findings survive somewhere.
- **BUT-1601** — Inline ingredient quantities in cooking-mode steps. No `autonomous` label, tagged
  `idea`; real NLP complexity, no mockup. Recommend: worth doing eventually, needs a product/UX
  pass first.
- **BUT-1499** — Collaborative weekly menu is fully coded but never wired to a live view. The
  ticket's own acceptance #1 is "decide: wire it up or park it" — genuinely your call.
- **BUT-1472** — `parse_corrections_v2`/`llm_response_samples` have no consumer. A real investment
  decision (build a consumer vs turn off the write path), not a bug fix. Recommend the cheap
  "turn off" path per cost-minimization, unless you want the corrections-mining tool.
- **BUT-1176** — Optional custom_lint/AST upgrade. Self-describes "pick up only if custom_lint is
  being added for other reasons" — condition unmet. Recommend: drop or leave parked.
- **BUT-1619 / BUT-1620 / BUT-1621 / BUT-1634 / BUT-1599** — Delivery-engine (sprint machinery)
  hardening tickets. All target `C:/claude-plugins/plugins/delivery/...` — a DIFFERENT git repo,
  shipped via `node tools/fanout-update.mjs`, not buildable from a Butlery app sprint. Recommend:
  batch all 5 into one claude-plugins-specific session.
- **BUT-1630** — Sprint scratch janitor. Self-describes "not urgent — harmless disposable
  scratch"; ambiguous repo target. Recommend: fold into the claude-plugins session above, or an
  occasional manual glance — doesn't need a dedicated ticket-driven build.
- **BUT-880** — PITR restore drill against a non-prod project. Already `need-malin`-labeled;
  ops-blocked (needs BUT-451 staging project or a throwaway project + your time). Recommend: do
  it, but it's an ops task for you.
- **9 other standing `need-malin`-labeled tickets** (BUT-1557, BUT-1502, BUT-1179, BUT-1368,
  BUT-863, BUT-1445, BUT-1229, BUT-1608, BUT-1453) remain parked in Backlog — no new judgment
  added this round; not re-litigated.

## Excluded from scoring entirely
- **BUT-677, BUT-722** — carry the `onboarding-reserved` label; per standing instruction, never
  scored, selected, transitioned, or implemented.
- **~85 `deferred`-labeled tickets** (epics, launch-gated, tablet/macOS, monetization ideas, etc.)
  — left untouched in Backlog per the lane convention; deliberately parked, not re-scored.

## Excluded this round (sequencing, not rejection)
- **BUT-1613** ("BUT-1323 slice 4: per-day portion adjustment by present count") — still blocked
  on BUT-1615's UI/wiring (Batch B this round). Revisit immediately after Batch B lands.
- **BUT-1323** — parent EPIC of BUT-1613/BUT-1615/BUT-1611; not itself buildable, sits in Todo as
  a container. No action.

## Not selected this round (scored but below the cut / lower urgency)
Low-priority `autonomous` batches that remain valid, clean-build candidates for a future sprint:
BUT-1566 (housekeeping micro-cleanups), BUT-1565 (retry-helper consolidation), BUT-1561 (FinOps
hardening — note: its "cap-trip alert" sub-item may need console access, scope down at Step-0),
BUT-1504, BUT-1501, BUT-1476, BUT-1488, BUT-1508 (78-file ServiceLocator→constructor-injection
refactor — large, Tier C candidate on its own), BUT-1507 (god-object refactor — large, Tier C
candidate on its own), BUT-1513 (rewrite ~120 bulk-skipped integration tests — large, Tier C
candidate on its own), BUT-1510, BUT-1509, BUT-1514, BUT-1480, BUT-1486, BUT-1485, BUT-1484,
BUT-1482, BUT-1471, BUT-1490, BUT-1240, BUT-945, BUT-1441, BUT-1452.

## Deviation log
(none yet — Phase 1 only, no implementation this pass)

---

## 2026-07-18 sprint (third pass) — Selection (Phase 1)

**Backlog scanned:** Linear team Butlery, states Backlog/Todo/In Progress/Triage (109 Backlog +
6 Todo, 0 In Progress, 0 Triage). `onboarding-reserved` label: BUT-677, BUT-722 present —
excluded entirely, not scored. Recent `git log` (7 days) mapped against the backlog: confirms
the second-pass salvage's 6 shipped tickets (BUT-1627, 1614, 1462, 1515, 1560-partial, 1626) are
correctly absent/downgraded in the open backlog, and surfaced 7 NEW follow-up tickets the salvage
filed for its own gaps (BUT-1628–1634).

**Lane convention honored:** `deferred`-lane tickets (epics/launch-gated/nice-to-haves) left
untouched in Backlog — deliberately parked, not re-scored. `need-malin`-lane tickets (9, now
includes BUT-880) stay parked; surfaced under Needs Malin below rather than re-litigated.

**Step-0 premise checks (mandatory, ran before selecting) reconfirmed all 3 prior obsolete
findings still hold** (nothing touched the relevant files since the last check) — closed in
Linear this round (see Obsolete).

**File-overlap merges (mandatory before batching):** BUT-1458 and BUT-1631 both edit
`lib/services/tagging/phases/tag_phase1_nutrition.dart` — merged into one batch. BUT-1459 and
BUT-1629 both edit `lib/viewmodels/user_profile_viewmodel.dart` — merged into one batch. Router
(`tools/stakeholder_router.py`) run for real on every batch's touched paths — tiers below are its
actual output, not estimated.

### Batch A — menu-tagging-correctness (full-panel: high-stakes tagging file)
- [x] **[Tier C] BUT-1458** — SHIPPED (b7e66bf1a).
- [x] **[Tier C] BUT-1631** — SHIPPED (b7e66bf1a).

### Batch B — group-minor-membership-hardening (single, security-labeled)
- [x] **[Tier A] BUT-1633** — SHIPPED (b7e66bf1a).

### Batch C — observability-remainder (full-panel: firestore.rules touch)
- [ ] **[Tier C] BUT-1632** — NOT shipped by the salvage. Re-carried as Batch A (fourth pass).

### Batch D — presence-selector-ui (build-review: UI/interaction call, carried from prior plan)
- [ ] **[Tier B] BUT-1615** — NOT shipped by the salvage. Re-carried as Batch B (fourth pass).

### Batch E — profile-viewmodel-cluster (file overlap on user_profile_viewmodel.dart)
- [ ] **[Tier A] BUT-1459** — NOT shipped by the salvage. Re-carried as Batch C (fourth pass).
- [ ] **[Tier B] BUT-1629** — NOT shipped by the salvage. Re-carried as Batch C (fourth pass).

### Batch F — test-coverage-gaps (test-only, no production files)
- [x] **[Tier A] BUT-1564** — SHIPPED (b7e66bf1a).

### Batch G — ci-coverage-wiring (CI config only)
- [ ] **[Tier A] BUT-1553** — NOT shipped by the salvage. Re-carried as Batch D (fourth pass).

### Batch H — perf-cleanup (repositories + services, no rules/CF touch)
- [~] **[Tier A] BUT-1558** — Production code SHIPPED (b7e66bf1a); test criteria only partial.
  CLOSED obsolete in the fourth pass, residual tests carried as BUT-1635.

## Obsolete (Step-0 re-verified this round — closed in Linear with resolving evidence)
- **BUT-1612** — CLOSED (Canceled). Re-confirmed: `grep -rn ".presentMemberIds =" lib/`
  repo-wide = zero hits. Dependency removed by BUT-1611's rebuild (`ca4ba8b70`). Comment posted
  citing the grep + the commit.
- **BUT-1463** — CLOSED (Canceled). Re-ran `flutter test test/unit/viewmodels/menu_viewmodel_test.dart`
  directly: 30/30 green. Comment posted citing the fresh run.
- **BUT-1456** — CLOSED (Canceled). Re-read `menu_scoring.dart`: the described
  `_Complexity`/`_complexityOf`/cuisine-affinity/cooking-skill code is gone, deleted by BUT-1594
  (`b3c7cb872`). Comment posted citing the grep + the commit.

## Excluded this round (sequencing, not rejection)
- **BUT-1613** ("BUT-1323 slice 4: per-day portion adjustment by present count") — still blocked
  on the REAL dependency (BUT-1615's UI/wiring, not the closed BUT-1611 the ticket names).
  Revisit immediately after Batch D lands.

## Needs Malin (speculative / contestable / ops-blocked / wrong-repo — not built)
- **BUT-1634** — Sprint Phase-0 clean-tree check aborts on untracked `.stale` markers. Target
  file is `C:/claude-plugins/plugins/delivery/workflows/sprint-execute-parallel.js` — a
  DIFFERENT git repo, shipped via `node tools/fanout-update.mjs`, not buildable from a Butlery
  app sprint. Recommend: pick up from a claude-plugins-specific session (same as 1619/1620/1621
  below — this is now 4 delivery-engine tickets queued there).
- **BUT-1619 / BUT-1620 / BUT-1621** — Delivery-engine hardening tickets, same wrong-repo
  situation as BUT-1634. Recommend: batch all 4 into one claude-plugins session.
- **BUT-1630** — Sprint scratch janitor (clean leftover patch dirs + tagged cleanup stashes).
  Ambiguous repo target (the fix is "run it from an interactive/Bash context outside the
  auto-mode ship prompt" — could be a Butlery-repo script or a claude-plugins/session-level
  habit). Self-describes "not urgent — harmless disposable scratch." Recommend: fold into the
  same claude-plugins session as the other 4 above, or just an occasional manual
  `git stash list` / patch-dir glance — genuinely doesn't need a dedicated ticket-driven build.
- **BUT-880** — PITR restore drill against a non-prod project. Already `need-malin`-labeled;
  ops-blocked (needs BUT-451 staging project or a throwaway project + your time). Recommend: do
  it, but it's an ops task for you.
- **BUT-1176** — Optional custom_lint/AST upgrade. Self-describes "pick up only if custom_lint is
  being added for other reasons" — condition unmet. Recommend: drop or leave parked.
- **BUT-1472** — `parse_corrections_v2`/`llm_response_samples` have no consumer. A real investment
  decision (build a consumer vs turn off the write path), not a bug fix. Recommend the cheap
  "turn off" path per cost-minimization, unless you want the corrections-mining tool.
- **BUT-1499** — Collaborative weekly menu is fully coded but never wired to a live view. The
  ticket's own acceptance #1 is "decide: wire it up or park it" — genuinely your call.
- **BUT-1625** — Safe present-aware menu generation. Explicitly framed as "IF product wants
  generation tuned to who's present" on a children's-allergen-safety surface. Recommend: leave
  parked unless specifically wanted (matches `accepted-deviations.md`).
- **BUT-1601** — Inline ingredient quantities in cooking-mode steps. No `autonomous` label, tagged
  `idea`; real NLP complexity, no mockup. Recommend: worth doing eventually, needs a product/UX
  pass first.
- **BUT-1617** — Triage 35 non-blocking specialist findings from the 2026-07-14 sprint. That
  sprint's scratch review artifacts are very likely gone (scratch space is disposable). Recommend:
  close as stale unless you know the findings survive somewhere.
- **BUT-1616** — Reconcile `raw-safe`/`processed` property-vocabulary drift. Needs a decision on
  which side is canonical per property — tagging vocabulary is safety-adjacent, not mine to
  guess. Recommend: a 2-minute decision from you, then this becomes a trivial follow-up build.
- **9 pre-existing `need-malin`-labeled tickets** (BUT-1557, BUT-1599, BUT-1502, BUT-1179,
  BUT-1368, BUT-863, BUT-1445, BUT-1229, BUT-880) remain parked in Backlog — no new judgment
  added this round; surfaced here only as a reminder they're waiting.

## Excluded from scoring entirely
- **BUT-677, BUT-722** — carry the `onboarding-reserved` label; per standing instruction, never
  scored, selected, transitioned, or implemented.
- **~85 `deferred`-labeled tickets** (epics, launch-gated, tablet/macOS, monetization ideas, etc.)
  — left untouched in Backlog per the lane convention; deliberately parked, not re-scored.

## Not selected this round (scored but below the cut / lower urgency than the 10 above)
Low-priority `autonomous` batches that remain valid, clean-build candidates for a future sprint:
BUT-1628 (BaseViewModel clearError-override sweep, 32-file audit), BUT-1566 (housekeeping
micro-cleanups), BUT-1565 (retry-helper consolidation), BUT-1561 (FinOps hardening — note: its
"cap-trip alert" sub-item may need console access, scope down at Step-0), BUT-1504, BUT-1501,
BUT-1476, BUT-1488, BUT-1508 (78-file ServiceLocator→constructor-injection refactor — large,
Tier C candidate on its own), BUT-1507 (god-object refactor — large, Tier C candidate on its
own), BUT-1513 (rewrite ~120 bulk-skipped integration tests — large, Tier C candidate on its
own), BUT-1510, BUT-1509, BUT-1514, BUT-1480, BUT-1486, BUT-1485, BUT-1484, BUT-1482, BUT-1471,
BUT-1490, BUT-1240, BUT-945, BUT-1441, BUT-1452.

## Deviation log
(none yet — Phase 1 only, no implementation this pass)

---

## 2026-07-18 sprint (second pass) — Selection (superseded by third pass above; its own
implementation did not complete — see the pass-2 note below for what actually shipped)

**Backlog scanned:** Linear team Butlery, states Backlog/Todo/In Progress/Triage (111 Backlog
+ 3 Todo/parent, 0 In Progress, 0 Triage). `onboarding-reserved` label: BUT-677, BUT-722 present
— excluded entirely, not scored. Recent `git log` (7 days, 9 salvage commits from this morning's
crashed-then-salvaged sprint) mapped against the backlog — confirms the 9 salvaged tickets are
correctly absent from the open backlog.

**Lane convention honored:** `deferred`-lane tickets (~90, epics/launch-gated/nice-to-haves) left
untouched in Backlog — deliberately parked, not re-scored. `need-malin`-lane tickets (8) stay
parked; the handful with live decision relevance are surfaced under Needs Malin below rather than
re-litigated individually.

**Step-0 premise checks (mandatory, ran before selecting) caught 2 obsolete tickets and 1
half-stale ticket that a text-only read would have missed** — see Obsolete and the BUT-1459
re-scope note.

### Batch A — docs-workflow-map (mechanical, isolated)
- [x] **[Tier A] BUT-1627** — SHIPPED (2c3d2aa31).

### Batch B — import-test-gap
- [x] **[Tier A] BUT-1614** — SHIPPED (b8da3fb12).

### Batch C — menu-tagging-quality
- [ ] **[Tier A] BUT-1458** — NOT shipped by pass-2 (uncommitted/backed up). Re-carried as
  Batch A above (third pass), merged with the new BUT-1631 finding.

### Batch D — presence-portions-ui (build-review: UI/interaction call)
- [ ] **[Tier B] BUT-1615** — NOT shipped by pass-2 (zero code — needs /preview + Malin
  sign-off). Re-carried as Batch D above (third pass), unchanged.

### Batch E — profile-save-flag (re-scoped at Step-0 — half the original ticket already shipped)
- [ ] **[Tier A] BUT-1459** — Pass-2 attempted this; **FAILED verification**
  (correctness:fail + data-safety:fail) and was never committed. Re-carried as part of Batch E
  above (third pass) for a clean re-implementation.

### Batch F — recipe-scaling-race
- [x] **[Tier A] BUT-1515** — SHIPPED (b8da3fb12).

### Batch G — viewmodel-dispose-decision (narrowed scope)
- [x] **[Tier A] BUT-1462** — SHIPPED (b8da3fb12). Follow-up filed: BUT-1628 (32-file sweep).

### Batch H — trust-safety-hardening (full-panel)
- [x] **[Tier C] BUT-1626** — SHIPPED (9eb7155b1). Follow-ups filed: BUT-1629 (searchable
  opt-in remainder), BUT-1633 (CF hardening).
- [~] **[Tier A] BUT-1560** — Partially shipped (1 of 4 criteria, in b8da3fb12). Remainder filed
  as BUT-1632.

## Deviation log
(archived with this sprint pass)

---

## 2026-07-18 sprint (first pass) — SALVAGE COMPLETE (all 7 batches shipped to main)

The 2026-07-18 sprint pile was salvaged ticket-by-ticket, each with fresh
commit-gate specialist reviews on the ACTUAL diff (never trusting the sprint's
gates:ok), findings fixed, tests green, committed + pushed:

1. **BUT-1518+1624** (227a99609) — ratings pool-key laundering telemetry + backfill blob fix.
   Fixed 2 PII-in-logs (uid→hashUid, anchor→anchorSig). CF-specialist + adversarial verify.
2. **BUT-1474** (c93386352) — menu swap-rate analytics. code-reviewer + testing.
3. **BUT-1607** (4de18d041) — ShoppingSelectionManager→BaseViewModel migration. code-reviewer + testing.
4. **BUT-1454** (4272ae9a0) — minor search-suppression (GDPR/child-safety). 4 specialists.
5. **BUT-1475+1489** (8d96b3055) — ingredient delta-refresh + tag-accuracy CI gate.
   Strengthened the weak test (delta-vs-full discriminator) + fixed forceRefresh coalescing race. 3 specialists.
6. **BUT-1473** (4c809ab58) — tag-override learning loop, now LIVE: added the missing
   Firestore rule (emulator-proven, 14/14) + GDPR cascade + capture test. 5 specialists.
7. **BUT-1469** (dbc1bdb54) — import-correction capture widening + fixed the name-less
   phantom-diff bug (polluted USP training data). Un-skipped the pinned test + over-correction guard. 2 specialists.

### Follow-ups (not blocking):
- **workflow-map.stale** — carried forward as BUT-1627 (shipped second pass).
- **BUT-1454**: enforcement is client-side; firestore.rules still permits minor isSearchable:true
  (future discovery opt-in) — carried forward as BUT-1626 (shipped second pass).
- **BUT-1469**: some URL structured/user-assisted fallback tiers don't re-tag source (accepted Low).
- **BUT-1475**: delta refresh can't observe deletions until next forceRefresh/restart (documented in code).

---

## 2026-07-16 parallel-sprint pile — status (archived)

**Shipped to main this session (each reviewed cold + fixed, tests green):**
- BUT-1611 — per-meal weekly-menu presence (rebuilt from the wrong per-day design; removed
  the allergen-unsafe generation-scoping → BUT-1625). `ca4ba8b70`
- BUT-1618 — rule-dialog property dropdown derives from the shared vocabulary. `20e68a79a`
- BUT-1609 — "Minderårigt konto" moderation badge (+ a real watchIsAdmin spinner-strand fix). `f0b046b8e`
- BUT-1519 — one shared Butlery-betyget rating pill + shared formatter. `3b0364475`
- BUT-1623 — 3 admin onCall callables classified; app-check guard green (14/14). `919569e1a`

---

## ⚠️ 2026-07-18 SPRINT PASS-2 (wf_bf9e87eb-ee1) — SHIP BLOCKED, uncommitted pile #2 (RESOLVED)

Second consecutive sprint whose ship phase was blocked by the safety classifier → committed
NOTHING directly, but was salvaged ticket-by-ticket into commit `b8da3fb12` (BUT-1462, BUT-1515,
BUT-1614, BUT-1560-partial) plus `9eb7155b1` (BUT-1626) and `2c3d2aa31` (BUT-1627, pre-existing).
BUT-1459 failed verification and was NOT shipped (re-carried above for clean re-implementation).
BUT-1615 had zero code and was NOT shipped (re-carried above, needs /preview + Malin sign-off).
The systemic ship-phase issue was fixed in commit `68a400d9f` ("drop the analyze-gate-skip commit
prefix so the parallel-sprint ship passes the auto-mode classifier").

---

## 2026-07-19 — Ship-salvage of the held sprint batch (approved by Malin) — SHIPPED (b7e66bf1a)

The sprint's ship phase correctly HALTED: the commit-gate hook blocked with
"STALE: testing-specialist — files edited after review". This pass closed the review findings
that justified the block, added the missing acceptance-criteria tests, re-ran the gates honestly,
and shipped BUT-1458, BUT-1631, BUT-1633, BUT-1564, and BUT-1558's production code as commit
`b7e66bf1a` (confirmed via `git show --stat` at the top of this file's current pass).

Full detail (fixes landed, cross-file review findings, deliberately-not-papered-over test gaps)
is preserved in git history for this file as of commit `b7e66bf1a` — condensed here since the
work is shipped and the residual scope is now tracked by fresh tickets (BUT-1632, BUT-1635) in
the current pass above.

---

## 2026-07-21 — Salvage of crashed sprint wxe0xnfys (usage-limit death)

The sprint died mid-ship on the WEEKLY usage limit (ship + completeness-sweep +
final-verify all aborted). Its review gates HAD passed; only verification+ship died,
leaving ~6 tickets' work uncommitted in the tree. Backed up the full 1878-line diff before
triage. Verified against LIVE code (not the crash report's own claims) and re-reviewed the
actual diff with 5 opus specialists.

Shipped this pass (all re-reviewed clean/SHIP on the real diff):
- **BUT-1637** (child-safety): server-authoritative `fetchPersistedSearchable` read before a
  minor's profile save, fails closed, honors a cross-device opt-out — firebase-backend-security
  verdict SHIP, no path to more-discoverable.
- **BUT-1565**: retry-helper consolidation (behaviourally sound, actually more resilient).
- **BUT-1566**: housekeeping micro-cleanups (all behaviour-preserving).
- **BUT-1638**: CF searchability test — 4 gate branches, proven non-vacuous. Fixed the LOW
  hygiene finding (two suites now run SEQUENTIALLY, not fire-and-forget).
- **BUT-1639/1640**: perf + disposed-guard tests. Removed 2 VACUOUS disposed-guard tests the
  testing-specialist caught (BaseViewModel triple-guards disposal, so they couldn't fail);
  kept the sound state-mutation emission test.
- **BUT-1643**: workflow-map re-trace (linter OK, marker cleared).

Follow-up filed: **BUT-1644** — direct service-layer test for the `setMinorSearchable` writer
(both reviewers flagged; not a blocker, the risky re-assert path is fully tested).

Verified green: dart analyze --fatal-infos clean; 218 + 76 + 33 Dart tests; tsc clean;
CF 5/5 + 3/3.
