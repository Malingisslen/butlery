# cloud-functions-specialist — accumulated knowledge

This file is the agent's long-term memory across sessions. The agent **MUST**
read it as Step 0 of every Cloud Functions task and **APPEND/EDIT** it on
discovery, real-bug fix, or user correction.

## How to update this file

This file is a **principles document, not an incident log.** A new lesson is
folded into the relevant Principles subsection (merge with what's already
there; restate only to sharpen/supersede) — never a new dated entry here.
The raw ticket-by-ticket narrative goes to
`cloud-functions-specialist.knowledge.archive.md`: dated
(`### YYYY-MM-DD — short title`, tagged [Pattern discovered] / [Bug fixed] /
[User correction] / [Cost finding]), verbatim, append-only, never deleted.

- **Archive = append-only log. This file = edited in place** — principles
  merged/tightened, not stacked chronologically.
- **A principle earns its place only if a future run would do something
  DIFFERENT because of it.** Keep exact names, trigger types, config keys,
  error signatures, index definitions. Cut the incident story.
- **Bias toward detail** on data-writing/deleting functions, idempotency,
  retry semantics, cost/quota, region pinning, GDPR paths — a miss there
  costs money or user data.

---

## Function families (functions/src/index.ts)

| Path | Concern | Trigger | Test command |
|---|---|---|---|
| `llm/` (Gemini/Vertex) | Paid-LLM cost, latency, prompt safety | callable | `test:ocr-retry` |
| `cleanup/` | Idempotent deletion cascades, batch limits | scheduled + onDocumentDeleted | `test:cleanup-*` |
| `social/` | Profile propagation across user trees | onDocumentUpdated | `test:profile-updated`, `test:set-profile-searchability` |
| `events/` | Telemetry append-only | onCall | `test:parse-correction`, `test:parse-tier-vocabulary` |
| `admin/` | One-shot scripts, ts-node only, never deployed | manual | idempotency/region/retry N/A |
| `notifications/` | FCM push, batched, rate-limited | onCall + scheduled | `test:send-notification`, `test:activity-digest` |
| `ingredients/` | Soft-delete cascade | onDocumentUpdated | (integration) |
| `analytics/` | Aggregation + lifecycle jobs | scheduled | `test:detect-lapsed-users`, `test:track-retention` |
| `ratings/` | Pooled-rating aggregation, debounced | write + scheduled | `test:canonical-rating-aggregation`, `test:family-rating-recompute` |
| `family/` | Household data lifecycle | scheduled | `test:purge-dormant-family-data` |
| `messaging/` | Conversation/DM safety triggers | onDocumentCreated | `test:enforce-group-minor-membership` (+integration twin) |
| `account/` | GDPR deletion + age verification | onCall + onDocumentDeleted | `test:verify-signup-age`, `test:request-account-deletion` |
| `migrations/` | One-shot gated backfills | manual ts-node | n/a |
| `middleware/` | Auth/validation/rate-limit wrappers | utility | `test:rate-limiter-*` |
| `shared/` | Pure helpers, no triggers | utility | varies |

New family → append a row + a test command.

## Region & global options

