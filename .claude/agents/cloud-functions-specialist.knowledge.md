# cloud-functions-specialist — accumulated knowledge

This file is the agent's long-term memory across sessions. The agent **MUST**
read it as Step 0 of every Cloud Functions task and **APPEND** to it on
discovery, real-bug fix, or user correction.

## How to update this file

- **Append-only** — supersede with a newer dated entry; never delete.
- **Date every entry** — `### YYYY-MM-DD — short title`.
- **Tag each entry** — [Pattern discovered] / [Bug fixed] / [User correction] /
  [Cost finding].

---

## Function families (functions/src/index.ts)

| Path | Concern | Trigger type | Test command |
|---|---|---|---|
| `llm/` (Mistral) | Cost-sensitive (paid LLM), latency, prompt safety | callable / HTTPS | (covered by integration) |
| `cleanup/` | Idempotent deletion cascades, batch limits | scheduled + onDocumentDeleted | `npm run test:lapsed-users` (the lapsed-users one) |
| `social/` | Profile propagation across user trees | onDocumentUpdated | (none yet) |
| `events/` | Telemetry append-only | onCall / HTTPS | `npm run test:parse-correction` |
| `admin/` | Migration / one-shot scripts (run via ts-node, not deployed) | manual via ts-node | n/a |
| `notifications/` | FCM push, batched, rate-limited | onCall + scheduled | `npm run test:send-notification`, `npm run test:activity-digest` |
| `ingredients/` | Soft-delete cascade | onDocumentUpdated | (covered by integration) |
| `feedback/` | Beta feedback intake (BUT-XXX) | onCall | (none yet) |
| `analytics/` | Aggregation jobs | scheduled | (none yet) |
| `middleware/` | Shared auth/validation wrappers | utility | (none yet) |
| `shared/` | Pure helpers, no triggers | utility | (none yet) |

When a new function family is added, append a row above + add a test command.

## Region & global options

```ts
setGlobalOptions({ region: "europe-west1" });
admin.initializeApp();
```

- All functions deploy to **europe-west1**. Do not introduce a function
  in a different region without explicit approval — clients call by
  function name + region, and a mismatch gives "function not found" with
  no helpful error.
- `admin.initializeApp()` runs once in `index.ts`. Do not re-init in a
  module file; it throws on second call.

## Firebase Functions v2 — what to use

- Firestore triggers: `onDocumentCreated`, `onDocumentUpdated`,
  `onDocumentDeleted` from `firebase-functions/v2/firestore`.
- HTTP/callable: `onCall`, `onRequest` from `firebase-functions/v2/https`.
- Scheduled: `onSchedule` from `firebase-functions/v2/scheduler`.
- Logging: `logger` from `firebase-functions/logger` — NEVER `console.log`
  in deployed functions (loses structured fields and request context).

## Idempotency rules (the most-bug-prone area)

Firestore triggers retry on uncaught exception. Every trigger handler must
be idempotent:

1. **Aggregate writes** (rating counts, follower counts) → use
   `FieldValue.increment(±1)` only when paired with an event-id guard:
   write the event-id to a `processed-events/{id}` doc inside the same
   transaction, abort the increment if the doc already exists.
2. **Cascade deletes** → check whether the target still exists before
   asserting "delete failed" — a retry will see it gone and that's fine.
3. **External-API calls** → use the request-id pattern: derive a stable
   request-id from the event payload, send it as an idempotency header
   to the external service.
4. **Email/push sends** → write a `sent-events/{id}` doc BEFORE the send;
   if the send fails after the doc write, the next retry sees it as
   "already sent" and skips.

If a function legitimately can't be made idempotent, document why in a
comment AND add a `processed-events`-style guard collection.

## Cost & cold-start

- Functions are billed per ms × allocated memory + per-invocation.
- Cold start ≈ 500–2000ms for Node TypeScript with these deps. Adding a
  large SDK (e.g. another Firebase Admin module) tacks on ~200ms each.
- Prefer narrow imports: `import { onCall } from "firebase-functions/v2/https"`
  rather than `import * as functions`.
- For LLM functions, set `timeoutSeconds: 540` (max for v2 callable) and
  `memory: "1GiB"` only if measured — over-allocation is paid every call.
- Scheduled cleanups: run hourly, not per-minute. Per-minute jobs run
  43,200×/month and accumulate cost.

## Secrets handling

- Use Firebase Secret Manager via `defineSecret("MY_KEY")` from
  `firebase-functions/params` — NOT environment variables in code.
- Never log a secret. `logger.info({ apiKey: secret })` will print it
  unredacted to Cloud Logging and bill you for the storage.
- The `.env` file in repo root is for the Flutter side only. Functions
  read from Secret Manager.

## Test commands (from `functions/`)

- `npm run build` — TS compile (must pass before any commit).
- `npm test` — runs the parity, lapsed-users, parse-correction, activity-digest, send-notification suites in sequence.
- `npm run test:rules:all` — Firestore rules tests (owned by `firestore-rules-tester`).
- `npm run serve` — local emulator with build step.

The non-rules tests use the same hand-rolled `test()` harness as the rules
tests. No jest. Don't introduce one.

## Logging conventions

```ts
logger.info("descriptive event", { userId, recipeId, action });
logger.error("operation failed", { err, userId });
```

- First arg is a **stable string** (queryable in Cloud Logging).
- Second arg is a **structured object** — no PII (no email, no message
  bodies, no recipe titles that might contain user names).
- For errors, include the actual error: `{ err }` works, `err.message` loses
  the stack.

## What NOT to do

- Do not deploy. User reserves `firebase deploy --only functions`.
- Do not change region in `index.ts` without explicit approval.
- Do not wire `console.log` — use `logger`.
- Do not write triggers without an idempotency story.
- Do not introduce a new test framework. Keep the hand-rolled harness.
- Do not import from `firebase-functions` (v1) — use `firebase-functions/v2/*`.

---

## Discovered patterns

*Append new dated, trigger-tagged entries below.*

### 2026-06-29 — family-diner ratings fold into public counter [Pattern discovered]

`updateRecipeRatingStats` (extracted to
`functions/src/ratings/update-recipe-rating-stats.ts`, now `(recipeId, db?)`
with an injectable db) folds TWO sources into one `recipe_social_stats/{recipeId}`
aggregate: `recipe_ratings` (`rating` + `createdAt`) and `family_ratings` where
`memberType == "profile"` (`stars` + `lastUpdatedAt ?? createdAt`). Three new
triggers `onFamilyRating{Created,Updated,Deleted}` on `family_ratings/{id}`,
gated to `memberType == "profile"`, call the same `scheduleRatingAggregation`
debounce path as the recipe_ratings triggers.

**Verified clean:**
- **No double-count** — confirmed against `family_rating_service.dart:147`:
  only a genuine self-rate (`memberType == user && enteredByUid == memberId`)
  mirrors to `recipe_ratings`. The aggregator folds only `profile` rows, so an
  adult's `user`-type family row is never added on top of their recipe_ratings
  row. The proxy-entered `user` rows are also correctly excluded.
- **Two-equality family query needs no composite index** — per
  `accepted-deviations.md`, equality-only `where(recipeId==).where(memberType==)`
  uses merged single-field indexes. Confirmed: no `orderBy`/range, so no
  composite. Not a finding.
- **memberType string match** — `HouseholdMemberType.name` produces exactly
  `"profile"`/`"user"` (enum in `family_rating.dart:8`); `toFirestore` always
  writes the field, so the server's raw-string `== "profile"` query is safe.
  Note the model's `fromName` defaults unknown→`profile` on READ only; doesn't
  affect the stored string the server queries.
- **Idempotency** — aggregator re-reads BOTH collections fully on each run and
  `set(..., {merge:true})`; debounce collapse is correct by construction
  (claim-by-delete drainer unchanged). Family update trigger gates on
  `before.stars !== after.stars` mirroring the recipe_ratings `rating` gate.
- **Drainer wiring** — `aggregate: updateRecipeRatingStats` in `index.ts:328`;
  drainer calls `aggregate(recipeId)` (one arg), optional `db?` defaults to
  `admin.firestore()`. Compatible.

**LOW finding (not a bug, behavior change worth recording):** a family diner
rating a PRIVATE (never-shared) recipe now creates a `recipe_social_stats/{recipeId}`
doc. That collection is `allow read: if isAuthenticated()` (firestore.rules:2299),
so any signed-in user who knows/guesses the recipe id can read an ANONYMOUS
aggregate (count/avg/distribution — no rater identity) for an otherwise-private
recipe. Pre-change, the doc only existed once a recipe entered the social rating
flow (`social.rateRecipe`). Acceptable given anonymity + opaque recipe ids, but
if private-recipe existence/score must stay hidden, gate stats creation on the
recipe being shared. Flagged, not fixed.

**Test fidelity nit:** the integration test seeds family doc ids as
`${recipeId}_${memberId}` but production `FamilyRating.buildId` uses
`$recipeId|$memberId` (pipe). Harmless — neither the query nor the aggregator
parses the doc id (both key off the `recipeId` field). Worth aligning if the
test is ever used as a doc-shape reference.

- **`_internal/rating_debounce/{recipeId}` was a 3-segment trap.**
  Spec said "marker doc at `_internal/rating_debounce/{recipeId}`"
  — but `_internal` (collection) → `rating_debounce` (doc) →
  `{recipeId}` would have to be a collection name, which is wrong for
  a single doc. Resolved via subcollection:
  `_internal/rating_debounce/markers/{recipeId}` (4 segments = doc).
  Same lesson as BUT-638's `metrics/weekly_north_star/snapshots/{isoWeek}`.
  Always count segments in plan specs and disambiguate before coding.

- **Claim-by-delete BEFORE aggregating.** Drainer pattern:
  `await doc.ref.delete(); await aggregate(recipeId);`. Deleting the
  marker first means a new rating that lands during aggregation creates
  a fresh marker, which the next drain picks up — re-fire is automatic.
  Aggregation itself is idempotent (reads the full ratings collection
  + writes one stats doc), so a rare double-run from a marker race is
  safe. Avoids needing a transaction across delete + aggregate.

- **count() aggregate for rate-limit checks.** The hourly cap on
  pings uses `collectionGroup('pings').where('fromUserId', '==', X)
  .where('createdAt', '>=', windowStart).count().get()`. Single
  billable read regardless of the user's actual ping volume — at
  worst $0.000036 per create vs $0.06+ if we had to fetch the docs.
  Always prefer `.count()` over `.get()` when only the cardinality
  matters.

- **Audit row goes to `audit/<event>/entries/{auto}` (4 segments).**
  Spec said `audit/ping_rate_limit/{autoId}` (3 segments) but for the
  same reason as the debounce marker, a 3-segment doc-id under
  `audit/ping_rate_limit` doesn't parse. Used
  `audit/ping_rate_limit/entries/{auto}`. Pattern reusable for any
  per-event audit collection.

- **Structured timing log = single helper closure, not scattered calls.**
  BUT-483: `const emitTiming = (success: boolean, extra?: ...) => {
  logger.info("structure_recipe.complete", { event, durationMs,
  textLength, mode, success, ...extra }) }` declared once at the top
  of the function, called at every exit path. Cheaper to maintain than
  copy-pasting the log object at 9+ exit points, and adding a new field
  later means one edit, not nine. Pair with per-exit `reason` field for
  failure-mode breakdown (kill_switch_ai / not_a_recipe /
  rate_limited / etc.) — a future Logs-Explorer slice on `reason`
  becomes trivial.

- **Cloud Logging metric filter is GCP console config, not code.**
  BUT-483's "wire a Cloud Logging metric filter for p95 latency"
  surfaces in plans as a code task but the actual config lives in
  Cloud Console (Logging → Logs Explorer → Create Metric). The CF code
  contribution is just emitting the structured fields cleanly. Ops
  step belongs in a runbook, not in code. Established
  `functions/RUNBOOK.md` for this and future ops-only notes.

- **collectionGroup index needs `queryScope: COLLECTION_GROUP`.** Most
  existing `firestore.indexes.json` entries use `"queryScope":
  "COLLECTION"` because they're per-parent queries. The new ping
  indexes (`expiresAt` ASC, `fromUserId` + `createdAt`) MUST be
  COLLECTION_GROUP because the queries use `db.collectionGroup('pings')`.
  Wrong scope = `FAILED_PRECONDITION` at first run (emulator silently
  auto-builds the right one, masking the deploy bug).

- **Pre-existing test failures unrelated to your changes.**
  `notification-rate-cap.ts:99` calls `admin.firestore()` lazily inside
  `checkAndIncrement`; tests for `detect-lapsed-users` and
  `send-activity-digest` don't initialise an app and don't stub
  `checkAndIncrement` either, so the chain throws `app/no-app`. This
  was already broken on `main` before this sprint. Document in the
  hand-off rather than chase fixes outside scope. Lesson: when running
  the full `npm test` after a multi-task sprint, sanity-check failures
  by `git log --oneline -1 -- <broken-file>` to see if the test file
  was last touched in your work or earlier.

### 2026-06-27 — BUT-1386 verifySignupAge DI-core tests [Pattern discovered]

Wrote `functions/src/__tests__/verify-signup-age.test.ts` (7 cases, all green
via `npx ts-node`) for `account/verify-signup-age.ts`'s
`runVerifySignupAgeWithDeps(deps, uid, birthYear)` + `enforceIpAuditCap(db, ip)`.
Mirrors `request-account-deletion.test.ts`: hand-rolled `test()` harness, fake
`{db, auth}` injected, no emulator. Registered `test:verify-signup-age` in
package.json so `run-all-tests.js` auto-discovers it (`npm test`).

**Patterns worth remembering:**

- **Assert field ABSENCE, not just presence, for data-minimisation contracts.**
  This function's whole Legal premise is what it *doesn't* write. The rejection
  audit row must carry no `uid`/`userIdHash`/`birthYear`/`birthDecade`, and the
  compliance row must carry no raw `birthYear`. Tests use `!("birthYear" in row)`
  etc. A presence-only test would pass even if someone later leaked the uid into
  the rejection row — exactly the regression that matters here.

- **`HttpsError.code` is namespaced `functions/<code>`.** When asserting an
  `HttpsError` from firebase-functions, `err.code` reads
  `"functions/resource-exhausted"`, not bare `"resource-exhausted"`. Accept both
  so the test isn't brittle to the SDK's prefixing. Same trap will hit any future
  test asserting on an HttpsError code in this repo.

- **Use real `new Date().getFullYear()` for age boundaries, don't hardcode.**
  The SUT computes `currentYear` from the system clock, so the test derives
  boundary birth years as `CURRENT_YEAR - MIN_AGE_YEARS` (admit) and
  `CURRENT_YEAR - (MIN_AGE_YEARS - 1)` (reject). Hardcoding `2011`/`2012` would
  silently rot as the year ticks over. The function isn't injectable on `now`,
  so the test mirrors its clock source instead.

