/// Social Sharing ViewModel providing unified friend selection and content sharing functionality.
///
/// This cross-cutting ViewModel handles social sharing operations across all shared content types
/// (recipes, menus, shopping lists) with friend management, sharing coordination, and
/// social interaction tracking. It implements the Strategy pattern to handle different
/// sharing behaviors per content type while maintaining consistent social UI.
///
/// **Responsibilities:**
/// - **Friend Management**: Load, select, and manage friends for sharing operations
/// - **Share Coordination**: Handle sharing across different content types with appropriate logic
/// - **Social State**: Track sharing status, selected friends, and sharing progress
/// - **Message Management**: Handle custom sharing messages and social context
/// - **Notification Integration**: Coordinate sharing notifications and social alerts
///
/// **Integration Points:**
/// - **UnifiedFriendsService**: For friend data loading and management
/// - **Social Coordinators**: Delegates to content-specific coordinators for sharing
/// - **Content ViewModels**: Coordinates with content ViewModels for sharing operations
/// - **UI Components**: Provides social state management for sharing UI components
///
/// **Usage Example:**
/// ```dart
/// final socialViewModel = SocialSharingViewModel(
///   friendsService: friendsService,
///   recipeCoordinator: recipeCoordinator,
///   menuCoordinator: menuCoordinator,
///   shoppingCoordinator: shoppingCoordinator,
/// );
/// 
/// // Load friends for sharing
/// await socialViewModel.loadFriends();
/// 
/// // Friend selection
/// socialViewModel.toggleFriendSelection('friend_123');
/// socialViewModel.updateShareMessage('Kolla in detta recept!');
/// 
/// // Share content
/// final success = await socialViewModel.shareContent(
///   contentId: 'recipe_456',
///   contentType: ContentType.recipe,
/// );
/// ```

// lib/viewmodels/shared_content/social_sharing_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/user_profile.dart';
// Removed unused imports
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/unified/modules/social_menu/social_menu_coordinator.dart';
import 'package:butlery/services/unified/modules/social_shopping/social_shopping_coordinator.dart';
import 'package:butlery/core/utils/logger.dart';

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
class SocialSharingViewModel extends ChangeNotifier {
  
  // ===== DEPENDENCIES =====
  
  final UnifiedFriendsService _friendsService;
  final SocialRecipeCoordinator _recipeCoordinator;
  final SocialMenuCoordinator _menuCoordinator;
  final SocialShoppingCoordinator _shoppingCoordinator;
  final UnifiedMenuService _menuService;
  final UnifiedShoppingService _shoppingService;

  // ===== STATE VARIABLES =====
  
  /// Available friends for sharing
  List<UserProfile> _availableFriends = [];
  
  /// Selected friend IDs for sharing
  final Set<String> _selectedFriendIds = <String>{};
  
  /// Custom share message
  String _shareMessage = '';
  
  /// Loading friends state
  bool _isLoadingFriends = false;
  
  /// Sharing in progress state
  bool _isSharing = false;
  
  /// Error message for sharing operations
  String? _error;
  
  /// Last sharing result
  SharingResult? _lastSharingResult;

  // ===== CONSTRUCTOR =====
  
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
    
