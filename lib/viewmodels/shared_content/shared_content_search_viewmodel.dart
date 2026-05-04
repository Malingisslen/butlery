/// Unified search across shared content with filtering and relevance scoring.
/// Handles search across recipes, menus, and shopping lists with debouncing,
/// advanced filtering (type, status, date), and relevance-based ranking.

// lib/viewmodels/shared_content/shared_content_search_viewmodel.dart

import 'package:clock/clock.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/viewmodels/shared_content/shared_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_menu_viewmodel.dart';
import 'package:butlery/viewmodels/shared_content/shared_shopping_viewmodel.dart';
import 'package:butlery/core/utils/logger.dart';

/// Enumeration for content type filtering
enum ContentType {
  all,
  recipes,
  menus,
  shoppingLists,
}

/// Enumeration for content status filtering
enum ContentStatus {
  all,
  unread,
  imported,
  dismissed,
  collaborative,
}

/// Enumeration for date range filtering
enum DateRange {
  all,
  today,
  thisWeek,
  lastWeek,
  thisMonth,
  lastMonth,
}

/// Search result wrapper with metadata
class SearchResult {
  final String id;
  final String title;
  final String description;
  final ContentType contentType;
  final DateTime sharedAt;
  final String sharedByDisplayName;
  final bool isUnread;
  final bool isImported;
  final bool isDismissed;
  final bool isCollaborative;
  final dynamic
      content; // Actual content object (SharedRecipe, SharedMenu, etc.)
  final double relevanceScore;

  const SearchResult({
    required this.id,
    required this.title,
    required this.description,
    required this.contentType,
    required this.sharedAt,
    required this.sharedByDisplayName,
    required this.isUnread,
    required this.isImported,
    required this.isDismissed,
    required this.isCollaborative,
    required this.content,
    this.relevanceScore = 0.0,
  });
}

/// Unified search ViewModel for all shared content types
class SharedContentSearchViewModel extends ChangeNotifier {
  final SharedRecipeViewModel _recipeViewModel;
  final SharedMenuViewModel _menuViewModel;
  final SharedShoppingViewModel _shoppingViewModel;

  /// Current search query
  String _searchQuery = '';

  /// Content type filter
  ContentType _contentTypeFilter = ContentType.all;

  /// Status filter
  ContentStatus _statusFilter = ContentStatus.all;

  /// Date range filter
  DateRange _dateFilter = DateRange.all;

  /// Search debounce timer
  Timer? _searchDebounceTimer;

  /// Search in progress indicator
  bool _isSearching = false;

  /// Cached search results
  List<SearchResult> _allResults = [];

  /// Search query history
  List<String> _searchHistory = [];

  /// Maximum search history items
  static const int _maxHistoryItems = 10;

  /// Search debounce duration
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  SharedContentSearchViewModel({
    required SharedRecipeViewModel recipeViewModel,
    required SharedMenuViewModel menuViewModel,
    required SharedShoppingViewModel shoppingViewModel,
  })  : _recipeViewModel = recipeViewModel,
        _menuViewModel = menuViewModel,
        _shoppingViewModel = shoppingViewModel {
    // Listen to content changes from specialized ViewModels
    _recipeViewModel.addListener(_onContentChanged);
    _menuViewModel.addListener(_onContentChanged);
    _shoppingViewModel.addListener(_onContentChanged);

    AppLogger.info(
        'SharedContentSearchViewModel initialized for unified search');
  }

  /// Current search query
  String get searchQuery => _searchQuery;

  /// Content type filter
  ContentType get contentTypeFilter => _contentTypeFilter;

  /// Status filter
  ContentStatus get statusFilter => _statusFilter;

  /// Date range filter
  DateRange get dateFilter => _dateFilter;

  /// Search in progress
  bool get isSearching => _isSearching;

  /// Has active search query
  bool get hasSearchQuery => _searchQuery.isNotEmpty;

  /// Has active filters
  bool get hasActiveFilters =>
      _contentTypeFilter != ContentType.all ||
      _statusFilter != ContentStatus.all ||
      _dateFilter != DateRange.all;

  /// All search results (unfiltered except by query)
  List<SearchResult> get allResults => List.unmodifiable(_allResults);

