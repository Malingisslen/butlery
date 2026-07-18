/// Tag-accuracy scorecard CI gate (BUT-1489).
///
/// Mirrors the CRF golden-gate pattern (BUT-1443, `crf_evaluator_test.dart`):
/// a deterministic evaluation that runs the REAL tagging pipeline against a
/// COMMITTED, human-verified golden dataset, scores it through the tag
/// scorecard's own scoring engine (`tools/corpus/tag_metrics.dart`), and
/// enforces numeric accuracy floors — so a regression that degrades tag
/// accuracy, or (worst of all) claims an allergen is FREE when the answer key
/// says otherwise, fails CI.
///
/// Why this file and not `test/corpus/tag_scorecard_test.dart`: that harness is
/// a PREDICTION-ONLY script that requires the external, uncommitted cookbook
/// corpus (`BUTLERY_CORPUS_DIR`) and never scores — it cannot gate CI. The
/// scorecard's scoring engine, however, is pure Dart and can run against the
/// committed golden set here, exactly as the CRF gate runs against
/// `test/golden/crf_ingredients.json`.
///
/// This lives in `test/evaluation/`, which is already wired into the CI suite
/// matrix (`.github/workflows/test.yml` → `suite-tests` → `evaluation`), so no
/// workflow change is needed — dropping the file in gates it, same as the CRF
/// evaluator.
///
/// The golden data (`test/golden/tagging_golden_dataset.json`) is the same
/// human-verified set the binary golden test (`test/golden/tagging_golden_test.dart`)
/// asserts verdict-by-verdict. This gate is complementary: it reports the
/// aggregate scorecard summary (allergen accuracy, the false-FREE safety count,
/// dietary accuracy) and gates on numeric floors rather than per-key equality.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/services/tagging/tag_generator.dart';

import '../infrastructure/builders/recipe_builder.dart';
import '../../tools/corpus/tag_metrics.dart';
import '../../tools/corpus/tag_models.dart';

/// Allergen accuracy floor. The committed golden set currently scores 100%
/// (the binary golden test proves every verdict), so this leaves generous
/// headroom while still failing a broad regression.
const double _allergenAccuracyFloor = 0.90;

/// Dietary accuracy floor — dietary verdicts are lower-stakes than allergens.
const double _dietaryAccuracyFloor = 0.85;

/// Hard safety gate: the tagger must NEVER claim FREE for an allergen the
/// answer key marks CONTAINS or UNKNOWN. This is the one metric that can harm
/// an allergic user, so it is gated at absolute zero, not a rate.
const int _maxAllergenFalseFree = 0;

void main() {
  late TagGenerator generator;
  late List<dynamic> dataset;

  setUpAll(() {
    generator = TagGenerator();
    final file = File('test/golden/tagging_golden_dataset.json');
    if (!file.existsSync()) {
      fail(
        'Golden dataset not found at test/golden/tagging_golden_dataset.json. '
        'Run from the project root.',
      );
    }
    dataset = jsonDecode(file.readAsStringSync()) as List;
  });

  test('tag scorecard: allergen/dietary accuracy floors + zero false-FREE', () {
    final scores = <RecipeTagScore>[];

    for (final raw in dataset) {
      final entry = raw as Map<String, dynamic>;
      final expected = (entry['expected'] as Map<String, dynamic>?) ?? const {};

      final recipe = RecipeBuilder()
          .withId(entry['id'] as String)
          .withTitle(entry['title'] as String)
          .withIngredients((entry['ingredients'] as List).cast<String>())
          .withInstructions((entry['instructions'] as List).cast<String>())
          .withTimeMinutes(entry['timeMinutes'] as int?)
          .build();

      final matched = (entry['matched'] as List)
          .cast<Map<String, dynamic>>()
          .map(
            (m) => IngredientData(
              id: m['id'] as String,
              swedish: m['swedish'] as String,
              english: m['english'] as String,
              group: m['group'] as String,
              properties: (m['properties'] as List).cast<String>().toSet(),
            ),
          )
          .toList();

      final lookup = IngredientLookupResult.fromLists(
        matched: matched,
        unmatched: (entry['unmatched'] as List).cast<String>(),
      );

      final result = generator.generate(ingredients: lookup, recipe: recipe);

      scores.add(scoreRecipeTags(_goldFrom(expected), _predictionFrom(result)));
    }

    final summary = summarizeTags(scores);

    // Print the scorecard summary so a CI log shows the real numbers.
    // ignore: avoid_print
    print(
      '\n=== Tag scorecard (committed golden set) ===\n'
      '  Recipes scored     : ${summary.count}\n'
      '  Allergen accuracy  : ${(summary.allergens.accuracy * 100).toStringAsFixed(1)}% '
      '(${summary.allergens.correct}/${summary.allergens.total})\n'
      '  Allergen FALSE-FREE: ${summary.allergens.falseFree} (safety)\n'
      '  Allergen missed-CON: ${summary.allergens.missedContains}\n'
      '  Dietary accuracy   : ${(summary.dietary.accuracy * 100).toStringAsFixed(1)}% '
      '(${summary.dietary.correct}/${summary.dietary.total})\n',
    );

    expect(
      summary.allergens.falseFree,
      lessThanOrEqualTo(_maxAllergenFalseFree),
      reason:
          'SAFETY: tagger claimed FREE for an allergen the golden set marks '
          'CONTAINS/UNKNOWN ${summary.allergens.falseFree} time(s). Must be 0.',
    );
    expect(
      summary.allergens.accuracy,
      greaterThanOrEqualTo(_allergenAccuracyFloor),
      reason:
          'Allergen accuracy ${(summary.allergens.accuracy * 100).toStringAsFixed(1)}% '
          '< floor ${(_allergenAccuracyFloor * 100).toStringAsFixed(0)}% '
          '(${summary.allergens.correct}/${summary.allergens.total})',
    );
    expect(
      summary.dietary.accuracy,
      greaterThanOrEqualTo(_dietaryAccuracyFloor),
      reason:
          'Dietary accuracy ${(summary.dietary.accuracy * 100).toStringAsFixed(1)}% '
          '< floor ${(_dietaryAccuracyFloor * 100).toStringAsFixed(0)}% '
          '(${summary.dietary.correct}/${summary.dietary.total})',
    );
  });
}

/// Builds the pure-Dart answer key from a golden entry's `expected` block.
GoldTags _goldFrom(Map<String, dynamic> expected) => GoldTags(
  verified: true,
  allergens: _triMap(expected['allergens']),
  dietary: _triMap(expected['dietary']),
);

/// Maps the real [TagResult] onto the scorecard's pure-Dart prediction struct,
/// exactly as the corpus harness does at the pipeline boundary.
PredictedTags _predictionFrom(TagResult result) => PredictedTags(
  allergens: {
    for (final e in result.allergenStatus.entries)
      e.key: TagTriState.fromString(e.value.name),
  },
  dietary: {
    for (final e in result.dietaryStatus.entries)
      e.key: TagTriState.fromString(e.value.name),
  },
  tags: result.tags,
  coverage: result.coverage,
  unmatchedIngredients: result.unknownIngredients.length,
);

Map<String, TagTriState> _triMap(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final e in raw.entries)
      e.key.toString(): TagTriState.fromString(e.value?.toString()),
  };
}
