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
import 'package:butlery/services/persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/tag_editing_service.dart';
import 'package:butlery/viewmodels/recipe_list/recipe_selection_manager.dart';
import 'package:butlery/viewmodels/recipe_list/recipe_delete_manager.dart';
import 'package:butlery/widgets/common/search_filter/filter_models.dart';

/// Recipe list ViewModel for search, filtering, sorting, and caching (MVVM).
class RecipeListViewModel extends ChangeNotifier {
  bool _isDisposed = false;
  StreamSubscription? _recipeServiceSubscription;
  final UnifiedRecipeService _recipeService;
  final SearchService _searchService;
  final TagEditingService _tagEditingService;

  // Search history
  static const _searchHistoryKey = 'butlery_search_history';
  static const _maxHistoryEntries = 10;
  List<String> _searchHistory = [];
  List<String> get searchHistory => List.unmodifiable(_searchHistory);

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

  /// Active personal tag filters for user-defined tag-based filtering.
  /// Stores tag UUIDs matched against recipe.core.personalTagIds.
  final Set<String> _activePersonalTagFilters = {};

  /// Excluded personal tag filters - recipes with ANY of these are filtered out.
  /// Stores tag UUIDs matched against recipe.core.personalTagIds.
  final Set<String> _excludedPersonalTagFilters = {};

  /// Whether to show only favorite recipes.
  bool _favoritesOnly = false;

  // Grid/list view toggle
  bool _isGridView = false;
  bool get isGridView => _isGridView;

  // Multi-select and delete managers
  final RecipeSelectionManager _selectionManager = RecipeSelectionManager();
  late final RecipeDeleteManager _deleteManager;

  /// Cached filtered recipe results for performance optimization and responsiveness.
  List<Recipe>? _cachedFilteredRecipes;

  /// Last search query for cache invalidation and state comparison optimization.
  String? _lastSearchQuery;

  /// Last sorting criteria for cache validation and performance optimization.
  SortCriteria? _lastSortCriteria;

  /// Last sorting direction for cache consistency and state management.
  bool? _lastSortAscending;

  Set<String>? _lastTimeFilters;
  Set<String>? _lastMealTypeFilters;
  Set<String>? _lastRatingFilters;
  Set<String>? _lastAllergenFilters;
  Set<String>? _lastDietaryFilters;
  Set<String>? _lastPersonalTagFilters;
  Set<String>? _lastExcludedPersonalTagFilters;
  bool? _lastFavoritesOnly;

  RecipeListViewModel({
    UnifiedRecipeService? recipeService,
    SearchService? searchService,
    TagEditingService? tagEditingService,
  })  : _recipeService =
            recipeService ?? ServiceLocator.get<UnifiedRecipeService>(),
        _searchService = searchService ?? ServiceLocator.get<SearchService>(),
        _tagEditingService =
            tagEditingService ?? ServiceLocator.get<TagEditingService>() {
    _deleteManager = RecipeDeleteManager(
      recipeService: _recipeService,
      invalidateCache: _invalidateCache,
      notifyParent: notifyListeners,
      onError: (_) => notifyListeners(),
    );
    _selectionManager.addListener(notifyListeners);
    _recipeServiceSubscription =
        _recipeService.stateStream.listen((_) => _onRecipesChanged());
    _recipeService.initialize();
    _loadDisplayPreferences();
    _loadOnboardingBannerState();
  }

  Future<void> _loadDisplayPreferences() async {
    try {
      final persistence = ServiceLocator.get<PersistenceService>();
      _isGridView = await persistence.getIsGridView();
      final savedCriteria = await persistence.getSortCriteria();
      if (savedCriteria != null) {
        _sortCriteria = SortCriteria.values.firstWhere(
          (c) => c.name == savedCriteria,
          orElse: () => SortCriteria.title,
        );
        _sortAscending = await persistence.getSortAscending();
        _invalidateCache();
      }
      notifyListeners();
    } catch (_) {
      // Persistence not available, keep defaults
    }
  }

