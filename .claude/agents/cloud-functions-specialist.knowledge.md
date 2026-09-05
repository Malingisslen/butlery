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
  queued-only delivery is abandoned without failing and writes NO marker, so every
  marker-based diagnostic reads clean. Raise `maxInstances`, never `concurrency`. Notification
  fan-out is IN-PROCESS — a cap never splits a batch.
- **`onUserDeleted` is the ONLY gcfv1 export** (own `.region().runWith()`,
  unreachable by `setGlobalOptions`) — exclude it from "every function" claims.
- **Prove endpoint config, never reason about it:** `npm run
  test:deploy-manifest` imports the ENTRY POINT (the only way the global call
  runs), pinning region, numeric `maxInstances` and the cascades'
  `concurrency === 1`. An unset v2 option is a sentinel OBJECT, not null
  (`== null` is FALSE) — check `typeof x === "number"`. Vacuity is in the
  `gcfv2` FILTER: guard the filtered COUNT per caller, keep presence AND value
  pins, and make a by-NAME pin fail rather than skip on a missing export.
- **Some gen2 exports pin their OWN region** (`moderateUpload`,
  `syncConversationLastMessage`, `purgeExpiredAuditLogs`, `migrations/`), so
  never say a global option "reaches every export", and never TALLY endpoints.
- **A trigger or `onSchedule` NOT re-exported from `index.ts` is DEAD** — it
  compiles, its unit tests pass, and nothing deploys, so every comment calling
  it a safety net is false. New periodic work is a `MaintenanceTask` in
  `WEEKLY_REPORT_TASKS`/`DAILY_ANALYTICS_TASKS` (Scheduler bills per JOB, 3 free
  per billing account), never a new `onSchedule`; a standalone one also needs
  its own `timeoutSeconds` (else the v2 60s default) and must sit BELOW
  `setGlobalOptions` in `index.ts`.

## Firebase Functions v2 — what to use

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
   and give every new sweep its own leg in `probeResidualData` — it has
   top-level-FIELD, `users/{uid}`-ENUMERATION and collectionGroup shapes, so
   "the probe cannot see this collection" is never true and never a reason to
   skip one. `strict:false` is why it matters: the deleter reports `true` over
   a chunk it never committed.
9. A sweep cap's threat model comes from the write RULE it bounds, never a
    copied rationale — a bound's ABSENCE needs the same read. Never cite a rules
    LINE NUMBER.
10. A fake whose `update()` no-ops on a missing doc can't stage grpc 5 —
    give it an injectable `updateFailures: Map<path, grpcCode>`. Deleting a
    cascade LEG needs a `__tests__` grep for writers of that path.
11. **Resolve-or-create keyed on a QUERY is not idempotent.** A
    `where(...).limit(1).get()` outside the transaction lets two concurrent
    callers both create, and no fake can show it (single-threaded). Derive
    the doc id deterministically from the key and `tx.create()` instead.
12. **Two triggers on ONE collection: gate the re-read on WRITE KIND** — never
    a LIST of writers, never the sibling's ADMISSION TEST (`create`-only misses
    the read-receipt update; the predicate misses a row edited OUT of
    candidacy). Stage by REPLAYING a pre-rewrite snapshot. Record: ADR-0009.

## Cost & cold-start

- Billed per ms × memory + per-invocation. Narrow imports. 540s is the v2 max;
  read the real value off `__endpoint`.
- **An in-code timeout guard is dead unless `timeoutSeconds` is declared on the
  SAME trigger** — global options carry no timeout, so a v2 event function
  defaults to 60s. Pin guard-ms against the manifest's
  `__endpoint.timeoutSeconds`; a constant-vs-constant test stays green after
  the declaration is deleted.
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
  **bare-literal** `const PROJECT_ID = "..."` (`rules-coverage-report.js`
  discovers ids by regex, so an env-defaulted const silently drops the suite from
  the coverage union — put any probe override at the `projectId:` CALL SITE).
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
- **A fake `commit()` that RE-DERIVES the intended effect instead of
  APPLYING the write payload makes the write vacuous** — dispatch on the
  `FieldValue` transform's `constructor.name`; reject `update()` on a
  MISSING doc with grpc 5.
- **A hand-rolled Firestore fake needs `.limit()` on BOTH `collection()` and
  `collectionGroup()`** — the caps split across them, so one missing method
  reports a GDPR step FAILED, not skipped, and an always-empty fake cannot
  stage the over-cap DECLINE. `.select()` must PROJECT or THROW, never pass
  through (flat-key `data()` ≠ real nested shape).
