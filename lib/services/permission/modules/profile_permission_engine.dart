// lib/services/permission/modules/profile_permission_engine.dart

import '../../unified/unified_friends_service.dart';
import '../../../models/user_profile.dart';
import '../../../models/permissions/resource_permission.dart';
import '../../../core/utils/logger.dart';
import 'auth_permission_engine.dart';

/// Focused module for profile permission engine
/// 
/// This module handles ONLY profile/social permission operations:
/// - Profile viewing and editing permissions
/// - Friend request management permissions
/// - User blocking and communication permissions
/// - Social interaction validation
/// 
/// ❌ DOES NOT CONTAIN: Recipes, shopping lists, groups, auth logic
class ProfilePermissionEngine {
  final AuthPermissionEngine _authEngine;
  final UnifiedFriendsService _friendsService;
  final Map<String, bool> _profilePermissionCache = {};

  ProfilePermissionEngine(this._authEngine, this._friendsService);

  // ===== CORE PROFILE PERMISSIONS =====

  /// Check if current user can view a profile
  bool canViewProfile(String userId) {
    return _authEngine.isAuthenticated; // All authenticated users can view profiles
  }

  /// Check if current user can edit a profile
  bool canEditProfile(String userId) {
    return _authEngine.isOwner(userId); // Only owner can edit their profile
  }

  /// Check if current user is viewing own profile
  bool isOwnProfile(String userId) {
    return _authEngine.currentUserId == userId;
  }

  /// Check if current user can modify profile settings
  bool canModifyProfileSettings(String userId) {
    return canEditProfile(userId);
  }

  /// Check if current user can change profile picture
  bool canChangeProfilePicture(String userId) {
    return canEditProfile(userId);
  }

  /// Check if current user can update profile information
  bool canUpdateProfileInfo(String userId) {
    return canEditProfile(userId);
  }

  // ===== FRIEND REQUEST PERMISSIONS =====

  /// Check if current user can send friend request
  bool canSendFriendRequest(String userId) {
    return _getCachedProfilePermission('friend_request_$userId', () {
      if (!_authEngine.isAuthenticated || userId == _authEngine.currentUserId) return false;
      
      // Check if already friends or request pending
      final friends = _friendsService.friends;
      final isAlreadyFriend = friends.any((friend) => friend.uid == userId);
      
      return !isAlreadyFriend;
    });
  }

  /// Check if current user can accept friend request
  bool canAcceptFriendRequest(String requestId) {
    return _authEngine.isAuthenticated;
  }

  /// Check if current user can reject friend request
  bool canRejectFriendRequest(String requestId) {
    return _authEngine.isAuthenticated;
  }

  /// Check if current user can cancel friend request
  bool canCancelFriendRequest(String requestId) {
    return _authEngine.isAuthenticated;
  }

  /// Check if current user can manage friend requests
  bool canManageFriendRequests() {
    return _authEngine.isAuthenticated;
  }

  // ===== FRIENDSHIP MANAGEMENT =====

  /// Check if current user can remove friend
  bool canRemoveFriend(String userId) {
    return _authEngine.isAuthenticated && _authEngine.currentUserId != userId;
  }

  /// Check if users are friends
  bool areFriends(String userId) {
    return _getCachedProfilePermission('are_friends_$userId', () {
      if (!_authEngine.isAuthenticated) return false;
      
      final friends = _friendsService.friends;
      return friends.any((friend) => friend.uid == userId);
    });
  }

  /// Check if current user can view friend list
  bool canViewFriendList(String userId) {
    return canViewProfile(userId);
  }

  /// Check if current user can manage own friend list
  bool canManageFriendList() {
    return _authEngine.isAuthenticated;
  }

  // ===== USER BLOCKING PERMISSIONS =====

  /// Check if current user can block another user
  bool canBlockUser(String userId) {
    return _authEngine.isAuthenticated && _authEngine.currentUserId != userId;
  }

  /// Check if current user can unblock another user
  bool canUnblockUser(String userId) {
    return _authEngine.isAuthenticated && _authEngine.currentUserId != userId;
  }

