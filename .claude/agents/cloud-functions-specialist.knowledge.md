# cloud-functions-specialist — accumulated knowledge

This file is the agent's long-term memory. Read it as Step 0 of every Cloud
Functions task. It holds durable PRINCIPLES only — edit it IN PLACE (merge
into the relevant subsection, sharpen or supersede; never add a dated entry
here). **Target size: under ~25,000 characters.** If an edit would push it
over, retire or tighten an existing principle rather than growing the file.

## How to update this file

- **Principles here, edited in place. Raw record in the archive,
  append-only.** Fold a new lesson into the matching principle — one rule
  plus the exact names/codes/thresholds a future run needs. The dated
  narrative ("Round N", "MEASURED…", wrong turns) goes to
  `cloud-functions-specialist.knowledge.archive.md` under
  `### YYYY-MM-DD — short title [tag]`, verbatim, append-only, never
  deleted. A principle earns its place only if a future run would do
  something DIFFERENT because of it — merge entries teaching the same
  thing, keep exact names/codes/config keys, cut the incident story.
- **Bias toward detail** on data-writing/deleting functions, idempotency,
  retry, cost, region, and GDPR/auth/money paths — but "detail" still
  means a sharp, findable rule, not a retelling nobody reads to the end.

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

`setGlobalOptions({ region: "europe-west1" })` — all functions deploy there,
never per-function without approval (mismatch = silent "not found"
client-side). `admin.initializeApp()` runs once in `index.ts`.

## Firebase Functions v2 — what to use

- Triggers: `onDocumentCreated/Updated/Deleted`, `onCall`/`onRequest`,
  `onSchedule`. `logger` from `firebase-functions/logger`, never
  `console.log` (except `admin/` ts-node scripts, never deployed).
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
11. A hand-rolled fake whose `update()` no-ops on a missing doc can't
    stage grpc code 5 — give it an injectable `updateFailures: Map<path,
    grpcCode>` on the update verb. Deleting a cascade LEG needs a
    `__tests__` grep for writers of that path — only dead once its
    fixture is retired in the same edit.

## Cost & cold-start

- Billed per ms × memory + per-invocation. Narrow imports. LLM functions:
  `timeoutSeconds:540` (v2 max). Scheduled jobs run hourly.
- **An in-code timeout guard is dead unless `timeoutSeconds` is declared on
  the SAME trigger** — `setGlobalOptions` sets only `region`, so a v2 event
  function defaults to the 60s platform timeout otherwise. Export the
  guard-ms/platform-seconds as a pair and pin it against the deploy
  manifest's `__endpoint.timeoutSeconds` (a constant-vs-constant test
  alone stays green after the declaration is deleted).
- **`x || DEFAULT` ≠ a typed guard** — passes negatives/numeric-strings/
  `true` through. Use `typeof x === "number" && x > 0 ? x : DEFAULT`.
- **A `retry:true` trigger enumerating a client-writable collection has
  unbounded fan-out** — cap the READ (`.limit(CAP+1).get()`), refuse above
  cap, chunk-delete with a per-item `.catch` on grpc code only, never
  throw. A boolean verdict gating a destructive delete needs a fixture
  that can force it FALSE, or no suite proves the caller obeys it. A
  `rateLimitWrite(bucket, n)` rules conjunct only binds if some writer
  actually STAMPS `users/{uid}/rate_limits/<bucket>` — grep before citing
  one as a real bound.
- **A parent-document predicate in rules is per-VERB, not blanket** — a
  roster's READ/CREATE route through `parentDoc()` while `allow delete`
  keys on the subject's own uid alone, so a deleted parent leaves such
  rows UNREADABLE, not unreachable. State such claims per verb (full
  roster-cap saga archived — see "When to consult the archive").

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
- A literal NUL/odd byte makes ripgrep silently skip a file as binary, and
  Grep can misrender punctuation — re-print with Node/`Read`. Doc-ID
  prefix-range sentinels need the 6-char escape, never a raw literal.

## What NOT to do

- Don't deploy; don't change region without approval; no `console.log` in
  a deployed function; no trigger without an idempotency story; no
  `retry:true` without a missing-doc audit.
- Don't trust a client-controlled field for a security decision unless the
  create/update RULE pins it to `request.auth.uid`. Converse: a rules DENY
  (e.g. a CEL error on a null-metadata access) can be what keeps a safety
  trigger armed against a degenerate first write — "harmonising" that
  spelling with a sibling rule can disarm it.

---

### Completion-event telemetry (`emitTiming` family)
- Gemini/Vertex implicit caching: `usageMetadata.cachedContentTokenCount`,
  billed ~10% of input rate, clamped to `[0, promptTokenCount]`.
- Never coerce a missing telemetry field to 0 — log as-is; Cloud Logging
  drops `undefined` fields, marking "not reported" vs a real zero.
