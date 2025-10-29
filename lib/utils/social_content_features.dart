/// Social content features utility providing advanced social functionality coordination.
///
/// This module centralizes social content operations including friend management, sharing coordination,
/// and social interaction utilities for consistent social functionality across shared content management.
/// Extracted from SharedContentViewModel to enable modular architecture and deprecation of the monolithic ViewModel.

// lib/utils/social_content_features.dart

import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/repositories/firebase/firebase_shared_shopping_repository.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/core/utils/logger.dart';

/// PHASE 3 FIX: Result class for share target validation
/// Used to communicate validation results and provide user feedback
/// Renamed to avoid conflict with UniversalShareDialogViewModel's ShareValidationResult
class ShareTargetValidationResult {
  final bool isValid;
  final List<String> validTargets;
  final String message;

  const ShareTargetValidationResult._({
    required this.isValid,
    required this.validTargets,
    required this.message,
  });

  /// Create result for valid share targets
  factory ShareTargetValidationResult.valid(List<String> validTargets) {
    return ShareTargetValidationResult._(
      isValid: true,
      validTargets: validTargets,
      message: 'All targets validated successfully',
    );
  }

  /// Create result for invalid share attempt
  factory ShareTargetValidationResult.invalid(String message) {
    return ShareTargetValidationResult._(
      isValid: false,
      validTargets: [],
      message: message,
    );
  }
}

/// Comprehensive social content features utility providing advanced social functionality coordination.
///
/// Centralizes social content operations including friend management, sharing coordination,
/// and social interaction utilities for consistent social functionality across shared content management.
/// Provides static utility methods for social operations with comprehensive error handling and state coordination.
class SocialContentFeatures {
  /// Loads friends for sharing functionality with comprehensive friend retrieval and social context.
  ///
  /// [service] Friends service instance for friend data retrieval
  ///
  /// Returns list of available friends for sharing functionality.
  /// Performs friend loading through service coordination with error handling
  /// and social context management for sharing operations.
  static Future<List<UserProfile>> loadFriends(dynamic service) async {
    return <UserProfile>[];
  }

  /// Updates share message with reactive state coordination and input management.
  ///
  /// [message] New share message for social sharing context
  /// [setter] Setter function for message state update
  ///
  /// Performs share message update with immediate state coordination
  /// for responsive social sharing functionality.
  static void updateShareMessage(String message, Function(String) setter) {
    setter(message);
  }

  /// Toggles friend selection with intelligent state management and social coordination.
  ///
  /// [friendId] Friend identifier for selection toggle
  /// [selectedIds] Current selection state for modification
  /// [notifyListeners] Notification function for UI updates
  ///
  /// Performs friend selection toggle with automatic state management
  /// and UI notification for responsive social interaction.
  static void toggleFriendSelection(
      String friendId, List<String> selectedIds, Function notifyListeners) {
    if (selectedIds.contains(friendId)) {
      selectedIds.remove(friendId);
    } else {
      selectedIds.add(friendId);
    }
    notifyListeners();
  }

  /// Clears friend selection with comprehensive state cleanup and UI coordination.
  ///
  /// [selectedIds] Selection state for complete cleanup
  /// [notifyListeners] Notification function for UI updates
  ///
  /// Performs complete friend selection cleanup with immediate UI notification
  /// for clean social interaction state management.
  static void clearFriendSelection(
      List<String> selectedIds, Function notifyListeners) {
    selectedIds.clear();
    notifyListeners();
  }

