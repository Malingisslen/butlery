// lib/services/unified/friends/friends_internal_operations.dart

import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/friends/friends_state_manager.dart';

/// Focused module for friends internal operations
/// 
/// This module handles ONLY internal operations for operations classes:
/// - Internal category management methods
/// - Internal invitation management methods
/// - Internal Firebase sync operations
/// - Internal utility methods
/// - Service integration helpers
/// 
/// ❌ DOES NOT CONTAIN: Public API methods, state management, UI concerns
class FriendsInternalOperations {
  final FriendsStateManager _stateManager;
  final dynamic _syncService; // FriendsSyncService
  final dynamic _cacheService; // FriendsCacheService

  FriendsInternalOperations(
    this._stateManager,
    this._syncService,
    this._cacheService,
  );

  // ===== INTERNAL CATEGORY OPERATIONS =====

  /// Internal method to add category (for operations classes)
  void addCategoryInternal(FriendCategory category) {
    _stateManager.addCategory(category);
    _cacheService?.saveCategoryToCache(category);
  }

  /// Internal method to update category (for operations classes)
  void updateCategoryInternal(String categoryId, FriendCategory category) {
    _stateManager.updateCategory(category);
    _cacheService?.saveCategoryToCache(category);
  }

  /// Internal method to remove category (for operations classes)
  void removeCategoryInternal(String categoryId) {
    _stateManager.removeCategory(categoryId);
    _cacheService?.removeCategoryFromCache(categoryId);
  }

  /// Internal method to get category by ID (for operations classes)
  FriendCategory? getCategoryByIdInternal(String categoryId) {
    return _stateManager.getCategoryById(categoryId);
  }

  /// Internal method to get all categories (for operations classes)
  List<FriendCategory> getAllCategoriesInternal() {
    return _stateManager.categories;
  }

  /// Internal method to sync category to Firebase (for operations classes)
  Future<void> syncCategoryToFirebaseInternal(FriendCategory category) async {
    try {
      await _syncService?.syncCategoryToFirebase(category);
      AppLogger.debug('Category synced to Firebase: ${category.name}');
    } catch (e) {
      AppLogger.error('Failed to sync category to Firebase: $e');
      rethrow;
    }
  }

  /// Internal method to delete category from Firebase (for operations classes)
  Future<void> deleteCategoryFromFirebaseInternal(String categoryId) async {
    try {
      await _syncService?.removeCategoryFromFirebase(categoryId);
      AppLogger.debug('Category deleted from Firebase: $categoryId');
    } catch (e) {
      AppLogger.error('Failed to delete category from Firebase: $e');
      rethrow;
    }
  }

  // ===== INTERNAL CATEGORY RELATIONSHIPS OPERATIONS =====

  /// Internal method to add friend to category (for operations classes)
  void addFriendToCategoryInternal(String friendId, String categoryId) {
    _stateManager.addFriendToCategory(friendId, categoryId);
    // Update cache
    _cacheService?.saveFriendCategoryRelationshipsToCache(_stateManager.relationshipsInternal);
  }

  /// Internal method to remove friend from category (for operations classes)
  void removeFriendFromCategoryInternal(String friendId, String categoryId) {
    _stateManager.removeFriendFromCategory(friendId, categoryId);
    // Update cache
    _cacheService?.saveFriendCategoryRelationshipsToCache(_stateManager.relationshipsInternal);
  }

  /// Internal method to get friends in category (for operations classes)
  Set<String> getFriendsInCategoryInternal(String categoryId) {
    return _stateManager.getFriendsInCategory(categoryId);
  }

  /// Internal method to get categories for friend (for operations classes)
  Set<String> getCategoriesForFriendInternal(String friendId) {
    return _stateManager.getCategoriesForFriend(friendId);
  }

  // ===== INTERNAL INVITATION OPERATIONS =====

  /// Internal method to add sent invitation (for operations classes)
  void addSentInvitationInternal(GroupInvitation invitation) {
    _stateManager.addSentInvitation(invitation);
    _cacheService?.saveSentInvitationsToCache(_stateManager.sentInvitations);
  }

  /// Internal method to get sent invitation by ID (for operations classes)
  GroupInvitation? getSentInvitationByIdInternal(String invitationId) {
    return _stateManager.getSentInvitationById(invitationId);
  }

  /// Internal method to update sent invitation (for operations classes)
  void updateSentInvitationInternal(String invitationId, GroupInvitation invitation) {
    _stateManager.updateSentInvitation(invitationId, invitation);
    _cacheService?.saveSentInvitationsToCache(_stateManager.sentInvitations);
  }

  /// Internal method to get all sent invitations (for operations classes)
  List<GroupInvitation> getAllSentInvitationsInternal() {
    return _stateManager.sentInvitations;
  }

  // ===== INTERNAL EXTERNAL SERVICE OPERATIONS =====

  /// Internal method to send email invitation (for operations classes)
  Future<bool> sendEmailInvitationInternal({
    required String email,
    required GroupInvitation invitation,
  }) async {
    try {
      // Email service integration would go here
      // For now, return false as service is not implemented
      AppLogger.warning('📧 Email service not implemented yet');
      return false;
    } catch (e) {
      AppLogger.error('Failed to send email invitation: $e');
      return false;
    }
  }