```ts
setGlobalOptions({ region: "europe-west1" });
admin.initializeApp();
```
All functions deploy to **europe-west1** — never a per-function region
without approval (client calls by name+region; mismatch = silent "not
found"). `admin.initializeApp()` runs once in `index.ts`; re-init throws.

## Firebase Functions v2 — what to use

- Firestore triggers: `onDocumentCreated/Updated/Deleted` (`v2/firestore`).
- HTTP/callable: `onCall`, `onRequest` (`v2/https`). Scheduled: `onSchedule`.
- `logger` from `firebase-functions/logger`, never `console.log` — except in
  `admin/` ts-node scripts (not deployed, no logger context to lose).

## Idempotency rules (the most bug-prone area)

Firestore triggers retry on uncaught exception; every handler must be
idempotent:
1. **Aggregate writes** → `FieldValue.increment` paired with an event-id
   guard doc (`processed-events/{id}`) written in the same transaction.
2. **Cascade deletes** → a target already gone on retry is success, not
   failure.
3. **External-API calls** → derive a stable idempotency-key from the event.
4. **Sends** → write a `sent-events/{id}` guard BEFORE sending.
5. **`retry:true` requires every write safe on a MISSING doc, not just safe
   on re-delivery.** `set`/`delete`/`set(merge)` are safe-on-missing;
   `.update()` is NOT — throws NOT_FOUND (grpc code numeric `5`, check
   `(e as {code?:number}).code === 5`) the instant the doc is gone, turning
   into a permanent retry loop under `retry:true` instead of the old
   drop-once. Audit every `.update()` in a `retry:true` handler for this
   race — the single most common gap when adding `retry:true`.
6. **Validation errors COLLECTED into an array but thrown later are not a
   gate** — anything between the collect and the throw runs on data already
   known invalid. Classic shape: `forEach` collects errors → an
   authorization/enrichment loop dereferences the same elements (a `null`
   element throws TypeError → callable returns `internal`, which clients
   retry) and burns a Firestore read per item → only then the
   `invalid-argument` throw. Throw immediately after collecting. A
   `payload as T[]` cast that checks only `Array.isArray` never validates
   ELEMENT shape — the cast is where this bug hides.
7. **Any client-supplied string interpolated into a doc path is a
   poison-pill/fail-open surface.** Full validator: non-empty, ≤1500 UTF-8
   **bytes** (not `.length`), no `/`, not `.`/`..`, not `/^__.*__$/`
   (reserved) — "non-empty, no slash" alone misses `.`/`..`/reserved ids,
   equally deterministic throws, often BEFORE the safety decision (fail-open).
8. **Sanitisation must never shrink the value a security gate's THRESHOLD is
   computed from** — sanitise for the *use*, gate on the *raw* shape/count.
9. Can't be idempotent? Document why + add a `processed-events`-style guard.

## Cost & cold-start

- Billed per ms × memory + per-invocation. Cold start ≈500–2000ms; each
  extra large SDK import adds ~200ms.
- Narrow imports (`from "firebase-functions/v2/https"`), not `import *`.
- LLM functions: `timeoutSeconds:540` (v2 callable max), `memory` sized to
  measurement, not guessed.
- Scheduled jobs run hourly, not per-minute (43,200×/month adds up).

## Secrets handling

- `defineSecret("MY_KEY")` (`firebase-functions/params`), never env vars in
  code. Never log a secret. Root `.env` is Flutter-only.

## Test commands (from `functions/`)

- `npm run build` — must pass before any commit.
- `npm test` = `run-all-tests.js`: auto-discovers every `test:*` script
  (excluding `test:rules*`/`test:integration:*`), runs ALL even after a
  failure. **A new `__tests__/*.test.ts` is invisible until its `test:*`
  script exists** — grep package.json FIRST when reviewing any new test
  file; this is the single most recurring CI-wiring trap in this codebase.
- `npm run test:rules:all` — rules + emulator integration (owned by
  `firestore-rules-tester`). A `test:integration:*` suite must ALSO be
  appended here AND to both `pull_request`/`push` `paths:` in
  `firestore-rules.yml`, or it never runs in CI despite passing by hand.
- `scripts/run-ci-unit-tests.js` — the real CI gate (Node 22, no emulator).
  `CI_EXCLUDE` lists known-broken suites.
- Hand-rolled `test()`/`_unit-runner` harness (console + `process.exit(1)`).
  No jest. A `_unit-runner` file calls `runTests` exactly ONCE — two
  concurrent `void runTests(...)` calls let a first-suite failure tear the
  process down and truncate the second's reporting (exit code still
  correct, but console output gets ambiguous).

## Logging conventions

```ts
logger.info("descriptive event", { userId, recipeId, action });
```
- First arg: stable, queryable STRING. Second arg: structured object, no
  PII. `logger.info(JSON.stringify({...}))` defeats Cloud Logging's
  queryable `jsonPayload` even when "queryable telemetry" is the stated
  goal — never crush structured data into the message string.
- Errors: an Error nested in the payload object serializes to `err: {}` —
  `firebase-functions`'s `entryFromArgs` unwraps an Error only when it is
  passed POSITIONALLY (`logger/index.js:112-121`), so `logger.error(msg,
  { err })` records NO cause at all (verified against the emulator, not
  inferred). Where the only other record is a count-only throw, add
  `errCode: (err as {code?:number|string}).code` + `errName` — the gRPC code
  is what separates DEADLINE_EXCEEDED from PERMISSION_DENIED, and unlike
  `err.message` it cannot carry a doc path containing the raw uid.
- **Hash ALL PII/title-derived log fields consistently, not just some** — a
  mixed line (one hashed, a sibling cleartext) is a tell the cleartext one
  was kept for eyeballing. Swedish dish titles often lead with a given name
  ("Annas paj", "Mormors …"); if only inequality-across-events matters for
  detection, a hash gives that signal without the leak. `hashUid(uid)`
  everywhere a raw uid would sit near other identifying fields.
- **A raw uid interpolated into the MESSAGE string is the recurring form of
  this leak**, and it fails twice: it is cleartext PII (worst on the Art. 17
  erasure path, where the log outlives the account) and it gives every user a
  distinct message, destroying Cloud Logging grouping. The account family's
  settled convention is `uid_prefix: uid.slice(0, 6)`
  (`request-account-deletion.ts:178,266`) or `hashUid(uid)`
  (`verify-signup-age.ts`). Grep `\${uid}` inside backticked log strings on
  any cascade/probe diff — one such line among a dozen clean siblings is the
  tell that it was added ad hoc.
- A literal NUL (or odd byte) in a source file makes `ripgrep` treat the
  WHOLE file as binary and silently skip it in sweeps — use `Read`/Node to
  inspect suspect files. CI backstop: `functions-binary-guard` in
  `test.yml` (`git ls-files -z 'functions/src/**' | xargs -0 -r grep -laP
  '\x00'`).