### PII scrubbing + GDPR cascade design
- **A server write leaving a doc unable to satisfy its own UPDATE limb BRICKS a
  DETERMINISTIC doc id** (`{groupId}_{ISO week}`). Two forms: emptying
  `memberPermissions` (a client `set()` is an UPDATE and every limb gates on
  that map), and — since the Admin SDK bypasses rules — `arrayUnion`ing past a
  rules cap (`contributorUserIds` 200), which freezes the doc
  for every client. Delete the doc, or prune/skip at the cap; before revoking
  the last holder, name what re-creates the id.
- A step's throw is CAUGHT by `runStep` → `failedCollections` +
  `gdprCompliant:false`, never an automatic retry; recovery is a human.
- **`batch.update()` on a concurrently-deleted doc fails the WHOLE chunk with
  NOT_FOUND** under `strict:false`; and `commitInChunks` calls `mutate` OUTSIDE
  that try, so a SYNCHRONOUS validation throw from the callback (`undefined` in
  an array, bad FieldValue) escapes `strict:false` and aborts the whole step —
  piggyback the existence probe on the SAME `getAll` as the idempotency gate;
  skip (never `set(merge)`) when absent.
- A step that early-`return false`s on its own cap skips every leg below it —
  put independent legs first.
- **Cross-check the identity FIELD and COLLECTION NAME across every leg**
  (deleter, export, probe, rules, Dart constant) — a wrong or pre-rename name
  deletes NOTHING silently, and the VALUE searched for must match what the
  PRODUCER writes. One field can have TWO stores — erase BOTH. A NEW uid
  ARRAY on an already-swept doc owes no cascade leg ONLY while every writer
  keeps it a strict SUBSET of the swept field (`categorySeatedUserIds` ⊆
  `memberIds`) — prove it per writer, else add deleter AND probe.
- **A parent deleted by plain `doc(id).delete()` leaves subcollection orphans
  the server cannot QUERY** — `listDocuments()` is the only Admin-SDK call
  returning refs for MISSING docs with live children (a `count()` reports ZERO);
  use it on sweep AND probe, and `strict:true` for a doomed parent's children.
