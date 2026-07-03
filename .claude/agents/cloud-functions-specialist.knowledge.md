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

### 2026-06-29 — family-diner ratings fold into public counter [Pattern discovered]

`updateRecipeRatingStats` (extracted to
`functions/src/ratings/update-recipe-rating-stats.ts`, now `(recipeId, db?)`
with an injectable db) folds TWO sources into one `recipe_social_stats/{recipeId}`
aggregate: `recipe_ratings` (`rating` + `createdAt`) and `family_ratings` where
`memberType == "profile"` (`stars` + `lastUpdatedAt ?? createdAt`). Three new
triggers `onFamilyRating{Created,Updated,Deleted}` on `family_ratings/{id}`,
gated to `memberType == "profile"`, call the same `scheduleRatingAggregation`
debounce path as the recipe_ratings triggers.

**Verified clean:**
- **No double-count** — confirmed against `family_rating_service.dart:147`:
  only a genuine self-rate (`memberType == user && enteredByUid == memberId`)
  mirrors to `recipe_ratings`. The aggregator folds only `profile` rows, so an
  adult's `user`-type family row is never added on top of their recipe_ratings
  row. The proxy-entered `user` rows are also correctly excluded.
- **Two-equality family query needs no composite index** — per
  `accepted-deviations.md`, equality-only `where(recipeId==).where(memberType==)`
  uses merged single-field indexes. Confirmed: no `orderBy`/range, so no
  composite. Not a finding.
- **memberType string match** — `HouseholdMemberType.name` produces exactly
  `"profile"`/`"user"` (enum in `family_rating.dart:8`); `toFirestore` always
  writes the field, so the server's raw-string `== "profile"` query is safe.
  Note the model's `fromName` defaults unknown→`profile` on READ only; doesn't
  affect the stored string the server queries.
- **Idempotency** — aggregator re-reads BOTH collections fully on each run and
  `set(..., {merge:true})`; debounce collapse is correct by construction
  (claim-by-delete drainer unchanged). Family update trigger gates on
  `before.stars !== after.stars` mirroring the recipe_ratings `rating` gate.
- **Drainer wiring** — `aggregate: updateRecipeRatingStats` in `index.ts:328`;
  drainer calls `aggregate(recipeId)` (one arg), optional `db?` defaults to
  `admin.firestore()`. Compatible.

**LOW finding (not a bug, behavior change worth recording):** a family diner
rating a PRIVATE (never-shared) recipe now creates a `recipe_social_stats/{recipeId}`
doc. That collection is `allow read: if isAuthenticated()` (firestore.rules:2299),
so any signed-in user who knows/guesses the recipe id can read an ANONYMOUS
aggregate (count/avg/distribution — no rater identity) for an otherwise-private
recipe. Pre-change, the doc only existed once a recipe entered the social rating
flow (`social.rateRecipe`). Acceptable given anonymity + opaque recipe ids, but
if private-recipe existence/score must stay hidden, gate stats creation on the
recipe being shared. Flagged, not fixed.

**Test fidelity nit:** the integration test seeds family doc ids as
`${recipeId}_${memberId}` but production `FamilyRating.buildId` uses
`$recipeId|$memberId` (pipe). Harmless — neither the query nor the aggregator
parses the doc id (both key off the `recipeId` field). Worth aligning if the
test is ever used as a doc-shape reference.

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

### 2026-06-15 — BUT-840 Algolia mirror in on-profile-updated [OPS-BLOCKED]

Ticket asked to extend `social/on-profile-updated.ts` to refresh the Algolia
user search record (`partialUpdateObject`) on displayName/avatarUrl change, so
the renamed-user mirror stops going stale. Step-0 feasibility gate halted it:
the Cloud Functions environment has **no Algolia ADMIN credentials**, so the
server cannot write the index. Not implemented (did not stub/invent a secret).

Evidence gathered:
- `functions/package.json` has no `algoliasearch` dependency. No
  `functions/src/algolia/` directory exists (a stale doc-comment in
  `lib/repositories/algolia/algolia_search_repository.dart:26` references one
  — it was never created).
- No `defineSecret`/params/functions-config entry for any `ALGOLIA_*` key
  anywhere under `functions/`. The only "Algolia" hits in `functions/src/` are
  a PII-scrubber regex comment and a test name — coincidental.
- The Flutter client gets its key via `String.fromEnvironment('ALGOLIA_APP_ID'
  / 'ALGOLIA_API_KEY')` (compile-time `--dart-define`, from the Flutter-side
  `.env`). That is the **search-only** key — it cannot write the index. The
  ticket itself notes the index is written client-side today.

What must be provisioned (the OPS hand-off) before this can be implemented:
1. An Algolia **Admin API key** (write-scoped) stored in **Secret Manager**,
   e.g. `firebase functions:secrets:set ALGOLIA_ADMIN_API_KEY`, read in code
   via `defineSecret("ALGOLIA_ADMIN_API_KEY")`.
2. The Algolia **App ID** + **users index name** as params/secrets too
   (`ALGOLIA_APP_ID`, `ALGOLIA_USERS_INDEX`). App ID must be the EU cluster
   (`-eu`) per the BUT-580 GDPR invariant enforced client-side.
3. Add the `algoliasearch` SDK (or call the REST `partialUpdateObject`
   endpoint directly to avoid the cold-start cost of the SDK — preferred,
   ~one `fetch` PATCH to `/1/indexes/{index}/{objectID}/partial`).

Lesson worth remembering: **a client-side third-party integration using a
public/search-scoped key does NOT imply the server can write that service.**
Server-side index writes need an admin key that must be independently
provisioned in Secret Manager — never assume it exists because the client
talks to the same vendor. Re-validate creds at Step 0 for any "extend the CF
to also call <external service>" ticket.

### 2026-06-20 — daily-snapshots for dashboard delta/anomaly series [Pattern discovered]

`functions/src/analytics/daily-snapshots.ts` — five `onSchedule` jobs that
each write ONE doc per UTC day to `analytics/<group>/daily/{date}`, giving
the admin dashboard's delta-arrow + anomaly engine a historical series for
the non-time-series tabs (Importhälsa / Recept / Parsing / Drift / Feedback).
Exports: `snapshotImportHealthDaily`, `snapshotRecipesDaily`,
`snapshotParsingCorrectionsDaily`, `snapshotOpsDaily`, `snapshotFeedbackDaily`
(registered in `index.ts` after `computeFeatureRetention`). Compiles clean.

**Patterns worth remembering:**

- **Five structurally-identical aggregators → shared helpers, one file.**
  `resolveDayWindow(deps)` returns `{db, dateStr, startMs, endMs, dayStart,
  dayEnd, computedAt}` from the run time once — every job calls it instead of
  re-deriving UTC boundaries. `dailyDocRef(db, group, dateStr)` centralizes
  the `analytics/<group>/daily/{date}` (4-segment doc) path so no job
  miscounts segments (the recurring 3-vs-4 segment trap). `bump(obj, key)`
  for the per-bucket counters. Kept all five `runX(deps)` seams + thin
  `onSchedule` wrappers exactly like `compute-feature-retention.ts`.

- **Region is inherited, NOT pinned per-function.** None of these set a
  `region` in the `onSchedule` options — `setGlobalOptions({region:
  "europe-west1"})` in `index.ts` governs every function. Pinning a per-
  function region here would be redundant at best and a drift risk at worst.
  Confirmed `compute-feature-retention.ts` also omits it. The convention is:
  global option only, never per-function.

- **`feedback.createdAt` is an ISO-8601 STRING, not a Timestamp.** The other
  four collections (`parse_events`, `parsing_corrections`, `system_events`)
  use real `Timestamp` fields (`timestamp`, `timestamp`, `executedAt`
  respectively) so they range-compare with `Timestamp.fromMillis`. Feedback
  must range-compare with `new Date(startMs).toISOString()` /
  `endMs.toISOString()` boundary STRINGS — correct because ISO-8601 sorts
  lexicographically == chronologically. Mixing the two (passing a Timestamp
  to the feedback query, or a string to the others) silently returns zero
  rows — no error, just a wrong snapshot.

- **`system_events` removed-count is dual-named.** `totalDeleted` OR
  `deletionAuditDeletedCount` depending on which cleanup job wrote the row.
  The snapshot sums `data.totalDeleted ?? data.deletionAuditDeletedCount`,
  mirroring `lib/models/admin/ops_event.dart:OpsEvent.fromFirestore` on the
  dashboard read side. Verified against that model — keep the two in sync.

- **Recipe method classification keys off `core.sourceArtefact.type`** (the
  `SourceArtefactType.name` string from `lib/models/recipe/source_artefact.dart`):
  `url→url`, `photoOcr→photo`, `textPaste→textPaste`,
  `youtubeTranscript|tiktokCaption|instagramCaption→social`, missing/null/
  unknown→`manual`. Extracted as `classifyRecipeMethod()` so it's unit-
  testable. Recipes live at `users/{uid}/recipes` (subcollection) → the scan
  is `db.collectionGroup("recipes")`.

- **Only the recipe snapshot can grow unbounded.** Four of the five are
  single-day range scans (effectively free at beta scale). The recipe one is
  a FULL collection-group scan (a stock count, not a per-day delta) → hard-
  capped at `RECIPE_SCAN_CAP = 5000` with a `logger.warn` if `snap.size >=
  cap`. When that warn fires, the counts become a floor, not exact — switch
  to an incremental `core.createdAt`-windowed query. Documented inline.

- **Staggered 05:00–05:40 UTC** to clear the existing 04:00
  (`track-retention`) / 04:30 (`compute-feature-retention`) jobs that scan
  big collections. Same scheduling-collision discipline as BUT-599.

### 2026-06-20 — Gen1→Gen2 fleet migration scoping [Pattern discovered]

A `firebase deploy --only functions` aborts with "[onRecipeDeleted(europe-west1)]
Upgrading from 1st Gen to 2nd Gen is not yet supported." This is NOT a single-
function problem — it's a whole-fleet stale-generation drift. Firebase aborts
the ENTIRE deploy on the first gen-conflict it hits, so you only ever see one
name in the error even when dozens are affected.

**Why it happened**: `index.ts` was migrated wholesale to `firebase-functions/v2/*`
+ `setGlobalOptions({region:"europe-west1"})`, but the matching `delete-then-
deploy` was never run for the already-deployed 1st-gen copies. Firebase forbids
in-place gen upgrade, so every function whose deployed copy is still gcfv1 blocks.

**Scoping recipe (reusable)**:
1. `firebase functions:list --json` — BUT the `version` field (gcfv1/gcfv2) only
   populates on a DIRECT terminal call. Via `execSync`/piped context it comes
   back `null`/`undefined`. Capture the gen/region from a direct `functions:list`
   run, then cross-reference names against `index.ts` exports in code.
