// lib/viewmodels/discovery_dashboard/discovery_friend_activity_manager.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/unified/operations/modules/recipe_discovery_service.dart';
import 'package:butlery/core/utils/logger.dart';

/// Manages friend activity timeline for the discovery dashboard.
/// Handles loading and displaying social activity including shared recipes,
/// collaborative cooking sessions, and friend interactions.
class DiscoveryFriendActivityManager extends ChangeNotifier {
  final RecipeDiscoveryService _discoveryService;

  // Friend activity state
  List<Map<String, dynamic>> _friendActivity = [];
  bool _isLoading = false;
  String? _error;

  DiscoveryFriendActivityManager({
    required RecipeDiscoveryService discoveryService,
  }) : _discoveryService = discoveryService;

  // ===== GETTERS =====

  List<Map<String, dynamic>> get friendActivity => List.unmodifiable(_friendActivity);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get hasFriendActivity => _friendActivity.isNotEmpty;
  int get friendActivityCount => _friendActivity.length;

  // ===== FRIEND ACTIVITY LOADING =====

  /// Load friend activity timeline
  Future<void> loadFriendActivity() async {
    _setLoading(true);
    _clearError();

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
      notifyListeners();
    } catch (e) {
      _setError('Failed to load friend activity: $e');
      AppLogger.error('❌ Failed to load friend activity', e);
      rethrow; // Rethrow to allow parent to handle error
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh friend activity timeline
  Future<void> refreshActivity() async {
    await loadFriendActivity();
  }

  /// Load more friend activity items (pagination)
  Future<void> loadMoreActivity() async {
    if (_isLoading) return;

    try {
      AppLogger.info('👥 Loading more friend activity');

      // Get more collaborative recipes
      final moreRecipes = await _discoveryService.getRecentlySharedRecipes(
        limit: 10,
        timeWindow: const Duration(days: 7), // Expand timeframe for more content
      );

      final newActivity = moreRecipes.map((recipe) {
        return {
          'id': recipe.id,
          'type': 'recipe_shared',
          'title': recipe.title,
          'description': recipe.description,
          'imageUrl': recipe.imageUrls.isNotEmpty ? recipe.imageUrls.first : null,
          'ownerName': recipe.socialData?.ownerDisplayName ?? 'Okänd användare',
          'ownerAvatarUrl': null,
          'sharedAt': recipe.createdAt,
          'contentType': 'recipe',
          'contentId': recipe.id,
          'engagement': {
            'likes': 0,
            'comments': 0,
            'shares': recipe.socialData?.memberPermissions?.length ?? 0,
          },
        };
      }).toList();

      _friendActivity.addAll(newActivity);
      AppLogger.success('✅ Loaded ${newActivity.length} more friend activity items');
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Failed to load more friend activity', e);
      _setError('Failed to load more activity: $e');
    }
  }

  /// Clear all friend activity (useful for logout/reset)
  void clearActivity() {
    _friendActivity.clear();
    _clearError();
    notifyListeners();
  }

  /// Get activity item by ID
  Map<String, dynamic>? getActivityItem(String activityId) {
    try {
      return _friendActivity.firstWhere((item) => item['id'] == activityId);
    } catch (e) {
      return null;
    }
  }

  /// Filter activity by type
  List<Map<String, dynamic>> getActivityByType(String type) {
    return _friendActivity.where((item) => item['type'] == type).toList();
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