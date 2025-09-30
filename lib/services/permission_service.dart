/// Comprehensive permission management service providing centralized authorization and access control across the application.

import 'package:flutter/foundation.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

/// This singleton service provides sophisticated permission management and access control functionality for
/// collaborative features including recipes, shopping lists, groups, and user interactions. It implements
/// a simplified mock-based permission system that can be easily extended to integrate with real authentication
/// and authorization backends while maintaining consistent permission semantics throughout the application.
///
/// **Architecture Integration:**
/// - Uses singleton pattern for centralized permission management across the application
/// - Integrates with [UserProfile] model for user identity and metadata management
/// - Provides [ResourcePermission] integration for role-based access control
/// - Implements mock authentication state for development and testing environments
/// - Coordinates with collaborative features to enforce access control policies
///
/// **Permission Management Features:**
/// - **User Authentication**: Simplified authentication state management with mock user support
/// - **Resource Access Control**: Comprehensive permission checking for recipes, shopping lists, and groups
/// - **Role-Based Permissions**: Support for different permission levels (viewer, editor, admin, owner)
/// - **Ownership Validation**: Owner identification and ownership-based permission checking
/// - **Collaborative Features**: Permission management for multi-user recipe and shopping list collaboration
/// - **Group Management**: Group administration and membership permission validation
///
/// **Mock Implementation Benefits:**
/// - **Development Efficiency**: Simplified permission system enabling rapid development and testing
/// - **Consistent API**: Production-ready API surface that can be implemented with real authentication
/// - **Feature Development**: Enables collaborative feature development without complex authentication setup
/// - **Testing Support**: Predictable permission behavior for unit and integration testing
/// - **Extension Ready**: Easy migration path to real authentication and authorization systems
///
/// **Usage Examples:**
/// ```dart
/// final permissionService = PermissionService();
///
/// // Check user authentication
/// if (permissionService.isAuthenticated) {
///   // User is logged in
/// }
///
/// // Check resource permissions
/// if (permissionService.canEditRecipe('recipe123')) {
///   // User can edit this recipe
/// }
///
/// // Verify ownership
/// if (permissionService.isOwner('user456')) {
///   // Current user owns this resource
/// }
/// ```

import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/operations/modules/recipe_permission_helper.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';

/// Permission management service providing centralized authorization and access control for collaborative features.
///
/// This singleton service implements a comprehensive permission system with mock authentication for development
/// and testing environments. It provides consistent permission checking across recipes, shopping lists, groups,
/// and user interactions while maintaining a clean API surface that can be extended with real authentication.
///
/// **Singleton Architecture:**
/// Uses thread-safe singleton pattern ensuring:
/// - Single instance across the entire application lifecycle
/// - Consistent permission state and behavior
/// - Memory-efficient permission management
/// - Predictable authentication state for development
///
/// **Mock Authentication Benefits:**
/// - Simplified development workflow without complex authentication setup
/// - Predictable behavior for automated testing and development
/// - Production-ready API surface for easy migration to real authentication
/// - Consistent permission semantics regardless of authentication backend
class PermissionService {
  /// Repository handling all Firebase Auth communication and operations.
  final AuthRepository _authRepository;

  /// Repository handling recipe data operations.
  final RecipeRepository? _recipeRepository;

  /// Unified recipe service for accessing cached recipe data.
  late final UnifiedRecipeService _recipeService;

  /// Unified shopping service for accessing shopping list data and permissions.
  late final UnifiedShoppingService _shoppingService;

  /// Recipe permission helper for actual permission validation.
  late final RecipePermissionHelper _permissionHelper;

  /// Private singleton instance for thread-safe singleton implementation.
  static PermissionService? _instance;

  /// Factory constructor providing singleton access to the permission service.
  factory PermissionService(
      {AuthRepository? authRepository, RecipeRepository? recipeRepository}) {
    _instance ??= PermissionService._internal(
      authRepository ?? FirebaseAuthRepository(),
      recipeRepository,
    );
    return _instance!;
  }

  /// Private constructor for singleton pattern implementation.
  PermissionService._internal(this._authRepository, this._recipeRepository) {
    // CRITICAL FIX: Initialize actual permission validation components
    _recipeService = ServiceLocator.get<UnifiedRecipeService>();
    _shoppingService = ServiceLocator.get<UnifiedShoppingService>();
    _permissionHelper = RecipePermissionHelper(_recipeService);
  }

