/// Scoring for the tag-accuracy scorecard.
///
/// Pure Dart, deterministic, side-effect-free — the always-green core that runs
/// under `dart test`. Compares the tagging pipeline's [PredictedTags] against a
/// hand-verified [GoldTags] answer key.
///
/// Allergen/dietary verdicts are scored as THREE distinct classes
/// (contains/free/unknown) — never collapsed to a boolean. The headline safety
/// metric is the **false-FREE rate**: how often we claimed FREE when the truth
/// was CONTAINS or UNKNOWN. That is the error that can harm an allergic user.
library;

import 'corpus_metrics.dart';
import 'tag_models.dart';

/// Score for one tri-state map (allergens OR dietary) on one recipe.
///
/// Scored over the keys the answer key ASSERTS — a partial answer key only
/// grades what it claims. A predicted value absent from the map is treated as
/// [TagTriState.unknown] (the tagger's own safe default).
class TriStateScore {
  /// Keys scored (== number of gold assertions).
  final int total;

  /// Predicted verdict exactly matched gold.
  final int correct;

  /// DANGEROUS: predicted FREE where gold was CONTAINS or UNKNOWN. Overclaims
  /// safety — the metric that must trend to zero.
  final int falseFree;

  /// Gold was CONTAINS but we did not say CONTAINS (missed a real allergen).
  /// NOT mutually exclusive with [falseFree]: a predicted FREE on a CONTAINS
  /// key increments both (it is at once a false safety claim and a missed
  /// allergen).
  final int missedContains;

  const TriStateScore({
    required this.total,
    required this.correct,
    required this.falseFree,
    required this.missedContains,
  });

  /// Vacuously perfect when there is nothing to grade.
  double get accuracy => total == 0 ? 1.0 : correct / total;
  double get falseFreeRate => total == 0 ? 0.0 : falseFree / total;

  TriStateScore operator +(TriStateScore o) => TriStateScore(
    total: total + o.total,
    correct: correct + o.correct,
    falseFree: falseFree + o.falseFree,
    missedContains: missedContains + o.missedContains,
  );

  static const zero = TriStateScore(
    total: 0,
    correct: 0,
    falseFree: 0,
    missedContains: 0,
  );
}

/// Compares a predicted tri-state map against the gold answer key. Iterates the
/// GOLD keys only; missing predictions count as [TagTriState.unknown].
TriStateScore scoreTriStateMap(
  Map<String, TagTriState> gold,
  Map<String, TagTriState> predicted,
) {
  var correct = 0;
  var falseFree = 0;
  var missedContains = 0;

  for (final entry in gold.entries) {
    final want = entry.value;
    final got = predicted[entry.key] ?? TagTriState.unknown;

    if (got == want) correct++;
    if (got == TagTriState.free && want != TagTriState.free) falseFree++;
    if (want == TagTriState.contains && got != TagTriState.contains) {
      missedContains++;
    }
  }

  return TriStateScore(
    total: gold.length,
    correct: correct,
    falseFree: falseFree,
    missedContains: missedContains,
  );
}

/// Full per-recipe tag score: allergens, dietary, and (optional) classification
/// tags as set-style precision/recall/F1 (reusing [Prf]).
class RecipeTagScore {
  final TriStateScore allergens;
  final TriStateScore dietary;

  /// Classification-tag P/R/F1. Only meaningful when [tagsAsserted] is true.
  final Prf tags;

  /// Whether the answer key asserted any classification tags. When false,
  /// [tags] is vacuous and this recipe is excluded from the corpus tag-F1 mean.
  final bool tagsAsserted;

  final double coverage;
  final int unmatchedIngredients;

  const RecipeTagScore({
    required this.allergens,
    required this.dietary,
    required this.tags,
    required this.tagsAsserted,
    required this.coverage,
    required this.unmatchedIngredients,
  });
}

