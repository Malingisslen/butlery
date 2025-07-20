// lib/services/search_service.dart

import '../models/recipe_unified.dart';

/// Centraliserad service för all sökfunktionalitet i appen
class SearchService {
  // Singleton pattern för global åtkomst
  static final SearchService _instance = SearchService._internal();
  factory SearchService() => _instance;
  SearchService._internal();

  /// Huvudsökfunktion - söker i alla fält av ett recept
  List<Recipe> searchRecipes(List<Recipe> recipes, String query) {
    if (query.trim().isEmpty) return recipes;

    final lowerQuery = query.toLowerCase().trim();

    return recipes.where((recipe) {
      return _matchesSearchQuery(recipe, lowerQuery);
    }).toList();
  }

  /// Filtrerar recept baserat på måltidstyp
  List<Recipe> filterByMealType(List<Recipe> recipes, String? mealType) {
    if (mealType == null || mealType.isEmpty) return recipes;
    return recipes.where((recipe) => recipe.mealType == mealType).toList();
  }

  /// Filtrerar recept baserat på taggar (AND-logik - alla taggar måste finnas)
  List<Recipe> filterByTags(List<Recipe> recipes, List<String> tags) {
    if (tags.isEmpty) return recipes;

    return recipes.where((recipe) {
      return tags.every((tag) => recipe.tags?.contains(tag) ?? false);
    }).toList();
  }

  /// Filtrerar recept baserat på maximal tid
  List<Recipe> filterByMaxTime(List<Recipe> recipes, int? maxMinutes) {
    if (maxMinutes == null) return recipes;

    return recipes.where((recipe) {
      return recipe.timeMinutes != null && recipe.timeMinutes! <= maxMinutes;
    }).toList();
  }

  /// Filtrerar recept baserat på minimalt betyg
  List<Recipe> filterByMinRating(List<Recipe> recipes, double? minRating) {
    if (minRating == null) return recipes;

    return recipes.where((recipe) {
      return recipe.rating != null && recipe.rating! >= minRating;
    }).toList();
  }

  /// Filtrerar recept baserat på antal portioner
  List<Recipe> filterByPortions(
    List<Recipe> recipes,
    int? minPortions,
    int? maxPortions,
  ) {
    var filtered = recipes;

    if (minPortions != null) {
      filtered =
          filtered.where((recipe) {
            return recipe.portions != null && recipe.portions! >= minPortions;
          }).toList();
    }

    if (maxPortions != null) {
      filtered =
          filtered.where((recipe) {
            return recipe.portions != null && recipe.portions! <= maxPortions;
          }).toList();
    }

    return filtered;
  }

