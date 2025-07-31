/// Permission mixins providing reusable authorization patterns for ViewModels and services.
///
/// This file contains a comprehensive set of permission mixins that eliminate duplicate
/// permission checking code across 20+ ViewModels and services by providing clean,
/// focused permission checking methods through a facade pattern.
///
/// Architecture overview:
/// The permission system is organized into focused modules, each handling specific
/// permission domains:
/// - [BasePermissionMixin] - Core authentication and user context
/// - [RecipePermissionMixin] - Recipe-specific authorization rules
/// - [ShoppingPermissionMixin] - Shopping list permission management
/// - [GroupPermissionMixin] - Group membership and role-based permissions
/// - [SocialPermissionMixin] - Social features and profile permissions
///
/// Each mixin acts as a clean facade that delegates to specialized permission
/// handlers, maintaining single responsibility while providing convenient access
/// to permission checking functionality.
///
/// Usage pattern:
/// ```dart
/// class RecipeViewModel extends ChangeNotifier
///     with BasePermissionMixin, RecipePermissionMixin {
///   
///   Future<void> deleteRecipe(String recipeId) async {
///     if (!canDeleteRecipe(recipeId)) {
///       showError('You don\'t have permission to delete this recipe');
///       return;
///     }
///     // Proceed with deletion
///   }
/// }
/// ```

// Import focused modules
import 'package:butlery/core/permissions/modules/base_permission_manager.dart';
import 'package:butlery/core/permissions/modules/recipe_permission_handler.dart';
import 'package:butlery/core/permissions/modules/shopping_permission_handler.dart';
import 'package:butlery/core/permissions/modules/group_permission_handler.dart';
import 'package:butlery/core/permissions/modules/social_permission_handler.dart';
import 'package:butlery/core/permissions/modules/permission_action_builder.dart';
import 'package:butlery/core/permissions/modules/permission_debug_tools.dart';

/// Base mixin providing core authentication and user context functionality.
///
/// This mixin serves as the foundation for all permission checking by providing
/// access to the current user's authentication state and basic user information.
/// All other permission mixins should extend this mixin to ensure consistent
/// access to user context.
///
/// Delegates to [BasePermissionManager] for actual implementation, maintaining
/// clean separation of concerns and enabling easy testing through dependency
/// injection.
///
/// Key capabilities:
/// - Current user ID access
/// - Authentication state checking
/// - User display name retrieval
/// - Session validation
mixin BasePermissionMixin {
  
  // ===== BASE PERMISSION DELEGATION =====

  /// The unique identifier of the currently authenticated user.
  ///
  /// Returns null if no user is currently authenticated. This is the primary
  /// identifier used throughout the app for permission checking and data access.
  String? get currentUserId => BasePermissionManager.currentUserId;
  
  /// Whether a user is currently authenticated with valid credentials.
  ///
  /// Returns true if the user has successfully logged in and their session
  /// is still valid. Use this for determining whether to show authenticated
  /// or guest content.
  bool get isAuthenticated => BasePermissionManager.isAuthenticated;
  
  /// Whether a user is currently logged in (alias for isAuthenticated).
  ///
  /// Provided for semantic clarity in contexts where "logged in" is more
  /// natural than "authenticated".
  bool get isLoggedIn => BasePermissionManager.isLoggedIn;
  
  /// The display name of the currently authenticated user.
  ///
  /// Returns null if no user is authenticated or if the user hasn't set
  /// a display name. Used for showing user-friendly names in the UI.
  String? get currentUserDisplayName => BasePermissionManager.currentUserDisplayName;
}

