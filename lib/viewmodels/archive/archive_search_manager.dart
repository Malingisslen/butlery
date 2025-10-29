/// Manager handling archive recipe search, filtering, and caching operations.

// lib/viewmodels/archive/archive_search_manager.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/data/archived_recipes.dart' as archive;

/// Time filtering options for recipe cooking duration.
enum TimeFilter { all, under15, under30, under60 }

/// Manages search, filtering, and caching for archive import operations.
class ArchiveSearchManager extends ChangeNotifier {
  final SearchService _searchService;

  // Filter state
  final Set<String> _selectedTags = {};
  TimeFilter _timeFilter = TimeFilter.all;
  String _searchQuery = '';

  // Cache state
  List<Recipe>? _cachedFilteredRecipes;
  String? _lastSearchQuery;
  TimeFilter? _lastTimeFilter;
  Set<String>? _lastSelectedTags;

  ArchiveSearchManager(this._searchService);

  // Getters
  List<Recipe> get archivedRecipes => archive.archivedRecipes;
  List<Recipe> get filteredRecipes => _getFilteredRecipes();
  Set<String> get selectedTags => Set.unmodifiable(_selectedTags);
  TimeFilter get timeFilter => _timeFilter;
  String get searchQuery => _searchQuery;

  /// Available tags from archived recipes.
  Set<String> get availableTags {
    final tags = <String>{};
    for (final recipe in archivedRecipes) {
      if (recipe.tags != null) {
        tags.addAll(recipe.tags!);
      }
    }
    return tags;
  }

  void updateSearch(String query) {
    _searchQuery = query;
    _invalidateCache();
    notifyListeners();
  }

  void toggleTag(String tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
    _invalidateCache();
    notifyListeners();
  }

  void setTimeFilter(TimeFilter filter) {
    _timeFilter = filter;
    _invalidateCache();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedTags.clear();
    _timeFilter = TimeFilter.all;
    _invalidateCache();
    notifyListeners();
  }

  /// Filters recipes based on search, tags, time with caching optimization.
  List<Recipe> _getFilteredRecipes() {
    // Use cache if possible
    if (_cachedFilteredRecipes != null &&
        _lastSearchQuery == _searchQuery &&
        _lastTimeFilter == _timeFilter &&
        _lastSelectedTags?.toString() == _selectedTags.toString()) {
      return _cachedFilteredRecipes!;
    }

    List<Recipe> results = List.from(archivedRecipes);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      results = _searchService.searchRecipes(results, _searchQuery);
    }

    // Tag filter: AND logic
    if (_selectedTags.isNotEmpty) {
      results = _searchService.filterByTags(results, _selectedTags.toList());
    }

    // Time filter
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

    // Cache results
    _cachedFilteredRecipes = results;
    _lastSearchQuery = _searchQuery;
    _lastTimeFilter = _timeFilter;
    _lastSelectedTags = Set.from(_selectedTags);

    return results;
  }

  void _invalidateCache() {
    _cachedFilteredRecipes = null;
  }
}
