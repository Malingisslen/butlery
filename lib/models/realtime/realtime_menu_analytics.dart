/// Comprehensive realtime menu analytics providing advanced search, filtering, and intelligent insights for collaborative meal planning.

// lib/models/realtime/realtime_menu_analytics.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/models/tagging/tri_state.dart';

/// Comprehensive realtime menu analytics with advanced search, filtering, and intelligent insights for collaborative meal planning.
/// Provides complete analytical capabilities for menu data including multi-criteria search, nutritional analysis,
/// balance insights, and recommendation systems through focused analytical algorithms and Swedish-optimized content analysis.
/// This class serves as the intelligence layer for all menu analysis and optimization features.
class RealtimeMenuAnalytics {
  /// Search functionality for intelligent recipe discovery with multi-field text matching.

  /// Searches recipes across all menu categories using comprehensive text matching and ingredient analysis.
  static List<Recipe> searchRecipes(RealtimeMenuData data, String query) {
    if (query.isEmpty) return data.allUniqueRecipes;

    final lowerQuery = query.toLowerCase();
    final results = <Recipe>[];

    for (final recipes in data.menuSnapshot.values) {
      for (final recipe in recipes) {
        if (_recipeMatchesQuery(recipe, lowerQuery) &&
            !results.any((r) => r.id == recipe.id)) {
          results.add(recipe);
        }
      }
    }

    return results;
  }

  /// Checks if a recipe matches the search query using comprehensive field analysis.
  static bool _recipeMatchesQuery(Recipe recipe, String lowerQuery) {
    return recipe.core.title.toLowerCase().contains(lowerQuery) ||
        recipe.core.description.toLowerCase().contains(lowerQuery) ||
        recipe.core.ingredients.any(
            (ingredient) => ingredient.toLowerCase().contains(lowerQuery)) ||
        recipe.core.mealType.toLowerCase().contains(lowerQuery) ||
        (recipe.core.personalTags
                ?.any((pt) => pt.name.toLowerCase().contains(lowerQuery)) ??
            false);
  }

  /// Performs advanced multi-criteria recipe search with comprehensive filtering and intelligent matching.
  static List<Recipe> searchRecipesAdvanced(
    RealtimeMenuData data, {
    String? query,
    String? mealType,
    List<String>? tags,
    int? maxTimeMinutes,
    int? minPortions,
    int? maxPortions,
    double? minRating,
  }) {
    var results = data.allUniqueRecipes;

    // Apply text search filter
    if (query != null && query.isNotEmpty) {
      results = searchRecipes(data, query);
    }

    // Apply meal type filter
    if (mealType != null) {
      results = results
          .where((recipe) =>
              recipe.core.mealType.toLowerCase() == mealType.toLowerCase())
          .toList();
    }

    // Apply time filter
    if (maxTimeMinutes != null) {
      results = results
          .where((recipe) => (recipe.core.timeMinutes ?? 0) <= maxTimeMinutes)
          .toList();
    }

    // Apply portion filters
    if (minPortions != null) {
      results = results
          .where((recipe) => (recipe.core.portions ?? 0) >= minPortions)
          .toList();
    }
    if (maxPortions != null) {
      results = results
          .where((recipe) => (recipe.core.portions ?? 0) <= maxPortions)
          .toList();
    }

    // Apply rating filter
    if (minRating != null) {
      results = results
          .where((recipe) => (recipe.core.rating ?? 0.0) >= minRating)
          .toList();
    }

    // Apply tags filter
    if (tags != null && tags.isNotEmpty) {
      results = results.where((recipe) {
        final recipeTags = recipe.core.personalTagIds ?? [];
        return tags.every((tag) => recipeTags.contains(tag));
      }).toList();
    }

    return results;
  }

  /// Filter menu by specific meal type
  static Map<String, List<Recipe>> filterByMealType(
      RealtimeMenuData data, String mealType) {
    final filtered = <String, List<Recipe>>{};

    for (final entry in data.menuSnapshot.entries) {
      final matchingRecipes = entry.value
          .where((recipe) =>
              recipe.core.mealType.toLowerCase() == mealType.toLowerCase())
          .toList();
      if (matchingRecipes.isNotEmpty) {
        filtered[entry.key] = matchingRecipes;
      }
    }

    return filtered;
  }

  /// Filter menu by max cooking time
  static Map<String, List<Recipe>> filterByMaxTime(
      RealtimeMenuData data, int maxMinutes) {
    final filtered = <String, List<Recipe>>{};

    for (final entry in data.menuSnapshot.entries) {
      final matchingRecipes = entry.value
          .where((recipe) => (recipe.core.timeMinutes ?? 0) <= maxMinutes)
          .toList();
      if (matchingRecipes.isNotEmpty) {
        filtered[entry.key] = matchingRecipes;
      }
    }

    return filtered;
  }

  /// Filter menu by minimum rating
  static Map<String, List<Recipe>> filterByMinRating(
      RealtimeMenuData data, double minRating) {
    final filtered = <String, List<Recipe>>{};

    for (final entry in data.menuSnapshot.entries) {
      final matchingRecipes = entry.value
          .where((recipe) => (recipe.core.rating ?? 0.0) >= minRating)
          .toList();
      if (matchingRecipes.isNotEmpty) {
        filtered[entry.key] = matchingRecipes;
      }
    }

    return filtered;
  }