/// Mixin providing recipe-specific permission checking functionality.
///
/// This mixin contains all recipe-related authorization rules, including
/// view, edit, delete, and sharing permissions. It delegates to the
/// [RecipePermissionHandler] for actual permission validation while
/// providing a clean interface for ViewModels and services.
///
/// Permission levels supported:
/// - View: Can see recipe details and content
/// - Edit: Can modify recipe information
/// - Delete: Can permanently remove recipes
/// - Share: Can share recipes with other users
/// - Collaborate: Can participate in collaborative editing
///
/// Usage in ViewModels:
/// ```dart
/// class RecipeDetailViewModel with BasePermissionMixin, RecipePermissionMixin {
///   void onEditPressed() {
///     if (!canEditRecipe(recipe.id)) {
///       showPermissionError('You cannot edit this recipe');
///       return;
///     }
///     navigateToEditScreen();
///   }
/// }
/// ```
mixin RecipePermissionMixin on BasePermissionMixin {
  
  // ===== CORE RECIPE PERMISSIONS =====
  
  /// Checks if the current user can view the specified recipe.
  ///
  /// [recipeId] The unique identifier of the recipe to check
  ///
  /// Returns true if the user has permission to view this recipe.
  /// This includes recipes they own, recipes shared with them,
  /// and public recipes.
  bool canViewRecipe(String recipeId) {
    return RecipePermissionHandler.canViewRecipe(recipeId);
  }
  
  /// Checks if the current user can edit the specified recipe.
  ///
  /// [recipeId] The unique identifier of the recipe to check
  ///
  /// Returns true if the user has permission to modify this recipe.
  /// This typically includes recipes they own and recipes where they
  /// have been granted edit permissions by the owner.
  bool canEditRecipe(String recipeId) {
    return RecipePermissionHandler.canEditRecipe(recipeId);
  }
  
  /// Check if user can delete a recipe
  bool canDeleteRecipe(String recipeId) {
    return RecipePermissionHandler.canDeleteRecipe(recipeId);
  }
  
  /// Check if user can share a recipe
  bool canShareRecipe(String recipeId) {
    return RecipePermissionHandler.canShareRecipe(recipeId);
  }
  
  /// Check if user can duplicate a recipe
  bool canDuplicateRecipe(String recipeId) {
    return RecipePermissionHandler.canDuplicateRecipe(recipeId);
  }
  
  /// Check if user is the owner of a recipe
  bool isRecipeOwner(String recipeId) {
    return RecipePermissionHandler.isRecipeOwner(recipeId);
  }
  
  /// Check if user can comment on a recipe
  bool canCommentOnRecipe(String recipeId) {
    return RecipePermissionHandler.canCommentOnRecipe(recipeId);
  }
  
  /// Check if user can rate a recipe
  bool canRateRecipe(String recipeId) {
    return RecipePermissionHandler.canRateRecipe(recipeId);
  }
  
  /// Check if user can add recipe to favorites
  bool canFavoriteRecipe(String recipeId) {
    return RecipePermissionHandler.canFavoriteRecipe(recipeId);
  }
  
  // ===== RECIPE PERMISSION HELPERS =====
  
  /// Get recipe permission level for UI display
  String getRecipePermissionLevel(String recipeId) {
    return PermissionActionBuilder.getRecipePermissionLevel(recipeId);
  }
  
  /// Check if user can perform any action on recipe
  bool hasRecipeAccess(String recipeId) {
    return RecipePermissionHandler.hasRecipeAccess(recipeId);
  }
  
  /// Get recipe actions available to user
  List<String> getAvailableRecipeActions(String recipeId) {
    return PermissionActionBuilder.getAvailableRecipeActions(recipeId);
  }
}

