// lib/services/unified/operations/social_recipe_operations.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

// Import focused modules
import 'package:butlery/services/unified/operations/modules/recipe_sharing_manager.dart';
import 'package:butlery/services/unified/operations/modules/recipe_member_manager.dart';
import 'package:butlery/services/unified/operations/modules/recipe_comments_manager.dart';
import 'package:butlery/services/unified/operations/modules/recipe_discovery_service.dart';
import 'package:butlery/services/unified/operations/modules/recipe_social_stats.dart';
import 'package:butlery/services/unified/operations/modules/recipe_permission_helper.dart';

/// ```dart
/// await ops.shareRecipe(recipeId, memberIds, memberDisplayNames);
/// await ops.addComment(recipeId, content); final stats = await ops.getRecipeStats(recipeId);
/// ```
class SocialRecipeOperations {
  final UnifiedRecipeService _parent;
  final RatingsRepository _ratingsRepository;
  final FirestoreRepository _firestoreRepository;
  late final NotificationService? _notificationService;

  // Focused modules for each responsibility area
  late final RecipeSharingManager _sharingManager;
  late final RecipeMemberManager _memberManager;
  late final RecipeCommentsManager _commentsManager;
  late final RecipeDiscoveryService _discoveryService;
  late final RecipeSocialStats _socialStats;
  late final RecipePermissionHelper _permissionHelper;
  SocialRecipeOperations(
    this._parent, {
    required RatingsRepository ratingsRepository,
    required FirestoreRepository firestoreRepository,
  })  : _ratingsRepository = ratingsRepository,
        _firestoreRepository = firestoreRepository {
    try {
      final currentUserId = _parent.currentUserId;
      if (currentUserId != null) {
        _notificationService = NotificationService(
          userId: currentUserId,
        );
        _notificationService?.initialize();
      } else {
        _notificationService = null;
      }
    } catch (e) {
      AppLogger.warning('⚠️ Could not initialize notification service: $e');
      _notificationService = null;
    }
    _sharingManager = RecipeSharingManager(_parent, _notificationService);
    _memberManager = RecipeMemberManager(_parent, _notificationService);
    _commentsManager = RecipeCommentsManager(_parent, _notificationService);
    _discoveryService = RecipeDiscoveryService(_parent);
    _socialStats = RecipeSocialStats(_parent, _ratingsRepository,
        _firestoreRepository, _notificationService);
    _permissionHelper = RecipePermissionHelper(_parent);

    AppLogger.info('✅ SocialRecipeOperations initialized with focused modules');
  }

  // ===== GETTERS =====

  RecipeDiscoveryService get discoveryService => _discoveryService;

  // ===== RECIPE SHARING (Delegates to RecipeSharingManager) =====