  /// Filtered search results based on active filters
  List<SearchResult> get filteredResults {
    var results = _allResults;

    // Apply content type filter
    if (_contentTypeFilter != ContentType.all) {
      results = results
          .where((result) => result.contentType == _contentTypeFilter)
          .toList();
    }

    // Apply status filter
    if (_statusFilter != ContentStatus.all) {
      results = results.where((result) {
        switch (_statusFilter) {
          case ContentStatus.unread:
            return result.isUnread;
          case ContentStatus.imported:
            return result.isImported;
          case ContentStatus.dismissed:
            return result.isDismissed;
          case ContentStatus.collaborative:
            return result.isCollaborative;
          case ContentStatus.all:
            return true;
        }
      }).toList();
    }

    // Apply date filter
    if (_dateFilter != DateRange.all) {
      final now = clock.now();
      results = results.where((result) {
        switch (_dateFilter) {
          case DateRange.today:
            return result.sharedAt.day == now.day &&
                result.sharedAt.month == now.month &&
                result.sharedAt.year == now.year;
          case DateRange.thisWeek:
            final weekStart = now.subtract(Duration(days: now.weekday - 1));
            return result.sharedAt.isAfter(weekStart);
          case DateRange.lastWeek:
            final lastWeekStart =
                now.subtract(Duration(days: now.weekday - 1 + 7));
            final lastWeekEnd = now.subtract(Duration(days: now.weekday - 1));
            return result.sharedAt.isAfter(lastWeekStart) &&
                result.sharedAt.isBefore(lastWeekEnd);
          case DateRange.thisMonth:
            return result.sharedAt.month == now.month &&
                result.sharedAt.year == now.year;
          case DateRange.lastMonth:
            final lastMonth = DateTime(now.year, now.month - 1);
            return result.sharedAt.month == lastMonth.month &&
                result.sharedAt.year == lastMonth.year;
          case DateRange.all:
            return true;
        }
      }).toList();
    }

    // Sort by relevance score (highest first) then by date (newest first)
    results.sort((a, b) {
      final scoreCompare = b.relevanceScore.compareTo(a.relevanceScore);
      if (scoreCompare != 0) return scoreCompare;
      return b.sharedAt.compareTo(a.sharedAt);
    });

    return results;
  }

  /// Search results grouped by content type
  Map<ContentType, List<SearchResult>> get resultsByType {
    final results = filteredResults;
    final groupedResults = <ContentType, List<SearchResult>>{};

    for (final result in results) {
      groupedResults[result.contentType] ??= [];
      groupedResults[result.contentType]!.add(result);
    }

    return groupedResults;
  }

  /// Result counts by type
  Map<ContentType, int> get resultCounts {
    final counts = <ContentType, int>{};
    final results = filteredResults;

    counts[ContentType.all] = results.length;
    counts[ContentType.recipes] =
        results.where((r) => r.contentType == ContentType.recipes).length;
    counts[ContentType.menus] =
        results.where((r) => r.contentType == ContentType.menus).length;
    counts[ContentType.shoppingLists] =
        results.where((r) => r.contentType == ContentType.shoppingLists).length;

    return counts;
  }

  /// Search history
  List<String> get searchHistory => List.unmodifiable(_searchHistory);

  /// Has search results
  bool get hasResults => filteredResults.isNotEmpty;

  /// Update search query with debouncing
  void updateSearchQuery(String query) {
    if (_searchQuery == query) return;

    _searchQuery = query;
    AppLogger.info(
        '🔍 Search query updated: "${query.isEmpty ? 'EMPTY' : query}"');

    // Add to history if not empty and not already present
    if (query.isNotEmpty && !_searchHistory.contains(query)) {
      _searchHistory.insert(0, query);
      if (_searchHistory.length > _maxHistoryItems) {
        _searchHistory = _searchHistory.take(_maxHistoryItems).toList();
      }
    }

    // Cancel previous debounce timer
    _searchDebounceTimer?.cancel();

    // Set up new debounce timer
    _searchDebounceTimer = Timer(_debounceDuration, _performSearch);

    notifyListeners();
  }

  /// Clear search query and results
  void clearSearch() {
    _searchQuery = '';
    _allResults.clear();
    _searchDebounceTimer?.cancel();
    AppLogger.info('🧹 Search cleared');
    notifyListeners();
  }

