# LLM Golden Tests

Closed-loop quality measurement for Butlery's 6 LLM-driven flows (BUT-784).

## What this prevents

Every prompt or model upgrade is a leap of faith without goldens. Three failure modes
that goldens catch and PR review can't:

1. **Quality regression** — parser starts missing ingredients it used to catch.
2. **Format drift** — model returns markdown when JSON was expected.
3. **Cost spike** — prompt change silently doubles token usage.

## What's where

| Path | Purpose |
|------|---------|
| `test/golden/llm/README.md` | Case format, runner contract |
| `test/golden/llm/_golden_runner.dart` | Case loader + scoring (foundation only) |
| `test/golden/llm/<corpus>/cases.json` | Per-corpus golden cases |
| `.github/workflows/golden-llm.yml` | Nightly cron + manual dispatch |
| `docs/testing/llm-golden-tests.md` | This document |

## The 6 corpora (planned)

| Corpus | Status | Scoring | Cost per run |
|--------|--------|---------|--------------|
| `categorize_ingredient` | foundation (10 seed cases) | `exact` | free (on-device) |
| `ner` | foundation (5 seed cases) | `jaccard ≥ 0.80` | free (on-device) |
| `recipe_from_url` | deferred → follow-up | `similarity ≥ 0.85` | ~$0.10/run |
| `ocr_recipe` | deferred → follow-up | `similarity ≥ 0.85` | ~$0.20/run |
| `enhance_recipe` | deferred → follow-up | `similarity ≥ 0.85` | ~$0.15/run |
| `generate_menu` | deferred → follow-up | `jaccard ≥ 0.70` on ingredient set | ~$0.20/run |

Hard cap: `$1.00` per nightly run. Exceeded = the cost guard fails the workflow and
opens a regression issue.

## Workflow

### Adding a case

1. Pick a corpus directory under `test/golden/llm/`.
2. Append a row to `cases.json` with a unique stable `id` and a HUMAN-VALIDATED
   `expected` field (never paste current model output as expected — circular).
3. Run the corpus locally; confirm the new case passes against the current model.
4. Commit.

### Investigating a regression

1. Find the failing case ids in the nightly's `golden-llm-summary-<run-id>` artifact.
2. Pull the case from `cases.json` and re-run locally with the latest model.
3. Decide:
   - **The new output is wrong** → revert the prompt change.
   - **The new output is right** (model legitimately improved or our gold was outdated)
     → update `expected`, commit alongside the change that triggered it.
4. **Never weaken tolerance just to go green** — destroys signal.

### Cost guard fired — what now

A nightly that exceeded `$COST_CAP_USD` (default `$1.00`) means a recent change is
burning more tokens than expected. Triage:

1. Check the workflow's run log for per-corpus `tokens_in`/`tokens_out` totals.
2. Compare against the most recent green nightly to identify the corpus that spiked.
3. Inspect the prompt change in that area's git log.
4. Either revert, optimize the prompt, or (if the spend is justified) bump the cap
   with the BUT-XXX ticket explaining why.

## Why this is foundation-only right now

The wave-8 sprint that filed BUT-784 shipped:

- Directory + case JSON schema
- Skeleton runner with case loading + scoring contract
- Nightly CI workflow + cost-guard plumbing
- Seed cases for the 2 free (on-device) corpora

The live model wiring per corpus is intentionally split into 4 follow-up tickets so
each can ship with the corpus that depends on it. The 2 free corpora can ship without
external service credentials; the 4 paid corpora need Vertex AI / Mistral API access
configured in CI, which is its own setup pass.

## Relationship to other work

- **BUT-626** — prompt A/B bucketing (different concern — measures which variant
  performs better; goldens measure absolute quality regression).
- **HIGH-AI4** — adversarial fixtures (separate ticket — stress-test inputs vs
  baseline regression suite).
