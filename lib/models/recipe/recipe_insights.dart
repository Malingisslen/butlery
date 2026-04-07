/// Typed recipe collection statistics — replaces stringly-typed Map.

// lib/models/recipe/recipe_insights.dart

class RecipeInsights {
  final int totalRecipes;
  final int personalRecipes;
  final int collaborativeRecipes;
  final int mealTypes;
  final int tags;
  final int recentlyCookedCount;
  final int favoriteCount;
  final int withImagesCount;
  final int highRatedCount;
  final int totalCooks;
  final int withoutPhotoCount;
  final int withoutTimeCount;
  final int incompleteCount;
  final Map<String, int> completenessDistribution;

  const RecipeInsights({
    required this.totalRecipes,
    required this.personalRecipes,
    required this.collaborativeRecipes,
    required this.mealTypes,
    required this.tags,
    required this.recentlyCookedCount,
    required this.favoriteCount,
    required this.withImagesCount,
    required this.highRatedCount,
    required this.totalCooks,
    required this.withoutPhotoCount,
    required this.withoutTimeCount,
    required this.incompleteCount,
    required this.completenessDistribution,
  });
}
