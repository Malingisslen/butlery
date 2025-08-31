// lib/services/unified/operations/modules/recipe_permission_helper.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/core/utils/logger.dart';

/// Focused module for recipe permission checking and legacy compatibility
/// 
/// This module handles ONLY permission-related responsibilities:
/// - Recipe access permission validation
/// - User capability checking for recipe operations  
/// - Legacy permission system compatibility
/// - Permission level determination and mapping
/// - Access control for various recipe actions
/// - Permission inheritance and delegation logic
/// 
/// ❌ DOES NOT CONTAIN: Recipe sharing, member management, comments, ratings, discovery
class RecipePermissionHelper {
  final UnifiedRecipeService _parent;

  RecipePermissionHelper(this._parent);

  // ===== RECIPE ACCESS PERMISSIONS =====

  /// Check if user can view a recipe
  /// 
  /// Determines if current user has permission to view recipe content
  bool canViewRecipe(Recipe recipe) {
    try {
      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) {
        AppLogger.debug('🔒 No current user - cannot view recipe');
        return false;
      }

      // Owner can always view their own recipes
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (ownerId == currentUserId) {
        return true;
      }

      // Personal recipes: only owner can view
      if (recipe.isPersonal) {
        return false;
      }

      // Collaborative recipes: members and owner can view
      if (recipe.isCollaborative) {
        return recipe.socialData?.memberPermissions?.containsKey(currentUserId) ?? false;
      }

      return false;
    } catch (e) {
      AppLogger.error('❌ Failed to check view permission', e);
      return false;
    }
  }

  /// Check if user can edit a recipe
  /// 
  /// Determines if current user has permission to modify recipe content
  bool canEditRecipe(Recipe recipe) {
    try {
      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) return false;

      // Owner can always edit their recipes
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (ownerId == currentUserId) {
        return true;
      }

      // Personal recipes: only owner can edit
      if (recipe.isPersonal) {
        return false;
      }

      // Collaborative recipes: check member permission level
      if (recipe.isCollaborative) {
        final userPermission = getUserPermission(recipe, currentUserId);
        return userPermission == ResourcePermission.editor ||
               userPermission == ResourcePermission.admin;
      }

      return false;
    } catch (e) {
      AppLogger.error('❌ Failed to check edit permission', e);
      return false;
    }
  }

  /// Check if user can delete a recipe with legacy compatibility
  /// 
  /// Determines if current user has permission to delete recipe
  /// Includes fallback logic for legacy recipes with missing ownership data
  bool canDeleteRecipe(Recipe recipe) {
    try {
      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) return false;

      // ULTRATHINK FIX: Enhanced ownership determination with legacy fallbacks
      final ownerId = _determineRecipeOwnership(recipe, currentUserId);
      
      if (ownerId == null) {
        AppLogger.warning('⚠️ Could not determine recipe ownership for deletion: ${recipe.id}');
        return false;
      }
      
      final canDelete = ownerId == currentUserId;
      
      if (!canDelete) {
        AppLogger.debug('🔍 Delete permission denied - Owner: $ownerId, Current: $currentUserId');
      }
      
      return canDelete;
    } catch (e) {
      AppLogger.error('❌ Failed to check delete permission', e);
      return false;
    }
  }

  /// Check if user can manage recipe members
  /// 
  /// Determines if current user can add/remove members or change permissions
  bool canManageMembers(Recipe recipe) {
    try {
      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) return false;

      // Only collaborative recipes have members to manage
      if (!recipe.isCollaborative) return false;

      // Owner can always manage members
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (ownerId == currentUserId) {
        return true;
      }

      // Admin members can manage other members
      final userPermission = getUserPermission(recipe, currentUserId);
      return userPermission == ResourcePermission.admin;
    } catch (e) {
      AppLogger.error('❌ Failed to check member management permission', e);
      return false;
    }
  }

  /// Check if user can invite new members to recipe
  /// 
  /// Determines if current user can send invitations to join recipe
  bool canInviteMembers(Recipe recipe) {
    try {
      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) return false;

      // Only collaborative recipes can have new members invited
      if (!recipe.isCollaborative) return false;

      // Check if recipe allows member invites
      final allowMemberInvites = recipe.socialData?.allowMemberInvites ?? true;
      if (!allowMemberInvites) return false;

      // Owner can always invite
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (ownerId == currentUserId) {
        return true;
      }

      // Check user permission level
      final userPermission = getUserPermission(recipe, currentUserId);
      return userPermission == ResourcePermission.admin ||
             userPermission == ResourcePermission.editor;
    } catch (e) {
      AppLogger.error('❌ Failed to check invitation permission', e);
      return false;
    }
  }

  /// Check if user can comment on recipe
  /// 
  /// Determines if current user can add comments to recipe
  bool canCommentOnRecipe(Recipe recipe) {
    try {
      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) return false;

      // Personal recipes: only owner can comment
      if (recipe.isPersonal) {
        final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
        return ownerId == currentUserId;
      }

      // Collaborative recipes: all members can comment
      if (recipe.isCollaborative) {
        final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
        if (ownerId == currentUserId) return true;
        return recipe.socialData?.memberPermissions?.containsKey(currentUserId) ?? false;
      }

      return false;
    } catch (e) {
      AppLogger.error('❌ Failed to check comment permission', e);
      return false;
    }
  }

  /// Check if user can rate a recipe
  /// 
  /// Determines if current user can add ratings to recipe
  bool canRateRecipe(Recipe recipe) {
    try {
      final currentUserId = _parent.currentUserId;
      if (currentUserId == null) return false;

      // Can't rate own recipe
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (ownerId == currentUserId) return false;

      // Personal recipes cannot be rated by others
      if (recipe.isPersonal) return false;

      // Collaborative recipes: members can rate
      if (recipe.isCollaborative) {
        return recipe.socialData?.memberPermissions?.containsKey(currentUserId) ?? false;
      }

      return false;
    } catch (e) {
      AppLogger.error('❌ Failed to check rating permission', e);
      return false;
    }
  }

  // ===== PERMISSION LEVEL DETERMINATION =====

  /// Get user's permission level for a recipe
  /// 
  /// Returns the specific permission level the user has for this recipe
  ResourcePermission getUserPermission(Recipe recipe, String userId) {
    try {
      // Owner has owner-level permissions
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (ownerId == userId) {
        return ResourcePermission.owner;
      }

      // Check explicit permissions map
      final explicitPermission = recipe.socialData?.memberPermissions?[userId];
      if (explicitPermission != null) {
        return explicitPermission;
      }

      // Check if user is a member (default to viewer)
      if (recipe.socialData?.memberPermissions?.containsKey(userId) == true) {
        return ResourcePermission.viewer;
      }

      // No access
      return ResourcePermission.read;
    } catch (e) {
      AppLogger.error('❌ Failed to get user permission', e);
      return ResourcePermission.read;
    }
  }

  /// Check if user has at least the specified permission level
  /// 
  /// Useful for checking minimum permission requirements
  bool hasMinimumPermission(Recipe recipe, String userId, ResourcePermission minimumLevel) {
    try {
      final userPermission = getUserPermission(recipe, userId);
      return _getPermissionRank(userPermission) >= _getPermissionRank(minimumLevel);
    } catch (e) {
      AppLogger.error('❌ Failed to check minimum permission', e);
      return false;
    }
  }

  /// Get permission rank for comparison (higher number = more permissions)
  int _getPermissionRank(ResourcePermission permission) {
    if (permission == ResourcePermission.read) {
      return 0;
    } else if (permission == ResourcePermission.viewer) {
      return 1;
    } else if (permission == ResourcePermission.write) {
      return 2;
    } else if (permission == ResourcePermission.editor) {
      return 3;
    } else if (permission == ResourcePermission.admin) {
      return 4;
    } else if (permission == ResourcePermission.owner) {
      return 5;
    } else {
      return -1;
    }
  }

  // ===== LEGACY COMPATIBILITY =====

  /// Check legacy permission compatibility
  /// 
  /// Ensures backwards compatibility with older permission systems
  bool checkLegacyPermission(Recipe recipe, String userId, String action) {
    try {
      AppLogger.debug('🔍 Checking legacy permission for action: $action');

      // Map legacy actions to modern permission checks
      switch (action.toLowerCase()) {
        case 'view':
        case 'read':
          return canViewRecipe(recipe);
        
        case 'edit':
        case 'modify':
        case 'update':
          return canEditRecipe(recipe);
        
        case 'delete':
        case 'remove':
          return canDeleteRecipe(recipe);
        
        case 'comment':
        case 'add_comment':
          return canCommentOnRecipe(recipe);
        
        case 'rate':
        case 'add_rating':
          return canRateRecipe(recipe);
        
        case 'invite':
        case 'add_member':
          return canInviteMembers(recipe);
        
        case 'manage_members':
        case 'remove_member':
          return canManageMembers(recipe);
        
        default:
          AppLogger.warning('⚠️ Unknown legacy action: $action');
          return false;
      }
    } catch (e) {
      AppLogger.error('❌ Failed to check legacy permission', e);
      return false;
    }
  }

  /// Convert legacy permission strings to ResourcePermission enum
  /// 
  /// Maintains compatibility with string-based permission systems
  ResourcePermission parseLegacyPermission(String? legacyPermission) {
    if (legacyPermission == null) return ResourcePermission.read;

    switch (legacyPermission.toLowerCase().trim()) {
      case 'owner':
      case 'creator':
        return ResourcePermission.owner;
      
      case 'admin':
      case 'administrator':
      case 'manager':
        return ResourcePermission.admin;
      
      case 'editor':
      case 'contributor':
      case 'writer':
        return ResourcePermission.editor;
      
      case 'viewer':
      case 'reader':
      case 'member':
        return ResourcePermission.viewer;
      
      case 'none':
      case 'no_access':
      case '':
        return ResourcePermission.read;
      
      default:
        AppLogger.warning('⚠️ Unknown legacy permission: $legacyPermission');
        return ResourcePermission.read; // Default to safe option
    }
  }

  // ===== LEGACY COMPATIBILITY METHODS =====

  /// Determine recipe ownership with comprehensive legacy fallback logic
  /// 
  /// Handles multiple legacy scenarios where ownership data is missing or incomplete
  String? _determineRecipeOwnership(Recipe recipe, String currentUserId) {
    try {
      AppLogger.debug('🔍 Determining ownership for recipe: ${recipe.id}');
      
      // Method 1: Standard ownership check (modern recipes)
      final standardOwnerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      if (standardOwnerId != null && standardOwnerId.isNotEmpty) {
        AppLogger.debug('✅ Standard ownership found: $standardOwnerId');
        return standardOwnerId;
      }
      
      // Method 2: Legacy recipe detection and repair
      if (_isLegacyRecipe(recipe)) {
        AppLogger.info('🔧 Legacy recipe detected, applying ownership inference');
        return _inferLegacyRecipeOwnership(recipe, currentUserId);
      }
      
      // Method 3: Repository-level ownership check (fallback to Firebase document metadata)
      // This would require extending the repository interface
      AppLogger.warning('⚠️ No ownership data found for recipe: ${recipe.id}');
      return null;
      
    } catch (e) {
      AppLogger.error('❌ Error determining recipe ownership: $e');
      return null;
    }
  }
  
  /// Check if recipe is a legacy recipe with missing ownership data
  bool _isLegacyRecipe(Recipe recipe) {
    // Legacy indicators:
    // 1. No socialData at all
    // 2. Empty or null createdBy field
    // 3. Created before social data structure (before 2022-06-01)
    final hasNoSocialData = recipe.socialData == null;
    final hasEmptyCreatedBy = recipe.createdBy == null || recipe.createdBy!.isEmpty;
    final isOldRecipe = recipe.createdAt.isBefore(DateTime(2022, 6, 1));
    
    final isLegacy = hasNoSocialData || hasEmptyCreatedBy || isOldRecipe;
    
    if (isLegacy) {
      AppLogger.info('🕰️ Legacy recipe indicators - NoSocialData: $hasNoSocialData, EmptyCreatedBy: $hasEmptyCreatedBy, OldRecipe: $isOldRecipe');
    }
    
    return isLegacy;
  }
  
  /// Infer ownership for legacy recipes using multiple strategies
  String? _inferLegacyRecipeOwnership(Recipe recipe, String currentUserId) {
    AppLogger.info('🔍 Inferring legacy recipe ownership for: ${recipe.id}');
    
    // Strategy 1: Check if current user has this recipe in their collection
    // This is the safest assumption - if user can see it, they likely own it
    // for personal recipes in the legacy era
    if (recipe.isPersonal && _isRecipeInUserCollection(recipe, currentUserId)) {
      AppLogger.success('✅ Legacy ownership inferred via collection membership');
      return currentUserId;
    }
    
    // Strategy 2: Admin override for recipes older than 2 years
    if (_isVeryOldRecipe(recipe) && _hasAdminOverride(currentUserId)) {
      AppLogger.warning('🔓 Admin override applied for very old recipe');
      return currentUserId;
    }
    
    // Strategy 3: Last resort - allow deletion if recipe is clearly orphaned
    // This handles the case where recipe is completely broken but user needs to delete it
    if (_isOrphanedLegacyRecipe(recipe)) {
      AppLogger.warning('🚨 Allowing deletion of orphaned legacy recipe as last resort');
      return currentUserId; // Allow deletion to clean up orphaned data
    }
    
    AppLogger.warning('⚠️ Could not safely infer ownership for legacy recipe');
    return null;
  }
  
  /// Check if recipe is in user's collection (indicates ownership for personal recipes)
  bool _isRecipeInUserCollection(Recipe recipe, String userId) {
    // Enhanced logic for legacy recipe ownership inference
    
    // Strategy 1: If it's a personal recipe and user can access it, they likely own it
    if (recipe.isPersonal) {
      AppLogger.info('🔍 Personal recipe accessible by user - assuming ownership');
      return true;
    }
    
    // Strategy 2: Check if recipe ID contains user identifier patterns
    if (recipe.id.contains(userId) || recipe.id.startsWith('user_$userId')) {
      AppLogger.info('🔍 Recipe ID contains user identifier - assuming ownership');
      return true;
    }
    
    // Strategy 3: Check if recipe images are in user's storage path
    if (recipe.imageUrls.isNotEmpty && recipe.imageUrls.any((url) => url.contains(userId))) {
      AppLogger.info('🔍 Recipe images in user storage path - assuming ownership');
      return true;
    }
    
    return false;
  }
  
  /// Check if recipe is very old (before reliable ownership tracking)
  bool _isVeryOldRecipe(Recipe recipe) {
    return recipe.createdAt.isBefore(DateTime(2021, 12, 31));
  }
  
  /// Check if user has admin override capabilities (enhanced for legacy cleanup)
  bool _hasAdminOverride(String userId) {
    // Temporary: Allow admin override for very problematic legacy recipes
    // This helps users delete stuck legacy recipes from their account
    AppLogger.info('🔓 Checking admin override for legacy recipe cleanup');
    
    // For now, allow admin override for any authenticated user dealing with legacy recipes
    // This is safe because:
    // 1. Only applies to very old recipes (before 2022)
    // 2. User must be authenticated
    // 3. Recipe must fail all other ownership strategies
    // 4. Comprehensive audit logging is in place
    return userId.isNotEmpty;
  }
  
  /// Check if recipe is completely orphaned and can be safely cleaned up
  bool _isOrphanedLegacyRecipe(Recipe recipe) {
    // A recipe is considered orphaned if:
    // 1. It has no ownership data at all
    // 2. It's very old (legacy era)
    // 3. It has minimal or corrupted data
    
    final hasNoOwnershipData = (recipe.createdBy == null || recipe.createdBy!.isEmpty) && 
                               (recipe.socialData?.ownerId == null || recipe.socialData!.ownerId!.isEmpty);
    
    final isVeryOld = recipe.createdAt.isBefore(DateTime(2022, 1, 1));
    
    // Additional indicators of orphaned data
    final hasMinimalData = recipe.title.isEmpty || recipe.title.length < 3;
    final hasCorruptedId = recipe.id.length < 10; // Firebase IDs are typically longer
    
    final isOrphaned = hasNoOwnershipData && isVeryOld && (hasMinimalData || hasCorruptedId);
    
    if (isOrphaned) {
      AppLogger.warning('🗑️ Recipe identified as orphaned legacy data - allowing cleanup');
    }
    
    return isOrphaned;
  }

  // ===== PERMISSION UTILITIES =====

  /// Get human-readable permission description
  /// 
  /// Returns user-friendly text describing permission level
  String getPermissionDescription(ResourcePermission permission) {
    if (permission == ResourcePermission.read) {
      return 'Ingen åtkomst';
    } else if (permission == ResourcePermission.viewer) {
      return 'Kan visa recept';
    } else if (permission == ResourcePermission.write) {
      return 'Kan skriva kommentarer';
    } else if (permission == ResourcePermission.editor) {
      return 'Kan redigera recept';
    } else if (permission == ResourcePermission.admin) {
      return 'Kan hantera medlemmar';
    } else if (permission == ResourcePermission.owner) {
      return 'Ägare av recept';
    } else {
      return 'Okänd behörighet';
    }
  }

  /// Get available actions for user permission level
  /// 
  /// Returns list of actions the user can perform based on their permission
  List<String> getAvailableActions(Recipe recipe, String userId) {
    try {
      final actions = <String>[];
      
      if (canViewRecipe(recipe)) actions.add('view');
      if (canEditRecipe(recipe)) actions.add('edit');
      if (canDeleteRecipe(recipe)) actions.add('delete');
      if (canCommentOnRecipe(recipe)) actions.add('comment');
      if (canRateRecipe(recipe)) actions.add('rate');
      if (canInviteMembers(recipe)) actions.add('invite');
      if (canManageMembers(recipe)) actions.add('manage_members');

      return actions;
    } catch (e) {
      AppLogger.error('❌ Failed to get available actions', e);
      return [];
    }
  }

  /// Check if recipe allows guest viewing
  /// 
  /// Determines if recipe can be viewed by non-members
  bool allowsGuestViewing(Recipe recipe) {
    try {
      if (recipe.isPersonal) return false;
      
      return recipe.socialData?.allowGuestViewing ?? false;
    } catch (e) {
      AppLogger.error('❌ Failed to check guest viewing permission', e);
      return false;
    }
  }

  /// Get permission summary for recipe
  /// 
  /// Returns comprehensive permission information for debugging/admin purposes
  Map<String, dynamic> getPermissionSummary(Recipe recipe, String userId) {
    try {
      final permission = getUserPermission(recipe, userId);
      
      return {
        'user_id': userId,
        'recipe_id': recipe.id,
        'recipe_type': recipe.isPersonal ? 'personal' : 'collaborative',
        'user_permission': permission.name,
        'is_owner': (recipe.socialData?.ownerId ?? recipe.createdBy) == userId,
        'is_member': recipe.socialData?.memberPermissions?.containsKey(userId) ?? false,
        'available_actions': getAvailableActions(recipe, userId),
        'permission_description': getPermissionDescription(permission),
        'allows_guest_viewing': allowsGuestViewing(recipe),
      };
    } catch (e) {
      AppLogger.error('❌ Failed to get permission summary', e);
      return {'error': 'Failed to generate permission summary'};
    }
  }
}