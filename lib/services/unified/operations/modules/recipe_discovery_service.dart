// lib/services/unified/operations/modules/recipe_discovery_service.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/base/base_service.dart';

/// Focused module for social recipe discovery and filtering
/// This module handles ONLY recipe discovery responsibilities:
/// - Finding collaborative recipes across the platform
/// - Filtering recipes shared with current user
/// - Retrieving recipes shared by current user
/// - User-specific recipe discovery and search
/// - Social recipe filtering and categorization
/// - Discovery analytics and recommendations
/// ❌ DOES NOT CONTAIN: Recipe sharing, member management, comments, ratings, permissions
class RecipeDiscoveryService extends BaseService {
  @override
  String get serviceName => 'RecipeDiscoveryService';

  final UnifiedRecipeService _parent;

  RecipeDiscoveryService(this._parent);
  Future<List<Recipe>> getCollaborativeRecipes({
    int limit = 50,
    String? startAfter,
    List<String>? categoryFilter,
    String? searchQuery,
  }) async {
    try {
      AppLogger.info('🔍 Getting collaborative recipes for current user');

      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) {
        AppLogger.warning('⚠️ No current user for collaborative recipes');
        return [];
      }

      // Get recipes from parent service and filter for collaborative ones
      final allRecipes = _parent.recipes;
      var collaborativeRecipes = allRecipes.where((recipe) {
        // Must be collaborative
        if (!recipe.isCollaborative) return false;

        // User must be owner or member
        final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
        if (ownerId == currentUserId) return true;
        if (recipe.socialData?.memberPermissions?.containsKey(currentUserId) ==
            true) {
          return true;
        }

        return false;
      }).toList();

      // Apply category filter if provided
      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        collaborativeRecipes = collaborativeRecipes.where((recipe) {
          final recipeCategoryIds = recipe.socialData?.categoryIds ?? [];
          return categoryFilter
              .any((categoryId) => recipeCategoryIds.contains(categoryId));
        }).toList();
      }

