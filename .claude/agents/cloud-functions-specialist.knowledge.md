# cloud-functions-specialist — accumulated knowledge

Step 0 of every Cloud Functions task. Durable PRINCIPLES only, edited IN
PLACE. **Target: under ~25,000 characters** — an edit that would push it
over must tighten or retire an existing principle in the same edit.

## How to update this file

- **Principles here, edited in place; dated narrative to
  `cloud-functions-specialist.knowledge.archive.md` (append-only).** A
  principle earns its place only if a future run would act DIFFERENTLY —
  keep exact names/codes/thresholds, cut the story, merge duplicates. Bias
  toward writes/deletes, idempotency, retry, cost, region, GDPR.

---

## Function families (functions/src/index.ts)

| Path | Concern (trigger) | Test command |
|---|---|---|
| `llm/` | LLM cost/latency/safety (callable) | `test:ocr-retry` |
| `cleanup/` | Idempotent deletion (scheduled+onDelete) | `test:cleanup-*` |
| `social/` | Profile propagation (onUpdate) | `test:on-profile-updated` |
| `events/` | Telemetry append-only (onCall) | `test:parse-correction` |
| `admin/` | One-shot scripts, ts-node, never deployed | N/A |
| `notifications/` | FCM push, rate-limited | `test:send-notification` |
| `ingredients/` | Soft-delete cascade (onUpdate) | (integration) |
| `analytics/` | Aggregation + lifecycle (scheduled) | `test:track-retention` |
| `ratings/` | Pooled-rating aggregation | `test:canonical-rating-aggregation` |
| `family/` | Household data lifecycle (scheduled) | `test:purge-dormant-family-data` |
| `messaging/` | Conversation/DM safety (onCreate) | `test:enforce-group-minor-membership` |
| `account/` | GDPR deletion + age verify | `test:request-account-deletion` |
| `migrations/` | One-shot gated backfills | n/a |
| `middleware/` | Auth/validation/rate-limit | `test:rate-limiter-*` |
| `shared/` | Pure helpers, no triggers | varies |

New family → append a row.

## Region & global options

`setGlobalOptions({ region: "europe-west1", maxInstances: 10 })` in
`index.ts`, above every `export … from`. Never re-region per-function
without approval (mismatch = silent client-side "not found").
`admin.initializeApp()` runs once, after that call.
- **Global and per-function options MERGE key-by-key**
  (`{...optionsToEndpoint(global), ...optionsToEndpoint(own)}` via
  `copyIfPresent`) — declaring `memory`/`timeoutSeconds`/`retry`/`secrets`
  loses nothing and still inherits the rest; per-function wins on collision.
- **`maxInstances: 10` is a DEPLOY gate, not tuning.** Unset = the v2
  default 100/function; Cloud Run reserves `cpu x maxInstances` summed
  region-wide, so 70 gen2 x 1 vCPU x 100 blew "Total allowable CPU per
  project per region", surfacing as `Container Healthcheck failed` on 53.
  Raising it globally re-arms the wall; a rolling deploy can trip it too
  (old revisions hold their reservation until replaced) — batch it.
- **10 instances != 10 concurrent executions, and a LOW cap PACKS.**
  `concurrency` defaults to 80 at `cpu >= 1`, and firebase-tools'
  `memoryToGen2Cpu` gives 1 for 128MiB–2GiB, so 80 holds for every function
  here → ~800 in flight, packed ~N/10 per container. A handler both
  LONG-LIVED and memory-hungry per request declares its OWN `concurrency: 1`
  — the two ingredient cascades (540s/512MiB holding a 500-doc page; ≤500
  events per `sync-ingredients` batch). It never changes the
  `cpu x maxInstances` quota, so it is deploy-neutral, and it is pinned BY
  NAME (`SERIALISED_ENDPOINTS`, `deploy-manifest.test.ts`).
