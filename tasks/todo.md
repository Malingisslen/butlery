# Sprint 2026-07-12 — parser/backend correctness burndown + backlog hygiene

`/sprint-execute` Phase 1 selection. 8 tickets across 8 disjoint-file batches (parallel-safe).
State UUIDs: Todo 5a6d3faa · InProgress f8a3cf05 · InReview 9929b3b0 · Done 57dc8a84

**Step-0 grep-of-main sweep:** no open ticket in the scanned range matched a symbol/behavior
already fixed on main under a different id — nothing obsolete this pass. Two near-duplicate
pairs were found among the freshest tickets (both filed same day by different scan passes) and
are closed as Linear duplicates below rather than built twice.

**Backlog note:** the full open pool (Backlog + Todo + Triage + In Progress, ~150 tickets,
paginated to completion) was read this pass. The great majority already carry a `deferred` or
`need-malin` lane label from prior sprints/role-org scans (post-beta epics, launch-gated ops,
already-surfaced product decisions) — those prior triage calls were treated as still standing,
not re-litigated ticket-by-ticket this sprint. Selection focused mandate judgement on
`autonomous`-labeled and freshly-filed candidates. Three borderline ones are flagged below under
Needs You rather than re-buried silently.

## Batch A — Family-rating recompute demotion gap (functions/src/ratings, gate: cloud-functions-specialist)

### BUT-1592 — family-rating recompute doesn't fire on profile→non-profile demotion (BUT-1511 residual) [Tier A, build, router: single]
`functions/src/ratings/family-rating-recompute.ts` (`shouldRecomputeOnFamilyRatingUpdate`).
Step-0 confirmed: the JSDoc and code both still short-circuit on `isProfileRating(after)` before
checking `before`, so a `profile`→non-profile demotion never triggers recompute — the row stays
folded into the public average under its old classification. Real, current, undisputed gap
(BUT-1511 explicitly scoped it out, documented in a comment + a negative test).
- [ ] Widen `shouldRecomputeOnFamilyRatingUpdate` to also recompute when `before` was `profile`
      and `after` is not (demotion), alongside the existing promotion/star-change checks
- [ ] New unit test: recompute fires on a profile→non-profile demotion with stars unchanged
- [ ] Existing promotion + star-change tests still pass unmodified
- Acceptance: (1) demotion transition triggers recompute; (2) new test proves it; (3) existing
  promotion/star-change tests unmodified and green; (4) don't touch the trigger's other gates
  (this is a condition widen only, not a rewrite)
- Files: `functions/src/ratings/family-rating-recompute.ts`, `functions/src/__tests__/family-rating-recompute.test.ts`
- Gates: cloud-functions-specialist. Close: Done.

## Batch B — Recipe parser: title truncation + ingredient misclassification (lib/services/import, gate: code-reviewer+testing-specialist)

