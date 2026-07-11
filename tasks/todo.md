# Sprint 2026-07-11 — Reliability + compliance burndown (10 tickets, 5 area batches)

Selection context: Linear MCP up. Gathered Butlery Backlog/Todo/In Progress/Triage
(149 Backlog + 8 Todo + 0/0), `tasks/todo.md` (prior 2026-07-10 plan), and 7-day git log.
The prior plan's Batches C+D (BUT-1576, BUT-1579, BUT-1506, BUT-1505) shipped in
`8754a5b1a` + salvage follow-up `09d1f8ca6` (BUT-1582/1583) — confirmed via `git show
--stat`. Its Batches A+B (BUT-1531, BUT-1547, BUT-1556, BUT-1548) were **never
implemented** — still sitting in Todo (briefly mis-cancelled 22:23–22:28 on 07-10, then
restored; no code touches `deep_link_handler.dart` or `algolia_search_repository.dart`
in the git log). Carried forward unchanged into this sprint with their original
acceptance criteria — nothing about them has changed.

`obsolete`: none — no BUT-XXX in the 7-day git log maps to a still-open ticket. BUT-1149
(coverage floor) is mentioned in `fc5f941e5` but that commit only re-measured/reported
the gap, didn't close it — legitimately still open, not selected this sprint (large,
CI-shaped, not a quick win).

**Mandate-gate note:** BUT-1524 ("Decide: age-maturity gate on comment posting") carries
an explicit Malin annotation in the ticket body — *"Malin decision 2026-07-04: decide
later"* — despite the `autonomous` label. Moved to `needsApproval`, joining the two
carried-forward from last sprint (BUT-1523, BUT-1525, same pattern). By contrast BUT-1521,
BUT-1540, and BUT-1539 each carry an explicit Malin decision to **build/enforce/retire**
in the ticket body — those override the "security/social label ⇒ pause" instinct and are
scored `build`.

All 5 batches routed `single` via `tools/stakeholder_router.py` (no `full-panel`, no
`high_stakes_hits`) — panel membership recorded per batch below.

## Batch A — Deep-linking (area: import) — shared files, one batch

- [ ] **[Tier A] BUT-1531 — Dead `butlery://import` deep link** (`build`)
  Files: `lib/core/bootstrap/handlers/deep_link_handler.dart`, a new/updated journey test.
  Fix: the host-validation guard rejects `host=='import'` (the actual host `Uri.parse`
  produces for `butlery://import?url=...`) before reaching the import branch — whitelist
  `import` alongside `butlery.app`.
  Stakeholders (single): Growth Marketer/ASO, Information Architect/Wayfinding.
  **requiresPlanMode: true** (single + priority=High ≤2).
  Acceptance:
  - [ ] Guard accepts `host=='import'` as a valid custom-scheme host alongside `butlery.app`.
  - [ ] New/updated test asserts `butlery://import?url=<value>` routes to the import flow
        with the URL argument extracted.
  - [ ] Guard still rejects other unrecognized hosts (no regression — existing/added test).

- [ ] **[Tier A] BUT-1540 — Enforce shared-link expiry on the live recipe path** (`build`,
  Malin decision 2026-07-04: "enforce expiry — you want expiring links")
  Files: `lib/core/bootstrap/handlers/deep_link_handler.dart`, `lib/services/deep_link_service.dart` (+ test).
  Fix: wire the existing `isLinkValid` expiry check into the live path before navigation
  (today expiry logic exists but is never called, so shared links never actually expire).
  Stakeholders (single): Growth Marketer/ASO, Information Architect/Wayfinding.
  requiresPlanMode: true (single + security label).
  Acceptance:
  - [ ] The live recipe navigation path calls `isLinkValid` (or equivalent expiry check)
        before navigating to a shared recipe.
  - [ ] A test with an expired link asserts navigation is rejected/redirected with a
        user-visible signal, not a silent success.
  - [ ] A still-valid (non-expired) shared link continues to navigate normally (regression
        test).

## Batch B — Import/search hardening (area: import)