- **Serialising trades OOM for QUEUE TIME, and queue time is charged
  against the event-age guard.** `isCascadeEventExpired` measures from
  `event.time`, so a FIRST delivery that only waited in the queue is
  abandoned without ever having failed. Budget before any `concurrency: 1`:
  `maxDuration = maxInstances x maxEventAge / burstSize` — 10 x 1h / 500
  events = 72s each, ample at today's volume. If a burst nears it, raise
  `maxInstances` on THOSE functions (override + `ALLOWED_OVERRIDES` in
  `deploy-manifest.test.ts`), never `concurrency`. Scheduled jobs need ONE
  instance; notification fan-out is IN-PROCESS (`MAX_PER_RUN=200`,
  `MAX_BATCH_NOTIFICATIONS=100`), so a cap never splits a batch.
- **`onUserDeleted` is the ONLY gcfv1 export** — a v1 auth trigger with its
  own `.region("europe-west1").runWith(...)`, unreachable by
  `setGlobalOptions`, so no instance cap and (platform property, unprovable
  here) a CPU pool separate from Cloud Run's. Exclude it from any
  "every function" claim.
- **Prove endpoint config, never reason about it:** `npm run
  test:deploy-manifest` imports the ENTRY POINT (the only way the global
  call runs) and asserts region + a numeric `maxInstances` on every
  `platform:"gcfv2"` endpoint, plus `concurrency === 1` on the two cascades
  — 71 exports, 70 gen2, healthy total 7/7. An unset v2 option is a sentinel
  OBJECT (`RESET_VALUE`; `toJSON()` → null, so `JSON.stringify` prints
  "null" while `== null` is FALSE) — check `typeof x === "number"`. `gcfv2`
  resets `maxInstances` AND `concurrency`; `initV1Endpoint` drops
  `concurrency`, so on the one gcfv1 export it is plain `undefined`. Nothing
  else reddens: `tsc` and every other suite stay green when any of these is
  deleted. VACUITY SURFACE is the `gcfv2` FILTER: rename `platform` and every
  assertion passes over ~0 endpoints — guard the FILTERED count (it reddens
  on an `__endpoint` rename too, demoting the readability check to a
  DIAGNOSTIC) and it records once per CALLER. A value pin (`!== 10`) misses
  the delete-the-option mutant (non-numbers drop first), so keep the presence
  check. A by-NAME pin must treat a missing export as FAIL, not skip.
  Re-measure every "N/N" a header quotes after adding an assertion.
- **Six gen2 exports pin their OWN region** — `moderateUpload`,
  `syncConversationLastMessage`, `purgeExpiredAuditLogs` and the three
  `migrations/` backfills. A global-region change moves 64 of 70, so never
  say a global option "reaches every export" without counting.

## Firebase Functions v2 — what to use

- `logger` from `firebase-functions/logger`, never `console.log` (except
  `admin/` ts-node scripts, which are never deployed).
- **`HttpsError` thrown inside `db.runTransaction` is NOT retried** —
  `isRetryableTransactionError` switches on numeric gRPC codes;
  `HttpsError.code` is a string and matches none, so the transaction rolls
  back first-attempt. Lets an authorization gate live inside the same
  transaction that reads the doc it judges.

## Idempotency rules (the most bug-prone area)

Firestore triggers retry on uncaught exception; every handler must be
idempotent:
1. **Aggregate writes** → `FieldValue.increment` + an event-id guard doc
   (`processed-events/{id}`) in the same transaction.
2. **Cascade deletes** → a target already gone on retry is success.
3. **External-API calls** → derive a stable idempotency-key from the event.
4. **Sends** → write a `sent-events/{id}` guard BEFORE sending.
5. **`retry:true` needs every write safe on a MISSING doc** — `.update()`
   throws NOT_FOUND (grpc `5`), turning a drop-once into a permanent loop.
6. Errors COLLECTED then thrown later are not a gate — throw immediately.
7. **Client-supplied strings in a doc path are a poison-pill surface** —
   validate non-empty, ≤1500 UTF-8 bytes, no `/`, not `.`/`..`/`/^__.*__$/`.
8. Sanitisation must never shrink the value a security gate's THRESHOLD is
   computed from. Can't be idempotent? Document why + add a guard doc.
