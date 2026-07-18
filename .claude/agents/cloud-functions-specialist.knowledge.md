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

### 2026-07-16 consolidation (2026-06-27 → 2026-07-07 raw entries verbatim in cloud-functions-specialist.knowledge.archive.md)

#### GDPR deletion cascade (account-deletion-cascade.ts + on-user-deleted.ts)
- A cascade step keyed on a shared/parent handle (e.g. `householdId` via `households where memberUserIds array-contains uid`) must perform the mutation that destroys the retry handle (the `arrayRemove(uid)` / household-doc delete) LAST, after all child cleanup commits with `strict:true` — otherwise a transient mid-step failure strands orphans a whole-cascade retry can no longer reach. Steps keyed `where(field,"==",uid)` are immune (`deleteFamilyData`, 2026-06-29).
- Wrong-field filters delete NOTHING, silently: `realtime_recipes`' owner field is `ownerId`, NOT `userId` (BUT-1396 Art.17 leak). Deletion keys on the OWNER, never `participantIds`. Cross-check the identity field across the Dart model's `toFirestore`, the firestore.rules `resource.data.<field>`, and sibling deleters/exporters. Every GDPR-deletion test needs a POSITIVE "owned doc is gone" assertion (control-survives alone passes a no-op filter), and prove a new regression test bites by reverting the SUT once.
- `probeResidualData` must mirror the deleter's field scoping per collection: `notification_delivery` needs BOTH `senderId` and `targetUserId` probes (two queries); `canonical_rating_events` needs a subcollection-shaped probe `.doc(uid).collection(...).count()`, never top-level `where("userId","==",uid)`. `count()` is the probe primitive; the probe never aborts the cascade — probe error ⇒ `residual += 1` (fail-toward-flagging) (BUT-1450).
- Pure `users/{uid}/*` subcollections erase via the `subs` array in `deleteUserSubcollections` (inherently uid-scoped, retry sees empty snapshot). Canonical test triple: own-erased + other-kept + `failedCollections` empty (pooled-ratings Incr 5).
- Deleting `canonical_rating_events` fires `onPooledRatingEventWritten` → debounced recompute writing a DIFFERENT collection (`canonical_recipe_stats`) — trigger separation carries GDPR erasure for free, no loop.
- Emulator workflow: `bash .claude/hooks/ensure-firestore-emulator.sh` (127.0.0.1:8080), then `npx ts-node src/__tests__/request-account-deletion.integration.test.ts` (self-clears via REST DELETE).

#### Retention / purge jobs
- Unfiltered `limit(N)` + client-side filter = starvation: long-retention consent rows (730d) crowd expired general rows (180d) out of the window. Push the discriminant server-side: Admin SDK 13+ supports `operation not-in CONSENT_OPERATIONS` + `timestamp <` multi-inequality, needing a genuine composite `(operation ASC, timestamp ASC)` on `audit_logs` (range + in/not-in — not the equality-only deviation). Pin the `CONSENT_OPERATIONS` values exhaustively in a test (`not-in` max 10) (BUT-1404).
- Retention buckets key off the `operation` prefix: `consent_*` ⇒ 730d, unprefixed (e.g. `age_verification_rejected`) ⇒ 180d (`audit_logs/purge-expired.ts`).
- Warn-before-purge two-pass is the GDPR shape for any auto-deletion of user data: pass 1 stamps `familyDataPurgeScheduledAt = now + grace` + in-app warning; pass 2 deletes only when `now >= scheduledAt`; reactivation clears the stamp; the purge branch is structurally unreachable on first detection (purge-dormant-family-data).
- A `.limit(200)` top-level scan with no cursor is "bounded, NOT paginating" — overflow is starved forever and the subset shifts between runs; use the `__name__`-cursor loop in `shared/batch-update.ts`. Contrast: a weekly reap re-querying `expireAt < now` under `.limit(10000)` self-heals (overflow stays matched next run).
- `commitInChunks(db, docs, (b,d)=>b.delete(d.ref), {strict:true})` for must-be-complete deletes of regulated data; stamp the parent (`familyDataPurgedAt`) only AFTER the children commit. `batchDeleteAll` is strict:false and swallows chunk errors — never let it precede deleting the only re-derivation handle.
- Dormancy = max(parent + all children timestamps) computed by reading the children (needed for the delete anyway) — not an `orderBy+limit(1)` probe that would force a composite per collection.
- `warnMembers`-style self-notifications write `user_notifications` with `senderId == recipient`; best-effort per-member try/catch, never blocks the schedule stamp.

#### verify-signup-age / account callables
- Region is inherited from `setGlobalOptions({region:"europe-west1"})` in index.ts — never add a per-function `region`.
- Write ordering claim → birthYear → audit deliberately favors "never able-to-post without a recorded-age decision"; a retry hits the idempotent `existingClaims.ageCompliant === true` branch. If ever tightened, re-check birthYear presence in the idempotent branch — don't reorder.
- Abuse/IP caps on account gates fail CLOSED (Firestore error ⇒ deny); notification gates fail OPEN — both correct for their domain, don't harmonize. `request.rawRequest?.ip` may be a proxy/shared egress; the `"unknown"` fallback buckets all ip-less callers into one key.
- Rejection audit rows are deliberately NOT deduped — each blocked attempt is a distinct security event; the per-IP cap is the cost bound.
- `isMinor` on the `users/{uid}` root doc is load-bearing (firestore.rules `get()` gates 1:1 DMs to minors) and is mirrored to `users/{uid}/settings/preferences` (the doc the client hydrates `UserProfile` from). The `isSearchable:false` root write was removed as DEAD — search reads `public_profiles.isSearchable`. Rule: trace the CONSUMER (client/rules read path) of any "protection default" before trusting the write (BUT-674 correction). Jan-1 year-subtraction age cutoff over-protects — the safe direction.
- Test patterns (verify-signup-age.test.ts): assert field ABSENCE for data-minimisation contracts (`!("birthYear" in row)`); `HttpsError.code` reads namespaced `"functions/resource-exhausted"` — accept both forms; derive age boundaries from `new Date().getFullYear()`, never hardcode; prove no-ops via call COUNTS on the injected fake, not the response envelope; rethrow-path tests assert the returned sentinel stayed `undefined`; fail-closed tests inject a transaction error and assert the deny. Logger error/info lines interleave with PASS output — the trailing `N/N passed` is the source of truth.

#### Notification categories
- A NEW `NotificationCategory` defaults on via unconditional `return true` on a missing field — never borrow a sibling category's stored boolean (BUT-1427 `digest`; `reEngagement`'s fallback to the `system` toggle is a legacy mapping, not a pattern). `isCategoryAllowed` is total ⇒ a typo'd/unknown category fails OPEN (sends).
- The analytics `notificationType` (fed to `evaluateSendGate`) and the preference `category` literal are separate taxonomies; per-frequency (`digestFrequency`, enforced in the scheduler) vs per-channel (category boolean, enforced in the helper) are separate opt-outs at different layers — don't fold them.

#### Pooled ratings + rating aggregation (ratings/ family)
- Recipes are USER-SCOPED: `users/{ownerUid}/recipes/{recipeId}`. firestore.rules has NO top-level `match /recipes`; `bulk-retag.ts`'s top-level `collection("recipes")` is legacy/unverified. Confirm any server-side collection path from firestore.rules + the repository's mixin, never from an incidental `collection()` call elsewhere. Test fakes must mirror the REAL layout or a path bug is structurally invisible (xhigh correction 2026-07-03 — a "clean" single-specialist review endorsed a dead-on-arrival top-level read).
- firebase-functions v2 event triggers default `retry=false` — a thrown error is logged and DROPPED. "throw ⇒ retry" requires `{retry:true}` in trigger options, and is safe only when the handler's sole mutation is idempotent (e.g. `onPooledRatingEventWritten` just schedules a coalescing marker; it recovers `poolKey` from `event.params`, which survives deletes).
- Unbounded collection-group folds use `.aggregate({count: AggregateField.count(), average: AggregateField.average("ratingValue")})` (firebase-admin 13.8.0), never `.get()` — pin with a test tripwire asserting zero raw fold `.get()`s. A `collectionGroup` equality query needs a `fieldOverrides` entry with `queryScope: "COLLECTION_GROUP"` in firestore.indexes.json — auto single-field indexes are COLLECTION-scope only, the emulator hides the prod `FAILED_PRECONDITION`, and this is distinct from the equality-composite accepted-deviation. Same for composite entries backing `collectionGroup()` queries (pings). `average(f)` skips non-numeric `f` — the producer must validate the field or count/average denominators silently diverge.
- A second debounced aggregator = a thin `DebounceConfig` adapter on `shared/debounce-queue.ts` with a distinct `markerCollection` (`_internal/pool_debounce/markers` vs `_internal/rating_debounce/markers`) + `logPrefix` — never a fork. Claim-by-delete BEFORE aggregating; aggregation is idempotent (full re-read + `set(merge)`), so a marker-race double-run is safe.
- A marker/queue doc-FIELD rename is deploy-transition-safe ONLY if every reader falls back to `doc.id` and the doc ID equals the value (`data?.key ?? doc.id`); otherwise two-phase deploy (read-both, then write-new).
- `updateRecipeRatingStats(recipeId, db?)` folds `recipe_ratings` + `family_ratings where memberType=="profile"` into `recipe_social_stats/{recipeId}`; no double-count because only genuine self-rates mirror to `recipe_ratings`. A family rating on a never-shared recipe creates an authed-readable anonymous stats doc (accepted Low). Empty pools are zeroed (count 0 / average null), not deleted — the reader gates on n≥5. The Stage-A mirror has NO `skipped_unchanged` gate and NO edit-detachment — decided (accepted-deviations 2026-07-03); don't re-file. Order free adversarial checks (maturity `auth.getUser`) BEFORE billed reads. `createdAt` semantics diverge between mirror (`serverTimestamp()`) and backfill (preserves original) — deliberate, unresolved for Stage-B weighting.
- One-shot backfills: persist the cursor (`startAfter` in / `nextCursor` out) — a local cursor plus caps that count skipped-identical docs stall permanently above ~10k docs (`hasMore` forever). Two-cursor split: `lastDocId` (last FETCHED, drives the query) vs `lastProcessedId` (last PROCESSED, drives `nextCursor`) — they diverge only at the maxRatings cutoff, re-fetching the cutoff doc, no skip. Collect a batch's writes into ONE `commit()` after the loop so a mid-loop throw leaves zero committed writes and `batchStartCursor` resume is exact. Dedup winner = last-by-doc-id in a Map keyed `${uid} ${poolKey}` — deterministic, converges across runs. Clamp `maxRatings = Math.max(1, ...)` (0 ⇒ `nextCursor` falls back to `lastDocId` and silently skips a whole batch).
- 3-segment doc paths in specs are traps (`_internal/rating_debounce/{recipeId}`, `audit/ping_rate_limit/{autoId}` — doc must be even segments): count segments; use `.../markers/{id}` and `audit/<event>/entries/{auto}`.
- `.count()` over `.get()` whenever only cardinality matters (ping hourly rate-limit: one billed read regardless of volume).