- **Doc-ID prefix ranges (`startAt(x).endAt(x+sentinel)`) must spell the
  sentinel as the 6-character escape (backslash-u-f-8-f-f), never a raw literal** — the literal
  renders as nothing, so the range reads as degenerate and invites a "fix"
  that erases the bound (BUT-1690 was exactly that false report). Verify with
  `Read`/Node codepoints, not eyes. The `lib/**.dart` guard added for BUT-1690
  lives in `test/architecture/architecture_test.dart` and does NOT cover
  `functions/src/**` — `account-deletion-cascade.ts`'s `system_rate_limits`
  range still carries the raw form, including inside its own comment prose.

## What NOT to do

- Don't deploy — user reserves `firebase deploy --only functions`.
- Don't change region without approval; don't wire `console.log` in a
  deployed function; don't skip an idempotency story on a trigger.
- Don't add `retry:true` without auditing every write for missing-doc safety.
- Don't introduce a new test framework; don't import `firebase-functions` v1.
- Don't trust a client-controlled field for a trigger's security decision
  unless the Firestore create/update RULE independently pins it to
  `request.auth.uid`.

---

## Principles (distilled 2026-04-25 – 2026-07-24)

Every lesson ever logged in this file's history is folded in below or
superseded by a newer entry; the full ticket-by-ticket narrative for all of
it lives verbatim in `cloud-functions-specialist.knowledge.archive.md` —
see "When to consult the archive" at the end.

### Completion-event telemetry (`emitTiming` family)
- Gemini/Vertex implicit caching: `usageMetadata.cachedContentTokenCount`,
  billed ~10% of input rate; cost = `((prompt-cached) + cached*DISCOUNT)/1M
  * INPUT_COST_PER_M`, `cached` clamped to `[0, promptTokenCount]`. Check
  the installed `.d.ts` before widening types locally.
- Never coerce a missing telemetry field to 0 — log as-is; Cloud Logging
  DROPS undefined JSON fields, which is what marks "not reported" vs a real
  zero. Widen a seam with an OPTIONAL field over a side-channel log.
- Declare `let experimentBucket: number | undefined` BEFORE the `emitTiming`
  closure on any early-exit-capable function, assign after the async step.
  Each experiment gets its OWN salt string.
- Emitter contract test: assert EXACTLY ONE event per call via a
  module-scope logger-capture array cleared per case — catches try-path +
  catch-path double-emits.

### Test seams, emulator infra & non-vacuity
- v2 exports carry `.run(event)` — call it with a typed payload to test
  triggers without firebase-functions-test. Build `Change` payloads from
  REAL emulator snapshots; `.data()` on a missing snapshot returns
  undefined exactly like prod.
- `onSchedule`/v1-auth bodies with no seam: extract an exported async core,
  wrapper stays a one-line delegate. Module-level `db = admin.firestore()`:
  set `FIRESTORE_EMULATOR_HOST` before `admin.initializeApp`, `require()`
  after. Parent docs must be explicitly seeded for `orderBy("__name__")`
  scans — a subcollection write alone doesn't make the parent exist.
- **When only one collaborator in a sequence is seam-injectable, spy on its
  earliest side effect to pin ORDER** — a boolean flipped on its first line
  is enough to redden a reverted order without a full seam.
- **A wrapper/gate test is non-vacuous only if breaking the gate produces a
  DIFFERENT observable result than any other failure mode** — check this
  deliberately before trusting a green wrapper suite.
- **Some guards are only reachable on a SECOND invocation, so only a
  re-run test can pin them.** Firestore `update(ref, {})` throws "At least
  one field must be updated", so an idempotent scrub's
  `if (Object.keys(update).length > 0)` guard is dead code on run 1 (every
  matched doc still has something to change) and load-bearing on run 2. A
  `<step> is idempotent on re-run (retry-safe)` test that simply calls the
  exported step a second time and awaits it catches that class outright —
  verified by mutation, it was the ONLY red in a 58-test suite. Give every
  re-enterable cascade step one.
- **An unsimulated fake stub must THROW, not answer.** A hand-rolled
  `runTransaction` whose `tx.get` hard-returns `{exists:false}` is safe only
  while no fixture reaches it; the day one is seeded, the SUT's
  `if (!snap.exists) return` early-exits and the test PASSES having scrubbed
  nothing. Same for a `listDocuments()` returning `[]`. Answer with a throw
  naming the right lane ("seed the emulator suite"), and never let the stub's
  comment claim it protects a future fixture.
- **A fix living in the I/O wrapper / handler-level gate can't be pinned by
  a pure-core unit suite.** Check which side of the pure-core/handler seam a
  fix landed on before crediting a suite with covering it. A test asserting
  on a literal built in the test file, or on an input pre-transformed the
  same way the SUT would, tests the fixture, not the code.

### PII scrubbing + GDPR cascade design
- Cross-port heuristic vectors (TS↔Dart) live in one shared JSON fixture;
  the "Dart copies this" note goes in a `_header` field.