9. **Concurrent Tier-1 cascade legs (`Promise.all`) can write the same
   collection** — grep sibling legs for writers before claiming "no
   race"; make anonymising legs NOT_FOUND-tolerant PER DOCUMENT
   (`commitInChunks(strict:false)` fails a whole chunk on one NOT_FOUND),
   and give every new sweep its own `count()` leg in `probeResidualData`.
10. A sweep cap's threat model comes from the write RULE it bounds, never
    a copied rationale — a bound's ABSENCE needs the same read
    (`hasRequiredFields` ≠ `hasOnly`). Never cite a rules LINE NUMBER in a
    comment — cite the `match` pattern or function name (it drifts).
11. A fake whose `update()` no-ops on a missing doc can't stage grpc 5 —
    give it an injectable `updateFailures: Map<path, grpcCode>`. Deleting a
    cascade LEG needs a `__tests__` grep for writers of that path.

## Cost & cold-start

- Billed per ms × memory + per-invocation. Narrow imports. 540s is the v2
  max, but read the real value off `__endpoint` — the LLM callables are
  `structureRecipe` 60s/512MiB and `ocrRecipeImage` 120s/1024MiB.
- **An in-code timeout guard is dead unless `timeoutSeconds` is declared on
  the SAME trigger** — global options carry no timeout, so a v2 event
  function defaults to the 60s platform timeout otherwise. Export the
  guard-ms/platform-seconds as a pair and pin it against the deploy
  manifest's `__endpoint.timeoutSeconds` (a constant-vs-constant test
  alone stays green after the declaration is deleted).
- **`x || DEFAULT` ≠ a typed guard** — passes negatives/numeric-strings/
  `true` through. Use `typeof x === "number" && x > 0 ? x : DEFAULT`.
- **A `retry:true` trigger enumerating a client-writable collection has
  unbounded fan-out** — cap the READ (`.limit(CAP+1).get()`), refuse above
  cap, chunk-delete with a per-item `.catch` on grpc code only, never
  throw. A boolean verdict gating a destructive delete needs a fixture that
  can force it FALSE. A `rateLimitWrite(bucket, n)` rules conjunct binds
  only if some writer STAMPS `users/{uid}/rate_limits/<bucket>` — grep
  before citing one as a real bound.

## Secrets handling

`defineSecret("MY_KEY")`, never env vars in code. Never log a secret. Root
`.env` is Flutter-only.

## Test commands (from `functions/`)

- `npm run build` — must pass before any commit. `npm test` =
  `run-all-tests.js`: auto-discovers every `test:*` script. **A new
  `__tests__/*.test.ts` is invisible until its `test:*` script exists** —
  grep package.json FIRST on any new test file.
- `npm run test:rules:all` — a new `test:integration:*` suite must ALSO be
  appended to both `paths:` blocks in `firestore-rules.yml`, or it never
  runs in CI despite passing by hand.
- `scripts/run-ci-unit-tests.js` — the real CI gate. Hand-rolled harness,
  no jest — call `runTests` exactly ONCE per file.

## Logging conventions

`logger.info("event", { userId, recipeId, action })` — stable string,
structured object, no PII. **`logger.error(msg, { err })` records NO
cause** — unwraps only when passed POSITIONALLY; use `errCode`/`errName`
from `(err as {code?}).code` instead.
- **Hash ALL PII/title-derived fields consistently** — a mixed line (one
  hashed, one cleartext) is the tell. `hashUid(uid)` or `uid.slice(0,6)`.
- **A DOCUMENT ID can be PII depending on the CALLER** — a conversation id
  is a UUIDv4 for a group, `direct_${sortedUidA}_${sortedUidB}` for a DM.
  `logSafeConversationId(id)` hashes the direct spelling, leaves group
  UUIDs greppable — re-derive for every NEW caller of an id-logging helper.
- Doc-ID prefix-range sentinels need the 6-char escape, never a raw
  literal — a NUL/odd byte also makes ripgrep skip the file as binary.

## What NOT to do

- Don't deploy; don't change region without approval; no `console.log` in
  a deployed function; no trigger without an idempotency story; no
  `retry:true` without a missing-doc audit.
