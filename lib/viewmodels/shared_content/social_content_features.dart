// lib/viewmodels/shared_content/social_content_features.dart

import '../../../models/user_profile.dart';
import '../../../models/unified/unified_shopping_list.dart';
import '../../../services/unified/unified_friends_service.dart';
import '../../../services/unified/unified_shopping_service.dart';
import '../../../core/utils/logger.dart';

/// Focused module for social content features
/// 
/// This module handles ONLY social-related functionality:
/// - Friends management for sharing
/// - Shopping list sharing with friends
/// - Social interaction state management
/// - Friend selection and sharing workflow
/// 
/// ❌ DOES NOT CONTAIN: Content operations, recipe/menu management, search/filtering
class SocialContentFeatures {

  // ===== FRIENDS MANAGEMENT =====

  /// Load friends for sharing functionality
  static Future<List<UserProfile>> loadFriendsForSharing(
    UnifiedFriendsService friendsService,
  ) async {
    try {
      final friends = friendsService.management.getAllFriends();
      AppLogger.info('👥 Laddade ${friends.length} vänner för shopping share');
      return friends;
    } catch (e) {
      AppLogger.error('Kunde inte ladda vänner för shopping share', e);
      return [];
    }
  }

  /// Refresh friends list
  static Future<List<UserProfile>> refreshFriends(
    UnifiedFriendsService friendsService,
  ) async {
    AppLogger.info('🔄 Refreshing friends for shopping share');
    return await loadFriendsForSharing(friendsService);
  }

  // ===== FRIEND SELECTION MANAGEMENT =====

  /// Toggle friend selection for sharing
  static List<String> toggleFriendSelection(
    String friendId,
    List<String> selectedFriendIds,
  ) {
    final updatedSelection = [...selectedFriendIds];
    
    if (updatedSelection.contains(friendId)) {
      updatedSelection.remove(friendId);
    } else {
      updatedSelection.add(friendId);
    }

    AppLogger.info(
        '👤 Friend selection toggled: $friendId, selected: ${updatedSelection.length}');
    
    return updatedSelection;
  }

  /// Select all friends
  static List<String> selectAllFriends(List<UserProfile> availableFriends) {
    final allFriendIds = availableFriends.map((f) => f.uid).toList();
    AppLogger.info('👥 All friends selected: ${allFriendIds.length}');
    return allFriendIds;
  }

  /// Clear all friend selections
  static List<String> clearAllSelections() {
    AppLogger.info('🧹 All friend selections cleared');
    return [];
  }

  /// Get selected friends from available friends
  static List<UserProfile> getSelectedFriends(
    List<UserProfile> availableFriends,
    List<String> selectedFriendIds,
  ) {
    return availableFriends
        .where((friend) => selectedFriendIds.contains(friend.uid))
        .toList();
  }

  // ===== SHARING STATE VALIDATION =====

  /// Check if sharing is possible
  static bool canShareShopping(List<String> selectedFriendIds, bool isSharing) {
    return selectedFriendIds.isNotEmpty && !isSharing;
  }

  /// Generate sharing summary text
  static String getSharingSummary(
    List<UserProfile> availableFriends,
    List<String> selectedFriendIds,
  ) {
    final selectedFriends = getSelectedFriends(availableFriends, selectedFriendIds);
    final friendNames = selectedFriends.map((f) => f.displayName).join(', ');
    return 'Dela med: $friendNames';
  }

  // ===== SHOPPING LIST SHARING =====

  /// Share shopping list with selected friends
  static Future<bool> shareShoppingList(
    UnifiedShoppingList shoppingList,
    List<String> selectedFriendIds,
    String shareMessage,
    UnifiedShoppingService shoppingService,
    Function(bool sharing) setSharing,
    Function(String? error) setError,
    Function() clearSharingForm,
  ) async {
    if (selectedFriendIds.isEmpty) {
      setError('Kan inte dela - välj minst en vän');
      return false;
    }

    setSharing(true);
    setError(null);

    try {
      AppLogger.info(
          '🛒 Delar inköpslista "${shoppingList.name}" med ${selectedFriendIds.length} vänner');

      // Prepare share data for logging/tracking
      final shareData = _prepareShareData(shoppingList, shareMessage);
      AppLogger.debug('Share data prepared: ${shareData['itemCount']} items');

      // Share with each selected friend
      bool allSuccessful = true;
      for (final friendId in selectedFriendIds) {
        try {
          final success = await shoppingService.sharing.shareListWithFriend(
            shoppingList.id,
            friendId,
          );
          if (success) {
            AppLogger.info('   ✅ Delad med vän: $friendId');
          } else {
            AppLogger.error('   ❌ Misslyckades med vän $friendId', 'Sharing failed');
            allSuccessful = false;
          }
        } catch (e) {
          AppLogger.error('   ❌ Misslyckades med vän $friendId', e);
          allSuccessful = false;
        }
      }

      if (allSuccessful) {
        clearSharingForm();
        AppLogger.success('🎉 Shopping list delning slutförd framgångsrikt');
        return true;
      } else {
        setError('Vissa delningar misslyckades');
        return false;
      }
    } catch (e) {
      setError('Misslyckades med delning: $e');
      AppLogger.error('❌ Shopping list delning misslyckades', e);
      return false;
    } finally {
      setSharing(false);
    }
  }

