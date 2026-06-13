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

## Discovered patterns

*Append new dated, trigger-tagged entries below.*

### 2026-04-25 — initial seed
Knowledge file seeded from `functions/src/index.ts`, `functions/package.json`,
the v2 SDK conventions in use, and standard Cloud Functions cost/idempotency
guidance. Future entries should record real bugs caught, project-specific
function patterns, cost surprises, or new function families.

### 2026-04-27 — BUT-425 OCR URL SSRF guard [Bug fixed]

`functions/src/llm/ocr-recipe-image.ts` previously passed any client-supplied
`imageUrl` straight into Gemini's `fileData.fileUri`. The basic
`isAllowedUrl()` SSRF check (private IPs / HTTPS-only) was insufficient —
attacker-controlled HTTPS domains were still accepted, turning the function
into an exfiltration relay (Gemini fetches the URL server-side from Google's
network).

Fix: new `functions/src/shared/ocr-url-validator.ts` doing
1. host pin to `<project>.firebasestorage.app` (or googleapis path-pinned to
   that bucket, plus legacy `<project>.appspot.com`),
2. HEAD pre-flight (5s timeout, `redirect: "manual"`) verifying allowlisted
   Content-Type (image/jpeg|png|webp|heic, application/pdf) and
   Content-Length ≤ 10 MB,
3. INFO audit log with origin + size + content-type + authUidHash. Full URL
   is NOT logged because Firebase download URLs carry `?token=` query params
   that grant read access — logging them would defeat the access control.

Wired into `runOcrRecipeImage` as a `validateImageUrl` test seam. Rejection
becomes `HttpsError("invalid-argument", ...)` with Swedish copy, never
`internal` (no retry will help). Tests in
`functions/src/__tests__/ocr-validation.test.ts` (21 cases) cover host
allowlist, accepted/rejected paths, network errors, and the integration seam
proving the validator runs BEFORE `performOcr`.

Patterns worth remembering:
- **Node 22 has native `fetch`** — no need to add `node-fetch`/`axios`. Just
  inject a `fetchImpl` test seam (typed as `typeof fetch`).
- **`redirect: "manual"`** is essential for any HEAD-based host check; without
  it a 302 to `evil.com` defeats the allowlist.
- **Project ID resolution**: `process.env.GCLOUD_PROJECT` is set in Cloud
  Functions runtime; mirror `gemini-client.ts` and fall back to a string
  literal so unit tests work without env wiring.
- **Don't log download URLs** — Firebase Storage tokens are bearer
  credentials. Log origin + path-shape only.
- **Test harness**: hijack the `firebase-functions/logger` module surface by
  reassigning `logger.info`/`warn`/`error` to a capture array. Assertion-
  ready, no jest needed.

### 2026-04-27 — BUT-641 notification payload schema [Pattern discovered]

Push notifications were landing users on home and bouncing because the
`data` payload had no consistent deep-link contract. Standardised on a
3-field schema enforced by a shared helper:

- `route` — one of `/recipe`, `/friend_request`, `/comment_thread`,
  `/cooking_session`, `/menu_voting`, `/winback`
- `targetId` — entity id, or empty string for inbox-style routes
- `notificationType` — analytics tag

Helper: `functions/src/shared/notification-payload.ts` →
`buildNotificationPayload({route, targetId, notificationType, additionalData})`
returns `Record<string, string>`. Schema fields **win** on collision with
`additionalData` so legacy senders can't override them. Throws on
missing/unknown route — surfaced as `HttpsError("invalid-argument")`
in callable wrappers, not `internal`, because retrying won't help.

Choke points wired through the helper:
- `notifications/send-notification.ts:sanitizeData` — both non-silent
  (prefs-aware) and silent (background-sync) paths funnel through it.
  Silent push also gets schema fields — the client needs `route`/
  `notificationType` to dispatch background work and attribute it.
- `analytics/detect-lapsed-users.ts` → win-back, route `/winback`.
- `analytics/send-activity-digest.ts` → digest, route `/winback` (it's
  effectively a re-engagement ping; `notificationType=activity_digest`
  separates it for analytics).

Patterns worth remembering:
- **FCM data payload is string-only.** A stray `null`/`undefined`/`Number`
  slipping through causes `messaging/invalid-argument` at delivery — billed
  but undelivered. The helper coerces via `String()` and drops nullish
  values defensively.
- **Allowlist drift is silent.** Without a typed `as const` array + test,
  a typo (`/recipes` vs `/recipe`) routes users to home. Test
  `notification-payload.test.ts` includes a "no drift" check that pins the
  exact 6 routes.
- **Throw early, surface clearly.** Helper throws plain `Error` with a
  prefix (`buildNotificationPayload:`) so the callable wrapper can
  recognise and convert to `HttpsError("invalid-argument")` instead of
  the generic `internal` (which would also trigger client retry storms).
- **Activity digest doesn't fit a unique route.** Reused `/winback`
  because both are re-engagement pings with no specific entity target.
  `notificationType` keeps them distinguishable for CTR analysis.

### 2026-04-29 — BUT-621 Remote-Config-style LLM prompts [Pattern discovered]

Compile-time prompt constants in `gemini-client.ts` meant a regressed prompt
required a Cloud Functions redeploy (≈15 min) to roll back. Moved the five
LLM system prompts (`RECIPE_EXTRACTION`, `RECIPE_ENHANCEMENT`,
`IMAGE_OCR`, `SPOKEN_CONTENT`, `INGREDIENT_LINE`) to Firestore at
`system/prompts`, with the compile-time constants kept verbatim as fallback.

**Cache pattern**: module-scope `let cache: { prompts, fetchedAt } | null` in
`functions/src/llm/prompts-config.ts`. TTL = 5 min. No global singleton class
— each CF isolate gets its own cache, cold starts naturally invalidate. No
promise-coalescing on TTL miss (concurrent callers may each issue a read);
`system/prompts` is one Firestore doc (~$0.000036/read) and the savings
weren't worth the complexity.

**Firestore doc shape** (operators bump `promptVersion` on every edit so
analytics keys off it):
```
system/prompts {
  recipeExtractionSystemPrompt: string,
  recipeEnhancementSystemPrompt: string,
  imageOcrSystemPrompt: string,
  spokenContentSystemPrompt: string,
  ingredientLineSystemPrompt: string,
  promptVersion: string,
  updatedAt: Timestamp,
}
```

**Validation is all-or-nothing.** A partial overlay (mixing fallback +
remote strings) creates a debugging nightmare where the `promptVersion`
reported to analytics doesn't match the prompt actually sent. Any
missing/non-string/empty-string field ⇒ wholesale fallback + a single
`logger.warn` per cache window.

**Three failure modes are distinguished in logs** (matters for triage):
- `Firestore doc missing` (no doc)
- `Firestore doc malformed` (doc exists but shape invalid — includes
  `keys: Object.keys(raw)` so an operator can spot a typo immediately)
- `Firestore read failed` (network / permission error — includes `err`)

**Patterns worth remembering**:
- **`PROMPT_VERSION` becomes the seed**, not the source of truth. Kept as
  exported const for backward compat (other modules import it as the
  fallback default) but the runtime `promptVersion` returned from
  `getPromptsConfig()` flows downstream into analytics + responses.
- **Test seam shape**: `getPromptsConfig({ loader, now, ttlMs })` mirrors
  the BUT-439 kill-switch convention (`loadKillSwitch` seam). Production
  passes nothing; tests inject everything.
- **Fallback isn't a permanent latch.** Cache TTL applies to the fallback
  too — after 5 min, a recovered Firestore doc flips the cache back to
  `source: "firestore"` automatically. Tested at
  `__tests__/prompts-config.test.ts` case [8].
- **Vision prompt threading**: `defaultPerformOcr` in `ocr-recipe-image.ts`
  used to read `IMAGE_OCR_SYSTEM_PROMPT` directly. Refactored to accept it
  via `OcrPerformArgs.systemPrompt` so the Firestore-backed prompts cache
  governs the vision branch uniformly with the text branch. Default falls
  back to the compiled-in const for older test seams.
- **Test harness pattern for logger assertions**: reassign
  `logger.info`/`warn`/`error` to a capture array in module scope, restore
  in a `restoreLogger()` finalizer. Same pattern as `ocr-validation.test.ts`.
- **Module-scope cache survives across tests in the same file.** Added an
  `__resetPromptsCacheForTests()` export that test cases call between
  cases. Don't forget — without it, case [2]'s cache hit will pollute case
  [3]'s cache miss assertions.

### 2026-04-30 — BUT-647/BUT-645/BUT-638 sprint [Pattern discovered]

**Sprint scope**: server-side quiet-hours enforcement (BUT-647), per-type
notification effectiveness + RC auto-suppression (BUT-645), North-Star
weekly aggregation (BUT-638). Three new functions, six new shared modules,
three new test suites (21 cases total, all passing).

**Key files added**:
- `functions/src/shared/analytics-server.ts` — `logAnalyticsEvent(name, fields)`
  emits structured `event=<name>` log → BigQuery export → Looker dashboards.
  Cloud Functions can't call the FA SDK directly; this is the server-side
  equivalent.
