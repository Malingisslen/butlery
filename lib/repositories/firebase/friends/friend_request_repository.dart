/// Firebase implementation for friend request lifecycle management.
/// Handles creation, acceptance, rejection, and cancellation with security validation.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

class FriendRequestRepository extends BaseFirebaseRepository<FriendRequest> {
  /// Creates a friend request repository with dependency injection support.
  /// [firestore] Optional Firestore instance for testing, defaults to production instance
  /// [authRepository] Optional authentication repository, defaults to FirebaseAuthRepository
  FriendRequestRepository({
    super.firestore,
    AuthRepository? authRepository,
    super.timestampProvider,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  CollectionReference<Map<String, dynamic>> get _friendRequestsRef =>
      firestore.collection(FirestoreCollections.friendRequests);
  @override
  String get collectionName => FirestoreCollections.friendRequests;

  @override
  FriendRequest fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      FriendRequest.fromMap(doc.id, doc.data() ?? {});

  @override
  Map<String, dynamic> toFirestore(FriendRequest entity) =>
      entity.toFirestore();

  @override
  String getId(FriendRequest entity) => entity.id;
  @override
  Future<bool> validateCreatePermission(
      String userId, FriendRequest entity) async {
    // Users can only create friend requests from their own account
    return userId == entity.fromUserId;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, FriendRequest? entity) async {
    if (entity == null) return false;
    // Users can read requests they sent or received
    return userId == entity.fromUserId || userId == entity.toUserId;
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, FriendRequest entity) async {
    // Sender can cancel, recipient can accept/reject
    return userId == entity.fromUserId || userId == entity.toUserId;
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    // Users can delete requests they sent or received
    try {
      final request = await fetchRequest(resourceId);
      if (request == null) return false;
      return userId == request.fromUserId || userId == request.toUserId;
    } catch (e) {
      return false;
    }
  }

  /// Send a new friend request.
  Future<void> sendRequest(FriendRequest request) async {
    // Validate that the sender is creating their own request
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: request.fromUserId,
      operation: 'send friend request',
    );

    // Validate required fields
    validateRequiredFields(
      data: request.toFirestore(),
      requiredFields: ['fromUserId', 'toUserId', 'status', 'sentAt'],
      resourceType: 'friend request',
    );

    // Ensure status is pending for new requests
    if (request.status != FriendRequestStatus.pending) {
      throw SecurityViolationException(
        'New friend requests must have pending status',
        details: 'Status was: ${request.status}',
      );
    }

    // Batch write: request + rate limit doc for server-side enforcement
    final batch = firestore.batch();
    batch.set(_friendRequestsRef.doc(request.id), request.toFirestore());
    batch.set(
      firestore
          .collection(FirestoreCollections.users)
          .doc(currentUser)
          .collection(FirestoreCollections.userRateLimits)
          .doc('friend_requests'),
      {'lastWrite': timestampProvider.serverTimestamp()},
      SetOptions(merge: true),
    );
    await batch.commit();

    logPermissionCheck(
      userId: currentUser,
      resource: 'friend_request',
      operation: 'create',
      granted: true,
      details: 'To user: ${request.toUserId}',
    );
  }

  /// Send a friend request to another user.
  Future<bool> sendFriendRequest(String toUserId, {String? message}) async {
    try {
      final fromId = requireCurrentUserId();

      // Can't send request to yourself
      if (fromId == toUserId) {
        throw SecurityViolationException(
          'Cannot send friend request to yourself',
        );
      }

      final exists = await requestExists(fromId, toUserId);
      if (exists) return false;

      final request = FriendRequest.create(
        fromUserId: fromId,
        toUserId: toUserId,
        message: message,
      );
      await sendRequest(request);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update an existing friend request document.
  Future<void> updateRequest(FriendRequest request) async {
    final currentUser = requireCurrentUserId();

    // Check permissions based on the status change
    if (request.status == FriendRequestStatus.cancelled) {
      // Only the sender can cancel their own request
      if (currentUser != request.fromUserId) {
        throw PermissionDeniedException(
          'Only the sender can cancel a friend request',
          resource: 'friend_request',
          operation: 'cancel',
          userId: currentUser,
        );
      }
    } else if (request.status == FriendRequestStatus.accepted ||
        request.status == FriendRequestStatus.rejected) {
      // Only the recipient can accept/reject
      if (currentUser != request.toUserId) {
        throw PermissionDeniedException(
          'Only the recipient can accept or reject a friend request',
          resource: 'friend_request',
          operation: 'update',
          userId: currentUser,
        );
      }
    } else {
      throw SecurityViolationException(
        'Invalid friend request status change',
        details: 'Status was: ${request.status}',
      );
    }

    await _friendRequestsRef.doc(request.id).update(request.toFirestore());

    logPermissionCheck(
      userId: currentUser,
      resource: 'friend_request',
      operation: 'update',
      granted: true,
      details: 'Status: ${request.status}',
    );
  }

  /// Non-transactional accept path — status update only, no friendship creation.
  /// Production UI uses FriendsManagementOperations.acceptFriendRequest() instead.
  @visibleForTesting
  Future<bool> acceptFriendRequest(String requestId) async {
    final req = await fetchRequest(requestId);
    if (req == null) {
      throw ResourceNotFoundException(
        'Friend request not found',
        resourceType: 'friend_request',
        resourceId: requestId,
      );
    }

    // Validate current user is the recipient
    final currentUser = requireCurrentUserId();
    if (currentUser != req.toUserId) {
      logPermissionCheck(
        userId: currentUser,
        resource: 'friend_request',
        operation: 'accept',
        granted: false,
        details: 'Not the recipient',
      );
      return false;
    }

    await updateRequest(req.accept());
    return true;
  }

  /// Reject a friend request.
  Future<bool> rejectFriendRequest(String requestId) async {
    final req = await fetchRequest(requestId);
    if (req == null) return false;
    await updateRequest(req.reject());
    return true;
  }

  /// Cancel a sent friend request.
  /// Uses delete instead of update because Firestore rules only allow the
  /// recipient (toUserId) to update status. The delete rule permits both parties.
  Future<bool> cancelFriendRequest(String requestId) async {
    final req = await fetchRequest(requestId);
    if (req == null) return false;

    final currentUser = requireCurrentUserId();
    if (currentUser != req.fromUserId) {
      throw PermissionDeniedException(
        'Only the sender can cancel a friend request',
        resource: 'friend_request',
        operation: 'cancel',
        userId: currentUser,
      );
    }

    await _friendRequestsRef.doc(requestId).delete();

    logPermissionCheck(
      userId: currentUser,
      resource: 'friend_request',
      operation: 'cancel_delete',
      granted: true,
      details: 'Deleted request $requestId',
    );
    return true;
  }

  /// Fetch a friend request by id.
  Future<FriendRequest?> fetchRequest(String requestId) async {
    final doc = await _friendRequestsRef.doc(requestId).get();
    if (!doc.exists) return null;
    return FriendRequest.fromMap(doc.id, doc.data() ?? {});
  }

  /// Check if a pending request already exists between two users.
  Future<bool> requestExists(String fromUserId, String toUserId) async {
    final query = await _friendRequestsRef
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: FriendRequestStatus.pending.name)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  /// Get incoming friend requests for current user.
  Future<List<FriendRequest>> getIncomingRequests() async {
    try {
      final uid = requireCurrentUserId();
      final snap = await _friendRequestsRef
          .where('toUserId', isEqualTo: uid)
          .where('status', isEqualTo: FriendRequestStatus.pending.name)
          .get();
      return snap.docs
          .map((doc) => FriendRequest.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get sent friend requests for current user.
  Future<List<FriendRequest>> getSentRequests() async {
    try {
      final uid = requireCurrentUserId();
      final snap = await _friendRequestsRef
          .where('fromUserId', isEqualTo: uid)
          .where('status', isEqualTo: FriendRequestStatus.pending.name)
          .get();
      return snap.docs
          .map((doc) => FriendRequest.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream incoming friend requests for the current user.
  /// Optimized (#043): Added limit to prevent unbounded stream
  Stream<List<FriendRequest>> incomingRequestsStream(String userId) {
    return _friendRequestsRef
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: FriendRequestStatus.pending.name)
        .limit(50) // Limit to 50 pending requests
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendRequest.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Stream sent friend requests for the current user.
  /// Optimized (#043): Added limit to prevent unbounded stream
  Stream<List<FriendRequest>> sentRequestsStream(String userId) {
    return _friendRequestsRef
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: FriendRequestStatus.pending.name)
        .limit(50) // Limit to 50 pending requests
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendRequest.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Get friend request statistics for a user.
  Future<Map<String, int>> getRequestStatistics(String userId) async {
    final incomingQuery = await _friendRequestsRef
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: FriendRequestStatus.pending.name)
        .count()
        .get();

    final sentQuery = await _friendRequestsRef
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: FriendRequestStatus.pending.name)
        .count()
        .get();

    return {
      'incoming': incomingQuery.count ?? 0,
      'sent': sentQuery.count ?? 0,
    };
  }

  /// Check if there are any pending requests between two users (either direction).
  Future<bool> hasPendingRequestBetween(String userId1, String userId2) async {
    final query1 = await _friendRequestsRef
        .where('fromUserId', isEqualTo: userId1)
        .where('toUserId', isEqualTo: userId2)
        .where('status', isEqualTo: FriendRequestStatus.pending.name)
        .limit(1)
        .get();

    if (query1.docs.isNotEmpty) return true;

    final query2 = await _friendRequestsRef
        .where('fromUserId', isEqualTo: userId2)
        .where('toUserId', isEqualTo: userId1)
        .where('status', isEqualTo: FriendRequestStatus.pending.name)
        .limit(1)
        .get();

    return query2.docs.isNotEmpty;
  }
}
