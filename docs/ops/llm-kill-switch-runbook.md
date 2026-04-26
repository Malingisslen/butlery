# LLM kill-switch runbook (BUT-439)

This runbook explains how to disable Vertex AI LLM features in Butlery in
an incident — partial outages (single prompt regressing), cost spikes,
abuse, or a regulatory pause. Two independent gates exist; both are
documented here.

## TL;DR

- **Total kill** (every Vertex call across the app): set Firestore doc
  `system/config.aiEnabled = false`. Effective in <1 minute.
- **Recipe-parse kill only** (OCR vision and other future LLM features
  remain live): set `system/config.llmParserEnabled = false`.
- **Client-side mirror** for fast UI short-circuit: Remote Config booleans
  `ai_enabled` and `llm_parser_enabled`. Slower propagation (12 h default
  fetch interval).

The Firestore gate is **authoritative**. Remote Config is **advisory** —
it short-circuits the client UI before the user spends a rate-limit
token, but a stale-config client cannot bypass the Firestore gate.

## Architecture: dual-control gates

Two gates, two sources of truth, deliberately layered:

| Layer | Source of truth | Path | Latency |
|-------|-----------------|------|---------|
| Server | Firestore | `system/config` (single doc) | <1 min |
| Client | Firebase Remote Config | `ai_enabled`, `llm_parser_enabled` | up to 12 h (Flutter default) |

Decision: option (a) — keep `aiEnabled` as master and add
`llmParserEnabled` as per-feature granular kill. Rationale: a regressed
prompt in the recipe parser shouldn't take down OCR vision or any future
LLM feature. The two-flag layered control is cheap to add and covers a
real incident class observed in the prompt-update pipeline.

## Server-side enforcement (authoritative)

Both gates are checked at the entry point of every Vertex-calling Cloud
Function. Audit (current state):

| Function | File | Gate placement | Status |
|----------|------|----------------|--------|
| `structureRecipe` | `functions/src/llm/structure-recipe.ts:117-138` | inside `runStructureRecipe`, before any `getGeminiClient()` call | OK — checks both `aiEnabled` and `llmParserEnabled` |
| `ocrRecipeImage` | `functions/src/llm/ocr-recipe-image.ts:218-226` | inside `runOcrRecipeImage` via `defaultIsAiDisabled` test seam | OK — checks `aiEnabled` only (vision); the OCR text-mode retry calls `runStructureRecipe` which enforces `llmParserEnabled` |
| `ocr-retry.ts` (orchestrator) | `functions/src/llm/ocr-retry.ts` | does not call Vertex directly | OK — delegates to `runStructureRecipe`, which gates |
| `gemini-client.ts` | `functions/src/llm/gemini-client.ts` | utility wrapper, no entry point | OK — never invoked outside the gated functions |

**Verdict:** every Vertex-calling function in `functions/src/llm/` is
gated at entry. No bypass.

### Fail-open vs fail-closed

- **Doc missing or field missing** → AI proceeds (fail open).
  *Why:* fresh deployments before ops runs the seed script must not
  block users. Documented behavior.
- **Firestore unreachable** → outer `catch` turns it into an `internal`
  HttpsError (fail closed for the user).
  *Why:* a Firestore outage is not a license to bypass the gate.
- **Remote Config unreachable on client** → AI proceeds locally; server
  gate still enforces. Client check is purely a UX optimisation.

The trade-off: a brand-new project (no `system/config` doc yet) starts
with AI on. This is intentional — bootstrapping the doc is the deploy
step that makes the kill-switch usable in the first place. We accept the
"first day = no kill switch" gap because (a) it can be created in <1 min
on day 1, (b) prompt regressions and cost spikes are not a day-1 concern.

## Operator commands

### Total kill (`aiEnabled=false`)

Kills every Vertex LLM call across the app. Use when:

- Cost spike detected and we cannot localise the source quickly.
- Vertex AI service incident and we want to fail fast instead of
  retrying expensive calls.
- Regulatory pause (EU AI Act, partner request).

**Firebase Console** (preferred for non-engineers):
1. Open https://console.firebase.google.com/project/_/firestore/databases/-default-/data
2. Navigate to `system/config`. If the doc doesn't exist, click "+ Add
   document", id `config`, in collection `system`.
3. Add field `aiEnabled` (boolean) = `false`.
4. Effective immediately on the next request (no caching).

**gcloud / Firestore CLI** (preferred for incident automation):
```sh
gcloud firestore documents update system/config \
  --update-mask=aiEnabled \
  --data='{"aiEnabled": {"booleanValue": false}}' \
  --project="$PROJECT_ID"
```

**Server-callable snippet** (for an admin tool):
```ts
await admin.firestore().doc("system/config").set(
  { aiEnabled: false, killedAt: FieldValue.serverTimestamp(), killedBy: operatorEmail },
  { merge: true }
);
```