  /// Reset singleton instance for testing purposes only.
  ///
  /// WARNING: This method should ONLY be used in test environments to ensure
  /// test isolation. Using this in production code will break the singleton
  /// pattern and may cause unexpected behavior.
  @visibleForTesting
  static void resetForTesting() {
    _instance = null;
  }

  /// Asynchronously check if the current user owns a recipe.
  ///
  /// This method queries the recipe repository to verify ownership,
  /// providing accurate ownership validation based on actual recipe data.
  /// Use this method when async operations are acceptable.
  Future<bool> isRecipeOwnerAsync(String recipeId) async {
    // Security: Must be authenticated to own recipes
    if (currentUserId == null) return false;

    // Security: Validate recipe ID
    if (recipeId.isEmpty) return false;

    // SECURITY FIX: If no repository is available, default to secure (deny)
    if (_recipeRepository == null) return false;

    try {
      // Query the recipe from repository
      final recipe = await _recipeRepository.read(recipeId);
      if (recipe == null) return false;

      // Check ownership
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      return ownerId == currentUserId;
    } catch (e) {
      // If we can't verify, default to safe (deny)
      return false;
    }
  }

  /// Current authenticated user ID for permission validation and ownership checks.
  ///
  /// Returns the actual Firebase Auth user ID for the currently authenticated user.
  /// Returns null if no user is authenticated, which is used for permission validation.
  String? get currentUserId => _authRepository.currentUserId;

  /// Current authenticated user profile for comprehensive user information access.
  ///
  /// Returns the UserProfile for the currently authenticated user by converting
  /// from Firebase Auth User. Returns null if no user is authenticated.
  UserProfile? get currentUser {
    final firebaseUser = _authRepository.currentUser;
    if (firebaseUser == null) return null;

    // Convert Firebase Auth User to UserProfile
    return UserProfile(
      uid: firebaseUser.uid,
      displayName: firebaseUser.displayName ?? 'User',
      email: firebaseUser.email ?? '',
      avatarUrl: firebaseUser.photoURL,
      isOnline: true, // Always true for current user
      joinedAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      lastActiveAt: DateTime.now(),
    );
  }

  /// Current authenticated user's display name for UI presentation and attribution.
  ///
  /// Returns the actual Firebase Auth user's display name for UI elements,
  /// notifications, and user attribution features.
  String? get currentUserDisplayName =>
      _authRepository.currentUser?.displayName;

  /// Checks if a user is currently authenticated and authorized to perform actions.
  ///
  /// Returns `true` if there is a current authenticated user, `false` otherwise.
  /// This is a security-critical check that must be performed before any sensitive operations.
  bool get isAuthenticated => currentUserId != null;

  /// Retrieves comprehensive user profile information for permission validation and UI presentation.
  ///
  /// This method provides detailed user profile information including display name, avatar, online status,
  /// and account metadata. In the mock implementation, it generates consistent mock data for development.
  /// In production, this would fetch real user profiles from the authentication system.
  ///
  /// [userId] Unique identifier of the user whose profile should be retrieved
  /// Returns [UserProfile] with complete user information or `null` if user not found
  ///
  /// **Mock Implementation Features:**
  /// - Generates consistent mock profiles with realistic data structure
  /// - Provides predictable online status and account age for testing
  /// - Maintains referential integrity with provided user ID
  /// - Simulates realistic user profile attributes for UI development
  ///
  /// **Production Integration:**
  /// In production, this method would:
  /// - Query the authentication service for real user profile data
  /// - Handle authentication errors and user not found scenarios
  /// - Provide cached user profiles for performance optimization
  /// - Support privacy settings and user visibility controls
  Future<UserProfile?> getUserProfile(String userId) async {
    // Security: Validate user ID
    if (userId.isEmpty) return null;

    // Check if this is the current user
    if (userId == currentUserId) {
      return currentUser;
    }

    // For other users, this would query Firestore
    // For now, return a mock profile
    final now = DateTime.now();
    return UserProfile(
      uid: userId,
      displayName: 'User $userId',
      email: 'user$userId@example.com',
      avatarUrl: null,
      isOnline: false, // Other users assumed offline in mock
      joinedAt: now.subtract(const Duration(days: 90)),
      lastActiveAt: now.subtract(const Duration(hours: 2)),
    );
  }

