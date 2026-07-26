# cloud-functions-specialist — archived patterns (pre-2026-06-04, relocated 2026-07-04). Append-only historical record; the live agent reads the main file + consults this when an index line below is relevant.

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


## Relocated 2026-07-04 — consolidation batch (entries 2026-06-09 → 2026-06-26; durable lessons distilled into the active file's principles section)

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

--- relocated 2026-07-16 ---

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

### 2026-07-03 — pooled-ratings Increment 1: debounce-queue generalization [Pattern discovered]

`functions/src/shared/debounce-queue.ts` (NEW, generic core) +
`functions/src/ratings/rating-aggregation.ts` (now a thin adapter). Decision 5
of `tasks/pooled-ratings-plan.md`: the pool aggregator REUSES this generic
coalesce+claim-by-delete module instead of forking a second copy. Reviewed
CLEAN — 5/5 BUT-482 tests pass unmodified, tsc clean, index.ts untouched.

**Field-rename across a Cloud Functions deploy is transition-safe ONLY when the
value equals the doc ID.** The marker's internal field was renamed
`recipeId`→`key`, and the drain reads `data?.key ?? doc.id`. This is safe in
BOTH deploy-window directions because `debounceMarkerRef` writes markers at
`{markerCollection}/{key}` — the doc ID IS the key, always:
- OLD writer (`recipeId` field) → NEW drain: `data?.key` undefined → `doc.id`. ✓
- NEW writer (`key` field) → OLD drain still deployed: `data?.recipeId`
  undefined → `doc.id`. ✓
No stranded/duplicated/lost markers. `pendingUntil`/`scheduledAt` field names
are unchanged, so coalescing works regardless of which version wrote a marker
in flight at deploy time. **General rule: a doc-field rename in a marker/queue
collection is a free deploy ONLY if every reader falls back to `doc.id` and the
doc ID equals the renamed value. Otherwise you need a two-phase deploy
(read-both, then write-new).**

**Coincidental test proof of the transition:** the two drain seed-tests
(`drainerProcessesReadyMarkers`, `drainerSurvivesAggregatorFailure`) still seed
markers with the OLD field name `recipeId:` and drain correctly via the doc.id
fallback — so the existing suite already exercises the deploy-transition path
without modification. Worth preserving when the pool aggregator's own tests land.

**Log-field rename (`recipeId`→`key`) verified low-risk:** the structured-log
FIELD changed but the event NAMES are preserved (`rating_aggregation.scheduled`
/`.skipped`/`.failed`, plus `.drain_complete` in index.ts which never carried a
recipeId). Grep found NO in-repo dashboards/alerts/log-based-metric configs
(no `monitoring/`, `*.tf`, alert yaml) filtering on `jsonPayload.recipeId`.
Caveat I CANNOT verify from code: alert policies / log-based metrics created
directly in the GCP Cloud Console. Any alert keyed on the event NAME (normal
pattern) is unaffected; only one filtering on the `recipeId` value would need a
one-line edit. Not a blocker — flagged to user as the single unverifiable point.

**Adapter mapping is correct:** `drainRatingAggregationQueue({aggregate})` maps
`drain: deps.aggregate`; both are `(string) => Promise<void>`. index.ts calls
`drainRatingAggregationQueue({ aggregate: updateRecipeRatingStats })` unchanged.
The adapter re-exports `ScheduleDeps` from the shared module and defines its own
`DrainDeps` (keeps the `aggregate` name for API stability). Public API
(`scheduleRatingAggregation`/`drainRatingAggregationQueue`/`__test__`) identical.

**When the pool aggregator (`canonical-rating-aggregation.ts`) lands**, its
`DebounceConfig` should use `markerCollection: "_internal/pool_debounce/markers"`
(already named in the shared module's docstring) and a distinct `logPrefix`
(`pool_aggregation`) so the two queues never share markers and their logs stay
separable. The generic drain default THROWS if no `drain` is wired — the pool
drainer's `onSchedule` must pass its aggregator, same as
`drainRatingAggregations` in index.ts.

### 2026-07-03 — Finding D: cross-prompt-family instruction gap (schema-shared prompts) [Pattern discovered]

Review of a prompt-only change in `gemini-client.ts`. The ingredient-group rule
("Deg:"/"Fyllning:" → `section=` per ingredient, NEVER emit the heading as its
own ingredient) lived ONLY in `RECIPE_EXTRACTION_SYSTEM_PROMPT` (text path).
The OCR, handwritten, and spoken prompts all share `RECIPE_SCHEMA`, where a bare
`name:"Deg"` is structurally valid — so a grouped recipe photographed/transcribed
could emit a phantom heading row that the text path would not. Fix extracted a
shared `INGREDIENT_GROUP_RULE` const and interpolated it into all four prompts.

**The reusable lesson: when N prompts share ONE responseSchema, a behavioural
instruction added to only one of them is a latent gap for the other N−1.** The
schema constrains structure, not semantics — anything the schema permits but you
don't want must be forbidden in *every* prompt that uses that schema, not just
the one you happened to edit. Grep the schema constant's usages before assuming a
per-prompt instruction is sufficient. Prefer a shared const over copy-paste so
the four prompts can't drift.

**Verification I ran (all clean):**
- **Byte-identical text prompt:** the `INGREDIENT_GROUP_RULE` value equals the
  old literal line verbatim (leading `- ` included); the template now interpolates
  `${INGREDIENT_GROUP_RULE}` on its own line → rendered text unchanged. Confirm
  this char-for-char, not by eyeballing — a dropped leading `- ` would silently
  reword the text prompt.
- **MINOR bump correct:** `INGREDIENT_SCHEMA`/`RECIPE_SCHEMA` untouched (the
  `section` field shipped in v3.0.0); this change is additive instruction only,
  same schema, same client parser → 3.0.0→3.1.0 MINOR is right. (v3.0.0 was MAJOR
  because it changed the schema + parser.)
- **INJECTION_DEFENSE still leads all four prompts** (`${INJECTION_DEFENSE}` is
  the first token of each template literal) — the rule was inserted mid-body,
  not before the security prefix.
- **Deploy-note keys are real override keys:** `prompts-config.ts` reads
  `imageOcrSystemPrompt`, `imageOcrHandwrittenSystemPrompt`, and
  `spokenContentSystemPrompt`. Nuance worth remembering: the three text/OCR/spoken
  keys are in the all-or-nothing `REQUIRED_FIELDS` set, but
  `imageOcrHandwrittenSystemPrompt` is OPTIONAL with a **per-field** fallback
  (BUT-684). So if prod `system/prompts` overrides a required key with a stale
  value (missing the rule), that stale value serves until the doc is updated in
  the same deploy; if prod simply lacks the handwritten key, the compiled fallback
  (which now carries the rule) serves. The changelog deploy note captures this.
- **No allergen risk:** `section` text stays on each ingredient object, never in
  the flat allergen-tagged ingredient list, so this can't ground a false
  "fritt från X" verdict. A phantom "Deg" row is junk, not a safety issue → LOW.

### 2026-07-03 — pooled-ratings Increment 2: Stage A mirror CF review [Pattern discovered]

Reviewed the NEW `ratings/canonical-rating-aggregation.ts` (core
`mirrorRatingToPool`), `ratings/pooled-ratings-flag.ts` (fail-CLOSED RC kill
switch), the `onRecipeRatingWrittenForPool` `onDocumentWritten` trigger in
index.ts, and the 11-case test suite. No Critical. Fail-closed flag + fail-closed
maturity gate + server-recomputed key are all correct. Followed the C4 knowledge
note exactly (coerces `core.title`/`core.ingredients` to string / string[] before
`computeKey`, so a malformed recipe doc can't throw a TypeError inside the
trigger). Two Medium + one Low below; all three are enhancement-shaped, not
blockers.

**Verified — recipe read location is correct (not a silent no-op).** The mirror
reads TOP-LEVEL `db.collection("recipes").doc(recipeId)`. The repo also has a
user-scoped personal library at `users/{uid}/recipes/{recipeId}` (that's what the
firestore-rules tests, `cleanup-recipe-storage.ts`, and `backfill-recipe-comments`
target), which made the correct location genuinely ambiguous. Confirmed top-level
is right because the LIVE Dart rating aggregate
(`lib/services/unified/operations/modules/rating_statistics.dart:180`) also writes
denormalized stats to `firestore.collection('recipes').doc(recipeId)` and
`batch.update(recipeRef)` — an update that would THROW if the top-level doc were
absent — so a top-level `recipes/{recipeId}` with `core.title`+`core.ingredients`
(also confirmed by `admin/bulk-retag.ts`) provably exists for every rated recipe.
`recipe_ratings.recipeId` therefore resolves against the top-level doc. **General
rule for this repo: `recipes/{id}` (top-level) is the rated/denormalized recipe;
`users/{uid}/recipes/{id}` is the personal library. Don't assume one from the
other — the rating pipeline keys off the top-level one.**

**MEDIUM (cost + consistency + latent semantic drift) — the mirror has NO
rating-change gate, unlike its sibling.** The existing `onRatingUpdated`
(index.ts:226) skips when `before.rating === after.rating`; the new
`onDocumentWritten` mirror reprocesses EVERY write. Two consequences:
1. Cost: any no-rating-change write to a `recipe_ratings` doc (review-text edit,
   `updatedAt` touch, client re-save) pays 1 billed recipe read + 1 event write
   that the social-stats path deliberately skips.
2. Latent correctness: the mirror always recomputes the key from CURRENT recipe
   content, so if the recipe was edited between the original rating and a later
   no-rating-change write, it files a NEW event at the new poolKey while the old
   event persists — a pool vote the user never actively cast. This is NOT the
   accepted "re-rate an edited dish → new vote" case (there the user re-rates);
   here an incidental write fabricates it. Remedy: in the trigger (or core), when
   `before && after && before.rating === after.rating && before.recipeId ===
   after.recipeId`, return a `skipped_unchanged` no-op — mirrors the sibling and
   kills both issues.

**MEDIUM (cost ordering) — maturity gate runs AFTER the billed recipe read.** The
order is validate → `recipes/{id}.get()` (billed) → `computeKey` → `isAccountMatured`
(`auth.getUser`, not billed per-call). The maturity gate exists to reject
throwaway-account spam, but a spam flood still pays one recipe read each before
rejection. Reorder to validate → maturity check → recipe read → key → write:
`getUser` is free, the recipe read is billed, so the free adversarial check should
gate the billed read. Pure win — normal ratings do the same total work reordered.

**LOW (Stage-B forward-looking) — `createdAt: serverTimestamp()` is rewritten on
every upsert.** A CF retry, or any re-processing of the same vote, shifts
`createdAt` to the reprocess time despite the "frozen" framing in the docstring.
Harmless today (Stage B doesn't exist), but if Increment 3 uses `createdAt` for
recency weighting or first-vote tie-breaking it will drift. Decide deliberately in
Increment 3: keep last-write semantics (rename to `updatedAt`) or preserve
first-create (transaction/`create`-then-`update`, or merge-if-absent).

**Boundary note (hand-off, not a finding):** the mirror trusts
`recipe_ratings.recipeId` and reads whatever recipe it names. The guarantee that a
user may only create a `recipe_ratings` doc for a recipe they're allowed to rate
lives in `firestore.rules` — that's `firestore-rules-tester`'s surface, not this
CF's. The CF's own poisoning defense (never trust a client-written key; recompute
from content) is intact and tested (AC2).

**Idempotency confirmed solid:** upsert = `set()` at doc-ID=poolKey (retry-safe);
delete = query-by-`recipeId` + delete (retry → `delete_noop`); the recipeId-keyed
delete correctly cleans up the multi-event case from the edit-then-rerate path.
`onDocumentWritten` create/update/delete branches all handled; both-absent guarded
in index.ts. Throw-on-error → CF retry is safe because the only mutation is the
final idempotent write.

### 2026-07-03 — [User correction] The 2026-07-03 pooled-ratings review above was WRONG on 3 counts — an xhigh multi-agent review caught a showstopper I cleared
I reviewed the Increment-2 pooled-ratings mirror CF and reported it "clean of
Critical/High." A subsequent `/code-review xhigh` (6 finders + 13 verifiers) found
**12 verified issues**, including a **showstopper I explicitly endorsed as correct**.
Corrections to the entry directly above — supersede it with these:
1. **Recipe content is USER-SCOPED, not top-level.** I asserted `recipes/{recipeId}`
   (top-level) was correct, citing a Dart write at `rating_statistics.dart:180`. WRONG.
   Recipes live at `users/{ownerUid}/recipes/{recipeId}` — `firestore.rules` has ONLY
   the nested `match /users/{userId}/recipes/{recipeId}` (line ~337, no top-level
   `match /recipes`), `FirebaseRecipeRepository` mixes in `UserScopedFirebaseRepository`
   (see `lib/repositories/CLAUDE.md`), and `recipe_ratings` docs carry **no owner uid**
   (only `recipeId, userId, rating, review, createdAt, updatedAt`). A CF reading
   `db.collection("recipes").doc(id)` always misses → feature dead on arrival. The
   `bulk-retag.ts` / `getRetagStatus` admin functions ALSO use top-level
   `collection("recipes")` and are the trap that misled me — do not treat them as proof
   a top-level collection exists; they are unverified/legacy. **Lesson: to confirm a
   server-side collection path, read `firestore.rules` (the authoritative layout) + the
   repository's mixin, NOT an incidental `collection(name)` call elsewhere.**
2. **`throw` does NOT retry by default.** firebase-functions v2 event triggers
   (`onDocumentWritten` et al.) have `retry=false` by default — a thrown error is logged
   and DROPPED, not redelivered. Must pass `{ retry: true }` in the trigger options for
   "throw → retry" to hold. I called the throw-to-retry design "safe" without checking.
3. **A test that seeds the same wrong path as the code cannot catch a path bug.** The 12
   unit tests passed only because the FakeFirestore seeded recipes at the same fake
   `recipes/{id}` path the code read. **Lesson: the fake must mirror the REAL collection
   layout (user-scoped subcollection), or a path bug is structurally invisible.**
Also confirmed-wrong from the entry above: the `recipeId`-keyed retraction does NOT
"correctly clean up" — when two copies of one dish collapse onto one poolKey doc it
deletes a still-live vote (or no-ops the wrong one). **Meta-lesson: on data-writing CFs,
the single-specialist gate is necessary but NOT sufficient — an adversarial multi-finder
review is warranted before commit.**

### 2026-07-03 — pooled-ratings Stage B pool aggregator (Increment 3) [Pattern discovered]

Reviewed clean (no findings) the Stage B aggregator that maintains the PUBLIC pooled
number `canonical_recipe_stats/{poolKey} = {count, average, updatedAt}`. Files:
`ratings/update-pooled-rating-stats.ts` (aggregator), `ratings/pool-aggregation.ts`
(debounce adapter), the `onPooledRatingEventWritten` trigger + `drainPooledRatingAggregations`
scheduler in `index.ts`, and a collection-group index in `firestore.indexes.json`.

**Patterns worth remembering:**

- **Unbounded collection-group fold → use `.aggregate({count, average})`, never `.get()`.**
  When a pool's rater count is unbounded by design, read-all-then-recompute is forbidden
  (memory + billed reads scale with pool size). The right shape is
  `db.collectionGroup(sub).where("poolKey","==",key).aggregate({ count:
  AggregateField.count(), average: AggregateField.average("ratingValue") }).get()` — both
  scalars computed in the index layer, O(1) memory, one billed read per ≤1000 matched
  entries. Confirmed `AggregateField.count/average/sum` all present in **firebase-admin
  13.8.0**. The test enforces the invariant by tripping a counter if anyone `.get()`s the
  raw collection-group query (fold tripwire) and asserting `foldGetCalls === 0`.

- **Collection-group equality query needs a fieldOverride COLLECTION_GROUP single-field
  index — NOT a composite, and NOT covered by the auto single-field index.** Firestore
  auto-creates single-field indexes at COLLECTION scope only; a `collectionGroup(...)`
  query with even a single equality filter needs an explicit `fieldOverrides` entry
  `{collectionGroup, fieldPath, indexes:[{order:"ASCENDING", queryScope:"COLLECTION_GROUP"}]}`.
  Without it the query (and its aggregate) throws `FAILED_PRECONDITION` in prod (emulator
  hides this). An aggregate query uses the SAME index as its underlying `where`; the
  averaged field (`ratingValue`) does not need indexing. This is distinct from the
  accepted-deviation "equality queries need no composite" — that rule is about COLLECTION
  scope; collection-GROUP scope still needs the explicit override.

- **count()/average() denominator parity depends on the producer validating the field.**
  `count()` counts every matched doc; `average(f)` only averages docs where `f` is numeric.
  If the producer could write an event missing/`null` `ratingValue`, the public average
  would be over a smaller denominator than count. Safe here because Stage A gates
  `typeof rating !== "number" || !Number.isFinite || <1 || >5` → `skipped_invalid`, so every
  event carries a finite [1,5] `ratingValue`. When reviewing any aggregate-average CF,
  verify the producer guarantees the averaged field or the two numbers silently diverge.

- **Debounce reuse via `DebounceConfig`, distinct marker namespace.** Stage B does NOT fork
  the claim-by-delete queue — it passes a `DebounceConfig` to the shared
  `shared/debounce-queue.ts` with `markerCollection: "_internal/pool_debounce/markers"`
  (rating aggregation uses `_internal/rating_debounce/markers` — no collision) and
  `logKeyField: "poolKey"`. This is the canonical way to add a second debounced aggregator:
  a thin adapter pinning namespace/config, never a second copy of the transaction logic.

- **retry:true on the event trigger only retries the cheap scheduling, not the recompute.**
  `onPooledRatingEventWritten` recovers `poolKey` from `event.params.poolKey` (works on
  delete — the wildcard doc-ID survives when the after-snapshot is gone) and does nothing
  but `schedulePoolAggregation` (an idempotent coalescing transaction). The actual
  recompute+upsert runs in the separate every-1-min drainer. So `retry:true` is safe (it
  re-runs an idempotent marker write); a drain failure self-heals on the next signal (the
  pre-existing, accepted debounce tradeoff). No trigger-loop risk: stats writes go to
  `canonical_recipe_stats` and markers to `_internal/...`, neither matching the trigger path.

- **Empty pool is zeroed (count 0 / average null), not deleted.** On last-event retraction /
  GDPR erasure the aggregate returns 0/null and that is written — the reader gates on n≥5 so
  a zeroed doc shows no pill (never a stale number). Leaves a negligible orphan zero-doc;
  accepted over an extra delete round-trip.

- **Per-minute drainer cadence is by parity with the sibling rating drainer, not a new
  cost.** `drainPooledRatingAggregations` runs `every 1 minutes` exactly like
  `drainRatingAggregations`. This nominally contradicts the "schedule hourly not per-minute"
  guidance, but it's the decided latency trade (0..60s pool freshness), the empty-scan cost
  is ~1 min-billed read per run (≈$0.016/mo), and the feature flag is OFF in prod so it
  rarely does real work pre-launch. Accepted.

### 2026-07-03 — pooled-ratings Incr 5: GDPR cascade of canonical_rating_events [Pattern discovered]

Reviewed the account-deletion wiring for the frozen pool events
(`functions/src/account/account-deletion-cascade.ts`). Clean — no findings. The pattern
worth remembering is the **two-shaped cleanup for one subcollection**:

- **Erase**: `canonical_rating_events` added to the `subs` array in
  `deleteUserSubcollections`. That loop is `userDoc.collection(name).get()` +
  `batchDeleteAll`, and `userDoc = db.collection("users").doc(uid)` — so it is inherently
  uid-scoped (no cross-user reach) and a cascade retry finds an empty snapshot (no-op). No
  separate function needed because it is a pure `users/{uid}/*` subcollection, unlike the
  top-level userId-scoped collections that get their own deleters.
- **Probe**: the residual check must be **subcollection-shaped**
  (`.doc(uid).collection("canonical_rating_events").count()`), NOT a top-level
  `where("userId","==",uid)` — the latter silently matches zero (the realtime_recipes
  wrong-field trap this codebase already hit). The added probe mirrors the existing probe
  structure (count query, `try/catch → residual += 1` on error, warn on count>0) and pushes
  `residual_data_detected` into `failedCollections`.

**Delete→recompute soundness (the load-bearing bit):** deleting each event fires
`onPooledRatingEventWritten` (an `onDocumentWritten`, so delete counts). The handler
recovers `poolKey` from `event.params` (after-snapshot is gone on delete) and schedules a
debounced recompute. The recompute (`updatePooledRatingStats`) is a collectionGroup
**aggregate** that writes `canonical_recipe_stats` — a *different* collection from
`canonical_rating_events` — so **no re-trigger / no infinite loop**. `set(merge)` from
source-of-truth makes it idempotent; `retry:true` is safe. Erasing a rater thus shrinks the
public averages they contributed to with no explicit recompute call — the established
Stage-A/Stage-B trigger separation carries GDPR erasure for free (bounded to the number of
distinct pools the user rated in; GDPR deletion is rare, so per-event trigger fan-out is an
accepted cost).

**Cost of the added probe:** one `count()` per account deletion (a rare op). count() bills
as reads in 1000-entry increments; a per-user subcollection is a handful → ~1 read.
Negligible, and consistent with every sibling probe.

**Test proof:** `request-account-deletion.integration.test.ts` seeds a TARGET event + an
OTHER control event. I-CRE1 asserts the target's event is gone (erasure), I-CRE2 asserts
OTHER's survives (uid-scope proof — the control lives under `users/OTHER/*` so it also can't
false-trip the TARGET-scoped residual probe), and I-CRE3 leans on I21
(`RESULT.failedCollections.length === 0`) so a surviving target event would have pushed
`residual_data_detected` and failed the run — residual-clean is doubly proven. 44/44 pass on
the emulator. This "own erased + other kept + envelope-clean" triple is the canonical shape
for any new GDPR-cascade subcollection test in this repo.

### 2026-07-04 — pooled-ratings backfill: no persisted cursor caps forward progress [Bug fixed / review finding]

Reviewed `migrations/backfill-canonical-ratings.ts` (decision 14, Increment F —
one-shot, HARD-GATED behind `enable_pooled_ratings`, never run in prod). It reuses
the live mirror's exported `isAccountMatured` + `recipeContentToKey` (the diff only
added `export` to those two — no body change, so the live mirror's behavior is
unchanged). Idempotency read + `batch.set` per event, 450 cap, ADR-0004 frozen
event shape. Clean on: server-recompute of poolKey (never trusts the rating doc's
client key — test 2 proves it), the maturity memo (monotonic ⇒ safe to memoize
`true`, immature never cached), the flag-refusal gate (real run only, dryRun
bypasses per AC10; `isPooledRatingsEnabled` throws on unreachable RC ⇒ fail-closed),
and no `WriteBatch` overflow (≤450 sets/commit).