  List<Recipe> get recipes => _getFilteredAndSortedRecipes();

  bool get isLoading => _recipeService.isLoading;
  String? get error => _recipeService.error;
  bool get hasError => _recipeService.hasError;

  String get searchQuery => _searchQuery;
  SortCriteria get sortCriteria => _sortCriteria;
  bool get sortAscending => _sortAscending;

  Set<String> get activeTimeFilters => Set.unmodifiable(_activeTimeFilters);
  Set<String> get activeMealTypeFilters =>
      Set.unmodifiable(_activeMealTypeFilters);
  Set<String> get activeRatingFilters => Set.unmodifiable(_activeRatingFilters);
  Set<String> get activeAllergenFilters =>
      Set.unmodifiable(_activeAllergenFilters);
  Set<String> get activeDietaryFilters =>
      Set.unmodifiable(_activeDietaryFilters);
  Set<String> get activePersonalTagFilters =>
      Set.unmodifiable(_activePersonalTagFilters);
  Set<String> get excludedPersonalTagFilters =>
      Set.unmodifiable(_excludedPersonalTagFilters);

  bool get favoritesOnly => _favoritesOnly;

  /// Whether local writes are pending server confirmation (Firestore metadata).
  bool get hasPendingWrites => _recipeService.hasPendingWrites;

  /// Whether data came from local cache — device is offline (Firestore metadata).
  bool get isFromCache => _recipeService.isFromCache;

  bool get hasActiveFilters =>
      _activeTimeFilters.isNotEmpty ||
      _activeMealTypeFilters.isNotEmpty ||
      _activeRatingFilters.isNotEmpty ||
      _activeAllergenFilters.isNotEmpty ||
      _activeDietaryFilters.isNotEmpty ||
      _activePersonalTagFilters.isNotEmpty ||
      _excludedPersonalTagFilters.isNotEmpty ||
      _favoritesOnly;

  /// Whether allergen or dietary filters are specifically active.
  /// These filters require tagResult to be present, so untagged recipes are excluded.
  bool get hasTagBasedFilters =>
      _activeAllergenFilters.isNotEmpty || _activeDietaryFilters.isNotEmpty;

  /// Count of recipes that are excluded from filter results due to missing tags.
  /// Used to inform users that some recipes are still being analyzed.
  int get untaggedRecipeCount {
    if (!hasTagBasedFilters) return 0;
    return _recipeService.recipes
        .where((r) =>
            r.tagResult == null ||
            r.tagResult!.hasFailed ||
            r.tagResult!.needsRetagging ||
            r.tagResult!.coverage < 1.0)
        .length;
  }

