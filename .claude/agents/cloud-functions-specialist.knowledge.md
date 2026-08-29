# cloud-functions-specialist — accumulated knowledge

Step 0 of every Cloud Functions task. Durable PRINCIPLES only, edited IN
PLACE; dated narrative goes to the paired `.archive.md` (append-only).
**OVER the ~25,000-char budget — every edit must retire more than it adds.**
A principle earns its place only if a future run would act DIFFERENTLY: keep
exact names/codes/thresholds, cut the story.

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
| `migrations/` | One-shot gated backfills | n/a |
| `middleware/` | Auth/validation/rate-limit | `test:rate-limiter-*` |
| `shared/` | Pure helpers, no triggers | varies |

New family → append a row.

## Region & global options

`setGlobalOptions({ region: "europe-west1", maxInstances: 3 })` in
`index.ts`, above every `export … from`. Never re-region per-function
without approval (mismatch = silent client-side "not found").
- **Global and per-function options MERGE key-by-key** (`copyIfPresent`) —
  a per-function `memory`/`timeoutSeconds`/`retry`/`secrets` inherits the
  rest and wins on collision.
- **`maxInstances` is a DEPLOY gate, not tuning.** Global 3; the two
  ingredient cascades override to 10. Unset = the v2 default 100/function,
  which blew "Total allowable CPU per project per region", surfacing as
  `Container Healthcheck failed`. `CpuAllocPerProjectRegion` = 20 vCPU
  (europe-west1); no export declares `cpu`, so a summed ceiling is
  INSTANCES read as vCPU — external measurement, not a manifest fact. The
  accounting is UNRECONCILED and the region-wide-sum model is FALSE (the
  sum exceeds the quota many times over while every service runs): never
  write a derived "N fit per deploy" number in ANY carrier, and never name
  one function as the one a batch fails on — the failing batch (run
  33043799598) held NEITHER cascade. An increase is refused
  (`NOT_ENOUGH_USAGE_HISTORY`). SEQUENCING is what is established: one
  function per `firebase deploy`, ~90s each against `timeout-minutes: 30`.
- **3 instances != 3 concurrent executions, and a LOW cap PACKS.**
  `concurrency` defaults to 80 at `cpu >= 1`. Only a LONG-LIVED,
  memory-hungry handler declares `concurrency: 1` (pinned in
  `SERIALISED_ENDPOINTS`); it is NOT deploy-neutral once it also overrides
  `maxInstances`. It trades OOM for QUEUE TIME charged against
  `isCascadeEventExpired`, which measures from `event.time` — a first
  delivery that only queued is abandoned without ever failing, and all
  events of one admin batch share one emission instant, so they race ONE
  window. Budget `maxInstances x maxEventAge / maxDuration`: a worst-case
  FLOOR, tight on neither side, so it never carries a would/would-not-abandon
  verdict. An abandoned cascade writes NO marker, so it is invisible to
  `STALE_TAG_MARKERS`, `getDeletedIngredientStats` and the Dart
  `_needsRetagging`; the only signal is a `cascade.abandoned` error log
  nothing consumes. Raise `maxInstances` (override + `ALLOWED_OVERRIDES`),
  never `concurrency`. Notification fan-out is IN-PROCESS — a cap never
  splits a batch.
- **`onUserDeleted` is the ONLY gcfv1 export** (own `.region().runWith()`,
  unreachable by `setGlobalOptions`, no instance cap) — 72 endpoints, 71
  gcfv2; exclude it from any "every function" claim.
- **Prove endpoint config, never reason about it:** `npm run
  test:deploy-manifest` imports the ENTRY POINT (the only way the global
  call runs) and asserts region + a numeric `maxInstances` on every
  `platform:"gcfv2"` endpoint, plus `concurrency === 1` on the two cascades.
  An unset v2 option is a sentinel OBJECT, not null (`== null` is FALSE) —
  check `typeof x === "number"`; on the gcfv1 export `concurrency` is plain
  `undefined`. VACUITY SURFACE is the `gcfv2` FILTER: rename `platform` and
  every assertion passes over ~0 endpoints — guard the FILTERED count, once
  per CALLER. Keep BOTH the presence check and the value pin; each misses
  the other's mutant. A by-NAME pin must FAIL on a missing export, not skip.
  A derived check whose assertion cannot flip at today's scale earns its
  place for what it PRINTS — say that, not that it guards a falsification.
