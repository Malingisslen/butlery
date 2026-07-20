# tasks/todo.md

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
- [ ] **[Tier C] BUT-1458** — Protein-tag drift guard is a hardcoded mirror; make it real + drop
  unused `allTags`. disposition: build. requiresPlanMode: **true** (router: full-panel —
  high_stakes_hits: `lib/services/tagging/phases/tag_phase1_nutrition.dart`; panel: Data/ML
  Engineer, FinOps, Legal, Privacy/DPO, Product Manager, Security Architect, Software Architect).
  Files: `lib/services/menu/protein_category.dart`,
  `lib/services/tagging/phases/tag_phase1_nutrition.dart`,
  `test/unit/services/menu_service_test.dart`, optionally new
  `test/unit/services/menu/protein_category_test.dart`.
  Acceptance:
  1. The protein-tag vocabulary in `tag_phase1_nutrition.dart` is extracted into one shared
     const both the tagger and `ProteinCategory`/the guard read.
  2. A test proves the guard now genuinely fails when a tag is added to the tagger without a
     `ProteinCategory` mapping (mutation-style regression, not just green-by-coincidence).
  3. `ProteinCategory.allTags` is removed, or documented/derived from the shared source instead
     of standing as an unused "production API".
  4. **Don't** change protein-cap generation behavior — test-integrity fix only; existing menu
     tests stay green.