#### TS↔Dart parity twins (canonical-pool-key.ts et al.)
- With no `unicode`/`u` flag, `\w`/`\b` are ASCII-only in BOTH Dart and JS — fold å/ä/ö→a/o FIRST, then run boundary regexes; adding the flag on one side breaks parity. Default sorts are UTF-16 code-unit ordinal in both (no locale comparator); `split(' ')` is literal in both; sha256 hex is lowercase in both; Set→Array preserves insertion order in both — dedup order is moot when you sort after.
- Module-scope `/g` regexes are safe with `.replace` but stateful (`lastIndex`) with `.test()`/`.exec()` in long-lived CF isolates — keep global regexes to `.replace` or make them local.
- Input validation belongs in the calling CF, not the pure helper: coerce `typeof === "string"` before `computePoolKey`, or a malformed doc's TypeError inside a trigger = retry storm.
- Shared word/heuristic lists: compiled-in consts pinned by JSON-fixture parity tests on BOTH sides (`test/fixtures/pool_key_wordlists.json`, `pool_key_parity.json`) — NEVER a runtime JSON load; tsc does not copy `.json` under `src/` into `functions/lib`, so a runtime read crashes the deployed function. `src/__tests__/*` compiling into lib is the accepted convention, zero cold-start cost.

#### LLM prompts & prompts-config
- Compiled-in prompt edits are INERT while a valid `system/prompts` override doc is live — a prompt-content change must ship with a matching prod-doc update (or verified doc absence) as an explicit deploy step, else the stale doc silently wins (PR #211 section rule).
- A NEW Firestore-backed prompt field must be OPTIONAL with per-field fallback (`typeof raw.x === "string" && raw.x.trim() ? raw.x : COMPILED_CONST`), never added to `requiredStringKeys` — validation is all-or-nothing (BUT-621), so a new required key silently reverts EVERY live override doc to compiled-in fallback on deploy (BUT-684 correction). Pin with a fixture LACKING the key asserting `source === "firestore"` + sibling override survives + new field == compiled const.
- Mirroring a prompts-config field = 5 edit sites in `prompts-config.ts` (doc-shape docstring, interface, `buildFallback()`, `requiredStringKeys`, `validateRemoteDoc()` return). And grep ALL test fixtures constructing `system/prompts` docs (`grep -rn "imageOcrSystemPrompt:" src/__tests__/*.ts`) — a stale fixture flips to fallback and can pass vacuously while no longer testing the firestore path.
- Any new/edited `*_SYSTEM_PROMPT` const trips the prompt-changelog CI guard: PROMPT_CHANGELOG.md entry + PROMPT_VERSION bump in the same change (MINOR for additive prompts; MAJOR only for schema+parser changes).
- N prompts sharing ONE responseSchema: a behavioural instruction in only one prompt is a latent gap in the other N−1 — the schema constrains structure, not semantics. Extract a shared const (e.g. `INGREDIENT_GROUP_RULE`) interpolated into all, verify byte-identical rendering char-for-char. The schema `description` is the one prompt surface ALL schema callers share, and the schema is compiled-in (not Firestore-overridable — deploys atomically). responseSchema cannot enforce string length — server-side `trim().slice(0,max)` in `validateIngredient` is the enforcement point. `${INJECTION_DEFENSE}` stays the FIRST token of every prompt.
- A/B `resolvePromptBucket` is analytics metadata only (experimentBucket/promptVariant on the timing log) — it never swaps the prompt string; prompt selection (e.g. `isHandwritten ?:`) is orthogonal.
- Testing `runOcrRecipeImage` with no initialized admin app: capture `args.systemPrompt` inside the `performOcr` seam (runs first) and try/catch the call — `captureLlmSample` throws later; assert on the captured value.
- Best-effort/never-throw helpers must resolve `admin.firestore()` INSIDE the try: a `= admin.firestore()` default param evaluates at call time BEFORE the body's try/catch and escapes the guard (kept the CF-unit CI red 4 days; BUT-1451 fix: `dbOverride?` + `const db = dbOverride ?? admin.firestore()` as the first line in the try).

#### Rate limiting (middleware/rate_limiter.ts)
- The per-user daily cap lives in the SAME doc + SAME transaction as the token bucket (no extra reads); denial is evaluated BEFORE token consumption and the deny path writes nothing (denials are free). `dayKey` uses 0-based `getUTCMonth()`, equality-only, never parsed back; pre-BUT-1477 docs (no dayKey) read as a fresh day; the 90-day-staleness weekly cleanup can't race an active user's doc. (The global-increment-before-per-user ordering wart flagged 2026-07-07 was fixed by BUT-1577 — see the retained 2026-07-11 entries.)

#### Ingredient sync (admin/ family)
- `admin/` scripts run `admin.initializeApp()` + `main()` at import — extract pure cores (`sync-ingredients-core.ts`: csvToFirestore, diff, mergePreservedFields, isResurrection) for the test harness. Idempotency/region/retry are N/A (manual ts-node, never deployed); separator/normalization changes cause a one-time reviewable churn wave in the first diff report, then converge — that's the fix working.
- List splits use `/;|,(?!\d)/` — comma is a separator unless immediately followed by a digit (Swedish decimal `"0,5%"`); applied to aliases_sv AND aliases_en/search_terms (regex triplicated ~L194/207/208 — keep in lockstep or hoist to a `LIST_SEPARATOR` const). Safe against the loader only because `parseCsvLine` is quote-aware AND `loadCsv` fails closed (exit 1) on column-count mismatch — re-verify BOTH when widening separators. Only `[swedish, ...aliasesSv]` feeds `normalizedNames` (the allergen-gate surface); aliases_en/search_terms degrade search recall at worst — that scoping is what makes their split safe without the xhigh data-writing gate.
- Normalization parity must hold across the THREE matching surfaces or the BUT-1468 gate-bypass class reopens (an ASCII alias like "jordnotter" passes the server gate yet matches "jordnötter" client-side): sync stamp (`shared/swedish-normalize.ts` stripDiacritics), server hold gate (`normalizeIngredientName` in `analyze-corrections.ts`), Dart client (`_normalize` in `firebase_ingredient_repository.dart`). Re-diff all three whenever the split or a normalizer changes. Any safety gate filtering strings the client later matches must run the SAME normalization as the client matcher.
- Allergen lockstep triple — no automated pin, re-diff by hand when touching any of them: `VALID_PROPERTIES` (admin/sync-ingredients.ts), `ALLERGEN_RELEVANT_PROPERTIES` (shared/allergen-properties.ts), `triggerProperty` list (lib/services/tagging/config/allergen_config.dart — includes non-medical triggers like `contains-alcohol`/`meat` NOT in the shared TS list). Skaldjur trigger = crustacean OR mollusc OR seafood via plain OR — a detail property never clears CONTAINS (deliberate false-CONTAINS safety net); its value is making the specific allergen detectable.
- Confirm-gated admin scripts: the human-review artifact (JSON diff report) writes BEFORE the confirmation prompt; the executed-marker Firestore row (`system_events`) writes AFTER the final commit — never before, or a cancelled/failed run leaves an audit row claiming the sync executed. Resurrection routing requires the Firestore fetch UNFILTERED (no status filter) so soft-deleted docs land in `toUpdate` and get `FieldValue.delete()` clears for `deletedAt`/`expireAt`.
- `validateAllIngredients` counts warnings only under `--verbose` — a new warning is invisible on the standard dry-run unless the counting moves outside the verbose guard (gate only the printing).
- Hold states in txn state machines: allowlist (`status === "pending"`), never blocklist (`!== "approved"`) — parked/terminal states (`held_for_review`/`rejected`/`revoked`) leak through blocklists. Hold-reason computed outside the txn is acceptable when inputs change only via rare admin paths and an admin revoke exists. Hoist per-event-constant reads (`isMatureAccount`) out of per-candidate loops. `learned_aliases` `status ==` + `orderBy count desc` needs a composite absent from firestore.indexes.json (emulator auto-creates and hides it).

#### CI / test wiring / ops
- A new `__tests__/*.test.ts` is INVISIBLE until a `test:*` script exists in package.json — `run-all-tests.js` auto-discovers `test:*` excluding `test:rules*`/`test:integration:*` (emulator-bound, run manually; don't file "not in the composite chain" for those). Recurring trap (BUT-1392, BUT-1477): grep package.json FIRST when reviewing any new test file.
- Every new `onCall` export must be added to `app-check-enforcement.test.ts`'s `USER_FACING`/`ADMIN_EXEMPT` sets immediately, or that suite goes red.
- Two runners: `run-all-tests.js` (dev, everything) vs `scripts/run-ci-unit-tests.js` (CI gate `cloud-functions-unit.yml`: Node 22, npm ci → build → runner, no emulator; `CI_EXCLUDE` lists known-broken suites — remove entries once fixed).
- `firestore-rules.yml` path filters must list each rules test file in BOTH the `pull_request` AND `push` lists, plus source-dir triggers (`functions/src/social/**`, `functions/src/family/**`) — silent drift trap.
- Post-deploy smoke (deploy-firebase.yml): `firebase functions:list --project butlery-app-1 --json` + fixed-string grep of 8 stable representative names (structureRecipe, ocrRecipeImage, sendNotification, onUserDeleted, verifySignupAge, requestAccountDeletion, cleanupExpiredCache, drainRatingAggregations; exclude migration-lifecycle functions). `firebase deploy` exit 0 does NOT prove functions are callable (DEPLOY_FAILED state) — only a control-plane query after deploy does. No error suppression on the check step.
- A Firestore TTL field (`expireAt` on parse_events / llm_response_samples) is INERT without the `gcloud firestore fields ttls update` policy — demand the `functions/RUNBOOK.md` entry, or the retention claim is documentation fiction. Cloud Logging metric filters are GCP-console config, not code — RUNBOOK, not a code task.
- Structured timing logs: ONE `emitTiming` closure declared at function top, called at every exit path with a per-exit `reason` field.
- Pre-existing failures in a full `npm test` after a sprint: `git log --oneline -1 -- <broken-file>` to check whether your work touched it before chasing fixes.
- Data-writing CFs get an adversarial multi-finder review before commit — the single-specialist gate endorsed a dead-on-arrival collection path and a false throw-retries assumption (2026-07-03 xhigh correction); necessary but not sufficient.

### Archived 2026-07-16 batch (2026-06-27 → 2026-07-07) — see cloud-functions-specialist.knowledge.archive.md
- 06-27 (2) — BUT-1386 verify-signup-age: DI-core test patterns + production-side review (region, write ordering, IP cap).
- 06-28 (3) — BUT-1404 audit-log purge starvation fix; BUT-1392 CF tests wired into CI; BUT-1423 post-deploy smoke gate.
- 06-29 (4) — family-diner ratings fold into recipe_social_stats; family-data cascade retry-handle ordering hazard; dormant-family-data purge sweep; BUT-1427 digest category decoupling.
- 06-30 (2) — BUT-1396 realtime_recipes ownerId deletion fix; BUT-1450 residual-probe field scoping.
- 07-01 (2) — BUT-674 minor default-private profile + post-review isSearchable correction.
- 07-02 (5) — BUT-684 handwritten-OCR prompt (variant, fixture breakage, made-optional correction); sync-ingredients warnings invisible; ingredient section field (PR #211).
- 07-03 (11) — pooled-ratings pool-key twin, C5 word-list guard, debounce-queue generalization, Stage A mirror review + xhigh USER-CORRECTION (user-scoped recipes, retry=false, fake-layout), Stage B aggregator, Incr 5 GDPR cascade; Finding D cross-prompt gap; BUT-1467 sync core extraction + allergen triple; audit-event timing in confirm-gated scripts; BUT-1468 alias hold-for-review.
- 07-04 (3) — pooled-ratings backfill cursor finding + verified cursor/dedup rewrite; best-effort telemetry admin.firestore()-inside-try fix.
- 07-07 (3) — BUT-1495 comma-tolerant aliases_sv split; BUT-1477/1478/1479 daily LLM cap + parse_events TTL; BUT-1571 decimal-comma split.

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

## Discovered patterns

*Append new dated, trigger-tagged entries below.*

### 2026-07-09 — BUT-1512 collection-group wildcard suite: friend_categories gap [Pattern discovered]

`collection-group-wildcards-rules.test.ts` isolation-tests the owner-shape catch-all
wildcards in `firestore.rules` on a NOVEL parent (`cg_wild/...`) so only the
`{path=**}/<name>/{id}` rule can match — the same trick as the members suite. There are
**seven** such catch-alls (grep `match /\{path=\*\*\}/` in firestore.rules): members,
friend_categories, engagements, comments, ratings, recipes, pings. The new suite covers
five (engagements/comments/ratings/recipes/pings) and correctly defers members to its own
suite — but its docstring says "the remaining five" and silently omits
**friend_categories** (`firestore.rules:2087`, `allow read if request.auth.uid in
resource.data.friendUserIds`). That is a SIXTH owner-field-shaped catch-all with the exact
latent-trust risk the suite exists to guard ("every present AND future subcollection of
that name carries the expected owner shape").

Its existing `friend-categories-rules.test.ts` does NOT close the gap: it only exercises
`users/{ownerUid}/friend_categories/{categoryId}`, which matches the **narrower** per-user
rule at `firestore.rules:436`, not the catch-all at 2087. So the friend_categories
collection-group wildcard is untested in isolation. Fix = add friend_categories cases to
the BUT-1512 suite on a novel parent: owner-in-array reads; array-missing denied;
foreign-only-array denied; unauth denied.

**Pattern**: when a "cover all the catch-all wildcards" suite lands, grep
`match /\{path=\*\*\}/` and reconcile the count against the docstring — a wildcard with a
sibling per-user rule (friend_categories, members) is the easy one to miss because a
same-named narrower suite *looks* like coverage but tests a different rule block.

Everything else verified clean: all five covered rules match the test assertions
byte-for-byte (engagements = doc-id gate, recipes = isAdmin() with `admins/{uid}` seeded to
match `isAdmin()` at rules:57, pings = from/to OR). Wiring is correct and consistent across
all three surfaces — `test:rules:collection-group-wildcards` script + appended to
`test:rules:all` (package.json), and listed in BOTH the `pull_request` and `push` path
filters of `firestore-rules.yml` (avoids the BUT-1392 push-list-drift trap). Emulator-bound
`test:rules:` prefix keeps it out of the no-emulator `run-ci-unit-tests.js` runner. Direct
get/delete (not a real `collectionGroup()` query) is the accepted members-suite convention —
not a finding.

### 2026-07-11 — BUT-1579 comma-split extended to aliases_en/search_terms [Pattern discovered]

`csvToFirestore` in `functions/src/admin/sync-ingredients-core.ts` now splits
`aliases_en` and `search_terms` on `/;|,(?!\d)/` (was plain `";"`), matching the
`aliases_sv` treatment established by BUT-1495 (humans type `,` where the Sheet
convention is `;`) + BUT-1571 (a comma followed by a digit is a Swedish decimal
`"0,5%"`, not a separator). Reviewed clean — no Critical/High/Medium. `npx ts-node
src/__tests__/sync-ingredients-diff.test.ts` = 18/18, tsc clean.

Why it's low-risk (verified, not assumed):
- **No allergen-safety surface touched.** `normalizedNames` (the diacritics-
  stripped allergen-lookup form the BUT-1468 hold-for-review gate queries) is
  derived from `[swedish, ...aliasesSv]` ONLY — `aliasesEn`/`searchTerms` never
  feed it. So a bad split here degrades search recall at worst, never an allergen
  verdict. This is the reason the same regex is safe to extend here without the
  xhigh multi-agent data-writing gate that a normalizedNames change would need.
- **Idempotent after first run.** `admin/` scripts are manual/ts-node, not
  deployed triggers, so no retry-storm concern. `hasChanges` DOES compare
  `aliasesEn`/`searchTerms` (added in the 2026-07-03 xhigh review), so the first
  sync after this ships re-updates every doc whose those columns held a comma
  list — a one-time churn, matches the BUT-1571/BUT-1468 backfill shape; the
  second run sees them equal. Reviewed via the human-gated dry-run diff report.

Two Info-level notes worth carrying:
- **Regex literal is now triplicated** (aliasesSv L194, aliasesEn L207, searchTerms
  L208). A future tweak to the separator must touch all three. Cheap to hoist into
  a module const `const LIST_SEPARATOR = /;|,(?!\d)/;` — not filed as a change, just
  flagged so the next editor keeps them in lockstep.
- **SyncReportEntry only surfaces properties/aliasesSv/status** in before/after, NOT
  aliasesEn/searchTerms. So the first-run re-split churn appears in the dry-run
  report as rows in `toUpdate` with *no visible before/after difference*. Pre-existing
  report shape, not introduced here, but a reviewer eyeballing the diff should know a
  "changed but looks identical" row on this sync is the aliasesEn/searchTerms re-split,
  not a phantom.

### 2026-07-11 — BUT-1506 merged friendship-delete + count-decrement review [Bug fixed]

`cleanup/on-user-deleted.ts` merged the old `cleanupReverseFriendships` (D1) and
`updateFriendCounts` (D4) into one `cleanupFriendshipsAndDecrementCounts`. The
reverse-friendship doc is now the idempotency token: per chunk it `getAll`s the
reverse docs and, only for friends whose reverse doc still exists, stages
`delete(reverse) + audit + increment(-1) on public_profiles + audit` in ONE atomic
batch (4 ops/friend → chunk = floor(500/4) = 125). Fixes the real non-idempotency
bug: the old D4 blindly decremented every friend off the never-deleted victim
friends-list, so a duplicate delivery / re-run double-decremented. `tsc --noEmit`
clean. `stageCascadeAuditEntry` = exactly 1 `set` op (confirmed), so the /4 math is
right and a full chunk is exactly 500 ops (at the limit, OK).

**HIGH — poison-pill: a friend with a missing `public_profile` doc aborts the whole
cascade.** `batch.update(public_profiles/{friendId}, …)` fails at commit if that doc
doesn't exist (Firestore `update` requires existence), and because the decrement now
shares a batch with the reverse-friendship deletes, the ENTIRE chunk rolls back →
`cleanupUserSocialData` throws at step 1 → steps 2-14 never run → GDPR erasure aborts.
The condition is data-driven (same every run), so it's a poison pill, not a transient.
Worse than the pre-merge code, which committed the reverse deletes in their own batches
before D4's blind update could throw. Fix: also `getAll` the `public_profiles/{friendId}`
refs alongside the reverse docs; when a profile is absent, still delete the reverse doc
+ audit (2 ops) but SKIP the decrement. The reverse doc stays the token; no throw; a
gone friend has no count to decrement anyway. Do NOT use `set(...,{merge:true})` — that
resurrects a deleted peer's profile with a negative count.

**MEDIUM (pre-existing, surfaced by this change) — no `failurePolicy`/retry configured.**
The v1 `.auth.user().onDelete` trigger is `.runWith({ timeoutSeconds: 540, memory:
"512MB" })` with NO `failurePolicy: true` (grep: zero matches repo-wide). v1 background/
auth triggers do NOT auto-retry on a thrown error unless failurePolicy is set — so the
`throw error; // Retry` comment and the whole "idempotent under cascade retry" rationale
are load-bearing on a config that isn't there. Consequences: (1) a mid-cascade failure is
DROPPED, never retried → Art.17 erasure silently incomplete; (2) the double-decrement the
rework fixes can only arise from at-least-once DUPLICATE DELIVERY, not auto-retry (still
real, so the idempotency work is still worth it — just for the right reason). Decide:
add `failurePolicy: true` if failed erasures should retry, or drop the "// Retry" framing.

**LOW — stale comment.** `cleanupGroupMemberships`'s strict-mode rationale still says
"the reverse-friendship cleanup (D1) and friend-count decrement (D4) depend on a converged
friendUserIds state" — but post-merge D1+D4 run in step 1 BEFORE group memberships (step 3),
so that ordering claim is inverted. Comment only; no behavior impact.

**MEDIUM — test gap.** The new retry assertion in the integration test only covers the
happy path (friend WITH a public_profile). It does not cover the missing-profile poison
pill (HIGH above) nor the already-missing-reverse-doc self-heal branch (`if
(!reverseSnap.exists) continue`). Seed a friend whose `public_profile` is absent and assert
the cascade still completes + that friend's reverse doc is erased.

**Dart side (`lib/services/family/family_rating_service.dart`, BUT-1505) — reviewed
sound, deferred.** `_denormalizeFamilyAverage` now wraps the read-then-write of the owned
recipe doc in a `runTransaction`: `txn.get(recipeRef)` is the conflict anchor, then a
non-transactional `_ratings.getForRecipe` recompute, then `txn.update` of ONLY the two
`core.family*` fields. Correct: two concurrent denormalizations serialize on the recipe
doc and each recomputes from the authoritative store; partial-field update avoids clobbering
concurrent edits (the BUT-1505 bug). The ratings query isn't in the txn read set but the
recipe-doc anchor covers it. This is Flutter-side Firestore → owned by firebase-backend-
security; flagged sound, not deep-reviewed here.

### 2026-07-11 — BUT-1582 poison-pill FIX verified clean (closes the HIGH+MEDIUM above) [Bug fixed]

Reviewed the uncommitted fix to `cleanup/on-user-deleted.ts`
`cleanupFriendshipsAndDecrementCounts` that closes the HIGH poison-pill and the MEDIUM
test gap flagged in the 2026-07-11 BUT-1506 entry above. Verdict: **clean, no findings.**

The fix reads each friend's `public_profiles/{friendId}` doc in the SAME `db.getAll`
that already reads the reverse-friendship docs — refs concatenated
`getAll(...reverseRefs, ...profileRefs)`, then split
`reverseSnaps = snaps.slice(0, chunk.length)` / `profileSnaps = snaps.slice(chunk.length)`.
When the profile is absent it stages only the reverse delete + audit and `continue`s
BEFORE the decrement (no `set(...,{merge:true})` — a merge-set would resurrect a deleted
peer with a negative count, which is exactly why the plain skip is correct).

Verified rigorously, all 5 review axes clean:
1. **Slicing correct, no off-by-one.** `getAll` returns snapshots in request order
   (Admin SDK guarantee), and both ref arrays are built from the same `chunk` in the
   same order, so `reverseSnaps[j]` and `profileSnaps[j]` both key `chunk[j]`. Each ref
   yields a snapshot even when missing (`.exists===false`), so both slices are exactly N.
2. **Idempotency preserved.** The reverse doc is still the sole reprocessing gate
   (`if (!reverseSnap.exists) continue`); decrement is atomic with the reverse delete in
   one batch, so reverse-absent ⟺ decrement-already-committed. No double-decrement on
   retry. A profile-absent friend commits its reverse delete, so a later retry skips it —
   and no decrement was owed anyway. Consistent.
3. **Batch-size safe.** `FRIENDS_PER_BATCH = floor(500/4) = 125`. Present friend = 4 ops,
   absent = 2, already-processed = 0. Worst case 125×4 = 500 = BATCH_LIMIT exactly (≤500,
   allowed). No overflow. `batchOps++` moved to fire once per reverse-present friend — still
   just the "did we stage anything" guard for `if (batchOps>0) commit`, unaffected by the
   500 cap (chunk size enforces that statically). The 2N reads are BatchGetDocuments, not
   batch writes — irrelevant to the 500 write cap.
4. **Extra-read cost accepted, and it is the cheapest correct option.** 2N docs instead of
   N, but piggybacked on the pre-existing `getAll` → still ONE round trip on a rare
   account-deletion path. Alternatives are all worse: merge-set resurrects peers;
   per-friend try/catch means N commits; batch commit is all-or-nothing so a NOT_FOUND
   can't be caught per-op. Reading-before-writing is optimal here.
5. **Test bites.** New case seeds `friendNoProfile` (reverse edge, NO profile) sharing
   victim's single chunk with `friend` (profile friendsCount:3). Asserts friend's
   decrement 3→2 STILL commits (chunk not poisoned — the load-bearing assertion), the
   profile-less friend's reverse edge is removed, and no profile doc is resurrected.
   Summary friendsRemoved:2 / friendCountsUpdated:1 matches. Reported 17/17 emulator-green.

**Pattern worth remembering — piggyback the existence-probe onto the idempotency getAll.**
When a merged cascade batch mixes `batch.delete` (safe on missing) with `batch.update`
(throws NOT_FOUND on missing), and it already `getAll`s one set of docs for its idempotency
gate, add the update-target refs to that SAME `getAll` and skip the update when absent.
Costs 2N reads on one round trip, removes the data-driven poison pill, and avoids the
merge-set-resurrection trap. This is the general fix for any "update in a merged batch can
NOT_FOUND-abort a delete cascade" hazard.

### 2026-07-11 — BUT-1586 track-retention floor→ms boundary mirror [Pattern discovered]

Reviewed the uncommitted `classifyLifecycleStageServer` change in
`analytics/track-retention.ts` (+ 2 new boundary cases in
`__tests__/track-retention.test.ts`). Clean — no findings, 13/13 green under
`npx ts-node`. It mirrors the client BUT-1550 fix: replace
`Math.floor((now - x)/MS_PER_DAY)` day-truncation with full-ms comparisons on the
churned/dormant boundaries in BOTH the active and never-active branches.

**Why floor was a real bug (not cosmetic):** `Math.floor` truncates toward zero,
so `[30d, 31d)` collapsed onto day-30. A user last active 30d12h ago is elapsed
`>30d` (churned) but floored to `30`, and `30 > 30` is false → fell through to
`>= 14` → **dormant**. The app-emitted `lifecycle_stage` (already fixed client-side
in BUT-1550) then disagreed with this server event in that whole window.

**Boundary parity confirmed against the client classifier**
(`lib/services/analytics/lifecycle_stage_classifier.dart`), operator-for-operator:
churned `> 30d` (strict), dormant `>= 14d` (inclusive of 14). Server now matches on
both branches. The 30d edge stays dormant (not churned) on both sides.

**Scope call verified correct:** the server-only 7-day habitual/activated proxy
(`daysSinceSignup > 7 && daysSinceActive <= 7`) is deliberately left on floored-day
semantics — it's an approximation of the Dart side's `cooksLast14Days` (which the
daily aggregator can't cheaply compute), NOT part of the BUT-1550 mirror. Both
`daysSinceSignup` (line 70) and `daysSinceActive` (line 84) are still `Math.floor`
and are now consumed ONLY by that proxy. Note `daysSinceSignup` is computed at the
top so it's dead in the never-active path now (was used by that branch's old floored
check) — a harmless single `Math.floor`, not worth flagging.

**The two new tests genuinely bite the old code** (proved by construction, not run):
30d12h on the active branch → old `floor(30.5)=30`, `30>30` false, `30>=14` true →
returns `dormant`; the test asserts `churned`, so it would go RED on the pre-fix
code. Same arithmetic on the never-active branch. A test at exactly 30d (no sub-day
remainder) would NOT have bitten — the sub-day 12h remainder is load-bearing.

**Pattern worth remembering — floored-day boundaries silently mis-bucket the
sub-day remainder.** Any `> N` / `>= N` comparison on `Math.floor(elapsed/DAY)` or
Dart's `Duration.inDays` mis-classifies the `[N, N+1)` window because truncation
lands it on `N`. When two systems (client + server) must agree on a lifecycle/recency
boundary, compare raw elapsed (`ms` / full `Duration`), not truncated days, and pin a
regression test with a **sub-day remainder** (e.g. `N*DAY + 12h`) — a whole-day
fixture passes under the buggy floor and proves nothing.

### 2026-07-11 — BUT-1573/1577 rate-limiter: config-pin + per-user-before-global reorder [Bug fixed / Pattern discovered]

Reviewed two changes to `functions/src/middleware/rate_limiter.ts` (+ its daily-cap
test). Both verified: `tsc --noEmit` clean, `rate-limiter-daily-cap.test.ts` 12/12.

**BUT-1573 (clean).** `RATE_LIMIT_CONFIGS` is now `export`ed and three `dailyLimit`
values are pinned by tests (structureRecipe 100, ocrRecipeImage 50, importRecipe 100).
Values match production. Good defensive test — deleting/weakening a per-user LLM
spend cap now regresses a test instead of shipping silently. No finding.

**BUT-1577 (real bug fixed, with an accepted residual).** `withRateLimit` previously
called `checkGlobalLimit()` (which *atomically increments* the shared
`system/llmLimits` hourly+daily counters) BEFORE the per-user `checkRateLimit`. So a
user whose own per-user bucket/daily-cap denied the request still inflated the shared
global budget — one abuser could drain the global cap for everyone with requests that
never ran (cross-user DoS). Fix reorders: per-user gate first, global increment only
after per-user allows. Correct direction, comment is accurate.

**Residual worth knowing (rated Low, not blocking).** The reorder is not free — it
swaps the asymmetry. `checkRateLimit` commits its token-consume + `dailyCount++` in a
transaction BEFORE `checkGlobalLimit` runs. So when the global limit denies (at
capacity) OR fails closed on a Firestore error, the requester's own per-user token and
daily counter were already spent for a request that never executed. During a sustained
global-capacity event every user burns their per-user daily cap on rejected calls and
can lock themselves out for the rest of the UTC day even after global frees up. This is
strictly better than the old cross-user harm (self-limited, no DoS), and the caps are a
soft cost-shaping lever, so accepted. A clean fix would need a global *peek* (read-only)
before the per-user consume, then a global *commit* after — but `checkGlobalLimit`
couples read+increment in one transaction; separating them wasn't in scope.

**Pattern — a two-stage gate where each stage has a side effect has NO free ordering.**
Whichever gate you run first, a denial by the second gate strands the first gate's
mutation. Put the gate whose side effect is *shared/cross-user* last (so a denial only
ever wastes the requester's *own* budget), which is exactly what this fix does. When
reviewing any "reorder the checks" fix, ask: does the now-first check mutate state, and
what does a later-check denial leave stranded?

**Coverage gap (Low).** The new tests only pin config values (BUT-1573); the BUT-1577
reorder — the actual behavioral fix — has NO test. `withRateLimit` is hard to unit-test
because `checkGlobalLimit` reads/increments `system/llmLimits` via `admin.firestore()`
directly with no injectable seam (only the *limits loader* is seam-injectable via
`__resetGlobalLimitsCacheForTest`, not the counter transaction). Pre-existing
testability limitation, consistent with the file having no `withRateLimit` test before.
If this ordering is ever tightened again, add a `firestoreForTest`-style seam to
`checkGlobalLimit` first so the order is pinnable.

**onCall retry note:** `withRateLimit` wraps *callables*, which the Firebase SDK does
NOT auto-retry on a thrown `resource-exhausted` — so the double-consume-on-retry worry
from the trigger idempotency rules does not apply here. The knowledge file's
idempotency section is about Firestore triggers; this is a callable gate.

### 2026-07-11 — BUT-1577 the missing ordering regression test [Pattern discovered]

Reviewed `functions/src/__tests__/rate-limiter-withratelimit-ordering.test.ts` (+ its
`test:rate-limiter-ordering` npm script) — the test that closes the "reorder has NO
test" coverage gap flagged in the entry above. Clean, no findings. 2/2 pass, tsc clean,
no emulator. Registered at package.json:118; `run-all-tests.js` auto-discovers it (not
under `test:rules`/`test:integration:` excludes), and each suite runs as its own
`npm run` child process so module-scope seam state (`firestoreForTest`,
`cachedGlobalLimits`, `globalLimitsLoaderForTest`) can't leak across files regardless.

**How it pins ordering without a counter seam.** `checkGlobalLimit` still has no
injectable Firestore handle (only the *limits loader* is seam-injectable). The test
turns that limitation into the probe: it installs a loader via
`__resetGlobalLimitsCacheForTest(async () => { globalChecked = true; ... })`. Since
`loadGlobalLimits()` is the FIRST line of `checkGlobalLimit`, the loader firing is that
function's earliest observable side effect — so `globalChecked` is a clean spy for
"was the global gate entered." Per-user doc is fed via `__setFirestoreForTest`.

**Why case 1 genuinely bites a reverted order.** Per-user-DENIED (seed `dailyCount:100`
== structureRecipe's `dailyLimit:100`, `dayKey` = live UTC key so the cap trips): asserts
`globalChecked === false` + the per-user Swedish message (`för många förfrågningar`). Swap
the order back (global first) and `checkGlobalLimit` runs before the per-user gate →
loader fires → `globalChecked` true → case 1 goes RED. Proven by construction. Case 2
(per-user-ALLOWED) is NOT an ordering guard on its own — with no test app,
`checkGlobalLimit` fail-closes to the global denial in BOTH orders, so its
`globalChecked === true` + global-message asserts pass either way — but it's not vacuous:
it pins that a per-user *allow* actually REACHES the global gate and the handler stays
unrun (would fail if the per-user gate wrongly denied, or if the handler leaked through).
Case 1 carries the ordering claim; case 2 carries the pass-through claim.

**No-app safety confirmed.** On the denied path `withRateLimit` calls
`logRateLimitViolation` → `admin.firestore()` with no initialized app throws
synchronously, but inside that helper's own try/catch → warn-logged, never propagates.
`admin.firestore.Timestamp.now()/fromDate()` are static namespace accessors that need no
app. So the suite is genuinely emulator-free.

**Pattern — when only one collaborator in a sequence is seam-injectable, spy on its
earliest side effect to pin ORDER even if you can't observe its full behavior.** You
don't need a full counter seam to prove "A runs before B"; a boolean set on B's first
line, plus which of the two error MESSAGES surfaces, is enough to make a reverted order
go red. Keep the deny-side fixture at the exact cap boundary so the first gate is the one
that trips.

### 2026-07-11 — BUT-1511 onFamilyRatingUpdated memberType-flip recompute [Pattern discovered]

`onFamilyRatingUpdated` recompute gate extracted to
`ratings/family-rating-recompute.ts` (`isProfileRating` +
`shouldRecomputeOnFamilyRatingUpdate(before, after)`) so the decision is
unit-testable without importing index.ts. New test
`__tests__/family-rating-recompute.test.ts` (5 cases, uses `_unit-runner`;
`test:family-rating-recompute` auto-discovered by both run-all + CI runners).
Build + test green.

The fix: an UPDATE that flips memberType `user`→`profile` with UNCHANGED stars
used to skip recompute (old gate was `after-is-profile` then `before.stars !==
after.stars`), so a row newly counting toward the public average never got
folded in. New gate recomputes when stars changed OR memberType changed, still
requiring `after` to be `profile`.

**Residual asymmetry worth remembering (flagged Low, documented out-of-scope in
the code):** the fix is one-directional. A DEMOTION `profile`→`user` is
short-circuited by the `!isProfileRating(after)` guard, so the demoted row's
stars stay folded into `recipe_social_stats` (aggregator queries
`family_ratings where memberType == "profile"`) until the NEXT rating event on
that recipe triggers a recompute. Self-heals, bounded, rare — but if promotion
is worth handling, demotion is too. Fully-correct gate would be membership-XOR:
`const w=isProfileRating(before), i=isProfileRating(after); if(!w&&!i) return
false; if(w!==i) return true; return before?.stars!==after?.stars;`. Left as the
ticket scoped only the recompute condition.

### 2026-07-12 — BUT-1567 crossed-since-last-run window can overlap across thresholds [Pattern discovered]

`analytics/detect-lapsed-users.ts` replaced the old fixed ±12h band per
threshold with a cursor-driven "crossed since last run" window
`(lastRun − N·days, now − N·days]` for N ∈ {7,14,30}. The window WIDTH equals
the cursor gap `(now − lastRun)`. Normal daily runs → ~1-day windows that never
overlap. **But on outage recovery — precisely the scenario the change targets —
the gap can exceed 7 days, and the 7/14/30 windows then OVERLAP.** A single user
(e.g. `lastActiveAt = now−15d` with a 10-day-stale cursor) legitimately crossed
both 7d and 14d during the outage and matches BOTH windows in one run → they get
stacked mild + moderate win-back notification docs + duplicate analytics events
in the same run. The old ±12h bands (24h wide, ≥6 days apart) were structurally
immune to this, so it is a REGRESSION introduced by BUT-1567. There is no
per-run dedup across thresholds.

Mitigations already present (why it's Medium not High): the BUT-1428 bridge gate
protects the A/B attribution field (only the first-processed threshold writes
`lastWinBack*`, later ones see it fresh and skip); and the push fatigue rate-cap
(`evaluateSendGate` + recorded send-event) likely suppresses the second/third
PUSH within the same run. What is NOT suppressed: the extra in-app notification
docs and the extra analytics `events` rows. Fix if pursued: track processed uids
across thresholds within the run and skip already-notified users, or select each
user's single highest crossed threshold.

Other notes from the same review:
- **Unbounded users scan + sequential per-user context reads.** `db.collection("users").where(...).get()` has no `.limit()`, and each matched user is awaited through `resolveContext` (a Firestore read) in a serial for-loop. On a wide catch-up window the matched set can be large — memory + the default 60s `onSchedule` timeout are both at risk. `onSchedule` here sets no `timeoutSeconds`/`memory`. Consider a `__name__`-cursor page loop (`shared/batch-update.ts`) + parallelizing the context reads.
- **`notificationSent: true` on the analytics event is written unconditionally** (batch, before the push gate). The push may still be dropped (opt-out / quiet-hours / rate-cap), so the field overstates delivery — it really means "in-app notification doc written".
- **Test-fake doc-id collision:** in `makeFakeDb`, auto doc ids use `store.writeCount`, which only increments on `commit`, not on `.doc()` creation. Multiple analytics-event docs created inside one batch therefore share the same `auto_<n>` path and overwrite each other in the store Map. Harmless for current single-user-per-batch assertions, but it would mask any future test that asserts on multiple analytics events. Fix: bump a counter at `.doc()` time.

### 2026-07-12 — cleanup-pagination: self-advancing drain vs `__name__` cursor [Pattern discovered]

Reviewed `cleanup/cleanup-old-notifications.ts` (limit→loop pagination) +
`firestore.indexes.json` (added `social_requests (status ASC, sentAt ASC)`).

- **Self-advancing drain is the correct pagination for a delete/filter-mutating
  sweep, and it is NOT the same primitive as `batchUpdateQueryPaginated`.**
  cleanup-old-notifications now loops `where(ts<cutoff).limit(BATCH_LIMIT).get()`
  → `batchDeleteDocs` → repeat until `snapshot.size < BATCH_LIMIT`. No
  `startAfter` cursor: the delete removes the doc from the filter, so the next
  page returns fresh rows. This is the ONLY safe paginator when the loop body
  changes a field the base query filters on. `batchUpdateQueryPaginated`
  (`shared/batch-update.ts`) orders by `__name__` with a `startAfter` cursor and
  its own docstring warns "the update must not change a field the base query
  filters on, otherwise the cursor could skip or revisit docs." So for a drain
  that flips the filtered field, use the self-advancing bounded loop, never the
  `__name__`-cursor helper.

- **`cleanup-expired-social-requests.ts` is the remaining pagination gap this
  sprint's index serves but did NOT fix.** It flips `status pending→expired` via
  `batchUpdateQuery` — a single unbounded `query.get()` (no `.limit()`), loading
  every matching doc into memory. It legitimately can't use
  `batchUpdateQueryPaginated` (it mutates the filtered `status` field → cursor
  skip). The right fix is the same self-advancing bounded loop
  cleanup-old-notifications now uses (query `.limit(BATCH_LIMIT)` → update →
  repeat; expired rows drop out of `status == pending`). Out of the reviewed
  two-file scope; flagged for the sprint owner.

- **The added `social_requests (status ASC, sentAt ASC)` composite is correct AND
  was genuinely missing.** The query `where("status","==","pending")
  .where("sentAt","<",cutoff)` is equality + range on DIFFERENT fields ⇒ needs a
  composite (not an equality-only case). `queryScope: COLLECTION` is right (it's
  a top-level `db.collection(...)`, not a collectionGroup). Since the CF landed
  in BUT-772 without this index, the weekly job has been throwing
  FAILED_PRECONDITION on every non-empty run — masked only by pre-launch ~0 data.
  Index addition is a real fix, not decoration.

- **LOW nit carried in cleanup-old-notifications:** `logger.error("Notification
  cleanup failed", e)` passes the raw Error as the structured second arg. House
  convention is `logger.error("...", { err: e })` so Cloud Logging keeps the
  stack/fields as structured data. Not a behavior bug.

### 2026-07-12 — BUT-1592 closed the demotion gap (membership-XOR shipped) [Pattern discovered]

The residual asymmetry flagged Low in the 2026-07-11 BUT-1511 entry is now
fixed. `shouldRecomputeOnFamilyRatingUpdate` is the exact membership-XOR gate
that entry predicted: `if(!wasProfile && !isProfile) return false; if(wasProfile
!== isProfile) return true; return before?.stars !== after?.stars;`. A demotion
`profile`→`user` with unchanged stars now recomputes immediately, so the demoted
row drops out of `recipe_social_stats` without waiting for the next rating event
on that recipe. `onFamilyRatingUpdated` reads `after.recipeId` for the schedule
target — safe because `family_ratings` doc id is `recipeId|memberId`
(`FamilyRating.buildId`), so an update never changes the row's `recipeId`.

Reviewed the two-file diff clean (no Critical/High). Test grew to 6 cases and
BOTH regression guards bite against the old `after`-only gate: the promotion case
(#1) and the demotion case (#5) each go RED if the gate reverts. 6/6 green,
`ts-node` run confirmed.

**Minor notes (not blockers):**
- The `runTests` label is still the stale `"BUT-1511: family-rating recompute
  gate"` even though the suite now proves BUT-1592 too. Cosmetic — the label is
  only console output, not a test key. Worth a one-word update next touch.
- Two edges uncovered by the 6 cases: a simultaneous flip + star change (e.g.
  `user(3)`→`profile(5)` — handled by the flip branch, returns true) and
  `undefined` `before`/`after` (the `Data` type admits undefined;
  `isProfileRating(undefined)` is false, so undefined/undefined → false). Both
  behave correctly by construction; adding them would harden against a future
  refactor of the branch order. Low.

### 2026-07-12 — SALVAGE re-review of force-committed 6f0942408: both FAIL votes were false positives [Pattern discovered]

Commit `6f0942408` was force-landed on main by refreshing the review markers 44s
before commit, with no specialist re-review of the final diff (harness raised a
security warning). Code is on main but NOT deployed (functions deploy is manual),
so it was re-reviewed fix-forward. Two fresh verification voters had marked
CORRECTNESS:FAIL on `detect-lapsed-users.ts` and INTENT:FAIL on the
`cleanup-old-notifications.ts` drain loop. **Both refuted — nothing blocking.**
Build clean; `detect-lapsed-users` 25/25 green; `family-rating-recompute` 6/6
green; both suites re-run under ts-node.

- **detect-lapsed CORRECTNESS:FAIL is a false positive.** Traced the
  crossed-since-last-run window math: a user crosses threshold N at
  `lastActiveAt + N·days`; catching crossers since `lastRun` gives
  `lastActiveAt ∈ (lastRun − N·days, now − N·days]`, which is exactly the code
  (`> alreadyCrossedAtLastRun` exclusive, `<= crossedByNow` inclusive). In steady
  daily runs these intervals tile perfectly per threshold — no gap, no daily
  re-notify (proven by the "already past thresholds … NOT re-notified" test). The
  degenerate guard reduces to `lastRun >= now` (clock-back / same-instant) → skip,
  correct for all thresholds. First run bounded by `DEFAULT_CURSOR_LOOKBACK_MS`
  (proven by the "bounded lookback / no backfill" test). The only real issues are
  the two already-documented NON-blocking ones from the same-day entries above:
  the >7-day-outage threshold-overlap burst (Medium) and unbounded users scan
  during wide recovery (Medium). Neither is a wrong result.

- **cleanup drain INTENT:FAIL is a false positive.** The self-advancing loop
  satisfies BUT-1563 (drain past the old 10k cap). Termination: `cutoff` is fixed
  at function start so new docs (`sentAt ≈ now > cutoff`) never enter the matching
  set — it only shrinks; loop ends on empty page or `size < BATCH_LIMIT`. No skip:
  no `orderBy`/cursor, but every read doc is deleted so the next page is always
  fresh smaller-timestamp rows (delete-advances-window is CORRECT precisely
  because the loop body flips the filtered field). No 500-op overflow:
  `limit(BATCH_LIMIT)` ⇒ snapshot ≤ 500 ⇒ one `batchDeleteDocs` commit of ≤500.
  Self-heals across weekly runs on a mid-drain timeout. Only genuine gap is
  "no test" — already filed BUT-1595, not a code defect.

- **The task's index premise was inverted — worth remembering.** The added
  `social_requests (status ASC, sentAt ASC)` index does NOT correspond to any
  query in `cleanup-old-notifications.ts` (that file's `where(ts<cutoff)` is a
  single-field inequality needing only the automatic index). It serves
  `cleanup-expired-social-requests.ts` (`status == pending` + `sentAt < cutoff`),
  and there it is fully correct (COLLECTION scope; equality field before range;
  `sentAt` ASC matches the implicit ascending sort of a no-orderBy range). The
  commit message misfiles it under the BUT-1563 bullet. When a review task hands
  you an index-to-query mapping, verify the mapping itself — the commit narrative
  can point at the wrong file.

- **Region/cold-start/cost all clean** across the three files: all inherit
  `europe-west1` from `setGlobalOptions` (no per-function region), no new SDK,
  one extra cursor read+write per lapsed-users run (negligible).

- **Deploy-order note (non-blocking):** `cleanupExpiredSocialRequests` has been
  throwing `FAILED_PRECONDITION` on every non-empty run since BUT-772 (index was
  missing); the new index fixes it, but deploy the index before/with the
  functions so the weekly job stops erroring. Strictly an improvement over the
  current broken state.

### 2026-07-14 — BUT-1595 drain tests + BUT-1592 family-rating demotion gate [Pattern discovered]

Follow-up sprint landing the tests the prior salvage entry flagged as the only
real gap, plus a family-rating gate correctness fix. Reviewed clean — no
Critical/High/Medium. `cleanup-old-notifications` 4/4 and
`cleanup-expired-social-requests` 2/2 green under ts-node; both wired into
package.json (`test:cleanup-old-notifications`, `test:cleanup-expired-social-requests`)
so `run-all-tests.js` auto-discovers them.

- **`cleanupCollection` got a bounded-iteration backstop (`MAX_DRAIN_ITERATIONS
  = 20000`) + was exported for testing, with `maxIterations` as an injectable
  last param.** Real value of the cap: a non-shrinking page would otherwise loop
  to the ~60s scheduled-function timeout, and a *timeout is a failure* that can
  trigger a retry — the graceful logged `break` converts a retry-prone crash into
  a clean partial-and-resume. Not merely cosmetic. The cap is a total-pass count,
  not a shrink-detector (20000×500 = 10M docs backstop), which is the right
  trade: simpler, and a legit drain never approaches it.

- **Test fidelity is good but deletedCount counts docs ATTEMPTED, not removed.**
  In the non-shrinking guard test the fake's `ref.delete()` is a no-op yet
  `batchDeleteDocs` still returns `snapshot.docs.length`, so `deletedCount ==
  BATCH_LIMIT*5`. Mirrors production: in the pathological silent-delete-failure
  case the reported `totalDeleted` (and the `system_events` doc) would be
  inflated. Bounded to the pathological path and logged as ERROR — accepted, not
  a finding.

- **BUT-1592 family-rating gate now recomputes on memberType flip in BOTH
  directions.** `shouldRecomputeOnFamilyRatingUpdate` (in
  `ratings/family-rating-recompute.ts`, imported by index.ts:38) was `after`-only
  (promotion INTO `profile`, BUT-1511); the demotion case (row leaving `profile`)
  short-circuited and left the public average stale. Fix: `wasProfile !==
  isProfile ⇒ recompute`. Verified NO double-count: the aggregator
  `updateRecipeRatingStats` re-reads `family_ratings where memberType=="profile"`
  in full and `set(merge)`s one stats doc, so a demoted row simply stops matching
  and drops out — idempotent by construction (consistent with the 2026-06-29
  aggregator entry). Both-non-profile updates still cost zero recompute. Correct.

- **Pre-existing (NOT in this diff, noted for the next editor):**
  `cleanupOldNotifications`'s catch does `logger.error("Notification cleanup
  failed", e)` — passes the raw Error as the structured second arg instead of the
  house `{ err: e }` shape (loses the queryable object wrapper). Low; leave unless
  touching that block.

### 2026-07-14 — BUT-1600 family-rating orphan reconciliation in the dormancy sweep [Pattern discovered]

`family/purge-dormant-family-data.ts` gained a per-household, per-sweep orphan
reconciliation (`reconcileDepartedMemberRatings` + `recomputeDenormalisedAverages`)
that runs BEFORE the dormancy judgement, deletes `family_ratings` whose `memberId`
is no longer in the roster (`memberUserIds` ∪ diner-profile doc ids), recomputes the
denormalised `core.familyAverage`/`core.familyRatingCount` on each member's own
recipe copy from the survivors, and returns the survivor set so dormancy/purge act on
the pruned data. Build clean (tsc --noEmit exit 0). Reviewed patterns/risks:

- **Recompute robust to both share models via the `.exists` filter.** It iterates
  `users/{eachMember}/recipes/{recipeId}` but filters `s.exists && hasDenormFamilyValue`,
  so it correctly patches only copies that actually hold a family pill — mirroring the
  client denorm (`family_rating_service.dart:154` `if (!snap.exists) return`). Works
  whether the household recipe is a shared single doc (only owner's subcollection has it)
  or per-member copies. No wrong-doc-id bug. Star validity `stars<1||stars>5` matches
  the client's `hasValidStars` (family_rating.dart:88), and it aggregates all memberTypes
  like `FamilyRatingSummary.fromRatings` (not profile-only). Verified consistent.

- **RISK (Medium): the orphan delete is ungated + destructive + irreversible, keyed
  solely on two query snapshots.** Unlike the dormancy purge (warn + 30d grace +
  strict), reconciliation deletes regulated family-rating data the instant a memberId
  isn't in the roster, every sweep, strict:false. A transiently empty/incomplete
  `memberUserIds` (mid-migration, bad read) or a diner_profile with a missing
  `householdId` (dropped from the `where(householdId==)` query) would mark legitimate
  ratings as orphans and delete them permanently, recomputing averages down. There is
  NO defensive guard. Recommend: skip reconciliation when `rosterMemberIds` is empty
  (roster.size===0 with ratings present is almost certainly a bad read), and/or require
  memberUserIds non-empty. Pattern: a destructive delete driven by "not present in a
  live query" must guard against the query itself being under-populated.

- **RISK (Low): warn-before-stamp idempotency inversion (pre-existing, unchanged).**
  `warnMembers` runs before the `familyDataPurgeScheduledAt` stamp; if the stamp write
  fails the run throws → scheduler retries → the still-unscheduled household re-warns
  (duplicate `user_notifications`). Best-effort, low impact, but the knowledge-file
  send-then-guard rule prefers the guard first.

- **Test gap (Medium): the memberUserIds roster branch is untested.** The integration
  test's only orphan is a profile-type `ghost`, matched out via the DINER half of
  `rosterMemberIds`; the valid rating is also a diner. So the `memberUserIds` spread in
  `rosterMemberIds` is never the deciding matcher — a regression dropping it would keep
  the test green while deleting real account-holder (user-type) ratings, which is the
  headline BUT-1600 "departed account holder" scenario. Also untested: recompute
  clearing the pill to null (all-orphan recipe) and multi-recipe orphans.

### 2026-07-14 — BUT-1604 deletion_audit_logs TTL purge extracted for testability [Pattern discovered]

`cleanup/cleanup-audit-logs.ts` — the inline `deletion_audit_logs` TTL reap
inside the `cleanupOldAuditLogs` scheduler was extracted to
`purgeExpiredDeletionAuditLogs(db, now = Timestamp.now())`, a pure DI-seam
delete function returning the count. New test `__tests__/cleanup-audit-logs.test.ts`
(4 cases, green) with a fake db modelling `where('expireAt','<',now).limit(n).get()`
+ `batch().delete()/commit()`. Wired `test:cleanup-audit-logs` into package.json;
run-all-tests.js AND run-ci-unit-tests.js both auto-discover it (no CI_EXCLUDE),
so it lands in the cloud-functions-unit CI gate. tsc clean. No Critical/High.

Reviewed clean; only latent/cosmetic notes (recorded so a future reviewer
doesn't re-flag them as bugs):
- **`.limit(10000)` cap is self-healing here, unlike the family-purge starvation.**
  This weekly reap re-queries `expireAt < now` each run; any overflow beyond 10k
  in one week stays expired and is caught next week — no shifting-subset starve
  (contrast `purge-dormant-family-data`'s `.limit(200)` no-cursor scan, which
  can starve overflow permanently). At beta scale deletion_audit_logs volume is
  tiny. Low/latent, not a fix.
- **`system_events.add` runs AFTER the delete inside the same try.** If the
  observability `add` throws, the CF rethrows → scheduler retries → purge re-runs
  (idempotent, deletes remaining/0) and writes a second, lower-count row. Cosmetic
  observability skew only; the data delete is idempotent. Not worth reordering.
- **`logger.error("...", e)` (lines ~86, ~145) passes the raw error as the 2nd
  arg** rather than the house `{ err: e }` structured object. Pre-existing (outside
  this diff), so not filed against this change, but flag it if the file is touched
  again — the convention loses queryable structure otherwise.
- firestore-rules.yml + test:rules:all also gained `functions/src/family/**` and
  `purge-dormant-family-data.integration.test.ts` triggers in the same commit —
  correct missing-wiring backfill, unrelated to the audit-log extraction.

### 2026-07-16 — C10/BUT-1518 repool telemetry review: re-fire on every touch + backfill fingerprint drift [Pattern discovered]

Reviewed the uncommitted C10 diff (`ratings/canonical-rating-aggregation.ts` repool
telemetry + `ingredientsFingerprint` stamping, its test suite, app-check exemptions).
tsc clean; 22/22 + 14/14 green. Two Medium findings, both proven, not merely reasoned:

- **MEDIUM — transition telemetry keyed on a FROZEN artifact re-fires forever.** The
  old pool event is never deleted (frozen semantics, decided), and it keeps carrying
  the same `recipeId` — so the "prior event for this recipeId at a different poolKey"
  detection matches on EVERY subsequent rating write after one edit-repool, not just at
  the transition (probe: touch3/touch4 both logged `anchor_only_title_change` again).
  An abuse counter inflates per innocent touch. General rule: when detecting a
  TRANSITION by querying immutable history, also check whether the DESTINATION state
  already exists (`priorSnap.docs.some((d) => d.id === poolKey)` — doc-id IS the
  poolKey) and skip when it does; the test suite's "plain re-rate → no telemetry" case
  only covered the no-prior-repool variant, so the re-fire was structurally untested.
- **MEDIUM — adding a stamped field to a shared derivation helper silently strands its
  OTHER consumer.** `recipeContentToKey` now returns `ingredientsFingerprint`, the live
  mirror stamps it — but `migrations/backfill-canonical-ratings.ts` (which imports the
  helper precisely to avoid drift) still writes events WITHOUT it, and its non-merge
  `batch.set({poolKey, ratingValue, recipeId, createdAt})` would STRIP a fingerprint
  the live mirror already stamped when overwriting a non-identical event. Backfill is
  hard-gated/never-run, so fix before first run. Rule: when a shared helper gains a
  returned/stamped field, grep every importer and reconcile their write shapes +
  identical-skip comparisons in the same change.
- Low notes: the prior-events query also runs on CREATE writes where it provably
  returns empty (delete branch always retracts by recipeId) — 1 wasted billed read on
  the most common path, gate on `input.before !== null`; and
  `logger.info(JSON.stringify({...}))` claims to be "the idiom of this pipeline's
  counters" but the live pipeline's trigger logs use the house
  `logger.info("stable.string", {fields})` shape — only the migrations use
  JSON.stringify. recipeId+hashUid in the log payload are GDPR-clean.
- App-check exemption additions verified genuine: `reviewLearnedAlias`/
  `revokeLearnedAlias`/`backfillCanonicalRatings` all call `requireAdmin(request)`
  first thing (read the handlers, not just the header comments).
- Gotcha rediscovered: `backfill-canonical-ratings.ts` contains a literal U+0000 in a
  Map-key template (`${uid}<NUL>${poolKey}` as a raw byte) — ripgrep treats the whole
  file as BINARY and silently skips it. Grep-based sweeps miss this file; use
  node/Read. Prefer the backslash-u0000 escape sequence in source.

### 2026-07-17 — BUT-1623 App-Check ADMIN_EXEMPT classification confirmed sound [Pattern discovered]

Independently confirmed (not just "test green") that adding `reviewLearnedAlias`,
`revokeLearnedAlias` (analytics/review-learned-alias.ts:216/235) and
`backfillCanonicalRatings` (migrations/backfill-canonical-ratings.ts:373) to
`ADMIN_EXEMPT` in `app-check-enforcement.test.ts` is the CORRECT classification, and the
exemption is SAFE. No findings — classification sound.

Why exempting an admin-claim callable from App Check is correct, and the established
pattern: **App Check attests the app binary; the admin custom claim attests the caller's
authorization** — they guard orthogonal threats. An admin-only callable that fails closed
for non-admins doesn't need app attestation (admin ops run from a console / ops scripts
where App Check adds friction with no matching threat reduction; the guard's own docstring
at lines 55-61 states exactly this). The safety hinges on `requireAdmin` actually blocking:
confirmed in `shared/require-admin.ts` it throws `unauthenticated` when `!request.auth` and
`permission-denied` unless `token.admin === true || token.role === "admin"` — fails closed,
no fall-through. All three new callables call `requireAdmin(request)` as the FIRST executed
statement inside the handler (before any read/side effect), so a non-admin is rejected
before anything runs; `backfillCanonicalRatings` adds a second hard gate (refuses a real run
unless `enable_pooled_ratings` is ON).

The three follow the identical convention as every existing ADMIN_EXEMPT entry —
spot-checked `getCorrectionStats`, `getAuditLogStats`, `getUnmatchedIngredientStats`,
`getRetagStatus` all open with `requireAdmin(request)`; `bulkMarkForRetagging` inlines the
equivalent `token.admin === true` check. None of the exempt callables carry
`enforceAppCheck: true` — admin-claim gating is the exemption basis, by design. No
accepted-deviations entry touches App Check, so nothing to reconcile.

**Rule for classifying a new onCall into this guard:** ADMIN_EXEMPT is justified iff the
handler's FIRST statement is `requireAdmin(request)` (or the inline `token.admin === true`
equivalent) — read the handler body, never trust the header/inline comment. A callable
reachable by an ordinary authenticated user belongs in USER_FACING with
`enforceAppCheck: true`, not ADMIN_EXEMPT.

### 2026-07-18 — BUT-1518/1624 pool-key dimensions telemetry + binary-blob CI guard [Bug fixed / Pattern discovered]

Reviewed the C10 rating-laundering-visibility change across 5 files (pool-key
component split, mirror telemetry line, backfill key-delimiter fix, CI binary
guard, test). tsc clean, `canonical-rating-aggregation.test.ts` 21/21 green, CI
glob verified to match all 218 `functions/src/` files, backfill file no longer
carries a NUL.

**The good (positive changes, no finding):**
- `computePoolKey` refactor to delegate to a new `poolKeyComponents(title,ings)`
  keeps the key byte-identical (`anchor + "::" + names.slice(0,12).join("|")`
  hashed the same) → **TS↔Dart parity holds**, `ingredientSig` is a NEW
  server-only 8-hex sig of the ingredient-names-only hash; Dart twin needs no
  change (parity is only on `computePoolKey`'s output). Single-sourced, no C5
  drift.
- Backfill winners-Map key `${uid}/${poolKey}` replaces a NUL (`\0`) separator
  that had made the whole file a git BINARY blob (undiffable/unreviewable).
  `/` is collision-free: both are Firestore doc IDs (uid alphanumeric, poolKey
  = `v1:hex`), neither contains `/`, and the string is never parsed back. Correct
  fix.
- CI `functions-binary-guard` in test.yml (`git ls-files -z 'functions/src/**' |
  xargs -0 -r grep -laP '\x00'`) automates the lesson "a new source file can land
  as a git binary blob." Glob `functions/src/**` == `functions/src` (both 218
  files) — works. Cheap, no toolchain. Good.

**MEDIUM — logging convention violated (queryability + no precedent).** The
telemetry line is `logger.info(JSON.stringify({tag:"pool_key_dimensions", uid,
recipeId, poolKey, anchor, ingredientSig}))` — everything crammed into the
message STRING. The knowledge convention is first-arg = stable string, second-arg
= structured object; a stringified JSON is NOT a queryable `jsonPayload` in Cloud
Logging, so the feature's own stated goal ("separable OFFLINE" by querying
anchor/ingredientSig/poolKey) is undercut. No precedent in the codebase — the
sibling `ratings/update-pooled-rating-stats.ts:96` already does it right
(`logger.info("pool_aggregation.updated", {…})`). Fix:
`logger.info("pool_key_dimensions", { uid, recipeId, poolKey, anchor,
ingredientSig })`. NB the test parses the message as JSON, so it must change with
the code (couples test to the wrong impl).

**MEDIUM — cleartext `anchor` is title-derived and can be a personal name.**
`anchor` = the longest significant title token (diacritics-folded, lowercased).
Swedish recipe titles routinely lead with a name ("Annas paj" → `annas`,
"Mormors …" → `mormors`), so the logged token can be a given name attached to a
`uid` in the same line — the exact "recipe titles that might contain user names"
the logging convention forbids. And the cleartext anchor is NOT needed for the
laundering signal: the detection invariant is stable `ingredientSig` + moved
`poolKey` across a recipeId's events (anchor-only change) vs moved `ingredientSig`
(real dish change) — both computable without cleartext. Fix: log an
`anchorSig` (hash) instead of, or drop, the cleartext `anchor` — grouping/change
detection survives, PII does not leak.

**LOW/INFO — double key computation + injected-computeKey inconsistency.** Per
upsert the normalization+hash now runs twice (once via `computeKey`→
`computePoolKey`→`poolKeyComponents` inside `recipeContentToKey`, once directly as
`poolKeyComponents(keyed.title, keyed.ingredients)` for telemetry), and
`computePoolKey` now always computes the extra `ingredientSig` sha256 even for
callers that discard it. Negligible CPU (sha256 of short strings). Also the
telemetry calls `poolKeyComponents` directly rather than the injected
`deps.computeKey`, so under a test-injected custom `computeKey` the logged
`poolKey` (from the override) and `anchor`/`ingredientSig` (from real
`poolKeyComponents`) could disagree — prod-safe (computeKey === computePoolKey),
test-seam only.

### 2026-07-18 — BUT-1454 verifySignupAge threads isMinor back in the response [Pattern discovered]

Reviewed the uncommitted BUT-1454 slice: `verify-signup-age.ts` now adds an
`isMinor: boolean` field to `VerifySignupAgeResponse` and returns it on all four
exit paths (rejected → `false`; idempotent-retry → the derived `isMinor`; first
pass → the derived `isMinor`). `isMinor` is derived ONCE at the top
(`compliant && age < AGE_OF_MAJORITY_YEARS`) so it is in scope in the idempotent
branch — verified. CF side is clean: no new write, so zero idempotency/retry
surface added (it is a response field only, not a Firestore mutation); no
per-function region added; no secrets. `tsc --noEmit` clean, `verify-signup-age.test.ts`
10/10, with new assertions pinning `result.isMinor` on adult / minor / retry /
rejected paths.

The design (verified end-to-end): the CF still does NOT write
`public_profiles.isSearchable`. Instead the minor flag rides the response →
`AgeVerificationService.verifyAge` returns a new `AgeVerificationResult(compliant,
isMinor)` (was a bare `bool`) → onboarding VM captures `_isMinor` at the gate AND on
the belt-path re-check → `completeOnboardingWithPreferences(isMinor: …)` ORs it with
the in-memory profile's existing value (monotonic, never downgrades a server-set
flag) → `UserProfile.toFirestore` derives `'isSearchable': isMinor ? false :
isSearchable`. That serializer is the single `public_profiles` chokepoint: both the
create path (`firebase_user_repository:159 toFirestore()`) and the edit path
(`:172 toFirestoreEditable()` → built from `toFirestore()`) run through it, so a
minor is kept out of search on EVERY profile write. Search reads
`public_profiles.where('isSearchable', ==, true)`, so the minor's doc never surfaces.
Test wiring solid — all 11 `onboarding_viewmodel_test` + 4 `onboarding_journey_test`
mocktail stub/verify sites updated with `isMinor: any(named:'isMinor')` (a missed
one would fail to match the now-parametrized call), and the search-repo test writes
REAL profiles through `toFirestore()` to prove the wiring, not a hand-set flag.

**Residual (Low, handed to firebase-backend-security, pre-existing + BUT-674-accepted):**
suppression only takes effect when the CLIENT writes `public_profiles` with
`isMinor:true` — i.e. at onboarding completion. The initial profile creation
(`user_service.dart:200`, `isSearchable: isSearchable ?? true`, isMinor defaulting
false) happens before onboarding completes, so a 15–17 minor is discoverable in the
window between initial profile write and completion, and PERMANENTLY if onboarding is
abandoned after the initial write. This matches the CF comment's "no regression"
framing (the CF deliberately doesn't write public_profiles to dodge the follow-up),
so it's an accepted residual of the BUT-674 phasing, not a defect in this diff — but
it partially limits the feature's stated "default-private" intent. A full close needs
either the CF writing `public_profiles.isSearchable:false` for minors, or the initial
onboarding profile creation to carry isMinor.

### 2026-07-18 — BUT-1518/1624 telemetry salvage: hash the anchor, not just the ingredients [Bug fixed / Pattern discovered]

Reviewed the uncommitted BUT-1518 (rating-laundering telemetry) + BUT-1624 (binary-blob
delimiter) salvage batch. tsc clean, `canonical-rating-aggregation.test.ts` 21/21.

**Verified clean:**
- `computePoolKey` byte-identical after the `poolKeyComponents` refactor: the sha256 input
  is still `anchor + "::" + names.slice(0,12).join("|")` → hex[:16] → `VERSION+":"+hash`.
  `ingredientSig` (sha256 of `joinedNames` only, hex[:8]) is ADDITIVE and never feeds
  poolKey. TS↔Dart parity intact — `ingredientSig`/`poolKeyComponents` is server-only
  telemetry, Dart never computes it, so no Dart twin is owed.
- uid-hash fix resolves the raw-uid PII leak: both the maturity `logger.warn` and the new
  `pool_key_dimensions` line emit `uidHash: hashUid(uid)` (sha256 12-hex, one-way) with no
  raw `uid`. Test pins `line.uidHash === hashUid("u1")` AND `line.uid === undefined`.
- BUT-1624 delimiter `NUL→"/"` is collision-free: the Map key `${uid}/${poolKey}` composes
  two values that are both used as Firestore doc IDs (uid; poolKey = `canonical_rating_events/{poolKey}`),
  and doc IDs cannot contain `/`. Key is never parsed back — only uniqueness matters.
  Diff touches ONLY the delimiter; cursor/commit/500-op batching unchanged (already-reviewed
  backfill). Migration is manual ts-node (admin family) → region/idempotency/retry N/A.
- CI `functions-binary-guard` (test.yml): `git ls-files -z 'functions/src/**' | xargs -0 -r
  grep -laP '\x00'` captured into a var so xargs-split exit codes can't be masked. Sound.

**HIGH (flagged, one-line fix) — the dish `anchor` is logged in CLEARTEXT while the
ingredients are hashed.** The `pool_key_dimensions` line emits `anchor: dims.anchor` (a
recipe-title-derived token) next to `recipeId`, but `ingredientSig` is already an 8-hex
sha256. That asymmetry is backwards: the anchor is the field MORE likely to carry a personal
name (Swedish dish titles: "Farmors …", "Annas …", occasionally anchoring on the name), and
the logging convention explicitly forbids "recipe titles that might contain user names" in
logs. Decoupling from the raw uid dropped it from Critical to High but didn't clear it —
`recipeId` still correlates events and the anchor is human-readable to log-only access (a
tier that, by design, must not see PII even though a DB-holder could resolve recipeId).
**The cleartext anchor adds ZERO detection power:** anchor-only-change detection only needs
to know the anchor *changed* while ingredientSig held, which a hashed `anchorSig` proves by
inequality exactly like ingredientSig does. Fix = add `anchorSig` (sha256(anchor) hex[:8]) to
`PoolKeyComponents`, emit `anchorSig` instead of `anchor`, update the test to assert
`line.anchorSig === a.anchorSig` + `line.anchor === undefined` (keep the pure-function
`a.anchor !== b.anchor` component assertion). Feature fully preserved.

**Pattern — when a telemetry line hashes one title/PII-derived dimension, hash them ALL.**
A mixed line (hashed ingredientSig + cleartext anchor) is a tell that the cleartext field
was left for human eyeballing convenience. If inequality-across-events is all the detection
needs (drift/laundering signals), a hash gives it while removing the leak. Check every
field on a structured log line derived from user free-text/titles against the same standard
the uid hashing set.

### 2026-07-18 — BUT-1473 tag_overrides_log GDPR cascade delete [Pattern discovered]

Reviewed the uncommitted salvage adding `deleteTagOverridesLog(db, uid)` to the
account-deletion cascade (`account/account-deletion-cascade.ts` + wired in
`account/request-account-deletion.ts`). **COMMIT-READY, no Critical/High.** `tsc --noEmit`
clean (exit 0).

`tag_overrides_log` is a top-level, `userId`-keyed collection (allergen tag-override
corrections: userId, recipeId, tag, direction, triggeringIngredients — linked PII, no TTL,
so Art. 17 needs an explicit cascade delete). The new deleter is byte-shape-identical to the
sibling `deleteCookSnaps`/`deleteActivityEvents`: `where("userId","==",uid).get()` →
`batchDeleteAll` (commitInChunks, strict:false, 450 ops/batch, early-return on empty).

All five review axes verified:
1. **Correct identity field — cross-checked all three legs** (the realtime_recipes
   wrong-field trap): model `lib/models/tagging/tag_override_log_entry.dart:50` writes
   `'userId': userId` in `toFirestore`; `firestore.rules:2053` gates create/read on
   `resource.data.userId`; deleter + probe both query `userId`. Consistent — a `userId==uid`
   filter genuinely matches the docs, not silently zero.
2. **Same 500-op-safe pattern** as every sibling deleter (batchDeleteAll, chunked at 450).
3. **Wired consistently in BOTH surfaces** — the cascade sequence (between
   `personal_tag_groups` and `cook_snaps`) AND the `probeResidualData` userId-scoped probe
   list (correct list, since it IS top-level userId-scoped — not the subcollection or
   two-field probe class).
4. **Idempotent/retry-safe** — userId-scoped `where` deleter, so a second run reads an empty
   snapshot and no-ops (immune to the shared/parent-handle ordering hazard from the 2026-06-29
   entry; those apply only to householdId/arrayRemove-keyed steps).
5. **No region/secret surface** — plain helper, region inherited from setGlobalOptions.

### 2026-07-18 — BUT-1626 group-conversation minor-safety trigger + public_profiles hard-deny [Pattern discovered]

New `messaging/enforce-group-minor-membership.ts` (`onDocumentCreated` on
`conversations/{id}`) backstops the 1:1 minor-DM rule for GROUP conversations
(rules can't iterate `participantIds`). Reviewed with firestore.rules
`accountIsMinor` + the age-gate PP1–PP5 tests. Wiring is correct: exported in
index.ts, `test:enforce-group-minor-membership` added to package.json (auto-picked
by run-all-tests). Region inherited (no per-fn region). Firestore trigger, not
onCall, so no app-check-enforcement.test.ts entry needed. Idempotent under
re-delivery (recomputes from the created snapshot, re-reads live user/friend docs,
re-applies the same removal; delete-below-2 is a no-op on a gone doc).

**MEDIUM — the trigger trusts client-controlled `metadata.creatorId` for its
friendship decision, and the create rule never pins it to `request.auth.uid`.**
`computeMinorsToRemove` keeps a minor when `users/{minor}/friends/{creatorId}`
exists, where `creatorId = data.metadata.creatorId`. The conversations create rule
(firestore.rules ~1511) only requires `request.auth.uid in participantIds` — it
does NOT constrain `metadata.creatorId`. So the exact adversary this backstop
targets (a tampered client adding a minor) can also set `metadata.creatorId` to any
known friend F of the target minor and the gate keeps the minor. Residual friction:
attacker must know one friend of a default-private minor. Surgical fix (cheap, no
client break): add to the create rule
`&& (!('creatorId' in request.resource.data.get('metadata', {})) || request.resource.data.metadata.creatorId == request.auth.uid)`
— absent creatorId still routes to the CF fail-safe (removes all minors), a present
one can't be spoofed to another uid.

**LOW — retry defaults false ⇒ a transient read blip fails OPEN on a child-safety
gate.** Handler is verified idempotent, so `{ retry: true }` in the trigger options
would let a dropped read re-run instead of silently leaving a minor in the group.
Worth it for a safety control even though it's defense-in-depth.

**LOW — test covers only the pure core.** The destructive I/O branches
(`remaining < 2 ⇒ snap.ref.delete()`, participant map-field `FieldValue.delete()`,
membership-mirror cleanup, metadata parsing) are untested. Convention allows
pure-core-only, but the delete-below-2 branch is destructive; a `fn.run(event)`
emulator test (per the BUT-839 pattern) would earn its keep.

firestore.rules `accountIsMinor` (public_profiles create+update hard-deny of a
minor setting `isSearchable:true`) is correct and cost-bounded: the `get()` fires
only when `isSearchable` is actually being SET to true (short-circuit `||`), on
update also gated on the `affectedKeys().hasAny(['isSearchable'])` diff. Missing/
false `isMinor` reads as adult. PP1–PP5 cover the core matrix; small untested gaps:
adult UPDATE→searchable, and a minor with a legacy `isSearchable:true` preserving it
while editing other fields (the update rule's stated allowance). Analytics side:
`AnalyticsRepository.setLifecycleStage` gained a REQUIRED `isMinor` (early-returns
for minors) — defense-in-depth mirror of `UserPropertyBootstrap.emitLifecycle`'s
gate; no production caller of the raw setter exists (only the bootstrap, which calls
`setUserProperty` directly), so it's a test-only guard. Feature-flag removal of
`audit_log_retention_days`/`auditLogRetentionDays` (BUT-1560) is clean — grep
confirms zero remaining references; retention is code-constant in the CFs.

### 2026-07-18 — BUT-1626 commit-gate re-review: the creatorId-spoof MEDIUM is CLOSED [Bug fixed]

The MEDIUM flagged in the 2026-07-18 entry above (trigger trusted client-controlled
`metadata.creatorId` because the create rule never pinned it) has been FIXED with the
exact surgical rule suggested. `firestore.rules` conversations `allow create`
(~1525–1529) now carries:
`(!('metadata' in request.resource.data) || !('creatorId' in request.resource.data.metadata) || request.resource.data.metadata.creatorId == request.auth.uid)`.
So a present `creatorId` is bound to `auth.uid` (can't be spoofed to a friend of the
target minor), and an absent one routes to the CF's fail-safe (all minors removed).
With that binding, the CF's trust of `metadata.creatorId` is now sound, and the friend
check is directional-correct — `readCreatorFriendships` reads
`users/{minor}/friends/{creatorId}` (creator in the MINOR's friends subcollection),
matching the rules' `passesMinorDmGate` directionality.

Re-verified all three review axes on the uncommitted diff: `tsc --noEmit` clean;
`test:enforce-group-minor-membership` 6/6 (fail-safe on null creator asserted directly);
`computeMinorsToRemove` fail-safe confirmed (null creator ⇒ push every minor; non-friend
⇒ push; creator + adults never removed). Idempotent under re-delivery (create-snapshot
payload → recompute same set → re-`set(participantIds:remaining)` + `FieldValue.delete()`
on already-absent map fields + `snap.ref.delete()` on a gone doc are all no-ops). Region
inherited, logs carry only counts/booleans/conversationId (no uids/names). The two
residual LOWs stand (retry defaults false ⇒ transient-read fail-open; I/O branches
untested) — neither blocks. **Verdict: COMMIT-READY.**