- Don't trust a client-controlled field for a security decision unless the
  create/update RULE pins it to `request.auth.uid`. Converse: a rules DENY
  (e.g. a CEL error on null-metadata access) can be what keeps a safety
  trigger armed against a degenerate first write — "harmonising" it with a
  sibling rule can disarm it.

---

### Completion-event telemetry (`emitTiming` family)
- Gemini/Vertex implicit caching: `usageMetadata.cachedContentTokenCount`,
  billed ~10% of input rate, clamped to `[0, promptTokenCount]`.
- Never coerce a missing telemetry field to 0 — log as-is; Cloud Logging
  drops `undefined` fields, marking "not reported" vs a real zero.
- Declare `let experimentBucket: number | undefined` BEFORE the closure on
  an early-exit function; each experiment gets its own salt. Emitter test:
  EXACTLY ONE event per call (catches try+catch double-emits).

### Test seams, emulator infra & non-vacuity
- v2 exports carry `.run(event)` — test triggers with a typed payload from
  real emulator snapshots, no firebase-functions-test needed.
- **A wrapper/gate test is non-vacuous only if breaking it produces a
  DIFFERENT result than any other failure** — the recurring failure is
  one error code from TWO branches; assert on branch-unique text. Some
  guards fire only on a SECOND invocation — give re-enterable cascade
  steps a re-run test. An unsimulated fake stub must THROW on an
  unmodelled path, not silently succeed.
- Vacuity patterns: a `?? {}` read survives the mutant that DELETES the doc
  (pair it with a sibling requiring EXISTS); a `src.includes("<field>")`
  assertion is free whenever the docstring names the field (assert the
  WRITE); a fake `listDocuments()` returning only stored docs cannot stage a
  PHANTOM parent.
- **Rules are not filters** — a client query with NO condition is DENIED
  wholesale on a member-scoped collection; only the RULES emulator lane
  proves it, and that emulator KEEPS data across runs, so give an "empty"
  fixture a uid no other test seeds.
- **A fake `commit()` that RE-DERIVES the intended effect instead of
  APPLYING the write payload makes the write vacuous** — dispatch on the
  `FieldValue` transform's `constructor.name`; reject `update()` on a
  MISSING doc with grpc 5. Mutate a SHADOW COPY, never the tracked file,
  in a live parallel-session worktree.
- **A hand-rolled Firestore fake needs `.limit()` on BOTH `collection()`
  and `collectionGroup()` queries** — the cascade's caps split across them,
  so one missing method reports a GDPR step FAILED, not skipped. Adding it
  proves nothing: an always-empty fake cannot stage the over-cap DECLINE
  (that is `account-deletion-cascade.test.ts`) — say so in its comment.
- **TS's CommonJS emit does NOT hoist an import's `require`** (measured,
  `module: node16` + ts-node): env set ABOVE an `import` IS visible to that
  module at eval, so "env must be set first, therefore `require`" is a FALSE
  justification — use `require` for explicitness, never claim necessity.
- To mutate a global option without writing a tracked file, patch
  `setGlobalOptions` in `require.cache`'s
  `firebase-functions/lib/v2/options.js` before requiring `../index`. One
  export's `__endpoint` is a live GETTER that regenerates, so tampering with
  endpoint objects in place under-counts by one.

### PII scrubbing + GDPR cascade design
- Cross-port heuristic vectors (TS↔Dart) live in one shared JSON fixture.
  JS `\b` misfires before å/ä/ö — use lookarounds; case-insensitive
  triggers need per-letter classes, not `/i`. Possessive titles are pinned
  NEGATIVE vectors — never generalize to bare capitalized-word NER.
- **PROMOTING a per-section field to the ROOT of an Art. 15 bundle changes
  its blast radius — the root value must be DERIVED, never copied** (a raw
  Firestore error string can carry another subject's uid or an internal
  path); the root guard does NOT clear the SECTION body.
- Cascade purges discover children via `rootRef.listCollections()`, never
  hard-coded names. New steps are BEST-EFFORT — a rethrow re-runs the WHOLE
  cascade, double-applying non-idempotent steps.