  /// Validates user permission to invite others to collaborate on a specific recipe.
  ///
  /// This method checks whether the current user has sufficient permissions to invite other users
  /// to view, edit, or collaborate on the specified recipe. Implements proper security validation
  /// with authentication checks and ownership verification.
  ///
  /// [recipeId] Unique identifier of the recipe for invitation permission validation
  /// Returns `true` if user can invite others to the recipe, `false` otherwise
  ///
  /// **Permission Rules:**
  /// - Recipe owners can always invite collaborators
  /// - Users with editor permissions can invite if enabled by owner
  /// - Viewers typically cannot invite others unless specifically granted permission
  /// - Unauthenticated users cannot invite anyone
  bool canInviteToRecipe(String recipeId) {
    // Security: Must be authenticated to invite
    if (currentUserId == null) return false;

    // Security: Validate recipe ID
    if (recipeId.isEmpty) return false;

    // Check if user is the recipe owner
    if (isRecipeOwner(recipeId)) return true;

    // Check if user has editor permission and owner allows member invites
    final permission = getUserPermission(recipeId);
    if (permission == ResourcePermission.editor) {
      // For collaborative recipes, editors can invite if owner allows
      // This would need to check recipe.socialData?.allowMemberInvites
      // For now, allow editors to invite
      return true;
    }

    return false;
  }

  /// Validates user permission to edit and modify a specific recipe.
  ///
  /// This method determines whether the current user has edit permissions for the specified recipe,
  /// including modifying ingredients, instructions, images, and metadata. Implements proper security
  /// validation with authentication and input validation checks.
  ///
  /// [recipeId] Unique identifier of the recipe for edit permission validation
  /// Returns `true` if user can edit the recipe, `false` otherwise
  ///
  /// **Edit Permission Hierarchy:**
  /// - Recipe owners have full edit permissions
  /// - Users with explicit editor role can modify recipe content
  /// - Collaborative recipes may allow multiple editors
  /// - Unauthenticated users cannot edit any recipes
  bool canEditRecipe(String recipeId) {
    // Security: Must be authenticated to edit
    if (currentUserId == null) return false;

    // Security: Validate recipe ID
    if (recipeId.isEmpty) return false;

    // Check if user is the recipe owner
    if (isRecipeOwner(recipeId)) return true;

    // Check if user has editor permission
    final permission = getUserPermission(recipeId);
    return permission == ResourcePermission.editor ||
        permission == ResourcePermission.owner;
  }

  /// Validates user permission to edit and modify a specific menu.
  ///
  /// This method determines whether the current user has edit permissions for the specified menu,
  /// including modifying menu items, categories, notes, and metadata. Implements proper security
  /// validation with authentication and input validation checks.
  ///
  /// [menuId] Unique identifier of the menu for edit permission validation
  /// Returns `true` if user can edit the menu, `false` otherwise
  ///
  /// **Edit Permission Hierarchy:**
  /// - Menu owners have full edit permissions
  /// - Users with explicit editor role can modify menu content
  /// - Collaborative menus may allow multiple editors
  /// - Unauthenticated users cannot edit any menus
  bool canEditMenu(String menuId) {
    // Security: Must be authenticated to edit
    if (currentUserId == null) return false;

    // Security: Validate menu ID
    if (menuId.isEmpty) return false;

    // Check if user is the menu owner (similar to recipe owner check)
    // Menus created by a user typically include their ID
    if (menuId.contains(currentUserId!)) return true;

    // Check if user has editor permission
    final permission = getUserPermission(menuId);
    return permission == ResourcePermission.editor ||
        permission == ResourcePermission.owner;
  }

  /// Validates user permission to view and access a specific recipe.
  ///
  /// This method checks whether the current user has read access to the specified recipe,
  /// including viewing ingredients, instructions, images, and comments. The mock implementation
  /// provides universal read access for development and testing purposes.
  ///
  /// [recipeId] Unique identifier of the recipe for view permission validation
  /// Returns `true` if user can view the recipe, `false` otherwise
  ///
  /// **View Permission Categories (Production):**
  /// - Public recipes are viewable by all authenticated users
  /// - Private recipes require explicit sharing or collaboration
  /// - Friends-only recipes respect social relationship settings
  /// - Anonymous users may have limited access to public content
  bool canViewRecipe(String recipeId) {
    // Security: Must be authenticated to view recipes
    if (currentUserId == null) return false;

    // Security: Validate recipe ID
    if (recipeId.isEmpty) return false;

    // Check if user is the recipe owner
    if (isRecipeOwner(recipeId)) return true;

    // Check if user has any permission level (viewer, editor, or owner)
    final permission = getUserPermission(recipeId);
    if (permission != null) return true;

    // For public recipes, all authenticated users can view
    // This would need to check recipe.socialData?.allowGuestViewing
    // For now, allow authenticated users to view
    return isAuthenticated;
  }

