/// Centralized permission management service for authorization and access control.

import 'package:flutter/foundation.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/user_profile.dart' as models;
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth_repo;
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/operations/modules/recipe_permission_helper.dart';
import 'package:butlery/core/base/base_service.dart';

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

  /// Permission modules
  late final RecipePermissionModule _recipeModule;
  late final ShoppingPermissionModule _shoppingModule;
  late final GroupPermissionModule _groupModule;

  /// Private singleton instance for thread-safe singleton implementation.
  static PermissionService? _instance;

  /// Factory constructor providing singleton access to the permission service.
  factory PermissionService(
      {auth_repo.AuthRepository? authRepository, RecipeRepository? recipeRepository}) {
    _instance ??= PermissionService._internal(
      authRepository ?? FirebaseAuthRepository(),
      recipeRepository,
    );
    return _instance!;
  }

  /// Private constructor for singleton pattern implementation.
  PermissionService._internal(this._authRepository, this._recipeRepository) {
    _initializeModules();
  }

  /// Initialize permission modules with dependency injection
  void _initializeModules() {
    final recipeService = ServiceLocator.get<UnifiedRecipeService>();
    final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
    final permissionHelper = RecipePermissionHelper(recipeService);

    _recipeModule = RecipePermissionModule(
      authRepository: _authRepository,
      recipeRepository: _recipeRepository,
      recipeService: recipeService,
      permissionHelper: permissionHelper,
      getCurrentUserId: () => currentUserId,
    );

    _shoppingModule = ShoppingPermissionModule(
      shoppingService: shoppingService,
      getCurrentUserId: () => currentUserId,
    );

    _groupModule = GroupPermissionModule(
      getCurrentUserId: () => currentUserId,
    );
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
  Future<bool> isRecipeOwnerAsync(String recipeId) async {
    return _recipeModule.isRecipeOwnerAsync(recipeId);
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
  models.UserProfile? get currentUser {
    final firebaseUser = _authRepository.currentUser;
    if (firebaseUser == null) return null;

    // Convert Firebase Auth User to UserProfile
    return models.UserProfile(
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
  Future<models.UserProfile?> getUserProfile(String userId) async {
    // Security: Validate user ID
    if (userId.isEmpty) return null;

    // Check if this is the current user
    if (userId == currentUserId) {
      return currentUser;
    }

    // For other users, this would query Firestore
    // For now, return a mock profile
    final now = DateTime.now();
    return models.UserProfile(
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
  Future<bool> canEditShoppingListWithRetry(String listId,
      {int maxRetries = 3}) async {
    return _shoppingModule.canEditShoppingListWithRetry(listId, maxRetries: maxRetries);
  }

  /// Validates user permission to manage sharing and collaboration settings for a shopping list.
  bool canManageShoppingList(String listId) {
    return _shoppingModule.canManageShoppingList(listId);
  }

  /// Validates user permission to permanently delete a specific shopping list.
  bool canDeleteShoppingList(String listId) {
    return _shoppingModule.canDeleteShoppingList(listId);
  }

  // ===== SHOPPING INVITATION PERMISSIONS =====

  /// Validates user permission to send shopping list invitations.
  bool canSendShoppingInvitation(String listId) {
    return _shoppingModule.canSendShoppingInvitation(listId);
  }

  /// Validates user permission to accept/decline shopping list invitations.
  bool canRespondToShoppingInvitation(String invitationRecipientId) {
    return _shoppingModule.canRespondToShoppingInvitation(invitationRecipientId);
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
