# tasks/todo.md

## 2026-07-18 sprint — Selection (Phase 1)

**Backlog scanned:** Linear team Butlery, states Backlog/Todo/In Progress/Triage (119 open
tickets total: 4 Todo, 0 In Progress, 0 Triage, ~115 Backlog). `onboarding-reserved` label:
none present this round. Recent `git log` (7 days) mapped against the backlog to find
already-done tickets — see Obsolete below.

**Lane convention honored:** only tickets labeled `autonomous` (never `deferred`) were
considered as build candidates, per `memory/project_linear_lane_labels.md`. `deferred`-lane
tickets (macOS sandbox, nutrition, cookbooks epic, tablet layouts, etc. — ~15 tickets) were
left untouched in Backlog; they are deliberately parked, not re-scored.

### Batch A — backend-ratings (functions/src, disjoint files)
- [ ] **[Tier A] BUT-1624** — A data-writing CF is a git binary blob (one NUL byte) →
  unreviewable. disposition: build. requiresPlanMode: false. router: single
  (Database Administrator, Vendor/Procurement).
  Files: `functions/src/migrations/backfill-canonical-ratings.ts`, its test, a new
  binary-file CI guard wired into `.github/workflows/test.yml` (or equivalent check script).
  Acceptance:
  1. `functions/src/migrations/backfill-canonical-ratings.ts` is git-recognized as text
     (`git grep -I . -- <file>` matches; `git diff` renders a normal diff, not "Binary file differs").
  2. The NUL-byte Map-key separator is replaced with a printable delimiter or a nested map —
     a test proves the same (uid, poolKey) pairs stay distinguishable as before.
  3. A CI check exists that fails on any binary file detected under `functions/src/`.
  4. Backfill behavior/output is unchanged for the same input (regression test) — don't
     change what the migration computes, only how the key is encoded.

- [ ] **[Tier A] BUT-1518** — Pooled ratings C10: anchor-only title-change telemetry
  (rating-laundering visibility). disposition: build. requiresPlanMode: false. router: single
  (Privacy/DPO, Vendor/Procurement).
  Files: `functions/src/ratings/canonical-rating-aggregation.ts`, its test.
  Acceptance:
  1. An anchor-only title change (dish-anchor token changes, ingredient set unchanged) is
     logged distinctly from a genuine dish change, via a structured JSON log line — test
     proves both cases produce distinguishable log output.
  2. No new Firestore collection or field is added — log-only, matching the ticket's stated
     scope. **Don't** add an `ingredientsFingerprint` field or any new pool-event schema
     field (a prior uncommitted attempt over-scoped into a data-writing change — stay log-only).
  3. Deterministic string/token comparison only — no LLM call.
  4. Existing pooled-ratings Stage-A aggregation behavior is unchanged — existing tests
     still pass.

