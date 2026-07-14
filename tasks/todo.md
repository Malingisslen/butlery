# Sprint 2026-07-14 — this-week follow-up burndown + carried GDPR fix

`/sprint-execute` Phase 1 selection. 6 tickets across 3 disjoint-file batches (parallel-safe).
State UUIDs: Todo 5a6d3faa · InProgress f8a3cf05 · InReview 9929b3b0 · Done 57dc8a84

**Step-0 grep-of-main sweep:** every candidate's target file/symbol was re-read on current
`main` before selection (not just `git log`). Confirmed still-live: BUT-1598's missing test
(index config genuinely un-asserted), BUT-1595's missing test (no test file exists for
`cleanupCollection`'s drain loop), BUT-1596's stale comment (index.ts:312-314 still only
describes the promotion case), BUT-1597's unlogged catch path (`_parseWithStrategy`'s
`catch (e)` block does not call `_logParseEvent`), BUT-1600's data gap (no member/diner-removal
reconciliation exists anywhere in `lib/services` or `functions/src`), and BUT-1544's two gaps
(no TTL/purge for `deletion_audit_logs.expireAt`; the consent-row starvation half was
independently confirmed already fixed by commit `3a01d8fcd`/BUT-1404, per the ticket's own
comment thread — so BUT-1544 in this sprint is narrower than its original text: TTL bullet
only). No candidate turned out to be obsolete.