**The real finding — inherited from `backfill-recipe-comments-denorm.ts`:** the
cursor `lastDocId` is a LOCAL variable, reset to null every invocation; nothing is
persisted across calls. `totalScanned` (vs `maxRatings`, default 10k) and
`batchesProcessed` (vs `MAX_BATCHES_PER_INVOCATION=23`, ≈10,350 docs) both count
**skipped-identical** docs. Consequence: a re-invoke always restarts from doc #1,
re-scans the already-mirrored head as `skippedIdentical` while the counters climb,
and short-circuits at the same ceiling — so **a corpus larger than ~10,350 ratings
can never fully backfill**; `hasMore` stays true forever and re-invoking is a no-op
loop over the head. The line-192 comment "the cursor lets a re-run resume" and the
runbook's "re-invoke while `hasMore` until false" are therefore inaccurate above
that ceiling. INERT at current beta scale (rating corpus << 10k), and at that scale
the transient-maturity-error → `HttpsError('unavailable')` re-run story IS safe
(re-scan from start + idempotent skip reliably reaches the previously-failing uid,
which sits within the first ceiling). Remediation for any future scale: persist
`lastDocId` to a cursor doc (e.g. `_migrations/backfill_canonical_ratings`) and
resume from it, OR don't count skipped-identical docs against the caps. Flagged
Medium (would be High if the corpus ever crosses ~10k before the file is deleted).

Two Lows recorded: (1) `createdAt` divergence — the backfill preserves the original
rating `Timestamp` (`data.createdAt ?? serverTimestamp()`) whereas the live mirror
always writes `serverTimestamp()`; the mirror explicitly DEFERRED the createdAt
semantics decision to Stage B (its own line 293-296 NOTE), so the two writers now
disagree — no reader today, but Stage B's eventual decision must account for both.
The `data.createdAt as Timestamp` cast is unchecked (harmless while recipe_ratings
writes a client serverTimestamp). (2) A corpus size exactly == `maxRatings` (or the
inner-break firing on the last real doc) reports `hasMore: true` perpetually —
cosmetic; the operator never sees the clean `hasMore: false`. Region/cold-start
conventions fine (europe-west1 pinned like the reference backfill; no new SDK).

### 2026-07-04 — pooled-ratings backfill: cursor + dedup rewrite VERIFIED CLEAN [Bug fixed]

Re-reviewed after the fix for the three findings above. All resolved; the four
boundary hazards I re-checked are sound. Keeping the reasoning so a future run
doesn't re-derive it.

- **Persisted cursor (the Medium).** `startAfter?` in/`nextCursor` out now thread
  the resume point through the caller (runbook: re-invoke with
  `{ startAfter: nextCursor }` until `hasMore` false). `maxRatings` is a
  PER-INVOCATION `totalScanned` ceiling (local, resets each call) — not a
  cumulative cap — so an arbitrarily large corpus completes across invocations.
  `hasMore` terminates: every invocation with `maxRatings ≥ 1` processes ≥1 doc
  (fresh `totalScanned` 0→1 ≤ ceiling on the first doc), so `lastProcessedId`
  strictly advances past `startAfter` each call; ends when `reachedEnd`
  (empty/short page). The `reachedEnd` flag correctly suppresses the spurious
  `hasMore` on an exact-`BATCH_SIZE`-multiple corpus (one extra empty query, then
  done) and on the exact `MAX_BATCHES`×`BATCH_SIZE` boundary (one extra
  invocation that returns empty).

- **Two-cursor split is the load-bearing correctness trick.** `lastDocId` = last
  FETCHED (drives the query `startAfter`); `lastProcessedId` = last actually
  PROCESSED (drives `nextCursor`). They diverge only on the `maxRatings` cutoff:
  the cutoff doc breaks BEFORE processing, so `lastProcessedId` stays at the prior
  doc and `nextCursor = lastProcessedId` re-fetches the cutoff doc + its
  unprocessed batch siblings next call → no skip. On the batch-ceiling exit they're
  equal (full batch processed) → no re-scan. Confirmed no gap and no double-process
  at either boundary.

- **`batchStartCursor` resume-after-throw is genuinely safe.** The batch's writes
  are collected in the `winners` map and committed in a SINGLE `batchWrites.commit()`
  AFTER the per-doc loop; the transient-maturity `HttpsError('unavailable')` throws
  INSIDE the loop, before that commit — so the current batch has ZERO committed
  writes, and resuming from `batchStartCursor` (= `lastDocId` at batch start, i.e.
  just past the prior COMMITTED batch) re-does exactly the uncommitted batch. No
  lost write, no double (the re-do is idempotent — see next).

- **Dedup winner is deterministic; re-runs converge (no oscillation).** Same-batch:
  ratings collapse into a `Map` keyed `${uid} ${poolKey}`, last-by-doc-id wins
  (iteration is `orderBy(documentId())` order), so the same-batch double-`set` that
  caused the old oscillation is gone — ONE idempotency-checked write per unique
  pool. The write is `batch.set` on a (uid,poolKey) doc-id (overwrite, NEVER
  increment), and the idempotency skip compares recipeId+ratingValue only
  (createdAt is deliberately NOT part of identity, so a Timestamp↔serverTimestamp
  flip can't defeat the skip). Test 10 proves the same-batch collision converges to
  the last-by-doc-id winner with a no-op second run. Cross-batch collision (the two
  colliding ratings ≥`BATCH_SIZE` apart) is NOT fully deduped — batch N writes copy-a,
  batch N+k overwrites with copy-b — but the FINAL committed value is invariant
  (global-max-doc-id winner) across runs, so it does not oscillate; the residual is
  one redundant overwrite per run, bounded to accepted-deviations edge #1 (rare
  self-own-copies-same-pool) — cost, not corruption. Not a finding.

- **`createdAt` cast fixed** — `data.createdAt instanceof admin.firestore.Timestamp
  ? … : serverTimestamp()` — a malformed field can no longer ride through as a bad
  cast.

**One residual Low (pre-existing, not introduced by this fix):** `runCanonicalRatingsBackfill`
does not clamp `maxRatings`, and the callable's `maxRatings = 10000` default only
fills `undefined`. A caller passing `maxRatings: 0` cutoffs on doc #1 with NOTHING
processed → `lastProcessedId` stays null → `nextCursor = lastProcessedId ?? lastDocId`
falls back to `lastDocId` (end of the fetched batch), so the next invocation
`startAfter`s PAST the whole unprocessed batch — silently skipping ratings while
still reporting `hasMore`. Only reachable via the absurd admin input `maxRatings:0`;
harmless at any sane value. Cheap guard: `const maxRatings = Math.max(1, options.maxRatings)`
at the top of the run fn (or clamp in the callable). Flagged, not blocking.

### 2026-07-02 — ingredient `section` field (PR #211, prompt v3.0.0) review [Pattern discovered]

