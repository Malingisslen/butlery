/// 🔍 AI INFO BLOCK:
/// Component: Social Recipe Operations - Feature interface for social recipe functionality
/// File: lib/services/unified/operations/social_recipe_operations.dart
/// Quick Guide: Handles all social recipe operations like sharing, comments, and social features
/// Dependencies IN: UnifiedRecipeService, UnifiedRecipe model, SocialRecipeService logic
/// Dependencies OUT: Used by ViewModels for social recipe operations
/// Data flow: ViewModels -> SocialRecipeOperations -> UnifiedRecipeService -> Firebase
/// State management: Delegates to parent UnifiedRecipeService
/// Purpose: Separate social recipe concerns from unified service
/// Common issues: Permission validation, member management, sharing logic
/// Test coverage: Unit tests for sharing and social operations
/// Performance: Real-time updates for shared recipes
/// Analytics: Recipe sharing events, member activity
/// Code smells: None - follows single responsibility principle
/// Connected to: UnifiedRecipeService, Social ViewModels, Friend services
/// Used in phases: Phase 5 - Service Consolidation

import '../../../models/unified/unified_recipe.dart';
import '../../../core/utils/logger.dart';
import '../../permission_service.dart';
import '../../../core/injection.dart';

/// Social recipe operations feature interface
/// 
/// Handles all operations related to social recipe features:
/// - Recipe sharing and collaboration invitations
/// - Member management for collaborative recipes
/// - Recipe comments and social interactions
/// - Social discovery and recommendations
/// - Integration with legacy social recipe service
class SocialRecipeOperations {
  final dynamic _parent; // UnifiedRecipeService

  SocialRecipeOperations(this._parent);

