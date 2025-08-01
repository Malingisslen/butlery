/// Comprehensive recipe list ViewModel providing advanced recipe management and filtering for Flutter applications.
///
/// This module implements sophisticated recipe list management following Single Responsibility Principle,
/// handling all aspects of recipe list presentation including search functionality, multi-criteria filtering,
/// sorting coordination, and performance optimization. It provides complete recipe list infrastructure while
/// maintaining clean separation from UI rendering, data persistence, and business logic implementation.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles recipe list presentation layer concerns:
/// - **Advanced Search Intelligence**: Comprehensive recipe search with real-time query processing and result optimization
/// - **Multi-Criteria Filtering**: Sophisticated filtering by time, meal type, and rating with logical OR combinations
/// - **Dynamic Sorting**: Flexible sorting by multiple criteria with ascending/descending toggle functionality
/// - **Performance Optimization**: Advanced caching system with intelligent cache invalidation for optimal responsiveness
/// - **State Management**: Reactive state coordination with service integration and comprehensive UI synchronization
///
/// **What This Module Does NOT Handle:**
/// - Recipe data persistence and storage (handled by UnifiedRecipeService and data repositories)
/// - UI rendering and widget creation (handled by MinaReceptView and recipe list UI components)
/// - Recipe business logic and operations (handled by recipe service layer and business logic)
/// - Search algorithm implementation (handled by SearchService for focused search responsibility)
///
/// **Recipe List ViewModel Features:**
/// - **Intelligent Search**: Real-time recipe search with query optimization and result relevance ranking
/// - **Advanced Filtering System**: Multi-dimensional filtering with time ranges, meal types, and rating thresholds
/// - **Dynamic Sorting**: Flexible sorting with criteria toggling and directional control for user preference
/// - **Performance Caching**: Sophisticated result caching with precise invalidation for optimal user experience
/// - **Swedish Localization**: Complete Swedish language support for filters, meal types, and user interface
///
/// **Usage Examples:**
/// ```dart
/// // Initialize recipe list ViewModel with service dependencies
/// final recipeListViewModel = RecipeListViewModel(
///   recipeService: unifiedRecipeService,
///   searchService: searchService,
/// );
/// 
/// // Search recipes with real-time filtering
/// recipeListViewModel.updateSearch('vegetarisk pasta');
/// 
/// // Apply time-based filtering
/// recipeListViewModel.toggleTimeFilter('quick'); // Under 30 minutes
/// recipeListViewModel.toggleTimeFilter('medium'); // 30-60 minutes
/// 
/// // Filter by meal type with Swedish localization
/// recipeListViewModel.toggleMealTypeFilter('dinner'); // Middag
/// recipeListViewModel.toggleMealTypeFilter('lunch'); // Lunch
/// 
/// // Apply rating filters
/// recipeListViewModel.toggleRatingFilter('high_rated'); // 4+ stars
/// 
/// // Dynamic sorting with toggle functionality
/// recipeListViewModel.updateSort(SortCriteria.title); // First click: A-Z
/// recipeListViewModel.updateSort(SortCriteria.title); // Second click: Z-A
/// 
/// // Recipe management operations
/// await recipeListViewModel.deleteRecipe('recipe_123');
/// await recipeListViewModel.refresh(); // Pull-to-refresh
/// 
/// // Clear filters and state
/// recipeListViewModel.clearAllFilters();
/// recipeListViewModel.clearError();
/// 
/// // Access filtered and sorted results
/// final recipes = recipeListViewModel.recipes; // Cached, optimized results
/// final hasFilters = recipeListViewModel.hasActiveFilters;
/// ```

// lib/viewmodels/recipe_list_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Comprehensive recipe list ViewModel providing advanced recipe management and filtering for Flutter applications.
///
/// Serves as the presentation layer coordinator for recipe list operations, providing intelligent search,
/// multi-criteria filtering, dynamic sorting, and performance optimization while maintaining clean MVVM architecture
/// separation between recipe list business logic and UI presentation concerns.
class RecipeListViewModel extends ChangeNotifier {
  final UnifiedRecipeService _recipeService;
  final SearchService _searchService;

  // ===== SEARCH AND SORTING STATE MANAGEMENT =====

  /// Current search query for real-time recipe filtering and search functionality.
  String _searchQuery = '';

  /// Active sorting criteria for recipe list organization and user preference management.
  SortCriteria _sortCriteria = SortCriteria.title;

  /// Sorting direction for ascending/descending toggle functionality and user control.
  bool _sortAscending = true;

  // ===== MULTI-CRITERIA FILTER STATE =====

  /// Active time-based filters for cooking duration filtering with OR logic combination.
  final Set<String> _activeTimeFilters = {};

  /// Active meal type filters for category-based recipe filtering with Swedish localization.
  final Set<String> _activeMealTypeFilters = {};

