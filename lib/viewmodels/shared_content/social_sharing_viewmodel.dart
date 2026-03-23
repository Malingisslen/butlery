/// Unified friend selection and social sharing across recipes, menus, and shopping lists.
/// Handles friend management, sharing coordination, and social interaction tracking
/// with content-specific delegation to Social Coordinators.

// lib/viewmodels/shared_content/social_sharing_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/error_sanitizer.dart';
import 'package:butlery/models/user_profile.dart';
// Removed unused imports
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/unified/modules/social_menu/social_menu_coordinator.dart';
import 'package:butlery/services/unified/modules/social_shopping/social_shopping_coordinator.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';

/// Enumeration for shareable content types
enum ShareableContentType {
  recipe,
  menu,
  shoppingList,
}

/// Social sharing operation result
class SharingResult {
  final bool success;
  final String? invitationId;
  final String? errorMessage;

  const SharingResult({
    required this.success,
    this.invitationId,
    this.errorMessage,
  });

  factory SharingResult.success({String? invitationId}) {
    return SharingResult(success: true, invitationId: invitationId);
  }

  factory SharingResult.failure(String errorMessage) {
    return SharingResult(success: false, errorMessage: errorMessage);
  }
}

/// Social sharing ViewModel for unified friend selection and content sharing
class SocialSharingViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  final UnifiedFriendsService _friendsService;
  final SocialRecipeCoordinator _recipeCoordinator;
  final SocialMenuCoordinator _menuCoordinator;
  final SocialShoppingCoordinator _shoppingCoordinator;
  final UnifiedMenuService _menuService;
  final UnifiedShoppingService _shoppingService;

  /// Available friends for sharing
  List<UserProfile> _availableFriends = [];

  /// Selected friend IDs for sharing
  final Set<String> _selectedFriendIds = <String>{};

  /// Custom share message
  String _shareMessage = '';

  // isLoading and error provided by AsyncOperationMixin

  /// Sharing in progress state (operation-specific)
  bool _isSharing = false;

  /// Last sharing result
  SharingResult? _lastSharingResult;

  SocialSharingViewModel({
    required UnifiedFriendsService friendsService,
    required SocialRecipeCoordinator recipeCoordinator,
    required SocialMenuCoordinator menuCoordinator,
    required SocialShoppingCoordinator shoppingCoordinator,
    required UnifiedMenuService menuService,
    required UnifiedShoppingService shoppingService,
  })  : _friendsService = friendsService,
        _recipeCoordinator = recipeCoordinator,
        _menuCoordinator = menuCoordinator,
        _shoppingCoordinator = shoppingCoordinator,
        _menuService = menuService,
        _shoppingService = shoppingService {
    AppLogger.info(
        'SocialSharingViewModel initialized for unified social sharing');
    _initialize();
  }

  /// Available friends
  List<UserProfile> get availableFriends =>
      List.unmodifiable(_availableFriends);

  /// Selected friend IDs
  Set<String> get selectedFriendIds => Set.unmodifiable(_selectedFriendIds);

  /// Selected friends profiles
  List<UserProfile> get selectedFriends {
    return _availableFriends
        .where((friend) => _selectedFriendIds.contains(friend.uid))
        .toList();
  }

  /// Share message
  String get shareMessage => _shareMessage;

  // isLoading and error getters provided by AsyncOperationMixin

  /// Sharing in progress state (operation-specific)
  bool get isSharing => _isSharing;

  /// Last sharing result
  SharingResult? get lastSharingResult => _lastSharingResult;

  /// Has friends available
  bool get hasFriends => _availableFriends.isNotEmpty;

  /// Has selected friends
  bool get hasSelectedFriends => _selectedFriendIds.isNotEmpty;

  /// Selected friends count
  int get selectedFriendsCount => _selectedFriendIds.length;

  /// Can share (has selected friends and not currently sharing)
  bool get canShare => hasSelectedFriends && !_isSharing;

  /// Friends loading or sharing in progress
  bool get isBusy => isLoading || _isSharing;

  Future<void> _initialize() async {
    await loadFriends();
  }

  /// Load available friends for sharing
  Future<void> loadFriends() async {
    AppLogger.info('🔄 Loading friends for social sharing...');

    await executeAsync(() async {
      // Initialize friends service if not already initialized
      if (!_friendsService.isInitialized) {
        await _friendsService.initialize();
      }
      final friends = _friendsService.friends; // Using friends getter
      _availableFriends = friends;
      AppLogger.success('✅ Loaded ${friends.length} friends for sharing');
    });
  }

  /// Refresh friends list
  Future<void> refreshFriends() async {
    AppLogger.info('🔄 Refreshing friends list...');
    await loadFriends();
  }

  /// Toggle friend selection
  void toggleFriendSelection(String friendId) {
    if (_selectedFriendIds.contains(friendId)) {
      _selectedFriendIds.remove(friendId);
      AppLogger.info('➖ Deselected friend: $friendId');
    } else {
      _selectedFriendIds.add(friendId);
      AppLogger.info('➕ Selected friend: $friendId');
    }

    notifyListeners();
  }

  /// Select all friends
  void selectAllFriends() {
    final previousCount = _selectedFriendIds.length;
    _selectedFriendIds.addAll(_availableFriends.map((friend) => friend.uid));

    if (_selectedFriendIds.length != previousCount) {
      AppLogger.info('✅ Selected all ${_availableFriends.length} friends');
      notifyListeners();
    }
  }

  /// Clear friend selection
  void clearFriendSelection() {
    if (_selectedFriendIds.isNotEmpty) {
      _selectedFriendIds.clear();
      AppLogger.info('🧹 Cleared friend selection');
      notifyListeners();
    }
  }

  /// Check if friend is selected
  bool isFriendSelected(String friendId) {
    return _selectedFriendIds.contains(friendId);
  }

  /// Update share message
  void updateShareMessage(String message) {
    if (_shareMessage != message) {
      _shareMessage = message;
      AppLogger.info(
          '💬 Share message updated: "${message.isEmpty ? 'EMPTY' : message}"');
      notifyListeners();
    }
  }

  /// Clear share message
  void clearShareMessage() {
    updateShareMessage('');
  }

  /// Get suggested message for content type
  String getSuggestedMessage(ShareableContentType contentType,
      {String? contentTitle}) {
    switch (contentType) {
      case ShareableContentType.recipe:
        if (contentTitle != null) {
          return AppLocale.current.shareMessageRecipeWithTitle(contentTitle);
        }
        return AppLocale.current.shareMessageRecipeDefault;

      case ShareableContentType.menu:
        if (contentTitle != null) {
          return AppLocale.current.shareMessageMenuWithTitle(contentTitle);
        }
        return AppLocale.current.shareMessageMenuDefault;

      case ShareableContentType.shoppingList:
        if (contentTitle != null) {
          return AppLocale.current
              .shareMessageShoppingListWithTitle(contentTitle);
        }
        return AppLocale.current.shareMessageShoppingListDefault;
    }
  }

  /// Share content with selected friends
  Future<SharingResult> shareContent({
    required String contentId,
    required ShareableContentType contentType,
    String? customMessage,
  }) async {
    if (!canShare) {
      final error =
          'Cannot share: ${!hasSelectedFriends ? 'no friends selected' : 'sharing in progress'}';
      AppLogger.error(error);
      return SharingResult.failure(error);
    }

    final message = customMessage ?? _shareMessage;
    final friendIds = _selectedFriendIds.toList();

    AppLogger.info(
        '🚀 Starting content sharing: $contentType $contentId to ${friendIds.length} friends');

    _setSharing(true);
    clearError(); // From StateNotifierMixin

    try {
      SharingResult result;

      switch (contentType) {
        case ShareableContentType.recipe:
          result = await _shareRecipe(contentId, friendIds, message);
          break;
        case ShareableContentType.menu:
          result = await _shareMenu(contentId, friendIds, message);
          break;
        case ShareableContentType.shoppingList:
          result = await _shareShoppingList(contentId, friendIds, message);
          break;
      }

      _lastSharingResult = result;

      if (result.success) {
        AppLogger.success(
            '✅ Content shared successfully: ${result.invitationId}');
        // Clear selections after successful sharing
        clearFriendSelection();
        clearShareMessage();
      } else {
        setError(result.errorMessage ?? AppLocale.current.errorGeneric);
        AppLogger.error('❌ Content sharing failed: ${result.errorMessage}');
      }

      return result;
    } catch (e) {
      setError(sanitizeErrorForUser(e));
      AppLogger.error('❌ Content sharing failed: $e');
      final result = SharingResult.failure(sanitizeErrorForUser(e));
      _lastSharingResult = result;
      return result;
    } finally {
      _setSharing(false);
    }
  }

  /// Share recipe with friends
  Future<SharingResult> _shareRecipe(
      String id, List<String> friendIds, String message) async {
    AppLogger.info('📖 Sharing recipe $id with ${friendIds.length} friends');
    return await _shareWithCoordinator(
      () async => await _recipeCoordinator.createRecipeInvitation(
        recipeId: id,
        inviteeUserIds: friendIds,
        message: message.isNotEmpty ? message : null,
        allowCollaboration: true,
      ),
      'recipe',
    );
  }

  /// Share menu with friends
  Future<SharingResult> _shareMenu(
      String id, List<String> friendIds, String message) async {
    AppLogger.info('📋 Sharing menu $id with ${friendIds.length} friends');
    if (_menuService.getMenuById(id) == null) {
      return SharingResult.failure('Menu not found: $id');
    }
    return await _shareWithCoordinator(
      () async => await _menuCoordinator.createMenuInvitation(
        menuId: id,
        inviteeUserIds: friendIds,
        message: message.isNotEmpty ? message : null,
        allowCollaboration: true,
      ),
      'menu',
    );
  }

  /// Share shopping list with friends
  Future<SharingResult> _shareShoppingList(
      String id, List<String> friendIds, String message) async {
    AppLogger.info(
        '🛒 Sharing shopping list $id with ${friendIds.length} friends');
    if (_shoppingService.lists.where((list) => list.id == id).firstOrNull ==
        null) {
      return SharingResult.failure('Shopping list not found: $id');
    }
    return await _shareWithCoordinator(
      () async => await _shoppingCoordinator.createShoppingListInvitation(
        shoppingListId: id,
        inviteeUserIds: friendIds,
        message: message.isNotEmpty ? message : null,
      ),
      'shopping list',
    );
  }

  /// Generic sharing helper with coordinator
  Future<SharingResult> _shareWithCoordinator(
    Future<String?> Function() createInvitation,
    String contentTypeName,
  ) async {
    final invitationId = await createInvitation();
    return invitationId != null
        ? SharingResult.success(invitationId: invitationId)
        : SharingResult.failure('Failed to create $contentTypeName invitation');
  }

  /// Quick share with default message
  Future<SharingResult> quickShare({
    required String contentId,
    required ShareableContentType contentType,
    String? contentTitle,
  }) async {
    if (!hasSelectedFriends) {
      return SharingResult.failure('No friends selected for sharing');
    }

    // Use suggested message if no custom message set
    final message = _shareMessage.isEmpty
        ? getSuggestedMessage(contentType, contentTitle: contentTitle)
        : _shareMessage;

    return await shareContent(
      contentId: contentId,
      contentType: contentType,
      customMessage: message,
    );
  }

  /// Get sharing statistics
  Map<String, dynamic> getSharingStats() {
    return {
      'totalFriends': _availableFriends.length,
      'selectedFriends': _selectedFriendIds.length,
      'hasCustomMessage': _shareMessage.isNotEmpty,
      'canShare': canShare,
      'isSharing': _isSharing,
      'lastResult': _lastSharingResult?.success,
    };
  }

  /// Get friend selection summary
  String getFriendSelectionSummary() {
    if (_selectedFriendIds.isEmpty) {
      return AppLocale.current.selectionNoFriendsSelected;
    }

    if (_selectedFriendIds.length == 1) {
      final friend = selectedFriends.first;
      return AppLocale.current
          .selectionFriendSelectedWithName(friend.displayName);
    }

    if (_selectedFriendIds.length <= 3) {
      final names = selectedFriends.map((f) => f.displayName).join(', ');
      return AppLocale.current
          .selectionFriendsSelectedWithNames(_selectedFriendIds.length, names);
    }

    return AppLocale.current
        .selectionFriendsSelectedCount(_selectedFriendIds.length);
  }

  /// Set sharing state (operation-specific)
  void _setSharing(bool sharing) {
    if (_isSharing != sharing) {
      _isSharing = sharing;
      notifyListeners();
    }
  }

  /// Reset sharing state
  void resetSharingState() {
    clearFriendSelection();
    clearShareMessage();
    clearError(); // From StateNotifierMixin
    _lastSharingResult = null;
    AppLogger.info('🧹 Sharing state reset');
    notifyListeners();
  }

  /// Prepare for sharing specific content
  void prepareForSharing({
    required ShareableContentType contentType,
    String? contentTitle,
    List<String>? suggestedFriends,
  }) {
    // Reset previous state
    resetSharingState();

    // Pre-select suggested friends if provided
    if (suggestedFriends != null) {
      for (final friendId in suggestedFriends) {
        if (_availableFriends.any((f) => f.uid == friendId)) {
          _selectedFriendIds.add(friendId);
        }
      }
    }

    // Set suggested message
    final suggestedMessage =
        getSuggestedMessage(contentType, contentTitle: contentTitle);
    updateShareMessage(suggestedMessage);

    AppLogger.info(
        '🎯 Prepared for sharing $contentType${contentTitle != null ? ' "$contentTitle"' : ''}');
  }

  @override
  void dispose() {
    _selectedFriendIds.clear();
    AppLogger.info('SocialSharingViewModel disposed');
    super.dispose();
  }
}
