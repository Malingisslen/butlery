// lib/services/unified/friends/friends_cache_service.dart

import '../../../core/cache/json_cache_helper.dart';
import '../../../models/user_profile.dart';
import '../../../models/friend_request.dart';
import '../../../models/friend_category.dart';
import '../../../models/group_invitation.dart';
import '../../../core/utils/logger.dart';

/// Friends cache service
/// 
/// Handles local caching of friends data for offline support:
/// - Friends list caching
/// - Friend requests caching
/// - Friend categories caching
/// - Group invitations caching
/// - Cache invalidation and cleanup
class FriendsCacheService {
  final JsonCacheHelper _cacheHelper;
  
  FriendsCacheService(this._cacheHelper);
  
  /// Set current user for cache operations
  void setCurrentUser(String? userId) {
    _cacheHelper.setCurrentUser(userId);
  }
  
  // ===== CACHE KEYS =====
  
  static const String _friendsKey = 'friends_list';
  static const String _incomingRequestsKey = 'incoming_friend_requests';
  static const String _outgoingRequestsKey = 'outgoing_friend_requests';
  static const String _categoriesKey = 'friend_categories';
  static const String _sentInvitationsKey = 'sent_group_invitations';
  static const String _blockedUsersKey = 'blocked_users';
  static const String _friendCategoryRelationshipsKey = 'friend_category_relationships';
  
  // ===== FRIENDS CACHING =====
  
  /// Load friends from cache
  Future<List<UserProfile>> loadFriendsFromCache() async {
    try {
      final cachedData = await _cacheHelper.loadJsonList(_friendsKey);
      if (cachedData != null) {
        return cachedData.map((json) => UserProfile.fromJson(json)).toList();
      }
    } catch (e) {
      AppLogger.error('Failed to load friends from cache: $e');
    }
    return [];
  }
  
  /// Save friends to cache
  Future<void> saveFriendsToCache(List<UserProfile> friends) async {
    try {
      final jsonList = friends.map((friend) => friend.toJson()).toList();
      await _cacheHelper.saveJsonList(_friendsKey, jsonList);
      AppLogger.debug('Friends saved to cache: ${friends.length} items');
    } catch (e) {
      AppLogger.error('Failed to save friends to cache: $e');
    }
  }
  
  /// Save single friend to cache
  Future<void> saveFriendToCache(UserProfile friend) async {
    try {
      final friends = await loadFriendsFromCache();
      final index = friends.indexWhere((f) => f.uid == friend.uid);
      
      if (index != -1) {
        friends[index] = friend;
      } else {
        friends.add(friend);
      }
      
      await saveFriendsToCache(friends);
    } catch (e) {
      AppLogger.error('Failed to save friend to cache: $e');
    }
  }
  
  /// Remove friend from cache
  Future<void> removeFriendFromCache(String friendId) async {
    try {
      final friends = await loadFriendsFromCache();
      friends.removeWhere((f) => f.uid == friendId);
      await saveFriendsToCache(friends);
    } catch (e) {
      AppLogger.error('Failed to remove friend from cache: $e');
    }
  }
  
  // ===== FRIEND REQUESTS CACHING =====
  
  /// Load incoming friend requests from cache
  Future<List<FriendRequest>> loadIncomingRequestsFromCache() async {
    try {
      final cachedData = await _cacheHelper.loadJsonList(_incomingRequestsKey);
      if (cachedData != null) {
        return cachedData.map((json) => FriendRequest.fromJson(json)).toList();
      }
    } catch (e) {
      AppLogger.error('Failed to load incoming requests from cache: $e');
    }
    return [];
  }
  
  /// Save incoming friend requests to cache
  Future<void> saveIncomingRequestsToCache(List<FriendRequest> requests) async {
    try {
      final jsonList = requests.map((request) => request.toJson()).toList();
      await _cacheHelper.saveJsonList(_incomingRequestsKey, jsonList);
      AppLogger.debug('Incoming requests saved to cache: ${requests.length} items');
    } catch (e) {
      AppLogger.error('Failed to save incoming requests to cache: $e');
    }
  }
  