- JS `\b` misfires before å/ä/ö — use `(?<=^|[^A-Za-zÅÄÖåäö])`, never lead a
  Swedish-letter regex with `\b`. Case-insensitive trigger words: per-letter
  classes (`[Mm]ormor`), not `/i`. Possessive titles ("Janssons frestelse")
  are pinned NEGATIVE vectors — never generalize to bare capitalized-word NER.
- Cascade purges: discover children via `rootRef.listCollections()`, never
  hard-coded names. Gate root-doc deletes on `exists`. New cascade steps are
  BEST-EFFORT (catch+warn+partial) — a rethrow re-runs the WHOLE cascade,
  double-applying non-idempotent steps like `increment(-1)`.
- **A merged batch mixing `batch.delete` (safe on missing) with
  `batch.update` (throws NOT_FOUND on missing) can have the update's
  absence abort the whole batch, including deletes that would've
  succeeded.** Fix: piggyback the update-target's existence probe onto the
  SAME `getAll` already used for the idempotency gate, skip the update
  (never `set(merge)` — resurrects a deleted peer) when absent.
- **A destructive delete driven by "not present in a live roster query"
  must guard against the query itself being under-populated** — a
  transiently empty/incomplete read must not permanently delete regulated
  data.
- Cross-check the identity field **and the COLLECTION NAME** a cascade
  filters on across all legs (Dart repo `collectionName`/`getUserCollection`,
  `firestore.rules` match block, deleter, export, probe) before trusting a
  query matches real docs — a wrong field or a pre-rename name deletes
  NOTHING, silently. Two live examples: `realtime_recipes` (`userId` vs
  `ownerId`) and `users/{uid}/shopping_lists` vs the real
  `unified_shopping_lists` (which also owns a per-list `items` subcollection
  needing its own sweep, and whose Art. 15 export read the same dead name).
  **A missing `match` block for the queried path in `firestore.rules` is
  proof the path holds no client-written data** — the cheapest check there
  is. `admin/reset-user-data.ts` listing two names for one thing is the tell.
  Every GDPR-deletion test needs a POSITIVE "owned doc is gone" assertion,
  not just "control survives." **Fixing a dead collection name in ONE consumer
  does not fix the rename** — sweep EVERY consumer in the same change
  (deleter, probe, Art. 15 export, denorm propagation, analytics/retention
  probes, Dart repo constants). `users/{uid}/shopping_lists` still lives in
  `analytics/compute-feature-retention.ts:212` (+ its docstring line 41), so
  the `shopped` feature is structurally always false, after the cascade +
  export legs were fixed.
- **One logical field can have TWO stores; only the READER decides which is
  authoritative.** Personal `unified_shopping_lists` keep items BOTH embedded
  in the list doc (written by `repository.update`) and in an `items`
  subcollection (written by the item-ops module) — and
  `ShoppingRepositoryQueryModule.readAll` does `list.copyWith(items:
  <subcollection>)`, so the doc array is silently discarded on every reload.
  When sizing a cascade/export/analytics leg, prove which store the app READS
  (a 20-line fake-Firestore round-trip settles it) instead of trusting the
  writer you happened to open. A cascade must erase BOTH stores.
- **Deleting a parent doc after a BEST-EFFORT (`strict:false`) sweep of its
  subcollection strands unreachable child PII**: the swallowed chunk failure
  is warn-only, the parent goes anyway, the retry has lost its handle, and a
  probe that counts only parent docs reports 0. Children of a to-be-deleted
  parent use `strict:true` (the `deleteFamilyData` household precedent) so the
  step fails loudly and the parent survives for the retry. Corollary: that
  strict child sweep now THROWS, so it must not sit in front of a
  higher-value leg in the same step — a legacy/pre-rename path swept before
  the live one can abort the step before the live data is ever touched. Order
  the live path first.
- **A parent-with-subcollection deleted by a plain client `doc(id).delete()`
  leaves an orphan the server cannot QUERY.** `get()` returns only existing
  docs and `count()` reports 0, so both a sweep and a residual probe certify
  a clean erasure while every child doc is still on disk. `listDocuments()`
  is the only Admin-SDK call that returns refs for MISSING documents that
  still own subcollections — use it on both the sweep and the probe wherever
  the client deletes a parent without recursing. `batch.delete(ref)` on such
  a phantom ref is a safe no-op, so the parent leg needs no exists-gate.
- **A "shared" collection also holds SOLO-owner docs, which are pure own-data
  and must be DELETED, not scrubbed.** A scrub-only loop over
  `where(memberPermissions.{uid} != null)` retains a collaborative list the
  deleted user created and never invited anyone to — item names and all,
  readable by nobody, invisible to every probe. Inside the same loop: delete
  when `ownerId === uid` and no other `memberPermissions` key remains.
- **Scrubbing a deleted user off a SHARED doc must enumerate every
  {uid, displayName} pair on the MODEL, including pairs inside embedded array
  elements — not just the pairs the profile-propagation CF writes.** That CF
  is a subset (owner + last-activity); the client stamps more
  (`addedBy*`, `lastModifiedBy*` on `UnifiedShoppingItem`). Also delete the
  `memberPermissions.{uid}` key like `deleteWeeklyMenuPlans`/
  `deleteFamilyData` do — in the SAME atomic per-doc `update()`, since that
  key is the step's re-entry query handle.
