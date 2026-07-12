/// Personalisation signals for weekly-menu recipe selection (BUT-1321 pantry,
/// BUT-1516 pooled "Butlery-betyget" community rating).
///
/// Holds the per-generation inputs derived from the current user's pantry and
/// the pooled community ratings, plus the gentle multiplicative nudges they
/// produce. Kept separate from [MenuService] so the static weighting stays a
/// pure function of (recipe, context) and every nudge is unit-testable in
/// isolation.
///
/// History: cuisine-affinity + cooking-skill nudges (BUT-1320) were removed in
/// BUT-1594 — the weekly menu is drawn from the user's OWN saved recipes, an
/// already-taste-curated set, so weighting it by cuisine/skill double-counted
/// taste. Those remain *discovery* signals on the profile, not menu signals.
library;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart'
    show PooledStats;

/// Immutable, per-generation scoring inputs.
///
/// Every field defaults to "no signal", so [MenuScoringContext.empty] leaves
/// the weight math byte-for-byte unchanged — generation behaves exactly as it
/// did before personalisation when no pantry/pooled data is supplied.
class MenuScoringContext {
  /// recipeId → pantry ingredient overlap in [0, 1] (1.0 = every ingredient of
  /// the recipe is already on hand). Precomputed once per generation from
  /// `PantryService.getMatchingRecipes`; recipes absent from the map get no
  /// boost (never a penalty).
  final Map<String, double> pantryMatchByRecipeId;

  /// recipeId → the pooled community stats for that recipe's dish (poolKey),
  /// as read from `canonical_recipe_stats/{poolKey}` (BUT-1516). Only recipes
  /// whose pool has a stat doc appear; recipes absent from the map — or present
  /// but below the display floor — get no boost. Populated only when the
  /// `enable_pooled_ratings` flag is on (empty otherwise, so this is a strict
  /// no-op while the feature is dark).
  final Map<String, PooledStats> pooledStatsByRecipeId;

  const MenuScoringContext({
    this.pantryMatchByRecipeId = const {},
    this.pooledStatsByRecipeId = const {},
  });

  /// A context that applies no personalisation — the identity for the weight
  /// multiplier (always yields 1.0).
  static const MenuScoringContext empty = MenuScoringContext();

  /// Pantry boost ceiling: a recipe whose every ingredient is on hand gets at
  /// most this multiplier. Deliberately below the rating ceiling (1.4x) and the
  /// season boost (1.5x) so it nudges without dominating recency or ratings.
  static const double pantryMaxBoost = 1.3;

  /// Pooled-rating shrinkage prior (BUT-1516). The dish's raw pooled average is
  /// pulled toward this global mean by [pooledShrinkageC] phantom votes for
  /// *ranking only* (never the displayed average — decision 8). No global-mean
  /// artifact exists in the data, so this is a documented, tunable constant.
  static const double pooledPriorMean = 3.5;

  /// Bayesian-shrinkage strength: phantom votes at [pooledPriorMean]. ≈10 per
  /// the ticket — so a 5★ dish with 5 votes cannot outrank a 4.6★ dish with 200.
  static const double pooledShrinkageC = 10.0;

  /// Pooled-rating boost ceiling (a shrunk score of 5.0) and floor (a shrunk
  /// score of 1.0). The floor down-weights but never excludes a dish (matching
  /// the old beginner-complexity penalty), and the ceiling sits below the
  /// personal/family rating boost (1.4x) so your own verdict always outweighs
  /// the crowd's.
  static const double pooledMaxBoost = 1.3;
  static const double pooledMinFactor = 0.85;

  /// The combined personalisation nudge is capped at this ceiling — strictly
  /// below the rating boost (`MenuService.debugMaxRatingBoost`, 1.4×) — so a
  /// highly-rated recipe always out-weights an unrated one no matter how well it
  /// personalises. The cap only bites the upper end, so a pooled down-weight
  /// (0.85×) is preserved. Keeps "rating is the strongest nudge; personalisation
  /// is a tiebreaker" a real aggregate guarantee, not just a per-signal one.
  static const double maxCombinedBoost = 1.35;

  /// The largest single-signal boost the pooled nudge can apply. Exposed so
  /// tests can assert it stays under the rating ceiling.
  @visibleForTesting
  static const double maxPooledBoost = pooledMaxBoost;

  /// Combined gentle multiplier for [recipe]: the product of the pantry and
  /// pooled-rating nudges, capped at [maxCombinedBoost] on the upper end so it
  /// never overtakes the rating signal. Always > 0 (every recipe stays
  /// selectable) and exactly 1.0 for [empty]. The cap only clamps the upper end,
  /// so the pooled down-weight (0.85×) is preserved.
  double multiplierFor(Recipe recipe) {
    final combined = _pantryMultiplier(recipe) * _pooledMultiplier(recipe);
    return combined < maxCombinedBoost ? combined : maxCombinedBoost;
  }

  double _pantryMultiplier(Recipe recipe) {
    final overlap = pantryMatchByRecipeId[recipe.id];
    if (overlap == null || overlap <= 0) return 1.0;
    final clamped = overlap.clamp(0.0, 1.0);
    return 1.0 + clamped * (pantryMaxBoost - 1.0);
  }

  /// Bayesian-shrunk pooled-rating nudge (BUT-1516). No-op (1.0) when the recipe
  /// has no pool, or its pool is below the display floor ([PooledStats.displayFloor],
  /// n≥5). Otherwise the raw pooled average is shrunk toward [pooledPriorMean]
  /// and mapped to a gentle multiplier centred on the prior: a shrunk score
  /// above the prior boosts (up to [pooledMaxBoost] at 5★), below the prior
  /// down-weights (down to [pooledMinFactor] at 1★), and exactly at the prior is
  /// neutral (1.0).
  double _pooledMultiplier(Recipe recipe) {
    final stats = pooledStatsByRecipeId[recipe.id];
    if (stats == null || !stats.meetsDisplayFloor) return 1.0;

    // meetsDisplayFloor guarantees average != null.
    final average = stats.average!;
    final shrunk =
        (pooledShrinkageC * pooledPriorMean + stats.count * average) /
        (pooledShrinkageC + stats.count);

    if (shrunk >= pooledPriorMean) {
      final fraction = (shrunk - pooledPriorMean) / (5.0 - pooledPriorMean);
      return 1.0 + fraction * (pooledMaxBoost - 1.0);
    }
    final fraction = (pooledPriorMean - shrunk) / (pooledPriorMean - 1.0);
    return 1.0 - fraction * (1.0 - pooledMinFactor);
  }
}
