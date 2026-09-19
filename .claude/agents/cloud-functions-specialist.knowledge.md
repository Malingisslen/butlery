# cloud-functions-specialist — accumulated knowledge

Core card: read on every review, after the shared review core. The chapters are listed under
`knowledge.tiers` in `.claude/shared-plugin.json`; read each chapter whose `paths` match a
file in the diff. The archive, `cloud-functions-specialist.knowledge.archive.md`, is never
read at review. A new principle goes into the chapter it is about, and into this card only
if it applies to every review; `knowledge-caps-gate` refuses a core card over 15,000 chars
and a chapter over 20,000.

---

## Function families (functions/src/index.ts)

| Path | Concern (trigger) | Test command |
|---|---|---|
| `llm/` | LLM cost/latency/safety (callable) | `test:ocr-retry` |
| `cleanup/` | Idempotent deletion (scheduled+onDelete) | `test:cleanup-*` |
| `social/` | Profile propagation (onUpdate) | `test:on-profile-updated` |
| `events/` | Telemetry append-only (onCall) | `test:parse-correction` |
| `admin/` | Mixed: ts-node scripts AND deployed ops callables | N/A |
| `notifications/` | FCM push, rate-limited | `test:send-notification` |
| `ingredients/` | Soft-delete cascade (onUpdate) | (integration) |
| `analytics/` | Aggregation + lifecycle (scheduled) | `test:track-retention` |
| `ratings/` | Pooled-rating aggregation | `test:canonical-rating-aggregation` |
| `family/` | Household data lifecycle (scheduled) | `test:purge-dormant-family-data` |
| `messaging/` | Conversation/DM safety (onCreate) | `test:enforce-group-minor-membership` |
| `account/` | GDPR deletion + age verify | `test:request-account-deletion` |
| `middleware/` | Auth/validation/rate-limit | `test:rate-limiter-*` |

## Region & global options

`setGlobalOptions({ region: "europe-west1", maxInstances: 3 })` in
`index.ts`, above every `export … from`. Never re-region per-function
without approval (mismatch = silent client-side "not found").
- **Global and per-function options MERGE key-by-key** (`copyIfPresent`) —
  a per-function `memory`/`timeoutSeconds`/`retry`/`secrets` inherits the
  rest and wins on collision.
- **`maxInstances` is a DEPLOY gate, not tuning.** Global 3; the two
  ingredient cascades override to 10. Unset = the v2 default 100/function,
  which blew the regional CPU quota. An increase is refused
  (`NOT_ENOUGH_USAGE_HISTORY`); remedy is one function per `firebase deploy`.
- **3 instances != 3 concurrent executions, and a LOW cap PACKS.**
  `concurrency` defaults to 80 at `cpu >= 1`; only a long-lived, memory-hungry
  handler declares `concurrency: 1` (`SERIALISED_ENDPOINTS`), trading OOM for
  QUEUE TIME charged against `isCascadeEventExpired` (from `event.time`) — a
  queued-only delivery is abandoned silently and writes NO marker, so marker-based
  diagnostics read clean. Raise `maxInstances`, never `concurrency`. Notification
  fan-out is IN-PROCESS — a cap never splits a batch.
- **A trigger or `onSchedule` NOT re-exported from `index.ts` is DEAD** — it
  compiles, its unit tests pass, and nothing deploys, so every comment calling
  it a safety net is false. New periodic work is a `MaintenanceTask` in
  `WEEKLY_REPORT_TASKS`/`DAILY_ANALYTICS_TASKS` (Scheduler bills per JOB, 3 free
  per billing account), never a new `onSchedule`; a standalone one also needs
  its own `timeoutSeconds` (else the v2 60s default) and must sit BELOW
  `setGlobalOptions` in `index.ts`.

## Idempotency rules (the most bug-prone area)

Triggers retry on uncaught exception; handlers must be idempotent:
1. **Aggregate/counter writes** → `FieldValue.increment` + an event-id guard
   doc (`processed-events/{id}`) in the same transaction. A counter written
   AFTER the transaction, keyed on its outcome, is ATTEMPT-safe ONLY — safe
   under a `runTransaction` retry, NOT under redelivery, unless the counting
   branch also wrote the event-id bookkeeping — a reject branch that returns
   before it re-counts on every redelivery. Exactly-once is `doc(eventId).create()` + swallow ALREADY_EXISTS, never a
   post-hoc `add()`; `set(merge:true)`+`increment` needs no transaction.
2. **Cascade deletes** → a target already gone on retry is success.
3. **External-API calls** → derive a stable idempotency-key from the event.
4. **Sends** → same shape: a `sent-events/{id}` guard BEFORE sending.
5. **`retry:true` needs every write safe on a MISSING doc** — `.update()`
   throws NOT_FOUND (grpc `5`), turning a drop-once into a permanent loop.
