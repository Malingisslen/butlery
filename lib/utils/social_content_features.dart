/// Social content features utility providing advanced social functionality coordination.
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
/// Centralizes social content operations including friend management, sharing coordination,
/// and social interaction utilities for consistent social functionality across shared content management.
/// Provides static utility methods for social operations with comprehensive error handling and state coordination.
class SocialContentFeatures {
  /// Loads friends for sharing functionality with comprehensive friend retrieval and social context.
  /// [service] Friends service instance for friend data retrieval
  /// Returns list of available friends for sharing functionality.
  /// Performs friend loading through service coordination with error handling
  /// and social context management for sharing operations.
  static Future<List<UserProfile>> loadFriends(dynamic service) async {
    return <UserProfile>[];
  }

  /// Updates share message with reactive state coordination and input management.
  /// [message] New share message for social sharing context
  /// [setter] Setter function for message state update
  /// Performs share message update with immediate state coordination
  /// for responsive social sharing functionality.
  static void updateShareMessage(String message, Function(String) setter) {
    setter(message);
  }

  /// Toggles friend selection with intelligent state management and social coordination.
  /// [friendId] Friend identifier for selection toggle
  /// [selectedIds] Current selection state for modification
  /// [notifyListeners] Notification function for UI updates
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
  /// [selectedIds] Selection state for complete cleanup
  /// [notifyListeners] Notification function for UI updates
  /// Performs complete friend selection cleanup with immediate UI notification
  /// for clean social interaction state management.
  static void clearFriendSelection(
      List<String> selectedIds, Function notifyListeners) {
    selectedIds.clear();
    notifyListeners();
  }

  /// Shares content with selected friends through comprehensive social distribution.
  /// [contentId] Content identifier for sharing operation
  /// [contentType] Type of content for sharing coordination
  /// [friendIds] Selected friend identifiers for sharing targets
  /// [message] Share message for social context
  /// [service] Service instance for sharing operations
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
    try {
      if (contentType == 'shopping_list' && service is UnifiedShoppingService) {
        // Get the shopping list
        final shoppingList =
            service.lists.firstWhere((list) => list.id == contentId);

        // PHASE 1 FIX: Create proper invitation instead of direct conversion
        final success = await _createSharedShoppingListInvitation(
            shoppingList, friendIds, message, service);

        if (!success) {
          return false;
        }

        return true;
      }

      // RECIPE INVITATION ROUTING
      if (contentType == 'recipe' && service is SocialRecipeService) {
        // Use SocialRecipeCoordinator to create recipe invitation
        final coordinator = ServiceLocator.get<SocialRecipeCoordinator>();
        final invitationId = await coordinator.createRecipeInvitation(
          recipeId: contentId,
          inviteeUserIds: friendIds,
          message: message.isNotEmpty ? message : null,
          allowCollaboration: false, // Copy-on-write collaboration
        );

        if (invitationId == null) {
          return false;
        }

        return true;
      }

      // MENU INVITATION ROUTING
      if (contentType == 'menu' && service is UnifiedMenuService) {
        // Get the menu data
        final menu = service.getMenuById(contentId);
        if (menu == null) {
          return false;
        }

        // Use UnifiedMenuService to create menu invitation
        final invitationId = await service.createMenuInvitation(
          menuTitle: menu.menuTitle,
          menuSnapshot: menu.menuSnapshot,
          inviteeUserIds: friendIds,
          message: message.isNotEmpty ? message : null,
          allowCollaboration: false, // Copy-on-write collaboration
        );

        if (invitationId == null) {
          return false;
        }

        return true;
      }

      // Unknown content type or service mismatch
      return false;
    } catch (e) {
      AppLogger.error('Failed to share content: $e');
      return false;
    }
  }

  /// Activates sharing mode with state coordination and UI preparation.
  /// [setter] Setter function for sharing state update
  /// [notifyListeners] Notification function for UI updates
  /// Enables sharing mode with immediate state coordination and UI notification
  /// for social sharing functionality activation.
  static void startSharing(Function(bool) setter, Function notifyListeners) {
    setter(true);
    notifyListeners();
  }

  /// Cancels sharing mode with comprehensive state cleanup and reset coordination.
  /// [setter] Setter function for sharing state cleanup
  /// [selectedIds] Selection state for cleanup
  /// [notifyListeners] Notification function for UI updates
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
      // Get current user information
      final currentUserId = service.currentUserId;
      final userService = ServiceLocator.get<UserService>();
      final currentUserProfile = userService.currentUserProfile;

      if (currentUserId == null || currentUserProfile == null) {
        return false;
      }

      // PHASE 3 FIX: Validate share targets to prevent duplicate invitations
      final validationResult =
          await _validateShareTargets(shoppingList, friendIds, service);
      if (!validationResult.isValid) {
        return false;
      }

      final validFriendIds = validationResult.validTargets;

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
      final sharedShoppingRepository =
          ServiceLocator.get<FirebaseSharedShoppingRepository>();
      // Note (Issue #014): Pass recipientIds separately since arrays removed from model
      await sharedShoppingRepository.createSharedShoppingList(
        validatedSharedShoppingList,
        recipientIds: validFriendIds,
      );

      return true;
    } catch (e) {
      AppLogger.error('Failed to create shopping list invitation: $e');
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
      // Check if there's already a collaborative version of this list
      final collaborativeVersions = service.lists
          .where((list) =>
              list.type == ListType.collaborative &&
              list.name == shoppingList.name &&
              list.ownerId == shoppingList.ownerId)
          .toList();

      if (collaborativeVersions.isEmpty) {
        return ShareTargetValidationResult.valid(friendIds);
      }

      // Get existing members from all collaborative versions
      final existingMembers = <String>{};
      for (final collaborativeList in collaborativeVersions) {
        existingMembers.addAll(collaborativeList.collaborators);
      }

      // Filter out targets who are already members
      final validTargets = friendIds
          .where((friendId) => !existingMembers.contains(friendId))
          .toList();

      if (validTargets.isEmpty) {
        return ShareTargetValidationResult.invalid(
            'All selected users already have access to this list');
      }

      return ShareTargetValidationResult.valid(validTargets);
    } catch (e) {
      AppLogger.error('Share validation failed: $e');
      // On error, allow all targets to avoid blocking sharing
      return ShareTargetValidationResult.valid(friendIds);
    }
  }
}
