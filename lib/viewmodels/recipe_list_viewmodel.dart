// lib/viewmodels/recipe_list_viewmodel.dart

import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../services/search_service.dart';
import '../core/injection.dart';

/// ViewModel för MinaReceptView
/// Hanterar all business logic för receptlistan
class RecipeListViewModel extends ChangeNotifier {
  final RecipeService _recipeService;
  final SearchService _searchService;

  // Search & Sort state
  String _searchQuery = '';
  SortCriteria _sortCriteria = SortCriteria.title;
  bool _sortAscending = true;

  // Cache för optimering
  List<Recipe>? _cachedFilteredRecipes;
  String? _lastSearchQuery;
  SortCriteria? _lastSortCriteria;
  bool? _lastSortAscending;

  RecipeListViewModel({
    RecipeService? recipeService,
    SearchService? searchService,
  }) : _recipeService = recipeService ?? sl<RecipeService>(),
       _searchService = searchService ?? sl<SearchService>() {
    // Lyssna på ändringar från RecipeService
    _recipeService.addListener(_onRecipesChanged);
  }

  // ===== GETTERS =====

  List<Recipe> get recipes => _getFilteredAndSortedRecipes();
  bool get isLoading => _recipeService.isLoading;
  String? get error => _recipeService.lastError;
  bool get hasError => _recipeService.hasError;

  String get searchQuery => _searchQuery;
  SortCriteria get sortCriteria => _sortCriteria;
  bool get sortAscending => _sortAscending;

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

  /// Ta bort recept
  Future<void> deleteRecipe(String recipeId) async {
    await _recipeService.deleteRecipe(recipeId);
    // RecipeService hanterar notifications, vi behöver inte göra något här
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
        _lastSortAscending == _sortAscending) {
      return _cachedFilteredRecipes!;
    }

    // Sök
    final searchResults = _searchService.searchRecipes(
      _recipeService.recipes,
      _searchQuery,
    );

    // Sortera
    final sorted = _searchService.sortRecipes(
      searchResults,
      _sortCriteria,
      ascending: _sortAscending,
    );

    // Cacha resultat
    _cachedFilteredRecipes = sorted;
    _lastSearchQuery = _searchQuery;
    _lastSortCriteria = _sortCriteria;
    _lastSortAscending = _sortAscending;

    return sorted;
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
