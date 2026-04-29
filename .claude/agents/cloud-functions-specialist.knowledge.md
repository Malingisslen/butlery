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