  /// Message to show when untagged recipes are excluded from filter results.
  /// Returns null if no untagged recipes are being excluded.
  String? get untaggedExclusionMessage {
    final count = untaggedRecipeCount;
    if (count == 0) return null;
    if (count == 1) {
      return '1 recept analyseras fortfarande och visas inte med valda filter.';
    }
    return '$count recept analyseras fortfarande och visas inte med valda filter.';
  }

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
        // Save meaningful queries (3+ chars) to history after debounce
        if (query.trim().length >= 3) {
          unawaited(_saveSearchToHistory(query.trim()));
        }
      });
    }
  }

  /// Load search history from SharedPreferences.
  Future<void> loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _searchHistory = prefs.getStringList(_searchHistoryKey) ?? [];
    notifyListeners();
  }

  Future<void> _saveSearchToHistory(String query) async {
    _searchHistory.remove(query);
    _searchHistory.insert(0, query);
    if (_searchHistory.length > _maxHistoryEntries) {
      _searchHistory = _searchHistory.sublist(0, _maxHistoryEntries);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_searchHistoryKey, _searchHistory);
  }

  /// Remove a single entry from search history.
  Future<void> removeFromSearchHistory(String query) async {
    _searchHistory.remove(query);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_searchHistoryKey, _searchHistory);
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
    try {
      ServiceLocator.get<PersistenceService>()
          .setSortPreferences(_sortCriteria.name, _sortAscending);
    } catch (_) {
      // PersistenceService not registered yet during early init
    }
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

  /// Toggles personal tag filter for user-defined tag-based filtering.
  /// Uses AND logic: recipes must have ALL selected personal tags.
  /// [tagId] is the tag UUID (matching recipe.core.personalTagIds which stores UUIDs).
  void togglePersonalTagFilter(String tagId) {
    if (_activePersonalTagFilters.contains(tagId)) {
      _activePersonalTagFilters.remove(tagId);
    } else {
      _activePersonalTagFilters.add(tagId);
    }
    _invalidateCache();
    notifyListeners();
  }

  /// Toggles excluded personal tag filter for exclusion-based filtering.
  /// Uses OR logic: recipes with ANY excluded tag are filtered out.
  /// [tagId] is the tag UUID (matching recipe.core.personalTagIds which stores UUIDs).
  void toggleExcludedPersonalTagFilter(String tagId) {
    if (_excludedPersonalTagFilters.contains(tagId)) {
      _excludedPersonalTagFilters.remove(tagId);
    } else {
      _excludedPersonalTagFilters.add(tagId);
    }
    _invalidateCache();
    notifyListeners();
  }

  /// Toggles favorites-only filter for quick access to favorite recipes.
  void toggleFavoritesFilter() {
    _favoritesOnly = !_favoritesOnly;
    _invalidateCache();
    notifyListeners();
  }

  void clearAllFilters() {
    _activeTimeFilters.clear();
    _activeMealTypeFilters.clear();
    _activeRatingFilters.clear();
    _activeAllergenFilters.clear();
    _activeDietaryFilters.clear();
    _activePersonalTagFilters.clear();
    _excludedPersonalTagFilters.clear();
    _favoritesOnly = false;
    _invalidateCache();
    notifyListeners();
  }

  /// Immediate UI response on slow connections — the service stream
  /// listener handles rebuilds, so no explicit notifyListeners needed here.
  Future<void> toggleFavorite(String recipeId) async {
    final recipe = _recipeService.getRecipeById(recipeId);
    if (recipe == null) return;
    final newValue = !recipe.isFavorite;

    _recipeService.optimisticUpdate(recipe.copyWith(isFavorite: newValue));

    final success = await _recipeService.toggleFavorite(recipeId, newValue);
    if (!success) {
      // Re-read current state to avoid overwriting concurrent changes
      final current = _recipeService.getRecipeById(recipeId);
      if (current != null) {
        _recipeService
            .optimisticUpdate(current.copyWith(isFavorite: !newValue));
      }
    }
  }

  void toggleViewMode() {
    _isGridView = !_isGridView;
    notifyListeners();
    try {
      final persistence = ServiceLocator.get<PersistenceService>();
      persistence.setIsGridView(_isGridView);
    } catch (_) {
      // Persistence not available, toggle still works in-memory
    }
  }

  // Selection delegation
  bool get isSelectionMode => _selectionManager.isSelectionMode;
  Set<String> get selectedIds => _selectionManager.selectedIds;
  int get selectedCount => _selectionManager.selectedCount;
  void enterSelectionMode(String firstId) =>
      _selectionManager.enterSelectionMode(firstId);
  void toggleSelection(String id) => _selectionManager.toggleSelection(id);
  void selectAll() => _selectionManager.selectAll(recipes.map((r) => r.id));
  void clearSelection() => _selectionManager.clearSelection();

  // Delete delegation
  void deleteRecipe(String recipeId) => _deleteManager.deleteRecipe(recipeId);
  void undoDeleteById(String id) => _deleteManager.undoDeleteById(id);
  void undoLastDelete() => _deleteManager.undoLastDelete();
  void deleteSelected() =>
      _deleteManager.deleteSelected(Set.from(_selectionManager.selectedIds));
  void undoBulkDelete() {
    _deleteManager.undoBulkDelete();
    _selectionManager.clearSelection();
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
    // Use cache if possible
    if (_cachedFilteredRecipes != null &&
        _lastSearchQuery == _searchQuery &&
        _lastSortCriteria == _sortCriteria &&
        _lastSortAscending == _sortAscending &&
        _setEquals(_lastTimeFilters, _activeTimeFilters) &&
        _setEquals(_lastMealTypeFilters, _activeMealTypeFilters) &&
        _setEquals(_lastRatingFilters, _activeRatingFilters) &&
        _setEquals(_lastAllergenFilters, _activeAllergenFilters) &&
        _setEquals(_lastDietaryFilters, _activeDietaryFilters) &&
        _setEquals(_lastPersonalTagFilters, _activePersonalTagFilters) &&
        _setEquals(
            _lastExcludedPersonalTagFilters, _excludedPersonalTagFilters) &&
        _lastFavoritesOnly == _favoritesOnly) {
      return _cachedFilteredRecipes!;
    }

    var filtered = List<Recipe>.from(_recipeService.recipes);

    // Applicera tidsfilter
    if (_activeTimeFilters.isNotEmpty) {
      filtered = _applyTimeFilters(filtered);
    }

    // Apply meal type filter
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

    // Applicera personliga taggar filter
    if (_activePersonalTagFilters.isNotEmpty) {
      filtered = _applyPersonalTagFilters(filtered);
    }

    // Applicera exkluderade personliga taggar filter
    if (_excludedPersonalTagFilters.isNotEmpty) {
      filtered = _searchService.filterByExcludedTags(
        filtered,
        _excludedPersonalTagFilters.toList(),
      );
    }

    // Applicera favoritfilter
    if (_favoritesOnly) {
      filtered = filtered.where((r) => r.isFavorite).toList();
    }

    // Search
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
    _lastPersonalTagFilters = Set.from(_activePersonalTagFilters);
    _lastExcludedPersonalTagFilters = Set.from(_excludedPersonalTagFilters);
    _lastFavoritesOnly = _favoritesOnly;

    // PERFORMANCE FIX: Apply pagination limit to prevent UI performance issues
    return sorted.take(_displayLimit).toList();
  }

  /// Applies time-based filters with intelligent OR logic and comprehensive range management.
  /// [recipes] Recipe collection to filter by cooking time
  /// Returns filtered recipes matching any active time criteria using OR logic.
  /// Time ranges: 'quick' (< 30 min), 'medium' (30-60 min), 'long' (> 60 min).
  /// Handles missing time data with fallback values for robust filtering.
  List<Recipe> _applyTimeFilters(List<Recipe> recipes) {
    // If multiple time filters are selected, show recipes matching ANY of them (OR)
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
    // Map filter ID to meal type
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

    // Find the highest requirement
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

  /// Applies allergen-free filters using effective tag status (with user overrides).
  /// Returns recipes that are proven free from ALL selected allergens (AND logic).
  /// SAFETY: Excludes recipes with coverage < 100% because unknown ingredients
  /// could contain allergens. Only recipes with full coverage can be trusted.
  List<Recipe> _applyAllergenFilters(List<Recipe> recipes) {
    return recipes.where((recipe) {
      final tagResult = recipe.tagResult;
      if (tagResult == null) return false;

      // CRIT-9: Don't trust allergen status if tagging needs to be redone
      if (tagResult.needsRetagging) return false;

      // SAFETY: Don't trust allergen status if coverage < 100%
      if (tagResult.coverage < 1.0) return false;

      // Recipe must be free from ALL selected allergens (AND logic)
      // Uses effective status which respects user overrides
      for (final filterId in _activeAllergenFilters) {
        final filterValue = RecipeFilters.allergenFilterValue(filterId);
        if (filterValue != null) {
          final effectiveStatus = _tagEditingService.getEffectiveAllergenStatus(
              recipe, filterValue);
          if (effectiveStatus != TriState.free) {
            return false;
          }
        }
      }
      return true;
    }).toList();
  }

  /// Applies dietary filters using effective tag status (with user overrides).
  /// Returns recipes that are safe for ALL selected diets (AND logic).
  /// SAFETY: Excludes recipes with coverage < 100% because unknown ingredients
  /// could violate dietary restrictions. Only recipes with full coverage can be trusted.
  List<Recipe> _applyDietaryFilters(List<Recipe> recipes) {
    return recipes.where((recipe) {
      final tagResult = recipe.tagResult;
      if (tagResult == null) return false;

      // CRIT-9: Don't trust dietary status if tagging needs to be redone
      if (tagResult.needsRetagging) return false;

      // SAFETY: Don't trust dietary status if coverage < 100%
      if (tagResult.coverage < 1.0) return false;

      // Recipe must be safe for ALL selected diets (AND logic)
      // Uses effective status which respects user overrides
      for (final filterId in _activeDietaryFilters) {
        final filterValue = RecipeFilters.dietaryFilterValue(filterId);
        if (filterValue != null) {
          final effectiveStatus =
              _tagEditingService.getEffectiveDietaryStatus(recipe, filterValue);
          if (effectiveStatus != TriState.free) {
            return false;
          }
        }
      }
      return true;
    }).toList();
  }

  /// Applies personal tag filters for user-defined tag-based filtering.
  /// Uses AND logic: recipe must contain ALL selected personal tag IDs.
  /// Both _activePersonalTagFilters and recipe.core.personalTagIds store tag UUIDs.
  List<Recipe> _applyPersonalTagFilters(List<Recipe> recipes) {
    return recipes.where((recipe) {
      final recipeTags = recipe.core.personalTagIds ?? [];
      if (recipeTags.isEmpty) return false;

      // Recipe must have ALL selected tags (AND logic)
      for (final tagId in _activePersonalTagFilters) {
        if (!recipeTags.contains(tagId)) {
          return false;
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

  void _onRecipesChanged() {
    _invalidateCache();
    notifyListeners();
  }

  // Onboarding skip banner state
  static const _bannerDismissedKey = 'butlery_onboarding_banner_dismissed';
  bool _showOnboardingBanner = false;

  bool get showOnboardingBanner => _showOnboardingBanner;

  void dismissOnboardingBanner() {
    _showOnboardingBanner = false;
    notifyListeners();
    try {
      ServiceLocator.get<PersistenceService>()
          .setBool(_bannerDismissedKey, true);
    } catch (_) {}
  }

  Future<void> _loadOnboardingBannerState() async {
    try {
      final persistence = ServiceLocator.get<PersistenceService>();
      final dismissed = await persistence.getBool(_bannerDismissedKey) ?? false;
      if (dismissed) return;
      final profile = ServiceLocator.get<UserService>().currentUserProfile;
      _showOnboardingBanner =
          profile != null && profile.onboardingSkippedAt != null;
      if (_showOnboardingBanner) notifyListeners();
    } catch (_) {}
  }

  /// Performs comprehensive ViewModel disposal with service listener cleanup and memory management.
  /// Removes UnifiedRecipeService listener connections and performs complete resource cleanup
  /// to prevent memory leaks and ensure proper ViewModel lifecycle management
  /// in dynamic recipe list scenarios with ViewModel creation and disposal.
  @override
  void notifyListeners() {
    if (!_isDisposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchDebounceTimer?.cancel();
    _deleteManager.dispose();
    _selectionManager.removeListener(notifyListeners);
    _selectionManager.dispose();
    _recipeServiceSubscription?.cancel();
    super.dispose();
  }
}