  /// Perform the actual search across all content types
  Future<void> _performSearch() async {
    if (_searchQuery.isEmpty) {
      _allResults.clear();
      notifyListeners();
      return;
    }

    // Snapshot query at method start to prevent mixing across sequential awaits
    final query = _searchQuery;

    _setSearching(true);

    try {
      final results = [
        ...await _searchContent<SharedRecipe>(
            _recipeViewModel,
            ContentType.recipes,
            query,
            (SharedRecipe r) => SearchResult(
                  id: r.id,
                  title: r.recipeTitle,
                  description: r.recipeDescription ?? '',
                  contentType: ContentType.recipes,
                  sharedAt: r.sharedAt,
                  sharedByDisplayName: r.sharedByDisplayName,
                  isUnread: !_recipeViewModel.isRecipeViewed(r),
                  isImported: _recipeViewModel.isRecipeImported(r),
                  isDismissed: _recipeViewModel.isRecipeDismissed(r),
                  isCollaborative: _recipeViewModel.isRecipeCollaborative(r),
                  content: r,
                  relevanceScore: _calculateRecipeRelevance(r, query),
                )),
        ...await _searchContent<SharedMenu>(
            _menuViewModel,
            ContentType.menus,
            query,
            (SharedMenu m) => SearchResult(
                  id: m.id,
                  title: m.menuTitle,
                  description: _menuViewModel.getMenuSummary(m),
                  contentType: ContentType.menus,
                  sharedAt: m.sharedAt,
                  sharedByDisplayName: m.sharedByDisplayName,
                  isUnread: !_menuViewModel.isMenuViewed(m),
                  isImported: _menuViewModel.isMenuImported(m),
                  isDismissed: _menuViewModel.isMenuDismissed(m),
                  isCollaborative: _menuViewModel.isMenuCollaborative(m),
                  content: m,
                  relevanceScore: _calculateMenuRelevance(m, query),
                )),
        ...await _searchContent<SharedShoppingList>(
            _shoppingViewModel,
            ContentType.shoppingLists,
            query,
            (SharedShoppingList l) => SearchResult(
                  id: l.id,
                  title: l.listName,
                  description: _shoppingViewModel.getShoppingListSummary(l),
                  contentType: ContentType.shoppingLists,
                  sharedAt: l.sharedAt,
                  sharedByDisplayName: l.sharedByDisplayName,
                  isUnread: !_shoppingViewModel.isShoppingListViewed(l),
                  isImported: false,
                  isDismissed: _shoppingViewModel.isShoppingListDismissed(l),
                  isCollaborative: _shoppingViewModel.isShoppingListJoined(l),
                  content: l,
                  relevanceScore: _calculateShoppingListRelevance(l, query),
                )),
      ];

      // Only apply results if query hasn't changed during search
      if (_searchQuery == query) {
        _allResults = results;
        AppLogger.info(
            '🔍 Search completed: ${_allResults.length} results for "$query"');
      }
    } catch (e) {
      AppLogger.error('Search failed: $e');
      if (_searchQuery == query) {
        _allResults.clear();
      }
    } finally {
      if (_searchQuery == query) {
        _setSearching(false);
      }
    }
  }

  /// Generic search helper
  Future<List<SearchResult>> _searchContent<T>(
    dynamic viewModel,
    ContentType contentType,
    String query,
    SearchResult Function(T) resultBuilder,
  ) async {
    final content = viewModel.content as List<T>;
    final results = <SearchResult>[];

    for (final item in content) {
      if (viewModel.contentMatchesSearch(item, query)) {
        results.add(resultBuilder(item));
      }
    }

    return results;
  }

  /// Set content type filter
  void setContentTypeFilter(ContentType filter) {
    if (_contentTypeFilter != filter) {
      _contentTypeFilter = filter;
      AppLogger.info('📂 Content type filter set to: $filter');
      notifyListeners();
    }
  }

  /// Set status filter
  void setStatusFilter(ContentStatus filter) {
    if (_statusFilter != filter) {
      _statusFilter = filter;
      AppLogger.info('📊 Status filter set to: $filter');
      notifyListeners();
    }
  }

  /// Set date range filter
  void setDateFilter(DateRange filter) {
    if (_dateFilter != filter) {
      _dateFilter = filter;
      AppLogger.info('📅 Date filter set to: $filter');
      notifyListeners();
    }
  }

