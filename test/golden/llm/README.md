# LLM Golden Tests

Closed-loop quality measurement for the 6 LLM-driven flows in Butlery (BUT-784).

## What lives here

```
test/golden/llm/
├── README.md                    ← this file
├── _golden_runner.dart          ← case loader + scoring contract (foundation only)
├── categorize_ingredient/
│   └── cases.json               ← 10 seed cases (Swedish ingredient → category)
├── ner/
│   └── cases.json               ← 5 seed cases (Swedish sentence → entity spans)
├── recipe_from_url/             ← deferred — see BUT-XXX (file follow-up)
├── ocr_recipe/                  ← deferred
├── enhance_recipe/              ← deferred
└── generate_menu/               ← deferred
```

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