- **Some gen2 exports pin their OWN region** (`moderateUpload`,
  `syncConversationLastMessage`, `purgeExpiredAuditLogs`, the `migrations/`
  backfills), so never say a global option "reaches every export". Adding an
  export falsifies every endpoint TALLY; no test guards them — strike, and
  sweep every carrier INCLUDING `.github/workflows/`, where "all 71
  functions" is already off by one. Load-bearing count ⇒ DERIVE it in a test.

## Firebase Functions v2 — what to use

- `logger` from `firebase-functions/logger`, never `console.log` (except
  `admin/` ts-node scripts, never deployed).
- **`HttpsError` thrown inside `db.runTransaction` is NOT retried** —
  `isRetryableTransactionError` switches on numeric gRPC codes and
  `HttpsError.code` is a string, so it rolls back first-attempt.

## Idempotency rules (the most bug-prone area)

Triggers retry on uncaught exception; handlers must be idempotent:
1. **Aggregate writes** → `FieldValue.increment` + an event-id guard doc
   (`processed-events/{id}`) in the same transaction.
2. **Cascade deletes** → a target already gone on retry is success.
3. **External-API calls** → derive a stable idempotency-key from the event.
4. **Sends** → write a `sent-events/{id}` guard BEFORE sending.
5. **`retry:true` needs every write safe on a MISSING doc** — `.update()`
   throws NOT_FOUND (grpc `5`), turning a drop-once into a permanent loop.
6. **Client-supplied strings in a doc path are a poison-pill surface** —
   validate non-empty, ≤1500 UTF-8 bytes, no `/`, not `.`/`..`/`/^__.*__$/`.
7. Sanitisation must never shrink the value a security gate's THRESHOLD is
   computed from. Can't be idempotent? Document why + add a guard doc.
8. **Concurrent Tier-1 cascade legs (`Promise.all`) can write the same
   collection** — grep sibling legs for writers before claiming "no
   race"; make anonymising legs NOT_FOUND-tolerant PER DOCUMENT
   (`commitInChunks(strict:false)` fails a whole chunk on one NOT_FOUND),
   and give every new sweep its own `count()` leg in `probeResidualData`.
9. A sweep cap's threat model comes from the write RULE it bounds, never
    a copied rationale — a bound's ABSENCE needs the same read
    (`hasRequiredFields` ≠ `hasOnly`). Never cite a rules LINE NUMBER in a
    comment — cite the `match` pattern or function name (it drifts).
10. A fake whose `update()` no-ops on a missing doc can't stage grpc 5 —
    give it an injectable `updateFailures: Map<path, grpcCode>`. Deleting a
    cascade LEG needs a `__tests__` grep for writers of that path.
11. **Resolve-or-create keyed on a QUERY is not idempotent.** A
    `where(...).limit(1).get()` outside the transaction lets two concurrent
    callers both see empty and both create — the "one object per key" the
    feature promises then holds only for SEQUENTIAL calls, and no fake can
    show it (single-threaded, no isolation). Derive the doc id
    deterministically from the key and `tx.create()` instead.
12. **Two triggers on ONE collection: gate the re-read on WRITE KIND** —
    never a LIST of writers, never the sibling's ADMISSION TEST. A stale
    payload lands LAST and undoes the correction: `create`-only misses the
    read-receipt update; the sibling's predicate misses a row edited OUT of
    candidacy. A CREATE gate may use the sibling's predicate only for the
    sibling's OWN marks — an unconstrained wire value has a SECOND producer,
    the client. A comment states what the trigger SEES, never what the row
    IS. Stage by REPLAYING a pre-rewrite snapshot. Full record: ADR-0009.

