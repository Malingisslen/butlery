# tasks/todo.md

## 2026-07-18 sprint (second pass) — Selection (Phase 1)

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
- [ ] **[Tier A] BUT-1627** — Re-trace 11 workflow-map trigger flows stale since 2026-07-16 +
  fix the Phase-0 untracked-marker gap note. disposition: build. requiresPlanMode: false.
  router: skip.
  Files: `docs/onboarding/workflow-map.html` (data JSON only), delete
  `docs/onboarding/workflow-map.stale`.
  Acceptance:
  1. Each of the 11 trigger files' flows in the `<script id="data">` JSON are re-traced against
     current code (BUT-1609, BUT-1611, BUT-1473, BUT-1518, BUT-1475 trigger sets).
  2. `docs/onboarding/workflow-map.stale` is deleted after the re-trace.
  3. `tools/check_workflow_map.py` exits clean.
  4. **Don't** touch anything in workflow-map.html beyond the flow JSON (per CLAUDE.md: "update
     the map's JSON, nothing else").

### Batch B — import-test-gap
- [ ] **[Tier A] BUT-1614** — Test gap: correction-capture on text/photo/url import strategies
  (follow-up to shipped BUT-1469). disposition: build. requiresPlanMode: false. router: single
  (Data/Integrations Engineer, FinOps, Monetization). Step-0 verified: zero test coverage for
  `cacheCorrectionSnapshot`/`buildCorrectionSnapshot` still holds (grepped `test/`, no hits).
  Files: `test/unit/services/import/text_import_strategy_test.dart`,
  `photo_import_strategy_test.dart`, `url_import_strategy_test.dart`.
  Acceptance:
  1. A snapshot is cached on import for each of text / photo / url (test per strategy).
  2. A subsequent edited parse produces a correction record; an identical unchanged parse
     produces no false correction (test per strategy).
  3. The `options['skipCorrectionCache']` opt-out on photo/url's internal `text.import()`
     sub-parse is covered — each user-facing import caches exactly one correctly-attributed
     snapshot, not two.
  4. Existing `*_import_strategy_test.dart` suites still pass — no regression to shipped
     BUT-1469 behavior.

### Batch C — menu-tagging-quality
- [ ] **[Tier A] BUT-1458** — Protein-tag drift guard is a hardcoded mirror; make it real + drop
  unused `allTags`. disposition: build. requiresPlanMode: false. router: single (Data/ML
  Engineer — parsing & tagging integrity, Product Manager). Step-0 verified: the hardcoded
  `_tagToCategory` map and the test's separate hardcoded drift-guard copy both still exist
  unchanged.
  Files: `lib/services/menu/protein_category.dart`, `lib/services/tagging/tag_phase1_nutrition.dart`,
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

### Batch D — presence-portions-ui (build-review: UI/interaction call)
- [ ] **[Tier B] BUT-1615** — Per-day presence selector UI + generator wiring + preview gate
  (the real remainder of BUT-1611 — its own Linear ticket closed on data-model-only, per BUT-1615's
  own text). disposition: build-review. requiresPlanMode: false (single tier, Medium priority,
  formula doesn't fire — flagged manually as substantial: new UI + generator wiring + preview
  gate). router: single (Product Manager).
  signoffReason: where the per-day "who's present" selector sits in the calendar UI and how it's
  toggled — a visual/interaction call for Malin before it ships.
  Files: `lib/viewmodels/menu/menu_generator.dart`, `lib/viewmodels/menu/weekly_menu_plan_viewmodel.dart`,
  `lib/services/menu/weekly_menu_plan_service.dart`, `lib/widgets/menu/calendar_weekly_menu_widget.dart`,
  `lib/views/veckomeny_view.dart`, a `/preview --directions` artifact under `tasks/previews/`,
  plus tests.
  Acceptance:
  1. A per-day "who's present" selector exists in the weekly-menu calendar UI and persists to
     `WeeklyMenuPlan.presenceByDay` via a plan-VM save method.
  2. `menu_generator.dart`'s day-generation path reads that day's own presence selection and
     sets `presentMemberIds` per generated day (wiring only).
  3. A `/preview --directions` marker exists for the new selector before implementation, per
     the repo's preview gate.
  4. **Don't** widen this into allergen-filtering/generation-pool scoping — matches the accepted
     display/portions-safe boundary in `accepted-deviations.md` (BUT-1625's boundary). Existing
     weekly-menu allergen-filtering tests stay unchanged.

### Batch E — profile-save-flag (re-scoped at Step-0 — half the original ticket already shipped)
- [ ] **[Tier A] BUT-1459** — Hoist save-in-flight flag into UserProfileViewModel. disposition:
  build. requiresPlanMode: false. router: single (Software Architect, Product Manager).
  **Step-0 finding: the ticket's premise is half-stale.** `menu_taste_view.dart` no longer
  exists — BUT-1594 (2026-07-12) renamed it to `household_size_view.dart` and, per its own
  commit body, ALREADY added the back-nav/unsaved-changes widget test (finding #2 of this
  ticket) — verified present at `test/widget/views/settings/household_size_view_test.dart`
  L190-238. Only finding #1 (the local `_saving` bool band-aid, still present at
  `household_size_view.dart:71`) remains open.
  Files: `lib/viewmodels/user_profile_viewmodel.dart`, `lib/views/settings/household_size_view.dart`,
  plus tests.
  Acceptance:
  1. `UserProfileViewModel.saveProfile()` exposes an in-flight `isSaving` flag.
  2. `household_size_view.dart`'s local `_saving` bool is replaced with the VM's flag (double-tap
     double-write guard behavior unchanged — test: two rapid taps produce one write).
  3. **Don't** re-add a back-nav/unsaved-changes widget test — already shipped and covered;
     this pass is the save-in-flight hoist only.