### Per-feature kill (`llmParserEnabled=false`)

Kills only the recipe-parse pipeline (`structureRecipe` + the OCR
text-mode retry path). Vision OCR (`ocrRecipeImage` first pass) stays
live. Use when:

- A new prompt version is producing junk output and we want to stop
  shipping bad parses while debugging.
- Selective ingredient-line parsing is misbehaving.

Same flip pattern as above with field name `llmParserEnabled`.

### Re-enabling

Set the field to `true` (or delete it — missing field = AI on by design).
Same propagation latency: <1 min server-side, up to 12 h client-side
(force-fresh by calling `FirebaseRemoteConfig.instance.fetchAndActivate()`
from a debug build, or the user can pull-to-refresh after the fetch
interval expires).

### Client-side mirror (Remote Config)

For UX consistency — a long-running web tab won't try to call a function
the server is going to deny. Set the same booleans in Remote Config:

```sh
firebase remoteconfig:get --project "$PROJECT_ID" -o /tmp/rc.json
# edit /tmp/rc.json — set ai_enabled and/or llm_parser_enabled to false
firebase remoteconfig:set /tmp/rc.json --project "$PROJECT_ID"
```

Or via the Console: https://console.firebase.google.com/project/_/config

## Per-user cap (`llmMaxDailyInvocationsPerUser`)

**Status:** **already exists** — implemented in the existing rate
limiter, no new infra needed.

Lives in `lib/services/import/import_rate_limiter.dart` (client) and is
enforced server-side via `functions/src/middleware/rate_limiter.ts`
(`structureRecipe`: 10 tokens, refill 3/min; `ocrRecipeImage`: 5 tokens,
refill 2/min). Daily caps are derived from the refill rate × 1440 min;
to set a stricter daily cap that doesn't replenish, the rate-limiter
schema would need a separate "daily ceiling" field.

If a hard daily cap separate from the per-minute bucket is required,
that is **out of scope** for BUT-439 and would land as a follow-up
ticket: extend `RateLimitConfig` with `dailyMaxInvocations` and store a
24-h rolling counter on the same Firestore doc.

## Monitoring & alerting

Cloud Logging filters that surface kill-switch trips:

- `severity=INFO` AND `jsonPayload.message:"AI-funktioner är tillfälligt avstängda"`
  → master kill firing.
- `severity=INFO` AND `jsonPayload.message:"AI-receptolkning är tillfälligt avstängd"`
  → per-feature kill firing.

Alert on either firing >100 times/hour (indicates user-visible incident
that ops should ack).

Cost dashboard:
https://console.cloud.google.com/billing/_/reports?project=$PROJECT_ID
filter by service "Vertex AI" — the kill switch's effect is visible
within 10–15 min on the running 1-h cost line.

## Test coverage

End-to-end test: `functions/src/__tests__/llm-kill-switch.test.ts`.

Proves:
1. Master kill (`aiEnabled=false`) blocks `structureRecipe` before any
   Vertex call.
2. Per-feature kill (`llmParserEnabled=false`) blocks `structureRecipe`
   with a different error message.
3. Both flags absent / true → `structureRecipe` proceeds to the
   Vertex client (test seam returns a stub recipe).
4. Master kill propagates through `runOcrRecipeImage` (vision path).

Run with:

```sh
cd functions && npm run test:kill-switch
```

## Decision log

- **2026-04-26 (BUT-439):** chose option (a) layered control. Rationale:
  the per-feature flag covers a real incident class (prompt regression on
  the parser) without breaking the master kill. Renaming `aiEnabled`
  would have required coordinating client + server + Remote Config flips
  in lockstep — too much risk for a kill-switch sprint.
- **2026-04-26 (BUT-439):** per-user cap deemed already covered by the
  existing rate-limiter. No new flag introduced. If a calendar-day hard
  cap is later required, separate ticket.

## SDK migration history

- **2026-04-22 (BUT-614):** swapped Cloud Functions LLM SDK to
  `@google-cloud/vertexai` (Vertex AI EU region). Replaced the Gemini
  Developer API path so all inference runs in `europe-west4` for GDPR
  data-residency. `getGeminiClient()` (`functions/src/llm/gemini-client.ts`)
  is the canonical wrapper; every Vertex call routes through it.
- **2026-04-27 (BUT-499):** verified cleanup of the deprecated
  `@google/generative-ai` package. Confirmed zero source imports
  (`functions/src/`) and zero entries in `functions/package.json` /
  `package-lock.json`. The Linear ticket called out `@google/genai` as a
  successor, but the project's chosen SDK is `@google-cloud/vertexai`
  (per BUT-614) — no further migration required. Task resolved as
  no-op cleanup verification; kill-switch + structureRecipe + ocr
  test suites unchanged.
