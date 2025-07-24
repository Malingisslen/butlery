// lib/models/realtime/realtime_menu_analytics.dart

import '../recipe_unified.dart';
import 'realtime_menu_data.dart';

/// Search, filtering, and advanced analytics for realtime menu data
/// 
/// This class contains ONLY:
/// - Search functionality
/// - Filtering operations
/// - Advanced analytics and insights
/// - Data analysis methods
/// 
/// ❌ DOES NOT CONTAIN: Data representation, basic operations, UI concerns
class RealtimeMenuAnalytics {
  
  // ===== SEARCH FUNCTIONALITY =====

  /// Search recipes in menu based on query
  static List<Recipe> searchRecipes(RealtimeMenuData data, String query) {
    if (query.isEmpty) return data.allUniqueRecipes;

    final lowerQuery = query.toLowerCase();
    final results = <Recipe>[];

    for (final recipes in data.menuSnapshot.values) {
      for (final recipe in recipes) {
        if (_recipeMatchesQuery(recipe, lowerQuery)) {
          results.add(recipe);
        }
      }
    }

    return results;
  }

  /// Check if recipe matches search query
  static bool _recipeMatchesQuery(Recipe recipe, String lowerQuery) {
    return recipe.title.toLowerCase().contains(lowerQuery) ||
        recipe.description.toLowerCase().contains(lowerQuery) ||
        recipe.ingredients.any((ingredient) =>
            ingredient.toLowerCase().contains(lowerQuery)) ||
        recipe.mealType.toLowerCase().contains(lowerQuery) ||
        (recipe.tags?.any((tag) => 
            tag.toLowerCase().contains(lowerQuery)) ?? false);
  }

  /// Search recipes with advanced filters
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

    // Apply text query filter
    if (query != null && query.isNotEmpty) {
      results = results.where((recipe) => 
          _recipeMatchesQuery(recipe, query.toLowerCase())).toList();
    }

    // Apply meal type filter
    if (mealType != null) {
      results = results.where((recipe) => 
          recipe.mealType == mealType).toList();
    }

    // Apply tags filter
    if (tags != null && tags.isNotEmpty) {
      results = results.where((recipe) =>
          recipe.tags?.any((tag) => tags.contains(tag)) ?? false).toList();
    }

    // Apply time filter
    if (maxTimeMinutes != null) {
      results = results.where((recipe) =>
          recipe.timeMinutes != null && 
          recipe.timeMinutes! <= maxTimeMinutes).toList();
    }

    // Apply portions filter
    if (minPortions != null) {
      results = results.where((recipe) =>
          recipe.portions != null && 
          recipe.portions! >= minPortions).toList();
    }

    if (maxPortions != null) {
      results = results.where((recipe) =>
          recipe.portions != null && 
          recipe.portions! <= maxPortions).toList();
    }

    // Apply rating filter
    if (minRating != null) {
      results = results.where((recipe) =>
          recipe.rating != null && 
          recipe.rating! >= minRating).toList();
    }