- [ ] **[Tier A] BUT-1547 — Algolia search swallows all errors as empty results** (`build`)
  Files: `lib/repositories/algolia/algolia_search_repository.dart` (+ test).
  Fix: surface a degraded/error signal (flag, exception, or logged event) when the
  underlying Algolia call fails, instead of returning empty results indistinguishable from
  a genuine no-match search.
  Stakeholders (single): Data/Integrations Engineer, Vendor/Procurement Manager.
  requiresPlanMode: false (single, Medium priority, no security label).
  Acceptance:
  - [ ] A distinguishable degraded/error signal is emitted on Algolia call failure.
  - [ ] Test simulating a failure asserts the degraded signal is present.
  - [ ] Genuine "no matches" case still returns a normal empty result with no error flag.

## Batch C — Backend resilience (area: backend)

- [ ] **[Tier A] BUT-1556 — recordUsage swallows transaction failure silently** (`build`)
  Files: `lib/services/import/import_rate_limiter.dart` (+ test).
  Fix: add a bounded retry on transient error codes; surface an error signal on persistent
  failure instead of a silent success-path return (cost-tracking under-count today).
  Stakeholders (single): Data/Integrations Engineer, FinOps, Monetization Lead.
  requiresPlanMode: false (single, Medium, no security label).
  Acceptance:
  - [ ] Transaction failure inside `recordUsage` is no longer silently swallowed.
  - [ ] A bounded retry runs on transient codes; persistent failure surfaces an error signal.
  - [ ] Test simulates a transaction failure and asserts retry + error-signal behavior.

- [ ] **[Tier A] BUT-1548 — CircuitBreaker half-open has no in-flight guard** (`build`)
  Files: `lib/core/circuit_breaker.dart` (+ test).
  Fix: convert the half-open getter to a method with an in-flight guard so only one probe
  passes through concurrently (today all concurrent calls pass the single probe).
  Stakeholders (single): Data/Integrations Engineer.
  requiresPlanMode: false (single, Medium, no security label).
  Acceptance:
  - [ ] Half-open check is a method (not a getter) with an in-flight guard.
  - [ ] Test with concurrent calls during half-open asserts exactly one probe passes.
  - [ ] Closed/open transitions unaffected (existing tests still pass).

- [ ] **[Tier A] BUT-1545 — LlmTier retry storm** (`build`)
  Files: `lib/services/parsing/tiers/llm_tier.dart` (+ test).
  Fix: the retry predicate string-matches on error text, so it misclassifies a typed
  `LlmException` and retries non-retryable cases (rate-limits, invalid-argument) — a
  cost/latency storm. Pass a typed `shouldRetry` predicate instead of string matching.
  Stakeholders (single): Data/Integrations Engineer, Data/ML Engineer, FinOps, Performance
  Engineer.
  requiresPlanMode: false (single, Medium, no security label).
  Acceptance:
  - [ ] Retry logic uses a typed `shouldRetry` predicate, not string-matching on the
        exception message.
  - [ ] Test with a typed rate-limit/invalid-argument exception asserts NO retry occurs.
  - [ ] Test with a genuinely transient/retryable typed exception asserts retry still
        occurs (no regression).

## Batch D — Analytics correctness (area: analytics)

- [ ] **[Tier A] BUT-1550 — Lifecycle classifier double-counts dormant/churned boundary** (`build`)
  Files: `lib/services/analytics/lifecycle_stage_classifier.dart` (+ test).
  Fix: the classifier uses `inDays` truncation, double-counting the exact boundary day
  between dormant and churned. Compare millisecond thresholds instead of truncated day
  counts.
  Stakeholders (single): Data Analyst/BI, Growth Marketer/ASO, Monetization Lead, Product
  Manager.
  requiresPlanMode: false (single, Medium, no security label).
  Acceptance:
  - [ ] The dormant/churned boundary comparison uses millisecond thresholds, not truncated
        `inDays`.
  - [ ] A test at the exact boundary instant asserts the user classifies into exactly one
        stage (not both).
  - [ ] Existing non-boundary classifications are unchanged (existing tests still pass).

- [ ] **[Tier A] BUT-1539 — Retire dead subscription_tier analytics** (`build`, Malin
  decision 2026-07-04: "retire entirely")
  Files: `lib/services/analytics/analytics_events.dart`,
  `lib/services/analytics/user_property_bootstrap.dart` (+ test cleanup).
  Fix: delete the `subscription_tier` analytics property and `emitSubscriptionTier` —
  dead-premise, hardcoded 'free' forever since consumer subscriptions were dropped.
  Stakeholders (single): Data Analyst/BI, Monetization Lead, Product Manager.
  requiresPlanMode: false (single, Medium, no security label).
  Acceptance:
  - [ ] `subscription_tier` analytics property and `emitSubscriptionTier` are deleted (no
        dead hardcoded-'free' emission remains).
  - [ ] No remaining call sites reference the removed property/method (`dart analyze` clean).
  - [ ] Existing analytics tests unrelated to subscription_tier still pass (no regression).

