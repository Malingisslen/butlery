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
  handler declares `concurrency: 1` (`SERIALISED_ENDPOINTS`). It trades OOM for
  QUEUE TIME charged against `isCascadeEventExpired` (from `event.time`) — a
  delivery that only queued is abandoned without failing and writes NO marker,
  invisible to `STALE_TAG_MARKERS`, `getDeletedIngredientStats` and
  `_needsRetagging`. Raise `maxInstances` (override + `ALLOWED_OVERRIDES`),
  never `concurrency`. Notification fan-out is IN-PROCESS — a cap never splits
  a batch.
- **`onUserDeleted` is the ONLY gcfv1 export** (own `.region().runWith()`,
  unreachable by `setGlobalOptions`) — exclude it from "every function" claims.
- **Prove endpoint config, never reason about it:** `npm run
  test:deploy-manifest` imports the ENTRY POINT (the only way the global call
  runs) and asserts region + numeric `maxInstances` on every `gcfv2` endpoint,
  plus `concurrency === 1` on the two cascades. An unset v2 option is a sentinel
  OBJECT, not null (`== null` is FALSE) — check `typeof x === "number"`.
  VACUITY SURFACE is the `gcfv2` FILTER: rename `platform` and every assertion
  passes over ~0 endpoints — guard the FILTERED count per CALLER, keep BOTH
  presence check and value pin, and make a by-NAME pin FAIL on a missing
  export, never skip.
- **Some gen2 exports pin their OWN region** (`moderateUpload`,
  `syncConversationLastMessage`, `purgeExpiredAuditLogs`, `migrations/`), so
  never say a global option "reaches every export". Adding an export
  falsifies every endpoint TALLY and no test guards them — strike the
  numeral (sweep `.github/workflows/` too) or DERIVE it in a test.

## Firebase Functions v2 — what to use

- `logger` from `firebase-functions/logger`, never `console.log` (except
  `admin/` ts-node scripts).
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
   computed from.
8. **Concurrent Tier-1 cascade legs (`Promise.all`) can write the same
   collection** — grep sibling legs for writers before claiming "no
   race"; make anonymising legs NOT_FOUND-tolerant PER DOCUMENT
   (`commitInChunks(strict:false)` fails a whole chunk on one NOT_FOUND),
   and give every new sweep its own leg in `probeResidualData` — it has
   top-level-FIELD, `users/{uid}`-ENUMERATION and collectionGroup shapes, so
   "the probe cannot see this collection" is never true and never a reason to
   skip one. `strict:false` is why it matters: the deleter reports `true` over
   a chunk it never committed.
9. A sweep cap's threat model comes from the write RULE it bounds, never a
    copied rationale — a bound's ABSENCE needs the same read. Never cite a
    rules LINE NUMBER in a comment; cite the `match` pattern or function name.
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
  read the real value off `__endpoint`, never a comment.
- **An in-code timeout guard is dead unless `timeoutSeconds` is declared on the
  SAME trigger** — global options carry no timeout, so a v2 event function
  defaults to 60s. Export guard-ms/platform-seconds as a pair and pin against
  the manifest's `__endpoint.timeoutSeconds` (a constant-vs-constant test stays
  green after the declaration is deleted).
- **A `retry:true` trigger enumerating a client-writable collection has
  unbounded fan-out** — cap the READ (`.limit(CAP+1).get()`), chunk-delete with
  a per-item `.catch` on grpc code only, never throw. The over-cap verdict
  follows the ACTION: DECLINE a destructive sweep (truncating half-erases), CUT
  the capped page for per-row ACCESS REVOCATION (refusing lets a planter keep
  access). A boolean verdict gating a destructive delete needs a fixture that
  can force it FALSE.

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
  `test:rules:all`, BOTH `paths:` blocks in `firestore-rules.yml`, and a UNIQUE
  **bare-literal** `const PROJECT_ID = "..."`. `rules-coverage-report.js`
  discovers ids by REGEX (`\bPROJECT_ID\s*=\s*["']`, plus a literal
  `projectId:`), so a `process.env.PROBE_X ?? "..."` const matches NEITHER and
  drops the suite from the coverage union — a HARD `exit 1` when that suite is
  the sole exerciser of a match block ADDED in the same commit (any conditional
  `allow` must be exercised). Put the probe override at the `projectId:` CALL
  SITE, never on the const. VERIFY, never infer: run the suite against a live
  emulator, then `node scripts/rules-coverage-report.js --base HEAD` and read
  `coverage-summary.json` → `newUntestedBlocks: 0`.
  `test:rules*`/`test:integration:*` are excluded from the unit lane by prefix.
- `scripts/run-ci-unit-tests.js` — the real CI gate. Hand-rolled harness,
  no jest — call `runTests` exactly ONCE per file.

## Logging conventions

`logger.info("event", { userId, recipeId, action })` — stable string,
structured object, no PII. **`logger.error(msg, { err })` records NO
cause** — unwraps only when passed POSITIONALLY; use `errCode`/`errName`
from `(err as {code?}).code`.
- **Hash ALL PII/title-derived fields consistently** — a mixed line (one
  hashed, one cleartext) is the tell. `hashUid(uid)` or `uid.slice(0,6)`.
- **A DOCUMENT ID can be PII depending on the CALLER** — a conversation id is
  a UUIDv4 for a group, `direct_${sortedUidA}_${sortedUidB}` for a DM.
  `logSafeConversationId(id)` hashes the direct spelling — re-derive it for
  every NEW caller of an id-logging helper.