- **`batch.update()` on a concurrently-deleted doc fails the WHOLE chunk
  with NOT_FOUND** under `strict:false` — piggyback the existence probe on
  the SAME `getAll` as the idempotency gate; skip (never `set(merge)`) when
  absent. Where step A SKIPS and step B DELETES the same doc, an ABSENCE
  assertion can't pin the skip — record `batch.update` PATHS on the fake. A
  destructive delete driven by "not in a roster query" must guard against a
  transiently under-populated query.
- **Cross-check the identity FIELD and COLLECTION NAME across every leg**
  (deleter, export, probe, rules, Dart constant) — a wrong field or
  pre-rename name deletes NOTHING silently. Repointing a dead COLLECTION is
  half the fix: the VALUE searched for must match what the PRODUCER writes
  (a diacritics mismatch was a live silent miss). One field can have TWO
  stores (array + subcollection) — erase BOTH.
- **A parent-with-subcollection deleted by plain `doc(id).delete()` leaves
  an orphan the server cannot QUERY** — `listDocuments()` is the only
  Admin-SDK call returning refs for MISSING docs with live subcollections;
  use it on sweep AND probe, and `strict:true` for the children of a
  to-be-deleted parent (a `strict:false` sweep strands PII silently).
- A "shared" collection also holds SOLO-owner docs that must be DELETED,
  not scrubbed. Scrubbing a deleted user off a SHARED doc must enumerate
  every {uid, displayName} pair on the MODEL, array elements and the
  PARENT's per-uid maps included — a propagation CF is usually a SUBSET of
  what the client stamps; the Art. 15 export's third-party redactions are
  the cheapest enumeration source.
- **A cascade write from a query-time snapshot applied via a plain
  `.update()` is a lost-update hazard** — wrap in `runTransaction`, re-read
  fresh, skip on `!fresh.exists`. The repo's fake transaction is
  single-threaded/no-retry, so a green suite proves values, not
  concurrency-safety. A client cascade can only query a field the READ rule
  authorizes (max 10 `get()`s/query); only the Admin SDK can key an erasure
  on a field the read rule doesn't expose.
- A rules hard-deny PLUS an Admin-SDK escape hatch has TWO guards and the
  callable exempts only the first — the model's `toFirestore` coercion is
  the second, and every path running the serializer reverts the opted-in
  state silently. Enumerate the SERIALIZER's call sites, not just the
  rules' write paths, before calling an opt-in durable.
- A serial `ref.update()` loop over an embedded array: NOT_FOUND aborts the
  remaining iterations AND the full-array write is a lost update. Per-doc
  `runTransaction` fixes only the second — try/catch each, accumulate,
  throw once, then filter failed ids out of any UNCONDITIONAL write the old
  abort-early behaviour protected. Parameterize fan-out helpers by
  `CollectionReference`, never a NAME string (a name queried TOP-LEVEL when
  it is a SUBCOLLECTION updates zero docs, silently).

### Scheduled analytics & lifecycle jobs
- Don't assume a date field's type (ISO vs `Timestamp` varies by
  collection). Full-scan jobs need an explicit cap + `logger.warn`.
- Anomaly gates: `baseline≥MIN_SAMPLES` AND `stddev>0` AND `|z|>3` AND
  `|today-mean|≥ABSOLUTE_FLOOR` — without the floor, pre-launch counts
  fire constantly. A consumer job SKIPS (never assumes zero) on a missing
  producer doc. `Math.floor(elapsed/DAY)` mis-classifies the sub-day
  remainder at a boundary — compare raw elapsed ms when client/server
  must agree.
- **A daily job probing "today" only measures the hours BEFORE its own run
  time** — probe the PREVIOUS COMPLETED UTC day and derive date, query
  window, rollup offsets AND active-user cutoff from that one base.