## Cost & cold-start

- Billed per ms × memory + per-invocation. Narrow imports. 540s is the v2
  max, but read the real value off `__endpoint`, never off a comment.
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
  `__tests__/*.test.ts` is invisible until its `test:*` script exists**, and
  `node scripts/check-test-registration.js` proves it — per FILE, so tests
  ADDED to an existing suite need no registration. A `test:*` naming an
  UNTRACKED file reddens the CI unit lane, so file + package.json line
  stage in ONE commit.
- `npm run test:rules:all` — a new rules/integration suite is FOUR
  registrations: its own `test:*` script, an append to the `&&` chain in
  `test:rules:all`, BOTH `paths:` blocks in `firestore-rules.yml`, and a
  UNIQUE bare-literal `const PROJECT_ID = "..."`. Coverage is scoped per
  project and `scripts/rules-coverage-report.js` discovers ids by REGEX, so
  the `process.env.X ?? "..."` spelling drops the suite out of the coverage
  union in silence (4 suites are out today). Miss one and the suite passes
  by hand and never guards anything in CI. `test:rules*`/`test:integration:*`
  are excluded from the unit lane by prefix, so no emulator suite reddens it.
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

## What NOT to do

- Don't trust a client-controlled field for a security decision unless the
  create/update RULE pins it to `request.auth.uid` — a PRESENCE requirement
  binds a tampered client, a CEL evaluation error only binds our own.

---

### Test seams, emulator infra & non-vacuity
- v2 exports carry `.run(event)` — test triggers with a typed payload from
  real emulator snapshots, no firebase-functions-test needed.
- **A wrapper/gate test is non-vacuous only if breaking it produces a
  DIFFERENT result than any other failure** — the recurring failure is one
  error code from TWO branches; assert on branch-unique text. Some guards
  fire only on a SECOND invocation — give re-enterable steps a re-run test.
  An unsimulated fake stub must THROW, not silently succeed.
- Vacuity patterns: a `?? {}` read survives the mutant that DELETES the doc
  (pair it with a sibling requiring EXISTS); a `src.includes("<field>")`
  assertion is free whenever the docstring names the field (assert the
  WRITE); a fake `listDocuments()` returning only stored docs cannot stage a
  PHANTOM parent. A rules test here, and a comment in `firestore.rules`, pin
  what the RULE grants and never which SCREEN reaches it — strike any
  app-reachability claim in either.
- **Rules are not filters** — a client query with NO condition is DENIED
  wholesale on a member-scoped collection; only the RULES emulator lane
  proves it, and that emulator KEEPS data across runs, so give an "empty"
  fixture a uid no other test seeds. The VERB decides which conjuncts run: a
  merge-`set` on a seeded doc is an UPDATE, and a `withSecurityRulesDisabled`
  seed evaluates none — so a create-only conjunct can never justify an
  update-path fixture's shape.
- **A fake `commit()` that RE-DERIVES the intended effect instead of
  APPLYING the write payload makes the write vacuous** — dispatch on the
  `FieldValue` transform's `constructor.name`; reject `update()` on a
  MISSING doc with grpc 5.
- **A hand-rolled Firestore fake needs `.limit()` on BOTH `collection()`
  and `collectionGroup()` queries** — the cascade's caps split across them,
  so one missing method reports a GDPR step FAILED, not skipped. An
  always-empty fake cannot stage the over-cap DECLINE. `.select()` must
  PROJECT or THROW, never pass through (a dotted path throws: flat-key
  `data()` ≠ real nested shape).
### PII scrubbing + GDPR cascade design
- **PROMOTING a per-section field to the ROOT of an Art. 15 bundle changes
  its blast radius — the root value must be DERIVED, never copied** (a raw
  Firestore error string can carry another subject's uid or an internal
  path); the root guard does NOT clear the SECTION body.
- Cascade purges discover children via `rootRef.listCollections()`, never
  hard-coded names. Steps are BEST-EFFORT — a rethrow re-runs the WHOLE
  cascade, double-applying non-idempotent ones.