- Declare `let experimentBucket: number | undefined` BEFORE the closure on
  an early-exit function; each experiment gets its own salt. Emitter test:
  assert EXACTLY ONE event per call (catches try+catch double-emits).

### Test seams, emulator infra & non-vacuity
- v2 exports carry `.run(event)` — test triggers with a typed payload from
  real emulator snapshots, no firebase-functions-test needed.
- **A wrapper/gate test is non-vacuous only if breaking it produces a
  DIFFERENT result than any other failure** — the recurring failure is
  one error code from TWO branches; assert on branch-unique text. Some
  guards fire only on a SECOND invocation — give re-enterable cascade
  steps a re-run test. An unsimulated fake stub must THROW on an
  unmodelled path, not silently succeed.
- A `?? {}` read is vacuous for the mutant that DELETES the document —
  pair it with a sibling requiring the doc to EXIST. A fake's
  `listDocuments()` returning only stored docs can't represent a PHANTOM
  parent, the one state production needs it to see.
- **Rules are not filters** — a client query with NO condition is DENIED
  wholesale on a member-scoped collection; only the RULES emulator lane
  proves this (`fake_cloud_firestore` evaluates none), and that emulator
  KEEPS data across runs — give an "empty" fixture a uid no other test
  seeds.
- A `src.includes("<field>")` assertion is vacuous whenever the docstring
  itself names the field — assert the WRITE, not the mention.
- **A fake `commit()` that RE-DERIVES the intended effect instead of
  APPLYING the write payload makes the write vacuous** — dispatch on the
  `FieldValue` transform's `constructor.name`; reject `update()` on a
  MISSING doc with grpc 5. Mutate a SHADOW COPY, never the tracked file,
  when testing this in a live parallel-session worktree.

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
  hard-coded names. New steps are BEST-EFFORT — a rethrow re-runs the
  WHOLE cascade, double-applying non-idempotent steps.
- **A batch reaching `batch.update()` on a doc a different actor
  concurrently deleted fails the WHOLE chunk with NOT_FOUND** under
  `strict:false`, mixed or pure-update — piggyback the existence probe on
  the SAME `getAll` already used for the idempotency gate; skip (never
  `set(merge)`) when absent. Where a function SKIPS a doc in step A and
  DELETES it in step B, an ABSENCE assertion can't pin the skip — record
  `batch.update` PATHS on the fake instead. A destructive delete driven by
  "not present in a roster query" must guard against a transiently
  under-populated query.
- **Cross-check the identity FIELD and COLLECTION NAME across every leg**
  (deleter, export, probe, rules, Dart constant) — a wrong field or
  pre-rename name deletes NOTHING silently. Repointing a dead COLLECTION
  is only HALF the fix — the VALUE searched for must match what the
  PRODUCER writes (a diacritics mismatch was a live silent miss). One
  field can also have TWO stores (embedded array + subcollection) — only
  the READER decides which is authoritative; erase BOTH.
- **A parent-with-subcollection deleted by plain `doc(id).delete()` leaves
  an orphan the server cannot QUERY** — `listDocuments()` is the only
  Admin-SDK call returning refs for MISSING docs with live subcollections;
  use it on both sweep and probe. A `strict:false` sweep followed by a
  parent delete strands PII if the sweep silently failed — a
  to-be-deleted parent's children use `strict:true` instead.
- A "shared" collection also holds SOLO-owner docs that must be DELETED
  not scrubbed. Scrubbing a deleted user off a SHARED doc must enumerate
  every {uid, displayName} pair on the MODEL including array elements — a
  propagation CF is usually a SUBSET of what the client stamps, and a
  PARENT's denormalised/per-uid map fields need scrubbing too (the Art.
  15 EXPORT's third-party redactions are the cheapest enumeration
  source).
- **A cascade write from a query-time snapshot applied via a plain
  `.update()` is a lost-update hazard against a concurrent edit** — wrap
  in `runTransaction`, re-read fresh, skip on `!fresh.exists`. The repo's
  hand-rolled fake transaction is single-threaded/no-retry, so a green
  suite proves values, not concurrency-safety. Rules aren't filters on
  delete either — a client cascade can only query a field the READ rule
  authorizes (capped at 10 `get()`s/query); only the Admin SDK can key an
  erasure on a field the read rule doesn't expose.
