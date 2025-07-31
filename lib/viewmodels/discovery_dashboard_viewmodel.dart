// lib/viewmodels/discovery_dashboard_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/operations/modules/recipe_discovery_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';

/// Manages the unified content discovery dashboard with trending content and social features.
///
/// This ViewModel serves as the central hub for content discovery within the Butlery
/// application, providing users with trending recipes, friend activity, and personalized
/// recommendations. It implements intelligent caching and state management for optimal
/// performance while handling multiple content types seamlessly.
///
/// Key responsibilities:
/// - Aggregating trending content across recipes, menus, and shopping lists
/// - Managing friend activity timeline with real-time updates
/// - Providing personalized content recommendations based on user preferences
/// - Handling advanced search and filtering across all discovery content
/// - Managing discovery categories and content organization
///
/// The ViewModel integrates with multiple services including the unified recipe service,
/// friends service, and social sharing repository to provide a comprehensive discovery
/// experience following MVVM architecture patterns.
///
/// Example usage:
/// ```dart
/// final viewModel = DiscoveryDashboardViewModel(
///   recipeService: sl<UnifiedRecipeService>(),
///   friendsService: sl<UnifiedFriendsService>(),
///   sharingRepository: sl<SocialSharingRepository>(),
/// );
/// await viewModel.initialize();
/// // Access trending content via trendingRecipes, friendActivity, etc.
/// ```
class DiscoveryDashboardViewModel extends ChangeNotifier {
  final UnifiedRecipeService _recipeService;
  late final RecipeDiscoveryService _discoveryService;

  // ===== STATE MANAGEMENT =====

  // Tab and search state
  int _activeTab = 0; // 0: Discovery, 1: Activity, 2: Recommendations
  String _searchQuery = '';
  String _selectedCategory = 'all';

  // Loading and error state
  bool _isInitialLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  // Discovery content state
  List<Recipe> _trendingRecipes = [];
  List<SharedMenu> _trendingMenus = [];
  List<UnifiedShoppingList> _trendingShoppingLists = [];
  
  // Friend activity state
  List<Map<String, dynamic>> _friendActivity = [];
  
  // Recommendations state
  List<Map<String, dynamic>> _personalizedRecommendations = [];
  
  // Search state
  List<Map<String, dynamic>> _searchResults = [];
  
  // Pagination state
  int _currentPage = 0;
  bool _hasMoreContent = true;

  // Discovery categories
  final List<Map<String, dynamic>> _discoveryCategories = [
    {'id': 'all', 'name': 'Allt', 'icon': 'explore', 'count': 0},
    {'id': 'recipes', 'name': 'Recept', 'icon': 'restaurant', 'count': 0},
    {'id': 'menus', 'name': 'Menyer', 'icon': 'calendar_month', 'count': 0},
    {'id': 'shopping_lists', 'name': 'Inköpslistor', 'icon': 'shopping_cart', 'count': 0},
    {'id': 'collaborative', 'name': 'Kollaborativt', 'icon': 'people', 'count': 0},
    {'id': 'trending', 'name': 'Populärt', 'icon': 'trending_up', 'count': 0},
  ];

  DiscoveryDashboardViewModel({
    required UnifiedRecipeService recipeService,
  })  : _recipeService = recipeService {
    _discoveryService = _recipeService.discovery;
  }

  // ===== GETTERS =====

  // Basic state getters
  int get activeTab => _activeTab;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  bool get isInitialLoading => _isInitialLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasError => _error != null;

  // Content getters
  List<Recipe> get trendingRecipes => List.unmodifiable(_trendingRecipes);
  List<SharedMenu> get trendingMenus => List.unmodifiable(_trendingMenus);
  List<UnifiedShoppingList> get trendingShoppingLists => List.unmodifiable(_trendingShoppingLists);
  List<Map<String, dynamic>> get friendActivity => List.unmodifiable(_friendActivity);
  List<Map<String, dynamic>> get personalizedRecommendations => List.unmodifiable(_personalizedRecommendations);
  List<Map<String, dynamic>> get searchResults => List.unmodifiable(_searchResults);
  List<Map<String, dynamic>> get discoveryCategories => List.unmodifiable(_discoveryCategories);

  // Content counts for tabs
  int get trendingContentCount => _trendingRecipes.length + _trendingMenus.length + _trendingShoppingLists.length;
  int get friendActivityCount => _friendActivity.length;
  int get recommendationsCount => _personalizedRecommendations.length;

