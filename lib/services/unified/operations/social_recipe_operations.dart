// lib/services/unified/operations/social_recipe_operations.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/notifications/notification_service.dart';

// Import focused modules
import 'package:butlery/services/unified/operations/modules/recipe_sharing_manager.dart';
import 'package:butlery/services/unified/operations/modules/recipe_member_manager.dart';
import 'package:butlery/services/unified/operations/modules/recipe_comments_manager.dart';
import 'package:butlery/services/unified/operations/modules/recipe_discovery_service.dart';
import 'package:butlery/services/unified/operations/modules/recipe_social_stats.dart';
import 'package:butlery/services/unified/operations/modules/recipe_permission_helper.dart';

/// Social recipe operations coordinator - Clean delegation to focused modules
/// 
/// Refactored in Phase 9.8 to follow Single Responsibility Principle.
/// This class now acts as a clean coordinator that delegates to specialized modules:
/// - RecipeSharingManager: Recipe sharing and collaboration setup
/// - RecipeMemberManager: Member management for collaborative recipes  
/// - RecipeCommentsManager: Complete comment system with real-time updates
/// - RecipeDiscoveryService: Social recipe discovery and filtering
/// - RecipeSocialStats: Recipe rating, statistics, and social metrics
/// - RecipePermissionHelper: Permission checking and legacy compatibility
class SocialRecipeOperations {
  final dynamic _parent; // UnifiedRecipeService
  late final NotificationService? _notificationService;
  
  // Focused modules for each responsibility area
  late final RecipeSharingManager _sharingManager;
  late final RecipeMemberManager _memberManager;
  late final RecipeCommentsManager _commentsManager;
  late final RecipeDiscoveryService _discoveryService;
  late final RecipeSocialStats _socialStats;
  late final RecipePermissionHelper _permissionHelper;

  SocialRecipeOperations(this._parent) {
    // Initialize notification service if user is authenticated
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
    
    // Initialize focused modules
    _sharingManager = RecipeSharingManager(_parent, _notificationService);
    _memberManager = RecipeMemberManager(_parent, _notificationService);
    _commentsManager = RecipeCommentsManager(_parent, _notificationService);
    _discoveryService = RecipeDiscoveryService(_parent);
    _socialStats = RecipeSocialStats(_parent, _parent.firestore, _notificationService);
    _permissionHelper = RecipePermissionHelper(_parent);
    
    AppLogger.info('✅ SocialRecipeOperations initialized with focused modules');
  }

  // ===== RECIPE SHARING (Delegates to RecipeSharingManager) =====

  /// Share a personal recipe with other users
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

  /// Convert collaborative recipe back to personal
  Future<String?> makeRecipePersonal({
    required String collaborativeRecipeId,
    String? newTitle,
  }) async {
    return await _sharingManager.makeRecipePersonal(
      collaborativeRecipeId: collaborativeRecipeId,
      newTitle: newTitle,
    );
  }
  
  /// Duplicate personal recipe for sharing (creates copy before conversion)
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

  // ===== MEMBER MANAGEMENT (Delegates to RecipeMemberManager) =====

  /// Add member to collaborative recipe
  Future<bool> addMember({
    required String recipeId,
    required String userId,
    required String userDisplayName,
    ResourcePermission permission = ResourcePermission.viewer,
  }) async {
    return await _memberManager.addMember(
      recipeId: recipeId,
      memberId: userId,
      memberDisplayName: userDisplayName,
      permission: permission,
    );
  }

  /// Remove member from collaborative recipe
  Future<bool> removeMember({
    required String recipeId,
    required String userId,
  }) async {
    return await _memberManager.removeMember(
      recipeId: recipeId,
      memberId: userId,
    );
  }

  /// Update member permission
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

  /// Get all members of a collaborative recipe
  Future<List<Map<String, dynamic>>> getRecipeMembers(String recipeId) async {
    return await _memberManager.getRecipeMembers(recipeId);
  }

  /// Check if user can invite members to recipe
  bool canInviteMembers(String recipeId) {
    return _memberManager.canInviteMembers(recipeId);
  }
  
  /// Get member statistics for a recipe
  Map<String, dynamic> getMemberStatistics(String recipeId) {
    return _memberManager.getMemberStatistics(recipeId);
  }

  // ===== SOCIAL DISCOVERY (Delegates to RecipeDiscoveryService) =====

  /// Get all collaborative recipes current user is member of
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

  /// Get recipes shared with current user
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

  /// Get recipes owned by current user that are shared
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

  /// Get recipes by specific user (if accessible)
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
  
  /// Get trending collaborative recipes
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
  
  /// Search recipes across all accessible recipes
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