### Batch F — recipe-scaling-race
- [ ] **[Tier A] BUT-1515** — Household-size default skipped on cold deep-link into a recipe
  (boot race). disposition: build. requiresPlanMode: false. router: single (Accessibility
  Specialist, Creative Director/Brand Lead — trivial UI touch flagged by file path, not a
  design decision). Step-0 verified: `initializeScaling` still reads `currentUserProfile`
  synchronously; the race is live.
  Files: `lib/views/recipe_detail/recipe_detail_actions.dart`,
  `lib/viewmodels/cooking_mode_viewmodel.dart`, plus tests.
  Acceptance:
  1. A recipe opened via cold deep-link, once `UserService`'s profile finishes loading after
     mount, re-applies the household-size default to the scaler (test simulates
     profile-loads-after-mount).
  2. A manual portion override the user already made on that screen is never clobbered by the
     late-arriving default (test).
  3. Normal (non-cold-start) navigation keeps its current behavior unchanged.

### Batch G — viewmodel-dispose-decision (narrowed scope)
- [ ] **[Tier A] BUT-1462** — Decide `BaseViewModel.executeAsync` post-dispose semantics.
  disposition: build. requiresPlanMode: false. router: single (Software Architect, Product
  Manager). **Scoped down from the ticket's full ask** — the "sweep all migrated VMs'
  `clearError` overrides" half is a 32-file undertaking (grepped: 32 files override
  `clearError()`), too large for this slice; carried as a filed follow-up instead.
  Files: `lib/viewmodels/base_viewmodel.dart` (doc comment), `tasks/lessons.md` +
  `.claude/rules/lessons-digest.md`.
  Acceptance:
  1. A documented decision (code comment on `executeAsync` + a lessons.md/digest line) states
     the fail-loud-on-disposed behavior is accepted/intended, not a bug.
  2. A follow-up Linear ticket is filed for the full `clearError`-override sweep across the 32
     files — **don't** attempt the full sweep in this pass.
  3. No behavior change to `executeAsync` itself — decision-and-document only.

### Batch H — trust-safety-hardening (full-panel: both touch firestore.rules, merged to stay
file-disjoint from every other batch)
- [ ] **[Tier C] BUT-1626** — Minor privacy: searchable opt-in + group-DM minor gate + lifecycle
  guard (BUT-1454 remainder — item 1 shipped 2026-07-18 salvage, this is items 2-4).
  disposition: build-review. requiresPlanMode: **true** (full-panel — Security Architect, Trust
  & Safety, Legal, Privacy/DPO, Product Manager, Software Architect + 4 more; `high_stakes_hits:
  firestore.rules`).
  signoffReason: the group-DM CF gate's reject-vs-remove behavior and the searchable opt-in's
  copy/placement are Malin's calls on a minors-safety surface.
  Files: `functions/src/` (new group-membership CF trigger), a privacy-settings toggle (view +
  viewmodel, TBD exact file at Step-0 of implementation), `firestore.rules`,
  `lib/services/analytics/analytics_repository.dart`, plus tests.
  Acceptance:
  1. A dedicated "sökbarhet" opt-in toggle writes `public_profiles.isSearchable:true` for a
     minor, distinct from the general profile save (which still omits the field for minors).
  2. A new CF trigger validates group-conversation membership adds: a non-friend adding an
     `isMinor` participant to a GROUP conversation is rejected/removed (emulator test).
  3. `firestore.rules` hard-denies a minor writing `isSearchable:true` directly, except through
     the gated opt-in path.
  4. `AnalyticsRepository.setLifecycleStage` routes through (or is guarded by) the
     `emitLifecycle` minor gate.

