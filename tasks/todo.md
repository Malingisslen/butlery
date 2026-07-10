# Sprint 2026-07-10 — Correctness/reliability burndown (8 tickets, 4 area batches)

Selection context: the prior sprint-salvage plan (fixing the 2026-07-09 parallel sprint's
6 review findings) is fully shipped — `fc5f941e5` (all 5 tickets' fixes + BUT-1512 wildcard
test) and `d31a54bdb` (lesson recorded), tree clean, archived below. This is a fresh
Selection pass. Linear MCP was up; gathered the Butlery backlog (Backlog/Todo/In
Progress/Triage, ~200 tickets scanned across priority + state slices), `tasks/todo.md`
(prior plan, done), and 7-day git log (no BUT-XXX in it maps to a still-open ticket —
`obsolete` is empty).

**Mandate-gate note:** two "autonomous"-labeled candidates carried an explicit Malin
annotation ("decide later" / "decide direction later") in the ticket body itself — that
overrides the label. Both moved to `needsApproval` instead of being built. See below.

## Batch A — Import & search reliability (area: import)

- [ ] **[Tier A] BUT-1531 — Dead `butlery://import` deep link** (`build`)
  Files: `lib/core/bootstrap/handlers/deep_link_handler.dart`, a new/updated journey test.
  Fix: the host-validation guard rejects `host=='import'` (the actual host `Uri.parse`
  produces for `butlery://import?url=...`) before reaching the import branch — whitelist
  `import` alongside `butlery.app`.
  Stakeholders (router: single): Growth Marketer/ASO, Information Architect/Wayfinding.
  **requiresPlanMode: true** (single + priority=High ≤2) — risk-gated plan expansion below.
  Acceptance:
  - [ ] Guard accepts `host=='import'` as a valid custom-scheme host alongside `butlery.app`.
  - [ ] New/updated test asserts `butlery://import?url=<value>` routes to the import flow
        with the URL argument extracted.
  - [ ] Guard still rejects other unrecognized hosts (no regression — existing/added test).

- [ ] **[Tier A] BUT-1547 — Algolia search swallows all errors as empty results** (`build`)
  Files: `lib/repositories/algolia/algolia_search_repository.dart` (+ test).
  Fix: surface a degraded/error signal (flag, exception, or logged event) when the
  underlying Algolia call fails, instead of returning empty results indistinguishable from
  a genuine no-match search.
  Stakeholders (router: single): Data/Integrations Engineer, Vendor/Procurement Manager.
  requiresPlanMode: false (single, Medium priority, no security label).
  Acceptance:
  - [ ] A distinguishable degraded/error signal is emitted on Algolia call failure.
  - [ ] Test simulating a failure asserts the degraded signal is present.
  - [ ] Genuine "no matches" case still returns a normal empty result with no error flag.

## Batch B — Data-integrations hardening (area: backend)

- [ ] **[Tier A] BUT-1556 — recordUsage swallows transaction failure silently** (`build`)
  Files: `lib/services/import/import_rate_limiter.dart` (+ test).
  Fix: add a bounded retry on transient error codes; surface an error signal on persistent
  failure instead of a silent success-path return (cost-tracking under-count today).
  Stakeholders (router: single): Data/Integrations Engineer, FinOps, Monetization Lead.
  requiresPlanMode: false (single, Medium, no security label).
  Acceptance:
  - [ ] Transaction failure inside `recordUsage` is no longer silently swallowed.
  - [ ] A bounded retry runs on transient codes; persistent failure surfaces an error signal.
  - [ ] Test simulates a transaction failure and asserts retry + error-signal behavior.

- [ ] **[Tier A] BUT-1548 — CircuitBreaker half-open has no in-flight guard** (`build`)
  Files: `lib/core/circuit_breaker.dart` (+ test).
  Fix: convert the half-open getter to a method with an in-flight guard so only one probe
  passes through concurrently (today all concurrent calls pass the single probe).
  Stakeholders (router: single): Data/Integrations Engineer.
  requiresPlanMode: false (single, Medium, no security label).
  Acceptance:
  - [ ] Half-open check is a method (not a getter) with an in-flight guard.
  - [ ] Test with concurrent calls during half-open asserts exactly one probe passes.
  - [ ] Closed/open transitions unaffected (existing tests still pass).

