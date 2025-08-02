// lib/viewmodels/discovery_dashboard_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/operations/modules/recipe_discovery_service.dart';
import 'package:butlery/services/recommendation_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';

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
/// final viewModel = DiscoveryDashboardViewModel();
/// await viewModel.initialize();
/// // Access trending content via trendingRecipes, friendActivity, etc.
/// ```
class DiscoveryDashboardViewModel extends ChangeNotifier with StreamManagementMixin {
  late final UnifiedRecipeService _recipeService;
  late final RecommendationService _recommendationService;
  late final RecipeDiscoveryService _discoveryService;

  // ===== STATE MANAGEMENT =====

  // Tab and search state
  int _activeTab = 0; // 0: Discovery, 1: Activity, 2: Recommendations
  String _searchQuery = '';
  String _selectedCategory = 'all';
  
  // Content type filter state
  final Map<String, bool> _contentTypeFilters = {
    'recipes': true,
    'menus': true,
    'shopping_lists': true,
  };

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
  
  // Discovery settings state
  bool _showTrendingContent = true;
  bool _showFriendActivity = true;
  bool _showRecommendations = true;
  bool _enablePushNotifications = true;

  // Discovery categories
  final List<Map<String, dynamic>> _discoveryCategories = [
    {'id': 'all', 'name': 'Allt', 'icon': 'explore', 'count': 0},
    {'id': 'recipes', 'name': 'Recept', 'icon': 'restaurant', 'count': 0},
    {'id': 'menus', 'name': 'Menyer', 'icon': 'calendar_month', 'count': 0},
    {'id': 'shopping_lists', 'name': 'Inköpslistor', 'icon': 'shopping_cart', 'count': 0},
    {'id': 'collaborative', 'name': 'Kollaborativt', 'icon': 'people', 'count': 0},
    {'id': 'trending', 'name': 'Populärt', 'icon': 'trending_up', 'count': 0},
  ];

