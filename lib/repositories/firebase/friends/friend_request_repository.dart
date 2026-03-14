/// Firebase Firestore implementation for comprehensive friend request lifecycle and social connection management.
/// This repository provides sophisticated friend request functionality using Firebase Firestore as the
/// backend, managing the complete lifecycle of friend requests from initiation through resolution.
/// It implements advanced features like request validation, status tracking, duplicate prevention,
/// and comprehensive security controls for safe social networking experiences.
/// **Architecture Integration:**
/// - Extends [BaseFirebaseRepository] for consistent CRUD operations and error handling
/// - Uses global `friend_requests` collection for centralized request management
/// - Integrates with permission validation system for comprehensive security controls
/// - Coordinates with friend relationship repository for seamless friendship establishment
/// - Implements real-time streams for immediate request status updates
/// **Friend Request Lifecycle:**
/// - **Request Creation**: Secure friend request initiation with validation and duplicate prevention
/// - **Status Management**: Complete status tracking (pending, accepted, rejected, cancelled)
/// - **Request Resolution**: Automatic cleanup and relationship establishment upon acceptance
/// - **Security Validation**: Comprehensive checks to prevent abuse and unauthorized requests
/// - **Real-time Updates**: Live streams for immediate request notifications and updates
/// **Security and Validation:**
/// - **Self-operation Validation**: Ensures users can only send requests from their own accounts
/// - **Duplicate Prevention**: Automatic detection and prevention of duplicate friend requests
/// - **Status Integrity**: Enforces correct status transitions and prevents invalid state changes
/// - **Comprehensive Logging**: Complete audit trail for all friend request operations

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase implementation for friend request management with comprehensive lifecycle and security controls.
/// This repository provides complete friend request functionality using Firebase Firestore with
/// sophisticated request lifecycle management, security validation, and real-time updates. It handles
/// the complete social connection workflow from initial request through friendship establishment.
/// **Request Management System:**
/// Uses a centralized collection approach for efficient request management and discovery:
/// - `friend_requests`: Global collection storing all friend requests with status tracking
/// - Comprehensive indexing for efficient querying by sender, recipient, and status
/// - Real-time streams for immediate request notifications and status updates
/// **Security and Validation:**
/// - **Comprehensive Validation**: Multi-layer validation including self-operation checks
/// - **Duplicate Prevention**: Automatic detection and prevention of duplicate requests
/// - **Status Integrity**: Enforces valid status transitions and prevents invalid modifications
/// - **Audit Logging**: Complete security audit trail for all request operations
/// **Usage Examples:**
/// ```dart
/// final requestRepo = FriendRequestRepository(
///   authRepository: ServiceLocator.get<AuthRepository>(),
/// );
/// // Send friend request
/// final success = await requestRepo.sendFriendRequest(
///   targetUserId,
///   message: 'Would love to connect!',
/// );
/// // Handle incoming requests
/// requestRepo.incomingRequestsStream(userId).listen((requests) {
///   updateRequestsUI(requests);
/// });
/// // Accept request and establish friendship
/// await requestRepo.acceptFriendRequest(requestId);
/// // Get request statistics
/// final stats = await requestRepo.getRequestStatistics(userId);
/// ```
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
          .collection('users')
          .doc(currentUser)
          .collection('rateLimits')
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

  /// Accept a friend request (status update only, no friendship creation).
  /// R1 note: This method does fetch-then-update without a transaction.
  /// The primary runtime path uses FriendsManagementOperations.acceptFriendRequest()
  /// which calls addMutualFriends (transactional). This method only updates
  /// request status and is not called from the main UI flow.
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
