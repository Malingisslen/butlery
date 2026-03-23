/// Universal share dialog ViewModel for multi-content sharing (recipes, menus, shopping lists) with friend/group targeting.
/// ```dart
/// final vm = UniversalShareDialogViewModel(socialRecipeCoordinator: sl.get());
/// await vm.shareRecipe(recipe, friendUserIds: [id], message: 'Check this!');

// lib/viewmodels/universal_share_dialog_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/utils/social_content_features.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// PHASE 2: Validation result for sharing operations
class ShareValidationResult {
  final bool hasExistingCollaborators;
  final String errorMessage;
  final List<String> existingCollaboratorIds;
  final List<String> newFriendIds;
  final bool canProceed;

  const ShareValidationResult({
    required this.hasExistingCollaborators,
    required this.errorMessage,
    required this.existingCollaboratorIds,
    required this.newFriendIds,
    required this.canProceed,
  });

  /// Factory for successful validation (no existing collaborators)
  factory ShareValidationResult.success() {
    return const ShareValidationResult(
      hasExistingCollaborators: false,
      errorMessage: '',
      existingCollaboratorIds: [],
      newFriendIds: [],
      canProceed: true,
    );
  }

  /// Factory for partial success (some existing collaborators, but new friends to invite)
  factory ShareValidationResult.partialSuccess(
      List<String> newIds, List<String> existingIds) {
    final existingCount = existingIds.length;
    final newCount = newIds.length;
    final warningMessage = existingCount == 1
        ? AppLocale.current.sharePartialSuccessSingular(newCount)
        : AppLocale.current.sharePartialSuccessPlural(existingCount, newCount);

    return ShareValidationResult(
      hasExistingCollaborators: true,
      errorMessage: warningMessage,
      existingCollaboratorIds: existingIds,
      newFriendIds: newIds,
      canProceed: true,
    );
  }

  /// Factory for validation failure with existing collaborators
  factory ShareValidationResult.existingCollaborators(
      List<String> existingIds) {
    final count = existingIds.length;
    final errorMessage = count == 1
        ? AppLocale.current.errorFriendAlreadyHasAccess
        : AppLocale.current.errorAllFriendsAlreadyHaveAccess;

    return ShareValidationResult(
      hasExistingCollaborators: true,
      errorMessage: errorMessage,
      existingCollaboratorIds: existingIds,
      newFriendIds: [],
      canProceed: false,
    );
  }
}

