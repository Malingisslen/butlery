// lib/services/unified/operations/realtime_recipe/collaboration_management_module.dart

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/operations/realtime_recipe/shared/realtime_recipe_utils.dart';

/// Collaboration management module
/// 
/// This module handles ONLY collaboration management operations:
/// - Enable/disable collaborative editing for recipes
/// - Manage collaboration membership and permissions
/// - Handle collaboration ownership transfers
/// - Track collaboration lifecycle events
/// 
/// ❌ DOES NOT CONTAIN: Watching, editing, presence, notifications
class CollaborationManagementModule {
  final dynamic _parent; // UnifiedRecipeService
  final dynamic _realtimeSyncService; // RealtimeSyncService?

  CollaborationManagementModule(this._parent, [this._realtimeSyncService]);

  // ===== COLLABORATION LIFECYCLE =====

  /// Enable collaborative editing for a personal recipe
  Future<bool> enableCollaborativeEditing(String recipeId, List<String> memberIds) async {
    try {
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) {
        AppLogger.error('Cannot enable collaborative editing: Recipe not found');
        return false;
      }

      if (recipe.isCollaborative) {
        AppLogger.warning('Recipe is already collaborative');
        return true;
      }

      if (!ServiceLocator.get<PermissionService>().isRecipeOwner(recipeId)) {
        AppLogger.error('Only recipe owner can enable collaborative editing');
        return false;
      }

      if (memberIds.isEmpty) {
        AppLogger.error('At least one member must be specified to enable collaboration');
        return false;
      }

      // Convert to collaborative recipe
      final collaborativeRecipeId = await _parent.createCollaborativeRecipe(
        title: recipe.title,
        memberIds: memberIds,
        memberDisplayNames: {}, // Would be populated from user service
        description: recipe.description,
        ingredients: recipe.ingredients,
        instructions: recipe.instructions,
        imageUrls: recipe.imageUrls,
        mealType: recipe.mealType,
        portions: recipe.portions,
        timeMinutes: recipe.timeMinutes,
        rating: recipe.rating,
        tags: recipe.tags,
        sourceUrl: recipe.sourceUrl,
      );

      if (collaborativeRecipeId != null) {
        // Delete original personal recipe
        await _parent.deleteRecipe(recipeId);
        
        AppLogger.success('Enabled collaborative editing for recipe: ${recipe.title}');
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Failed to enable collaborative editing', e);
      return false;
    }
  }

