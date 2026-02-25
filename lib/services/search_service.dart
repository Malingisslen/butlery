/// Search service for recipe discovery with text search, filtering, sorting, and Swedish suggestions.
/// ```dart
/// final ss = SearchService(); final r = ss.advancedSearch(recipes, searchQuery: 'pasta');

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/utils/text/swedish_character_normalizer.dart';

/// Search service for recipe discovery with multi-criteria filtering and Swedish language support.
class SearchService extends BaseService {
  SearchService();

  @override
  String get serviceName => 'SearchService';

  /// Performs full-text search across recipe fields (title, ingredients, tags, etc.). Case-insensitive, Swedish-optimized.
  List<Recipe> searchRecipes(List<Recipe> recipes, String query) {
    if (query.trim().isEmpty) return recipes;

    final lowerQuery = query.toLowerCase().trim();

    return recipes.where((recipe) {
      return _matchesSearchQuery(recipe, lowerQuery);
    }).toList();
  }

  /// Filters recipes based on meal type
  List<Recipe> filterByMealType(List<Recipe> recipes, String? mealType) {
    if (mealType == null || mealType.isEmpty) return recipes;
    return recipes.where((recipe) => recipe.mealType == mealType).toList();
  }

  /// Filters recipes based on tags (AND logic - all tags must be present)
  List<Recipe> filterByTags(List<Recipe> recipes, List<String> tags) {
    if (tags.isEmpty) return recipes;

    return recipes.where((recipe) {
      return tags
          .every((tag) => (recipe.personalTagIds?.contains(tag)).orFalse());
    }).toList();
  }

  /// Filters out recipes that have any of the excluded tags.
  ///
  /// Uses OR logic for exclusion - if the recipe has ANY of the
  /// excluded tags it is removed from the result.
  List<Recipe> filterByExcludedTags(
      List<Recipe> recipes, List<String> excludedTags) {
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

  /// Advanced multi-criteria search with query, mealType, tags, excludedTags, maxTime, minRating, and portions filters (sequential).
  List<Recipe> advancedSearch(
    List<Recipe> recipes, {
    String? searchQuery,
    String? mealType,
    List<String>? tags,
    List<String>? excludedTags,
    int? maxTime,
    double? minRating,
    int? minPortions,
    int? maxPortions,
  }) {
    var filtered = List<Recipe>.from(recipes);

    // Applicera alla filter i sekvens
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      filtered = searchRecipes(filtered, searchQuery);
    }

    if (mealType != null) {
      filtered = filterByMealType(filtered, mealType);
    }

    if (tags != null && tags.isNotEmpty) {
      filtered = filterByTags(filtered, tags);
    }

    if (excludedTags != null && excludedTags.isNotEmpty) {
      filtered = filterByExcludedTags(filtered, excludedTags);
    }

    if (maxTime != null) {
      filtered = filterByMaxTime(filtered, maxTime);
    }

    if (minRating != null) {
      filtered = filterByMinRating(filtered, minRating);
    }

    if (minPortions != null || maxPortions != null) {
      filtered = filterByPortions(filtered, minPortions, maxPortions);
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
    }

    return sorted;
  }

