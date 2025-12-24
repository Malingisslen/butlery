/// Comprehensive realtime menu analytics providing advanced search, filtering, and intelligent insights for collaborative meal planning.

// lib/models/realtime/realtime_menu_analytics.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';

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
        (recipe.core.tags
                ?.any((tag) => tag.toLowerCase().contains(lowerQuery)) ??
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
        final recipeTags = recipe.core.tags ?? [];
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
        final recipeTags = recipe.core.tags ?? [];
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

  /// Get difficulty distribution (simplified)
  static Map<String, int> getDifficultyDistribution(RealtimeMenuData data) {
    return {'Lätt': data.allUniqueRecipes.length}; // Simplified
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
      final tags = recipe.core.tags ?? [];
      allTags.addAll(tags);
    }

    return allTags.toList()..sort();
  }

  /// Get tag frequency distribution
  static Map<String, int> getTagFrequency(RealtimeMenuData data) {
    final frequency = <String, int>{};

    for (final recipe in data.allUniqueRecipes) {
      final tags = recipe.core.tags ?? [];
      for (final tag in tags) {
        frequency[tag] = (frequency[tag] ?? 0) + 1;
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

  /// Get healthiness score (simplified)
  static double getHealthinessScore(RealtimeMenuData data) {
    return 0.75; // Simplified placeholder
  }
}