## Batch E — Account/security compliance (area: account)

- [ ] **[Tier A] BUT-1521 — Persist Terms acceptance at signup** (`build`, Malin decision
  2026-07-04: "build it — ticketed, not urgent, do when picked up")
  Files: `lib/views/auth_view.dart`, `lib/services/user_service.dart`,
  `lib/repositories/firebase/firebase_user_repository.dart`,
  `lib/repositories/interfaces/user_repository.dart` (+ test).
  Fix: nothing currently records that a user accepted the Terms (no `termsAcceptedAt`, no
  `termsVersion`) — a legal-provability gap. Mirror the existing persisted-consent pattern
  (ConsentService) to capture acceptance timestamp + version at signup; add a version field
  to the ToS reference.
  Stakeholders (single): Accessibility Specialist, Data Analyst/BI, Performance Engineer,
  Trust & Safety.
  **requiresPlanMode: true** (single + security label).
  Acceptance:
  - [ ] Signup persists `termsAcceptedAt` (timestamp) and `termsVersion` for the user,
        mirroring the existing ConsentService persisted-consent pattern.
  - [ ] The ToS reference carries an explicit version identifier the signup write points to.
  - [ ] A test asserts a new signup writes both fields; an existing already-signed-up user
        is unaffected (no regression/backfill side effect).

- [ ] **[Tier A] BUT-1551 — Account-deletion View bypasses AuthService** (`build`)
  Files: `lib/views/onboarding/onboarding_age_gate_blocked_view.dart`,
  `lib/services/auth_service.dart` (+ test).
  Fix: the view deletes the auth user directly instead of routing through the service
  layer. Add `AuthService.deleteCurrentAuthUser()` and route the View through it.
  Stakeholders (single): Accessibility Specialist, Data Analyst/BI, Performance Engineer,
  Trust & Safety.
  requiresPlanMode: false (single, Medium, no security label — tech-debt only).
  Acceptance:
  - [ ] `AuthService` gains a `deleteCurrentAuthUser()` method wrapping the Firebase
        auth-delete call.
  - [ ] `onboarding_age_gate_blocked_view.dart` routes its auth-user deletion through
        `AuthService` instead of calling Firebase auth directly.
  - [ ] A test asserts the view calls the service method (mockable) rather than a direct
        Firebase Auth API call.

## Risky-ticket plan blocks (Phase 1.5 — risk-gated, no halt)

**BUT-1531** (single + priority≤2): blast radius is one handler function
(`deep_link_handler.dart`'s host-validation guard) plus its journey test; no schema/API
change. Rollback: revert the one-line host whitelist + the added test. Product-intent
flag: none — this restores an already-intended entry point (share-target import), not a
new behavior.

**BUT-1540** (single + security label): blast radius is the same handler file plus
`deep_link_service.dart`'s existing (currently-unwired) `isLinkValid` check — wiring it in,
not writing new expiry logic. Must not change the expiry *policy* (duration/fields), only
enforce the existing one. Rollback: revert the call-site wiring; links go back to
never-expiring (the current, if unintended, behavior). Product-intent flag: none — Malin
already decided she wants expiry enforced (role-org scan Q&A, 2026-07-04).

**BUT-1521** (single + security label): blast radius spans the auth signup view down to
the user repository/interface — a genuine cross-layer touch (view → service → repository).
Must not touch existing users' records (backfill is explicitly out of scope — new-signup
only, per the ticket). Rollback: revert the two new fields + the write; no destructive
migration involved so a revert is clean. Product-intent flag: none — Malin already decided
to build this (2026-07-04).

## Needs your call (NOT built — mandate gate)

- **BUT-1523** — "Decide + wire the 'socialFeatures' consent toggle (currently gates
  nothing)." Ticket body: *"Malin decision 2026-07-04: decide direction later."* Carried
  forward unchanged from last sprint — not built.
  Recommendation: worth deciding soon (GDPR "consent theatre" risk) but it's a
  product/legal call between gating social writes on the toggle vs. removing it.
