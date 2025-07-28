// lib/repositories/firebase/friends/friend_request_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

/// Friend Request Repository
/// 
/// Handles ONLY friend request operations and management.
/// This includes sending, accepting, rejecting, and managing friend requests.
class FriendRequestRepository extends BaseFirebaseRepository<FriendRequest> {
  FriendRequestRepository({
    super.firestore,
    AuthRepository? authRepository,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  CollectionReference<Map<String, dynamic>> get _friendRequestsRef =>
      firestore.collection('friend_requests');

  // ===== BASE CLASS IMPLEMENTATION =====

  @override
  String get collectionName => 'friend_requests';

  @override
  FriendRequest fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      FriendRequest.fromMap(doc.id, doc.data() ?? {});

  @override
  Map<String, dynamic> toFirestore(FriendRequest entity) => entity.toFirestore();

  @override
  String getId(FriendRequest entity) => entity.id;

  // ===== FRIEND REQUEST OPERATIONS =====

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
    
    await _friendRequestsRef.doc(request.id).set(request.toFirestore());
    
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
    
    // Only the recipient can update (accept/reject) a friend request
    if (currentUser != request.toUserId) {
      throw PermissionDeniedException(
        'Only the recipient can update a friend request',
        resource: 'friend_request',
        operation: 'update',
        userId: currentUser,
      );
    }
    
    // Validate status change is allowed
    if (request.status != FriendRequestStatus.accepted && 
        request.status != FriendRequestStatus.rejected) {
      throw SecurityViolationException(
        'Friend request can only be accepted or rejected',
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

  /// Accept a friend request.
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
  Future<bool> cancelFriendRequest(String requestId) async {
    final req = await fetchRequest(requestId);
    if (req == null) return false;
    await updateRequest(req.cancel());
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
      return snap.docs.map((doc) => FriendRequest.fromMap(doc.id, doc.data())).toList();
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
      return snap.docs.map((doc) => FriendRequest.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream incoming friend requests for the current user.
  Stream<List<FriendRequest>> incomingRequestsStream(String userId) {
    return _friendRequestsRef
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: FriendRequestStatus.pending.name)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FriendRequest.fromMap(doc.id, doc.data())).toList());
  }

  /// Stream sent friend requests for the current user.
  Stream<List<FriendRequest>> sentRequestsStream(String userId) {
    return _friendRequestsRef
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: FriendRequestStatus.pending.name)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FriendRequest.fromMap(doc.id, doc.data())).toList());
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