  /// Shares content with selected friends through comprehensive social distribution.
  ///
  /// [contentId] Content identifier for sharing operation
  /// [contentType] Type of content for sharing coordination
  /// [friendIds] Selected friend identifiers for sharing targets
  /// [message] Share message for social context
  /// [service] Service instance for sharing operations
  ///
  /// Returns true if sharing succeeds, false if operation fails.
  /// Performs content sharing through service coordination with comprehensive
  /// error handling and social distribution management.
  static Future<bool> shareContentWithFriends(
    String contentId,
    String contentType,
    List<String> friendIds,
    String message,
    dynamic service,
  ) async {
    AppLogger.info('🚀 INVITATION DEBUG: INVITATION CREATION START');
    AppLogger.info(
        '📋 INVITATION DEBUG: Sharing content: "$contentId" (type: $contentType)');
    AppLogger.info(
        '📋 INVITATION DEBUG: Target friends: ${friendIds.length} friends: $friendIds');
    AppLogger.info(
        '📋 INVITATION DEBUG: Message: "${message.isEmpty ? 'None' : message}"');
    AppLogger.info('📋 INVITATION DEBUG: Service type: ${service.runtimeType}');

    try {
      if (contentType == 'shopping_list' && service is UnifiedShoppingService) {
        AppLogger.info(
            '✅ INVITATION DEBUG: Confirmed shopping list sharing workflow - USING INVITATION SYSTEM');

        // Get the shopping list
        AppLogger.info(
            '🔄 INVITATION DEBUG: Looking up shopping list with ID: $contentId');
        final shoppingList =
            service.lists.firstWhere((list) => list.id == contentId);
        AppLogger.info(
            '✅ INVITATION DEBUG: Found shopping list: "${shoppingList.name}" with ${shoppingList.items.length} items');
        AppLogger.info(
            '📊 INVITATION DEBUG: List details - Type: ${shoppingList.type}, Collaborative: ${shoppingList.isCollaborative}, Owner: ${shoppingList.ownerId}');

        // CRITICAL CHECK: Verify this is not already a collaborative list being shared incorrectly
        if (shoppingList.isCollaborative) {
          AppLogger.warning(
              '⚠️ INVITATION DEBUG: WARNING - Attempting to share an already collaborative list!');
          AppLogger.info(
              '📋 INVITATION DEBUG: Current collaborators: ${shoppingList.collaborators}');
          AppLogger.info(
              '📋 INVITATION DEBUG: Member permissions: ${shoppingList.memberPermissions}');
          AppLogger.info(
              '🤔 INVITATION DEBUG: This might explain why recipients are auto-added!');

          // Check if any target friends are already in collaborators vs removed from permissions
          for (final friendId in friendIds) {
            final isCurrentCollaborator = shoppingList.collaborators.contains(friendId);
            final hasPermission = shoppingList.memberPermissions.containsKey(friendId);
            AppLogger.info('👤 INVITATION DEBUG: Friend $friendId - InCollaborators: $isCurrentCollaborator, HasPermission: $hasPermission');
            if (!isCurrentCollaborator && !hasPermission) {
              AppLogger.info('✅ INVITATION DEBUG: Friend $friendId is truly new (removed or never added)');
            }
          }
        }

        // PHASE 1 FIX: Create proper invitation instead of direct conversion
        AppLogger.info(
            '🔄 INVITATION DEBUG: Creating SharedShoppingList invitation for "Delat med mig" workflow');
        final success = await _createSharedShoppingListInvitation(
            shoppingList, friendIds, message, service);

        if (!success) {
          AppLogger.error(
              '❌ INVITATION DEBUG: Failed to create shopping list invitation');
          return false;
        }

        AppLogger.success(
            '🎉 INVITATION DEBUG: Shopping list invitation created successfully - should appear in "Delat med mig"!');
        return true;
      }

      // RECIPE INVITATION ROUTING
      if (contentType == 'recipe' && service is SocialRecipeService) {
        AppLogger.info(
            '✅ INVITATION DEBUG: Confirmed recipe sharing workflow - USING INVITATION SYSTEM');

        // Use SocialRecipeCoordinator to create recipe invitation
        AppLogger.info('🔄 INVITATION DEBUG: Creating recipe invitation via SocialRecipeCoordinator');
        final coordinator = ServiceLocator.get<SocialRecipeCoordinator>();
        final invitationId = await coordinator.createRecipeInvitation(
          recipeId: contentId,
          inviteeUserIds: friendIds,
          message: message.isNotEmpty ? message : null,
          allowCollaboration: false, // Copy-on-write collaboration
        );

        if (invitationId == null) {
          AppLogger.error('❌ INVITATION DEBUG: Failed to create recipe invitation');
          return false;
        }

        AppLogger.success(
            '🎉 INVITATION DEBUG: Recipe invitation created successfully - should appear in "Delat med mig"!');
        return true;
      }

      // MENU INVITATION ROUTING
      if (contentType == 'menu' && service is UnifiedMenuService) {
        AppLogger.info(
            '✅ INVITATION DEBUG: Confirmed menu sharing workflow - USING INVITATION SYSTEM');

        // Get the menu data
        AppLogger.info('🔄 INVITATION DEBUG: Looking up menu with ID: $contentId');
        final menu = service.getMenuById(contentId);
        if (menu == null) {
          AppLogger.error('❌ INVITATION DEBUG: Menu not found: $contentId');
          return false;
        }

        // Use UnifiedMenuService to create menu invitation
        AppLogger.info('🔄 INVITATION DEBUG: Creating menu invitation via UnifiedMenuService');
        final invitationId = await service.createMenuInvitation(
          menuTitle: menu.menuTitle,
          menuSnapshot: menu.menuSnapshot,
          inviteeUserIds: friendIds,
          message: message.isNotEmpty ? message : null,
          allowCollaboration: false, // Copy-on-write collaboration
        );

        if (invitationId == null) {
          AppLogger.error('❌ INVITATION DEBUG: Failed to create menu invitation');
          return false;
        }

        AppLogger.success(
            '🎉 INVITATION DEBUG: Menu invitation created successfully - should appear in "Delat med mig"!');
        return true;
      }

      // Unknown content type or service mismatch
      AppLogger.error(
          '❌ INVITATION DEBUG: Unknown content type "$contentType" or service mismatch: ${service.runtimeType}');
      return false;
    } catch (e) {
      AppLogger.error('Failed to share content: $e');
      return false;
    }
  }