  /// Load outgoing friend requests from cache
  Future<List<FriendRequest>> loadOutgoingRequestsFromCache() async {
    try {
      final cachedData = await _cacheHelper.loadJsonList(_outgoingRequestsKey);
      if (cachedData != null) {
        return cachedData.map((json) => FriendRequest.fromJson(json)).toList();
      }
    } catch (e) {
      AppLogger.error('Failed to load outgoing requests from cache: $e');
    }
    return [];
  }
  
  /// Save outgoing friend requests to cache
  Future<void> saveOutgoingRequestsToCache(List<FriendRequest> requests) async {
    try {
      final jsonList = requests.map((request) => request.toJson()).toList();
      await _cacheHelper.saveJsonList(_outgoingRequestsKey, jsonList);
      AppLogger.debug('Outgoing requests saved to cache: ${requests.length} items');
    } catch (e) {
      AppLogger.error('Failed to save outgoing requests to cache: $e');
    }
  }
  
  // ===== FRIEND CATEGORIES CACHING =====
  
  /// Load friend categories from cache
  Future<List<FriendCategory>> loadCategoriesFromCache() async {
    try {
      final cachedData = await _cacheHelper.loadJsonList(_categoriesKey);
      if (cachedData != null) {
        return cachedData.map((json) => FriendCategory.fromJson(json)).toList();
      }
    } catch (e) {
      AppLogger.error('Failed to load categories from cache: $e');
    }
    return [];
  }
  
  /// Save friend categories to cache
  Future<void> saveCategoriesToCache(List<FriendCategory> categories) async {
    try {
      final jsonList = categories.map((category) => category.toJson()).toList();
      await _cacheHelper.saveJsonList(_categoriesKey, jsonList);
      AppLogger.debug('Categories saved to cache: ${categories.length} items');
    } catch (e) {
      AppLogger.error('Failed to save categories to cache: $e');
    }
  }
  
  /// Save single category to cache
  Future<void> saveCategoryToCache(FriendCategory category) async {
    try {
      final categories = await loadCategoriesFromCache();
      final index = categories.indexWhere((c) => c.id == category.id);
      
      if (index != -1) {
        categories[index] = category;
      } else {
        categories.add(category);
      }
      
      await saveCategoriesToCache(categories);
    } catch (e) {
      AppLogger.error('Failed to save category to cache: $e');
    }
  }
  
  /// Remove category from cache
  Future<void> removeCategoryFromCache(String categoryId) async {
    try {
      final categories = await loadCategoriesFromCache();
      categories.removeWhere((c) => c.id == categoryId);
      await saveCategoriesToCache(categories);
    } catch (e) {
      AppLogger.error('Failed to remove category from cache: $e');
    }
  }
  
  // ===== GROUP INVITATIONS CACHING =====
  
  /// Load sent group invitations from cache
  Future<List<GroupInvitation>> loadSentInvitationsFromCache() async {
    try {
      final cachedData = await _cacheHelper.loadJsonList(_sentInvitationsKey);
      if (cachedData != null) {
        return cachedData.map((json) => GroupInvitation.fromJson(json)).toList();
      }
    } catch (e) {
      AppLogger.error('Failed to load sent invitations from cache: $e');
    }
    return [];
  }
  
  /// Save sent group invitations to cache
  Future<void> saveSentInvitationsToCache(List<GroupInvitation> invitations) async {
    try {
      final jsonList = invitations.map((invitation) => invitation.toJson()).toList();
      await _cacheHelper.saveJsonList(_sentInvitationsKey, jsonList);
      AppLogger.debug('Sent invitations saved to cache: ${invitations.length} items');
    } catch (e) {
      AppLogger.error('Failed to save sent invitations to cache: $e');
    }
  }
  
  // ===== BLOCKED USERS CACHING =====
  
  /// Load blocked users from cache
  Future<Set<String>> loadBlockedUsersFromCache() async {
    try {
      final cachedData = await _cacheHelper.loadJsonList(_blockedUsersKey);
      if (cachedData != null) {
        return cachedData.map((item) => item['userId'] as String).toSet();
      }
    } catch (e) {
      AppLogger.error('Failed to load blocked users from cache: $e');
    }
    return <String>{};
  }
  
