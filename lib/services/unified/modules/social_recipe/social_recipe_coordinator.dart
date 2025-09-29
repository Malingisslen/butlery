// lib/services/unified/modules/social_recipe/social_recipe_coordinator.dart

import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/services/user_service.dart' as user_service;
// Temporarily disabled notification imports
// import 'package:butlery/services/notifications/notification_service.dart' as notif;
// import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';
import 'package:butlery/core/providers/application_provider.dart';

// Import the focused services
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_creation_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_membership_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_sharing_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_permission_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_query_service.dart';

/// Social Recipe Coordinator (Facade)
/// 
/// Coordinates all social recipe operations by delegating to focused services.
/// Maintains backward compatibility while providing clean separation of concerns.
/// 
/// This is a facade pattern that:
/// - Provides the same interface as the original SocialRecipeModule
/// - Delegates operations to appropriate focused services
/// - Handles notifications and cross-cutting concerns
/// - Maintains state and error handling
class SocialRecipeCoordinator extends BaseService with UserContextMixin {
  @override
  String get serviceName => 'SocialRecipeCoordinator';

  // Focused services
  late final SocialRecipeCreationService _creationService;
  late final SocialRecipeMembershipService _membershipService;
  late final SocialRecipeSharingService _sharingService;
  late final SocialRecipePermissionService _permissionService;
  late final SocialRecipeQueryService _queryService;

  // Dependencies (passed to focused services)
  final RecipeServiceAdapter _serviceAdapter;
  late final FirebaseSharedRecipeRepository _sharedRecipeRepository;
  final String? Function() _getCurrentUserId;
  
  /// Notification service for social notifications (temporarily disabled)
  // late final notif.NotificationService? _notificationService;

  SocialRecipeCoordinator({
    required JsonCacheHelper cacheHelper,
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required void Function(String) setError,
    required void Function() notifyListeners,
    required Future<Recipe?> Function(String) getRecipe,
    required Future<bool> Function(Recipe) saveRecipe,
    RecipeServiceAdapter? serviceAdapter,
  }) : _serviceAdapter = serviceAdapter ?? SocialRecipeCoordinator._createDefaultServiceAdapter(),
       _getCurrentUserId = getCurrentUserId {
    
    // Set the user ID provider for the mixin
    setUserIdProvider(getCurrentUserId);
    
    // Initialize focused services
    _creationService = SocialRecipeCreationService(
      getCurrentUserId: getCurrentUserId,
      getCurrentUserDisplayName: getCurrentUserDisplayName,
      setError: setError,
      notifyListeners: notifyListeners,
      getRecipe: getRecipe,
      saveRecipe: saveRecipe,
    );

    _membershipService = SocialRecipeMembershipService(
      getCurrentUserId: getCurrentUserId,
      setError: setError,
      notifyListeners: notifyListeners,
      getRecipe: getRecipe,
      saveRecipe: saveRecipe,
    );

    _sharingService = SocialRecipeSharingService(
      getCurrentUserId: getCurrentUserId,
      getCurrentUserDisplayName: getCurrentUserDisplayName,
      setError: setError,
      notifyListeners: notifyListeners,
      getRecipe: getRecipe,
      saveRecipe: saveRecipe,
    );

    _permissionService = SocialRecipePermissionService(
      getRecipe: getRecipe,
    );

    _queryService = SocialRecipeQueryService(
      cacheHelper: cacheHelper,
      getCurrentUserId: getCurrentUserId,
      setError: setError,
      serviceAdapter: _serviceAdapter,
    );

    // Initialize SharedRecipe repository
    _sharedRecipeRepository = FirebaseSharedRecipeRepository();

    // _initializeNotificationService(); // Temporarily disabled
  }

  // ===== CREATION OPERATIONS (Delegate to CreationService) =====