### Fan-out pagination & denormalization (shared/batch-update.ts family)
- Self-advancing bounded loop when the mutation removes the doc from the
  base query's next match. Use the `__name__`-cursor helper ONLY when every
  write touches solely denorm fields — hard iteration cap either way.
  **"A deleted doc can't anchor a `startAfter` cursor" is FALSE** — the
  cursor is built from the snapshot LOCALLY; anchor on the last SCANNED doc
  for ORDERING, since a deleted one can sort earlier.

### GDPR account-deletion cascade
- A cascade step keyed on a shared/parent handle must destroy the retry
  handle LAST, after all child cleanup commits. Subtler form: a
  purpose-built QUERY HANDLE cleared in the SAME write as the content
  scrub, ahead of a dependent mirror — order the mirror write FIRST.
- **`probeResidualData` must not be BROADER than the deleter** — union the
  probe's queries into the deleter's scoping, dedup by doc id; prove the
  coupling by deleting one union leg and checking BOTH the targeted fixture
  AND "no failed collections" redden. A probe ERROR ADDS to the residual
  count, never aborts the cascade; a new leg dropped INSIDE an existing
  `try` silently shortens every leg after it — one try/catch each.
- Pure `users/{uid}/*` subcollections erase via a generic uid-scoped
  sweep. Test triple: own-erased + other-kept + `failedCollections` empty.
- **Data written by a SCHEDULED JOB under a non-`users/{uid}` path is
  invisible to both of the cascade's structural loops** — sweep every
  scheduled writer for uid-keyed output; a colliding subcollection name
  would arm a `fieldOverrides` TTL (COLLECTION-GROUP scoped) over the
  wrong docs. Warn-before-purge two-pass for auto-deletion: pass 1 stamps
  scheduled-at+warning, pass 2 deletes only once due, reactivation clears
  the stamp.

### Rate limiting & LLM cost gates (middleware/rate_limiter.ts)
- A two-stage gate's SHARED/cross-user side effect (global counter) goes
  LAST, so a denial only wastes the requester's own budget. A
  retry/fallback path calling an UNWRAPPED core (bypassing
  `withRateLimit`) silently skips BOTH per-user AND global caps.
- A per-ITEM token charge couples `maxTokens` to the callable's payload
  cap — must be ≥ the max batch size or a full batch is denied forever.
- **Standalone callables use `enforceRateLimit`, not bare
  `checkRateLimit`** — only the former writes the `system_events`
  `rate_limit_violation` row. Abuse/cost gates fail CLOSED on a Firestore
  error; some notification gates deliberately fail OPEN — don't
  harmonize.
- `system_events` has no TTL — every enforced callable adds an unbounded
  write-per-denial stream, and `resource-exhausted` is client-RETRYABLE.

### Pooled ratings + rating aggregation (ratings/ family)
- Recipes are USER-SCOPED — no top-level `match /recipes`. Confirm any
  server path from firestore.rules + the repository mixin.
- Unbounded collection-group folds use `.aggregate({count, average})`,
  never `.get()`; a `collectionGroup` equality query needs a
  `fieldOverrides` entry with `queryScope:"COLLECTION_GROUP"`.
- **`recipe_social_stats` is SERVER-ONLY** — `fake_cloud_firestore`
  evaluates no rules, so a green Dart test proves nothing; check
  firestore.rules by hand.
- A backfill reconstructing a value must exclude every field the erasure
  cascade deliberately RETAINS (e.g. `ownerId`) — gate on a handle the
  cascade CLEARS instead.
- A full-collection `orderBy(documentId()).limit(N)` backfill with no
  filter cannot self-advance — needs an operator-supplied `startAfter` +
  `nextCursor`; only a filter-mutating sweep may skip the cursor.

### Verify-signup-age, account callables & minor-safety triggers
- Rules can't iterate an array field for a per-member rule on GROUP-shaped
  data — needs a companion `onDocumentCreated` backstop, with the create
  RULE binding any trusted client field to `request.auth.uid`.
- **A callable that READS a doc before checking caller membership is an
  ORACLE, and its idempotent no-op branch is the leak** — collapse
  `!exists` + non-member into ONE uniform response, no count.
- A no-oracle gate DESTROYS the only symptom of a wrong collection path —
  pair it with a path-pinning test (`collectionName` on a Dart repository
  is NOT the path; check for `UserScopedFirebaseRepository`).
