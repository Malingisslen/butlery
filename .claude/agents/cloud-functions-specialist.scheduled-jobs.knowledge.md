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

