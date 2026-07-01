/// Personalisation signals for weekly-menu recipe selection (BUT-1320 + BUT-1321).
///
/// Holds the per-generation inputs derived from the current user's profile and
/// pantry, plus the gentle multiplicative nudges they produce. Kept separate
/// from [MenuService] so the static weighting stays a pure function of
/// (recipe, context) and every nudge is unit-testable in isolation.
library;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/tagging/config/cuisine_config.dart';

/// Complexity bucket derived from a recipe's cook time (primary) or step
/// count (fallback). `unknown` means we have no signal and must not bias.
enum _Complexity { simple, moderate, complex, unknown }

/// Immutable, per-generation scoring inputs.
///
/// Every field defaults to "no signal", so [MenuScoringContext.empty] leaves
/// the weight math byte-for-byte unchanged — generation behaves exactly as it
/// did before personalisation when no profile/pantry is supplied.
class MenuScoringContext {
  /// recipeId → pantry ingredient overlap in [0, 1] (1.0 = every ingredient of
  /// the recipe is already on hand). Precomputed once per generation from
  /// `PantryService.getMatchingRecipes`; recipes absent from the map get no
  /// boost (never a penalty).
  final Map<String, double> pantryMatchByRecipeId;

  /// Cuisine tags the user has marked as favourites (CuisineConfig tags, the
  /// same values `CuisineConfig.extractCuisineTag` returns).
  final Set<String> cuisineAffinities;

  /// The user's self-reported cooking skill, or null when unknown.
  final CookingSkillLevel? skill;

  const MenuScoringContext({
    this.pantryMatchByRecipeId = const {},
    this.cuisineAffinities = const {},
    this.skill,
  });

  /// A context that applies no personalisation — the identity for the weight
  /// multiplier (always yields 1.0).
  static const MenuScoringContext empty = MenuScoringContext();

  /// Pantry boost ceiling: a recipe whose every ingredient is on hand gets at
  /// most this multiplier. Deliberately below the rating ceiling (1.4x) and the
  /// season boost (1.5x) so it nudges without dominating recency or ratings.
  static const double pantryMaxBoost = 1.3;

  /// Cuisine-affinity boost for a recipe whose cuisine is in the user's
  /// favourites. A gentle nudge, not a filter.
  static const double cuisineAffinityBoost = 1.25;

  /// Skill-bias multipliers. Beginners get a small lift toward simpler/faster
  /// recipes and a small down-weight (never exclusion) away from very complex
  /// ones; advanced cooks get a slight lift toward complex recipes. All are
  /// kept below the rating ceiling so skill is a tiebreaker, never a filter —
  /// a beginner still sees complex recipes they can grow into.
  static const double beginnerSimpleBoost = 1.15;
  static const double beginnerComplexPenalty = 0.85;
  static const double advancedComplexBoost = 1.1;

  /// The largest multiplier the skill bias can ever apply. Exposed so tests can
  /// assert it stays under the rating ceiling.
  @visibleForTesting
  static const double maxSkillBoost = beginnerSimpleBoost;

  /// Cook-time thresholds (minutes) for the complexity bucket.
  static const int _simpleMaxMinutes = 30;
  static const int _complexMinMinutes = 60;

  /// Step-count thresholds used only when a recipe has no cook time.
  static const int _simpleMaxSteps = 5;
  static const int _complexMinSteps = 10;

  /// The combined personalisation nudge is capped at this ceiling — strictly
  /// below the rating boost (`MenuService.debugMaxRatingBoost`, 1.4×) — so a
  /// highly-rated recipe always out-weights an unrated one no matter how well it
  /// personalises. Without the cap the three nudges would compound to ~1.87×,
  /// letting an unrated pantry-staple recipe overtake a household 5★ favourite;
  /// the cap makes "rating is the strongest nudge; personalisation is a
  /// tiebreaker" a real aggregate guarantee, not just a per-signal one.
  static const double maxCombinedBoost = 1.35;

  /// Combined gentle multiplier for [recipe]: the product of the pantry,
  /// cuisine-affinity and skill-bias nudges, capped at [maxCombinedBoost] so it
  /// never overtakes the rating signal. Always > 0 (every recipe stays
  /// selectable) and exactly 1.0 for [empty]. The cap only bites the upper end,
  /// so the beginner skill down-weight (0.85×) is preserved.
  double multiplierFor(Recipe recipe) {
    final combined =
        _pantryMultiplier(recipe) *
        _cuisineMultiplier(recipe) *
        _skillMultiplier(recipe);
    return combined < maxCombinedBoost ? combined : maxCombinedBoost;
  }

  double _pantryMultiplier(Recipe recipe) {
    final overlap = pantryMatchByRecipeId[recipe.id];
    if (overlap == null || overlap <= 0) return 1.0;
    final clamped = overlap.clamp(0.0, 1.0);
    return 1.0 + clamped * (pantryMaxBoost - 1.0);
  }

  double _cuisineMultiplier(Recipe recipe) {
    if (cuisineAffinities.isEmpty) return 1.0;
    final cuisine = CuisineConfig.extractCuisineTag(recipe);
    if (cuisine == null) return 1.0;
    return cuisineAffinities.contains(cuisine) ? cuisineAffinityBoost : 1.0;
  }

  double _skillMultiplier(Recipe recipe) {
    final level = skill;
    if (level == null) return 1.0;
    final complexity = _complexityOf(recipe);
    if (complexity == _Complexity.unknown) return 1.0;

    switch (level) {
      case CookingSkillLevel.beginner:
        if (complexity == _Complexity.simple) return beginnerSimpleBoost;
        if (complexity == _Complexity.complex) return beginnerComplexPenalty;
        return 1.0;
      case CookingSkillLevel.advanced:
        if (complexity == _Complexity.complex) return advancedComplexBoost;
        return 1.0;
      case CookingSkillLevel.intermediate:
        return 1.0;
    }
  }

  static _Complexity _complexityOf(Recipe recipe) {
    final minutes = recipe.core.timeMinutes;
    if (minutes != null) {
      if (minutes <= _simpleMaxMinutes) return _Complexity.simple;
      if (minutes >= _complexMinMinutes) return _Complexity.complex;
      return _Complexity.moderate;
    }
    final steps = recipe.core.instructions.length;
    if (steps == 0) return _Complexity.unknown;
    if (steps <= _simpleMaxSteps) return _Complexity.simple;
    if (steps >= _complexMinSteps) return _Complexity.complex;
    return _Complexity.moderate;
  }
}
