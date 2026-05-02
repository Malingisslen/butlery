# ADR-001: Single retry layer for Gemini API calls — client-side only

**Status:** Accepted (2026-05-02)
**Ticket:** BUT-566
**Supersedes:** none

## Context

Calls to Google's Gemini API can fail with transient 5xx errors (rate limit, server overload, model unavailable). Without a deliberate retry policy, both the Flutter client and the Cloud Functions backend could independently retry the same logical request. With two retry layers stacked, a transient outage that resolves after 1 client retry would have already issued `client_retries × server_retries` API calls — multiplying load against the very rate limit that caused the failure.

Today the topology is:

- **Client (`lib/services/parsing/tiers/llm_tier.dart:120-128`)** — wraps `llmService.structureRecipe(...)` in `RetryHelper.retryNetworkOperation(..., maxRetries: 2)`. Exponential backoff via `lib/core/utils/retry_helper.dart` (base 1s, cap 30s).
- **Server (`functions/src/llm/structure-recipe.ts:316-336`)** — `catch (error)` block converts any non-`HttpsError` into a generic `internal` `HttpsError` and throws. There is no `try`/loop around the `generateContent` call.

The current behavior is "client retries; server fails fast." This ADR ratifies that as the policy.

## Decision

**Gemini API retries happen exclusively at the client layer.** The Cloud Functions backend MUST NOT add retry logic around `model.generateContent()` or any other Gemini SDK call. Server-side errors propagate as `HttpsError` and the client decides whether to retry.

**Retry budget (client):**
- `maxRetries: 2` (i.e. up to 3 total attempts: 1 initial + 2 retries)
- Exponential backoff base 1000ms, cap 30000ms
- `RetryHelper.retryNetworkOperation` controls eligibility (network/timeout/transient errors retried; validation/auth/4xx errors not retried)

## Rationale

1. **Avoid rate-limit amplification.** If the server retries 3× and the client retries 3×, a single user-visible attempt issues up to 9 Gemini calls. Under load, this turns a 1% transient failure rate into a 9% Gemini rate-limit hit rate.
2. **Idempotency lives at the request boundary.** Gemini's `generateContent` is not naturally idempotent (model temperature, sampling). Retrying changes the output. The client can decide to re-prompt the user with the same input; the server cannot.
3. **Cost visibility.** Each Gemini call is billed. Retries inflate the cost. Concentrating retries at the client keeps the per-attempt cost predictable and surfaces it in client-side logs that already aggregate `estimatedCost`.
4. **Operational clarity.** When debugging a parse failure, "client tried 3 times" + "server tried once each" beats compounding multiplicities.

## Implications

- **New server code MUST NOT** add `for`/`while` loops around `generateContent()`, nor wrap it in any retry helper.
- **Existing server code** at `structure-recipe.ts:316-336` is the canonical pattern: catch → classify (rate limit vs other) → throw `HttpsError` → done.
- **Client retry tuning** (changing `maxRetries`, base/cap delay) is the only knob. If Gemini rate-limit incidents become frequent, the answer is to *reduce* client `maxRetries`, not to add server retries.
- **Idempotency keys** are not currently passed; if Gemini supports them in the future, they should be set client-side and threaded through the call so retries become safe even if the policy changes.

## Cross-references

- Server entry point comment: `functions/src/llm/structure-recipe.ts:316` (catch block) — references this ADR.
- Client retry call: `lib/services/parsing/tiers/llm_tier.dart:120-128`.
- Retry helper implementation: `lib/core/utils/retry_helper.dart`.
- Prompt-version traceability: `functions/src/llm/PROMPT_CHANGELOG.md` (BUT-669).