**Backlog note:** Linear Backlog/Todo/Triage/In Progress was read (Todo had 2, Triage/In
Progress empty, Backlog ~large — 47 tickets carry the `autonomous` label). Per the standing
precedent from the 2026-07-11c/07-12 sprints, the broad autonomous tech-debt/refactor backlog
(god-object splits, ServiceLocator migrations, dead-flag cleanups, etc.) was scored at a title
level but not re-litigated — those were already triaged in prior passes and haven't changed.
Selection instead focused on this week's freshest, most concrete candidates: five follow-up
tickets filed against code that shipped in the last 48h (so Step-0 grep is maximally reliable),
plus one carried-forward real GDPR gap that a prior sprint's batch-drop left genuinely unbuilt
(BUT-1544, see its comment thread — re-laned `need-malin` not because it's speculative but
because the drop wasn't disclosed as a decision).

## Batch A — Backend cleanup + GDPR hygiene (functions/src, gate: cloud-functions-specialist)

### BUT-1598 — test gap: no index-config assertion for the social_requests (status, sentAt) composite [Tier A, build, router: single]
Step-0 confirmed: commit `6f0942408` added the composite (`firestore.indexes.json:102-109`,
status ASC + sentAt ASC) that `cleanupExpiredSocialRequests` needs, but no test pins it — a
future refactor could silently drop the line and nothing would fail until the weekly job
throws in production again.
- [ ] Add a test that parses `firestore.indexes.json` and asserts the `social_requests`
      (status, sentAt) composite is present with the correct field order/directions
- Acceptance: (1) new test asserts the exact composite (fields + directions) is present;
  (2) test fails if the index line is removed/altered — not a tautological always-pass check;
  (3) no production code changed, this is test-gap-only; (4) existing
  cleanup-expired-social-requests tests stay green
- Files: `functions/src/__tests__/cleanup-expired-social-requests.test.ts` (new)
- Gates: cloud-functions-specialist. Close: Done.

### BUT-1595 — test gap: cleanup-old-notifications pagination drain loop is untested (follow-up to BUT-1563) [Tier A, build, router: single]
Step-0 confirmed: `cleanupCollection` (`cleanup-old-notifications.ts:22-59`) has the
BUT-1563 drain loop live but genuinely no test file exists under `functions/src/__tests__/`
for it. The ticket's own 2026-07-12 salvage-review note adds a real edge: the loop only exits
on `snapshot.size < BATCH_LIMIT`, so a delete that silently returns fewer deletions than
requested (partial-batch/permission edge, not the normal atomic-batch case) could re-return a
full page indefinitely.
- [ ] Test: seeds > BATCH_LIMIT expired docs, asserts multi-page drain to zero
- [ ] Test: a sub-full final page terminates the loop; an empty collection fast-exits
- [ ] Test + fix: a fake `batchDeleteDocs` that deletes fewer docs than requested must not spin
      forever — add a bounded-iteration safety net if the current loop lacks one
- Acceptance: (1) multi-page happy-path drain is proven by a test; (2) short-final-page and
  empty-collection exits are proven; (3) a non-shrinking-page scenario is proven bounded (test
  + guard, not just a comment); (4) don't change the RETENTION_DAYS/collections list, only the
  drain loop's termination safety
- Files: `functions/src/__tests__/cleanup-old-notifications.test.ts` (new),
  `functions/src/cleanup/cleanup-old-notifications.ts` (only if the iteration-cap guard is
  needed)
- Gates: cloud-functions-specialist. Close: Done.

### BUT-1596 — stale comment at functions/src/index.ts:312-314 after ratings profile change (follow-up to BUT-1592) [Tier A, build, router: single]
Step-0 confirmed: the comment at `index.ts:312-314` still only describes the promotion
("flipped into profile") case; BUT-1592 (shipped in `6f0942408`) widened
`shouldRecomputeOnFamilyRatingUpdate` to also cover demotion, but deliberately left index.ts
untouched to avoid a cross-batch apply conflict at the time.
- [ ] Update the comment to describe both promotion and demotion as recompute triggers
- Acceptance: (1) comment accurately reflects current `shouldRecomputeOnFamilyRatingUpdate`
  behavior (both directions); (2) no logic/behavior change — comment-only edit; (3) doesn't
  touch any other export in this file
- Files: `functions/src/index.ts`
- Gates: cloud-functions-specialist. Close: Done.

### BUT-1544 — GDPR audit-log purge: unverified 180-day TTL on deletion_audit_logs [Tier A, build, router: FULL-PANEL (GDPR/high-stakes)]
Carried forward — a prior sprint selected this and it was silently dropped mid-run (see the
ticket's own post-sprint comment, `need-malin` label was added to surface the drop, not because
the fix is a product decision). Narrowed scope this pass: the ticket's second bullet
(general-category purge starving behind consent rows) is independently confirmed ALREADY FIXED
by commit `3a01d8fcd`/BUT-1404 (per the ticket's own 2026-07-11 comment) — only bullet 1
remains live: `deletion_audit_logs.expireAt` sets a 180-day value but nothing has been
confirmed to actually reap it.
- [ ] Phase 1.4 full-panel blind critique (GDPR/Privacy/Legal/Security) → fold must-haves
      BEFORE implementing
- [ ] Confirm whether a Firestore TTL policy or a CF purge exists for
      `deletion_audit_logs.expireAt`; if neither, add one (TTL policy declaration or a purge
      pass), with evidence cited in the commit
- [ ] Test proving the mechanism actually removes an expired doc (not just that the field is
      set)
- Acceptance: (1) `deletion_audit_logs` docs are provably reaped at 180 days by a real,
  verified mechanism — not just a field nothing reads; (2) evidence for which mechanism (TTL
  config or CF) is cited in the commit; (3) don't touch the consent-row retention query (already
  fixed by BUT-1404) or any other retention policy, only this one collection's enforcement;
  (4) full-panel review ran and its must-haves are folded in before commit
- Files: `functions/src/account/request-account-deletion.ts` (only if a purge CF is the chosen
  mechanism — read first, TTL-policy-only fix may need no code change), plus a new/updated test
- Gates: firebase-backend-security (+ full Phase 1.4 panel). Close: Done (Tier A) unless the
  panel raises a sign-off item, in which case In Review.

## Batch B — Import parse-event exception logging (lib/services/import, gate: code-reviewer+testing-specialist)

### BUT-1597 — parse failures (exception path) are not logged as parse events (follow-up to BUT-1470) [Tier A, build, router: single]
Step-0 confirmed: `_parseWithStrategy`'s `catch (e)` block (`import_manager.dart:786-791`)
returns a failure result without calling `_logParseEvent` — BUT-1470 deliberately scoped
logging to the try-block outcomes only. Consequence: analytics on parse-event volume undercount
hard failures (exceptions surface via AppLogger but not the parse-event pipeline).
- [ ] Add one `_logParseEvent`-equivalent call on the catch path so exceptions are captured as
      parse events too (reuse the existing logger — no new plumbing)
- [ ] New test in a DEDICATED new test file (not `import_manager_test.dart`, to avoid
      conflicting with any other in-flight edits to that golden file) proving the logger fires
      when a strategy throws
- Acceptance: (1) an exception in `_parseWithStrategy` now produces a parse event, not just an
  AppLogger entry; (2) existing success/needsAssistance/failure logging (BUT-1470) is
  unchanged; (3) new test lives in a new file, `import_manager_test.dart` is not modified;
  (4) no new logging plumbing/CF/dashboard — reuses `ParseEventLogger`
- Files: `lib/services/import/import_manager.dart`,
  `test/unit/services/import/import_manager_parse_event_exception_test.dart` (new)
- Gates: code-reviewer, testing-specialist. Close: Done.

## Batch C — Family-rating membership reconciliation (lib/services/family + functions/src/family, gate: firebase-backend-security)

### BUT-1600 — family-rating breakdown count can exceed visible rows when a rater left the household [Tier A, build, router: single]
Step-0 confirmed: no member/diner-removal reconciliation exists anywhere in `lib/services` or
`functions/src` — `Household.removeMember()` (`lib/models/household.dart:203`) is a pure model
method with no data-side cleanup of that member's `family_ratings` docs, so the recipe-detail
summary (derived from the FULL `family_ratings` set) can show a count that exceeds the number of
rendered breakdown rows once a rater leaves the household. Pre-existing gap, not introduced by
BUT-1461 Gap 2.
- [ ] Reconcile `family_ratings` docs for a removed member/diner (delete or reattribute) and
      recompute the denormalised recipe-card average, either via the removal call path in
      `HouseholdService` or as an added step in the existing weekly
      `purgeDormantFamilyData` sweep
- [ ] Test: a rater removed from the roster after rating no longer produces a header count
      exceeding rendered rows
- [ ] Test: denormalised recipe-card average reflects the reconciled set (no stale over-count)
- Acceptance: (1) header count never exceeds rendered breakdown rows after a member/diner
  removal, proven by a test; (2) denormalised recipe-card average is recomputed to match;
  (3) don't add a new exported Cloud Function to `functions/src/index.ts` — Batch A's BUT-1596
  edits that same file in this sprint, so implement via the existing removal call path or an
  addition inside an already-exported scheduled job, not a new top-level export; (4) don't
  change dormancy-purge behavior (24-month sweep) for still-active households
- Files: `lib/services/household_service.dart`,
  `functions/src/family/purge-dormant-family-data.ts` (only if the sweep-extension approach is
  chosen), plus a new/updated test
- Gates: firebase-backend-security. Close: Done.

## Needs you (Tier D / needs-approval — not built this sprint)

- **BUT-1601** (inline ingredient quantities in cooking-mode steps — "tärna tomaterna" →
  "tärna 4 stora tomater") — labeled `idea`, not `autonomous`; a genuine new-feature/UX call
  (how quantities get parsed into step text, scaling behavior), not a correctness fix.
  Recommendation: worth exploring — it's a nice differentiator per the ticket's own framing —
  but wants a product look (parsing risk, scaling edge cases) before building, not an autonomous
  default.
- **BUT-1599** (sprint engine force-commits past the marker review-gate) — the code that needs
  fixing (`sprint-execute-parallel.js`) lives in the shared `C:/claude-plugins/plugins/delivery`
  repo, not this one; already labeled `need-malin`. Recommendation: real and worth fixing (this
  sprint itself runs on that engine), but out of scope for a Butlery-repo sprint — needs a
  session in the plugin repo.
- **BUT-1570** (enable parse_events TTL policy + run expiry backfill) — ops action requiring
  Firebase console / gcloud access (Tier D), already labeled `need-malin`. Recommendation: do
  it — it's a already-scoped, already-approved follow-up (BUT-1478), just needs you to run the
  two RUNBOOK steps.
- **BUT-1323** ("Who's eating": per-day household presence + per-member preferences, epic) — the
  ticket's own text flags it "Large — may warrant splitting into sub-tickets" and it's the
  marquee differentiator, i.e. a strategic commitment call, not a bug fix. Recommendation: high
  payoff or I would not have carried it forward at all, but it should be broken into the four
  sub-pieces the ticket already outlines (per-member dislikes, per-day presence toggle,
  generator scoping, per-day portions) and sequenced deliberately rather than auto-built as one
  large Tier-C change.
- **BUT-1454** (minor default-private search-suppression + searchable opt-in, BUT-674 remainder)
  — carried from the 2026-07-12 plan; still unresolved. Minors-adjacent opt-in copy/framing is a
  UX call. Recommendation: worth doing (documented remainder of already-approved work), wants a
  copy look first given the minors context.
- **BUT-1500** (Algolia search router has zero callers — enable or remove) — carried from
  2026-07-12; still framed as a keep-vs-delete decision in its own title. Recommendation: low
  stakes either way, your call on which is faster.

## Deviation log

(none yet — filled during Phase 2 execution)

---
# Sprint 2026-07-12 — parser/backend correctness burndown + backlog hygiene [ARCHIVED — mostly shipped]

`/sprint-execute` Phase 1 selection. 8 tickets across 8 disjoint-file batches (parallel-safe).
State UUIDs: Todo 5a6d3faa · InProgress f8a3cf05 · InReview 9929b3b0 · Done 57dc8a84

Verified 2026-07-14: BUT-1592 (rating recompute demotion), BUT-1593 (parser truncation),
BUT-1455 (menu re-roll pantry), BUT-1470 (parse-event logging), BUT-1567 (lapsed-user window),
BUT-1563 (notification cleanup pagination), and BUT-1575 (bulk-verify hygiene) all shipped —
confirmed Done/archived in Linear and/or present on current `main`. BUT-1544 (GDPR audit-log
purge, Batch F) was selected but its code batch was silently dropped mid-run (see its own
2026-07-12 comment) — carried forward into the new sprint above as a narrower, confirmed-live
gap.

**Step-0 grep-of-main sweep:** no open ticket in the scanned range matched a symbol/behavior
already fixed on main under a different id — nothing obsolete this pass. Two near-duplicate
pairs were found among the freshest tickets (both filed same day by different scan passes) and
are closed as Linear duplicates below rather than built twice.

## Duplicate closures (this session — same-day scan pairs, not built twice)

- **BUT-1590** — duplicate of BUT-1592. Close as Duplicate → BUT-1592.
- **BUT-1591** — duplicate of BUT-1593. Close as Duplicate → BUT-1593.

## Needs you (Tier D / needs-approval — not built this sprint) — historical, see new plan above
## Deviation log
(none recorded)

---
# Sprint 2026-07-11c — backend/test-gap hardening + backlog hygiene [ARCHIVED — shipped]

`/sprint-execute` Phase 1 selection. 8 tickets across 7 disjoint-file batches (parallel-safe).
State UUIDs: Todo 5a6d3faa · InProgress f8a3cf05 · InReview 9929b3b0 · Done 57dc8a84

Verified 2026-07-12: BUT-1511 + BUT-1562 shipped together in commit `dade7b44b` ("fix(ratings,gdpr):
member-promotion recompute + accurate export truncation"). BUT-1493 shipped (confirmed via
`test/unit/services/import/import_manager_test.dart:183-214` — the exact golden test described in
this plan's Batch E is present on main). BUT-1539/1589/1492/1491 are no longer in the open backlog
(closed). BUT-1575 (Batch G) was selected here but is still open as of 2026-07-12 — carried
forward into the new sprint above, not re-described here.

## Needs you (Tier D / needs-approval — not built this sprint) — historical, see new plan above
## Obsolete (closed 2026-07-11 — see git history for evidence)
## Deviation log
(none recorded)

---
# Sprint 2026-07-11b — backend hardening test-gaps + decided-preference UI burndown [ARCHIVED — SHIPPED]

`/sprint-execute` Phase 1 selection. 8 tickets across 5 disjoint-file batches (parallel-safe).
State UUIDs: Todo 5a6d3faa · InProgress f8a3cf05 · InReview 9929b3b0 · Done 57dc8a84

All 8 tickets in this batch (BUT-1577, BUT-1573, BUT-1578, BUT-1572, BUT-1481, BUT-1574,
BUT-1526, BUT-1587) shipped in commit `a16611f27` and follow-on commits; none remain in
Backlog/Todo as of the 2026-07-11c selection. BUT-1588 (a BUT-1577 test-coverage follow-up
filed after this sprint) was found obsolete and closed above.

## Needs you (Tier D / needs-approval — not built this sprint)

- **BUT-1149** (restore coverage floor to 60%) — SUPERSEDED 2026-07-11: Malin decided 55% is the
  durable floor (`project_coverage_floor_decision.md`).
- **BUT-1580** (post-BUT-1571 ops: ingredient-sync healing pass) — writes to production allergen
  data; wants an attended, watched run.
- **BUT-1581** (require-review-before-commit gate misfires) — lives in the shared
  `C:/claude-plugins/plugins/workflow-guards` repo, not this one.
- **BUT-1585** (sprint accounting fix) — item C folds into the BUT-1581 fix session.

## Deviation log

(none yet — filled during Phase 2 execution)

---
# Sprint 2026-07-11 (serial) — ready-set burndown from the salvage [ARCHIVED — mostly shipped]

Serial `/sprint-execute` (parallel engine held — BUT-1569 deny-rule bug). 5 tickets, one
at a time, each its own commit. BUT-1523 held (need-malin, plan-first) — since resolved:
BUT-1523 closed 2026-07-12, `socialFeatures` decided as contract-basis (not a consent gate).

State UUIDs: Todo 5a6d3faa · InProgress f8a3cf05 · InReview 9929b3b0 · Done 57dc8a84

## BUT-1586 — server retention classifier: inDays→ms (Tier A, router: single) — SHIPPED (Done in Linear)
## BUT-1551 — route account-deletion through AuthService (Tier A, router: single) — SHIPPED (Done in Linear)
## BUT-1540 — enforce shared-link expiry on live recipe path (Tier A, router: single) — SHIPPED (Done in Linear)
## BUT-1525 — tokenise PII in shareable-URL slugs (Tier A code, router: FULL-PANEL high-stakes) — held (need-malin)
## BUT-1524 — age-maturity gate on comment posting (Tier C, router: FULL-PANEL high-stakes, firestore.rules) — CANCELED in Linear

## Needs you (Tier D): none in this batch.

---
(prior sprint plans archived in git history: commit 0db2fbca4 and earlier)

<!-- Voice recipe import (IMP-12) and Köksbutlern v1 (COOK-13/COOK-14) plans removed
     2026-07-14 — both shipped; full plans in tasks/voice-import-plan.md,
     tasks/koksbutlern-plan.md, and git history. -->
