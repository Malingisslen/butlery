// lib/viewmodels/discovery_dashboard_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/operations/modules/recipe_discovery_service.dart';
import 'package:butlery/services/recommendation_service.dart';
import 'package:butlery/models/recommendation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';

// Import focused managers
import 'package:butlery/viewmodels/discovery_dashboard/discovery_content_manager.dart';
import 'package:butlery/viewmodels/discovery_dashboard/discovery_friend_activity_manager.dart';
import 'package:butlery/viewmodels/discovery_dashboard/discovery_recommendations_manager.dart';

/// Discovery dashboard ViewModel for trending content, friend activity, and recommendations.
/// ```dart
/// final vm = DiscoveryDashboardViewModel(); await vm.initialize();
class DiscoveryDashboardViewModel extends ChangeNotifier
    with StreamManagementMixin, StateNotifierMixin, AsyncOperationMixin {
  late final UnifiedRecipeService _recipeService;
  late final RecommendationService _recommendationService;
  late final RecipeDiscoveryService _discoveryService;

  // Manager instances
  late final DiscoveryContentManager _contentManager;
  late final DiscoveryFriendActivityManager _friendActivityManager;
  late final DiscoveryRecommendationsManager _recommendationsManager;

  // State
  int _activeTab = 0;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  final Map<String, bool> _contentTypeFilters = {
    'recipes': true,
    'menus': true,
    'shopping_lists': true
  };
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  List<Map<String, dynamic>> _searchResults = [];
  int _currentPage = 0;
  bool _hasMoreContent = true;
  bool _showTrendingContent = true;
  bool _showFriendActivity = true;
  bool _showRecommendations = true;
  bool _enablePushNotifications = true;
  final List<Map<String, dynamic>> _discoveryCategories = [
    {'id': 'all', 'name': 'Allt', 'icon': 'explore', 'count': 0},
    {'id': 'recipes', 'name': 'Recept', 'icon': 'restaurant', 'count': 0},
    {'id': 'menus', 'name': 'Menyer', 'icon': 'calendar_month', 'count': 0},
    {
      'id': 'shopping_lists',
      'name': 'Inköpslistor',
      'icon': 'shopping_cart',
      'count': 0
    },
    {
      'id': 'collaborative',
      'name': 'Kollaborativt',
      'icon': 'people',
      'count': 0
    },
    {'id': 'trending', 'name': 'Populärt', 'icon': 'trending_up', 'count': 0},
  ];

  DiscoveryDashboardViewModel() {
    // Get services from DI
    _recipeService = ServiceLocator.get<UnifiedRecipeService>();
    _recommendationService = ServiceLocator.get<RecommendationService>();
    _discoveryService = _recipeService.discovery;

    // Initialize focused managers with required dependencies
    _contentManager =
        DiscoveryContentManager(discoveryService: _discoveryService);
    _friendActivityManager =
        DiscoveryFriendActivityManager(discoveryService: _discoveryService);
    _recommendationsManager = DiscoveryRecommendationsManager(
        recommendationService: _recommendationService);

    // Load settings from persistent storage on initialization
    loadDiscoverySettings();
  }

  // Getters
  int get activeTab => _activeTab;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  bool get isInitialLoading => _isInitialLoading;
  bool get isLoadingMore => _isLoadingMore;
  @override
  String? get error => _error;
  @override
  bool get hasError => _error != null;
  List<Recipe> get trendingRecipes => _contentManager.trendingRecipes;
  List<SharedMenu> get trendingMenus => _contentManager.trendingMenus;
  List<UnifiedShoppingList> get trendingShoppingLists =>
      _contentManager.trendingShoppingLists;
  List<Map<String, dynamic>> get friendActivity =>
      _friendActivityManager.friendActivity;
  List<Map<String, dynamic>> get personalizedRecommendations =>
      _recommendationsManager.personalizedRecommendations;
  List<Map<String, dynamic>> get searchResults =>
      List.unmodifiable(_searchResults);
  List<Map<String, dynamic>> get discoveryCategories =>
      List.unmodifiable(_discoveryCategories);
  Map<String, bool> get contentTypeFilters =>
      Map.unmodifiable(_contentTypeFilters);
  bool get recipesFilterEnabled => _contentTypeFilters['recipes'] ?? true;
  bool get menusFilterEnabled => _contentTypeFilters['menus'] ?? true;
  bool get shoppingListsFilterEnabled =>
      _contentTypeFilters['shopping_lists'] ?? true;
  int get trendingContentCount => _contentManager.trendingContentCount;
  int get friendActivityCount => _friendActivityManager.friendActivityCount;
  int get recommendationsCount => _recommendationsManager.recommendationsCount;
  bool get hasSearchResults => _searchResults.isNotEmpty;
  bool get hasMoreContent => _hasMoreContent;
  Map<String, dynamic> get discoveryStats => {
        'trendingRecipes': _contentManager.trendingRecipes.length,
        'trendingMenus': _contentManager.trendingMenus.length,
        'trendingShoppingLists': _contentManager.trendingShoppingLists.length,
        'friendActivityItems': _friendActivityManager.friendActivity.length,
        'recommendations':
            _recommendationsManager.personalizedRecommendations.length,
        'totalDiscoverableContent': trendingContentCount,
        'searchResultsCount': _searchResults.length,
      };
  bool get showTrendingContent => _showTrendingContent;
  bool get showFriendActivity => _showFriendActivity;
  bool get showRecommendations => _showRecommendations;
  bool get enablePushNotifications => _enablePushNotifications;

  /// Initialize the discovery dashboard
  Future<void> initialize() async {
    AppLogger.info('🔍 Initializing Discovery Dashboard');
    await _loadAllContent();
  }

  /// Load all discovery content
  Future<void> _loadAllContent() async {
    _setInitialLoading(true);
    _setError(null);

    try {
      await Future.wait([
        _contentManager.loadAllTrendingContent(),
        _friendActivityManager.loadFriendActivity(),
        _recommendationsManager.loadPersonalizedRecommendations(),
        _updateCategoryCounts(),
      ]);

      AppLogger.success('✅ Discovery Dashboard initialized successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to initialize Discovery Dashboard', e);
      _setError('Kunde inte ladda upptäcktsinnehåll: ${e.toString()}');
    } finally {
      _setInitialLoading(false);
    }
  }

  /// Provide feedback on a recommendation
  Future<void> provideRecommendationFeedback(
      String recommendationId, FeedbackType feedbackType) async {
    await _recommendationsManager.provideRecommendationFeedback(
        recommendationId, feedbackType);
    notifyListeners();
  }

  /// Dismiss a recommendation
  Future<void> dismissRecommendation(String recommendationId) async {
    await _recommendationsManager.dismissRecommendation(recommendationId);
    notifyListeners();
  }

  /// Undo dismissal of a recommendation
  Future<void> undoRecommendationDismissal(String recommendationId) async {
    await _recommendationsManager.undoRecommendationDismissal(recommendationId);
    notifyListeners();
  }

  /// Update search query and perform search with debouncing to avoid excessive server calls
  Future<void> updateSearchQuery(String query) async {
    _searchQuery = query;
    notifyListeners();

    if (query.trim().isEmpty) {
      _searchResults.clear();
      AppLogger.info('🧹 Search cleared');
    } else {
      // Debounce search to avoid excessive service calls on every keystroke
      await executeDebounced(
        'discoverySearch',
        () => _performSearch(query),
        const Duration(milliseconds: 300),
      );
    }
  }

  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    _searchResults.clear();
    notifyListeners();
    AppLogger.info('🧹 Search cleared');
  }

  /// Perform search across all content types
  Future<void> _performSearch(String query) async {
    try {
      AppLogger.info('🔍 Searching for: "$query"');
      final queryLower = query.toLowerCase();
      final allResults = <Map<String, dynamic>>[];
      if (_contentTypeFilters['recipes'] == true) {
        final recipeResults = await _contentManager.searchRecipes(query);
        allResults.addAll(recipeResults);
      }
      if (_contentTypeFilters['menus'] == true) {
        final menuResults = _contentManager.searchMenus(queryLower);
        allResults.addAll(menuResults);
      }
      if (_contentTypeFilters['shopping_lists'] == true) {
        final shoppingListResults =
            _contentManager.searchShoppingLists(queryLower);
        allResults.addAll(shoppingListResults);
      }
      allResults.sort((a, b) => (b['relevanceScore'] as double)
          .compareTo(a['relevanceScore'] as double));

      _searchResults = allResults;
      AppLogger.success(
          '✅ Found ${_searchResults.length} search results for "$query"');
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Search failed for "$query"', e);
      _searchResults.clear();
      notifyListeners();
    }
  }

  /// Set active tab
  void setActiveTab(int tabIndex) {
    if (tabIndex != _activeTab) {
      _activeTab = tabIndex;
      notifyListeners();
      AppLogger.info('📑 Discovery tab changed to: $tabIndex');
    }
  }

  /// Set selected category
  void setSelectedCategory(String categoryId) {
    if (categoryId != _selectedCategory) {
      _selectedCategory = categoryId;
      notifyListeners();
      AppLogger.info('🏷️ Discovery category changed to: $categoryId');

      // Filter content based on category if needed
      _applyCategoryFilter();
    }
  }

  /// Apply category filter to content
  void _applyCategoryFilter() {
    if (_selectedCategory == 'all') {
      // Show all content when 'all' is selected
      AppLogger.info('🔧 Showing all content - no filtering applied');
      return;
    }

    // Apply category filter via content manager
    _contentManager.applyCategoryFilter(_selectedCategory);

    AppLogger.info(
        '🔧 Applied category filter: $_selectedCategory via content manager');
    notifyListeners();
  }

  // ===== FILTER MANAGEMENT =====

  /// Toggle content type filter
  void toggleContentTypeFilter(String contentType) {
    if (_contentTypeFilters.containsKey(contentType)) {
      _contentTypeFilters[contentType] =
          !(_contentTypeFilters[contentType] ?? true);
      notifyListeners();
      AppLogger.info(
          '🔧 Toggled $contentType filter: ${_contentTypeFilters[contentType]}');

      // Re-run search if there's an active query to apply filters
      if (_searchQuery.isNotEmpty) {
        _performSearch(_searchQuery);
      }
    }
  }

  /// Set specific content type filter state
  void setContentTypeFilter(String contentType, bool enabled) {
    if (_contentTypeFilters.containsKey(contentType) &&
        _contentTypeFilters[contentType] != enabled) {
      _contentTypeFilters[contentType] = enabled;
      notifyListeners();
      AppLogger.info('🔧 Set $contentType filter: $enabled');

      // Re-run search if there's an active query to apply filters
      if (_searchQuery.isNotEmpty) {
        _performSearch(_searchQuery);
      }
    }
  }

  /// Reset all filters to enabled state
  void resetFilters() {
    bool changed = false;
    for (final key in _contentTypeFilters.keys) {
      if (_contentTypeFilters[key] != true) {
        _contentTypeFilters[key] = true;
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
      AppLogger.info('🔧 Reset all content type filters');

      // Re-run search if there's an active query to apply filters
      if (_searchQuery.isNotEmpty) {
        _performSearch(_searchQuery);
      }
    }
  }

  // Search utility methods moved to respective managers

  /// Update category counts
  Future<void> _updateCategoryCounts() async {
    try {
      final stats = _discoveryService.getDiscoveryStatistics();

      // Update category counts based on available content
      for (var category in _discoveryCategories) {
        switch (category['id']) {
          case 'all':
            category['count'] = trendingContentCount;
            break;
          case 'recipes':
            category['count'] = _contentManager.trendingRecipes.length;
            break;
          case 'menus':
            category['count'] = _contentManager.trendingMenus.length;
            break;
          case 'shopping_lists':
            category['count'] = _contentManager.trendingShoppingLists.length;
            break;
          case 'collaborative':
            category['count'] = stats['shared_with_me'] ?? 0;
            break;
          case 'trending':
            category['count'] = trendingContentCount;
            break;
        }
      }

      AppLogger.success('✅ Updated discovery categories with counts');
    } catch (e) {
      AppLogger.error('❌ Failed to update category counts', e);
    }
  }

  // ===== INFINITE LOADING =====

  /// Load more content for infinite scrolling
  Future<void> loadMoreContent() async {
    if (_isLoadingMore || !_hasMoreContent) return;

    _setLoadingMore(true);

    try {
      AppLogger.info('📄 Loading more content (page ${_currentPage + 1})');

      // Load more based on active tab
      switch (_activeTab) {
        case 0: // Discovery
          await _contentManager.loadMoreTrendingContent();
          break;
        case 1: // Activity
          await _friendActivityManager.loadMoreActivity();
          break;
        case 2: // Recommendations
          await _recommendationsManager.loadMoreRecommendations();
          break;
      }

      _currentPage++;
      AppLogger.success('✅ Loaded more content (page $_currentPage)');
    } catch (e) {
      AppLogger.error('❌ Failed to load more content', e);
    } finally {
      _setLoadingMore(false);
    }
  }

  // Helper methods for mock data generation moved to respective managers

  // ===== REFRESH =====

  /// Refresh all discovery content
  Future<void> refresh() async {
    _currentPage = 0;
    _hasMoreContent = true;
    await _loadAllContent();
  }

  // ===== STATE MANAGEMENT HELPERS =====

  @override
  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  void _setInitialLoading(bool loading) {
    _isInitialLoading = loading;
    notifyListeners();
  }

  void _setLoadingMore(bool loading) {
    _isLoadingMore = loading;
    notifyListeners();
  }

  // ===== DISCOVERY SETTINGS MANAGEMENT =====

  /// Set whether to show trending content
  void setShowTrendingContent(bool show) {
    if (_showTrendingContent != show) {
      _showTrendingContent = show;
      notifyListeners();
    }
  }

  /// Set whether to show friend activity
  void setShowFriendActivity(bool show) {
    if (_showFriendActivity != show) {
      _showFriendActivity = show;
      notifyListeners();
    }
  }

  /// Set whether to show recommendations
  void setShowRecommendations(bool show) {
    if (_showRecommendations != show) {
      _showRecommendations = show;
      notifyListeners();
    }
  }

  /// Set whether to enable push notifications
  void setEnablePushNotifications(bool enable) {
    if (_enablePushNotifications != enable) {
      _enablePushNotifications = enable;
      notifyListeners();
    }
  }

  /// Save discovery settings to persistent storage
  /// ✅ FIXED: Implemented persistent storage using SharedPreferences
  Future<void> saveDiscoverySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save all discovery settings to SharedPreferences
      await Future.wait([
        prefs.setBool('discovery_show_trending', _showTrendingContent),
        prefs.setBool('discovery_show_friend_activity', _showFriendActivity),
        prefs.setBool('discovery_show_recommendations', _showRecommendations),
        prefs.setBool(
            'discovery_enable_notifications', _enablePushNotifications),
      ]);

      AppLogger.success('Discovery settings saved to persistent storage: '
          'trending=$_showTrendingContent, activity=$_showFriendActivity, '
          'recommendations=$_showRecommendations, notifications=$_enablePushNotifications');

      // Refresh content based on new settings
      await _loadAllContent();
    } catch (e) {
      AppLogger.error('Failed to save discovery settings', e);
      rethrow;
    }
  }

  /// Load discovery settings from persistent storage
  /// ✅ FIXED: Load saved settings on app startup
  Future<void> loadDiscoverySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load settings with fallback to defaults
      _showTrendingContent = prefs.getBool('discovery_show_trending') ?? true;
      _showFriendActivity =
          prefs.getBool('discovery_show_friend_activity') ?? true;
      _showRecommendations =
          prefs.getBool('discovery_show_recommendations') ?? true;
      _enablePushNotifications =
          prefs.getBool('discovery_enable_notifications') ?? true;

      AppLogger.info('Loaded discovery settings from persistent storage: '
          'trending=$_showTrendingContent, activity=$_showFriendActivity, '
          'recommendations=$_showRecommendations, notifications=$_enablePushNotifications');

      notifyListeners();
    } catch (e) {
      AppLogger.warning(
          'Failed to load discovery settings, using defaults: $e');
      // Keep default values if loading fails
    }
  }

  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions
    // Dispose of resources
    disposeStreamResources(); // From StreamManagementMixin
    super.dispose();
  }
}