  /// Avancerad kombinerad sökning med alla filter
  List<Recipe> advancedSearch(
    List<Recipe> recipes, {
    String? searchQuery,
    String? mealType,
    List<String>? tags,
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

  /// Sorterar recept baserat på olika kriterier
  List<Recipe> sortRecipes(
    List<Recipe> recipes,
    SortCriteria criteria, {
    bool ascending = true,
  }) {
    final sorted = List<Recipe>.from(recipes);

    switch (criteria) {
      case SortCriteria.title:
        sorted.sort(
          (a, b) =>
              ascending
                  ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
                  : b.title.toLowerCase().compareTo(a.title.toLowerCase()),
        );
        break;

      case SortCriteria.time:
        sorted.sort((a, b) {
          final timeA = a.timeMinutes ?? 9999;
          final timeB = b.timeMinutes ?? 9999;
          return ascending ? timeA.compareTo(timeB) : timeB.compareTo(timeA);
        });
        break;

      case SortCriteria.rating:
        sorted.sort((a, b) {
          final ratingA = a.rating ?? 0.0;
          final ratingB = b.rating ?? 0.0;
          return ascending
              ? ratingA.compareTo(ratingB)
              : ratingB.compareTo(ratingA);
        });
        break;

      case SortCriteria.portions:
        sorted.sort((a, b) {
          final portionsA = a.portions ?? 0;
          final portionsB = b.portions ?? 0;
          return ascending
              ? portionsA.compareTo(portionsB)
              : portionsB.compareTo(portionsA);
        });
        break;

      case SortCriteria.mealType:
        sorted.sort(
          (a, b) =>
              ascending
                  ? a.mealType.compareTo(b.mealType)
                  : b.mealType.compareTo(a.mealType),
        );
        break;
    }

    return sorted;
  }

  /// Hämtar sökförslag baserat på tidigare sökningar
  List<String> getSearchSuggestions(List<Recipe> recipes, String partial) {
    if (partial.length < 2) return [];

    final suggestions = <String>{};
    final lowerPartial = partial.toLowerCase();

    for (final recipe in recipes) {
      // Titel-förslag
      if (recipe.title.toLowerCase().contains(lowerPartial)) {
        suggestions.add(recipe.title);
      }

      // Ingrediens-förslag
      for (final ingredient in recipe.ingredients) {
        if (ingredient.toLowerCase().contains(lowerPartial)) {
          suggestions.add(ingredient);
        }
      }

      // Tagg-förslag
      if (recipe.tags != null) {
        for (final tag in recipe.tags!) {
          if (tag.toLowerCase().contains(lowerPartial)) {
            suggestions.add(tag);
          }
        }
      }
    }

    return suggestions.take(10).toList()..sort();
  }

  /// Hämtar populära söktermer baserat på receptdata
  List<String> getPopularSearchTerms(List<Recipe> recipes) {
    final termFrequency = <String, int>{};

    for (final recipe in recipes) {
      // Räkna måltidstyper
      termFrequency[recipe.mealType] =
          (termFrequency[recipe.mealType] ?? 0) + 1;

      // Räkna taggar
      if (recipe.tags != null) {
        for (final tag in recipe.tags!) {
          termFrequency[tag] = (termFrequency[tag] ?? 0) + 1;
        }
      }

      // Räkna vanliga ingredienser
      for (final ingredient in recipe.ingredients) {
        final cleaned =
            ingredient
                .toLowerCase()
                .replaceAll(
                  RegExp(r'\d+|\s*(dl|g|kg|msk|tsk|st|burk|påse)\s*'),
                  '',
                )
                .trim();
        if (cleaned.length > 3) {
          termFrequency[cleaned] = (termFrequency[cleaned] ?? 0) + 1;
        }
      }
    }

    // Returnera de mest populära termerna
    final sorted =
        termFrequency.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(20).map((e) => e.key).toList();
  }

  /// Privat hjälpfunktion för att matcha sökfrågor
  bool _matchesSearchQuery(Recipe recipe, String query) {
    // Titel
    if (recipe.title.toLowerCase().contains(query)) return true;

    // Beskrivning
    if (recipe.description.toLowerCase().contains(query)) return true;

    // Ingredienser
    if (recipe.ingredients.any(
      (ingredient) => ingredient.toLowerCase().contains(query),
    )) {
      return true;
    }

    // Instruktioner
    if (recipe.instructions.any(
      (instruction) => instruction.toLowerCase().contains(query),
    )) {
      return true;
    }

    // Taggar
    if (recipe.tags?.any((tag) => tag.toLowerCase().contains(query)) ?? false) {
      return true;
    }

    // Måltidstyp
    if (recipe.mealType.toLowerCase().contains(query)) return true;

    // Numeriska fält (portioner, tid, betyg)
    final queryAsNumber = double.tryParse(query);
    if (queryAsNumber != null) {
      if (recipe.portions?.toString().contains(query) ?? false) return true;
      if (recipe.timeMinutes?.toString().contains(query) ?? false) return true;
      if (recipe.rating?.toString().contains(query) ?? false) return true;
    }

    return false;
  }
}

/// Enum för olika sorteringsalternativ
enum SortCriteria { title, time, rating, portions, mealType }

/// Hjälpklass för att hålla sökparametrar
class SearchParameters {
  final String? query;
  final String? mealType;
  final List<String> tags;
  final int? maxTime;
  final double? minRating;
  final int? minPortions;
  final int? maxPortions;
  final SortCriteria sortBy;
  final bool sortAscending;

  const SearchParameters({
    this.query,
    this.mealType,
    this.tags = const [],
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
      maxTime: maxTime ?? this.maxTime,
      minRating: minRating ?? this.minRating,
      minPortions: minPortions ?? this.minPortions,
      maxPortions: maxPortions ?? this.maxPortions,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}
