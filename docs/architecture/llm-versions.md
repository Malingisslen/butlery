# LLM Version Pin Runbook (BUT-785)

This runbook covers the Vertex AI Gemini model pin and the cadence for bumping
to a newer version. A single source of truth lives in
`functions/src/llm/gemini-client.ts`:

```ts
export const TEXT_MODEL = "gemini-2.0-flash-001";
export const MODEL_ID = TEXT_MODEL;
```

`MODEL_ID` is exported separately so analytics events stamp the actual model
used per call rather than a derived name.

## Why pin the version

Google reserves the right to update the moving alias `gemini-2.0-flash` at
any time. An alias rotation can shift:

- **Quality** — prompt regressions appear without code changes.
- **Cost** — pricing-tier bumps land silently.
- **Latency** — p95 / p99 distribution moves.
- **Schema fidelity** — newer snapshots may interpret JSON-schema responses
  differently.

Pinning to `-001` (or whichever stable snapshot is current) means the model
behind the call doesn't change underneath the golden-test suite or the cost
dashboards.

## Bump cadence

**Quarterly review.** Once per quarter, evaluate whether to bump to a newer
snapshot. The decision criteria:

1. **Golden tests pass.** Run the LLM golden corpus (BUT-784 — pending) on
   the candidate model. ≥95% pass rate is the bar.
2. **Cost delta ≤ 20%** vs the current pinned model on a representative
   sample of recent prompts (sample 50–100 calls from the past month).
3. **No regression on the prompt-changelog gate** (HIGH-AI8) — the candidate
   model must respect the schema-enforced JSON output without tightening.
4. **Vertex AI region pin still holds** (`europe-west1`). Pre-release
   snapshots are sometimes unavailable in EU regions; verify before pinning.

If all four pass, bump in a single PR that:

- Changes `TEXT_MODEL` in `gemini-client.ts`.
- Updates this doc with the new version + the date of the bump.
- Notes the golden-test pass rate and cost delta in the commit message.

## How to verify the pin in production

After deploy, every Vertex-fronted call writes `modelId` into the structured
log:

```
{ "event": "structure_recipe.complete", ..., "modelId": "gemini-2.0-flash-001" }
```

Cloud Logging filter to confirm rollout:

```
resource.type="cloud_function"
jsonPayload.event="structure_recipe.complete"
jsonPayload.modelId="gemini-2.0-flash-001"
```

A non-zero count for the new `modelId` within ~5 min of deploy confirms the
pin took effect.

The `modelId` is also threaded into the callable response so on-device
analytics events (`recipe_parse_completed`, `ocr_completed`) can correlate
quality / cost regressions to the version the call ran under.

## Cost telemetry

`calculateGeminiCost(usage)` lives next to `TEXT_MODEL` in
`gemini-client.ts`. Per-1M-token pricing is co-located with the model
constant so a version bump that changes pricing is a single-file change.

Pricing source: Vertex AI EU region, gemini-2.0-flash family —
[Vertex AI pricing](https://cloud.google.com/vertex-ai/generative-ai/pricing).
Re-verify on every bump.

## Bump history

| Date       | Pinned model              | Notes                                    |
| ---------- | ------------------------- | ---------------------------------------- |
| 2026-05-06 | `gemini-2.0-flash-001`    | Initial pin (BUT-785). Was the moving `gemini-2.0-flash` alias. |
