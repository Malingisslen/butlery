# CRF Ingredient Parser — Training & Testing Plan

The CRF model currently has hand-crafted weights. This plan covers training it on real data.

## Prerequisites

- Python 3.10+ with `python-crfsuite` and `scikit-learn`
- Dart SDK (for export and scraping scripts)
- Run `dart run scripts/crf/export_lexicons.dart` to generate `scripts/crf/data/lexicons.json`

## Step 1: Export Lexicons

```bash
dart run scripts/crf/export_lexicons.dart
```

Produces `scripts/crf/data/lexicons.json` — the shared lexicon file that `train_crf.py` reads. Must be re-run if `KnownIngredients`, `UnitDefinitions`, or `PreparationWords` change.

## Step 2: Collect Recipe URLs

Gather 100-200 URLs from Swedish recipe sites into `scripts/crf/data/urls.txt`:

```
https://www.ica.se/recept/...
https://www.koket.se/...
https://www.arla.se/recept/...
```

Target variety: baking, soups, salads, mains, desserts. Include recipes with compound quantities (ranges like "1-2"), fractions, and multi-word ingredient names.

## Step 3: Scrape Ingredient Lines

```bash
dart run scripts/crf/scrape_ingredients.dart < scripts/crf/data/urls.txt > scripts/crf/data/raw.txt
```

Expected: ~1500-3000 ingredient lines. Rate-limited (500ms between requests).

## Step 4: Auto-Annotate

```bash
dart run scripts/crf/auto_annotate.dart < scripts/crf/data/raw.txt > scripts/crf/data/training.conll
```

Uses the existing regex-based `IngredientParser` to bootstrap BIO labels. Output is CoNLL format (tab-separated `token\tlabel`, blank lines between sequences).

## Step 5: Manual Review (Optional but Recommended)

Sample ~500 lines and correct labeling errors. Focus on patterns the regex parser misses:
- Quantity ranges ("1-2", "ca 3")
- Compound ingredient names ("krossade tomater", "svarta bönor")
- Preparation phrases embedded in names ("hackad persilja")

## Step 6: Train

```bash
pip install python-crfsuite scikit-learn
python scripts/crf/train_crf.py \
  --input scripts/crf/data/training.conll \
  --output assets/data/crf_ingredient_weights.json
```

Prints a classification report with per-label precision/recall/F1. Target: >85% F1 on B-NAME, >90% on B-QTY and B-UNIT.

## Step 7: Verify

```bash
# Unit tests (must all pass)
flutter test test/unit/services/parsing/crf/

# Full parsing suite (must not regress)
flutter test test/unit/services/parsing/

# Analyze
flutter analyze lib/services/parsing/
```

## Step 8: Smoke Test

Test with 5-10 real ingredient lines manually:
```dart
final parser = CrfIngredientParser(decoder);
final result = parser.parseLine('2 dl vispgrädde');
// Expect: qty=2, unit=dl, name=vispgrädde
```

## Quality Checklist

- [ ] Lexicons exported (`dart run scripts/crf/export_lexicons.dart`)
- [ ] Training data collected (>1000 ingredient lines)
- [ ] Model trained with classification report reviewed
- [ ] F1 scores acceptable (>85% on NAME, >90% on QTY/UNIT)
- [ ] All existing CRF tests pass
- [ ] All parsing tests pass (no regression)
- [ ] `flutter analyze` clean
- [ ] Weights file committed (`assets/data/crf_ingredient_weights.json`)
