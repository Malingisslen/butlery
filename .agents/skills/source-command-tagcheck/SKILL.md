---
name: "source-command-tagcheck"
description: "Run the tag-accuracy scorecard (allergen safety first) and report results in plain language"
---

# source-command-tagcheck

Use this skill when the user asks to run the migrated source command `tagcheck`.

## Command Template

Run the **tag-accuracy scorecard**: regenerate the tagging pipeline's predictions
against the current code, score them against the hand-verified answer keys, and
report the result for a non-coder (Malin reads every summary; she does not read code).

This is an offline, deterministic, **free** check — no network, Firebase, or paid
LLM calls. It scores the real tagging pipeline against an in-memory snapshot of the
ingredient DB (`scripts/crf/data/firebase_ingredients.json`). The corpus lives
outside the repo at `../butlery-corpus/`.

## Arguments
- (none) — full run: regenerate predictions, then score.
- `--score-only` — skip regeneration; just re-score the existing predictions
  (use when the tagging code hasn't changed since the last run).
- `--web` — ALSO run the web-import eval (`tools/web_eval.dart`) and report it.

## Steps

1. **Regenerate predictions** (skip if `--score-only`):
   ```
   RUN_TAG_SCORECARD=1 /c/tools/flutter/bin/flutter test test/corpus/tag_scorecard_test.dart
   ```
   This re-runs the real tagger over every verified recipe and rewrites each
   `tags.draft.json`. Note the console lines (how many predicted, their coverage).

2. **Score** against the answer keys:
   ```
   /c/tools/flutter/bin/dart run tools/tag_scorecard.dart
   ```
   It prints a summary and writes `../butlery-corpus/_reports/tags/scorecard-<ts>.json`.
   A non-zero exit with "No verified tag answer keys scored" is **not an error** —
   it means no `tags.gold.json` has been hand-verified yet (see step 4).

3. **If `--web`**, also run and report:
   ```
   /c/tools/flutter/bin/dart run tools/web_eval.dart
   ```

4. **Report to Malin in plain language.** Lead with the outcome, no jargon:
   - **The safety number first:** the **false-FREE** count/rate — how often the app
     said a recipe is *free* of an allergen when the truth was "contains" or "we
     can't tell." This is the one that could harm someone; it should be **zero**.
     Call out every false-FREE recipe by name if any exist.
   - **Coverage:** the share of ingredients the database recognized. Remind her that
     below 100% coverage the app must answer "unknown" for allergens — so low
     coverage, not wrong rules, is usually why allergen badges go missing.
   - **Allergen + dietary accuracy**, then classification-tag F1 (secondary).
   - **Movement vs last time:** read the two most recent files in
     `../butlery-corpus/_reports/tags/` and state what changed (better/worse/flat).
     If this is the first run, say so.
   - **Coverage of the check itself:** how many recipes were scored vs skipped, and
     why skipped (almost always "answer key not verified yet").

5. **If little/nothing was scored**, tell her plainly that the tool is ready but
   needs hand-verified answer keys: edit `../butlery-corpus/<book>/<recipe>/tags.gold.json`,
   fill in the correct allergen/dietary verdicts, set `"verified": true`, then re-run
   `/tagcheck`. This is reading-and-correcting, not coding.

## Notes
- Do not commit anything — this is a read/measure command. The corpus and its
  reports live outside the repo and are never committed.
- If `flutter test` reports the harness as skipped, the `RUN_TAG_SCORECARD=1` env
  var didn't reach it — re-run with the env var prefixed exactly as above.
