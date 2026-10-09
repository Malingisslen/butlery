# Nightly maintenance and rating cost: BUT-1814, BUT-1671, BUT-2084 (2026-10-09)

Malin said "kör" to these three in the project thread "Nästa ärenden utan krock".
Scope: `functions/src` only. Not touched: `firestore.rules`,
`account/account-deletion-cascade.ts`, anything under `lib/`.
Stakeholder router (run 2026-10-09 on the five production paths): tier `single`, no
high-stakes hits. Blind critique by the Privacy / DPO seat (2026-10-09): APPROVE WITH
CONDITIONS; its six conditions are folded in below as AC4–AC6 and AC13–AC14. Plan audit
(fresh context, 2026-10-09) findings F1–F10 are folded in. Scope widens by two files the
DPO named: `docs/security/family-data-retention.md` (dated line) and
`functions/src/admin/reset-collection-lists.ts` (the `_internal` rationale). One PR per ticket, merged and deployed by this thread when CI is green.

Step-0 measurements, read on `main` b8bd3c3:

- `scheduled/task-chain.ts`: `TASK_TIMEOUT_MS = 60_000`, `CHAIN_DEADLINE_MS = 500_000`,
  `CHAIN_RESERVE_MS = 5_000` (not exported), `budgetMs = Math.min(task.timeoutMs, available)`.
- `DAILY_ANALYTICS_TASKS` has 12 entries today, not the 10 the ticket counted: 720 s of task
  budget inside a 500 s deadline. `WEEKLY_REPORT_TASKS` has 4 (240 s), which fits.
- `family/purge-dormant-family-data.ts`: cursor is a local variable, 200 households per page,
  `timeoutSeconds: 300`, no wall-clock check.
- `analytics/detect-lapsed-users.ts`: one unbounded `.get()` per threshold, the
  cursor `analytics/lapsed_users.lastRunAt` is written only after all three thresholds.
- `ratings/update-recipe-rating-stats.ts`: two unbounded `.get()`s per recompute.
  `lastRatedAt` is parsed into `RatingStatistics.lastRatedAt` by
  `firebase_ratings_repository.dart`, and nothing reads that field after it (audit
  2026-10-09).
- `KEPT_PARENT_FIELDS` in `admin/reset-analytics-prune.ts`: `analytics/lapsed_users` may carry only `lastRunAt`;
  anything else is reported as residue by the reset script.
- Firestore rules: `family_ratings.stars` is an int 1–5; `recipe_ratings.rating` is 1–5
  but not pinned to int.

## BUT-1814 — daily chain fits its deadline

Measure first: PR #640 adds a read-only step to `measure-production.yml` that prints each
task's p50/p95/max over 30 days. Run it on `main` after merge.

- [ ] AC1: per-task budgets are sized from the measurement so the daily chain's budgets plus
  `CHAIN_RESERVE_MS` fit inside `CHAIN_DEADLINE_MS`: each task gets `min(60 s, max(3 × its
  measured max, 15 s))`, and the sum must fit. A task with its own wall clock gets more than
  that clock; a task that pages data growing with the user base and has no wall clock keeps
  60 s (review 2026-10-09). If it does not fit, the fallback is raising
  `CHAIN_TIMEOUT_SECONDS` and `CHAIN_DEADLINE_MS` together, only after the v2 scheduled
  function ceiling is checked in Firebase's docs; if neither fits, stop and report the
  numbers rather than cut a task below 3 × its measured max.
- [ ] AC2: `runTaskChain` skips a task when the available slice is smaller than the task's
  own `timeoutMs` (hard skip, logged `maintenance.task_skipped` with reason
  `insufficient_budget`), instead of starting it on a cut budget. The old docstring
  paragraph about truncation and the BUT-1814 pointer are struck.
- [ ] AC3: `maintenance-dispatchers.test.ts` asserts, for both chains, that the sum of
  `timeoutMs` plus the reserve is at most the deadline (export `CHAIN_RESERVE_MS`), and adds
  the missing truncation case: a slice between the floor and the task's budget skips the
  task and the chain continues to a later task that fits. The "matches the 60s default"
  assertion changes with AC1. The `TASK_TIMEOUT_MS` docstring sentences that AC1/AC2 make
  false ("60s is exactly what these tasks run under TODAY", "No task gets more budget…")
  are struck, not reworded.

## BUT-1671 — two sweeps resume instead of starting over

Family purge:

- [ ] AC4: the household cursor persists at `_internal/family_purge_cursor`
  (`lastHouseholdId`, `updatedAt`) after every page; a run resumes after it; a run that
  reaches the end of the collection deletes it, so the next run starts a new pass.
- [ ] AC5: a wall-clock budget (`SWEEP_DEADLINE_MS`, injectable, well under the 300 s
  timeout, same shape as `moderation/erasure-hold.ts`) stops between households, saves the
  cursor and logs `family-retention.sweep_deferred` with how many households it scanned;
  a complete pass logs `sweep_complete` with `passComplete: true`. Warning and purge
  semantics are unchanged. Bound: a pass takes ceil(households / households-per-run)
  weekly runs, so a purge can slip by that many weeks past its date; the deferred log
  makes the slip visible. (Daily runs were considered and rejected: every run reads every
  household it reaches, so daily is up to 7× the reads for the same guarantee.)
- [ ] AC5b (DPO 1): one household that throws does not pin the cursor: the error is caught
  per household, logged `family-retention.household_failed` (household id, error code),
  the cursor moves past it, and the run still throws at the end so it is recorded failed.