  Future<String?> createCollaborativeRecipe({
    required String title,
    required List<String> ingredients,
    required List<String> instructions,
    List<String>? initialMembers,
    Map<String, ResourcePermission>? initialPermissions,
    String? description,
    int? portions,
    int? cookingTime,
    List<String>? tags,
  }) async {
    return await _creationService.createCollaborativeRecipe(
      title: title,
      ingredients: ingredients,
      instructions: instructions,
      initialMembers: initialMembers,
      initialPermissions: initialPermissions,
      description: description,
      portions: portions,
      cookingTime: cookingTime,
      tags: tags,
    );
  }

  // ===== MEMBERSHIP OPERATIONS (Delegate to MembershipService) =====

  Future<bool> addMemberToRecipe(String recipeId, String userId, ResourcePermission permission) async {
    final result = await _membershipService.addMemberToRecipe(recipeId, userId, permission);
    
    // Send notification after successful addition
    if (result) {
      await sendMemberAdditionNotification(recipeId, userId);
    }
    
    return result;
  }

  Future<bool> removeMemberFromRecipe(String recipeId, String userId) async {
    return await _membershipService.removeMemberFromRecipe(recipeId, userId);
  }

  Future<bool> updateMemberPermission(String recipeId, String userId, ResourcePermission permission) async {
    return await _membershipService.updateMemberPermission(recipeId, userId, permission);
  }

  // ===== SHARING OPERATIONS (Delegate to SharingService) =====

  Future<bool> shareRecipeWithUsers(String recipeId, List<String> userIds, ResourcePermission permission) async {
    final result = await _sharingService.shareRecipeWithUsers(recipeId, userIds, permission);
    
    // Send notifications after successful sharing
    if (result) {
      await sendRecipeSharingNotifications(recipeId, userIds);
    }
    
    return result;
  }

  Future<bool> shareRecipeWithGroups(String recipeId, List<String> groupIds, ResourcePermission permission) async {
    return await _sharingService.shareRecipeWithGroups(recipeId, groupIds, permission);
  }

  Future<bool> unshareRecipe(String recipeId) async {
    return await _sharingService.unshareRecipe(recipeId);
  }

  // ===== PERMISSION OPERATIONS (Delegate to PermissionService) =====

  Future<bool> canEditRecipe(String recipeId, String userId) async {
    return await _permissionService.canEditRecipe(recipeId, userId);
  }

  Future<bool> canManageRecipeMembers(String recipeId, String userId) async {
    return await _permissionService.canManageRecipeMembers(recipeId, userId);
  }

  Future<bool> canViewRecipe(String recipeId, String userId) async {
    return await _permissionService.canViewRecipe(recipeId, userId);
  }

  Future<ResourcePermission?> getUserPermissionForRecipe(String recipeId, String userId) async {
    return await _permissionService.getUserPermissionForRecipe(recipeId, userId);
  }

  // ===== QUERY OPERATIONS (Delegate to QueryService) =====

  Future<List<Recipe>> getCollaborativeRecipesForUser() async {
    return await _queryService.getCollaborativeRecipesForUser();
  }

  Future<List<Recipe>> getRecipesSharedByUser(String userId) async {
    return await _queryService.getRecipesSharedByUser(userId);
  }

  Future<List<Recipe>> getRecipesWithPermission(ResourcePermission permission) async {
    return await _queryService.getRecipesWithPermission(permission);
  }

  Future<Map<String, int>> getCollaborationStats() async {
    return await _queryService.getCollaborationStats();
  }

  Future<List<String>> getMostActiveCollaborators({int limit = 10}) async {
    return await _queryService.getMostActiveCollaborators(limit: limit);
  }

  Future<List<Recipe>> loadCachedCollaborativeRecipes() async {
    return await _queryService.loadCachedCollaborativeRecipes();
  }

  // ===== NOTIFICATION OPERATIONS (Temporarily Simplified) =====

  Future<void> sendCollaborationInvitations(String recipeId, List<String> userIds) async {
    AppLogger.info('📧 Sending collaboration invitations to ${userIds.length} users for recipe $recipeId');
    // Note: Notification system implementation would be integrated here
    // when NotificationService dependency is available in this coordinator
  }