  /// Active rating filters for quality-based recipe filtering with threshold management.
  final Set<String> _activeRatingFilters = {};

  // ===== PERFORMANCE OPTIMIZATION CACHE =====

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

  /// Initializes recipe list ViewModel with comprehensive service integration and reactive state coordination.
  /// 
  /// [recipeService] Optional UnifiedRecipeService instance for dependency injection
  /// [searchService] Optional SearchService instance for dependency injection
  /// 
  /// Establishes service layer integration with reactive state coordination, enabling
  /// comprehensive recipe list management with automatic cache invalidation and UI synchronization
  /// for optimal user experience and performance optimization.
  RecipeListViewModel({
    UnifiedRecipeService? recipeService,
    SearchService? searchService,
  }) : _recipeService = recipeService ?? ServiceLocator.get<UnifiedRecipeService>(),
       _searchService = searchService ?? ServiceLocator.get<SearchService>() {
    // Lyssna på ändringar från UnifiedRecipeService
    _recipeService.addListener(_onRecipesChanged);
  }

  // ===== RECIPE LIST STATE ACCESSORS =====

  /// Filtered and sorted recipe collection with performance caching and intelligent optimization.
  /// 
  /// Provides complete recipe list with applied search, filtering, and sorting operations
  /// through cached results for optimal performance and responsive user experience.
  /// Automatically invalidates cache when filter or sort criteria change.
  List<Recipe> get recipes => _getFilteredAndSortedRecipes();

  /// Loading state from recipe service for UI progress indication and interaction control.
  /// 
  /// Delegates to UnifiedRecipeService for loading state enabling UI loading indicators
  /// and user interaction management during recipe operations and data refresh.
  bool get isLoading => _recipeService.isLoading;

  /// Error state from recipe service for user feedback and error handling.
  /// 
  /// Provides localized error messages from recipe operations for user display
  /// and comprehensive error state management throughout recipe list operations.
  String? get error => _recipeService.error;

  /// Error presence indicator for UI conditional rendering and error state management.
  /// 
  /// Delegates to UnifiedRecipeService for error state checking enabling
  /// UI conditional display and error handling throughout recipe operations.
  bool get hasError => _recipeService.hasError;

  // ===== SEARCH AND SORT STATE ACCESSORS =====

  /// Current search query for UI display and search state management.
  /// 
  /// Provides access to active search query for UI input field synchronization
  /// and search state display throughout recipe list filtering operations.
  String get searchQuery => _searchQuery;

  /// Current sorting criteria for UI display and sort state management.
  /// 
  /// Indicates active sorting method for UI sort control display
  /// and sort state management throughout recipe list organization.
  SortCriteria get sortCriteria => _sortCriteria;

  /// Current sorting direction for UI display and sort toggle management.
  /// 
  /// Provides sorting direction state for UI sort direction indicators
  /// and ascending/descending toggle functionality display.
  bool get sortAscending => _sortAscending;

  // ===== FILTER STATE ACCESSORS =====

  /// Active time filters for UI display and filter state management.
  /// 
  /// Provides immutable set of active time-based filters for UI filter display
  /// and filter state synchronization with user interface components.
  Set<String> get activeTimeFilters => Set.unmodifiable(_activeTimeFilters);

  /// Active meal type filters for UI display and category filter management.
  /// 
  /// Provides immutable set of active meal type filters with Swedish localized categories
  /// for UI filter display and meal category selection state management.
  Set<String> get activeMealTypeFilters =>
      Set.unmodifiable(_activeMealTypeFilters);

  /// Active rating filters for UI display and quality filter management.
  /// 
  /// Provides immutable set of active rating-based filters for UI filter display
  /// and quality threshold selection state management.
  Set<String> get activeRatingFilters => Set.unmodifiable(_activeRatingFilters);

  /// Filter presence indicator for UI conditional display and filter management.
  /// 
  /// Indicates whether any filters are currently active for UI conditional rendering
  /// of filter clear buttons and filter state indicators.
  bool get hasActiveFilters =>
      _activeTimeFilters.isNotEmpty ||
      _activeMealTypeFilters.isNotEmpty ||
      _activeRatingFilters.isNotEmpty;

  // ===== RECIPE LIST MANAGEMENT ACTIONS =====