## Batch C — Ingredient pipeline hygiene (area: tagging/backend)

- [ ] **[Tier A] BUT-1576 — Cap the "och" compound-split fan-out** (`build`)
  Files: `lib/utils/text/ingredient_parser.dart` (or its `lookupFromRaw` call site in
  `lib/services/tagging/ingredient_lookup_service.dart`) (+ test).
  Fix: cap the "och"-split at the split site (~8 parts) — today it's unbounded and each part
  walks the full Firestore lookup ladder (unbounded read amplification / cost risk).
  Stakeholders (router: single): Software Architect, Product Manager.
  requiresPlanMode: false (single, Medium, no security label).
  Acceptance:
  - [ ] The split is capped at a fixed bound instead of unbounded.
  - [ ] Test with a many-"och" line asserts the cap (no unbounded fan-out).
  - [ ] Normal 1-2-"och" case behavior unchanged (existing tests still pass).

- [ ] **[Tier A] BUT-1579 — Extend digit-safe split to aliases_en/search_terms** (`build`)
  Files: `functions/src/admin/sync-ingredients-core.ts` (+ tests).
  Fix: apply the same `/;|,(?!\d)/` digit-safe split (already live for `aliases_sv` since
  BUT-1571) to the `aliases_en` and `search_terms` `parseList` calls.
  Stakeholders (router: single): Vendor/Procurement Manager.
  requiresPlanMode: false (single, Low priority).
  Acceptance:
  - [ ] `aliases_en` and `search_terms` `parseList` calls use the digit-safe split regex.
  - [ ] Regression test: a decimal-comma value in either column survives intact (no split).
  - [ ] Regression test: a genuine comma-typed list in either column still splits correctly.

## Batch D — Social/account cascade correctness (area: social)

- [ ] **[Tier A] BUT-1506 — Friend-count double-decrement on onUserDeleted retry** (`build`)
  Files: `functions/src/cleanup/on-user-deleted.ts`,
  `functions/src/__tests__/on-user-deleted.integration.test.ts`.
  Fix: `updateFriendCounts` reuses the stale top-of-function `friendsSnapshot` for the
  decrement step; a retried cascade (the file rethrows specifically to trigger retries)
  double-decrements `friendsCount` for already-processed friends with no self-heal. Make the
  decrement idempotent (track processed friend IDs, or derive from current reverse-friendship
  state) rather than the stale snapshot.
  Stakeholders (router: **full-panel** — high-stakes core: Legal Counsel, Product Manager,
  Security Architect, Software Architect + matched Privacy/DPO, FinOps, Vendor/Procurement,
  DBA/Data-layer Engineer).
  **requiresPlanMode: true** (full-panel) — risk-gated plan expansion below.
  Acceptance:
  - [ ] A retried invocation does not double-decrement `friendsCount` for friends already
        processed in the prior (failed) run.
  - [ ] The fix does not rely on the stale top-of-function `friendsSnapshot` for the
        decrement step.
  - [ ] New test in `on-user-deleted.integration.test.ts` simulates a retried invocation and
        asserts `friendsCount` decrements exactly once per friend.
  - [ ] Other steps' existing best-effort/idempotent single-invocation behavior is unchanged.