- **BUT-1525** — "PII (name/address) in shareable URL slugs survives both PII scrubbers."
  Ticket body: *"Malin decision 2026-07-04: decide later."* Carried forward unchanged —
  not built.
  Recommendation: lean toward tokenising slug segments (cheap, closes a real log/analytics
  leak) but it's flagged rather than decided for you since you already logged intent to
  decide it personally. (Related but separate: BUT-1546, a PII-scrubber hardening ticket for
  the opaque-key allowlist + list-valued URL scrubbing, was left in the backlog this sprint —
  not selected, not a decide-later item, just didn't make this round's cut.)
- **BUT-1524** — "Decide: age-maturity gate on comment posting (DMs/friend-reqs have it,
  comments don't)." Ticket body: *"Malin decision 2026-07-04: decide later."* New this
  sprint — not built.
  Recommendation: lean toward gating comments the same way (consistency, low cost — the
  helper already exists and is just unwired) unless you consider comments meaningfully
  lower-risk than DMs/friend-requests, in which case record it as an accepted deviation
  instead.

## Needs you (Tier D)

None this sprint — no ops/console/deploy-blocked candidates were selected into this batch.

## Post-sprint steps (Phase 3 checklist — not yet run)

1. `dart analyze --fatal-infos` full run.
2. File follow-ups for any deferred sub-scope found during implementation.
3. Commit per the `reviewGates` table (code-reviewer + testing-specialist on all `.dart`
   diffs; `firebase-backend-security` triggers on Batch B (`lib/repositories/algolia/`) and
   Batch E (`lib/repositories/firebase/`); `cloud-functions-specialist` does NOT trigger —
   no `functions/src/` files in this sprint's selection).
4. Push (no deploy trigger on push per config).
5. Transition: Tier A + all-pass → Done; any failed/unclear criterion → In Review.
6. Fold deviation log back per Phase 3 rule 6.
7. Final plain-language report.

## Deviation log

(none yet — Selection phase only; Execution has not started)

## What this means in plain language

- This sprint fixes ten small-but-real issues found by earlier automated code scans: a
  broken "import from outside the app" link, shared recipe links that never actually
  expire even though you asked for that, a search box that goes silently blank during an
  outage, three backend resilience gaps (a cost-tracking write that can fail silently, a
  circuit-breaker safety check that lets too many requests through at once, and an AI-cost
  control that retries requests it shouldn't), an analytics bug that can double-count a
  user's activity status, some dead tracking code being deleted, a missing legal record of
  when someone accepted your Terms of Service, and a cleanup so account deletion goes
  through the proper safety layer instead of a shortcut.
- Nothing here changes how any screen looks or adds a new feature — these are all "make
  the existing thing work correctly" fixes, each with its own test. Four of the ten
  (deep-link, algolia, and the two backend-resilience tickets) were meant to ship last
  sprint but got dropped by a sprint-tooling bug — they're carried forward untouched.
- Three related tickets were deliberately NOT built this sprint (a social-sharing consent
  toggle, a URL-privacy issue, and whether comments need the same anti-spam delay as
  direct messages) because you'd earlier said you wanted to decide those yourself — they're
  flagged above for your call.
- Risk is low: every fix is scoped to a small, named set of files, reviewed by the usual
  automated gates before anything ships, and each is a clean revert if something looks
  wrong afterward. Two items (the shared-link expiry fix and the Terms-acceptance record)
  get an extra up-front plan review because they touch security-labeled or cross-layer
  code — that's process, not a sign anything is riskier than it looks.

---

# Archived: Sprint 2026-07-10 — Correctness/reliability burndown

Partially shipped. Batches C+D (BUT-1576 parser fan-out cap, BUT-1579 digit-safe split,
BUT-1506 idempotent friend-cleanup, BUT-1505 family-rating race) shipped in `8754a5b1a` +
salvage follow-up `09d1f8ca6` (BUT-1582/1583 fixes from a post-ship review). Batches A+B
(BUT-1531, BUT-1547, BUT-1556, BUT-1548) were never implemented — carried forward into the
2026-07-11 sprint above unchanged.

---

# Archived: Sprint-salvage — 6 confirmed /code-review findings (SHIPPED 2026-07-10)

Fully implemented and committed: `fc5f941e5` (all 5 original fixes: BUT-1483 tagging config
isolation, BUT-1503 atomic-share correctness + notification, BUT-1466 menu allergen-trust
routing, BUT-1512 rules wildcard test, BUT-1149 CI floor status) + the 2 fix-pass findings
(menu_service untagged-exclusion regression test, social_recipe_sharing_service pre-access
construction-order fix) + `d31a54bdb` (lesson recorded: a parallel sprint's own "verified"
status is a claim, not a fact — run the workflow `/code-review` cross-file pass on staged
sprint output before file-scoped specialist gates).

Context: the parallel sprint (wf_31f86296) built 5 tickets but the pre-commit
`/code-review high` gate found 6 confirmed defects the sprint's own verification
missed. Malin decided (2026-07-09): fix everything, re-review, then commit the
full batch. Nothing has shipped to main yet; the work is staged.

## Fixes

- [x] **Finding 0/1 — BUT-1483 cross-recipe config split** (`tag_generator.dart`,
  `tagging_pipeline_runner.dart`). Root cause: BUT-1483 made `_phase1`/`_phase5`
  mutable on the single shared `TaggingService._tagGenerator`; under parallel
  retagging (`Future.wait` in retagging_scheduler) a sibling recipe's rebuild
  swaps phases mid-run. Fix: phases become final boot phases;
  `resolveConfigPhases()` returns an immutable per-run pair (memoised per
  version); the runner resolves ONCE per run and threads the pair into
  `runPhase1`/`runPhase5`/`runPhase5FromPhase1`. Update `tagging_service_test`
  stubs for the new signatures. Add a generator test proving a resolved pair is
  isolated from a later config change.
- [x] **Finding 2/4 — BUT-1503 accepted share stuck pending**
  (`recipe_share_request_module.dart`). `acceptRecipeShareRequest` aborts on
  `!shared` even when the primary memberPermissions write succeeded. Fix: treat
  a granted-primary as accepted (flip request status) even if the secondary
  shared_recipes write failed.
- [x] **Finding 3 — BUT-1503 recipient not notified**
  (`social_recipe_coordinator.dart`). Notification gated on the now-false
  result. Fix: notify when the recipient was actually granted access.
- [x] **Finding 5/7 — BUT-1466 menu override exclusion + dedup**
  (`menu_service.dart`). `_matchesConstraint` early-returns false on null
  tagResult, ignoring a manual FREE override; also duplicates `_passesGlobals`'
  trust loops. Fix: route through `MenuAllergenTrust` (honours override) and
  share one helper.
- [x] **Finding 6 — BUT-1512 missing friend_categories wildcard test**
  (`collection-group-wildcards-rules.test.ts`). Add the 6th catch-all wildcard.

## Verification
- `flutter test` the touched tagging + service + menu suites; `dart analyze`
  clean; re-run the specialist reviewers + a fresh `/code-review` before commit.

## Open questions
No architecture-changing unknowns — Malin approved the full fix-and-ship scope
via AskUserQuestion. Assumptions: (a) proportionate correctness fixes over
larger redesigns; (b) BUT-1503's "return false on persistent secondary failure"
stays (it's the intended signal) — only the downstream callers are corrected.

## What this means in plain language
- Same five improvements as before, but with the bugs the review caught now
  fixed: sharing won't leave requests stuck or people un-notified during a
  database hiccup; the menu builder respects your manual "gluten-free" marks;
  and the tagging fix is now safe when the app re-tags many recipes at once.
- You won't see anything new beyond the original five items working correctly.
- Risk: these are careful correctness fixes; each is re-reviewed before it
  lands, and everything is a clean revert if needed.

## Fix-pass review (2026-07-10) — 2 findings on the fixes themselves
- [x] CONFIRMED menu_service.dart: removing the null-tagResult early-return let
  untagged recipes slip past an excludedTags gate. Fix: exclude untagged when
  excludedTags present (conservative); add a regression test.
- [x] PLAUSIBLE social_recipe_sharing_service.dart: a throw from SharedRecipe.create
  after the primary save returns failed not partial. Fix: build the SharedRecipe
  BEFORE the primary memberPermissions save so a construction throw is pre-access.