### Batch B — import-correction-capture
- [ ] **[Tier A] BUT-1469** — Widen correction capture from 1 of 8 import paths to all.
  disposition: build. requiresPlanMode: **true** (single tier, priority High ≤2). router:
  single (Data/Integrations Engineer, FinOps, Monetization).
  Files: `lib/services/import/photo_import_strategy.dart`,
  `lib/services/import/text_import_strategy.dart`,
  `lib/services/import/archive_import_strategy.dart`,
  `lib/services/import/voice_import_strategy.dart`, `lib/services/recipe_persistence_manager.dart`,
  `lib/services/import/url_import_strategy.dart` (tiers 2-7), plus tests.
  Acceptance:
  1. Photo/OCR, text-paste, and at least one social/URL-tier-2-7 path each write a pre-edit
     snapshot (equivalent to today's Tier-1 `ParsedRecipeCache`) keyed by recipe id and
     tagged with source — not only Tier-1 URL imports.
  2. A diff/correction-capture record is produced when any imported recipe (regardless of
     source) is edited post-import — test per newly-covered strategy.
  3. Existing Tier-1 URL-import correction-capture behavior is unchanged (no regression on
     the one working path).
  4. **Don't** touch parsing accuracy or the recipe RESULT itself — this ticket is
     capture/telemetry only.

### Batch C — account-security (standalone: firestore.rules touched, full-panel review)
- [ ] **[Tier C] BUT-1454 (item 1 only — search-suppression)** — Minor default-private
  search-suppression. disposition: build. requiresPlanMode: **true** (router: full-panel —
  Security Architect, Trust & Safety, Legal, Privacy/DPO, Product Manager, Software Architect
  + 3 more). Scope for THIS sprint is item 1 of the ticket only (items 2-4 — opt-in toggle,
  group-DM CF gate, defense-in-depth on `setLifecycleStage` — stay in the ticket as
  follow-up scope, not this pass).
  Files: `functions/src/` (the `verifySignupAge` CF), `lib/services/user_service.dart`,
  the user profile model's `toFirestore`/`toFirestoreEditable`, the onboarding
  profile-completion viewmodel, `firestore.rules`/search test, plus tests.
  Acceptance:
  1. `verifySignupAge` CF response returns `isMinor`; onboarding sets
     `public_profiles.isSearchable = false` for a minor at profile-completion time (test).
  2. `toFirestore`/`toFirestoreEditable` omit `isSearchable` for minors so a general profile
     save cannot clobber the CF-set `false` value (test).
  3. A firestore-rules-tester/search test proves a minor with a fresh `public_profiles` doc
     is absent from `searchUsers` results.
  4. **Don't** implement items 2-4 from the ticket in this pass (opt-in toggle, group-DM CF
     gate, `setLifecycleStage` defense-in-depth) — file a follow-up ticket for them if not
     completed; this slice is search-suppression only.

### Batch D — tagging
- [ ] **[Tier A] BUT-1475** — Stop full-collection ingredients fetch per session + hourly.
  disposition: build. requiresPlanMode: false. router: single (Software Architect, Product
  Manager).
  Files: `lib/repositories/firebase_ingredient_repository.dart`, plus tests.
  Acceptance:
  1. The ingredient repository no longer fetches the full ~5.6k-doc collection on first use
     each session — a version-stamped Storage snapshot or delta-fetch mechanism replaces it.
  2. The hourly full-collection re-fetch is removed/replaced.
  3. Ingredient data served to callers (tagging, search, etc.) is unchanged in content — a
     test proves parity between the old full-fetch result and the new snapshot/delta result
     for a sample set.
  4. **Don't** change the ingredient register's write path — read-path only.

- [ ] **[Tier A] BUT-1489** — CI-gate the tag scorecard. disposition: build.
  requiresPlanMode: false. router: single (DevOps/SRE, QA, Release Manager).
  Files: `.github/workflows/test.yml`, reads `test/corpus/tag_scorecard_test.dart`.
  Acceptance:
  1. `test/corpus/tag_scorecard_test.dart` runs in the CI suite matrix — visible as a CI job.
  2. A numeric accuracy floor gate is enforced (mirroring the BUT-1443 CRF golden-gate
     pattern) — CI fails if the scorecard drops below the floor.
  3. The floor value is documented (comment or config) so a future regression is traceable
     to a specific threshold, not a magic number.

- [ ] **[Tier A] BUT-1473** — Capture tagging corrections (allergen overrides first).
  disposition: build. requiresPlanMode: false. router: single (Data/ML Engineer — parsing &
  tagging integrity).
  Files: `lib/services/tagging/tag_editing_service.dart`,
  `lib/services/tagging/tag_resolution_service.dart`, new `tag_overrides_log` write path,
  plus tests.
  Acceptance:
  1. Saving an allergen tag override writes a `tag_overrides_log` doc capturing tag,
     direction, and the triggering ingredients from `TagDecision` (test).
  2. The override save's existing display behavior (badge changes) is unchanged — capture is
     additive telemetry only.
  3. **Don't** implement dietary/other tag capture yet — allergen overrides first, per the
     ticket.

