import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/services/search/recipe_search_matcher.dart';

/// Search service for recipe discovery with multi-criteria filtering and Swedish language support.
class SearchService extends BaseService {
  SearchService();

  @override
  String get serviceName => 'SearchService';

  /// Text search with the app-wide rule in [RecipeSearchMatcher].
  List<Recipe> searchRecipes(List<Recipe> recipes, String query) =>
      RecipeSearchMatcher.filter(recipes, query);

  /// Filters recipes based on meal type
  List<Recipe> filterByMealType(List<Recipe> recipes, String? mealType) {
    if (mealType == null || mealType.isEmpty) return recipes;
    return recipes.where((recipe) => recipe.mealType == mealType).toList();
  }

  /// Filters recipes based on tags (AND logic - all tags must be present)
  List<Recipe> filterByTags(List<Recipe> recipes, List<String> tags) {
    if (tags.isEmpty) return recipes;

    return recipes.where((recipe) {
      return tags.every(
        (tag) => (recipe.personalTagIds?.contains(tag)).orFalse(),
      );
    }).toList();
  }

  /// Filters out recipes that have any of the excluded tags.
  ///
  /// Uses OR logic for exclusion - if the recipe has ANY of the
  /// excluded tags it is removed from the result.
  List<Recipe> filterByExcludedTags(
    List<Recipe> recipes,
    List<String> excludedTags,
  ) {
    if (excludedTags.isEmpty) return recipes;

    return recipes.where((recipe) {
      final recipeTags = recipe.personalTagIds ?? [];
      // Keep the recipe if it does NOT have any of the excluded tags
      return !excludedTags.any((tag) => recipeTags.contains(tag));
    }).toList();
  }

  /// Filters recipes based on maximum time
  List<Recipe> filterByMaxTime(List<Recipe> recipes, int? maxMinutes) {
    if (maxMinutes == null) return recipes;

    return recipes.where((recipe) {
      return recipe.timeMinutes != null && recipe.timeMinutes! <= maxMinutes;
    }).toList();
  }

  /// Filters recipes based on minimum rating
  List<Recipe> filterByMinRating(List<Recipe> recipes, double? minRating) {
    if (minRating == null) return recipes;

    return recipes.where((recipe) {
      return recipe.rating != null && recipe.rating! >= minRating;
    }).toList();
  }

  /// Filters recipes based on number of servings
  List<Recipe> filterByPortions(
    List<Recipe> recipes,
    int? minPortions,
    int? maxPortions,
  ) {
    var filtered = recipes;

    if (minPortions != null) {
      filtered = filtered.where((recipe) {
        return recipe.portions != null && recipe.portions! >= minPortions;
      }).toList();
    }

    if (maxPortions != null) {
      filtered = filtered.where((recipe) {
        return recipe.portions != null && recipe.portions! <= maxPortions;
      }).toList();
    }

    return filtered;
  }

  /// Sorts recipes based on various criteria
  List<Recipe> sortRecipes(
    List<Recipe> recipes,
    SortCriteria criteria, {
    bool ascending = true,
  }) {
    final sorted = List<Recipe>.from(recipes);

    switch (criteria) {
      case SortCriteria.title:
        sorted.sort(
          (a, b) => ascending
              ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
              : b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
        break;

      case SortCriteria.time:
        sorted.sort((a, b) {
          final timeA = (a.timeMinutes).orDefault(9999);
          final timeB = (b.timeMinutes).orDefault(9999);
          return ascending ? timeA.compareTo(timeB) : timeB.compareTo(timeA);
        });
        break;

      case SortCriteria.rating:
        sorted.sort((a, b) {
          final ratingA = (a.rating).orDefault(0.0);
          final ratingB = (b.rating).orDefault(0.0);
          return ascending
              ? ratingA.compareTo(ratingB)
              : ratingB.compareTo(ratingA);
        });
        break;

      case SortCriteria.portions:
        sorted.sort((a, b) {
          final portionsA = (a.portions).orZero();
          final portionsB = (b.portions).orZero();
          return ascending
              ? portionsA.compareTo(portionsB)
              : portionsB.compareTo(portionsA);
        });
        break;

      case SortCriteria.mealType:
        sorted.sort(
          (a, b) => ascending
              ? a.mealType.compareTo(b.mealType)
              : b.mealType.compareTo(a.mealType),
        );
        break;

      case SortCriteria.lastCooked:
        sorted.sort((a, b) {
          final dateA = a.lastCookedAt;
          final dateB = b.lastCookedAt;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return ascending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
        });
        break;

      case SortCriteria.cookCount:
        sorted.sort((a, b) {
          return ascending
              ? a.cookCount.compareTo(b.cookCount)
              : b.cookCount.compareTo(a.cookCount);
        });
        break;

      case SortCriteria.newest:
        sorted.sort((a, b) {
          return ascending
              ? a.createdAt.compareTo(b.createdAt)
              : b.createdAt.compareTo(a.createdAt);
        });
        break;

      case SortCriteria.random:
        sorted.shuffle();
        break;
    }

    return sorted;
  }
}

/// Enumeration defining available sorting criteria for recipe organization and discovery optimization.
/// This enum provides comprehensive sorting options for recipe collections enabling users to organize
/// and discover recipes based on different attributes. Each criteria supports both ascending and descending
/// sort orders for flexible recipe organization that meets various user preferences and discovery patterns.
/// **Sorting Criteria:**
/// - [title] Alphabetical sorting by recipe name for browsing and organization
/// - [time] Cooking time sorting for meal planning and time-constrained cooking
/// - [rating] Quality-based sorting for discovering highly-rated recipes
/// - [portions] Serving size sorting for meal planning and group cooking
/// - [mealType] Category-based sorting for meal organization and discovery
/// **Usage Examples:**
/// ```dart
/// // Sort by rating (highest first)
/// final topRated = searchService.sortRecipes(recipes, SortCriteria.rating, ascending: false);
/// // Sort by cooking time (quickest first)
/// final quickMeals = searchService.sortRecipes(recipes, SortCriteria.time, ascending: true);
/// // Alphabetical organization
/// final alphabetical = searchService.sortRecipes(recipes, SortCriteria.title);
/// ```
enum SortCriteria {
  title,
  time,
  rating,
  portions,
  mealType,
  lastCooked,
  cookCount,
  newest,
  random,
}