- `functions/src/shared/notification-importance.ts` — static allowlist
  splitting `low` (drop) from `high` (delay) importance. Default low so
  unknown types err on NOT disturbing the user.
- `functions/src/shared/quiet-hours.ts` — DST-safe `Intl`-based local
  hour/minute resolver, supports per-user IANA timezone, falls open on
  prefs read errors.
- `functions/src/shared/scheduled-notifications.ts` — Firestore-backed
  delayed-push queue.
- `functions/src/shared/notification-rc-flags.ts` — RC flag reader for
  `notifications.enabled.<type>` with 5-min cache and **fail-open** on
  any error (RC outage must not silently mute pushes).
- `functions/src/shared/notification-send-events.ts` — best-effort write
  of `notification_send_events` row per push (30-day TTL). Failures are
  logged at warn but never block the actual send.
- `functions/src/shared/notification-gate.ts` — central pre-send gate
  combining the above. Three senders (`sendNotification` callable,
  `detectLapsedUsers`, `sendWeeklyActivityDigest`) all call this.
- `functions/src/notifications/deliver-scheduled-notifications.ts` —
  `every 5 minutes` scheduler draining the queue. Transaction-flips
  `pending → delivered` BEFORE the FCM send (at-most-once contract).
- `functions/src/analytics/suppress-low-performers.ts` — weekly job
  flipping RC flags when CTR < 5% over ≥50 sends.
- `functions/src/scheduled/north-star-weekly.ts` — Mondays 06:00 UTC
  aggregator writing `metrics/weekly_north_star/snapshots/{isoWeek}`.

**Patterns worth remembering**:

- **Cloud Tasks vs Firestore queue trade-off**: spec asked for Cloud
  Tasks. Repo has zero existing Cloud Tasks usage → adding it means new
  top-level dep (`@google-cloud/tasks`), new IAM role (`Cloud Tasks
  Enqueuer`), queue resource in `firebase.json`, and a separate HTTP
  receiver function. For our beta scale (hundreds/night) a Firestore
  queue + 5-min scheduler is cheaper, simpler, and avoids the new dep.
  Architectural deviation flagged in the file's docstring with the
  inflection point (~10k delayed pushes/night) at which the trade
  reverses.

- **Fail-open is the right default for notification gates.** RC fetch
  errors, prefs read errors, send-event write errors all log + continue
  rather than block. The cost of fail-closed during an infra blip is
  silently muting all notifications (worse than a few extra pushes).

- **DST-safe local-time resolution**: `new Intl.DateTimeFormat("en-GB",
  { timeZone, hour, minute, hour12: false })` + `formatToParts()`. No
  date library needed. Tested at 02:30 UTC on 2026-03-29 (Stockholm
  spring-forward) — correctly resolves to 04:30 CEST.

- **`metrics/{collection}/{doc}` is invalid Firestore.** Spec said
  `metrics/weekly_north_star/{isoWeek}` (3 segments = doc path) but
  `weekly_north_star` would have to be a doc, leaving `{isoWeek}` as a
  subcollection name (which is wrong). Resolved via subcollection:
  `metrics/weekly_north_star/snapshots/{isoWeek}`. Always count
  segments — odd = collection, even = doc.

- **Activity-event schema drift in production**: spec used `userId` +
  `eventType == "recipe_cooked"` but client (`activity_event.dart`)
  writes `actorId` + `type == "cooked"`. Aggregator accepts BOTH via
  `||` fallbacks so it works against live data without a coordinated
  client refactor. Document the dual-shape in the function header so
  future readers know it's intentional.

- **Test seam pattern for new senders/aggregators**: every new function
  exposes a `runX(deps)` plain async function alongside the `onSchedule`
  export. The schedule wrapper is one line that delegates to `runX()`.
  Tests exercise `runX(deps)` with fake `db`, `now`, and helper-function
  injections. Avoids spinning up the emulator for unit-level tests.

- **Existing `send-notification.test.ts` must opt out of the gate.**
  Adding `gate` + `recordEvent` to `DispatchOptions` broke the existing
  test because its `makeDeps` didn't pass them, so the real
  `evaluateSendGate` ran and tried to read `admin.firestore()` without
  an app initialized. Updated the test's `makeDeps` to stub both seams
  with `{action: "proceed", reason: "test-stub"}`. Lesson: any time you
  add a new test seam to `DispatchOptions`, audit existing tests and
  give them a default stub.

- **Aggregator queries: cap window-fetch in parallel, NOT serial.**
  North Star fetches W0/W1/W2/W3 windows concurrently via
  `Promise.all([...])` — single round-trip latency rather than 4×.
  Each window is one Firestore range query.

- **Idempotent re-run = `set()`, not `create()`.** Test idempotency by
  asserting `writeCount=2` but `Set<docPath>.size=1` (one path written
  twice). `set()` overwrites; `create()` would throw on second call.

### 2026-04-30 — security review fixes (C1/C2/H1/M1) [Bug fixed]

Security review of the BUT-647/BUT-645/BUT-638 sprint caught four
wiring gaps. All four were "architecture sound, plumbing missing"
class — useful patterns for future sprints.

**C1 — producerless aggregator (CRITICAL)**: `suppressLowPerformers`
read `notification_opened_events` but no code wrote it. CTR computed
0/N for every type → every notification type would auto-disable in week 1.

Fix: new callable `recordNotificationOpened` in
`functions/src/notifications/record-notification-opened.ts`. Deterministic
doc id (`<userId>_<notificationId>`, slash-sanitized) provides server-side
dedup so double-taps don't inflate CTR. Client wired in
`lib/services/notifications/notification_deep_link_router.dart` via
`FirebaseFunctions.instanceFor(region: 'europe-west1')` (NOT
`.instance` — `.instance` defaults to us-central1 and silently fails
against europe-west1 functions). Fire-and-forget; failures logged at
warn but never block navigation.

**Regression guard pattern (worth remembering)**: any time an
aggregator reads collection X, add a test that wires the *real* X
producer to the *real* aggregator with a shared fake DB. The
"producer→consumer end-to-end" case in `notification-effectiveness.test.ts`
demonstrates this — if anyone removes the writer, the test goes red
because the consumer sees 0 opens and tries to disable a healthy type.
Pure unit tests would never catch a producerless gap.

**C2 — GDPR cascade + TTL on PII queues (CRITICAL)**:
`scheduled_notifications` carries push body (comment snippets, recipe
titles, friend names — PII). `notification_send_events` and
`notification_opened_events` carry `userId` (linked PII). All three
needed:
1. `expireAt` field stamped at write-time (7d for scheduled-queue,
   30d for analytics streams). The TTL POLICY itself must be enabled
   manually — `gcloud firestore fields ttls update expireAt
   --collection-group=<col> --enable-ttl`. Document this as an
   environment-setup step in the writer module's docstring.
2. Cascade in `on-user-deleted.ts`. Added
   `cleanupNotificationQueuesWithDb(database, userId)` (test seam) +
   `cleanupNotificationQueues(userId)` (production wrapper). Iterates
   `[scheduled_notifications, notification_send_events,
   notification_opened_events]`, batches deletes per `BATCH_LIMIT`.

**H1 — composite index for drainer**: `where('status', '==',
'pending').where('deliverAt', '<=', now)` is a compound query.
Without an entry in `firestore.indexes.json`, the first scheduler run
throws `FAILED_PRECONDITION`. Always check `firestore.indexes.json`
when introducing a multi-`where` query — the emulator silently
auto-creates the index, but production deployment doesn't.

**M1 — drainer poison-pill loop**: a permanently-failing FCM token
(expired/invalid recipient) bounced docs through
`pending → delivered → pending → ...` forever. Fix: `MAX_ATTEMPTS = 5`
constant, increment counter inside the claim transaction, on send-failure
compare post-bump count: rollback if `< MAX`, park at `status="failed"`
with `failureReason: "max_attempts_exceeded"` if `>= MAX`. Emit
`scheduled_notification_max_attempts_exceeded` analytics for ops.

**Patterns worth remembering**:

- **Region pinning on the client side**: `FirebaseFunctions.instance`
  defaults to us-central1. Project functions are pinned to europe-west1.
  Always use `FirebaseFunctions.instanceFor(region: 'europe-west1')`.
  `notification_service.dart:487` is a latent bug doing the wrong thing
  (out of scope for this sprint to fix).

- **Module-load admin.firestore() is import-poison for tests**: the
  pre-existing `const db = admin.firestore()` at top of
  `on-user-deleted.ts` requires an initialized default app. Tests that
  only need an exported pure helper (test-seam) must
  `admin.initializeApp({projectId: 'butlery-test-X'})` then
  `require()` the module dynamically. See `presence-cascade.test.ts`
  and `notification-queues-gdpr.test.ts` for the pattern. Lazy
  initialization (`const getDb = () => admin.firestore()`) is the
  better fix but pre-existing files use eager init.

- **Manual one-shot setup steps belong in the writer's docstring**:
  TTL policies aren't auto-deployed by `firebase deploy`. Document the
  `gcloud firestore fields ttls update` invocation right where the
  field is written, so the next reader knows the policy is required
  but not in CI.

