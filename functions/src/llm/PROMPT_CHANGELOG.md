# LLM Prompt Changelog

Append-only log of changes to the LLM system prompts that drive recipe extraction. Bump `PROMPT_VERSION` in [`gemini-client.ts`](./gemini-client.ts) and add an entry here in the same commit.

## Why this exists

When parse quality moves (recall, precision, ingredient-count drift, OCR error rate), we need to correlate the change to a specific prompt edit. The version constant alone doesn't tell us **what changed** or **why** — git blame is slower and noisier than this single file.

This log serves three downstream consumers:
1. **Quality measurement** — when activation/import-success metrics shift, look up which prompt version was live during the regression window.
2. **A/B testing** ([BUT-626](https://linear.app/butlery/issue/BUT-626)) — variant labels need stable, ordered version strings.
3. **Remote Config prompts** ([BUT-621](https://linear.app/butlery/issue/BUT-621)) — when a Remote Config override is rolled out, its baseline must be a logged version.

## Format

Each entry leads with the version + ship date, then four sections:

```
## v<MAJOR>.<MINOR>.<PATCH> — YYYY-MM-DD

**What changed:** one-line summary of the prompt diff.

**Why:** the constraint, bug, metric, or ticket that motivated the change.

**Expected impact:** the directional move we predict in metrics — recall up, false-positive ingredient count down, OCR retry rate down, etc.

**Linked metrics / tickets:** BUT-XXX, dashboard URL, parse-quality-loop run.
```

**Versioning rule of thumb:**
- **PATCH** — typo fix, whitespace, single-word swap, no behavioural change expected.
- **MINOR** — new instruction added, output format clarified, examples adjusted; behaviour change expected but backward-compatible parser.
- **MAJOR** — output schema change (parser must update), tone/role pivot, model swap.

**Append-only.** Never edit a published entry. If a prompt was reverted, log the revert as a new entry referencing the original.

---

## v2.1.0 — 2026-05-04 (current)

**What changed:** `INGREDIENT_LINE_SYSTEM_PROMPT` expanded from 2 to 6 few-shot examples. Added EXEMPEL 3 (unicode-bråkdelar: ½ tsk, ¼ kopp, 1½ dl), EXEMPEL 4 (parenthetical weights: "kycklingfilé (ca 600 g)"), EXEMPEL 5 ("ca"/"cirka"/"ungefär" approximations resolved to numeric amounts with `cirka` in preparation), and EXEMPEL 6 (instruction-text leaking into the ingredient list, recovered as low-info preparation). No schema or output-shape change — additive few-shot bulk only.

**Why:** [BUT-676](https://linear.app/butlery/issue/BUT-676) — parse-quality reports flagged that 2 examples sat at the low end of what a Swedish-specific structured-extraction task needs to lock onto edge cases. The four added cases each correspond to a real failure pattern observed in user imports (fractions in baking recipes, parenthetical brand-pack weights, "ca"-prefixed approximations, and ingredient-list rows that turned out to be instructions).

**Expected impact:** Higher recall + amount accuracy on the four pattern families above; minor token-count increase per request (~120 tokens at p99). Watch parse-correction-rate dashboard for regression — if any worsens, the `EXEMPEL 6` instruction-leak case is the most likely culprit (training the model to extract from instructions can over-extract from clean ingredient lists).

**Linked metrics / tickets:** [BUT-676](https://linear.app/butlery/issue/BUT-676). Re-run parse-quality goldens before/after.

---

## v2.0.0 — 2026-04-26

**What changed:** Remote Config prompts + `promptVersion` threading + OCR cache key fix. The `PROMPT_VERSION` constant in `gemini-client.ts` became the canonical version source; downstream Cloud Functions (`structure-recipe.ts`, `ocr-recipe-image.ts`) now record the version that produced each result onto the parse output (`promptVersion` field), and the OCR result cache keys it so prompt revisions invalidate stale cached extractions automatically.

**Why:** [BUT-621](https://linear.app/butlery/issue/BUT-621) (Remote Config prompts) — needed an authoritative version field threaded through every parse path so quality regressions could be attributed to specific prompt edits rather than guessed from git blame. [BUT-606](https://linear.app/butlery/issue/BUT-606) and [BUT-666](https://linear.app/butlery/issue/BUT-666) addressed the OCR-side gaps that made cache invalidation flaky when prompts moved.

**Expected impact:** No direct extraction-quality movement (this was a plumbing change). Enables future A/B work without re-piping. Cache hit rate may dip transiently when v2.x → v3.0 ships, by design.

**Linked metrics / tickets:** [BUT-621](https://linear.app/butlery/issue/BUT-621), [BUT-606](https://linear.app/butlery/issue/BUT-606), [BUT-666](https://linear.app/butlery/issue/BUT-666). Commit `4f0c65af0`.

---

## Backfilled history (pre-changelog)

The entries below are reconstructed from git log for context. They are **not** guaranteed to match the precise prompt-version semantics adopted from v2.0.0 forward. Use them for narrative, not for metric attribution.

### v1.x era — 2025-Q4

- **`001c2f5e1`** — On-device BERT NER for ingredients moved off the LLM into a local inference path. The LLM ingredient-line prompt narrowed scope: it now handles parsing ingredients only when NER cannot match (fallback path), reducing token spend ~60%.
- **`00635cf84`** — LLM prompt improvements + line-level routing + model unification. Multiple prompts converged on a single Mistral model; `INGREDIENT_LINE_SYSTEM_PROMPT` was extracted as a discrete constant for the per-line fallback case.
- **`f38edf76a`** — Initial smart recipe import system with multi-strategy parsing. Prompts here were authored from scratch.

---

## Adding a new entry — checklist

When you bump `PROMPT_VERSION`:

1. Edit the prompt source (`gemini-client.ts` / `structure-recipe.ts` / `ocr-recipe-image.ts` / `INGREDIENT_LINE_SYSTEM_PROMPT`).
2. Bump `PROMPT_VERSION` in `gemini-client.ts:25` (PATCH/MINOR/MAJOR per the rule above).
3. Add a new entry **above** the previous most-recent entry in this file (newest first).
4. Reference the Linear ticket and any metric/dashboard you expect to move.
5. If reverting, link the original entry being reverted.
6. CI lint (planned, not yet active): a `PROMPT_VERSION` bump without a corresponding changelog entry will warn on PR.

## See also

- [`gemini-client.ts`](./gemini-client.ts) — `PROMPT_VERSION` constant + `INGREDIENT_LINE_SYSTEM_PROMPT`
- [`structure-recipe.ts`](./structure-recipe.ts) — recipe structuring prompt
- [`ocr-recipe-image.ts`](./ocr-recipe-image.ts) — OCR system prompt
- [`prompts-config.ts`](./prompts-config.ts) — Remote Config override path with `FALLBACK_PROMPT_VERSION` re-export
