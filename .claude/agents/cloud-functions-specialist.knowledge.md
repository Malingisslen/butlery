# cloud-functions-specialist — accumulated knowledge

Step 0 of every Cloud Functions task. Durable PRINCIPLES only, edited IN PLACE;
dated narrative goes to the paired `.archive.md`. Keep exact
names/codes/thresholds, cut the story.
**OVER the ~25,000-char budget — every edit must retire more than it adds.**

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
- **Prove endpoint config, never reason about it:** `npm run
  test:deploy-manifest` imports the ENTRY POINT (the only way the global call
  runs), pinning region, numeric `maxInstances` and the cascades'
  `concurrency === 1`. An unset v2 option is a sentinel OBJECT, not null
  (`== null` is FALSE) — check `typeof x === "number"`. Vacuity is in the
  `gcfv2` FILTER: guard the filtered COUNT per caller, keep presence AND value
  pins, and make a by-NAME pin fail rather than skip on a missing export.
- **No global option reaches EVERY export, and never TALLY endpoints.**
  `onUserDeleted` is gcfv1 (own `.region().runWith()`) and others pin their own
  region — grep `\.region(|region: "` and exclude every hit from an "every
  function" claim, rather than trusting a roster written here.
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
### PII scrubbing + GDPR cascade design
- **A server write leaving a doc unable to satisfy its own UPDATE limb BRICKS a
  DETERMINISTIC doc id** (`{groupId}_{ISO week}`). Two forms: emptying
  `memberPermissions` (a client `set()` is an UPDATE and every limb gates on
  that map), and — since the Admin SDK bypasses rules — `arrayUnion`ing past a
  rules cap (`contributorUserIds` 200), which freezes the doc
  for every client. Delete the doc, or prune/skip at the cap; before revoking
  the last holder, name what re-creates the id.
- A step's throw is CAUGHT by `runStep` → `failedCollections` +
  `gdprCompliant:false`; no automatic retry, recovery is a human. So a step that
  DECIDES something the later steps read (a lawful hold) reports its failure by
  RETURNING false with the decision intact, never by throwing — a throw skips the
  caller's assignment and the destructive steps then run on the default.
- **`batch.update()` on a concurrently-deleted doc fails the WHOLE chunk with
  NOT_FOUND** under `strict:false`; and `commitInChunks` calls `mutate` OUTSIDE
  that try, so a SYNCHRONOUS validation throw from the callback (`undefined` in
  an array, bad FieldValue) escapes `strict:false` and aborts the step —
  piggyback the existence probe on the SAME `getAll` as the idempotency gate;
  skip (never `set(merge)`) when absent. `strict` DEFAULTS to false. A step that
  DELETES and UPDATES one collection: await the deletes, then RE-QUERY — the
  re-query is what removes the NOT_FOUND, so a doc-id dedupe across the two
  halves is dead defence, and rule 10's fake shows neither.
- A step that early-`return false`s on its own cap skips every leg below it —
  put independent legs first.
- **Cross-check the identity FIELD and COLLECTION NAME across every leg**
  (deleter, export, probe, rules, Dart constant) — a wrong or pre-rename name
  deletes NOTHING silently, and the VALUE searched for must match what the
  PRODUCER writes. A DEAD SPELLING has no writer, so no source scan and no TTL
  reach it (a policy keys an EXACT id) — sweep BOTH names, only a prod dry run
  finds one, and the legacy inherits the live Art. 15 exemption by CITATION.
  One field can have TWO stores — erase BOTH. A NEW uid
  ARRAY on an already-swept doc owes no cascade leg ONLY while every writer
  keeps it a strict SUBSET of the swept field (`categorySeatedUserIds` ⊆
  `memberIds`) — prove it per writer, else add deleter AND probe.