Reviewed the chunk-3 CF diff adding nullable `section` to `INGREDIENT_SCHEMA` +
`ExtractedIngredient`, reworking the extraction prompt's group rule/EXEMPEL 4,
and capping `section` at 60 chars in `validateIngredient`. Clean except one
deploy-coordination finding. Patterns worth remembering:

- **Compiled-in prompt edits are INERT in prod while a valid `system/prompts`
  override doc is live (BUT-621).** `structure-recipe.ts` serves
  `prompts.recipeExtractionSystemPrompt` from Firestore when the doc validates;
  the new compiled-in v3.0.0 rule ("sätt section=...") never reaches the model
  until the operator updates the doc. Worse than inert here: the stale doc
  actively teaches the OLD flatten (`preparation="deg"`), so post-deploy the
  schema offers `section` but the prompt forbids using it — feature silently
  dead, `preparation` stays polluted, analytics reports the doc's
  `promptVersion` (not 3.0.0). **Any prompt-content change must ship with a
  matching prod `system/prompts` doc update (or verified doc absence) as an
  explicit deploy step.** Sibling of the BUT-684 required-key footgun but
  inverted: there the doc broke on deploy; here the doc silently wins.

- **Schema `description` is the only prompt surface shared by ALL callers of a
  schema.** `INGREDIENT_SCHEMA` feeds RECIPE_SCHEMA (extract + OCR printed +
  handwritten + spoken) AND INGREDIENT_LINES_SCHEMA. Putting the behavioural
  guidance ("never repeat group name in preparation / never emit heading as
  ingredient") in the field's `description` gives the OCR/spoken paths the
  rule without touching their prompts — and, unlike the prompts, the schema is
  compiled-in (NOT Firestore-overridable), so it deploys atomically.

- **responseSchema cannot enforce string length** — server-side
  `trim().slice(0, maxLen)` in the validator is the enforcement point for any
  bounded STRING field. Blank/whitespace → null BEFORE the cap so no phantom
  empty groups.

- **Widening `ExtractedIngredient` with a required TS field**: `tsc --noEmit`
  is the audit tool for literal construction sites (here: one, in
  `ocr-retry.test.ts`); `validateIngredient` is the single runtime constructor,
  so missing/non-string keys from old cached responses or pre-3.0.0 replays
  coerce to null — backward compatible by construction. Contract pinned in
  `__tests__/ingredient-section-schema.test.ts` (5 cases incl. a prompt-content
  guard asserting the old flatten wording is GONE).


### 2026-07-03 — BUT-1467 sync-ingredients core extraction + allergen lockstep triple [Pattern discovered]

`sync-ingredients.ts` (admin/, ts-node script) calls `admin.initializeApp()` +
`main()` at import time, so it can't be imported by tests. BUT-1467 extracted
the pure logic into `admin/sync-ingredients-core.ts` (csvToFirestore, diff,
mergePreservedFields, isResurrection, buildSyncReport) — the admin-script
analog of the `runX(deps)` seam. Tests: `__tests__/sync-ingredients-diff.test.ts`
(8 behavioral cases, `_unit-runner`).

**Allergen lockstep triple** (three lists that must stay aligned by hand):
1. `admin/sync-ingredients.ts` — `VALID_PROPERTIES` (NOT in `-core.ts`; the
   core file's docstring pointing there is a known drift hazard).
2. `shared/allergen-properties.ts` — `ALLERGEN_RELEVANT_PROPERTIES` (allergen
   block + fish/shellfish/seafood/dairy/egg). Feeds the sync diff report now,
   the BUT-1468 alias hold-for-review gate next.
3. `lib/services/tagging/config/allergen_config.dart` — client
   `triggerProperty` list. Includes non-medical verdict triggers
   (`contains-alcohol`, `meat`, `pork`, `beef`) that produce FREE/CONTAINS
   tags via the same machinery — decide explicitly whether a "wrong allergen
   verdict" gate covers them; as of BUT-1467 they are NOT in
   ALLERGEN_RELEVANT_PROPERTIES.

No automated drift pin exists between the three; when reviewing any of them,
re-diff all three by hand.


### 2026-07-03 — audit-event timing in confirm-gated admin scripts [Pattern discovered]

BUT-1467 review of `admin/sync-ingredients.ts`: the `system_events` ops-log row
(`type: "ingredient_sync"`, `executedAt`, counts) was written by
`persistSyncReport` BEFORE the `askConfirmation` prompt and before any batch
commit. Consequence: a run the operator cancels at the prompt, or one that
throws mid-batch, still leaves an ops-log row claiming the sync executed —
the audit trail over-claims, which defeats the feature's own purpose.

Rule for confirm-gated admin scripts: **the human-review artifact (JSON diff
report file) belongs BEFORE the confirmation prompt (the operator reviews it to
decide); the executed-marker Firestore row belongs AFTER the final commit.**
Split "persist report" into write-file (early) + log-event (post-commit) when
both live in one helper. Dry-run correctly skips the event row.

Related soft-delete+TTL patterns confirmed good in the same review:
- Resurrection routing depends on the Firestore fetch being UNFILTERED
  (`collection.get()` with no status filter) so soft-deleted docs land in
  `toUpdate` (status differs) rather than `toAdd` — the update path can then
  attach `FieldValue.delete()` clears for `deletedAt`/`expireAt`.
- Pre-existing (not introduced): `hasChanges` skips `aliasesEn`/`searchTerms`
  (edits to only those never sync), and sparse optional fields
  (`notesSv`, `typicalUnit`, `seasonAvailability`, …) omitted from an `update`
  payload are never DELETED when cleared in the Sheet — such rows churn as
  "updated" on every sync forever and now pollute the diff report.


### 2026-07-03 — BUT-1468 alias hold-for-review review [Pattern discovered]

Review of `analytics/analyze-corrections.ts` (maturity gate + allergen hold)
and new `analytics/review-learned-alias.ts` (admin approve/reject/revoke).

- **Server gate vs client matching normalization MUST agree.** The
  `allergen_alias_text` hold gate resolves the alias text via
  `findIngredientByName` (exact / lowercase / array-contains on stored
  diacritic forms), but the Dart consumer (`FirebaseIngredientRepository
  ._normalize`) matches learned aliases **diacritics-stripped** (å/ä→a, ö→o).
  So an ASCII-variant alias ("jordnotter") bypasses the server gate yet still
  matches the real allergen word ("jordnötter") client-side. General rule: any
  safety gate filtering strings the client will later match must run the SAME
  normalization as the client matcher, or match on a normalized-lookup field
  (e.g. stamp a `normalizedNames` array in the sync pipeline). Filed High.
- **Hold states need an allowlist status check, not a blocklist.** The old
  auto-approve guard was `status !== "approved"`; introducing
  `held_for_review`/`rejected`/`revoked` under that guard would have let the
  quorum re-approve them. The diff correctly flipped to
  `status === "pending"`. When adding a terminal/parked state to a txn state
  machine, audit every status conditional for blocklist shape.
- **Hold-reason computed outside the txn is acceptable** when (a) it needs
  queries, (b) its input (ingredient `properties`) changes only via rare
  admin/sync paths, and (c) the bad-direction outcome is recoverable via an
  admin revoke callable. Cheap hardening: the doc-read half (target's own
  properties) can be re-verified inside the txn with `tx.get(ingredientRef)`
  at the threshold moment; Admin SDK txns also support `tx.get(query)` if the
  query half ever needs to move inside.
- **`npm test` composite deliberately excludes `test:rules:*` and
  `test:integration:*`** (`scripts/run-all-tests.js` EXCLUDE_PREFIXES) —
  emulator-bound suites run manually. Don't file "new test not in the
  composite chain" for `test:integration:*` scripts.
- **Hoist per-event-constant reads out of per-candidate loops**: a correction
  event with N ingredient corrections ran `isMatureAccount` (1 user-doc read)
  N times for the same uid.
- **`learned_aliases` admin queries (`status ==` + `orderBy count desc`) have
  NO entry in `firestore.indexes.json`** — equality+orderBy needs a composite
  in prod (emulator auto-creates). Pre-existing for pending/approved; verify
  the console before relying on the new held_for_review queue surfacing.


### 2026-07-04 — best-effort telemetry must resolve `admin.firestore()` INSIDE the try [Bug fixed]

`captureLlmSample` (`llm/llm-sample-capture.ts`, BUT-1451) had a test-seam
default param `db: admin.firestore.Firestore = admin.firestore()`. Default
params are evaluated at **call time, BEFORE the function body's try/catch**, so
in any context with no initialized default app (DI-seam unit tests) or an
unreachable Firestore, `admin.firestore()` threw and the exception escaped the
"best-effort, never a failure surface for an import" catch — it bubbled up
through the awaiting OCR/structure-import callers and surfaced as an internal
`HttpsError`. This kept the "Cloud Functions Unit Tests" workflow red on `main`
for ~4 days (ocr-retry, kill-switch, ocr-validation, ocr-handwritten-prompt).

Fix: param → optional `dbOverride?: admin.firestore.Firestore`; resolve
`const db = dbOverride ?? admin.firestore();` as the FIRST line inside the try.
The missing-app/unreachable throw is now swallowed by the existing catch.

**Reviewed clean:**
- **Zero production behavior change** — prod always has an initialized app
  (`admin.initializeApp()` in `index.ts`), so `admin.firestore()` never threw
  there; the handle is SDK-memoized per app, so resolving it inside the try vs
  as a default has no cost/perf delta. Only the failure path changes.
- **Seam rename breaks no caller** — the only two prod callers
  (`ocr-recipe-image.ts:435`, `structure-recipe.ts:332`) pass no db (now safe).
  The standalone `llm-sample-capture.test.ts` passes db as the 2nd positional
  arg — unchanged position, just optional/renamed.
- **Idempotency N/A** — helper does `.add()` (auto-id, inherently non-idempotent
  duplicate on retry), but it's awaited best-effort telemetry that can never
  throw, and both callers are `onCall` callables (no server-side auto-retry).
  Not part of any retry-corruption story. The fix doesn't touch this.

**Pattern (reusable):** any best-effort / never-throw helper that takes a
`= admin.firestore()` (or any throwing expression) default param has a latent
escape hatch — the default is evaluated OUTSIDE the guard. Make the seam
`?:` optional and resolve `?? admin.firestore()` on the first line inside the
try. Same root cause as the 2026-06-10 `notification-rate-cap.ts` lazy
`admin.firestore()` note — a throwing SDK call in a "can't fail" path must sit
inside the catch, never at the boundary.

### 2026-07-07 — BUT-1495 comma-tolerant aliases_sv split reviewed clean [Pattern discovered]

`sync-ingredients-core.ts` `csvToFirestore` now splits `aliases_sv` on
`/[;,]/` (Sheet convention is ';' but humans type ','; a comma blob alias
poisoned `normalizedNames`, the diacritics-stripped allergen-lookup surface
the BUT-1468 server gate queries). 15/15 diff tests + tsc clean.

- **The change is safe against the CSV loader** because `parseCsvLine` in
  `sync-ingredients.ts` is quote-aware (Sheets quotes comma-containing cells)
  AND `loadCsv` fails closed (process.exit 1) on any column-count mismatch —
  an unquoted comma cell aborts the run instead of mis-aligning columns and
  soft-deleting rows. When widening any cell's separator handling, re-verify
  both properties of the loader.
- **Idempotency/retry/region/cost all N/A-clean for admin/ family**: the sync
  is a manual ts-node script (never deployed → no region pin, no cold-start);
  the transform is deterministic and the differ converges — docs healed on
  the first post-ship sync compare `unchanged` thereafter. Expect a ONE-TIME
  churn wave in the first diff report (every doc whose stored `aliasesSv`
  holds an old comma blob lands in `updated`) — that is the fix working,
  reviewable in the report, not a regression.
- **Residual asymmetry (Low, deliberate scope)**: `aliases_en` and
  `search_terms` still split on ';' only — a comma-typed list there survives
  as one blob entry. Lower stakes (neither feeds `normalizedNames` nor any
  allergen gate), but same human-error class; apply `/[;,]/` there if it
  recurs in the Sheet.

### 2026-07-07 — BUT-1477/1478/1479 daily LLM cap + parse_events TTL review [Pattern discovered]

Reviewed `middleware/rate_limiter.ts` (per-user daily cap), `events/log-parse-event.ts`
(`expireAt` TTL field), `llm/gemini-client.ts` (comment-only pricing verification),
plus the new `rate-limiter-daily-cap.test.ts`. Build clean, 6/6 tests green.
No Critical/High. Fixed two Mediums during the review (npm script + RUNBOOK entry).

- **The BUT-1392 silent-coverage trap struck again**: the new test file shipped
  without a `test:*` script in package.json, so `run-all-tests.js` / CI would
  never run it. Added `test:rate-limiter-daily-cap`. Checklist item for every
  review of a new `__tests__/*.test.ts`: grep package.json for the script FIRST.
- **A Firestore TTL field is inert without the TTL policy** — `expireAt` on
  `parse_events` enforces nothing until `gcloud firestore fields ttls update`
  is run (console ops step). Added the runbook section (`functions/RUNBOOK.md`,
  "parse_events TTL policy") with the exact gcloud command; it's a DEPLOY-DAY
  dependency for the GDPR Art. 5(1)(e) retention claim. Same audit applies to
  `llm_response_samples` (same pattern) — whenever a review sees a new
  `expireAt`-style field, demand the runbook entry, or the retention claim is
  documentation fiction.
- **Daily-cap design verified sound**: counter lives in the SAME doc + SAME
  transaction as the token bucket (no extra reads); denial is evaluated BEFORE
  token consumption (a capped request doesn't burn bucket tokens) and the deny
  path writes nothing (denials are free retries; cap counts allowed requests
  only). `dayKey` uses 0-based `getUTCMonth()` matching `checkGlobalLimit` —
  equality-only, never parsed back. Pre-BUT-1477 docs (no dayKey) read as a
  fresh day. Weekly cleanup (90-day `updatedAt` staleness) can't race the
  daily counter — an active user's doc is always fresh.
- **Pre-existing ordering wart, amplified (filed Low, not fixed)**:
  `withRateLimit` runs `checkGlobalLimit()` (which INCREMENTS the global
  hourly/daily counters) BEFORE the per-user check — so a denied user's retries
  inflate the global LLM budget without any LLM call. Was already true for
  minute-bucket denials; a daily-capped user extends the denied window to a
  whole day, so one hammering capped account can eat toward the 1000/h //
  10000/d global caps and starve everyone. Fix if it ever bites: check per-user
  first, or split checkGlobalLimit into check (read) and commit (increment
  after per-user allow). Left as-is: costs an extra read per request on the
  common path, and the master kill switch remains the emergency brake.
- **Transaction wiring of the cap is untested** (only the pure
  `evaluateDailyCap` seam has tests) — consistent with the house DI-seam
  pattern (`calculateCurrentTokens` likewise), noted as Low.

### 2026-07-07 — BUT-1571 decimal-comma-aware aliases_sv split reviewed clean [Pattern discovered]

`sync-ingredients-core.ts` `csvToFirestore`: the BUT-1495 split `/[;,]/` fragmented
Swedish decimal commas ("lättmjölk 0,5%" → "lättmjölk 0" + "5%"), poisoning
`normalizedNames` with junk. New split `/;|,(?!\d)/` treats a comma immediately
followed by a digit as a decimal comma, not a separator. 16/16 diff tests, tsc clean.

- **Normalization parity re-verified end-to-end for comma-bearing aliases** across
  the three matching surfaces: sync stamp (`stripDiacritics(lower.trim())`,
  `shared/swedish-normalize.ts`), server hold gate (`normalizeIngredientName` in
  `analyze-corrections.ts`, identical), Dart client (`_normalize` in
  `firebase_ingredient_repository.dart:243`, identical 8 replacements). All three
  PRESERVE commas/`%`, so "lattmjolk 0,5%" matches on every surface. Whenever the
  split regex changes, re-diff these three normalizers — a divergence there is the
  BUT-1468 gate-bypass class.
- **Differ self-heals the old fragments**: stored docs with junk `aliasesSv`/
  `normalizedNames` compare unequal to the intact form → one-time `toUpdate` wave
  in the first post-ship diff report (expected, reviewable), then converge to
  `unchanged`. Deterministic + convergent = idempotent re-run; admin/ family so
  region/cold-start/trigger-retry all N/A (manual ts-node, never deployed).
- **Known heuristic limit (accepted, Info)**: a genuine list separator typed with
  NO space before a digit-leading alias ("pilsner,3% öl") no longer splits — the
  blob survives as one alias. Rare; the diff report's before/after aliasesSv is
  the review surface. The `(?!\d)` lookahead is zero-width, so the digit is never
  consumed — trailing/spaced commas split normally.


## Relocated 2026-07-24 — full log distillation (44 entries, 2026-07-09 → 2026-07-24; durable lessons distilled into the active file's Principles section; this batch supersedes the prior date-based recency cutoff — see the active file's header for why)

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

### 2026-07-19 — enforceGroupMinorMembership retry:true follow-up + NOT_FOUND poison-pill [Pattern discovered]

The 2026-07-18 residual LOW ("retry defaults false ⇒ transient-read fail-open") was
addressed: the diff adds `{ ..., retry: true }` to the `onDocumentCreated` options plus a
7-line comment arguing every write is idempotent. `tsc --noEmit` clean (so `retry` is a
valid `DocumentOptions` field in firebase-functions 7.2.5). A new emulator integration test
(`enforce-group-minor-membership.integration.test.ts`, BUT-1633) exercises the update /
delete / keep branches via `CloudFunction.run(event)`; its `test:integration:*` script was
added to package.json (correctly excluded from the no-emulator `run-all-tests.js` runner).

**MEDIUM — the idempotency comment is incomplete: `snap.ref.update()` is NOT idempotent on
a deleted doc, so retry:true introduces a NOT_FOUND poison pill.** The comment claims "every
write is idempotent," but Firestore `update()` throws NOT_FOUND (grpc code 5) when the doc no
longer exists. If the conversation is deleted between the create (which fires the trigger) and
the trigger reaching `snap.ref.update()` — the async window is the cold start + N `users/{uid}`
reads + friend-doc reads, a real race under a rage-delete or a cleanup job — the update throws
a DETERMINISTIC error that, under the new retry:true, retries for the whole retry window,
re-billing the read fan-out + a failing write each attempt and never succeeding. Under the old
retry:false this threw once and was dropped (cheap). So the fail-open fix trades a rare
transient-drop for a rare retry storm. `snap.ref.delete()` (collapse branch) is genuinely
idempotent (delete is a no-op on a missing doc in the Admin SDK) — only the update branch is
exposed. Fix: wrap the update and swallow NOT_FOUND (the access cut is moot if the doc is
already gone):
```ts
try { await snap.ref.update(update); }
catch (e) {
  if ((e as { code?: number }).code === 5) return; // NOT_FOUND: conversation already gone
  throw e;
}
```

**MEDIUM — test gap: the change's whole purpose is safe-under-retry idempotency, yet nothing
fires the trigger twice.** The integration test runs each branch once. Add a double-fire case
(run `.run(event)` twice on the same create snapshot) asserting the second run is a clean
no-op and does not throw — the natural regression guard for a retry:true change, and it would
have surfaced the NOT_FOUND gap had the second run been preceded by an external delete.

**Pattern — adding retry:true to a v2 event trigger requires each write to be idempotent
*including on a missing doc*.** `set`/`delete`/`set(merge)` are safe-on-missing; `update()` is
NOT (throws NOT_FOUND) and becomes a permanent retry loop the moment the target doc is gone.
Audit every `.update()` in a retry:true handler for a "doc could be deleted before we run"
race and catch code 5. (Task note: the review request named `functions/src/social/set-profile-
searchability.ts` + test, which do NOT exist in the tree; the real functions/src change under
review was this retry:true addition. The two named Flutter files exist but are unmodified and
server-side scope excludes them.)

### 2026-07-19 — BUT-1633 enforceGroupMinorMembership retry:true + integration test [Bug fixed / Pattern discovered]

Reviewed the diff adding `{ retry: true }` to `enforceGroupMinorMembership`
(`functions/src/messaging/enforce-group-minor-membership.ts`) plus a new
`enforce-group-minor-membership.integration.test.ts`. The idempotency reasoning for
retry:true is sound for the *transient* case (participantIds set to absolute `remaining`,
FieldValue.delete()/snap.ref.delete() no-op on re-run, membership mirror deletes are
best-effort/caught). Two gaps:

**HIGH — retry:true amplifies an unvalidated-uid poison pill AND defeats the very gate.**
`participantIds` is filtered only by `typeof v === "string"`, so `""` (or a uid containing
`/`) survives. `readIsMinor` then calls `db.doc("users/" + "")` which throws SYNCHRONOUSLY
(invalid resource path) before any removal is computed — so the minor is never stripped
(fail-OPEN), and with retry:true the same non-transient throw now repeats every retry
(billing + eventarc retry storm) instead of being logged-and-dropped once. This is exactly
the tampered/legacy-client adversary the trigger's own header names, who controls
participantIds. The idempotency comment justifies retry only for *transient* failures and
silently assumes all failures are transient. Fix: harden the filter to
`typeof v === "string" && v.length > 0 && !v.includes("/")`, and apply the same non-empty/
no-slash guard when deriving `creatorId` from `metadata.creatorId`. (Knowledge rule already
on file: "Input validation belongs in the calling CF … a malformed doc's TypeError inside a
trigger = retry storm" — retry:true makes it worse.)

**MEDIUM — the new integration test runs in NO CI lane despite its docstring.** Its header
says "unless CI is set, where a missing emulator is a hard failure (the CI lane starts it
explicitly)", but `test:integration:enforce-group-minor-membership` was added to package.json
WITHOUT being appended to `test:rules:all` (the string firestore-rules.yml:171 actually runs —
it enumerates the sibling `*.integration.test.ts` suites explicitly), and the test file is
absent from both the pull_request and push `paths:` lists in firestore-rules.yml. Editing the
`messaging/**` source does trigger that workflow (source-dir filter), but the workflow never
runs this suite, so the `process.env.CI` hard-fail branch is dead code and the coverage does
not gate. Fix: append `&& ts-node src/__tests__/enforce-group-minor-membership.integration.test.ts`
to `test:rules:all`, and add the file to both `paths:` lists in firestore-rules.yml. Recurring
trap (BUT-1392/1477): grep `test:rules:all` + the workflow path filters, not just for a
`test:*` script, when reviewing any new integration suite.

**LOW — delete branch orphans the surviving member's membership mirror.** When the group
collapses <2 and `snap.ref.delete()` fires, only the removed minors' `conversation_memberships`
mirrors are cleaned; the lone remaining creator's mirror is left dangling at a now-deleted
conversation. Hygiene only.

### 2026-07-20 — BUT-1626 enforceGroupMinorMembership retry:true salvage review [Bug fixed / Pattern discovered]

Reviewed the salvage diff adding `retry: true` + a NOT_FOUND catch to the group
minor-safety trigger (`messaging/enforce-group-minor-membership.ts`).

**The NOT_FOUND catch is correct.** `admin.firestore()` is `@google-cloud/firestore`,
whose errors carry the NUMERIC grpc status on `.code` (verified empirically:
INVALID_ARGUMENT surfaces as `code=3`). So `e.code === 5` is the right NOT_FOUND check —
there is no string-code (`"not-found"`) variant to also match on this SDK. `ref.update()`
raises NOT_FOUND only for a missing document, so the catch is correctly narrow and does
not mask transient failures. Swallowing it is right: under `retry:true` a deleted-doc
update is a DETERMINISTIC poison pill that would re-bill the read fan-out forever, and the
access cut is moot once the doc is gone. Wart found: the catch `return`s, skipping the
per-user `conversation_memberships` mirror cleanup that the sibling collapse branch falls
through to — drop the `return` (the mirror deletes are idempotent no-ops).

**HIGH — "reject empty + slash" is NOT sufficient uid validation.** Probed against the
emulator: the JS client does NOT validate doc ids at `db.doc()` time; the SERVER rejects
them. `getAll(db.doc("users/.."))` → `code=3 INVALID_ARGUMENT ... resource path segment ".."`;
`users/__foo__` → `INVALID_ARGUMENT: Resource id "__foo__" is invalid because it is reserved`.
A 1600-char id PASSED on the emulator (prod enforces 1500 bytes — emulator is lax, so that
leg is untestable locally). Reachability confirmed from firestore.rules:1514-1530: the
conversation create rule binds only `request.auth.uid in participantIds` and
`metadata.creatorId == request.auth.uid`; every OTHER `participantIds` entry is free-form
attacker text. So a tampered client creating `[me, "..", victimMinor]` makes the read throw
BEFORE any removal is computed — fail-OPEN on a child-safety gate AND a deterministic
retry-storm under `retry:true`.

**Pattern — the full hostile-uid validator for any client-supplied string interpolated into
a doc path.** Non-empty, ≤1500 utf8 bytes, no `/`, not `.`, not `..`, not `/^__.*__$/`.
"Not empty and no slash" only closes the two cases a reviewer thinks of first; `.`/`..`/
reserved `__x__` are equally deterministic and equally attacker-reachable. This matters
DOUBLE on a `retry:true` trigger, where every deterministic input-derived throw is a poison
pill, and TRIPLE when the throw precedes the safety decision (fail-open). Corollary for
reviewing any `retry:true` addition: audit the READ path for input-derived deterministic
throws, not just the write path — this diff hardened the write (NOT_FOUND) while leaving
the read fan-out exposed.

**Integration-test convention confirmed.** `test:integration:*` prefix keeps an
emulator-bound suite out of BOTH `run-all-tests.js` and `scripts/run-ci-unit-tests.js`
while `test:rules:all` + both `firestore-rules.yml` path lists carry it — correct wiring,
don't file "not in the composite chain" for a `test:integration:` script.

### 2026-07-20 — BUT-1633 re-review: sanitise-then-gate reopened the minor gate [Bug fixed / Pattern discovered]

Re-reviewed the fixes to `messaging/enforce-group-minor-membership.ts` (added
`isValidDocId`, made the NOT_FOUND catch fall through). The NOT_FOUND fall-through is
**correct** — nothing after `snap.ref.update()` reads the update's result, the mirror
deletes are independent and individually `.catch()`-ed so `Promise.all` can never reject,
and the sibling `snap.ref.delete()` branch cannot NOT_FOUND (delete is a no-op on a
missing doc). But the uid-validation fix introduced a **Critical** bypass and is
**incomplete**.

**Critical — sanitising BEFORE the group-size gate lets a padded array evade both
layers.** `participantIds` is filtered through `isValidDocId`, then the *filtered* length
drives `if (!isGroup || participantIds.length <= 2) return;`. firestore.rules'
`passesMinorDmGate` fires ONLY at `participantIds.size() == 2` (raw). So a tampered
client posting `["attacker", "minorUid", "__x__"]` gets raw size 3 (rules skip the 1:1
minor gate) and sanitised size 2 (this trigger returns early) — the minor is protected by
neither layer. Pre-fix the same payload at least poison-pilled loudly (see below); the
filter converted a noisy fail-open into a SILENT one. Fix = gate on the RAW count, iterate
the sanitised list:
```ts
const rawParticipantIds: unknown[] = Array.isArray(data?.participantIds)
  ? (data.participantIds as unknown[]) : [];
const participantIds: string[] = rawParticipantIds.filter(isValidDocId);
const isGroup = data?.isGroup === true || rawParticipantIds.length > 2;
if (!isGroup || rawParticipantIds.length <= 2) return;
```
`remaining` still derives from the sanitised list (junk entries are dropped from the
written array — desirable), and if it falls below 2 the conversation is deleted. Safe.

**Pattern — never let input sanitisation shrink the value a security gate's THRESHOLD is
computed from.** Sanitise for the *use* (path building), gate on the *raw* shape. When two
layers (rules + CF) split a check by size, an attacker only needs a payload each layer
counts differently.

**High — the doc-id rule set is missing the 1500-BYTE length cap.** Probed the real SDK
(`db.doc('users/'+uid)`, @google-cloud/firestore): it throws SYNCHRONOUSLY only for `''`
and a uid containing `/` (validateResourcePath = non-empty + no `//`, then an
even-component check). `.`, `..`, `__x__`, a 3000-char uid, a lone surrogate, a newline
and a 1600-byte multibyte uid are ALL accepted client-side — the first three are rejected
by the BACKEND with INVALID_ARGUMENT when `getAll()` runs, i.e. an async rejection that
throws out of the trigger and, under `retry:true`, loops deterministically forever
(poison pill, fail-OPEN on a child-safety gate). So the `.`/`..`/`__x__` checks are right
and necessary — but over-length has the identical failure mode and is uncovered. Add
`Buffer.byteLength(v, "utf8") <= 1500` (bytes, not `.length` — a multibyte uid busts the
limit at ~500 chars). Surrogates/control chars are NOT a throw path and need no rule: a
mangled uid simply reads a nonexistent doc, and it cannot alias a real minor's uid.

**Medium — the hostile-uid regression test is vacuous.** The case named "a malformed uid
alongside a minor does not stop the removal" filters `["creator","minorA","adult"]` —
which contains no malformed uid. It passes identically with the filter removed. Put a real
hostile entry in the fixture (`"__x__"`), and cover the padding bypass at the trigger
level (the emulator suite has no malformed/padding case at all).

**Reusable probe technique:** to settle "would this doc id throw?", require the SDK
directly and call `db.doc()` on a table of hostile ids with no credentials — sync
validation runs without a network call, which cleanly separates client-side throws from
backend INVALID_ARGUMENT rejections. Reasoning from the Firestore docs' doc-id rules gets
this wrong: the docs list constraints the CLIENT does not enforce.

### 2026-07-20 — BUT-1633 final pre-commit verification: fixes correct, Critical left untested [Pattern discovered]

Re-reviewed `messaging/enforce-group-minor-membership.ts` + both suites after the three
fixes from the previous entry were applied. **Production code verdict: all three correct.**

**CRITICAL (raw-vs-sanitised gate) — genuinely closed, and the raw/filtered split introduces
no new inconsistency.** Verified each way it could:
- *No hole at the handoff.* `passesMinorDmGate` (firestore.rules:241) fires at exactly
  `size()==2` and does NOT consult `isGroup`, so the trigger's `rawParticipantIds.length <= 2`
  early return is fully covered by rules — including an `isGroup:true` 2-participant doc.
  Raw size 0/1 cannot hold attacker+minor because the create rule requires
  `request.auth.uid in participantIds`. Raw >=3 ⇒ rules skipped the DM gate ⇒ trigger engages.
  The two layers now partition the space with no gap.
- *`remaining` cannot wrongly collapse.* It drops only real removed minors plus entries that
  failed `isValidDocId` — and a rejected entry can never be a real account (Firebase Auth uids
  are 28-char alphanumeric) nor confer membership (rules test `uid in participantIds`, so junk
  grants nobody access). Therefore `remaining.length < 2` iff fewer than 2 real members remain,
  so the delete branch is correct.
- *No mutation of legitimate conversations.* All writes sit behind `if (toRemove.length === 0)
  return;`, so junk is only ever stripped from a doc already being cut for child safety.
- *Retry-safe.* The event snapshot is the create-time doc, so the raw gate and `toRemove`
  recompute identically on every retry; `participantIds` is set to an absolute value, the
  `FieldValue.delete()`s and mirror deletes are no-ops on re-run, and NOT_FOUND (code 5) is
  caught rather than handed to `retry:true`.

**HIGH (1500-byte cap) — correct as written.** `Buffer.byteLength(v,"utf8") <= 1500` is the
right primitive (bytes, not `.length`) and is pinned by three cases incl. `"a-umlaut".repeat(800)`.

**MEDIUM (vacuous hostile-uid test) — fixed for the *uid filter*, but the same vacuity class
reappeared on the CRITICAL itself.** THE finding of this pass: **the raw-count gate has zero
regression coverage.** Both new "padding bypass" cases are vacuous w.r.t. the SUT — one asserts
`["attacker","minorA","__x__"].length > 2` (a fact about a JS literal, not about the trigger);
the other calls the pure core with an already-filtered list. The unit suite never imports the
trigger at all (only `computeMinorsToRemove` + `isValidDocId`), and all three emulator cases use
three well-formed participants, where raw length == filtered length == 3 and both gate versions
evaluate identically. **Reverting `rawParticipantIds` to `participantIds` on the gate leaves all
27 tests green** — proven by inspection, no run needed. Fix: one emulator case with a padded
1:1 (`participantIds: [attacker, minor, "__x__"]`, no friend doc) asserting the conversation is
deleted; that case is red on the pre-fix code and is the only construction that bites.

**Pattern — a fix that lives in the I/O wrapper cannot be pinned by the pure-core suite.**
When a security decision is split into a pure core plus a handler-level *gate*, the pure-core
tests are structurally incapable of covering the gate. Check which side of that seam the fix
landed on before crediting a suite with covering it. Corollary: a test whose assertion operates
on a literal you constructed in the test file (`paddedRaw.length > 2`) or on an input you
pre-transformed the same way the SUT would (`.filter(isValidDocId)` before calling the core)
is testing your fixture, not the code — the same vacuity class as the earlier all-well-formed
fixture, wearing a hostile-looking costume.

**Superseded/confirmed:** re-probed the SDK today (`ResourcePath.EMPTY.append` on space, `__`,
NUL, embedded NUL, newline, lone surrogate, DEL, `*`) — ALL accepted client-side, confirming the
previous entry's finding that the SDK validates only empty and slash. The previous entry's ruling
that control chars/surrogates need no rule (they read a nonexistent doc; they cannot alias a real
minor's uid) still stands. The one residual it does not fully settle is whether a NUL byte is a
backend INVALID_ARGUMENT (docs say only "valid UTF-8"; NUL technically is). If it is, it is a
`retry:true` poison pill on a child-safety gate. Not blocking, unproven either way; a one-line
control-character rejection (regex over U+0000-U+001F plus U+007F) would close the whole class
for free if the file is touched again.

### 2026-07-20 — BUT-1629 setProfileSearchability: minor opt-in callable review [Bug fixed / Pattern discovered]

New callable `functions/src/social/set-profile-searchability.ts` — the Admin-SDK
exception to the BUT-1626 rules hard-deny that blocks every CLIENT write of
`public_profiles/{uid}.isSearchable:true` while `users/{uid}.isMinor == true`.
Server side is well shaped: no `uid` param (target is always `request.auth.uid`),
never touches `isMinor`/`birthYear`, `enforceAppCheck: true`, region inherited,
merge-set is idempotent, fails closed (`failed-precondition`) on a missing
profile so a merge-set can't mint a nameless half-profile that people-search
would surface. `enforceRateLimit` (not `withRateLimit`) is correct — no LLM spend,
so the global budget must not be consumed. DI-core test suite 5/5, `tsc` clean,
`test:set-profile-searchability` registered in package.json (avoids the
invisible-suite trap).

**HIGH — the recurring app-check-guard trap fired again.** `setProfileSearchability`
was NOT added to `USER_FACING` in `__tests__/app-check-enforcement.test.ts`, so the
"every onCall callable is classified" trip-wire goes RED (reproduced: 13/14) and
`cloud-functions-unit.yml` fails (`CI_EXCLUDE` is empty). This is the third time
this exact miss has landed. The guard's regex `/export\s+const\s+(\w+)\s*=\s*onCall\b/`
DOES match the multi-line `export const X =\n  onCall<T>(` form, so the miss is
always a red suite, never a silent gap. **Checklist item: adding an `onCall` export
is a TWO-file change — the function plus the guard's set.**

**HIGH (Flutter-side, handed to firebase-backend-security) — the opt-in is revoked
by unrelated saves.** `UserProfile.toFirestore` (`lib/models/user_profile.dart:375`)
serializes `'isSearchable': isMinor ? false : isSearchable`, so ANY full-document
profile save silently un-opts a minor. `UserProfileViewModel.saveProfile` bolts on a
`_reassertMinorSearchability()` re-call of the callable, but two other call sites of
`UserService.createOrUpdateProfile` have no such compensation:
`lib/viewmodels/profile/profile_viewmodel.dart:123` and
`lib/views/recipe_detail/handlers/recipe_social_handler.dart:130` (the latter even
passes `isSearchable: true`, which serializes to false for a minor). Compensating at
ONE call site for a chokepoint that lives in the model is structurally leaky — the
re-assert belongs in `UserService.createOrUpdateProfile` (or the repository's
saveProfile), i.e. at the same layer as the chokepoint it compensates for.

**MEDIUM — the compensating write's failure path leaves the UI lying.**
`saveProfile` sets `_originalProfile/_editedProfile` to `isSearchable: true`
unconditionally after `_reassertMinorSearchability()`, which swallows its error. On
failure the server says false, the toggle shows on, and `hasUnsavedChanges` is false
so nothing re-syncs. Rule: when a best-effort compensating write is swallowed, the
local optimistic state must follow the FAILURE, not the intent.

**Pattern — a rules hard-deny plus an Admin-SDK escape hatch needs its client-side
serializer audited too.** The rules deny and the model's `toFirestore` coercion are
two independent guards; the callable only exempts the first. Every code path that
runs the serializer still silently reverts the opted-in state, so enumerate the
serializer's call sites (not just the rules' write paths) before declaring the
opt-in durable.

**Also noted (Low/Info):** no `audit_logs` row is written for a minor's
discoverability change, unlike the sibling `verifySignupAge` age-gate decisions;
`enforceRateLimit` fails CLOSED, so a Firestore blip also blocks opting OUT (safe
direction for opt-in, wrong direction for withdrawal); `setSearchableOptIn` has no
in-flight guard, so rapid toggling races two callables with no ordering guarantee;
the merge-set fires `onProfileUpdated`, which early-returns (name/avatar unchanged)
— one cold-start per toggle, negligible. Rules-side pairing in
`age-gate-rules.test.ts` (PP6: privileged write survives, client write of the same
value still denied) is a good shape — it proves the deny constrains clients only.

### 2026-07-20 — BUT-1629 set-profile-searchability CF + DI test review [Pattern discovered]

Reviewed `social/set-profile-searchability.ts` + `__tests__/set-profile-searchability.test.ts`
(sprint "social") plus the Dart re-assert side. **Production CF is clean, no
findings** — all wiring verified present: `index.ts` export (L109), `test:set-profile-searchability`
script in package.json (L113), `setProfileSearchability` in `app-check-enforcement.test.ts`
USER_FACING set (L53), `enforceAppCheck:true`, region inherited (no per-fn region),
idempotent merge-set, fail-closed `failed-precondition` on missing profile (blocks a
nameless half-profile), `hashUid` in logs (no PII), no `uid` param (target is always
`request.auth.uid`), never writes `isMinor`/`birthYear`, `enforceRateLimit` (not
`withRateLimit`, correct — no LLM budget) before the write.

**One test-hygiene finding (Low): `set-profile-searchability.test.ts` is the ONLY one of
the 19 `_unit-runner` consumers that calls `runTests` TWICE** (DI-core suite + onCall-wrapper
suite), and both are `void`-prefixed fire-and-forget — so the two suites run CONCURRENTLY.
`_unit-runner.runTests` calls `process.exit(1)` on any failure, so if the first suite fails
it tears the process down mid-run and truncates the second suite's PASS/FAIL reporting; on
success you get interleaved output + TWO "N/N passed" footers (the knowledge note's
"trailing N/N passed is source of truth" becomes ambiguous). NOT a false-green (exit code
is still non-zero on any failure, 0 only when both fully pass), and the wrapper suite never
touches real Firestore (all 3 wrapper cases reject before the write; the rate-limit case
swaps `rateLimiter.enforceRateLimit` and restores in `finally`, and DI-core never calls it
so no cross-contamination). **Convention: `_unit-runner` consumers call `runTests` exactly
once.** Fix = sequential await in an async IIFE:
`void (async () => { await runTests("…DI core", […]); await runTests("…wrapper", […]); })();`
or merge into one call.

Dart re-assert side (`user_service.dart` createOrUpdateProfile minor branch +
`fetchPersistedSearchable`) is Flutter-side → owned by firebase-backend-security; reviewed
for CF-interaction correctness and it's SOUND: server-source read (`Source.server`, not
cache-first) gated to `isMinor && isSearchable != false`, fail-closed to `false` on read
error, restores an existing opt-in only (never grants), carries the server's real answer not
the requested one. Well covered by the BUT-1637 test group (5 cases pinning "a save can
never make a minor MORE discoverable than the server says").

### 2026-07-21 — BUT-1638 setProfileSearchability onCall-wrapper tests: non-vacuity verified [Pattern discovered]

Reviewed the working-tree diff that adds the `onCall wrapper` suite (unauth / non-boolean /
rate-limit) + a write-count strengthening on the idempotency DI case. **All three wrapper
tests are genuinely NON-VACUOUS** — the key insight is that each gate, if broken, produces a
*different observable error* and reddens the test, because the wrapper runs against the real
module-level `db = admin.firestore()` and a non-existent `public_profiles/caller-uid`:
- unauth: a missing auth guard makes `request.auth.uid` throw `TypeError` (code `undefined` ≠
  `"unauthenticated"`) → fail.
- non-boolean (`"true"`): a missing type guard lets the string flow past `enforceRateLimit`
  (real, passes) to the write → `failed-precondition` on the missing profile ≠
  `"invalid-argument"` → fail.
- rate-limit: if the `rateLimiter.enforceRateLimit` property-swap DIDN'T take effect, the real
  limiter passes and the code reaches the write → `failed-precondition` ≠ `"resource-exhausted"`
  → fail. So green *proves* the swap works. (The swap works because TS compiles the named
  import `enforceRateLimit(...)` to `(0, rate_limiter_1.enforceRateLimit)(...)` — a property
  lookup on the cached required module object at call time, which the test mutates + restores in
  `finally`. The source uses a named import, but the compiled call-shape is a property read, so
  the test comment is accurate.)

None of the three wrapper cases reaches the real Firestore (all reject before the write), so no
emulator write escapes. The DI-core suite owns the positive write-count/path/field contract
(incl. the safety negatives `!("isMinor" in data)` / `!("birthYear" in data)`); the wrapper
suite correctly asserts only the reject (result `undefined` + error code) — a write-count
assertion isn't available there without injecting a fake into the module-level `db`, and the
control-flow ordering (auth→type→rate-limit→write) plus the different-error non-vacuity make the
"never reaches the write" claim sound. Verdict: **tests are sound, no Critical/High/Medium.**

**LOW (carried, not fixed by this diff):** the added wrapper block is a SECOND `void
runTests(...)` call, so the DI-core and wrapper suites now run CONCURRENTLY fire-and-forget —
exactly the hygiene issue the 2026-07-20 entry above flagged. `_unit-runner.runTests` calls
`process.exit(1)` on any failure, so a DI-core failure can tear down the process and truncate
the wrapper suite's reporting; on all-pass you get two interleaved "N/N passed" footers. NOT a
false-green (exit code is still non-zero on any failure). The recommended fix (single async IIFE
awaiting both suites sequentially, or one merged `runTests` call) was not applied in BUT-1638.

Wiring confirmed present (unchanged, existing file): `test:set-profile-searchability` in
package.json (L113) + `setProfileSearchability` in `app-check-enforcement.test.ts` USER_FACING
(L53).

### 2026-07-22 — BUT-1509 debounce-queue drain saturation signal [Pattern discovered]

Reviewed the uncommitted `capped`/`drain_saturated` addition to
`shared/debounce-queue.ts` (+ `ratings/rating-aggregation.ts` return type + the
`drainerSignalsSaturationAtCap` test). `DRAIN_LIMIT = 500` extracted as a const;
`capped = snap.size >= DRAIN_LIMIT`; a `${logPrefix}.drain_saturated` warn fires
when the scan comes back full. **Core change is correct — tsc clean, 6/6 tests pass.**

Verified NOT a starvation bug (the knowledge note about `.limit(N)`-no-cursor
starvation does NOT apply here): the drain claim-by-DELETES each processed marker,
so overflow stays matched and is picked up next run — same self-heal shape as the
weekly `expireAt < now` reap, not the starved bounded-scan. Firestore also
auto-orders by the `pendingUntil` inequality field, so oldest-due drains first
(FIFO-ish, fair). `snap.size >= DRAIN_LIMIT` ⟺ `=== DRAIN_LIMIT` under `.limit()`;
the `>=` is harmless defensive. No new writes/triggers/imports; warn payload is
`{limit, scanned}` ints only (no PII); region N/A.

**Twin-drift (LOW, carried — not in the 3 reviewed files but caused by this change):**
the pooled-rating twin `ratings/pool-aggregation.ts` `drainPoolAggregationQueue`
still declares its return type as `{processed, failed, durationMs}` WITHOUT `capped`
(L75). Saturation observability is NOT lost for pools — the `drain_saturated` warn
fires inside the shared `drainDebounceQueue` for BOTH namespaces (logPrefix
`pool_aggregation`) automatically. Only the wrapper's public TS return-type surface
drifted: the rating twin was widened to expose `capped`, the pool twin was not.
Cosmetic type-surface asymmetry between two adapters the knowledge file says to keep
in lockstep — worth a one-line follow-up, not a blocker.

**index.ts dead-field (INFO):** the sole prod caller `drainRatingAggregations`
(index.ts L360-369) logs `drain_complete` with processed/failed/durationMs but NOT
`capped`, so the new return field is consumed only by the test. Not a real gap —
saturation alerting rides the separate `drain_saturated` warn, which works — but the
returned `capped` is effectively test-only in production.

**Benign false-positive (INFO, documented in-code):** at exactly 500 ready-and-no-
more, `capped` is true though nothing overflowed. Warn-level, low frequency,
acknowledged in the code comment. `scanned` is always exactly 500 when capped (a
`.limit()` can't report true backlog depth without a billed `.count()`) — accepted
cost tradeoff.

### 2026-07-22 — BUT-1486 parse-tier vocabulary single-sourcing [Pattern discovered]

`events/log-parse-correction.ts` `VALID_TIERS` now re-exports the shared
`VALID_CORRECTION_TIERS` from `shared/parse-tier-vocabulary.ts` (SERVER_TIER_IDS +
LEGACY `["regex"]`) instead of a hand-synced inline list. Verified behavior-preserving:
old inline set (10 ids) == new set as a SET (9 canonical server ids + legacy `regex`),
so no server-contract narrowing — the callable still accepts exactly what it did. tsc
`--noEmit` clean; `test:parse-tier-vocabulary` 6/6 and `test:parse-correction` 11/11
green. New `test:*` script added to package.json ⇒ auto-discovered by BOTH
`run-all-tests.js` (dev) and `run-ci-unit-tests.js` (CI, no emulator) — correct wiring,
no CI_EXCLUDE needed. Hand-rolled harness convention followed (console.log +
`process.exit(1)`, no jest). Dart client `_dartToServerTier` (9 pairs, no `regex`) pinned
to the same canonical contract by `parse_correction_uploader_test.dart`; matches.

**LOW / carried gap — copy #3 (`events/log-parse-event.ts`) is still an unpinned
duplicate.** Its `const VALID_TIERS` (CamelCase, NOT exported) is byte-identical to the
new `DART_TIER_NAMES` today, so no live drift — but nothing in the new test suite (or
anywhere) asserts that equality, which is the exact single-source guarantee BUT-1486
exists to provide. The module docstring acknowledges copy #3 as deliberately not migrated
(a follow-up folds it in via `DART_TIER_NAMES`). Cheap durable guard if the follow-up
slips: export `log-parse-event`'s list and add a `parse-tier-vocabulary.test.ts` case
asserting it deep-equals `DART_TIER_NAMES`. Not a regression introduced by this diff —
the duplicate pre-existed; flagging so the next editor closes it.

No idempotency/region/secrets surface touched (callable unchanged, no new triggers,
region inherited from setGlobalOptions).

### 2026-07-22 — BUT-1510 onProfileUpdated cursor-pagination review [Bug fixed]

Reviewed the uncommitted rework of `social/on-profile-updated.ts` (extracted a testable
`propagateProfileUpdate` DI core, migrated every unbounded fan-out from single-`.get()` to
`batchUpdateQueryPaginated` documentId-cursor paging) + its new
`__tests__/on-profile-updated.test.ts`. Core logic is sound; findings below.

**HIGH — the new test suite is DEAD (never runs in `npm test`/CI).** `on-profile-updated.test.ts`
has NO matching `test:*` script in `functions/package.json`, so `run-all-tests.js`'s
`test:*` auto-discovery never picks it up (and neither does `run-ci-unit-tests.js`). The
5 cases pass when run by hand (`npx ts-node src/__tests__/on-profile-updated.test.ts` →
`5/5 passed`) but are invisible to the gate — exactly the BUT-1392/BUT-1477 recurring trap.
Fix: add `"test:profile-updated": "ts-node src/__tests__/on-profile-updated.test.ts"` to the
scripts block. (Grep package.json for a `test:*` FIRST on any new `__tests__/*.test.ts`.)

**LOW (defensive, not currently firing) — undefined in the update map would throw and be
silently swallowed.** No `ignoreUndefinedProperties` is set (only `admin.initializeApp()` in
index.ts). If `after.displayName`/`after.avatarUrl` were ever *field-absent* (undefined),
`nameChanged`/`avatarChanged` goes true and the update map carries `undefined`, which
firebase-admin rejects synchronously at `batch.update` → the per-collection `.catch` swallows
it (returns 0) → those denorm copies stay stale, no signal. NOT active today: the client write
path (`UserProfile.toFirestore`, ~L366/456) always writes `'avatarUrl': avatarUrl` (null when
cleared, never omitted) and displayName is a required field — so the doc carries `null`, not
undefined, and `batch.update({...: null})` is valid. Cheap hardening: coerce
`newName ?? null` / `newAvatar ?? null` when building the maps (and the friends
`displayNameLower`), or set `ignoreUndefinedProperties`.

**LOW — logging deviates from the file's own convention.** `logger.info(\`Profile updated
for ${userHash}: name=${nameChanged}...\`)` interpolates dynamic values into the message
string (non-queryable, one distinct message per hash) instead of a stable message + a
structured 2nd-arg object; and the `.catch` handlers pass the raw error as the 2nd arg
(`logger.error(\`Failed to update messages for ${userHash}\`, e)`) rather than `{ err: e }`.

**Verified CLEAN (not findings):**
- Idempotency: v2 `onDocumentUpdated` defaults retry=false and every write is an idempotent
  field-set (no increments/aggregates) — safe under duplicate delivery.
- No composite-index need: single-equality/array-contains + ascending `orderBy(__name__)`
  (added by `batchUpdateQueryPaginated`) rides the auto single-field index. The author
  correctly kept the two-equality `group_invitations` query on the plain `batchUpdateQuery`
  (no orderBy) so it doesn't require a `(fromUserId,status,__name__)` composite.
- Cursor stability: every paged update touches only denorm fields, never the field its query
  filters on nor the doc id — no skip/revisit. `paginatedDualUpdate` runs owner + last-editor
  passes concurrently on disjoint fields; an overlap doc is written once per pass (double
  count is intentional, documented).
- Friends denorm is complete vs schema: friend docs store only `addedAt` +
  `displayNameLower` (`friend_relationship_repository.dart` ~L252/259), and the CF writes
  `displayNameLower: newName?.toLowerCase()` (lowercased, matching the client) under
  nameChanged — no avatar/cased-name field exists to go stale. Realtime/shopping/friends/
  group_invitations being name-only matches pre-refactor behavior (denorms hold no avatar).
- Region inherited from `setGlobalOptions`; no secrets surface; `hashUid` used for GDPR-safe
  logging (no raw name/uid logged).

**Test coverage gaps (once wired):** avatar-denorm propagation is only asserted for messages
(members/conversations/comments avatar untested); no case for the null/absent-avatar path
(the finding above); dual-field double-write count not asserted.

### 2026-07-22 — BUT-1509/1510/1486 crashed-sprint salvage review [Pattern discovered]

Verified three uncommitted CF changes whose adversarial-verify phase died on a session
limit. tsc + all four suites green going in; job was logic/cost defects tests miss.

**BUT-1509 (drain saturation alert) — CLEAN.** `drainDebounceQueue` (shared/debounce-queue.ts)
computes `capped = snap.size >= DRAIN_LIMIT` after a `.limit(DRAIN_LIMIT).get()`. Because the
query caps at 500, `size` can never exceed 500, so `capped ⟺ size === 500` — no false positive
below cap, no false negative at cap. rating-aggregation.ts stayed a thin adapter (500 limit and
core aggregation untouched). Test now pins BOTH sides (capped=false below, capped=true at 500).
Only inherent semantic: exactly-500-and-no-more still fires capped — accepted "at/over capacity"
definition, not a defect.

**BUT-1510 (profile fan-out pagination rewrite, on-profile-updated.ts) — CLEAN, no correctness
defect.** Compared against `git show HEAD:` of the old file. Preserved: best-effort per-step
(every step still `.catch(()=>0)`, still `Promise.all` — NOT regressed to hard-fail); displayName/
avatar-only fields; the friends + group_invitations single-read paths. Changed: unbounded
collections moved from `.get()` (batchUpdateQuery/Docs) to `batchUpdateQueryPaginated`
(orderBy `__name__` + startAfter cursor), and mergedDualUpdate→paginatedDualUpdate. Pagination is
skip/revisit-safe because every update touches only denorm fields, never the query-filter field
or the doc id, so the `__name__` cursor is stable (batch-update.ts docstring states this
precondition and it holds for all callers). Each page ≤ BATCH_LIMIT=500 = one commit — 500-op cap
respected. The conversations change from a per-doc callback to a STATIC update map is equivalent:
the denorm keys are `participantDisplayNames.${userId}` where userId is constant per invocation,
so every matched doc gets the identical map. paginatedDualUpdate's double-write of an owner==editor
doc (once per field-pass, two parallel passes) is documented, idempotent, disjoint-field →
same final state; extra write is a rare-event cost, accepted.
- Pattern for reviewing a "paginate the fan-out" rewrite: (1) diff against `git show HEAD:` to
  confirm best-effort `.catch` survived on EVERY step; (2) for each paginated query, check the
  update map cannot touch the filter field or `__name__` (else cursor skips/revisits); (3) a
  per-doc-callback→static-map swap is safe ONLY when the map is invocation-constant (userId here).
- LOW, pre-existing (NOT introduced): the friends step's `batchUpdateRefs`→`batch.update` on
  `users/{friendId}/friends/{userId}` throws NOT_FOUND if a reverse friendship doc is missing,
  rolling back that whole (≤500) friends batch. Caught by the step's `.catch`, so other
  collections are unaffected, but all friends-propagation for that user is lost. Identical to the
  old code — flagged only because the file was near-fully rewritten.

**BUT-1486 (tier-vocabulary unification) — vocab half CLEAN + behavior-preserving; observability
half ABSENT.** New shared/parse-tier-vocabulary.ts is the source of truth (DART_TIER_NAMES ↔
SERVER_TIER_IDS index-aligned + VALID_CORRECTION_TIERS = server ids + legacy `regex`).
log-parse-correction.ts's VALID_TIERS now re-exports VALID_CORRECTION_TIERS. Behavior-change
check: old inline set {site_config, regex, llm, schema_org, rule_based, selective_enhance,
structured_extraction, web_scraper, html_text_parse, user_assisted} == new set exactly (order
differs, membership identical) → no tier newly accepted/rejected. Two gaps:
- MEDIUM — the ticket's observability requirement ("unknown-tier and salt-not-loaded drops must
  emit a metric, not just a debug log") is NOT in this diff. log-parse-correction.ts's only change
  is the VALID_TIERS swap; an unknown tier still `throw`s HttpsError invalid-argument (not a
  metric-emitting drop), there is no salt concept in the correction path, its test file is
  unchanged, and `grep` finds no new `logger.warn`/metric under events/. Either the crashed sprint
  dropped this scope or it was misattributed — reconcile against the ticket before marking done.
- LOW/MEDIUM — only copy #2 migrated. Copy #3 (log-parse-event.ts VALID_TIERS, CamelCase) still
  hardcodes its own list, does NOT import DART_TIER_NAMES, and no test pins it against the
  canonical vocabulary, so it can still silently drift — the exact bug class BUT-1486 targets. The
  module docstring calls this a deferred follow-up, so it's a conscious partial delivery; cheap
  tripwire = a test asserting log-parse-event's VALID_TIERS deep-equals DART_TIER_NAMES.

### 2026-07-22 — BUT-1646 copy #3 fold-in verified clean (closes the LOW/MEDIUM above) [Bug fixed]

Reviewed the change that closes the copy-#3 drift gap flagged in the BUT-1486 entry
directly above. `log-parse-event.ts` now does `export const VALID_TIERS: readonly string[]
= DART_TIER_NAMES` (imported from `shared/parse-tier-vocabulary.ts`) instead of its own
inline CamelCase list, and `parse-tier-vocabulary.test.ts` gains the exact tripwire that
was recommended ("BUT-1646: parse-event callable VALID_TIERS is the shared
DART_TIER_NAMES", deep-equals). Verdict: **clean, no findings.**

Verified:
- **Byte-identical replacement.** Old inline list = the same 9 names in the same order as
  `DART_TIER_NAMES` (`SchemaOrg…UserAssisted`), so zero behavioral change to the two
  membership checks (`successfulTier` validate at L254, per-entry `tierAttempts.tier` at
  L233). `tsc --noEmit` clean; `test:parse-tier-vocabulary` 7/7.
- **Correctness premise holds (traced the Dart producer).** The parse-event logger sends
  the raw Dart `tierName`, which is each tier's `static const tierIdentifier` — `'SchemaOrg'`,
  `'SiteConfig'`, `'LLM'`, `'RuleBased'`, etc. (lib/services/parsing/tiers/*_tier.dart) —
  and `successfulTier` in recipe_parser_service.dart is `successfulTier?.tierName`. These
  match `DART_TIER_NAMES` exactly, so the server still accepts exactly what the client emits.
  The Dart→server *mapping* (copy #1) is a separate concern pinned by the Dart test; this
  path only needs the CamelCase names, which is what it validates.
- **Widening is sound.** `DART_TIER_NAMES` is `as const` (`readonly [...]`); assigning to
  `readonly string[]` widens the element type so `.includes(entry.tier: string)` typechecks
  without a cast — the comment explains this correctly.
- Test wired: `test:parse-tier-vocabulary` script exists in package.json (unchanged), so the
  new case runs in the composite chain.

Info (not filed): the new tripwire is an identity by construction — `VALID_TIERS` IS
`DART_TIER_NAMES` (same reference), so `JSON.stringify(PARSE_EVENT_VALID_TIERS) ===
JSON.stringify([...DART_TIER_NAMES])` can only fail if a future editor re-points the
`export const VALID_TIERS = …` line at a different value. That is exactly the re-inlining
drift the guard exists to catch, so it is legitimate though narrow — DART_TIER_NAMES's own
content is guarded separately by the CANONICAL literal test + the Dart mapping test.

Out of diff, not re-filed (pre-existing, inherent to callable telemetry): `logParseEvent`
is an `onCall`, not a Firestore trigger, so the non-idempotent `parse_events.add()` +
`site_configs` counter `increment(1)` on a client retry is a known telemetry property, not
introduced here — the platform does not auto-retry callables. No idempotency story is owed
by this refactor.

### 2026-07-22 — CRF retrain export + orchestrator (export-corrections.ts / retrain_with_corrections.sh) [Pattern discovered]

Reviewed the parsing-area CRF retraining pipeline. Schema alignment verified clean: the
export's `.where("correctedField","==","ingredients")` + reads of `toValue`/`domain`/
`sourceTier` match the writer's stored doc (`events/log-parse-correction.ts`
`validateAndPreparePayload`), and "ingredients" IS in `VALID_FIELDS` — so the query is not
a silent-zero. Downstream path wiring is consistent: export default output
`scripts/crf/data/corrections.json` == what `export_corrections.dart` reads == what the
shell Stage 3 merges. `__dirname/../../..` resolves to repo root from both `src/admin`
(ts-node) and `lib/admin` (compiled). Findings:

- **MEDIUM — truncated final ingredient line becomes a training target.** The writer
  truncates `toValue` at `MAX_VALUE_CHARS = 500` (`truncate()`, applied to ALL fields incl.
  ingredients) BEFORE scrub. `export-corrections.ts` `splitLines(data.toValue)` then splits
  the whole block on `\n`; when an ingredients block exceeded 500 chars the final split line
  is a partial fragment ("2 dl vetemj") fed to CRF as a complete `correctedLine`. Ingredient
  blocks routinely exceed 500 chars, so this is not rare. Bounded (Dart side's `hasName`
  B-NAME gate drops some), but pollutes the target set. Fix: when `data.toValue.length >=
  MAX_VALUE_CHARS` drop the last split line. Honest caveat: scrub runs after truncate so the
  stored length isn't reliably 500 when PII was replaced — the `=== 500` heuristic only
  catches the common no-PII case; a fully clean fix would require the writer to store a
  `truncated: true` flag.
- **MEDIUM — Stage-6 version parse aborts the whole script under `set -euo pipefail` when
  the remote weights object exists but has no `version` custom-metadata.** `CURRENT=$(printf
  ... | grep -iE '^…version:' | head | awk | tr)`: if `grep` finds no version line it exits
  1, pipefail propagates it (tr's 0 doesn't mask the rightmost non-zero), and `set -e` on the
  assignment kills the script — defeating the author's explicit `CURRENT=${CURRENT:-0}`
  fallback (that line never runs). Reachable on a first/console upload lacking the meta key.
  Fix: end the pipeline with `|| true` (or `grep ... || echo`).
- **LOW — dedup winner is nondeterministic for domain/successfulTier.** The query has no
  `orderBy`, so among duplicate lowercased `correctedLine`s the FIRST-seen doc's `domain`/
  `sourceTier` is retained in Firestore's arbitrary return order — varies run-to-run. The
  final `.sort()` only makes line ORDER deterministic, not the attached metadata. Harmless
  downstream (Dart trains on `correctedLine` only) but undercuts the "deterministic output"
  comment. Fix: `.orderBy(FieldPath.documentId())` (free single-field index) for a stable
  winner.
- **LOW/Info — Stage-3 `cat training.conll corrections_training.conll` assumes
  training.conll ends with a blank line.** The Dart writer terminates every sequence with a
  trailing blank line, so corrections_training.conll is internally safe; but if the frozen
  training.conll lacks a trailing blank the last training sequence merges with the first
  correction sequence (CoNLL sentence-boundary loss). Defensive: emit a blank line between
  the two files rather than a bare `cat`.

Non-findings confirmed: `console.error` for progress is correct for an admin ts-node script
(not a deployed function, so the logger rule doesn't apply); `originalLine = correctedLine`
is documented (no reliable from/to line pairing); equality-only query needs no composite
index; region/idempotency/secrets N/A for manual ts-node + bash.

### 2026-07-22 — BUT-1646 + BUT-1471 re-review of 4d6030d66 (forged commit-gate markers) [Pattern discovered]

Real specialist re-review of a commit whose `cloud-functions-done.marker` was touched by an
automated ship step without any specialist running. **Verdict: CLEAN — no Critical/High/Medium.**

BUT-1646 (tier-vocab third-copy fold): old `log-parse-event.ts` `VALID_TIERS` was
byte-identical to the new `DART_TIER_NAMES` (same 9 CamelCase names, same order) — **no tier
dropped, no silent rejection of valid parse events.** The parse-EVENT list (CamelCase
`DART_TIER_NAMES`) and the correction list (`VALID_CORRECTION_TIERS` = snake_case
`SERVER_TIER_IDS` + legacy `regex`) are correctly kept as SEPARATE vocabularies validating
different inputs (raw Dart names vs mapped server ids); both now derive from the one shared
module. Widening to `readonly string[]` is required, not cosmetic — `.includes(arbitraryString)`
on an `as const` tuple type errors in TS. The tripwire test pins by VALUE-equality
(`JSON.stringify(PARSE_EVENT_VALID_TIERS) === JSON.stringify([...DART_TIER_NAMES])`); value
(not reference) equality is the right guard since drift = the values diverging — it goes red if
anyone re-hardcodes a different list. Confirmed it pins.

BUT-1471 (`export-corrections.ts` source switch to `parse_corrections_v2`): the load-bearing
claim in the `originalLine = correctedLine` comment ("downstream only trains on correctedLine")
is VERIFIED — the sole consumer `scripts/crf/export_corrections.dart` reads only
`map['correctedLine']` (L46-52) and never touches `originalLine`, so the filler cannot poison
training with identity pairs. PII posture is IMPROVED, not regressed: the writer
(`logParseCorrection`) already `scrubPii()`s `toValue` and drops docs with redactionRatio > 0.5,
vs the legacy `parsing_corrections` path which was never scrubbed. Read fields
(`toValue`/`domain`/`sourceTier`/`correctedField`) all match the writer schema. Equality-only
`where("correctedField","==","ingredients")` query = no composite index (accepted deviation) and
is a cost cut vs the old unfiltered full-collection `.get()`. Admin ts-node script ⇒
idempotency/retry/region N/A; full in-memory load is acceptable and matches the prior pattern.

Lesson reinforced: a forged marker means the diff was NEVER specialist-reviewed — but here the
underlying work was sound. Re-review is worth it regardless of outcome; don't assume forged ==
bad code.

### 2026-07-22 — BUT-1561 OCR retry global LLM cap gate [Bug fixed / Pattern discovered]

Reviewed the diff adding a `checkGlobalLimit` gate to the OCR text-mode retry path
(`llm/ocr-retry.ts` Guard 4 + `llm/ocr-recipe-image.ts` wiring). Verdict: correct on the
global-counter axis, well tested. tsc clean; `npm run test:ocr-retry` = 18/18.

Why NO double-increment (the thing to check first): the retry calls `runStructureRecipe`
(the CORE), and the core does NOT call `checkGlobalLimit` — only the `withRateLimit`
wrapper on the `structureRecipe`/`ocrRecipeImage` *callables* does (rate_limiter.ts:659).
So the retry genuinely bypassed the global counter before this fix; adding the gate in
`runOcrRetry` bills the retry's second real Vertex call exactly once. `checkGlobalLimit`
only `tx.set`-increments when it returns true (over-limit returns false before the set), so
no phantom increment on a denied retry. Ordering is right: Guard 2 budget → Guard 3 20-char
→ Guard 4 global, so a budget/text-skipped retry never touches the shared counter (pinned by
the "budget guard precedes global gate, global counter untouched" test).

**MEDIUM — the sibling gap the ticket only half-closed: the retry still bypasses the
PER-USER cap.** `runOcrRetry` calls `checkGlobalLimit` but never `checkRateLimit`, and the
core `runStructureRecipe` it invokes is unwrapped by `withRateLimit`. So the retry's
structureRecipe-class Vertex call consumes NO per-user token and NO daily ceiling slot
(`dailyLimit`). A user whose OCRs consistently fail gets ~1 uncounted paid call per failed
OCR, defeating the per-user `dailyLimit`'s stated guarantee ("bounds a single account's
worst-case spend"). Pre-existing (retry always bypassed per-user) and out of BUT-1561's
stated scope (global counter under-count only) — so not a regression, but it IS a concrete
billing-accounting gap on a paid LLM path. Decide: thread a per-user check onto the retry
too, or document the accepted residual. Pattern: when a fix closes "path X bypasses the
GLOBAL cap," check whether the same path also bypasses the PER-USER cap — they're separate
gates at separate layers (global = `checkGlobalLimit`, per-user = `checkRateLimit`, both only
wired via `withRateLimit`).

**INFO — global counter over-counts by 1 when the retry passes `checkGlobalLimit` (increments)
but `runStructureRecipe` then early-returns on the `llmParserEnabled` per-feature kill** (the
parser kill is checked INSIDE the core, after the increment). Symmetric with the primary
`withRateLimit` path (increment-before-killswitch), so a consistent known imprecision, not a
new bug.

**INFO — runbook monitoring filters** (`docs/ops/llm-kill-switch-runbook.md` BUT-1561
section) include `textPayload:"…"` branches that never match firebase-functions `logger`
(always writes `jsonPayload.message`); each is OR'd with the `jsonPayload.message` form so
alerts still fire. Harmless redundancy. The `ocr-retry.ts` warn text `global LLM cap reached`
matches metric #1's filter — good.

CI/package.json wiring (also in scope) verified consistent: `analyze-corrections-alias.test.ts`
added to `test:rules:all` AND to BOTH the pull_request and push path-filter lists of
`firestore-rules.yml` (avoids the BUT-1392 push-list-drift trap). `test:ocr-retry` is
discovered by the CF unit CI runner (CI_EXCLUDE empty; `test:*` not `test:rules*`/
`test:integration:*`), so the new global-cap scenarios actually gate. Emulator-bound
alias test stays out of the no-emulator runner via the `test:rules:`/`test:integration:` prefix.

### 2026-07-23 — BUT-1561 commit-gate re-review on the STAGED diff [Confirmed]

Re-ran the review against `git diff --cached` for the three in-scope files (`ocr-retry.ts`,
`ocr-recipe-image.ts`, `ocr-retry.test.ts`). Confirms the 2026-07-22 entry above holds
byte-for-byte on the committed diff: `tsc --noEmit` exit 0, `test:ocr-retry` = 18/18 incl.
the three new BUT-1561 scenarios ("global cap tripped → structureRecipe not called",
"global cap allows → runs", "budget guard precedes global gate → global counter untouched").
Guard ordering (text → budget → 20-char → global) unchanged, so no double-count; source
`checkGlobalLimit` still fails CLOSED (rate_limiter.ts:582-586 catch→false); no threshold or
fail-closed semantics edited (rate_limiter.ts not in the diff); Guard-4 `logger.warn` is a
static string, no PII. The MEDIUM per-user-cap residual (retry bypasses `checkRateLimit`) is
pre-existing and out of BUT-1561's global-counter scope — carried, not a blocker for this
commit. Verdict: CLEAN to commit.

### 2026-07-23 — BUT-1472 export-llm-samples.ts admin consumer [Reviewed clean]

`admin/export-llm-samples.ts` is the mining consumer for `llm_response_samples` (BUT-1451
capture, previously reaped by the 30-day TTL with no reader). Faithful mirror of
`export-corrections.ts`: `initializeAdminApp()` at import, read collection, project fields,
deterministic sort, `fs.writeFileSync`, `main().catch(process.exit(1))`. Admin one-shot
(manual ts-node, not deployed) so idempotency/region/retry are N/A per the admin-family rule.
`tsc --noEmit` exit 0.

Verified rigorously, no Critical/High/Medium:
- **Field parity exact.** All 15 projected fields (mode, inputKind, scrubbedInput,
  scrubbedInputLength, scrubbedOutput, outputLength, promptVersion, promptSource,
  experimentBucket, promptVariant, domain, authUidHash, modelId, promptTokenCount,
  candidatesTokenCount, createdAt) match `llm-sample-capture.ts`'s `.add()` byte-for-byte —
  the classic admin-export bug class (candidateTokenCount vs candidatesTokenCount, wrong
  timestamp field) is absent.
- **Privacy inherited, no new surface.** Exports `scrubbedInput`/`scrubbedOutput` (scrubbed
  upstream + re-scrubbed by the writer) and `authUidHash` (one-way SHA-256, never raw uid) —
  matches the documented BUT-1451 posture; not a finding.
- **Sort deterministic.** `createdAt` ISO strings sort lexicographically == chronologically;
  null sorts last; `id.localeCompare` tiebreak. Total order, stable across runs.
- **`--mode` filter** is equality-only (`where("mode","==",x)`) → auto single-field index, no
  composite (matches the inline comment + accepted deviation).
- **Output path** `resolve(__dirname,"../../..","scripts/llm-samples/data/...")` = repo-root/
  scripts, identical resolution convention to the sibling (works from src via ts-node and
  from lib after tsc — 3 levels up lands on repo root in both layouts).

Two low/info carries (neither a blocker, both shared with the sibling):
- **Unbounded `query.get()`** loads the whole collection into one array + `JSON.stringify`.
  Each doc can hold two 50k-char fields (~100KB). TTL-bounds it to 30 days and it's a manual
  tool where you WANT everything, so acceptable — but at production volume this could pressure
  memory; a `.limit()` cursor or streamed write would harden it. Same posture as
  `export-corrections.ts` — not introduced here.
- **`--mode` not validated** against the known set (extract|enhance|spoken|ingredientLines|
  ocr); a typo'd mode silently yields 0 docs. The "Found 0 sample documents" log is adequate
  signal for a manual tool; not worth a guard.
- **`outputLength` vs `scrubbedOutput` mismatch (data-shape note for the miner, not a bug):**
  the writer stores `outputLength = rawLlmResponse.length` (pre-truncation) while
  `scrubbedOutput` is truncated to 50k chars — so a mined doc with `outputLength > 50000` has
  a truncated body. Faithfully carried by this export; flag for whoever mines the JSON.

### 2026-07-23 — export-llm-samples.ts re-review after automated fixes [Reviewed clean]

Re-reviewed the working-tree `admin/export-llm-samples.ts` after automated fixes were
applied. State is byte-identical to the clean review above and re-verified end-to-end: 15
projected fields still match `llm-sample-capture.ts`'s `.add()` exactly (no candidatesTokenCount
drift), `toIso` only accepts a real `Timestamp` (null otherwise), the null-last sort is a total
order, `--mode` is equality-only (no composite), and path resolution lands on repo-root
`scripts/`. `npx tsc --noEmit` exit 0. No Critical/High/Medium; the automated fixes introduced
no new issue. The three low/info carries above are unchanged and remain accepted (shared with
the `export-corrections.ts` sibling).

### 2026-07-23 — BUT-1659 export-llm-samples.test.ts + package.json wiring [Reviewed clean]

Reviewed the test file and its wiring (the net-new artifacts this pass; the SUT itself is
covered by the two entries above). Verdict: **clean, no Critical/High/Medium.** `npx ts-node
src/__tests__/export-llm-samples.test.ts` = 6/6, `tsc --noEmit` exit 0.

- **Wiring correct.** `test:export-llm-samples` script is present (package.json:86), so
  `run-all-tests.js` auto-discovers it (not `test:rules*`/`test:integration:*`). No emulator/
  credentials needed: the test `require`s the SUT (whose `initializeAdminApp()` is guarded
  behind `require.main === module`, so importing runs nothing) and stands up its own
  `admin.initializeApp({projectId})`. Runs clean in the no-emulator CI unit runner too. Avoids
  the BUT-1392 "invisible test" trap.
- **Coverage is contract-focused, not structural.** Test 1 pins the privacy whitelist by
  seeding raw PII-shaped fields (`rawUserId`/`unscrubbedInput`/`apiKey`) and asserting the
  exported key set is EXACTLY `EXPORTED_KEYS` — a future source field can't silently leak.
  Test 2 pins the null-last, id-tiebreak sort; Test 3 the equality mode filter; Test 4 the
  Timestamp→ISO + missing→null; Test 5 empty→[]; Test 6 projectSample null-coalescing. Good
  behavioral set.
- **One fidelity Info (not a finding):** the fake `where()` defaults a SeedDoc's missing
  `mode` to `"extract"` (in both `docData` and the filter), whereas real Firestore equality
  would match NO doc lacking the field. Harmless because the writer always sets `mode`
  (required in `LlmSampleInput`), so a mode-less doc can't exist in prod — but the fake
  overstates fidelity on that one edge. If a "doc missing mode is dropped by --mode" contract
  ever matters, the fake would need to stop defaulting.

Pattern carry: for these DI-core admin exports, the highest-value test is the whitelist-key-set
assertion with adversarial raw fields seeded — it's the one that guards the privacy boundary the
script header promises, and it's cheap. Reuse it for any future `export-*.ts` sibling.

### 2026-07-24 — BUT-1655 per-user cap guard on the OCR structureRecipe retry [Pattern discovered]

Reviewed the uncommitted BUT-1655 change to `llm/ocr-retry.ts` + `llm/ocr-recipe-image.ts`
(commit-gate review). Verdict: **clean, no Critical/High/Medium.** tsc clean; `ocr-retry.test.ts`
21/21; `llm-kill-switch` 6/6, `ocr-handwritten-prompt` 6/6, `ocr-validation` 21/21.

The retry calls the UNWRAPPED `runStructureRecipe` (not the `withRateLimit`-wrapped callable),
so it bypassed BOTH caps `withRateLimit` normally applies. BUT-1561 already added the global
cap gate; this adds the per-user one. Both are dependency-injected `() => Promise<boolean>`
seams on `RetryDeps`, default-to-allow when omitted (unit tests). New `RetryOutcome` member
`skipped_user_limit`.

Verified against all five review axes, all clean:
1. **Guard ordering correct.** `ocr-retry.ts` Guard 4 (per-user, ~L198) runs STRICTLY before
   Guard 5 (global, ~L220). This mirrors BUT-1577's per-user-before-global ordering so an
   over-cap user's denied retry never reaches `checkGlobalLimit` (which check-AND-increments
   the shared `system/llmLimits` counter) — an over-cap user therefore cannot inflate the
   global counter.
2. **Same operation key/cost — no new operationType.** The in-core default resolver is
   `checkRateLimit(opts.userId, "structureRecipe").then(r => r.allowed)` — reuses the existing
   `structureRecipe` RATE_LIMITS key (rate_limiter.ts:91) with default `tokensRequired=1`
   (rate_limiter.ts:325). So an image-import-that-retries consumes 1 `structureRecipe` token,
   same bucket as the text primary path — intentional, bounded.
3. **Raw userId required, never logged.** `userId: string` is REQUIRED (not optional) on
   `OcrCoreOptions` so the compiler forces every call site to wire it — an unwired caller can't
   silently fail open on an abuse cap. Grep-confirmed userId appears only at the onCall wrapper
   pass (`request.auth!.uid`), the type decl, a doc comment, and the `checkRateLimit` doc key —
   never in a `logger.*` call. All logging/timing/sample-capture stays on `authUidHash`.
4. **No idempotency/retry-storm regression.** `ocrRecipeImage` is an `onCall` callable (not a
   Firestore trigger with `retry:true`), so no auto-retry storm surface. `checkRateLimit` is
   check-and-consume in one transaction, fails CLOSED on Firestore error (a false result skips
   the retry → rawText fallback, same user-visible outcome as a failed retry, no budget spent).
   The retry hits the UNWRAPPED `runStructureRecipe`, so no double rate-limit consumption inside
   the retry itself.
5. **Tests prove the ordering.** The BUT-1655 per-user-deny scenario asserts BOTH
   `globalChecked === 0` AND `calls.length === 0` on deny — that `globalChecked === 0` is the
   ordering lock: if a refactor moved the per-user guard after the global one, `globalChecked`
   flips to 1 and the test fails. The allow scenario asserts both gates checked once in order →
   success; a third scenario proves fail-closed (`checkUserLimit → false` skips).

**Info (accepted design, not a finding):** on the per-user-allow-but-global-deny path the
per-user token is already consumed (check-and-consume) yet the retry is suppressed — a user
"spends" a `structureRecipe` token for no retry. This is inherent to the BUT-1577 ordering
(per-user consume must precede the global check to protect the shared counter) and is the same
tradeoff the wrapped path carries; not introduced here.

**Pattern**: when a retry/fallback path calls an UNWRAPPED core (`runStructureRecipe`,
`runOcrRetry`) instead of the `withRateLimit`-wrapped callable, it silently bypasses BOTH the
per-user AND global caps — audit for each separately. The per-user gate must be re-applied via
`checkRateLimit(uid, <sameOperationKey>)` (reuse the wrapped callable's key, don't invent an
operationType), placed BEFORE the global gate (BUT-1577 ordering), and its raw uid made a
REQUIRED param so no call site can fail open. Ordering is provable in a Layer-1 test by
asserting the global seam's call count is 0 on a per-user deny.

### 2026-07-25 — BUT-1664 sendNotificationBatch per-notification billing [Pattern discovered]

Reviewed working-tree diff: `functions/src/notifications/send-notification.ts`,
`functions/src/middleware/rate_limiter.ts`,
`functions/src/__tests__/send-notification.test.ts`.

**What the change does.** `sendNotificationBatch` used to charge ONE token from the
*single-send* `sendNotification` bucket regardless of batch size, so 100 pushes cost the
same as 1 — the batch path was ~100x cheaper to abuse than the loop it replaces. The diff
extracts `preflightNotificationBatch({callerUid, notifications, rateLimit?})`, validates
`Array.isArray` + `length <= MAX_BATCH_NOTIFICATIONS (100)` BEFORE charging, then charges
the dedicated `sendNotificationBatch` bucket `Math.max(1, notifications.length)` tokens.
Bucket resized `maxTokens 10→100`, `refillRate 5→30`. Six new table-driven cases; suite
green at 13/13 via `npm run test:send-notification` (script already wired in package.json,
so the recurring CI-invisibility trap does not apply here). `npm run build` clean.

**Verdict: the billing fix itself is correct and a real tightening.** Old ceiling was 60
batch calls x 100 = 6000 notifications in a burst (single-send bucket, 60 tokens);
new ceiling is 100 notifications burst + 30/min sustained.

**Finding 1 (High) — validation is collected but not enforced until after the auth loop.**
Unchanged by this diff but now the dominant cost hole the diff is trying to close. Order in
the callable is: preflight charge → `forEach` collects `validationErrors` (no throw) →
`uniqueTargets = notifications.map(n => n.targetUserId)` → serial per-target authorization
loop (1–3 Firestore reads each, up to 100 targets) → THEN
`throw HttpsError("invalid-argument", ...)`. Two consequences:
(a) `{notifications:[null]}` makes `n.targetUserId` throw a raw TypeError before the
    invalid-argument throw is ever reached; the callable returns `internal`, which this
    very file's BUT-641 comment (line ~162) says "would also trigger client retry" — so a
    poison-pill batch becomes a retry+recharge loop;
(b) a 100-item batch that is entirely invalid still pays up to ~300 Firestore reads.
Both close with a one-line move: throw the `validationErrors` block immediately after the
`forEach`, before `uniqueTargets`. Root enabler is `return notifications as
NotificationRequest[]` in the preflight — an `Array.isArray` check plus a cast asserts an
element shape nothing ever verified.

**Finding 2 (Medium) — `MAX_BATCH_NOTIFICATIONS` and `maxTokens` are coupled across two
files with nothing enforcing it.** Both are 100 today, so a full batch is admitted (a
first-request bucket starts full and `100 < 100` is false). Raise the payload cap above
`maxTokens` and EVERY max-size batch is denied permanently — `currentTokens` can never
reach `tokensRequired`, and the computed retryAfter (ceil(needed/refillRate) intervals)
never helps. The rate_limiter comment documents the dependency; a comment is not a gate.

**Finding 3 (Medium) — denials lose their abuse telemetry.** `preflightNotificationBatch`
calls bare `checkRateLimit` and hand-throws `resource-exhausted`, skipping
`logRateLimitViolation` and therefore the `system_events/rate_limit_violation` row. Every
other standalone callable in this repo (`verifySignupAge`, `logParseEvent`,
`logParseCorrection`, `logWebError`, `setProfileSearchability`) uses `enforceRateLimit`,
which does check + log + throw and already accepts `tokensRequired`. `notifications/` is
the outlier on both the single and batch paths.

**Finding 4 (Medium) — the wrapper wiring is unpinned.** All six new cases call the pure
core directly, so nothing proves `sendNotificationBatch` calls the preflight at all, nor
that it passes `request.data?.notifications` rather than `request.data` (both land on
`invalid-argument`, just with different messages — so the assertion must be on the message).
v2 `onCall` exports carry `.run()`; an oversized-batch case through `.run()` is
non-vacuous and needs no emulator because the size check precedes the rate-limit call.

**Finding 5 (Medium, pre-existing) — raw uids in logs.** Lines ~140 and ~602 interpolate
`callerUid`/target uids into `logger.warn` template strings. The repo convention is
`hashUid()` (rate_limiter.ts uses it in the sibling violation log) plus a structured second
arg rather than string interpolation.

**Finding 6 (Info) — no client calls this callable.** `grep httpsCallable` across `lib/`
finds no `sendNotificationBatch` call site, and there is no Dart mirror for either
notification bucket in `lib/core/rate_limiting/rate_limiter.dart` (that mirror covers CRUD/
social/import ops only). So the tightening carries zero in-app regression risk, and the
callable is a deployed-but-unused attack surface — a point in favour of the tighter bucket.

**Generalized into the principles file:** (1) idempotency rule 6 — collected-then-deferred
validation is not a gate, and an `Array.isArray`+cast never checks element shape;
(2) rate-limiting section — a per-ITEM charge couples `maxTokens` to the payload cap
(derive or pin, don't comment), split buckets are ADDITIVE so state the combined ceiling,
and standalone callables use `enforceRateLimit` for the violation row.

### 2026-07-25 — BUT-1664 re-review after automated fixes [Bug fixed]

Re-reviewed the same three files in the working tree after the fix pass:
`functions/src/notifications/send-notification.ts`,
`functions/src/middleware/rate_limiter.ts`,
`functions/src/__tests__/send-notification.test.ts`.

**Finding 1 (High) from the 2026-07-25 first pass is CLOSED and the fix is correct.**
The deferred `validationErrors` block was extracted into an exported
`assertBatchValid(notifications: unknown[])` that throws immediately, and the callable
now reads: auth -> `preflightNotificationBatch` (Array.isArray, size<=100, charge
`sendNotificationBatch` by count) -> `assertBatchValid` -> `uniqueTargets` -> per-target
auth loop. A `null`/primitive/`undefined` element therefore terminates as
`invalid-argument` before any dereference and before any Firestore read, killing the
`internal`->client-retry->recharge loop. `validateNotification` already handled falsy
elements (`if (!notification) return "notification object is required"`), so the extraction
needed no new element checks. Verified green: `npm run build` clean; `npm run
test:send-notification` 18/18 (was 13/13 — five `assertBatchValid` cases added: valid
batch, `[null]`, `[42,"nope"]`, one-bad-element, missing targetUserId). Sibling suites
unaffected: `test:rate-limiter-daily-cap` 12/12, `test:rate-limiter-refill` 5/5,
`test:rate-limiter-ordering` 2/2, `test:app-check-enforcement` 15/15,
`test:notification-rate-cap` 8/8.

**Behaviour change worth naming:** for a batch that is BOTH invalid and unauthorized, the
error code flips from `permission-denied` to `invalid-argument`. Correct precedence (the
cheap terminal check first), no client depends on it (still no `sendNotificationBatch`
call site in `lib/`).

**No new Critical/High introduced.** The charge still lands before element validation —
that is deliberate and desirable (a poison-pill batch should cost the abuser budget), and
it costs only the single rate-limit transaction.

**Findings 2–5 from the first pass remain OPEN, unchanged by this pass:**
- (Medium) `MAX_BATCH_NOTIFICATIONS = 100` (send-notification.ts) vs
  `RATE_LIMIT_CONFIGS.sendNotificationBatch.maxTokens = 100` (rate_limiter.ts) still
  coupled by comment only. Confirmed by grep: no test in `functions/src/__tests__`
  references either constant. The new "full-size batch (100) is charged 100 and still
  admitted" case STUBS the bucket, so it pins the charge amount, not the admission — the
  permanent-deny failure mode is still untested.
- (Medium) `preflightNotificationBatch` still calls bare `checkRateLimit` + hand-thrown
  `resource-exhausted`, so a batch denial writes no `system_events/rate_limit_violation`
  row. `enforceRateLimit(uid, "sendNotificationBatch", n)` already takes `tokensRequired`.
- (Medium) Handler wiring still unpinned: all 11 batch cases call the exported cores
  directly. Nothing proves the callable calls preflight before `assertBatchValid` before
  the auth loop — i.e. the very ordering this fix pass established. `sendNotificationBatch.run()`
  with an oversized payload is non-vacuous and emulator-free.
- (Medium, pre-existing) Raw uids interpolated into `logger.warn` template strings at
  lines ~141 and ~637; repo convention is `hashUid()` + structured second arg.
- (Low, new phrasing) The `sendNotificationBatch` config comment claims the sustained
  per-notification budget "is the same whichever path a caller uses". True per path, but
  the buckets are ADDITIVE — a caller working both paths sustains 60 notifications/min.

**Generalized into the principles file:** nothing new. Every item above already maps to an
existing principle — idempotency rule 6 (validate-then-throw immediately), the rate-limiting
section (per-ITEM charge couples maxTokens to the payload cap; `enforceRateLimit` for the
violation row; additive split buckets), the logging section (hash all PII-ish log fields),
and the test-seam section (a fix living in the handler-level gate cannot be pinned by a
pure-core unit suite). This re-review is confirmation, not a new pattern.
