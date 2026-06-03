/// Centralized permission management service for authorization and access control.

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/user_profile.dart' as models;
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart'
    as auth_repo;
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/operations/modules/recipe_permission_helper.dart';
import 'package:butlery/services/user_service.dart' as user_svc;
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

// Permission modules
import 'package:butlery/services/permissions/recipe_permission_module.dart';
import 'package:butlery/services/permissions/shopping_permission_module.dart';
import 'package:butlery/services/permissions/group_permission_module.dart';

/// Singleton permission service with modular domain-specific permission handling.
class PermissionService extends BaseService {
  @override
  String get serviceName => 'PermissionService';

  /// Repository handling all Firebase Auth communication and operations.
  final auth_repo.AuthRepository _authRepository;

  /// Repository handling recipe data operations.
  final RecipeRepository? _recipeRepository;

  /// Permission modules (lazy initialized)
  RecipePermissionModule? _recipeModuleInstance;
  ShoppingPermissionModule? _shoppingModuleInstance;
  GroupPermissionModule? _groupModuleInstance;

  /// Private singleton instance for thread-safe singleton implementation.
  static PermissionService? _instance;

  /// Factory constructor providing singleton access to the permission service.
  factory PermissionService({
    auth_repo.AuthRepository? authRepository,
    RecipeRepository? recipeRepository,
  }) {
    _instance ??= PermissionService._internal(
      authRepository ?? FirebaseAuthRepository(),
      recipeRepository,
    );
    return _instance!;
  }

  /// Private constructor for singleton pattern implementation.
  PermissionService._internal(this._authRepository, this._recipeRepository) {
    // Modules are now lazy initialized on first access
  }

  /// Lazy getter for recipe permission module
  RecipePermissionModule get _recipeModule {
    if (_recipeModuleInstance == null) {
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      final permissionHelper = RecipePermissionHelper(
        getCurrentUserId: () => recipeService.currentUserId,
      );
      _recipeModuleInstance = RecipePermissionModule(
        authRepository: _authRepository,
        recipeRepository: _recipeRepository,
        recipeService: recipeService,
        permissionHelper: permissionHelper,
        getCurrentUserId: () => currentUserId,
      );
    }
    return _recipeModuleInstance!;
  }

  /// Lazy getter for shopping permission module
  ShoppingPermissionModule get _shoppingModule {
    if (_shoppingModuleInstance == null) {
      final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
      _shoppingModuleInstance = ShoppingPermissionModule(
        shoppingService: shoppingService,
        getCurrentUserId: () => currentUserId,
      );
    }
    return _shoppingModuleInstance!;
  }

  /// Lazy getter for group permission module
  GroupPermissionModule get _groupModule {
    _groupModuleInstance ??= GroupPermissionModule(
      getCurrentUserId: () => currentUserId,
    );
    return _groupModuleInstance!;
  }

  /// Reset singleton instance for testing purposes only.
  /// WARNING: This method should ONLY be used in test environments to ensure
  /// test isolation. Using this in production code will break the singleton
  /// pattern and may cause unexpected behavior.
  @visibleForTesting
  static void resetForTesting() {
    _instance?._recipeModuleInstance = null;
    _instance?._shoppingModuleInstance = null;
    _instance?._groupModuleInstance = null;
    _instance = null;
  }

  /// Asynchronously check if the current user owns a recipe.
  Future<bool> isRecipeOwnerAsync(String recipeId) async {
    return _recipeModule.isRecipeOwnerAsync(recipeId);
  }

  /// Current authenticated user ID for permission validation and ownership checks.
  /// Returns the actual Firebase Auth user ID for the currently authenticated user.
  /// Returns null if no user is authenticated, which is used for permission validation.
  String? get currentUserId => _authRepository.currentUserId;

  /// Current authenticated user profile for comprehensive user information access.
  /// Returns the UserProfile for the currently authenticated user by converting
  /// from Firebase Auth User. Returns null if no user is authenticated.
  models.UserProfile? get currentUser {
    final firebaseUser = _authRepository.currentUser;
    if (firebaseUser == null) return null;

    // Convert Firebase Auth User to UserProfile
    return models.UserProfile(
      uid: firebaseUser.uid,
      displayName: firebaseUser.displayName ?? 'User',
      email: firebaseUser.email.orEmpty(),
      avatarUrl: firebaseUser.photoURL,
      isOnline: true, // Always true for current user
      joinedAt: firebaseUser.metadata.creationTime ?? clock.now(),
      lastActiveAt: clock.now(),
    );
  }

  /// Current authenticated user's display name for UI presentation and attribution.
  /// Returns the actual Firebase Auth user's display name for UI elements,
  /// notifications, and user attribution features.
  String? get currentUserDisplayName =>
      _authRepository.currentUser?.displayName;

  /// Checks if a user is currently authenticated and authorized to perform actions.
  /// Returns `true` if there is a current authenticated user, `false` otherwise.
  /// This is a security-critical check that must be performed before any sensitive operations.
  bool get isAuthenticated => currentUserId != null;