- **A server-written PROJECTION of a client collection (`block_mirror` of
  `blocks`) owes**: an existence check on the SUBJECT the constrained user cannot
  forge — `users/{uid}` is owner-DELETABLE, so ask `admin.auth().getUser`, OUTSIDE
  the transaction (Auth is not transactional), answering `auth/user-not-found` and
  `auth/invalid-uid` as "gone" and rethrowing every other code; a DELETE of an
  orphan (a late rebuild re-creates the erased uid's doc post-probe, and Auth
  deletion is the cascade's LAST step, so the subject exists throughout it); the
  cross-user sweep STAMPS the revision guard (`arrayRemove` leaves it untouched, so
  an in-flight older rebuild wins); it runs AFTER the source tier; and a CAP flag
  unread by the consuming rules gate under-enforces on input OTHER people choose
  (`.limit(cap+1)` with NO `orderBy` keeps the lowest doc ids, so sockpuppets sort a
  real entry off the end). Trigger + reconcile NARROWS the window, never closes it;
  a task LAST in `WEEKLY_REPORT_TASKS` is what `runTaskChain` SKIPS first.
- **A compare-before-repair reconciliation resolves EXISTENCE once per uid ABOVE
  every branch, and counts a DELETE as drift on every branch.** `stored == expected`
  never settles orphanhood: an EMPTY orphan (what a post-cascade rebuild writes)
  matches an empty expectation, and a NON-EMPTY one matches too whenever the source
  sweep DECLINED at its cap or a `strict:false` chunk failed. Scoping the fix to the
  empty case leaves BOTH defects one branch over — measured: the equal-non-empty
  orphan survives every weekly pass, and the unequal one IS deleted but counts
  `skipped`, so the run logs "no drift" after changing something. Never reach the
  existence seam THROUGH the repair call either: it rewrites the benign doc and
  files it as drift.
- A "shared" collection also holds SOLO-owner docs to DELETE, not scrub. A scrub
  enumerates every uid in the MODEL's `toFirestore`: array elements, per-uid map
  keys, AND attribution scalars (`lastModifiedBy`, `lastEditedBy`).
- **A cascade write from a query-time snapshot applied via a plain `.update()`
  is a lost-update hazard** — wrap in `runTransaction`, re-read, skip on
  `!fresh.exists`.
- A rules hard-deny plus an Admin-SDK escape hatch has TWO guards: the callable
  exempts only the first; the model's `toFirestore` coercion is the second.
  Enumerate the SERIALIZER's call sites, not just the rules' writes.
- A serial `ref.update()` loop over an embedded array: NOT_FOUND aborts the
  remaining iterations AND the full-array write is a lost update. Per-doc
  `runTransaction` fixes only the second — try/catch each, throw once, then
  filter failed ids out of any UNCONDITIONAL write the abort protected.
  Parameterize fan-out helpers by `CollectionReference`, never a NAME string.

### Scheduled analytics & lifecycle jobs
- Never assume a date field's type (ISO vs `Timestamp` varies per collection).
- Anomaly gates: `baseline≥MIN_SAMPLES` AND `stddev>0` AND `|z|>3` AND
  `|today-mean|≥ABSOLUTE_FLOOR` — without the floor, pre-launch counts fire
  constantly. A consumer job SKIPS (never assumes zero) on a missing producer
  doc. `Math.floor(elapsed/DAY)` mis-classifies the sub-day remainder.
- **A daily job probing "today" only measures the hours BEFORE its own run
  time** — probe the PREVIOUS COMPLETED UTC day and derive date, query
  window, rollup offsets AND active-user cutoff from that one base.

### GDPR account-deletion cascade
- A cascade step keyed on a shared/parent handle destroys that handle LAST,
  after all child cleanup commits — including a purpose-built QUERY HANDLE
  cleared in the same write as the content scrub, ahead of a dependent mirror.
- **`probeResidualData` must not be BROADER than the deleter, and the deleter
  must not be NARROWER than the EXPORT's predicate** — Art. 15 must never reach
  a document Art. 17 cannot (`memberPermissions.<uid> != null` = Dart
  `isNull:false`). Union the probe's queries into the deleter's scoping, dedup
  by `doc.ref.path`; prove the coupling by DELETING the leg and checking BOTH
  the targeted fixture AND "no failed collections" redden. A leg on an
  ATTRIBUTION SCALAR (`lastModifiedBy`, `ownerId`) is broader unless
  `firestore.rules` PINS that field to the roster the deleter discovers by —
  read the write limb, never the app's own writer; unpinned, any editor plants
  a stranger's uid and that user's deletions report `gdprCompliant:false`
  forever.
  GATE any empty-roster DELETE on the uid having been ON that roster AND on EVERY
  denormalised roster being empty, EACH READ RAW (a DERIVED witness or a
  `.select()` projection collapses the gate); witnesses are ROSTERS (readers)
  only, never a discovery handle (`contributorUserIds`). It binds EVERY server
  writer that can empty a roster, and its NON-delete branch rewrites roster
  projections PER KEY and drops the whole-field key from the same payload.
  A leg with no DIRTY fixture is mutation-invisible and `strict:false` swallows
  a failed chunk, so the probe is the ONLY contradiction to `return true` — leg
  and scenario ship in one edit. A probe ERROR ADDS to residual (a sentinel,
  never a count), never aborts; one try/catch per leg. Hoist any list a deleter
  and probe both hardcode into one exported const.
- **An ENUMERATING probe (`rootRef.listCollections()`) is BROADER than the
  deleter by construction** — any user subcollection no step erases then
  reports `gdprCompliant:false` forever, unclearable. Ship it only with a
  DERIVED drift test: regex every
  `.collection(users).doc(..).collection("X")` writer across `functions/src` +
  `lib`, RESOLVING collection CONSTANTS incl. file-local ones, and spelling the
  users token `\w*[Uu]sers\w*` (`[A-Za-z_]\w*` misses the bare
  `FirestoreCollections.users` every Dart repo writes);
  `db.doc("users/${uid}/X/y")` string paths are still missed. Bucket each name
  into the source-PARSED `subs`, the source-PARSED exclusions, or a map whose
  every entry is EXERCISED (seed, run the named deleter, assert gone). Parse
  those literals by BRACKET MATCHING: `new Set([...])` closes `])`, so
  `indexOf("];")` swallows half the module. A deleter removing ONE DOC BY ID is
  NOT a deleter for the COLLECTION the probe counts. The exclusion list is
  load-bearing BOTH ways and needs its own fixture. Every hand-rolled fake
  doc-ref then needs `listCollections()` derived from stored deeper paths,
  never stubbed `[]` — absent, the outer catch fails CLOSED and every CLEAN
  fixture reddens.
- **EXPORT ⊇ DELETION is the cascade's other drift guard**: every source-parsed
  `subs` name is either read by an export chain or in a reasoned exemption map
  kept in PRODUCTION source, not the test. Such a map is PERMANENT — re-check
  each "no live writer" exemption against the same writer scan, and name every
  withheld collection in the bundle's `data_minimisation` line, or the gap is
  undisclosed (Art. 12(1)).
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
  inline `checkRateLimit` it burns two tokens per call. `rate_limiter.ts`'s
  docstring shows the wrapper as THE pattern, so grepping the helper misleads.
- **Bare `checkRateLimit` + a local throw drops BOTH** the `system_events`
  `rate_limit_violation` row AND `details.retryAfterSeconds`; both spellings are
  live, so copying a sibling is CONSISTENT, not correct. Abuse/cost gates fail
  CLOSED on a Firestore error; some notification gates deliberately fail OPEN —
  don't harmonize. A `…WithDeps` core test sees none of the wrapper's gates, and
  an unknown operation key falls back to `RATE_LIMIT_CONFIGS.default` in silence —
  pin the `(check|enforce)RateLimit(uid, "<key>")` LITERALS by parsing source,
  ranging over EVERY callable in the directory, never a hand-named subset.
- **A source pin matching BOTH spellings cannot detect a revert to the bare
  form** — it pins the KEY, never `details`. Pin on the DENIED path: both
  `enforceRateLimit` and `logRateLimitViolation` read `getFirestore()`, so
  `__setFirestoreForTest` + a throwing fake reaches the fail-closed branch. The
  ALLOWED path is unreachable — `getDb()` is a bare `admin.firestore()`.
- **`retryAfterSeconds` only beats the client's 60s fallback where the config
  declares `dailyLimit`** — read the bucket's config; never write daily-cap
  rationale onto a capless one.
- **`rateLimitWrite(bucket, s)` is INERT unless a client writes
  `users/{uid}/rate_limits/<bucket>`** — grep the Dart writers per bucket before
  citing it as a control; several rules name buckets nothing writes.
- `system_events` has no TTL — every enforced callable adds an unbounded
  write-per-denial stream, and `resource-exhausted` is client-RETRYABLE.

### Pooled ratings + rating aggregation (ratings/ family)
- Recipes are USER-SCOPED (no top-level `match /recipes`);
  `recipe_social_stats` is SERVER-ONLY — confirm from firestore.rules, not from
  a green Dart test.
- Unbounded collection-group folds use `.aggregate({count, average})`, never
  `.get()`; ANY filtered `collectionGroup` query — equality or
  `array-contains` — needs a `fieldOverrides` entry with
  `queryScope:"COLLECTION_GROUP"`, in `firestore.indexes.json`, staged in the
  SAME commit (precedent: `participants/participantId`). Missing, a cascade leg
  throws FAILED_PRECONDITION on every real erasure while the fake stays green.
  A COLLECTION-scoped equality needs none unless `fieldOverrides` EXEMPTS that
  field — check exemptions, not `indexes`.

### Verify-signup-age, account callables & minor-safety triggers
- Rules can't iterate an array, so a per-member rule on GROUP-shaped data lives in
  a CF (`groups/minor-membership-gate.ts`) with a trigger backstop.
- **A callable that READS a doc before checking caller membership is an ORACLE,
  and its idempotent no-op branch is the leak** — collapse `!exists` +
  non-member into ONE uniform response.
- **A cleanup helper spawned from a callable needs `callerUid` passed IN if it
  writes any ATTRIBUTION row** — deriving the actor from the SUBJECT is right
  only for a self-leave and misnames an eviction.
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
  override doc is live — ship a matching prod-doc update with the change.
- A new prompt field must be OPTIONAL with per-field fallback — a
  required-keys set reverts every live override. When
  mirroring a config field, grep every test fixture, or a stale one flips to
  fallback and passes vacuously.

### Ingredient sync, allergen data & admin exports/ETL (admin/ family)
- `admin/` scripts run `main()` at import — extract pure cores to test.
- Normalization parity must hold across every matching surface (sync stamp,
  server hold-gate, Dart client); list-split regexes stay in lockstep.
- Export/mining scripts: verify FIELD PARITY against the writer. Best test is a
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
  half-miss. A hand-rolled `paths:` parser fails CLOSED — an unknown glob shape
  reports UNCOVERED. Breadth must reach the ORCHESTRATOR that assembles the
  output, not only the helper directory it calls.
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
