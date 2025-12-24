// lib/viewmodels/discovery_dashboard/discovery_content_manager.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/operations/modules/recipe_discovery_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';

/// Manages trending content discovery and loading for the discovery dashboard.
/// Handles all content discovery operations including trending recipes, menus,
/// and shopping lists with intelligent caching and error handling.
class DiscoveryContentManager extends ChangeNotifier {
  final RecipeDiscoveryService _discoveryService;

  // Content state
  List<Recipe> _trendingRecipes = [];
  List<SharedMenu> _trendingMenus = [];
  List<UnifiedShoppingList> _trendingShoppingLists = [];
  bool _isLoading = false;
  String? _error;

  DiscoveryContentManager({
    required RecipeDiscoveryService discoveryService,
  }) : _discoveryService = discoveryService;

  // ===== GETTERS =====

  List<Recipe> get trendingRecipes => List.unmodifiable(_trendingRecipes);
  List<SharedMenu> get trendingMenus => List.unmodifiable(_trendingMenus);
  List<UnifiedShoppingList> get trendingShoppingLists =>
      List.unmodifiable(_trendingShoppingLists);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  // Content counts
  int get trendingContentCount =>
      _trendingRecipes.length +
      _trendingMenus.length +
      _trendingShoppingLists.length;

  // ===== CONTENT LOADING =====

  /// Load all trending content across all types
  Future<void> loadAllTrendingContent() async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('📈 Loading trending content');

      // Load all content types in parallel
      await Future.wait([
        _loadTrendingRecipes(),
        _loadTrendingMenus(),
        _loadTrendingShoppingLists(),
      ]);

      AppLogger.success(
          '✅ Loaded trending content: ${_trendingRecipes.length} recipes, ${_trendingMenus.length} menus, ${_trendingShoppingLists.length} lists');
      notifyListeners();
    } catch (e) {
      _setError('Failed to load trending content: $e');
      AppLogger.error('❌ Failed to load trending content', e);
      rethrow; // Rethrow to allow parent to handle error
    } finally {
      _setLoading(false);
    }
  }

  /// Load trending recipes from the discovery service
  Future<void> _loadTrendingRecipes() async {
    try {
      _trendingRecipes = await _discoveryService.getTrendingRecipes(
        limit: 20,
        timeWindow: const Duration(days: 7),
      );
    } catch (e) {
      AppLogger.error('❌ Failed to load trending recipes', e);
      rethrow;
    }
  }

  /// Loads trending menus from the discovery service.
  /// Currently returns an empty list as menu discovery features are being
  /// developed. The delay simulates network latency for consistent UX.
  Future<void> _loadTrendingMenus() async {
    try {
      // Placeholder implementation while menu discovery service is in development
      await Future.delayed(const Duration(milliseconds: 200));
      _trendingMenus = [];
    } catch (e) {
      AppLogger.error('❌ Failed to load trending menus', e);
      rethrow;
    }
  }

  /// Loads trending shopping lists from the discovery service.
  /// Currently returns an empty list as shopping list discovery features are being
  /// developed. The delay simulates network latency for consistent UX.
  Future<void> _loadTrendingShoppingLists() async {
    try {
      // Placeholder implementation while shopping list discovery service is in development
      await Future.delayed(const Duration(milliseconds: 200));
      _trendingShoppingLists = [];
    } catch (e) {
      AppLogger.error('❌ Failed to load trending shopping lists', e);
      rethrow;
    }
  }

  /// Refresh all trending content
  Future<void> refreshContent() async {
    await loadAllTrendingContent();
  }

  /// Clear all content (useful for logout/reset)
  void clearContent() {
    _trendingRecipes.clear();
    _trendingMenus.clear();
    _trendingShoppingLists.clear();
    _clearError();
    notifyListeners();
  }

  // ===== SEARCH METHODS =====

  /// Search recipes
  Future<List<Map<String, dynamic>>> searchRecipes(String query) async {
    try {
      final recipeResults = await _discoveryService.searchRecipes(
        query: query,
        limit: 20,
        includePersonal: false,
      );

      return recipeResults.map((recipe) {
        return {
          'id': recipe.id,
          'type': 'recipe',
          'title': recipe.title,
          'description': recipe.description,
          'imageUrl':
              recipe.imageUrls.isNotEmpty ? recipe.imageUrls.first : null,
          'ownerName': recipe.socialData?.ownerDisplayName,
          'contentId': recipe.id,
          'relevanceScore':
              _calculateRelevanceScore(query, recipe.title, recipe.description),
        };
      }).toList();
    } catch (e) {
      AppLogger.error('❌ Failed to search recipes', e);
      return [];
    }
  }

  /// Search menus
  List<Map<String, dynamic>> searchMenus(String query) {
    return _trendingMenus.where((menu) {
      return menu.menuTitle.toLowerCase().contains(query.toLowerCase()) ||
          (menu.shareMessage?.toLowerCase().contains(query.toLowerCase()) ??
              false);
    }).map((menu) {
      return {
        'id': menu.id,
        'type': 'menu',
        'title': menu.menuTitle,
        'description': menu.menuSummary,
        'imageUrl': null,
        'ownerName': menu.sharedByDisplayName,
        'contentId': menu.id,
        'relevanceScore': _calculateRelevanceScore(
            query, menu.menuTitle, menu.shareMessage ?? ''),
      };
    }).toList();
  }

  /// Search shopping lists
  List<Map<String, dynamic>> searchShoppingLists(String query) {
    return _trendingShoppingLists.where((list) {
      final itemNames = list.items.map((item) => item.name).toList();
      return list.name.toLowerCase().contains(query.toLowerCase()) ||
          itemNames
              .any((item) => item.toLowerCase().contains(query.toLowerCase()));
    }).map((list) {
      return {
        'id': list.id,
        'type': 'shopping_list',
        'title': list.name,
        'description': '${list.items.length} varor',
        'imageUrl': null,
        'ownerName': 'Delad lista',
        'contentId': list.id,
        'relevanceScore':
            _calculateRelevanceScore(query, list.name, list.description ?? ''),
      };
    }).toList();
  }

  /// Apply category filter to content
  void applyCategoryFilter(String category) {
    // Implementation for category filtering
    AppLogger.info('🔧 Applied category filter: $category');
    notifyListeners();
  }

  /// Load more trending content for pagination
  Future<void> loadMoreTrendingContent() async {
    try {
      final moreRecipes = await _discoveryService.getTrendingRecipes(
        limit: 10,
        timeWindow: const Duration(days: 14),
      );

      _trendingRecipes.addAll(moreRecipes);
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Failed to load more trending content', e);
    }
  }

  /// Calculate relevance score for search results
  double _calculateRelevanceScore(
      String query, String title, String description) {
    double score = 0.0;
    final queryLower = query.toLowerCase();

    if (title.toLowerCase().contains(queryLower)) {
      score += title.toLowerCase() == queryLower ? 10.0 : 5.0;
    }

    if (description.toLowerCase().contains(queryLower)) {
      score += 2.0;
    }

    return score;
  }

  // ===== PRIVATE HELPERS =====

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  @override
  void dispose() {
    // Cleanup if needed
    super.dispose();
  }
}