- **`batch.update()` on a concurrently-deleted doc fails the WHOLE chunk
  with NOT_FOUND** under `strict:false` — piggyback the existence probe on
  the SAME `getAll` as the idempotency gate; skip (never `set(merge)`) when
  absent. Where step A SKIPS and step B DELETES the same doc, record
  `batch.update` PATHS on the fake — absence can't pin the skip.
- A cascade STEP that early-`return false`s on its own cap skips every leg
  below it; put independent legs before the decline, or they are lost for a
  reason unrelated to them.
- **Cross-check the identity FIELD and COLLECTION NAME across every leg**
  (deleter, export, probe, rules, Dart constant) — a wrong or pre-rename
  name deletes NOTHING silently, and the VALUE searched for must match what
  the PRODUCER writes. One field can have TWO stores — erase BOTH. A NEW uid
  ARRAY on an already-swept doc owes no cascade leg ONLY while every writer
  keeps it a strict SUBSET of the field the sweep queries — prove it per
  writer (`categorySeatedUserIds` ⊆ `memberIds`), else add deleter AND probe.
- **A parent-with-subcollection deleted by plain `doc(id).delete()` leaves
  an orphan the server cannot QUERY** — `listDocuments()` is the only
  Admin-SDK call returning refs for MISSING docs with live subcollections;
  use it on sweep AND probe, and `strict:true` for a to-be-deleted parent's
  children (`strict:false` strands PII silently).
- A "shared" collection also holds SOLO-owner docs that must be DELETED,
  not scrubbed. Scrubbing a deleted user off a SHARED doc must enumerate
  every {uid, displayName} pair on the MODEL — array elements and the
  PARENT's per-uid maps included.
- **A cascade write from a query-time snapshot applied via a plain
  `.update()` is a lost-update hazard** — wrap in `runTransaction`, re-read
  fresh, skip on `!fresh.exists`. The repo's fake transaction is
  single-threaded/no-retry, so a green suite proves values, not
  concurrency-safety. Only the Admin SDK can key an erasure on a field the
  read rule doesn't expose.
- A rules hard-deny PLUS an Admin-SDK escape hatch has TWO guards and the
  callable exempts only the first — the model's `toFirestore` coercion is
  the second. Enumerate the SERIALIZER's call sites, not just the rules'
  write paths, before calling an opt-in durable.
- A serial `ref.update()` loop over an embedded array: NOT_FOUND aborts the
  remaining iterations AND the full-array write is a lost update. Per-doc
  `runTransaction` fixes only the second — try/catch each, throw once, then
  filter failed ids out of any UNCONDITIONAL write the old abort-early
  behaviour protected. Parameterize fan-out helpers by `CollectionReference`,
  never a NAME string (a top-level query against a SUBCOLLECTION name
  updates zero docs).

### Scheduled analytics & lifecycle jobs
- Don't assume a date field's type (ISO vs `Timestamp` varies by collection).
- Anomaly gates: `baseline≥MIN_SAMPLES` AND `stddev>0` AND `|z|>3` AND
  `|today-mean|≥ABSOLUTE_FLOOR` — without the floor, pre-launch counts fire
  constantly. A consumer job SKIPS (never assumes zero) on a missing producer
  doc. `Math.floor(elapsed/DAY)` mis-classifies the sub-day remainder —
  compare raw elapsed ms when client/server must agree.
- **A daily job probing "today" only measures the hours BEFORE its own run
  time** — probe the PREVIOUS COMPLETED UTC day and derive date, query
  window, rollup offsets AND active-user cutoff from that one base.

### GDPR account-deletion cascade
- A cascade step keyed on a shared/parent handle must destroy the retry
  handle LAST, after all child cleanup commits. Subtler form: a
  purpose-built QUERY HANDLE cleared in the SAME write as the content
  scrub, ahead of a dependent mirror — order the mirror write FIRST.