    return results;
  }

  // ===== FILTERING OPERATIONS =====

  /// Filter menu by specific meal type
  static Map<String, List<Recipe>> filterByMealType(
    RealtimeMenuData data, 
    String mealType,
  ) {
    final filtered = <String, List<Recipe>>{};

    for (final entry in data.menuSnapshot.entries) {
      final filteredRecipes =
          entry.value.where((recipe) => recipe.mealType == mealType).toList();

      if (filteredRecipes.isNotEmpty) {
        filtered[entry.key] = filteredRecipes;
      }
    }

    return filtered;
  }

  /// Filter menu by cooking time
  static Map<String, List<Recipe>> filterByMaxTime(
    RealtimeMenuData data,
    int maxMinutes,
  ) {
    final filtered = <String, List<Recipe>>{};

    for (final entry in data.menuSnapshot.entries) {
      final filteredRecipes = entry.value.where((recipe) =>
          recipe.timeMinutes != null && 
          recipe.timeMinutes! <= maxMinutes).toList();

      if (filteredRecipes.isNotEmpty) {
        filtered[entry.key] = filteredRecipes;
      }
    }

    return filtered;
  }

  /// Filter menu by rating
  static Map<String, List<Recipe>> filterByMinRating(
    RealtimeMenuData data,
    double minRating,
  ) {
    final filtered = <String, List<Recipe>>{};

    for (final entry in data.menuSnapshot.entries) {
      final filteredRecipes = entry.value.where((recipe) =>
          recipe.rating != null && 
          recipe.rating! >= minRating).toList();

      if (filteredRecipes.isNotEmpty) {
        filtered[entry.key] = filteredRecipes;
      }
    }

    return filtered;
  }

  /// Filter menu by tags
  static Map<String, List<Recipe>> filterByTags(
    RealtimeMenuData data,
    List<String> requiredTags,
  ) {
    final filtered = <String, List<Recipe>>{};

    for (final entry in data.menuSnapshot.entries) {
      final filteredRecipes = entry.value.where((recipe) =>
          recipe.tags?.any((tag) => requiredTags.contains(tag)) ?? false).toList();

      if (filteredRecipes.isNotEmpty) {
        filtered[entry.key] = filteredRecipes;
      }
    }

    return filtered;
  }

  // ===== ADVANCED ANALYTICS =====

  /// Get cooking time distribution
  static Map<String, int> getCookingTimeDistribution(RealtimeMenuData data) {
    final distribution = <String, int>{};
    
    for (final recipes in data.menuSnapshot.values) {
      for (final recipe in recipes) {
        final timeCategory = _getTimeCategoryForRecipe(recipe);
        distribution[timeCategory] = (distribution[timeCategory] ?? 0) + 1;
      }
    }

    return distribution;
  }

  /// Get time category for recipe
  static String _getTimeCategoryForRecipe(Recipe recipe) {
    if (recipe.timeMinutes == null) return 'Okänd tid';
    
    final minutes = recipe.timeMinutes!;
    if (minutes <= 15) return 'Snabb (≤15 min)';
    if (minutes <= 30) return 'Medel (16-30 min)';  
    if (minutes <= 60) return 'Långsam (31-60 min)';
    return 'Mycket långsam (>60 min)';
  }

  /// Get difficulty distribution based on recipe complexity
  static Map<String, int> getDifficultyDistribution(RealtimeMenuData data) {
    final distribution = <String, int>{};
    
    for (final recipes in data.menuSnapshot.values) {
      for (final recipe in recipes) {
        final difficulty = _getDifficultyForRecipe(recipe);
        distribution[difficulty] = (distribution[difficulty] ?? 0) + 1;
      }
    }

    return distribution;
  }

  /// Estimate difficulty for recipe
  static String _getDifficultyForRecipe(Recipe recipe) {
    final instructionCount = recipe.instructions.length;
    final ingredientCount = recipe.ingredients.length;
    final totalSteps = instructionCount + (ingredientCount / 3).ceil();
    
    if (totalSteps <= 5) return 'Enkel';
    if (totalSteps <= 10) return 'Medel';
    return 'Avancerad';
  }

  /// Get rating distribution
  static Map<String, int> getRatingDistribution(RealtimeMenuData data) {
    final distribution = <String, int>{};
    
    for (final recipes in data.menuSnapshot.values) {
      for (final recipe in recipes) {
        final ratingCategory = _getRatingCategoryForRecipe(recipe);
        distribution[ratingCategory] = (distribution[ratingCategory] ?? 0) + 1;
      }
    }

    return distribution;
  }

  /// Get rating category for recipe
  static String _getRatingCategoryForRecipe(Recipe recipe) {
    if (recipe.rating == null) return 'Ej betygsatt';
    
    final rating = recipe.rating!;
    if (rating >= 4.5) return 'Utmärkt (4.5-5.0)';
    if (rating >= 3.5) return 'Bra (3.5-4.4)';
    if (rating >= 2.5) return 'OK (2.5-3.4)';
    return 'Behöver förbättras (<2.5)';
  }

  /// Get all unique tags in menu
  static List<String> getAllTags(RealtimeMenuData data) {
    final allTags = <String>{};
    
    for (final recipes in data.menuSnapshot.values) {
      for (final recipe in recipes) {
        if (recipe.tags != null) {
          allTags.addAll(recipe.tags!);
        }
      }
    }
    
    return allTags.toList()..sort();
  }

  /// Get tag frequency distribution
  static Map<String, int> getTagFrequency(RealtimeMenuData data) {
    final frequency = <String, int>{};
    
    for (final recipes in data.menuSnapshot.values) {
      for (final recipe in recipes) {
        if (recipe.tags != null) {
          for (final tag in recipe.tags!) {
            frequency[tag] = (frequency[tag] ?? 0) + 1;
          }
        }
      }
    }
    
    return frequency;
  }

  /// Get most popular tags
  static List<String> getMostPopularTags(RealtimeMenuData data, {int limit = 10}) {
    final frequency = getTagFrequency(data);
    final sortedTags = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedTags
        .take(limit)
        .map((entry) => entry.key)
        .toList();
  }

  // ===== NUTRITIONAL ANALYSIS =====

  /// Estimate menu healthiness score (0-100)
  static double getHealthinessScore(RealtimeMenuData data) {
    if (data.allUniqueRecipes.isEmpty) return 0.0;

    double score = 0.0;
    int scoredRecipes = 0;

    for (final recipe in data.allUniqueRecipes) {
      final recipeScore = _getRecipeHealthinessScore(recipe);
      if (recipeScore > 0) {
        score += recipeScore;
        scoredRecipes++;
      }
    }

    return scoredRecipes > 0 ? score / scoredRecipes : 0.0;
  }

  /// Estimate healthiness score for individual recipe
  static double _getRecipeHealthinessScore(Recipe recipe) {
    double score = 50.0; // Base score
    
    // Analyze ingredients for healthy keywords
    final healthyKeywords = [
      'grönsak', 'frukt', 'bär', 'nöt', 'fisk', 'vollkorn', 'fiber',
      'protein', 'vitamin', 'mineral', 'olivolja', 'avokado'
    ];
    
    final unhealthyKeywords = [
      'socker', 'fett', 'friterat', 'processad', 'konserv', 'färdigmat',
      'snabbmat', 'godis', 'läsk', 'alkohol'
    ];

    for (final ingredient in recipe.ingredients) {
      final lowerIngredient = ingredient.toLowerCase();
      
      for (final keyword in healthyKeywords) {
        if (lowerIngredient.contains(keyword)) {
          score += 2.0;
        }
      }
      
      for (final keyword in unhealthyKeywords) {
        if (lowerIngredient.contains(keyword)) {
          score -= 3.0;
        }
      }
    }

    // Consider cooking method from instructions
    final instructions = recipe.instructions.join(' ').toLowerCase();
    if (instructions.contains('grilla') || instructions.contains('ång')) {
      score += 5.0;
    }
    if (instructions.contains('fritera') || instructions.contains('friterad')) {
      score -= 10.0;
    }

    // Consider meal type
    if (recipe.mealType == 'Frukost' && recipe.ingredients.any((i) => 
        i.toLowerCase().contains('vollkorn') || 
        i.toLowerCase().contains('müsli'))) {
      score += 5.0;
    }

    return score.clamp(0.0, 100.0);
  }

  // ===== MENU INSIGHTS =====

  /// Get menu balance insights
  static MenuBalanceInsights getBalanceInsights(RealtimeMenuData data) {
    final mealTypes = <String, int>{};
    final cookingTimes = <String, int>{};
    final difficulties = <String, int>{};
    
    for (final recipe in data.allUniqueRecipes) {
      // Count meal types
      mealTypes[recipe.mealType] = (mealTypes[recipe.mealType] ?? 0) + 1;
      
      // Count cooking times
      final timeCategory = _getTimeCategoryForRecipe(recipe);
      cookingTimes[timeCategory] = (cookingTimes[timeCategory] ?? 0) + 1;
      
      // Count difficulties
      final difficulty = _getDifficultyForRecipe(recipe);
      difficulties[difficulty] = (difficulties[difficulty] ?? 0) + 1;
    }

    return MenuBalanceInsights(
      mealTypeDistribution: mealTypes,
      cookingTimeDistribution: cookingTimes,
      difficultyDistribution: difficulties,
      healthinessScore: getHealthinessScore(data),
      totalRecipes: data.allUniqueRecipes.length,
      uniqueCategories: data.categories.length,
    );
  }

  /// Get recipe recommendations based on menu analysis
  static List<String> getRecipeRecommendations(RealtimeMenuData data) {
    final recommendations = <String>[];
    final insights = getBalanceInsights(data);
    
    // Analyze gaps in meal types
    final mealTypes = insights.mealTypeDistribution;
    if ((mealTypes['Frukost'] ?? 0) < 2) {
      recommendations.add('Lägg till fler frukostalternativ för variation');
    }
    if ((mealTypes['Mellanmål'] ?? 0) == 0) {
      recommendations.add('Överväg att lägga till nyttiga mellanmål');
    }
    
    // Analyze cooking time balance
    final cookingTimes = insights.cookingTimeDistribution;
    final quickRecipes = cookingTimes['Snabb (≤15 min)'] ?? 0;
    if (quickRecipes < insights.totalRecipes * 0.3) {
      recommendations.add('Lägg till fler snabba recept för hektiska dagar');
    }
    
    // Analyze difficulty balance
    final difficulties = insights.difficultyDistribution;
    final easyRecipes = difficulties['Enkel'] ?? 0;
    if (easyRecipes < insights.totalRecipes * 0.4) {
      recommendations.add('Inkludera fler enkla recept för vardagsmat');
    }
    
    // Analyze healthiness
    if (insights.healthinessScore < 60) {
      recommendations.add('Försök inkludera fler näringsrika ingredienser');
    }
    
    // Check category balance
    if (insights.uniqueCategories < 3) {
      recommendations.add('Diversifiera menyn med fler matkategorier');
    }
    
    return recommendations;
  }

  // ===== COMPARISON ANALYTICS =====

  /// Compare two menu data sets
  static MenuComparisonResult compareMenus(
    RealtimeMenuData menu1,
    RealtimeMenuData menu2,
  ) {
    final insights1 = getBalanceInsights(menu1);
    final insights2 = getBalanceInsights(menu2);
    
    return MenuComparisonResult(
      recipeDifference: insights2.totalRecipes - insights1.totalRecipes,
      categoryDifference: insights2.uniqueCategories - insights1.uniqueCategories,
      healthinessDifference: insights2.healthinessScore - insights1.healthinessScore,
      commonRecipes: _findCommonRecipes(menu1, menu2),
      uniqueToFirst: _findUniqueRecipes(menu1, menu2),
      uniqueToSecond: _findUniqueRecipes(menu2, menu1),
    );
  }

  /// Find common recipes between two menus
  static List<Recipe> _findCommonRecipes(
    RealtimeMenuData menu1,
    RealtimeMenuData menu2,
  ) {
    final menu1Ids = menu1.allUniqueRecipes.map((r) => r.id).toSet();
    return menu2.allUniqueRecipes
        .where((recipe) => menu1Ids.contains(recipe.id))
        .toList();
  }

  /// Find recipes unique to first menu
  static List<Recipe> _findUniqueRecipes(
    RealtimeMenuData menu1,
    RealtimeMenuData menu2,
  ) {
    final menu2Ids = menu2.allUniqueRecipes.map((r) => r.id).toSet();
    return menu1.allUniqueRecipes
        .where((recipe) => !menu2Ids.contains(recipe.id))
        .toList();
  }
}

