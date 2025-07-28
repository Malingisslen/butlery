// lib/repositories/firebase/friends/group_invitation_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

/// Group Invitation Repository
/// 
/// Handles ONLY group invitation operations and cleanup tasks.
/// This includes sending, accepting, managing group invitations and cleanup operations.
class GroupInvitationRepository extends BaseFirebaseRepository<GroupInvitation> {
  GroupInvitationRepository({
    super.firestore,
    AuthRepository? authRepository,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  CollectionReference<Map<String, dynamic>> get _invitationsRef =>
      firestore.collection('group_invitations');

  // ===== BASE CLASS IMPLEMENTATION =====

  @override
  String get collectionName => 'group_invitations';

  @override
  GroupInvitation fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      GroupInvitation.fromMap(doc.id, doc.data() ?? {});

  @override
  Map<String, dynamic> toFirestore(GroupInvitation entity) => entity.toFirestore();

  @override
  String getId(GroupInvitation entity) => entity.id;

  // ===== GROUP INVITATION OPERATIONS =====

  /// Stream received invitations for a user.
  Stream<List<GroupInvitation>> receivedInvitationsStream(String userId) {
    return _invitationsRef
        .where('toUserId', isEqualTo: userId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((doc) => GroupInvitation.fromMap(doc.id, doc.data())).toList());
  }

  /// Stream sent invitations for a user.
  Stream<List<GroupInvitation>> sentInvitationsStream(String userId) {
    return _invitationsRef
        .where('fromUserId', isEqualTo: userId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((doc) => GroupInvitation.fromMap(doc.id, doc.data())).toList());
  }

  /// Get a specific invitation.
  Future<GroupInvitation?> getInvitation(String invitationId) async {
    final doc = await _invitationsRef.doc(invitationId).get();
    if (!doc.exists) return null;
    return GroupInvitation.fromMap(doc.id, doc.data() ?? {});
  }

  /// Save a new group invitation.
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

  /// Update an invitation.
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

  /// Check if there's a pending invitation for a group and user.
  Future<bool> hasPendingInvitation(String groupId, String toUserId) async {
    final query = await _invitationsRef
        .where('groupId', isEqualTo: groupId)
        .where('toUserId', isEqualTo: toUserId)
        .where('status', isEqualTo: GroupInvitationStatus.pending.name)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  /// Get received invitations for current user.
  Future<List<GroupInvitation>> getReceivedInvitations() async {
    try {
      final uid = requireCurrentUserId();
      final snap = await _invitationsRef
          .where('toUserId', isEqualTo: uid)
          .where('status', isEqualTo: GroupInvitationStatus.pending.name)
          .orderBy('sentAt', descending: true)
          .get();
      return snap.docs.map((doc) => GroupInvitation.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get sent invitations for current user.
  Future<List<GroupInvitation>> getSentInvitations() async {
    try {
      final uid = requireCurrentUserId();
      final snap = await _invitationsRef
          .where('fromUserId', isEqualTo: uid)
          .where('status', isEqualTo: GroupInvitationStatus.pending.name)
          .orderBy('sentAt', descending: true)
          .get();
      return snap.docs.map((doc) => GroupInvitation.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      return [];
    }
  }

  /// Accept a group invitation.
  Future<bool> acceptInvitation(String invitationId) async {
    try {
      await updateInvitation(invitationId, {
        'status': GroupInvitationStatus.accepted.name,
        'respondedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Reject a group invitation.
  Future<bool> rejectInvitation(String invitationId) async {
    try {
      await updateInvitation(invitationId, {
        'status': GroupInvitationStatus.rejected.name,
        'respondedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cancel a sent invitation.
  Future<bool> cancelInvitation(String invitationId) async {
    try {
      await updateInvitation(invitationId, {
        'status': GroupInvitationStatus.cancelled.name,
        'respondedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ===== CLEANUP OPERATIONS =====

  /// Get expired invitations that need cleanup.
  Future<List<DocumentReference<Map<String, dynamic>>>> expiredInvitations(
      DateTime now) async {
    final query = await _invitationsRef
        .where('status', isEqualTo: GroupInvitationStatus.pending.name)
        .where('expiresAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();
    return query.docs.map((d) => d.reference).toList();
  }

  /// Get old invitations for cleanup.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> oldInvitations(
      String userId, DateTime cutoffDate) async {
    final query = await _invitationsRef
        .where('toUserId', isEqualTo: userId)
        .where('sentAt', isLessThan: Timestamp.fromDate(cutoffDate))
        .get();
    return query.docs;
  }

  /// Delete multiple documents in batch.
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
    
    final batch = firestore.batch();
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

  /// Update multiple documents in batch.
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
    
    final batch = firestore.batch();
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

  // ===== INVITATION STATISTICS =====

  /// Get invitation statistics for a user.
  Future<Map<String, int>> getInvitationStatistics(String userId) async {
    final receivedQuery = await _invitationsRef
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: GroupInvitationStatus.pending.name)
        .count()
        .get();
    
    final sentQuery = await _invitationsRef
        .where('fromUserId', isEqualTo: userId)
        .where('status', isEqualTo: GroupInvitationStatus.pending.name)
        .count()
        .get();

    return {
      'pendingReceived': receivedQuery.count ?? 0,
      'pendingSent': sentQuery.count ?? 0,
    };
  }

  /// Get invitations for a specific group.
  Future<List<GroupInvitation>> getGroupInvitations(String groupId, {GroupInvitationStatus? status}) async {
    Query<Map<String, dynamic>> query = _invitationsRef
        .where('groupId', isEqualTo: groupId);
    
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }
    
    final snap = await query.orderBy('sentAt', descending: true).get();
    return snap.docs.map((doc) => GroupInvitation.fromMap(doc.id, doc.data())).toList();
  }

  /// Cleanup expired invitations.
  Future<int> cleanupExpiredInvitations() async {
    final now = DateTime.now();
    final expiredRefs = await expiredInvitations(now);
    
    if (expiredRefs.isNotEmpty) {
      // Update to expired status instead of deleting
      await updateDocuments(expiredRefs, {
        'status': GroupInvitationStatus.expired.name,
        'expiredAt': FieldValue.serverTimestamp(),
      });
    }
    
    return expiredRefs.length;
  }
}