/// Shopping list permission mixin - eliminates shopping list permission duplications  
mixin ShoppingListPermissionMixin on BasePermissionMixin {
  
  // ===== CORE SHOPPING LIST PERMISSIONS =====
  
  /// Check if user can view a shopping list
  bool canViewShoppingList(String listId) {
    return ShoppingPermissionHandler.canViewShoppingList(listId);
  }
  
  /// Check if user can edit a shopping list
  bool canEditShoppingList(String listId) {
    return ShoppingPermissionHandler.canEditShoppingList(listId);
  }
  
  /// Check if user can manage a shopping list
  bool canManageShoppingList(String listId) {
    return ShoppingPermissionHandler.canManageShoppingList(listId);
  }
  
  /// Check if user can delete a shopping list
  bool canDeleteShoppingList(String listId) {
    return ShoppingPermissionHandler.canDeleteShoppingList(listId);
  }
  
  /// Check if user can share a shopping list
  bool canShareShoppingList(String listId) {
    return ShoppingPermissionHandler.canShareShoppingList(listId);
  }
  
  /// Check if user can invite to a shopping list
  bool canInviteToShoppingList(String listId) {
    return ShoppingPermissionHandler.canInviteToShoppingList(listId);
  }
  
  /// Check if user is the owner of a shopping list
  bool isShoppingListOwner(String listId) {
    return ShoppingPermissionHandler.isShoppingListOwner(listId);
  }
  
  /// Check if user can add items to shopping list
  bool canAddItemsToShoppingList(String listId) {
    return ShoppingPermissionHandler.canAddItemsToShoppingList(listId);
  }
  
  /// Check if user can remove items from shopping list
  bool canRemoveItemsFromShoppingList(String listId) {
    return ShoppingPermissionHandler.canRemoveItemsFromShoppingList(listId);
  }
  
  /// Check if user can modify item status in shopping list
  bool canModifyItemStatus(String listId) {
    return ShoppingPermissionHandler.canModifyItemStatus(listId);
  }
  
  // ===== SHOPPING LIST PERMISSION HELPERS =====
  
  /// Get shopping list permission level for UI display
  String getShoppingListPermissionLevel(String listId) {
    return PermissionActionBuilder.getShoppingListPermissionLevel(listId);
  }
  
  /// Check if user can perform any action on shopping list
  bool hasShoppingListAccess(String listId) {
    return ShoppingPermissionHandler.hasShoppingListAccess(listId);
  }
  
  /// Get shopping list actions available to user
  List<String> getAvailableShoppingListActions(String listId) {
    return PermissionActionBuilder.getAvailableShoppingListActions(listId);
  }
}

/// Group permission mixin - eliminates group permission duplications
mixin GroupPermissionMixin on BasePermissionMixin {
  
  // ===== CORE GROUP PERMISSIONS =====
  
  /// Check if user can view a group
  bool canViewGroup(String groupId) {
    return GroupPermissionHandler.canViewGroup(groupId);
  }
  
  /// Check if user can edit a group
  bool canEditGroup(String groupId) {
    return GroupPermissionHandler.canEditGroup(groupId);
  }
  
  /// Check if user can manage a group
  bool canManageGroup(String groupId) {
    return GroupPermissionHandler.canManageGroup(groupId);
  }
  
  /// Check if user can delete a group
  bool canDeleteGroup(String groupId) {
    return GroupPermissionHandler.canDeleteGroup(groupId);
  }
  
  /// Check if user can invite to a group
  bool canInviteToGroup(String groupId) {
    return GroupPermissionHandler.canInviteToGroup(groupId);
  }
  
  /// Check if user can remove from a group
  bool canRemoveFromGroup(String groupId, String userId) {
    return GroupPermissionHandler.canRemoveFromGroup(groupId, userId);
  }
  
  /// Check if user is group admin
  bool isGroupAdmin(String groupId) {
    return GroupPermissionHandler.isGroupAdmin(groupId);
  }
  
  /// Check if user is group owner
  bool isGroupOwner(String groupId) {
    return GroupPermissionHandler.isGroupOwner(groupId);
  }
  
  /// Check if user is group member
  bool isGroupMember(String groupId) {
    return GroupPermissionHandler.isGroupMember(groupId);
  }
  
  /// Check if user can leave group
  bool canLeaveGroup(String groupId) {
    return GroupPermissionHandler.canLeaveGroup(groupId);
  }
  
  /// Check if user can change group settings
  bool canChangeGroupSettings(String groupId) {
    return GroupPermissionHandler.canChangeGroupSettings(groupId);
  }
  
  // ===== GROUP PERMISSION HELPERS =====
  
  /// Get group permission level for UI display
  String getGroupPermissionLevel(String groupId) {
    return PermissionActionBuilder.getGroupPermissionLevel(groupId);
  }
  
  /// Check if user can perform any action on group
  bool hasGroupAccess(String groupId) {
    return GroupPermissionHandler.hasGroupAccess(groupId);
  }
  
  /// Get group actions available to user
  List<String> getAvailableGroupActions(String groupId) {
    return PermissionActionBuilder.getAvailableGroupActions(groupId);
  }
}