// ===== DATA CLASSES FOR ANALYTICS =====

/// Menu balance insights data class
class MenuBalanceInsights {
  final Map<String, int> mealTypeDistribution;
  final Map<String, int> cookingTimeDistribution;
  final Map<String, int> difficultyDistribution;
  final double healthinessScore;
  final int totalRecipes;
  final int uniqueCategories;

  const MenuBalanceInsights({
    required this.mealTypeDistribution,
    required this.cookingTimeDistribution,
    required this.difficultyDistribution,
    required this.healthinessScore,
    required this.totalRecipes,
    required this.uniqueCategories,
  });

  @override
  String toString() {
    return 'MenuBalanceInsights('
        'recipes: $totalRecipes, '
        'categories: $uniqueCategories, '
        'healthiness: ${healthinessScore.toStringAsFixed(1)}'
        ')';
  }
}

/// Menu comparison result data class
class MenuComparisonResult {
  final int recipeDifference;
  final int categoryDifference;
  final double healthinessDifference;
  final List<Recipe> commonRecipes;
  final List<Recipe> uniqueToFirst;
  final List<Recipe> uniqueToSecond;

  const MenuComparisonResult({
    required this.recipeDifference,
    required this.categoryDifference,
    required this.healthinessDifference,
    required this.commonRecipes,
    required this.uniqueToFirst,
    required this.uniqueToSecond,
  });

  @override
  String toString() {
    return 'MenuComparisonResult('
        'recipeDiff: $recipeDifference, '
        'categoryDiff: $categoryDifference, '
        'common: ${commonRecipes.length}'
        ')';
  }
}