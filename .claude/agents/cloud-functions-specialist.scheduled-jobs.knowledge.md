# cloud-functions-specialist — chapter: scheduled-jobs

### Scheduled analytics & lifecycle jobs
- Never assume a date field's type (ISO vs `Timestamp` varies per collection).
- Anomaly gates: `baseline≥MIN_SAMPLES` AND `stddev>0` AND `|z|>3` AND
  `|today-mean|≥ABSOLUTE_FLOOR` — without the floor, pre-launch counts fire
  constantly. A consumer job SKIPS (never assumes zero) on a missing producer
  doc. `Math.floor(elapsed/DAY)` mis-classifies the sub-day remainder.
- **A daily job probing "today" only measures the hours BEFORE its own run
  time** — probe the PREVIOUS COMPLETED UTC day and derive date, query
  window, rollup offsets AND active-user cutoff from that one base. A
  REALTIME writer into a SCANNED collection is invisible for the hours after
  the run (`runOpsSnapshot`, 06:00 UTC over `system_events`), and evicts job
  rows from that collection's other readers. Put a realtime counter in an
  ADDRESSED doc (`analytics/{group}/daily/{date}` + `increment`) and name its
  reader, or it is a number nobody sees.
- **An `onSchedule` BODY is unreachable from a unit test, so anything written
  only there is unpinned** — a receipt/summary row typed out AGAIN inside the
  test asserts the test's own literal and stays green when the production
  `add({...})` is renamed or deleted, which is precisely the failure such a row
  has (a mis-spelled key is invisible to `runOpsSnapshot` and the ops-log tab
  with no error anywhere). Split wrapper/core like `cleanupOldRateLimitsCore`
  and drive the CORE.
- **A cleanup job's own `timeoutSeconds` needs an `__endpoint` pin, not a
  comment** — `deploy-manifest.test.ts` enumerates exports for REGION and
  `maxInstances` only, so a declared timeout is unguarded; assert
  `__endpoint.timeoutSeconds` and that the in-code self-budget is below it, or
  the job joins the siblings whose 8-minute budgets have never been reachable.
- **A repair that re-derives a rollup delta must use the nightly job's window
  CONSTANTS and pin each LENGTH at its edge** — a user seen at offset N-1 counts, at
  N does not, per window (`wau7d` 7, `wau28d` 28). A fixture three days apart leaves
  `offset <= days` and `WAU_28D = 7` green, and the wrong delta is permanent: the
  re-run sees no false left to flip.
- **A collection-group sweep that PATH-scopes rows after the read re-reads every
  skipped row on every run** — under `orderBy(timestamp)` skipped rows older than
  the in-scope ones are read first and can use up the run's real timeout (an
  `onSchedule` without `timeoutSeconds` gets 60s). Log the
  skipped count so the first prod run measures it. Narrowing a sweep off a DEAD
  parent spelling turns "deleted at N days" into "kept forever" for its residue.
- **`servingComposite` (`__tests__/_query-index-coverage.ts`) checks COLLECTION-
  scope composites only** — it answers "served" for any `collectionGroup` shape
  without a range+equality pair (single-field auto indexes are collection-scoped,
  so those need a `fieldOverrides` COLLECTION_GROUP entry) and ignores every
  `orderBy` after the first. Pin a group query's override separately.
- **Auth `UserRecord.metadata` times are `toUTCString()` strings, whole seconds.** A
  fake built the same way rounds a "1 ms short of N days" boundary fixture ONTO the
  line; step a boundary by 1000 ms. A sweep module importing
  `request-account-deletion` needs `admin.initializeApp` BEFORE its `require`
  (module-level `admin.firestore()`), or the suite dies with `app/no-app` at load.