6. **Client-supplied strings in a doc path are a poison-pill surface** —
   validate non-empty, ≤1500 UTF-8 bytes, no `/`, not `.`/`..`/`/^__.*__$/`.
   A rules-pinned DOC ID pins nothing about the FIELDS inside it (`blocks` pins
   `blockerId` and the composite id, leaving `blockedId` free), and a bad segment
   makes the ref builder throw INVALID_ARGUMENT — a `retry:true` loop any account
   plants with one write. Every DOWNSTREAM caller with a TIGHTER bound owes the
   same treatment at ITS OWN boundary: `getUser` rejects >128 chars pre-network
   with `auth/invalid-uid`, so ANSWER that code "gone" rather than rethrow it.
7. Sanitisation must never shrink the value a security gate's THRESHOLD is
   computed from.
8. **Concurrent Tier-1 cascade legs (`Promise.all`) can write the same
   collection** — grep sibling legs for writers before claiming "no
   race"; make anonymising legs NOT_FOUND-tolerant PER DOCUMENT,
   and give every new sweep its own leg in `probeResidualData` — its three shapes
   (top-level FIELD, `users/{uid}` ENUMERATION, collectionGroup) make "the probe
   cannot see this collection" never a reason to skip one.
9. A sweep cap's threat model comes from the write RULE it bounds, never a
    copied rationale — a bound's ABSENCE needs the same read. Never cite a rules
    LINE NUMBER.
10. A fake whose `update()` no-ops on a missing doc can't stage grpc 5 —
    give it an injectable `updateFailures: Map<path, grpcCode>`.
11. **Resolve-or-create keyed on a QUERY is not idempotent.** A
    `where(...).limit(1).get()` outside the transaction lets two concurrent
    callers both create, and no fake can show it (single-threaded). Derive
    the doc id deterministically from the key and `tx.create()` instead.
12. **Two triggers on ONE collection: gate the re-read on WRITE KIND** — never
    a LIST of writers, never the sibling's ADMISSION TEST (`create`-only misses
    the read-receipt update; the predicate misses a row edited OUT of
    candidacy). Stage by REPLAYING a pre-rewrite snapshot. Record: ADR-0009.
13. **New I/O ABOVE a handler's own `try` is a new drop point.** A gen1 Auth
    trigger has no `failurePolicy`, so a throw from a pre-flight read (a kill
    switch, a config flag) discards the event with nothing to retry it — wrap it
    and fail OPEN, matching how the reader treats its own malformed/expired
    cases (`llm-sample-capture.ts` is the precedent). A default that fails
    CLOSED suppresses the work instead.
14. **`HttpsError` thrown inside `db.runTransaction` is NOT retried** —
    `isRetryableTransactionError` switches on numeric gRPC codes and
    `HttpsError.code` is a string, so it rolls back first-attempt.

## Cost & cold-start

- Narrow imports. 540s is the v2 max; read the real value off `__endpoint`.
- **An in-code timeout guard is dead unless `timeoutSeconds` is declared on the
  SAME trigger** — global options carry no timeout, so a v2 event function
  defaults to 60s. Pin guard-ms against `__endpoint.timeoutSeconds`; a
  constant-vs-constant test survives deleting the declaration.
- **A `retry:true` trigger enumerating a client-writable collection has
  unbounded fan-out** — cap the READ (`.limit(CAP+1).get()`), chunk-delete with
  a per-item `.catch` on grpc code only, never throw. The over-cap verdict
  follows the ACTION: DECLINE a destructive sweep (truncating half-erases), CUT
  the capped page for per-row ACCESS REVOCATION (refusing lets a planter keep
  access).

## Secrets handling

`defineSecret("MY_KEY")`, never env vars in code. Never log a secret. Root
`.env` is Flutter-only.

## Test commands (from `functions/`)

- `npm run build` before any commit. `npm test` = `run-all-tests.js`,
  auto-discovering every `test:*`. **A new `__tests__/*.test.ts` is invisible
  until its `test:*` script exists** (`check-test-registration.js`; additions to
  an existing suite need none), and a `test:*` naming an UNTRACKED file reddens
  the CI unit lane — file + package.json line in ONE commit.
- `npm run test:rules:all` — a new rules/integration suite is FOUR
  registrations: its own `test:*` script, an append to the `&&` chain in
  `test:rules:all`, BOTH `paths:` blocks in `firestore-rules.yml`, and a UNIQUE
  **bare-literal** `const PROJECT_ID = "..."` (`rules-coverage-report.js` discovers
  ids by regex; an env-defaulted const drops the suite from the coverage union —
  put a probe override at the `projectId:` CALL SITE).
  Details are `firestore-rules-tester`'s; hand rules off.
  `test:rules*`/`test:integration:*` are excluded from the unit lane by prefix.
- `scripts/run-ci-unit-tests.js` — the real CI gate. Hand-rolled harness,
  no jest — call `runTests` exactly ONCE per file.

## Logging conventions