2. Parse `index.ts` exports: `export { ... }` blocks (take the post-`as` alias)
   + `export const X`. That's the source-of-truth set.
3. Classify each deployed fn: gcfv1+eu+in-source → DELETE+RECREATE (gen blocker);
   us-central1+in-source → DELETE(us)+DEPLOY(eu) (region move, also a delete);
   gcfv2+eu → plain redeploy; deployed-but-not-in-source → DELETE-only orphan.

**This audit's result** (butlery-app-1, 47 deployed): 16 gcfv1 eu gen-blockers,
17 us-central1 stragglers (all gcfv1), 1 orphan (`cleanupExpiredFriendRequests`,
renamed to `cleanupExpiredSocialRequests` in source), 13 already-correct,
17 new-never-deployed.

**Critical exception — auth triggers stay v1.** `onUserDeleted`
(`cleanup/on-user-deleted.ts`) is `v1.auth.user().onDelete(...)` and imports
`firebase-functions/v1` BY DESIGN — Firebase Auth `user().onDelete` has NO Gen2
equivalent. It deploys as gcfv1 and that is CORRECT; it is a plain redeploy, NOT
a gen migration. Don't "fix" it to v2 — there is no v2 form of it. (`shared/
batch-update.ts` also imports `firebase-functions/v1` but only for `v1.logger`,
not a trigger — harmless.) Grep `firebase-functions/v1` to find these before
assuming "all source is v2".

**Gap-risk classification for delete+recreate**: a delete-then-deploy leaves a
window where the function doesn't exist.
- SCHEDULED + CALLABLE → SAFE-GAP. A missed cron tick re-runs next interval; a
  callable just errors client-side and retries. No silent data loss.
- EVENT TRIGGERS (Firestore onDocument*, Auth onDelete) → RISKY-GAP. Eventarc
  does NOT backfill events that fire while the trigger is absent — they're
  dropped silently. Dangerous ones here: `onRecipeDeleted` (orphaned Storage
  images = silent cost leak), `onUserDeleted` (GDPR social-cascade cleanup
  missed — a deletion during the gap leaves PII in other users' docs),
  `onProfileUpdated` (stale denormalized name/avatar), `onReportCreated`
  (moderation report dropped). Mitigation: delete + immediately redeploy EACH
  risky trigger individually (gap ~60-90s, not minutes), do them one at a time
  last, ideally during low traffic. For pre-launch ~1-user scale the practical
  risk is near-zero but the discipline matters at scale.

**predeploy hook** (`firebase.json`): runs `npm ci` + `npm audit --audit-level=
critical` + `npm run build`. `npm ci` does a CLEAN reinstall — slower, and will
fail the whole deploy if lockfile/registry hiccups. Build was confirmed green
before planning.

### 2026-06-20 — detectAnomalies nightly outlier job [Pattern discovered]

New scheduled CF `functions/src/analytics/detect-anomalies.ts` (export
`detectAnomalies`, 06:00 UTC) reading the five `daily-snapshots.ts` series at
`analytics/<group>/daily/{date}` and writing one report doc at
`analytics/anomalies/daily/{date}` (4-seg = doc). Same `runDetectAnomalies(deps)`
test-seam + thin `onSchedule` wrapper shape as `daily-snapshots.ts` /
`compute-feature-retention.ts`. Test `__tests__/detect-anomalies.test.ts`
(10 cases, all pass), `test:detect-anomalies` script added (auto-discovered by
`scripts/run-all-tests.js`). Build + test green.

**Detection rule** (all four gates): baseline count ≥ MIN_SAMPLES(14), sample
stddev > 0, |z| > 3, AND |today − mean| ≥ a per-series ABSOLUTE_FLOOR (default
5). The floor is the load-bearing one — without it 3σ on tiny pre-launch counts
(0→2 feedback rows) fires constantly. `metric` token MUST be exactly
`<group>_<field>` (e.g. `import_health_totalFailure`, `recipes_total`) — the
Flutter AnomalyRepository keys its label map off these literals.

**Patterns worth remembering**:

- **Schedule offset for read-after-write CFs.** Pinned 06:00 UTC because it
  CONSUMES what the 05:00–05:40 snapshot jobs PRODUCE that same morning. A
  consumer that scans a producer's same-day output must schedule strictly after
  the producer's slowest run, with margin (snapshots finish in <5 min at scale;
  20 min margin is cheap insurance). If today's snapshot doc is missing for a
  series (producer hasn't run / no data), SKIP that series and log info — don't
  guess a zero, which would manufacture a false "drop" anomaly.

- **Sample stddev (n−1), not population.** Daily series are a sample of an
  ongoing process, so use the n−1 denominator. `computeBaselineStats` returns
  stddev 0 for count<2 so the stddev>0 gate naturally absorbs the degenerate
  case — no separate guard needed.

- **id-desc orderBy on a date-string-keyed subcollection is free.**
  `orderBy(FieldPath.documentId(), "desc").limit(29)` gives the trailing window
  with no composite index (doc-id order is intrinsic) because doc ids are
  `yyyy-mm-dd` which sort lexicographically == chronologically. Same property
  the feedback snapshot relies on for its ISO-string range query.

- **Pure `evaluateSeries(series, today, baseline)` split out from the I/O.**
  The four-gate decision is a pure function tested in isolation (cases g/h),
  while `runDetectAnomalies` only does fetch + split-on-run-day + write. Keeps
  the statistical logic testable without any fake DB and makes the floor/z
  thresholds trivially unit-checkable.

- **Empty report is still written.** Even with zero anomalies the job writes
  `{date, anomalies: [], computedAt}` so the dashboard can distinguish "ran,
  nothing wrong" from "job never ran" (missing doc). Don't early-return on an
  empty anomaly list.

- **Idempotency**: deterministic doc id = run-day UTC date + `set()`. Re-run
  test asserts writeCount=2 but one distinct output path (case i), the canonical
  idempotency proof for this codebase.

### 2026-06-20 — WS3 validate-limit + on-suggestion-created review [Pattern discovered]

`shared/validate-limit.ts` — `clampLimit(raw, {fallback, max})` imports `HttpsError`
from `"firebase-functions/v2/https"`. Confirmed correct: the v2 callable dispatcher
catches any `HttpsError` instance thrown anywhere in the call stack and surfaces it
as `functions/invalid-argument` to the client. No special wiring needed.

`on-suggestion-created.ts:93-95` — **Medium**: `suggestion.originalName` (raw user
text) was embedded as a string literal in a `logger.info` message body. Per logging
conventions, user-supplied free-text must never appear in structured logs (potential
PII). Fix: replace with `originalNameLength: suggestion.originalName?.length ?? 0`
in the structured second argument. This is the correct pattern when the operationally
useful signal is "did we get a non-empty value", not the value itself.

Patterns worth remembering:
- **`HttpsError` thrown by a helper inside an `onCall` handler propagates
  correctly** — the v2 dispatcher does not require the `HttpsError` to originate
  from the top-level handler function. Deep helpers can throw it directly.
- **`requireAdmin` before `clampLimit` is safe**: a non-admin caller never reaches
  the limit validation, so exposing a clear `invalid-argument` error to admin callers
  on malformed input does not change the security posture for non-admins.
- **Idempotency guard pattern for onDocumentCreated**: stamp a metadata field
  (`notifiedAt`) on success, check `if (doc.notifiedAt) { return; }` at the start.
  Works because the trigger retries on uncaught exception; any retry sees the stamp
  and exits cleanly. The existing pattern in on-suggestion-created is correct.
- **User-supplied free-text fields (ingredient names, recipe titles) must never
  appear in logger message strings.** Log length or a hash instead. The structured
  second arg to `logger.info` should only contain safe identifiers (hashed UIDs,
  doc IDs, counts, enums).

### 2026-06-20 — B1 acceptFriendRequest review: tx.update vs tx.set(merge) [Pattern discovered]

`functions/src/social/accept-friend-request.ts` reviewed clean except one
Medium finding: `tx.update(fromProfileRef, {friendsCount: increment(1)})` and
the matching `tx.update(toProfileRef, ...)` both call `update`, which throws
`NOT_FOUND` if the `public_profiles` doc does not exist. No data corruption
results (the transaction aborts without committing anything), but the callable
returns `HttpsError("internal")` instead of a meaningful error for any user
whose profile doc was never created. The test seeds both docs unconditionally
so the emulator suite can't surface this gap.

Fix: replace both `tx.update` calls with `tx.set(..., { merge: true })`. A
`set` with `merge: true` is an upsert — safe for both absent and existing docs.

**Patterns worth remembering:**

- **`tx.update` vs `tx.set(merge: true)` in transactions**: `tx.update` fails
  with `NOT_FOUND` on a missing doc; `tx.set(data, { merge: true })` is the
  safe upsert alternative. For `FieldValue.increment` writes on aggregate docs
  that MIGHT not exist yet (profile docs created asynchronously on first sign-in,
  join-era accounts, race conditions), always use `set + merge`.

- **Integration test seeders hide the missing-doc class of bugs.** When every
  test case calls `seedProfile()` before the function under test, any `tx.update`
  precondition failure is invisible. Add a test variant that deliberately omits
  the profile seed whenever the code path touches a doc that could reasonably
  be absent.

- **Early-return inside a transaction with no writes is valid and correct.**
  `database.runTransaction(async tx => { ...; return value; })` with zero writes
  commits an empty transaction (no-op). The SDK does not throw. Verified in B1
  context: the `status === "accepted" && alreadyFriends` early return on line
  127-129 is safe.

- **Consent gate is transaction-local.** The `toUserId !== callerUid` check
  (permission-denied path) occurs BEFORE any writes within the same transaction
  execution. There is no path where writes precede the gate. Future reviewers
  should verify this property explicitly whenever the guard and the writes
  are both inside the same `runTransaction` callback.

### 2026-06-21 — BUT-1167 (AI8) prompt-changelog CI gate [Pattern discovered]

New CI gate failing when an LLM prompt in `gemini-client.ts` changes without a
matching `PROMPT_CHANGELOG.md` update. Pure core +
CLI + workflow + hand-rolled test. Files: `functions/src/ci/prompt-changelog-guard.ts`
(pure `promptChangelogViolation(changedFiles, geminiClientDiff)`),
`functions/src/ci/prompt-changelog-guard-cli.ts` (git-driven wrapper, exits 1),
`functions/src/__tests__/prompt-changelog-guard.test.ts` (10 cases),
`.github/workflows/prompt-changelog-gate.yml` (Node-only, no Flutter).

**New family**: `ci/` — pure CI-gate logic + thin git/process CLI wrappers,
deployed-irrelevant (excluded from `index.ts`). Test command:
`npm run test:prompt-changelog-guard` (auto-discovered by
`scripts/run-all-tests.js` since it's a `test:*` script).

| Path | Concern | Trigger | Test |
|---|---|---|---|
| `ci/` | Pure gate logic + git CLI wrapper, not deployed | n/a (run in GitHub Actions) | `test:<name>` |

**Patterns worth remembering**:

- **Token-matching on changed lines is NOT enough for multi-line prompts.**
  The prompts are big backtick template literals. Editing a prompt's *interior
  body text* (the most common + most quality-relevant change) produces a diff
  whose `+`/`-` lines carry NO prompt token — only the surrounding `const
  RECIPE_EXTRACTION_SYSTEM_PROMPT = \`...` declaration does, and that sits on a
  context line. My first cut missed this; my own test case (a') caught it. Fix:
  also scan the **git hunk header's enclosing-declaration context**. For TS,
  `git diff` appends the enclosing declaration after the closing `@@`, e.g.
  `@@ -252,7 +252,7 @@ export const RECIPE_EXTRACTION_SYSTEM_PROMPT = \`...`.
  If a hunk's context names a prompt token AND the hunk changes a line, it's a
  prompt edit. Verified empirically against a real `sed` body edit before
  coding the heuristic — don't guess what git emits, generate a sample diff.

- **Two-signal detection avoids both misses and false-positives.** Signal 1:
  prompt token on a changed line (version bump / constant decl / INJECTION_DEFENSE).
  Signal 2: changed line inside a prompt-declaration hunk (interior body edit).
  Context lines and `+++`/`---` file headers never trip it alone, so an edit to
  a `estimateTokenCount` helper (whose hunk context is the function name, no
  prompt token) correctly passes — the explicit no-false-positive case.

- **`_SYSTEM_PROMPT` substring beats enumerating constant names.** Matching the
  shared suffix covers all five current prompts AND any future `*_SYSTEM_PROMPT`
  without a code change. Same spirit as the BUT-641 route-allowlist drift guard
  but inverted (here we WANT new constants auto-covered).

- **Diff-base resolution in the workflow.** PR events: `github.event.pull_request.base.sha`.
  Push events: `github.event.before` (guard against the all-zero first-push
  SHA → fall back to `HEAD^`). `fetch-depth: 0` is mandatory so the base commit
  exists locally. The CLI takes `merge-base(base, HEAD)` internally so it only
  sees this branch's own changes, not unrelated commits on the base.

- **Pure core / git CLI split is the testable shape for CI gates.** The pure
  function takes `(changedFiles, diff)` and is exhaustively unit-tested with
  synthetic diffs; the CLI does the git plumbing and exits. End-to-end I also
  validated the real CLI against a throwaway violating commit (exit 1) and the
  fixed commit with changelog (exit 0) on a temp branch, then restored main.
  Don't trust the unit test alone for a gate — prove the git wiring exits
  correctly too.

- **Convention check paid off: NO jest in this repo.** Task spec asked for a
  "jest test" but the knowledge file (and every existing suite) uses the
  hand-rolled `test()` harness via ts-node + `run-all-tests.js` auto-discovery.
  Wrote the test in-harness instead; flagged the deviation rather than
  introducing jest. Always reconcile a task's wording against the established
  test convention before adding a framework.

### 2026-06-22 — BUT-1352 (AI6) recipe-text splitter dedup — PREMISE STALE [Pattern discovered]

Ticket asked to consolidate "duplicated recipe-text splitter logic" in
`functions/src`. Investigated all `.split(` sites; there is NO genuine
duplication. Closed as premise-stale, no refactor.

Evidence map (so future passes don't re-chase this):
- **Only one** recipe-text line-split exists: `llm/structure-recipe.ts:494`
  `text.split("\n").filter((l) => l.trim().length > 0)` inside
  `buildIngredientLinesPrompt` — counts already-newline-separated ingredient
  lines from the Dart client to interpolate the count into the prompt.
  Single occurrence in the whole LLM pipeline.
- `llm/ocr-recipe-image.ts` — zero text line-splitting (URLs + JSON only).
- `llm/gemini-client.ts` — zero text line-splitting; response handling is
  `JSON.parse` + the BUT-577 brace-counter salvage, not line splitting.
- `llm/pii-scrubber.ts:285` — `split("/")` on a URL **pathname** for opaque-
  token redaction. Different delimiter/input/intent.
- `admin/sync-ingredients.ts:158` — `content.split("\n").filter((l) => l.trim())`
  looks structurally identical but is the first step of a **CSV parser** in a
  manual non-deployed `admin/` script, feeding rows into the quote-aware
  `parseCsvLine`. Sharing a helper would couple the deployed LLM pipeline to a
  ts-node admin script for a one-liner — a false abstraction.
- All other `.split` hits are unambiguous different-intent: `/` for Firestore
  doc paths + Storage object names, `T` for ISO dates, `/\r?\n/` for the CI
  prompt-changelog diff guard, `;`/`,` for CSV field lists + content-type headers.

**Pattern worth remembering**: "scattered `.split()`" is NOT evidence of
duplication. A real splitter-dedup needs the *same intent on the same input
type* at 2+ sites. A line-split into trimmed non-empty lines that appears in a
prompt builder and in a CSV parser are different intents that happen to share
characters — don't extract. Per the ticket's own decision rule this is the
"different-intent one-liners → do NOT refactor" branch.

### 2026-06-24 — BUT-1354 emulator integration tests for cleanup jobs [Pattern discovered]

Added emulator-bound integration tests for three scheduled/triggered cleanup
jobs by extracting their handler bodies into plain exported async cores
(mirroring `acceptFriendRequestWithDeps`). Cores: `cleanupOldRateLimitsCore(db)`
in `cleanup/cleanup-rate-limits.ts`, `cleanupSharedContentMetadataCore(db)` in
`cleanup/cleanup-shared-content-metadata.ts`, and (already a delegated private
fn) `cleanupUserSocialData(userId)` in `cleanup/on-user-deleted.ts` — now
exported and returning its `results` summary. Each `onSchedule`/trigger wrapper
is a one-liner that calls the core. Tests:
`cleanup-rate-limits.integration.test.ts` (7/7), `…shared-content-metadata…`
(11/11), `on-user-deleted.integration.test.ts` (13/13). All green via
`firebase emulators:exec --only firestore --project demo-test "npx ts-node …"`.

**Patterns worth remembering**:

- **`onSchedule`/v1-auth-trigger bodies need the `runX(db)` test seam too.**
  Same lift as analytics CFs: pull the body into an exported async core, leave
  the wrapper as one delegating line, return a small summary
  (`{deletedCount, processedUsers}` etc.) so emulator tests can assert both
  effects AND counts. Byte-for-byte body lift — no logic change.

- **on-user-deleted needs NO injected `db`.** Its cascade + ~14 helpers all
  close over the module-level `db = admin.firestore()`. Because the integration
  test sets `FIRESTORE_EMULATOR_HOST` BEFORE `admin.initializeApp` and
  `require()`s the module AFTERward, that module `db` is already emulator-bound.
  Threading a `database` param through every helper would be large, risky churn
  for zero test benefit — exporting the existing delegated fn (made to return
  its results) is the faithful minimal extraction. The injected-`db` form
  (rate-limits/shared-metadata) is right when the body already takes `db`
  locally; the module-db form is right when helpers close over module `db`.

- **Storage delete fails gracefully without a Storage emulator.** The feedback
  screenshot purge in on-user-deleted calls
  `admin.storage().bucket().deleteFiles(...)`; with no `storageBucket` configured
  it throws "Bucket name not specified", but the production try/catch logs a
  warn and continues. The integration test (firestore-only emulator) exercises
  this path and confirms the cascade still completes + returns its summary —
  good evidence the best-effort wrapping works.

- **Parent docs must be seeded for `orderBy("__name__")` user/parent scans.**
  Both rate-limits (scans `users`) and shared-metadata (scans
  `shared_recipes`/`shared_menus`/`shared_shopping_lists`) paginate the parent
  collection. Subcollection-only writes don't make the parent doc "exist" for a
  collection scan in the emulator, so seed an explicit `parentRef.set({...})`
  or the scan enumerates nothing and the test silently deletes zero.

- **`run-all-tests.js` already excludes `test:integration:`** — registering the
  three new `test:integration:cleanup-*` / `test:integration:on-user-deleted`
  scripts keeps them out of `npm test` automatically (emulator-bound). No edit
  to the runner needed; confirmed the prefix match.

- **functions/ has no eslint config or lint script.** The `eslint-disable`
  comments in existing `*.integration.test.ts` are precautionary only. The
  verification gate is `npm run build` (tsc): `tsconfig.json` `include:["src"]`
  covers `src/__tests__`, and `noUnusedLocals` + `noImplicitReturns` are on, so
  the typecheck catches unused imports and missing-return paths in both cores
  and tests.

### 2026-06-27 — BUT-1386 verifySignupAge DI-core tests [Pattern discovered]

Wrote `functions/src/__tests__/verify-signup-age.test.ts` (7 cases, all green
via `npx ts-node`) for `account/verify-signup-age.ts`'s
`runVerifySignupAgeWithDeps(deps, uid, birthYear)` + `enforceIpAuditCap(db, ip)`.
Mirrors `request-account-deletion.test.ts`: hand-rolled `test()` harness, fake
`{db, auth}` injected, no emulator. Registered `test:verify-signup-age` in
package.json so `run-all-tests.js` auto-discovers it (`npm test`).

**Patterns worth remembering:**

- **Assert field ABSENCE, not just presence, for data-minimisation contracts.**
  This function's whole Legal premise is what it *doesn't* write. The rejection
  audit row must carry no `uid`/`userIdHash`/`birthYear`/`birthDecade`, and the
  compliance row must carry no raw `birthYear`. Tests use `!("birthYear" in row)`
  etc. A presence-only test would pass even if someone later leaked the uid into
  the rejection row — exactly the regression that matters here.

- **`HttpsError.code` is namespaced `functions/<code>`.** When asserting an
  `HttpsError` from firebase-functions, `err.code` reads
  `"functions/resource-exhausted"`, not bare `"resource-exhausted"`. Accept both
  so the test isn't brittle to the SDK's prefixing. Same trap will hit any future
  test asserting on an HttpsError code in this repo.

- **Use real `new Date().getFullYear()` for age boundaries, don't hardcode.**
  The SUT computes `currentYear` from the system clock, so the test derives
  boundary birth years as `CURRENT_YEAR - MIN_AGE_YEARS` (admit) and
  `CURRENT_YEAR - (MIN_AGE_YEARS - 1)` (reject). Hardcoding `2011`/`2012` would
  silently rot as the year ticks over. The function isn't injectable on `now`,
  so the test mirrors its clock source instead.

- **Idempotency is asserted via call COUNTS on the fake, not just return value.**
  The retry case returns `compliant:true` whether or not it re-wrote — so the
  real assertions are `setClaimsCallCount === 0`, `setWrites.length === 0`,
  `auditRows.length === 0`. Counting side effects on the injected fake is how you
  prove a no-op, not the response envelope.

- **Rethrow-path test asserts the returned value stayed `undefined`.** For "must
  not proceed as admitted when deleteUser throws", catch the throw AND assert the
  pre-initialised `returned` sentinel is still `undefined` — proves the function
  never reached a `return { compliant: ... }` before throwing. Catching alone
  wouldn't distinguish "threw" from "returned then a later line threw".

- **Fail-closed test = inject a transaction error, assert it throws.** For
  `enforceIpAuditCap`, the FinOps contract is "a Firestore error denies, never
  resolves." Fake `runTransaction` rejects when `txError` is set; the test asserts
  the cap rethrows as `resource-exhausted`. The function's own `logger.error` line
  prints during this case — that's expected output, not a failure.

- **Logger ERROR/INFO lines interleave with PASS output.** The rejection-delete
  and fail-closed cases legitimately emit `logger.error`; the harness has no
  logger-silencing seam (unlike `ocr-validation.test.ts`). Don't mistake those
  structured-log lines for test failures — the trailing `N/N passed` is the
  source of truth.

### 2026-06-27 — BUT-1386 verify-signup-age production-side review [Pattern discovered]

Reviewed the callable + DI core + IP cap before commit. Implementation is sound;
no Critical, no High. Notes worth keeping for the next account-callable:

- **Region is inherited, not pinned per-function.** `verify-signup-age.ts` sets no
  `region` in its `onCall` options — it relies on `setGlobalOptions({ region:
  "europe-west1" })` in `index.ts`. That is the correct house pattern (the client
  uses `instanceFor(region: 'europe-west1')`, which matches). Do NOT add a
  per-function region; the global option already covers it, and a per-function
  override would be redundant noise. Verified the export at `index.ts:74` and the
  global option at `index.ts:25`.

- **Write-ordering rationale (claim → birthYear → audit) is correct and the
  fail-window is benign.** If `setCustomUserClaims` succeeds but the birthYear
  `set()` then fails, the function throws `internal` and the client retries; the
  retry hits the idempotent no-op branch (`existingClaims.ageCompliant === true`)
  and returns success WITHOUT ever writing birthYear or the audit row. That is a
  latent gap (claim set, birthYear never stored, no consent audit) but: (a) the
  birthYear writes are a single `Promise.all` that rarely partially fails, (b) the
  gate (claim) is the safety-critical artifact and it IS set, (c) worst case is a
  compliant user missing their stored birthYear, not a minor getting through. Rated
  Low, not High — the ordering deliberately favors "never able-to-post without a
  recorded-age decision" over "never claim-without-birthYear". If this is ever
  tightened, the fix is to re-check birthYear-doc presence in the idempotent branch,
  not to reorder.

- **Consent audit retention wiring verified end-to-end.** `writeComplianceAudit`
  writes `operation: "consent_age_verification"` + `timestamp: serverTimestamp()`.
  `audit_logs/purge-expired.ts` matches consent via `op.startsWith("consent_")`
  (CONSENT_OPERATION_PREFIX) → 730-day retention, and queries `where("timestamp",
  "<", cutoff)`. Field name and prefix both line up — the 730-day claim in the ADR
  holds. The rejection audit (`operation: "age_verification_rejected"`, no prefix)
  correctly falls into the 180-day general bucket and carries no identifier.

- **Rejection audit is written BEFORE `deleteUser` and has no dedup.** A bot that
  passes the per-IP cap (≤5/h) and the per-user bucket could in principle write up
  to 5 rejection rows/hour/IP. That is exactly the cost-bound the IP cap exists to
  enforce, so it's working as designed — the rows are intentionally non-identifying
  and cheap. Not a finding; recording so a future reviewer doesn't re-flag it as a
  "missing idempotency guard" — these rows are deliberately NOT deduped (each
  blocked attempt is a distinct event for the security record).

- **IP cap fail-closed is correct for an account gate** (unlike the notification
  gates which fail-OPEN per the 2026-04-30 entry). The distinction: notification
  gates fail-open because muting all pushes during an infra blip is worse than a few
  extra sends; an age/abuse gate fails-closed because admitting an unverified signup
  during a blip is the worse outcome. Both are right for their domain — don't
  "harmonize" them.

- **`request.rawRequest?.ip` can be a proxy/load-balancer IP.** The per-IP cap keys
  on `request.rawRequest?.ip ?? "unknown"`. Behind Google's front-end this is
  usually the real client IP, but if it ever resolves to a shared egress the cap
  buckets many users together (false positives) — and the `"unknown"` fallback
  buckets ALL ip-less callers into one key. Acceptable for a signup-once flow at
  beta scale; flag if abuse patterns suggest the key needs `X-Forwarded-For`
  parsing. Low.

### 2026-06-28 — BUT-1404 audit-log general purge starvation fix [Bug fixed]

`audit_logs/purge-expired.ts` — `purgeAuditCategoryWithDb` for the "general"
category fetched the oldest 10k docs with `where('timestamp','<',cutoff).limit(10000)`
then filtered consent rows client-side. As the collection aged, consent rows
(730d retention) filled that unfiltered 10k window, leaving expired general
rows (180d) unpurged — GDPR Art 5(1)(c) data-minimisation breach + unbounded
cost. The `truncated` flag was also computed from the post-filter deleted count
(never ≥ 10k for general after filtering), so real truncation was invisible.

**Fix (Path A)**: server-side filter via `CONSENT_OPERATIONS` array +
`where('operation', 'in'/'not-in', CONSENT_OPERATIONS)` before the timestamp
range and limit. Admin SDK 13.8.0 supports multi-inequality queries (operation
`in`/`not-in` + timestamp `<`); confirmed by zero TS errors at build.

**Discriminant**: the `operation` field present on every audit_log write. The
consent set is bounded: 4 values (`consent_age_verification`, `consent_granted`,
`consent_updated`, `consent_revoked`), all prefixed `consent_`. Firestore
`not-in` supports up to 10 values; current set is 4. If it exceeds 10, a new
`retentionTier` field + backfill would be needed (ops-blocked).

**Index added**: composite `(operation ASC, timestamp ASC)` on `audit_logs`
in `firestore.indexes.json` — required for `in`/`not-in` + range on a
different field. This IS a genuine composite (range + in/not-in across two
fields); not an equality-only case.

**truncated flag**: after the fix, `snapshot.docs.length` == number deleted
(no client-side filtering), so `deleted >= maxDocs` correctly reflects
server-side truncation.

**Test change**: `makeFakeDb` rewritten to support the new two-`where` chain
(`operation in/not-in` + `timestamp <` + `limit`). Two new test cases:
- `generalPurgeNotStarvedByConsentRows` — the starvation scenario: window of
  10 slots filled by consent rows + 1 expired general doc → general doc IS
  deleted (would have returned 0 with old code).
- `consentOperationsArrayIsExhaustive` — pins the 4 known consent op values
  against `CONSENT_OPERATIONS` so a new consent op without a list update
  turns red immediately.

**Patterns worth remembering**:
- **Unfiltered `limit` + client-side filter = starvation.** Whenever a purge
  fetches a bounded window and post-filters, a long-lived category will
  crowd out the short-lived one. Always push the category discriminant into
  the server-side query so `limit` applies to the right set.
- **`CONSENT_OPERATIONS` exhaustiveness guard belongs in the test, not in
  code.** The write path is in multiple files; a closed enum in a `.ts` const
  array + a test that pins the known values is the cheapest guard against
  list drift. If the list grows past 10, that test also fails (Firestore
  `not-in` max).
- **Multi-inequality in Admin SDK 13+ works** — `operation not-in` (treated
  internally as a range filter) + `timestamp <` on a different field is
  supported without needing to restructure the query or add a discriminant
  field at write time.

### 2026-06-28 — BUT-1392 CF tests wired into CI [Pattern discovered]

Added the Cloud Functions unit-test CI gate (`cloud-functions-unit.yml`).
Findings and patterns for future reference:

**5 test files had no npm script** (run-all-tests.js auto-discovers `test:*`
so missing scripts = missing coverage with no error):
- `acquisition-rules.test.ts` — emulator-bound rules test; got `test:rules:acquisition`
  and was added to `test:rules:all`. NOT added to DI-seam auto-discovery (prefix
  `test:rules:` is excluded by the runner).
- `log-parse-event-domain.test.ts` — DI-seam unit; got `test:log-parse-event-domain`.
- `rate-limiter-refill.test.ts` — DI-seam unit; got `test:rate-limiter-refill`.
- `validate-limit.test.ts` — DI-seam unit; got `test:validate-limit`.
- `winback-context.test.ts` — DI-seam unit; got `test:winback-context`.

**Two config gaps in `firestore-rules.yml`**: the path filter lists for both
`pull_request` and `push` were missing 7 test files that ARE in `test:rules:all`
(`realtime-menus-rules`, `friend-categories-rules`, `members-collection-group-rules`,
`friends-accept-rules`, `recipe-ratings-rules`, `accept-friend-request.integration`,
`on-report-created.integration`) plus `acquisition-rules.test.ts`. All added.
Also added `functions/src/social/**` path trigger (was missing; `social/` changes
could affect friends-accept and on-report-created without triggering the rules CI).

**Two pre-existing broken suites excluded from the new CI gate** — MUST NOT be
included in `cloud-functions-unit.yml` or the gate is red on day 1:

1. `test:app-check-enforcement` — `verifySignupAge` (BUT-1386) and
   `acceptFriendRequest` (B1 commit) are new `onCall` exports but were never
   added to the test's `USER_FACING` or `ADMIN_EXEMPT` classification sets.
   Fix: add both to `USER_FACING` (both are user-callable, not admin-only).

2. `test:request-account-deletion` — `deleteUserSubcollections` in
   `account/account-deletion-cascade.ts` gained a
   `.orderBy(FieldPath.documentId()).startAt(...).endAt(...)` chain in BUT-1390
   (commit 08e04be29). The unit test's `makeFakeDb.makeCollection` fake does not
   stub `orderBy()`, so the chain blows up and the `user_subcollections` step
   shows as failed. Fix: add `orderBy() { return this; }` to the query stub in
   the test file.

Both failures confirmed pre-existing on main (neither file appears in `git diff`).
Documented in `functions/scripts/run-ci-unit-tests.js` with fix instructions.

**CI job shape** (`cloud-functions-unit.yml`): Node 22, `npm ci` → `npm run build`
→ `node scripts/run-ci-unit-tests.js`. No Java/emulator needed. Triggers on any
`functions/src/**` change. 51/51 suites, ~108s locally.

**Distinction between the two runners**:
- `run-all-tests.js` — developer tool, runs ALL discovered suites including the
  two broken ones. Intent: "see everything, decide what to fix". 49 suites (53
  discovered minus the 4 new ones that just got added = 53 total now).
- `run-ci-unit-tests.js` — CI tool, excludes 2 known-broken suites. 51/51 green.
  Remove a suite from `CI_EXCLUDE` once it's fixed locally and confirmed green.

Pattern: whenever a new `onCall` export is added, immediately update the
`USER_FACING` or `ADMIN_EXEMPT` set in `app-check-enforcement.test.ts`. Forgetting
this is the source of the test:app-check-enforcement failure.

### 2026-06-28 — BUT-1423 post-deploy smoke gate in deploy-firebase.yml [Pattern discovered]

Added a post-deploy presence-check step to `.github/workflows/deploy-firebase.yml`
(runs after the Deploy step, before the Summary). Fires only when `DEPLOY_TARGET`
is `functions` or `all`.

**Mechanism**: `firebase functions:list --project butlery-app-1 --json` queries
the Cloud Functions control plane and returns the deployed function manifest.
A bash loop checks that 8 representative function names appear as quoted tokens
in that JSON output. Any missing name exits 1 and fails the workflow with a
`::error::` annotation.

**Why `firebase functions:list --json` and substring grep**:
- The `--json` flag gives a stable machine-readable format.
- `grep -qF '"functionName"'` (fixed-string literal match) is simple, no JSON
  parser needed, and is robust to minor field-order changes across firebase-tools
  versions.
- The function name appears in the `"name"` resource path and/or as an `"id"`
  field; either occurrence makes the grep succeed.

**8 representative functions chosen** (span all major families, stable long-term):
`structureRecipe`, `ocrRecipeImage` (LLM callables), `sendNotification`
(notifications), `onUserDeleted` (GDPR cascade), `verifySignupAge` (age-gate),
`requestAccountDeletion` (account), `cleanupExpiredCache` (cleanup scheduler),
`drainRatingAggregations` (rating scheduler). Migration-lifecycle-bound functions
(e.g. `backfillRecipeCommentsDenorm`) are deliberately excluded — they may be
removed and a false-fail would block future deploys.

**Fail-safe contract**: the step has NO error suppression. If `firebase
functions:list` itself errors (auth failure, network blip, CLI bug), `set -euo
pipefail` propagates the non-zero exit. Better a false-fail (redeploy to
investigate) than a silent pass over a broken function fleet.

**Auth**: no new secrets. `GOOGLE_APPLICATION_CREDENTIALS` is set by the
Authenticate step earlier in the same job; the `env:` block in the new step
passes it through.

**Lesson**: `firebase deploy` exiting 0 does NOT guarantee all functions are
callable. A bad runtime-config or build artifact can leave individual functions
in `DEPLOY_FAILED` state on the backend. The only way to detect that in CI is
a separate control-plane query after deploy.

### 2026-06-29 — Phase 5 item 15 family-data deletion: retry-handle ordering hazard [Pattern discovered]

`deleteFamilyData(db, uid)` in `account-deletion-cascade.ts` cascades family
data per shared household with two branches (sole member → teardown; others
remain → membership scrub + re-home + proxy scrub). Field names all verified
against the Dart models (`HouseholdMember.userId`, `FamilyRating.memberId`/
`enteredByUid`/`householdId`, `DinerProfile.createdBy`). All compound queries
are equality-only (`householdId==` + `memberId==`/`createdBy==`/`enteredByUid==`)
→ no composite index needed (accepted-deviations: equality merges on
single-field indexes).

**The hazard (general, reusable):** in a cascade step that is keyed off a
**shared/parent handle** rather than off `uid`, you must perform the
destructive mutation that *destroys the retry handle* LAST — after all
dependent child cleanup has committed. Otherwise a transient mid-step failure
strands orphans that a whole-cascade retry can no longer reach.

Two manifestations in this function:
1. **Remaining-members branch** does `hhDoc.ref.update({ memberUserIds:
   arrayRemove(uid), ... })` BEFORE re-homing diner profiles and scrubbing
   proxy attribution. The top-level re-entry query is `households where
   memberUserIds array-contains uid`. Once the arrayRemove commits, a retry
   no longer matches the household, so an orphaned child profile
   (`createdBy == deletedUid`) or un-scrubbed proxy verdict is never fixed —
   yet `auth.deleteUser` still runs at the end. Fix: reorder so the household
   membership scrub is the LAST mutation in the branch.
2. **Sole-member branch** deletes children via `batchDeleteAll` (which is
   `commitInChunks` with `strict:false` — swallows commit errors) and then
   `hhDoc.ref.delete()` unconditionally. If a child chunk fails, the error is
   swallowed and the household doc — the only handle to re-derive `hid` — is
   deleted anyway. Residual `diner_profiles`/`family_ratings` with that
   `householdId` are unreachable on retry. Fix: in the teardown, delete child
   docs with `strict:true` (or otherwise confirm child commits succeeded)
   before deleting the household doc; a thrown error then marks `family_data`
   failed and leaves `uid` in `memberUserIds` so the retry re-matches.

**Why this matters here specifically:** every OTHER cascade step queries by
`where(<field>, "==", uid)`, so residuals are always re-discoverable on retry
regardless of partial failure. Family data is the first step keyed on a parent
(`householdId`) whose handle the step itself destroys — breaking the cascade's
stated invariant ("every step ... safe to re-run if the caller retries after a
partial failure"). When adding cascade steps, check: *is the retry query keyed
on uid, or on a parent I'm about to delete/mutate?*

Severity rated High (orphan under retry + GDPR incompleteness; happy path is
correct, requires a transient mid-step failure). The 5 integration tests cover
happy-path branches but none injects a mid-step failure + re-run, so the
ordering regression is untested.

### 2026-06-29 — family-data storage-limitation sweep [Pattern discovered]

`functions/src/family/purge-dormant-family-data.ts` —
`purgeDormantFamilyData`, weekly `onSchedule` ("30 3 * * 0", UTC, 300s),
inherits europe-west1 from `setGlobalOptions`. Core
`runDormantFamilyPurge(db, now)` test seam exercised by emulator integration
test `__tests__/purge-dormant-family-data.integration.test.ts`
(`npm run test:integration:family-data-purge`, NOT in `test:rules:all` — needs
emulator). GDPR Art. 5(1)(e): a household whose family data
(`diner_profiles` + `family_ratings`) is dormant 24mo is warned, then purged
unless reactivated. Household doc + accounts are NOT deleted.

**New function family**: `family/` — household-scoped family-rating feature CFs.

| Path | Concern | Trigger | Test |
|---|---|---|---|
| `family/` | Household-scoped retention/aggregation; GDPR storage-limitation; idempotent warn→purge | scheduled + (aggregation triggers) | `test:integration:family-data-purge`, `test:integration:family-rating-aggregation` |

**Patterns worth remembering**:

- **Warn-before-purge two-pass is the GDPR-safe shape for any auto-deletion of
  user data.** Pass 1 stamps `familyDataPurgeScheduledAt = now + grace` + writes
  an in-app warning; pass 2 only deletes once `now >= scheduledAt`. The purge
  branch is structurally unreachable on the pass that first detects dormancy
  (it requires the schedule field to already exist). Reactivation clears the
  schedule. Never auto-delete user data on first eligibility — always a recorded
  warning + grace window first.

- **Dormancy = max of parent + all children timestamps, computed by reading the
  children, not an `orderBy limit(1)` probe.** For SMALL per-parent child counts
  (a household has a handful of diners/ratings) reading all children to compute
  the newest timestamp is correct: the docs are needed for the delete anyway, and
  `orderBy("lastUpdatedAt","desc").limit(1)` would force a composite index per
  collection for no real saving. Only switch to the indexed probe when per-parent
  child counts grow large.

- **`.limit(N).get()` on the top-level scan is "bounded but NOT paginating".**
  This sweep reads `households` with `.limit(200)` and no cursor — so beyond 200
  households the rest are silently never processed that run, and without an
  `orderBy` the scanned subset can shift between runs. Not a crash and purge
  correctness holds for those scanned, but it starves the overflow of any
  dormancy processing → defeats the storage-limitation guarantee. Flagged
  Medium (latent; fine at beta scale). Fix = the `__name__`-cursor loop already
  in `shared/batch-update.ts:batchUpdateQueryPaginated`. Rule: a "bounded"
  comment is not pagination; if the collection is unbounded, use a cursor loop.

- **`commitInChunks(db, docs, (b,d)=>b.delete(d.ref), { strict: true })` is the
  right primitive for a must-be-complete delete.** strict:true re-throws on any
  chunk failure, aborting BEFORE the parent stamp write, so the scheduler retries
  and you never get a silent partial purge of regulated data. Stamp the parent
  (`familyDataPurgedAt`) only AFTER the children commit succeeds.

- **System/self in-app warnings**: `warnMembers` writes `user_notifications`
  with `senderId == recipient uid` (self-notification). Best-effort (per-member
  try/catch, warn-logged, never blocks the schedule stamp). Watch that the
  notification-render path doesn't show a confusing "from yourself" sender.

- **Test seam shape holds**: `runX(db, now)` plain async + one-line `onSchedule`
  delegate, same as the analytics CFs. Integration test injects a fixed `now`
  and seeds one household per branch. Gap noted in this review: the
  reactivation-clears-schedule and empty-children-clears-stale-schedule branches
  (both have side effects) are not yet asserted.

### 2026-06-29 — BUT-1427 digest decoupled from reEngagement category [Bug fixed]

The weekly activity-digest push (`analytics/send-activity-digest.ts`) was passing
category `"reEngagement"` to `sendPushToUserRespectingPreferences`, so a user who
opted out of win-back pings silently lost their digest too — two distinct lifecycle
channels (retention summary for active users vs. win-back for lapsed users) collapsed
into one toggle. Fix added a dedicated `"digest"` member to the `NotificationCategory`
union in `shared/preference-aware-push.ts`, gated default-on, and switched the digest
scheduler to pass `"digest"`. Reviewed clean — no Critical/High; 6/6 test, tsc clean.

**Patterns worth remembering / confirmed this review:**

- **Default-on for a NEW category must be unconditional `return true` on a missing
  field — no fallback to a sibling category's stored value.** The `reEngagement`
  branch falls back to `categorySettings["NotificationCategory.system"]` because that
  is the pre-existing client-side toggle it maps to. `digest` correctly does NOT
  borrow any sibling boolean: there is no pre-existing client toggle for it, so any
  borrowed value would mean "a user who set some *other* category controls digest."
  A brand-new server-side category whose field predates no client UI must read only
  its own optional boolean and default-on otherwise. This is the no-silent-mute
  guarantee: prefs docs written before BUT-1427 have no `digest` field → enabled.

- **Push category gate is independent of `evaluateSendGate`.** The digest scheduler
  runs `evaluateSendGate({ notificationType: "activity_digest" })` (importance +
  quiet-hours + RC suppression + send-event) BEFORE the preference-aware push, and
  that gate keys off `notificationType`, not the push `category` literal. The
  category change touches only the `isCategoryAllowed` opt-out check inside the
  helper. `notification-importance.ts` still lists `"activity_digest"` (unchanged) —
  the two gates are orthogonal and both correctly still fire. Don't conflate the
  analytics `notificationType` string with the preference `category` literal: they
  are separate taxonomies that happen to both describe "digest."

- **Adding a union member is safe for other callers only because every other call
  site passes a string literal, not a variable.** `detect-lapsed-users.ts`,
  `send-notification.ts`, and `deliver-scheduled-notifications.ts` all pass the
  literal `"reEngagement"`; widening the union to `"reEngagement" | "digest"` cannot
  break them (a literal is still assignable). If any caller had passed a
  `NotificationCategory`-typed variable through a switch, widening the union would
  have demanded a new branch — `tsc` would have caught it via exhaustiveness only if
  the switch returned the union type. Here the trailing `return true` makes
  `isCategoryAllowed` total, so an unhandled future category fails OPEN (sends),
  which is the right default for a notification gate but worth knowing: a typo'd
  category silently sends rather than erroring.

- **Per-frequency vs per-channel are two separate opt-outs and must both be checked
  at the right layer.** `digestFrequency !== "never"` (does the user want digests at
  all, and how often) is enforced in the scheduler upstream; the `digest` boolean
  (is the push *channel* allowed right now) is enforced in the helper. Don't try to
  fold frequency into the category gate — the scheduler already filtered the
  user set before the push fan-out, and the helper has no frequency context.

### 2026-06-30 — BUT-1396 follow-up: realtime_recipes deletion keyed on the wrong owner field [Bug fixed]

`deleteRealtimeRecipes` (in `account-deletion-cascade.ts`, Tier 1) queried
`realtime_recipes` with `.where("userId", "==", uid)`. That collection has **no
`userId` field** — the authoritative owner field is `ownerId`:
- the Flutter model serializes `ownerId` (`lib/models/realtime/realtime_recipe.dart:327/408`),
- the Firestore rule gates read/delete on `resource.data.ownerId`
  (`firestore.rules` ~909-923; only the owner may delete).
So the filter matched **zero docs** — a deleted user's collaborative recipes were
exported under Art. 15 but never erased under Art. 17 (right-to-erasure leak). Fix
(already applied): filter on `ownerId`. Verified the step is wired into the
orchestrator at `request-account-deletion.ts:209` (Tier 1, parallel) — a fix to an
unwired function would be moot.

Cross-checks done (worth repeating for any "wrong filter field" cascade bug):
- **Other writers of the same collection**: `admin/reset-user-data.ts` deletes
  `realtime_recipes` via a collection *registry* (recursive/whole-collection delete),
  NOT a `userId` filter, so nothing depended on the old field.
- **Owner vs participant**: deletion must key on the OWNER, never on
  `participantIds`. A collaborator deleting their account must not erase someone
  else's recipe (and the rule only lets the owner delete anyway). The regression
  test pins this with a `rt-participant` fixture (TARGET is a participant on OTHER's
  recipe → must survive).

**Regression test added** to the emulator-backed
`request-account-deletion.integration.test.ts` (now 42 tests): 3 `realtime_recipes`
fixtures — `rt-own` (ownerId==TARGET → deleted), `rt-control` (ownerId==OTHER →
survives), `rt-participant` (TARGET only a participant → survives). Proved the test
is a real guard, not a tautology: temporarily reverting the SUT to the buggy
`userId` filter turns exactly the owned-deleted assertion RED (41/42), restoring
`ownerId` returns 42/42.

**Patterns worth remembering**:
- **"Wrong filter field" cascade bugs are silent and asymmetric.** An over-broad
  filter deletes too much (loud — control docs vanish); a wrong-field filter
  deletes *nothing* (silent — the negative-only "control survives" assertions still
  pass). A GDPR-deletion test MUST include a POSITIVE "owned doc is gone" assertion,
  not just "control survives" — only the positive one catches a no-op filter.
- **Prove the test bites.** For a regression test against an already-applied fix,
  flip the SUT back to the bug for one run and confirm the new assertion goes red.
  Cheap, and it's the only thing that distinguishes a real guard from a green
  tautology.
- **Cross-check the owner field across all three layers** when a cascade filters by
  identity: the Flutter model's `toFirestore` key, the Firestore rule's
  `resource.data.<field>`, and any sibling deleter (admin reset, export). The export
  side already filtered on `ownerId`; "export ⊇ erased" requires the SAME field on
  both — a mismatch is the tell.
- **Emulator workflow**: `bash .claude/hooks/ensure-firestore-emulator.sh` starts a
  local Firestore emulator on 127.0.0.1:8080 (needs firebase-cli + java, both
  present in this env); then
  `npx ts-node src/__tests__/request-account-deletion.integration.test.ts`. The test
  self-clears its namespace via the emulator REST DELETE endpoint before/after.

### 2026-06-30 — BUT-1450 residual-probe field scoping for notification analytics [Pattern discovered]

`probeResidualData` in `account/account-deletion-cascade.ts` (the post-cascade
"did anything survive?" sweep) was extended to cover the notification-analytics
collections that `deleteNotificationAnalytics` erases. Reviewed clean; build
clean; 42/42 deletion-cascade integration tests pass against the live emulator.

**The probe MUST mirror the deleter's field scoping, collection by collection.**
`deleteNotificationAnalytics` erases on these exact fields:
- `notification_history` / `notification_batches` / `notification_engagement` → `userId == uid`
- `notification_delivery` → `senderId == uid` AND `targetUserId == uid` (two queries, unioned)

The change reflects that split correctly: the first three go in the `userId`-scoped
`probes` array (the existing `count().where("userId","==",uid)` loop); `notification_delivery`
gets its OWN loop over `["senderId","targetUserId"]`. Putting `notification_delivery`
in the userId array would silently `count()` zero — the exact `realtime_recipes`/`ownerId`
wrong-field trap from BUT-1396 (a deleter/probe filtering the wrong field passes green
while leaving Art.17 data behind). So the probe now catches a silent delete failure for
each of the five collections, not just three.

**Patterns worth remembering**:
- **A residual probe is only as good as its field alignment with the deleter.** When
  reviewing a new probe, open the matching `delete*` function and diff the `.where()`
  field per collection. A probe on the wrong field is worse than no probe — it reports
  "clean" while data persists.
- **`count()` is the right primitive for residual probes** (vs `limit(1).get()` used for
  the feature-retention "did it ever happen" flags): here we want the actual surviving
  doc count in the warn log for ops triage, and `count()` is a single aggregation read.
- **The probe never aborts the cascade** — preserved. Both loops swallow errors into
  `logger.error` and bump `residual += 1` on probe failure (fail-toward-flagging:
  a probe that itself errors is treated as "possible residual" so `residual_data_detected`
  still trips). The only side effect is appending `"residual_data_detected"` to
  `result.failedCollections`; nothing throws, no retry storm.
- **Accepted Low — self-notification double-count.** A `notification_delivery` doc with
  `senderId == uid` AND `targetUserId == uid` (user notified themselves) is counted twice
  across the two probe queries, inflating the residual total. Harmless: `residual` is a
  trip-the-flag signal, not an exact figure, and the deleter's `batchDeleteAll` dedups by
  doc ref anyway. Not worth a `Set<docId>` dedup pass on a once-per-deletion sweep.
- **Coverage gap noted, not a blocker.** Neither `request-account-deletion.test.ts` (unit)
  nor the integration suite asserts `probeResidualData` behaviour directly — the integration
  run exercises it only incidentally (ends "cascade: completed with no failed collections").
  A targeted probe test (seed a residual `notification_delivery.senderId` doc, assert
  `residual_data_detected` trips) would lock the field scoping against future drift; left
  for the owning ticket.

### 2026-07-01 — BUT-674 minor default-private profile in verifySignupAge [Pattern discovered]

`verify-signup-age.ts` gained `AGE_OF_MAJORITY_YEARS = 18` and a derived
`isMinor = compliant && age < 18` threaded into `writeComplianceArtifacts`. The
`users/{uid}` merge-set now writes `{ birthYear, isMinor }`, plus
`isSearchable: false` ONLY when `isMinor` — the default-private profile for
15–17-year-olds. Reviewed clean, no findings.

**Why the derivation can't mislabel:** the non-compliant branch (`!compliant`)
returns after `writeRejectionAudit` + `auth.deleteUser` BEFORE any artifact
write, so `isMinor` is only ever read for compliant users. `compliant &&` is
therefore belt-and-suspenders — the value is meaningful by construction.

**Why the `isSearchable:false` write is retry-safe** (confirmed Malin's reasoning):
- The CF runs only during onboarding, before the profile privacy toggle is
  reachable in the client, so it can never clobber a later minor opt-in.
- Both call sites (first-pass + BUT-1435 idempotent-retry branch) thread the
  same `isMinor`, and the write is a `merge:true` set of the same value — a
  retry re-writing `isSearchable:false` is a no-op in effect, harmless.
- Adults get `isMinor:false` and NO `isSearchable` key (the field is only added
  to the write object `if (isMinor)`), so an adult's `isSearchable` default —
  which lives in `UserProfile` — is never touched by this CF.

**Test pattern:** the existing `makeFakeDb` already captures every `doc().set()`
into `setWrites[{path,data,merge}]`, so asserting the new fields needed no fake
changes — just `find(w => w.path === users/${uid})` and inspect `.data`. Added
3 BUT-674 cases (adult isMinor:false + no isSearchable across [1990, exactly-18];
minor isMinor:true + isSearchable:false across ages 15/16/17; idempotent-retry
minor still writes both). Full suite 10/10, tsc clean. Run:
`npm run test:verify-signup-age`.

**Age boundary note:** Jan-1 (year-subtraction) cutoff means age is conservative
— someone turning 18 later this year is still `isMinor:true` until Jan 1. That's
the safe direction for a protection default (over-protect, never under-protect);
matches the same conservative cutoff the ≥15 gate already uses.

### 2026-07-01 — BUT-674 post-review: `isSearchable` write removed, `isMinor` mirrored to prefs [User correction]

SUPERSEDES the `isSearchable:false` half of the 2026-06 BUT-674 entry above.
A security review changed `writeComplianceArtifacts` in
`functions/src/account/verify-signup-age.ts`. The `isSearchable:false` write to
`users/{uid}` was **DEAD** — user search reads `public_profiles.isSearchable`,
not the root user doc — so it was removed entirely (search-suppression deferred
to a follow-up that threads `isMinor` through onboarding profile creation +
the searchable opt-in + a group-DM CF). New behavior:

- `users/{uid}` (root) now gets `{ birthYear, isMinor }`. `isMinor` here is
  **load-bearing**: `firestore.rules` reads it via `get()` to gate 1:1 DMs to a
  minor. Root doc is owner/admin-read only, not loaded into the client profile.
- `users/{uid}/settings/preferences` now gets `{ birthYear, isMinor }` (was just
  `birthYear`). The client hydrates its `UserProfile` from this **private** doc,
  so this mirror is how the app learns `isMinor` for analytics minimization —
  without it the client's `isMinor` is always false and minimization is inert.
- NO `isSearchable` is written by the CF anywhere anymore.

**Lesson — verify the *consumer* of a field before trusting a "private default"
write.** The old entry rationalized `isSearchable:false` as retry-safe (true) but
never checked that anything *reads* it at that path. It didn't — the client reads
`isSearchable` off `public_profiles`. A write nobody reads is dead code that looks
correct in every unit test (the fake db happily records it). When a CF writes a
"protection default", trace the read path in the client/rules, not just the write.

**Test update:** the 3 BUT-674 cases previously asserted `isSearchable:false` on
`users/{uid}` — now wrong. Updated to: adult → `isMinor:false` on BOTH docs + no
`isSearchable` anywhere; minor(15/16/17) → `isMinor:true` on BOTH docs + no
`isSearchable`; minor retry → still writes `isMinor:true` to both, no
`isSearchable`. The `makeFakeDb` `setWrites[{path,data,merge}]` capture already
records per-path, so asserting the `settings/preferences` write separately is a
`find(w => w.path === users/${uid}/settings/preferences)`. Every remaining
`isSearchable` reference in the test is now a **negative** assertion
(`setWrites.every(w => !("isSearchable" in w.data))`). Suite 10/10, tsc clean.

### 2026-07-02 — BUT-684 handwritten-recipe OCR prompt variant [Pattern discovered]

Added a second OCR system prompt for handwritten recipe cards, selected at
call time. Files: `gemini-client.ts` (new `IMAGE_OCR_HANDWRITTEN_SYSTEM_PROMPT`
const + `PROMPT_VERSION` 2.1.0→2.2.0), `PROMPT_CHANGELOG.md` (v2.2.0 entry),
`prompts-config.ts` (new `imageOcrHandwrittenSystemPrompt` field mirrored
end-to-end), `ocr-recipe-image.ts` (new `isHandwritten?: boolean` request flag +
selection), new test `ocr-handwritten-prompt.test.ts` + `test:ocr-handwritten`
script. Client toggle is a separate follow-on.

**Param shape for the client**: `ocrRecipeImage` request gains
`isHandwritten?: boolean` (default false). `true` → handwritten prompt; absent/
false → printed prompt, byte-for-byte unchanged.

**Patterns worth remembering**:

- **Adding a NEW `*_SYSTEM_PROMPT` const trips the prompt-changelog CI guard.**
  `prompt-changelog-guard.ts` keys on the `_SYSTEM_PROMPT` substring on any
  +/- diff line, so a new prompt constant REQUIRES a `PROMPT_CHANGELOG.md`
  entry in the same change or the gate fails. Bump `PROMPT_VERSION` too (the
  bundle changed) — MINOR for an additive new prompt. The guard's unit tests
  use synthetic diffs, so they stay green regardless.

- **Mirroring a Firestore-backed prompt field = 5 edit sites in
  `prompts-config.ts`**: the doc-shape docstring, the `PromptsConfig`
  interface, `buildFallback()`, the `requiredStringKeys` array, and the
  `validateRemoteDoc()` return literal. Miss any one and either the field is
  silently absent (missing from return) or never validated.

- **Adding a REQUIRED key is a breaking change to any live `system/prompts`
  override doc.** Because validation is all-or-nothing (BUT-621), an existing
  override doc that predates the new field now fails validation and the WHOLE
  bundle reverts to compiled-in fallback until an operator adds the field.
  The *prompt string sent* for the printed path is unchanged (fallback ==
  current compiled-in const), but the reported `source`/`promptVersion` flips
  to fallback. Operator action item: add `imageOcrHandwrittenSystemPrompt` to
  the prod doc. This also breaks any existing prompts-config test fixture
  (`validRemoteDoc()`) — it must gain the new field or the firestore-source
  cases fail. Audit test fixtures whenever you add a required key.

- **A/B bucket vs prompt selection are orthogonal in the OCR handler.**
  `resolvePromptBucket()` only tags analytics (`experimentBucket`/
  `promptVariant` on the timing log); it does NOT swap the prompt string. So
  the handwritten selection (`isHandwritten ? handwritten : printed`) sits
  independently and both keep working — bucket is still computed + logged for
  both paths.

- **Unit-testing `runOcrRecipeImage` without an initialized admin app**: the
  handler has no seam for `getPromptsConfig` or `captureLlmSample`. Both call
  `admin.firestore()`. `getPromptsConfig` catches the `app/no-app` throw and
  falls back to compiled-in prompts (deterministic — the selected prompt then
  equals the imported const). `captureLlmSample` throws its default-arg
  `admin.firestore()` eagerly AFTER `performOcr` runs, surfacing as an internal
  HttpsError. To test prompt SELECTION, capture `args.systemPrompt` inside the
  `performOcr` seam (runs first) and wrap the call in try/catch — the assertion
  is on the captured value, not the return. Same limitation already affects the
  `ocr-validation.test.ts` accepted-URL integration case.

### 2026-07-02 — BUT-684 handwritten-OCR prompt: adding a required prompts-config key breaks OTHER test fixtures [Bug fixed]

BUT-684 added `imageOcrHandwrittenSystemPrompt` as a **required** key in
`validateRemoteDoc()`'s `requiredKeys` list (all-or-nothing validation, same
rationale as BUT-621). The author correctly updated the fixture in
`prompts-config.test.ts` (`validRemoteDoc()`) — but a second module,
`prompt-ab-bucket.test.ts`, builds its OWN inline `system/prompts` doc fixtures
in THREE places (the "promptVariants populated / absent / malformed" cases) and
none were updated. Effect after the change:

- The **"populated"** case asserts `source === "firestore"` → now **FAILS**
  (`expected source=firestore, got fallback`) because its doc lacks the new
  required key, so the whole bundle reverts to compiled-in fallback.
- The **"absent"** and **"malformed variants"** cases only assert
  `promptVariants === undefined` → they still pass, but **for the wrong reason**:
  the fallback bundle happens to have no `promptVariants`, so they no longer
  exercise the firestore validation path they were written to test (silently
  vacuous).

Fix: add `imageOcrHandwrittenSystemPrompt: "handwritten ocr prompt"` to all
three doc literals in `prompt-ab-bucket.test.ts` (the fixtures at the
`imageOcrSystemPrompt: "ocr prompt"` lines), mirroring the staged
`prompts-config.test.ts` update.

**Pattern worth remembering — grep ALL fixtures when adding a required key.**
The `requiredKeys` list in `prompts-config.ts` is validated against every inline
`system/prompts` doc any test constructs. Adding a key there silently invalidates
every hand-rolled fixture that omits it. Before committing a new required prompt
field, run `grep -rn "imageOcrSystemPrompt:" src/__tests__/*.ts` (any always-present
sibling key works as the anchor) and add the new field to each hit. Watch for the
insidious variant: a fixture-turned-fallback whose assertion still passes because
it only checks something the fallback bundle also satisfies — green but no longer
testing the intended path.

**BUT-684 review verdict (rest clean):** printed path is byte-for-byte unchanged
when `isHandwritten` is falsy (ternary defaults to `prompts.imageOcrSystemPrompt`;
only added a `handwritten=false` log field). Handwritten prompt keeps the same
`${INJECTION_DEFENSE}` prefix + `${SWEDISH_MEASUREMENTS}` suffix and the same
"valid JSON som matchar schemat" contract (schema is enforced downstream by
`structureRecipe` regardless). A/B `resolvePromptBucket` is still computed and
logged for both paths — the variant is metadata only and never overrode the
system-prompt string, so bucketing/kill-switch/App-Check/rate-limit/PII-scrub are
untouched. No region change, no new trigger, no idempotency surface. PROMPT_VERSION
2.1.0→2.2.0 with changelog "(current)" marker moved — `prompt-changelog-guard`
passes.

**Deploy dependency (documented, not a defect):** because the new key is required,
a live `system/prompts` override doc that predates this field will fail validation
on deploy and revert the WHOLE bundle to compiled-in fallback until an operator
adds `imageOcrHandwrittenSystemPrompt`. The PRINTED fallback (`buildFallback()`
uses the unchanged compiled-in `IMAGE_OCR_SYSTEM_PROMPT`) is identical to what
shipped, so there is NO behaviour change **unless** an operator had hot-fixed a
prompt in Firestore that diverges from compiled-in — in which case all five
prompts silently revert. Coordinate: add the field to the live override doc as
part of the deploy, not after. Reporting-only change otherwise (`source` flips to
`fallback`, `promptVersion` reports 2.2.0).

### 2026-07-02 — BUT-684 follow-up: handwritten prompt made OPTIONAL, not required [User correction]

A /code-review flagged the required-key design from the entry above as a deploy
footgun and it was corrected. **Superseding guidance:** a NEW Firestore-backed
prompt field must be OPTIONAL with per-field fallback, NOT added to
`requiredStringKeys`.

Why required was wrong: the config validation is all-or-nothing (BUT-621). Any
EXISTING production `system/prompts` override doc — valid under the prior 6
keys — would fail validation the moment the 7th key became required, silently
reverting EVERY prompt (extraction, enhancement, printed OCR, spoken,
ingredient) to compiled-in defaults and losing all operator tuning until
someone hand-edits the prod doc. That's a data-loss-of-tuning event triggered
purely by deploying code, gated on a manual prod-doc edit.

The fix in `validateRemoteDoc()`:
- Keep `requiredStringKeys` at the original 6 (do NOT add the new key).
- In the return, default the new field per-field:
  `typeof raw.x === "string" && raw.x.trim() ? raw.x : COMPILED_IN_CONST`.
- A doc lacking the field still validates as `source: "firestore"`, keeps all
  its other overrides, and the new field gracefully falls back. Removes the
  deploy dependency entirely.

**General rule for this codebase:** all-or-nothing bundle validation means
"required key" == "breaking change to every existing override doc". Reserve
required status for keys present since the doc's inception. Every ADDED key
should be optional + per-field fallback. This contradicts the instinct (from
the original 5 prompts) that "all prompts are required for version integrity" —
that instinct only holds for the original shape, never for additions.

Test to pin it: a fixture doc WITHOUT the new key must assert
`source === "firestore"` AND that a sibling override (e.g. `imageOcrSystemPrompt`)
survives AND the new field equals the compiled-in const. See
`ocr-handwritten-prompt.test.ts` case [6]. (The field-present fixtures in
`prompts-config.test.ts` / `prompt-ab-bucket` are now harmless either way.)

### 2026-07-02 — sync-ingredients.ts review: warnings invisible by default [Pattern discovered]

Reviewed the generic-'seafood' validation warning added to
`functions/src/admin/sync-ingredients.ts` (`validateIngredient`). Two
findings worth remembering about this admin/ script:

1. **`validateAllIngredients` only counts warnings under `--verbose`.**
   `warningCount += result.warnings.length` sits INSIDE
   `if (result.warnings.length > 0 && verbose)`, so a default (non-verbose)
   run reports 0 warnings and the "N warnings (use --verbose to see)" hint
   never prints (guarded by `warningCount > 0`). Any warning added to
   `validateIngredient` is therefore INVISIBLE on the standard
   `npm run sync-ingredients:dry-run` invocation. When adding warnings,
   also move the counting outside the verbose guard (gate only the
   per-row printing) or the warning is dead code in practice.

2. **The script is a non-testable monolith by design**: module scope runs
   `admin.initializeApp()` + `main()` executes on import, so
   `validateIngredient` can't be imported into the hand-rolled test harness
   without refactoring (extract validators to a side-effect-free module).
   Consistent with the admin/ family's "test: n/a" row — pinning validation
   warnings is optional here; if warnings ever gate real decisions, extract
   first.

Client-side contract behind the seafood warning (verified in
`lib/services/tagging/`): skaldjur allergen trigger is
`crustacean OR mollusc OR seafood` via plain `hasAnyProperty` OR-logic
(`tag_phase1_allergen.dart` → `getCombinedPropertyStatus`). So ANY row
carrying 'seafood' yields skaldjur CONTAINS — adding a detail property
(fish/crustacean/mollusc) does NOT clear it (deliberate false-CONTAINS
safety net, allergen_config.dart comment 2026-07-01); the detail property's
real value is making the SPECIFIC allergen (fisk/kräftdjur/blötdjur)
detectable. Sync-time warning messages should say that, not imply the
skaldjur verdict flips.

### 2026-07-03 — pooled-ratings v1 server key twin (canonical-pool-key.ts) [Pattern discovered]

New family `ratings/` (pure helper for now). `computePoolKey(title, ingredients)`
is the SERVER AUTHORITY for the pooled-ratings recipe-identity key and must be a
byte-identical twin of the Dart `lib/services/rating/canonical_pool_key.dart`.
Parity is gated by the shared fixture `test/fixtures/pool_key_parity.json` (read by
both `functions/src/__tests__/pool-key-parity.test.ts` and the Dart test). Reviewed
2026-07-03: 11/11 parity, faithful twin, no correctness-breaking divergence found.

**Cross-language parity checklist (reusable for any TS↔Dart twin):**
- **Dart RegExp follows ECMAScript non-Unicode semantics.** With no `unicode:true`
  (Dart) / no `u` flag (JS), `\w`/`\b` are ASCII-only in BOTH, and `\s` matches the
  same set. This is why "fold å/ä/ö→a/o FIRST, then strip single-letter units with
  `\b(l|g|...)\b`" works identically in both — the string is ASCII by the time the
  boundary regex runs. Add `unicode`/`u` to only one side and this breaks.
- **Default string sort is UTF-16 code-unit ordinal in BOTH.** Dart `List<String>
  ..sort()` (→ `String.compareTo`) and JS `Array.sort()` with no comparator both
  compare by UTF-16 code units (shorter-prefix-first). They agree even for non-ASCII
  BMP + surrogate pairs. Safe to rely on — but only because neither passes a
  locale-aware comparator.
- **Dedup order is irrelevant when you sort after.** `set().toList()..sort()` (Dart
  LinkedHashSet insertion order) vs `Array.from(new Set()).sort()` (JS insertion
  order) — the trailing sort makes insertion order moot. Good pattern; don't remove
  the sort thinking Set order is stable across languages.
- **`String.split(' ')` is literal in both** (only JS `split('')`/regex-split and
  Python `split()`-no-arg are special). Consecutive spaces → empty tokens in both;
  `''.split(' ')` → `['']` in both.
- **Anchored `^` regex: Dart `replaceAll` == JS non-global `.replace`.** `^`
  (non-multiline) matches only index 0, so replaceAll does exactly one replacement,
  same as a non-global `.replace`. No `g` flag needed on TS `leadingNumbersRe`/
  `leadingDigitsRe`.
- **sha256 hex is lowercase in both** (`Digest.toString()` / `.digest('hex')`);
  `utf8.encode` == `.update(raw,'utf8')`. `.substring(0,16)` identical.

**Footguns flagged (not bugs today):**
- **Module-level `/g` regexes are safe with `.replace` but NOT with `.test()`/
  `.exec()`.** canonical-pool-key.ts only uses `.replace` on its global regexes, so
  no `lastIndex` statefulness bug. If a future edit calls `.test()`/`.exec()` on any
  module-scope `/g` regex, `lastIndex` persists across invocations (CF isolates are
  long-lived) → intermittent wrong results. Keep global regexes to `.replace`, or
  make them local.
- **Input validation belongs in the calling CF, not the helper.** `computePoolKey`
  guards `!ingredients`/empty but does `title.toLowerCase()` and `raw.toLowerCase()`
  on array elements unconditionally. A Firestore doc with a non-string title or a
  non-string element in the ingredients array throws a `TypeError`; inside a Firestore
  trigger that's an uncaught exception → retry storm. The aggregation CF MUST coerce/
  validate (`typeof === 'string'`) and fail-closed (skip / null) before calling.
- **C5 word-list drift.** INGREDIENT_UNITS / TITLE_STOP_WORDS / APPROXIMATE_WORDS /
  DISH_QUALIFIERS / GENERIC_ANCHORS are hand-duplicated from the Dart twin. Verified
  in sync 2026-07-03, but nothing mechanically prevents a one-sided edit. Both files
  already flag the C5 follow-up (share via one JSON asset or CI byte-diff). Highest-
  value guard: the parity fixture only exercises lists indirectly — a shared asset or
  byte-diff CI is the real fix.

**Fixture gaps worth closing (proposed, not divergences):** all-caps input (locks
`toLowerCase()` parity + `gi` unit regex), >12 unique ingredients (locks sort-then-
`take(12)` boundary — the single most divergence-prone construct), and ingredients
that fold to the same name across mixed case (locks Set dedup after folding).

### 2026-07-03 — C5 word-list drift guard CLOSED [Pattern discovered]

The predicted C5 fix (above) shipped. Reviewed the TS side clean.

- `canonical-pool-key.ts` now `export`s the five word-list consts
  (`INGREDIENT_UNITS`, `TITLE_STOP_WORDS`, `APPROXIMATE_WORDS`,
  `DISH_QUALIFIERS`, `GENERIC_ANCHORS`). No algorithm change; regex build +
  `Set.has` usage unchanged. `noUnusedLocals` still satisfied (all consumed
  in-module).
- New `__tests__/pool-key-wordlist-parity.test.ts` — same hand-rolled,
  `process.exit(1)`-on-fail, `run()`-at-top-level style as the C4
  `pool-key-parity.test.ts`. Reads repo-root `test/fixtures/pool_key_wordlists.json`
  (`__dirname/../../../test/fixtures/...`), compares each list IN ORDER. The Dart
  twin pins the same JSON, so a one-sided edit reddens one of the two suites.
- `package.json` adds `test:parity:poolkey-wordlists`; auto-discovered by
  `scripts/run-all-tests.js` (`test:*` minus `test:rules*`/`test:integration:*`).
  Confirmed the prefix filter admits it.

**Patterns worth remembering:**

- **Native consts + CI parity test, NOT runtime JSON load — deliberate and
  correct.** `tsc` does not copy `.json` under `src/` into `functions/lib` on
  build, so a runtime `import`/`readFileSync` of the fixture would crash the
  deployed function. Keeping the lists as compiled-in consts keeps the pool key
  synchronous and dependency-free; drift is caught at CI time by the two parity
  suites instead of at runtime. Do NOT "improve" this into a runtime shared-asset
  load — that reintroduces a deploy-bundle-missing-file crash. (Decision 2: this
  TS module is the pool-key SERVER AUTHORITY.)

- **Set→Array insertion order is a sound parity basis.** ECMAScript guarantees
  Set iteration in insertion order, so `Array.from(set)`/`[...set]` reproduce the
  literal declaration order; Dart's default `Set` (`LinkedHashSet`) is likewise
  insertion-ordered. Ordered comparison is meaningful for BOTH: the array lists
  (`INGREDIENT_UNITS`, `APPROXIMATE_WORDS`) are joined into a regex alternation
  where order is load-bearing; the Set lists compare by order too, harmlessly
  (membership is what the algorithm uses, but ordered compare is stricter and free).

- **Exporting pure-data consts has zero cold-start / isolate cost.** The consts
  were already instantiated at module load; adding `export` changes nothing the
  deployed entry loads (the test file is never `require`d from `index.ts`). No
  admin-init import-poison either — the module builds only regexes + `createHash`
  at load, no `admin.firestore()`. One theoretical Low: exported arrays/Sets are
  mutable references (not `Object.freeze`d), but the only importer is a read-only
  test, and internal consumers could already mutate pre-export — so no new risk.

- **`src/__tests__/*` compiles into `functions/lib` (tsconfig `include: ["src"]`).**
  Pre-existing convention for every parity/rules suite; slightly bloats the deploy
  artifact but costs nothing at cold start (unreferenced modules aren't loaded).
  Not introduced by this change — do not flag.