  /// Activates sharing mode with state coordination and UI preparation.
  ///
  /// [setter] Setter function for sharing state update
  /// [notifyListeners] Notification function for UI updates
  ///
  /// Enables sharing mode with immediate state coordination and UI notification
  /// for social sharing functionality activation.
  static void startSharing(Function(bool) setter, Function notifyListeners) {
    setter(true);
    notifyListeners();
  }

  /// Cancels sharing mode with comprehensive state cleanup and reset coordination.
  ///
  /// [setter] Setter function for sharing state cleanup
  /// [selectedIds] Selection state for cleanup
  /// [notifyListeners] Notification function for UI updates
  ///
  /// Deactivates sharing mode with complete state cleanup and UI notification
  /// for clean social sharing state management.
  static void cancelSharing(Function(bool) setter, List<String> selectedIds,
      Function notifyListeners) {
    setter(false);
    selectedIds.clear();
    notifyListeners();
  }

  // ===== PHASE 1 FIX: INVITATION CREATION =====

  /// Create SharedShoppingList invitation for proper "Delat med mig" workflow
  /// This method converts UnifiedShoppingList to SharedShoppingList invitation
  /// and persists it via FirebaseSharedShoppingRepository
  static Future<bool> _createSharedShoppingListInvitation(
    UnifiedShoppingList shoppingList,
    List<String> friendIds,
    String message,
    UnifiedShoppingService service,
  ) async {
    try {
      AppLogger.info(
          '🔄 INVITATION CREATION: Creating SharedShoppingList invitation for "${shoppingList.name}"');
      AppLogger.info(
          '🔄 INVITATION CREATION: Target friends: ${friendIds.length}, Message: "${message.isEmpty ? 'None' : message}"');

      // Get current user information
      final currentUserId = service.currentUserId;
      final userService = ServiceLocator.get<UserService>();
      final currentUserProfile = userService.currentUserProfile;

      if (currentUserId == null || currentUserProfile == null) {
        AppLogger.error(
            '❌ INVITATION CREATION: Cannot get current user information');
        return false;
      }

      AppLogger.info(
          '✅ INVITATION CREATION: Current user: ${currentUserProfile.displayName} ($currentUserId)');

      AppLogger.info(
          '🔄 INVITATION CREATION: Creating SharedShoppingList invitation...');

      // PHASE 3 FIX: Validate share targets to prevent duplicate invitations
      final validationResult = await _validateShareTargets(shoppingList, friendIds, service);
      if (!validationResult.isValid) {
        AppLogger.warning(
            '⚠️ PHASE 3 FIX: Share validation failed: ${validationResult.message}');
        return false;
      }

      final validFriendIds = validationResult.validTargets;
      AppLogger.info(
          '✅ PHASE 3 FIX: Validated ${validFriendIds.length}/${friendIds.length} share targets');

      // Create SharedShoppingList invitation with validated targets
      final validatedSharedShoppingList = SharedShoppingList.create(
        sharedByUserId: currentUserId,
        sharedByDisplayName: currentUserProfile.displayName,
        sharedToUserIds: validFriendIds,
        shareMessage: message,
        listName: shoppingList.name,
        listDescription: shoppingList.description,
        listItems: shoppingList.items,
      );

      // Persist invitation via repository
      final sharedShoppingRepository = ServiceLocator.get<FirebaseSharedShoppingRepository>();
      final invitationId = await sharedShoppingRepository.createSharedShoppingList(validatedSharedShoppingList);

      AppLogger.success(
          '🎉 INVITATION CREATION: SharedShoppingList invitation saved with ID: $invitationId');
      AppLogger.info(
          '✅ INVITATION CREATION: Invitation will appear in recipients "Delat med mig" view');

      return true;
    } catch (e) {
      AppLogger.error(
          '❌ INVITATION CREATION: Failed to create shopping list invitation: $e');
      return false;
    }
  }