`logger` from `firebase-functions/logger`, never `console.log` (except `admin/`
ts-node scripts): `logger.info("event", {structured})` — stable string, no
PII. **`logger.error(msg, { err })` records NO
cause** — unwraps only when passed POSITIONALLY; use `errCode`/`errName`
from `(err as {code?}).code`.
- **Hash ALL PII/title-derived fields consistently** — a mixed line (one
  hashed, one cleartext) is the tell. `hashUid(uid)` or `uid.slice(0,6)`.
- **A DOCUMENT ID can be PII depending on the CALLER** — a GROUP conversation
  id is server-minted; a DM's is `direct_<uidA>_<uidB>` and a `blocks` id is
  `{blockerId}_{blockedId}`. Hash the WHOLE id (`logSafeConversationId`,
  `hashUid(doc.id)`); re-derive it for every NEW caller of an id-logging helper.
- A logged `FieldPath(…, uid)` stringifies its SEGMENTS — the raw uid lands on
  the very line that truncates it to `uid_prefix`. Log a literal label.

## What NOT to do

- Don't trust a client-controlled field for a security decision unless the
  create/update RULE pins it to `request.auth.uid` — a PRESENCE requirement
  binds a tampered client, a CEL evaluation error only binds our own.

---

### Test seams & non-vacuity
- v2 exports carry `.run(event)` — test triggers with a typed payload from
  real emulator snapshots; no firebase-functions-test.
- **A wrapper/gate test is non-vacuous only if breaking it produces a
  DIFFERENT result than any other failure** — the recurring failure is one
  error code from TWO branches; assert on branch-unique text. An unsimulated
  fake stub must THROW, not silently succeed — and a fake resolving a dotted
  `where()` field MUST special-case `FieldPath` (read `.segments`): it HAS
  `.split`, so it matches ZERO in silence. Type EVERY fake query seam
  `string | FieldPath` — an `as unknown as Firestore` cast checks none.
### Rate limiting & LLM cost gates (middleware/rate_limiter.ts)
- A retry/fallback path calling an UNWRAPPED core skips BOTH per-user and global
  caps; the shared global counter is spent LAST so a denial wastes only the caller's.
- **`enforceRateLimit` for NON-LLM callables; `withRateLimit` only for LLM-backed
  ones** (ADR-0013). The wrapper also spends `system/llmLimits`, so an exhausted
  AI quota would refuse signup or LEAVING a group chat; it re-orders auth/limit
  ABOVE the handler's own eligibility gates (validate + `assertAgeCompliant` /
  `assertAccountMatured` must stay above the limit call); and left beside an
  inline `checkRateLimit` it burns two tokens per call.
- **Bare `checkRateLimit` + a local throw drops BOTH** the `system_events`
  `rate_limit_violation` row AND `details.retryAfterSeconds`; both spellings are
  live, so copying a sibling is CONSISTENT, not correct. Abuse/cost gates fail
  CLOSED on a Firestore error; some notification gates deliberately fail OPEN —
  don't harmonize. A `…WithDeps` core test sees none of the wrapper's gates, and an
  unknown key falls back to `RATE_LIMIT_CONFIGS.default` in silence — pin the
  `(check|enforce)RateLimit(uid, "<key>")` LITERALS by parsing source, over EVERY
  callable in the directory, never a hand-named subset.
- **A pin matching BOTH spellings cannot detect a revert to the bare
  form** — it pins the KEY, never `details`. Pin on the DENIED path: both
  `enforceRateLimit` and `logRateLimitViolation` read `getFirestore()`, so
  `__setFirestoreForTest` + a throwing fake reaches the fail-closed branch. The
  ALLOWED path is unreachable — `getDb()` is a bare `admin.firestore()`.
- **A new `onCall` export is a THREE-file change**: the function, its
  `test:*`/suite in `package.json`, and `app-check-enforcement.test.ts`'s
  classification (`ADMIN_EXEMPT` only if the handler's FIRST statement
  checks the admin claim); a deletion is the same in reverse.
- **A TTL field is INERT without a policy** — `fieldOverrides` `"ttl": true` +
  `firebase deploy --only firestore:indexes`. `--force` deletes every live
  override absent from the file; only `gcloud firestore fields ttls list`
  proves ACTIVE vs DECLARED.
- **`expireAt`/`expiresAt` is a retention CLAIM, not retention — sweep ALL at
  once.** The NAME must match every writer of the same target; the anchor must
  cover the whole collection GROUP; the TTL must exceed the READER's window.
  An ENUMERATED allowlist fails silently toward the SHORTER window — derive it
  from the WRITER files.
- **Review the STAGED copy** — `git hash-object <path>` must match
  `git ls-files -s <path>` (never `md5sum`: CRLF moves it, not the blob hash).
  The index holds PRE-FIX bytes on `MM`. Read `.claude/state/review-ledger.jsonl`
  with the **Grep tool** (Bash `grep` is refused by its own hook).