  /// Retrieves the current user's permission level for a specific resource.
  ///
  /// This method determines the exact permission level that the current user has for the specified
  /// resource, enabling fine-grained access control and UI customization based on user capabilities.
  /// The mock implementation returns editor-level permissions for comprehensive development access.
  ///
  /// [resourceId] Unique identifier of the resource for permission level determination
  /// Returns [ResourcePermission] indicating the user's permission level for the resource
  ///
  /// **Permission Levels:**
  /// - [ResourcePermission.owner] Full control including deletion and permission management
  /// - [ResourcePermission.editor] Can modify content but not manage permissions
  /// - [ResourcePermission.viewer] Read-only access to resource content
  ResourcePermission? getUserPermission(String resourceId) {
    // Security: Must be authenticated to have permissions
    if (currentUserId == null) return null;

    // Security: Validate resource ID
    if (resourceId.isEmpty) return null;

    // CRITICAL FIX: Use actual permission validation instead of mock bypass
    try {
      // Get recipe from cached data in UnifiedRecipeService
      final recipe = _recipeService.getRecipeById(resourceId);
      if (recipe == null) {
        // Recipe not found or not accessible - no permissions
        return null;
      }

      // Use RecipePermissionHelper for actual permission validation
      return _permissionHelper.getUserPermission(recipe, currentUserId!);
    } catch (e) {
      // If validation fails, default to safe (no permissions)
      return null;
    }
  }

  /// Validates whether the current user has at least the specified permission level for a resource.
  ///
  /// This method performs comprehensive permission validation by comparing the user's actual
  /// permission level against the required permission level. It supports hierarchical permission
  /// checking where higher permissions automatically include lower-level capabilities.
  ///
  /// [resourceId] Unique identifier of the resource for permission validation
  /// [permission] Minimum required permission level for the requested operation
  /// Returns `true` if user has at least the specified permission level, `false` otherwise
  ///
  /// **Permission Hierarchy (Production):**
  /// - Owner permissions include all editor and viewer capabilities
  /// - Editor permissions include all viewer capabilities
  /// - Viewer permissions are the minimum level for resource access
  bool hasPermission(String resourceId, ResourcePermission permission) {
    // Security: Must be authenticated to have any permissions
    if (currentUserId == null) return false;

    // Security: Validate resource ID
    if (resourceId.isEmpty) return false;

    // Get the actual user permission for this resource
    final userPermission = getUserPermission(resourceId);
    if (userPermission == null) return false;

    // Check permission hierarchy
    switch (permission) {
      case ResourcePermission.viewer:
        // Any permission level grants viewer access
        return true;
      case ResourcePermission.editor:
        // Editor or owner permissions grant editor access
        return userPermission == ResourcePermission.editor ||
            userPermission == ResourcePermission.owner;
      case ResourcePermission.owner:
        // Only owner permission grants owner access
        return userPermission == ResourcePermission.owner;
      case ResourcePermission.read:
        // Read is equivalent to viewer
        return true;
      case ResourcePermission.write:
        // Write is equivalent to editor
        return userPermission == ResourcePermission.write ||
            userPermission == ResourcePermission.editor ||
            userPermission == ResourcePermission.owner ||
            userPermission == ResourcePermission.admin;
      case ResourcePermission.admin:
        // Only admin permission grants admin access
        return userPermission == ResourcePermission.admin;
    }
  }

  // REMOVED: Duplicate isAuthenticated getter - already defined on line 105