- [ ] AC5c (DPO 2): the cursor doc carries `passStartedAt`; `sweep_deferred` and
  `sweep_complete` log `passAgeDays`. The accepted maximum slip is 28 days (4 weekly
  runs): a pass older than that logs `family-retention.pass_overdue` at ERROR and the run
  throws, so it shows as a failed run. The deferred log never carries the cursor id.
- [ ] AC5d (DPO 5): resume uses `startAfter(<id string>)`, which needs no document there.
- [ ] AC6: integration test (emulator): a run stopped by the budget resumes on the next run
  and the two runs together evaluate every household exactly once; a full pass clears
  the cursor; a throwing household is followed by later households in the same run and the
  next run does not stall on it; a cursor household deleted between runs resumes at the
  next id; a household warned in run N is not purged before its date even when the pass
  wraps, and one that becomes active after the warning is reactivated, not purged.

Lapsed users:

- [ ] AC7: each threshold pages users by `lastActiveAt` ascending, at most `PAGE_SIZE`
  (≤ 165, so a page's 3 writes per user plus the cursor fit one 500-op batch). When a page
  is full, the users sharing its last `lastActiveAt` are read with one equality query and
  joined to the page, so the cursor is a TIMESTAMP only and never holds a uid. The
  per-threshold cursors live in `_internal/lapsed_users_cursor` (`<type>: Timestamp`), not
  on `analytics/lapsed_users`, whose fields the reset prune restricts to `lastRunAt`. Each
  page's analytics rows, notification docs, bridge fields and cursor commit before its
  pushes. A drained window and an empty one store the window's upper bound. Without a stored per-threshold cursor the bound is
  `lastRunAt - N days` as today, so the first deploy neither re-sends nor skips.
  `lastRunAt` is still written when all thresholds drain. The dispatcher's "KNOWN,
  ACCEPTED, TICKETED SEPARATELY" paragraph's "advances its resume cursor only at the very
  end" becomes false and is struck; the re-send window it describes shrinks to a crash
  between a page's commit and its pushes (pushes lost, never doubled).
- [ ] AC8: an injectable run budget split evenly across the three thresholds (an earlier
  threshold that finishes early leaves its time to the next) stops paging between pages;
  the next run continues from the stored cursor. The budget is below the task's chain
  budget from AC1.
- [ ] AC9: tests: a backlog larger than one page drains across two runs with each user
  notified once; users with an equal `lastActiveAt` across a page boundary are each
  notified once; a budget stop resumes exactly; the legacy `lastRunAt`-only cursor gives
  the same window as before. Page processing moves to a sibling module for the file-size
  limit.

DPO records, same PR as the code they describe:

- [ ] AC13 (DPO 3): `docs/security/family-data-retention.md` gets a dated line under "Sweep
  (BUILT)": a pass can span several weekly runs, the 28-day maximum slip, the deferred log
  and the overdue failure, and that the cursor id is overwritten each run and deleted when
  a pass ends.
- [ ] AC14 (DPO 4): the `_internal` entry in `admin/reset-collection-lists.ts` names both
  cursor docs and their fields, and a unit test asserts each cursor write carries exactly
  those fields (`lastHouseholdId`, `updatedAt`, `passStartedAt`; one Timestamp per
  threshold type).

## BUT-2084 — rating recompute reads a bounded number of documents

- [ ] AC10: `updateRecipeRatingStats` first reads each collection with
  `limit(FOLD_LIMIT + 1)`. A collection under the limit is folded as today; one past it
  has its count and distribution from `count()` aggregations (`recipeId ==`, value `==` 1..5; plus
  `memberType == profile` for family rows), which Firestore bills per 1,000 index entries.
  Both paths count only INTEGER values 1–5 (the fold path today also folds e.g. 3.5, which
  the app never writes but the rules allow), so the two paths agree at the limit; average
  = sum of value × count / count from the distribution, never `sum()`/`average()` (those
  need a composite index). The counted path keeps the stored `lastRatedAt` rather than
  inventing one.
- [ ] AC11: the recompute returns how many documents it read (aggregations counted as the
  billed reads). The dispatcher's `drainAggregations` wraps the aggregate callback in a
  closure that sums it (no change to `shared/debounce-queue.ts`), logs it as `docsRead` on
  `rating_aggregation.drain_complete`, and increments
  `analytics/rating_reads/daily/{UTC date}.docsRead` once per drain minute that read
  anything (≤ 1,440 writes a day, the ticket asks for a counter).
- [ ] AC12: tests (emulator): a recipe under the limit gives the same stats as before; one
  over the limit gives the same count, average and distribution from the aggregation path
  and reports a bounded read count.

## Verification

- `npm run build` and the touched suites (`test:maintenance-dispatchers`,
  `test:lapsed-users`, `test:integration:family-data-purge`, rating suites) pass locally.
- cloud-functions-specialist reviews every staged file before each commit.
- After merge: deploy the touched functions through `deploy-firebase.yml`, check the run,
  close the tickets.
- After the BUT-2084 deploy: the emulator does not enforce indexes, so check the
  `drainAggregations` logs for FAILED_PRECONDITION after the first rating recompute (the
  measure workflow can read it).

## Open questions

None for Malin: the choices above are engineering defaults inside her "kör". The
anomaly detector is not wired to the new rating counter, because its banner labels live in
the app (redesign-owned) and its 06:00 run would read a partial day.

## Summary for Malin

Tre saker på servern blir tåligare. Nattjobbet får tidsgränser som faktiskt ryms, så en
långsam uppgift inte längre drar med sig resten. Två städjobb fortsätter där de slutade i
stället för att börja om, så ingen hushålls- eller användardata blir liggande när ni blir
fler. Och betygssnittet räknas med ett tak på hur mycket som läses, plus en daglig siffra
som visar om det plötsligt blir dyrt. Inget syns i appen.