- [ ] **[Tier A] BUT-1505 — Family-rating denormalization race** (`build`)
  Files: `lib/services/family/family_rating_service.dart` (+ test).
  Fix: `_denormalizeFamilyAverage` is a non-transactional client read-then-write of
  `familyAverage`/`familyRatingCount` — two near-simultaneous ratings from different devices
  can drop a contribution (last-write-wins). Wrap in a transaction client-side (proportionate
  fix; the ticket's larger alternative — moving the recompute server-side to mirror the
  public aggregate's Cloud Function trigger — is a bigger architecture change, not taken here).
  Stakeholders (router: single): Software Architect, Product Manager.
  requiresPlanMode: false (single, Medium, no security label).
  Acceptance:
  - [ ] The read-then-write of `familyAverage`/`familyRatingCount` runs inside a transaction
        (no longer a plain non-transactional read-then-write).
  - [ ] Test simulating two near-simultaneous rating writes for the same recipe asserts both
        contributions land in the final average/count (no silent drop).
  - [ ] The existing "recompute failure never fails the underlying rating write" guarantee
        is preserved.

## Risky-ticket plan blocks (Phase 1.5 — risk-gated, no halt)

**BUT-1531** (single + priority≤2): blast radius is one handler function
(`deep_link_handler.dart`'s host-validation guard) plus its journey test; no schema/API
change. Rollback: revert the one-line host whitelist + the added test. Product-intent flag:
none — this restores an already-intended entry point (share-target import), not a new
behavior.

**BUT-1506** (full-panel, high-stakes core): blast radius is the `onUserDeleted` Cloud
Function cascade step 4 (friend-count decrement) — read carefully alongside steps 1-3
(reverse-friendship deletion) before changing the decrement source. Product-intent flag:
none (pure correctness/idempotency fix, no behavior change to what gets deleted). Rollback:
revert the idempotency-tracking change; the existing (buggy but currently-shipped) behavior
returns. Must not touch the reverse-friendship deletion logic (step 1) — scope is the
decrement step only. GDPR angle: this fixes data correctness for OTHER users' friend counts
after a deletion cascade retry — no PII handling change, no new export/erasure surface.

## Needs your call (NOT built — mandate gate)

- **BUT-1523** — "Decide + wire the 'socialFeatures' consent toggle (currently gates
  nothing)." The ticket body itself says *"Malin decision 2026-07-04: decide direction
  later"* — despite the `autonomous` label, this is explicitly parked for your call between
  (a) gate social writes on the toggle or (b) remove the toggle. Not built.
  Recommendation: worth deciding soon (GDPR "consent theatre" risk — a control that visibly
  does nothing) but it's a product/legal call, not a bug fix.
- **BUT-1525** — "PII (name/address) in shareable URL slugs survives both PII scrubbers."
  Same pattern: ticket body says *"Malin decision 2026-07-04: decide later"* — decide between
  tokenising slug segments before the scrub heuristics run, or accepting it as a documented
  deviation if slugs are deemed low-risk. Not built.
  Recommendation: lean toward tokenising (cheap, closes a real log/analytics leak vector) but
  flagging rather than deciding for you since a previous session already logged your intent
  to decide it personally.

## Needs you (Tier D)

None this sprint — no ops/console/deploy-blocked candidates were selected into this batch.

## Post-sprint steps (Phase 3 checklist — not yet run)

1. `dart analyze --fatal-infos` full run.
2. File follow-ups for any deferred sub-scope found during implementation.
3. Commit per the `reviewGates` table (code-reviewer + testing-specialist on all `.dart`
   diffs; `firebase-backend-security` + `cloud-functions-specialist` + `firestore-rules-tester`
   are NOT triggered by the current file list — no `lib/repositories/`,
   `lib/services/{firebase|firestore|auth|user|gdpr}`, or `firestore.rules` touched; BUT-1506
   and BUT-1579 touch `functions/src/` so `cloud-functions-specialist` DOES trigger there).
4. Push (no deploy trigger on push per config).
5. Transition: Tier A + all-pass → Done; any failed/unclear criterion → In Review.
6. Fold deviation log back per Phase 3 rule 6.
7. Final plain-language report.

## Deviation log

(none yet — Selection phase only; Execution has not started)

## What this means in plain language

- This sprint fixes eight small-but-real bugs found by earlier automated code scans — things
  like a broken "import from outside the app" link, a search box that goes silently blank
  during an outage instead of saying so, a friend-count that can get corrupted twice when an
  account deletion retries, and a family rating that can quietly lose one person's star if two
  people rate the same dish at almost the same moment.
- Nothing here changes how any screen looks or adds a new feature — these are all "make the
  existing thing work correctly" fixes, each with its own test.
- Two related tickets were deliberately NOT built this sprint (a social-sharing consent toggle
  and a URL-privacy issue) because an earlier note from you said you wanted to decide those
  yourself rather than have them auto-fixed — they're flagged above for your call.
- Risk is low: every fix is scoped to one file, reviewed by the usual automated gates before
  anything ships, and each is a clean revert if something looks wrong afterward.

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