  /// Filter menu by tags
  static Map<String, List<Recipe>> filterByTags(
      RealtimeMenuData data, List<String> requiredTags) {
    final filtered = <String, List<Recipe>>{};

    for (final entry in data.menuSnapshot.entries) {
      final matchingRecipes = entry.value.where((recipe) {
        final recipeTags = recipe.core.personalTagIds ?? [];
        return requiredTags.every((tag) => recipeTags.contains(tag));
      }).toList();
      if (matchingRecipes.isNotEmpty) {
        filtered[entry.key] = matchingRecipes;
      }
    }

    return filtered;
  }

  /// Get cooking time distribution
  static Map<String, int> getCookingTimeDistribution(RealtimeMenuData data) {
    final distribution = <String, int>{};

    for (final recipe in data.allUniqueRecipes) {
      final time = recipe.core.timeMinutes ?? 0;
      String category;
      if (time <= 15) {
        category = 'Snabb (≤15 min)';
      } else if (time <= 30) {
        category = 'Medel (16-30 min)';
      } else if (time <= 60) {
        category = 'Längre (31-60 min)';
      } else {
        category = 'Lång (>60 min)';
      }

      distribution[category] = (distribution[category] ?? 0) + 1;
    }

    return distribution;
  }

  /// Get difficulty distribution based on cooking time as proxy.
  static Map<String, int> getDifficultyDistribution(RealtimeMenuData data) {
    final distribution = <String, int>{};

    for (final recipe in data.allUniqueRecipes) {
      final time = recipe.core.timeMinutes ?? 0;
      String category;
      if (time <= 15) {
        category = 'Lätt';
      } else if (time <= 30) {
        category = 'Medel';
      } else if (time <= 60) {
        category = 'Avancerad';
      } else {
        category = 'Expert';
      }

      distribution[category] = (distribution[category] ?? 0) + 1;
    }

    return distribution;
  }

  /// Get rating distribution
  static Map<String, int> getRatingDistribution(RealtimeMenuData data) {
    final distribution = <String, int>{};

    for (final recipe in data.allUniqueRecipes) {
      final rating = recipe.core.rating ?? 0.0;
      String category;
      if (rating >= 4.5) {
        category = 'Excellent (4.5+)';
      } else if (rating >= 4.0) {
        category = 'Very Good (4.0+)';
      } else if (rating >= 3.0) {
        category = 'Good (3.0+)';
      } else {
        category = 'Fair (<3.0)';
      }

      distribution[category] = (distribution[category] ?? 0) + 1;
    }

    return distribution;
  }

  /// Get all unique tags in menu
  static List<String> getAllTags(RealtimeMenuData data) {
    final allTags = <String>{};

    for (final recipe in data.allUniqueRecipes) {
      final tags = recipe.core.personalTags ?? [];
      allTags.addAll(tags.map((t) => t.name));
    }

    return allTags.toList()..sort();
  }

  /// Get tag frequency distribution
  static Map<String, int> getTagFrequency(RealtimeMenuData data) {
    final frequency = <String, int>{};

    for (final recipe in data.allUniqueRecipes) {
      final tags = recipe.core.personalTags ?? [];
      for (final t in tags) {
        frequency[t.name] = (frequency[t.name] ?? 0) + 1;
      }
    }

    return frequency;
  }

  /// Get most popular tags
  static List<String> getMostPopularTags(RealtimeMenuData data,
      {int limit = 10}) {
    final frequency = getTagFrequency(data);
    final sorted = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// Healthiness score (0.0-1.0) based on dietary variety, vegetable balance,
  /// and allergen-free diversity across the menu.
  static double getHealthinessScore(RealtimeMenuData data) {
    final recipes = data.allUniqueRecipes;
    if (recipes.isEmpty) return 0.0;

    final recipesWithTags = recipes.where((r) => r.tagResult != null).toList();
    if (recipesWithTags.isEmpty) return 0.5;

    // Sub-score A: Dietary variety (weight 0.4)
    // Count distinct dietary categories with at least one FREE recipe
    final dietaryKeys = <String>{};
    for (final recipe in recipesWithTags) {
      for (final entry in recipe.tagResult!.dietaryStatus.entries) {
        if (entry.value == TriState.free) dietaryKeys.add(entry.key);
      }
    }
    final dietaryScore = (dietaryKeys.length / 4.0).clamp(0.0, 1.0);

    // Sub-score B: Vegetarian balance (weight 0.35)
    // Ideal is ~40% vegetarian recipes
    final vegCount = recipesWithTags
        .where((r) => r.tagResult!.dietaryStatus['vegetarisk'] == TriState.free)
        .length;
    final vegRatio = vegCount / recipesWithTags.length;
    final balanceScore = (1.0 - (vegRatio - 0.4).abs() * 2.0).clamp(0.0, 1.0);

    // Sub-score C: Allergen-free diversity (weight 0.25)
    // Count distinct allergens that at least one recipe is free from
    final freeAllergens = <String>{};
    for (final recipe in recipesWithTags) {
      for (final entry in recipe.tagResult!.allergenStatus.entries) {
        if (entry.value == TriState.free) freeAllergens.add(entry.key);
      }
    }
    final allergenScore = (freeAllergens.length / 5.0).clamp(0.0, 1.0);

    return (dietaryScore * 0.4 + balanceScore * 0.35 + allergenScore * 0.25)
        .clamp(0.0, 1.0);
  }
}