  /// Generates intelligent search suggestions based on partial input and existing recipe content.
  /// This method analyzes the recipe collection to provide relevant search suggestions as users type,
  /// improving search discoverability and user experience. It examines titles, ingredients, and tags
  /// to generate contextually relevant suggestions with duplicate removal and intelligent ranking.
  /// [recipes] Recipe collection to analyze for suggestion generation
  /// [partial] Partial search input from user for suggestion matching
  /// Returns up to 10 relevant search suggestions sorted alphabetically
  /// **Suggestion Algorithm:**
  /// - **Minimum Length**: Requires at least 2 characters for meaningful suggestions
  /// - **Multi-Source**: Analyzes titles, ingredients, and tags for comprehensive coverage
  /// - **Case-Insensitive**: Performs lowercase matching for consistent results
  /// - **Duplicate Removal**: Uses Set data structure to eliminate duplicate suggestions
  /// - **Result Limiting**: Returns top 10 suggestions to prevent UI overcrowding
  /// - **Alphabetical Sorting**: Provides predictable, user-friendly suggestion ordering
  /// **Suggestion Sources:**
  /// - Recipe titles for primary content matching
  /// - Individual ingredients for specific component suggestions
  /// - Recipe tags for categorical and descriptive suggestions
  /// **Usage Examples:**
  /// ```dart
  /// // Real-time search suggestions
  /// final suggestions = searchService.getSearchSuggestions(recipes, 'kyck');
  /// // Returns: ['kyckling', 'kycklingbröst', 'kycklinglår', ...]
  /// // Ingredient-based suggestions
  /// final ingredientSuggestions = searchService.getSearchSuggestions(recipes, 'tom');
  /// // Returns: ['tomat', 'tomatpuré', 'tomatkonserv', ...]
  /// ```
  List<String> getSearchSuggestions(List<Recipe> recipes, String partial) {
    if (partial.length < 2) return [];

    final suggestions = <String>{};
    final lowerPartial = partial.toLowerCase();

    for (final recipe in recipes) {
      // Title suggestions
      if (recipe.title.toLowerCase().contains(lowerPartial)) {
        suggestions.add(recipe.title);
      }

      // Ingredient suggestions
      for (final ingredient in recipe.ingredients) {
        if (ingredient.toLowerCase().contains(lowerPartial)) {
          suggestions.add(ingredient);
        }
      }

      // Tag suggestions (use tag names, not UUIDs)
      if (recipe.core.personalTags != null) {
        for (final tag in recipe.core.personalTags!) {
          if (tag.name.toLowerCase().contains(lowerPartial)) {
            suggestions.add(tag.name);
          }
        }
      }
    }

    return suggestions.take(10).toList()..sort();
  }

  /// Gets popular search terms based on recipe data
  List<String> getPopularSearchTerms(List<Recipe> recipes) {
    final termFrequency = <String, int>{};

    for (final recipe in recipes) {
      // Count meal types
      termFrequency[recipe.mealType] =
          (termFrequency[recipe.mealType]).orZero() + 1;

      // Count tags (use tag names, not UUIDs)
      if (recipe.core.personalTags != null) {
        for (final tag in recipe.core.personalTags!) {
          termFrequency[tag.name] = (termFrequency[tag.name]).orZero() + 1;
        }
      }

      // Count common ingredients
      for (final ingredient in recipe.ingredients) {
        final cleaned = ingredient
            .toLowerCase()
            .replaceAll(RegExp(r'\d+|\s*(dl|g|kg|msk|tsk|st|burk|påse)\s*'), '')
            .trim();
        if (cleaned.length > 3) {
          termFrequency[cleaned] = (termFrequency[cleaned]).orZero() + 1;
        }
      }
    }

    // Return the most popular terms
    final sorted = termFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(20).map((e) => e.key).toList();
  }

  /// Checks if target contains all query words (Swedish-normalized).
  static bool _normalizedContains(
      String target, String normalizedQuery, List<String> queryWords) {
    final normalizedTarget =
        SwedishCharacterNormalizer.normalize(target.toLowerCase());
    if (queryWords.length == 1) {
      return normalizedTarget.contains(normalizedQuery);
    }
    // Multi-word: all words must be present (AND logic)
    return queryWords.every((word) => normalizedTarget.contains(word));
  }