- **Idempotency is asserted via call COUNTS on the fake, not just return value.**
  The retry case returns `compliant:true` whether or not it re-wrote — so the
  real assertions are `setClaimsCallCount === 0`, `setWrites.length === 0`,
  `auditRows.length === 0`. Counting side effects on the injected fake is how you
  prove a no-op, not the response envelope.

- **Rethrow-path test asserts the returned value stayed `undefined`.** For "must
  not proceed as admitted when deleteUser throws", catch the throw AND assert the
  pre-initialised `returned` sentinel is still `undefined` — proves the function
  never reached a `return { compliant: ... }` before throwing. Catching alone
  wouldn't distinguish "threw" from "returned then a later line threw".

- **Fail-closed test = inject a transaction error, assert it throws.** For
  `enforceIpAuditCap`, the FinOps contract is "a Firestore error denies, never
  resolves." Fake `runTransaction` rejects when `txError` is set; the test asserts
  the cap rethrows as `resource-exhausted`. The function's own `logger.error` line
  prints during this case — that's expected output, not a failure.

- **Logger ERROR/INFO lines interleave with PASS output.** The rejection-delete
  and fail-closed cases legitimately emit `logger.error`; the harness has no
  logger-silencing seam (unlike `ocr-validation.test.ts`). Don't mistake those
  structured-log lines for test failures — the trailing `N/N passed` is the
  source of truth.

### 2026-06-27 — BUT-1386 verify-signup-age production-side review [Pattern discovered]

Reviewed the callable + DI core + IP cap before commit. Implementation is sound;
no Critical, no High. Notes worth keeping for the next account-callable:

- **Region is inherited, not pinned per-function.** `verify-signup-age.ts` sets no
  `region` in its `onCall` options — it relies on `setGlobalOptions({ region:
  "europe-west1" })` in `index.ts`. That is the correct house pattern (the client
  uses `instanceFor(region: 'europe-west1')`, which matches). Do NOT add a
  per-function region; the global option already covers it, and a per-function
  override would be redundant noise. Verified the export at `index.ts:74` and the
  global option at `index.ts:25`.

- **Write-ordering rationale (claim → birthYear → audit) is correct and the
  fail-window is benign.** If `setCustomUserClaims` succeeds but the birthYear
  `set()` then fails, the function throws `internal` and the client retries; the
  retry hits the idempotent no-op branch (`existingClaims.ageCompliant === true`)
  and returns success WITHOUT ever writing birthYear or the audit row. That is a
  latent gap (claim set, birthYear never stored, no consent audit) but: (a) the
  birthYear writes are a single `Promise.all` that rarely partially fails, (b) the
  gate (claim) is the safety-critical artifact and it IS set, (c) worst case is a
  compliant user missing their stored birthYear, not a minor getting through. Rated
  Low, not High — the ordering deliberately favors "never able-to-post without a
  recorded-age decision" over "never claim-without-birthYear". If this is ever
  tightened, the fix is to re-check birthYear-doc presence in the idempotent branch,
  not to reorder.

- **Consent audit retention wiring verified end-to-end.** `writeComplianceAudit`
  writes `operation: "consent_age_verification"` + `timestamp: serverTimestamp()`.
  `audit_logs/purge-expired.ts` matches consent via `op.startsWith("consent_")`
  (CONSENT_OPERATION_PREFIX) → 730-day retention, and queries `where("timestamp",
  "<", cutoff)`. Field name and prefix both line up — the 730-day claim in the ADR
  holds. The rejection audit (`operation: "age_verification_rejected"`, no prefix)
  correctly falls into the 180-day general bucket and carries no identifier.

- **Rejection audit is written BEFORE `deleteUser` and has no dedup.** A bot that
  passes the per-IP cap (≤5/h) and the per-user bucket could in principle write up
  to 5 rejection rows/hour/IP. That is exactly the cost-bound the IP cap exists to
  enforce, so it's working as designed — the rows are intentionally non-identifying
  and cheap. Not a finding; recording so a future reviewer doesn't re-flag it as a
  "missing idempotency guard" — these rows are deliberately NOT deduped (each
  blocked attempt is a distinct event for the security record).

- **IP cap fail-closed is correct for an account gate** (unlike the notification
  gates which fail-OPEN per the 2026-04-30 entry). The distinction: notification
  gates fail-open because muting all pushes during an infra blip is worse than a few
  extra sends; an age/abuse gate fails-closed because admitting an unverified signup
  during a blip is the worse outcome. Both are right for their domain — don't
  "harmonize" them.

- **`request.rawRequest?.ip` can be a proxy/load-balancer IP.** The per-IP cap keys
  on `request.rawRequest?.ip ?? "unknown"`. Behind Google's front-end this is
  usually the real client IP, but if it ever resolves to a shared egress the cap
  buckets many users together (false positives) — and the `"unknown"` fallback
  buckets ALL ip-less callers into one key. Acceptable for a signup-once flow at
  beta scale; flag if abuse patterns suggest the key needs `X-Forwarded-For`
  parsing. Low.

### 2026-06-28 — BUT-1404 audit-log general purge starvation fix [Bug fixed]

`audit_logs/purge-expired.ts` — `purgeAuditCategoryWithDb` for the "general"
category fetched the oldest 10k docs with `where('timestamp','<',cutoff).limit(10000)`
then filtered consent rows client-side. As the collection aged, consent rows
(730d retention) filled that unfiltered 10k window, leaving expired general
rows (180d) unpurged — GDPR Art 5(1)(c) data-minimisation breach + unbounded
cost. The `truncated` flag was also computed from the post-filter deleted count
(never ≥ 10k for general after filtering), so real truncation was invisible.

**Fix (Path A)**: server-side filter via `CONSENT_OPERATIONS` array +
`where('operation', 'in'/'not-in', CONSENT_OPERATIONS)` before the timestamp
range and limit. Admin SDK 13.8.0 supports multi-inequality queries (operation
`in`/`not-in` + timestamp `<`); confirmed by zero TS errors at build.

**Discriminant**: the `operation` field present on every audit_log write. The
consent set is bounded: 4 values (`consent_age_verification`, `consent_granted`,
`consent_updated`, `consent_revoked`), all prefixed `consent_`. Firestore
`not-in` supports up to 10 values; current set is 4. If it exceeds 10, a new
`retentionTier` field + backfill would be needed (ops-blocked).

**Index added**: composite `(operation ASC, timestamp ASC)` on `audit_logs`
in `firestore.indexes.json` — required for `in`/`not-in` + range on a
different field. This IS a genuine composite (range + in/not-in across two
fields); not an equality-only case.

**truncated flag**: after the fix, `snapshot.docs.length` == number deleted
(no client-side filtering), so `deleted >= maxDocs` correctly reflects
server-side truncation.

**Test change**: `makeFakeDb` rewritten to support the new two-`where` chain
(`operation in/not-in` + `timestamp <` + `limit`). Two new test cases:
- `generalPurgeNotStarvedByConsentRows` — the starvation scenario: window of
  10 slots filled by consent rows + 1 expired general doc → general doc IS
  deleted (would have returned 0 with old code).
- `consentOperationsArrayIsExhaustive` — pins the 4 known consent op values
  against `CONSENT_OPERATIONS` so a new consent op without a list update
  turns red immediately.

**Patterns worth remembering**:
- **Unfiltered `limit` + client-side filter = starvation.** Whenever a purge
  fetches a bounded window and post-filters, a long-lived category will
  crowd out the short-lived one. Always push the category discriminant into
  the server-side query so `limit` applies to the right set.
- **`CONSENT_OPERATIONS` exhaustiveness guard belongs in the test, not in
  code.** The write path is in multiple files; a closed enum in a `.ts` const
  array + a test that pins the known values is the cheapest guard against
  list drift. If the list grows past 10, that test also fails (Firestore
  `not-in` max).
- **Multi-inequality in Admin SDK 13+ works** — `operation not-in` (treated
  internally as a range filter) + `timestamp <` on a different field is
  supported without needing to restructure the query or add a discriminant
  field at write time.

### 2026-06-28 — BUT-1392 CF tests wired into CI [Pattern discovered]

Added the Cloud Functions unit-test CI gate (`cloud-functions-unit.yml`).
Findings and patterns for future reference:

**5 test files had no npm script** (run-all-tests.js auto-discovers `test:*`
so missing scripts = missing coverage with no error):
- `acquisition-rules.test.ts` — emulator-bound rules test; got `test:rules:acquisition`
  and was added to `test:rules:all`. NOT added to DI-seam auto-discovery (prefix
  `test:rules:` is excluded by the runner).
- `log-parse-event-domain.test.ts` — DI-seam unit; got `test:log-parse-event-domain`.
- `rate-limiter-refill.test.ts` — DI-seam unit; got `test:rate-limiter-refill`.
- `validate-limit.test.ts` — DI-seam unit; got `test:validate-limit`.
- `winback-context.test.ts` — DI-seam unit; got `test:winback-context`.

**Two config gaps in `firestore-rules.yml`**: the path filter lists for both
`pull_request` and `push` were missing 7 test files that ARE in `test:rules:all`
(`realtime-menus-rules`, `friend-categories-rules`, `members-collection-group-rules`,
`friends-accept-rules`, `recipe-ratings-rules`, `accept-friend-request.integration`,
`on-report-created.integration`) plus `acquisition-rules.test.ts`. All added.
Also added `functions/src/social/**` path trigger (was missing; `social/` changes
could affect friends-accept and on-report-created without triggering the rules CI).

**Two pre-existing broken suites excluded from the new CI gate** — MUST NOT be
included in `cloud-functions-unit.yml` or the gate is red on day 1:

1. `test:app-check-enforcement` — `verifySignupAge` (BUT-1386) and
   `acceptFriendRequest` (B1 commit) are new `onCall` exports but were never
   added to the test's `USER_FACING` or `ADMIN_EXEMPT` classification sets.
   Fix: add both to `USER_FACING` (both are user-callable, not admin-only).

2. `test:request-account-deletion` — `deleteUserSubcollections` in
   `account/account-deletion-cascade.ts` gained a
   `.orderBy(FieldPath.documentId()).startAt(...).endAt(...)` chain in BUT-1390
   (commit 08e04be29). The unit test's `makeFakeDb.makeCollection` fake does not
   stub `orderBy()`, so the chain blows up and the `user_subcollections` step
   shows as failed. Fix: add `orderBy() { return this; }` to the query stub in
   the test file.

Both failures confirmed pre-existing on main (neither file appears in `git diff`).
Documented in `functions/scripts/run-ci-unit-tests.js` with fix instructions.

**CI job shape** (`cloud-functions-unit.yml`): Node 22, `npm ci` → `npm run build`
→ `node scripts/run-ci-unit-tests.js`. No Java/emulator needed. Triggers on any
`functions/src/**` change. 51/51 suites, ~108s locally.

**Distinction between the two runners**:
- `run-all-tests.js` — developer tool, runs ALL discovered suites including the
  two broken ones. Intent: "see everything, decide what to fix". 49 suites (53
  discovered minus the 4 new ones that just got added = 53 total now).
- `run-ci-unit-tests.js` — CI tool, excludes 2 known-broken suites. 51/51 green.
  Remove a suite from `CI_EXCLUDE` once it's fixed locally and confirmed green.

Pattern: whenever a new `onCall` export is added, immediately update the
`USER_FACING` or `ADMIN_EXEMPT` set in `app-check-enforcement.test.ts`. Forgetting
this is the source of the test:app-check-enforcement failure.

### 2026-06-28 — BUT-1423 post-deploy smoke gate in deploy-firebase.yml [Pattern discovered]

Added a post-deploy presence-check step to `.github/workflows/deploy-firebase.yml`
(runs after the Deploy step, before the Summary). Fires only when `DEPLOY_TARGET`
is `functions` or `all`.

**Mechanism**: `firebase functions:list --project butlery-app-1 --json` queries
the Cloud Functions control plane and returns the deployed function manifest.
A bash loop checks that 8 representative function names appear as quoted tokens
in that JSON output. Any missing name exits 1 and fails the workflow with a
`::error::` annotation.

**Why `firebase functions:list --json` and substring grep**:
- The `--json` flag gives a stable machine-readable format.
- `grep -qF '"functionName"'` (fixed-string literal match) is simple, no JSON
  parser needed, and is robust to minor field-order changes across firebase-tools
  versions.
- The function name appears in the `"name"` resource path and/or as an `"id"`
  field; either occurrence makes the grep succeed.

**8 representative functions chosen** (span all major families, stable long-term):
`structureRecipe`, `ocrRecipeImage` (LLM callables), `sendNotification`
(notifications), `onUserDeleted` (GDPR cascade), `verifySignupAge` (age-gate),
`requestAccountDeletion` (account), `cleanupExpiredCache` (cleanup scheduler),
`drainRatingAggregations` (rating scheduler). Migration-lifecycle-bound functions
(e.g. `backfillRecipeCommentsDenorm`) are deliberately excluded — they may be
removed and a false-fail would block future deploys.

**Fail-safe contract**: the step has NO error suppression. If `firebase
functions:list` itself errors (auth failure, network blip, CLI bug), `set -euo
pipefail` propagates the non-zero exit. Better a false-fail (redeploy to
investigate) than a silent pass over a broken function fleet.

**Auth**: no new secrets. `GOOGLE_APPLICATION_CREDENTIALS` is set by the
Authenticate step earlier in the same job; the `env:` block in the new step
passes it through.

**Lesson**: `firebase deploy` exiting 0 does NOT guarantee all functions are
callable. A bad runtime-config or build artifact can leave individual functions
in `DEPLOY_FAILED` state on the backend. The only way to detect that in CI is
a separate control-plane query after deploy.

### 2026-06-29 — Phase 5 item 15 family-data deletion: retry-handle ordering hazard [Pattern discovered]

`deleteFamilyData(db, uid)` in `account-deletion-cascade.ts` cascades family
data per shared household with two branches (sole member → teardown; others
remain → membership scrub + re-home + proxy scrub). Field names all verified
against the Dart models (`HouseholdMember.userId`, `FamilyRating.memberId`/
`enteredByUid`/`householdId`, `DinerProfile.createdBy`). All compound queries
are equality-only (`householdId==` + `memberId==`/`createdBy==`/`enteredByUid==`)
→ no composite index needed (accepted-deviations: equality merges on
single-field indexes).

**The hazard (general, reusable):** in a cascade step that is keyed off a
**shared/parent handle** rather than off `uid`, you must perform the
destructive mutation that *destroys the retry handle* LAST — after all
dependent child cleanup has committed. Otherwise a transient mid-step failure
strands orphans that a whole-cascade retry can no longer reach.