/// Social permission mixin - eliminates social permission duplications
mixin SocialPermissionMixin on BasePermissionMixin {
  
  // ===== CORE SOCIAL PERMISSIONS =====
  
  /// Check if user can view a profile
  bool canViewProfile(String userId) {
    return SocialPermissionHandler.canViewProfile(userId);
  }
  
  /// Check if user can edit a profile
  bool canEditProfile(String userId) {
    return SocialPermissionHandler.canEditProfile(userId);
  }
  
  /// Check if user can send friend request
  bool canSendFriendRequest(String userId) {
    return SocialPermissionHandler.canSendFriendRequest(userId);
  }
  
  /// Check if user can accept friend request
  bool canAcceptFriendRequest(String requestId) {
    return SocialPermissionHandler.canAcceptFriendRequest(requestId);
  }
  
  /// Check if user can reject friend request
  bool canRejectFriendRequest(String requestId) {
    return SocialPermissionHandler.canRejectFriendRequest(requestId);
  }
  
  /// Check if user can cancel friend request
  bool canCancelFriendRequest(String requestId) {
    return SocialPermissionHandler.canCancelFriendRequest(requestId);
  }
  
  /// Check if user can remove friend
  bool canRemoveFriend(String userId) {
    return SocialPermissionHandler.canRemoveFriend(userId);
  }
  
  /// Check if user can block another user
  bool canBlockUser(String userId) {
    return SocialPermissionHandler.canBlockUser(userId);
  }
  
  /// Check if user can unblock another user
  bool canUnblockUser(String userId) {
    return SocialPermissionHandler.canUnblockUser(userId);
  }
  
  /// Check if user can message another user
  bool canMessageUser(String userId) {
    return SocialPermissionHandler.canMessageUser(userId);
  }
  
  /// Check if user is own profile
  bool isOwnProfile(String userId) {
    return SocialPermissionHandler.isOwnProfile(userId);
  }
  
  /// Check if users are friends
  bool areFriends(String userId) {
    return SocialPermissionHandler.areFriends(userId);
  }
  
  // ===== SOCIAL PERMISSION HELPERS =====
  
  /// Get social permission level for UI display
  String getSocialPermissionLevel(String userId) {
    return PermissionActionBuilder.getSocialPermissionLevel(userId);
  }
  
  /// Get social actions available to user
  List<String> getAvailableSocialActions(String userId) {
    return PermissionActionBuilder.getAvailableSocialActions(userId);
  }
}

