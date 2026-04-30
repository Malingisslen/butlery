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