  /// Clear all filters
  void clearFilters() {
    var hasChanges = false;

    if (_contentTypeFilter != ContentType.all) {
      _contentTypeFilter = ContentType.all;
      hasChanges = true;
    }

    if (_statusFilter != ContentStatus.all) {
      _statusFilter = ContentStatus.all;
      hasChanges = true;
    }

    if (_dateFilter != DateRange.all) {
      _dateFilter = DateRange.all;
      hasChanges = true;
    }

    if (hasChanges) {
      AppLogger.info('🧹 All filters cleared');
      notifyListeners();
    }
  }

  /// Helper: Score title match with prefix bonus
  double _scoreTitleMatch(String title, String query) {
    final lowerTitle = title.toLowerCase();
    final lowerQuery = query.toLowerCase();
    if (!lowerTitle.contains(lowerQuery)) return 0.0;
    return lowerTitle.startsWith(lowerQuery) ? 15.0 : 10.0;
  }

  /// Helper: Recency bonus for recent shares
  double _recencyBonus(DateTime sharedAt) =>
      clock.now().difference(sharedAt).inDays < 7 ? 1.0 : 0.0;

  /// Helper: Shared by name match
  double _sharedByNameScore(String sharedByName, String query) =>
      sharedByName.toLowerCase().contains(query.toLowerCase()) ? 2.0 : 0.0;

  /// Calculate relevance score for recipe search results
  double _calculateRecipeRelevance(SharedRecipe recipe, String query) {
    final lowerQuery = query.toLowerCase();

    // Use denormalized fields for V2 efficiency
    double score = _scoreTitleMatch(recipe.recipeTitle, query);
    score +=
        (recipe.recipeDescription?.toLowerCase().contains(lowerQuery) ?? false)
            ? 5.0
            : 0.0;

    // If full snapshot available, search ingredients
    if (recipe.hasFullSnapshot) {
      score += recipe.recipeSnapshot!.ingredients
              .where((i) => i.toLowerCase().contains(lowerQuery))
              .length *
          3.0;
    }

    score += _sharedByNameScore(recipe.sharedByDisplayName, query);
    score += _recencyBonus(recipe.sharedAt);

    return score;
  }

  /// Calculate relevance score for menu search results
  double _calculateMenuRelevance(SharedMenu menu, String query) {
    return _scoreTitleMatch(menu.menuTitle, query) +
        menu.categories
                .where((c) => c.toLowerCase().contains(query.toLowerCase()))
                .length *
            4.0 +
        _sharedByNameScore(menu.sharedByDisplayName, query) +
        menu.totalRecipeCount * 0.5 +
        _recencyBonus(menu.sharedAt);
  }

  /// Calculate relevance score for shopping list search results
  double _calculateShoppingListRelevance(
      SharedShoppingList list, String query) {
    // Issue #015: Items now in subcollection, can't search without loading
    // Simplified scoring without item-level search
    final lowerQuery = query.toLowerCase();
    return _scoreTitleMatch(list.listName, query) +
        // Note: Can't search item names without loading from repository.getItems()
        (list.listDescription?.toLowerCase().contains(lowerQuery) == true
            ? 4.0
            : 0.0) +
        (list.shareMessage?.toLowerCase().contains(lowerQuery) == true
            ? 2.0
            : 0.0) +
        _sharedByNameScore(list.sharedByDisplayName, query) +
        list.itemCount * 0.3 +
        _recencyBonus(list.sharedAt);
  }

  /// Set searching state
  void _setSearching(bool searching) {
    if (_isSearching != searching) {
      _isSearching = searching;
      notifyListeners();
    }
  }

  /// Handle content changes from specialized ViewModels
  void _onContentChanged() {
    // Re-perform search if we have an active query
    if (_searchQuery.isNotEmpty) {
      _searchDebounceTimer?.cancel();
      _searchDebounceTimer = Timer(_debounceDuration, _performSearch);
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _recipeViewModel.removeListener(_onContentChanged);
    _menuViewModel.removeListener(_onContentChanged);
    _shoppingViewModel.removeListener(_onContentChanged);
    AppLogger.info('SharedContentSearchViewModel disposed');
    super.dispose();
  }
}