- **Server-side write callable vs client-direct write trade-off**:
  for new analytics-style collections, prefer a callable
  (`record*` family). Keeps Firestore-rules surface narrow (no new
  client-writable collection), centralizes auth + dedup +
  schema-validation in TypeScript, and makes the data flow auditable
  (one entry point to grep for).

- **Deterministic doc id for dedup**: `<userId>_<entityId>` is the
  go-to pattern. `set()` becomes idempotent, no transactions needed,
  no race conditions on concurrent writes for the same key.

- **npm script chains** — when adding a new test, append both the
  granular `test:foo` script AND extend the composite `test` chain.
  Easy to forget the second; CI then runs partial coverage.

### 2026-04-30 — BUT-458 one-shot migration patterns [Pattern discovered]

`functions/src/migrations/backfill-recipe-comments-denorm.ts` —
admin-gated `onCall` backfill stamping `recipeOwnerId` +
`sharedWithUserIds` on legacy `recipe_comments` docs. Reviewed clean
with one Medium finding (lifecycle comment) and three Lows.

**New family**: `migrations/` — one-shot `onCall` scripts that ship
deployed (vs `admin/` which runs via local `ts-node` against prod
creds). Distinguishing factor: `migrations/` are admin-only callables
designed to run from a deployed environment so an operator can invoke
with `httpsCallable` from a privileged client; `admin/` scripts run
from a workstation with `firebase-admin` initialized via service
account.

| Path | Concern | Trigger | Test |
|---|---|---|---|
| `migrations/` | Idempotent, paginated, admin-gated, lifecycle-bound | onCall (admin only) | per-script `test:<name>` |

**Patterns worth remembering**:

