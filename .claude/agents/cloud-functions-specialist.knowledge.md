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
| `social/` | Profile propagation across user trees | onDocumentUpdated | `test:on-profile-updated` (verified 2026-07-30; NOT `test:profile-updated`), `test:set-profile-searchability` |
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
  everywhere a raw uid would sit near other identifying fields. CLOSED
  2026-07-30 after FOUR reports: `compute-feature-retention.ts`'s
  `feature_retention_probe_failed` now emits
  `{flag, userIdHash, errCode, errName}` and its comment forbids re-adding
  `err.message` (Firestore error text carries `users/<raw uid>/…` paths and
  `create_composite` URLs). That is the canonical shape for any probe warn —
  and the way to ARGUE such a finding is to run the suite, because
  `npm run test:compute-feature-retention` PRINTS the log line in its own
  PASSING output. Never argue a log-shape finding from source alone.
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
  deliberately before trusting a green wrapper suite. The recurring form:
  ONE failure code emitted from TWO branches. `check-test-registration.js`
  raises `RULES_TRIGGERS` both for "block lists no test files at all" and for
  "this chained suite is missing from the block"; the fixture set the other
  trigger to `["firestore.rules"]` (zero test entries), so it exercised the
  wrong branch and `if (!matchesAny(...))` → `if (false)` left the suite
  **14/14 green**. Rule: build the fixture so only the targeted branch CAN
  fire, and assert on branch-unique message text, not the shared code. A
  criterion is pinned only when you have watched it go red.
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
- **Rules are not filters, so a client query built with NO condition is DENIED
  wholesale on a member-scoped collection** — the symptom of a no-op client
  filter (`isNotEqualTo: null` builds no condition: `cloud_firestore`
  `query.dart` guards every operator with `if (arg != null)`; `isNull:
  false/true` is the working spelling) is "the screen will not load", never an
  over-share. That branch is provable ONLY on the emulator rules lane —
  `fake_cloud_firestore` evaluates no rules, so a Dart unit test proves the
  filter shape and says nothing about the server's verdict. Pin all three:
  filtered query allowed + returns rows, UNFILTERED query denied, filtered
  query by a non-member allowed-and-empty.
- **The rules emulator KEEPS data across `npm run` invocations, so a later
  test's seeded foreign doc leaks backwards into any actor-scoped
  expect-empty assertion.** An "actor is a member of nothing" fixture must use
  a uid no other test ever seeds (`list-nobody-uid`), not a `STRANGER`
  constant another test makes an owner. Per-run doc-id tokens fix create
  collisions only — and they are what makes the collection GROW ~3 docs a run.
  So a QUERY deny test whose denial rests on one unreadable doc being inside
  `.limit(N)` has a shelf life, and it is COMPUTABLE — enumerate the corpus,
  find the unreadable fixture's `__name__` position, divide the remaining window
  by the per-run growth. `unified_shared_shopping_lists` (still unfixed as of
  2026-07-30): 56 docs after 9 runs, +3/run (`create-{seat,absent,at-cap}-<RUN>`;
  the deny-side creates persist nothing), order `create-*` < `del-editor` <
  `query-foreign` < `query-mine` < `read-*`, and every `create-*` doc IS readable
  by the querying actor — so the sole unreadable doc sits at ~29 of a `.limit(200)`
  window and SSL38's `assertFails` flips red in ~57 more runs (red, not a false
  green). Give the unreadable fixture a doc id that sorts FIRST (`00-query-foreign`),
  or drop the limit — never rely on `__name__` order against a growing corpus. Verify
  the corpus with `curl -H "Authorization: Bearer owner"
  "http://127.0.0.1:8080/v1/projects/<pid>/databases/(default)/documents/<col>"`
  — without that header the REST read is rules-evaluated and 403s.
- **A fix living in the I/O wrapper / handler-level gate can't be pinned by
  a pure-core unit suite.** Check which side of the pure-core/handler seam a
  fix landed on before crediting a suite with covering it. A test asserting
  on a literal built in the test file, or on an input pre-transformed the
  same way the SUT would, tests the fixture, not the code.
- **A fake whose `commit()` RE-DERIVES the intended effect instead of
  APPLYING the recorded write payload makes the whole write vacuous.** The
  sentinel is not actually opaque: `FieldValue.arrayUnion(...)` is an
  `ArrayUnionTransform` whose `elements` is a PUBLIC own property and whose
  `isEqual` works with no initialized app (order-sensitive) — so a double can
  apply the payload it was handed and throw when the shape is unrecognised,
  instead of recomputing the intended effect. Pair that with an explicit
  `sentinel.isEqual(FieldValue.arrayUnion(...expected))` assertion: field name,
  sentinel type and value set all pinned at once. Any hand-rolled
  batch/transaction double.