- **A new `onCall` export is a THREE-file change**: the function, its
  `test:*`/suite in `package.json`, and `app-check-enforcement.test.ts`'s
  classification (`ADMIN_EXEMPT` only if the handler's FIRST statement
  checks the admin claim). Deleting a callable is the same in reverse.

### TS↔Dart parity twins (canonical-pool-key.ts et al.)
- `\w`/`\b` are ASCII-only in both without the `u` flag — fold å/ä/ö→a/o
  FIRST. Module-scope `/g` regexes are stateful with `.test()`/`.exec()`
  in long-lived CF isolates. Shared word lists: compiled-in consts pinned
  by JSON-fixture parity tests on BOTH sides, never a runtime JSON load.
- A sentinel default must be ROUND-TRIP STABLE through Firestore; the
  Dart-side `DateTime`/`isUtc` half of that rule belongs to
  `firebase-backend-security` (archive, 2026-08-17).

### LLM prompts & prompts-config
- Compiled-in prompt edits are INERT while a Firestore `system/prompts`
  override doc is live — ship a matching prod-doc update with the change.
- A new prompt field must be OPTIONAL with per-field fallback, never a
  required-keys set — a new required key reverts every live override.
  Mirroring a config field touches ~5 sites — grep every test fixture, or
  a stale one flips to fallback and passes vacuously.

### Ingredient sync, allergen data & admin exports/ETL (admin/ family)
- `admin/` scripts run `main()` at import — extract pure cores for testing.
  `reset-user-data.ts`'s `subcollections` list is DOCUMENTATION ONLY —
  `deleteDocRecursive` discovers subcollections via `listCollections()`.
- Normalization parity must hold across every matching surface (sync
  stamp, server hold-gate, Dart client) — list-split regexes stay in
  lockstep across every field they're applied to.
- For export/mining scripts: verify FIELD PARITY against the writer.
  Highest-value test: a PRIVACY WHITELIST — seed adversarial PII-shaped
  fields, assert the exported key set is EXACTLY allow-listed.

### CI / test wiring / ops
- Post-deploy smoke: `firebase functions:list --json` + grep stable names
  — `deploy` exiting 0 does NOT prove functions are callable.
- **A Firestore TTL field is INERT without a policy**; a `fieldOverrides`
  entry with `"ttl": true` + `firebase deploy --only firestore:indexes`
  creates one. `--force` deletes every live override ABSENT from the
  file. Only `gcloud firestore fields ttls list` proves ACTIVE vs
  DECLARED.
- **A field stamped `expireAt`/`expiresAt` is a retention CLAIM, not
  retention — sweep ALL at once.** The field NAME must match every writer
  of the SAME target; the anchor must cover every writer of the collection
  GROUP; the TTL must exceed the READER's window. An ENUMERATED allowlist
  fails silently toward the SHORTER window when a value is left off —
  derive the expected set from the WRITER files.
- **Prove a lefthook glob by RUNNING it** (`npx lefthook validate` +
  `dump`) — `pre-commit` hides UNSTAGED changes but still sees UNTRACKED
  files.
- **Review the STAGED copy** (`git show :<path>`) when a parallel session is
  live; `MM` means the index predates the fix under review, and a first read
  after "fixes landed" can return PRE-FIX bytes. Hash with `git hash-object`,
  not `md5sum` (CRLF moves the md5, not the blob hash). Read
  `.claude/state/review-ledger.jsonl` with the **Grep tool** (Bash `grep` is
  refused by its own hook).
- **A `test:*` script naming a file git does not TRACK reddens the whole CI
  unit lane** — `run-ci-unit-tests.js` auto-discovers every `test:*` that is
  not `test:rules*`/`test:integration:*`, so a new suite's file and its
  package.json line must be staged in the SAME commit.

### When to consult the archive
Grep it when a principle here is too compressed — probe-vs-deleter
disagreements, cascade ordering, the roster-cap saga, a TTL not reaping, a
ticket's round chain, or whether a config value existed at some past date.