    AppLogger.info('SocialSharingViewModel initialized for unified social sharing');
    _initialize();
  }

  // ===== GETTERS =====
  
  /// Available friends
  List<UserProfile> get availableFriends => List.unmodifiable(_availableFriends);
  
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
  
  /// Loading friends state
  bool get isLoadingFriends => _isLoadingFriends;
  
  /// Sharing in progress state
  bool get isSharing => _isSharing;
  
  /// Error state
  String? get error => _error;
  
  /// Has error
  bool get hasError => _error != null;
  
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
  bool get isBusy => _isLoadingFriends || _isSharing;

  // ===== INITIALIZATION =====
  
  Future<void> _initialize() async {
    await loadFriends();
  }

  // ===== FRIEND MANAGEMENT =====
  
  /// Load available friends for sharing
  Future<void> loadFriends() async {
    AppLogger.info('🔄 Loading friends for social sharing...');
    _setLoadingFriends(true);
    _clearError();
    
    try {
      // Initialize friends service if not already initialized
      if (!_friendsService.isInitialized) {
        await _friendsService.initialize();
      }
      final friends = _friendsService.friends; // Using friends getter
      _availableFriends = friends;
      AppLogger.success('✅ Loaded ${friends.length} friends for sharing');
    } catch (e) {
      _setError('Failed to load friends: $e');
      AppLogger.error('Failed to load friends: $e');
      _availableFriends = [];
    } finally {
      _setLoadingFriends(false);
    }
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

  // ===== SHARE MESSAGE MANAGEMENT =====
  
  /// Update share message
  void updateShareMessage(String message) {
    if (_shareMessage != message) {
      _shareMessage = message;
      AppLogger.info('💬 Share message updated: "${message.isEmpty ? 'EMPTY' : message}"');
      notifyListeners();
    }
  }
  
  /// Clear share message
  void clearShareMessage() {
    updateShareMessage('');
  }
  
  /// Get suggested message for content type
  String getSuggestedMessage(ShareableContentType contentType, {String? contentTitle}) {
    switch (contentType) {
      case ShareableContentType.recipe:
        if (contentTitle != null) {
          return 'Kolla in detta recept: "$contentTitle"! 👩‍🍳';
        }
        return 'Jag hittade ett fantastiskt recept som jag ville dela med dig! 👩‍🍳';
        
      case ShareableContentType.menu:
        if (contentTitle != null) {
          return 'Här är min veckomeny: "$contentTitle" 📋';
        }
        return 'Här är min veckomeny som kanske kan inspirera dig! 📋';
        
      case ShareableContentType.shoppingList:
        if (contentTitle != null) {
          return 'Vill du hjälpa mig med inköpslistan: "$contentTitle"? 🛒';
        }
        return 'Vill du hjälpa mig med inköpen denna vecka? 🛒';
    }
  }

  // ===== SHARING OPERATIONS =====
  
  /// Share content with selected friends
  Future<SharingResult> shareContent({
    required String contentId,
    required ShareableContentType contentType,
    String? customMessage,
  }) async {
    if (!canShare) {
      final error = 'Cannot share: ${!hasSelectedFriends ? 'no friends selected' : 'sharing in progress'}';
      AppLogger.error(error);
      return SharingResult.failure(error);
    }
    
    final message = customMessage ?? _shareMessage;
    final friendIds = _selectedFriendIds.toList();
    
    AppLogger.info('🚀 Starting content sharing: $contentType $contentId to ${friendIds.length} friends');
    
    _setSharing(true);
    _clearError();
    
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
        AppLogger.success('✅ Content shared successfully: ${result.invitationId}');
        // Clear selections after successful sharing
        clearFriendSelection();
        clearShareMessage();
      } else {
        _setError(result.errorMessage ?? 'Sharing failed');
        AppLogger.error('❌ Content sharing failed: ${result.errorMessage}');
      }
      
      return result;
    } catch (e) {
      final error = 'Sharing failed: $e';
      _setError(error);
      AppLogger.error('❌ Content sharing failed: $e');
      final result = SharingResult.failure(error);
      _lastSharingResult = result;
      return result;
    } finally {
      _setSharing(false);
    }
  }
  
  /// Share recipe with friends
  Future<SharingResult> _shareRecipe(String recipeId, List<String> friendIds, String message) async {
    AppLogger.info('📖 Sharing recipe $recipeId with ${friendIds.length} friends');
    
    final invitationId = await _recipeCoordinator.createRecipeInvitation(
      recipeId: recipeId,
      inviteeUserIds: friendIds,
      message: message.isNotEmpty ? message : null,
      allowCollaboration: true, // Enable copy-on-write collaboration
    );
    
    if (invitationId != null) {
      return SharingResult.success(invitationId: invitationId);
    } else {
      return SharingResult.failure('Failed to create recipe invitation');
    }
  }
  
  /// Share menu with friends
  Future<SharingResult> _shareMenu(String menuId, List<String> friendIds, String message) async {
    AppLogger.info('📋 Sharing menu $menuId with ${friendIds.length} friends');
    
    // Get menu data for sharing
    final menu = _menuService.getMenuById(menuId);
    if (menu == null) {
      return SharingResult.failure('Menu not found: $menuId');
    }
    
    final invitationId = await _menuCoordinator.createMenuInvitation(
      menuId: menuId,
      inviteeUserIds: friendIds,
      message: message.isNotEmpty ? message : null,
      allowCollaboration: true, // Enable copy-on-write collaboration
    );
    
    if (invitationId != null) {
      return SharingResult.success(invitationId: invitationId);
    } else {
      return SharingResult.failure('Failed to create menu invitation');
    }
  }
  
  /// Share shopping list with friends
  Future<SharingResult> _shareShoppingList(String listId, List<String> friendIds, String message) async {
    AppLogger.info('🛒 Sharing shopping list $listId with ${friendIds.length} friends');
    
    // Get shopping list for sharing
    final shoppingList = _shoppingService.lists.where((list) => list.id == listId).firstOrNull;
    if (shoppingList == null) {
      return SharingResult.failure('Shopping list not found: $listId');
    }
    
    final invitationId = await _shoppingCoordinator.createShoppingListInvitation(
      shoppingListId: listId,
      inviteeUserIds: friendIds,
      message: message.isNotEmpty ? message : null,
    );
    
    if (invitationId != null) {
      return SharingResult.success(invitationId: invitationId);
    } else {
      return SharingResult.failure('Failed to create shopping list invitation');
    }
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

  // ===== SHARING ANALYTICS =====
  
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
      return 'Inga vänner valda';
    }
    
    if (_selectedFriendIds.length == 1) {
      final friend = selectedFriends.first;
      return '1 vän vald: ${friend.displayName}';
    }
    
    if (_selectedFriendIds.length <= 3) {
      final names = selectedFriends.map((f) => f.displayName).join(', ');
      return '${_selectedFriendIds.length} vänner valda: $names';
    }
    
    return '${_selectedFriendIds.length} vänner valda';
  }

  // ===== STATE MANAGEMENT =====
  
  /// Set loading friends state
  void _setLoadingFriends(bool loading) {
    if (_isLoadingFriends != loading) {
      _isLoadingFriends = loading;
      notifyListeners();
    }
  }
  
  /// Set sharing state
  void _setSharing(bool sharing) {
    if (_isSharing != sharing) {
      _isSharing = sharing;
      notifyListeners();
    }
  }
  
  /// Set error message
  void _setError(String errorMessage) {
    _error = errorMessage;
    notifyListeners();
  }
  
  /// Clear error state
  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  // ===== UTILITY METHODS =====
  
  /// Reset sharing state
  void resetSharingState() {
    clearFriendSelection();
    clearShareMessage();
    _clearError();
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
    final suggestedMessage = getSuggestedMessage(contentType, contentTitle: contentTitle);
    updateShareMessage(suggestedMessage);
    
    AppLogger.info('🎯 Prepared for sharing $contentType${contentTitle != null ? ' "$contentTitle"' : ''}');
  }

  // ===== CLEANUP =====
  
  @override
  void dispose() {
    _selectedFriendIds.clear();
    AppLogger.info('SocialSharingViewModel disposed');
    super.dispose();
  }
}