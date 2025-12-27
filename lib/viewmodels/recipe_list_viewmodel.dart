/// Recipe list ViewModel with search, multi-criteria filtering, sorting, and caching.
/// ```dart
/// final vm = RecipeListViewModel(recipeService: sl.get());
/// vm.updateSearch('pasta'); vm.toggleTimeFilter('quick');

// lib/viewmodels/recipe_list_viewmodel.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/search_filter/filter_models.dart';

/// Recipe list ViewModel for search, filtering, sorting, and caching (MVVM).
class RecipeListViewModel extends ChangeNotifier {
  final UnifiedRecipeService _recipeService;
  final SearchService _searchService;

  // State
  String _searchQuery = '';
  Timer? _searchDebounceTimer;
  SortCriteria _sortCriteria = SortCriteria.title;
  bool _sortAscending = true;
  static const int _initialPageSize = 50;
  int _displayLimit = _initialPageSize;
  bool get canLoadMore => _displayLimit < (_cachedFilteredRecipes?.length ?? 0);
  final Set<String> _activeTimeFilters = {};

  /// Active meal type filters for category-based recipe filtering with Swedish localization.
  final Set<String> _activeMealTypeFilters = {};

  /// Active rating filters for quality-based recipe filtering with threshold management.
  final Set<String> _activeRatingFilters = {};

  /// Active allergen-free filters for allergen-based recipe filtering.
  final Set<String> _activeAllergenFilters = {};

  /// Active dietary filters for diet-based recipe filtering.
  final Set<String> _activeDietaryFilters = {};

  /// Cached filtered recipe results for performance optimization and responsiveness.
  List<Recipe>? _cachedFilteredRecipes;

  /// Last search query for cache invalidation and state comparison optimization.
  String? _lastSearchQuery;

  /// Last sorting criteria for cache validation and performance optimization.
  SortCriteria? _lastSortCriteria;

  /// Last sorting direction for cache consistency and state management.
  bool? _lastSortAscending;

  /// Last time filters for cache invalidation and filter state comparison.
  Set<String>? _lastTimeFilters;

  /// Last meal type filters for cache validation and performance optimization.
  Set<String>? _lastMealTypeFilters;

  /// Last rating filters for cache consistency and state management optimization.
  Set<String>? _lastRatingFilters;

  /// Last allergen filters for cache validation.
  Set<String>? _lastAllergenFilters;

  /// Last dietary filters for cache validation.
  Set<String>? _lastDietaryFilters;

  /// Initializes recipe list ViewModel with comprehensive service integration and reactive state coordination.
  /// [recipeService] Optional UnifiedRecipeService instance for dependency injection
  /// [searchService] Optional SearchService instance for dependency injection
  /// Establishes service layer integration with reactive state coordination, enabling
  /// comprehensive recipe list management with automatic cache invalidation and UI synchronization
  /// for optimal user experience and performance optimization.
  RecipeListViewModel({
    UnifiedRecipeService? recipeService,
    SearchService? searchService,
  })  : _recipeService =
            recipeService ?? ServiceLocator.get<UnifiedRecipeService>(),
        _searchService = searchService ?? ServiceLocator.get<SearchService>() {
    // Lyssna på ändringar från UnifiedRecipeService
    _recipeService.addListener(_onRecipesChanged);
    // Initialize service to ensure recipes are loaded
    _recipeService.initialize();
  }

  /// Filtered and sorted recipe collection with performance caching and intelligent optimization.
  /// Provides complete recipe list with applied search, filtering, and sorting operations
  /// through cached results for optimal performance and responsive user experience.
  /// Automatically invalidates cache when filter or sort criteria change.
  List<Recipe> get recipes => _getFilteredAndSortedRecipes();

  /// Loading state from recipe service for UI progress indication and interaction control.
  /// Delegates to UnifiedRecipeService for loading state enabling UI loading indicators
  /// and user interaction management during recipe operations and data refresh.
  bool get isLoading => _recipeService.isLoading;

  /// Error state from recipe service for user feedback and error handling.
  /// Provides localized error messages from recipe operations for user display
  /// and comprehensive error state management throughout recipe list operations.
  String? get error => _recipeService.error;

  /// Error presence indicator for UI conditional rendering and error state management.
  /// Delegates to UnifiedRecipeService for error state checking enabling
  /// UI conditional display and error handling throughout recipe operations.
  bool get hasError => _recipeService.hasError;