- **`probeResidualData` must not be BROADER than the deleter** — union the
  probe's queries into the deleter's scoping, dedup by doc id; prove the
  coupling by DELETING the leg and checking BOTH the targeted fixture AND
  "no failed collections" redden. A leg with no DIRTY-fixture scenario is
  mutation-invisible, and since `batchDeleteAll(strict:false)` swallows a
  whole failed chunk the probe is the ONLY contradiction to a deleter's
  unconditional `return true` — leg and scenario ship in one edit. A probe
  ERROR ADDS to residual (a sentinel, never a count), never aborts; one
  try/catch per leg. Hoist any parent/collection LIST the deleter and probe
  both hardcode into one exported const. A "the N siblings" completeness
  numeral in a cascade docstring is a GDPR claim — strike it. Read
  `fieldOverrides[].ttl` AND an `expireAt` writer before a retention
  sentence; grep every collection of a NAME before a "no collectionGroup id
  collision" claim (`events` collides with `recipe_cook_events/{uid}/events`,
  as `users` does with profiles); never say WHY an earlier ticket left a
  collection out — its record shows SCOPE, not intent.
- Pure `users/{uid}/*` subcollections erase via a generic uid-scoped
  sweep. Test triple: own-erased + other-kept + `failedCollections` empty.
- **Data written by a SCHEDULED JOB under a non-`users/{uid}` path is
  invisible to both of the cascade's structural loops** — sweep every
  scheduled writer for uid-keyed output; a colliding subcollection name
  would arm a `fieldOverrides` TTL (COLLECTION-GROUP scoped) over the
  wrong docs. Warn-before-purge two-pass: pass 1 stamps scheduled-at, pass 2
  deletes only once due, reactivation clears the stamp.

### Rate limiting & LLM cost gates (middleware/rate_limiter.ts)
- A two-stage gate's SHARED/cross-user side effect (global counter) goes
  LAST, so a denial only wastes the requester's own budget. A
  retry/fallback path calling an UNWRAPPED core (bypassing
  `withRateLimit`) silently skips BOTH per-user AND global caps.
- **Only `enforceRateLimit` writes the `system_events`
  `rate_limit_violation` row** — bare `checkRateLimit` + a local throw does
  not, and the four `groups/` callables plus `sendNotification` take the bare
  form, so a chat-group abuse loop leaves no audit trail. A new `groups/`
  callable copying its siblings is CONSISTENT, not correct. Abuse/cost gates
  fail CLOSED on a Firestore error; some notification gates deliberately fail
  OPEN — don't harmonize.
- `system_events` has no TTL — every enforced callable adds an unbounded
  write-per-denial stream, and `resource-exhausted` is client-RETRYABLE.

### Pooled ratings + rating aggregation (ratings/ family)
- Recipes are USER-SCOPED (no top-level `match /recipes`) and
  `recipe_social_stats` is SERVER-ONLY — confirm any server path from
  firestore.rules + the repository mixin, never from a green Dart test
  (`fake_cloud_firestore` evaluates no rules).
- Unbounded collection-group folds use `.aggregate({count, average})`,
  never `.get()`; a `collectionGroup` equality query needs a
  `fieldOverrides` entry with `queryScope:"COLLECTION_GROUP"`.
- A full-collection `orderBy(documentId()).limit(N)` backfill with no
  filter cannot self-advance — needs an operator-supplied `startAfter` +
  `nextCursor`; only a filter-mutating sweep may skip the cursor.

### Verify-signup-age, account callables & minor-safety triggers
- Rules can't iterate an array for a per-member rule on GROUP-shaped data —
  the check lives in the CALLABLES (`groups/minor-membership-gate.ts`),
  backstopped by `enforceGroupMinorMembership`, `onDocumentWritten` on
  `chat_groups/{groupId}`. NO trigger watches `conversations/{id}`, so "a
  conversation create disarms child safety" is stale.
- **A callable that READS a doc before checking caller membership is an
  ORACLE, and its idempotent no-op branch is the leak** — collapse
  `!exists` + non-member into ONE uniform response, no count.
