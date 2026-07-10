// lib/services/unified/modules/social_recipe/social_recipe_coordinator.dart
import 'dart:async';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
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

/// Social Recipe Coordinator - Facade coordinating social recipe operations via focused services.
/// Maintains backward compatibility while providing clean separation of concerns.
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
  /// Cached viewed status (recipeId → bool)
  final Map<String, bool> _viewedStatusCache = {};

  /// Cached imported status (recipeId → bool)
  final Map<String, bool> _importedStatusCache = {};

  /// Cached dismissed status (recipeId → bool)
  final Map<String, bool> _dismissedStatusCache = {};

  SocialRecipeCoordinator({
    required JsonCacheHelper Function() getCacheHelper,
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required void Function(String) setError,
    required void Function() notifyListeners,
    required Future<Recipe?> Function(String) getRecipe,
    required Future<bool> Function(Recipe) saveRecipe,
    RecipeServiceAdapter? serviceAdapter,
  }) : _serviceAdapter =
           serviceAdapter ??
           SocialRecipeCoordinator._createDefaultServiceAdapter(),
       _getCurrentUserId = getCurrentUserId {
    // Set the user ID provider for the mixin
    setUserIdProvider(getCurrentUserId);

    // Initialize SharedRecipeRepository from DI
    _sharedRecipeRepository =
        ServiceLocator.get<FirebaseSharedRecipeRepository>();

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
      sharedRecipeRepository: _sharedRecipeRepository,
    );

    _permissionService = SocialRecipePermissionService(
      getRecipe: getRecipe,
    );

    _queryService = SocialRecipeQueryService(
      getCacheHelper: getCacheHelper,
      getCurrentUserId: getCurrentUserId,
      setError: setError,
      serviceAdapter: _serviceAdapter,
    );

    // Note: _sharedRecipeRepository initialized from DI at line 73

    // _initializeNotificationService(); // Temporarily disabled
  }
  Future<String?> createCollaborativeRecipe({
    required String title,
    required List<String> ingredients,
    required List<String> instructions,
    List<String>? initialMembers,
    Map<String, ResourcePermission>? initialPermissions,
    String? description,
    int? portions,
    int? cookingTime,
    List<String>? personalTagIds,
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
      personalTagIds: personalTagIds,
    );
  }

  Future<bool> addMemberToRecipe(
    String recipeId,
    String userId,
    ResourcePermission permission,
  ) async {
    final result = await _membershipService.addMemberToRecipe(
      recipeId,
      userId,
      permission,
    );

    // Send notification after successful addition
    if (result) {
      await sendMemberAdditionNotification(recipeId, userId);
    }

    return result;
  }

  Future<bool> removeMemberFromRecipe(String recipeId, String userId) async =>
      await _membershipService.removeMemberFromRecipe(recipeId, userId);

  Future<bool> updateMemberPermission(
    String recipeId,
    String userId,
    ResourcePermission permission,
  ) async => await _membershipService.updateMemberPermission(
    recipeId,
    userId,
    permission,
  );
  Future<RecipeShareResult> shareRecipeWithUsers(
    String recipeId,
    List<String> userIds,
    ResourcePermission permission,
  ) async {
    final result = await _sharingService.shareRecipeWithUsers(
      recipeId,
      userIds,
      permission,
    );

    // BUT-1503: notify whenever access was actually granted (the primary
    // memberPermissions write succeeded), even if the secondary discovery-doc
    // write failed — the recipient can open the recipe and must be told.
    if (result.accessGranted) {
      await sendRecipeSharingNotifications(recipeId, userIds);
    }

    return result;
  }

  Future<bool> shareRecipeWithGroups(
    String recipeId,
    List<String> groupIds,
    ResourcePermission permission,
  ) async => await _sharingService.shareRecipeWithGroups(
    recipeId,
    groupIds,
    permission,
  );

  Future<bool> unshareRecipe(String recipeId) async =>
      await _sharingService.unshareRecipe(recipeId);
  Future<bool> canEditRecipe(String recipeId, String userId) async =>
      await _permissionService.canEditRecipe(recipeId, userId);

  Future<bool> canManageRecipeMembers(String recipeId, String userId) async =>
      await _permissionService.canManageRecipeMembers(recipeId, userId);

  Future<bool> canViewRecipe(String recipeId, String userId) async =>
      await _permissionService.canViewRecipe(recipeId, userId);

  Future<ResourcePermission?> getUserPermissionForRecipe(
    String recipeId,
    String userId,
  ) async =>
      await _permissionService.getUserPermissionForRecipe(recipeId, userId);
  Future<List<Recipe>> getCollaborativeRecipesForUser() async =>
      await _queryService.getCollaborativeRecipesForUser();

  Future<List<Recipe>> getRecipesSharedByUser(String userId) async =>
      await _queryService.getRecipesSharedByUser(userId);

  Future<List<Recipe>> getRecipesWithPermission(
    ResourcePermission permission,
  ) async => await _queryService.getRecipesWithPermission(permission);

  Future<Map<String, int>> getCollaborationStats() async =>
      await _queryService.getCollaborationStats();

  Future<List<String>> getMostActiveCollaborators({int limit = 10}) async =>
      await _queryService.getMostActiveCollaborators(limit: limit);

  Future<List<Recipe>> loadCachedCollaborativeRecipes() async =>
      await _queryService.loadCachedCollaborativeRecipes();
  Future<void> sendCollaborationInvitations(
    String recipeId,
    List<String> userIds,
  ) async {
    AppLogger.info(
      '📧 Sending collaboration invitations to ${userIds.length} users for recipe $recipeId',
    );
    // Note: Notification system implementation would be integrated here
    // when NotificationService dependency is available in this coordinator
  }

  Future<void> sendMemberAdditionNotification(
    String recipeId,
    String addedUserId,
  ) async {
    AppLogger.info(
      '📧 Sending member addition notification for recipe $recipeId to user $addedUserId',
    );
    // Note: Notification system implementation would be integrated here
    // when NotificationService dependency is available in this coordinator
  }

  Future<void> sendRecipeSharingNotifications(
    String recipeId,
    List<String> sharedWithUserIds,
  ) async {
    AppLogger.info(
      '📧 Sending sharing notifications to ${sharedWithUserIds.length} users for recipe $recipeId',
    );
    // Note: Notification system implementation would be integrated here
    // when NotificationService dependency is available in this coordinator
  }

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
      AppLogger.info(
        '📨 Creating recipe invitation for recipe $recipeId to ${inviteeUserIds.length} users',
      );

      final recipe = await _serviceAdapter.getRecipeById(recipeId);
      if (recipe == null) {
        AppLogger.error('Recipe not found: $recipeId');
        return null;
      }

      final userService = ServiceLocator.get<user_service.UserService>();
      final currentUserProfile = userService.currentUserProfile;
      if (currentUserProfile == null) {
        AppLogger.error('Cannot get current user profile for invitation');
        return null;
      }

      final sharedRecipe = SharedRecipe.create(
        originalRecipeId: recipeId,
        sharedByUserId: currentUserId, // Already checked for null above
        sharedByDisplayName: currentUserProfile.displayName,
        sharedToUserIds: inviteeUserIds,
        shareMessage: message,
        allowCollaboration: allowCollaboration,
        recipeSnapshot: recipe,
      );

      // Note (Issue #014): Pass recipientIds separately since arrays removed from model
      final invitationId = await _sharedRecipeRepository.createSharedRecipe(
        sharedRecipe,
        recipientIds: inviteeUserIds,
      );

      AppLogger.success(
        ' Recipe invitation created successfully: $invitationId',
      );
      AppLogger.info(
        '📥 Recipients will see invitation in "Delat med mig" view',
      );

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
      AppLogger.info(
        '📤 Getting sent recipe invitations for user $currentUserId',
      );
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
      AppLogger.warning(
        'Cannot get received invitations: No authenticated user',
      );
      return [];
    }

    try {
      AppLogger.info(
        '📥 Getting received recipe invitations for user $currentUserId',
      );
      return await _sharedRecipeRepository.getSharedRecipesForUser(
        currentUserId,
      );
    } catch (e) {
      AppLogger.error('Failed to get received recipe invitations: $e');
      return [];
    }
  }

  /// Get all shared recipes for a specific user
  /// Phase 3 Session 1: Content loading method for ViewModel migration.
  /// Wraps repository call with error handling and logging.
  Future<List<SharedRecipe>> getSharedRecipesForUser(String userId) async {
    try {
      AppLogger.info(
        '📥 Loading shared recipes for user ${userId.maskedUserId}',
      );
      return await _sharedRecipeRepository.getSharedRecipesForUser(userId);
    } catch (e) {
      AppLogger.error(
        'Failed to load shared recipes for user ${userId.maskedUserId}',
        e,
      );
      return [];
    }
  }

  /// Get specific shared recipe by ID.
  /// Used for group content view and deep links where the full SharedRecipe is needed.
  Future<SharedRecipe?> getSharedRecipeById(String recipeId) async {
    try {
      AppLogger.info('📥 Loading shared recipe by ID: $recipeId');
      return await _sharedRecipeRepository.getSharedRecipe(recipeId);
    } catch (e) {
      AppLogger.error('Failed to load shared recipe $recipeId', e);
      return null;
    }
  }

  /// Load status for a recipe from repository and cache it
  /// Phase 3 Session 2: Status caching method for ViewModel migration.
  /// Loads viewed, imported, and dismissed status from repository and caches locally.
  Future<void> loadStatusForRecipe(String recipeId, String userId) async {
    try {
      final results = await Future.wait([
        _sharedRecipeRepository.hasViewed(recipeId, userId),
        _sharedRecipeRepository.hasEngaged(recipeId, userId),
        _sharedRecipeRepository.hasDismissed(recipeId, userId),
      ]);
      _viewedStatusCache[recipeId] = results[0];
      _importedStatusCache[recipeId] = results[1];
      _dismissedStatusCache[recipeId] = results[2];
    } catch (e) {
      AppLogger.error('Failed to load status for recipe $recipeId', e);
    }
  }

  /// Load status for all recipes in bulk
  /// Phase 3 Session 2: Bulk status loading method for ViewModel migration.
  /// Loads status for multiple recipes to populate cache efficiently.
  Future<void> loadStatusForAllRecipes(
    List<SharedRecipe> recipes,
    String userId,
  ) async {
    // Batch to avoid unbounded concurrent Firestore reads (3 reads per recipe)
    const batchSize = 5;
    for (var i = 0; i < recipes.length; i += batchSize) {
      final end = (i + batchSize < recipes.length)
          ? i + batchSize
          : recipes.length;
      final batch = recipes.sublist(i, end);
      await Future.wait(
        batch.map((recipe) => loadStatusForRecipe(recipe.id, userId)),
      );
    }
  }

  /// Check if recipe is dismissed using cache
  /// Phase 3 Session 2: Status checking method for ViewModel migration.
  /// Falls back to false if not cached.
  bool isRecipeDismissed(String recipeId) {
    return _dismissedStatusCache[recipeId] ?? false;
  }

  /// Check if recipe is viewed using cache
  /// Phase 3 Session 2: Status checking method for ViewModel migration.
  /// Falls back to false if not cached.
  bool isRecipeViewed(String recipeId) {
    return _viewedStatusCache[recipeId] ?? false;
  }

  /// Directly update the viewed status cache without a Firestore round-trip.
  void setViewedStatus(String recipeId, bool viewed) {
    _viewedStatusCache[recipeId] = viewed;
  }

  /// Check if recipe is imported using cache
  /// Phase 3 Session 2: Status checking method for ViewModel migration.
  /// Falls back to false if not cached.
  bool isRecipeImported(String recipeId) {
    return _importedStatusCache[recipeId] ?? false;
  }

  /// Join shared recipe for viewing with true copy-on-write (copy created on first edit).
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

      final sharedRecipe = await _sharedRecipeRepository.getSharedRecipe(
        sharedRecipeId,
      );
      if (sharedRecipe == null) {
        AppLogger.error('Shared recipe not found: $sharedRecipeId');
        return null;
      }

      await _sharedRecipeRepository.markAsImported(
        sharedRecipeId,
        currentUserId,
      );

      AppLogger.success(
        ' Joined shared recipe as viewer (copy-on-write ready)',
      );
      AppLogger.info('💡 Copy will be created when you first edit the recipe');

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
      AppLogger.error(
        'Cannot start collaborative editing: No authenticated user',
      );
      return null;
    }

    try {
      AppLogger.info(
        '🔄 Triggering copy-on-write for shared recipe $sharedRecipeId',
      );

      final sharedRecipe = await _sharedRecipeRepository.getSharedRecipe(
        sharedRecipeId,
      );
      if (sharedRecipe == null) {
        AppLogger.error('Shared recipe not found: $sharedRecipeId');
        return null;
      }

      if (sharedRecipe.copyOnWriteTriggered) {
        AppLogger.info(
          'Copy-on-write already triggered, adding as collaborator',
        );
        final updatedRecipe = sharedRecipe.addActiveCollaborator(currentUserId);
        await _sharedRecipeRepository.update(updatedRecipe);
        return sharedRecipeId;
      }

      // Use contentSnapshot which handles V1 (full snapshot) or V2 (minimal from metadata)
      final originalRecipe = sharedRecipe.contentSnapshot;
      final staticCopy = Recipe(
        core: originalRecipe.core.copyWith(
          title:
              '${originalRecipe.core.title} (Min kopia)', // Mark as owner's copy
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

      final collaborativeVersion = sharedRecipe.triggerCopyOnWrite(
        editingUserId: currentUserId,
        staticCopyId: staticCopyId,
      );

      await _sharedRecipeRepository.update(collaborativeVersion);

      AppLogger.success(' Copy-on-write triggered successfully');
      AppLogger.info(
        '📄 Static copy created for original owner: $staticCopyId',
      );
      AppLogger.info('👥 Shared version is now collaborative');

      return sharedRecipeId; // Return collaborative version ID
    } catch (e) {
      AppLogger.error('Failed to trigger copy-on-write: $e');
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
      await _sharedRecipeRepository.markAsDismissed(
        sharedRecipeId,
        currentUserId,
      );
      AppLogger.success(' Shared recipe dismissed');
      return true;
    } catch (e) {
      AppLogger.error('Failed to dismiss shared recipe: $e');
      return false;
    }
  }

  /// Restore dismissed shared recipe to user's list
  Future<bool> undismissSharedRecipe(String sharedRecipeId) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.error('Cannot undismiss recipe: No authenticated user');
      return false;
    }

    try {
      AppLogger.info('↩️ Restoring shared recipe $sharedRecipeId');
      await _sharedRecipeRepository.undismiss(sharedRecipeId, currentUserId);
      AppLogger.success(' Shared recipe restored');
      return true;
    } catch (e) {
      AppLogger.error('Failed to restore shared recipe: $e');
      return false;
    }
  }

  /// Mark shared recipe as viewed by current user
  Future<bool> markRecipeAsViewed(String sharedRecipeId) async {
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      AppLogger.error('Cannot mark recipe as viewed: No authenticated user');
      return false;
    }

    try {
      AppLogger.info('👁️ Marking shared recipe $sharedRecipeId as viewed');
      await _sharedRecipeRepository.markAsViewed(sharedRecipeId, currentUserId);
      AppLogger.success(' Shared recipe marked as viewed');
      return true;
    } catch (e) {
      AppLogger.error('Failed to mark recipe as viewed: $e');
      return false;
    }
  }

  /// Send recipe invitation notifications (placeholder)
  Future<void> sendRecipeInvitationNotifications(
    String recipeId,
    List<String> inviteeUserIds,
  ) async {
    AppLogger.info(
      '📧 Sending recipe invitation notifications to ${inviteeUserIds.length} users for recipe $recipeId',
    );
    // Note: Notification system implementation would be integrated here
    // when NotificationService dependency is available in this coordinator
  }

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
    return RecipeOperationResult.success(
      message ?? 'Operation completed successfully',
    );
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