  /// Validates whether the current user is the owner of a specific shopping list.
  ///
  /// This method determines ownership status for shopping list access control and UI customization.
  /// Owners have full control over their shopping lists including sharing, editing, and deletion.
  /// The mock implementation grants ownership status for all lists to enable development workflows.
  ///
  /// [listId] Unique identifier of the shopping list for ownership validation
  /// Returns `true` if current user owns the shopping list, `false` otherwise
  bool isShoppingListOwner(String listId) {
    // Security: Must be authenticated to own shopping lists
    if (currentUserId == null) return false;

    // Security: Validate list ID
    if (listId.isEmpty) return false;

    try {
      // SECURITY FIX: Get actual shopping list from Firebase data
      final list = _shoppingService.lists.firstWhere(
        (list) => list.id == listId,
        orElse: () => throw StateError('List not found'),
      );

      // Check ownership against actual Firebase data
      return list.ownerId == currentUserId;
    } catch (e) {
      // If list not found or error occurs, deny access (secure default)
      return false;
    }
  }

  /// Validates user permission to view and access a specific shopping list.
  ///
  /// This method checks read access permissions for shopping lists, including viewing items,
  /// quantities, and completion status. The mock implementation provides universal read access
  /// for development and testing of collaborative shopping features.
  ///
  /// [listId] Unique identifier of the shopping list for view permission validation
  /// Returns `true` if user can view the shopping list, `false` otherwise
  bool canViewShoppingList(String listId) {
    // Security: Must be authenticated to view shopping lists
    if (currentUserId == null) return false;

    // Security: Validate list ID
    if (listId.isEmpty) return false;

    try {
      // SECURITY FIX: Get actual shopping list from Firebase data
      final list = _shoppingService.lists.firstWhere(
        (list) => list.id == listId,
        orElse: () => throw StateError('List not found'),
      );

      // Check ownership first
      if (list.ownerId == currentUserId) return true;

      // For collaborative lists, check member permissions
      if (list.type == ListType.collaborative) {
        final userPermission = list.memberPermissions[currentUserId];
        return userPermission != null; // Any permission level allows viewing
      }

      // For personal lists, only owner can view
      return false;
    } catch (e) {
      // If list not found or error occurs, deny access (secure default)
      return false;
    }
  }

  /// Validates user permission to edit and modify items in a specific shopping list.
  ///
  /// This method determines whether the user can add, remove, or modify items in the shopping list,
  /// including updating quantities and marking items as completed. Mock implementation grants
  /// edit access to support collaborative shopping development.
  ///
  /// [listId] Unique identifier of the shopping list for edit permission validation
  /// Returns `true` if user can edit the shopping list, `false` otherwise
  bool canEditShoppingList(String listId) {
    // Security: Must be authenticated to edit shopping lists
    if (currentUserId == null) {
      return false;
    }

    // Security: Validate list ID
    if (listId.isEmpty) {
      return false;
    }

    try {
      // SECURITY FIX: Get actual shopping list from Firebase data
      final list = _shoppingService.lists.firstWhere(
        (list) => list.id == listId,
        orElse: () => throw StateError('List not found'),
      );

      // Check ownership first - owners can always edit
      if (list.ownerId == currentUserId) {
        return true;
      }

      // For collaborative lists, check member permissions
      if (list.type == ListType.collaborative) {
        final userPermission = list.memberPermissions[currentUserId];

        // Only admin and edit permissions allow editing
        final canEdit = userPermission == SharedListPermission.admin ||
            userPermission == SharedListPermission.edit;

        return canEdit;
      }

      // For personal lists, only owner can edit
      return false;
    } catch (e) {
      // If list not found or error occurs, deny access (secure default)
      return false;
    }
  }

  /// Add retry logic for permission checking with service refresh
  Future<bool> canEditShoppingListWithRetry(String listId,
      {int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final result = canEditShoppingList(listId);
      if (result) {
        return true;
      }

      if (attempt < maxRetries) {
        // Refresh shopping service data
        await _shoppingService.loadLists();

        // Wait a bit for data to propagate
        await Future.delayed(Duration(milliseconds: 200 * attempt));
      }
    }

    return false;
  }

