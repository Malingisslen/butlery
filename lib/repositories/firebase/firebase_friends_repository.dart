// lib/repositories/firebase/firebase_friends_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

/// Repository handling friend requests and friends collections in Firestore.
///
/// Refactored to extend BaseFirebaseRepository for UserProfile CRUD operations,
/// eliminating 25+ lines of duplicate code while maintaining specialized functionality.
class FirebaseFriendsRepository extends BaseFirebaseRepository<UserProfile>
    implements FriendsRepository {
  FirebaseFriendsRepository({
    super.firestore,
    AuthRepository? authRepository,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  CollectionReference<Map<String, dynamic>> get _friendRequestsRef =>
      FirebaseFirestore.instance.collection('friend_requests');

  CollectionReference<Map<String, dynamic>> _userFriendsRef(String userId) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('friends');

  CollectionReference<Map<String, dynamic>> _categoriesRef(String userId) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('friendCategories');

  CollectionReference<Map<String, dynamic>> get _invitationsRef =>
      FirebaseFirestore.instance.collection('group_invitations');

  // ===== BASE CLASS IMPLEMENTATION =====

  @override
  String get collectionName => 'public_profiles';

  @override
  UserProfile fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      UserProfile.fromMap(doc.id, doc.data() ?? {});

  @override
  Map<String, dynamic> toFirestore(UserProfile entity) => entity.toFirestore();

  @override
  String getId(UserProfile entity) => entity.uid;

  // ===== SPECIALIZED COLLECTIONS ACCESS =====

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

  @override
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

  @override
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
    await addMutualFriends(req.fromUserId, req.toUserId);
    return true;
  }

  @override
  Future<bool> rejectFriendRequest(String requestId) async {
    final req = await fetchRequest(requestId);
    if (req == null) return false;
    await updateRequest(req.reject());
    return true;
  }

  @override
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
  @override
  Future<bool> requestExists(String fromUserId, String toUserId) async {
    final query = await _friendRequestsRef
        .where('fromUserId', isEqualTo: fromUserId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: FriendRequestStatus.pending.name)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  /// Check if users are already friends.
  @override
  Future<bool> areFriends(String userId1, String userId2) async {
    final doc = await _userFriendsRef(userId1).doc(userId2).get();
    return doc.exists;
  }

  /// Add users to each other's friends collections and update counts.
  @override
  Future<void> addMutualFriends(String userId1, String userId2) async {
    final batch = FirebaseFirestore.instance.batch();

    final user1Ref = _userFriendsRef(userId1).doc(userId2);
    final user2Ref = _userFriendsRef(userId2).doc(userId1);

    batch.set(user1Ref, {'addedAt': FieldValue.serverTimestamp()});
    batch.set(user2Ref, {'addedAt': FieldValue.serverTimestamp()});

    final user1Profile = collection.doc(userId1);
    final user2Profile = collection.doc(userId2);
    batch.update(user1Profile, {'friendsCount': FieldValue.increment(1)});
    batch.update(user2Profile, {'friendsCount': FieldValue.increment(1)});

    await batch.commit();
  }

  /// Remove users from each other's friends collections and update counts.
  @override
  Future<void> removeMutualFriends(String userId1, String userId2) async {
    final batch = FirebaseFirestore.instance.batch();

    final user1Ref = _userFriendsRef(userId1).doc(userId2);
    final user2Ref = _userFriendsRef(userId2).doc(userId1);

    batch.delete(user1Ref);
    batch.delete(user2Ref);

    final user1Profile = collection.doc(userId1);
    final user2Profile = collection.doc(userId2);
    batch.update(user1Profile, {'friendsCount': FieldValue.increment(-1)});
    batch.update(user2Profile, {'friendsCount': FieldValue.increment(-1)});

    await batch.commit();
  }

  @override
  Future<bool> removeFriend(String friendUserId) async {
    try {
      final current = requireCurrentUserId();
      await removeMutualFriends(current, friendUserId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Retrieve friend ids for a user.
  @override
  Future<List<String>> fetchFriendIds(String userId) async {
    final snapshot = await _userFriendsRef(userId).get();
    return snapshot.docs.map((d) => d.id).toList();
  }

  @override
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

  @override
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

  /// Retrieve user profiles for a list of ids.
  @override
  Future<List<UserProfile>> fetchFriendProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    const batchSize = 10;
    final profiles = <UserProfile>[];
    for (var i = 0; i < userIds.length; i += batchSize) {
      final batch = userIds.skip(i).take(batchSize).toList();
      final query =
          await collection.where(FieldPath.documentId, whereIn: batch).get();
      for (final doc in query.docs) {
        profiles.add(UserProfile.fromMap(doc.id, doc.data()));
      }
    }
    return profiles;
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

  // ===== Category methods =====

  @override
  Future<void> saveCategory(String userId, FriendCategory category) async {
    // Validate user is saving their own category
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'save friend category',
    );
    
    // Validate required fields
    validateRequiredFields(
      data: category.toFirestore(),
      requiredFields: ['name', 'friendUserIds'],
      resourceType: 'friend category',
    );
    
    await _categoriesRef(userId).doc(category.id).set(category.toFirestore());
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'friend_category',
      operation: 'create',
      granted: true,
    );
  }

  @override
  Future<void> updateCategory(
      String userId, String categoryId, Map<String, dynamic> data) async {
    // Validate user owns the category they're updating
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'update friend category',
    );
    
    await _categoriesRef(userId).doc(categoryId).update(data);
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'friend_category',
      operation: 'update',
      granted: true,
      details: 'Category: $categoryId',
    );
  }

  @override
  Future<void> deleteCategory(String userId, String categoryId) async {
    // Validate user owns the category they're deleting
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'delete friend category',
    );
    
    await _categoriesRef(userId).doc(categoryId).delete();
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'friend_category',
      operation: 'delete',
      granted: true,
      details: 'Category: $categoryId',
    );
  }

  @override
  Future<List<FriendCategory>> fetchCategories(String userId) async {
    final snap = await _categoriesRef(userId).get();
    return snap.docs.map((doc) => FriendCategory.fromMap(doc.id, doc.data())).toList();
  }

  @override
  Future<void> createCategoryForUser(String userId, FriendCategory category) async {
    // Validate user is creating their own category
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'create friend category',
    );
    
    // Validate required fields
    validateRequiredFields(
      data: category.toFirestore(),
      requiredFields: ['name', 'friendUserIds'],
      resourceType: 'friend category',
    );
    
    await _categoriesRef(userId).doc(category.id).set(category.toFirestore());
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'friend_category',
      operation: 'create',
      granted: true,
    );
  }

  @override
  Future<void> updateCategoryMembers(
      String userId, String categoryId, List<String> memberIds) async {
    // Validate user owns the category they're updating
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: userId,
      operation: 'update friend category members',
    );
    
    await _categoriesRef(userId).doc(categoryId).update({
      'friendUserIds': memberIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'friend_category',
      operation: 'update_members',
      granted: true,
      details: 'Category: $categoryId, Members: ${memberIds.length}',
    );
  }

  @override
  Future<FriendCategory?> getCategory(String userId, String categoryId) async {
    final doc = await _categoriesRef(userId).doc(categoryId).get();
    if (!doc.exists) return null;
    return FriendCategory.fromMap(doc.id, doc.data() ?? {});
  }

  // ===== Invitation methods =====

  @override
  Stream<List<GroupInvitation>> receivedInvitationsStream(String userId) {
    return _invitationsRef
        .where('toUserId', isEqualTo: userId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((doc) => GroupInvitation.fromMap(doc.id, doc.data())).toList());
  }

  @override
  Stream<List<GroupInvitation>> sentInvitationsStream(String userId) {
    return _invitationsRef
        .where('fromUserId', isEqualTo: userId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((doc) => GroupInvitation.fromMap(doc.id, doc.data())).toList());
  }

  @override
  Future<GroupInvitation?> getInvitation(String invitationId) async {
    final doc = await _invitationsRef.doc(invitationId).get();
    if (!doc.exists) return null;
    return GroupInvitation.fromMap(doc.id, doc.data() ?? {});
  }

  @override
  Future<void> saveInvitation(GroupInvitation invitation) async {
    // Validate user is the sender of the invitation
    final currentUser = requireCurrentUserId();
    await validateSelfOperation(
      currentUserId: currentUser,
      targetUserId: invitation.fromUserId,
      operation: 'send group invitation',
    );
    
    // Validate required fields
    validateRequiredFields(
      data: invitation.toFirestore(),
      requiredFields: ['fromUserId', 'toUserId', 'groupId', 'status', 'sentAt'],
      resourceType: 'group invitation',
    );
    
    // Ensure status is pending for new invitations
    if (invitation.status != GroupInvitationStatus.pending) {
      throw SecurityViolationException(
        'New invitations must have pending status',
        details: 'Status was: ${invitation.status}',
      );
    }
    
    await _invitationsRef.doc(invitation.id).set(invitation.toFirestore());
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'group_invitation',
      operation: 'create',
      granted: true,
      details: 'To user: ${invitation.toUserId}, Group: ${invitation.groupId}',
    );
  }

  @override
  Future<void> updateInvitation(
      String invitationId, Map<String, dynamic> data) async {
    final currentUser = requireCurrentUserId();
    
    // Get the invitation to check permissions
    final invitation = await getInvitation(invitationId);
    if (invitation == null) {
      throw ResourceNotFoundException(
        'Invitation not found',
        resourceType: 'group_invitation',
        resourceId: invitationId,
      );
    }
    
    // Only the recipient can accept/reject an invitation
    if (currentUser != invitation.toUserId) {
      throw PermissionDeniedException(
        'Only the recipient can update an invitation',
        resource: 'group_invitation',
        operation: 'update',
        userId: currentUser,
      );
    }
    
    await _invitationsRef.doc(invitationId).update(data);
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'group_invitation',
      operation: 'update',
      granted: true,
      details: 'Invitation: $invitationId',
    );
  }

  @override
  Future<List<DocumentReference<Map<String, dynamic>>>> expiredInvitations(
      DateTime now) async {
    final query = await _invitationsRef
        .where('status', isEqualTo: GroupInvitationStatus.pending.name)
        .where('expiresAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();
    return query.docs.map((d) => d.reference).toList();
  }

  @override
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> oldInvitations(
      String userId, DateTime cutoffDate) async {
    final query = await _invitationsRef
        .where('toUserId', isEqualTo: userId)
        .where('sentAt', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();
    return query.docs;
  }

  @override
  Future<void> deleteDocuments(
      List<DocumentReference<Map<String, dynamic>>> refs) async {
    if (refs.isEmpty) return;
    
    final currentUser = requireCurrentUserId();
    
    // Validate ownership for each document before deletion
    for (final ref in refs) {
      final doc = await ref.get();
      if (doc.exists) {
        final data = doc.data();
        // Check if it's a user-owned document (has userId or fromUserId)
        final ownerId = data?['userId'] ?? data?['fromUserId'] ?? data?['toUserId'];
        if (ownerId != null && ownerId != currentUser) {
          throw PermissionDeniedException(
            'Cannot delete document not owned by user',
            resource: ref.path,
            operation: 'delete',
            userId: currentUser,
          );
        }
      }
    }
    
    final batch = FirebaseFirestore.instance.batch();
    for (final ref in refs) {
      batch.delete(ref);
    }
    await batch.commit();
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'documents',
      operation: 'batch_delete',
      granted: true,
      details: 'Count: ${refs.length}',
    );
  }

  @override
  Future<void> updateDocuments(
      List<DocumentReference<Map<String, dynamic>>> refs,
      Map<String, dynamic> data) async {
    if (refs.isEmpty) return;
    
    final currentUser = requireCurrentUserId();
    
    // Validate ownership for each document before update
    for (final ref in refs) {
      final doc = await ref.get();
      if (doc.exists) {
        final docData = doc.data();
        // Check if it's a user-owned document (has userId or fromUserId)
        final ownerId = docData?['userId'] ?? docData?['fromUserId'] ?? docData?['toUserId'];
        if (ownerId != null && ownerId != currentUser) {
          throw PermissionDeniedException(
            'Cannot update document not owned by user',
            resource: ref.path,
            operation: 'update',
            userId: currentUser,
          );
        }
      }
    }
    
    final batch = FirebaseFirestore.instance.batch();
    for (final ref in refs) {
      batch.update(ref, data);
    }
    await batch.commit();
    
    logPermissionCheck(
      userId: currentUser,
      resource: 'documents',
      operation: 'batch_update',
      granted: true,
      details: 'Count: ${refs.length}',
    );
  }

  @override
  Future<bool> hasPendingInvitation(String groupId, String toUserId) async {
    final query = await _invitationsRef
        .where('groupId', isEqualTo: groupId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: GroupInvitationStatus.pending.name)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }
}