- **A cascade step that read-then-rewrites a whole embedded array via a
  serial `ref.update()` loop has two defects at once**: NOT_FOUND on a
  concurrently deleted doc aborts every remaining doc in the loop, and the
  full-array write is a lost update against live editors. Per-doc
  `runTransaction` (re-read inside, `if (!snap.exists) return`) fixes both —
  but ONLY for NOT_FOUND. Every other transaction error (ABORTED after
  contention retries, DEADLINE_EXCEEDED) still escapes the `await` and aborts
  the rest of the loop, and contention is the LIKELIER failure on a live
  shared doc. Wrap each per-doc transaction in its own try/catch, collect the
  failures, throw once after the loop. Two corollaries, both missed on the
  first fix pass: (a) apply it to EVERY serial loop in the step, not only the
  one under review — a `for (ref of refs) await deleteChildren(ref)` whose
  child sweep is `strict:true` aborts on item 1 and skips every later item PLUS
  every leg after it (`deleteShoppingLists`' personal-items loop still does
  this while the shared loop below it accumulates); (b) converting abort-early
  → accumulate makes an UNCONDITIONAL downstream write unsafe, because the
  abort used to protect it for free — after accumulating item-sweep failures
  you must filter those ids out of the parent-delete batch, or you delete the
  parent whose children just failed and strand them unreachable. The
  accumulation itself is invisible to a suite with no failure injection: only a
  seam that makes ONE iteration throw distinguishes it from the aborting
  version — and that seam needs NO production code change. Pass the step a
  `Proxy` over `db` whose `batch()` records each `delete(ref).path` and throws
  on `commit()` when a path matches the child collection (`/items/`); real
  transactions and parent deletes still run, so one ~20-line script proves the
  later legs execute (done for `deleteShoppingLists`: parent kept, items kept,
  shared scrub applied, count-only throw, remediation re-run clean).
  Corollary (c): converting abort-early → accumulate moves the CAUSE out of
  `runStep`'s `result.errors` (which used to receive the raw `err.message` in
  the audit row) into a per-iteration log line — so the aggregate throw stays
  count-only for PII and the log line MUST carry the error code, or the
  failure is diagnosable nowhere.
- A denorm-name propagation step querying a name as a TOP-LEVEL collection
  when it is a user SUBCOLLECTION updates zero docs, silently
  (`on-profile-updated.ts:159` still passes `Collections.unifiedShoppingLists`
  to `paginatedDualUpdate`, which does `db.collection(name)`). A
  `collectionGroup` fix needs `fieldOverrides` with
  `queryScope:"COLLECTION_GROUP"`.
- **`probeResidualData` must not be BROADER than the deleter** — a probe leg
  the cascade has no path to clear makes the canary permanently red. The
  shared-shopping-list orphan probe counts `ownerId == uid` with no other
  member, while the deleter is keyed only on `memberPermissions.{uid}`; a doc
  with `ownerId == uid` and no such key (tampered client — the owner branch of
  the update rule carries no `cannotModify`) is retained own-data the probe
  reports forever. Make the deleter's scoping a SUPERSET of every probe leg —
  literally union the probe's own queries and dedup by doc id. The property
  is PROVABLE, not just assertable: delete one union leg and the suite must
  redden BOTH the targeted fixture test AND the `no failed collections` test
  (the probe flagging its own uncleaable residual). If only one reddens, the
  probe and the deleter are not actually coupled.
- A forged/rushed commit-gate marker does NOT imply bad code — always
  re-review the real diff regardless of how the marker was created.

### Scheduled analytics & lifecycle jobs
- Don't assume a date field's type (ISO string vs `Timestamp` varies by
  collection — mixing silently returns zero rows). Full-scan jobs need an
  explicit cap + `logger.warn` when hit. Stagger schedules away from
  existing big scans.
- Anomaly gates: `baseline≥MIN_SAMPLES` AND `stddev>0` AND `|z|>3` AND
  `|today-mean|≥ABSOLUTE_FLOOR` — without the floor, 3σ on pre-launch counts
  (0→2) fires constantly. A consumer job schedules strictly after its
  producer's slowest run and SKIPS (never assumes zero) on a missing
  producer doc. Always write the output doc even when empty.
- **`Math.floor(elapsed/DAY)` truncation on a `>N`/`>=N` boundary
  mis-classifies the sub-day remainder in `[N,N+1)`** (30d12h floors to 30,
  falls in the wrong bucket). Compare raw elapsed ms, never truncated days,
  when client+server must agree on a boundary; pin with a sub-day-remainder
  fixture — a whole-day fixture passes under the buggy floor and proves
  nothing.