- **A parent deleted by plain `doc(id).delete()` leaves subcollection orphans
  no PARENT-KEYED read can reach** — `listDocuments()` is the only Admin-SDK call
  returning refs for MISSING docs with live children (a `count()` reports ZERO);
  use it on sweep AND probe, and `strict:true` for a doomed parent's children.
  The CHILDREN stay reachable: a `collectionGroup` query on the row's OWN field,
  path-scoped via `ref.parent.parent`, returns them whatever happened to the
  parent — so "orphaned = unerasable forever" is FALSE for such a leg, however
  true it is for every CLIENT. Never write it without naming which reader.
  So a step destroys its parent/shared HANDLE LAST, after every child commit —
  including a QUERY HANDLE cleared in the same write as the scrub, ahead of a
  dependent mirror.
- **A server-written PROJECTION of a client collection (`block_mirror` of
  `blocks`) owes**: an existence check on the SUBJECT the constrained user cannot
  forge — `users/{uid}` is owner-DELETABLE, so ask `admin.auth().getUser`, OUTSIDE
  the transaction (Auth is not transactional), answering `auth/user-not-found` and
  `auth/invalid-uid` as "gone", rethrowing every other code; a DELETE of an
  orphan (a late rebuild re-creates the erased uid's doc post-probe; Auth
  deletion is the cascade's LAST step); a cross-user sweep that STAMPS the
  revision guard (`arrayRemove` leaves it untouched, so an older in-flight
  rebuild wins); a run AFTER the source tier; and a CAP flag unread by the
  consuming gate under-enforces on input OTHERS choose (`.limit(cap+1)` with no
  `orderBy` keeps the lowest doc ids, so sockpuppets sort a real entry off the
  end). Trigger + reconcile NARROWS the window, never closes it;
  a task LAST in `WEEKLY_REPORT_TASKS` is what `runTaskChain` SKIPS first, and a
  TIMEOUT aborts the chain at ANY index — so a safety sweep needs its own
  wall-clock budget, not just a row cap.
- **A compare-before-repair reconciliation resolves EXISTENCE once per uid ABOVE
  every branch, and counts a DELETE as drift on every branch.** `stored == expected`
  never settles orphanhood (an EMPTY orphan matches an empty expectation), and the
  existence seam must not be reached THROUGH the repair call.
- A "shared" collection also holds SOLO-owner docs to DELETE, not scrub. A scrub
  enumerates every uid in the MODEL's `toFirestore`: array elements, per-uid map
  keys, AND attribution scalars (`lastModifiedBy`, `lastEditedBy`).
  **DISCOVER those rows by collectionGroup query PER UID FIELD, never by current
  MEMBERSHIP** — `removeMember` drops `members/{uid}` AND `arrayRemove`s the
  roster in one call, so a departed member is invisible to both handles while the
  name stays. Check `firestore.indexes.json` first: the COLLECTION_GROUP
  overrides may already exist for a rename propagator. PATH-scope each row
  (`parent.id === X && parent.parent === null`, BOTH limbs) where a sibling path
  shares the group id, and scope BEFORE counting against a cap.
- A rules hard-deny plus an Admin-SDK escape hatch has TWO guards: the callable
  exempts only the first; the model's `toFirestore` coercion is the second.
  Enumerate the SERIALIZER's call sites, not just the rules' writes.
- **Any write derived from an EARLIER read is a lost update** — a query-time
  snapshot via plain `.update()`, or a serial `ref.update()` loop over an embedded
  array, where NOT_FOUND also aborts the remaining iterations. Per-doc
  `runTransaction` + re-read fixes only the lost update: skip on `!fresh.exists`,
  try/catch each, throw once, filter failed ids out of any UNCONDITIONAL write the
  abort protected. Fan-out helpers take a `CollectionReference`, never a NAME.
- **A chunked migration walks by OFFSET, never by re-reading what is left** —
  full rule in `lessons-digest.md` (BUT-2046): per-pass counters are ASSIGNMENTS
  inside the transaction, clear the source only on a pass ending with zero
  failures anywhere, ≤400 rows/pass.

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

### GDPR account-deletion cascade
- **A probe leg whose ONLY deleter lives in `onUserDeleted` is broader by TIMING.**
  `probeResidualData` runs BEFORE `auth.deleteUser` (the cascade's last step) and
  `success = authDeleted && !failedCollections.length`, so such a leg returns
  `success:false` + `gdprCompliant:false` on every affected account while the row
  IS erased seconds later. `TRIGGER_OWNED_SUBCOLLECTIONS` is that exclusion;
  `social_requests` is deliberately unprobed. Probe only what a CASCADE step
  erases — cross-user is no reason to leave the deleter in the trigger
  (`deleteBlocks` erases rows other users authored, from tier 1).
- **`probeResidualData` must not be BROADER than the deleter, and the deleter
  must not be NARROWER than the EXPORT's predicate** — Art. 15 must never reach
  a document Art. 17 cannot (`memberPermissions.<uid> != null` = Dart
  `isNull:false`). Union the probe's queries into the deleter's scoping, dedup
  by `doc.ref.path`. A LAWFUL-HOLD exception narrows the deleter on purpose:
  every field it then KEEPS must be spread out of the probe by the SAME flag —
  one decision in two lists, keyed on the retained record's `resourceType`, never
  on `retained.length` — or each held erasure reports `gdprCompliant:false`
  forever with no path able to clear it. A leg on an
  ATTRIBUTION SCALAR (`lastModifiedBy`, `ownerId`) is broader unless
  `firestore.rules` PINS that field to the roster the deleter discovers by —
  read the write limb, never the app's own writer; unpinned, any editor plants
  a stranger's uid and that user's deletions report `gdprCompliant:false`
  forever.
  GATE any empty-roster DELETE on the uid having been ON that roster AND on EVERY
  denormalised roster being empty, EACH READ RAW (a DERIVED witness or `.select()`
  projection collapses it); witnesses are ROSTERS (readers) only, never a discovery
  handle (`contributorUserIds`). Binds EVERY server writer that can empty a roster;
  its NON-delete branch rewrites projections PER KEY and drops the whole-field key.
  A leg with no DIRTY fixture is mutation-invisible and `strict:false` swallows
  a failed chunk, so the probe is the ONLY contradiction to `return true` — leg
  and scenario ship in one edit, and DELETING the leg must redden BOTH the
  targeted fixture and "no failed collections". A probe ERROR ADDS to residual (a sentinel,
  never a count), never aborts; one try/catch per leg.
- **An ENUMERATING probe (`rootRef.listCollections()`) is BROADER than the
  deleter by construction** — any user subcollection no step erases reports
  `gdprCompliant:false` forever.
  Ship it only with a DERIVED drift test: regex every
  `.collection(users).doc(..).collection("X")` writer across `functions/src` +
  `lib`, spelling the users token `\w*[Uu]sers\w*` (`[A-Za-z_]\w*` misses the bare
  `FirestoreCollections.users` every Dart repo writes);
  `db.doc("users/${uid}/X/y")` strings are still missed. Bucket each name into the
  EXPORTED `USER_SUBCOLLECTIONS` or `TRIGGER_OWNED_SUBCOLLECTIONS` — IMPORT them,
  never parse the cascade as text — or into a map whose every entry is EXERCISED
  (seed, run the named deleter, assert gone). A deleter removing ONE DOC BY ID is NOT a deleter for the
  COLLECTION the probe counts. Every fake doc-ref then needs `listCollections()`
  derived from stored deeper paths, never `[]` — absent, the outer catch fails
  CLOSED and every CLEAN fixture reddens.
- **EXPORT ⊇ DELETION is the cascade's other drift guard**: every source-parsed
  `subs` name is either read by an export chain or in a reasoned exemption map
  kept in PRODUCTION source, not the test. That map is PERMANENT — re-check each "no live writer"
  exemption against the writer scan; one reasoned from another export SECTION dies
  with it, so re-argue it in the removing commit and supersede every
  decision-record sentence it falsifies. Name each withheld collection in a
  `data_minimisation` line, verifying WHICH line, or the gap is undisclosed
  (Art. 12(1)).
- **Scope limits what you CHANGE, not what you may READ.** Whether a TS comment's
  "live"/"unused" claim holds is often decided by the Dart WRITER one file away
  ("maintained by nothing" != "not live"). Open it before calling a referent
  unsettleable.
- **A SCHEDULED JOB writing uid-keyed rows under a non-`users/{uid}` path is
  invisible to both of the cascade's structural loops** (e.g.
  `analytics/notifications/effectiveness`) — give each its own probe leg; a
  colliding subcollection name arms a `fieldOverrides` TTL (COLLECTION-GROUP
  scoped) over the wrong docs. Such a job can flush IN-MEMORY pages back AFTER
  the sweep, so pin the leg with a RESURRECTION scenario, never by mirroring
  the deleter.

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
- **`rateLimitWrite(bucket, s)` is INERT unless a client writes
  `users/{uid}/rate_limits/<bucket>`** — grep the Dart writers per bucket before
  citing it as a control; several rules name buckets nothing writes.
- `system_events` has no TTL — every enforced callable adds an unbounded
  write-per-denial stream, and `resource-exhausted` is client-RETRYABLE.

### Pooled ratings + rating aggregation (ratings/ family)
- Unbounded collection-group folds use `.aggregate({count, average})`, never
  `.get()`; ANY filtered `collectionGroup` query — equality or
  `array-contains` — needs a `fieldOverrides` entry with
  `queryScope:"COLLECTION_GROUP"` in `firestore.indexes.json`, staged in the
  SAME commit (precedent: `participants/participantId`) — missing, a cascade leg
  throws FAILED_PRECONDITION on every real erasure while the fake stays green.
  COLLECTION-scoped equality needs none unless `fieldOverrides` EXEMPTS the
  field — check exemptions, not `indexes`.

### Verify-signup-age, account callables & minor-safety triggers
- **A cleanup helper writing an ATTRIBUTION row takes the ACTOR as an argument,
  and a no-tombstone rule binds every CONSTANT it writes.** Deriving the actor
  from the SUBJECT misnames an eviction; a SENTINEL marks that eviction as well
  as a tombstone would, correlated with the uid removed in the same write. For a
  TRIGGER caller the answer is a NULLABLE actor and NO row, never a nicer
  sentinel — a non-uid also sticks permanently in any append-only uid array the
  client derives from that row. Pin the CALL SITE: testing the shared function
  leaves deleting the call green.
- **A callable that READS a doc before checking caller membership is an ORACLE,
  and its idempotent no-op branch is the leak** — collapse `!exists` +
  non-member into ONE uniform response.
- **A client-chosen document id is not unique across accounts.** A
  server-side pointer to one (`friend_categories/{uuid}`) must be keyed on
  OWNER + id, or an ex-member re-creating that id under their own uid is
  handed the victim's object. Do not then exempt that owner from the
  membership check — an owner who left could otherwise empty its roster.
- **A new `onCall` export is a THREE-file change**: the function, its
  `test:*`/suite in `package.json`, and `app-check-enforcement.test.ts`'s
  classification (`ADMIN_EXEMPT` only if the handler's FIRST statement
  checks the admin claim); a deletion is the same in reverse.

### TS↔Dart parity twins (canonical-pool-key.ts et al.)
- Case-insensitive triggers need per-letter classes, not `/i`. Module-scope
  `/g` regexes are stateful with `.test()`/`.exec()` in long-lived isolates.
  Shared word lists and cross-port VECTORS: compiled-in consts or one shared
  JSON fixture, pinned on BOTH sides, never a runtime load.

### LLM prompts & prompts-config
- Compiled-in prompt edits are INERT while a Firestore `system/prompts`
  override doc is live — ship a matching prod-doc update. A new prompt field
  must be OPTIONAL with per-field fallback (a required-keys set reverts every
  live override), and mirroring a config field means grepping every test
  fixture, or a stale one flips to fallback and passes vacuously.

### Ingredient sync, allergen data & admin exports/ETL (admin/ family)
- `admin/` scripts run `main()` at import — extract pure cores to test.
- **A hand-run script's delete/keep OVERLAP guard no-ops the WHOLE script in
  silence** (`reset-user-data.ts`); repairing it removes the header's only
  enforcement, so the durable barrier is a HUMAN step nothing can pre-satisfy: a
  typed `CONFIRMATION_PHRASE`, `!dryRun`-scoped, above the first `runPhases(`
  (`admin-init.ts` hardcodes prod). Its Auth-wipe phase fires
  `onUserDeleted`, which writes into collections Phase 2 is concurrently deleting.
- **A run-time REPORT of "what no list decides" reads EVERY register the deleters
  use** (one erased by its OWN tier step — `pantry` — is in no list and fires on
  every account), never steers the run, and never says
  what an appearing name MEANS: trigger-owned rows come from ordinary app use.
- **Moving a collection to `COLLECTIONS_TO_KEEP` only half-decides it.** Its
  SUBCOLLECTIONS need a fail-closed allowlist, and a subcollection-level prune
  leaves PARENT-DOCUMENT FIELDS behind — measure them in the verification pass
  rather than promising them in a comment. A kept-collection existence probe
  (`.limit(1).get()`) reports "empty" for a collection whose parents hold only
  subcollections; `listDocuments()` answers, and bills one read per document. A
  `dryRun` flag on a helper that DELEGATES deletion is inert unless the helper
  reads it — delete it.
- **A source pin owes**: a grep-UNIQUE anchor; the guard's EFFECT, not its position
  (`process.exit(0|1)` INSIDE the gate); `//`-stripping, which stops NEITHER
  `&& false` NOR a `/* */` wrap; and the INVOKER, its literal DERIVED from the
  declaration, anchored `/^const NAME = "([^"]+)"/m` (`String.match` takes the
  FIRST hit — an unstripped `/** */` quoting it wins).
- **A "wipes all" claim needs TWO sources, never a number**: `firestore.rules`
  top-level `match` blocks (blind to server-only) UNION a `functions/src` scan
  resolving `Collections.X`, `(export )?const N = "…"` PER FILE (an IMPORTED name
  must stay unresolved), `collectionGroup(…)`, and doc paths in BOTH quote and
  backtick form. ONE anchor per branch, on a name only THAT branch finds and
  something writes; the mutant must COMPILE (TS6133 is not a red test).
- **A skip register's reason is a MEASURED claim about EVERY writer** — it authorises
  retention, and rules are not evidence (the Admin SDK bypasses them): `system_events`
  read clean in two writers while a third wrote raw uids in a doc id and a field.
- Normalization parity must hold across every matching surface (sync stamp,
  server hold-gate, Dart client); list-split regexes stay in lockstep.
- Export/mining: verify FIELD PARITY against the writer. Best test is a
  PRIVACY WHITELIST — seed adversarial PII-shaped fields, assert the exported
  key set is EXACTLY allow-listed.

### CI / test wiring / ops
- Post-deploy smoke: `firebase functions:list --json` + grep stable names.
  `deploy` exiting 0 does not prove callability; a run concluding `failure`
  does not prove the DEPLOY step failed.
- **A step whose `if:` names only a step OUTCOME is DEAD after a failure** —
  GitHub ANDs an implicit `success()`. Write `always() && (...)`.
- **A guard READING files outside `functions/src` is asleep unless the workflow
  `paths:` reach them** — derive the list from what the guard OPENS and assert
  it against BOTH the `push` and `pull_request` blocks; fixing one is the
  half-miss. A hand-rolled `paths:` parser fails CLOSED. Assert PER GUARD — a
  sibling scenario's derived assertion covers only ITS inputs — and reach the
  ORCHESTRATOR assembling the output, not just the helper directory. Two guards
  in two languages must never cite EACH OTHER for a case neither covers: a
  TEXT scan sees the token, the behavioural test sees named keys, and a rename
  escapes both — name the residual, never describe it as covered.
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