### BUT-1593 — recipe parser truncates Swedish titles + misclassifies ingredients ('Köttbullar med gräddsås' case) [Tier A, build, router: single]
Discovered writing the BUT-1493 golden test (shipped, current `import_manager_test.dart:183-214`
confirmed on Step-0 read — it deliberately asserts `startsWith('Kottbullar')` and a `>=3`
ingredient-count lower bound specifically so it wouldn't cement these bugs). Real, current,
core-USP-pipeline defects: multi-word Swedish titles with a "med …" tail get truncated, and
instruction-sentence fragments leak into the ingredient list while a real measured ingredient
line gets dropped.
- [ ] Trace and fix the title-truncation logic in the text-import title extractor so the full
      title survives (no premature cutoff on "med …" tails)
- [ ] Trace and fix the ingredient/instruction line-classification so instruction fragments
      aren't captured as ingredients and genuine measured lines (e.g. "500 g köttfärs") aren't dropped
- [ ] Tighten the BUT-1493 golden test (`import_manager_test.dart`) to the exact expected title
      and ingredient set now that the underlying bugs are fixed
- Acceptance: (1) the Köttbullar-fixture title is NOT truncated; (2) no instruction fragment
  appears in the parsed ingredient list for that fixture; (3) the golden test pins exact values
  (no more `startsWith`/`>=` loosening); (4) no other import strategy's existing tests regress
- Files: `lib/services/import/text_import_strategy.dart` (title/line-classification logic —
  exact culprit confirmed at Step-0 implementation time), `test/unit/services/import/import_manager_test.dart`
- Gates: code-reviewer, testing-specialist. Close: Done.

## Batch C — Menu re-roll pantry re-fetch (lib/viewmodels/menu, gate: code-reviewer+testing-specialist)

### BUT-1455 — menu section re-roll rebuilds the full pantry scoring context every tap (hot-path I/O) [Tier A, build, router: single]
CONFIRMED `/code-review high` finding (2026-07-01), Step-0 re-read confirms it's still live:
`regenerateMenuSection` (`menu_generator.dart:586-611`) calls `getAvailableRecipesAsync()` (full
library) then `_buildScoringContext(pool)` on every single-section re-roll tap — identical full
pantry read + ingredient-overlap match as a full generation, for one meal slot.
- [ ] Cache/reuse the scoring context (or at least `pantryMatchByRecipeId`) from the last full
      generation for section re-rolls, refreshing only when pantry/library actually changed —
      OR scope the pantry read to the section's candidate pool instead of the whole library
- [ ] New test asserting a single-section re-roll does not perform a full-library pantry read
      on every tap (pantry-read-count or scoped-input assertion)
- Acceptance: (1) re-roll no longer re-reads/re-scores the whole library on every tap (proven by
  a test); (2) full-generation behavior is unchanged (existing menu tests stay green); (3) don't
  change what recipes a re-roll can surface, only how the context is computed
- Files: `lib/viewmodels/menu/menu_generator.dart`, `test/unit/viewmodels/menu/menu_generator_test.dart`
- Gates: code-reviewer, testing-specialist. Close: Done.

## Batch D — Parse-event logging for every import path (lib/services/import, gate: code-reviewer+testing-specialist)

### BUT-1470 — log parse events for every import path, not just URL [Tier A, build, router: single, requiresPlanMode]
Step-0 confirmed: `_parseWithStrategy` (`import_manager.dart:655`) is the single choke point
called from all ~8 import paths (URL, photo, text, Instagram, TikTok, YouTube, etc. — grep
confirms every call site funnels through it). Obvious-benefit instrumentation: reuses the
existing `ParseEventLogger` + CF + dashboard, no new plumbing, no product ambiguity.
- [ ] One `ParseEventLogger` call at the end of `_parseWithStrategy` logging strategy, success,
      needsAssistance, elapsed — for every import path, not just URL
- [ ] New FOCUSED test file (do NOT add to `import_manager_test.dart` — Batch B tightens that
      file's golden-test assertions in parallel; a second batch editing it would conflict)
      asserting the logger fires for a non-URL path (e.g. text import)
- Acceptance: (1) every import path now logs a parse event, not just URL; (2) no new
  plumbing/CF/dashboard added — reuses the existing logger; (3) a dedicated new test file (not
  `import_manager_test.dart`) proves it fires on a non-URL path; (4) existing import behavior
  (success/failure results returned to callers) is unchanged
- Files: `lib/services/import/import_manager.dart`, new
  `test/unit/services/import/import_manager_parse_event_logging_test.dart`
- Gates: code-reviewer, testing-specialist. Close: Done.

## Batch E — Lapsed-user win-back window fix (functions/src/analytics, gate: cloud-functions-specialist)

### BUT-1567 — lapsed-user detection is point-in-time; irregular users escape all win-back windows [Tier A, build, router: single]
Step-0 confirmed: `runDetectLapsedUsers` (`detect-lapsed-users.ts:138-145`) still queries an
exact ±12h window around each of the 7/14/30-day thresholds — a user whose `lastActiveAt` skips
past all three exact windows (irregular check-in pattern) never enters any win-back flow. Clear
correctness fix to a scheduled CF, no UI surface, no product-intent ambiguity (behavior is
strictly "catch more of the users the feature already intends to catch," not a new targeting
policy).
- [ ] Replace the point-in-time ±12h window predicate with a crossed-threshold-since-last-run
      check per threshold (needs a stored last-run cursor so a user isn't re-notified every run
      once they've crossed a threshold)
- [ ] New/updated unit test: a user whose `lastActiveAt` falls between two scheduled runs (skips
      the old exact window) still gets detected once they cross a threshold
- [ ] Existing threshold tests still pass; a user is not notified twice for the same threshold
- Acceptance: (1) a user who would have skipped the old ±12h window is now detected; (2) same
  user is not double-notified for one threshold across runs; (3) existing win-back tests green;
  (4) don't change which thresholds exist (7/14/30) or the copy/variant resolution, only the
  detection predicate
- Files: `functions/src/analytics/detect-lapsed-users.ts`, `functions/src/__tests__/detect-lapsed-users.test.ts`
- Gates: cloud-functions-specialist. Close: Done.

## Batch F — GDPR audit-log TTL + purge query split (functions/src/account+audit_logs, gate: firebase-backend-security)

### BUT-1544 — GDPR audit-log purge: unverified 180-day TTL + general-category purge starves behind consent rows [Tier A, build, router: FULL-PANEL (high-stakes GDPR files)]
Two sub-items, both correctness/compliance, no product-intent call: (1) `deletion_audit_logs`
sets a 180-day `expireAt` but Step-0 needs to confirm whether a Firestore TTL policy or a CF
purge actually exists for it — currently unverified; (2) the general-category audit-log purge in
`purge-expired.ts` fetches-then-filters in the same query as long-retained consent rows, so it
starves behind them — split by an indexed retention-tier field.
- [ ] Phase 1.4 full-panel blind critique (GDPR/security-adjacent) → fold must-haves
- [ ] Confirm/create the TTL policy (or CF purge) for `deletion_audit_logs.expireAt`; state which
      one, with evidence
- [ ] Split the general-category purge query by an indexed retention-tier field so it no longer
      starves behind consent-row retention
- [ ] Tests for both behaviors
- Acceptance: (1) `deletion_audit_logs` docs actually expire at 180 days by a real, verified
  mechanism (not just a field that nothing reads); (2) general-category purge is provably no
  longer blocked by consent-row volume (test asserts independent progress); (3) no change to
  what data is retained/deleted, only to whether the stated retention actually executes;
  (4) don't touch the consent-row retention policy itself, only the query structure
- Files: `functions/src/account/request-account-deletion.ts`, `functions/src/audit_logs/purge-expired.ts`
- Gates: firebase-backend-security. Close: Done (Tier A) unless panel raises a sign-off item.

## Batch G — DB cleanup pagination + index verify (functions/src/cleanup, gate: firebase-backend-security)

### BUT-1563 — DBA low batch: cleanupOldNotifications pagination + cleanupExpiredSocialRequests index verify [Tier A, build, router: FULL-PANEL (high-stakes: touches account/GDPR-adjacent cleanup)]
Same gap class as the already-fixed BUT-1372 (paginate past the 10k cap): `cleanupOldNotifications`
(`cleanup-old-notifications.ts:22-40`) caps at 10k docs with no pagination loop, so a backlog
past 10k never fully drains. `cleanupExpiredSocialRequests` (`cleanup-expired-social-requests.ts:32-35`)
likely needs a `(status, sentAt)` composite index — verify against the actual index config, add
only if genuinely missing.
- [ ] Phase 1.4 full-panel blind critique → fold must-haves
- [ ] Wrap `cleanupOldNotifications` in a `startAfter` pagination loop past the 10k cap
- [ ] Verify `cleanupExpiredSocialRequests`'s query against `firestore.indexes.json`; add the
      composite only if actually missing — state the finding either way, don't add a redundant index
- [ ] Tests for the pagination loop
- Acceptance: (1) `cleanupOldNotifications` provably drains past 10k docs (test with >10k-doc
  scenario or an equivalent pagination-loop assertion); (2) index finding is stated explicitly
  (added because missing, or confirmed already present — cite the config); (3) no change to what
  counts as "expired" for either cleanup, only to how much of the backlog a single run clears;
  (4) don't touch unrelated cleanup jobs
- Files: `functions/src/cleanup/cleanup-old-notifications.ts`, `functions/src/cleanup/cleanup-expired-social-requests.ts`
- Gates: firebase-backend-security. Close: Done (Tier A) unless panel raises a sign-off item.

## Batch H — Backlog Hygiene (Linear-only, no production files, gate: none)

### BUT-1575 — bulk-verify remaining 2026-07-04 org-scan tickets against current code; close false positives [Tier A meta, build, router: n/a]
Already in Todo (selected by the prior sprint but not completed — no evidence of execution
found). Carried forward as-is: re-verify every still-open BUT-1521–1568-range ticket against
current code (grep/blame), close false positives citing the resolving commit, correctly lane
survivors.
- [ ] Re-verify every still-open BUT-1521–1568-range ticket against current code (grep/blame)
- [ ] Close false positives citing the specific resolving commit
- [ ] Correctly lane survivors (autonomous/need-malin/deferred) for future sprint trust
- Acceptance: (1) every open ticket in range has been re-verified or closed; (2) each closure
  cites commit/blame evidence; (3) survivors carry a correct lane label
- Gates: none (no code diff). Close: Done.

## Duplicate closures (this session — same-day scan pairs, not built twice)

- **BUT-1590** — duplicate of BUT-1592 (identical finding, filed 90 minutes apart by two scan
  passes; BUT-1592 has the fuller writeup + explicit gate). Close as Duplicate → BUT-1592.
- **BUT-1591** — duplicate of BUT-1593 (identical Köttbullar-fixture finding, same root cause,
  filed same session; BUT-1593 has the fuller writeup). Close as Duplicate → BUT-1593.

## Needs you (Tier D / needs-approval — not built this sprint)

- **BUT-1461** (family rating: no push notification on new rating + no realtime refresh) — the
  ticket itself flags Gap 1 as needing a decision first ("could be noise in a same-kitchen
  household"). Gap 2 (realtime stream on the breakdown view) is a clean, undebatable bug fix on
  its own. Recommendation: decide on the push notification (yes/no) first; if the answer is easy,
  split into two tickets so Gap 2 can ship without waiting on the Gap 1 call.
- **BUT-1454** (minor default-private search-suppression + searchable opt-in + group-DM CF,
  BUT-674 remainder) — security+account+minors-adjacent, and "searchable opt-in" is a genuine
  user-facing UX/copy decision, not just a backend toggle. Recommendation: worth doing (it's the
  documented remainder of an already-approved slice), but the opt-in framing/copy wants a look
  before building, given the minors context.
- **BUT-1500** (Algolia search router has zero callers — enable the flag or remove the path) —
  literally framed as a keep-vs-delete decision in its own title; not something to guess at.
  Recommendation: low stakes either way (it's dead code today), so whichever is faster is fine —
  but it's your call, not an autonomous default.

## Deviation log

(none yet — filled during Phase 2 execution)

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

---

# Voice recipe import — "Tala in recept" (appended 2026-07-13, separate session)

Full plan: tasks/voice-import-plan.md (approved flow: Malin's "continue with the next phase"
+ interview decision guided-sections + directions pick "B med A:s stora mikrofon" 2026-07-13;
single-role stakeholder review approve-with-conditions, conditions implemented in Batch A+B).

- [x] Batch A+B: SourceArtefactType.voiceDictation, VoiceCaptureService timeout+maxDuration,
      VoiceImportStrategy, voice_transcript_assembler, ImportManager.importVoiceTranscript,
      source-tag 'voice', 27 tests green
- [ ] Batch C (IN PROGRESS): VoiceImportViewModel + voice_import_view (direction B, big mic
      in active card) + route /voiceImport + tile + l10n + widget tests; preview marker stamped
- [ ] Batch D: feature inventory IMP-12, workflow-map flow, component library
- [ ] Batch E: /code-review high + specialist gates + commit + push

## Open questions
No architecture-changing unknowns — assumptions: `record` package for capture (already
shipped in v1), success→SkrivSjalvReceptView review navigation (photo precedent),
assistance→assisted-import dialog (existing terminal path).
