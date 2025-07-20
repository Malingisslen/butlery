// lib/viewmodels/recipe_list_viewmodel.dart

import 'package:flutter/foundation.dart';
import '../models/recipe_unified.dart';
import '../services/unified/unified_recipe_service.dart';
import '../services/search_service.dart';
import '../core/injection.dart';

/// ViewModel för MinaReceptView
/// Hanterar all business logic för receptlistan
class RecipeListViewModel extends ChangeNotifier {
  final UnifiedRecipeService _recipeService;
  final SearchService _searchService;

  // Search & Sort state
  String _searchQuery = '';
  SortCriteria _sortCriteria = SortCriteria.title;
  bool _sortAscending = true;

  // Filter state
  final Set<String> _activeTimeFilters = {};
  final Set<String> _activeMealTypeFilters = {};
  final Set<String> _activeRatingFilters = {};

  // Cache för optimering
  List<Recipe>? _cachedFilteredRecipes;
  String? _lastSearchQuery;
  SortCriteria? _lastSortCriteria;
  bool? _lastSortAscending;
  Set<String>? _lastTimeFilters;
  Set<String>? _lastMealTypeFilters;
  Set<String>? _lastRatingFilters;

  RecipeListViewModel({
    UnifiedRecipeService? recipeService,
    SearchService? searchService,
  }) : _recipeService = recipeService ?? sl<UnifiedRecipeService>(),
       _searchService = searchService ?? sl<SearchService>() {
    // Lyssna på ändringar från UnifiedRecipeService
    _recipeService.addListener(_onRecipesChanged);
  }

  // ===== GETTERS =====

  List<Recipe> get recipes => _getFilteredAndSortedRecipes();
  bool get isLoading => _recipeService.isLoading;
  String? get error => _recipeService.error;
  bool get hasError => _recipeService.hasError;

  String get searchQuery => _searchQuery;
  SortCriteria get sortCriteria => _sortCriteria;
  bool get sortAscending => _sortAscending;

  // Filter getters
  Set<String> get activeTimeFilters => Set.unmodifiable(_activeTimeFilters);
  Set<String> get activeMealTypeFilters =>
      Set.unmodifiable(_activeMealTypeFilters);
  Set<String> get activeRatingFilters => Set.unmodifiable(_activeRatingFilters);
  bool get hasActiveFilters =>
      _activeTimeFilters.isNotEmpty ||
      _activeMealTypeFilters.isNotEmpty ||
      _activeRatingFilters.isNotEmpty;

  // ===== ACTIONS =====

  /// Uppdatera sökfråga
  void updateSearch(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      _invalidateCache();
      notifyListeners();
    }
  }

  /// Uppdatera sortering
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

  /// Toggle tid-filter
  void toggleTimeFilter(String filterId) {
    if (_activeTimeFilters.contains(filterId)) {
      _activeTimeFilters.remove(filterId);
    } else {
      _activeTimeFilters.add(filterId);
    }
    _invalidateCache();
    notifyListeners();
  }

  /// Toggle måltidstyp-filter
  void toggleMealTypeFilter(String filterId) {
    if (_activeMealTypeFilters.contains(filterId)) {
      _activeMealTypeFilters.remove(filterId);
    } else {
      _activeMealTypeFilters.add(filterId);
    }
    _invalidateCache();
    notifyListeners();
  }

  /// Toggle betyg-filter
  void toggleRatingFilter(String filterId) {
    if (_activeRatingFilters.contains(filterId)) {
      _activeRatingFilters.remove(filterId);
    } else {
      _activeRatingFilters.add(filterId);
    }
    _invalidateCache();
    notifyListeners();
  }

  /// Rensa alla filter
  void clearAllFilters() {
    _activeTimeFilters.clear();
    _activeMealTypeFilters.clear();
    _activeRatingFilters.clear();
    _invalidateCache();
    notifyListeners();
  }

  /// Ta bort recept
  Future<void> deleteRecipe(String recipeId) async {
    await _recipeService.deleteRecipe(recipeId);
    // UnifiedRecipeService hanterar notifications, vi behöver inte göra något här
    return;
  }

  /// Uppdatera data (pull-to-refresh)
  Future<void> refresh() async {
    await _recipeService.refresh();
  }

  /// Rensa fel
  void clearError() {
    _recipeService.clearError();
  }

  // ===== PRIVATE METHODS =====

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

  bool _setEquals<T>(Set<T>? a, Set<T>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  void _invalidateCache() {
    _cachedFilteredRecipes = null;
  }

  void _onRecipesChanged() {
    _invalidateCache();
    notifyListeners();
  }

  @override
  void dispose() {
    _recipeService.removeListener(_onRecipesChanged);
    super.dispose();
  }
}