  /// Updates search query with intelligent caching and real-time filtering coordination.
  /// 
  /// [query] New search query for recipe filtering and search functionality
  /// 
  /// Performs search query update with automatic cache invalidation and UI notification
  /// for real-time search functionality and optimal user experience. Only triggers
  /// updates when query actually changes for performance optimization.
  void updateSearch(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _invalidateCache();
      notifyListeners();
    }
  }

  /// Updates sorting criteria with intelligent toggle functionality and performance optimization.
  /// 
  /// [criteria] New sorting criteria for recipe list organization
  /// 
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

  // ===== ADVANCED FILTERING OPERATIONS =====

  /// Toggles time-based filter with intelligent state management and cache coordination.
  /// 
  /// [filterId] Time filter identifier ('quick', 'medium', 'long')
  /// 
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
  /// 
  /// [filterId] Meal type filter identifier ('breakfast', 'lunch', 'dinner', 'snack', 'dessert')
  /// 
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
  /// 
  /// [filterId] Rating filter identifier ('high_rated', 'top_rated')
  /// 
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

  /// Clears all active filters with comprehensive state reset and performance optimization.
  /// 
  /// Removes all time, meal type, and rating filters with automatic cache invalidation
  /// and UI notification for complete filter state reset and clean recipe list display.
  /// Essential for filter reset functionality and clean state management.
  void clearAllFilters() {
    _activeTimeFilters.clear();
    _activeMealTypeFilters.clear();
    _activeRatingFilters.clear();
    _invalidateCache();
    notifyListeners();
  }

  // ===== RECIPE MANAGEMENT OPERATIONS =====

  /// Deletes recipe with service coordination and automatic state management.
  /// 
  /// [recipeId] Unique identifier for recipe deletion
  /// 
  /// Performs recipe deletion through UnifiedRecipeService with automatic list updates.
  /// Service handles state notifications and cache invalidation automatically
  /// for seamless recipe management and UI synchronization.
  Future<void> deleteRecipe(String recipeId) async {
    await _recipeService.deleteRecipe(recipeId);
    // UnifiedRecipeService hanterar notifications, vi behöver inte göra något här
    return;
  }

  /// Refreshes recipe data with pull-to-refresh coordination and service integration.
  /// 
  /// Performs comprehensive data refresh through UnifiedRecipeService for pull-to-refresh
  /// functionality with automatic state management and UI synchronization.
  /// Essential for data consistency and user-initiated refresh operations.
  Future<void> refresh() async {
    await _recipeService.refresh();
  }

  /// Clears error state with service coordination and comprehensive state management.
  /// 
  /// Delegates to UnifiedRecipeService for error state cleanup enabling
  /// error recovery and clean user experience after error resolution.
  void clearError() {
    _recipeService.clearError();
  }

  // ===== ADVANCED FILTERING AND CACHING IMPLEMENTATION =====

  /// Retrieves filtered and sorted recipe collection with intelligent caching and comprehensive optimization.
  /// 
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
        _setEquals(_lastRatingFilters, _activeRatingFilters)) {
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

    return sorted;
  }

  /// Applies time-based filters with intelligent OR logic and comprehensive range management.
  /// 
  /// [recipes] Recipe collection to filter by cooking time
  /// 
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
  /// 
  /// [recipes] Recipe collection to filter by meal type categories
  /// 
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

    final selectedMealTypes =
        _activeMealTypeFilters
            .map((id) => mealTypeMap[id])
            .where((type) => type != null)
            .toSet();

    if (selectedMealTypes.isEmpty) return recipes;

    return recipes.where((recipe) {
      return selectedMealTypes.contains(recipe.mealType);
    }).toList();
  }

  /// Applies rating filters with intelligent threshold management and quality-based filtering.
  /// 
  /// [recipes] Recipe collection to filter by rating thresholds
  /// 
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

  // ===== PERFORMANCE OPTIMIZATION UTILITIES =====

  /// Compares two sets for equality with null safety and performance optimization.
  /// 
  /// [a] First set for comparison
  /// [b] Second set for comparison
  /// 
  /// Returns true if sets contain identical elements, false otherwise.
  /// Handles null values and performs efficient equality checking for cache validation.
  bool _setEquals<T>(Set<T>? a, Set<T>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  /// Invalidates performance cache for fresh result computation on next access.
  /// 
  /// Clears cached filter results forcing fresh computation on next recipe list access.
  /// Essential for maintaining data consistency when filter or sort criteria change.
  void _invalidateCache() {
    _cachedFilteredRecipes = null;
  }

  /// Handles reactive updates from recipe service changes with automatic cache management.
  /// 
  /// Provides seamless state synchronization between UnifiedRecipeService and ViewModel ensuring
  /// all recipe data changes are immediately reflected in filtered results with cache invalidation
  /// for consistent user experience and real-time recipe list updates.
  void _onRecipesChanged() {
    _invalidateCache();
    notifyListeners();
  }

  /// Performs comprehensive ViewModel disposal with service listener cleanup and memory management.
  /// 
  /// Removes UnifiedRecipeService listener connections and performs complete resource cleanup
  /// to prevent memory leaks and ensure proper ViewModel lifecycle management
  /// in dynamic recipe list scenarios with ViewModel creation and disposal.
  @override
  void dispose() {
    _recipeService.removeListener(_onRecipesChanged);
    super.dispose();
  }
}
