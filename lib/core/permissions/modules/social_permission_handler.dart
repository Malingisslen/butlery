// lib/core/permissions/modules/social_permission_handler.dart

import 'base_permission_manager.dart';

/// Focused module for social permission handling
/// 
/// This module handles ONLY social/profile-specific permissions:
/// - Profile viewing and editing permissions
/// - Friend request management permissions
/// - User blocking and communication permissions
/// - Social interaction validation
/// 
/// ❌ DOES NOT CONTAIN: Action builders, permission levels, other resource types
class SocialPermissionHandler {

  // ===== PROFILE PERMISSIONS =====

  /// Check if user can view a profile
  static bool canViewProfile(String userId) {
    return BasePermissionManager.permissionService.canViewProfile(userId);
  }

  /// Check if user can edit a profile
  static bool canEditProfile(String userId) {
    return BasePermissionManager.permissionService.canEditProfile(userId);
  }

  /// Check if user is viewing own profile
  static bool isOwnProfile(String userId) {
    return BasePermissionManager.currentUserId == userId;
  }

  /// Check if user can modify profile settings
  static bool canModifyProfileSettings(String userId) {
    return canEditProfile(userId);
  }

  /// Check if user can change profile picture
  static bool canChangeProfilePicture(String userId) {
    return canEditProfile(userId);
  }

  /// Check if user can update profile information
  static bool canUpdateProfileInfo(String userId) {
    return canEditProfile(userId);
  }

  // ===== FRIEND REQUEST PERMISSIONS =====

  /// Check if user can send friend request
  static bool canSendFriendRequest(String userId) {
    return BasePermissionManager.permissionService.canSendFriendRequest(userId);
  }

  /// Check if user can accept friend request
  static bool canAcceptFriendRequest(String requestId) {
    // Authenticated users can accept friend requests
    return BasePermissionManager.isAuthenticated;
  }

  /// Check if user can reject friend request
  static bool canRejectFriendRequest(String requestId) {
    // Authenticated users can reject friend requests
    return BasePermissionManager.isAuthenticated;
  }

  /// Check if user can cancel friend request
  static bool canCancelFriendRequest(String requestId) {
    // Authenticated users can cancel their own friend requests
    return BasePermissionManager.isAuthenticated;
  }

  /// Check if user can manage friend requests
  static bool canManageFriendRequests() {
    return BasePermissionManager.isAuthenticated;
  }

  // ===== FRIENDSHIP MANAGEMENT =====

  /// Check if user can remove friend
  static bool canRemoveFriend(String userId) {
    // Can remove friend if authenticated and not self
    return BasePermissionManager.isAuthenticated && 
           BasePermissionManager.currentUserId != userId;
  }

  /// Check if users are friends
  static bool areFriends(String userId) {
    // Simplified - can be enhanced later with actual friendship checking
    return BasePermissionManager.isAuthenticated;
  }

  /// Check if user can view friend list
  static bool canViewFriendList(String userId) {
    return canViewProfile(userId);
  }

  /// Check if user can manage own friend list
  static bool canManageFriendList() {
    return BasePermissionManager.isAuthenticated;
  }

  // ===== USER BLOCKING PERMISSIONS =====

  /// Check if user can block another user
  static bool canBlockUser(String userId) {
    // Can block if authenticated and not self
    return BasePermissionManager.isAuthenticated && 
           BasePermissionManager.currentUserId != userId;
  }

  /// Check if user can unblock another user
  static bool canUnblockUser(String userId) {
    // Can unblock if authenticated and not self
    return BasePermissionManager.isAuthenticated && 
           BasePermissionManager.currentUserId != userId;
  }

  /// Check if user can view blocked users list
  static bool canViewBlockedUsers() {
    return BasePermissionManager.isAuthenticated;
  }

  /// Check if user can manage blocked users
  static bool canManageBlockedUsers() {
    return BasePermissionManager.isAuthenticated;
  }

  // ===== COMMUNICATION PERMISSIONS =====

  /// Check if user can message another user
  static bool canMessageUser(String userId) {
    // Can message if authenticated and not self
    return BasePermissionManager.isAuthenticated && 
           BasePermissionManager.currentUserId != userId;
  }

  /// Check if user can start conversation
  static bool canStartConversation(String userId) {
    return canMessageUser(userId);
  }

  /// Check if user can send direct messages
  static bool canSendDirectMessages() {
    return BasePermissionManager.isAuthenticated;
  }

  /// Check if user can receive messages
  static bool canReceiveMessages() {
    return BasePermissionManager.isAuthenticated;
  }

  // ===== SOCIAL INTERACTION PERMISSIONS =====

  /// Check if user can follow another user
  static bool canFollowUser(String userId) {
    return BasePermissionManager.isAuthenticated && 
           BasePermissionManager.currentUserId != userId;
  }

  /// Check if user can unfollow another user
  static bool canUnfollowUser(String userId) {
    return BasePermissionManager.isAuthenticated && 
           BasePermissionManager.currentUserId != userId;
  }

  /// Check if user can mention another user
  static bool canMentionUser(String userId) {
    return BasePermissionManager.isAuthenticated;
  }

  /// Check if user can tag another user
  static bool canTagUser(String userId) {
    return BasePermissionManager.isAuthenticated;
  }

  // ===== PRIVACY PERMISSIONS =====

  /// Check if user can view private content
  static bool canViewPrivateContent(String userId) {
    return isOwnProfile(userId) || areFriends(userId);
  }

  /// Check if user can change privacy settings
  static bool canChangePrivacySettings(String userId) {
    return isOwnProfile(userId);
  }

  /// Check if user can control who can message them
  static bool canControlMessagingPrivacy(String userId) {
    return isOwnProfile(userId);
  }

  /// Check if user can control who can see their profile
  static bool canControlProfilePrivacy(String userId) {
    return isOwnProfile(userId);
  }

  // ===== SOCIAL VALIDATION =====

  /// Validate user ID format
  static bool isValidUserId(String userId) {
    return userId.isNotEmpty && userId.trim().isNotEmpty;
  }

  /// Check if user exists and can be interacted with
  static bool validateUserInteraction(String userId) {
    if (!isValidUserId(userId)) return false;
    return BasePermissionManager.isAuthenticated;
  }

  /// Get social permission validation result
  static Map<String, bool> validateAllSocialPermissions(String userId) {
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

  // ===== SOCIAL PERMISSION CONTEXT =====

  /// Create permission context for social operations
  static Map<String, dynamic> createSocialPermissionContext(String userId) {
    return {
      'targetUserId': userId,
      'currentUserId': BasePermissionManager.currentUserId,
      'permissions': validateAllSocialPermissions(userId),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Check if user can perform social operation
  static bool canPerformSocialOperation(String userId, String operation) {
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
  static String getRelationshipStatus(String userId) {
    if (isOwnProfile(userId)) return 'self';
    if (areFriends(userId)) return 'friends';
    // Could add more statuses: blocked, pending_request, etc.
    return 'none';
  }

  /// Check if users can interact socially
  static bool canInteractSocially(String userId) {
    return BasePermissionManager.isAuthenticated && 
           BasePermissionManager.currentUserId != userId;
  }

  /// Check if user can see social activity
  static bool canSeeSocialActivity(String userId) {
    return canViewProfile(userId);
  }
}