  /// Current search query for UI display and search state management.
  /// Provides access to active search query for UI input field synchronization
  /// and search state display throughout recipe list filtering operations.
  String get searchQuery => _searchQuery;

  /// Current sorting criteria for UI display and sort state management.
  /// Indicates active sorting method for UI sort control display
  /// and sort state management throughout recipe list organization.
  SortCriteria get sortCriteria => _sortCriteria;

  /// Current sorting direction for UI display and sort toggle management.
  /// Provides sorting direction state for UI sort direction indicators
  /// and ascending/descending toggle functionality display.
  bool get sortAscending => _sortAscending;

  /// Active time filters for UI display and filter state management.
  /// Provides immutable set of active time-based filters for UI filter display
  /// and filter state synchronization with user interface components.
  Set<String> get activeTimeFilters => Set.unmodifiable(_activeTimeFilters);

  /// Active meal type filters for UI display and category filter management.
  /// Provides immutable set of active meal type filters with Swedish localized categories
  /// for UI filter display and meal category selection state management.
  Set<String> get activeMealTypeFilters =>
      Set.unmodifiable(_activeMealTypeFilters);

  /// Active rating filters for UI display and quality filter management.
  /// Provides immutable set of active rating-based filters for UI filter display
  /// and quality threshold selection state management.
  Set<String> get activeRatingFilters => Set.unmodifiable(_activeRatingFilters);

  /// Active allergen-free filters for UI display and allergen filter management.
  Set<String> get activeAllergenFilters =>
      Set.unmodifiable(_activeAllergenFilters);

  /// Active dietary filters for UI display and dietary filter management.
  Set<String> get activeDietaryFilters =>
      Set.unmodifiable(_activeDietaryFilters);

  /// Filter presence indicator for UI conditional display and filter management.
  /// Indicates whether any filters are currently active for UI conditional rendering
  /// of filter clear buttons and filter state indicators.
  bool get hasActiveFilters =>
      _activeTimeFilters.isNotEmpty ||
      _activeMealTypeFilters.isNotEmpty ||
      _activeRatingFilters.isNotEmpty ||
      _activeAllergenFilters.isNotEmpty ||
      _activeDietaryFilters.isNotEmpty;