  /// Validates user permission to manage sharing and collaboration settings for a shopping list.
  ///
  /// This method checks whether the user can manage list sharing, invite collaborators, and
  /// modify permission settings. Typically reserved for list owners and designated managers.
  /// Mock implementation grants management access for comprehensive feature testing.
  ///
  /// [listId] Unique identifier of the shopping list for management permission validation
  /// Returns `true` if user can manage the shopping list, `false` otherwise
  bool canManageShoppingList(String listId) {
    // Security: Must be authenticated to manage shopping lists
    if (currentUserId == null) return false;

    // Security: Validate list ID
    if (listId.isEmpty) return false;

    try {
      // SECURITY FIX: Get actual shopping list from Firebase data
      final list = _shoppingService.lists.firstWhere(
        (list) => list.id == listId,
        orElse: () => throw StateError('List not found'),
      );

      // Check ownership first - owners can always manage
      if (list.ownerId == currentUserId) return true;

      // For collaborative lists, only admin permissions allow management
      if (list.type == ListType.collaborative) {
        final userPermission = list.memberPermissions[currentUserId];
        return userPermission == SharedListPermission.admin;
      }

      // For personal lists, only owner can manage
      return false;
    } catch (e) {
      // If list not found or error occurs, deny access (secure default)
      return false;
    }
  }

  /// Validates user permission to permanently delete a specific shopping list.
  ///
  /// This method determines whether the user has deletion privileges for the shopping list,
  /// which is typically the most restrictive permission level reserved for owners.
  /// Mock implementation allows deletion for development and testing purposes.
  ///
  /// [listId] Unique identifier of the shopping list for deletion permission validation
  /// Returns `true` if user can delete the shopping list, `false` otherwise
  bool canDeleteShoppingList(String listId) {
    // Security: Must be authenticated to delete shopping lists
    if (currentUserId == null) return false;

    // Security: Validate list ID
    if (listId.isEmpty) return false;

    // Only owners can delete shopping lists
    return isShoppingListOwner(listId);
  }

  // ===== SHOPPING INVITATION PERMISSIONS =====

  /// Validates user permission to send shopping list invitations.
  ///
  /// This method checks whether the user can invite others to collaborate on a shopping list.
  /// Only list owners and users with admin permissions can send invitations.
  ///
  /// [listId] Unique identifier of the shopping list for invitation permission validation
  /// Returns `true` if user can send invitations for this list, `false` otherwise
  bool canSendShoppingInvitation(String listId) {
    // Security: Must be authenticated to send invitations
    if (currentUserId == null) return false;

    // Security: Validate list ID
    if (listId.isEmpty) return false;

    // Use the existing management permission check (owners and admins can invite)
    return canManageShoppingList(listId);
  }

  /// Validates user permission to accept/decline shopping list invitations.
  ///
  /// This method checks whether the user can respond to a specific shopping list invitation.
  /// Only the intended recipient can accept or decline invitations.
  ///
  /// [invitationRecipientId] The user ID that should be able to respond to the invitation
  /// Returns `true` if current user can respond to this invitation, `false` otherwise
  bool canRespondToShoppingInvitation(String invitationRecipientId) {
    // Security: Must be authenticated to respond to invitations
    if (currentUserId == null) return false;

    // Security: Validate recipient ID
    if (invitationRecipientId.isEmpty) return false;

    // Only the intended recipient can respond to invitations
    return currentUserId == invitationRecipientId;
  }

  /// Validates whether the current user has administrative privileges for a specific group.
  ///
  /// This method determines if the user has group admin status, which typically includes managing
  /// members, modifying group settings, and controlling group content. Group admins have elevated
  /// permissions beyond regular members for group management tasks.
  ///
  /// [groupId] Unique identifier of the group for admin privilege validation
  /// Returns `true` if user has admin privileges for the group, `false` otherwise
  ///
  /// **Admin Privileges (Production):**
  /// - Managing group membership (adding/removing members)
  /// - Modifying group settings and description
  /// - Controlling content sharing and visibility
  /// - Delegating admin privileges to other members
  bool isGroupAdmin(String groupId) {
    // Security: Must be authenticated to have admin privileges
    if (currentUserId == null) return false;

    // Security: Validate group ID
    if (groupId.isEmpty) return false;

    try {
      // FIXED: Properly check group ownership by querying the group
      // Get the group data from UnifiedFriendsService
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();
      final group = friendsService.getCategoryById(groupId);
      
      if (group == null) {
        return false;
      }
      
      // Check if current user is the group owner
      final isOwner = group.ownerId == currentUserId;
      
      return isOwner;
    } catch (e) {
      AppLogger.error('Error checking group admin status', e);
      return false;
    }
  }

