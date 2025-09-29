/// Shared Content Search ViewModel providing unified search and filtering functionality.
///
/// This cross-cutting ViewModel handles search operations across all shared content types
/// (recipes, menus, shopping lists) with advanced filtering, query management, and
/// search result coordination. It implements the Strategy pattern to allow different
/// search algorithms for different content types while maintaining consistent UI.
///
/// **Responsibilities:**
/// - **Unified Search**: Search across all content types with single query
/// - **Advanced Filtering**: Filter by content type, status, date ranges
/// - **Query Management**: Search history, suggestions, recent searches
/// - **Result Coordination**: Aggregate and rank search results
/// - **Performance**: Debounced search, caching, result pagination
///
/// **Integration Points:**
/// - **Content ViewModels**: Delegates to specialized ViewModels for content-specific search
/// - **Search Algorithms**: Supports different search strategies per content type
/// - **UI Coordination**: Provides search state management for search UI components
///
/// **Usage Example:**
/// ```dart
/// final searchViewModel = SharedContentSearchViewModel(
///   recipeViewModel: recipeViewModel,
///   menuViewModel: menuViewModel,
///   shoppingViewModel: shoppingViewModel,
/// );
/// 
/// // Unified search
/// searchViewModel.updateSearchQuery('pasta');
/// final allResults = searchViewModel.allResults;
/// 
/// // Filtered search
/// searchViewModel.setContentTypeFilter(ContentType.recipes);
/// final recipeResults = searchViewModel.filteredResults;
/// 
/// // Advanced filtering
/// searchViewModel.setStatusFilter(ContentStatus.unread);
/// searchViewModel.setDateFilter(DateRange.lastWeek);
/// ```