  /// Updates search query with intelligent caching and debounced filtering coordination.
  /// [query] New search query for recipe filtering and search functionality
  /// Performs search query update with debouncing (300ms delay) to prevent excessive
  /// filtering operations on every keystroke. Provides optimal user experience while
  /// maintaining performance during rapid typing. Only triggers updates when query changes.
  void updateSearch(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;

      // PERFORMANCE FIX: Cancel previous timer and start new one for debouncing
      _searchDebounceTimer?.cancel();
      _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        _invalidateCache();
        notifyListeners();
      });
    }
  }

  /// Updates sorting criteria with intelligent toggle functionality and performance optimization.
  /// [criteria] New sorting criteria for recipe list organization
  /// Performs dynamic sorting update with toggle functionality - if same criteria is selected,
  /// toggles ascending/descending direction; if new criteria, resets to ascending.
  /// Includes automatic cache invalidation and UI notification for immediate sorting changes.
  void updateSort(SortCriteria criteria) {
    if (_sortCriteria == criteria) {
      _sortAscending = !_sortAscending;
    } else {
      _sortCriteria = criteria;
      _sortAscending = true;
    }
    _invalidateCache();
    notifyListeners();
  }

  /// Toggles time-based filter with intelligent state management and cache coordination.
  /// [filterId] Time filter identifier ('quick', 'medium', 'long')
  /// Performs time filter toggle with automatic cache invalidation and UI notification.
  /// Supports multiple active filters with OR logic for flexible time-based recipe filtering.
  /// Filters: 'quick' (< 30 min), 'medium' (30-60 min), 'long' (> 60 min).
  void toggleTimeFilter(String filterId) {
    if (_activeTimeFilters.contains(filterId)) {
      _activeTimeFilters.remove(filterId);
    } else {
      _activeTimeFilters.add(filterId);
    }
    _invalidateCache();
    notifyListeners();
  }

  /// Toggles meal type filter with Swedish localization and comprehensive category management.
  /// [filterId] Meal type filter identifier ('breakfast', 'lunch', 'dinner', 'snack', 'dessert')
  /// Performs meal type filter toggle with automatic cache invalidation and UI notification.
  /// Maps English filter IDs to Swedish meal types for localized filtering:
  /// 'breakfast' → 'Frukost', 'lunch' → 'Lunch', 'dinner' → 'Middag', etc.
  void toggleMealTypeFilter(String filterId) {
    if (_activeMealTypeFilters.contains(filterId)) {
      _activeMealTypeFilters.remove(filterId);
    } else {
      _activeMealTypeFilters.add(filterId);
    }
    _invalidateCache();
    notifyListeners();
  }

  /// Toggles rating filter with quality threshold management and performance optimization.
  /// [filterId] Rating filter identifier ('high_rated', 'top_rated')
  /// Performs rating filter toggle with automatic cache invalidation and UI notification.
  /// Supports quality-based filtering: 'high_rated' (4+ stars), 'top_rated' (5 stars).
  /// Uses highest threshold when multiple rating filters are active.
  void toggleRatingFilter(String filterId) {
    if (_activeRatingFilters.contains(filterId)) {
      _activeRatingFilters.remove(filterId);
    } else {
      _activeRatingFilters.add(filterId);
    }
    _invalidateCache();
    notifyListeners();
  }

  /// Toggles allergen-free filter for allergen-based recipe filtering.
  /// [filterId] Allergen filter identifier matching RecipeFilters.allergenFreeFilters
  void toggleAllergenFilter(String filterId) {
    if (_activeAllergenFilters.contains(filterId)) {
      _activeAllergenFilters.remove(filterId);
    } else {
      _activeAllergenFilters.add(filterId);
    }
    _invalidateCache();
    notifyListeners();
  }

  /// Toggles dietary filter for diet-based recipe filtering.
  /// [filterId] Dietary filter identifier matching RecipeFilters.dietaryFilters
  void toggleDietaryFilter(String filterId) {
    if (_activeDietaryFilters.contains(filterId)) {
      _activeDietaryFilters.remove(filterId);
    } else {
      _activeDietaryFilters.add(filterId);
    }
    _invalidateCache();
    notifyListeners();
  }

  /// Clears all active filters with comprehensive state reset and performance optimization.
  /// Removes all time, meal type, rating, allergen, and dietary filters with automatic
  /// cache invalidation and UI notification for complete filter state reset.
  void clearAllFilters() {
    _activeTimeFilters.clear();
    _activeMealTypeFilters.clear();
    _activeRatingFilters.clear();
    _activeAllergenFilters.clear();
    _activeDietaryFilters.clear();
    _invalidateCache();
    notifyListeners();
  }

  /// Deletes recipe with service coordination and automatic state management.
  /// [recipeId] Unique identifier for recipe deletion
  /// Performs recipe deletion through UnifiedRecipeService with automatic list updates.
  /// Service handles state notifications and cache invalidation automatically
  /// for seamless recipe management and UI synchronization.
  Future<void> deleteRecipe(String recipeId) async {
    await _recipeService.deleteRecipe(recipeId);
    // UnifiedRecipeService hanterar notifications, vi behöver inte göra något här
    return;
  }

  /// Refreshes recipe data with pull-to-refresh coordination and service integration.
  /// Performs comprehensive data refresh through UnifiedRecipeService for pull-to-refresh
  /// functionality with automatic state management and UI synchronization.
  /// Essential for data consistency and user-initiated refresh operations.
  Future<void> refresh() async {
    await _recipeService.refresh();
  }

  /// Clears error state with service coordination and comprehensive state management.
  /// Delegates to UnifiedRecipeService for error state cleanup enabling
  /// error recovery and clean user experience after error resolution.
  void clearError() {
    _recipeService.clearError();
  }

  /// Loads more recipes for pagination with performance optimization.
  /// Increases display limit to show more recipes progressively,
  /// preventing initial performance issues while allowing access to all recipes.
  void loadMore() {
    if (canLoadMore) {
      _displayLimit += _initialPageSize;
      notifyListeners();
    }
  }

  /// Retrieves filtered and sorted recipe collection with intelligent caching and comprehensive optimization.
  /// Returns processed recipe list with applied search, filtering, and sorting operations
  /// through sophisticated caching system for optimal performance and responsive user experience.
  /// Validates cache state against all filter criteria for accurate result delivery.
  List<Recipe> _getFilteredAndSortedRecipes() {
    // Använd cache om möjligt
    if (_cachedFilteredRecipes != null &&
        _lastSearchQuery == _searchQuery &&
        _lastSortCriteria == _sortCriteria &&
        _lastSortAscending == _sortAscending &&
        _setEquals(_lastTimeFilters, _activeTimeFilters) &&
        _setEquals(_lastMealTypeFilters, _activeMealTypeFilters) &&
        _setEquals(_lastRatingFilters, _activeRatingFilters) &&
        _setEquals(_lastAllergenFilters, _activeAllergenFilters) &&
        _setEquals(_lastDietaryFilters, _activeDietaryFilters)) {
      return _cachedFilteredRecipes!;
    }

    var filtered = List<Recipe>.from(_recipeService.recipes);

    // Applicera tidsfilter
    if (_activeTimeFilters.isNotEmpty) {
      filtered = _applyTimeFilters(filtered);
    }

    // Applicera måltidsfilter
    if (_activeMealTypeFilters.isNotEmpty) {
      filtered = _applyMealTypeFilters(filtered);
    }

    // Applicera betygsfilter
    if (_activeRatingFilters.isNotEmpty) {
      filtered = _applyRatingFilters(filtered);
    }

    // Applicera allergenfilter
    if (_activeAllergenFilters.isNotEmpty) {
      filtered = _applyAllergenFilters(filtered);
    }

    // Applicera kostfilter
    if (_activeDietaryFilters.isNotEmpty) {
      filtered = _applyDietaryFilters(filtered);
    }

    // Sök
    if (_searchQuery.isNotEmpty) {
      filtered = _searchService.searchRecipes(filtered, _searchQuery);
    }

    // Sortera
    final sorted = _searchService.sortRecipes(
      filtered,
      _sortCriteria,
      ascending: _sortAscending,
    );

    // Cacha resultat
    _cachedFilteredRecipes = sorted;
    _lastSearchQuery = _searchQuery;
    _lastSortCriteria = _sortCriteria;
    _lastSortAscending = _sortAscending;
    _lastTimeFilters = Set.from(_activeTimeFilters);
    _lastMealTypeFilters = Set.from(_activeMealTypeFilters);
    _lastRatingFilters = Set.from(_activeRatingFilters);
    _lastAllergenFilters = Set.from(_activeAllergenFilters);
    _lastDietaryFilters = Set.from(_activeDietaryFilters);

    // PERFORMANCE FIX: Apply pagination limit to prevent UI performance issues
    return sorted.take(_displayLimit).toList();
  }

  /// Applies time-based filters with intelligent OR logic and comprehensive range management.
  /// [recipes] Recipe collection to filter by cooking time
  /// Returns filtered recipes matching any active time criteria using OR logic.
  /// Time ranges: 'quick' (< 30 min), 'medium' (30-60 min), 'long' (> 60 min).
  /// Handles missing time data with fallback values for robust filtering.
  List<Recipe> _applyTimeFilters(List<Recipe> recipes) {
    // Om flera tidsfilter är valda, visa recept som matchar NÅGOT av dem (OR)
    return recipes.where((recipe) {
      final time = recipe.timeMinutes ?? 999;

      for (final filterId in _activeTimeFilters) {
        switch (filterId) {
          case 'quick':
            if (time < 30) return true;
            break;
          case 'medium':
            if (time >= 30 && time <= 60) return true;
            break;
          case 'long':
            if (time > 60) return true;
            break;
        }
      }
      return false;
    }).toList();
  }

  /// Applies meal type filters with Swedish localization and comprehensive category mapping.
  /// [recipes] Recipe collection to filter by meal type categories
  /// Returns filtered recipes matching selected meal types with Swedish localized categories.
  /// Maps English filter IDs to Swedish meal types: 'breakfast' → 'Frukost', 'lunch' → 'Lunch',
  /// 'dinner' → 'Middag', 'snack' → 'Mellanmål', 'dessert' → 'Efterrätt'.
  List<Recipe> _applyMealTypeFilters(List<Recipe> recipes) {
    // Mappa filter-id till måltidstyp
    final mealTypeMap = {
      'breakfast': 'Frukost',
      'lunch': 'Lunch',
      'dinner': 'Middag',
      'snack': 'Mellanmål',
      'dessert': 'Efterrätt',
    };

    final selectedMealTypes = _activeMealTypeFilters
        .map((id) => mealTypeMap[id])
        .where((type) => type != null)
        .toSet();

    if (selectedMealTypes.isEmpty) return recipes;

    return recipes.where((recipe) {
      return selectedMealTypes.contains(recipe.mealType);
    }).toList();
  }

  /// Applies rating filters with intelligent threshold management and quality-based filtering.
  /// [recipes] Recipe collection to filter by rating thresholds
  /// Returns filtered recipes meeting minimum rating requirements with highest threshold priority.
  /// Rating filters: 'high_rated' (4+ stars), 'top_rated' (5 stars).
  /// Uses highest active threshold when multiple rating filters are selected.
  List<Recipe> _applyRatingFilters(List<Recipe> recipes) {
    double minRating = 0;

    // Hitta högsta kravet
    if (_activeRatingFilters.contains('top_rated')) {
      minRating = 5.0;
    } else if (_activeRatingFilters.contains('high_rated')) {
      minRating = 4.0;
    }

    if (minRating == 0) return recipes;

    return recipes.where((recipe) {
      return recipe.rating != null && recipe.rating! >= minRating;
    }).toList();
  }

  /// Applies allergen-free filters using recipe tag results.
  /// Returns recipes that are proven free from ALL selected allergens (AND logic).
  List<Recipe> _applyAllergenFilters(List<Recipe> recipes) {
    return recipes.where((recipe) {
      final tagResult = recipe.tagResult;
      if (tagResult == null) return false;

      // Recipe must be free from ALL selected allergens (AND logic)
      for (final filterId in _activeAllergenFilters) {
        final filterOption = RecipeFilters.allergenFreeFilters.firstWhere(
          (f) => f.id == filterId,
          orElse: () => const FilterOption(id: '', label: '', value: ''),
        );
        if (filterOption.value is String &&
            (filterOption.value as String).isNotEmpty) {
          if (!tagResult.isAllergenFree(filterOption.value as String)) {
            return false;
          }
        }
      }
      return true;
    }).toList();
  }

  /// Applies dietary filters using recipe tag results.
  /// Returns recipes that are safe for ALL selected diets (AND logic).
  List<Recipe> _applyDietaryFilters(List<Recipe> recipes) {
    return recipes.where((recipe) {
      final tagResult = recipe.tagResult;
      if (tagResult == null) return false;

      // Recipe must be safe for ALL selected diets (AND logic)
      for (final filterId in _activeDietaryFilters) {
        final filterOption = RecipeFilters.dietaryFilters.firstWhere(
          (f) => f.id == filterId,
          orElse: () => const FilterOption(id: '', label: '', value: ''),
        );
        if (filterOption.value is String &&
            (filterOption.value as String).isNotEmpty) {
          if (!tagResult.isDietarySafe(filterOption.value as String)) {
            return false;
          }
        }
      }
      return true;
    }).toList();
  }

  /// Compares two sets for equality with null safety and performance optimization.
  /// [a] First set for comparison
  /// [b] Second set for comparison
  /// Returns true if sets contain identical elements, false otherwise.
  /// Handles null values and performs efficient equality checking for cache validation.
  bool _setEquals<T>(Set<T>? a, Set<T>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  /// Invalidates performance cache for fresh result computation on next access.
  /// Clears cached filter results forcing fresh computation on next recipe list access.
  /// Essential for maintaining data consistency when filter or sort criteria change.
  void _invalidateCache() {
    _cachedFilteredRecipes = null;
    // PERFORMANCE FIX: Reset pagination when filters change
    _displayLimit = _initialPageSize;
  }

  /// Handles reactive updates from recipe service changes with automatic cache management.
  /// Provides seamless state synchronization between UnifiedRecipeService and ViewModel ensuring
  /// all recipe data changes are immediately reflected in filtered results with cache invalidation
  /// for consistent user experience and real-time recipe list updates.
  void _onRecipesChanged() {
    _invalidateCache();
    notifyListeners();
  }

  /// Performs comprehensive ViewModel disposal with service listener cleanup and memory management.
  /// Removes UnifiedRecipeService listener connections and performs complete resource cleanup
  /// to prevent memory leaks and ensure proper ViewModel lifecycle management
  /// in dynamic recipe list scenarios with ViewModel creation and disposal.
  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _recipeService.removeListener(_onRecipesChanged);
    super.dispose();
  }
}