/// Combined permission mixin - for ViewModels that need multiple permission types
mixin CombinedPermissionMixin on BasePermissionMixin
    implements RecipePermissionMixin, ShoppingListPermissionMixin, GroupPermissionMixin, SocialPermissionMixin {
  
  // ===== RECIPE PERMISSIONS IMPLEMENTATION =====
  
  @override
  bool canViewRecipe(String recipeId) => RecipePermissionHandler.canViewRecipe(recipeId);
  @override
  bool canEditRecipe(String recipeId) => RecipePermissionHandler.canEditRecipe(recipeId);
  @override
  bool canDeleteRecipe(String recipeId) => RecipePermissionHandler.canDeleteRecipe(recipeId);
  @override
  bool canShareRecipe(String recipeId) => RecipePermissionHandler.canShareRecipe(recipeId);
  @override
  bool canDuplicateRecipe(String recipeId) => RecipePermissionHandler.canDuplicateRecipe(recipeId);
  @override
  bool isRecipeOwner(String recipeId) => RecipePermissionHandler.isRecipeOwner(recipeId);
  @override
  bool canCommentOnRecipe(String recipeId) => RecipePermissionHandler.canCommentOnRecipe(recipeId);
  @override
  bool canRateRecipe(String recipeId) => RecipePermissionHandler.canRateRecipe(recipeId);
  @override
  bool canFavoriteRecipe(String recipeId) => RecipePermissionHandler.canFavoriteRecipe(recipeId);
  @override
  String getRecipePermissionLevel(String recipeId) => PermissionActionBuilder.getRecipePermissionLevel(recipeId);
  @override
  bool hasRecipeAccess(String recipeId) => RecipePermissionHandler.hasRecipeAccess(recipeId);
  @override
  List<String> getAvailableRecipeActions(String recipeId) => PermissionActionBuilder.getAvailableRecipeActions(recipeId);
  
  // ===== SHOPPING LIST PERMISSIONS IMPLEMENTATION =====
  
  @override
  bool canViewShoppingList(String listId) => ShoppingPermissionHandler.canViewShoppingList(listId);
  @override
  bool canEditShoppingList(String listId) => ShoppingPermissionHandler.canEditShoppingList(listId);
  @override
  bool canManageShoppingList(String listId) => ShoppingPermissionHandler.canManageShoppingList(listId);
  @override
  bool canDeleteShoppingList(String listId) => ShoppingPermissionHandler.canDeleteShoppingList(listId);
  @override
  bool canShareShoppingList(String listId) => ShoppingPermissionHandler.canShareShoppingList(listId);
  @override
  bool canInviteToShoppingList(String listId) => ShoppingPermissionHandler.canInviteToShoppingList(listId);
  @override
  bool isShoppingListOwner(String listId) => ShoppingPermissionHandler.isShoppingListOwner(listId);
  @override
  bool canAddItemsToShoppingList(String listId) => ShoppingPermissionHandler.canAddItemsToShoppingList(listId);
  @override
  bool canRemoveItemsFromShoppingList(String listId) => ShoppingPermissionHandler.canRemoveItemsFromShoppingList(listId);
  @override
  bool canModifyItemStatus(String listId) => ShoppingPermissionHandler.canModifyItemStatus(listId);
  @override
  String getShoppingListPermissionLevel(String listId) => PermissionActionBuilder.getShoppingListPermissionLevel(listId);
  @override
  bool hasShoppingListAccess(String listId) => ShoppingPermissionHandler.hasShoppingListAccess(listId);
  @override
  List<String> getAvailableShoppingListActions(String listId) => PermissionActionBuilder.getAvailableShoppingListActions(listId);
  
  // ===== GROUP PERMISSIONS IMPLEMENTATION =====
  
  @override
  bool canViewGroup(String groupId) => GroupPermissionHandler.canViewGroup(groupId);
  @override
  bool canEditGroup(String groupId) => GroupPermissionHandler.canEditGroup(groupId);
  @override
  bool canManageGroup(String groupId) => GroupPermissionHandler.canManageGroup(groupId);
  @override
  bool canDeleteGroup(String groupId) => GroupPermissionHandler.canDeleteGroup(groupId);
  @override
  bool canInviteToGroup(String groupId) => GroupPermissionHandler.canInviteToGroup(groupId);
  @override
  bool canRemoveFromGroup(String groupId, String userId) => GroupPermissionHandler.canRemoveFromGroup(groupId, userId);
  @override
  bool isGroupAdmin(String groupId) => GroupPermissionHandler.isGroupAdmin(groupId);
  @override
  bool isGroupOwner(String groupId) => GroupPermissionHandler.isGroupOwner(groupId);
  @override
  bool isGroupMember(String groupId) => GroupPermissionHandler.isGroupMember(groupId);
  @override
  bool canLeaveGroup(String groupId) => GroupPermissionHandler.canLeaveGroup(groupId);
  @override
  bool canChangeGroupSettings(String groupId) => GroupPermissionHandler.canChangeGroupSettings(groupId);
  @override
  String getGroupPermissionLevel(String groupId) => PermissionActionBuilder.getGroupPermissionLevel(groupId);
  @override
  bool hasGroupAccess(String groupId) => GroupPermissionHandler.hasGroupAccess(groupId);
  @override
  List<String> getAvailableGroupActions(String groupId) => PermissionActionBuilder.getAvailableGroupActions(groupId);
  
  // ===== SOCIAL PERMISSIONS IMPLEMENTATION =====
  
  @override
  bool canViewProfile(String userId) => SocialPermissionHandler.canViewProfile(userId);
  @override
  bool canEditProfile(String userId) => SocialPermissionHandler.canEditProfile(userId);
  @override
  bool canSendFriendRequest(String userId) => SocialPermissionHandler.canSendFriendRequest(userId);
  @override
  bool canAcceptFriendRequest(String requestId) => SocialPermissionHandler.canAcceptFriendRequest(requestId);
  @override
  bool canRejectFriendRequest(String requestId) => SocialPermissionHandler.canRejectFriendRequest(requestId);
  @override
  bool canCancelFriendRequest(String requestId) => SocialPermissionHandler.canCancelFriendRequest(requestId);
  @override
  bool canRemoveFriend(String userId) => SocialPermissionHandler.canRemoveFriend(userId);
  @override
  bool canBlockUser(String userId) => SocialPermissionHandler.canBlockUser(userId);
  @override
  bool canUnblockUser(String userId) => SocialPermissionHandler.canUnblockUser(userId);
  @override
  bool canMessageUser(String userId) => SocialPermissionHandler.canMessageUser(userId);
  @override
  bool isOwnProfile(String userId) => SocialPermissionHandler.isOwnProfile(userId);
  @override
  bool areFriends(String userId) => SocialPermissionHandler.areFriends(userId);
  @override
  String getSocialPermissionLevel(String userId) => PermissionActionBuilder.getSocialPermissionLevel(userId);
  @override
  List<String> getAvailableSocialActions(String userId) => PermissionActionBuilder.getAvailableSocialActions(userId);
}