- **A uid enters a log through a QUERY OBJECT too** — a logged `FieldPath(...,
  uid)` JSON-stringifies its SEGMENTS, writing the raw uid on the very line
  that truncates it to `uid_prefix`. Log a literal label.

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
  error code from TWO branches; assert on branch-unique text. An unsimulated
  fake stub must THROW, not silently succeed — and a fake resolving a dotted
  `where()` field MUST special-case `FieldPath` (read `.segments`): it HAS
  `.split`, so it matches ZERO in silence. Type EVERY fake query seam
  `string | FieldPath` — an `as unknown as Firestore` cast checks none.
- Vacuity: a `?? {}` read survives the mutant DELETING the doc (pair with a
  sibling requiring EXISTS); `src.includes("<field>")` is free when a
  docstring names the field (assert the WRITE). A LOG-ONLY branch is pinnable
  via the fake's recorded `writes[].data` — never write "no test can pin
  this".
- **Rules are not filters** — a client query with NO condition is DENIED
  wholesale on a member-scoped collection; only the RULES emulator lane
  proves it, and it KEEPS data across runs, so give an "empty" fixture a uid
  no other test seeds. The VERB decides which conjuncts run: a merge-`set` on
  a seeded doc is an UPDATE and a `withSecurityRulesDisabled` seed evaluates
  none, so a create-only conjunct never justifies an update-path fixture.
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
- Cascade purges discover children via `rootRef.listCollections()`, never
  hard-coded names. Steps are BEST-EFFORT — a rethrow re-runs the WHOLE
  cascade, double-applying non-idempotent ones. Before citing
  `admin/reset-user-data.ts` as provenance OR as the recovery a capped sweep's
  DECLINE names: `subcollections` is a READER'S note, not enforcement;
  `COLLECTIONS_TO_DELETE` holds TOP-LEVEL names; and a name in BOTH it and
  `COLLECTIONS_TO_KEEP` makes `main()` `process.exit(1)` before deleting
  anything (`tag_configs` does). List membership is NECESSARY, not sufficient.
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
- A cascade step keyed on a shared/parent handle must destroy the retry
  handle LAST, after all child cleanup commits. Subtler form: a
  purpose-built QUERY HANDLE cleared in the SAME write as the content
  scrub, ahead of a dependent mirror — order the mirror write FIRST.
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
  users token `\w*[Uu]sers\w*` — `[A-Za-z_]\w*` REQUIRES a char before "users"
  and so misses the bare `FirestoreCollections.users` every Dart repo writes;
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
- A two-stage gate's SHARED/cross-user side effect (global counter) goes
  LAST, so a denial only wastes the requester's own budget. A
  retry/fallback path calling an UNWRAPPED core (bypassing
  `withRateLimit`) silently skips BOTH per-user AND global caps.
- **Only `enforceRateLimit` writes the `system_events` `rate_limit_violation`
  row** — bare `checkRateLimit` + a local throw does not, and the `groups/`
  callables plus `sendNotification` take the bare form, so a chat-group abuse
  loop leaves no audit trail. A new callable copying its siblings is
  CONSISTENT, not correct. Abuse/cost gates fail CLOSED on a Firestore error;
  some notification gates deliberately fail OPEN — don't harmonize.
- `system_events` has no TTL — every enforced callable adds an unbounded
  write-per-denial stream, and `resource-exhausted` is client-RETRYABLE.

### Pooled ratings + rating aggregation (ratings/ family)
- Recipes are USER-SCOPED (no top-level `match /recipes`);
  `recipe_social_stats` is SERVER-ONLY — confirm from firestore.rules, not from
  a green Dart test.
- Unbounded collection-group folds use `.aggregate({count, average})`, never
  `.get()`; a `collectionGroup` equality query needs a `fieldOverrides` entry
  with `queryScope:"COLLECTION_GROUP"`. A COLLECTION-scoped equality needs
  none — unless `fieldOverrides` EXEMPTS that field, so check exemptions, not
  just `indexes`.

### Verify-signup-age, account callables & minor-safety triggers
- Rules can't iterate an array for a per-member rule on GROUP-shaped data —
  the check lives in the CALLABLES (`groups/minor-membership-gate.ts`),
  backstopped by `enforceGroupMinorMembership`, `onDocumentWritten` on
  `chat_groups/{groupId}`.
- **A callable that READS a doc before checking caller membership is an ORACLE,
  and its idempotent no-op branch is the leak** — collapse `!exists` +
  non-member into ONE uniform response.
- **A cleanup helper spawned from a callable needs `callerUid` passed IN if it
  writes any ATTRIBUTION row** — deriving the actor from the SUBJECT is right
  only for a self-leave and misnames an eviction.
- **A client-chosen document id is not unique across accounts.** A
  server-side pointer to one (`friend_categories/{uuid}`) must be keyed on
  OWNER + id, or an ex-member re-creating that id under their own uid is
  handed the victim's object. Do NOT then exempt that owner from the object's
  membership check — an owner who left could otherwise empty its roster.
- **A new `onCall` export is a THREE-file change**: the function, its
  `test:*`/suite in `package.json`, and `app-check-enforcement.test.ts`'s
  classification (`ADMIN_EXEMPT` only if the handler's FIRST statement
  checks the admin claim); a deletion is the same in reverse.

### TS↔Dart parity twins (canonical-pool-key.ts et al.)
- `\w`/`\b` are ASCII-only in both — fold å/ä/ö→a/o FIRST or use lookarounds;
  case-insensitive triggers need per-letter classes, not `/i`. Module-scope
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
  does not prove the DEPLOY step failed. "Setting X fixed the deploy" is a
  claim about a RUN — `gh run list --workflow=`, then `git show <sha>:<file>`.
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