  /// Save blocked users to cache
  Future<void> saveBlockedUsersToCache(Set<String> blockedUsers) async {
    try {
      await _cacheHelper.saveJsonList(_blockedUsersKey, blockedUsers.map((userId) => {'userId': userId}).toList());
      AppLogger.debug('Blocked users saved to cache: ${blockedUsers.length} items');
    } catch (e) {
      AppLogger.error('Failed to save blocked users to cache: $e');
    }
  }
  
  // ===== FRIEND-CATEGORY RELATIONSHIPS CACHING =====
  
  /// Load friend-category relationships from cache
  Future<Map<String, Set<String>>> loadFriendCategoryRelationshipsFromCache() async {
    try {
      final cachedData = await _cacheHelper.loadJson(_friendCategoryRelationshipsKey);
      if (cachedData != null) {
        final relationships = <String, Set<String>>{};
        for (final entry in cachedData.entries) {
          final friendId = entry.key;
          final categoryIds = (entry.value as List<dynamic>).cast<String>();
          relationships[friendId] = categoryIds.toSet();
        }
        return relationships;
      }
    } catch (e) {
      AppLogger.error('Failed to load friend-category relationships from cache: $e');
    }
    return <String, Set<String>>{};
  }
  
  /// Save friend-category relationships to cache
  Future<void> saveFriendCategoryRelationshipsToCache(Map<String, Set<String>> relationships) async {
    try {
      final jsonMap = <String, dynamic>{};
      for (final entry in relationships.entries) {
        jsonMap[entry.key] = entry.value.toList();
      }
      await _cacheHelper.saveJson(_friendCategoryRelationshipsKey, jsonMap);
      AppLogger.debug('Friend-category relationships saved to cache: ${relationships.length} items');
    } catch (e) {
      AppLogger.error('Failed to save friend-category relationships to cache: $e');
    }
  }
  
  // ===== CACHE MANAGEMENT =====
  
  /// Clear all friends cache
  Future<void> clearAllCache() async {
    try {
      await _cacheHelper.delete(_friendsKey);
      await _cacheHelper.delete(_incomingRequestsKey);
      await _cacheHelper.delete(_outgoingRequestsKey);
      await _cacheHelper.delete(_categoriesKey);
      await _cacheHelper.delete(_sentInvitationsKey);
      await _cacheHelper.delete(_blockedUsersKey);
      await _cacheHelper.delete(_friendCategoryRelationshipsKey);
      
      AppLogger.debug('All friends cache cleared');
    } catch (e) {
      AppLogger.error('Failed to clear friends cache: $e');
    }
  }
  
  /// Load all cached data
  Future<Map<String, dynamic>> loadAllCachedData() async {
    return {
      'friends': await loadFriendsFromCache(),
      'incomingRequests': await loadIncomingRequestsFromCache(),
      'outgoingRequests': await loadOutgoingRequestsFromCache(),
      'categories': await loadCategoriesFromCache(),
      'sentInvitations': await loadSentInvitationsFromCache(),
      'blockedUsers': await loadBlockedUsersFromCache(),
      'friendCategoryRelationships': await loadFriendCategoryRelationshipsFromCache(),
    };
  }
  
  /// Save all data to cache
  Future<void> saveAllDataToCache({
    required List<UserProfile> friends,
    required List<FriendRequest> incomingRequests,
    required List<FriendRequest> outgoingRequests,
    required List<FriendCategory> categories,
    required List<GroupInvitation> sentInvitations,
    required Set<String> blockedUsers,
    required Map<String, Set<String>> friendCategoryRelationships,
  }) async {
    await Future.wait([
      saveFriendsToCache(friends),
      saveIncomingRequestsToCache(incomingRequests),
      saveOutgoingRequestsToCache(outgoingRequests),
      saveCategoriesToCache(categories),
      saveSentInvitationsToCache(sentInvitations),
      saveBlockedUsersToCache(blockedUsers),
      saveFriendCategoryRelationshipsToCache(friendCategoryRelationships),
    ]);
  }
}