- **Lifecycle comment is mandatory for `migrations/`**. One-shot
  CFs without a removal-trigger comment become permanent zombie
  endpoints. The doc-block header MUST specify: (1) the data
  condition that signals completion (e.g. "all `recipe_comments`
  have `recipeOwnerId`"), (2) the soak window before deletion
  (typically 7d), (3) the Linear ticket. Mirror a one-line "REMOVE
  after BUT-XXX soak" in `index.ts` at the export site. Without
  this, future maintainers won't know if it's safe to delete.

- **`hasMore` continuation flag for per-invocation ceilings** —
  any migration with a wall-clock or doc-count ceiling MUST return
  a structured response containing `hasMore: boolean` so the
  caller knows to re-invoke. Two ceiling paths in the BUT-458
  script: per-doc `maxComments` (caller-supplied) and per-batch
  `MAX_BATCHES_PER_INVOCATION` (hard-coded at 50 batches × 200
  docs = 10k). Both flip `hasMore`. Silent termination = footgun.

- **Pagination cursor on `__name__`** — `orderBy(FieldPath.documentId())`
  + `startAfter(lastDocId)` is the cheapest cursor (no extra
  index, deterministic, total-order). Update cursor *after*
  consuming the snapshot; combined with `snapshot.size < BATCH_SIZE`
  exit, eliminates infinite-loop risk on a malformed doc. Wrap
  the per-doc work in try/catch so a single bad doc increments
  `failed` and the loop continues.

- **Idempotency via field-presence guard**, not transaction.
  `if (typeof data.recipeOwnerId === "string" && data.recipeOwnerId)
  { skipped++; continue; }` short-circuits BEFORE the expensive
  collectionGroup lookup. Type-narrowing + truthiness check
  prevents partial migrations (empty string) from masquerading
  as done. Re-running the migration is then near-free
  (1 read per skipped doc).

- **Orphan handling — graceful degrade, don't fail**. When the
  recipe-ownership lookup returns null (recipe deleted, or
  unindexed shape), stamp `recipeOwnerId = authorId,
  sharedWithUserIds = []`. The row stays author-only-readable
  (matches the rules' fallback path). Track in a separate
  `orphanedAuthorOnly` counter so ops can see how many fell
  through. Throwing here would mean the same orphan blocks every
  subsequent invocation forever.

- **N+1 cost for one-shots is acceptable; for ongoing CFs, batch.**
  10k × `collectionGroup.where(documentId, '==', X)` = ~$0.006 +
  ~50s of latency. Fine for one-shot. For an ongoing trigger,
  use `where(documentId, 'in', [...30 ids])` to cut reads ~30×.

- **Structured-log second-arg, not `JSON.stringify`**. Cloud
  Logging indexes the second arg as a JSON object (queryable via
  `jsonPayload.migrated > 0`). `JSON.stringify` collapses
  everything into the message string — searchable but not
  filterable. Spotted in BUT-458 at the per-batch progress log;
  not blocking but inconsistent with house style.

### 2026-04-30 — BUT-605 retention extension to D14/90/180 [Pattern discovered]

`track-retention.ts` previously emitted auto-id'd docs at
`/analytics/retention/events/{auto}` for D1/7/30. Two issues with that
shape became blockers when extending to D14/90/180:

1. **Auto-id breaks the "set, not create" idempotency promise.** A
   re-run on the same UTC day appended duplicate rows, doubling
   downstream cohort counts. Fix: switch to deterministic
   `<userId>_d<N>` ids — per-(user, day-bucket) doc, `set()` overwrites
   on re-run. Mirrors the BUT-638 north-star idempotency pattern.

2. **Lifecycle slicing without an N+1.** Spec asked to filter by
   `analytics_user_properties.lifecycle_stage` (BUT-639), but BUT-639
   only emits to Firebase Analytics SDK — no Firestore mirror. Two
   options: (a) introduce a new `analytics_user_properties` collection
   + writers, (b) compute lifecycleStage server-side from the user
   doc's `joinedAt`+`lastActiveAt`. Picked (b) — single read per user
   already in flight, no new producers, and the recency-dominated
   classifier rules (`churned`/`dormant`) are intact. The Dart
   classifier's `cooksLast14Days` input is approximated via signup
   age + recent activity (no per-user cook count query), which cannot
   distinguish habitual from activated for users with rare-but-recent
   cooking patterns. Acceptable for cohort-level dashboards.
   Documented the divergence in `classifyLifecycleStageServer`'s
   docstring so future readers know not to treat the server output
   as canonical.

**Patterns worth remembering**:
- **Refactor pattern: `runX(deps)` test seam alongside `onSchedule`
  wrapper.** Existing CFs that lack a test seam (whole body inside
  the `onSchedule` callback) can't be unit-tested without firing
  the scheduler. When extending such a CF, lift the body into
  `runX(deps)` first, leave the schedule wrapper as a one-liner that
  delegates. Costs nothing at runtime, unlocks tests immediately.

- **Deterministic doc id pattern for time-bucketed events**:
  `<userId>_d<N>` for "user hit day N" rows, `<userId>_<entityId>` for
  "user did X to entity" (e.g. notification_opened). Both make `set()`
  idempotent without transactions; the latter dedupes double-taps,
  the former dedupes scheduler re-runs.

- **`!=` queries cost a real index in production.** The original
  `where("lastActiveAt", "!=", null)` line works in the emulator but
  requires a single-field index exemption in prod. Kept as-is since
  it was already shipped; flag for future review if the user
  collection grows enough to make the index cost matter.

### 2026-05-01 — BUT-741 backfill parallelization [Pattern discovered]

`backfill-recipe-comments-denorm` resolved recipe ownership sequentially per
comment (≤10k serial `collectionGroup('recipes')` reads → callable timeout
risk on chatty datasets). Fixed by adding two layers inside each batch loop:

1. **Pre-pass dedup**: walk the batch once, classify
   skipped/malformed/over-cap, collect distinct `recipeId`s into a `Set`.
   For datasets where many comments target the same recipe, this alone
   slashes resolve count by 2-5×.
2. **Bounded parallel resolve**: `pLimit(20)` over the unique-id set,
   `Promise.all(ids.map(id => limit(() => resolveRecipeOwnership(id))))`.
   Errors captured per-id in a `Map<recipeId, OwnershipResult>` so a
   resolve failure for one recipeId fans out cleanly to every comment
   referencing it (counted as `failed`, not silently dropped).

Adjacent quick wins shipped in the same change:
- `BATCH_SIZE` 200 → 450 (Firestore writeBatch hard cap is 500; previous
  setting wasted ~55% of capacity, doubling round-trips).
- `MAX_BATCHES_PER_INVOCATION` 50 → 23 to keep the doc-count ceiling at
  ~10k (23 × 450 = 10350 ≈ 10k; the inner `maxComments` guard enforces
  the precise hard ceiling).

**Patterns worth remembering**:

- **`p-limit@3` is the right pin for this repo.** `tsconfig.json` uses
  `module: "node16"` but the Functions runtime + `ts-node` operate as
  CommonJS in practice. `p-limit@4+` is ESM-only and forces dynamic
  `await import()` (works but adds a top-level-await wrapper). v3.1.0 is
  CJS, exports a default function, plays cleanly with
  `import pLimit from "p-limit"` under `esModuleInterop: true`. v3.1.0
  was already on disk as a transitive — promoted to a direct dep at
  `^3.1.0` so the dependency is explicit and survives prune cycles.

- **Dedup BEFORE parallelize.** Concurrency without dedup still issues
  N reads for N comments referencing the same recipe — just faster.
  Pre-pass with a `Set<string>` of recipeIds reduces both Firestore
  reads ($) and per-resolve latency contention. Apply this to any
  fan-out trigger that may reference the same upstream entity multiple
  times.

- **Per-id error capture, not per-comment.** When a parallel resolve
  fails, you must remember WHICH id failed so the fan-out step counts
  every dependent comment as failed. A `Map<id, {ok, value|err}>`
  tagged-union is the cleanest type for this; rejection-as-value
  pattern keeps `Promise.all` from short-circuiting on one failure.

- **Test seam for parallelism assertions**: extend the in-memory db
  fake with optional `onResolveStart`/`onResolveEnd` hooks plus a
  `resolveDelayMs` knob. Tests increment a shared `inFlight` counter
  on start, decrement on end, track `maxInFlight` between yields.
  Two assertions become trivial: `maxInFlight > 1` proves concurrent
  execution; `maxInFlight ≤ CAP` proves the limiter is wired.
  `setImmediate(r)` as a default microtask yield is enough to expose
  parallelism without artificial delays for fast-path tests.

- **Symbol-keyed back-pointer on the fake `ref`** lets the fake
  `batch.update(ref, data)` mutate the right `FakeComment` even when
  writes arrive out of declaration order. The previous fake's
  "find-first-unmigrated-comment" heuristic only worked under strict
  sequential order — broken by parallel resolve. Pattern:
  `ref[COMMENT_REF] = c` at snap construction, lookup on update.
  Survives any reordering the SUT might introduce.

- **Lifecycle comment unchanged.** This is still BUT-458's one-shot
  migration — BUT-741 just made it faster/safer. The lifecycle
  removal trigger ("hasMore: false + 30d soak") is preserved verbatim.
  When extending one-shot migrations, never extend the lifecycle
  without reason; you'd be re-introducing zombie-endpoint risk.

### 2026-05-01 — BUT-688 win-back A/B via Remote Config [Pattern discovered]

`functions/src/analytics/winback-variant.ts` — Remote Config-backed
push copy for `detect-lapsed-users` with deterministic SHA-256 bucket
assignment. Refactored `detect-lapsed-users.ts` from inline-body
`onSchedule` into the standard `runDetectLapsedUsers(deps)` test seam
(mirrors `track-retention.ts` shape).

**Why server-side bucket assignment?** Cloud Functions cannot set
Firebase Analytics user properties directly. The bridge to FA is the
user doc: when the server sends a win-back push it merges
`lastWinBackVariant`, `lastWinBackBucket`, `lastWinBackChannel: "push"`,
and `lastWinBackSentAt`. The Dart `ExperimentAssignment` helper
(BUT-657) reads those at session start and stamps `exp_winback_copy`
onto FA. This split is correct: bucket consistency lives where the
push actually sends, not where it's received.

**Patterns worth remembering**:

- **Hash 6 bytes of SHA-256, not 4 or 8.** 4 bytes (32 bits) is fine
  for ≤2 variants but skews on small variant counts that don't
  evenly divide 2^32. 6 bytes (48 bits) gives a uniform distribution
  far larger than any plausible variants.length without needing
  `bigint` arithmetic — number is safe up to 2^53. 10k-uid
  distribution test confirmed ~50/50 within ±5%.

- **Deterministic bucket key = `${uid}:${thresholdType}`, not just
  `uid`.** Mixing the threshold type into the hash makes mild /
  moderate / strong independent experiments. A user can be `baseline`
  for mild and `curiosity` for strong, which is what you want for
  cross-bucket attribution analysis.

- **All-or-nothing RC validation, same as BUT-621 prompts.** Partial
  overlay (RC has title but body missing) ⇒ falls back to baseline
  WHOLESALE for that (threshold, variant) pair. Otherwise the
  variant attribution downstream lies — analytics says "curiosity"
  but the user saw half-baseline. Cleaner: log the partial-overlay
  as a warn so an operator notices the typo, return baseline.

- **RC Server SDK access pattern**: `admin.remoteConfig().getTemplate()`
  returns `RemoteConfigTemplate` with `.parameters: {[key]:
  {defaultValue: ExplicitParameterValue}}`. Project the template
  down to a flat `{paramKey: defaultValue.value}` map at the cache
  layer — keeps the consumer surface small and makes the test seam
  trivial (`async () => Record<string, string> | null`).

- **Cache TTL = 10 min for daily-scheduled CFs.** Higher than the
  prompts-config 5 min because (a) RC propagation latency is minutes
  anyway, and (b) the win-back CF runs once a day, so within-run
  cache reuse is the only thing TTL governs. All 3 thresholds in a
  single `runDetectLapsedUsers` call hit the same cached template —
  one network round-trip per CF cold start, not three.

- **OPS_PER_USER bookkeeping for batch reservations.** Adding the
  user-doc bridge write bumped per-user ops from 2 (analytics +
  notification) to 3. The reservation `BATCH_LIMIT - OPS_PER_USER`
  must track this exactly; under-reserving overflows the batch
  silently and Firestore rejects the commit with `INVALID_ARGUMENT`.

- **`lastWinBackSentAt` is NOT an idempotency gate.** The same user
  can legitimately get pinged at mild → moderate → strong as they
  progress through dormancy stages. The field is a session-bridge
  for the client, not a "did we already ping". Comment says so
  loudly to prevent future-me from "fixing" the apparent re-ping.

- **Test seam for orchestration over collaborators**: when the
  function under test calls 3+ other modules (RC fetch + variant
  resolve + push + gate + recordEvent), inject ALL of them via
  `RunDeps`. The integration test then exercises real ordering /
  data-flow / batch-reservation logic without spinning up admin SDK,
  RC, or FCM. `runDetectLapsedUsers({db, fetchCopy, sendPush, gate,
  recordEvent, now})` is the canonical shape.

- **Fake Firestore for batch-set tests**: model `batch.set(ref, data,
  options)` with merge-aware semantics by reading the existing
  store entry on `merge: true`. Without that, the test for
  `lastWinBackVariant` (which is a merge write) silently overwrites
  the test's earlier user-doc seed and gives false positives.

- **RC parameter naming convention**: `winback_<thresholdType>_<variant>_<title|body>`.
  Underscores throughout, lowercase, threshold type baked-in (not
  abbreviated). The keys are literal strings in code, not built
  via template — easier to grep when an operator asks "is this RC
  param actually being read?".

### 2026-05-01 — BUT-599 per-feature retention aggregator [Pattern discovered]

`functions/src/analytics/compute-feature-retention.ts` — daily 04:30 UTC
scheduler (30 min after `track-retention.ts` to avoid colliding on the
same `users` collection scan). Computes per-user-per-day boolean flags
across 5 features (cooked / imported / shared / mealPlanned / shopped) and
a daily aggregate doc with DAU + rolling WAU 7d/28d. `wau28d` doubles as
the MAU proxy — strict 28-day rolling window is functionally equivalent
to MAU for cohort dashboards and avoids a second pass with different
boundaries. Documented that semantics in the field name.

**Feature → source mapping (verified against codebase 2026-05-01)**:

| Flag | Source | Time field |
|---|---|---|
| cooked | `cook_snaps` (top-level), userId == uid | `createdAt` |
| imported | `users/{uid}/recipes` | `core.createdAt` |
| shared | `shared_recipes`, sharedByUserId == uid | `sharedAt` |
| mealPlanned | `users/{uid}/menus` (personal subcoll, not top-level) | `createdAt` |
| shopped | `users/{uid}/shopping_lists` | `updatedAt` |

**Patterns worth remembering**:

- **`shopped` uses `updatedAt`, not `createdAt`.** Shopping lists are
  long-lived (created once, updated as items are checked off).
  `createdAt` would dramatically undercount actual feature usage.
  `updatedAt` better captures "user touched a shopping list today" even
  though it conflates check-off with metadata edit. For other features
  the create event IS the activity, so `createdAt` is correct.

- **Probe with `limit(1)`**, not `count()`. We only care whether the user
  did the thing at least once — exact count is irrelevant for DAU/WAU
  flags. `limit(1).get()` is the cheapest possible probe; `count()`
  aggregations cost the same as a full read in practice and add a query
  shape that needs a separate index.

- **`Promise.all` the 5 probes per user.** Five `where(...).limit(1)`
  queries fan out concurrently with no contention — same SDK round-trip
  budget as one. Sequential would 5× the latency for no benefit.

- **WAU rollup reads prior days; today comes from in-memory.** We just
  wrote today's flag doc — no point reading it back. Seed the
  per-user `seenAnyIn7/28` with the in-memory result, then read days
  1..27 from `analytics/feature_retention/users/{uid}_{yyyy-mm-dd}`.
  Saves 1 read per scanned user.

- **WAU historical reads are sequential per user, not parallelized.** At
  10k active users the `Promise.all`(28 reads) per user would issue 280k
  concurrent reads, blowing past the SDK's connection pool. Sequential
  per-user with `Promise.all` only across the 5 same-user same-day
  probes keeps concurrency bounded. If users grows past ~10k consider
  switching from per-user history reads to a single daily counter doc
  per feature (massive read reduction, slight write overhead).

- **Graceful probe degradation**: per-flag try/catch around each probe
  query. If a feature collection is missing or its index isn't built,
  the flag falls back to `false` and a `feature_retention_probe_failed`
  warn is emitted. The run does NOT crash. Better to ship 4 of 5
  working flags than to ship 5 with one bricking the daily aggregate.
  Tested at `compute-feature-retention.test.ts` case 5.

- **Active-user filter aligns with the WAU window.** Only scan users
  with `lastActiveAt >= now - 28d`. A user inactive past 28d would
  contribute zero to all DAU/WAU windows anyway — reading them wastes
  Firestore quota. Aligning the scan boundary with the longest WAU
  window is the right cutoff.

- **Read budget back-of-envelope**: at ~1k active users, ~34k reads/day
  ≈ $0.012/day. Documented in the file header so future cost-tuning
  knows what they're optimizing.

- **Test-seam shape mirrors `runTrackRetention`/`runDetectLapsedUsers`**:
  pure `runComputeFeatureRetention(deps: {db?, now?})`; the schedule
  wrapper is a one-liner that delegates. Production passes nothing;
  tests pin both. This is now the canonical shape for any new analytics
  CF in this codebase.

- **Schedule offset matters when two CFs scan `users`.** Pinned 04:30
  UTC because `trackDayNRetention` runs at 04:00 UTC and also iterates
  the entire users collection. Co-running risks 2× connection-pool
  pressure during the most expensive part of both runs. 30-min offset
  is generous (each CF finishes in <5 min at current scale) but cheap
  insurance against future growth.

### 2026-05-02 — BUT-577 ingredient-lines partial-array salvage [Bug fixed]

`parseIngredientLinesResponse` in `functions/src/llm/gemini-client.ts`
called `JSON.parse` on the full Gemini response. When the model hit
`INGREDIENT_LINE_MAX_TOKENS = 1000` mid-array on large recipes (>40
ingredients), the parse threw and the function returned `null`. The
single caller in `structure-recipe.ts` then surfaced
"Kunde inte tolka AI-svaret som ingredienser" to the user — losing
the entire fully-formed prefix the model HAD produced.

Fix: keep the happy path, add a salvage branch on `JSON.parse` failure
that strips the `{ "ingredients": [` (or bare `[`) wrapper and walks
the body with a quote-aware brace counter to extract every top-level
`{...}` object whose braces balance. Each is parsed independently;
the unterminated tail object is dropped. Result type widened from
`ExtractedIngredient[] | null` to `{ ingredients, truncated } | null`
so callers can distinguish "all good" from "partial recovery — warn
user". Single caller updated; emits `logger.warn` with the recovered
count when truncated.

**Patterns worth remembering**:

- **Bracket counter beats regex for partial-JSON salvage.** Regex
  `/\{[^}]*\}/g` breaks on objects that contain `{` or `}` inside
  string values (e.g. `"preparation": "med } i strängen"`) or nested
  objects (which ingredient schemas may grow into). Char-by-char with
  `inString` + `escape` flags is ~30 lines, exact, and survives any
  schema additions. Same approach used by every robust streaming-JSON
  consumer.

- **Stop scanning on first unterminated object, don't try to "fix" it.**
  When the brace counter never returns to 0, the salvager bails out of
  the loop rather than trying to append `}` or skip ahead. Synthesizing
  a closer would silently fabricate data — fail-safe is to drop the
  partial.

- **Return-shape decision: extend the type, don't add a sibling
  function.** With one caller, widening the return from `T[] | null` to
  `{ items: T[]; truncated: boolean } | null` is cheaper than parallel
  `parseFooWithMeta` + `parseFoo` overloads. The caller change is one
  destructure. Sibling functions would have meant two near-identical
  bodies to keep in sync — the salvage loop is non-trivial enough that
  divergence would be inevitable.

- **Don't widen unless a caller would care.** This applies because
  user-facing error copy and per-batch token-budget tuning both improve
  with the truncation signal. For pure-internal helpers with no
  observable consequence, the bare-array shape would be correct to
  preserve.

- **Test the depth counter explicitly.** Two cases pin the salvage
  scanner against (a) `}` inside a string value and (b) escaped
  quotes inside a string value. Without those, a future "simplification"
  to regex-based extraction would pass shape tests but corrupt real
  Gemini output that contains either pattern.

- **`INGREDIENT_LINE_MAX_TOKENS = 1000` is the proximate cause.** A
  follow-up worth considering: bump to 2000 or chunk the input on the
  caller side. Salvage is the safety net, not a license to ship a
  too-tight cap. If `truncated: true` log lines become frequent, that's
  the signal to revisit.

### 2026-05-04 — BUT-482 / BUT-483 / BUT-627 Sprint G [Pattern discovered]

Three Cloud Functions tasks in one sprint: rating aggregation debounce
(BUT-482), structureRecipe timing log (BUT-483), ping sweeper +
hourly rate-limit (BUT-627). All shipped clean; build + new tests pass.

**New family**: `triggers/` — generic Firestore-triggered functions that
don't fit into a domain folder (cleanup/, social/, ratings/, etc.).
First inhabitant: `triggers/ping_onCreate.ts` (rate-limit enforcement).

**Patterns worth remembering**:

- **Cloud Tasks vs Firestore-marker + scheduler trade-off, again.**
  BUT-482 originally specced Cloud Tasks for the 5s debounce. Repo still
  has zero Cloud Tasks usage — same calculation as BUT-647: the
  `_internal/rating_debounce/markers/{recipeId}` doc + a 1-min drainer
  is far lighter than introducing `@google-cloud/tasks`, the IAM role,
  and a queue resource. 1-min latency is acceptable for rating-stats
  refresh (was: synchronous + throttled at ~1/sec). The trade-off
  inflection point is roughly the same: ~10k debounced events/min.

- **`_internal/rating_debounce/{recipeId}` was a 3-segment trap.**
  Spec said "marker doc at `_internal/rating_debounce/{recipeId}`"
  — but `_internal` (collection) → `rating_debounce` (doc) →
  `{recipeId}` would have to be a collection name, which is wrong for
  a single doc. Resolved via subcollection:
  `_internal/rating_debounce/markers/{recipeId}` (4 segments = doc).
  Same lesson as BUT-638's `metrics/weekly_north_star/snapshots/{isoWeek}`.
  Always count segments in plan specs and disambiguate before coding.

- **Claim-by-delete BEFORE aggregating.** Drainer pattern:
  `await doc.ref.delete(); await aggregate(recipeId);`. Deleting the
  marker first means a new rating that lands during aggregation creates
  a fresh marker, which the next drain picks up — re-fire is automatic.
  Aggregation itself is idempotent (reads the full ratings collection
  + writes one stats doc), so a rare double-run from a marker race is
  safe. Avoids needing a transaction across delete + aggregate.

- **count() aggregate for rate-limit checks.** The hourly cap on
  pings uses `collectionGroup('pings').where('fromUserId', '==', X)
  .where('createdAt', '>=', windowStart).count().get()`. Single
  billable read regardless of the user's actual ping volume — at
  worst $0.000036 per create vs $0.06+ if we had to fetch the docs.
  Always prefer `.count()` over `.get()` when only the cardinality
  matters.

- **Audit row goes to `audit/<event>/entries/{auto}` (4 segments).**
  Spec said `audit/ping_rate_limit/{autoId}` (3 segments) but for the
  same reason as the debounce marker, a 3-segment doc-id under
  `audit/ping_rate_limit` doesn't parse. Used
  `audit/ping_rate_limit/entries/{auto}`. Pattern reusable for any
  per-event audit collection.

- **Structured timing log = single helper closure, not scattered calls.**
  BUT-483: `const emitTiming = (success: boolean, extra?: ...) => {
  logger.info("structure_recipe.complete", { event, durationMs,
  textLength, mode, success, ...extra }) }` declared once at the top
  of the function, called at every exit path. Cheaper to maintain than
  copy-pasting the log object at 9+ exit points, and adding a new field
  later means one edit, not nine. Pair with per-exit `reason` field for
  failure-mode breakdown (kill_switch_ai / not_a_recipe /
  rate_limited / etc.) — a future Logs-Explorer slice on `reason`
  becomes trivial.

- **Cloud Logging metric filter is GCP console config, not code.**
  BUT-483's "wire a Cloud Logging metric filter for p95 latency"
  surfaces in plans as a code task but the actual config lives in
  Cloud Console (Logging → Logs Explorer → Create Metric). The CF code
  contribution is just emitting the structured fields cleanly. Ops
  step belongs in a runbook, not in code. Established
  `functions/RUNBOOK.md` for this and future ops-only notes.

- **collectionGroup index needs `queryScope: COLLECTION_GROUP`.** Most
  existing `firestore.indexes.json` entries use `"queryScope":
  "COLLECTION"` because they're per-parent queries. The new ping
  indexes (`expiresAt` ASC, `fromUserId` + `createdAt`) MUST be
  COLLECTION_GROUP because the queries use `db.collectionGroup('pings')`.
  Wrong scope = `FAILED_PRECONDITION` at first run (emulator silently
  auto-builds the right one, masking the deploy bug).

- **Pre-existing test failures unrelated to your changes.**
  `notification-rate-cap.ts:99` calls `admin.firestore()` lazily inside
  `checkAndIncrement`; tests for `detect-lapsed-users` and
  `send-activity-digest` don't initialise an app and don't stub
  `checkAndIncrement` either, so the chain throws `app/no-app`. This
  was already broken on `main` before this sprint. Document in the
  hand-off rather than chase fixes outside scope. Lesson: when running
  the full `npm test` after a multi-task sprint, sanity-check failures
  by `git log --oneline -1 -- <broken-file>` to see if the test file
  was last touched in your work or earlier.

### 2026-05-02 — BUT-753 admin cascade for legacy `sharedWith` arrays [Pattern discovered]

`functions/src/cleanup/on-user-deleted.ts` gained a 10th cascade step:
`cleanupLegacySharedWithArrays(userId)` (with the standard
`...WithDb(database, userId)` test seam). Closes a Right-to-Erasure gap
where the user-driven path
(`SocialDeletionOperations.removeFromSharedContent`) cannot scrub a
legacy `sharedWith: [...uid]` flat-array entry on `shared_content` docs:
`firestore.rules:515-518` only permits `update` if the caller is the
sharedByUserId owner OR has a `members/{uid}` doc — a recipient
present only in the legacy array satisfies neither, the rule denies,
the user is permanently embedded in another user's doc.

**Patterns worth remembering**:

- **Idempotency from two layers**, not one. `array-contains` query
  returns nothing once the user is gone (read-side guard) AND
  `arrayRemove(userId)` is a no-op when the value isn't present
  (write-side guard). Both being independently safe makes the cascade
  retry-tolerant regardless of which guarantee fails first — useful
  when the trigger is `auth.user().onDelete` (v1) which retries on
  any thrown error.

- **Best-effort per chunk for cleanup-style cascades**: a `flush()`
  closure that try/catches `batch.commit()` and logs a warn lets
  partial cleanup land. The next user-delete event for the same uid
  (or a manual sweep) picks up the residue. Failing the whole cascade
  on one chunk error means the OTHER 9 cleanup steps re-run too —
  some of which are not idempotent (presence rows are arguably idem
  but friend counts use `increment(-1)` which double-decrements on
  retry). Containing the failure to one step is the more conservative
  choice.

- **Top-level scan vs collectionGroup**: only `shared_content` (top-
  level) ever held the legacy `sharedWith` array. Verified by `grep
  sharedWith\b` returning zero hits in `firestore.rules` and only one
  unrelated metric-key match in `lib/`. A `collectionGroup` sweep
  would just be cost without coverage.

- **FieldValue marker hijack pattern for unit tests**: when the test
  doesn't initialise a real Firestore app, `admin.firestore.FieldValue
  .arrayRemove` doesn't produce a sentinel the fake batch can recognise.
  Reassign the static method on `FieldValue` to return a symbol-marked
  object (`{ [ARRAY_REMOVE_MARKER]: true, values }`); the fake batch
  type-guards on the marker and applies array-filter semantics on
  commit. Lets the test exercise real `arrayRemove` SUT code without
  an emulator, mirroring the logger-hijack pattern from
  `prompts-config.test.ts`.

- **Existing `auth.user().onDelete` is v1**, not v2. v2 has no
  equivalent auth-trigger as of `firebase-functions@7.2.5`. Don't try
  to migrate this one to v2 until the SDK ships an equivalent — the
  v1 trigger is intentional, not legacy debt.

- **Region pinning via `.region("europe-west1")` chain**: v1 auth
  triggers don't pick up `setGlobalOptions`. Always chain
  `.region("europe-west1")` explicitly (same as the existing
  `onUserDeleted` export). New v1-style functions in this repo MUST
  do this or they deploy to us-central1 by default and silently miss
  the auth events for europe-west1 users.

### 2026-06-03 — BUT-1187 Gemini model retirement 404 [Bug fixed]

Google retired `gemini-2.0-flash-001` (and `gemini-2.0-flash-lite-001`)
on 2026-06-01. Vertex AI returns **404** for retired model ids, so every
recipe-import LLM call (text structuring + image OCR — both share the
single multimodal `TEXT_MODEL` constant via `getTextModel` /
`getIngredientLinesModel` at `gemini-client.ts:71-95`) failed in prod.

Fix: `TEXT_MODEL` `gemini-2.0-flash-001` → `gemini-2.5-flash-lite`
(`gemini-client.ts:782`-ish). One-line swap; `MODEL_ID = TEXT_MODEL`
alias left untouched so analytics auto-follows (verified: kill-switch
test log now emits `"modelId":"gemini-2.5-flash-lite"`).

**Patterns worth remembering**:

- **Vertex model id is a plain string forwarded to the endpoint.** The
  `@google-cloud/vertexai` SDK (pinned 1.12.0) does no client-side model
  validation — `client.getGenerativeModel({ model })` just builds the
  request URL. So a model swap is a pure string change; no SDK bump, no
  signature change, no new generationConfig fields needed.
  `gemini-2.5-flash-lite` is multimodal + supports `responseMimeType`
  + `responseSchema` (the only generationConfig fields this code sets),
  so the two call sites needed zero structural change.

- **Do NOT add `thinkingConfig`.** 2.5 models support a thinking budget;
  flash-lite defaults thinking OFF, which keeps cost/latency at the old
  2.0-flash tier. Adding it would silently raise per-call cost. Leave
  unset.

- **Pricing constants are telemetry-only.** `INPUT_COST_PER_M` /
  `OUTPUT_COST_PER_M` feed `calculateGeminiCost`, which only stamps a
  cost number into analytics — it never gates a request. So a model swap
  must NOT block on confirming exact pricing: set best-known list rate +
  a `// TODO(BUT-1187): confirm <model> pricing` and ship. 2.5-flash-lite
  is cost-parity with the retired 2.0-flash, so the prior 0.10/0.40
  values were kept.

- **Model id has zero test-fixture coupling here.** Grepped
  `functions/src/__tests__` for `gemini-2`/`TEXT_MODEL`/`MODEL_ID` — no
  hits. Tests assert parser behavior on canned response strings, never
  the model id. So the swap needed no test edits. (If a future test ever
  pins the id, it'll be in the kill-switch suite where the
  `structure_recipe.complete` log line surfaces `modelId`.)

- **Single source of truth held.** Only 3 string references to the old
  model existed in `functions/src`, all in `gemini-client.ts` (the const
  + two comments). `docs/architecture/llm-versions.md` is the only other
  place (code block + bump-history table). The BUT-785 single-source-of-
  truth design (one `TEXT_MODEL`, `MODEL_ID` aliases it) paid off — the
  incident fix was genuinely a one-line behavioral change.

- **Retirement ≠ quarterly bump.** The BUT-785 runbook gates bumps on
  golden-test pass-rate + cost-delta review. A forced-retirement 404 is
  incident response, not a cadence bump — noted as such in the bump-log
  so the skipped golden-test gate is auditable. Re-run the golden corpus
  retroactively when BUT-784 lands.

### 2026-06-09 — BUT-1032 phase 1: implicit-cache cost telemetry [Pattern discovered] [Cost finding]

Gemini 2.5 models on Vertex have **implicit caching on by default**; cached
prompt tokens surface as `usageMetadata.cachedContentTokenCount` and are
billed at ~10% of the input rate. `calculateGeminiCost` in
`llm/gemini-client.ts` is now cache-aware:
`((prompt - cached) + cached * CACHED_INPUT_DISCOUNT) / 1M * INPUT_COST_PER_M`,
with `cached` clamped to `[0, promptTokenCount]`. Telemetry-only — no
request-behavior change. Both call sites (structure-recipe, OCR
`defaultPerformOcr`) already passed the whole `usageMetadata` object, so the
discount flowed automatically once the param type accepted the field.

Raw token counts (`promptTokenCount` / `candidatesTokenCount` /
`cachedContentTokenCount`) are now logged on every post-Gemini exit of
`structure_recipe.complete` (incl. `empty_response` — it has a response too)
and via a new `[ocrRecipeImage] Vision call usage` structured log inside
`defaultPerformOcr`. Fields logged **as-is** (may be undefined) — Cloud
Logging drops undefined JSON fields, which distinguishes "Vertex didn't
report it" from a real 0. Never coerce to 0.

Patterns worth remembering:

- **SDK already declares the field.** `@google-cloud/vertexai@1.12.0`'s
  `UsageMetadata` (build/src/types/content.d.ts:428) includes
  `cachedContentTokenCount?: number` — no local type widening needed. Check
  the installed `.d.ts` before assuming a usage field is undeclared.
- **CJS export hijack = Vertex-client test seam without jest.** With
  `module: node16` CJS emit, `import { getTextModel } from "./gemini-client"`
  resolves through the module object at call time, and exported function
  declarations are plain writable `exports.x = x` properties. A ts-node test
  can reassign `geminiClient.getGeminiClient` / `.getTextModel` to fakes
  (restore in `finally`) and drive `runStructureRecipe`'s real success path —
  no seam param needed. See `__tests__/gemini-cache-telemetry.test.ts`.
- **`getPromptsConfig` fail-open makes that test cheap**: the default loader's
  `admin.firestore()` throws `app/no-app` in unit env → caught → compiled-in
  fallback prompts. No admin.initializeApp needed for structure-recipe
  success-path tests.
- **OCR file has no `*.complete` timing log** (unlike structure-recipe's
  BUT-483 `emitTiming`). Usage was logged inside `defaultPerformOcr` because
  the `OcrPerformResult` seam is `{content, cost}` only — widening it would
  touch every test seam. Follow-up candidate: an `ocr_recipe_image.complete`
  emitTiming twin with token counts + retry outcome in one queryable event.
- **Mirror private pricing constants in the cost test on purpose** — a silent
  `INPUT_COST_PER_M` change should turn the telemetry suite red so the cache
  math gets re-reviewed alongside any price update.

### 2026-06-10 — BUT-1222 ocr_recipe_image.complete timing event [Pattern discovered]

The BUT-1032 follow-up landed: `runOcrRecipeImage` now has an `emitTiming`
twin of structure-recipe's `structure_recipe.complete` (BUT-483 pattern),
emitting `ocr_recipe_image.complete` on every exit path with durationMs,
success, reason, retryCount/retryOutcome (BUT-559), modelId, and the three
raw token counts. The standalone `[ocrRecipeImage] Vision call usage` log
from BUT-1032 is removed — tokens are queryable from the same event as
duration/success (one metric filter).

Patterns worth remembering:

- **Optional seam-widening beats a side-channel log.** BUT-1032 avoided
  widening `OcrPerformResult` and logged usage inside `defaultPerformOcr`
  instead. The right long-term fix was an OPTIONAL `usage?` field on the
  seam result — zero breakage for existing `{content, cost}` test seams
  (verified: ocr-retry + ocr-validation suites compiled untouched), and the
  caller owns the single structured event.
- **Token fields stay undefined-capable through the closure.** `let
  ocrUsage` is captured by `emitTiming` and assigned only after the vision
  call; pre-Gemini exits log undefined token fields which Cloud Logging
  drops (absence ≠ zero — BUT-1032 convention preserved).
- **Early-throw exits sit BEFORE the try block** in `runOcrRecipeImage`
  (missing input / isAllowedUrl / BUT-425 validator / size cap), so giving
  them their own `emitTiming(...); throw` does NOT double-emit via the
  catch's `https_error` path. When mirroring this pattern elsewhere, check
  whether validation throws are inside or outside the try before adding
  catch-side emits.
- **OCR exit-path reason taxonomy**: missing_image_input, invalid_image_url,
  url_validation_rejected (+ urlRejectionReason), image_too_large,
  kill_switch_ai, empty_response, parse_failed_after_retry, https_error
  (+ code), rate_limited, internal_error; success carries ingredientCount +
  retryCount/retryOutcome instead of reason.
- **"Exactly one event per call" is the test contract.** Layer-3 cases in
  `ocr-retry.test.ts` clear a module-scope logger-capture array per case and
  assert `completeEvents().length === 1` — this is what catches a future
  double-emit (e.g. someone adding an emit inside the try AND keeping the
  catch emit).

### 2026-06-10 — BUT-1223 run-all test runner + 6 pre-existing suite fixes [Bug fixed]

The composite `npm test` chained 34 suites with `&&` — the first red suite
(lapsed-users, suite #2) masked everything after it, hiding that 6 suites
were red on main. Replaced with `functions/scripts/run-all-tests.js`
(plain Node, no deps): auto-discovers every `test:*` script in package.json
except `test:rules*` / `test:integration:*` (emulator-bound, owned by
firestore-rules-tester), runs ALL of them even when earlier ones fail,
prints a summary, exits non-zero if any failed. Verified by deliberately
breaking `test:kill-switch` mid-list: all 44 suites still ran, exit 1,
failed suite named in summary; restored after.

**Fix 1 — rate-cap app-init seam (lapsed-users + activity-digest)**:
`sendPushToUserRespectingPreferences` called the real `checkAndIncrement`
(BUT-651) directly, which opens a Firestore transaction via
`admin.firestore()` → `app/no-app` in unit env. Root-cause fix: added a
`checkRateCap` field to the helper's `Deps` interface (defaults to the
real `checkAndIncrement`; tests inject `async () => ({allowed, count,
cap, reason})`). Same convention as the gate/recordEvent seams on
DispatchOptions (2026-04-30 entry). Also added a `rate_capped` scenario to
detect-lapsed-users.test.ts proving the seam's decision flows through.

**Fix 2 — cascade fakes vs BUT-886 audit wiring (4 suites)**:
presence-cascade, notification-gdpr, but753-sharedwith, but466-tombstone
fakes predated `stageCascadeAuditEntry` and broke three ways:
1. `database.collection("audit_logs").doc()` — fakes lacked `.doc()` on
   the collection stub (auto-id ref: `audit_logs/auto-N`).
2. `batch.set(ref, data)` — fakes lacked `set`. Route audit set-ops to a
   separate `auditRows` array (NOT the main docs map) so existing
   size()/has() assertions stay about the cascade target docs.
3. `doc.ref.parent.parent` (presence only) — refs were bare `{path}`;
   built a `makeRef(path)` helper deriving the full parent chain.

**Batching assertions were wrong-as-tests after BUT-886** — each cascade
doc now stages 2 ops (mutation + audit), halving the per-batch cap to 250.
The "501 docs → 2 commits" assertions asserted the obsolete pre-audit
behavior; updated to 3 commits (250+250+1), and best-effort failure cases
to "first of 3 chunks fails → 2 successful commits". Also added positive
audit-row assertions (count + operation + userId/targetUid) per suite.

**Orphan suites registered**: `notification-rate-cap`, `cascade-audit-log`,
`cascade-audit-log-wirings`, `duplicate-content-guard`, `on-report-created`,
`parse-recipe-description-length`, `pii-scrubber`,
`rate-limiter-global-limits`, `request-account-deletion`,
`structure-recipe-empty` — 10 test files existed with NO `test:` script
(the 2026-04-30 "easy to forget the chain" lesson had escalated to
forgetting the script entirely). All verified green standalone before
registering. The auto-discovery runner makes this failure mode structural:
a new `test:foo` script is automatically part of `npm test`.

Patterns worth remembering:
- **`npm test` now = `node scripts/run-all-tests.js`** (44 suites, ~100s).
  Adding a suite = add the `test:<name>` script only; no chain to extend.
- **When production code halves a batch cap, grep tests for the old
  commit-count constant.** `git log -1 -- <test-file>` predating the
  wiring commit (here 5bd98f8e8/633595561) is the tell that fakes/asserts
  are stale, not that the production change is wrong.
- **spawnSync on Windows needs `shell: true`** for `npm` (npm.cmd; Node's
  CVE fix blocks .cmd without shell). Command string built only from our
  own package.json script names.

### 2026-06-11 — BUT-694(c) PII heuristics + BUT-838 cook-event GDPR cascade [Pattern discovered]

**BUT-694 option (c)** — `llm/pii-scrubber.ts` gained two deterministic
heuristic rules (no LLM/ONNX): Swedish street addresses
(closed suffix set + REQUIRED house number → `[ADDRESS]`) and person names
(closed relation/honorific trigger set + capitalized name → `[NAME]`,
trigger word kept). The full HEURISTIC CONTRACT lives as a comment block in
the file; the Dart mirror is written from it.

Patterns worth remembering:
- **Shared JSON vector fixture as the cross-port sync mechanism**:
  `src/__tests__/fixtures/pii-heuristic-vectors.json` — `{_header: [...],
  vectors: [{name, input, expected}]}`. TS suite asserts exact full-string
  equality; the Dart side copies the file verbatim. JSON has no comments, so
  the "Dart copies this" note lives in a `_header` string array (wrapper
  object, not a bare array).
- **JS ASCII `\b` mis-fires before å/ä/ö** (Å is non-word in `\w`). For
  Swedish-letter patterns, don't lead with `\b` — let the letter class
  extend the match — or use a `(?<=^|[^A-Za-zÅÄÖåäö])` lookbehind (used for
  the relation triggers). Trailing `\b` is fine after ASCII digits/letters.
- **No `/i` flag when only the trigger should be case-insensitive**: spell
  per-letter classes (`[Mm]ormor`) so the NAME part stays strictly
  capital-initial. The `\s+` after the trigger is what rejects genitives
  ("mormors äppelkaka") and embedded matches ("Frukost" never triggers
  "fru").
- **Reuse `UNIT_SUFFIX_LOOKAHEAD` for any number-terminated heuristic** —
  it's what keeps "Följ Ringvägen 5 minuter" from redacting as an address.
- **Pinned negative landmines**: "X:s" possessive recipe titles ("Janssons
  frestelse", "Gustavs special") must NEVER redact — no general
  capitalized-word NER. These are fixture vectors; don't "improve" the name
  rule into one that matches bare capitalized words.
- **redactionRatio extends by token registration only**: new replacement
  tokens just get appended to `PII_TOKENS`; the ratio (token coverage over
  scrubbed output) then counts them with unchanged semantics. For RULE B the
  kept trigger word correctly counts as non-redacted.

**BUT-838** — `cleanup/on-user-deleted.ts` step 14:
`cleanupRecipeCookEvents(WithDb)` purges the `recipe_cook_events/{userId}`
tree (per-user root doc + event subcollection). BUT-886 audit wiring:
delete + audit = 2 ops/doc via `commitInChunks(opsPerItem: 2)` (chunk cap
250). Tests live in `notification-queues-gdpr.test.ts` (suite doubles as
the general per-user GDPR cascade suite now).

Patterns worth remembering:
- **`listCollections()` for shape-not-yet-final subcollection purges**: this
  cascade shipped BEFORE the client writer (Dart half of BUT-838 lands the
  rules + writes). Discovering subcollections via
  `rootRef.listCollections()` instead of hard-coding `events` keeps the
  cascade correct if the name shifts. It also sees subcollections under
  ghost parents (root doc never written).
- **Root-doc delete gated on `exists`** — auditing the delete of a ghost
  parent is noise; one extra read buys a truthful audit log.
- **New cascade steps should be best-effort, not strict**: a re-thrown error
  retries the WHOLE onUserDeleted cascade, and step 4's
  `friendsCount: increment(-1)` is NOT idempotent — strict failure in a late
  step double-decrements friend counts. Catch + warn + return partial
  (BUT-753 rationale). The strict mode on the notification-queues step is
  pre-existing behavior, not the template to copy.
- **Rules assumption recorded, not implemented**: the cascade assumes
  owner-only rules (`request.auth.uid == userId` read/create, no client
  delete needed — admin cascade is the erasure path). firestore.rules is
  owned by the Dart-side agent/firestore-rules-tester.

### 2026-06-11 — BUT-839 v2-trigger integration tests via CloudFunction.run() [Pattern discovered]

First integration tests for STORAGE/FIRESTORE-TRIGGERED functions (vs the
BUT-1009 precedent which tested a callable's `runX(deps)` seam). Neither
`moderateUpload` (`storage/moderate-upload.ts`, onObjectFinalized) nor
`syncConversationLastMessage` (`messaging/sync-conversation-last-message.ts`,
onDocumentWritten) has a deps seam — their logic is inline in the trigger
body. The emulator does NOT fire deployed trigger code, so the tests invoke
the real handler via the v2 SDK's `CloudFunction.run(event)` surface:

- **v2 exports carry `.run(event)`** — every `onDocumentWritten`/
  `onObjectFinalized`/etc. export is callable as `fn.run(event)` with a
  typed event payload. This proves the REAL handler wiring without
  firebase-functions-test or a functions emulator.
- **Build Firestore `Change` payloads from REAL emulator snapshots**: read
  the doc BEFORE the write (non-existent snapshot for creates — `.data()`
  returns undefined, exactly like production), write, read again, pass
  `{ params, data: { before, after } }`. Delete events: snapshot before,
  delete, snapshot after (exists=false). No hand-rolled snapshot fakes.
- **Storage events are plain objects**: `{ data: { bucket, name,
  contentType, metadata } }` is all `moderateUpload` reads; seed the actual
  bytes via `bucket().file(p).save(buf, { contentType })` first so the
  handler's ranged `download({ start, end })` hits real emulator data.
- **Admin SDK → Storage emulator**: set `FIREBASE_STORAGE_EMULATOR_HOST=
  127.0.0.1:9199` (plus `FIRESTORE_EMULATOR_HOST`, `GCLOUD_PROJECT`,
  `FIREBASE_CONFIG` with `storageBucket`) BEFORE importing firebase-admin.
  The trigger module must also be `require()`d AFTER `admin.initializeApp`.
- **Skip gate**: probe the emulator port(s) with a raw `http.request`
  (any HTTP answer = live; storage answers 501 on bare GET). Port down +
  `process.env.CI` unset → print SKIP, exit 0. In CI (GitHub Actions sets
  `CI=true`) a missing emulator is a hard fail. This keeps Java-less local
  machines green while CI stays strict.
- **Storage emulator alongside the hook's firestore-only emulator**: the
  `ensure-firestore-emulator.sh` instance holds hub 4400 / UI 4000, so a
  second `emulators:start` collides. Workaround: alternate config at REPO
  ROOT (`firebase.storage-emulator.json` — rules path must be inside the
  config's directory, so it cannot live under `.claude/state/`) with
  `--only storage`, hub 4401, logging 4501, UI disabled:
  `firebase emulators:start --only storage --project demo-test --config
  firebase.storage-emulator.json`. CI doesn't need this (it starts
  firestore,storage in one instance).
- **Shared demo-test namespace**: when a suite uses project `demo-test`
  (so storage's singleProjectMode doesn't complain), use per-run unique
  ids, assert by unique resourceId (avoids needing a namespace wipe that
  would clobber parallel suites), and delete seeded docs in cleanup.
- Suites wired as `test:integration:moderate-upload` /
  `test:integration:sync-conversation`, appended to `test:rules:all`
  (which the firestore-rules CI lane runs with both emulators up), and
  added to the workflow's path triggers incl. `functions/src/storage/**`
  + `functions/src/messaging/**`.

### 2026-06-13 — BUT-626 prompt A/B bucket experiment [Pattern discovered]

`functions/src/shared/prompt-ab-bucket.ts` — deterministic per-user bucket
assignment for prompt experiments. Two exported functions:
- `assignPromptBucket(userId, bucketCount?)` — SHA-256(`uid:prompt_experiment`)
  mod bucketCount. Pure, <5µs, zero Firestore reads.
- `resolvePromptBucket(userId, promptVariants?)` — maps bucket to named variant
  from an optional `string[]`. Returns `{ bucket, variant }` where `variant`
  is undefined when no experiment is configured (safe no-op).

Integration points:
- `PromptsConfig` (prompts-config.ts) gained optional `promptVariants?: string[]`
  parsed from `system/prompts` Firestore doc. Validation is all-or-nothing:
  any invalid element (non-string, empty string) → field absent (no partial
  overlay). Doc without the field → field absent. The five required string
  fields are completely unchanged; `promptVariants` is strictly additive.
- `structure-recipe.ts` + `ocr-recipe-image.ts`: declared `let experimentBucket`
  and `let promptVariant` in the function scope BEFORE the `emitTiming` closure
  so the closure captures them at call time. They get assigned after
  `getPromptsConfig()` resolves. Early exit paths (validation before prompts
  fetch) emit undefined bucket fields — Cloud Logging drops undefined JSON
  fields, distinguishing "bucket not yet known" from bucket=0.
- Both `structure_recipe.complete` and `ocr_recipe_image.complete` analytics
  events now carry `experimentBucket` (number) and `promptVariant` (string |
  absent) alongside the existing `promptVersion`.

**Operator workflow to start an experiment**: add
`promptVariants: ["control", "challenger"]` to the `system/prompts` Firestore
doc alongside the normal `promptVersion` bump. Every CF instance picks it up
within the 5-min cache TTL. To end the experiment: remove the field (or leave
it — variant=undefined is the no-op fallback). No redeploy needed.

**Patterns worth remembering**:

- **Mutable closure variables let early-exit emitTiming stay unaware of
  bucket assignment.** The alternative (passing bucket explicitly to every
  `emitTiming(false, {...})` call) would mean touching 9+ call sites. Declare
  `let experimentBucket: number | undefined` BEFORE `emitTiming`, assign
  AFTER prompts fetch. Cloud Logging drops undefined JSON fields, which is
  exactly the right signal for "validate-before-fetch" exits.

- **`:prompt_experiment` salt keeps this bucket independent of winback
  buckets.** Same user hashes to different buckets for different experiments.
  Don't reuse the `:thresholdType` salt pattern from BUT-688 for orthogonal
  experiments — give each experiment its own salt string.

- **`promptVariants` does NOT replace `promptVersion`.** `promptVersion`
  remains the canonical analytics key for prompt regressions (bumped on every
  doc edit). `experimentBucket` + `promptVariant` are additive fields for
  A/B slicing. A Logs Explorer query like
  `jsonPayload.experimentBucket=0 AND jsonPayload.promptVersion="v12"`
  filters to one bucket for one prompt version.

- **Bucket count comes from the variants array length.** When `promptVariants`
  has 3 entries, bucketCount=3 automatically. No separate config field needed.

- **Test suite** (`test:prompt-ab-bucket`, 14 cases): covers stability,
  ±10% distribution for 2- and 3-bucket cases over 1000-1500 ids,
  variant-to-bucket mapping correctness, all fallback/malformed paths, and
  the analytics payload shape. Auto-discovered by the run-all-tests.js runner.