- **Mutating a `Collections.x` reference to a bare literal to prove a test
  non-vacuous can break the BUILD instead** (the import goes unused →
  `noUnusedLocals` TSError, which reads as a red suite for the wrong reason).
  Keep the symbol referenced: `.collection(Collections.x ? "old_name" : "y")`.
  Verified on BUT-1724 — the first mutation attempt produced a TSError, the
  reworked one reddened exactly the one targeted test. Same trap on a
  destructured `Promise.all` result: deleting a leg from the OR it feeds
  (`shopped: a || b` → `a`) orphans `b` and yields the same TSError; neutralise
  instead (`[b].length > 99 ? true : a`).
- **A fake query whose `.where()` ignores the FIELD ARGUMENT pins the
  collection but not the field, and a paired "the composite is declared in
  `firestore.indexes.json`" test does NOT close the gap** — it pins the INDEX
  side of the pair while the QUERY side stays free to drift, which is the
  silent-zero bug class itself. Measured on BUT-1761: swapping the new probe's
  `.where("lastActivityByUserId","==",uid)` for `ownerId` left
  `compute-feature-retention` 11/11 GREEN, though in production it matches no
  declared composite → FAILED_PRECONDITION → swallowed by `safeProbe` → the
  flag re-zeroes. (The COLLECTION name IS pinned when the fake's
  `collection()` throws on an unmodelled name — keep that branch.) Fix the
  fake: record the equality/range field names on the query object and throw on
  an unexpected one, or assert them in the index test alongside the JSON.
- **Refactoring a fan-out helper from a collection NAME to a
  `CollectionReference` couples its legs inside any hand-rolled Firestore
  double whose `.where()/.orderBy()/.limit()/.startAfter()` MUTATE and return
  `this`** — real Firestore returns a fresh immutable `Query`, `db.collection(x)`
  called twice did not. `paginatedDualUpdate` (BUT-1724) receives ONE ref and
  calls `.where()` on it twice, so a mutating `makeFakeDb` had the second call
  overwrite the first's predicate — passing only because `async get()` has no
  `await` before it filters, so leg A's first page was captured synchronously
  before leg B mutated; leg A's SECOND page would have used leg B's predicate.
  CLOSED 2026-07-30: `on-profile-updated.test.ts`'s `makeQuery` now threads an
  immutable `QueryState` and returns a NEW query from every builder call. Fix
  the double, never the SUT. Residual: still no `>BATCH_LIMIT` dual-field
  fixture, so the dual-field writer is proven CORRECT but not proven PAGED.
- **A mutation applied by string-replace against a CRLF worktree file silently
  no-ops** — the replace returns the input, the suite stays green, and you
  write up "criterion unpinned" about a mutation that never happened. Every
  mutation harness must assert `s.includes(target)` and `out !== s` (match on
  LF after `raw.replace(/\r\n/g,"\n")`, restore endings on write), and finish
  with an md5 check that the source is byte-identical again. A mutation whose
  reds are all in OTHER tests is also suspect: check it failed for the intended
  reason (keying a `Map` on `ref.id` when the fake's ref carries `__id` broke
  five unrelated tests and left the targeted one green).

### PII scrubbing + GDPR cascade design
- Cross-port heuristic vectors (TS↔Dart) live in one shared JSON fixture;
  the "Dart copies this" note goes in a `_header` field.
