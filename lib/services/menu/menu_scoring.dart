/// Personalisation signals for weekly-menu recipe selection (BUT-1321).
///
/// Holds the per-generation inputs derived from the current user's pantry, plus
/// the gentle multiplicative nudge they produce. Kept separate from
/// [MenuService] so the static weighting stays a pure function of
/// (recipe, context) and the nudge is unit-testable in isolation.
///
/// History: cuisine-affinity + cooking-skill nudges (BUT-1320) were removed in
/// BUT-1594 — the weekly menu is drawn from the user's OWN saved recipes, an
/// already-taste-curated set, so weighting it by cuisine/skill double-counted
/// taste. Those remain *discovery* signals on the profile, not menu signals.
library;

import 'package:butlery/models/recipe_unified.dart';

/// Immutable, per-generation scoring inputs.
///
/// Every field defaults to "no signal", so [MenuScoringContext.empty] leaves
/// the weight math byte-for-byte unchanged — generation behaves exactly as it
/// did before personalisation when no pantry data is supplied.
class MenuScoringContext {
  /// recipeId → pantry ingredient overlap in [0, 1] (1.0 = every ingredient of
  /// the recipe is already on hand). Precomputed once per generation from
  /// `PantryService.getMatchingRecipes`; recipes absent from the map get no
  /// boost (never a penalty).
  final Map<String, double> pantryMatchByRecipeId;

  const MenuScoringContext({
    this.pantryMatchByRecipeId = const {},
  });

  /// A context that applies no personalisation — the identity for the weight
  /// multiplier (always yields 1.0).
  static const MenuScoringContext empty = MenuScoringContext();

  /// Pantry boost ceiling: a recipe whose every ingredient is on hand gets at
  /// most this multiplier. Deliberately below the rating ceiling (1.4x) and the
  /// season boost (1.5x) so it nudges without dominating recency or ratings.
  static const double pantryMaxBoost = 1.3;

  /// The combined personalisation nudge is capped at this ceiling — strictly
  /// below the rating boost (`MenuService.debugMaxRatingBoost`, 1.4×) — so a
  /// highly-rated recipe always out-weights an unrated one no matter how well it
  /// personalises. With only the pantry signal live the cap is never reached
  /// (pantry tops out at [pantryMaxBoost], 1.3×), but it is kept as a defensive
  /// aggregate guarantee: "rating is the strongest nudge; personalisation is a
  /// tiebreaker" stays true even if more signals are re-added later.
  static const double maxCombinedBoost = 1.35;

  /// Gentle multiplier for [recipe]: the pantry nudge, capped at
  /// [maxCombinedBoost] so it never overtakes the rating signal. Always > 0
  /// (every recipe stays selectable) and exactly 1.0 for [empty].
  double multiplierFor(Recipe recipe) {
    final combined = _pantryMultiplier(recipe);
    return combined < maxCombinedBoost ? combined : maxCombinedBoost;
  }

  double _pantryMultiplier(Recipe recipe) {
    final overlap = pantryMatchByRecipeId[recipe.id];
    if (overlap == null || overlap <= 0) return 1.0;
    final clamped = overlap.clamp(0.0, 1.0);
    return 1.0 + clamped * (pantryMaxBoost - 1.0);
  }
}