- **A cursor-driven "crossed threshold(s) since last run" window is safe
  under normal cadence but OVERLAPS across thresholds after an
  outage/wide-gap recovery** — exactly the scenario it targets. Without
  cross-threshold dedup, one user matches several thresholds in one
  recovery run and gets stacked notifications; track already-notified users
  across thresholds, or pick each user's single highest threshold.
- An unbounded `.where().get()` with a serial per-user read in a loop is a
  memory/timeout risk specifically on a wide catch-up window — page with a
  `__name__` cursor and parallelize the reads.
- A test fake's auto-doc-id keyed off a write COUNTER that only increments
  on `commit()` can collide across docs created inside one uncommitted
  batch — bump the counter at `.doc()` time.

### Fan-out pagination & denormalization (shared/batch-update.ts family)
- **Self-advancing bounded loop** (`query.limit(N).get()` → mutate → repeat
  until `size<N`) for any delete/filter-mutating sweep whose body changes a
  field the base query filters on (the mutation removes the doc from the
  next page's match, so it self-advances safely). Use the `__name__`-cursor
  helper (`batchUpdateQueryPaginated`) ONLY when every write touches solely
  denorm fields, never the filtered field or the doc id. A self-advancing
  drain still needs a hard iteration cap as a backstop against a
  non-shrinking page — converts a scheduler-timeout crash into a clean
  logged partial-and-resume.
- A drain that CLAIMS-BY-DELETE each processed item self-heals across runs
  (overflow stays matched, retried next run) — safer than a bounded scan
  with no claim mechanism, which can starve overflow permanently if the
  matched subset shifts between runs.
- Rewriting an unbounded fan-out to paginate: (1) diff against `git show
  HEAD:` of the old file to confirm every step's `.catch` survived; (2)
  confirm no paginated update touches its own filter field or `__name__`;
  (3) a per-doc-callback → static-update-map swap is safe ONLY when the map
  is invocation-constant.
- A shared debounce/queue wrapper gaining a new observability field needs
  its return-type surface updated in EVERY adapter, not just the one under
  test — the warn-log behavior fires everywhere automatically, but a typed
  return field can drift between adapters.

### GDPR account-deletion cascade
- A cascade step keyed on a shared/parent handle (e.g. `arrayRemove` on a
  household doc) must destroy the retry handle LAST, after all child
  cleanup commits — else a transient mid-step failure strands orphans a
  retry can no longer reach. Steps keyed `where(field,"==",uid)` are immune.
- `probeResidualData` must mirror the deleter's exact field scoping per
  collection (two probes when a collection has two owner-ish fields; a
  subcollection-shaped probe, never top-level `where`, for a subcollection).
  `count()` is the probe primitive; a probe error should ADD to the
  residual count, never abort the cascade.
- Pure `users/{uid}/*` subcollections erase via a generic uid-scoped sweep
  (retry-safe by construction). Canonical test triple for any new deleter:
  own-erased + other-kept + `failedCollections` empty.
- Warn-before-purge two-pass is the shape for any auto-deletion of user
  data: pass 1 stamps a scheduled-at + warning; pass 2 deletes only once
  due; reactivation clears the stamp.

### Rate limiting & LLM cost gates (middleware/rate_limiter.ts)
- **A two-stage gate where each stage has its own side effect has NO free
  ordering** — a denial by the second gate strands the first gate's
  mutation. Put the SHARED/cross-user side effect (the global counter)
  LAST, so a denial only ever wastes the requester's OWN budget.
- **A retry/fallback path calling an UNWRAPPED core (bypassing the
  `withRateLimit`-wrapped callable) silently skips BOTH the per-user AND
  global cap — close both, separately.** Re-apply the per-user check via
  the SAME operation key the wrapped callable uses, BEFORE the global
  check (same ordering rule), with the caller's uid a REQUIRED parameter so
  no call site can silently fail open.
- **A per-ITEM token charge couples the bucket's `maxTokens` to the
  callable's own payload cap**: `maxTokens` must be ≥ the max batch size or
  every full-size batch is denied forever (`currentTokens` can never reach
  `tokensRequired`), with a retryAfter that never helps. The two constants
  sit in different files — derive one from the other or pin both in a test;
  a comment is not enforcement. Also state the COMBINED ceiling when a
  second bucket is split off an existing one: separate buckets are
  ADDITIVE, so "same budget either way" is only true per-path.
- **Standalone callables use `enforceRateLimit`, not bare `checkRateLimit`**
  — only the former writes the `system_events` `rate_limit_violation` row
  via `logRateLimitViolation`. A bare `checkRateLimit` + hand-thrown
  `resource-exhausted` silently drops the abuse telemetry, which is usually
  the whole point of the ticket adding the gate. (`notifications/` is the
  existing outlier.)
- Abuse/cost gates fail CLOSED on a Firestore error; some notification
  gates fail OPEN by design for their own domain — don't harmonize.
  `withRateLimit` wraps *callables*; the SDK does NOT auto-retry a thrown
  `resource-exhausted`, so callable rate limits carry no double-consume
  concern from the trigger idempotency rules.

### Pooled ratings + rating aggregation (ratings/ family)
- Recipes are USER-SCOPED (`users/{ownerUid}/recipes/{recipeId}`) — no
  top-level `match /recipes` in rules. Confirm any server collection path
  from firestore.rules + the repository mixin, never an incidental
  `collection()` call; a test fake not mirroring the real layout makes a
  path bug structurally invisible.
- Unbounded collection-group folds use `.aggregate({count, average})`,
  never `.get()`. A `collectionGroup` equality query needs a
  `fieldOverrides` entry with `queryScope:"COLLECTION_GROUP"` — auto
  single-field indexes are COLLECTION-scope only, and the emulator hides
  the prod `FAILED_PRECONDITION`. `average(f)` skips non-numeric `f`
  silently.
- A recompute gate for a status-flip aggregation must be a full
  membership-XOR (`wasCounted !== isCounted ⇒ recompute`), not a
  before/after-is-X-only check — an asymmetric gate lets one direction
  (e.g. demotion) go stale until an unrelated future event.
- **When detecting a state TRANSITION via immutable history, also check
  whether the DESTINATION state already exists and skip if so** — else the
  "transition happened" signal re-fires on every subsequent touch, not
  just the transition.
- A shared derivation helper gaining a new returned/stamped field needs
  EVERY importer's write shape reconciled in the same change — a sibling's
  non-merge `.set()` can silently STRIP a field the primary path stamps.
- A second debounced aggregator sharing the queue infra needs only a
  distinct marker-collection + log-prefix adapter, never a fork.
  Claim-by-delete before aggregating; the aggregation itself should be a
  full re-read + `set(merge)` so a marker-race double-run is safe.
- One-shot backfills: persist the resume cursor; use TWO cursors
  (`lastFetched` drives the query, `lastProcessed` drives the resume value)
  when a per-batch cap can stop mid-fetch — a single cursor plus a
  skip-if-identical count can stall forever above a few thousand docs.
  Collect a batch's writes into ONE `commit()` after the loop so a
  mid-loop throw leaves zero partial writes.

### Verify-signup-age, account callables & minor-safety triggers
- Abuse/IP caps on account-gate callables fail CLOSED (some notification
  gates fail OPEN — don't harmonize). Compute a response-only derived
  field ONCE before any branch so it's in scope on every exit path,
  including an idempotent-retry branch.
- Trace the actual CONSUMER (client/rules read path) of a "protection
  default" before trusting a write accomplishes it — a default-private flag
  taking effect only on a LATER write (not the initial one) leaves a real
  window unprotected.
- **Rules can't iterate an array field (`participantIds`) to enforce a
  per-member rule for GROUP-shaped data** — needs a companion
  `onDocumentCreated` trigger as backstop, with the create RULE binding any
  client field the trigger trusts (e.g. `metadata.creatorId`) to
  `request.auth.uid` — else the tampered-client adversary the trigger
  targets can spoof the field it trusts.
- **A new `onCall` export is a TWO-FILE change**: the function AND
  `app-check-enforcement.test.ts`'s classification. `ADMIN_EXEMPT` is
  justified iff the handler's FIRST statement is `requireAdmin(request)` (or
  `token.admin===true`) — App Check attests the app binary, the admin claim
  attests the caller; orthogonal threats. A callable reachable by an
  ordinary user belongs in `USER_FACING` with `enforceAppCheck:true`, never
  `ADMIN_EXEMPT`. (The guard's regex matches multi-line declarations, so a
  miss is always a RED suite — but it still recurs.)
- A rules hard-deny paired with an Admin-SDK escape-hatch callable needs
  its CLIENT-SIDE SERIALIZER audited too — enumerate every call site of the
  model chokepoint (e.g. `toFirestore()`) that could re-trigger the deny'd
  default; one compensating re-call at one site is leaky when the
  reverting logic lives in a shared method with other callers.

### TS↔Dart parity twins (canonical-pool-key.ts et al.)
- With no `u` flag, `\w`/`\b` are ASCII-only in BOTH Dart and JS — fold
  å/ä/ö→a/o FIRST, then run boundary regexes; adding the flag on one side
  breaks parity. Default sorts are UTF-16 ordinal in both; sha256 hex is
  lowercase in both.
- Module-scope `/g` regexes are safe with `.replace` but stateful
  (`lastIndex`) with `.test()`/`.exec()` in long-lived CF isolates.
- Validate `typeof === "string"` in the calling CF, not the pure helper —
  a malformed doc's TypeError inside a trigger becomes a retry storm.
- Shared word/heuristic lists: compiled-in consts pinned by JSON-fixture
  parity tests on BOTH sides — never a runtime JSON load (tsc doesn't copy
  `.json` under `src/` into `lib/`; a runtime read crashes the deployed fn).

### LLM prompts & prompts-config
- Compiled-in prompt edits are INERT while a valid Firestore `system/
  prompts` override doc is live — a prompt change ships WITH a matching
  prod-doc update (or verified absence) as an explicit deploy step.
- A new Firestore-backed prompt field must be OPTIONAL with per-field
  fallback, never added to a required-keys set — that validation is
  all-or-nothing; a new required key reverts EVERY live override doc to
  fallback on deploy.
- Mirroring a prompts-config field touches ~5 sites (doc-shape docstring,
  interface, fallback builder, required-keys set, remote-doc validator) —
  grep every test fixture constructing the doc, or a stale fixture flips to
  fallback and passes vacuously.
- A new/edited `*_SYSTEM_PROMPT` const trips the prompt-changelog CI guard.
  N prompts sharing ONE response schema: a behavioural instruction added to
  only one is a latent gap in the others — extract a shared const,
  interpolated into all, verified byte-identical.
- Best-effort/never-throw helpers must resolve `admin.firestore()` INSIDE
  the try — a default-param `= admin.firestore()` evaluates BEFORE the
  try/catch and escapes the guard.

### Ingredient sync, allergen data & admin exports/ETL (admin/ family)
- `admin/` scripts run `admin.initializeApp()`+`main()` at import — extract
  pure cores for testing; idempotency/region/retry N/A (manual ts-node).
- List-split regexes must stay in lockstep across every field they're
  applied to — hoist to one shared const. Only the SWEDISH-derived alias
  list feeds allergen-lookup `normalizedNames`; other alias fields degrade
  search recall at worst, never a verdict — that scoping is what makes
  extending their split safe without the xhigh data-writing review gate.
- Normalization parity must hold across every matching surface (sync
  stamp, server hold-gate, Dart client) or an ASCII alias can pass server
  but fail client-side match — re-diff all three on any normalizer change.
- The allergen-property lockstep triple (sync valid-properties list,
  shared allergen-relevant list, Dart trigger-property list) has no
  automated pin — re-diff by hand when touching any of them.
- Confirm-gated scripts: the human-review diff writes BEFORE the
  confirmation prompt; an executed-marker audit row writes AFTER the final
  commit, never before. Hold-state machines use an ALLOWLIST
  (`status==="pending"`), never a blocklist — terminal states leak through
  a blocklist.
- For any export/mining script: verify FIELD PARITY name-for-name against
  the writer's capture call (classic bug: a near-miss field name, or the
  wrong timestamp field). Highest-value test: a PRIVACY WHITELIST assertion
  — seed adversarial raw PII-shaped fields and assert the exported key set
  is EXACTLY the allow-listed set.