- **PROMOTING a per-section field to the ROOT of an Art. 15 bundle changes its
  blast radius, so the root value must be DERIVED, never copied.** A chokepoint
  aggregator cannot tell an authored sentence from an `e.toString()`, and a raw
  Firestore string carries another data subject's uid (composite doc ids like
  `blocks/<uid>_<otherUid>`), a `create_composite` URL embedding the project id +
  a `memberPermissions.<uid>` field path, or internal collection paths.
  `data_export_service.dart` now builds `warnings[].message` itself and defaults
  `error_code` to `'<section>-export-failed'`, which also stops a NEW manager
  going silent at bundle level by forgetting the token. Two corollaries: an
  aggregator keyed on `error_code` ALONE misses every section that fails with
  `{'error': …}` (most of them), so a whole missing section reported the bundle
  complete; and defending at the chokepoint does NOT clear the SECTION body —
  `content_export_manager.dart` (12 sites) and `preferences_export_manager.dart`
  (10) still `return {'error': e.toString()}` INSIDE the exported artifact
  (open as of 2026-07-30). A completeness walk over the bundle must also handle
  a flag nested in a LIST (`messages.conversations[i].messages_truncated`) —
  iterating `value.values` and requiring each to be a Map silently skips it.
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
  probes, Dart repo constants). The `unified_shopping_lists` rename sweep is
  CLOSED as of BUT-1724 (last two readers: the `shopped` probe in
  `analytics/compute-feature-retention.ts` and `on-profile-updated.ts`'s
  personal-list leg). `shopping_lists` now survives only as DELIBERATE legacy
  safety nets (`account-deletion-cascade.ts`, `admin/reset-user-data.ts`) plus
  one Dart negative-assertion test — don't re-file those as dead reads.
  Corollary for any dead-read fix on an ANALYTICS probe: the stored history
  keeps the structural zeros, so a rollup that ORs prior per-day flag docs
  (`compute-feature-retention`'s wau7d/wau28d) ramps in over its whole window
  after the fix; say so in the write-up instead of letting the dashboard read
  as a launch. The shipped BUT-1724 docstring documents the two `shopped`
  coverage gaps (collaborative lists BUT-1761, item ticks BUT-1762) but NOT the
  28-day ramp-in, so the only warning a dashboard reader gets is this file —
  add it to the docstring/deploy note the next time that file is open.
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
- **Anonymizing a CHILD collection is not done until the PARENT's
  denormalised preview copy and its per-uid MAP fields are scrubbed too, and
  the cheapest way to enumerate them is to read what the Art. 15 EXPORT
  already redacts about OTHER people.** Whatever the export must hide about a
  third party on a doc, the cascade must erase about the departing user on the
  same doc. CLOSED 2026-07-30 (BUT-1766/BUT-1768, 26/26 green): the GROUP leg
  now does one `update()` per conversation covering `participantIds`,
  `participantDisplayNames.{uid}`, `participantAvatarUrls.{uid}`,
  `lastReadTimestamps.{uid}`, `perUserSettings.{uid}` AND a `lastMessage.*`
  tombstone (only when `lastMessage.senderId === uid`) — `messages.metadata`
  and `reactions` are still open gaps, not covered by this pass.
  `deleteRealtimeMenus`/`deleteRealtimeRecipes` got the same treatment
  (`scrubLastEditor` + `removeRealtimeParticipation` + child-subcollection
  sweep via `deleteRealtimeDocsWithChildren`) and `realtime_menus` got a tier
  entry for the first time ever.
- **A cascade write built from a QUERY-TIME snapshot and applied via a plain
  (non-transactional) `.update()` is a lost-update hazard against the exact
  thing a "realtime"/collaborative surface exists to do: a concurrent edit by
  a DIFFERENT, non-deleted user.** A literal-value field overwrite decided from
  a stale read is the tell; an atomic op (`arrayRemove`, `FieldValue.delete()`)
  needs no fix, since Firestore applies those against the live document
  regardless of what was read. CLOSED 2026-07-30/31 for both instances found in
  the BUT-1766/1768 diff: `buildGroupDepartureUpdate` (the `lastMessage.*`
  tombstone) and `scrubLastEditor` (`lastEditedBy`/`lastEditedByDisplayName`)
  now each wrap their write in `db.runTransaction`, `tx.get()` the doc fresh,
  skip on `!fresh.exists`, and derive every literal-value field from `fresh`
  only — the outer query's `convoDoc`/`doc` snapshot is used for `.ref` alone,
  never `.data()`, which is the structural proof the fix is real (grep for a
  literal-value field sourced from the outer snapshot inside a
  post-transactional-rewrite step; finding one is the regression). `scrubLastEditor`
  additionally re-checks `lastEditedBy === uid` inside the transaction before
  writing — the query-time membership can go stale the same way `lastMessage`
  did. Real Firestore transaction semantics (auto-retry on a conflicting write
  to a doc read inside the transaction) close the race for both; this is proven
  by code inspection against documented SDK behaviour, not by the test suite —
  **the hand-rolled `FakeFirestore.runTransaction` passthrough (`get`/`update`
  hit the same in-memory store as everywhere else, no isolation, no retry,
  single-threaded so nothing can interleave) cannot simulate an actual
  concurrent writer, and says so in its own docstring.** The 26/26 green suite
  is real evidence for a different, still-valuable property — that the
  transaction-wrapped code computes the SAME correct scrub/tombstone values as
  before (no regression in the field-path/FieldValue-marker logic) — not for
  concurrency-safety itself. Don't let a green suite substitute for the code-read
  when reviewing a *future* transactional fix in this file; check `fresh` vs the
  outer snapshot by eye every time.
- A batch built from a query snapshot that reaches `batch.update()` on a doc a
  DIFFERENT actor concurrently deleted fails the WHOLE chunk (up to 500 docs)
  with NOT_FOUND, silently, under `commitInChunks({strict:false})` — the
  merged-batch abort rule applies to a uniform batch of updates, not only a
  mixed delete+update batch. `probeResidualData` is the backstop IF the
  scrubbed field is itself probed (`realtime_menus.lastEditedBy`/
  `.participantIds` are; the `participants.{uid}` MAP KEY is not, by design —
  unqueryable). Low real risk here specifically (a user's realtime-doc
  participation count is small), but the failure mode is silent, so say so in
  review rather than assuming the probe always catches it.
- **Rules are not filters on the DELETE path either: a CLIENT-side cascade can
  only query on the field the read rule authorizes.** `match /messages` grants
  read via `get(conversations/$(resource.data.conversationId)).data
  .participantIds`, so a client `where("senderId","==",uid)` list over the whole
  collection (a) is denied wholesale the moment one matched doc sits in a
  conversation the user has LEFT, and (b) blows the rules limit of **10
  `get()`/`exists()` access calls per query request** as soon as the matches
  span >10 distinct conversations (identical paths are cached, so a
  `where("conversationId","==",x)` read costs exactly 1 and is fine).
  `fake_cloud_firestore` evaluates no rules, so a Dart unit test asserting
  "messages in a conversation the user already LEFT are still deleted" is green
  and meaningless. Only the Admin SDK can key an erasure on the sender.
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
  when it is a user SUBCOLLECTION updates zero docs, silently — and still bills
  a read per pass. **The shape that HIDES it is a shared fan-out helper
  parameterized by collection NAME** (`db.collection(name)` inside), which
  cannot express a subcollection at all; make such a helper take a
  `CollectionReference` (BUT-1724 fixed `paginatedDualUpdate` that way) and the
  bug becomes unwritable. A `collectionGroup` fix instead needs `fieldOverrides`
  with `queryScope:"COLLECTION_GROUP"`; a per-user subcollection query does NOT
  (auto single-field indexes cover equality + `__name__` ASC per collection ID —
  verify no `fieldOverrides` exemption exists for that id).
- **PROPAGATION coverage is not ERASURE coverage — they are two separate
  tables, and a docstring that says "the CF maintains this copy and account
  deletion scrubs it" is asserting BOTH.** Grep the collection in
  `on-profile-updated.ts` AND in `account-deletion-cascade.ts` /
  `request-account-deletion.ts`'s step table before letting such a sentence
  stand (CLAUDE.md's "a decision record that asserts something about code has
  an expiry"). Live asymmetry as of 2026-07-30: `on-profile-updated.ts:143`
  propagates owner + last-editor names to BOTH `realtime_recipes` and
  `realtime_menus`, while the cascade has only `deleteRealtimeRecipes`
  (`ownerId == uid`) — `realtime_menus` appears nowhere in either account file,
  and neither collection scrubs a `lastEditedBy*` stamp the deleted user left on
  SOMEONE ELSE's doc. Fix shape: a `deleteRealtimeMenus` twin plus a
  `lastEditedBy == uid → lastEditedByDisplayName: null` scrub leg on both, each
  with its own `probeResidualData` leg. The asymmetry also runs the OTHER way,
  and shopping lists were the live case: the cascade scrubbed ITEM-level
  `addedByDisplayName`/`lastModifiedByDisplayName` while `on-profile-updated.ts`
  updated only the LIST-level `ownerDisplayName`/`lastActivityByDisplayName`, so
  a rename left every "X la till mjölk" row showing the old name forever.
  BUT-1770 closed it (2026-07-30) and the CLOSING SHAPE is the reusable part:
  `collectionGroup("items").where("addedByUserId"|"lastModifiedByUserId","==",uid)`
  through `batchUpdateQueryPaginated`, plus a per-list transaction for the
  EMBEDDED `items` ARRAY on `unified_shared_shopping_lists` (an array element's
  field is neither queryable nor patchable — read-modify-write, and rewrite only
  the rows whose own `*ByUserId` is this uid, or you stamp your name on someone
  else's row). `items` is a shopping-only collection id — the ONLY `match /items`
  blocks in `firestore.rules` are `users/{uid}/unified_shopping_lists/{listId}/items`
  and `shared_content/{contentId}/items` — so the collection group has no
  cross-feature blast radius; re-verify that before adding a third leg. Whenever
  a leg reasons about "which stamps must move", check the DOC MODEL's full
  {uid, displayName} pair set, not the stamps the leg already knows about.
  **The residual, and the general rule: a rename leg and an erasure leg over the
  same docs must use the SAME scoping union, and a docstring claiming they do is
  checkable in 60 seconds.** BUT-1770's embedded-array leg scopes on
  `contributorUserIds` array-contains ALONE while `deleteShoppingLists`
  (`account-deletion-cascade.ts:571-588`) unions FOUR queries over that same
  collection — `memberPermissions.{uid}`, `ownerId == uid`,
  `contributorUserIds array-contains uid`, `lastActivityByUserId == uid` — dedup'd
  into one `Map<docId, ref>`, precisely because membership/ownership/activity are
  each things a user can stop having while their name stays on the doc. The
  rename leg's own docstring asserts "the deletion cascade uses the same handle
  for the same reason", which is false; the gap is pre-BUT-1725 rows on lists
  never touched since (the trail is unioned by the client on every item write,
  and `backfillSharedListContributors` is the shape that cannot finish above its
  scan cap). Copy the cascade's four-query union + dedup, don't re-derive.
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
  residual count, never abort the cascade. **A new probe leg dropped INSIDE an
  existing `try` shortens every leg after it** — one transient error on the new
  query now also skips the legs it was inserted above (BUT-1725 put two legs in
  front of the sole-member-orphan leg). Give each independent leg its own
  try/catch, or append rather than insert.
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
  a comment is not enforcement. The working shape (BUT-1692): `export` the
  callable's cap (`MAX_BATCH_NOTIFICATIONS`) and assert it equals
  `RATE_LIMIT_CONFIGS.<op>.maxTokens` in `rate-limiter-daily-cap.test.ts`,
  alongside a second assertion that the split bucket's `refillRate`/
  `refillIntervalMs` equal the single-item bucket's — else batching becomes
  the cheap sustained path. Also state the COMBINED ceiling when a second
  bucket is split off an existing one: separate buckets are ADDITIVE, so
  "same budget either way" is only true per-path.
- **Standalone callables use `enforceRateLimit`, not bare `checkRateLimit`**
  — only the former writes the `system_events` `rate_limit_violation` row
  via `logRateLimitViolation`. A bare `checkRateLimit` + hand-thrown
  `resource-exhausted` silently drops the abuse telemetry, which is usually
  the whole point of the ticket adding the gate. `notifications/` was the
  outlier; BUT-1692 converted `sendNotificationBatch` (SHIPPED — the docstring
  now names the remaining gap explicitly, so the earlier over-claim is
  closed), so the remaining one is `sendNotification` single-send
  (`send-notification.ts:91-97`, still bare `checkRateLimit` + local throw as
  of 2026-07-30) — a diff that fixes one path must not claim in prose that the
  family now leaves a trace. A seam typed
  `enforce?: typeof enforceRateLimit` type-pins the production default: TS's
  void-return bivariance does NOT reach through `Promise`, so
  `Promise<RateLimitCheckResult>` is NOT assignable to `Promise<void>`
  (verified with `tsc --strict`) and a silent revert to `checkRateLimit`
  cannot compile. But the TYPE pin is not a BEHAVIOUR pin: a lambda that
  calls `checkRateLimit` and throws `resource-exhausted` locally satisfies
  the seam type, throws the SAME code, and drops the audit row — measured,
  `thrown=resource-exhausted auditRows=0`. So every seam-injected case stays
  green and only a case passing NO `enforce` catches it. Pin the default with
  a case that asserts the ROW: drive the real enforcer against an exhausted
  bucket via `__setFirestoreForTest` and assert exactly one
  `system_events` doc with `type:"rate_limit_violation"` and the right
  `operationType`. SHIPPED 2026-07-30 and green (19/19), but it needed
  `logRateLimitViolation` switched from `admin.firestore()` to the seam's
  `getFirestore()` first — the audit write was otherwise observable only on a
  live emulator, which is exactly why the batch path first shipped unasserted.
  **A deny asserted through a fake db cannot tell deny-by-bucket from
  `checkRateLimit`'s fail-closed `catch`** (a fake that throws also yields
  `allowed:false` → the same row, same `operationType`, so the case passes for
  the wrong reason): disambiguate on the row's `retryAfterMs` —
  `intervalsNeeded * refillIntervalMs` (60000 for a 10-token
  `sendNotificationBatch` deny; measured `remainingTokens: 0.0005`) versus the
  fail-closed 30000. The SHIPPED case does not assert `retryAfterMs`; it stays
  honest only because its fixture is a well-formed zero-token bucket, so treat
  "fake throws → same row, still green" as live technical debt. Reviewing the
  `admin.firestore()`→`getFirestore()` swap itself: production is byte-identical
  (`firestoreForTest` is null → `admin.firestore()`) and no non-test file calls
  `__setFirestoreForTest` — grep that before rating the swap, it is the whole
  question of whether an audit row can land in the wrong place. That seam covers
  only the per-user bucket +
  `logRateLimitViolation`; `getGlobalLimits`/`checkGlobalLimit`
  (`rate_limiter.ts:516,563-564`) still call `admin.firestore()` directly, so
  a fake db injected through it does NOT intercept them. `system_events` has
  no TTL policy or cleanup job, so every newly-enforced callable adds an
  unbounded write-per-denial stream — cheap, but say so, and note that
  `retry_helper.dart:286` treats `resource-exhausted` as RETRYABLE, so a
  future Dart caller multiplies the rows per denial.
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
- **A backfill that RECONSTRUCTS a value from fields still on the doc must
  exclude every field the erasure cascade DELIBERATELY RETAINS, not just the
  sentinel it writes.** Excluding the `"deleted"` sentinel and `null`s is the
  obvious half; `ownerId` on `unified_shared_shopping_lists` is the trap — the
  cascade keeps it raw on purpose (rules read it for write authorization), so
  a reconstruction that adds it re-creates a deleted user's identifier in a
  NEW field. Gate on a handle the cascade actually clears (owner present in
  `memberPermissions`), not on the retained one. Worse once the field is
  made APPEND-ONLY in `firestore.rules` (BUT-1725 did exactly that): the
  re-created uid is then removable by no client write and by no future
  cascade run (that user's cascade already completed) — only by an admin
  script. Check the rule before rating a resurrection finding as merely
  cosmetic. The discriminator to gate on is the handle the cascade CLEARS: the
  create rule pins a live owner into `memberPermissions` and the cascade
  deletes that key, so `hasOwnProperty(memberPermissions, ownerId)` separates
  live from erased. A fixture feeding the SENTINEL into the retained field
  (`ownerId: "deleted"`) proves nothing — the sentinel is written for item
  `addedByUserId`/`lastModifiedByUserId` only; assert the shape the cascade
  actually leaves. Re-flagged unfixed on a second review pass: verify a
  resurrection finding against the FINAL staged bytes, never against the
  earlier pass's write-up.
- **A full-collection `orderBy(documentId()).limit(N)` backfill with NO filter
  cannot self-advance across invocations** — already-migrated docs stay
  matched and burn the per-invocation scan cap, so run 2 rescans run 1 and
  `hasMore` never reaches false above the cap. That shape needs an
  operator-supplied `startAfter` in the request + a `nextCursor` in the
  response (`backfillCanonicalRatings` is the correct precedent;
  `backfillRecipeCommentsDenorm` and `backfillSharedListContributors` share the
  defect — don't copy either). A filter-mutating sweep is the only shape that
  may skip the cursor. Measured (`backfillSharedListContributors`, 23×450 cap,
  corpus 20,000): run 1 stamps 10,350, runs 2–3 re-read the SAME docs
  (`migrated 0, skipped 10350`), 10,351+ never reached, every run still
  `success: true` — structurally unfinishable, not a cosmetic nag. Two things get
  dropped when the shape is copied without the cursor: (a) an explicit
  `reachedEnd` flag set at EVERY exhaustion break — inferring completion from
  `batchesProcessed >= MAX` reports `hasMore: true` exactly when the final
  allowed batch was a SHORT page, i.e. when the corpus IS done, so a "delete this
  file once a run returns `hasMore:false`" lifecycle gate never opens;
  (b) NOT_FOUND handling on the 450-op
  `batch.update()` — one doc a client deleted between the page read and the
  commit aborts all 450 (catch grpc code 5, fall back per-doc). A
  `maxLists`-style cap tested only between batches is a SOFT cap: with
  `maxLists:10` the run still processes the whole 450-doc page — don't document
  it as a hard ceiling. A snapshot-read + blind-`arrayUnion` backfill also races
  a concurrent cascade: the page read before the cascade commits re-adds uids it
  just removed. Fix shape (BUT-1725): drop the 450-op batch entirely and give
  each doc needing a write its own transaction that RE-DERIVES the write set
  from the fresh read — the cascade's anonymised items then yield an empty set
  and nothing is written. This also dissolves the grpc-5 batch-abort problem
  (`if (!fresh.exists) return "raced"`). It costs one extra read per written
  doc and nothing at all on re-runs, but 450 sequential transactions per page
  will not fit a 540s budget: run them through a small concurrency pool (25),
  counting `written`/`raced`/`failed` and returning `success: failed === 0`
  rather than aborting the page.
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
- **A new `onCall` export is a THREE-FILE change**: the function, its
  `test:*` script + `__tests__` suite in `package.json`, AND
  `app-check-enforcement.test.ts`'s classification. `ADMIN_EXEMPT` is
  justified iff the handler's FIRST statement is `requireAdmin(request)` (or
  `token.admin===true`) — App Check attests the app binary, the admin claim
  attests the caller; orthogonal threats. A callable reachable by an
  ordinary user belongs in `USER_FACING` with `enforceAppCheck:true`, never
  `ADMIN_EXEMPT`. (The guard's regex matches multi-line declarations, so a
  miss is always a RED suite — but it still recurs, most often on a new
  `migrations/` backfill; `CI_EXCLUDE` is empty, so the miss reddens the real
  CI lane. `check-test-registration.js` will NOT catch it: that script only
  checks that EXISTING test files are registered, so a source file shipped
  with no test at all passes it silently. Grep the new callable's name in
  `app-check-enforcement.test.ts` + `package.json` as step one of any review
  that adds an export to `index.ts`.)
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
- **A sentinel default that fixes a non-determinism must be ROUND-TRIP STABLE
  through Firestore, or the fix only narrows the window.** Dart's
  `DateTime.==` compares `isUtc` as well as the instant (measured:
  `DateTime.utc(1970) == DateTime.fromMillisecondsSinceEpoch(0)` is **false**
  while `isAtSameMomentAs` is true), and `Timestamp.toDate()` returns a LOCAL
  `DateTime` — so a UTC sentinel written by `toFirestore()` comes back
  non-equal to itself. BUT-1755 (`UnifiedShoppingList.unknownCreatedAt =
  DateTime.utc(1970)`) hits this: the value IS persisted, by
  `mutateCollaborativeList`'s `transaction.set(mutated.toFirestore(),
  merge:true)`, which ships every field. Any client-side equality gate over a
  parsed timestamp (`ShoppingListPermissionGuards.requireNoPrivilegeEscalation`)
  must use `isAtSameMomentAs`, never `!=`. Same class: a second parse entry
  point left on the old fallback (`fromJson` still defaults to `clock.now()`
  where `fromMap` now uses the sentinel) — grep EVERY factory, not just the one
  the ticket names.

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
- `reset-user-data.ts`'s `CollectionTarget.subcollections` is DOCUMENTATION
  ONLY — `deleteDocRecursive` discovers every subcollection at every depth via
  `listCollections()`, so a name absent from that list is still wiped. Never
  file a "data survives the reset" finding from a gap in it (BUT-1724 was filed
  on exactly that misreading); the list is still worth keeping honest as the
  shape a reader greps.
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
- **Before approving a new composite index, check for an EXISTING composite on
  the same two fields in the opposite orderBy direction — Firestore serves a
  query by scanning that index in reverse, so the "opposite direction" variant
  is usually redundant.** Caught on the BUT-1766/1768 diff:
  `firestore.indexes.json` already declared `messages` (conversationId ASC,
  sentAt DESCENDING) for `sync-conversation-last-message.ts`'s
  `.orderBy("sentAt","desc")`; the diff added a second entry, same two fields,
  sentAt ASCENDING — no query in the codebase orders that way, so it's a
  standing write-cost tax with zero query benefit. Contrast with a GENUINELY
  new requirement in the same diff: `unified_shared_shopping_lists`
  (lastActivityByUserId ASC, updatedAt ASC) for the new
  `compute-feature-retention.ts` collaborative-shopping probe — that one is
  correctly the collection's ONLY composite, so nothing to reverse-check
  against. Always grep the collection name in `firestore.indexes.json` for
  existing entries before rating a new composite as required.
- Data-writing/deleting CFs get an adversarial multi-finder review before
  commit — a single-specialist gate has endorsed a dead-on-arrival
  collection path before; necessary but not sufficient alone.
- Verify an index-to-query mapping stated in a commit message against the
  ACTUAL queries in the actual files — a commit has misattributed an index
  to the wrong file before.
- **Prove a lefthook glob by RUNNING it:** `npx lefthook run <hook> --command
  <name> --no-auto-install` (singular `--command`; `--commands` is not a flag).
  But in a LIVE worktree with dozens of unstaged files and nothing staged, that
  hiding step would stash the whole tree — too dangerous next to a parallel
  session. Read-only substitute that still proves the wiring: `npx lefthook
  validate` (config parses) + `npx lefthook dump | grep -A5 <job>` (the job's
  glob/run/priority as lefthook actually resolved them), then run the guard
  SCRIPT directly with a positive fixture and a comment-only fixture and check
  exit 1 / exit 0. That combination pins everything except the glob's file
  matching, which a proven sibling job with the identical glob covers.
  Lefthook HIDES unstaged changes for `pre-commit`, so the job sees the STAGED
  file set plus any UNTRACKED file still on disk — a parallel session's
  untracked WIP test can redden a guard that scans the working tree, and that
  is a real commit block, not a false alarm. `**/*.js` requires an intermediate
  directory (misses `functions/scripts/x.js`); `functions/scripts/**` matches
  both flat sources and `__tests__/`.
- **A new `tools/check_*.sh` lefthook guard is almost never wired into CI, so a
  documented zero-arg "CI / manual" mode in its header is usually DEAD code** —
  only 8 of them run in `architecture-validation.yml` (`check_null_filter.sh`,
  BUT-1746, is not one). Grep `.github/workflows/` for the script name and say
  whether the second mode has a caller: pre-commit-only means the guard never
  sees an UNSTAGED violation, which is exactly the state a parallel session's
  mutation leaves on disk. Second trap in the same script shape: a comment-skip
  filter anchored `^[^:]*:[0-9]+:` against grep's `path:line:` prefix BREAKS on a
  drive-letter path — measured, `check_null_filter.sh 'C:\...\x.dart'` reports all
  three WHY-comment lines as violations (exit 1) where the same file by relative
  path exits 0. Lefthook passes relative paths so it does not fire today; prove
  any such filter with BOTH a relative and an absolute-path fixture, and prefer
  an unanchored `:[0-9]+:[[:space:]]*(//|\*)`.
- **A guard's own CI registration is usually outside the guard's universe.**
  `check-test-registration.js` scans `functions/src/__tests__/` only, so
  deleting `test:script-coverage-report` + `test:script-test-registration` from
  `package.json` leaves it at exit 0 / "117 test files registered" while
  `run-ci-unit-tests.js` silently drops from 78 to 76 suites — and the
  `functions/scripts/**` pre-commit hook doesn't fire on a `package.json` edit.
  When reviewing a self-checking guard, ask what deregisters it, not just what
  it checks.
- **To review the staged set free of a parallel session's worktree edits:**
  `git archive $(git write-tree) | tar -x -C <scratch>` — `write-tree` touches
  no ref and no index. Run the guards there and say so.
- **Review the STAGED copy (`git show :<path>`), not only the worktree.** A
  `MM` file means the index is older than the fix under review, so `git commit`
  ships the version the review just rejected — `account-deletion-cascade.ts`
  sat `MM` with the abort-early regression in the index while the worktree held
  the accepted fix. Diff both, and say which one you reviewed.
- **A pass dispatched "re-review AFTER automated fixes" does NOT imply your
  scoped files changed.** Hash all of them FIRST and compare against the
  previous pass's recorded hashes (the archive entry carries them for exactly
  this): the sprint's fixes usually landed in the OTHER files of the same
  commit. BUT-1724's nine-file scope came back a third time byte-identical
  (`compute-feature-retention.ts` md5 `c7c7760001a46bea8bb7eb6cbf4612b2`,
  `on-profile-updated.ts` `7cc2acc50a2f35385526b66cefa5143c`). Say "nothing in
  my scope moved; the prior findings are still open" rather than writing as if
  a fix landed — and still re-derive every finding from the CURRENT bytes and
  re-run the suites, because copying a verdict forward is how a stale claim
  survives three passes.
- **In a live sprint worktree the file can change UNDER the review: hash the
  bytes immediately before and after EVERY suite you run, and report the
  hash — but hash with `git hash-object`, not `md5sum`.** Raw-byte md5 also
  moves on a pure LF→CRLF normalization (measured on
  `send-notification.ts`: md5 changed, `git hash-object` and the `git diff`
  index blob both identical), so md5 alone sends you hunting a content change
  that never happened. A mid-review red is as likely someone else's MUTATION
  PROOF as a defect: on 2026-07-30 both realtime services'
  `_currentUserDisplayName` getters were reverted to the old source (twice in
  one session, ~3 min each, and NOT simultaneously — my second run reddened
  only the recipe file's 3 tests while the menu file was mutated too), with
  docstring and new import left in place so the file read as
  self-contradictory; the harness restored the exact original blobs and the
  same suites went 52/52 green. So: poll on file CONTENT (grep the expected
  line in a loop), never on a timer, never write up a finding from a run whose
  before/after hashes differ — re-run, and treat the reds as free non-vacuity
  evidence for the tests they hit. **Equal before/after hashes do NOT prove the
  window never opened**: on a third pass the same day, a `grep` between two
  IDENTICAL `git hash-object` readings of `realtime_menu_service.dart` returned
  the reverted getter, because the mutate-and-restore cycle fitted entirely
  between the two hashes. The tell is the self-contradictory read itself
  (BUT-1736 docstring + `PermissionService` getter + an unused `user_service`
  import) — when a grep contradicts a hash, re-read the LINES (`sed -n`), don't
  trust either alone; a hash-stable grep hit is a window, not a finding. The change is not always a mutation proof:
  later the same day `shopping_repository_routing_module_test.dart` moved under
  a Dart review because a parallel session STRENGTHENED an assertion (added a
  falsifiable `items isEmpty` beside a name-only one). Either way the response
  is identical — re-`git diff` the file, re-run its suite, and report the verdict
  against the NEW bytes. The cheapest detector is a `md5sum ... | tee
  before.md5` before the run and `md5sum -c before.md5` after; it names the file
  for you. **The mutated file is often OUTSIDE your fileset, and then the tell is a
  newly-added GUARD SCRIPT reddening on the whole tree rather than a red test** —
  2026-07-30, `check_null_filter.sh` reported `shopping_repository_query_module.dart`
  still carrying `isNotEqualTo: null` three lines under a comment stating it uses
  `isNull: false`, which reads exactly like "the fix was never applied, only its
  comments were". Four disambiguators, ~60s, BEFORE writing that Critical: (a) RE-RUN
  `git status --porcelain -- <file>` — the session-start snapshot is stale and had
  shown it clean; (b) `git show HEAD:<file>` — HEAD held the CORRECT spelling, so the
  worktree was an uncommitted REGRESSION against a good commit, which no unfinished
  fix looks like; (c) `stat -c '%y'` vs `date` — seconds old; (d) poll on CONTENT,
  restored on the first poll. Then re-run that file's suite against the restored
  bytes and report THAT. Never restore another session's file yourself, and expect
  the knowledge files themselves to move mid-session — re-`Read` before editing.
  Second trap, same cause: the scratchpad
  is SHARED between sessions, so a generically-named runner
  (`_run_test.bat`) gets overwritten and you silently execute another
  session's file list — name throwaway runners uniquely (`_cfs_<what>_$$.bat`)
  and confirm the suite names in the output match what you asked for. Earlier
  case, same rule: `tsconfig.json` has `include: ["src"]`, so `__tests__` IS
  typechecked — a `tsc --noEmit` PASS that disagrees with a later `ts-node`
  FAIL means the file moved (an intermediate save mid-review), not that the
  lanes differ.

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
