// lib/services/unified/friends/friends_sync_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../models/friend_request.dart';
import '../../../models/user_profile.dart';
import '../../../models/friend_category.dart';
import '../../../models/group_invitation.dart';
import '../../../core/utils/logger.dart';
import '../../../core/mixins/firebase_sync_mixin.dart';
import '../../../services/permission_service.dart';
import '../../../core/injection.dart';

/// Firebase sync service for friends data
/// 
/// Handles all Firebase synchronization operations for:
/// - Friend profiles
/// - Friend requests
/// - Friend categories
/// - Group invitations
/// - Blocked users
class FriendsSyncService extends ChangeNotifier with FirebaseSyncMixin<UserProfile> {
  final FirebaseFirestore _firestore;
  
  FriendsSyncService(this._firestore);
  
  @override
  FirebaseFirestore get firestore => _firestore;
  
  @override
  String? get currentUserId => sl<PermissionService>().currentUserId;
  
  @override
  List<SyncCollection> get syncCollections => [
    // Friends collection
    SyncCollection(
      name: 'friends',
      query: () => _firestore
          .collection('users')
          .doc(currentUserId!)
          .collection('friends'),
      onAdded: (doc) => _onFriendAdded(doc),
      onModified: (doc) => _onFriendModified(doc),
      onRemoved: (doc) => _onFriendRemoved(doc),
    ),
    
    // Friend requests collection
    SyncCollection(
      name: 'friend_requests',
      query: () => _firestore
          .collection('friend_requests')
          .where('recipientId', isEqualTo: currentUserId),
      onAdded: (doc) => _onFriendRequestAdded(doc),
      onModified: (doc) => _onFriendRequestModified(doc),
      onRemoved: (doc) => _onFriendRequestRemoved(doc),
    ),
    
    // Friend categories collection
    SyncCollection(
      name: 'friend_categories',
      query: () => _firestore
          .collection('users')
          .doc(currentUserId!)
          .collection('friend_categories'),
      onAdded: (doc) => _onCategoryAdded(doc),
      onModified: (doc) => _onCategoryModified(doc),
      onRemoved: (doc) => _onCategoryRemoved(doc),
    ),
  ];
  
  // ===== SYNC TO FIREBASE =====
  