- [ ] **[Tier A] BUT-1560** — Ops/Support observability batch: silent failures + missing
  escalation signals (role-org scan #14). disposition: build. requiresPlanMode: **true**
  (bumped to full-panel by the `firestore.rules` touch — merged into Batch H to stay
  file-disjoint rather than run parallel firestore.rules edits in two worktrees).
  Files: `functions/src/notifications/on-feedback-created.ts`, `firestore.rules`,
  `lib/services/monitoring/app_monitoring_service.dart`,
  `lib/services/feature_flags/feature_flag_service.dart`, plus tests.
  Acceptance:
  1. Feedback-email send failure writes a `system_events` doc (test: forced failure asserts
     the doc).
  2. `feedback` create rule gets `keys().hasOnly` + size caps (rules test: oversized/extra-field
     payload rejected).
  3. `AppMonitoringService.recordError` forwards to `WebErrorReporter` when `kIsWeb`.
  4. The stale `audit_log_retention_days` Remote Config default is removed/deprecated. **Don't**
     touch the BUT-665 tiered retention policy itself — only the stale flag.

## Obsolete (Step-0 code/test read shows the premise gone — close, don't build)
- **BUT-1612** ("BUT-1323 slice 3: apply per-member dislikes in the present-scoped menu filter")
  — re-confirmed this round: `menu_generator.dart`'s `presentMemberIds` field is still never set
  from outside the class (grepped `.presentMemberIds =` repo-wide, zero hits). Dependency
  removed in BUT-1611's rebuild (`ca4ba8b70`). Close citing that commit.
- **BUT-1463** ("Menu-generation VM tests red on main — 7 failures") — ran
  `flutter test test/unit/viewmodels/menu_viewmodel_test.dart` directly: **30/30 green**, zero
  failures. The 7 failures the ticket describes no longer exist on current main. Close citing
  this run (2026-07-18) as the resolving evidence — the fix landed incidentally in a later
  commit, not traceable to one specific commit.
- **BUT-1456** ("Menu scorer duplicates recipe-complexity heuristic vs
  `RecipeOperations.getComplexityScore`") — read the current `menu_scoring.dart`: the
  cuisine-affinity/cooking-skill fields, the `_Complexity` enum, and the `_complexityOf`
  skill-bias method the ticket describes were **deleted entirely** by BUT-1594
  (`b3c7cb872`, 2026-07-12, "remove cuisine/skill menu weighting"). The file's own docstring
  now states this. Nothing left to dedupe. Close citing `b3c7cb872`.

## Excluded this round (sequencing, not rejection)
- **BUT-1613** ("BUT-1323 slice 4: per-day portion adjustment by present count") — its stated
  blocker (slice 2 / BUT-1611 shipping the per-day presence selector) is NOT actually satisfied
  yet: BUT-1615 (Batch D above) reveals BUT-1611 shipped only the dead data-model field, not the
  UI/wiring that lets a user actually set a day's presence. Building 1613's portion-scaling logic
  now would be unreachable dead code (nothing ever populates the presence it reads). Revisit
  immediately after Batch D (BUT-1615) lands — the real dependency, not the closed ticket. Left
  in its current Todo state (not reverted) since it's queued, just sequenced behind D.

## Needs Malin (speculative / contestable / ops-blocked / wrong-repo — not built)
- **BUT-1619 / BUT-1620 / BUT-1621** — Delivery-engine hardening tickets (review-marker content
  verification, stub-finding rejection, worktree dep-resolution). Target files live in
  `C:/claude-plugins`, a different git repo, shipped via `node tools/fanout-update.mjs` — not
  buildable from a Butlery app sprint. Recommend: pick up from a claude-plugins-specific session.
- **BUT-880** — PITR restore drill against a non-prod project. Already `need-malin`-labeled;
  ops-blocked (needs BUT-451 staging project or a throwaway project + your time). Recommend: do
  it, but it's an ops task for you.
- **BUT-1176** — Optional custom_lint/AST upgrade. Self-describes "pick up only if custom_lint
  is being added for other reasons" — condition unmet. Recommend: drop or leave parked.
- **BUT-1472** — `parse_corrections_v2`/`llm_response_samples` have no consumer. Two forks (build
  a consumer vs turn off the write path) — a real investment decision, not a bug fix. Recommend
  the cheap "turn off" path per cost-minimization, unless you want the corrections-mining tool.
- **BUT-1499** — Collaborative weekly menu is fully coded but never wired to a live view. The
  ticket's own acceptance #1 is "decide: wire it up or park it" — genuinely your call; wiring adds
  real support surface, parking downgrades 3 feature-inventory rows from Verified.
- **BUT-1625** — Safe present-aware menu generation. Explicitly framed as "IF product wants
  generation tuned to who's present" — a real product decision on a children's-allergen-safety
  surface. The safe household-wide baseline already ships. Recommend: leave parked unless
  specifically wanted.
- **BUT-1601** — Inline ingredient quantities in cooking-mode steps ("tärna tomaterna" → "tärna
  4 stora tomater"). No `autonomous` label, tagged `idea` — a genuine feature idea with real NLP
  complexity (matching a free-text instruction token to a structured ingredient amount) and no
  mockup. Recommend: worth doing eventually, needs a product/UX pass first, not an autonomous pick.
- **BUT-1617** — Triage 35 non-blocking specialist findings from the 2026-07-14 sprint. The
  findings text lived in that sprint's scratch review artifacts, which are very likely gone by
  now (scratch space is disposable per the docs taxonomy). Recommend: close as stale unless you
  know the findings survive somewhere; re-deriving them would mean re-running a full review pass
  on old code, which isn't what this ticket asks for.
- **BUT-1616** — Reconcile `raw-safe`/`processed` property-vocabulary drift (follow-up to
  BUT-1498). Genuinely needs a decision on which side is canonical for each property — tagging
  vocabulary is safety-adjacent, not mine to guess. Recommend: a 2-minute decision from you
  (both/neither/one side per property), then this becomes a trivial follow-up build.
- **8 pre-existing `need-malin`-labeled tickets** (BUT-1557, BUT-1599, BUT-1502, BUT-1179,
  BUT-1368, BUT-863, BUT-1445, BUT-1229) remain parked in Backlog, already flagged by earlier
  scans — no new judgment added this round; surfaced here only as a reminder they're waiting.

## Excluded from scoring entirely
- **BUT-677, BUT-722** — carry the `onboarding-reserved` label; per standing instruction, never
  scored, selected, transitioned, or implemented.
- **~90 `deferred`-labeled tickets** (epics, launch-gated, tablet/macOS, monetization ideas, etc.)
  — left untouched in Backlog per the lane convention; deliberately parked, not re-scored.

## Deviation log
(none yet — Phase 1 only, no implementation this pass)

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
- **workflow-map.stale** — carried forward as BUT-1627 above (this second-pass sprint).
- **BUT-1454**: enforcement is client-side; firestore.rules still permits minor isSearchable:true
  (future discovery opt-in) — carried forward as BUT-1626 above.
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

## ⚠️ 2026-07-18 SPRINT PASS-2 (wf_bf9e87eb-ee1) — SHIP BLOCKED, uncommitted pile #2

Second consecutive sprint whose ship phase was **blocked by the safety classifier**
("No reason provided") → committed NOTHING (HEAD still 1c69dc9f9). 54 agents, ~5M tokens,
~85 min. Its OWN completeness critic said "should not ship — 8 gaps." Pile is 39 dirty files
(staged index INCOMPLETE — misses a large unstaged body of load-bearing fixes), backed up to
scratchpad/sprint-2026-07-18-pass2-backup/ (3899-line patch).

- **verified:true (salvageable):** BUT-1627, 1614, 1458, 1515, 1462, 1626.
- **FAILED verification (do NOT ship):** BUT-1459 (correctness:fail + data-safety:fail).
- **partial/dropped:** BUT-1560 (1 of 4 criteria), BUT-1615 (ZERO code — needs /preview + Malin sign-off).
- **obsolete:** 1612, 1463, 1456, 1615. **needsApproval:** many (1619/1620/1621 wrong-repo=claude-plugins, 880 ops, 1176, 1472, 1499, 1625, 1601, 1617, 1616).
- **entanglement:** unstaged fixes (user_service household-size, base_viewmodel retry guard,
  portion_scaler, BUT-1626 firestore.rules creatorId, conversations-rules.test.ts) modified
  16:22-16:35 — committing the staged-only index would DROP these + half-ship tickets.

### SYSTEMIC ISSUE (root cause — fix before more sprints):
The engine's ship phase is safety-classifier-blocked every run (overnight + this). Auto-looping
it is a treadmill: each run costs ~5M tokens + leaves a pile. FIX the ship step (why the
classifier blocks its commit — likely the LEFTHOOK_EXCLUDE-prefixed commit or a forced marker
touch) in C:/claude-plugins .../sprint-execute-parallel.js before running more. Loop STOPPED.

### If salvaging pass-2: ship ONLY the 6 verified-clean tickets, reconcile staged-vs-unstaged
per file first (staged index is incomplete), EXCLUDE 1459 (unsafe), park 1560/1615.