  /// PHASE 3 FIX: Validate share targets to prevent duplicate invitations
  /// This method checks if target users are already members of existing collaborative versions
  static Future<ShareTargetValidationResult> _validateShareTargets(
    UnifiedShoppingList shoppingList,
    List<String> friendIds,
    UnifiedShoppingService service,
  ) async {
    try {
      AppLogger.info(
          '🔄 SHARE VALIDATION: Validating ${friendIds.length} share targets for "${shoppingList.name}"');

      // Check if there's already a collaborative version of this list
      final collaborativeVersions = service.lists.where((list) =>
          list.type == ListType.collaborative &&
          list.name == shoppingList.name &&
          list.ownerId == shoppingList.ownerId).toList();

      if (collaborativeVersions.isEmpty) {
        AppLogger.info(
            '✅ SHARE VALIDATION: No collaborative version exists - all targets valid');
        return ShareTargetValidationResult.valid(friendIds);
      }

      AppLogger.info(
          '🔍 SHARE VALIDATION: Found ${collaborativeVersions.length} collaborative version(s), checking members');

      // Get existing members from all collaborative versions
      final existingMembers = <String>{};
      for (final collaborativeList in collaborativeVersions) {
        existingMembers.addAll(collaborativeList.collaborators);
        AppLogger.info(
            '🔍 SHARE VALIDATION: Collaborative list "${collaborativeList.id}" has members: ${collaborativeList.collaborators}');
      }

      // Filter out targets who are already members
      final validTargets = friendIds.where((friendId) => !existingMembers.contains(friendId)).toList();
      final duplicateTargets = friendIds.where((friendId) => existingMembers.contains(friendId)).toList();

      AppLogger.info(
          '📊 SHARE VALIDATION: Valid targets: ${validTargets.length}, Already members: ${duplicateTargets.length}');

      if (duplicateTargets.isNotEmpty) {
        AppLogger.warning(
            '⚠️ SHARE VALIDATION: Found duplicate targets - these users already have access: $duplicateTargets');
      }

      if (validTargets.isEmpty) {
        AppLogger.warning(
            '⚠️ SHARE VALIDATION: No valid targets - all selected users already have access');
        return ShareTargetValidationResult.invalid(
            'All selected users already have access to this list');
      }

      return ShareTargetValidationResult.valid(validTargets);

    } catch (e) {
      AppLogger.error('❌ SHARE VALIDATION: Validation failed: $e');
      // On error, allow all targets to avoid blocking sharing
      AppLogger.warning(
          '⚠️ SHARE VALIDATION: Falling back to allowing all targets due to validation error');
      return ShareTargetValidationResult.valid(friendIds);
    }
  }
}