  /// Prepare share data structure for internal tracking
  static Map<String, dynamic> _prepareShareData(
    UnifiedShoppingList shoppingList,
    String shareMessage,
  ) {
    return {
      'type': 'shopping_list',
      'listId': shoppingList.id,
      'listName': shoppingList.name,
      'itemCount': shoppingList.totalItems,
      'items': shoppingList.items
          .map((item) => {
                'name': item.name,
                'amount': item.amount,
                'unit': item.unit,
                'category': item.category,
                'bought': item.bought,
              })
          .toList(),
      'message': shareMessage.isNotEmpty
          ? shareMessage
          : 'Kolla in min inköpslista!',
      'sharedAt': DateTime.now().toIso8601String(),
    };
  }

  // ===== SHARING FORM MANAGEMENT =====

  /// Clear sharing form after successful share
  static Map<String, dynamic> clearSharingForm() {
    return {
      'shareMessage': '',
      'selectedFriendIds': <String>[],
    };
  }

  /// Update share message
  static String updateShareMessage(String message) {
    return message.trim();
  }

  // ===== SOCIAL VALIDATION =====

  /// Validate friends are available
  static bool hasFriends(List<UserProfile> availableFriends) {
    return availableFriends.isNotEmpty;
  }

  /// Validate friends are selected
  static bool hasSelectedFriends(List<String> selectedFriendIds) {
    return selectedFriendIds.isNotEmpty;
  }

  /// Get selected friends count
  static int getSelectedFriendsCount(List<String> selectedFriendIds) {
    return selectedFriendIds.length;
  }

  // ===== SOCIAL STATE UTILITIES =====

  /// Check if a specific friend is selected
  static bool isFriendSelected(String friendId, List<String> selectedFriendIds) {
    return selectedFriendIds.contains(friendId);
  }

  /// Get available friends count
  static int getAvailableFriendsCount(List<UserProfile> availableFriends) {
    return availableFriends.length;
  }

  /// Find friend by ID
  static UserProfile? findFriend(String friendId, List<UserProfile> availableFriends) {
    try {
      return availableFriends.firstWhere((friend) => friend.uid == friendId);
    } catch (e) {
      return null;
    }
  }

  /// Get friend display names for selected friends
  static List<String> getSelectedFriendNames(
    List<UserProfile> availableFriends,
    List<String> selectedFriendIds,
  ) {
    final selectedFriends = getSelectedFriends(availableFriends, selectedFriendIds);
    return selectedFriends.map((friend) => friend.displayName).toList();
  }

  // ===== SHARING WORKFLOW HELPERS =====

  /// Validate sharing prerequisites
  static String? validateSharingPrerequisites(
    UnifiedShoppingList? shoppingList,
    List<String> selectedFriendIds,
    bool isSharing,
  ) {
    if (shoppingList == null) {
      return 'Ingen inköpslista vald';
    }
    
    if (selectedFriendIds.isEmpty) {
      return 'Välj minst en vän att dela med';
    }
    
    if (isSharing) {
      return 'Delning pågår redan';
    }
    
    if (shoppingList.items.isEmpty) {
      return 'Inköpslistan är tom';
    }
    
    return null; // No validation errors
  }

  /// Get sharing status message
  static String getSharingStatusMessage(
    bool isSharing,
    List<String> selectedFriendIds,
  ) {
    if (isSharing) {
      return 'Delar med ${selectedFriendIds.length} vänner...';
    }
    
    if (selectedFriendIds.isEmpty) {
      return 'Välj vänner att dela med';
    }
    
    return 'Redo att dela med ${selectedFriendIds.length} vänner';
  }
}