/// Unified repository for social requests (friend requests + group invitations).
/// Replaces FriendRequestRepository and GroupInvitationRepository with a single
/// collection using a `type` discriminator field.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

class FirebaseSocialRequestRepository
    extends BaseFirebaseRepository<SocialRequest> {
  FirebaseSocialRequestRepository({
    super.firestore,
    AuthRepository? authRepository,
    super.timestampProvider,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  CollectionReference<Map<String, dynamic>> get _requestsRef =>
      firestore.collection(FirestoreCollections.socialRequests);

  @override
  String get collectionName => FirestoreCollections.socialRequests;

  @override
  SocialRequest fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      SocialRequest.fromMap(doc.id, doc.data() ?? {});

  @override
  Map<String, dynamic> toFirestore(SocialRequest entity) =>
      entity.toFirestore();

  @override
  String getId(SocialRequest entity) => entity.id;

  @override
  Future<bool> validateCreatePermission(
      String userId, SocialRequest entity) async {
    return userId == entity.fromUserId;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, SocialRequest? entity) async {
    if (entity == null) return false;
    return userId == entity.fromUserId || userId == entity.toUserId;
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, SocialRequest entity) async {
    return userId == entity.fromUserId || userId == entity.toUserId;
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    try {
      final request = await getRequest(resourceId);
      if (request == null) return false;
      return userId == request.fromUserId || userId == request.toUserId;
    } catch (e) {
      return false;
    }
  }

  // ── CRUD ──

  Future<void> createRequest(SocialRequest request) async {
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: request.fromUserId,
      operation: 'create social request',
    );

    if (request.status != SocialRequestStatus.pending) {
      throw SecurityViolationException(
        'New requests must have pending status',
        details: 'Status was: ${request.status}',
      );
    }

    // Batch write: request + rate limit doc for server-side enforcement
    final batch = firestore.batch();
    batch.set(_requestsRef.doc(request.id), request.toFirestore());
    batch.set(
      firestore
          .collection(FirestoreCollections.users)
          .doc(currentUser)
          .collection(FirestoreCollections.userRateLimits)
          .doc('social_requests'),
      {'lastWrite': timestampProvider.serverTimestamp()},
      SetOptions(merge: true),
    );
    await batch.commit();

    logPermissionCheck(
      userId: currentUser,
      resource: 'social_request',
      operation: 'create',
      granted: true,
      details: 'Type: ${request.type.name}, To: ${request.toUserId}',
    );
  }

  Future<SocialRequest?> getRequest(String requestId) async {
    final doc = await _requestsRef.doc(requestId).get();
    if (!doc.exists) return null;
    return SocialRequest.fromMap(doc.id, doc.data() ?? {});
  }

  Future<void> updateRequestStatus(
      String requestId, Map<String, dynamic> data) async {
    final currentUser = requireCurrentUserId();

    final request = await getRequest(requestId);
    if (request == null) {
      throw ResourceNotFoundException(
        'Social request not found',
        resourceType: 'social_request',
        resourceId: requestId,
      );
    }

    // Role-based: sender can cancel, recipient can accept/reject
    if (data['status'] == SocialRequestStatus.cancelled.name) {
      if (currentUser != request.fromUserId) {
        throw PermissionDeniedException(
          'Only the sender can cancel a request',
          resource: 'social_request',
          operation: 'cancel',
          userId: currentUser,
        );
      }
    } else {
      if (currentUser != request.toUserId) {
        throw PermissionDeniedException(
          'Only the recipient can update a request',
          resource: 'social_request',
          operation: 'update',
          userId: currentUser,
        );
      }
    }

    await _requestsRef.doc(requestId).update(data);

    logPermissionCheck(
      userId: currentUser,
      resource: 'social_request',
      operation: 'update',
      granted: true,
      details: 'Request: $requestId',
    );
  }

  /// Delete uses Firestore delete (both sender and recipient allowed by rules)
  Future<void> deleteRequest(String requestId) async {
    final currentUser = requireCurrentUserId();
    final request = await getRequest(requestId);
    if (request == null) return;

    if (currentUser != request.fromUserId && currentUser != request.toUserId) {
      throw PermissionDeniedException(
        'Only sender or recipient can delete a request',
        resource: 'social_request',
        operation: 'delete',
        userId: currentUser,
      );
    }

    await _requestsRef.doc(requestId).delete();

    logPermissionCheck(
      userId: currentUser,
      resource: 'social_request',
      operation: 'delete',
      granted: true,
      details: 'Deleted request $requestId',
    );
  }

  // ── Friend request queries ──

  Future<List<FriendRequest>> getIncomingFriendRequests() async {
    try {
      final uid = requireCurrentUserId();
      final snap = await _requestsRef
          .where('toUserId', isEqualTo: uid)
          .where('type', isEqualTo: SocialRequestType.friend.name)
          .where('status', isEqualTo: SocialRequestStatus.pending.name)
          .get();
      return snap.docs
          .map((doc) => SocialRequest.fromMap(doc.id, doc.data()))
          .map((sr) => sr.toFriendRequest())
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<FriendRequest>> getSentFriendRequests() async {
    try {
      final uid = requireCurrentUserId();
      final snap = await _requestsRef
          .where('fromUserId', isEqualTo: uid)
          .where('type', isEqualTo: SocialRequestType.friend.name)
          .where('status', isEqualTo: SocialRequestStatus.pending.name)
          .get();
      return snap.docs
          .map((doc) => SocialRequest.fromMap(doc.id, doc.data()))
          .map((sr) => sr.toFriendRequest())
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Check if a pending friend request already exists between two users
  Future<bool> friendRequestExists(String fromUserId, String toUserId) async {
    final query = await _requestsRef
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('type', isEqualTo: SocialRequestType.friend.name)
        .where('status', isEqualTo: SocialRequestStatus.pending.name)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  // ── Friend request streams ──

  Stream<List<FriendRequest>> incomingFriendRequestsStream(String userId) {
    return _requestsRef
        .where('toUserId', isEqualTo: userId)
        .where('type', isEqualTo: SocialRequestType.friend.name)
        .where('status', isEqualTo: SocialRequestStatus.pending.name)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SocialRequest.fromMap(doc.id, doc.data()))
            .map((sr) => sr.toFriendRequest())
            .toList());
  }

  Stream<List<FriendRequest>> sentFriendRequestsStream(String userId) {
    return _requestsRef
        .where('fromUserId', isEqualTo: userId)
        .where('type', isEqualTo: SocialRequestType.friend.name)
        .where('status', isEqualTo: SocialRequestStatus.pending.name)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SocialRequest.fromMap(doc.id, doc.data()))
            .map((sr) => sr.toFriendRequest())
            .toList());
  }

  // ── Group invitation queries ──

  Future<List<GroupInvitation>> getReceivedInvitations() async {
    try {
      final uid = requireCurrentUserId();
      final snap = await _requestsRef
          .where('toUserId', isEqualTo: uid)
          .where('type', isEqualTo: SocialRequestType.groupInvitation.name)
          .orderBy('sentAt', descending: true)
          .limit(50)
          .get();
      return snap.docs
          .map((doc) => SocialRequest.fromMap(doc.id, doc.data()))
          .map((sr) => sr.toGroupInvitation())
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<GroupInvitation>> getSentInvitations() async {
    try {
      final uid = requireCurrentUserId();
      final snap = await _requestsRef
          .where('fromUserId', isEqualTo: uid)
          .where('type', isEqualTo: SocialRequestType.groupInvitation.name)
          .orderBy('sentAt', descending: true)
          .limit(50)
          .get();
      return snap.docs
          .map((doc) => SocialRequest.fromMap(doc.id, doc.data()))
          .map((sr) => sr.toGroupInvitation())
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Check if there's a pending invitation for a group and user
  Future<bool> hasPendingInvitation(String groupId, String toUserId) async {
    final query = await _requestsRef
        .where('groupId', isEqualTo: groupId)
        .where('toUserId', isEqualTo: toUserId)
        .where('type', isEqualTo: SocialRequestType.groupInvitation.name)
        .where('status', isEqualTo: SocialRequestStatus.pending.name)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  // ── Group invitation streams ──

  Stream<List<GroupInvitation>> receivedInvitationsStream(String userId) {
    return _requestsRef
        .where('toUserId', isEqualTo: userId)
        .where('type', isEqualTo: SocialRequestType.groupInvitation.name)
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SocialRequest.fromMap(doc.id, doc.data()))
            .map((sr) => sr.toGroupInvitation())
            .toList());
  }

  Stream<List<GroupInvitation>> sentInvitationsStream(String userId) {
    return _requestsRef
        .where('fromUserId', isEqualTo: userId)
        .where('type', isEqualTo: SocialRequestType.groupInvitation.name)
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SocialRequest.fromMap(doc.id, doc.data()))
            .map((sr) => sr.toGroupInvitation())
            .toList());
  }

  // ── Cleanup ──

  /// Get expired pending requests for batch cleanup
  Future<List<DocumentReference<Map<String, dynamic>>>> expiredRequests(
      DateTime now) async {
    final query = await _requestsRef
        .where('status', isEqualTo: SocialRequestStatus.pending.name)
        .where('expiresAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();
    return query.docs.map((d) => d.reference).toList();
  }

  /// Get old requests for cleanup (by user and cutoff date)
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> oldRequests(
      String userId, DateTime cutoffDate) async {
    final query = await _requestsRef
        .where('toUserId', isEqualTo: userId)
        .where('sentAt', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();
    return query.docs;
  }

  /// Batch delete documents
  Future<void> deleteDocuments(
      List<DocumentReference<Map<String, dynamic>>> refs) async {
    if (refs.isEmpty) return;

    final currentUser = requireCurrentUserId();
    final batch = firestore.batch();
    for (final ref in refs) {
      batch.delete(ref);
    }
    await batch.commit();

    logPermissionCheck(
      userId: currentUser,
      resource: 'social_request',
      operation: 'batch_delete',
      granted: true,
      details: 'Count: ${refs.length}',
    );
  }

  /// Batch update documents
  Future<void> updateDocuments(
      List<DocumentReference<Map<String, dynamic>>> refs,
      Map<String, dynamic> data) async {
    if (refs.isEmpty) return;

    final currentUser = requireCurrentUserId();
    final batch = firestore.batch();
    for (final ref in refs) {
      batch.update(ref, data);
    }
    await batch.commit();

    logPermissionCheck(
      userId: currentUser,
      resource: 'social_request',
      operation: 'batch_update',
      granted: true,
      details: 'Count: ${refs.length}',
    );
  }

  /// Cleanup expired requests (mark as expired instead of deleting)
  Future<int> cleanupExpired() async {
    final now = DateTime.now();
    final expiredRefs = await expiredRequests(now);

    if (expiredRefs.isNotEmpty) {
      await updateDocuments(expiredRefs, {
        'status': SocialRequestStatus.expired.name,
        'expiredAt': timestampProvider.serverTimestamp(),
      });
    }

    return expiredRefs.length;
  }

  // ── Statistics ──

  Future<Map<String, int>> getFriendRequestStatistics(String userId) async {
    final results = await Future.wait([
      _requestsRef
          .where('toUserId', isEqualTo: userId)
          .where('type', isEqualTo: SocialRequestType.friend.name)
          .where('status', isEqualTo: SocialRequestStatus.pending.name)
          .count()
          .get(),
      _requestsRef
          .where('fromUserId', isEqualTo: userId)
          .where('type', isEqualTo: SocialRequestType.friend.name)
          .where('status', isEqualTo: SocialRequestStatus.pending.name)
          .count()
          .get(),
    ]);

    return {
      'incoming': results[0].count ?? 0,
      'sent': results[1].count ?? 0,
    };
  }

  Future<Map<String, int>> getInvitationStatistics(String userId) async {
    final results = await Future.wait([
      _requestsRef
          .where('toUserId', isEqualTo: userId)
          .where('type', isEqualTo: SocialRequestType.groupInvitation.name)
          .where('status', isEqualTo: SocialRequestStatus.pending.name)
          .count()
          .get(),
      _requestsRef
          .where('fromUserId', isEqualTo: userId)
          .where('type', isEqualTo: SocialRequestType.groupInvitation.name)
          .where('status', isEqualTo: SocialRequestStatus.pending.name)
          .count()
          .get(),
    ]);

    return {
      'pendingReceived': results[0].count ?? 0,
      'pendingSent': results[1].count ?? 0,
    };
  }
}