  /// Private helper function for matching search queries
  bool _matchesSearchQuery(Recipe recipe, String query) {
    final normalizedQuery = SwedishCharacterNormalizer.normalize(query);
    final queryWords = normalizedQuery.split(RegExp(r'\s+'));

    // Titel
    if (_normalizedContains(recipe.title, normalizedQuery, queryWords)) {
      return true;
    }

    // Beskrivning
    if (_normalizedContains(recipe.description, normalizedQuery, queryWords)) {
      return true;
    }

    // Ingredienser
    if (recipe.ingredients.any(
      (ingredient) =>
          _normalizedContains(ingredient, normalizedQuery, queryWords),
    )) {
      return true;
    }

    // Instruktioner
    if (recipe.instructions.any(
      (instruction) =>
          _normalizedContains(instruction, normalizedQuery, queryWords),
    )) {
      return true;
    }

    // Taggar (use personalTags names, not UUID-based personalTagIds)
    if ((recipe.core.personalTags?.any(
      (tag) => _normalizedContains(tag.name, normalizedQuery, queryWords),
    )).orFalse()) {
      return true;
    }

    // Meal type
    if (_normalizedContains(recipe.mealType, normalizedQuery, queryWords)) {
      return true;
    }

    // Numeric fields (servings, time, rating)
    final queryAsNumber = double.tryParse(query);
    if (queryAsNumber != null) {
      if ((recipe.portions?.toString().contains(query)).orFalse()) return true;
      if ((recipe.timeMinutes?.toString().contains(query)).orFalse()) {
        return true;
      }
      if ((recipe.rating?.toString().contains(query)).orFalse()) return true;
    }

    return false;
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
  /// Alphabetical sorting by recipe name for browsing and organization.
  title,

  /// Cooking time sorting for meal planning and time-constrained cooking.
  time,

  /// Quality-based sorting for discovering highly-rated recipes.
  rating,

  /// Serving size sorting for meal planning and group cooking.
  portions,

  /// Category-based sorting for meal organization and discovery.
  mealType,
}

/// Comprehensive search parameters container for complex search operations and state management.
/// This class encapsulates all possible search and filtering parameters into a single, immutable
/// data structure that simplifies search state management and enables complex search operations.
/// It provides comprehensive parameter management with sensible defaults and supports immutable
/// updates through the copyWith pattern for predictable state management.
/// **Parameter Categories:**
/// - **Text Search**: Query string for full-text search across recipe content
/// - **Category Filter**: Meal type filtering for category-based discovery
/// - **Tag Filtering**: List-based tag filtering with AND-logic semantics
/// - **Time Constraints**: Maximum cooking time filter for time-sensitive meal planning
/// - **Quality Filter**: Minimum rating threshold for quality-based recipe discovery
/// - **Portion Filters**: Minimum and maximum serving size constraints for meal planning
/// - **Sorting Options**: Sort criteria and direction for result organization
/// **Immutable Design:**
/// - Immutable data structure prevents accidental state mutations
/// - copyWith method enables controlled parameter updates
/// - Default values provide sensible starting points for search operations
/// - Comprehensive parameter validation through type safety
/// **Usage Examples:**
/// ```dart
/// // Create basic search parameters
/// final params = SearchParameters(
///   query: 'kyckling',
///   mealType: 'middag',
///   maxTime: 45,
/// );
/// // Update parameters immutably
/// final updatedParams = params.copyWith(
///   minRating: 4.0,
///   tags: ['glutenfri'],
/// );
/// // Use with advanced search
/// final results = searchService.advancedSearch(
///   recipes,
///   searchQuery: params.query,
///   mealType: params.mealType,
///   maxTime: params.maxTime,
/// );
/// ```
class SearchParameters {
  final String? query;
  final String? mealType;
  final List<String> tags;
  final List<String> excludedTags;
  final int? maxTime;
  final double? minRating;
  final int? minPortions;
  final int? maxPortions;
  final SortCriteria sortBy;
  final bool sortAscending;

  /// Creates SearchParameters with comprehensive search and filtering configuration.
  /// All parameters are optional with sensible defaults to provide flexible search configuration.
  /// The constructor creates an immutable instance that can be updated through copyWith method
  /// for predictable search state management throughout the application.
  /// [query] Optional text search query for full-text recipe matching
  /// [mealType] Optional meal category filter for category-based discovery
  /// [tags] List of tags for AND-logic filtering (defaults to empty list)
  /// [excludedTags] List of tags to exclude - recipes with ANY of these are filtered out
  /// [maxTime] Optional maximum cooking time filter in minutes
  /// [minRating] Optional minimum rating threshold for quality filtering
  /// [minPortions] Optional minimum serving size filter
  /// [maxPortions] Optional maximum serving size filter
  /// [sortBy] Sort criteria for result organization (defaults to title)
  /// [sortAscending] Sort direction flag (defaults to ascending)
  const SearchParameters({
    this.query,
    this.mealType,
    this.tags = const [],
    this.excludedTags = const [],
    this.maxTime,
    this.minRating,
    this.minPortions,
    this.maxPortions,
    this.sortBy = SortCriteria.title,
    this.sortAscending = true,
  });

  SearchParameters copyWith({
    String? query,
    String? mealType,
    List<String>? tags,
    List<String>? excludedTags,
    int? maxTime,
    double? minRating,
    int? minPortions,
    int? maxPortions,
    SortCriteria? sortBy,
    bool? sortAscending,
  }) {
    return SearchParameters(
      query: query ?? this.query,
      mealType: mealType ?? this.mealType,
      tags: tags ?? this.tags,
      excludedTags: excludedTags ?? this.excludedTags,
      maxTime: maxTime ?? this.maxTime,
      minRating: minRating ?? this.minRating,
      minPortions: minPortions ?? this.minPortions,
      maxPortions: maxPortions ?? this.maxPortions,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}