  /// Check if current user can view blocked users list
  bool canViewBlockedUsers() {
    return _authEngine.isAuthenticated;
  }

  /// Check if current user can manage blocked users
  bool canManageBlockedUsers() {
    return _authEngine.isAuthenticated;
  }

  // ===== COMMUNICATION PERMISSIONS =====

  /// Check if current user can message another user
  bool canMessageUser(String userId) {
    return _authEngine.isAuthenticated && _authEngine.currentUserId != userId;
  }

  /// Check if current user can start conversation
  bool canStartConversation(String userId) {
    return canMessageUser(userId);
  }

  /// Check if current user can send direct messages
  bool canSendDirectMessages() {
    return _authEngine.isAuthenticated;
  }

  /// Check if current user can receive messages
  bool canReceiveMessages() {
    return _authEngine.isAuthenticated;
  }

  // ===== SOCIAL INTERACTION PERMISSIONS =====

  /// Check if current user can follow another user
  bool canFollowUser(String userId) {
    return _authEngine.isAuthenticated && _authEngine.currentUserId != userId;
  }

  /// Check if current user can unfollow another user
  bool canUnfollowUser(String userId) {
    return _authEngine.isAuthenticated && _authEngine.currentUserId != userId;
  }

  /// Check if current user can mention another user
  bool canMentionUser(String userId) {
    return _authEngine.isAuthenticated;
  }

  /// Check if current user can tag another user
  bool canTagUser(String userId) {
    return _authEngine.isAuthenticated;
  }

  // ===== PRIVACY PERMISSIONS =====

  /// Check if current user can view private content
  bool canViewPrivateContent(String userId) {
    return isOwnProfile(userId) || areFriends(userId);
  }

  /// Check if current user can change privacy settings
  bool canChangePrivacySettings(String userId) {
    return isOwnProfile(userId);
  }

  /// Check if current user can control who can message them
  bool canControlMessagingPrivacy(String userId) {
    return isOwnProfile(userId);
  }

  /// Check if current user can control who can see their profile
  bool canControlProfilePrivacy(String userId) {
    return isOwnProfile(userId);
  }

  // ===== CONTENT PERMISSIONS =====

  /// Check if current user can create content
  bool canCreateContent() {
    return _authEngine.isAuthenticated; // All authenticated users can create content
  }

  /// Check if current user can share content
  bool canShareContent() {
    return _authEngine.isAuthenticated; // All authenticated users can share content
  }

  /// Check if current user can access premium features
  bool canAccessPremiumFeatures() {
    // This could be extended with subscription logic
    return _authEngine.isAuthenticated;
  }

  /// Check if current user can import content
  bool canImportContent() {
    return _authEngine.isAuthenticated; // All authenticated users can import content
  }

  /// Check if current user can export content
  bool canExportContent() {
    return _authEngine.isAuthenticated; // All authenticated users can export content
  }

  // ===== PROFILE ACCESS VALIDATION =====

  /// Check if user has any access to profile
  bool hasProfileAccess(String userId) {
    return canViewProfile(userId);
  }

  /// Check if user has read access to profile
  bool hasReadAccess(String userId) {
    return canViewProfile(userId);
  }

  /// Check if user has write access to profile
  bool hasWriteAccess(String userId) {
    return canEditProfile(userId);
  }

  /// Check if user has admin access to profile
  bool hasAdminAccess(String userId) {
    return canEditProfile(userId); // Same as write for profiles
  }

  /// Check if user has owner access to profile
  bool hasOwnerAccess(String userId) {
    return isOwnProfile(userId);
  }

  // ===== PROFILE PERMISSION LEVEL =====

  /// Get resource permission level for current user
  ResourcePermission getProfilePermissionLevel(String userId) {
    if (canEditProfile(userId)) return ResourcePermission.owner;
    if (canViewProfile(userId)) return ResourcePermission.viewer;
    return ResourcePermission.viewer; // Default fallback
  }

  /// Check if user has minimum required permission
  bool hasMinimumProfilePermission(String userId, ResourcePermission required) {
    final current = getProfilePermissionLevel(userId);
    return ResourcePermissionHelper.isHigherPermission(current, required) || current == required;
  }