  /// Internal method to send SMS invitation (for operations classes)
  Future<bool> sendSMSInvitationInternal({
    required String phoneNumber,
    required GroupInvitation invitation,
  }) async {
    try {
      // SMS service integration would go here
      // For now, return false as service is not implemented
      AppLogger.warning('📱 SMS service not implemented yet');
      return false;
    } catch (e) {
      AppLogger.error('Failed to send SMS invitation: $e');
      return false;
    }
  }

  /// Internal method to create invitation link (for operations classes)
  String createInvitationLinkInternal(String invitationId) {
    try {
      // Deep link service integration would go here
      // For now, return a placeholder link
      final link = 'https://butlery.app/invite/$invitationId';
      AppLogger.debug('🔗 Invitation link created: $link');
      return link;
    } catch (e) {
      AppLogger.error('Failed to create invitation link: $e');
      return 'https://butlery.app/invite/error';
    }
  }

  /// Internal method to update invitation status (for operations classes)
  Future<void> updateInvitationStatusInternal(String invitationId, GroupInvitationStatus status) async {
    try {
      // Firebase update would go here
      // For now, just log the action
      AppLogger.debug('📝 Invitation status updated: $invitationId -> $status');
      
      // Update local state if invitation exists
      final invitation = _stateManager.getSentInvitationById(invitationId);
      if (invitation != null) {
        final updatedInvitation = invitation.copyWith(status: status);
        updateSentInvitationInternal(invitationId, updatedInvitation);
      }
    } catch (e) {
      AppLogger.error('Failed to update invitation status: $e');
      rethrow;
    }
  }

  // ===== INTERNAL USER CONTEXT OPERATIONS =====

  /// Internal getter for current user display name (for operations classes)
  String? getCurrentUserDisplayNameInternal() {
    try {
      // This would typically come from user profile service
      // For now, return a placeholder
      return 'Current User';
    } catch (e) {
      AppLogger.error('Failed to get current user display name: $e');
      return null;
    }
  }

  // ===== INTERNAL FRIENDS LIST OPERATIONS =====

  /// Internal getter for friends list (for operations classes)
  List<UserProfile> get friendsInternal => _stateManager.friendsInternal;

  /// Internal method to get friend by ID (for operations classes)
  UserProfile? getFriendByIdInternal(String friendId) {
    try {
      return _stateManager.friendsInternal.firstWhere((f) => f.uid == friendId);
    } catch (e) {
      return null;
    }
  }

  /// Internal method to check if user is friend (for operations classes)
  bool isUserFriendInternal(String userId) {
    return _stateManager.friendsInternal.any((f) => f.uid == userId);
  }

  // ===== INTERNAL BLOCKED USERS OPERATIONS =====

  /// Internal method to block user (for operations classes)
  void blockUserInternal(String userId) {
    _stateManager.addBlockedUser(userId);
    _cacheService?.saveBlockedUsersToCache(_stateManager.blockedUsers);
  }

  /// Internal method to unblock user (for operations classes)
  void unblockUserInternal(String userId) {
    _stateManager.removeBlockedUser(userId);
    _cacheService?.saveBlockedUsersToCache(_stateManager.blockedUsers);
  }

  /// Internal method to check if user is blocked (for operations classes)
  bool isUserBlockedInternal(String userId) {
    return _stateManager.isUserBlocked(userId);
  }

  // ===== INTERNAL CACHE OPERATIONS =====

  /// Internal method to save friend to cache (for operations classes)
  void saveFriendToCacheInternal(UserProfile friend) {
    _cacheService?.saveFriendToCache(friend);
  }

  /// Internal method to remove friend from cache (for operations classes)
  void removeFriendFromCacheInternal(String friendId) {
    _cacheService?.removeFriendFromCache(friendId);
  }

  /// Internal method to clear all cache (for operations classes)
  void clearAllCacheInternal() {
    _cacheService?.clearAllCache();
  }

  // ===== INTERNAL UTILITY METHODS =====

  /// Internal method to notify listeners (for operations classes)
  void notifyListenersInternal() {
    _stateManager.triggerNotification();
  }

  /// Internal method to validate category name (for operations classes)
  bool validateCategoryNameInternal(String name) {
    if (name.trim().isEmpty) {
      return false;
    }
    
    if (name.length > 50) {
      return false;
    }
    
    // Check for duplicate names
    return !_stateManager.categories.any((c) => c.name.toLowerCase() == name.toLowerCase());
  }

  /// Internal method to validate invitation email (for operations classes)
  bool validateInvitationEmailInternal(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// Internal method to validate invitation phone number (for operations classes)
  bool validateInvitationPhoneInternal(String phone) {
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{10,}$');
    return phoneRegex.hasMatch(phone);
  }

  /// Internal method to generate unique category ID (for operations classes)
  String generateCategoryIdInternal() {
    return 'category_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Internal method to generate unique invitation ID (for operations classes)
  String generateInvitationIdInternal() {
    return 'invitation_${DateTime.now().millisecondsSinceEpoch}';
  }
}