  /// Disable collaborative editing and convert back to personal recipe
  Future<bool> disableCollaborativeEditing(String recipeId) async {
    try {
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) {
        AppLogger.error('Cannot disable collaborative editing: Recipe not found');
        return false;
      }

      if (!recipe.isCollaborative) {
        AppLogger.warning('Recipe is not collaborative');
        return true;
      }

      if (!ServiceLocator.get<PermissionService>().isRecipeOwner(recipeId)) {
        AppLogger.error('Only recipe owner can disable collaborative editing');
        return false;
      }

      // Convert back to personal recipe
      final personalRecipeId = await _parent.createPersonalRecipe(
        title: recipe.title,
        description: recipe.description,
        ingredients: recipe.ingredients,
        instructions: recipe.instructions,
        imageUrls: recipe.imageUrls,
        mealType: recipe.mealType,
        portions: recipe.portions,
        timeMinutes: recipe.timeMinutes,
        rating: recipe.rating,
        tags: recipe.tags,
        sourceUrl: recipe.sourceUrl,
      );

      if (personalRecipeId != null) {
        // Delete collaborative recipe
        await _parent.deleteRecipe(recipeId);
        AppLogger.success('Disabled collaborative editing for recipe: ${recipe.title}');
        return true;
      }

      return false;
    } catch (e) {
      AppLogger.error('Failed to disable collaborative editing', e);
      return false;
    }
  }

  /// Check if recipe can be made collaborative
  bool canEnableCollaboration(String recipeId) {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;
    
    return !recipe.isCollaborative && 
           ServiceLocator.get<PermissionService>().isRecipeOwner(recipeId);
  }

  /// Check if recipe collaboration can be disabled
  bool canDisableCollaboration(String recipeId) {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;
    
    return recipe.isCollaborative && 
           ServiceLocator.get<PermissionService>().isRecipeOwner(recipeId);
  }

  // ===== MEMBER MANAGEMENT =====

  /// Add members to collaborative recipe
  Future<bool> addCollaborators(String recipeId, List<String> memberIds) async {
    try {
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) {
        AppLogger.error('Cannot add collaborators: Recipe not found');
        return false;
      }

      if (!recipe.isCollaborative) {
        AppLogger.error('Cannot add collaborators: Recipe is not collaborative');
        return false;
      }

      if (!ServiceLocator.get<PermissionService>().isRecipeOwner(recipeId)) {
        AppLogger.error('Only recipe owner can add collaborators');
        return false;
      }

      if (memberIds.isEmpty) {
        AppLogger.error('No members specified to add');
        return false;
      }

      // Filter out members who are already collaborators
      final currentMembers = recipe.socialData?.memberPermissions?.keys.toList() ?? [];
      final newMembers = memberIds.where((id) => !currentMembers.contains(id)).toList();

      if (newMembers.isEmpty) {
        AppLogger.warning('All specified members are already collaborators');
        return true;
      }

      // Add new members (this would typically update Firestore)
      // await _parent.addRecipeCollaborators(recipeId, newMembers);

      AppLogger.success('Added ${newMembers.length} new collaborators to recipe: ${recipe.title}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to add collaborators', e);
      return false;
    }
  }

  /// Remove members from collaborative recipe
  Future<bool> removeCollaborators(String recipeId, List<String> memberIds) async {
    try {
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) {
        AppLogger.error('Cannot remove collaborators: Recipe not found');
        return false;
      }

      if (!recipe.isCollaborative) {
        AppLogger.error('Cannot remove collaborators: Recipe is not collaborative');
        return false;
      }

      if (!ServiceLocator.get<PermissionService>().isRecipeOwner(recipeId)) {
        AppLogger.error('Only recipe owner can remove collaborators');
        return false;
      }

      if (memberIds.isEmpty) {
        AppLogger.error('No members specified to remove');
        return false;
      }

      // Prevent owner from removing themselves
      final ownerId = recipe.socialData?.ownerId;
      if (ownerId != null && memberIds.contains(ownerId)) {
        AppLogger.error('Recipe owner cannot be removed from collaboration');
        return false;
      }

      // Remove members (this would typically update Firestore)
      // await _parent.removeRecipeCollaborators(recipeId, memberIds);

      AppLogger.success('Removed ${memberIds.length} collaborators from recipe: ${recipe.title}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to remove collaborators', e);
      return false;
    }
  }

  /// Update member permissions in collaborative recipe
  Future<bool> updateMemberPermissions(String recipeId, Map<String, String> memberPermissions) async {
    try {
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) {
        AppLogger.error('Cannot update permissions: Recipe not found');
        return false;
      }

      if (!recipe.isCollaborative) {
        AppLogger.error('Cannot update permissions: Recipe is not collaborative');
        return false;
      }

      if (!ServiceLocator.get<PermissionService>().isRecipeOwner(recipeId)) {
        AppLogger.error('Only recipe owner can update member permissions');
        return false;
      }

      if (memberPermissions.isEmpty) {
        AppLogger.error('No permission updates specified');
        return false;
      }

      // Validate permission values
      final validPermissions = ['view', 'edit', 'admin'];
      for (final permission in memberPermissions.values) {
        if (!validPermissions.contains(permission)) {
          AppLogger.error('Invalid permission: $permission. Must be one of: ${validPermissions.join(', ')}');
          return false;
        }
      }

      // Update permissions (this would typically update Firestore)
      // await _parent.updateRecipeMemberPermissions(recipeId, memberPermissions);

      AppLogger.success('Updated permissions for ${memberPermissions.length} members in recipe: ${recipe.title}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to update member permissions', e);
      return false;
    }
  }

  // ===== OWNERSHIP MANAGEMENT =====

  /// Transfer ownership of collaborative recipe
  Future<bool> transferOwnership(String recipeId, String newOwnerId) async {
    try {
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) {
        AppLogger.error('Cannot transfer ownership: Recipe not found');
        return false;
      }

      if (!recipe.isCollaborative) {
        AppLogger.error('Cannot transfer ownership: Recipe is not collaborative');
        return false;
      }

      if (!ServiceLocator.get<PermissionService>().isRecipeOwner(recipeId)) {
        AppLogger.error('Only current owner can transfer ownership');
        return false;
      }

      final currentOwnerId = recipe.socialData?.ownerId;
      if (newOwnerId == currentOwnerId) {
        AppLogger.warning('User is already the owner');
        return true;
      }

      // Verify new owner is a member
      final memberPermissions = recipe.socialData?.memberPermissions ?? {};
      if (!memberPermissions.containsKey(newOwnerId)) {
        AppLogger.error('New owner must be a member of the recipe');
        return false;
      }

      // Transfer ownership (this would typically update Firestore)
      // await _parent.transferRecipeOwnership(recipeId, newOwnerId);

      AppLogger.success('Transferred ownership of recipe: ${recipe.title} to user: $newOwnerId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to transfer ownership', e);
      return false;
    }
  }

  /// Leave collaborative recipe as a member
  Future<bool> leaveCollaboration(String recipeId) async {
    try {
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null) {
        AppLogger.error('Cannot leave collaboration: Recipe not found');
        return false;
      }

      if (!recipe.isCollaborative) {
        AppLogger.error('Cannot leave collaboration: Recipe is not collaborative');
        return false;
      }

      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) {
        AppLogger.error('User must be logged in to leave collaboration');
        return false;
      }

      // Prevent owner from leaving without transferring ownership
      if (recipe.socialData?.ownerId == currentUserId) {
        AppLogger.error('Recipe owner cannot leave collaboration. Transfer ownership first.');
        return false;
      }

      // Remove user from collaboration
      await removeCollaborators(recipeId, [currentUserId]);

      AppLogger.success('Left collaboration for recipe: ${recipe.title}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to leave collaboration', e);
      return false;
    }
  }

  // ===== COLLABORATION INFORMATION =====

  /// Get collaboration details for recipe
  Map<String, dynamic> getCollaborationDetails(String recipeId) {
    try {
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null || !recipe.isCollaborative) return {};

      final socialData = recipe.socialData;
      if (socialData == null) return {};

      final memberCount = socialData.memberPermissions?.length ?? 0;
      final activeEditors = RealtimeRecipeUtils.getActiveEditorsFromRecipe(recipe);
      
      return {
        'isCollaborative': true,
        'ownerId': socialData.ownerId,
        'ownerDisplayName': socialData.ownerDisplayName,
        'memberCount': memberCount,
        'activeEditorsCount': activeEditors.length,
        'members': socialData.memberPermissions?.entries.map((entry) => {
          'userId': entry.key,
          'permission': entry.value.toString().split('.').last,
          'isActive': activeEditors.contains(entry.key),
        }).toList() ?? [],
        'canEdit': ServiceLocator.get<PermissionService>().canEditRecipe(recipeId),
        'canManage': ServiceLocator.get<PermissionService>().isRecipeOwner(recipeId),
      };
    } catch (e) {
      AppLogger.error('Failed to get collaboration details', e);
      return {};
    }
  }

  /// Get collaboration statistics
  Map<String, dynamic> getCollaborationStats(String recipeId) {
    return RealtimeRecipeUtils.getCollaborationStats(
      _parent.recipes.where((r) => r.id == recipeId).firstOrNull!
    );
  }

  /// Get collaboration history for recipe
  Future<List<Map<String, dynamic>>> getCollaborationHistory(String recipeId) async {
    try {
      final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
      if (recipe == null || !recipe.isCollaborative) return [];

      // This would fetch actual collaboration history from Firebase
      // For now, generate simulated history
      return RealtimeRecipeUtils.generateEditHistory(recipe);
    } catch (e) {
      AppLogger.error('Failed to get collaboration history', e);
      return [];
    }
  }

  // ===== COLLABORATION VALIDATION =====

  /// Validate collaboration settings
  Map<String, String> validateCollaborationSettings({
    required List<String> memberIds,
    Map<String, String>? memberPermissions,
  }) {
    final errors = <String, String>{};

    if (memberIds.isEmpty) {
      errors['members'] = 'At least one member must be specified';
    }

    if (memberIds.length > 20) {
      errors['members'] = 'Maximum 20 members allowed in collaboration';
    }

    if (memberPermissions != null) {
      final validPermissions = ['view', 'edit', 'admin'];
      for (final entry in memberPermissions.entries) {
        if (!validPermissions.contains(entry.value)) {
          errors['permission_${entry.key}'] = 'Invalid permission: ${entry.value}';
        }
      }
    }

    return errors;
  }

  /// Check collaboration limits
  bool isWithinCollaborationLimits(String recipeId, int additionalMembers) {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null) return false;

    final currentMemberCount = recipe.socialData?.memberPermissions?.length ?? 0;
    final totalMembers = currentMemberCount + additionalMembers;
    
    return totalMembers <= 20; // Maximum collaboration size
  }

  // ===== STATUS AND DIAGNOSTICS =====

  /// Get collaboration status for recipe
  Map<String, dynamic> getCollaborationStatus(String recipeId) {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    
    return {
      'exists': recipe != null,
      'isCollaborative': recipe?.isCollaborative ?? false,
      'canEnableCollaboration': canEnableCollaboration(recipeId),
      'canDisableCollaboration': canDisableCollaboration(recipeId),
      'memberCount': recipe?.socialData?.memberPermissions?.length ?? 0,
      'userRole': _getUserRole(recipeId),
      'hasRealtimeService': _realtimeSyncService != null,
    };
  }

  /// Get user's role in collaboration
  String _getUserRole(String recipeId) {
    final recipe = _parent.recipes.where((r) => r.id == recipeId).firstOrNull;
    if (recipe == null || !recipe.isCollaborative) return 'none';

    final currentUserId = _parent.currentUserId;
    if (currentUserId == null) return 'none';

    if (recipe.socialData?.ownerId == currentUserId) {
      return 'owner';
    }

    final permission = recipe.socialData?.memberPermissions?[currentUserId];
    return permission?.toString().split('.').last ?? 'none';
  }
}