- A writer truncating a field at N chars BEFORE downstream line-splitting
  can hand an ETL pipeline a truncated PARTIAL final line as complete —
  a stored `truncated:true` flag is the honest signal (`length===N` alone
  can be wrong if a later scrub shifts the length).
- In `set -euo pipefail` bash, a step that can legitimately return nonzero
  (`grep` finding nothing) needs `|| true`/`|| echo`, or `set -e` kills the
  script before a `${VAR:-default}` fallback runs.
- An unordered dedup query has a NONDETERMINISTIC winner among collisions —
  add `orderBy(FieldPath.documentId())` if "deterministic output" is claimed.
- Unifying N hand-synced copies of one vocabulary into a shared module:
  verify SET equality before re-exporting, and pin ALL copies with a
  deep-equals tripwire — a copy marked "deferred" drifts until it's pinned.

### CI / test wiring / ops
- Post-deploy smoke: `firebase functions:list --json` + a fixed-string
  grep of stable representative function names — `firebase deploy` exiting
  0 does NOT prove functions are callable (a function can land
  `DEPLOY_FAILED`); only a control-plane query after deploy does.
- A Firestore TTL field is INERT without the matching `gcloud firestore
  fields ttls update` policy actually applied — demand the runbook entry.
- Data-writing/deleting CFs get an adversarial multi-finder review before
  commit — a single-specialist gate has endorsed a dead-on-arrival
  collection path before; necessary but not sufficient alone.
- Verify an index-to-query mapping stated in a commit message against the
  ACTUAL queries in the actual files — a commit has misattributed an index
  to the wrong file before.
- **Review the STAGED copy (`git show :<path>`), not only the worktree.** A
  `MM` file means the index is older than the fix under review, so `git commit`
  ships the version the review just rejected — `account-deletion-cascade.ts`
  sat `MM` with the abort-early regression in the index while the worktree held
  the accepted fix. Diff both, and say which one you reviewed.

### When to consult the archive
Grep `cloud-functions-specialist.knowledge.archive.md` (not this file) for:
- A Gen1→Gen2 deploy conflict, or a `DEPLOY_FAILED`/"function not found"
  incident — exact error strings + fleet-scoping reasoning live there.
- A PII-scrubber regex misfiring on a specific Swedish word/name — regex
  history, fixture vectors, negative-vector list live there.
- Debugging/extending a specific ticket (BUT-XXXX in code/git log) — the
  full review narrative, incl. earlier wrong turns, is there.
- Why an accepted residual/tradeoff was decided the way it was — the
  reasoning chain is there; this file keeps only the resulting rule.
- Whether a specific test file/script/config value existed at some past
  date, or a suite's historical pass count.
