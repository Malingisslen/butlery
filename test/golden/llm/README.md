# LLM Golden Tests

Closed-loop quality measurement for the 6 LLM-driven flows in Butlery (BUT-784).

`_golden_runner.dart` is the case loader + scoring contract. Live corpora: `categorize_ingredient/`,
`adversarial/`, `ner/` (each a `cases.json`). The model-driven corpora are deferred — see Follow-ups.

## Case schema

Every `cases.json` is a flat array of objects matching this shape:

```jsonc
{
  "id": "string — stable identifier; never reuse",
  "input": "string | object — what the model receives",
  "expected": "string | object — the gold answer",
  "tolerance": "exact | similarity | jaccard — how to score",
  "tags": ["optional", "fixture", "labels"],
  "notes": "optional reviewer notes, e.g. why this case matters"
}
```

Scoring tolerances:

| Tolerance | Meaning | Used for |
|-----------|---------|----------|
| `exact` | `==` after trim+lowercase | `categorize_ingredient` (label is a fixed enum) |
| `similarity` | cosine-sim ≥ 0.85 between `expected` and actual | free-text fields (titles, instructions) |
| `jaccard` | set-jaccard ≥ 0.80 between expected and actual span lists | `ner` (entity-span overlap) |

## Adversarial corpus (BUT-804 / HIGH-AI4)

`adversarial/cases.json` holds prompt-injection, jailbreak, and structural-attack
inputs. It is scored against `IngredientCategorizer.categorize` — the one
LLM-adjacent flow that is fully deterministic and bundled (no model, no Firebase,
no platform channel), so it runs on every CI shard with zero API cost.

The contract under test (`adversarial_test.dart`) is **safe schema output**: for
every adversarial input the categorizer must (1) not throw, (2) return a member
of `ShoppingCategory.all`, and (3) never echo the raw payload back as the
category. Injection/jailbreak directives are inert against a rule engine; cases
that embed a real ingredient (`lök`, `smör`, `lax`) still resolve to the correct
bucket, proving the attack cannot redirect classification. The test will fail
loudly the day a "smarter" (LLM-backed) categorizer starts echoing input or
emitting free-form labels.

Control-char attacks are stored as JSON `\uXXXX` escapes so the fixture stays
text-safe on disk while `jsonDecode` materializes the real bytes at load time.

The remaining HIGH-AI4 surface — adversarial corpora for the **model-driven**
flows (OCR retry, recipe-from-URL, menu generation) — needs live API calls plus
a cost guard and is tracked as an ops follow-up alongside AI1/AI5/AI6/AI8.

## Run locally

```bash
# Run all corpora (foundation only — actual model wiring is per-corpus follow-up)
dart test test/golden/llm/_golden_runner.dart

# Single corpus (when the per-corpus runner lands)
dart test test/golden/llm/categorize_ingredient/
```

## Run in CI

`.github/workflows/golden-llm.yml` schedules a nightly run. Failures emit a Crashlytics
non-fatal event (`llm_golden_regression`) tagged with the failing case id so we can
triage which input regressed without re-running locally.

The workflow is intentionally NOT a per-PR gate — full corpora call paid APIs and
take minutes. PR-time quality signal comes from unit tests; the goldens are the
quality canary for prompt + model changes.

## Cost guard

The runner records `tokens_in` + `tokens_out` per case (where applicable — the on-device
corpora `categorize_ingredient` and `ner` are free). If a nightly run exceeds the
budget cap declared in the workflow (`COST_CAP_USD`, default `$1.00`), the job fails
loudly so a runaway prompt change doesn't silently burn budget.

## Updating expected outputs

A model upgrade or intentional prompt change will fail goldens — that's the point.
To accept the new output as the new baseline:

1. Re-run the failing corpus locally.
2. Diff the `actual` output against `expected` in the failing case(s).
3. If the new output is genuinely better (manually reviewed), update `expected` in
   `cases.json`.
4. Commit with the prompt change and reference the BUT- ticket driving the upgrade.

Never weaken `tolerance` to make tests pass — that destroys the signal.

## Adding new cases

1. Pick a corpus directory.
2. Append to `cases.json` with a unique `id` (next sequential number or a short slug).
3. The `expected` field MUST be hand-validated by a human; don't paste the model's
   current output back as "expected" — that's circular validation.

## Follow-ups (Linear tickets to be filed)

The wave-8 sprint shipped foundation only. These require real model-call wiring + cost guard:

- **recipe_from_url** — 20-30 input URLs + expected ingredient/instruction extraction (`similarity` scoring).
- **ocr_recipe** — 20 sample images + expected text (`similarity`).
- **enhance_recipe** — 15 input recipes + expected enhancement deltas (`similarity`).
- **generate_menu** — 10 prompt sets + expected structure (`jaccard` on the ingredient set).

For the on-device corpora (`categorize_ingredient`, `ner`), the runner just needs to be
wired against the existing `ShoppingListGenerator._categorizeIngredient` and the NER
model loader. Both are still TODO — see `_golden_runner.dart` skeleton.
