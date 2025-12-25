/// Universal share dialog ViewModel for multi-content sharing (recipes, menus, shopping lists) with friend/group targeting.
/// ```dart
/// final vm = UniversalShareDialogViewModel(socialRecipeService: sl.get());
/// await vm.shareRecipe(recipe, friendUserIds: [id], message: 'Check this!');

// lib/viewmodels/universal_share_dialog_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';
import 'package:butlery/utils/social_content_features.dart';
import 'package:butlery/core/providers/application_provider.dart';

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
        ? 'En vän har redan tillgång. $newCount nya inbjudningar kommer skickas.'
        : '$existingCount vänner har redan tillgång. $newCount nya inbjudningar kommer skickas.';

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
        ? 'Den valda vännen har redan tillgång till listan'
        : 'Alla valda vänner har redan tillgång till listan';

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
  final SocialRecipeService _socialRecipeService;
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
  /// [socialRecipeService] SocialRecipeService instance for recipe and menu sharing operations
  /// [shoppingService] UnifiedShoppingService instance for shopping list sharing coordination
  /// Establishes universal sharing infrastructure with multi-service integration, enabling comprehensive
  /// social content distribution functionality with recipe sharing, menu distribution, shopping list coordination,
  /// and recipient management through unified sharing interface and consistent operation patterns.
  /// **Service Integration:**
  /// - SocialRecipeService integration for recipe and menu sharing with social distribution
  /// - UnifiedShoppingService integration for shopping list sharing and collaborative coordination
  /// - Cross-service sharing coordination for consistent user experience across content types
  /// - Unified error handling and state management across different sharing operations
  UniversalShareDialogViewModel({
    required SocialRecipeService socialRecipeService,
    required UnifiedShoppingService shoppingService,
  })  : _socialRecipeService = socialRecipeService,
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
      _setError('Inga vänner eller grupper valda');
      return false;
    }

    _setSharing(true);
    _clearError();

    try {
      // Share to friends if any selected
      if (friendUserIds.isNotEmpty) {
        await _socialRecipeService.shareRecipeToFriends(
          recipe.id,
          friendUserIds,
        );
      }

      // Share to groups if any selected
      if (groupIds != null && groupIds.isNotEmpty) {
        await _socialRecipeService.shareRecipeToGroups(
          recipe.id,
          groupIds,
        );
      }

      return true;
    } catch (e) {
      _setError('Kunde inte dela recept: $e');
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
    AppLogger.info('🔍🔍🔍 DEBUG VIEWMODEL: shareMenu() CALLED');
    AppLogger.info(
        '🔍 DEBUG: friendUserIds = $friendUserIds (${friendUserIds.length} items)');
    AppLogger.info('🔍 DEBUG: groupIds = $groupIds');
    AppLogger.info('🔍 DEBUG: menuName = $menuName');

    if (friendUserIds.isEmpty && (groupIds?.isEmpty ?? true)) {
      AppLogger.warning(
          '🔍 DEBUG: Early return - no friends or groups selected!');
      _setError('Inga vänner eller grupper valda');
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
        _setError('Inga mottagare hittades');
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
      _setError('Kunde inte dela meny: $e');
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
      _setError('Inga vänner eller grupper valda');
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
        // ULTRATHINK FIX: Use invitation system with filtered friends
        final success = await SocialContentFeatures.shareContentWithFriends(
          shoppingList.id,
          'shopping_list',
          filteredFriendUserIds,
          message ?? 'Vill dela denna inköpslista med dig!',
          _shoppingService,
        );

        if (success) {
          // Set success message that includes info about skipped friends
          if (validationResult.hasExistingCollaborators) {
            final invitedCount = filteredFriendUserIds.length;
            final skippedCount =
                validationResult.existingCollaboratorIds.length;
            _setError(
                '$invitedCount inbjudningar skickade. $skippedCount vänner hoppades över (har redan tillgång).');
          }

          return true;
        } else {
          throw Exception('Kunde inte skicka inbjudningar');
        }
      } else {
        // Handle traditional copy-based sharing with filtered friends
        // ULTRATHINK FIX: Use invitation system for copy mode too instead of broken shareListWithFriend
        final success = await SocialContentFeatures.shareContentWithFriends(
          shoppingList.id,
          'shopping_list',
          filteredFriendUserIds,
          message ?? 'Vill dela denna inköpslista med dig!',
          _shoppingService,
        );

        // Share to groups if any selected
        // FIXME(Phase 6 - Social Features): Implement group invitations for copy mode
        //   - Extend invitation system to support group sharing
        //   - Add group member notification system
        //   - Update UI to show group share status
        //   - Priority: Medium (friend sharing works, groups are less common use case)
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
          throw Exception('Kunde inte skicka inbjudningar');
        }
      }
    } catch (e) {
      _setError('Kunde inte dela inköpslista: $e');
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
