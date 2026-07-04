# Role #7 — Financial Controller / FinOps — scan findings

Scope: docs/ops/** (gcp-alerting-runbook, llm-kill-switch-runbook), functions/src/cleanup/cleanup-rate-limits.ts,
functions/src/llm/** (gemini-client, ocr-recipe-image, ocr-retry, prompts-config, structure-recipe),
functions/src/middleware/rate_limiter.ts, lib/services/import/import_rate_limiter.dart

Lens: minimize Firebase/LLM running cost — LLM spend control, rate limiting, OCR cost, kill-switch, read/write efficiency.

Already-known watch-items NOT re-filed: dossier already tracks unverified pricing constants TODO
(gemini-client.ts:828-834), unvalidated implicit-cache discount (BUT-1032 phase 2, in dedup), OCR retry-skip
unmonitored, prompts-config fallback masking outages, model-retirement monitoring gap. BUT-439 (kill-switch) and
BUT-1378 (logParseCorrection key) already exist/closed. Skipped all of these.

---

## PASS 1 — primary (uncapped spend, rate limits, retry storms, cache, OCR cost)

### Rate-limit cleanup cron targets the WRONG collection — `system_rate_limits` grows unbounded forever
- type: bug  area: backend (FinOps / Firestore storage cost)  priority: High
- pass: 1
- finding: The rate-limiter middleware was moved to write its per-user buckets to the **top-level**
  `system_rate_limits/{userId}_{operation}` collection so clients cannot delete their own limits
  (`functions/src/middleware/rate_limiter.ts:155-158`). But the weekly cleanup cron still reads the **old**
  per-user subcollection `users/{userId}/rate_limits` (`functions/src/cleanup/cleanup-rate-limits.ts:103-104`).
  Nothing in `functions/src/` writes to `users/*/rate_limits` anymore (grep: only the cleanup job and the
  account-deletion/reset paths reference it). Result: every (user × LLM-operation) record in `system_rate_limits`
  is created once and `updatedAt`-touched on every call, but is **never purged** — the collection grows monotonically
  with the user base and is never cleaned. Meanwhile the cron does real work for zero benefit.
- why: Unbounded Firestore collection growth is a pure FinOps storage-cost leak (and a slow query/scan-cost creep on
  anything that ever lists it). The CRIT-7 batched-delete machinery built for this exact purpose is now dead code
  pointed at empty subcollections. The integration test
  (`functions/src/__tests__/cleanup-rate-limits.integration.test.ts:86-95`) seeds `users/{uid}/rate_limits` — the
  *same stale path* — so it passes green while production cleanup deletes nothing. False confidence.
- fix: Repoint `cleanupOldRateLimitsCore` to scan the top-level `system_rate_limits` collection directly
  (`db.collection("system_rate_limits").orderBy("__name__").limit(...).startAfter(...)`, filter `updatedAt < cutoff`,
  batch-delete) instead of the per-user-subcollection nested loop. This also removes the N+1 read pattern below as a
  side effect. Update the integration test to seed/assert `system_rate_limits`. Confirm whether `account-deletion-cascade.ts:581`
  / `reset-user-data.ts:39` (which still delete `users/*/rate_limits`) should also target `system_rate_limits` for
  GDPR erasure of a user's bucket docs — likely yes (cross-check with role #5).

### Cleanup cron does an N+1 read over every user even when nothing needs deleting
- type: bug  area: backend (FinOps / Firestore read cost)  priority: Medium
- pass: 1
- finding: Even setting aside the wrong-path bug, the cleanup loop issues one `.get()` per user on the
  rate-limit subcollection (`cleanup-rate-limits.ts:103-104`, inside the per-user `for`) — i.e. one extra read round
  per user every Sunday, scaling linearly with the entire user base, regardless of whether any record is stale.
- why: Read cost scales with total users, not with deletable records. A `collectionGroup`/top-level query filtered by
  `updatedAt < cutoff` reads only the docs that actually need deleting — orders of magnitude fewer reads at scale.
- fix: Folded into the fix above — a single top-level `system_rate_limits` query with a `where("updatedAt", "<", cutoff)`
  filter reads only stale docs. (Equality/range note: this is a single-field range query, served by the automatic
  single-field index — no composite needed per accepted-deviations.)

### OCR text-mode retry bypasses both the global cap and the per-user bucket — global counter undercounts true Vertex volume
- type: improvement  area: backend (FinOps / cost-cap accuracy)  priority: Low
- pass: 1
- finding: A failed OCR image parse triggers a second Gemini call via the text-mode retry, which calls
  `runStructureRecipe` **core directly** (`functions/src/llm/ocr-recipe-image.ts:265` → `ocr-retry.ts:160`), not the
  `withRateLimit("structureRecipe", …)` callable wrapper. So the retry's Vertex call increments neither
  `checkGlobalLimit`'s `system/llmLimits` counter nor the per-user `structureRecipe` token bucket
  (`rate_limiter.ts:502, 514`). Each OCR failure can therefore cost up to 2 Vertex calls while the global hourly/daily
  cap counts only 1.
- why: The global aggregate cap (`globalHourlyLimit`/`globalDailyLimit`) is FinOps's coarse cost ceiling; if real
  call volume is systematically higher than the counter, a cost spike driven by OCR-retry traffic can slip under a
  cap that looks like it's holding. Partly mitigated: the retry is bounded to exactly 1, budget-gated (≥65s headroom),
  and the user already spent an `ocrRecipeImage` token — so it's a soft accuracy gap, not a runaway. Reasonable to
  accept, but worth a one-line `checkGlobalLimit()` call (or a counted increment) on the retry path so the cap
  reflects true Vertex volume.
- fix: Either call `checkGlobalLimit()` before the retry in `runOcrRetry` (deny → fall back to rawText, no extra
  cost), or increment the global counter when `retryCount === 1`. Cheapest correct option: gate the retry behind
  `checkGlobalLimit()` so a global-cap incident also throttles the second call.

---

## PASS 2 — second sweep (Firebase read/write efficiency, kill-switch coverage, cron cost)

### `withRateLimit` adds two extra Firestore transactions on the hot path of every LLM call
- type: improvement  area: backend (FinOps / Firestore write cost)  priority: Low
- pass: 2
- finding: Every gated LLM call runs `checkGlobalLimit()` (1 transactional read+write on `system/llmLimits`,
  `rate_limiter.ts:428-450`) **then** `checkRateLimit()` (1 transactional read+write on the per-user bucket,
  `rate_limiter.ts:230-289`) before the handler. That's 2 Firestore transactions (each a contended read-modify-write)
  per import/OCR. `system/llmLimits` in particular is a **single global document** every LLM call writes to — a
  hotspot that, under launch surge, hits Firestore's ~1 write/sec/document soft limit and serializes all LLM traffic
  behind one doc's contention.
- why: Single-document write contention is both a cost (retried transactions = extra ops) and a throughput ceiling.
  The per-instance 30-min cache covers the *limit values* but not the *counter writes* — those are unconditional and
  unsharded. Not urgent at ~1 user, but it's the first thing that breaks on a real surge and is cheap to shard now.
- fix: Shard the global counter (e.g. `system/llmLimits_{0..9}`, sum on read) or move the aggregate cap to an
  approximate in-memory/Cloud-Monitoring counter rather than a synchronous per-call Firestore transaction. At minimum,
  document the single-doc contention ceiling in the kill-switch runbook's "Global aggregate caps" section so ops know
  the cap itself becomes the bottleneck before it's hit.

### Kill-switch runbook's per-user-cap section points at a non-functional cleanup path (doc drift)
- type: improvement  area: backend (docs / ops accuracy)  priority: Low
- pass: 2
- finding: `docs/ops/llm-kill-switch-runbook.md:166-176` documents the per-user cap as enforced by
  `rate_limiter.ts` and the records as cleaned up by the weekly job — but per Pass 1 the cleanup never touches the
  collection the middleware actually writes (`system_rate_limits`). The runbook also still describes the storage path
  using the old per-user-subcollection mental model. The middleware's own header comment (`rate_limiter.ts:9`)
  likewise still says "Reads from /users/{userId}/rateLimits/{operation}" and "graceful fallback (allows request)"
  even though the code now reads `system_rate_limits` and **fails closed** (denies) on error (`rate_limiter.ts:292-305`).
- why: Stale runbook + stale header send an incident responder to the wrong collection and wrong fail-mode during a
  cost spike. Cheap to fix; high leverage during an incident.
- fix: After the Pass-1 cleanup repoint lands, correct the runbook storage-path description and update the
  `rate_limiter.ts` file header (lines 9 and the "graceful fallback on errors (allows request but logs)" line) to
  reflect the `system_rate_limits` path and the current fail-closed behavior.

### No alert on global-cap trips or rate-limit-violation volume — cost ceiling is silent when it fires
- type: improvement  area: backend (ops / alerting)  priority: Low
- pass: 2
- finding: `checkGlobalLimit` returning false throws `resource-exhausted` and logs a `logger.warn`
  (`rate_limiter.ts:503-510`); per-user violations write a `system_events` doc + warn (`rate_limiter.ts:311-328`).
  `docs/ops/gcp-alerting-runbook.md` has alerts for error-rate and p99 latency but (checked) no alert on the global
  cap firing or on rate-limit-violation rate. The kill-switch runbook alerts on kill-switch *message* strings but not
  on the global-cap exhaustion message.
- why: The global cap is the cost ceiling; when it trips it means the app is at capacity (legitimate surge OR abuse/
  runaway). Today that's invisible until someone reads logs. A log-based metric + alert on the `resource-exhausted`/
  "kapacitetsgräns" message (or on `system_events` rate_limit_violation volume) gives ops the early signal the
  DevOps dossier's "budget alerts are manual" gap leaves open.
- fix: Add a log-based-metric alert (≥N "Systemets kapacitetsgräns har nåtts" or "Global LLM limit exceeded" /hour)
  to `gcp-alerting-runbook.md`. Pairs with the existing kill-switch message alerts; no new infra.

---

COVERAGE: All owned paths read and verified at file:line — rate_limiter.ts (current state: top-level
`system_rate_limits` path + fail-closed), cleanup-rate-limits.ts, gemini-client.ts (cost telemetry),
ocr-recipe-image.ts + ocr-retry.ts (retry/global-cap bypass), structure-recipe.ts (kill-switch gates),
prompts-config.ts (cache fallback), import_rate_limiter.dart (client cost/daily/monthly budgets),
both ops runbooks. 6 NEW findings (1 High, 1 Medium, 4 Low). Dossier-known items and BUT-439/BUT-1032/BUT-1378
deliberately not re-filed. The High finding (cleanup wrong-path) is the headline: a real, verified unbounded-growth
cost leak masked by a test that seeds the stale path.