- [ ] **[Tier C] BUT-1631** — Protein-tag detection gaps: duck cuts missed by the `'anka'`
  substring match; no generic poultry/plant-based fallback (unlike fish/shellfish), so an
  unrecognised member of those groups escapes the BUT-1324 weekly protein-balance cap entirely.
  disposition: build. requiresPlanMode: **true** (same file, same router result as BUT-1458 —
  full-panel). Same-batch as BUT-1458 (file overlap on `tag_phase1_nutrition.dart` — sequence,
  don't run in a second parallel worktree).
  Files: `lib/services/tagging/phases/tag_phase1_nutrition.dart`, plus recall tests.
  Acceptance:
  1. A duck-cut ingredient name that previously escaped the `'anka'` substring match now tags
     correctly (test with a real compound/cut name from the gap).
  2. An unrecognised poultry-group ingredient gets a generic poultry fallback tag (mirroring the
     existing fish/shellfish fallback pattern) instead of emitting no protein tag.
  3. An unrecognised plant-based-group ingredient gets a generic plant-based fallback tag, same
     pattern.
  4. **Don't** touch the BUT-1458 drift-guard mechanism itself in this ticket's diff beyond
     what's needed to keep it green — this is a detection-recall fix, that's a test-integrity fix.

### Batch B — group-minor-membership-hardening (single, security-labeled)
- [ ] **[Tier A] BUT-1633** — Harden `enforce-group-minor-membership` CF: `retry:true` (the
  handler is idempotent; `retry:false` currently fails OPEN on a transient read error, leaving a
  non-friend-added minor in a group — a real child-safety gap gap) + a `fn.run(event)` emulator
  test covering the untested destructive-I/O branches (delete-below-2-participants,
  `FieldValue.delete()` cleanups, membership-mirror cleanup). disposition: build.
  requiresPlanMode: **true** (router: single + `security` label →
  `single + security label` fires the gate even though priority is Low; panel: QA/Test,
  Security Architect, Vendor/Procurement).
  Files: `functions/src/messaging/enforce-group-minor-membership.ts`,
  `functions/src/__tests__/enforce-group-minor-membership.test.ts`.
  Acceptance:
  1. The trigger options include `{ retry: true }`.
  2. A new emulator integration test drives `fn.run(event)` through the delete-below-2-participants
     branch and asserts the `FieldValue.delete()` / membership-mirror cleanup actually happens.
  3. The existing 6/6 `computeMinorsToRemove` pure-logic unit tests stay green, unchanged.

### Batch C — observability-remainder (full-panel: firestore.rules touch)
- [ ] **[Tier C] BUT-1632** — Observability remainder of BUT-1560 (which shipped only 1 of 4
  criteria in the pass-2 salvage — the dead RC-flag removal, commit `b8da3fb12`). Three
  independent, clean-build fixes: (1) feedback-email send failure writes a `system_events` doc
  instead of failing silently, (2) the `feedback` create rule gets a `hasOnly([...])` field
  allowlist + size caps (currently a client can write arbitrary/oversized fields — a real
  security gap), (3) `AppMonitoringService.recordError` forwards to `WebErrorReporter` when
  `kIsWeb` (web errors currently vanish). disposition: build. requiresPlanMode: **true** (router:
  full-panel — high_stakes_hits: `firestore.rules`; panel incl. Security Architect, Trust &
  Safety, Legal, Privacy/DPO, Product Manager, Software Architect, FinOps).
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

### Batch D — presence-selector-ui (build-review: UI/interaction call, carried from prior plan)
- [ ] **[Tier B] BUT-1615** — Per-day presence selector UI + generator wiring + preview gate
  (the real remainder of BUT-1611 — its own ticket shipped only the dead data-model field, per
  BUT-1615's own text: `presenceByDay`/`presentOn` exist but nothing in the UI or generator
  reads/writes them). disposition: build-review. requiresPlanMode: false (router: single, panel:
  Product Manager only — no high-stakes hit — but flagged manually as substantial: new UI +
  generator wiring + preview gate, same call as the prior plan pass).
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

### Batch E — profile-viewmodel-cluster (file overlap on user_profile_viewmodel.dart)
- [ ] **[Tier A] BUT-1459** — Hoist save-in-flight flag into `UserProfileViewModel.saveProfile()`
  (today only avatar-upload is tracked by `isLoading`; `menu_taste_view.dart`/now
  `household_size_view.dart` has to re-implement a local `_saving` bool band-aid) + a widget test
  for the already-shipped menu-taste/household-size back-nav unsaved-changes guard.
  disposition: build. requiresPlanMode: false (router: single, panel: Vendor/Procurement only —
  no security/high-priority hit; same-batch as BUT-1629 for the file-overlap, not for risk).
  **Note:** `menu_taste_view.dart` was renamed to `household_size_view.dart` by BUT-1594
  (2026-07-12) and its own commit ALREADY added the back-nav widget test
  (`test/widget/views/settings/household_size_view_test.dart` L190-238) — re-verify at Step-0 of
  implementation that this still holds; if so, only the flag-hoist half remains.
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
  Files: new `functions/src/social/set-profile-searchability.ts` (or similar, TBD at Step-0),
  `lib/viewmodels/user_profile_viewmodel.dart`, a privacy-settings view (TBD exact file at
  Step-0), plus tests.
  Acceptance:
  1. The callable CF requires auth + App Check, is rate-limited, and idempotent-merge-sets
     `public_profiles/{uid}.isSearchable` via the admin SDK.
  2. A minor's opt-in flows through the CF, never the ordinary profile-save path (test: a
     minor's normal `saveProfile()` call never sets `isSearchable:true`, only the dedicated
     toggle's CF call does).
  3. A rules test proves the CF-written `isSearchable:true` survives while a client-written one
     for the same minor is still denied (regression guard on BUT-1626's hard-deny).
  4. Adults keep the existing client-write path unchanged.

### Batch F — test-coverage-gaps (test-only, no production files)
- [ ] **[Tier A] BUT-1564** — Test-coverage gap batch (role-org scans #4, #8): `birthYear`
  immutability assertion for a merge write omitting `birthYear`; a rules test locking the decided
  cook_snaps/activity_events "not age-gated" scope (pins the accepted-deviations entry so a
  future change gets caught); unit tests for `Phase1AllergenCalculator` + 3 GDPR-export
  sub-managers (currently zero direct coverage). disposition: build. requiresPlanMode: false
  (router: single, panel: Software Architect, Product Manager).
  Files: test-only — new/extended tests under `test/unit/services/tagging/`,
  `test/unit/services/gdpr/`, `functions/src/__tests__/*-rules.test.ts`.
  Acceptance:
  1. A test proves a `preferences` doc merge write omitting `birthYear` does not clear/mutate an
     existing `birthYear` value.
  2. A rules test explicitly asserts cook_snaps + activity_events create paths are NOT age-gated
     (matches the accepted-deviations entry — don't add gating, just pin the current behavior).
  3. `Phase1AllergenCalculator` and each of the 3 GDPR-export sub-managers gets at least one
     direct unit test exercising real behavior (not a trivial constructor-only test).
  4. No production code changes — this ticket is test-only.

### Batch G — ci-coverage-wiring (CI config only)
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

### Batch H — perf-cleanup (repositories + services, no rules/CF touch)
- [ ] **[Tier A] BUT-1558** — Perf cleanup batch (role-org scan #13): an upload-progress
  `StreamSubscription` that's never cancelled (leak); `uploadImage` validating permission twice
  per upload (redundant Firestore read); image cache-HIT recorded on every rebuild instead of
  once per load (skews cache-hit metrics); predictive prefetch fetching 20 recipes every 5 min
  regardless of idle state (cost); frame-timing monitoring compiled out of release yet still
  emitting a fabricated `0.0` (misleading metric). disposition: build. requiresPlanMode: false
  (router: single, panel: Customer Support/Operations).
  Files: `lib/repositories/firebase_storage_repository.dart`,
  `lib/services/cache/optimized_image_loader.dart`,
  `lib/services/cache/intelligent_cache_manager.dart`,
  `lib/services/monitoring/performance_monitoring_service.dart`, plus tests.
  Acceptance:
  1. The upload-progress subscription is captured and cancelled in a `finally` block (test:
     upload completes without a leaked subscription).
  2. `uploadImage`'s duplicate permission check is removed; `uploadImageData`'s check still gates
     the write (test: permission-denied case still rejects).
  3. Image cache-HIT is recorded once per load, not once per rebuild (test: multiple rebuilds of
     the same loaded image record one hit, not N).
  4. Frame-timing monitoring either emits real sampled data in release or stops emitting the
     fabricated `0.0` — pick one, don't leave the misleading metric. **Don't** touch the
     predictive-prefetch idle-gate threshold values beyond adding the gate itself (no product
     tuning call here — just stop the unconditional 5-min fetch).

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

## 2026-07-19 — Ship-salvage of the held sprint batch (approved by Malin)

The sprint's ship phase correctly HALTED: the commit-gate hook blocked with
"STALE: testing-specialist — files edited after review". Nothing was committed or pushed;
HEAD stayed 05632e197 and the whole batch sat staged. Full diff backed up to the session
scratchpad before any triage. Malin chose "finish the salvage properly" over holding or
discarding, so this pass closes the review findings that justified the block, adds the
missing acceptance-criteria tests, re-runs the gates honestly, and ships only what passes.

### Already fixed by the sprint (verified in the working tree, no action)
- [x] BUT-1633 HIGH — malformed-uid fail-open: `participantIds` + `creatorId` now reject
  empty/slash-bearing ids, so a `users/${uid}` path build can't throw and strand the gate.
- [x] BUT-1633 CI gap — the new integration test IS wired into `test:rules:all` and both
  `paths:` lists in `.github/workflows/firestore-rules.yml`.

### To fix in this salvage
- [x] **BUT-1633 (Medium)** DONE — — `snap.ref.update()` is NOT idempotent on a deleted conversation:
  Firestore `update()` throws NOT_FOUND (code 5), which under the newly-added `retry: true`
  becomes a deterministic poison-pill retry storm re-billing the read fan-out forever.
  Swallow NOT_FOUND (the access cut is moot once the doc is gone) and correct the comment,
  which currently over-claims "every write here is idempotent".
- [x] **BUT-1631 (Medium)** DONE — — the generic `växtprotein` fallback fires for the WHOLE
  `protein/plant-based` group, but the live register puts 15 vegan dairy-alternatives and a
  seasoning in that group (yoghurts, näringsjäst, the vegansk ost/grädde/kvarg/parmesan
  family). A splash of vegan cream therefore logs the dish as a plant-protein main and
  pollutes the BUT-1324 weekly protein-balance nudge. Gate the fallback on at least one
  center-of-plate member. NOTE: must not match bare `ost` — it also matches `rostad`.
- [x] **BUT-1631 (Low)** DONE — — the broad `contains('ank')` duck stem is tested BEFORE `kalkon`;
  reorder so exact species win over the stem (latent, safe on today's register).
- [~] **BUT-1558** PARTIAL — — perf behaviour shipped with zero tests. Add the three its acceptance
  criteria name: subscription cancelled in `finally`, permission-denied still rejects after
  the duplicate-check removal (security-adjacent), cache-HIT recorded once per load.

### Gates + ship
- [x] `dart analyze --fatal-infos` clean; run the touched Dart test suites; `tsc --noEmit` for functions.
- [ ] Re-dispatch the commit-gate specialists against the ACTUAL staged diff (code-reviewer,
  testing-specialist, cloud-functions-specialist, firebase-backend-security) — markers only
  after each reports clean. Never forge a marker to satisfy a gate.
- [ ] Commit + push what passes; carry the rest as follow-ups.

### Carried as follow-ups, NOT shipped here (need Malin or a clean rebuild)
- BUT-1632 — feedback create-rule hardening never shipped (sweep disputes the "obsolete" call);
  a client can still write arbitrary/oversized feedback fields. Re-carry as a build ticket.
- BUT-1553 — CF unit tests + CRF golden eval still wired into no CI workflow.
- BUT-1459 / BUT-1629 — landed NO code (batch failed to apply); 1629 also needs a
  privacy-toggle design decision.
- BUT-1564 residual — the `accepted-deviations.md` cook_snaps/activity_events entry is now
  stale (they ARE age-gated since BUT-1418); superseding it is Malin's ADR call.

### Salvage outcome (2026-07-19)

Verification run before the gates: `dart analyze --fatal-infos` clean; functions `npx tsc
--noEmit` exit 0; 122 Dart tests green across the affected suites; the trigger's own CF unit
suite 6/6.

Fixes landed in this pass:
- NOT_FOUND (grpc code 5) is now caught around `snap.ref.update()` and returns early, so
  `retry: true` cannot loop forever on a conversation deleted mid-flight. Header comment
  corrected — it had over-claimed unconditional idempotency.
- `_isPlantDairyAlternative()` gates the `växtprotein` fallback on a real center-of-plate
  member. Validated against ALL 61 live register rows in `protein/plant-based`: exactly 15
  excluded (every genuine dairy-alt/seasoning), 46 kept (every genuine protein). The
  `vegansk`-pairing design is deliberate — bare `ost` also matches `rostad`, which would have
  excluded "rostade kikärter".
- Poultry species precedence reordered: exact `kalkon` now beats the broad `ank` stem.
- Tests added: 12 tagging tests (dairy-alt boundary, accompaniment case, no-dairy-word vegan
  product, the `rostad` trap, species precedence) + 1 security regression test proving
  `uploadImage` still rejects a foreign path after its duplicate permission check was removed.

TEST GAPS DELIBERATELY NOT PAPERED OVER (both carried as follow-ups):
- BUT-1558 progress-subscription cancel: a test was written and REMOVED because
  `firebase_storage_mocks`' `MockTaskSnapshot` exposes no `bytesTransferred`, so attaching any
  onProgress callback makes the fake throw — the test could only ever have passed for the
  wrong reason. Needs a controllable UploadTask (integration lane).
- BUT-1558 cache-HIT-once-per-load: untested; driving the widget's `imageBuilder` needs
  network-image mocking infrastructure this repo does not have.

### Cross-file /code-review high — 10 defects, 6 fixed here, 4 carried

The workflow review (run on the staged diff, after the per-file specialists) found what
the file-scoped passes structurally could not. Fixed in this pass:

- **CONFIRMED, child-safety**: `isValidDocId` accepted uids that are legal DOCUMENT IDs but
  illegal FIELD-PATH segments (dot, `[`, `]`, `*`, backtick). `update()` rejects those with
  INVALID_ARGUMENT (grpc 3 — NOT the NOT_FOUND 5 we catch), so `retry: true` replayed a
  deterministic error forever while the minor was never removed: the gate failed OPEN in the
  exact tampered-client threat model it exists for. A dotted uid was wrong even without a
  throw — `participantDisplayNames.a.b` addresses a nested map, not the key "a.b", so the
  removed minor's name/avatar survived the cut. Now rejects the union of both constraint sets.
- **CONFIRMED, red test on the staged tree**: the new generic `fågel` tag was never added to
  `ReservedTags._autoGeneratedTags`, so a user could create a personal tag "fågel" that
  shadows the auto-tag. `reserved_tags_consistency_test.dart` was already failing — missed
  because the earlier runs only covered the suites for touched files, and this guard lives in
  a different file precisely because it checks a cross-file invariant.
- Orphaned mirrors: when the group collapses and the conversation is deleted, the SURVIVING
  member's membership mirror is now cleared too (previously only the removed minors'), so no
  one is left with an undismissable conversation row pointing at a deleted doc.
- Read fan-out is now capped (`MAX_GROUP_PARTICIPANTS = 100`): rules cap neither the
  participant-list length nor the create rate, so a tampered create could force an unbounded
  billed getAll that `retry: true` then replays.
- Duplicate uids in the mirror cleanup de-duplicated.
- Test expectation corrected: `"..leading"` is now (rightly) rejected as field-path-unsafe —
  the test was stale, not the code.

CARRIED AS FOLLOW-UPS (deliberately not folded in):
- Image-cache hit/miss flags are never reset on a new URL (no `didUpdateWidget`), so in a
  scrolling list a recycled widget records nothing for images 2..N — telemetry undercount.
  The same missing reset leaves `_thumbnailUrl` stale, which is a genuine USER-VISIBLE glitch
  (previous recipe's blurred placeholder behind a new card image). Deserves its own ticket
  against the card path rather than being quietly folded into this batch.
- `cacheHitRate` still reports a fabricated 0.0 when there are zero samples — the same
  zero-samples class as the frame-metric fix, one line below it.
- BUT-1558's progress-subscription-cancel and cache-hit-once remain untested (see above).