// lib/viewmodels/shared_content/shared_content_search_viewmodel.dart

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
  final dynamic content; // Actual content object (SharedRecipe, SharedMenu, etc.)
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
  
  // ===== DEPENDENCIES =====
  
  final SharedRecipeViewModel _recipeViewModel;
  final SharedMenuViewModel _menuViewModel;
  final SharedShoppingViewModel _shoppingViewModel;

  // ===== STATE VARIABLES =====
  
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

  // ===== CONSTRUCTOR =====
  
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
    
    AppLogger.info('SharedContentSearchViewModel initialized for unified search');
  }

  // ===== GETTERS =====
  
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
      results = results.where((result) => result.contentType == _contentTypeFilter).toList();
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
      final now = DateTime.now();
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
            final lastWeekStart = now.subtract(Duration(days: now.weekday - 1 + 7));
            final lastWeekEnd = now.subtract(Duration(days: now.weekday - 1));
            return result.sharedAt.isAfter(lastWeekStart) && result.sharedAt.isBefore(lastWeekEnd);
          case DateRange.thisMonth:
            return result.sharedAt.month == now.month && result.sharedAt.year == now.year;
          case DateRange.lastMonth:
            final lastMonth = DateTime(now.year, now.month - 1);
            return result.sharedAt.month == lastMonth.month && result.sharedAt.year == lastMonth.year;
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
    counts[ContentType.recipes] = results.where((r) => r.contentType == ContentType.recipes).length;
    counts[ContentType.menus] = results.where((r) => r.contentType == ContentType.menus).length;
    counts[ContentType.shoppingLists] = results.where((r) => r.contentType == ContentType.shoppingLists).length;
    
    return counts;
  }
  
  /// Search history
  List<String> get searchHistory => List.unmodifiable(_searchHistory);
  
  /// Has search results
  bool get hasResults => filteredResults.isNotEmpty;

  // ===== SEARCH OPERATIONS =====
  
  /// Update search query with debouncing
  void updateSearchQuery(String query) {
    if (_searchQuery == query) return;
    
    _searchQuery = query;
    AppLogger.info('🔍 Search query updated: "${query.isEmpty ? 'EMPTY' : query}"');
    
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
    
    _setSearching(true);
    
    try {
      final results = <SearchResult>[];
      
      // Search recipes
      final recipeResults = await _searchRecipes(_searchQuery);
      results.addAll(recipeResults);
      
      // Search menus
      final menuResults = await _searchMenus(_searchQuery);
      results.addAll(menuResults);
      
      // Search shopping lists
      final shoppingResults = await _searchShoppingLists(_searchQuery);
      results.addAll(shoppingResults);
      
      _allResults = results;
      AppLogger.info('🔍 Search completed: ${results.length} results for "$_searchQuery"');
    } catch (e) {
      AppLogger.error('Search failed: $e');
      _allResults.clear();
    } finally {
      _setSearching(false);
    }
  }
  
  /// Search recipes with relevance scoring
  Future<List<SearchResult>> _searchRecipes(String query) async {
    final recipes = _recipeViewModel.content;
    final results = <SearchResult>[];
    
    for (final recipe in recipes) {
      if (_recipeViewModel.contentMatchesSearch(recipe, query)) {
        final relevanceScore = _calculateRecipeRelevance(recipe, query);
        results.add(SearchResult(
          id: recipe.id,
          title: recipe.recipeSnapshot.title,
          description: recipe.recipeSnapshot.description,
          contentType: ContentType.recipes,
          sharedAt: recipe.sharedAt,
          sharedByDisplayName: recipe.sharedByDisplayName,
          isUnread: _recipeViewModel.isRecipeViewed(recipe) == false,
          isImported: _recipeViewModel.isRecipeImported(recipe),
          isDismissed: _recipeViewModel.isRecipeDismissed(recipe),
          isCollaborative: _recipeViewModel.isRecipeCollaborative(recipe),
          content: recipe,
          relevanceScore: relevanceScore,
        ));
      }
    }
    
    return results;
  }
  
  /// Search menus with relevance scoring
  Future<List<SearchResult>> _searchMenus(String query) async {
    final menus = _menuViewModel.content;
    final results = <SearchResult>[];
    
    for (final menu in menus) {
      if (_menuViewModel.contentMatchesSearch(menu, query)) {
        final relevanceScore = _calculateMenuRelevance(menu, query);
        results.add(SearchResult(
          id: menu.id,
          title: menu.menuTitle,
          description: _menuViewModel.getMenuSummary(menu),
          contentType: ContentType.menus,
          sharedAt: menu.sharedAt,
          sharedByDisplayName: menu.sharedByDisplayName,
          isUnread: _menuViewModel.isMenuViewed(menu) == false,
          isImported: _menuViewModel.isMenuImported(menu),
          isDismissed: _menuViewModel.isMenuDismissed(menu),
          isCollaborative: _menuViewModel.isMenuCollaborative(menu),
          content: menu,
          relevanceScore: relevanceScore,
        ));
      }
    }
    
    return results;
  }
  
  /// Search shopping lists with relevance scoring  
  Future<List<SearchResult>> _searchShoppingLists(String query) async {
    final shoppingLists = _shoppingViewModel.content;
    final results = <SearchResult>[];
    
    for (final list in shoppingLists) {
      if (_shoppingViewModel.contentMatchesSearch(list, query)) {
        final relevanceScore = _calculateShoppingListRelevance(list, query);
        results.add(SearchResult(
          id: list.id,
          title: list.listName,
          description: _shoppingViewModel.getShoppingListSummary(list),
          contentType: ContentType.shoppingLists,
          sharedAt: list.sharedAt,
          sharedByDisplayName: list.sharedByDisplayName,
          isUnread: _shoppingViewModel.isShoppingListViewed(list) == false,
          isImported: false, // Shopping lists use join, not import
          isDismissed: _shoppingViewModel.isShoppingListDismissed(list),
          isCollaborative: _shoppingViewModel.isShoppingListJoined(list),
          content: list,
          relevanceScore: relevanceScore,
        ));
      }
    }
    
    return results;
  }

  // ===== FILTER OPERATIONS =====
  
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

  // ===== RELEVANCE SCORING =====
  
  /// Calculate relevance score for recipe search results
  double _calculateRecipeRelevance(SharedRecipe recipe, String query) {
    final lowerQuery = query.toLowerCase();
    double score = 0.0;
    
    // Title match (highest weight)
    if (recipe.recipeSnapshot.title.toLowerCase().contains(lowerQuery)) {
      score += 10.0;
      if (recipe.recipeSnapshot.title.toLowerCase().startsWith(lowerQuery)) {
        score += 5.0; // Bonus for title prefix match
      }
    }
    
    // Description match
    if (recipe.recipeSnapshot.description.toLowerCase().contains(lowerQuery)) {
      score += 5.0;
    }
    
    // Ingredient match
    for (final ingredient in recipe.recipeSnapshot.ingredients) {
      if (ingredient.toLowerCase().contains(lowerQuery)) {
        score += 3.0;
      }
    }
    
    // Shared by name match
    if (recipe.sharedByDisplayName.toLowerCase().contains(lowerQuery)) {
      score += 2.0;
    }
    
    // Recency bonus (newer content gets slight boost)
    final daysSinceShared = DateTime.now().difference(recipe.sharedAt).inDays;
    if (daysSinceShared < 7) {
      score += 1.0;
    }
    
    return score;
  }
  
  /// Calculate relevance score for menu search results
  double _calculateMenuRelevance(SharedMenu menu, String query) {
    final lowerQuery = query.toLowerCase();
    double score = 0.0;
    
    // Title match (highest weight)
    if (menu.menuTitle.toLowerCase().contains(lowerQuery)) {
      score += 10.0;
      if (menu.menuTitle.toLowerCase().startsWith(lowerQuery)) {
        score += 5.0;
      }
    }
    
    // Category match
    for (final category in menu.categories) {
      if (category.toLowerCase().contains(lowerQuery)) {
        score += 4.0;
      }
    }
    
    // Shared by name match
    if (menu.sharedByDisplayName.toLowerCase().contains(lowerQuery)) {
      score += 2.0;
    }
    
    // Recipe count bonus (larger menus might be more valuable)
    score += menu.totalRecipeCount * 0.5;
    
    // Recency bonus
    final daysSinceShared = DateTime.now().difference(menu.sharedAt).inDays;
    if (daysSinceShared < 7) {
      score += 1.0;
    }
    
    return score;
  }
  
  /// Calculate relevance score for shopping list search results
  double _calculateShoppingListRelevance(SharedShoppingList list, String query) {
    final lowerQuery = query.toLowerCase();
    double score = 0.0;
    
    // List name match (highest weight)
    if (list.listName.toLowerCase().contains(lowerQuery)) {
      score += 10.0;
      if (list.listName.toLowerCase().startsWith(lowerQuery)) {
        score += 5.0;
      }
    }
    
    // Item name matches
    for (final item in list.listItems) {
      if (item.name.toLowerCase().contains(lowerQuery)) {
        score += 3.0;
      }
    }
    
    // Description match
    if (list.listDescription?.toLowerCase().contains(lowerQuery) ?? false) {
      score += 4.0;
    }
    
    // Share message match
    if (list.shareMessage?.toLowerCase().contains(lowerQuery) == true) {
      score += 2.0;
    }
    
    // Shared by name match
    if (list.sharedByDisplayName.toLowerCase().contains(lowerQuery)) {
      score += 2.0;
    }
    
    // Item count bonus
    score += list.listItems.length * 0.3;
    
    // Recency bonus
    final daysSinceShared = DateTime.now().difference(list.sharedAt).inDays;
    if (daysSinceShared < 7) {
      score += 1.0;
    }
    
    return score;
  }

  // ===== STATE MANAGEMENT =====
  
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

  // ===== CLEANUP =====
  
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