### Batch E — menu-signals
- [ ] **[Tier A] BUT-1474** — Log menu engagement (swap-rate signal). disposition: build.
  requiresPlanMode: false. router: single (Data Analyst/BI, Growth, Monetization, Product
  Manager). **Step-0 finding: `menu_generated` already fires** (`firebase_analytics_repository.dart:400`,
  `winback_attribution_service.dart`, `analytics_service.dart`) — the ticket's premise is
  half-stale. Only `menu_recipe_swapped` is genuinely missing (zero hits repo-wide).
  Files: `lib/services/analytics/analytics_events.dart`, the recipe-swap call site
  (`lib/viewmodels/menu/weekly_menu_plan_viewmodel.dart` or `menu_generator.dart`'s
  `swapSingleRecipe`), plus tests.
  Acceptance:
  1. A `menu_recipe_swapped` Firebase Analytics event fires on a recipe swap in the weekly
     menu (test).
  2. The swap event carries enough context (menu id or week reference) to compute a
     swap-rate-per-menu metric later.
  3. **Don't** re-add `menu_generated` — verify it already fires and leave it as-is; adding a
     duplicate call site is a regression, not a fix.

- [ ] **[Tier A] BUT-1613 (BUT-1323 slice 4)** — Per-day portion adjustment by present count.
  disposition: build. requiresPlanMode: false. router: single (Product Manager). Verified
  premise still holds: no `servings`/`portion` adjustment tied to `presentMemberIdsFor` exists
  in `menu_generator.dart` today.
  Files: `lib/viewmodels/menu/menu_generator.dart`, `lib/viewmodels/menu/weekly_menu_plan_viewmodel.dart`,
  plus tests.
  Acceptance:
  1. A day with a present count set (per slice 2's per-weekday presence) generates that
     day's portions/servings scaled to the present count (test: 3 present → 3 servings).
  2. A day with no presence selection keeps today's current default serving behavior
     unchanged (test).
  3. **Don't** touch allergen filtering or generation-pool scoping — this ticket is
     presentation/serving-size only, per BUT-1625's explicit boundary between safe presence
     uses (display/portions) and unsafe uses (allergen filtering).

### Batch F — tech-debt-viewmodels
- [ ] **[Tier A] BUT-1607** — Migrate a slice of the remaining ~56 ChangeNotifier ViewModels
  to BaseViewModel (BUT-520 continuation). disposition: build. requiresPlanMode: false.
  router: single (Software Architect, Product Manager).
  Files: 2-3 ViewModels under `lib/viewmodels/shopping/` (chosen to stay file-disjoint from
  every other batch this sprint), plus their existing test suites.
  Acceptance:
  1. At least 2 ViewModels currently `extends ChangeNotifier` are migrated to
     `extends BaseViewModel`.
  2. Each migrated ViewModel's existing test suite is re-run and passes after the constructor
     change (a base-class change un-matches mocktail stubs — re-run, don't just skip).
  3. No user-visible behavior change — confirmed by unchanged test assertions beyond the
     base-class swap.
  4. Ticket stays open afterward (partial slice of ~56) — don't close it Done; note progress
     in a comment instead.

## Obsolete (git/code shows the premise gone — close, don't build)
- **BUT-1612** ("BUT-1323 slice 3: apply per-member dislikes in the present-scoped menu
  filter") — its dependency (`presentMemberIds` fed from `presentUnionForGeneration()`) was
  deliberately **removed** in BUT-1611's rebuild (`ca4ba8b70`, 2026-07-17) after a
  high-effort review found it narrowed allergen filtering below the household baseline.
  Verified via grep: `menu_generator.dart`'s `presentMemberIds` field is never set from
  outside the class today. Building dislikes-filtering on top of a disconnected feed would
  ship dead code. The proper redesign track (if wanted) is **BUT-1625**, which itself needs
  Malin's go/no-go (see below) before any implementation.

## Needs Malin (speculative / contestable / ops-blocked / out of mechanism — not built)
- **BUT-1625** — Safe present-aware menu generation. The ticket is explicitly framed as
  "IF product wants generation tuned to who's present" — a real product decision on a
  children's-allergen-safety surface, not a mechanical fix. The safe household-wide baseline
  already ships (BUT-1611/BUT-1464); this only matters if you want menu generation itself
  (not just display/portions) narrowed to who's present on a given day. Recommend: leave
  parked unless you specifically want this; if you do, it needs a dedicated plan-mode pass
  against the ticket's 4 written safety requirements, not a routine autonomous slice.
- **BUT-1499** — Collaborative weekly menu (realtime edit + slot voting) is fully coded but
  never wired to a live view. The ticket's own acceptance criterion #1 is "Decide: wire it up
  or park it." Wiring up a dormant social/realtime feature adds real support surface
  pre-launch; parking it means downgrading MENU-07/08/09 in the feature inventory from
  Verified. Genuinely your call either way — recommend picking one explicitly rather than
  leaving it dormant-but-marked-Verified (that's a live accuracy gap in the feature inventory
  today).
- **BUT-1472** — `parse_corrections_v2`/`llm_response_samples` have no consumer; the ticket
  itself offers two forks — build a consumer (admin export + dashboard metric) or turn off
  the write path. Recommend the cheap "turn off" path per the cost-minimization principle,
  unless you actually want the corrections-mining tool built — that's a real investment
  decision, not a bug fix.
- **BUT-1176** — Optional `custom_lint`/AST upgrade for subscription-disposal linting. The
  ticket self-describes as "pick up only if custom_lint is being added for other reasons" —
  that condition isn't met. Recommend: drop or leave parked; zero production leaks found by
  the original audit, arch-test guard already covers the common regression.
- **BUT-880** — PITR restore drill against a non-prod Firebase project. Already labeled
  `need-malin` in Linear. Ops-blocked: needs either the BUT-451 staging project or a
  throwaway project + your time for a multi-hour manual drill — not autonomously buildable.
  Recommend: do it, but it's an ops task for you, not a sprint pick.
- **BUT-1619 / BUT-1620 / BUT-1621** — Delivery-engine hardening tickets. Their target files
  (`plugins/delivery/workflows/sprint-execute-parallel.js`, the workflow-guards hook) live in
  **C:/claude-plugins**, a different git repo from this Butlery checkout, shipped via
  `node tools/fanout-update.mjs` from that repo — not this sprint's commit/worktree
  mechanism. Recommend: pick these up from a claude-plugins-specific session (or the janitor
  routine there), not a Butlery app sprint.

## Excluded this round (sequencing, not rejection)
- **BUT-1501** (CRF/NER cascade + assisted-import correction capture) — overlaps file-wise
  and in spirit with BUT-1469 (both widen correction capture beyond URL imports). Selecting
  both risks two agents editing the same import-strategy files in parallel. BUT-1469 is
  broader scope + higher priority; revisit BUT-1501 next sprint once BUT-1469 has landed —
  some of its acceptance may already be covered.

## Deviation log
(none yet — Phase 1 only, no implementation this pass)

---

## 2026-07-16 parallel-sprint pile — status (archived)

**Shipped to main this session (each reviewed cold + fixed, tests green):**
- BUT-1611 — per-meal weekly-menu presence (rebuilt from the wrong per-day design; removed
  the allergen-unsafe generation-scoping → BUT-1625). `ca4ba8b70`
- BUT-1618 — rule-dialog property dropdown derives from the shared vocabulary. `20e68a79a`
- BUT-1609 — "Minderårigt konto" moderation badge (+ a real watchIsAdmin spinner-strand fix). `f0b046b8e`
- BUT-1519 — one shared Butlery-betyget rating pill + shared formatter. `3b0364475`
- BUT-1623 — 3 admin onCall callables classified; app-check guard green (14/14). `919569e1a`

**Remaining 3 — deliberately NOT landed tonight (need fresh, careful attention):**
- [x] **BUT-1518** — re-selected this sprint (Batch A), scoped strictly to the ticket's
  log-only intent this time (prior uncommitted attempt over-scoped into a data field — lost,
  tree was clean at Phase 1 start).
- [x] **BUT-1612** — closed as obsolete this sprint; see Obsolete section above.
- [x] **BUT-1469** — re-selected this sprint (Batch B).

## Follow-ups filed this session (2026-07-16)
- BUT-1624 — a data-writing CF is an unreviewable git binary blob (one NUL byte). Re-selected
  this sprint (Batch A).
- BUT-1625 — safe present-aware menu generation (deferred from BUT-1611; also the home for
  BUT-1612's dislikes redesign). Parked pending Malin's go/no-go — see Needs Malin above.

---

## ⚠️ 2026-07-18 sprint OUTCOME — died on session usage limit (resets 4:20am), NOT shipped

The sprint implemented ~9 tickets and its REVIEW gates passed (code-reviewer/testing/
firebase-security/cloud-functions all ok), but the adversarial-VERIFY + completeness + ship
phases all died on the usage limit. So: **commit=null, pushed=false** — nothing committed.

- **done (verified true):** BUT-1518 (correctly scoped LOG-ONLY telemetry this time).
- **inReview (implemented, review-gates-passed, but UNVERIFIED + UNCOMMITTED in the tree):**
  BUT-1624, 1469, 1454, 1475, 1489, 1473, 1474, 1607.
- **obsolete:** BUT-1612, 1613.
- **needsApproval (product decisions — parked, correct):** 1625, 1499, 1472, 1176, 880, 1619/1620/1621.

**The pile is uncommitted (partly half-staged) in the main tree. Backed up to
scratchpad/sprint-2026-07-18-backup/ (full-diff.patch + newfiles/).**

### SALVAGE (do this AFTER 4:20am reset, before any new sprint — the dirty tree will abort one):
1. Ground-truth from git + the backup; do NOT trust the sprint's gates:ok (it can push past
   forged markers — proven twice this session).
2. Per ticket: re-run the real commit-gate specialists on its actual diff + /code-review; the
   backend/CF ones (1518 done, 1624/1454 touch functions/src + firestore.rules) need cloud-functions
   + firestore-rules-tester; 1454 is a minor-privacy full-panel ticket — treat as high-stakes.
3. Fix findings, then pathspec-commit each ticket separately.
4. 1454 touches firestore.rules → needs firestore-rules-tester (the sprint's rules-tester gate
   showed ok:false — i.e. NOT satisfied). Verify rules carefully.

### 2026-07-18 — PII-in-logs finding ADDRESSED on the uncommitted BUT-1518 pile
Background security review flagged raw `uid` in the `pool_key_dimensions` info log in
functions/src/ratings/canonical-rating-aggregation.ts. Fixed BOTH raw-uid log lines
(the info telemetry + the transient-maturity warn) to `uidHash: hashUid(uid)`; test
`test:canonical-rating-aggregation` green (21/21), C10 assertion now checks
`line.uidHash === hashUid("u1")` AND `line.uid === undefined`. Do NOT re-flag at salvage —
already closed. (Still needs the cloud-functions-specialist gate at commit time.)

---

## ✅ SALVAGE COMPLETE — 2026-07-18 (all 7 batches shipped to main)

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
- **workflow-map.stale** — re-trace the 11 trigger flows (session-wide, incl. 1611/1609 +
  1473/1518/1475) and update docs/onboarding/workflow-map.html JSON. Deferred to a dedicated pass.
- **BUT-1454**: enforcement is client-side; firestore.rules still permits minor isSearchable:true
  (future discovery opt-in) — rules-layer follow-up.
- **BUT-1469**: some URL structured/user-assisted fallback tiers don't re-tag source (accepted Low).
- **BUT-1475**: delta refresh can't observe deletions until next forceRefresh/restart (documented in code).