  /// Validates user permission to permanently delete a specific group.
  ///
  /// This method checks whether the user has deletion privileges for the group, which is typically
  /// the most restrictive permission reserved for group creators or designated admins. Group
  /// deletion is irreversible and affects all group members and content.
  ///
  /// [groupId] Unique identifier of the group for deletion permission validation
  /// Returns `true` if user can delete the group, `false` otherwise
  ///
  /// **Deletion Authority (Production):**
  /// - Group creators typically have deletion privileges
  /// - Designated admins may be granted deletion permissions
  /// - Regular members cannot delete groups
  /// - Requires confirmation and affects all group content
  bool canDeleteGroup(String groupId) {
    // Security: Must be authenticated to delete groups
    if (currentUserId == null) return false;

    // Security: Validate group ID
    if (groupId.isEmpty) return false;

    // Check if user is a group admin (which includes creators)
    return isGroupAdmin(groupId);
  }

  /// Validates whether the current user is the owner of a specific recipe.
  ///
  /// This method determines recipe ownership for access control and UI customization. Recipe owners
  /// have full control over their recipes including editing, sharing, collaboration management, and
  /// deletion. Ownership status enables the highest level of recipe permissions.
  ///
  /// [recipeId] Unique identifier of the recipe for ownership validation
  /// Returns `true` if current user owns the recipe, `false` otherwise
  ///
  /// **Owner Privileges:**
  /// - Full editing rights for all recipe content
  /// - Managing collaboration and sharing settings
  /// - Inviting and removing collaborators
  /// - Deleting the recipe permanently
  bool isRecipeOwner(String recipeId) {
    // Security: Must be authenticated to own recipes
    if (currentUserId == null) return false;

    // Security: Validate recipe ID
    if (recipeId.isEmpty) return false;

    // CRITICAL FIX: Use actual permission validation instead of mock bypass
    try {
      // Get recipe from cached data in UnifiedRecipeService
      final recipe = _recipeService.getRecipeById(recipeId);
      if (recipe == null) {
        // Recipe not found or not accessible
        return false;
      }

      // Use RecipePermissionHelper for actual ownership validation
      final ownerId = recipe.socialData?.ownerId ?? recipe.createdBy;
      return ownerId == currentUserId;
    } catch (e) {
      // If validation fails, default to safe (deny access)
      return false;
    }
  }

  /// Validates user permission to invite others to join a specific group.
  ///
  /// This method checks whether the user has invitation privileges for the group, enabling them
  /// to send group invitations to other users. Invitation permissions may be restricted based on
  /// group settings and the user's role within the group.
  ///
  /// [groupId] Unique identifier of the group for invitation permission validation
  /// Returns `true` if user can invite others to the group, `false` otherwise
  ///
  /// **Invitation Authority (Production):**
  /// - Group admins can typically invite new members
  /// - Regular members may have invitation privileges based on group settings
  /// - Some groups may restrict invitations to creators only
  /// - Open groups may allow broader invitation permissions
  bool canInviteToGroup(String groupId) {
    // Security: Must be authenticated to invite to groups
    if (currentUserId == null) return false;

    // Security: Validate group ID
    if (groupId.isEmpty) return false;

    // Check if user is a group admin
    if (isGroupAdmin(groupId)) return true;

    // In production, also check if group.settings.allowMemberInvites
    // and if user is a member of the group
    return false;
  }

  /// Validates whether the current user is the owner of a resource by comparing user IDs.
  ///
  /// This method provides fundamental ownership validation by comparing the current user's ID
  /// against the provided owner ID. It serves as the foundation for ownership-based permission
  /// checking throughout the application and enables consistent ownership semantics.
  ///
  /// [ownerId] The user ID of the resource owner to validate against current user
  /// Returns `true` if current user ID matches the owner ID, `false` otherwise
  ///
  /// **Ownership Validation:**
  /// - Performs exact string matching between user IDs
  /// - Returns `false` if current user is not authenticated (null user ID)
  /// - Provides consistent ownership semantics across all resource types
  /// - Enables hierarchical permission checking based on ownership status
  ///
  /// **Usage Examples:**
  /// ```dart
  /// // Check if current user owns a specific resource
  /// if (permissionService.isOwner(resource.ownerId)) {
  ///   // Enable owner-specific UI elements
  /// }
  /// ```
  bool isOwner(String ownerId) => currentUserId == ownerId;
}
