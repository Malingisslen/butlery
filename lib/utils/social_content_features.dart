/// Social content features utility providing advanced social functionality coordination.
/// This module centralizes social content operations including friend management, sharing coordination,
/// and social interaction utilities for consistent social functionality across shared content management.
/// Extracted from SharedContentViewModel to enable modular architecture and deprecation of the monolithic ViewModel.

// lib/utils/social_content_features.dart

import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/core/utils/logger.dart';

/// Comprehensive social content features utility providing advanced social functionality coordination.
/// Centralizes social content operations including friend management, sharing coordination,
/// and social interaction utilities for consistent social functionality across shared content management.
/// Provides static utility methods for social operations with comprehensive error handling and state coordination.
class SocialContentFeatures {
  /// Loads friends for sharing functionality with comprehensive friend retrieval and social context.
  static Future<List<UserProfile>> loadFriends(
    UnifiedFriendsService service,
  ) async {
    try {
      if (!service.isInitialized) {
        await service.initialize();
      }
      return service.friends;
    } catch (e) {
      AppLogger.error('Failed to load friends for sharing', e);
      return <UserProfile>[];
    }
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
    String friendId,
    List<String> selectedIds,
    Function notifyListeners,
  ) {
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
    List<String> selectedIds,
    Function notifyListeners,
  ) {
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
    dynamic service, {
    List<String>? groupIds,
  }) async {
    try {
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
  static void cancelSharing(
    Function(bool) setter,
    List<String> selectedIds,
    Function notifyListeners,
  ) {
    setter(false);
    selectedIds.clear();
    notifyListeners();
  }
}