  // ===== RECIPE SHARING =====

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
    try {
      final personalRecipe = _parent.recipes
          .where((r) => r.id == recipeId && r.isPersonal)
          .firstOrNull;
      
      if (personalRecipe == null) {
        AppLogger.error('Cannot share recipe: Recipe not found or not personal');
        return null;
      }

      // Create collaborative version
      return await _parent.createCollaborativeRecipe(
        name: personalRecipe.name,
        memberIds: memberIds,
        memberDisplayNames: memberDisplayNames,
        description: personalRecipe.description,
        ingredients: personalRecipe.ingredients,
        instructions: personalRecipe.instructions,
        imageUrls: personalRecipe.imageUrls,
        mealType: personalRecipe.mealType,
        portions: personalRecipe.portions,
        timeMinutes: personalRecipe.timeMinutes,
        rating: personalRecipe.rating,
        tags: personalRecipe.tags,
        sourceUrl: personalRecipe.sourceUrl,
        descriptionCollaborative: collaborativeDescription,
        allowGuestViewing: allowGuestViewing,
        allowMemberInvites: allowMemberInvites,
        categoryIds: categoryIds,
      );
    } catch (e) {
      AppLogger.error('Failed to share recipe', e);
      return null;
    }
  }

  /// Convert collaborative recipe back to personal
  Future<String?> makeRecipePersonal(String collaborativeRecipeId) async {
    try {
      final collaborativeRecipe = _parent.recipes
          .where((r) => r.id == collaborativeRecipeId && r.isCollaborative)
          .firstOrNull;
      
      if (collaborativeRecipe == null) {
        AppLogger.error('Cannot convert recipe: Recipe not found or not collaborative');
        return null;
      }

      // Check if user is owner
      if (collaborativeRecipe.ownerId != _parent.currentUserId) {
        AppLogger.error('Cannot convert recipe: User is not owner');
        return null;
      }

      // Create personal version
      final personalRecipeId = await _parent.createPersonalRecipe(
        name: collaborativeRecipe.name,
        description: collaborativeRecipe.description,
        ingredients: collaborativeRecipe.ingredients,
        instructions: collaborativeRecipe.instructions,
        imageUrls: collaborativeRecipe.imageUrls,
        mealType: collaborativeRecipe.mealType,
        portions: collaborativeRecipe.portions,
        timeMinutes: collaborativeRecipe.timeMinutes,
        rating: collaborativeRecipe.rating,
        tags: collaborativeRecipe.tags,
        sourceUrl: '${collaborativeRecipe.sourceUrl} (konverterat från kollaborativt)',
      );

      // Delete collaborative version
      if (personalRecipeId != null) {
        await _parent.deleteRecipe(collaborativeRecipeId);
      }

      return personalRecipeId;
    } catch (e) {
      AppLogger.error('Failed to make recipe personal', e);
      return null;
    }
  }

  // ===== MEMBER MANAGEMENT =====

  /// Add member to collaborative recipe
  Future<bool> addMember({
    required String recipeId,
    required String userId,
    required String userDisplayName,
    RecipePermission permission = RecipePermission.edit,
  }) async {
    try {
      return await _parent.addMemberToRecipe(recipeId, userId, permission);
    } catch (e) {
      AppLogger.error('Failed to add member to recipe', e);
      return false;
    }
  }

  /// Remove member from collaborative recipe
  Future<bool> removeMember({
    required String recipeId,
    required String userId,
  }) async {
    try {
      return await _parent.removeMemberFromRecipe(recipeId, userId);
    } catch (e) {
      AppLogger.error('Failed to remove member from recipe', e);
      return false;
    }
  }

  /// Update member permission
  Future<bool> updateMemberPermission({
    required String recipeId,
    required String userId,
    required RecipePermission permission,
  }) async {
    try {
      return await _parent.updateMemberPermission(recipeId, userId, permission);
    } catch (e) {
      AppLogger.error('Failed to update member permission', e);
      return false;
    }
  }

  /// Get all members of a collaborative recipe
  Map<String, RecipePermission> getRecipeMembers(String recipeId) {
    final recipe = _parent.recipes
        .where((r) => r.id == recipeId && r.isCollaborative)
        .firstOrNull;
    
    return recipe?.memberPermissions ?? {};
  }

  /// Check if user can invite members to recipe
  bool canInviteMembers(String recipeId) {
    final recipe = _parent.recipes
        .where((r) => r.id == recipeId && r.isCollaborative)
        .firstOrNull;
    
    if (recipe == null) return false;
    
    return recipe.allowMemberInvites && 
           _parent.currentUserId != null &&
           recipe.canManageMembersBy(_parent.currentUserId!);
  }

  // ===== SOCIAL DISCOVERY =====

  /// Get all collaborative recipes current user is member of
  List<UnifiedRecipe> getCollaborativeRecipes() {
    return _parent.collaborativeRecipes;
  }

  /// Get recipes shared with current user
  List<UnifiedRecipe> getSharedWithMe() {
    if (!sl<PermissionService>().isAuthenticated) return [];
    
    return _parent.collaborativeRecipes
        .where((r) => r.ownerId != _parent.currentUserId)
        .toList();
  }

  /// Get recipes owned by current user that are shared
  List<UnifiedRecipe> getSharedByMe() {
    if (!sl<PermissionService>().isAuthenticated) return [];
    
    return _parent.collaborativeRecipes
        .where((r) => sl<PermissionService>().isRecipeOwner(r.id))
        .toList();
  }

  /// Get recipes by specific user (if accessible)
  List<UnifiedRecipe> getRecipesByUser(String userId) {
    if (!sl<PermissionService>().isAuthenticated) return [];
    
    return _parent.recipes
        .where((r) => sl<PermissionService>().isOwner(r.ownerId) && 
          sl<PermissionService>().canViewRecipe(r.id))
        .toList();
  }

  // ===== RECIPE COMMENTS (Future Enhancement) =====

  /// Add comment to recipe
  Future<bool> addComment({
    required String recipeId,
    required String comment,
  }) async {
    try {
      // This would integrate with a comment system
      // For now, we can add to recipe metadata or separate collection
      AppLogger.info('Comment functionality to be implemented');
      return true;
    } catch (e) {
      AppLogger.error('Failed to add comment', e);
      return false;
    }
  }

  /// Get comments for recipe
  Future<List<Map<String, dynamic>>> getComments(String recipeId) async {
    try {
      // This would fetch from comment system
      AppLogger.info('Comment fetching functionality to be implemented');
      return [];
    } catch (e) {
      AppLogger.error('Failed to get comments', e);
      return [];
    }
  }

  // ===== RECIPE RATING & SOCIAL STATS =====

  /// Rate a recipe
  Future<bool> rateRecipe({
    required String recipeId,
    required double rating,
  }) async {
    try {
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) return false;

      // For collaborative recipes, we might want to track individual ratings
      // For now, update the recipe's rating
      return await _parent.updateRecipeContent(
        recipeId: recipeId,
        rating: rating,
      );
    } catch (e) {
      AppLogger.error('Failed to rate recipe', e);
      return false;
    }
  }

  /// Get social stats for recipe
  Map<String, dynamic> getRecipeStats(String recipeId) {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return {};

    return {
      'memberCount': recipe.isCollaborative ? recipe.memberPermissions.length : 1,
      'lastActivity': recipe.updatedAt,
      'lastEditedBy': recipe.lastEditedByDisplayName,
      'viewsCount': 0, // To be implemented
      'rating': recipe.rating,
      'isCollaborative': recipe.isCollaborative,
      'allowGuestViewing': recipe.isCollaborative ? recipe.allowGuestViewing : false,
    };
  }

  // ===== LEGACY COMPATIBILITY =====

  /// Convert to legacy SharedRecipe format
  List<Map<String, dynamic>> getLegacySharedRecipes() {
    try {
      return getSharedWithMe().map((recipe) {
        return {
          'id': recipe.id,
          'title': recipe.name,
          'description': recipe.description,
          'ownerId': recipe.ownerId,
          'ownerDisplayName': recipe.ownerDisplayName,
          'sharedAt': recipe.createdAt.toIso8601String(),
          'permissions': {_parent.currentUserId!: 'view'}, // Simplified
          'recipe': recipe.toLegacyRecipe(),
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

  // ===== PERMISSION HELPERS =====

  /// Check if current user can edit recipe
  bool canEdit(String recipeId) {
    return sl<PermissionService>().canEditRecipe(recipeId);
  }

  /// Check if current user can view recipe
  bool canView(String recipeId) {
    return sl<PermissionService>().canViewRecipe(recipeId);
  }

  /// Check if current user can manage members
  bool canManageMembers(String recipeId) {
    return sl<PermissionService>().canInviteToRecipe(recipeId);
  }

  /// Check if current user can delete recipe
  bool canDelete(String recipeId) {
    return sl<PermissionService>().canDeleteRecipe(recipeId);
  }
}

// RecipePermission is now imported from ../types/recipe_types.dart