/// Comprehensive universal sharing dialog ViewModel providing advanced multi-content social distribution through service integration.
/// Manages universal sharing state enabling multi-content social distribution with recipe sharing, menu distribution,
/// shopping list coordination, and recipient management while maintaining clean MVVM architecture separation between
/// universal sharing business logic and UI presentation concerns through unified sharing interface.
/// **Core Responsibilities:**
/// - Advanced multi-content sharing with unified interface for recipes, menus, and shopping lists
/// - Comprehensive recipient management with friend and group targeting coordination
/// - Cross-service integration with social recipe and shopping services for content distribution
/// - Complete sharing state management with progress tracking and comprehensive error handling
/// - Swedish localized error messages and user feedback coordination throughout sharing operations
class UniversalShareDialogViewModel extends ChangeNotifier
    with StreamManagementMixin {
  final SocialRecipeCoordinator _socialRecipeCoordinator;
  final UnifiedShoppingService _shoppingService;

  /// Share operation state for UI progress indication during sharing operations.
  /// Indicates active sharing operation for loading indicators and interaction
  /// control during content distribution and delivery processes.
  bool _isSharing = false;

  /// Error message for user feedback and comprehensive error state management.
  /// Provides localized error messages for user display and error recovery
  /// throughout universal sharing operations and content distribution.
  String? _errorMessage;

  /// Initializes universal share dialog ViewModel with comprehensive service integration and sharing preparation.
  /// [socialRecipeCoordinator] SocialRecipeCoordinator instance for recipe and menu sharing operations
  /// [shoppingService] UnifiedShoppingService instance for shopping list sharing coordination
  /// Establishes universal sharing infrastructure with multi-service integration, enabling comprehensive
  /// social content distribution functionality with recipe sharing, menu distribution, shopping list coordination,
  /// and recipient management through unified sharing interface and consistent operation patterns.
  /// **Service Integration:**
  /// - SocialRecipeCoordinator integration for recipe and menu sharing with social distribution
  /// - UnifiedShoppingService integration for shopping list sharing and collaborative coordination
  /// - Cross-service sharing coordination for consistent user experience across content types
  /// - Unified error handling and state management across different sharing operations
  UniversalShareDialogViewModel({
    required SocialRecipeCoordinator socialRecipeCoordinator,
    required UnifiedShoppingService shoppingService,
  })  : _socialRecipeCoordinator = socialRecipeCoordinator,
        _shoppingService = shoppingService;

  /// Share operation state for UI progress indication and interaction control.
  /// Indicates whether sharing operation is in progress for loading indicators
  /// and user interaction management during sharing operations.
  bool get isSharing => _isSharing;

  /// Error message for user feedback and comprehensive error state management.
  /// Provides access to current error state enabling error display
  /// and recovery coordination throughout universal sharing operations.
  String? get errorMessage => _errorMessage;

  /// Error state indicator for UI conditional rendering and error handling.
  /// Indicates presence of errors for UI error display decisions
  /// and error state management throughout sharing operations.
  bool get hasError => _errorMessage != null;

  /// Share a recipe with selected friends and groups
  Future<bool> shareRecipe({
    required Recipe recipe,
    required List<String> friendUserIds,
    List<String>? groupIds,
    String? message,
    bool allowCollaboration = false,
  }) async {
    if (friendUserIds.isEmpty && (groupIds?.isEmpty ?? true)) {
      _setError(AppLocale.current.errorNoFriendsOrGroupsSelected);
      return false;
    }

    _setSharing(true);
    _clearError();

    try {
      // Share to friends if any selected
      if (friendUserIds.isNotEmpty) {
        final success = await _socialRecipeCoordinator.shareRecipeWithFriends(
          recipeId: recipe.id,
          friendIds: friendUserIds,
          message: message,
          allowCollaboration: allowCollaboration,
        );
        if (!success) {
          _setError(AppLocale.current.errorCouldNotUpdate('delning'));
          return false;
        }
      }

      // Share to groups if any selected
      if (groupIds != null && groupIds.isNotEmpty) {
        final permission = allowCollaboration
            ? ResourcePermission.editor
            : ResourcePermission.read;
        final groupSuccess =
            await _socialRecipeCoordinator.shareRecipeWithGroups(
          recipe.id,
          groupIds,
          permission,
        );
        if (!groupSuccess) {
          _setError(AppLocale.current.errorCouldNotUpdate('gruppdelning'));
          return false;
        }
      }

      return true;
    } catch (e) {
      _setError(AppLocale.current.errorCouldNotUpdate('recept'));
      return false;
    } finally {
      _setSharing(false);
    }
  }

  /// Share a menu with selected friends and groups using UnifiedMenuService invitation system
  Future<bool> shareMenu({
    required Map<String, List<Recipe>> menu,
    String? menuName,
    required List<String> friendUserIds,
    List<String>? groupIds,
    String? menuId,
    String? message,
    bool allowCollaboration = false,
  }) async {
    if (friendUserIds.isEmpty && (groupIds?.isEmpty ?? true)) {
      _setError(AppLocale.current.errorNoFriendsOrGroupsSelected);
      return false;
    }

    _setSharing(true);
    _clearError();

    try {
      // Get menu service for invitation system
      final menuService = ServiceLocator.get<UnifiedMenuService>();
      final friendsService = ServiceLocator.get<UnifiedFriendsService>();

      // Use provided menu name or generate from menu content
      final menuTitle = menuName ?? _generateMenuTitle(menu);

      // Collect all recipient user IDs (friends + resolved group members)
      final allRecipientIds = <String>{...friendUserIds};

      // Resolve group members to user IDs
      if (groupIds != null && groupIds.isNotEmpty) {
        for (final groupId in groupIds) {
          final group = friendsService.getCategoryByIdInternal(groupId);
          if (group != null) {
            allRecipientIds.addAll(group.friendUserIds);
            AppLogger.info(
                '📋 Resolved group "${group.name}" to ${group.friendUserIds.length} members');
          } else {
            AppLogger.warning('⚠️ Group $groupId not found');
          }
        }
      }

      if (allRecipientIds.isEmpty) {
        _setError(AppLocale.current.errorNoRecipientsFound);
        return false;
      }

      AppLogger.info(
          '📨 Creating menu invitation for ${allRecipientIds.length} recipients');
      AppLogger.info(
          '   Friends: ${friendUserIds.length}, Groups: ${groupIds?.length ?? 0}');
      AppLogger.info('   Total unique recipients: ${allRecipientIds.length}');

      // Use UnifiedMenuService to create invitation (writes to shared_menus collection)
      final success = await menuService.shareMenuWithFriends(
        menuTitle: menuTitle,
        menuSnapshot: menu,
        friendIds: allRecipientIds.toList(),
        message: message,
        allowCollaboration: allowCollaboration,
      );

      if (success) {
        final totalTargets = friendUserIds.length + (groupIds?.length ?? 0);
        AppLogger.success('✅ Menu invitation created successfully');
        AppLogger.info('📥 Recipients will see menu in group shared content');
        AppLogger.success(
            'Menu shared with $totalTargets targets (${friendUserIds.length} friends, ${groupIds?.length ?? 0} groups)');
        return true;
      } else {
        throw Exception('Failed to create menu invitation');
      }
    } catch (e) {
      _setError(AppLocale.current.errorCouldNotUpdate('meny'));
      AppLogger.error('Failed to share menu: $e');
      return false;
    } finally {
      _setSharing(false);
    }
  }

  /// Share a shopping list with selected friends and groups
  Future<bool> shareShoppingList({
    required UnifiedShoppingList shoppingList,
    required List<String> friendUserIds,
    List<String>? groupIds,
    String? message,
    ShareMode shareMode = ShareMode.staticCopy,
  }) async {
    if (friendUserIds.isEmpty && (groupIds?.isEmpty ?? true)) {
      _setError(AppLocale.current.errorNoFriendsOrGroupsSelected);
      return false;
    }

    // PHASE 2: Validate sharing targets and filter existing collaborators
    final validationResult =
        _validateSharingTargets(shoppingList, friendUserIds);
    if (!validationResult.canProceed) {
      _setError(validationResult.errorMessage);
      return false;
    }

    // Use filtered friends list (exclude existing collaborators)
    final filteredFriendUserIds = validationResult.newFriendIds.isNotEmpty
        ? validationResult.newFriendIds
        : friendUserIds;

    _setSharing(true);
    _clearError();

    try {
      final totalTargets =
          filteredFriendUserIds.length + (groupIds?.length ?? 0);
      final modeText =
          shareMode == ShareMode.realtime ? 'kollaborativ lista' : 'kopia';

      AppLogger.info(
        '📋 Delar inköpslista: ${shoppingList.name} som $modeText med $totalTargets mottagare (${filteredFriendUserIds.length} vänner, ${groupIds?.length ?? 0} grupper)',
      );

      // Show info about validation results
      if (validationResult.hasExistingCollaborators) {
        AppLogger.info(
            '⚠️ ${validationResult.existingCollaboratorIds.length} friends skipped (already have access)');
      }

      if (message != null) {
        AppLogger.info('💬 Meddelande: $message');
      }

      // Handle collaborative sharing for realtime mode - USE INVITATION SYSTEM
      if (shareMode == ShareMode.realtime) {
        // Use invitation system with filtered friends
        final success = await SocialContentFeatures.shareContentWithFriends(
          shoppingList.id,
          'shopping_list',
          filteredFriendUserIds,
          message ?? AppLocale.current.shareDefaultShoppingListMessage,
          _shoppingService,
        );

        if (success) {
          // Set success message that includes info about skipped friends
          if (validationResult.hasExistingCollaborators) {
            final invitedCount = filteredFriendUserIds.length;
            final skippedCount =
                validationResult.existingCollaboratorIds.length;
            _setError(AppLocale.current
                .shareInvitationsSentWithSkipped(invitedCount, skippedCount));
          }

          return true;
        } else {
          throw Exception(AppLocale.current.errorCouldNotSendInvitations);
        }
      } else {
        // Handle traditional copy-based sharing with filtered friends
        // Use invitation system for copy mode (replaces broken shareListWithFriend)
        final success = await SocialContentFeatures.shareContentWithFriends(
          shoppingList.id,
          'shopping_list',
          filteredFriendUserIds,
          message ?? AppLocale.current.shareDefaultShoppingListMessage,
          _shoppingService,
        );

        // Share to groups if any selected
        // Group copy-sharing is not yet implemented.
        // Friend sharing works; group support deferred.
        if (groupIds != null && groupIds.isNotEmpty) {
          AppLogger.warning(
              '⚠️ COPY MODE: Group sharing not yet implemented for copy mode');
          // For now, just log this - group sharing would need similar invitation system
        }

        if (success) {
          AppLogger.success(
              '✅ COPY MODE FIX: Inköpslista invitations sent successfully via invitation system');
          return true;
        } else {
          throw Exception(AppLocale.current.errorCouldNotSendInvitations);
        }
      }
    } catch (e) {
      _setError(AppLocale.current
          .errorCouldNotUpdate(AppLocale.current.nounShoppingList));
      return false;
    } finally {
      _setSharing(false);
    }
  }

  /// Share a personal tag with selected friends by creating a shared snapshot.
  ///
  /// The tag is shared as a link-based static snapshot. Recipients receive a
  /// notification and can import the tag definition into their own collection.
  Future<bool> sharePersonalTag({
    required String tagId,
    required String tagName,
    required List<String> friendUserIds,
    List<String>? groupIds,
    String? message,
  }) async {
    if (friendUserIds.isEmpty && (groupIds?.isEmpty ?? true)) {
      _setError(AppLocale.current.errorNoFriendsOrGroupsSelected);
      return false;
    }

    _setSharing(true);
    _clearError();

    try {
      final personalTagService = ServiceLocator.get<PersonalTagService>();
      final shareId = await personalTagService.shareTag(
        tagId,
        recipientUserIds: friendUserIds,
      );

      if (shareId == null) {
        throw Exception(AppLocale.current
            .errorCouldNotCreate(AppLocale.current.nounShareLink));
      }

      AppLogger.info(
        'Personal tag "$tagName" shared with ID: $shareId to ${friendUserIds.length} friends',
      );

      // Send notification to recipients
      try {
        final notificationService = ServiceLocator.get<NotificationService>();
        final userService = ServiceLocator.get<UserService>();
        final senderName = userService.currentUserProfile?.displayName ?? '';
        await notificationService.sendImmediateNotification(
          targetUserIds: friendUserIds,
          strategy: NotificationStrategy.tagShared,
          variables: {'senderName': senderName, 'tagName': tagName},
          additionalData: {'shareId': shareId, 'type': 'shared_tag'},
        );
      } catch (e) {
        AppLogger.warning('Failed to send tag share notification: $e');
      }

      return true;
    } catch (e) {
      _setError(AppLocale.current.errorCouldNotUpdate('tagg'));
      return false;
    } finally {
      _setSharing(false);
    }
  }

  /// Clear any error messages
  void clearError() {
    _clearError();
  }

  // Private methods
  void _setSharing(bool value) {
    _isSharing = value;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Generate a descriptive menu title based on menu content
  String _generateMenuTitle(Map<String, List<Recipe>> menu) {
    final recipeCount =
        menu.values.fold<int>(0, (sum, recipes) => sum + recipes.length);
    final dayCount = menu.keys.length;

    // Create a descriptive title like "Veckans meny (5 dagar, 12 recept)"
    if (dayCount == 7) {
      return 'Veckans meny ($recipeCount recept)';
    } else if (dayCount == 1) {
      return 'Dagens meny ($recipeCount recept)';
    } else {
      return 'Meny ($dayCount dagar, $recipeCount recept)';
    }
  }

  /// PHASE 2: Validate sharing targets to filter existing collaborators but allow new friends
  ShareValidationResult _validateSharingTargets(
      UnifiedShoppingList shoppingList, List<String> friendUserIds) {
    // Get existing collaborators from the shopping list
    final existingCollaborators = shoppingList.collaborators.toSet();

    // Find friends who are already collaborators
    final existingCollaboratorIds = friendUserIds
        .where((friendId) => existingCollaborators.contains(friendId))
        .toList();

    // Find friends who are NOT already collaborators (new friends to invite)
    final newFriendIds = friendUserIds
        .where((friendId) => !existingCollaborators.contains(friendId))
        .toList();

    AppLogger.info(
        '🔍 VALIDATION: Analyzing ${friendUserIds.length} selected friends for list "${shoppingList.name}"');
    AppLogger.info(
        '📊 VALIDATION: Existing collaborators: ${existingCollaboratorIds.length}, New friends: ${newFriendIds.length}');

    if (existingCollaboratorIds.isNotEmpty) {
      AppLogger.info(
          '⚠️ VALIDATION: ${existingCollaboratorIds.length} friends already have access: $existingCollaboratorIds');
    }

    if (newFriendIds.isEmpty) {
      // All selected friends are already collaborators
      AppLogger.warning(
          '🚫 VALIDATION: All selected friends already have access to this list');
      return ShareValidationResult.existingCollaborators(
          existingCollaboratorIds);
    }

    if (existingCollaboratorIds.isNotEmpty) {
      // Some friends already have access, but we have new friends to invite
      AppLogger.info(
          '✅ VALIDATION: Will invite ${newFriendIds.length} new friends and skip ${existingCollaboratorIds.length} existing collaborators');
      return ShareValidationResult.partialSuccess(
          newFriendIds, existingCollaboratorIds);
    }

    // All friends are new
    AppLogger.info(
        '✅ VALIDATION: All selected friends are new - sharing can proceed with all ${newFriendIds.length} friends');
    return ShareValidationResult.success();
  }

  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions
    // Dispose of resources
    disposeStreamResources(); // From StreamManagementMixin
    super.dispose();
  }
}