/// Scores one recipe end-to-end.
RecipeTagScore scoreRecipeTags(GoldTags gold, PredictedTags predicted) {
  // Classification tags are scored ONLY when the answer key asserts at least
  // one. An empty expectedTags means "not annotated" (e.g. an allergen-only
  // answer key), NOT "no tags expected" — so the recipe is excluded from the
  // tag-F1 mean rather than scored a vacuous 1.0 that would hide hallucinated
  // tags. When tags ARE asserted, the real predicted count is used so extra
  // (false-positive) tags lower precision.
  final tagsAsserted = gold.expectedTags.isNotEmpty;
  final tagsPrf = tagsAsserted
      ? Prf.from(
          matched: gold.expectedTags.intersection(predicted.tags).length,
          goldCount: gold.expectedTags.length,
          predCount: predicted.tags.length,
        )
      : Prf.from(matched: 0, goldCount: 0, predCount: 0);

  return RecipeTagScore(
    allergens: scoreTriStateMap(gold.allergens, predicted.allergens),
    dietary: scoreTriStateMap(gold.dietary, predicted.dietary),
    tags: tagsPrf,
    tagsAsserted: tagsAsserted,
    coverage: predicted.coverage,
    unmatchedIngredients: predicted.unmatchedIngredients,
  );
}

/// Corpus-level aggregate. Tri-state metrics aggregate by SUMMING counts (so a
/// recipe with 21 allergens weighs more than one with 2 — the natural
/// per-verdict denominator), while tag-F1 and coverage are means over recipes.
class TagSummary {
  final int count;
  final TriStateScore allergens;
  final TriStateScore dietary;
  final double meanTagF1;
  final double meanCoverage;

  const TagSummary({
    required this.count,
    required this.allergens,
    required this.dietary,
    required this.meanTagF1,
    required this.meanCoverage,
  });

  Map<String, dynamic> toJson() => {
    'count': count,
    'allergenAccuracy': _round(allergens.accuracy),
    'allergenFalseFree': allergens.falseFree,
    'allergenFalseFreeRate': _round(allergens.falseFreeRate),
    'allergenMissedContains': allergens.missedContains,
    'allergenVerdicts': allergens.total,
    'dietaryAccuracy': _round(dietary.accuracy),
    'dietaryFalseFree': dietary.falseFree,
    'dietaryFalseFreeRate': _round(dietary.falseFreeRate),
    'dietaryMissedContains': dietary.missedContains,
    'dietaryVerdicts': dietary.total,
    'meanTagF1': _round(meanTagF1),
    'meanCoverage': _round(meanCoverage),
  };
}

/// Aggregate per-recipe scores into a [TagSummary]. Pure — no IO.
TagSummary summarizeTags(List<RecipeTagScore> scores) {
  if (scores.isEmpty) {
    return const TagSummary(
      count: 0,
      allergens: TriStateScore.zero,
      dietary: TriStateScore.zero,
      meanTagF1: 0,
      meanCoverage: 0,
    );
  }

  final n = scores.length;
  final allergens = scores
      .map((s) => s.allergens)
      .fold(TriStateScore.zero, (a, b) => a + b);
  final dietary = scores
      .map((s) => s.dietary)
      .fold(TriStateScore.zero, (a, b) => a + b);
  // Tag-F1 averages ONLY over recipes whose answer key asserted tags, so
  // allergen-only answer keys don't dilute the classification metric.
  final asserted = scores.where((s) => s.tagsAsserted).toList();
  final meanTagF1 = asserted.isEmpty
      ? 0.0
      : asserted.map((s) => s.tags.f1).reduce((a, b) => a + b) /
            asserted.length;
  final meanCoverage =
      scores.map((s) => s.coverage).reduce((a, b) => a + b) / n;

  return TagSummary(
    count: n,
    allergens: allergens,
    dietary: dietary,
    meanTagF1: meanTagF1,
    meanCoverage: meanCoverage,
  );
}

double _round(double v) => double.parse(v.toStringAsFixed(4));