  Future<String?> shareRecipe({
    required String recipeId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String? collaborativeDescription,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    return await _sharingManager.shareRecipe(
      recipeId: recipeId,
      memberIds: memberIds,
      memberDisplayNames: memberDisplayNames,
      collaborativeDescription: collaborativeDescription,
      allowGuestViewing: allowGuestViewing,
      allowMemberInvites: allowMemberInvites,
      categoryIds: categoryIds,
    );
  }

  Future<String?> makeRecipePersonal({
    required String collaborativeRecipeId,
    String? newTitle,
  }) async {
    return await _sharingManager.makeRecipePersonal(
      collaborativeRecipeId: collaborativeRecipeId,
      newTitle: newTitle,
    );
  }

  Future<String?> duplicateAndShareRecipe({
    required String recipeId,
    required List<String> memberIds,
    required Map<String, String> memberDisplayNames,
    String? newTitle,
    String? collaborativeDescription,
    bool allowGuestViewing = false,
    bool allowMemberInvites = true,
    List<String>? categoryIds,
  }) async {
    return await _sharingManager.duplicateAndShareRecipe(
      recipeId: recipeId,
      memberIds: memberIds,
      memberDisplayNames: memberDisplayNames,
      newTitle: newTitle,
      collaborativeDescription: collaborativeDescription,
      allowGuestViewing: allowGuestViewing,
      allowMemberInvites: allowMemberInvites,
      categoryIds: categoryIds,
    );
  }

  Future<bool> addMember({
    required String recipeId,
    required String userId,
    required String userDisplayName,
    ResourcePermission? permission,
  }) async {
    permission ??= ResourcePermission.viewer; // Default permission
    return await _memberManager.addMember(
      recipeId: recipeId,
      memberId: userId,
      memberDisplayName: userDisplayName,
      permission: permission,
    );
  }

  Future<bool> removeMember({
    required String recipeId,
    required String userId,
  }) async {
    return await _memberManager.removeMember(
      recipeId: recipeId,
      memberId: userId,
    );
  }

  Future<bool> updateMemberPermission({
    required String recipeId,
    required String userId,
    required ResourcePermission permission,
  }) async {
    return await _memberManager.updateMemberPermission(
      recipeId: recipeId,
      memberId: userId,
      newPermission: permission,
    );
  }

  Future<List<Map<String, dynamic>>> getRecipeMembers(String recipeId) async {
    return await _memberManager.getRecipeMembers(recipeId);
  }

  bool canInviteMembers(String recipeId) {
    return _memberManager.canInviteMembers(recipeId);
  }

  Map<String, dynamic> getMemberStatistics(String recipeId) {
    return _memberManager.getMemberStatistics(recipeId);
  }

  // ===== SOCIAL DISCOVERY (Delegates to RecipeDiscoveryService) =====

  Future<List<Recipe>> getCollaborativeRecipes({
    int limit = 50,
    String? startAfter,
    List<String>? categoryFilter,
    String? searchQuery,
  }) async {
    return await _discoveryService.getCollaborativeRecipes(
      limit: limit,
      startAfter: startAfter,
      categoryFilter: categoryFilter,
      searchQuery: searchQuery,
    );
  }

  Future<List<Recipe>> getSharedWithMe({
    int limit = 50,
    List<String>? categoryFilter,
    String? searchQuery,
  }) async {
    return await _discoveryService.getSharedWithMe(
      limit: limit,
      categoryFilter: categoryFilter,
      searchQuery: searchQuery,
    );
  }

  Future<List<Recipe>> getSharedByMe({
    int limit = 50,
    bool includeEmpty = false,
    List<String>? categoryFilter,
    String? searchQuery,
  }) async {
    return await _discoveryService.getSharedByMe(
      limit: limit,
      includeEmpty: includeEmpty,
      categoryFilter: categoryFilter,
      searchQuery: searchQuery,
    );
  }

  Future<List<Recipe>> getRecipesByUser({
    required String userId,
    int limit = 50,
    bool includePersonal = false,
    List<String>? categoryFilter,
    String? searchQuery,
  }) async {
    return await _discoveryService.getRecipesByUser(
      userId: userId,
      limit: limit,
      includePersonal: includePersonal,
      categoryFilter: categoryFilter,
      searchQuery: searchQuery,
    );
  }

  Future<List<Recipe>> getTrendingRecipes({
    int limit = 20,
    Duration? timeWindow,
    List<String>? categoryFilter,
  }) async {
    return await _discoveryService.getTrendingRecipes(
      limit: limit,
      timeWindow: timeWindow,
      categoryFilter: categoryFilter,
    );
  }

  Future<List<Recipe>> searchRecipes({
    required String query,
    int limit = 20,
    List<String>? categoryFilter,
    bool includePersonal = false,
  }) async {
    return await _discoveryService.searchRecipes(
      query: query,
      limit: limit,
      categoryFilter: categoryFilter,
      includePersonal: includePersonal,
    );
  }

  // ===== RECIPE COMMENTS (Delegates to RecipeCommentsManager) =====

  Future<String?> addComment({
    required String recipeId,
    required String content,
    String? parentCommentId,
    List<String>? mentions,
  }) async {
    return await _commentsManager.addComment(
      recipeId: recipeId,
      content: content,
      parentCommentId: parentCommentId,
      mentions: mentions,
    );
  }

  Future<List<RecipeComment>> getComments({
    required String recipeId,
    int limit = 20,
    DateTime? before,
    bool includeReplies = true,
  }) async {
    return await _commentsManager.getComments(
      recipeId: recipeId,
      limit: limit,
      before: before,
      includeReplies: includeReplies,
    );
  }

  Future<bool> editComment({
    required String commentId,
    required String newContent,
  }) async {
    return await _commentsManager.editComment(
      commentId: commentId,
      newContent: newContent,
    );
  }

  Future<bool> deleteComment(String commentId) async {
    return await _commentsManager.deleteComment(commentId);
  }

  Future<bool> toggleCommentLike(String commentId) async {
    return await _commentsManager.toggleCommentLike(commentId);
  }

  Stream<List<RecipeComment>> getCommentsStream(String recipeId) {
    return _commentsManager.getCommentsStream(recipeId);
  }

  Future<Map<String, dynamic>> getCommentStatistics(String recipeId) async {
    return await _commentsManager.getCommentStatistics(recipeId);
  }

  // ===== RECIPE RATING & SOCIAL STATS (Delegates to RecipeSocialStats) =====

  Future<bool> rateRecipe({
    required String recipeId,
    required double rating,
    String? review,
  }) async {
    return await _socialStats.rateRecipe(
      recipeId: recipeId,
      rating: rating,
      review: review,
    );
  }

  Future<Map<String, dynamic>> getRecipeStats(String recipeId) async {
    return await _socialStats.getRecipeStats(recipeId);
  }

  Future<Map<String, dynamic>?> getUserRating(String recipeId) async {
    return await _socialStats.getUserRating(recipeId);
  }

  Future<List<Map<String, dynamic>>> getTopRatedRecipes({
    int limit = 10,
    double minRating = 4.0,
    int minRatingCount = 3,
  }) async {
    return await _socialStats.getTopRatedRecipes(
      limit: limit,
      minRating: minRating,
      minRatingCount: minRatingCount,
    );
  }

  Future<Map<String, dynamic>> getUserSocialStats() async {
    return await _socialStats.getUserSocialStats();
  }

  // ===== LEGACY COMPATIBILITY =====

  Future<List<Map<String, dynamic>>> getLegacySharedRecipes() async {
    try {
      final sharedRecipes = await getSharedWithMe();
      return sharedRecipes.map((recipe) {
        return {
          'id': recipe.id,
          'title': recipe.title,
          'description': recipe.description,
          'ownerId': recipe.socialData?.ownerId ?? recipe.createdBy,
          'ownerDisplayName': recipe.socialData?.ownerDisplayName ?? 'Unknown',
          'sharedAt': recipe.createdAt.toIso8601String(),
          'permissions': {_parent.currentUserId!: 'view'}, // Simplified
          'recipe': recipe.toJson(),
        };
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get legacy shared recipes', e);
      return [];
    }
  }

  Future<void> markSharedRecipeAsViewed(String recipeId) async {
    try {
      // This would update view tracking
      AppLogger.info('Marking recipe $recipeId as viewed');
    } catch (e) {
      AppLogger.error('Failed to mark recipe as viewed', e);
    }
  }

  bool checkLegacyPermission(String recipeId, String userId, String action) {
    try {
      final recipe = _parent.recipes.firstWhere((r) => r.id == recipeId);
      return _permissionHelper.checkLegacyPermission(recipe, userId, action);
    } catch (e) {
      return false;
    }
  }

  // ===== PERMISSION HELPERS (Delegates to RecipePermissionHelper) =====

  bool canView(String recipeId) {
    try {
      final recipe = _parent.recipes.firstWhere((r) => r.id == recipeId);
      return _permissionHelper.canViewRecipe(recipe);
    } catch (e) {
      return false;
    }
  }

  bool canEdit(String recipeId) {
    try {
      final recipe = _parent.recipes.firstWhere((r) => r.id == recipeId);
      return _permissionHelper.canEditRecipe(recipe);
    } catch (e) {
      return false;
    }
  }

  bool canDelete(String recipeId) {
    try {
      final recipe = _parent.recipes.firstWhere((r) => r.id == recipeId);
      return _permissionHelper.canDeleteRecipe(recipe);
    } catch (e) {
      return false;
    }
  }

  bool canManageMembers(String recipeId) {
    try {
      final recipe = _parent.recipes.firstWhere((r) => r.id == recipeId);
      return _permissionHelper.canManageMembers(recipe);
    } catch (e) {
      return false;
    }
  }

  bool canComment(String recipeId) {
    try {
      final recipe = _parent.recipes.firstWhere((r) => r.id == recipeId);
      return _permissionHelper.canCommentOnRecipe(recipe);
    } catch (e) {
      return false;
    }
  }

  bool canRate(String recipeId) {
    try {
      final recipe = _parent.recipes.firstWhere((r) => r.id == recipeId);
      return _permissionHelper.canRateRecipe(recipe);
    } catch (e) {
      return false;
    }
  }

  ResourcePermission getUserPermission(String recipeId, String userId) {
    try {
      final recipe = _parent.recipes.firstWhere((r) => r.id == recipeId);
      return _permissionHelper.getUserPermission(recipe, userId);
    } catch (e) {
      return ResourcePermission.read;
    }
  }

  Map<String, dynamic> getPermissionSummary(String recipeId, String userId) {
    try {
      final recipe = _parent.recipes.firstWhere((r) => r.id == recipeId);
      return _permissionHelper.getPermissionSummary(recipe, userId);
    } catch (e) {
      return {'error': 'Recipe not found'};
    }
  }

  // ===== ADDITIONAL FEATURES =====

  Map<String, dynamic> getDiscoveryStatistics() {
    return _discoveryService.getDiscoveryStatistics();
  }

  Future<Map<String, int>> getPopularCollaborativeCategories(
      {int limit = 10}) async {
    return await _discoveryService.getPopularCollaborativeCategories(
        limit: limit);
  }

  Map<String, dynamic> getSharingStats() {
    return _sharingManager.getSharingStats();
  }

  void dispose() {
    try {
      _commentsManager.dispose();
      AppLogger.info('✅ SocialRecipeOperations disposed successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to dispose SocialRecipeOperations', e);
    }
  }
}
