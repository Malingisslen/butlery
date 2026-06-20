// lib/repositories/firebase/firebase_friends_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/utils/logger.dart';

import 'package:butlery/repositories/firebase/firebase_social_request_repository.dart';
import 'package:butlery/repositories/firebase/friends/friend_relationship_repository.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Facade coordinating three focused repositories:
/// - FirebaseSocialRequestRepository: friend requests + group invitations (unified)
/// - FriendRelationshipRepository: mutual friendships and profiles
/// - FriendCategoryRepository: friend groups/categories
class FirebaseFriendsRepository extends BaseFirebaseRepository<UserProfile>
    implements FriendsRepository {
  late final FirebaseSocialRequestRepository _socialRequestRepo;
  late final FriendRelationshipRepository _friendRelationshipRepo;
  late final FriendCategoryRepository _friendCategoryRepo;

  FirebaseFriendsRepository({
    super.firestore,
    AuthRepository? authRepository,
    super.auditRepository,
    super.timestampProvider,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        ) {
    _socialRequestRepo = FirebaseSocialRequestRepository(
      firestore: firestore,
      authRepository: this.authRepository,
      timestampProvider: timestampProvider,
    );
    _friendRelationshipRepo = FriendRelationshipRepository(
      firestore: firestore,
      authRepository: this.authRepository,
      timestampProvider: timestampProvider,
    );
    _friendCategoryRepo = FriendCategoryRepository(
      firestore: firestore,
      authRepository: this.authRepository,
      timestampProvider: timestampProvider,
    );
  }

  @override
  String get collectionName => FirestoreCollections.publicProfiles;

  @override
  UserProfile fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      UserProfile.fromMap(doc.id, doc.data() ?? {});

  @override
  Map<String, dynamic> toFirestore(UserProfile entity) => entity.toFirestore();

  @override
  String getId(UserProfile entity) => entity.uid;

  @override
  Future<bool> validateCreatePermission(
      String userId, UserProfile entity) async {
    return userId == entity.uid;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, UserProfile? entity) async {
    return true;
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, UserProfile entity) async {
    return userId == entity.uid;
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    return userId == resourceId;
  }

  // ── Friend request operations (delegated to social request repo) ──

  Future<void> sendRequest(FriendRequest request) async {
    final socialRequest = SocialRequest.friendRequest(
      fromUserId: request.fromUserId,
      toUserId: request.toUserId,
      message: request.message,
    );
    await _socialRequestRepo.createRequest(socialRequest);
  }

  @override
  Future<bool> sendFriendRequest(String toUserId, {String? message}) async {
    try {
      final fromId = requireCurrentUserId();
      if (fromId == toUserId) return false;
      final exists =
          await _socialRequestRepo.friendRequestExists(fromId, toUserId);
      if (exists) return false;

      final request = SocialRequest.friendRequest(
        fromUserId: fromId,
        toUserId: toUserId,
        message: message,
      );
      await _socialRequestRepo.createRequest(request);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> acceptFriendRequest(String requestId) async {
    try {
      final currentUser = requireCurrentUserId();
      AppLogger.debug(
          'Accepting friend request $requestId for user $currentUser');

      // Pre-release audit B1: the mutual friend-doc write now runs server-side
      // via the `acceptFriendRequest` callable (validates the request, writes
      // both sides under Admin SDK). The client can no longer write into
      // another user's friends subcollection — that's what closed the privacy
      // hole. The function derives the parties + status from the request doc.
      await _friendRelationshipRepo.acceptFriendRequestViaFunction(requestId);

      logPermissionCheck(
        userId: currentUser,
        resource: 'social_request',
        operation: 'accept',
        granted: true,
        details: 'Request $requestId accepted via acceptFriendRequest function',
      );
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
          'Failed to accept friend request $requestId: $e', stackTrace);
      return false;
    }
  }

  @override
  Future<bool> rejectFriendRequest(String requestId) async {
    try {
      await _socialRequestRepo.updateRequestStatus(requestId, {
        'status': SocialRequestStatus.rejected.name,
        'respondedAt': timestampProvider.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> cancelFriendRequest(String requestId) async {
    try {
      // Sender cancellation uses delete (rules only allow recipient to update)
      await _socialRequestRepo.deleteRequest(requestId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<FriendRequest?> fetchRequest(String requestId) async {
    final sr = await _socialRequestRepo.getRequest(requestId);
    return sr?.toFriendRequest();
  }

  @override
  Future<bool> requestExists(String fromUserId, String toUserId) async {
    return await _socialRequestRepo.friendRequestExists(fromUserId, toUserId);
  }

  @override
  Future<List<FriendRequest>> getIncomingRequests() async {
    return await _socialRequestRepo.getIncomingFriendRequests();
  }

  @override
  Future<List<FriendRequest>> getSentRequests() async {
    return await _socialRequestRepo.getSentFriendRequests();
  }

  Stream<List<FriendRequest>> incomingRequestsStream(String userId) {
    return _socialRequestRepo.incomingFriendRequestsStream(userId);
  }

  Stream<List<FriendRequest>> sentRequestsStream(String userId) {
    return _socialRequestRepo.sentFriendRequestsStream(userId);
  }

  // ── Relationship operations (unchanged) ──

  @override
  Future<bool> areFriends(String userId1, String userId2) async {
    return await _friendRelationshipRepo.areFriends(userId1, userId2);
  }

  @override
  Future<void> addMutualFriends(String userId1, String userId2) async {
    return await _friendRelationshipRepo.addMutualFriends(userId1, userId2);
  }

  @override
  Future<void> removeMutualFriends(String userId1, String userId2) async {
    return await _friendRelationshipRepo.removeMutualFriends(userId1, userId2);
  }

  @override
  Future<bool> removeFriend(String friendUserId) async {
    return await _friendRelationshipRepo.removeFriend(friendUserId);
  }

  @override
  Future<List<String>> fetchFriendIds(String userId) async {
    return await _friendRelationshipRepo.fetchFriendIds(userId);
  }

  @override
  Stream<List<String>> friendIdsStream(String userId) {
    return _friendRelationshipRepo.friendIdsStream(userId);
  }

  @override
  Future<List<UserProfile>> fetchFriendProfiles(List<String> userIds) async {
    return await _friendRelationshipRepo.fetchFriendProfiles(userIds);
  }

  // ── Category operations (unchanged) ──

  @override
  Future<void> saveCategory(String userId, FriendCategory category) async {
    return await _friendCategoryRepo.saveCategory(userId, category);
  }

  @override
  Future<void> updateCategory(
      String userId, String categoryId, Map<String, dynamic> data) async {
    return await _friendCategoryRepo.updateCategory(userId, categoryId, data);
  }

  @override
  Future<void> deleteCategory(String userId, String categoryId) async {
    return await _friendCategoryRepo.deleteCategory(userId, categoryId);
  }

  @override
  Future<List<FriendCategory>> fetchCategories(String userId) async {
    return await _friendCategoryRepo.fetchCategories(userId);
  }

  @override
  Future<void> createCategoryForUser(
      String userId, FriendCategory category) async {
    return await _friendCategoryRepo.createCategoryForUser(userId, category);
  }

  @override
  Future<void> updateCategoryMembers(
      String userId, String categoryId, List<String> memberIds) async {
    return await _friendCategoryRepo.updateCategoryMembers(
        userId, categoryId, memberIds);
  }

  @override
  Future<FriendCategory?> getCategory(String userId, String categoryId) async {
    return await _friendCategoryRepo.getCategory(userId, categoryId);
  }

  // ── Group invitation operations (delegated to social request repo) ──

  @override
  Stream<List<GroupInvitation>> receivedInvitationsStream(String userId) {
    return _socialRequestRepo.receivedInvitationsStream(userId);
  }

  @override
  Stream<List<GroupInvitation>> sentInvitationsStream(String userId) {
    return _socialRequestRepo.sentInvitationsStream(userId);
  }

  @override
  Future<GroupInvitation?> getInvitation(String invitationId) async {
    final sr = await _socialRequestRepo.getRequest(invitationId);
    return sr?.toGroupInvitation();
  }

  @override
  Future<void> saveInvitation(GroupInvitation invitation) async {
    // Preserve the invitation's existing ID
    final requestWithId = SocialRequest(
      id: invitation.id,
      type: SocialRequestType.groupInvitation,
      fromUserId: invitation.fromUserId,
      toUserId: invitation.toUserId,
      message: invitation.personalMessage,
      groupId: invitation.groupId,
      groupName: invitation.groupName,
      groupEmoji: invitation.groupEmoji,
      fromUserName: invitation.fromUserName,
      sentAt: invitation.sentAt,
      expiresAt: invitation.expiresAt,
    );
    await _socialRequestRepo.createRequest(requestWithId);
  }

  @override
  Future<void> updateInvitation(
      String invitationId, Map<String, dynamic> data) async {
    await _socialRequestRepo.updateRequestStatus(invitationId, data);
  }

  @override
  Future<void> deleteInvitation(String invitationId) async {
    await _socialRequestRepo.deleteRequest(invitationId);
  }

  Future<List<GroupInvitation>> fetchReceivedInvitations(String userId) async {
    return await _socialRequestRepo.getReceivedInvitations();
  }

  Future<List<GroupInvitation>> fetchSentInvitations(String userId) async {
    return await _socialRequestRepo.getSentInvitations();
  }

  @override
  Future<List<DocumentReference<Map<String, dynamic>>>> expiredInvitations(
      DateTime now) async {
    return await _socialRequestRepo.expiredRequests(now);
  }

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> oldInvitations(
      String userId, DateTime cutoffDate) async {
    return await _socialRequestRepo.oldRequests(userId, cutoffDate);
  }

  @override
  Future<void> deleteDocuments(
      List<DocumentReference<Map<String, dynamic>>> refs) async {
    return await _socialRequestRepo.deleteDocuments(refs);
  }

  @override
  Future<void> updateDocuments(
      List<DocumentReference<Map<String, dynamic>>> refs,
      Map<String, dynamic> data) async {
    return await _socialRequestRepo.updateDocuments(refs, data);
  }

  @override
  Future<bool> hasPendingInvitation(String groupId, String toUserId) async {
    return await _socialRequestRepo.hasPendingInvitation(groupId, toUserId);
  }

  Future<bool> acceptInvitation(String invitationId) async {
    try {
      await _socialRequestRepo.updateRequestStatus(invitationId, {
        'status': SocialRequestStatus.accepted.name,
        'respondedAt': timestampProvider.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> rejectInvitation(String invitationId) async {
    try {
      await _socialRequestRepo.updateRequestStatus(invitationId, {
        'status': SocialRequestStatus.rejected.name,
        'respondedAt': timestampProvider.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Statistics ──

  Future<Map<String, dynamic>> getComprehensiveFriendStatistics(
      String userId) async {
    final friendStats =
        await _friendRelationshipRepo.getFriendStatistics(userId);
    final requestStats =
        await _socialRequestRepo.getFriendRequestStatistics(userId);
    final categoryStats =
        await _friendCategoryRepo.getCategoryStatistics(userId);
    final invitationStats =
        await _socialRequestRepo.getInvitationStatistics(userId);

    return {
      'friends': friendStats,
      'requests': requestStats,
      'categories': categoryStats,
      'invitations': invitationStats,
    };
  }

  Future<List<UserProfile>> getFriendsWithProfiles(String userId) async {
    return await _friendRelationshipRepo.getFriendsWithProfiles(userId);
  }

  Future<List<String>> getMutualFriends(String userId1, String userId2) async {
    return await _friendRelationshipRepo.getMutualFriends(userId1, userId2);
  }

  Stream<List<UserProfile>> friendProfilesStream(String userId) {
    return _friendRelationshipRepo.friendProfilesStream(userId);
  }

  Stream<List<FriendCategory>> categoriesStream(String userId) {
    return _friendCategoryRepo.categoriesStream(userId);
  }

  Future<void> addFriendToCategory(
      String userId, String categoryId, String friendId) async {
    return await _friendCategoryRepo.addFriendToCategory(
        userId, categoryId, friendId);
  }

  Future<void> removeFriendFromCategory(
      String userId, String categoryId, String friendId) async {
    return await _friendCategoryRepo.removeFriendFromCategory(
        userId, categoryId, friendId);
  }

  Future<List<UserProfile>> searchFriends(String userId, String query) async {
    return await _friendRelationshipRepo.searchFriends(userId, query);
  }

  Future<List<FriendCategory>> searchCategories(
      String userId, String query) async {
    return await _friendCategoryRepo.searchCategories(userId, query);
  }
}
