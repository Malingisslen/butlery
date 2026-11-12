import 'package:butlery/core/utils/season_utils.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/meal_slot_mapper.dart';
import 'package:butlery/services/tagging/config/cuisine_config.dart';

abstract final class SwapCandidates {
  /// Filters recipes eligible for swap: matches category, not in menu.
  static List<Recipe> filterEligible(
    List<Recipe> pool,
    Set<String> excludeIds,
    String category,
  ) {
    return pool.where((recipe) {
      if (excludeIds.contains(recipe.id)) return false;

      return fitsMealSlot(recipe.mealType, category);
    }).toList();
  }

  /// Scores candidates and picks the highest. Ties are broken randomly.
  static Recipe scoreAndPickBest(List<Recipe> candidates, Recipe current) {
    final seasonTag = SeasonUtils.currentSeasonTag();
    final currentCuisine = extractCuisine(current);
    final currentCategory = menuMealKey(current.mealType);

    var bestScore = -1;
    final bestCandidates = <Recipe>[];

    for (final candidate in candidates) {
      var score = 0;

      // +3 same cuisine
      if (currentCuisine != null) {
        final candidateCuisine = extractCuisine(candidate);
        if (candidateCuisine == currentCuisine) score += 3;
      }

      // +2 same category
      if (menuMealKey(candidate.mealType) == currentCategory) score += 2;

      // +1 seasonal match
      final tags = candidate.tagResult?.tags;
      if (tags != null && tags.contains(seasonTag)) score += 1;

      if (score > bestScore) {
        bestScore = score;
        bestCandidates
          ..clear()
          ..add(candidate);
      } else if (score == bestScore) {
        bestCandidates.add(candidate);
      }
    }

    bestCandidates.shuffle();
    return bestCandidates.first;
  }

  static String? extractCuisine(Recipe recipe) =>
      CuisineConfig.extractCuisineTag(recipe);
}