  Future<void> sendMemberAdditionNotification(String recipeId, String addedUserId) async {
    AppLogger.info('📧 Sending member addition notification for recipe $recipeId to user $addedUserId');
    // Note: Notification system implementation would be integrated here
    // when NotificationService dependency is available in this coordinator
  }

  Future<void> sendRecipeSharingNotifications(String recipeId, List<String> sharedWithUserIds) async {
    AppLogger.info('📧 Sending sharing notifications to ${sharedWithUserIds.length} users for recipe $recipeId');
    // Note: Notification system implementation would be integrated here
    // when NotificationService dependency is available in this coordinator
  }

  // ===== INVITATION OPERATIONS (Universal Invitation System) =====

  /// Create recipe invitation using SharedRecipe model for universal invitation system
  Future<String?> createRecipeInvitation({
    required String recipeId,
    required List<String> inviteeUserIds,
    String? message,
    bool allowCollaboration = false,
  }) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.error('Cannot create recipe invitation: No authenticated user');
      return null;
    }

    try {
      AppLogger.info('📨 Creating recipe invitation for recipe $recipeId to ${inviteeUserIds.length} users');

      // Get the recipe to create snapshot
      final recipe = await _serviceAdapter.getRecipeById(recipeId);
      if (recipe == null) {
        AppLogger.error('Recipe not found: $recipeId');
        return null;
      }

      // Get current user's display name
      final userService = ServiceLocator.get<user_service.UserService>();
      final currentUserProfile = userService.currentUserProfile;
      if (currentUserProfile == null) {
        AppLogger.error('Cannot get current user profile for invitation');
        return null;
      }

      // Create SharedRecipe invitation
      final sharedRecipe = SharedRecipe.create(
        originalRecipeId: recipeId,
        sharedByUserId: currentUserId, // Already checked for null above
        sharedByDisplayName: currentUserProfile.displayName,
        sharedToUserIds: inviteeUserIds,
        shareMessage: message,
        allowCollaboration: allowCollaboration,
        recipeSnapshot: recipe,
      );

      // Save invitation to Firebase
      final invitationId = await _sharedRecipeRepository.createSharedRecipe(sharedRecipe);

      AppLogger.success('✅ Recipe invitation created successfully: $invitationId');
      AppLogger.info('📥 Recipients will see invitation in "Delat med mig" view');

      // Send notifications (placeholder for future implementation)
      await sendRecipeInvitationNotifications(recipeId, inviteeUserIds);

      return invitationId;
    } catch (e) {
      AppLogger.error('Failed to create recipe invitation: $e');
      return null;
    }
  }

  /// Share recipe with friends using invitation system
  Future<bool> shareRecipeWithFriends({
    required String recipeId,
    required List<String> friendIds,
    String? message,
    bool allowCollaboration = false,
  }) async {
    final invitationId = await createRecipeInvitation(
      recipeId: recipeId,
      inviteeUserIds: friendIds,
      message: message,
      allowCollaboration: allowCollaboration,
    );

    return invitationId != null;
  }

  /// Get recipe invitations sent by current user
  Future<List<SharedRecipe>> getSentRecipeInvitations() async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.warning('Cannot get sent invitations: No authenticated user');
      return [];
    }

    try {
      // Note: This would require additional repository method
      // For now, we'll focus on the recipient side which is more important
      AppLogger.info('📤 Getting sent recipe invitations for user $currentUserId');
      return []; // Placeholder - would need additional repository method
    } catch (e) {
      AppLogger.error('Failed to get sent recipe invitations: $e');
      return [];
    }
  }

  /// Get recipe invitations received by current user
  Future<List<SharedRecipe>> getReceivedRecipeInvitations() async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.warning('Cannot get received invitations: No authenticated user');
      return [];
    }

    try {
      AppLogger.info('📥 Getting received recipe invitations for user $currentUserId');
      return await _sharedRecipeRepository.getSharedRecipesForUser(currentUserId);
    } catch (e) {
      AppLogger.error('Failed to get received recipe invitations: $e');
      return [];
    }
  }

  /// Join shared recipe for viewing (true copy-on-write collaboration)
  /// 
  /// This implements TRUE copy-on-write where users initially view the original
  /// recipe until someone attempts to edit it, which triggers copy creation.
  Future<String?> joinSharedRecipe({
    required String sharedRecipeId,
    String? newTitle,
  }) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.error('Cannot join recipe: No authenticated user');
      return null;
    }

    try {
      AppLogger.info('📥 Joining shared recipe $sharedRecipeId for viewing');

      // Get shared recipe
      final sharedRecipe = await _sharedRecipeRepository.getSharedRecipe(sharedRecipeId);
      if (sharedRecipe == null) {
        AppLogger.error('Shared recipe not found: $sharedRecipeId');
        return null;
      }

      // For true copy-on-write: Just mark as joined/imported (viewer status)
      // No actual copy is created until first edit attempt
      await _sharedRecipeRepository.markAsImported(sharedRecipeId, currentUserId);

      AppLogger.success('✅ Joined shared recipe as viewer (copy-on-write ready)');
      AppLogger.info('💡 Copy will be created when you first edit the recipe');
      
      // Return the shared recipe ID (user views original until CoW triggers)
      return sharedRecipeId;
    } catch (e) {
      AppLogger.error('Failed to join shared recipe: $e');
      return null;
    }
  }

  /// Trigger copy-on-write when user attempts to edit shared recipe
  Future<String?> startCollaborativeEditing({
    required String sharedRecipeId,
  }) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.error('Cannot start collaborative editing: No authenticated user');
      return null;
    }

    try {
      AppLogger.info('🔄 Triggering copy-on-write for shared recipe $sharedRecipeId');

      // Get current shared recipe
      final sharedRecipe = await _sharedRecipeRepository.getSharedRecipe(sharedRecipeId);
      if (sharedRecipe == null) {
        AppLogger.error('Shared recipe not found: $sharedRecipeId');
        return null;
      }

      // Check if CoW already triggered
      if (sharedRecipe.copyOnWriteTriggered) {
        AppLogger.info('Copy-on-write already triggered, adding as collaborator');
        final updatedRecipe = sharedRecipe.addActiveCollaborator(currentUserId);
        await _sharedRecipeRepository.update(updatedRecipe);
        return sharedRecipeId;
      }

      // Create static copy for original owner
      final originalRecipe = sharedRecipe.recipeSnapshot;
      final staticCopy = Recipe(
        core: originalRecipe.core.copyWith(
          title: '${originalRecipe.core.title} (Min kopia)', // Mark as owner's copy
        ),
        type: originalRecipe.type,
        socialData: originalRecipe.socialData,
        realtimeData: originalRecipe.realtimeData,
        offlineData: originalRecipe.offlineData,
      );
      
      final staticCopyId = await _serviceAdapter.createRecipe(staticCopy);
      if (staticCopyId == null) {
        AppLogger.error('Failed to create static copy for original owner');
        return null;
      }

      // Trigger copy-on-write
      final collaborativeVersion = sharedRecipe.triggerCopyOnWrite(
        editingUserId: currentUserId,
        staticCopyId: staticCopyId,
      );

      // Save updated shared recipe
      await _sharedRecipeRepository.update(collaborativeVersion);

      AppLogger.success('✅ Copy-on-write triggered successfully');
      AppLogger.info('📄 Static copy created for original owner: $staticCopyId');
      AppLogger.info('👥 Shared version is now collaborative');
      
      return sharedRecipeId; // Return collaborative version ID
    } catch (e) {
      AppLogger.error('Failed to trigger copy-on-write: $e');
      return null;
    }
  }

  // ===== LEGACY COMPATIBILITY =====

  /// Legacy import method for backward compatibility (GitHub fork style)
  /// 
  /// This maintains the old behavior for existing code that hasn't been updated
  /// to use the new copy-on-write pattern. Creates immediate copy with attribution.
  @Deprecated('Use joinSharedRecipe for true copy-on-write behavior')
  Future<String?> importSharedRecipe({
    required String sharedRecipeId,
    String? newTitle,
  }) async {
    AppLogger.warning('⚠️ Using legacy import mode - consider using joinSharedRecipe for true copy-on-write');
    
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.error('Cannot import recipe: No authenticated user');
      return null;
    }

    try {
      AppLogger.info('📥 Importing shared recipe $sharedRecipeId (legacy mode)');

      // Get shared recipe
      final sharedRecipe = await _sharedRecipeRepository.getSharedRecipe(sharedRecipeId);
      if (sharedRecipe == null) {
        AppLogger.error('Shared recipe not found: $sharedRecipeId');
        return null;
      }

      // Create imported recipe with attribution (GitHub fork style)
      final importedRecipe = sharedRecipe.createImportRecipe(newOwnerId: currentUserId);
      
      // Override title if provided
      final finalRecipe = newTitle != null 
          ? importedRecipe.copyWith(title: newTitle)
          : importedRecipe;

      // Save imported recipe
      final recipeId = await _serviceAdapter.createRecipe(finalRecipe);
      if (recipeId == null) {
        AppLogger.error('Failed to save imported recipe');
        return null;
      }

      // Mark as imported in SharedRecipe
      await _sharedRecipeRepository.markAsImported(sharedRecipeId, currentUserId);

      AppLogger.success('✅ Recipe imported successfully with attribution (legacy mode)');
      return recipeId;
    } catch (e) {
      AppLogger.error('Failed to import shared recipe: $e');
      return null;
    }
  }

  /// Dismiss shared recipe from user's list
  Future<bool> dismissSharedRecipe(String sharedRecipeId) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.error('Cannot dismiss recipe: No authenticated user');
      return false;
    }

    try {
      AppLogger.info('🗑️ Dismissing shared recipe $sharedRecipeId');
      await _sharedRecipeRepository.markAsDismissed(sharedRecipeId, currentUserId);
      AppLogger.success('✅ Shared recipe dismissed');
      return true;
    } catch (e) {
      AppLogger.error('Failed to dismiss shared recipe: $e');
      return false;
    }
  }

  /// Send recipe invitation notifications (placeholder)
  Future<void> sendRecipeInvitationNotifications(String recipeId, List<String> inviteeUserIds) async {
    AppLogger.info('📧 Sending recipe invitation notifications to ${inviteeUserIds.length} users for recipe $recipeId');
    // Note: Notification system implementation would be integrated here
    // when NotificationService dependency is available in this coordinator
  }

  // ===== UTILITY OPERATIONS =====

  bool validateCollaborativeRecipeData({
    required String title,
    required List<String> ingredients,
    required List<String> instructions,
  }) {
    return _creationService.validateCollaborativeRecipeData(
      title: title,
      ingredients: ingredients,
      instructions: instructions,
    );
  }

  RecipeOperationResult createSuccessResult([String? message]) {
    return RecipeOperationResult.success(message ?? 'Operation completed successfully');
  }

  RecipeOperationResult createFailureResult(String error) {
    return RecipeOperationResult.failure(error);
  }

  // Note: _hasAdminPermission removed - now handled by SocialRecipePermissionService
  
  /// Create default service adapter using ServiceLocator
  static RecipeServiceAdapter _createDefaultServiceAdapter() {
    return RecipeServiceAdapter(
      recipeRepository: ServiceLocator.get(),
      commentsRepository: ServiceLocator.tryGet(),
      ratingsRepository: ServiceLocator.tryGet(),
      notificationsRepository: ServiceLocator.tryGet(),
    );
  }
}