  // Search and filtering
  bool get hasSearchResults => _searchResults.isNotEmpty;
  bool get hasMoreContent => _hasMoreContent;

  // Discovery statistics
  Map<String, dynamic> get discoveryStats => {
    'trendingRecipes': _trendingRecipes.length,
    'trendingMenus': _trendingMenus.length,
    'trendingShoppingLists': _trendingShoppingLists.length,
    'friendActivityItems': _friendActivity.length,
    'recommendations': _personalizedRecommendations.length,
    'totalDiscoverableContent': trendingContentCount,
    'searchResultsCount': _searchResults.length,
  };

  // ===== INITIALIZATION =====

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
        _loadTrendingContent(),
        _loadFriendActivity(),
        _loadPersonalizedRecommendations(),
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

  // ===== TRENDING CONTENT =====

  /// Load trending content across all types
  Future<void> _loadTrendingContent() async {
    try {
      AppLogger.info('📈 Loading trending content');

      // Load trending recipes
      _trendingRecipes = await _discoveryService.getTrendingRecipes(
        limit: 20,
        timeWindow: const Duration(days: 7),
      );

      // Load trending menus (simulated for now)
      _trendingMenus = await _loadTrendingMenus();

      // Load trending shopping lists (simulated for now)
      _trendingShoppingLists = await _loadTrendingShoppingLists();

      AppLogger.success('✅ Loaded trending content: ${_trendingRecipes.length} recipes, ${_trendingMenus.length} menus, ${_trendingShoppingLists.length} lists');
    } catch (e) {
      AppLogger.error('❌ Failed to load trending content', e);
      rethrow;
    }
  }

  /// Loads trending menus from the discovery service.
  ///
  /// Currently returns an empty list as menu discovery features are being
  /// developed. The delay simulates network latency for consistent UX.
  ///
  /// @returns Empty list of SharedMenu objects
  Future<List<SharedMenu>> _loadTrendingMenus() async {
    // Placeholder implementation while menu discovery service is in development
    await Future.delayed(const Duration(milliseconds: 200));
    return [];
  }

  /// Loads trending shopping lists from the discovery service.
  ///
  /// Currently returns an empty list as shopping list discovery features are being
  /// developed. The delay simulates network latency for consistent UX.
  ///
  /// @returns Empty list of UnifiedShoppingList objects
  Future<List<UnifiedShoppingList>> _loadTrendingShoppingLists() async {
    // Placeholder implementation while shopping list discovery service is in development
    await Future.delayed(const Duration(milliseconds: 200));
    return [];
  }

  // ===== FRIEND ACTIVITY =====

  /// Load friend activity timeline
  Future<void> _loadFriendActivity() async {
    try {
      AppLogger.info('👥 Loading friend activity');

      // Get recent collaborative recipes as friend activity
      final collaborativeRecipes = await _discoveryService.getRecentlySharedRecipes(
        limit: 15,
        timeWindow: const Duration(days: 3),
      );

      _friendActivity = collaborativeRecipes.map((recipe) {
        return {
          'id': recipe.id,
          'type': 'recipe_shared',
          'title': recipe.title,
          'description': recipe.description,
          'imageUrl': recipe.imageUrls.isNotEmpty ? recipe.imageUrls.first : null,
          'ownerName': recipe.socialData?.ownerDisplayName ?? 'Okänd användare',
          'ownerAvatarUrl': null, // Avatar URLs will be populated when user profile service integration is complete
          'sharedAt': recipe.createdAt,
          'contentType': 'recipe',
          'contentId': recipe.id,
          'engagement': {
            'likes': 0, // Like counts will be populated when social engagement metrics are implemented
            'comments': 0,
            'shares': recipe.socialData?.memberPermissions?.length ?? 0,
          },
        };
      }).toList();

      AppLogger.success('✅ Loaded ${_friendActivity.length} friend activity items');
    } catch (e) {
      AppLogger.error('❌ Failed to load friend activity', e);
      rethrow;
    }
  }

  // ===== PERSONALIZED RECOMMENDATIONS =====