  // ===== PROFILE VALIDATION =====

  /// Validate user ID format
  bool isValidUserId(String userId) {
    return userId.isNotEmpty && userId.trim().isNotEmpty;
  }

  /// Check if user exists and can be interacted with
  bool validateUserInteraction(String userId) {
    if (!isValidUserId(userId)) return false;
    return _authEngine.isAuthenticated;
  }

  /// Get profile permission validation result
  Map<String, bool> validateAllProfilePermissions(String userId) {
    return {
      'canView': canViewProfile(userId),
      'canEdit': canEditProfile(userId),
      'canSendFriendRequest': canSendFriendRequest(userId),
      'canRemoveFriend': canRemoveFriend(userId),
      'canBlock': canBlockUser(userId),
      'canUnblock': canUnblockUser(userId),
      'canMessage': canMessageUser(userId),
      'canFollow': canFollowUser(userId),
      'canMention': canMentionUser(userId),
      'isOwnProfile': isOwnProfile(userId),
      'areFriends': areFriends(userId),
    };
  }

  // ===== PROFILE PERMISSION CONTEXT =====

  /// Create permission context for profile operations
  Map<String, dynamic> createProfilePermissionContext(String userId) {
    return {
      'targetUserId': userId,
      'currentUserId': _authEngine.currentUserId,
      'permissions': validateAllProfilePermissions(userId),
      'permissionLevel': getProfilePermissionLevel(userId).toString(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Check if user can perform operation on profile
  bool canPerformProfileOperation(String userId, String operation) {
    switch (operation.toLowerCase()) {
      case 'view':
        return canViewProfile(userId);
      case 'edit':
        return canEditProfile(userId);
      case 'send_friend_request':
        return canSendFriendRequest(userId);
      case 'remove_friend':
        return canRemoveFriend(userId);
      case 'block':
        return canBlockUser(userId);
      case 'unblock':
        return canUnblockUser(userId);
      case 'message':
        return canMessageUser(userId);
      case 'follow':
        return canFollowUser(userId);
      case 'unfollow':
        return canUnfollowUser(userId);
      case 'mention':
        return canMentionUser(userId);
      case 'tag':
        return canTagUser(userId);
      default:
        return false;
    }
  }

  // ===== SOCIAL RELATIONSHIP HELPERS =====

  /// Get relationship status between users
  String getRelationshipStatus(String userId) {
    if (isOwnProfile(userId)) return 'self';
    if (areFriends(userId)) return 'friends';
    // Could add more statuses: blocked, pending_request, etc.
    return 'none';
  }

  /// Check if users can interact socially
  bool canInteractSocially(String userId) {
    return _authEngine.isAuthenticated && _authEngine.currentUserId != userId;
  }

  /// Check if user can see social activity
  bool canSeeSocialActivity(String userId) {
    return canViewProfile(userId);
  }

  // ===== ASYNC PROFILE OPERATIONS =====

  /// Get user profile by ID
  Future<UserProfile?> getUserProfile(String userId) async {
    return await _authEngine.getUserProfile(userId);
  }

  /// Validate user exists and is accessible
  Future<bool> validateUserExists(String userId) async {
    return await _authEngine.validateUserExists(userId);
  }

  // ===== CACHE MANAGEMENT =====

  /// Clear profile permission cache
  void clearProfilePermissionCache() {
    _profilePermissionCache.clear();
    AppLogger.info('🔐 Profile permission cache cleared');
  }

  /// Clear specific profile permission from cache
  void clearProfilePermissionFromCache(String key) {
    _profilePermissionCache.remove(key);
    AppLogger.debug('🔐 Profile permission cache cleared for key: $key');
  }

  // ===== PRIVATE HELPERS =====

  /// Get cached profile permission result or compute and cache it
  bool _getCachedProfilePermission(String key, bool Function() computation) {
    if (_profilePermissionCache.containsKey(key)) {
      return _profilePermissionCache[key]!;
    }
    
    final result = computation();
    _profilePermissionCache[key] = result;
    return result;
  }
}