  /// Sync friend to Firebase
  Future<void> syncFriendToFirebase(UserProfile friend) async {
    if (!sl<PermissionService>().isAuthenticated) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(friend.uid)
          .set({
            'uid': friend.uid,
            'displayName': friend.displayName,
            'email': friend.email,
            'avatarUrl': friend.avatarUrl,
            'bio': friend.bio,
            'joinedAt': friend.joinedAt.toIso8601String(),
            'lastActiveAt': friend.lastActiveAt.toIso8601String(),
          }, SetOptions(merge: true));

      AppLogger.debug('Friend synced: ${friend.displayName}');
    } catch (e) {
      AppLogger.error('Failed to sync friend to Firebase: $e');
    }
  }
  
  /// Sync friend request to Firebase
  Future<void> syncFriendRequestToFirebase(FriendRequest request) async {
    if (!sl<PermissionService>().isAuthenticated) return;

    try {
      await _firestore
          .collection('friend_requests')
          .doc(request.id)
          .set(request.toFirestore(), SetOptions(merge: true));

      AppLogger.debug('Friend request synced: ${request.id}');
    } catch (e) {
      AppLogger.error('Failed to sync friend request to Firebase: $e');
    }
  }
  
  /// Update friend request status
  Future<void> updateFriendRequestStatus(FriendRequest request) async {
    try {
      await _firestore
          .collection('friend_requests')
          .doc(request.id)
          .update({'status': request.status.toString().split('.').last});

      AppLogger.debug('Friend request status updated: ${request.id}');
    } catch (e) {
      AppLogger.error('Failed to update friend request status: $e');
    }
  }
  
  /// Remove friend from Firebase
  Future<void> removeFriendFromFirebase(String friendId) async {
    if (!sl<PermissionService>().isAuthenticated) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(friendId)
          .delete();

      AppLogger.debug('Friend removed from Firebase: $friendId');
    } catch (e) {
      AppLogger.error('Failed to remove friend from Firebase: $e');
    }
  }
  
  /// Sync category to Firebase
  Future<void> syncCategoryToFirebase(FriendCategory category) async {
    if (!sl<PermissionService>().isAuthenticated) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friend_categories')
          .doc(category.id)
          .set(category.toFirestore(), SetOptions(merge: true));

      AppLogger.debug('Category synced: ${category.name}');
    } catch (e) {
      AppLogger.error('Failed to sync category to Firebase: $e');
    }
  }
  
  /// Remove category from Firebase
  Future<void> removeCategoryFromFirebase(String categoryId) async {
    if (!sl<PermissionService>().isAuthenticated) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friend_categories')
          .doc(categoryId)
          .delete();

      AppLogger.debug('Category removed from Firebase: $categoryId');
    } catch (e) {
      AppLogger.error('Failed to remove category from Firebase: $e');
    }
  }
  
  /// Sync group invitation to Firebase
  Future<void> syncGroupInvitationToFirebase(GroupInvitation invitation) async {
    if (!sl<PermissionService>().isAuthenticated) return;

    try {
      await _firestore
          .collection('group_invitations')
          .doc(invitation.id)
          .set(invitation.toFirestore(), SetOptions(merge: true));

      AppLogger.debug('Group invitation synced: ${invitation.id}');
    } catch (e) {
      AppLogger.error('Failed to sync group invitation to Firebase: $e');
    }
  }
  
  /// Sync blocked user to Firebase
  Future<void> syncBlockedUserToFirebase(String blockedUserId) async {
    if (!sl<PermissionService>().isAuthenticated) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(blockedUserId)
          .set({
            'blockedUserId': blockedUserId,
            'blockedAt': DateTime.now().toIso8601String(),
          });

      AppLogger.debug('Blocked user synced: $blockedUserId');
    } catch (e) {
      AppLogger.error('Failed to sync blocked user to Firebase: $e');
    }
  }
  
  /// Remove blocked user from Firebase
  Future<void> removeBlockedUserFromFirebase(String blockedUserId) async {
    if (!sl<PermissionService>().isAuthenticated) return;

    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blocked_users')
          .doc(blockedUserId)
          .delete();

      AppLogger.debug('Blocked user removed from Firebase: $blockedUserId');
    } catch (e) {
      AppLogger.error('Failed to remove blocked user from Firebase: $e');
    }
  }
  
  // ===== SYNC CALLBACKS =====
  
  void _onFriendAdded(DocumentSnapshot doc) {
    final friend = UserProfile.fromFirestore(doc);
    onFriendAdded?.call(friend);
  }
  
  void _onFriendModified(DocumentSnapshot doc) {
    final friend = UserProfile.fromFirestore(doc);
    onFriendModified?.call(friend);
  }
  
  void _onFriendRemoved(DocumentSnapshot doc) {
    onFriendRemoved?.call(doc.id);
  }
  
  void _onFriendRequestAdded(DocumentSnapshot doc) {
    final request = FriendRequest.fromFirestore(doc);
    onFriendRequestAdded?.call(request);
  }
  
  void _onFriendRequestModified(DocumentSnapshot doc) {
    final request = FriendRequest.fromFirestore(doc);
    onFriendRequestModified?.call(request);
  }
  
  void _onFriendRequestRemoved(DocumentSnapshot doc) {
    onFriendRequestRemoved?.call(doc.id);
  }
  
  void _onCategoryAdded(DocumentSnapshot doc) {
    final category = FriendCategory.fromFirestore(doc);
    onCategoryAdded?.call(category);
  }
  
  void _onCategoryModified(DocumentSnapshot doc) {
    final category = FriendCategory.fromFirestore(doc);
    onCategoryModified?.call(category);
  }
  
  void _onCategoryRemoved(DocumentSnapshot doc) {
    onCategoryRemoved?.call(doc.id);
  }
  
  // ===== CALLBACKS =====
  
  Function(UserProfile)? onFriendAdded;
  Function(UserProfile)? onFriendModified;
  Function(String)? onFriendRemoved;
  
  Function(FriendRequest)? onFriendRequestAdded;
  Function(FriendRequest)? onFriendRequestModified;
  Function(String)? onFriendRequestRemoved;
  
  Function(FriendCategory)? onCategoryAdded;
  Function(FriendCategory)? onCategoryModified;
  Function(String)? onCategoryRemoved;
}