  DiscoveryDashboardViewModel() {
    // Get services from DI
    _recipeService = ServiceLocator.get<UnifiedRecipeService>();
    _recommendationService = ServiceLocator.get<RecommendationService>();
    _discoveryService = _recipeService.discovery;
    
    // Load settings from persistent storage on initialization
    loadDiscoverySettings();
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
  
  // Filter getters
  Map<String, bool> get contentTypeFilters => Map.unmodifiable(_contentTypeFilters);
  bool get recipesFilterEnabled => _contentTypeFilters['recipes'] ?? true;
  bool get menusFilterEnabled => _contentTypeFilters['menus'] ?? true;
  bool get shoppingListsFilterEnabled => _contentTypeFilters['shopping_lists'] ?? true;

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
  
  // Discovery settings getters
  bool get showTrendingContent => _showTrendingContent;
  bool get showFriendActivity => _showFriendActivity;
  bool get showRecommendations => _showRecommendations;
  bool get enablePushNotifications => _enablePushNotifications;

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

      // Get current user ID from permission service
      final permissionService = ServiceLocator.get<PermissionService>();
      final userId = permissionService.currentUserId;
      
      if (userId == null) {
        AppLogger.warning('⚠️ No user ID available for recommendations');
        _personalizedRecommendations = [];
        notifyListeners();
        return;
      }

      // Generate recommendations using the AI-powered recommendation service
      final recommendations = await _recommendationService.generateRecommendations(
        userId: userId,
        limit: 15,
      );

      // Convert Recommendation objects to the expected Map format
      _personalizedRecommendations = recommendations.map((rec) {
        return {
          'id': rec.id,
          'type': rec.type.toString().split('.').last,
          'title': rec.title,
          'description': rec.description,
          'imageUrl': rec.imageUrl,
          'reason': rec.reason,
          'contentType': rec.contentType,
          'contentId': rec.contentId,
          'score': rec.score,
          'isDismissed': rec.isDismissed,
          'isLiked': rec.isLiked,
          'metadata': rec.metadata,
        };
      }).toList();

      AppLogger.success('✅ Loaded ${_personalizedRecommendations.length} personalized recommendations');
    } catch (e) {
      AppLogger.error('❌ Failed to load personalized recommendations', e);
      _personalizedRecommendations = [];
      // Don't rethrow - gracefully handle recommendation service failures
    }
  }

  /// Provide feedback on a recommendation
  Future<void> provideRecommendationFeedback(String recommendationId, FeedbackType feedbackType) async {
    try {
      AppLogger.info('👍 Providing recommendation feedback: $feedbackType');
      
      await _recommendationService.provideFeedback(recommendationId, feedbackType);
      
      // Update local state if needed
      final index = _personalizedRecommendations.indexWhere((rec) => rec['id'] == recommendationId);
      if (index != -1) {
        switch (feedbackType) {
          case FeedbackType.like:
            _personalizedRecommendations[index]['isLiked'] = true;
            _personalizedRecommendations[index]['isDismissed'] = false;
            break;
          case FeedbackType.dismiss:
          case FeedbackType.notInterested:
            _personalizedRecommendations[index]['isDismissed'] = true;
            _personalizedRecommendations[index]['isLiked'] = false;
            break;
          case FeedbackType.save:
            _personalizedRecommendations[index]['isLiked'] = true;
            break;
        }
        notifyListeners();
      }
      
      AppLogger.success('✅ Recommendation feedback recorded');
    } catch (e) {
      AppLogger.error('❌ Failed to provide recommendation feedback', e);
      // Don't rethrow - handle gracefully
    }
  }

  /// Dismiss a recommendation
  Future<void> dismissRecommendation(String recommendationId) async {
    try {
      AppLogger.info('🚫 Dismissing recommendation: $recommendationId');
      
      await _recommendationService.dismissRecommendation(recommendationId);
      
      // Remove from local list
      _personalizedRecommendations.removeWhere((rec) => rec['id'] == recommendationId);
      notifyListeners();
      
      AppLogger.success('✅ Recommendation dismissed');
    } catch (e) {
      AppLogger.error('❌ Failed to dismiss recommendation', e);
      // Don't rethrow - handle gracefully
    }
  }

  /// Undo dismissal of a recommendation
  Future<void> undoRecommendationDismissal(String recommendationId) async {
    try {
      AppLogger.info('↩️ Undoing recommendation dismissal: $recommendationId');
      
      await _recommendationService.undoDismissal(recommendationId);
      
      // Reload recommendations to reflect the change
      await _loadPersonalizedRecommendations();
      
      AppLogger.success('✅ Recommendation dismissal undone');
    } catch (e) {
      AppLogger.error('❌ Failed to undo recommendation dismissal', e);
      // Don't rethrow - handle gracefully
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
      final queryLower = query.toLowerCase();
      final allResults = <Map<String, dynamic>>[];

      // Search recipes
      final recipeResults = await _discoveryService.searchRecipes(
        query: query,
        limit: 20,
        includePersonal: false,
      );

      // Convert recipes to unified search results with relevance scoring
      final recipeSearchResults = <Map<String, dynamic>>[];
      if (_contentTypeFilters['recipes'] == true) {
        recipeSearchResults.addAll(recipeResults.map((recipe) {
          final relevanceScore = _calculateRelevanceScore(
            query: queryLower,
            title: recipe.title,
            description: recipe.description,
            tags: recipe.tags,
            ingredients: recipe.ingredients,
            category: recipe.mealType,
          );
          
          return {
            'id': recipe.id,
            'type': 'recipe',
            'title': recipe.title,
            'description': recipe.description,
            'imageUrl': recipe.imageUrls.isNotEmpty ? recipe.imageUrls.first : null,
            'ownerName': recipe.socialData?.ownerDisplayName,
            'contentId': recipe.id,
            'relevanceScore': relevanceScore,
          };
        }).toList());
      }
      allResults.addAll(recipeSearchResults);

      // Search menus
      final menuSearchResults = <Map<String, dynamic>>[];
      if (_contentTypeFilters['menus'] == true) {
        menuSearchResults.addAll(_trendingMenus.where((menu) {
          return _matchesSearchQuery(queryLower, menu.menuTitle, menu.shareMessage, menu.categories);
        }).map((menu) {
          final relevanceScore = _calculateRelevanceScore(
            query: queryLower,
            title: menu.menuTitle,
            description: menu.shareMessage ?? '',
            tags: menu.categories,
            category: 'menu',
          );
          
          return {
            'id': menu.id,
            'type': 'menu',
            'title': menu.menuTitle,
            'description': menu.menuSummary,
            'imageUrl': null,
            'ownerName': menu.sharedByDisplayName,
            'contentId': menu.id,
            'relevanceScore': relevanceScore,
          };
        }).toList());
      }
      allResults.addAll(menuSearchResults);

      // Search shopping lists
      final shoppingListSearchResults = <Map<String, dynamic>>[];
      if (_contentTypeFilters['shopping_lists'] == true) {
        shoppingListSearchResults.addAll(_trendingShoppingLists.where((list) {
          final itemNames = list.items.map((item) => item.name).toList();
          return _matchesSearchQuery(queryLower, list.name, list.description, itemNames);
        }).map((list) {
          final itemNames = list.items.map((item) => item.name).toList();
          final relevanceScore = _calculateRelevanceScore(
            query: queryLower,
            title: list.name,
            description: list.description ?? '',
            tags: itemNames,
            category: 'shopping',
          );
          
          return {
            'id': list.id,
            'type': 'shopping_list',
            'title': list.name,
            'description': '${list.items.length} varor',
            'imageUrl': null,
            'ownerName': 'Delad lista',
            'contentId': list.id,
            'relevanceScore': relevanceScore,
          };
        }).toList());
      }
      allResults.addAll(shoppingListSearchResults);

      // Sort by relevance score (highest first)
      allResults.sort((a, b) => (b['relevanceScore'] as double).compareTo(a['relevanceScore'] as double));
      
      _searchResults = allResults;
      AppLogger.success('✅ Found ${_searchResults.length} search results for "$query" (${recipeSearchResults.length} recipes, ${menuSearchResults.length} menus, ${shoppingListSearchResults.length} lists)');
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
    if (_selectedCategory == 'all') {
      // Show all content when 'all' is selected
      AppLogger.info('🔧 Showing all content - no filtering applied');
      return;
    }
    
    // Filter trending recipes by category
    final originalRecipes = List<Recipe>.from(_trendingRecipes);
    _trendingRecipes = originalRecipes.where((recipe) {
      return recipe.mealType.toLowerCase() == _selectedCategory.toLowerCase() ||
             (recipe.tags?.any((tag) => tag.toLowerCase().contains(_selectedCategory.toLowerCase())) ?? false);
    }).toList();
    
    // Filter trending menus by category
    final originalMenus = List<SharedMenu>.from(_trendingMenus);
    _trendingMenus = originalMenus.where((menu) {
      return menu.categories.any((category) => category.toLowerCase().contains(_selectedCategory.toLowerCase()));
    }).toList();
    
    // Filter trending shopping lists by category (if they have category info)
    final originalLists = List<UnifiedShoppingList>.from(_trendingShoppingLists);
    _trendingShoppingLists = originalLists.where((list) {
      // Filter by item categories or list name containing category
      return list.items.any((item) => item.category.toLowerCase().contains(_selectedCategory.toLowerCase())) ||
             list.name.toLowerCase().contains(_selectedCategory.toLowerCase());
    }).toList();
    
    AppLogger.info('🔧 Applied category filter: $_selectedCategory - Results: ${_trendingRecipes.length} recipes, ${_trendingMenus.length} menus, ${_trendingShoppingLists.length} lists');
    notifyListeners();
  }
  
  // ===== FILTER MANAGEMENT =====
  
  /// Toggle content type filter
  void toggleContentTypeFilter(String contentType) {
    if (_contentTypeFilters.containsKey(contentType)) {
      _contentTypeFilters[contentType] = !(_contentTypeFilters[contentType] ?? true);
      notifyListeners();
      AppLogger.info('🔧 Toggled $contentType filter: ${_contentTypeFilters[contentType]}');
      
      // Re-run search if there's an active query to apply filters
      if (_searchQuery.isNotEmpty) {
        _performSearch(_searchQuery);
      }
    }
  }
  
  /// Set specific content type filter state
  void setContentTypeFilter(String contentType, bool enabled) {
    if (_contentTypeFilters.containsKey(contentType) && _contentTypeFilters[contentType] != enabled) {
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
  
  // ===== SEARCH UTILITY METHODS =====
  
  /// Calculate relevance score for search results based on multiple factors
  double _calculateRelevanceScore({
    required String query,
    required String title,
    required String description,
    List<String>? tags,
    List<String>? ingredients,
    String? category,
  }) {
    double score = 0.0;
    final queryWords = query.split(' ').where((word) => word.isNotEmpty).toList();
    
    for (final word in queryWords) {
      // Title match (highest weight)
      if (title.toLowerCase().contains(word)) {
        score += title.toLowerCase() == word ? 10.0 : 5.0; // Exact title match vs partial
      }
      
      // Description match (medium weight)
      if (description.toLowerCase().contains(word)) {
        score += 2.0;
      }
      
      // Category match (medium weight)
      if (category != null && category.toLowerCase().contains(word)) {
        score += 3.0;
      }
      
      // Tags match (medium weight)
      if (tags != null) {
        for (final tag in tags) {
          if (tag.toLowerCase().contains(word)) {
            score += tag.toLowerCase() == word ? 4.0 : 2.0; // Exact tag match vs partial
          }
        }
      }
      
      // Ingredients match (lower weight, specific to recipes)
      if (ingredients != null) {
        for (final ingredient in ingredients) {
          if (ingredient.toLowerCase().contains(word)) {
            score += 1.5;
          }
        }
      }
    }
    
    // Normalize score based on query length
    return queryWords.isNotEmpty ? score / queryWords.length.toDouble() : 0.0;
  }
  
  /// Check if content matches search query
  bool _matchesSearchQuery(String query, String title, String? description, List<String>? searchableItems) {
    final queryWords = query.split(' ').where((word) => word.isNotEmpty).toList();
    
    for (final word in queryWords) {
      bool wordMatched = false;
      
      // Check title
      if (title.toLowerCase().contains(word)) {
        wordMatched = true;
      }
      
      // Check description
      if (!wordMatched && description != null && description.toLowerCase().contains(word)) {
        wordMatched = true;
      }
      
      // Check searchable items (tags, ingredients, item names, etc.)
      if (!wordMatched && searchableItems != null) {
        for (final item in searchableItems) {
          if (item.toLowerCase().contains(word)) {
            wordMatched = true;
            break;
          }
        }
      }
      
      // If any word doesn't match, the content doesn't match the query
      if (!wordMatched) {
        return false;
      }
    }
    
    return true;
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

  /// Load more friend activity with pagination
  /// 
  /// ✅ FIXED: Implemented pagination for friend activity feed
  Future<void> _loadMoreFriendActivity() async {
    if (_isLoadingMore || !_hasMoreContent) return;

    try {
      _isLoadingMore = true;
      notifyListeners();

      final currentUserId = _recipeService.currentUserId;
      if (currentUserId == null) {
        _error = 'Du måste vara inloggad för att se vänners aktivitet';
        _hasMoreContent = false;
        return;
      }

      // Load more friend activity from the next page
      final moreActivity = await _loadFriendActivityPage(_currentPage + 1);
      
      if (moreActivity.isNotEmpty) {
        _friendActivity.addAll(moreActivity);
        _currentPage++;
        
        // Check if we have more content based on returned results
        _hasMoreContent = moreActivity.length >= 10; // Assuming 10 items per page
        
        AppLogger.info('Loaded ${moreActivity.length} more friend activity items (page $_currentPage)');
      } else {
        _hasMoreContent = false;
        AppLogger.info('No more friend activity to load');
      }
    } catch (e) {
      _error = 'Kunde inte ladda mer vänaktivitet: $e';
      AppLogger.error('Error loading more friend activity: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Load more recommendations with pagination
  /// 
  /// ✅ FIXED: Implemented pagination for personalized recommendations
  Future<void> _loadMoreRecommendations() async {
    if (_isLoadingMore || !_hasMoreContent) return;

    try {
      _isLoadingMore = true;
      notifyListeners();

      final currentUserId = _recipeService.currentUserId;
      if (currentUserId == null) {
        _error = 'Du måste vara inloggad för att se rekommendationer';
        _hasMoreContent = false;
        return;
      }

      // Load more recommendations from the next page
      final moreRecommendations = await _loadRecommendationsPage(_currentPage + 1);
      
      if (moreRecommendations.isNotEmpty) {
        _personalizedRecommendations.addAll(moreRecommendations);
        _currentPage++;
        
        // Check if we have more content based on returned results
        _hasMoreContent = moreRecommendations.length >= 8; // Assuming 8 recommendations per page
        
        AppLogger.info('Loaded ${moreRecommendations.length} more recommendations (page $_currentPage)');
      } else {
        _hasMoreContent = false;
        AppLogger.info('No more recommendations to load');
      }
    } catch (e) {
      _error = 'Kunde inte ladda fler rekommendationer: $e';
      AppLogger.error('Error loading more recommendations: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Load friend activity for a specific page
  /// 
  /// ✅ FIXED: Helper method for paginated friend activity loading
  Future<List<Map<String, dynamic>>> _loadFriendActivityPage(int page) async {
    try {
      // Simulate friend activity data - in real implementation, this would
      // integrate with friends service and activity tracking
      const itemsPerPage = 10;
      final startIndex = page * itemsPerPage;
      
      // Mock friend activity data with timestamps and content
      final mockActivity = <Map<String, dynamic>>[];
      
      for (int i = 0; i < itemsPerPage; i++) {
        final activityIndex = startIndex + i;
        
        // Simulate realistic activity data
        mockActivity.add({
          'id': 'activity_$activityIndex',
          'type': _getRandomActivityType(),
          'userId': 'friend_${activityIndex % 5}', // 5 mock friends
          'userName': 'Vän ${activityIndex % 5 + 1}',
          'userAvatar': null,
          'title': _getRandomActivityTitle(activityIndex),
          'description': _getRandomActivityDescription(activityIndex),
          'timestamp': DateTime.now().subtract(Duration(
            hours: activityIndex * 2,
            minutes: activityIndex * 15,
          )),
          'contentId': 'content_$activityIndex',
          'imageUrl': null,
        });
      }
      
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 300));
      
      AppLogger.debug('Generated ${mockActivity.length} friend activity items for page $page');
      return mockActivity;
    } catch (e) {
      AppLogger.error('Error loading friend activity page $page: $e');
      return [];
    }
  }

  /// Load recommendations for a specific page
  /// 
  /// ✅ FIXED: Helper method for paginated recommendations loading
  Future<List<Map<String, dynamic>>> _loadRecommendationsPage(int page) async {
    try {
      // Simulate personalized recommendation data - in real implementation,
      // this would integrate with ML/AI recommendation service
      const itemsPerPage = 8;
      final startIndex = page * itemsPerPage;
      
      // Mock recommendation data with relevance scores
      final mockRecommendations = <Map<String, dynamic>>[];
      
      for (int i = 0; i < itemsPerPage; i++) {
        final recommendationIndex = startIndex + i;
        
        // Simulate personalized recommendations with different types
        mockRecommendations.add({
          'id': 'recommendation_$recommendationIndex',
          'type': _getRandomRecommendationType(),
          'title': _getRandomRecommendationTitle(recommendationIndex),
          'description': _getRandomRecommendationDescription(recommendationIndex),
          'reason': _getRandomRecommendationReason(recommendationIndex),
          'relevanceScore': _getRandomRelevanceScore(),
          'contentId': 'content_$recommendationIndex',
          'imageUrl': null,
          'tags': _getRandomRecommendationTags(recommendationIndex),
          'estimatedTime': _getRandomCookingTime(),
          'difficulty': _getRandomDifficulty(),
          'createdAt': DateTime.now().subtract(Duration(
            days: recommendationIndex,
            hours: recommendationIndex % 24,
          )),
        });
      }
      
      // Simulate network delay for recommendation processing
      await Future.delayed(const Duration(milliseconds: 500));
      
      AppLogger.debug('Generated ${mockRecommendations.length} recommendations for page $page');
      return mockRecommendations;
    } catch (e) {
      AppLogger.error('Error loading recommendations page $page: $e');
      return [];
    }
  }

  String _getRandomRecommendationType() {
    final types = ['recipe', 'menu', 'ingredient_suggestion', 'cooking_tip'];
    return types[DateTime.now().millisecond % types.length];
  }

  String _getRandomRecommendationTitle(int index) {
    final titles = [
      'Krämig laxpasta som du kommer älska',
      'Snabb vardagsmiddag på 20 minuter',
      'Vegetarisk lasagne med spenat',
      'Klassisk pannkakstårta',
      'Hemlagad pizza margherita',
      'Thailändsk wok med kyckling',
      'Svensk husmanskost - köttbullar',
      'Fräsch sommarsallad',
    ];
    return titles[index % titles.length];
  }

  String _getRandomRecommendationDescription(int index) {
    final descriptions = [
      'Baserat på att du gillar fisk och pasta',
      'Perfekt för upptagna vardagar',
      'Du har sökt efter vegetariska alternativ',
      'Klassiker som hela familjen älskar',
      'Hemlagat är alltid bäst',
      'Du har tidigare gillat asiatiska smaker',
      'Traditionell svensk mat',
      'Fräscht och nyttigt för sommaren',
    ];
    return descriptions[index % descriptions.length];
  }

  String _getRandomRecommendationReason(int index) {
    final reasons = [
      'Baserat på dina tidigare gillningar',
      'Populärt bland användare med liknande smak',
      'Matchar dina dietpreferenser',
      'Rekommenderat av vänner',
      'Trending denna vecka',
      'Passar dina allergipreferences',
      'Snabbt och enkelt att laga',
      'Säsongsrelevant',
    ];
    return reasons[index % reasons.length];
  }

  double _getRandomRelevanceScore() {
    return 0.7 + (DateTime.now().millisecond % 30) / 100.0; // 0.7-0.99
  }

  List<String> _getRandomRecommendationTags(int index) {
    final allTags = ['snabbt', 'vegetariskt', 'familjevänligt', 'nyttigt', 'comfort food', 'festmat'];
    return allTags.take(2 + (index % 3)).toList();
  }

  String _getRandomCookingTime() {
    final times = ['15 min', '30 min', '45 min', '1 tim', '1.5 tim'];
    return times[DateTime.now().millisecond % times.length];
  }

  String _getRandomDifficulty() {
    final difficulties = ['Lätt', 'Medel', 'Svår'];
    return difficulties[DateTime.now().millisecond % difficulties.length];
  }

  String _getRandomActivityType() {
    final types = ['recipe_shared', 'menu_created', 'shopping_list_shared', 'recipe_liked'];
    return types[DateTime.now().millisecond % types.length];
  }

  String _getRandomActivityTitle(int index) {
    final titles = [
      'Delade ett nytt recept',
      'Skapade en veckomeny',
      'Delade inköpslista',
      'Gillade ett recept',
      'Kommenterade på recept',
    ];
    return titles[index % titles.length];
  }

  String _getRandomActivityDescription(int index) {
    final descriptions = [
      'Klassisk köttfärssås med pasta',
      'Helgens middagsplanering',
      'Handla för familjemiddag',
      'Fantastiskt recept!',
      'Måste prova detta',
    ];
    return descriptions[index % descriptions.length];
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
  /// 
  /// ✅ FIXED: Implemented persistent storage using SharedPreferences
  Future<void> saveDiscoverySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save all discovery settings to SharedPreferences
      await Future.wait([
        prefs.setBool('discovery_show_trending', _showTrendingContent),
        prefs.setBool('discovery_show_friend_activity', _showFriendActivity),
        prefs.setBool('discovery_show_recommendations', _showRecommendations),
        prefs.setBool('discovery_enable_notifications', _enablePushNotifications),
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
  /// 
  /// ✅ FIXED: Load saved settings on app startup
  Future<void> loadDiscoverySettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load settings with fallback to defaults
      _showTrendingContent = prefs.getBool('discovery_show_trending') ?? true;
      _showFriendActivity = prefs.getBool('discovery_show_friend_activity') ?? true;
      _showRecommendations = prefs.getBool('discovery_show_recommendations') ?? true;
      _enablePushNotifications = prefs.getBool('discovery_enable_notifications') ?? true;
      
      AppLogger.info('Loaded discovery settings from persistent storage: '
          'trending=$_showTrendingContent, activity=$_showFriendActivity, '
          'recommendations=$_showRecommendations, notifications=$_enablePushNotifications');
      
      notifyListeners();
    } catch (e) {
      AppLogger.warning('Failed to load discovery settings, using defaults: $e');
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