Two manifestations in this function:
1. **Remaining-members branch** does `hhDoc.ref.update({ memberUserIds:
   arrayRemove(uid), ... })` BEFORE re-homing diner profiles and scrubbing
   proxy attribution. The top-level re-entry query is `households where
   memberUserIds array-contains uid`. Once the arrayRemove commits, a retry
   no longer matches the household, so an orphaned child profile
   (`createdBy == deletedUid`) or un-scrubbed proxy verdict is never fixed —
   yet `auth.deleteUser` still runs at the end. Fix: reorder so the household
   membership scrub is the LAST mutation in the branch.
2. **Sole-member branch** deletes children via `batchDeleteAll` (which is
   `commitInChunks` with `strict:false` — swallows commit errors) and then
   `hhDoc.ref.delete()` unconditionally. If a child chunk fails, the error is
   swallowed and the household doc — the only handle to re-derive `hid` — is
   deleted anyway. Residual `diner_profiles`/`family_ratings` with that
   `householdId` are unreachable on retry. Fix: in the teardown, delete child
   docs with `strict:true` (or otherwise confirm child commits succeeded)
   before deleting the household doc; a thrown error then marks `family_data`
   failed and leaves `uid` in `memberUserIds` so the retry re-matches.

**Why this matters here specifically:** every OTHER cascade step queries by
`where(<field>, "==", uid)`, so residuals are always re-discoverable on retry
regardless of partial failure. Family data is the first step keyed on a parent
(`householdId`) whose handle the step itself destroys — breaking the cascade's
stated invariant ("every step ... safe to re-run if the caller retries after a
partial failure"). When adding cascade steps, check: *is the retry query keyed
on uid, or on a parent I'm about to delete/mutate?*

Severity rated High (orphan under retry + GDPR incompleteness; happy path is
correct, requires a transient mid-step failure). The 5 integration tests cover
happy-path branches but none injects a mid-step failure + re-run, so the
ordering regression is untested.

### 2026-06-29 — family-data storage-limitation sweep [Pattern discovered]

`functions/src/family/purge-dormant-family-data.ts` —
`purgeDormantFamilyData`, weekly `onSchedule` ("30 3 * * 0", UTC, 300s),
inherits europe-west1 from `setGlobalOptions`. Core
`runDormantFamilyPurge(db, now)` test seam exercised by emulator integration
test `__tests__/purge-dormant-family-data.integration.test.ts`
(`npm run test:integration:family-data-purge`, NOT in `test:rules:all` — needs
emulator). GDPR Art. 5(1)(e): a household whose family data
(`diner_profiles` + `family_ratings`) is dormant 24mo is warned, then purged
unless reactivated. Household doc + accounts are NOT deleted.

**New function family**: `family/` — household-scoped family-rating feature CFs.

| Path | Concern | Trigger | Test |
|---|---|---|---|
| `family/` | Household-scoped retention/aggregation; GDPR storage-limitation; idempotent warn→purge | scheduled + (aggregation triggers) | `test:integration:family-data-purge`, `test:integration:family-rating-aggregation` |

**Patterns worth remembering**:

- **Warn-before-purge two-pass is the GDPR-safe shape for any auto-deletion of
  user data.** Pass 1 stamps `familyDataPurgeScheduledAt = now + grace` + writes
  an in-app warning; pass 2 only deletes once `now >= scheduledAt`. The purge
  branch is structurally unreachable on the pass that first detects dormancy
  (it requires the schedule field to already exist). Reactivation clears the
  schedule. Never auto-delete user data on first eligibility — always a recorded
  warning + grace window first.

- **Dormancy = max of parent + all children timestamps, computed by reading the
  children, not an `orderBy limit(1)` probe.** For SMALL per-parent child counts
  (a household has a handful of diners/ratings) reading all children to compute
  the newest timestamp is correct: the docs are needed for the delete anyway, and
  `orderBy("lastUpdatedAt","desc").limit(1)` would force a composite index per
  collection for no real saving. Only switch to the indexed probe when per-parent
  child counts grow large.

- **`.limit(N).get()` on the top-level scan is "bounded but NOT paginating".**
  This sweep reads `households` with `.limit(200)` and no cursor — so beyond 200
  households the rest are silently never processed that run, and without an
  `orderBy` the scanned subset can shift between runs. Not a crash and purge
  correctness holds for those scanned, but it starves the overflow of any
  dormancy processing → defeats the storage-limitation guarantee. Flagged
  Medium (latent; fine at beta scale). Fix = the `__name__`-cursor loop already
  in `shared/batch-update.ts:batchUpdateQueryPaginated`. Rule: a "bounded"
  comment is not pagination; if the collection is unbounded, use a cursor loop.

- **`commitInChunks(db, docs, (b,d)=>b.delete(d.ref), { strict: true })` is the
  right primitive for a must-be-complete delete.** strict:true re-throws on any
  chunk failure, aborting BEFORE the parent stamp write, so the scheduler retries
  and you never get a silent partial purge of regulated data. Stamp the parent
  (`familyDataPurgedAt`) only AFTER the children commit succeeds.

- **System/self in-app warnings**: `warnMembers` writes `user_notifications`
  with `senderId == recipient uid` (self-notification). Best-effort (per-member
  try/catch, warn-logged, never blocks the schedule stamp). Watch that the
  notification-render path doesn't show a confusing "from yourself" sender.

- **Test seam shape holds**: `runX(db, now)` plain async + one-line `onSchedule`
  delegate, same as the analytics CFs. Integration test injects a fixed `now`
  and seeds one household per branch. Gap noted in this review: the
  reactivation-clears-schedule and empty-children-clears-stale-schedule branches
  (both have side effects) are not yet asserted.

### 2026-06-29 — BUT-1427 digest decoupled from reEngagement category [Bug fixed]

The weekly activity-digest push (`analytics/send-activity-digest.ts`) was passing
category `"reEngagement"` to `sendPushToUserRespectingPreferences`, so a user who
opted out of win-back pings silently lost their digest too — two distinct lifecycle
channels (retention summary for active users vs. win-back for lapsed users) collapsed
into one toggle. Fix added a dedicated `"digest"` member to the `NotificationCategory`
union in `shared/preference-aware-push.ts`, gated default-on, and switched the digest
scheduler to pass `"digest"`. Reviewed clean — no Critical/High; 6/6 test, tsc clean.

**Patterns worth remembering / confirmed this review:**

- **Default-on for a NEW category must be unconditional `return true` on a missing
  field — no fallback to a sibling category's stored value.** The `reEngagement`
  branch falls back to `categorySettings["NotificationCategory.system"]` because that
  is the pre-existing client-side toggle it maps to. `digest` correctly does NOT
  borrow any sibling boolean: there is no pre-existing client toggle for it, so any
  borrowed value would mean "a user who set some *other* category controls digest."
  A brand-new server-side category whose field predates no client UI must read only
  its own optional boolean and default-on otherwise. This is the no-silent-mute
  guarantee: prefs docs written before BUT-1427 have no `digest` field → enabled.

- **Push category gate is independent of `evaluateSendGate`.** The digest scheduler
  runs `evaluateSendGate({ notificationType: "activity_digest" })` (importance +
  quiet-hours + RC suppression + send-event) BEFORE the preference-aware push, and
  that gate keys off `notificationType`, not the push `category` literal. The
  category change touches only the `isCategoryAllowed` opt-out check inside the
  helper. `notification-importance.ts` still lists `"activity_digest"` (unchanged) —
  the two gates are orthogonal and both correctly still fire. Don't conflate the
  analytics `notificationType` string with the preference `category` literal: they
  are separate taxonomies that happen to both describe "digest."

- **Adding a union member is safe for other callers only because every other call
  site passes a string literal, not a variable.** `detect-lapsed-users.ts`,
  `send-notification.ts`, and `deliver-scheduled-notifications.ts` all pass the
  literal `"reEngagement"`; widening the union to `"reEngagement" | "digest"` cannot
  break them (a literal is still assignable). If any caller had passed a
  `NotificationCategory`-typed variable through a switch, widening the union would
  have demanded a new branch — `tsc` would have caught it via exhaustiveness only if
  the switch returned the union type. Here the trailing `return true` makes
  `isCategoryAllowed` total, so an unhandled future category fails OPEN (sends),
  which is the right default for a notification gate but worth knowing: a typo'd
  category silently sends rather than erroring.

- **Per-frequency vs per-channel are two separate opt-outs and must both be checked
  at the right layer.** `digestFrequency !== "never"` (does the user want digests at
  all, and how often) is enforced in the scheduler upstream; the `digest` boolean
  (is the push *channel* allowed right now) is enforced in the helper. Don't try to
  fold frequency into the category gate — the scheduler already filtered the
  user set before the push fan-out, and the helper has no frequency context.

### 2026-06-30 — BUT-1396 follow-up: realtime_recipes deletion keyed on the wrong owner field [Bug fixed]

`deleteRealtimeRecipes` (in `account-deletion-cascade.ts`, Tier 1) queried
`realtime_recipes` with `.where("userId", "==", uid)`. That collection has **no
`userId` field** — the authoritative owner field is `ownerId`:
- the Flutter model serializes `ownerId` (`lib/models/realtime/realtime_recipe.dart:327/408`),
- the Firestore rule gates read/delete on `resource.data.ownerId`
  (`firestore.rules` ~909-923; only the owner may delete).
So the filter matched **zero docs** — a deleted user's collaborative recipes were
exported under Art. 15 but never erased under Art. 17 (right-to-erasure leak). Fix
(already applied): filter on `ownerId`. Verified the step is wired into the
orchestrator at `request-account-deletion.ts:209` (Tier 1, parallel) — a fix to an
unwired function would be moot.

Cross-checks done (worth repeating for any "wrong filter field" cascade bug):
- **Other writers of the same collection**: `admin/reset-user-data.ts` deletes
  `realtime_recipes` via a collection *registry* (recursive/whole-collection delete),
  NOT a `userId` filter, so nothing depended on the old field.
- **Owner vs participant**: deletion must key on the OWNER, never on
  `participantIds`. A collaborator deleting their account must not erase someone
  else's recipe (and the rule only lets the owner delete anyway). The regression
  test pins this with a `rt-participant` fixture (TARGET is a participant on OTHER's
  recipe → must survive).

**Regression test added** to the emulator-backed
`request-account-deletion.integration.test.ts` (now 42 tests): 3 `realtime_recipes`
fixtures — `rt-own` (ownerId==TARGET → deleted), `rt-control` (ownerId==OTHER →
survives), `rt-participant` (TARGET only a participant → survives). Proved the test
is a real guard, not a tautology: temporarily reverting the SUT to the buggy
`userId` filter turns exactly the owned-deleted assertion RED (41/42), restoring
`ownerId` returns 42/42.

**Patterns worth remembering**:
- **"Wrong filter field" cascade bugs are silent and asymmetric.** An over-broad
  filter deletes too much (loud — control docs vanish); a wrong-field filter
  deletes *nothing* (silent — the negative-only "control survives" assertions still
  pass). A GDPR-deletion test MUST include a POSITIVE "owned doc is gone" assertion,
  not just "control survives" — only the positive one catches a no-op filter.
- **Prove the test bites.** For a regression test against an already-applied fix,
  flip the SUT back to the bug for one run and confirm the new assertion goes red.
  Cheap, and it's the only thing that distinguishes a real guard from a green
  tautology.
- **Cross-check the owner field across all three layers** when a cascade filters by
  identity: the Flutter model's `toFirestore` key, the Firestore rule's
  `resource.data.<field>`, and any sibling deleter (admin reset, export). The export
  side already filtered on `ownerId`; "export ⊇ erased" requires the SAME field on
  both — a mismatch is the tell.
- **Emulator workflow**: `bash .claude/hooks/ensure-firestore-emulator.sh` starts a
  local Firestore emulator on 127.0.0.1:8080 (needs firebase-cli + java, both
  present in this env); then
  `npx ts-node src/__tests__/request-account-deletion.integration.test.ts`. The test
  self-clears its namespace via the emulator REST DELETE endpoint before/after.

### 2026-06-30 — BUT-1450 residual-probe field scoping for notification analytics [Pattern discovered]

`probeResidualData` in `account/account-deletion-cascade.ts` (the post-cascade
"did anything survive?" sweep) was extended to cover the notification-analytics
collections that `deleteNotificationAnalytics` erases. Reviewed clean; build
clean; 42/42 deletion-cascade integration tests pass against the live emulator.

**The probe MUST mirror the deleter's field scoping, collection by collection.**
`deleteNotificationAnalytics` erases on these exact fields:
- `notification_history` / `notification_batches` / `notification_engagement` → `userId == uid`
- `notification_delivery` → `senderId == uid` AND `targetUserId == uid` (two queries, unioned)

The change reflects that split correctly: the first three go in the `userId`-scoped
`probes` array (the existing `count().where("userId","==",uid)` loop); `notification_delivery`
gets its OWN loop over `["senderId","targetUserId"]`. Putting `notification_delivery`
in the userId array would silently `count()` zero — the exact `realtime_recipes`/`ownerId`
wrong-field trap from BUT-1396 (a deleter/probe filtering the wrong field passes green
while leaving Art.17 data behind). So the probe now catches a silent delete failure for
each of the five collections, not just three.

**Patterns worth remembering**:
- **A residual probe is only as good as its field alignment with the deleter.** When
  reviewing a new probe, open the matching `delete*` function and diff the `.where()`
  field per collection. A probe on the wrong field is worse than no probe — it reports
  "clean" while data persists.
- **`count()` is the right primitive for residual probes** (vs `limit(1).get()` used for
  the feature-retention "did it ever happen" flags): here we want the actual surviving
  doc count in the warn log for ops triage, and `count()` is a single aggregation read.
- **The probe never aborts the cascade** — preserved. Both loops swallow errors into
  `logger.error` and bump `residual += 1` on probe failure (fail-toward-flagging:
  a probe that itself errors is treated as "possible residual" so `residual_data_detected`
  still trips). The only side effect is appending `"residual_data_detected"` to
  `result.failedCollections`; nothing throws, no retry storm.
- **Accepted Low — self-notification double-count.** A `notification_delivery` doc with
  `senderId == uid` AND `targetUserId == uid` (user notified themselves) is counted twice
  across the two probe queries, inflating the residual total. Harmless: `residual` is a
  trip-the-flag signal, not an exact figure, and the deleter's `batchDeleteAll` dedups by
  doc ref anyway. Not worth a `Set<docId>` dedup pass on a once-per-deletion sweep.
- **Coverage gap noted, not a blocker.** Neither `request-account-deletion.test.ts` (unit)
  nor the integration suite asserts `probeResidualData` behaviour directly — the integration
  run exercises it only incidentally (ends "cascade: completed with no failed collections").
  A targeted probe test (seed a residual `notification_delivery.senderId` doc, assert
  `residual_data_detected` trips) would lock the field scoping against future drift; left
  for the owning ticket.

### 2026-07-01 — BUT-674 minor default-private profile in verifySignupAge [Pattern discovered]

`verify-signup-age.ts` gained `AGE_OF_MAJORITY_YEARS = 18` and a derived
`isMinor = compliant && age < 18` threaded into `writeComplianceArtifacts`. The
`users/{uid}` merge-set now writes `{ birthYear, isMinor }`, plus
`isSearchable: false` ONLY when `isMinor` — the default-private profile for
15–17-year-olds. Reviewed clean, no findings.

**Why the derivation can't mislabel:** the non-compliant branch (`!compliant`)
returns after `writeRejectionAudit` + `auth.deleteUser` BEFORE any artifact
write, so `isMinor` is only ever read for compliant users. `compliant &&` is
therefore belt-and-suspenders — the value is meaningful by construction.

**Why the `isSearchable:false` write is retry-safe** (confirmed Malin's reasoning):
- The CF runs only during onboarding, before the profile privacy toggle is
  reachable in the client, so it can never clobber a later minor opt-in.
- Both call sites (first-pass + BUT-1435 idempotent-retry branch) thread the
  same `isMinor`, and the write is a `merge:true` set of the same value — a
  retry re-writing `isSearchable:false` is a no-op in effect, harmless.
- Adults get `isMinor:false` and NO `isSearchable` key (the field is only added
  to the write object `if (isMinor)`), so an adult's `isSearchable` default —
  which lives in `UserProfile` — is never touched by this CF.

**Test pattern:** the existing `makeFakeDb` already captures every `doc().set()`
into `setWrites[{path,data,merge}]`, so asserting the new fields needed no fake
changes — just `find(w => w.path === users/${uid})` and inspect `.data`. Added
3 BUT-674 cases (adult isMinor:false + no isSearchable across [1990, exactly-18];
minor isMinor:true + isSearchable:false across ages 15/16/17; idempotent-retry
minor still writes both). Full suite 10/10, tsc clean. Run:
`npm run test:verify-signup-age`.

**Age boundary note:** Jan-1 (year-subtraction) cutoff means age is conservative
— someone turning 18 later this year is still `isMinor:true` until Jan 1. That's
the safe direction for a protection default (over-protect, never under-protect);
matches the same conservative cutoff the ≥15 gate already uses.

### 2026-07-01 — BUT-674 post-review: `isSearchable` write removed, `isMinor` mirrored to prefs [User correction]

SUPERSEDES the `isSearchable:false` half of the 2026-06 BUT-674 entry above.
A security review changed `writeComplianceArtifacts` in
`functions/src/account/verify-signup-age.ts`. The `isSearchable:false` write to
`users/{uid}` was **DEAD** — user search reads `public_profiles.isSearchable`,
not the root user doc — so it was removed entirely (search-suppression deferred
to a follow-up that threads `isMinor` through onboarding profile creation +
the searchable opt-in + a group-DM CF). New behavior:

- `users/{uid}` (root) now gets `{ birthYear, isMinor }`. `isMinor` here is
  **load-bearing**: `firestore.rules` reads it via `get()` to gate 1:1 DMs to a
  minor. Root doc is owner/admin-read only, not loaded into the client profile.
- `users/{uid}/settings/preferences` now gets `{ birthYear, isMinor }` (was just
  `birthYear`). The client hydrates its `UserProfile` from this **private** doc,
  so this mirror is how the app learns `isMinor` for analytics minimization —
  without it the client's `isMinor` is always false and minimization is inert.
- NO `isSearchable` is written by the CF anywhere anymore.

**Lesson — verify the *consumer* of a field before trusting a "private default"
write.** The old entry rationalized `isSearchable:false` as retry-safe (true) but
never checked that anything *reads* it at that path. It didn't — the client reads
`isSearchable` off `public_profiles`. A write nobody reads is dead code that looks
correct in every unit test (the fake db happily records it). When a CF writes a
"protection default", trace the read path in the client/rules, not just the write.

**Test update:** the 3 BUT-674 cases previously asserted `isSearchable:false` on
`users/{uid}` — now wrong. Updated to: adult → `isMinor:false` on BOTH docs + no
`isSearchable` anywhere; minor(15/16/17) → `isMinor:true` on BOTH docs + no
`isSearchable`; minor retry → still writes `isMinor:true` to both, no
`isSearchable`. The `makeFakeDb` `setWrites[{path,data,merge}]` capture already
records per-path, so asserting the `settings/preferences` write separately is a
`find(w => w.path === users/${uid}/settings/preferences)`. Every remaining
`isSearchable` reference in the test is now a **negative** assertion
(`setWrites.every(w => !("isSearchable" in w.data))`). Suite 10/10, tsc clean.

### 2026-07-02 — BUT-684 handwritten-recipe OCR prompt variant [Pattern discovered]

Added a second OCR system prompt for handwritten recipe cards, selected at
call time. Files: `gemini-client.ts` (new `IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT`
const + `PROMPT_VERSION` 2.1.0→2.2.0), `PROMPT_CHANGELOG.md` (v2.2.0 entry),
`prompts-config.ts` (new `imageOcrHandwrittenSystemPrompt` field mirrored
end-to-end), `ocr-recipe-image.ts` (new `isHandwritten?: boolean` request flag +
selection), new test `ocr-handwritten-prompt.test.ts` + `test:ocr-handwritten`
script. Client toggle is a separate follow-on.

**Param shape for the client**: `ocrRecipeImage` request gains
`isHandwritten?: boolean` (default false). `true` → handwritten prompt; absent/
false → printed prompt, byte-for-byte unchanged.

**Patterns worth remembering**:

- **Adding a NEW `*_SYSTEM_PROMPT` const trips the prompt-changelog CI guard.**
  `prompt-changelog-guard.ts` keys on the `_SYSTEM_PROMPT` substring on any
  +/- diff line, so a new prompt constant REQUIRES a `PROMPT_CHANGELOG.md`
  entry in the same change or the gate fails. Bump `PROMPT_VERSION` too (the
  bundle changed) — MINOR for an additive new prompt. The guard's unit tests
  use synthetic diffs, so they stay green regardless.

- **Mirroring a Firestore-backed prompt field = 5 edit sites in
  `prompts-config.ts`**: the doc-shape docstring, the `PromptsConfig`
  interface, `buildFallback()`, the `requiredStringKeys` array, and the
  `validateRemoteDoc()` return literal. Miss any one and either the field is
  silently absent (missing from return) or never validated.

- **Adding a REQUIRED key is a breaking change to any live `system/prompts`
  override doc.** Because validation is all-or-nothing (BUT-621), an existing
  override doc that predates the new field now fails validation and the WHOLE
  bundle reverts to compiled-in fallback until an operator adds the field.
  The *prompt string sent* for the printed path is unchanged (fallback ==
  current compiled-in const), but the reported `source`/`promptVersion` flips
  to fallback. Operator action item: add `imageOcrHandwrittenSystemPrompt` to
  the prod doc. This also breaks any existing prompts-config test fixture
  (`validRemoteDoc()`) — it must gain the new field or the firestore-source
  cases fail. Audit test fixtures whenever you add a required key.

- **A/B bucket vs prompt selection are orthogonal in the OCR handler.**
  `resolvePromptBucket()` only tags analytics (`experimentBucket`/
  `promptVariant` on the timing log); it does NOT swap the prompt string. So
  the handwritten selection (`isHandwritten ? handwritten : printed`) sits
  independently and both keep working — bucket is still computed + logged for
  both paths.

- **Unit-testing `runOcrRecipeImage` without an initialized admin app**: the
  handler has no seam for `getPromptsConfig` or `captureLlmSample`. Both call
  `admin.firestore()`. `getPromptsConfig` catches the `app/no-app` throw and
  falls back to compiled-in prompts (deterministic — the selected prompt then
  equals the imported const). `captureLlmSample` throws its default-arg
  `admin.firestore()` eagerly AFTER `performOcr` runs, surfacing as an internal
  HttpsError. To test prompt SELECTION, capture `args.systemPrompt` inside the
  `performOcr` seam (runs first) and wrap the call in try/catch — the assertion
  is on the captured value, not the return. Same limitation already affects the
  `ocr-validation.test.ts` accepted-URL integration case.

### 2026-07-02 — BUT-684 handwritten-OCR prompt: adding a required prompts-config key breaks OTHER test fixtures [Bug fixed]

BUT-684 added `imageOcrHandwrittenSystemPrompt` as a **required** key in
`validateRemoteDoc()`'s `requiredKeys` list (all-or-nothing validation, same
rationale as BUT-621). The author correctly updated the fixture in
`prompts-config.test.ts` (`validRemoteDoc()`) — but a second module,
`prompt-ab-bucket.test.ts`, builds its OWN inline `system/prompts` doc fixtures
in THREE places (the "promptVariants populated / absent / malformed" cases) and
none were updated. Effect after the change:

- The **"populated"** case asserts `source === "firestore"` → now **FAILS**
  (`expected source=firestore, got fallback`) because its doc lacks the new
  required key, so the whole bundle reverts to compiled-in fallback.
- The **"absent"** and **"malformed variants"** cases only assert
  `promptVariants === undefined` → they still pass, but **for the wrong reason**:
  the fallback bundle happens to have no `promptVariants`, so they no longer
  exercise the firestore validation path they were written to test (silently
  vacuous).

Fix: add `imageOcrHandwrittenSystemPrompt: "handwritten ocr prompt"` to all
three doc literals in `prompt-ab-bucket.test.ts` (the fixtures at the
`imageOcrSystemPrompt: "ocr prompt"` lines), mirroring the staged
`prompts-config.test.ts` update.

**Pattern worth remembering — grep ALL fixtures when adding a required key.**
The `requiredKeys` list in `prompts-config.ts` is validated against every inline
`system/prompts` doc any test constructs. Adding a key there silently invalidates
every hand-rolled fixture that omits it. Before committing a new required prompt
field, run `grep -rn "imageOcrSystemPrompt:" src/__tests__/*.ts` (any always-present
sibling key works as the anchor) and add the new field to each hit. Watch for the
insidious variant: a fixture-turned-fallback whose assertion still passes because
it only checks something the fallback bundle also satisfies — green but no longer
testing the intended path.

**BUT-684 review verdict (rest clean):** printed path is byte-for-byte unchanged
when `isHandwritten` is falsy (ternary defaults to `prompts.imageOcrSystemPrompt`;
only added a `handwritten=false` log field). Handwritten prompt keeps the same
`${INJECTION_DEFENSE}` prefix + `${SWEDISH_MEASUREMENTS}` suffix and the same
"valid JSON som matchar schemat" contract (schema is enforced downstream by
`structureRecipe` regardless). A/B `resolvePromptBucket` is still computed and
logged for both paths — the variant is metadata only and never overrode the
system-prompt string, so bucketing/kill-switch/App-Check/rate-limit/PII-scrub are
untouched. No region change, no new trigger, no idempotency surface. PROMPT_VERSION
2.1.0→2.2.0 with changelog "(current)" marker moved — `prompt-changelog-guard`
passes.

**Deploy dependency (documented, not a defect):** because the new key is required,
a live `system/prompts` override doc that predates this field will fail validation
on deploy and revert the WHOLE bundle to compiled-in fallback until an operator
adds `imageOcrHandwrittenSystemPrompt`. The PRINTED fallback (`buildFallback()`
uses the unchanged compiled-in `IMAGE_OCR_SYSTEM_PROMPT`) is identical to what
shipped, so there is NO behaviour change **unless** an operator had hot-fixed a
prompt in Firestore that diverges from compiled-in — in which case all five
prompts silently revert. Coordinate: add the field to the live override doc as
part of the deploy, not after. Reporting-only change otherwise (`source` flips to
`fallback`, `promptVersion` reports 2.2.0).

### 2026-07-02 — BUT-684 follow-up: handwritten prompt made OPTIONAL, not required [User correction]

A /code-review flagged the required-key design from the entry above as a deploy
footgun and it was corrected. **Superseding guidance:** a NEW Firestore-backed
prompt field must be OPTIONAL with per-field fallback, NOT added to
`requiredStringKeys`.

Why required was wrong: the config validation is all-or-nothing (BUT-621). Any
EXISTING production `system/prompts` override doc — valid under the prior 6
keys — would fail validation the moment the 7th key became required, silently
reverting EVERY prompt (extraction, enhancement, printed OCR, spoken,
ingredient) to compiled-in defaults and losing all operator tuning until
someone hand-edits the prod doc. That's a data-loss-of-tuning event triggered
purely by deploying code, gated on a manual prod-doc edit.

The fix in `validateRemoteDoc()`:
- Keep `requiredStringKeys` at the original 6 (do NOT add the new key).
- In the return, default the new field per-field:
  `typeof raw.x === "string" && raw.x.trim() ? raw.x : COMPILED_IN_CONST`.
- A doc lacking the field still validates as `source: "firestore"`, keeps all
  its other overrides, and the new field gracefully falls back. Removes the
  deploy dependency entirely.

**General rule for this codebase:** all-or-nothing bundle validation means
"required key" == "breaking change to every existing override doc". Reserve
required status for keys present since the doc's inception. Every ADDED key
should be optional + per-field fallback. This contradicts the instinct (from
the original 5 prompts) that "all prompts are required for version integrity" —
that instinct only holds for the original shape, never for additions.

Test to pin it: a fixture doc WITHOUT the new key must assert
`source === "firestore"` AND that a sibling override (e.g. `imageOcrSystemPrompt`)
survives AND the new field equals the compiled-in const. See
`ocr-handwritten-prompt.test.ts` case [6]. (The field-present fixtures in
`prompts-config.test.ts` / `prompt-ab-bucket` are now harmless either way.)

### 2026-07-02 — sync-ingredients.ts review: warnings invisible by default [Pattern discovered]

Reviewed the generic-'seafood' validation warning added to
`functions/src/admin/sync-ingredients.ts` (`validateIngredient`). Two
findings worth remembering about this admin/ script:

1. **`validateAllIngredients` only counts warnings under `--verbose`.**
   `warningCount += result.warnings.length` sits INSIDE
   `if (result.warnings.length > 0 && verbose)`, so a default (non-verbose)
   run reports 0 warnings and the "N warnings (use --verbose to see)" hint
   never prints (guarded by `warningCount > 0`). Any warning added to
   `validateIngredient` is therefore INVISIBLE on the standard
   `npm run sync-ingredients:dry-run` invocation. When adding warnings,
   also move the counting outside the verbose guard (gate only the
   per-row printing) or the warning is dead code in practice.

2. **The script is a non-testable monolith by design**: module scope runs
   `admin.initializeApp()` + `main()` executes on import, so
   `validateIngredient` can't be imported into the hand-rolled test harness
   without refactoring (extract validators to a side-effect-free module).
   Consistent with the admin/ family's "test: n/a" row — pinning validation
   warnings is optional here; if warnings ever gate real decisions, extract
   first.

Client-side contract behind the seafood warning (verified in
`lib/services/tagging/`): skaldjur allergen trigger is
`crustacean OR mollusc OR seafood` via plain `hasAnyProperty` OR-logic
(`tag_phase1_allergen.dart` → `getCombinedPropertyStatus`). So ANY row
carrying 'seafood' yields skaldjur CONTAINS — adding a detail property
(fish/crustacean/mollusc) does NOT clear it (deliberate false-CONTAINS
safety net, allergen_config.dart comment 2026-07-01); the detail property's
real value is making the SPECIFIC allergen (fisk/kräftdjur/blötdjur)
detectable. Sync-time warning messages should say that, not imply the
skaldjur verdict flips.

### 2026-07-03 — pooled-ratings v1 server key twin (canonical-pool-key.ts) [Pattern discovered]

New family `ratings/` (pure helper for now). `computePoolKey(title, ingredients)`
is the SERVER AUTHORITY for the pooled-ratings recipe-identity key and must be a
byte-identical twin of the Dart `lib/services/rating/canonical_pool_key.dart`.
Parity is gated by the shared fixture `test/fixtures/pool_key_parity.json` (read by
both `functions/src/__tests__/pool-key-parity.test.ts` and the Dart test). Reviewed
2026-07-03: 11/11 parity, faithful twin, no correctness-breaking divergence found.

**Cross-language parity checklist (reusable for any TS↔Dart twin):**
- **Dart RegExp follows ECMAScript non-Unicode semantics.** With no `unicode:true`
  (Dart) / no `u` flag (JS), `\w`/`\b` are ASCII-only in BOTH, and `\s` matches the
  same set. This is why "fold å/ä/ö→a/o FIRST, then strip single-letter units with
  `\b(l|g|...)\b`" works identically in both — the string is ASCII by the time the
  boundary regex runs. Add `unicode`/`u` to only one side and this breaks.
- **Default string sort is UTF-16 code-unit ordinal in BOTH.** Dart `List<String>
  ..sort()` (→ `String.compareTo`) and JS `Array.sort()` with no comparator both
  compare by UTF-16 code units (shorter-prefix-first). They agree even for non-ASCII
  BMP + surrogate pairs. Safe to rely on — but only because neither passes a
  locale-aware comparator.
- **Dedup order is irrelevant when you sort after.** `set().toList()..sort()` (Dart
  LinkedHashSet insertion order) vs `Array.from(new Set()).sort()` (JS insertion
  order) — the trailing sort makes insertion order moot. Good pattern; don't remove
  the sort thinking Set order is stable across languages.
- **`String.split(' ')` is literal in both** (only JS `split('')`/regex-split and
  Python `split()`-no-arg are special). Consecutive spaces → empty tokens in both;
  `''.split(' ')` → `['']` in both.
- **Anchored `^` regex: Dart `replaceAll` == JS non-global `.replace`.** `^`
  (non-multiline) matches only index 0, so replaceAll does exactly one replacement,
  same as a non-global `.replace`. No `g` flag needed on TS `leadingNumbersRe`/
  `leadingDigitsRe`.
- **sha256 hex is lowercase in both** (`Digest.toString()` / `.digest('hex')`);
  `utf8.encode` == `.update(raw,'utf8')`. `.substring(0,16)` identical.

**Footguns flagged (not bugs today):**
- **Module-level `/g` regexes are safe with `.replace` but NOT with `.test()`/
  `.exec()`.** canonical-pool-key.ts only uses `.replace` on its global regexes, so
  no `lastIndex` statefulness bug. If a future edit calls `.test()`/`.exec()` on any
  module-scope `/g` regex, `lastIndex` persists across invocations (CF isolates are
  long-lived) → intermittent wrong results. Keep global regexes to `.replace`, or
  make them local.
- **Input validation belongs in the calling CF, not the helper.** `computePoolKey`
  guards `!ingredients`/empty but does `title.toLowerCase()` and `raw.toLowerCase()`
  on array elements unconditionally. A Firestore doc with a non-string title or a
  non-string element in the ingredients array throws a `TypeError`; inside a Firestore
  trigger that's an uncaught exception → retry storm. The aggregation CF MUST coerce/
  validate (`typeof === 'string'`) and fail-closed (skip / null) before calling.
- **C5 word-list drift.** INGREDIENT_UNITS / TITLE_STOP_WORDS / APPROXIMATE_WORDS /
  DISH_QUALIFIERS / GENERIC_ANCHORS are hand-duplicated from the Dart twin. Verified
  in sync 2026-07-03, but nothing mechanically prevents a one-sided edit. Both files
  already flag the C5 follow-up (share via one JSON asset or CI byte-diff). Highest-
  value guard: the parity fixture only exercises lists indirectly — a shared asset or
  byte-diff CI is the real fix.

**Fixture gaps worth closing (proposed, not divergences):** all-caps input (locks
`toLowerCase()` parity + `gi` unit regex), >12 unique ingredients (locks sort-then-
`take(12)` boundary — the single most divergence-prone construct), and ingredients
that fold to the same name across mixed case (locks Set dedup after folding).

### 2026-07-03 — C5 word-list drift guard CLOSED [Pattern discovered]

The predicted C5 fix (above) shipped. Reviewed the TS side clean.

- `canonical-pool-key.ts` now `export`s the five word-list consts
  (`INGREDIENT_UNITS`, `TITLE_STOP_WORDS`, `APPROXIMATE_WORDS`,
  `DISH_QUALIFIERS`, `GENERIC_ANCHORS`). No algorithm change; regex build +
  `Set.has` usage unchanged. `noUnusedLocals` still satisfied (all consumed
  in-module).
- New `__tests__/pool-key-wordlist-parity.test.ts` — same hand-rolled,
  `process.exit(1)`-on-fail, `run()`-at-top-level style as the C4
  `pool-key-parity.test.ts`. Reads repo-root `test/fixtures/pool_key_wordlists.json`
  (`__dirname/../../../test/fixtures/...`), compares each list IN ORDER. The Dart
  twin pins the same JSON, so a one-sided edit reddens one of the two suites.
- `package.json` adds `test:parity:poolkey-wordlists`; auto-discovered by
  `scripts/run-all-tests.js` (`test:*` minus `test:rules*`/`test:integration:*`).
  Confirmed the prefix filter admits it.

**Patterns worth remembering:**

- **Native consts + CI parity test, NOT runtime JSON load — deliberate and
  correct.** `tsc` does not copy `.json` under `src/` into `functions/lib` on
  build, so a runtime `import`/`readFileSync` of the fixture would crash the
  deployed function. Keeping the lists as compiled-in consts keeps the pool key
  synchronous and dependency-free; drift is caught at CI time by the two parity
  suites instead of at runtime. Do NOT "improve" this into a runtime shared-asset
  load — that reintroduces a deploy-bundle-missing-file crash. (Decision 2: this
  TS module is the pool-key SERVER AUTHORITY.)

- **Set→Array insertion order is a sound parity basis.** ECMAScript guarantees
  Set iteration in insertion order, so `Array.from(set)`/`[...set]` reproduce the
  literal declaration order; Dart's default `Set` (`LinkedHashSet`) is likewise
  insertion-ordered. Ordered comparison is meaningful for BOTH: the array lists
  (`INGREDIENT_UNITS`, `APPROXIMATE_WORDS`) are joined into a regex alternation
  where order is load-bearing; the Set lists compare by order too, harmlessly
  (membership is what the algorithm uses, but ordered compare is stricter and free).

- **Exporting pure-data consts has zero cold-start / isolate cost.** The consts
  were already instantiated at module load; adding `export` changes nothing the
  deployed entry loads (the test file is never `require`d from `index.ts`). No
  admin-init import-poison either — the module builds only regexes + `createHash`
  at load, no `admin.firestore()`. One theoretical Low: exported arrays/Sets are
  mutable references (not `Object.freeze`d), but the only importer is a read-only
  test, and internal consumers could already mutate pre-export — so no new risk.

- **`src/__tests__/*` compiles into `functions/lib` (tsconfig `include: ["src"]`).**
  Pre-existing convention for every parity/rules suite; slightly bloats the deploy
  artifact but costs nothing at cold start (unreferenced modules aren't loaded).
  Not introduced by this change — do not flag.

### 2026-07-03 — pooled-ratings Increment 1: debounce-queue generalization [Pattern discovered]

`functions/src/shared/debounce-queue.ts` (NEW, generic core) +
`functions/src/ratings/rating-aggregation.ts` (now a thin adapter). Decision 5
of `tasks/pooled-ratings-plan.md`: the pool aggregator REUSES this generic
coalesce+claim-by-delete module instead of forking a second copy. Reviewed
CLEAN — 5/5 BUT-482 tests pass unmodified, tsc clean, index.ts untouched.

**Field-rename across a Cloud Functions deploy is transition-safe ONLY when the
value equals the doc ID.** The marker's internal field was renamed
`recipeId`→`key`, and the drain reads `data?.key ?? doc.id`. This is safe in
BOTH deploy-window directions because `debounceMarkerRef` writes markers at
`{markerCollection}/{key}` — the doc ID IS the key, always:
- OLD writer (`recipeId` field) → NEW drain: `data?.key` undefined → `doc.id`. ✓
- NEW writer (`key` field) → OLD drain still deployed: `data?.recipeId`
  undefined → `doc.id`. ✓
No stranded/duplicated/lost markers. `pendingUntil`/`scheduledAt` field names
are unchanged, so coalescing works regardless of which version wrote a marker
in flight at deploy time. **General rule: a doc-field rename in a marker/queue
collection is a free deploy ONLY if every reader falls back to `doc.id` and the
doc ID equals the renamed value. Otherwise you need a two-phase deploy
(read-both, then write-new).**

**Coincidental test proof of the transition:** the two drain seed-tests
(`drainerProcessesReadyMarkers`, `drainerSurvivesAggregatorFailure`) still seed
markers with the OLD field name `recipeId:` and drain correctly via the doc.id
fallback — so the existing suite already exercises the deploy-transition path
without modification. Worth preserving when the pool aggregator's own tests land.

**Log-field rename (`recipeId`→`key`) verified low-risk:** the structured-log
FIELD changed but the event NAMES are preserved (`rating_aggregation.scheduled`
/`.skipped`/`.failed`, plus `.drain_complete` in index.ts which never carried a
recipeId). Grep found NO in-repo dashboards/alerts/log-based-metric configs
(no `monitoring/`, `*.tf`, alert yaml) filtering on `jsonPayload.recipeId`.
Caveat I CANNOT verify from code: alert policies / log-based metrics created
directly in the GCP Cloud Console. Any alert keyed on the event NAME (normal
pattern) is unaffected; only one filtering on the `recipeId` value would need a
one-line edit. Not a blocker — flagged to user as the single unverifiable point.

**Adapter mapping is correct:** `drainRatingAggregationQueue({aggregate})` maps
`drain: deps.aggregate`; both are `(string) => Promise<void>`. index.ts calls
`drainRatingAggregationQueue({ aggregate: updateRecipeRatingStats })` unchanged.
The adapter re-exports `ScheduleDeps` from the shared module and defines its own
`DrainDeps` (keeps the `aggregate` name for API stability). Public API
(`scheduleRatingAggregation`/`drainRatingAggregationQueue`/`__test__`) identical.

**When the pool aggregator (`canonical-rating-aggregation.ts`) lands**, its
`DebounceConfig` should use `markerCollection: "_internal/pool_debounce/markers"`
(already named in the shared module's docstring) and a distinct `logPrefix`
(`pool_aggregation`) so the two queues never share markers and their logs stay
separable. The generic drain default THROWS if no `drain` is wired — the pool
drainer's `onSchedule` must pass its aggregator, same as
`drainRatingAggregations` in index.ts.

### 2026-07-03 — Finding D: cross-prompt-family instruction gap (schema-shared prompts) [Pattern discovered]

Review of a prompt-only change in `gemini-client.ts`. The ingredient-group rule
("Deg:"/"Fyllning:" → `section=` per ingredient, NEVER emit the heading as its
own ingredient) lived ONLY in `RECIPE_EXTRACTION_SYSTEM_PROMPT` (text path).
The OCR, handwritten, and spoken prompts all share `RECIPE_SCHEMA`, where a bare
`name:"Deg"` is structurally valid — so a grouped recipe photographed/transcribed
could emit a phantom heading row that the text path would not. Fix extracted a
shared `INGREDIENT_GROUP_RULE` const and interpolated it into all four prompts.

**The reusable lesson: when N prompts share ONE responseSchema, a behavioural
instruction added to only one of them is a latent gap for the other N−1.** The
schema constrains structure, not semantics — anything the schema permits but you
don't want must be forbidden in *every* prompt that uses that schema, not just
the one you happened to edit. Grep the schema constant's usages before assuming a
per-prompt instruction is sufficient. Prefer a shared const over copy-paste so
the four prompts can't drift.

**Verification I ran (all clean):**
- **Byte-identical text prompt:** the `INGREDIENT_GROUP_RULE` value equals the
  old literal line verbatim (leading `- ` included); the template now interpolates
  `${INGREDIENT_GROUP_RULE}` on its own line → rendered text unchanged. Confirm
  this char-for-char, not by eyeballing — a dropped leading `- ` would silently
  reword the text prompt.
- **MINOR bump correct:** `INGREDIENT_SCHEMA`/`RECIPE_SCHEMA` untouched (the
  `section` field shipped in v3.0.0); this change is additive instruction only,
  same schema, same client parser → 3.0.0→3.1.0 MINOR is right. (v3.0.0 was MAJOR
  because it changed the schema + parser.)
- **INJECTION_DEFENSE still leads all four prompts** (`${INJECTION_DEFENSE}` is
  the first token of each template literal) — the rule was inserted mid-body,
  not before the security prefix.
- **Deploy-note keys are real override keys:** `prompts-config.ts` reads
  `imageOcrSystemPrompt`, `imageOcrHandwrittenSystemPrompt`, and
  `spokenContentSystemPrompt`. Nuance worth remembering: the three text/OCR/spoken
  keys are in the all-or-nothing `REQUIRED_FIELDS` set, but
  `imageOcrHandwrittenSystemPrompt` is OPTIONAL with a **per-field** fallback
  (BUT-684). So if prod `system/prompts` overrides a required key with a stale
  value (missing the rule), that stale value serves until the doc is updated in
  the same deploy; if prod simply lacks the handwritten key, the compiled fallback
  (which now carries the rule) serves. The changelog deploy note captures this.
- **No allergen risk:** `section` text stays on each ingredient object, never in
  the flat allergen-tagged ingredient list, so this can't ground a false
  "fritt från X" verdict. A phantom "Deg" row is junk, not a safety issue → LOW.

### 2026-07-03 — pooled-ratings Increment 2: Stage A mirror CF review [Pattern discovered]

Reviewed the NEW `ratings/canonical-rating-aggregation.ts` (core
`mirrorRatingToPool`), `ratings/pooled-ratings-flag.ts` (fail-CLOSED RC kill
switch), the `onRecipeRatingWrittenForPool` `onDocumentWritten` trigger in
index.ts, and the 11-case test suite. No Critical. Fail-closed flag + fail-closed
maturity gate + server-recomputed key are all correct. Followed the C4 knowledge
note exactly (coerces `core.title`/`core.ingredients` to string / string[] before
`computeKey`, so a malformed recipe doc can't throw a TypeError inside the
trigger). Two Medium + one Low below; all three are enhancement-shaped, not
blockers.

**Verified — recipe read location is correct (not a silent no-op).** The mirror
reads TOP-LEVEL `db.collection("recipes").doc(recipeId)`. The repo also has a
user-scoped personal library at `users/{uid}/recipes/{recipeId}` (that's what the
firestore-rules tests, `cleanup-recipe-storage.ts`, and `backfill-recipe-comments`
target), which made the correct location genuinely ambiguous. Confirmed top-level
is right because the LIVE Dart rating aggregate
(`lib/services/unified/operations/modules/rating_statistics.dart:180`) also writes
denormalized stats to `firestore.collection('recipes').doc(recipeId)` and
`batch.update(recipeRef)` — an update that would THROW if the top-level doc were
absent — so a top-level `recipes/{recipeId}` with `core.title`+`core.ingredients`
(also confirmed by `admin/bulk-retag.ts`) provably exists for every rated recipe.
`recipe_ratings.recipeId` therefore resolves against the top-level doc. **General
rule for this repo: `recipes/{id}` (top-level) is the rated/denormalized recipe;
`users/{uid}/recipes/{id}` is the personal library. Don't assume one from the
other — the rating pipeline keys off the top-level one.**

**MEDIUM (cost + consistency + latent semantic drift) — the mirror has NO
rating-change gate, unlike its sibling.** The existing `onRatingUpdated`
(index.ts:226) skips when `before.rating === after.rating`; the new
`onDocumentWritten` mirror reprocesses EVERY write. Two consequences:
1. Cost: any no-rating-change write to a `recipe_ratings` doc (review-text edit,
   `updatedAt` touch, client re-save) pays 1 billed recipe read + 1 event write
   that the social-stats path deliberately skips.
2. Latent correctness: the mirror always recomputes the key from CURRENT recipe
   content, so if the recipe was edited between the original rating and a later
   no-rating-change write, it files a NEW event at the new poolKey while the old
   event persists — a pool vote the user never actively cast. This is NOT the
   accepted "re-rate an edited dish → new vote" case (there the user re-rates);
   here an incidental write fabricates it. Remedy: in the trigger (or core), when
   `before && after && before.rating === after.rating && before.recipeId ===
   after.recipeId`, return a `skipped_unchanged` no-op — mirrors the sibling and
   kills both issues.

**MEDIUM (cost ordering) — maturity gate runs AFTER the billed recipe read.** The
order is validate → `recipes/{id}.get()` (billed) → `computeKey` → `isAccountMatured`
(`auth.getUser`, not billed per-call). The maturity gate exists to reject
throwaway-account spam, but a spam flood still pays one recipe read each before
rejection. Reorder to validate → maturity check → recipe read → key → write:
`getUser` is free, the recipe read is billed, so the free adversarial check should
gate the billed read. Pure win — normal ratings do the same total work reordered.

**LOW (Stage-B forward-looking) — `createdAt: serverTimestamp()` is rewritten on
every upsert.** A CF retry, or any re-processing of the same vote, shifts
`createdAt` to the reprocess time despite the "frozen" framing in the docstring.
Harmless today (Stage B doesn't exist), but if Increment 3 uses `createdAt` for
recency weighting or first-vote tie-breaking it will drift. Decide deliberately in
Increment 3: keep last-write semantics (rename to `updatedAt`) or preserve
first-create (transaction/`create`-then-`update`, or merge-if-absent).

**Boundary note (hand-off, not a finding):** the mirror trusts
`recipe_ratings.recipeId` and reads whatever recipe it names. The guarantee that a
user may only create a `recipe_ratings` doc for a recipe they're allowed to rate
lives in `firestore.rules` — that's `firestore-rules-tester`'s surface, not this
CF's. The CF's own poisoning defense (never trust a client-written key; recompute
from content) is intact and tested (AC2).

**Idempotency confirmed solid:** upsert = `set()` at doc-ID=poolKey (retry-safe);
delete = query-by-`recipeId` + delete (retry → `delete_noop`); the recipeId-keyed
delete correctly cleans up the multi-event case from the edit-then-rerate path.
`onDocumentWritten` create/update/delete branches all handled; both-absent guarded
in index.ts. Throw-on-error → CF retry is safe because the only mutation is the
final idempotent write.

### 2026-07-03 — [User correction] The 2026-07-03 pooled-ratings review above was WRONG on 3 counts — an xhigh multi-agent review caught a showstopper I cleared
I reviewed the Increment-2 pooled-ratings mirror CF and reported it "clean of
Critical/High." A subsequent `/code-review xhigh` (6 finders + 13 verifiers) found
**12 verified issues**, including a **showstopper I explicitly endorsed as correct**.
Corrections to the entry directly above — supersede it with these:
1. **Recipe content is USER-SCOPED, not top-level.** I asserted `recipes/{recipeId}`
   (top-level) was correct, citing a Dart write at `rating_statistics.dart:180`. WRONG.
   Recipes live at `users/{ownerUid}/recipes/{recipeId}` — `firestore.rules` has ONLY
   the nested `match /users/{userId}/recipes/{recipeId}` (line ~337, no top-level
   `match /recipes`), `FirebaseRecipeRepository` mixes in `UserScopedFirebaseRepository`
   (see `lib/repositories/CLAUDE.md`), and `recipe_ratings` docs carry **no owner uid**
   (only `recipeId, userId, rating, review, createdAt, updatedAt`). A CF reading
   `db.collection("recipes").doc(id)` always misses → feature dead on arrival. The
   `bulk-retag.ts` / `getRetagStatus` admin functions ALSO use top-level
   `collection("recipes")` and are the trap that misled me — do not treat them as proof
   a top-level collection exists; they are unverified/legacy. **Lesson: to confirm a
   server-side collection path, read `firestore.rules` (the authoritative layout) + the
   repository's mixin, NOT an incidental `collection(name)` call elsewhere.**
2. **`throw` does NOT retry by default.** firebase-functions v2 event triggers
   (`onDocumentWritten` et al.) have `retry=false` by default — a thrown error is logged
   and DROPPED, not redelivered. Must pass `{ retry: true }` in the trigger options for
   "throw → retry" to hold. I called the throw-to-retry design "safe" without checking.
3. **A test that seeds the same wrong path as the code cannot catch a path bug.** The 12
   unit tests passed only because the FakeFirestore seeded recipes at the same fake
   `recipes/{id}` path the code read. **Lesson: the fake must mirror the REAL collection
   layout (user-scoped subcollection), or a path bug is structurally invisible.**
Also confirmed-wrong from the entry above: the `recipeId`-keyed retraction does NOT
"correctly clean up" — when two copies of one dish collapse onto one poolKey doc it
deletes a still-live vote (or no-ops the wrong one). **Meta-lesson: on data-writing CFs,
the single-specialist gate is necessary but NOT sufficient — an adversarial multi-finder
review is warranted before commit.**

### 2026-07-03 — pooled-ratings Stage B pool aggregator (Increment 3) [Pattern discovered]

Reviewed clean (no findings) the Stage B aggregator that maintains the PUBLIC pooled
number `canonical_recipe_stats/{poolKey} = {count, average, updatedAt}`. Files:
`ratings/update-pooled-rating-stats.ts` (aggregator), `ratings/pool-aggregation.ts`
(debounce adapter), the `onPooledRatingEventWritten` trigger + `drainPooledRatingAggregations`
scheduler in `index.ts`, and a collection-group index in `firestore.indexes.json`.

**Patterns worth remembering:**

- **Unbounded collection-group fold → use `.aggregate({count, average})`, never `.get()`.**
  When a pool's rater count is unbounded by design, read-all-then-recompute is forbidden
  (memory + billed reads scale with pool size). The right shape is
  `db.collectionGroup(sub).where("poolKey","==",key).aggregate({ count:
  AggregateField.count(), average: AggregateField.average("ratingValue") }).get()` — both
  scalars computed in the index layer, O(1) memory, one billed read per ≤1000 matched
  entries. Confirmed `AggregateField.count/average/sum` all present in **firebase-admin
  13.8.0**. The test enforces the invariant by tripping a counter if anyone `.get()`s the
  raw collection-group query (fold tripwire) and asserting `foldGetCalls === 0`.

- **Collection-group equality query needs a fieldOverride COLLECTION_GROUP single-field
  index — NOT a composite, and NOT covered by the auto single-field index.** Firestore
  auto-creates single-field indexes at COLLECTION scope only; a `collectionGroup(...)`
  query with even a single equality filter needs an explicit `fieldOverrides` entry
  `{collectionGroup, fieldPath, indexes:[{order:"ASCENDING", queryScope:"COLLECTION_GROUP"}]}`.
  Without it the query (and its aggregate) throws `FAILED_PRECONDITION` in prod (emulator
  hides this). An aggregate query uses the SAME index as its underlying `where`; the
  averaged field (`ratingValue`) does not need indexing. This is distinct from the
  accepted-deviation "equality queries need no composite" — that rule is about COLLECTION
  scope; collection-GROUP scope still needs the explicit override.

- **count()/average() denominator parity depends on the producer validating the field.**
  `count()` counts every matched doc; `average(f)` only averages docs where `f` is numeric.
  If the producer could write an event missing/`null` `ratingValue`, the public average
  would be over a smaller denominator than count. Safe here because Stage A gates
  `typeof rating !== "number" || !Number.isFinite || <1 || >5` → `skipped_invalid`, so every
  event carries a finite [1,5] `ratingValue`. When reviewing any aggregate-average CF,
  verify the producer guarantees the averaged field or the two numbers silently diverge.

- **Debounce reuse via `DebounceConfig`, distinct marker namespace.** Stage B does NOT fork
  the claim-by-delete queue — it passes a `DebounceConfig` to the shared
  `shared/debounce-queue.ts` with `markerCollection: "_internal/pool_debounce/markers"`
  (rating aggregation uses `_internal/rating_debounce/markers` — no collision) and
  `logKeyField: "poolKey"`. This is the canonical way to add a second debounced aggregator:
  a thin adapter pinning namespace/config, never a second copy of the transaction logic.

- **retry:true on the event trigger only retries the cheap scheduling, not the recompute.**
  `onPooledRatingEventWritten` recovers `poolKey` from `event.params.poolKey` (works on
  delete — the wildcard doc-ID survives when the after-snapshot is gone) and does nothing
  but `schedulePoolAggregation` (an idempotent coalescing transaction). The actual
  recompute+upsert runs in the separate every-1-min drainer. So `retry:true` is safe (it
  re-runs an idempotent marker write); a drain failure self-heals on the next signal (the
  pre-existing, accepted debounce tradeoff). No trigger-loop risk: stats writes go to
  `canonical_recipe_stats` and markers to `_internal/...`, neither matching the trigger path.

- **Empty pool is zeroed (count 0 / average null), not deleted.** On last-event retraction /
  GDPR erasure the aggregate returns 0/null and that is written — the reader gates on n≥5 so
  a zeroed doc shows no pill (never a stale number). Leaves a negligible orphan zero-doc;
  accepted over an extra delete round-trip.

- **Per-minute drainer cadence is by parity with the sibling rating drainer, not a new
  cost.** `drainPooledRatingAggregations` runs `every 1 minutes` exactly like
  `drainRatingAggregations`. This nominally contradicts the "schedule hourly not per-minute"
  guidance, but it's the decided latency trade (0..60s pool freshness), the empty-scan cost
  is ~1 min-billed read per run (≈$0.016/mo), and the feature flag is OFF in prod so it
  rarely does real work pre-launch. Accepted.

### 2026-07-03 — pooled-ratings Incr 5: GDPR cascade of canonical_rating_events [Pattern discovered]

Reviewed the account-deletion wiring for the frozen pool events
(`functions/src/account/account-deletion-cascade.ts`). Clean — no findings. The pattern
worth remembering is the **two-shaped cleanup for one subcollection**:

- **Erase**: `canonical_rating_events` added to the `subs` array in
  `deleteUserSubcollections`. That loop is `userDoc.collection(name).get()` +
  `batchDeleteAll`, and `userDoc = db.collection("users").doc(uid)` — so it is inherently
  uid-scoped (no cross-user reach) and a cascade retry finds an empty snapshot (no-op). No
  separate function needed because it is a pure `users/{uid}/*` subcollection, unlike the
  top-level userId-scoped collections that get their own deleters.
- **Probe**: the residual check must be **subcollection-shaped**
  (`.doc(uid).collection("canonical_rating_events").count()`), NOT a top-level
  `where("userId","==",uid)` — the latter silently matches zero (the realtime_recipes
  wrong-field trap this codebase already hit). The added probe mirrors the existing probe
  structure (count query, `try/catch → residual += 1` on error, warn on count>0) and pushes
  `residual_data_detected` into `failedCollections`.

**Delete→recompute soundness (the load-bearing bit):** deleting each event fires
`onPooledRatingEventWritten` (an `onDocumentWritten`, so delete counts). The handler
recovers `poolKey` from `event.params` (after-snapshot is gone on delete) and schedules a
debounced recompute. The recompute (`updatePooledRatingStats`) is a collectionGroup
**aggregate** that writes `canonical_recipe_stats` — a *different* collection from
`canonical_rating_events` — so **no re-trigger / no infinite loop**. `set(merge)` from
source-of-truth makes it idempotent; `retry:true` is safe. Erasing a rater thus shrinks the
public averages they contributed to with no explicit recompute call — the established
Stage-A/Stage-B trigger separation carries GDPR erasure for free (bounded to the number of
distinct pools the user rated in; GDPR deletion is rare, so per-event trigger fan-out is an
accepted cost).

**Cost of the added probe:** one `count()` per account deletion (a rare op). count() bills
as reads in 1000-entry increments; a per-user subcollection is a handful → ~1 read.
Negligible, and consistent with every sibling probe.

**Test proof:** `request-account-deletion.integration.test.ts` seeds a TARGET event + an
OTHER control event. I-CRE1 asserts the target's event is gone (erasure), I-CRE2 asserts
OTHER's survives (uid-scope proof — the control lives under `users/OTHER/*` so it also can't
false-trip the TARGET-scoped residual probe), and I-CRE3 leans on I21
(`RESULT.failedCollections.length === 0`) so a surviving target event would have pushed
`residual_data_detected` and failed the run — residual-clean is doubly proven. 44/44 pass on
the emulator. This "own erased + other kept + envelope-clean" triple is the canonical shape
for any new GDPR-cascade subcollection test in this repo.

### 2026-07-04 — pooled-ratings backfill: no persisted cursor caps forward progress [Bug fixed / review finding]

Reviewed `migrations/backfill-canonical-ratings.ts` (decision 14, Increment F —
one-shot, HARD-GATED behind `enable_pooled_ratings`, never run in prod). It reuses
the live mirror's exported `isAccountMatured` + `recipeContentToKey` (the diff only
added `export` to those two — no body change, so the live mirror's behavior is
unchanged). Idempotency read + `batch.set` per event, 450 cap, ADR-0004 frozen
event shape. Clean on: server-recompute of poolKey (never trusts the rating doc's
client key — test 2 proves it), the maturity memo (monotonic ⇒ safe to memoize
`true`, immature never cached), the flag-refusal gate (real run only, dryRun
bypasses per AC10; `isPooledRatingsEnabled` throws on unreachable RC ⇒ fail-closed),
and no `WriteBatch` overflow (≤450 sets/commit).

**The real finding — inherited from `backfill-recipe-comments-denorm.ts`:** the
cursor `lastDocId` is a LOCAL variable, reset to null every invocation; nothing is
persisted across calls. `totalScanned` (vs `maxRatings`, default 10k) and
`batchesProcessed` (vs `MAX_BATCHES_PER_INVOCATION=23`, ≈10,350 docs) both count
**skipped-identical** docs. Consequence: a re-invoke always restarts from doc #1,
re-scans the already-mirrored head as `skippedIdentical` while the counters climb,
and short-circuits at the same ceiling — so **a corpus larger than ~10,350 ratings
can never fully backfill**; `hasMore` stays true forever and re-invoking is a no-op
loop over the head. The line-192 comment "the cursor lets a re-run resume" and the
runbook's "re-invoke while `hasMore` until false" are therefore inaccurate above
that ceiling. INERT at current beta scale (rating corpus << 10k), and at that scale
the transient-maturity-error → `HttpsError('unavailable')` re-run story IS safe
(re-scan from start + idempotent skip reliably reaches the previously-failing uid,
which sits within the first ceiling). Remediation for any future scale: persist
`lastDocId` to a cursor doc (e.g. `_migrations/backfill_canonical_ratings`) and
resume from it, OR don't count skipped-identical docs against the caps. Flagged
Medium (would be High if the corpus ever crosses ~10k before the file is deleted).

Two Lows recorded: (1) `createdAt` divergence — the backfill preserves the original
rating `Timestamp` (`data.createdAt ?? serverTimestamp()`) whereas the live mirror
always writes `serverTimestamp()`; the mirror explicitly DEFERRED the createdAt
semantics decision to Stage B (its own line 293-296 NOTE), so the two writers now
disagree — no reader today, but Stage B's eventual decision must account for both.
The `data.createdAt as Timestamp` cast is unchecked (harmless while recipe_ratings
writes a client serverTimestamp). (2) A corpus size exactly == `maxRatings` (or the
inner-break firing on the last real doc) reports `hasMore: true` perpetually —
cosmetic; the operator never sees the clean `hasMore: false`. Region/cold-start
conventions fine (europe-west1 pinned like the reference backfill; no new SDK).

### 2026-07-04 — pooled-ratings backfill: cursor + dedup rewrite VERIFIED CLEAN [Bug fixed]

Re-reviewed after the fix for the three findings above. All resolved; the four
boundary hazards I re-checked are sound. Keeping the reasoning so a future run
doesn't re-derive it.

- **Persisted cursor (the Medium).** `startAfter?` in/`nextCursor` out now thread
  the resume point through the caller (runbook: re-invoke with
  `{ startAfter: nextCursor }` until `hasMore` false). `maxRatings` is a
  PER-INVOCATION `totalScanned` ceiling (local, resets each call) — not a
  cumulative cap — so an arbitrarily large corpus completes across invocations.
  `hasMore` terminates: every invocation with `maxRatings ≥ 1` processes ≥1 doc
  (fresh `totalScanned` 0→1 ≤ ceiling on the first doc), so `lastProcessedId`
  strictly advances past `startAfter` each call; ends when `reachedEnd`
  (empty/short page). The `reachedEnd` flag correctly suppresses the spurious
  `hasMore` on an exact-`BATCH_SIZE`-multiple corpus (one extra empty query, then
  done) and on the exact `MAX_BATCHES`×`BATCH_SIZE` boundary (one extra
  invocation that returns empty).

- **Two-cursor split is the load-bearing correctness trick.** `lastDocId` = last
  FETCHED (drives the query `startAfter`); `lastProcessedId` = last actually
  PROCESSED (drives `nextCursor`). They diverge only on the `maxRatings` cutoff:
  the cutoff doc breaks BEFORE processing, so `lastProcessedId` stays at the prior
  doc and `nextCursor = lastProcessedId` re-fetches the cutoff doc + its
  unprocessed batch siblings next call → no skip. On the batch-ceiling exit they're
  equal (full batch processed) → no re-scan. Confirmed no gap and no double-process
  at either boundary.

- **`batchStartCursor` resume-after-throw is genuinely safe.** The batch's writes
  are collected in the `winners` map and committed in a SINGLE `batchWrites.commit()`
  AFTER the per-doc loop; the transient-maturity `HttpsError('unavailable')` throws
  INSIDE the loop, before that commit — so the current batch has ZERO committed
  writes, and resuming from `batchStartCursor` (= `lastDocId` at batch start, i.e.
  just past the prior COMMITTED batch) re-does exactly the uncommitted batch. No
  lost write, no double (the re-do is idempotent — see next).

- **Dedup winner is deterministic; re-runs converge (no oscillation).** Same-batch:
  ratings collapse into a `Map` keyed `${uid} ${poolKey}`, last-by-doc-id wins
  (iteration is `orderBy(documentId())` order), so the same-batch double-`set` that
  caused the old oscillation is gone — ONE idempotency-checked write per unique
  pool. The write is `batch.set` on a (uid,poolKey) doc-id (overwrite, NEVER
  increment), and the idempotency skip compares recipeId+ratingValue only
  (createdAt is deliberately NOT part of identity, so a Timestamp↔serverTimestamp
  flip can't defeat the skip). Test 10 proves the same-batch collision converges to
  the last-by-doc-id winner with a no-op second run. Cross-batch collision (the two
  colliding ratings ≥`BATCH_SIZE` apart) is NOT fully deduped — batch N writes copy-a,
  batch N+k overwrites with copy-b — but the FINAL committed value is invariant
  (global-max-doc-id winner) across runs, so it does not oscillate; the residual is
  one redundant overwrite per run, bounded to accepted-deviations edge #1 (rare
  self-own-copies-same-pool) — cost, not corruption. Not a finding.

- **`createdAt` cast fixed** — `data.createdAt instanceof admin.firestore.Timestamp
  ? … : serverTimestamp()` — a malformed field can no longer ride through as a bad
  cast.

**One residual Low (pre-existing, not introduced by this fix):** `runCanonicalRatingsBackfill`
does not clamp `maxRatings`, and the callable's `maxRatings = 10000` default only
fills `undefined`. A caller passing `maxRatings: 0` cutoffs on doc #1 with NOTHING
processed → `lastProcessedId` stays null → `nextCursor = lastProcessedId ?? lastDocId`
falls back to `lastDocId` (end of the fetched batch), so the next invocation
`startAfter`s PAST the whole unprocessed batch — silently skipping ratings while
still reporting `hasMore`. Only reachable via the absurd admin input `maxRatings:0`;
harmless at any sane value. Cheap guard: `const maxRatings = Math.max(1, options.maxRatings)`
at the top of the run fn (or clamp in the callable). Flagged, not blocking.

## Distilled principles (2026-07-04 consolidation — raw entries verbatim in cloud-functions-specialist.knowledge.archive.md)

### Completion-event telemetry (`emitTiming` family)
- Gemini/Vertex implicit caching: `usageMetadata.cachedContentTokenCount`, billed ~10% of input rate; cost = `((prompt - cached) + cached * CACHED_INPUT_DISCOUNT) / 1M * INPUT_COST_PER_M`, `cached` clamped to `[0, promptTokenCount]` (BUT-1032). Check the installed `.d.ts` before widening types locally.
- Never coerce a missing telemetry field to 0 — log as-is; Cloud Logging DROPS undefined JSON fields, which is what distinguishes "not reported" from a real zero (BUT-1032/1222/626).
- Widen a seam with an OPTIONAL field (`usage?`) over a side-channel log; existing test seams must compile untouched (BUT-1222).
- Early-exit-capable functions: declare `let experimentBucket: number | undefined` BEFORE the `emitTiming` closure, assign after the async step (BUT-626/1222). Each experiment gets its OWN salt string (`:prompt_experiment` ≠ `:thresholdType`) (BUT-626).
- Emitter contract test: assert EXACTLY ONE event per call via a module-scope logger-capture array cleared per case — catches try-path + catch-path double-emits (BUT-1222).

### Test seams & emulator integration infrastructure
- `npm test` = `node scripts/run-all-tests.js`, auto-discovers every `test:*` script (excluding `test:rules*`/`test:integration:*`) and runs ALL even after a failure — a new suite needs only its `test:<name>` script (BUT-1223). Windows: `spawnSync` needs `shell: true` for `npm.cmd` (BUT-1223).
- v2 exports carry `.run(event)` — call `fn.run(event)` with a typed payload to test STORAGE/FIRESTORE triggers without firebase-functions-test (BUT-839). Build `Change` payloads from REAL emulator snapshots (read-write-read); `.data()` on a missing snapshot returns undefined exactly like prod (BUT-839).
- `onSchedule`/v1-auth bodies with no seam: extract an exported async core (`cleanupOldRateLimitsCore(db)`), wrapper stays a one-line delegate (BUT-1354). Module-level `db = admin.firestore()`: set `FIRESTORE_EMULATOR_HOST` before `admin.initializeApp`, `require()` after (BUT-1354).
- Parent docs must be explicitly seeded for `orderBy("__name__")` parent scans — subcollection writes don't make the parent exist; the job silently processes zero (BUT-1354).

### Callables, transactions, logging hygiene
- `HttpsError` thrown by a DEEP helper still propagates to the client correctly (WS3).
- In transactions, `tx.set(ref, data, { merge: true })` over `tx.update` for any aggregate doc that might not exist — `tx.update` throws NOT_FOUND (B1 acceptFriendRequest). Seeders that ALWAYS `seedProfile()` hide this failure class: add a variant omitting the seed (B1).
- `onDocumentCreated` idempotency: stamp `notifiedAt` on success, `if (doc.notifiedAt) return;` at start — retries observe the stamp (WS3).
- User free-text NEVER in `logger.info` message strings — only length/hash/count in the structured second arg (WS3).

### PII scrubbing + GDPR cascade design
- Cross-port heuristic vectors (TS↔Dart) live in a shared JSON fixture (`pii-heuristic-vectors.json`, `{_header:[...], vectors:[{name,input,expected}]}`) — the "Dart copies this" note goes in `_header` (BUT-694c).
- JS `\b` misfires before å/ä/ö (non-word to `\w`) — use `(?<=^|[^A-Za-zÅÄÖåäö])`, never lead a Swedish-letter regex with `\b` (BUT-694c). Trigger-word-only case-insensitivity: per-letter classes (`[Mm]ormor`), not `/i` (BUT-694c). Possessive recipe titles ("Janssons frestelse") are pinned NEGATIVE vectors — never generalize to bare capitalized-word NER (BUT-694c).
- Cascade purges: discover children via `rootRef.listCollections()`, not hard-coded names — survives renames + finds ghost-parent subcollections (BUT-838). Gate root-doc deletes on `exists` (truthful audit) (BUT-838). New cascade steps are BEST-EFFORT (catch + warn + partial) — a rethrow re-runs the whole `onUserDeleted`, double-applying non-idempotent steps like `friendsCount: increment(-1)` (BUT-838).

### Scheduled analytics jobs
- Region set ONCE via `setGlobalOptions({region: "europe-west1"})` — never per-function (daily-snapshots).
- Don't assume a date field's type: `feedback.createdAt` is an ISO STRING (compare via `toISOString()` boundaries); siblings use real `Timestamp` — mixing silently returns zero rows (daily-snapshots).
- Full-scan jobs need an explicit cap (`RECIPE_SCAN_CAP = 5000`) + `logger.warn` when hit (count becomes a floor) (daily-snapshots). Stagger same-purpose schedules away from existing big scans (daily-snapshots).
- Anomaly gates: `baseline ≥ MIN_SAMPLES` AND `stddev > 0` AND `|z| > 3` AND `|today - mean| ≥ ABSOLUTE_FLOOR` — without the floor, 3σ on pre-launch counts (0→2) fires constantly (detectAnomalies). Use (n−1) sample stddev.
- A consumer job reading a producer's output schedules strictly after the producer's slowest run and SKIPS (never assumes zero) on a missing producer doc (detectAnomalies).
- `orderBy(FieldPath.documentId(), "desc")` gives a free trailing window on `yyyy-mm-dd`-keyed subcollections (lexicographic == chronological) (detectAnomalies).
- Always write the output doc even when empty (`{date, anomalies: [], computedAt}`) — "ran, found nothing" ≠ "never ran" (detectAnomalies).

### Fleet migration + CI gates + premise checks
- `firebase deploy --only functions` aborts the WHOLE deploy at the FIRST gen1→gen2 conflict — one error name ≠ one affected function; audit the fleet (Gen1→Gen2). `functions:list --json`'s `version` only populates on DIRECT terminal invocation (null via execSync). v1 auth triggers (`firebase-functions/v1`) have NO Gen2 equivalent — correct to stay gcfv1. Delete-then-recreate gap risk: SCHEDULED/CALLABLE = safe gap; EVENT triggers = risky (Eventarc does NOT backfill) — migrate those one at a time, low traffic.
- CI-gate logic = pure core (`promptChangelogViolation(changedFiles, diff)`) + thin CLI wrapper in `ci/` (excluded from index.ts). Diff-line token matching MISSES interior edits of multi-line template-literal prompts — also match hunk headers naming a prompt declaration. Match the shared suffix (`_SYSTEM_PROMPT`), not enumerated constants. PR base = `github.event.pull_request.base.sha`; push = `github.event.before` with `HEAD^` fallback; needs `fetch-depth: 0`. Verify end-to-end with a real violating commit, not just unit tests (BUT-1167).
- "This repo has no jest" — reconcile a ticket's framework assumption against the hand-rolled `test()` harness before adding anything (BUT-1167).
- OPS premise check: a client-side public/search key does NOT imply server write credentials — verify the dependency + Secret Manager secret exist at Step 0 (BUT-840, Algolia). "Scattered `.split()` calls" ≠ duplication — same intent on same input type at 2+ sites, proven by an evidence map, or no refactor (BUT-1352).

### Archived 2026-07-04 batch (2026-06-09 → 2026-06-26) — see cloud-functions-specialist.knowledge.archive.md
- 06-09→06-13 (3) — emitTiming/cost telemetry: Gemini cache cost, OCR timing, prompt A/B buckets.
- 06-10→06-24 (3) — test infra: run-all runner, CloudFunction.run() trigger tests, emulator cleanup-job tests.
- 06-11 (1) — PII heuristics + on-user-deleted GDPR cascade design.
- 06-15 (1) — Algolia OPS-BLOCKED: client key ≠ server credential.
- 06-20 (5) — WS3/B1 callable+transaction reviews; daily-snapshots + detectAnomalies design; Gen1→Gen2 fleet scoping.
- 06-21→06-22 (2) — prompt-changelog CI gate; splitter-dedup premise-stale.

### Archived (pre-2026-06-04) — see cloud-functions-specialist.knowledge.archive.md

- 2026-04-25 — initial seed
 — Seeded knowledge file from index.ts and SDK conventions
- 2026-04-27 — BUT-425 OCR URL SSRF guard [Bug fixed]
 — Added SSRF host-pin + validation for OCR image URLs
- 2026-04-27 — BUT-641 notification payload schema [Pattern discovered]
 — Standardized FCM data payload schema across senders
- 2026-04-29 — BUT-621 Remote-Config-style LLM prompts [Pattern discovered]
 — Moved LLM prompts to Firestore with fallback + cache
- 2026-04-30 — BUT-647/BUT-645/BUT-638 sprint [Pattern discovered]
 — Quiet-hours, notification effectiveness, North-Star aggregation functions
- 2026-04-30 — security review fixes (C1/C2/H1/M1) [Bug fixed]
 — Fixed producerless aggregator, GDPR TTL/cascade, index, poison-pill loop
- 2026-04-30 — BUT-458 one-shot migration patterns [Pattern discovered]
 — Admin-gated backfill migration with pagination and idempotency
- 2026-04-30 — BUT-605 retention extension to D14/90/180 [Pattern discovered]
 — Extended retention tracking with deterministic doc ids
- 2026-05-01 — BUT-741 backfill parallelization [Pattern discovered]
 — Parallelized recipe-ownership backfill with dedup + bounded concurrency
- 2026-05-01 — BUT-688 win-back A/B via Remote Config [Pattern discovered]
 — Deterministic bucket assignment for win-back push copy A/B
- 2026-05-01 — BUT-599 per-feature retention aggregator [Pattern discovered]
 — Daily DAU/WAU aggregator across five recipe features
- 2026-05-02 — BUT-577 ingredient-lines partial-array salvage [Bug fixed]
 — Bracket-counter salvage for truncated Gemini ingredient JSON
- 2026-05-04 — BUT-482 / BUT-483 / BUT-627 Sprint G [Pattern discovered]
 — Rating debounce, timing logs, ping rate-limit sweeper
- 2026-05-02 — BUT-753 admin cascade for legacy `sharedWith` arrays [Pattern discovered]
 — Cascade cleanup of legacy sharedWith array field on deletion
- 2026-06-03 — BUT-1187 Gemini model retirement 404 [Bug fixed]
 — Swapped retired Gemini model id, one-line fix

### 2026-07-02 — ingredient `section` field (PR #211, prompt v3.0.0) review [Pattern discovered]

Reviewed the chunk-3 CF diff adding nullable `section` to `INGREDIENT_SCHEMA` +
`ExtractedIngredient`, reworking the extraction prompt's group rule/EXEMPEL 4,
and capping `section` at 60 chars in `validateIngredient`. Clean except one
deploy-coordination finding. Patterns worth remembering:

- **Compiled-in prompt edits are INERT in prod while a valid `system/prompts`
  override doc is live (BUT-621).** `structure-recipe.ts` serves
  `prompts.recipeExtractionSystemPrompt` from Firestore when the doc validates;
  the new compiled-in v3.0.0 rule ("sätt section=...") never reaches the model
  until the operator updates the doc. Worse than inert here: the stale doc
  actively teaches the OLD flatten (`preparation="deg"`), so post-deploy the
  schema offers `section` but the prompt forbids using it — feature silently
  dead, `preparation` stays polluted, analytics reports the doc's
  `promptVersion` (not 3.0.0). **Any prompt-content change must ship with a
  matching prod `system/prompts` doc update (or verified doc absence) as an
  explicit deploy step.** Sibling of the BUT-684 required-key footgun but
  inverted: there the doc broke on deploy; here the doc silently wins.

- **Schema `description` is the only prompt surface shared by ALL callers of a
  schema.** `INGREDIENT_SCHEMA` feeds RECIPE_SCHEMA (extract + OCR printed +
  handwritten + spoken) AND INGREDIENT_LINES_SCHEMA. Putting the behavioural
  guidance ("never repeat group name in preparation / never emit heading as
  ingredient") in the field's `description` gives the OCR/spoken paths the
  rule without touching their prompts — and, unlike the prompts, the schema is
  compiled-in (NOT Firestore-overridable), so it deploys atomically.

- **responseSchema cannot enforce string length** — server-side
  `trim().slice(0, maxLen)` in the validator is the enforcement point for any
  bounded STRING field. Blank/whitespace → null BEFORE the cap so no phantom
  empty groups.

- **Widening `ExtractedIngredient` with a required TS field**: `tsc --noEmit`
  is the audit tool for literal construction sites (here: one, in
  `ocr-retry.test.ts`); `validateIngredient` is the single runtime constructor,
  so missing/non-string keys from old cached responses or pre-3.0.0 replays
  coerce to null — backward compatible by construction. Contract pinned in
  `__tests__/ingredient-section-schema.test.ts` (5 cases incl. a prompt-content
  guard asserting the old flatten wording is GONE).


### 2026-07-03 — BUT-1467 sync-ingredients core extraction + allergen lockstep triple [Pattern discovered]

`sync-ingredients.ts` (admin/, ts-node script) calls `admin.initializeApp()` +
`main()` at import time, so it can't be imported by tests. BUT-1467 extracted
the pure logic into `admin/sync-ingredients-core.ts` (csvToFirestore, diff,
mergePreservedFields, isResurrection, buildSyncReport) — the admin-script
analog of the `runX(deps)` seam. Tests: `__tests__/sync-ingredients-diff.test.ts`
(8 behavioral cases, `_unit-runner`).

**Allergen lockstep triple** (three lists that must stay aligned by hand):
1. `admin/sync-ingredients.ts` — `VALID_PROPERTIES` (NOT in `-core.ts`; the
   core file's docstring pointing there is a known drift hazard).
2. `shared/allergen-properties.ts` — `ALLERGEN_RELEVANT_PROPERTIES` (allergen
   block + fish/shellfish/seafood/dairy/egg). Feeds the sync diff report now,
   the BUT-1468 alias hold-for-review gate next.
3. `lib/services/tagging/config/allergen_config.dart` — client
   `triggerProperty` list. Includes non-medical verdict triggers
   (`contains-alcohol`, `meat`, `pork`, `beef`) that produce FREE/CONTAINS
   tags via the same machinery — decide explicitly whether a "wrong allergen
   verdict" gate covers them; as of BUT-1467 they are NOT in
   ALLERGEN_RELEVANT_PROPERTIES.

No automated drift pin exists between the three; when reviewing any of them,
re-diff all three by hand.


### 2026-07-03 — audit-event timing in confirm-gated admin scripts [Pattern discovered]

BUT-1467 review of `admin/sync-ingredients.ts`: the `system_events` ops-log row
(`type: "ingredient_sync"`, `executedAt`, counts) was written by
`persistSyncReport` BEFORE the `askConfirmation` prompt and before any batch
commit. Consequence: a run the operator cancels at the prompt, or one that
throws mid-batch, still leaves an ops-log row claiming the sync executed —
the audit trail over-claims, which defeats the feature's own purpose.

Rule for confirm-gated admin scripts: **the human-review artifact (JSON diff
report file) belongs BEFORE the confirmation prompt (the operator reviews it to
decide); the executed-marker Firestore row belongs AFTER the final commit.**
Split "persist report" into write-file (early) + log-event (post-commit) when
both live in one helper. Dry-run correctly skips the event row.

Related soft-delete+TTL patterns confirmed good in the same review:
- Resurrection routing depends on the Firestore fetch being UNFILTERED
  (`collection.get()` with no status filter) so soft-deleted docs land in
  `toUpdate` (status differs) rather than `toAdd` — the update path can then
  attach `FieldValue.delete()` clears for `deletedAt`/`expireAt`.
- Pre-existing (not introduced): `hasChanges` skips `aliasesEn`/`searchTerms`
  (edits to only those never sync), and sparse optional fields
  (`notesSv`, `typicalUnit`, `seasonAvailability`, …) omitted from an `update`
  payload are never DELETED when cleared in the Sheet — such rows churn as
  "updated" on every sync forever and now pollute the diff report.


### 2026-07-03 — BUT-1468 alias hold-for-review review [Pattern discovered]

Review of `analytics/analyze-corrections.ts` (maturity gate + allergen hold)
and new `analytics/review-learned-alias.ts` (admin approve/reject/revoke).

- **Server gate vs client matching normalization MUST agree.** The
  `allergen_alias_text` hold gate resolves the alias text via
  `findIngredientByName` (exact / lowercase / array-contains on stored
  diacritic forms), but the Dart consumer (`FirebaseIngredientRepository
  ._normalize`) matches learned aliases **diacritics-stripped** (å/ä→a, ö→o).
  So an ASCII-variant alias ("jordnotter") bypasses the server gate yet still
  matches the real allergen word ("jordnötter") client-side. General rule: any
  safety gate filtering strings the client will later match must run the SAME
  normalization as the client matcher, or match on a normalized-lookup field
  (e.g. stamp a `normalizedNames` array in the sync pipeline). Filed High.
- **Hold states need an allowlist status check, not a blocklist.** The old
  auto-approve guard was `status !== "approved"`; introducing
  `held_for_review`/`rejected`/`revoked` under that guard would have let the
  quorum re-approve them. The diff correctly flipped to
  `status === "pending"`. When adding a terminal/parked state to a txn state
  machine, audit every status conditional for blocklist shape.
- **Hold-reason computed outside the txn is acceptable** when (a) it needs
  queries, (b) its input (ingredient `properties`) changes only via rare
  admin/sync paths, and (c) the bad-direction outcome is recoverable via an
  admin revoke callable. Cheap hardening: the doc-read half (target's own
  properties) can be re-verified inside the txn with `tx.get(ingredientRef)`
  at the threshold moment; Admin SDK txns also support `tx.get(query)` if the
  query half ever needs to move inside.
- **`npm test` composite deliberately excludes `test:rules:*` and
  `test:integration:*`** (`scripts/run-all-tests.js` EXCLUDE_PREFIXES) —
  emulator-bound suites run manually. Don't file "new test not in the
  composite chain" for `test:integration:*` scripts.
- **Hoist per-event-constant reads out of per-candidate loops**: a correction
  event with N ingredient corrections ran `isMatureAccount` (1 user-doc read)
  N times for the same uid.
- **`learned_aliases` admin queries (`status ==` + `orderBy count desc`) have
  NO entry in `firestore.indexes.json`** — equality+orderBy needs a composite
  in prod (emulator auto-creates). Pre-existing for pending/approved; verify
  the console before relying on the new held_for_review queue surfacing.


### 2026-07-04 — best-effort telemetry must resolve `admin.firestore()` INSIDE the try [Bug fixed]

`captureLlmSample` (`llm/llm-sample-capture.ts`, BUT-1451) had a test-seam
default param `db: admin.firestore.Firestore = admin.firestore()`. Default
params are evaluated at **call time, BEFORE the function body's try/catch**, so
in any context with no initialized default app (DI-seam unit tests) or an
unreachable Firestore, `admin.firestore()` threw and the exception escaped the
"best-effort, never a failure surface for an import" catch — it bubbled up
through the awaiting OCR/structure-import callers and surfaced as an internal
`HttpsError`. This kept the "Cloud Functions Unit Tests" workflow red on `main`
for ~4 days (ocr-retry, kill-switch, ocr-validation, ocr-handwritten-prompt).

Fix: param → optional `dbOverride?: admin.firestore.Firestore`; resolve
`const db = dbOverride ?? admin.firestore();` as the FIRST line inside the try.
The missing-app/unreachable throw is now swallowed by the existing catch.

**Reviewed clean:**
- **Zero production behavior change** — prod always has an initialized app
  (`admin.initializeApp()` in `index.ts`), so `admin.firestore()` never threw
  there; the handle is SDK-memoized per app, so resolving it inside the try vs
  as a default has no cost/perf delta. Only the failure path changes.
- **Seam rename breaks no caller** — the only two prod callers
  (`ocr-recipe-image.ts:435`, `structure-recipe.ts:332`) pass no db (now safe).
  The standalone `llm-sample-capture.test.ts` passes db as the 2nd positional
  arg — unchanged position, just optional/renamed.
- **Idempotency N/A** — helper does `.add()` (auto-id, inherently non-idempotent
  duplicate on retry), but it's awaited best-effort telemetry that can never
  throw, and both callers are `onCall` callables (no server-side auto-retry).
  Not part of any retry-corruption story. The fix doesn't touch this.

**Pattern (reusable):** any best-effort / never-throw helper that takes a
`= admin.firestore()` (or any throwing expression) default param has a latent
escape hatch — the default is evaluated OUTSIDE the guard. Make the seam
`?:` optional and resolve `?? admin.firestore()` on the first line inside the
try. Same root cause as the 2026-06-10 `notification-rate-cap.ts` lazy
`admin.firestore()` note — a throwing SDK call in a "can't fail" path must sit
inside the catch, never at the boundary.