/// Debug permission mixin - for development and testing
mixin DebugPermissionMixin on BasePermissionMixin {
  
  /// Print all permissions for a resource
  void debugPrintPermissions(String resourceType, String resourceId) {
    PermissionDebugTools.debugPrintPermissions(resourceType, resourceId);
  }
  
  /// Test all permission combinations for a resource
  Map<String, bool> testAllPermissions(String resourceType, String resourceId) {
    return PermissionDebugTools.testAllPermissions(resourceType, resourceId);
  }
  
  /// Compare permissions between resources
  void compareResourcePermissions(Map<String, String> resources) {
    PermissionDebugTools.compareResourcePermissions(resources);
  }
  
  /// Debug permission context for all resource types
  void debugPermissionContext({
    String? recipeId,
    String? shoppingListId,
    String? groupId,
    String? userId,
  }) {
    PermissionDebugTools.debugPermissionContext(
      recipeId: recipeId,
      shoppingListId: shoppingListId,
      groupId: groupId,
      userId: userId,
    );
  }
  
  /// Benchmark permission checking performance
  void benchmarkPermissions(String resourceType, List<String> resourceIds) {
    PermissionDebugTools.benchmarkPermissions(resourceType, resourceIds);
  }
  
  /// Debug permission errors
  void debugPermissionError(String operation, String resourceType, String resourceId) {
    PermissionDebugTools.debugPermissionError(operation, resourceType, resourceId);
  }
  
  /// Validate permission consistency across handlers
  List<String> validatePermissionConsistency(String resourceType, String resourceId) {
    return PermissionDebugTools.validatePermissionConsistency(resourceType, resourceId);
  }
}