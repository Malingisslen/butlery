// lib/viewmodels/archive_import_viewmodel.dart

import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../services/search_service.dart';
import '../data/archived_recipes.dart' as archive;
import '../core/injection.dart';

enum TimeFilter { all, under15, under30, under60 }

/// ViewModel för import från arkiv
class ArchiveImportViewModel extends ChangeNotifier {
  final RecipeService _recipeService;
  final SearchService _searchService;

  // State
  final Set<String> _selectedTags = {};
  final Set<String> _selectedRecipeIds = {};
  TimeFilter _timeFilter = TimeFilter.all;
  String _searchQuery = '';
  bool _isImporting = false;
  String? _error;

  // Cache
  List<Recipe>? _cachedFilteredRecipes;
  String? _lastSearchQuery;
  TimeFilter? _lastTimeFilter;
  Set<String>? _lastSelectedTags;

  ArchiveImportViewModel({
    RecipeService? recipeService,
    SearchService? searchService,
  }) : _recipeService = recipeService ?? sl<RecipeService>(),
       _searchService = searchService ?? sl<SearchService>();

  // ===== GETTERS =====

  List<Recipe> get archivedRecipes => archive.archivedRecipes;
  List<Recipe> get filteredRecipes => _getFilteredRecipes();
  Set<String> get selectedTags => Set.unmodifiable(_selectedTags);
  Set<String> get selectedRecipeIds => Set.unmodifiable(_selectedRecipeIds);
  TimeFilter get timeFilter => _timeFilter;
  String get searchQuery => _searchQuery;
  bool get isImporting => _isImporting;
  String? get error => _error;
  bool get hasError => _error != null;

  int get selectedCount => _selectedRecipeIds.length;
  bool get hasSelection => _selectedRecipeIds.isNotEmpty;
  bool get allSelected => _selectedRecipeIds.length == filteredRecipes.length;

  // Hämta alla unika taggar från arkivet
  Set<String> get availableTags {
    final tags = <String>{};
    for (final recipe in archivedRecipes) {
      if (recipe.tags != null) {
        tags.addAll(recipe.tags!);
      }
    }
    return tags;
  }

  // ===== ACTIONS =====

  /// Uppdatera sökfråga
  void updateSearch(String query) {
    _searchQuery = query;
    _invalidateCache();
    _updateSelection();
    notifyListeners();
  }

  /// Toggle tagg-filter
  void toggleTag(String tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
    _invalidateCache();
    _updateSelection();
    notifyListeners();
  }

  /// Uppdatera tidsfilter
  void setTimeFilter(TimeFilter filter) {
    _timeFilter = filter;
    _invalidateCache();
    _updateSelection();
    notifyListeners();
  }

  /// Toggle recept-val
  void toggleRecipeSelection(String recipeId) {
    if (_selectedRecipeIds.contains(recipeId)) {
      _selectedRecipeIds.remove(recipeId);
    } else {
      _selectedRecipeIds.add(recipeId);
    }
    notifyListeners();
  }

  /// Markera/avmarkera alla
  void toggleSelectAll() {
    if (allSelected) {
      _selectedRecipeIds.clear();
    } else {
      _selectedRecipeIds.clear();
      _selectedRecipeIds.addAll(filteredRecipes.map((r) => r.id));
    }
    notifyListeners();
  }

  /// Importera valda recept
  Future<void> importSelectedRecipes() async {
    if (_selectedRecipeIds.isEmpty) {
      _setError('Inga recept valda');
      return;
    }

    _setImporting(true);

    try {
      final toImport =
          archivedRecipes
              .where((r) => _selectedRecipeIds.contains(r.id))
              .toList();

      final result = await _recipeService.addMultipleRecipes(toImport);

      if (result.isSuccess) {
        _error = null;
        _selectedRecipeIds.clear();
        notifyListeners();
      } else {
        _setError(result.message);
      }
    } catch (e) {
      _setError('Import misslyckades: ${e.toString()}');
    } finally {
      _setImporting(false);
    }
  }

  /// Importera alla (filtrerade) recept
  Future<void> importAllRecipes() async {
    _setImporting(true);

    try {
      final toImport =
          filteredRecipes.isEmpty ? archivedRecipes : filteredRecipes;
      final result = await _recipeService.addMultipleRecipes(toImport);

      if (result.isSuccess) {
        _error = null;
        _selectedRecipeIds.clear();
        notifyListeners();
      } else {
        _setError(result.message);
      }
    } catch (e) {
      _setError('Import misslyckades: ${e.toString()}');
    } finally {
      _setImporting(false);
    }
  }

  /// Rensa fel
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Rensa alla filter
  void clearFilters() {
    _searchQuery = '';
    _selectedTags.clear();
    _timeFilter = TimeFilter.all;
    _selectedRecipeIds.clear();
    _invalidateCache();
    notifyListeners();
  }

  // ===== PRIVATE METHODS =====

  List<Recipe> _getFilteredRecipes() {
    // Använd cache om möjligt
    if (_cachedFilteredRecipes != null &&
        _lastSearchQuery == _searchQuery &&
        _lastTimeFilter == _timeFilter &&
        _lastSelectedTags?.toString() == _selectedTags.toString()) {
      return _cachedFilteredRecipes!;
    }

    List<Recipe> results = List.from(archivedRecipes);

    // Sökfilter
    if (_searchQuery.isNotEmpty) {
      results = _searchService.searchRecipes(results, _searchQuery);
    }

    // Tagg-filter: AND-logik
    if (_selectedTags.isNotEmpty) {
      results = _searchService.filterByTags(results, _selectedTags.toList());
    }

    // Tids-filter
    switch (_timeFilter) {
      case TimeFilter.under15:
        results = _searchService.filterByMaxTime(results, 15);
        break;
      case TimeFilter.under30:
        results = _searchService.filterByMaxTime(results, 30);
        break;
      case TimeFilter.under60:
        results = _searchService.filterByMaxTime(results, 60);
        break;
      case TimeFilter.all:
        break;
    }

    // Cacha resultat
    _cachedFilteredRecipes = results;
    _lastSearchQuery = _searchQuery;
    _lastTimeFilter = _timeFilter;
    _lastSelectedTags = Set.from(_selectedTags);

    return results;
  }

  void _updateSelection() {
    // Uppdatera selection baserat på nya filter
    final currentRecipeIds = filteredRecipes.map((r) => r.id).toSet();
    _selectedRecipeIds.removeWhere((id) => !currentRecipeIds.contains(id));
  }

  void _invalidateCache() {
    _cachedFilteredRecipes = null;
  }

  void _setImporting(bool value) {
    _isImporting = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }
}