  /// Retrieves a user profile. Returns current user from auth state,
  /// or delegates to UserService for other users (cached lookup).
  Future<models.UserProfile?> getUserProfile(String userId) async {
    if (userId.isEmpty) return null;

    // Return current user from auth state (no Firestore read needed)
    if (userId == currentUserId) {
      return currentUser;
    }

    // S7 fix: Delegate to UserService for real profile lookup (cached)
    try {
      return await ServiceLocator.get<user_svc.UserService>()
          .getUserProfile(userId);
    } catch (e) {
      AppLogger.warning(
          'Failed to fetch user profile for ${userId.maskedUserId}: $e');
      return null;
    }
  }

  /// Validates user permission to invite others to collaborate on a specific recipe.
  bool canInviteToRecipe(String recipeId) {
    return _recipeModule.canInviteToRecipe(recipeId);
  }

  /// Validates user permission to edit and modify a specific recipe.
  bool canEditRecipe(String recipeId) {
    return _recipeModule.canEditRecipe(recipeId);
  }

  /// Validates user permission to edit and modify a specific menu.
  bool canEditMenu(String menuId) {
    return _recipeModule.canEditMenu(menuId);
  }

  /// Validates user permission to view and access a specific recipe.
  bool canViewRecipe(String recipeId) {
    return _recipeModule.canViewRecipe(recipeId);
  }

  /// Retrieves the current user's permission level for a specific resource.
  ResourcePermission? getUserPermission(String resourceId) {
    return _recipeModule.getUserPermission(resourceId);
  }

  /// Validates whether the current user has at least the specified permission level for a resource.
  bool hasPermission(String resourceId, ResourcePermission permission) {
    return _recipeModule.hasPermission(resourceId, permission);
  }

  /// Validates whether the current user is the owner of a specific shopping list.
  bool isShoppingListOwner(String listId) {
    return _shoppingModule.isShoppingListOwner(listId);
  }

  /// Validates user permission to view and access a specific shopping list.
  bool canViewShoppingList(String listId) {
    return _shoppingModule.canViewShoppingList(listId);
  }

  /// Validates user permission to edit and modify items in a specific shopping list.
  bool canEditShoppingList(String listId) {
    return _shoppingModule.canEditShoppingList(listId);
  }

  /// Add retry logic for permission checking with service refresh
  Future<bool> canEditShoppingListWithRetry(
    String listId, {
    int maxRetries = 3,
  }) async {
    return _shoppingModule.canEditShoppingListWithRetry(
      listId,
      maxRetries: maxRetries,
    );
  }

  /// Validates user permission to manage sharing and collaboration settings for a shopping list.
  bool canManageShoppingList(String listId) {
    return _shoppingModule.canManageShoppingList(listId);
  }

  /// Validates user permission to permanently delete a specific shopping list.
  bool canDeleteShoppingList(String listId) {
    return _shoppingModule.canDeleteShoppingList(listId);
  }

  /// Validates user permission to send shopping list invitations.
  bool canSendShoppingInvitation(String listId) {
    return _shoppingModule.canSendShoppingInvitation(listId);
  }

  /// Validates user permission to accept/decline shopping list invitations.
  bool canRespondToShoppingInvitation(String invitationRecipientId) {
    return _shoppingModule.canRespondToShoppingInvitation(
      invitationRecipientId,
    );
  }

  /// Validates whether the current user has administrative privileges for a specific group.
  bool isGroupAdmin(String groupId) {
    return _groupModule.isGroupAdmin(groupId);
  }

  /// Validates user permission to permanently delete a specific group.
  bool canDeleteGroup(String groupId) {
    return _groupModule.canDeleteGroup(groupId);
  }

  /// Validates whether the current user is the owner of a specific recipe.
  bool isRecipeOwner(String recipeId) {
    return _recipeModule.isRecipeOwner(recipeId);
  }

  /// Validates user permission to invite others to join a specific group.
  bool canInviteToGroup(String groupId) {
    return _groupModule.canInviteToGroup(groupId);
  }

  /// Validates whether the current user is the owner of a resource by comparing user IDs.
  /// This method provides fundamental ownership validation by comparing the current user's ID
  /// against the provided owner ID. It serves as the foundation for ownership-based permission
  /// checking throughout the application and enables consistent ownership semantics.
  /// [ownerId] The user ID of the resource owner to validate against current user
  /// Returns `true` if current user ID matches the owner ID, `false` otherwise
  /// **Ownership Validation:**
  /// - Performs exact string matching between user IDs
  /// - Returns `false` if current user is not authenticated (null user ID)
  /// - Provides consistent ownership semantics across all resource types
  /// - Enables hierarchical permission checking based on ownership status
  /// **Usage Examples:**
  /// ```dart
  /// // Check if current user owns a specific resource
  /// if (permissionService.isOwner(resource.ownerId)) {
  ///   // Enable owner-specific UI elements
  /// }
  /// ```
  bool isOwner(String ownerId) => currentUserId == ownerId;
}