- A rules hard-deny PLUS an Admin-SDK escape hatch has TWO independent
  guards, and the callable exempts only the first. The model's
  `toFirestore` coercion is the second: every path that runs the
  serializer still reverts the opted-in state silently. Enumerate the
  SERIALIZER's call sites, not just the rules' write paths, before
  calling an opt-in durable. (Restored 2026-08-17 — the diet dropped
  this as single-incident; it is a two-guards pattern and it governs a
  minor's discoverability setting.)
- A serial `ref.update()` loop over an embedded array has two defects:
  NOT_FOUND aborts remaining iterations, and the full-array write is a
  lost update. Per-doc `runTransaction` fixes NOT_FOUND only — wrap each
  in its own try/catch, accumulate, throw once, then filter failed ids
  out of any UNCONDITIONAL write the old abort-early behaviour protected.
  A denorm-name propagation step querying a name as TOP-LEVEL when it's a
  SUBCOLLECTION updates zero docs, silently — parameterize fan-out
  helpers by `CollectionReference`, never a NAME string.

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
  base query's next match. Use the `__name__`-cursor helper ONLY when
  every write touches solely denorm fields — add a hard iteration cap
  either way. A drain that CLAIMS-BY-DELETE each item self-heals runs.
  **"A deleted doc can't anchor a `startAfter` cursor" is FALSE** — the
  cursor is built from the snapshot LOCALLY; anchor on the last SCANNED
  doc (not deleted) for ORDERING, since a deleted one can sort earlier.

### GDPR account-deletion cascade
- A cascade step keyed on a shared/parent handle must destroy the retry
  handle LAST, after all child cleanup commits. Subtler form: a
  purpose-built QUERY HANDLE cleared in the SAME write as the content
  scrub, ahead of a dependent mirror — order the mirror write FIRST.
- **`probeResidualData` must not be BROADER than the deleter** — union the
  probe's own queries into the deleter's scoping, dedup by doc id; prove
  the coupling by deleting one union leg and checking BOTH the targeted
  fixture AND "no failed collections" redden. A probe ERROR must ADD to
  the residual count, never abort the cascade, and a new leg dropped
  INSIDE an existing `try` silently shortens every leg after it — give
  each its own try/catch.
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
- A no-oracle gate can DESTROY the only symptom of a wrong collection
  path — pair it with a path-pinning test (`collectionName` on a Dart
  repository is NOT the path; check the mixin list for
  `UserScopedFirebaseRepository`).
- **A new `onCall` export is a THREE-file change**: the function, its
  `test:*`/suite in `package.json`, and `app-check-enforcement.test.ts`'s
  classification (`ADMIN_EXEMPT` only if the handler's FIRST statement
  checks the admin claim). Deleting a callable is the same in reverse.

### TS↔Dart parity twins (canonical-pool-key.ts et al.)
- `\w`/`\b` are ASCII-only in both without the `u` flag — fold å/ä/ö→a/o
  FIRST. Module-scope `/g` regexes are stateful with `.test()`/`.exec()`
  in long-lived CF isolates. Shared word lists: compiled-in consts pinned
  by JSON-fixture parity tests on BOTH sides, never a runtime JSON load.
- **A sentinel default fixing a non-determinism must be ROUND-TRIP STABLE
  through Firestore** — Dart's `DateTime.==` also compares `isUtc`, and
  `Timestamp.toDate()` returns a LOCAL `DateTime`. Use `isAtSameMomentAs`,
  never `!=`, and grep EVERY factory for a stale default.

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
  retention — sweep ALL at once.** The field NAME must match across every
  writer of the SAME target; the anchor must cover every writer of the
  collection GROUP; the TTL must exceed the READER's window. A bucket
  chosen by an ENUMERATED allowlist fails silently toward the SHORTER
  window when a value is left off — derive the expected set from the
  WRITER files, not a hand-typed mirror.
- **Prove a lefthook glob by RUNNING it** (`npx lefthook validate` +
  `dump | grep -A5 <job>`) — it hides UNSTAGED changes for `pre-commit`
  but still sees any UNTRACKED file.
- **To review the staged set free of a parallel session's edits:**
  `git archive $(git write-tree) | tar -x -C <scratch>`; review the
  STAGED copy (`git show :<path>`) — `MM` means the index predates the fix
  under review. A first read after "fixes landed" can return PRE-FIX
  bytes — run the suite first, diff its names/count against what you
  "read". Check `.claude/state/review-ledger.jsonl`'s `sha` (the git blob
  hash, `git cat-file -p <sha> | diff -u - <file>`) with the **Grep
  tool**, not Bash `grep` (refused by its own hook).
- A live sprint worktree file can change mid-pass — hash before/after
  with `git hash-object`, not `md5sum` (CRLF normalization moves the
  md5, not the blob hash); poll file CONTENT.

### When to consult the archive
Grep `cloud-functions-specialist.knowledge.archive.md` (not this file) for:
- A residual probe disagreeing with a deleter, or a cascade step's
  ordering/transaction rationale — the GDPR-cascade and PII-scrubbing
  sagas (incl. the roster-cleanup cap saga and the `leaveGroupConversation`
  oracle bug) are archived in full.
- A TTL policy declared but not reaping, a retention rationale needing
  the original measurement, or a PII-scrubber regex misfiring on a
  specific Swedish word/name.
- Debugging/extending a specific ticket (BUT-XXXX) — the full narrative
  and round-by-round correction chains (BUT-1838, BUT-1835, BUT-1801,
  BUT-1792) are there.
- Why an accepted residual/tradeoff was decided the way it was, or
  whether a specific test/config value existed at some past date.