  /// Load personalized content recommendations
  Future<void> _loadPersonalizedRecommendations() async {
    try {
      AppLogger.info('🎯 Loading personalized recommendations');

      // Get discovery statistics to understand user preferences
      final stats = _discoveryService.getDiscoveryStatistics();
      
      // Load recommendations based on user's sharing pattern
      if (stats['shared_with_me'] > 0) {
        // User receives shared content - recommend similar content
        final sharedWithMe = await _discoveryService.getSharedWithMe(limit: 10);
        
        _personalizedRecommendations = sharedWithMe.map((recipe) {
          return {
            'id': recipe.id,
            'type': 'similar_to_shared',
            'title': recipe.title,
            'description': recipe.description,
            'imageUrl': recipe.imageUrls.isNotEmpty ? recipe.imageUrls.first : null,
            'reason': 'Baserat på recept som delats med dig',
            'contentType': 'recipe',
            'contentId': recipe.id,
            'score': 0.8, // Similarity score
          };
        }).toList();
      } else {
        // New user or no shared content - recommend trending content
        _personalizedRecommendations = _trendingRecipes.take(10).map((recipe) {
          return {
            'id': recipe.id,
            'type': 'trending_for_you',
            'title': recipe.title,
            'description': recipe.description,
            'imageUrl': recipe.imageUrls.isNotEmpty ? recipe.imageUrls.first : null,
            'reason': 'Populärt just nu',
            'contentType': 'recipe',
            'contentId': recipe.id,
            'score': 0.6,
          };
        }).toList();
      }

      AppLogger.success('✅ Loaded ${_personalizedRecommendations.length} personalized recommendations');
    } catch (e) {
      AppLogger.error('❌ Failed to load personalized recommendations', e);
      rethrow;
    }
  }

  // ===== SEARCH FUNCTIONALITY =====

  /// Update search query and perform search
  Future<void> updateSearchQuery(String query) async {
    _searchQuery = query;
    notifyListeners();
    
    if (query.trim().isEmpty) {
      _searchResults.clear();
      AppLogger.info('🧹 Search cleared');
    } else {
      await _performSearch(query);
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

      // Search recipes
      final recipeResults = await _discoveryService.searchRecipes(
        query: query,
        limit: 20,
        includePersonal: false,
      );

      // Convert to unified search results format
      _searchResults = recipeResults.map((recipe) {
        return {
          'id': recipe.id,
          'type': 'recipe',
          'title': recipe.title,
          'description': recipe.description,
          'imageUrl': recipe.imageUrls.isNotEmpty ? recipe.imageUrls.first : null,
          'ownerName': recipe.socialData?.ownerDisplayName,
          'contentId': recipe.id,
          'relevanceScore': 1.0, // TODO: Implement proper relevance scoring
        };
      }).toList();

      // TODO: Add menu and shopping list search results when available

      AppLogger.success('✅ Found ${_searchResults.length} search results for "$query"');
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Search failed for "$query"', e);
      _searchResults.clear();
      notifyListeners();
    }
  }

  // ===== TAB AND CATEGORY MANAGEMENT =====

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
    // TODO: Implement category filtering logic
    AppLogger.info('🔧 Applying category filter: $_selectedCategory');
  }

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
            category['count'] = _trendingRecipes.length;
            break;
          case 'menus':
            category['count'] = _trendingMenus.length;
            break;
          case 'shopping_lists':
            category['count'] = _trendingShoppingLists.length;
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
          await _loadMoreTrendingContent();
          break;
        case 1: // Activity
          await _loadMoreFriendActivity();
          break;
        case 2: // Recommendations
          await _loadMoreRecommendations();
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

  /// Load more trending content
  Future<void> _loadMoreTrendingContent() async {
    final moreRecipes = await _discoveryService.getTrendingRecipes(
      limit: 10,
      timeWindow: const Duration(days: 14), // Expand time window for more content
    );
    
    if (moreRecipes.isEmpty) {
      _hasMoreContent = false;
    } else {
      _trendingRecipes.addAll(moreRecipes);
    }
  }

  /// Load more friend activity
  Future<void> _loadMoreFriendActivity() async {
    // TODO: Implement pagination for friend activity
    _hasMoreContent = false;
  }

  /// Load more recommendations
  Future<void> _loadMoreRecommendations() async {
    // TODO: Implement pagination for recommendations
    _hasMoreContent = false;
  }

  // ===== REFRESH =====

  /// Refresh all discovery content
  Future<void> refresh() async {
    _currentPage = 0;
    _hasMoreContent = true;
    await _loadAllContent();
  }

  // ===== STATE MANAGEMENT HELPERS =====

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

}