      // Apply search query if provided
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.toLowerCase().trim();
        collaborativeRecipes = collaborativeRecipes.where((recipe) {
          return recipe.title.toLowerCase().contains(query) ||
              recipe.description.toLowerCase().contains(query) ||
              (recipe.tags?.any((tag) => tag.toLowerCase().contains(query)) ??
                  false);
        }).toList();
      }

      // Sort by last edited (most recent first)
      collaborativeRecipes.sort((a, b) {
        return b.updatedAt.compareTo(a.updatedAt);
      });

      // Apply pagination
      if (limit > 0 && collaborativeRecipes.length > limit) {
        collaborativeRecipes = collaborativeRecipes.take(limit).toList();
      }

      AppLogger.success(
          '✅ Found ${collaborativeRecipes.length} collaborative recipes');
      return collaborativeRecipes;
    } catch (e) {
      AppLogger.error('❌ Failed to get collaborative recipes', e);
      return [];
    }
  }

  Future<List<Recipe>> getSharedWithMe({
    int limit = 50,
    List<String>? categoryFilter,
    String? searchQuery,
  }) async {
    try {
      AppLogger.info('🔍 Getting recipes shared with current user');

      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) {
        AppLogger.warning('⚠️ No current user for shared recipes');
        return [];
      }

      // Get recipes from parent service
      final allRecipes = _parent.recipes;
      var sharedRecipes = allRecipes.where((recipe) {
        // Must be collaborative
        if (!recipe.isCollaborative) return false;

        // User must be member but NOT owner
        final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
        if (ownerId == currentUserId) return false;
        if (recipe.socialData?.memberPermissions?.containsKey(currentUserId) !=
            true) {
          return false;
        }

        return true;
      }).toList();

      // Apply category filter if provided
      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        sharedRecipes = sharedRecipes.where((recipe) {
          final recipeCategoryIds = recipe.socialData?.categoryIds ?? [];
          return categoryFilter
              .any((categoryId) => recipeCategoryIds.contains(categoryId));
        }).toList();
      }

      // Apply search query if provided
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.toLowerCase().trim();
        sharedRecipes = sharedRecipes.where((recipe) {
          return recipe.title.toLowerCase().contains(query) ||
              recipe.description.toLowerCase().contains(query) ||
              (recipe.tags?.any((tag) => tag.toLowerCase().contains(query)) ??
                  false) ||
              (recipe.socialData?.ownerDisplayName
                      ?.toLowerCase()
                      .contains(query) ??
                  false);
        }).toList();
      }

      // Sort by when user was added (most recent first)
      // Since we don't track when members were added, sort by creation date
      sharedRecipes.sort((a, b) => (b.createdAt).compareTo(a.createdAt));

      // Apply limit
      if (limit > 0 && sharedRecipes.length > limit) {
        sharedRecipes = sharedRecipes.take(limit).toList();
      }

      AppLogger.success(
          '✅ Found ${sharedRecipes.length} recipes shared with user');
      return sharedRecipes;
    } catch (e) {
      AppLogger.error('❌ Failed to get recipes shared with user', e);
      return [];
    }
  }

  Future<List<Recipe>> getSharedByMe({
    int limit = 50,
    bool includeEmpty = false,
    List<String>? categoryFilter,
    String? searchQuery,
  }) async {
    try {
      AppLogger.info('🔍 Getting recipes shared by current user');

      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) {
        AppLogger.warning('⚠️ No current user for shared recipes');
        return [];
      }

      // Get recipes from parent service
      final allRecipes = _parent.recipes;
      var sharedRecipes = allRecipes.where((recipe) {
        // Must be collaborative and owned by current user
        if (!recipe.isCollaborative) return false;
        final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
        if (ownerId != currentUserId) return false;

        // If includeEmpty is false, only include recipes with members
        if (!includeEmpty &&
            (recipe.socialData?.memberPermissions?.isEmpty ?? true)) {
          return false;
        }

        return true;
      }).toList();

      // Apply category filter if provided
      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        sharedRecipes = sharedRecipes.where((recipe) {
          final recipeCategoryIds = recipe.socialData?.categoryIds ?? [];
          return categoryFilter
              .any((categoryId) => recipeCategoryIds.contains(categoryId));
        }).toList();
      }

      // Apply search query if provided
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.toLowerCase().trim();
        sharedRecipes = sharedRecipes.where((recipe) {
          return recipe.title.toLowerCase().contains(query) ||
              recipe.description.toLowerCase().contains(query) ||
              (recipe.tags?.any((tag) => tag.toLowerCase().contains(query)) ??
                  false);
        }).toList();
      }

      // Sort by last edited (most recent first)
      sharedRecipes.sort((a, b) {
        return b.updatedAt.compareTo(a.updatedAt);
      });

      // Apply limit
      if (limit > 0 && sharedRecipes.length > limit) {
        sharedRecipes = sharedRecipes.take(limit).toList();
      }

      AppLogger.success(
          '✅ Found ${sharedRecipes.length} recipes shared by user');
      return sharedRecipes;
    } catch (e) {
      AppLogger.error('❌ Failed to get recipes shared by user', e);
      return [];
    }
  }

  Future<List<Recipe>> getRecipesByUser({
    required String userId,
    int limit = 50,
    bool includePersonal = false,
    List<String>? categoryFilter,
    String? searchQuery,
  }) async {
    try {
      AppLogger.info('🔍 Getting recipes by user $userId');

      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) {
        AppLogger.warning('⚠️ No current user for recipe discovery');
        return [];
      }

      // Get recipes from parent service
      final allRecipes = _parent.recipes;
      var userRecipes = allRecipes.where((recipe) {
        // Must be owned by the specified user
        final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
        if (ownerId != userId) return false;

        // Check access permissions
        if (recipe.isPersonal) {
          // Personal recipes: only accessible if user is the owner or if explicitly allowed
          if (!includePersonal) return false;
          return currentUserId == userId; // Only owner can see personal recipes
        } else if (recipe.isCollaborative) {
          // Collaborative recipes: accessible if user is owner or member
          if (currentUserId == userId) {
            return true; // Owner can see all their recipes
          }
          return recipe.socialData?.memberPermissions
                  ?.containsKey(currentUserId) ??
              false;
        }

        return false;
      }).toList();

      // Apply category filter if provided
      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        userRecipes = userRecipes.where((recipe) {
          final recipeCategoryIds = recipe.socialData?.categoryIds ?? [];
          return categoryFilter
              .any((categoryId) => recipeCategoryIds.contains(categoryId));
        }).toList();
      }

      // Apply search query if provided
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.toLowerCase().trim();
        userRecipes = userRecipes.where((recipe) {
          return recipe.title.toLowerCase().contains(query) ||
              recipe.description.toLowerCase().contains(query) ||
              (recipe.tags?.any((tag) => tag.toLowerCase().contains(query)) ??
                  false);
        }).toList();
      }

      // Sort by creation date (most recent first)
      userRecipes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Apply limit
      if (limit > 0 && userRecipes.length > limit) {
        userRecipes = userRecipes.take(limit).toList();
      }

      AppLogger.success(
          '✅ Found ${userRecipes.length} accessible recipes by user $userId');
      return userRecipes;
    } catch (e) {
      AppLogger.error('❌ Failed to get recipes by user', e);
      return [];
    }
  }

  Future<List<Recipe>> getTrendingRecipes({
    int limit = 20,
    Duration? timeWindow,
    List<String>? categoryFilter,
  }) async {
    try {
      AppLogger.info('🔥 Getting trending collaborative recipes');

      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) return [];

      // Get all accessible collaborative recipes
      final collaborativeRecipes = await getCollaborativeRecipes(limit: 0);

      if (collaborativeRecipes.isEmpty) return [];

      // Apply category filter if provided
      var trendingRecipes = collaborativeRecipes;
      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        trendingRecipes = trendingRecipes.where((recipe) {
          final recipeCategoryIds = recipe.socialData?.categoryIds ?? [];
          return categoryFilter
              .any((categoryId) => recipeCategoryIds.contains(categoryId));
        }).toList();
      }

      // Calculate trending score based on:
      // - Number of members
      // - Recent activity (last edited)
      // - Recipe rating
      final now = DateTime.now();
      final timeWindowDays = timeWindow?.inDays ?? 30;

      final scoredRecipes = trendingRecipes.map((recipe) {
        var score = 0.0;

        // Member count score (more members = higher score)
        final memberCount =
            (recipe.socialData?.memberPermissions?.length ?? 0) +
                1; // +1 for owner
        score += memberCount * 10;

        // Recent activity score
        final lastActivity = recipe.updatedAt;
        final daysSinceActivity = now.difference(lastActivity).inDays;
        if (daysSinceActivity <= timeWindowDays) {
          score += (timeWindowDays - daysSinceActivity) * 2;
        }

        // Rating score
        if (recipe.rating != null && recipe.rating! > 0) {
          score += recipe.rating! * 5;
        }

        return MapEntry(recipe, score);
      }).toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final result =
          scoredRecipes.take(limit).map((entry) => entry.key).toList();

      AppLogger.success('✅ Found ${result.length} trending recipes');
      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to get trending recipes', e);
      return [];
    }
  }

  Future<List<Recipe>> getRecentlySharedRecipes({
    int limit = 20,
    Duration? timeWindow,
  }) async {
    try {
      AppLogger.info('⏰ Getting recently shared recipes');

      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) return [];

      final cutoffTime =
          DateTime.now().subtract(timeWindow ?? const Duration(days: 7));

      // Get collaborative recipes from parent service
      final allRecipes = _parent.recipes;
      var recentlyShared = allRecipes.where((recipe) {
        if (!recipe.isCollaborative) return false;

        // Check if user has access
        final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
        if (ownerId == currentUserId) return true;
        if (recipe.socialData?.memberPermissions?.containsKey(currentUserId) ==
            true) {
          return true;
        }

        return false;
      }).where((recipe) {
        // Filter by creation time (assuming collaborative recipes are created when shared)
        return recipe.createdAt.isAfter(cutoffTime);
      }).toList();

      // Sort by creation date (most recent first)
      recentlyShared.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Apply limit
      if (limit > 0 && recentlyShared.length > limit) {
        recentlyShared = recentlyShared.take(limit).toList();
      }

      AppLogger.success(
          '✅ Found ${recentlyShared.length} recently shared recipes');
      return recentlyShared;
    } catch (e) {
      AppLogger.error('❌ Failed to get recently shared recipes', e);
      return [];
    }
  }

  Map<String, dynamic> getDiscoveryStatistics() {
    try {
      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) {
        return {'error': 'No current user'};
      }

      final allRecipes = _parent.recipes;

      // Count different types of recipes
      var personalRecipes = 0;
      var ownedCollaborative = 0;
      var sharedWithMe = 0;
      var totalMembers = 0;

      for (final recipe in allRecipes) {
        final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
        if (ownerId == currentUserId) {
          if (recipe.isPersonal) {
            personalRecipes++;
          } else if (recipe.isCollaborative) {
            ownedCollaborative++;
            totalMembers += recipe.socialData?.memberPermissions?.length ?? 0;
          }
        } else if (recipe.isCollaborative &&
            recipe.socialData?.memberPermissions?.containsKey(currentUserId) ==
                true) {
          sharedWithMe++;
        }
      }

      return {
        'personal_recipes': personalRecipes,
        'owned_collaborative': ownedCollaborative,
        'shared_with_me': sharedWithMe,
        'total_recipes': personalRecipes + ownedCollaborative + sharedWithMe,
        'total_members_in_owned_recipes': totalMembers,
        'average_members_per_shared_recipe': ownedCollaborative > 0
            ? (totalMembers / ownedCollaborative).round()
            : 0,
        'collaboration_ratio': (personalRecipes + ownedCollaborative) > 0
            ? ((ownedCollaborative / (personalRecipes + ownedCollaborative)) *
                    100)
                .round()
            : 0,
      };
    } catch (e) {
      AppLogger.error('❌ Failed to get discovery statistics', e);
      return {'error': 'Failed to calculate statistics'};
    }
  }

  Future<Map<String, int>> getPopularCollaborativeCategories(
      {int limit = 10}) async {
    try {
      final collaborativeRecipes = await getCollaborativeRecipes(limit: 0);
      final categoryCount = <String, int>{};

      for (final recipe in collaborativeRecipes) {
        final categoryIds = recipe.socialData?.categoryIds ?? [];
        for (final categoryId in categoryIds) {
          categoryCount[categoryId] = (categoryCount[categoryId] ?? 0) + 1;
        }
      }

      // Sort by count and return top categories
      final sortedEntries = categoryCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return Map.fromEntries(sortedEntries.take(limit));
    } catch (e) {
      AppLogger.error('❌ Failed to get popular categories', e);
      return {};
    }
  }

  Future<List<Recipe>> searchRecipes({
    required String query,
    int limit = 20,
    List<String>? categoryFilter,
    bool includePersonal = false,
  }) async {
    try {
      AppLogger.info('🔍 Searching recipes with query: "$query"');

      if (query.trim().isEmpty) {
        AppLogger.warning('⚠️ Empty search query');
        return [];
      }

      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) return [];

      final searchQuery = query.toLowerCase().trim();
      final allRecipes = _parent.recipes;

      // Filter accessible recipes
      var searchableRecipes = allRecipes.where((recipe) {
        // Check access permissions
        final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
        if (recipe.isPersonal) {
          return includePersonal && ownerId == currentUserId;
        } else if (recipe.isCollaborative) {
          return ownerId == currentUserId ||
              (recipe.socialData?.memberPermissions
                      ?.containsKey(currentUserId) ??
                  false);
        }
        return false;
      }).toList();

      // Apply category filter
      if (categoryFilter != null && categoryFilter.isNotEmpty) {
        searchableRecipes = searchableRecipes.where((recipe) {
          final recipeCategoryIds = recipe.socialData?.categoryIds ?? [];
          return categoryFilter
              .any((categoryId) => recipeCategoryIds.contains(categoryId));
        }).toList();
      }

      // Apply search filter
      final searchResults = searchableRecipes.where((recipe) {
        return recipe.title.toLowerCase().contains(searchQuery) ||
            recipe.description.toLowerCase().contains(searchQuery) ||
            (recipe.tags
                    ?.any((tag) => tag.toLowerCase().contains(searchQuery)) ??
                false) ||
            recipe.ingredients.any((ingredient) =>
                ingredient.toLowerCase().contains(searchQuery)) ||
            (recipe.socialData?.ownerDisplayName
                    ?.toLowerCase()
                    .contains(searchQuery) ??
                false);
      }).toList();

      // Sort by relevance (title matches first, then description, then other fields)
      searchResults.sort((a, b) {
        var aScore = 0;
        var bScore = 0;

        // Title matches get highest score
        if (a.title.toLowerCase().contains(searchQuery)) aScore += 100;
        if (b.title.toLowerCase().contains(searchQuery)) bScore += 100;

        // Description matches get medium score
        if (a.description.toLowerCase().contains(searchQuery)) aScore += 50;
        if (b.description.toLowerCase().contains(searchQuery)) bScore += 50;

        // Tag/ingredient matches get lower score
        if (a.tags?.any((tag) => tag.toLowerCase().contains(searchQuery)) ??
            false) {
          aScore += 25;
        }
        if (b.tags?.any((tag) => tag.toLowerCase().contains(searchQuery)) ??
            false) {
          bScore += 25;
        }

        return bScore - aScore;
      });

      // Apply limit
      final result = searchResults.take(limit).toList();

      AppLogger.success('✅ Found ${result.length} recipes matching "$query"');
      return result;
    } catch (e) {
      AppLogger.error('❌ Failed to search recipes', e);
      return [];
    }
  }
}
