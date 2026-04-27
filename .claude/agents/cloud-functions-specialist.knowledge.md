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