- A no-oracle gate DESTROYS the only symptom of a wrong collection path —
  pair it with a path-pinning test (`collectionName` on a Dart repository
  is NOT the path; check for `UserScopedFirebaseRepository`).
- **A client-chosen document id is not unique across accounts.** A
  server-side pointer to one (`friend_categories/{uuid}`) must be keyed on
  OWNER + id, or an ex-member re-creating that id under their own uid is
  handed the victim's object. Do NOT then exempt that owner from the
  object's own membership check — an owner who left still drives its roster
  and can empty it, leaving a `chat_groups` doc no client can touch.
- **A new `onCall` export is a THREE-file change**: the function, its
  `test:*`/suite in `package.json`, and `app-check-enforcement.test.ts`'s
  classification (`ADMIN_EXEMPT` only if the handler's FIRST statement
  checks the admin claim); a deletion is the same in reverse.

### TS↔Dart parity twins (canonical-pool-key.ts et al.)
- `\w`/`\b` are ASCII-only in both without the `u` flag — fold å/ä/ö→a/o
  FIRST, or use lookarounds; case-insensitive triggers need per-letter
  classes, not `/i`. Module-scope `/g` regexes are stateful with
  `.test()`/`.exec()` in long-lived CF isolates. Shared word lists and
  cross-port VECTORS: compiled-in consts or one shared JSON fixture, pinned
  by parity tests on BOTH sides, never a runtime load. Possessive titles are
  pinned NEGATIVE vectors — never generalize to capitalized-word NER; a
  sentinel default must be ROUND-TRIP STABLE through Firestore.

### LLM prompts & prompts-config
- Compiled-in prompt edits are INERT while a Firestore `system/prompts`
  override doc is live — ship a matching prod-doc update with the change.
- A new prompt field must be OPTIONAL with per-field fallback, never a
  required-keys set — a new required key reverts every live override. When
  mirroring a config field, grep every test fixture, or a stale one flips
  to fallback and passes vacuously.

### Ingredient sync, allergen data & admin exports/ETL (admin/ family)
- `admin/` scripts run `main()` at import — extract pure cores for testing.
- Normalization parity must hold across every matching surface (sync stamp,
  server hold-gate, Dart client); list-split regexes stay in lockstep across
  every field.
- For export/mining scripts: verify FIELD PARITY against the writer. Best
  test: a PRIVACY WHITELIST — seed adversarial PII-shaped fields, assert the
  exported key set is EXACTLY allow-listed.

### CI / test wiring / ops
- Post-deploy smoke: `firebase functions:list --json` + grep stable names —
  `deploy` exiting 0 does NOT prove functions are callable, and a run
  concluding `failure` does NOT prove the DEPLOY step failed (the smoke gate
  is a later step). **"Setting X fixed/helped the deploy" is a claim about a
  RUN**: read conclusions from `gh run list --workflow=`, then
  `git show <headSha>:<file>` PER RUN to prove the value under test was even
  committed — an uncommitted change has deployed nothing.
- **A workflow step whose `if:` names only a step OUTCOME is DEAD after a
  failure** — GitHub ANDs an implicit `success()` unless the expression
  holds a status function, so `deploy-firebase.yml`'s auto-rollback ran on
  neither failing run. Write `always() && (...)`; never cite a
  failure-handler as a safety net without a run where it fired.
- **Count `Could not create or update Cloud Run service <name>` lines, not
  the CLI's closing `Failed to update function` summary** — 52 quota-failed
  while the summary named 2, and that reading wrote off 50 real broken
  revisions as a reporting artifact.
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
- **Review the STAGED copy** (`git show :<path>`) when a parallel session is
  live; `MM` means the index predates the fix under review, and a first read
  after "fixes landed" can return PRE-FIX bytes. Hash with `git hash-object`,
  not `md5sum` (CRLF moves the md5, not the blob hash). Read
  `.claude/state/review-ledger.jsonl` with the **Grep tool** (Bash `grep` is
  refused by its own hook).