  /// Add comment to recipe
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

  /// Get comments for recipe
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

  /// Edit comment
  Future<bool> editComment({
    required String commentId,
    required String newContent,
  }) async {
    return await _commentsManager.editComment(
      commentId: commentId,
      newContent: newContent,
    );
  }

  /// Delete comment
  Future<bool> deleteComment(String commentId) async {
    return await _commentsManager.deleteComment(commentId);
  }

  /// Toggle like on comment
  Future<bool> toggleCommentLike(String commentId) async {
    return await _commentsManager.toggleCommentLike(commentId);
  }

  /// Stream comments for recipe (real-time)
  Stream<List<RecipeComment>> getCommentsStream(String recipeId) {
    return _commentsManager.getCommentsStream(recipeId);
  }
  
  /// Get comment statistics for a recipe
  Future<Map<String, dynamic>> getCommentStatistics(String recipeId) async {
    return await _commentsManager.getCommentStatistics(recipeId);
  }

  // ===== RECIPE RATING & SOCIAL STATS (Delegates to RecipeSocialStats) =====

  /// Rate a recipe
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

  /// Get comprehensive recipe statistics
  Future<Map<String, dynamic>> getRecipeStats(String recipeId) async {
    return await _socialStats.getRecipeStats(recipeId);
  }
  
  /// Get user's rating for a specific recipe
  Future<Map<String, dynamic>?> getUserRating(String recipeId) async {
    return await _socialStats.getUserRating(recipeId);
  }
  
  /// Get top-rated recipes
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
  
  /// Get social statistics for current user
  Future<Map<String, dynamic>> getUserSocialStats() async {
    return await _socialStats.getUserSocialStats();
  }

  // ===== LEGACY COMPATIBILITY =====

  /// Convert to legacy SharedRecipe format
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

  /// Mark shared recipe as viewed (legacy compatibility)
  Future<void> markSharedRecipeAsViewed(String recipeId) async {
    try {
      // This would update view tracking
      AppLogger.info('Marking recipe $recipeId as viewed');
    } catch (e) {
      AppLogger.error('Failed to mark recipe as viewed', e);
    }
  }
  
  /// Check legacy permission compatibility
  bool checkLegacyPermission(String recipeId, String userId, String action) {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;
    return _permissionHelper.checkLegacyPermission(recipe, userId, action);
  }

  // ===== PERMISSION HELPERS (Delegates to RecipePermissionHelper) =====

  /// Check if current user can view recipe
  bool canView(String recipeId) {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;
    return _permissionHelper.canViewRecipe(recipe);
  }

  /// Check if current user can edit recipe
  bool canEdit(String recipeId) {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;
    return _permissionHelper.canEditRecipe(recipe);
  }

  /// Check if current user can delete recipe
  bool canDelete(String recipeId) {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;
    return _permissionHelper.canDeleteRecipe(recipe);
  }

  /// Check if current user can manage members
  bool canManageMembers(String recipeId) {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;
    return _permissionHelper.canManageMembers(recipe);
  }
  
  /// Check if current user can comment on recipe
  bool canComment(String recipeId) {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;
    return _permissionHelper.canCommentOnRecipe(recipe);
  }
  
  /// Check if current user can rate a recipe
  bool canRate(String recipeId) {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;
    return _permissionHelper.canRateRecipe(recipe);
  }
  
  /// Get user's permission level for a recipe
  ResourcePermission getUserPermission(String recipeId, String userId) {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return ResourcePermission.read;
    return _permissionHelper.getUserPermission(recipe, userId);
  }
  
  /// Get permission summary for debugging/admin purposes
  Map<String, dynamic> getPermissionSummary(String recipeId, String userId) {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return {'error': 'Recipe not found'};
    return _permissionHelper.getPermissionSummary(recipe, userId);
  }

  // ===== ADDITIONAL FEATURES =====
  
  /// Get discovery statistics for current user
  Map<String, dynamic> getDiscoveryStatistics() {
    return _discoveryService.getDiscoveryStatistics();
  }
  
  /// Get popular categories in collaborative recipes
  Future<Map<String, int>> getPopularCollaborativeCategories({int limit = 10}) async {
    return await _discoveryService.getPopularCollaborativeCategories(limit: limit);
  }
  
  /// Get sharing statistics for current user
  Map<String, dynamic> getSharingStats() {
    return _sharingManager.getSharingStats();
  }
  
  /// Dispose of resources (especially comment streams)
  void dispose() {
    try {
      _commentsManager.dispose();
      AppLogger.info('✅ SocialRecipeOperations disposed successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to dispose SocialRecipeOperations', e);
    }
  }
}