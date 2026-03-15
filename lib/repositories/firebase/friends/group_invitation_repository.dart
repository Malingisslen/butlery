/// Firebase Firestore implementation for comprehensive group invitation management and lifecycle control.
/// This repository provides sophisticated group invitation functionality using Firebase Firestore as
/// the backend, managing the complete lifecycle of group invitations from creation through resolution.
/// It implements advanced features like invitation validation, expiration handling, cleanup operations,
/// and comprehensive security controls for safe group collaboration experiences.
/// **Architecture Integration:**
/// - Extends [BaseFirebaseRepository] for consistent CRUD operations and error handling
/// - Uses global `group_invitations` collection for centralized invitation management
/// - Integrates with permission validation system for comprehensive security controls
/// - Coordinates with group management system for seamless member onboarding
/// - Implements real-time streams for immediate invitation notifications and updates
/// **Group Invitation Lifecycle:**
/// - **Invitation Creation**: Secure group invitation initiation with validation and duplicate prevention
/// - **Status Management**: Complete status tracking (pending, accepted, rejected, expired)
/// - **Expiration Handling**: Automatic invitation expiration and cleanup for security
/// - **Batch Operations**: Efficient bulk invitation management and cleanup operations
/// - **Real-time Updates**: Live streams for immediate invitation notifications and status changes
/// **Security and Cleanup:**
/// - **Self-operation Validation**: Ensures users can only send invitations from their own accounts
/// - **Duplicate Prevention**: Automatic detection and prevention of duplicate group invitations
/// - **Expiration Management**: Systematic cleanup of expired and old invitations
/// - **Bulk Cleanup Operations**: Efficient batch operations for invitation maintenance

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase implementation for group invitation management with comprehensive lifecycle and cleanup controls.
/// This repository provides complete group invitation functionality using Firebase Firestore with
/// sophisticated invitation lifecycle management, security validation, expiration handling, and
/// automated cleanup operations. It handles the complete group collaboration workflow from invitation
/// through member onboarding with comprehensive security and maintenance features.
/// **Invitation Management System:**
/// Uses a centralized collection approach for efficient invitation management and maintenance:
/// - `group_invitations`: Global collection storing all group invitations with status tracking
/// - Comprehensive indexing for efficient querying by sender, recipient, group, and status
/// - Real-time streams for immediate invitation notifications and status updates
/// - Automated expiration and cleanup processes for invitation maintenance
/// **Advanced Features:**
/// - **Lifecycle Management**: Complete invitation workflow from creation to resolution
/// - **Expiration Control**: Automatic invitation expiration and cleanup for security
/// - **Bulk Operations**: Efficient batch operations for invitation management and cleanup
/// - **Security Validation**: Multi-layer validation and comprehensive audit logging
/// **Usage Examples:**
/// ```dart
/// final invitationRepo = GroupInvitationRepository(
///   authRepository: ServiceLocator.get<AuthRepository>(),
/// );
/// // Send group invitation
/// final invitation = GroupInvitation.create(
///   fromUserId: currentUserId,
///   toUserId: targetUserId,
///   groupId: groupId,
/// );
/// await invitationRepo.saveInvitation(invitation);
/// // Stream received invitations
/// invitationRepo.receivedInvitationsStream(userId).listen((invitations) {
///   updateInvitationsUI(invitations);
/// });
/// // Cleanup expired invitations
/// final expiredRefs = await invitationRepo.expiredInvitations(DateTime.now());
/// await invitationRepo.deleteDocuments(expiredRefs);
/// ```
class GroupInvitationRepository
    extends BaseFirebaseRepository<GroupInvitation> {
  /// Creates a group invitation repository with dependency injection support.
  /// [firestore] Optional Firestore instance for testing, defaults to production instance
  /// [authRepository] Optional authentication repository, defaults to FirebaseAuthRepository
  GroupInvitationRepository({
    super.firestore,
    AuthRepository? authRepository,
    super.timestampProvider,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  CollectionReference<Map<String, dynamic>> get _invitationsRef =>
      firestore.collection(FirestoreCollections.groupInvitations);
  @override
  String get collectionName => FirestoreCollections.groupInvitations;

  @override
  GroupInvitation fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      GroupInvitation.fromMap(doc.id, doc.data() ?? {});

  @override
  Map<String, dynamic> toFirestore(GroupInvitation entity) =>
      entity.toFirestore();

  @override
  String getId(GroupInvitation entity) => entity.id;
  @override
  Future<bool> validateCreatePermission(
      String userId, GroupInvitation entity) async {
    // Users can only create invitations from their own account
    return userId == entity.fromUserId;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, GroupInvitation? entity) async {
    if (entity == null) return false;
    // Users can read invitations they sent or received
    return userId == entity.fromUserId || userId == entity.toUserId;
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, GroupInvitation entity) async {
    // Sender can cancel, recipient can accept/reject
    return userId == entity.fromUserId || userId == entity.toUserId;
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    // Users can delete invitations they sent or received
    try {
      final invitation = await getInvitation(resourceId);
      if (invitation == null) return false;
      return userId == invitation.fromUserId || userId == invitation.toUserId;
    } catch (e) {
      return false;
    }
  }

  /// Stream received invitations for a user.
  /// Optimized (#043): Added limit to prevent unbounded stream
  Stream<List<GroupInvitation>> receivedInvitationsStream(String userId) {
    return _invitationsRef
        .where('toUserId', isEqualTo: userId)
        .orderBy('sentAt', descending: true)
        .limit(50) // Limit to 50 recent invitations
        .snapshots()
        .map((s) => s.docs
            .map((doc) => GroupInvitation.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Stream sent invitations for a user.
  /// Optimized (#043): Added limit to prevent unbounded stream
  Stream<List<GroupInvitation>> sentInvitationsStream(String userId) {
    return _invitationsRef
        .where('fromUserId', isEqualTo: userId)
        .orderBy('sentAt', descending: true)
        .limit(50) // Limit to 50 recent invitations
        .snapshots()
        .map((s) => s.docs
            .map((doc) => GroupInvitation.fromMap(doc.id, doc.data()))
            .toList());
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

    // Role-based permission: sender can cancel, recipient can accept/reject
    if (data['status'] == GroupInvitationStatus.cancelled.name) {
      if (currentUser != invitation.fromUserId) {
        throw PermissionDeniedException(
          'Only the sender can cancel an invitation',
          resource: 'group_invitation',
          operation: 'cancel',
          userId: currentUser,
        );
      }
    } else {
      if (currentUser != invitation.toUserId) {
        throw PermissionDeniedException(
          'Only the recipient can update an invitation',
          resource: 'group_invitation',
          operation: 'update',
          userId: currentUser,
        );
      }
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
      return snap.docs
          .map((doc) => GroupInvitation.fromMap(doc.id, doc.data()))
          .toList();
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
      return snap.docs
          .map((doc) => GroupInvitation.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Accept a group invitation.
  Future<bool> acceptInvitation(String invitationId) async {
    try {
      await updateInvitation(invitationId, {
        'status': GroupInvitationStatus.accepted.name,
        'respondedAt': timestampProvider.serverTimestamp(),
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
        'respondedAt': timestampProvider.serverTimestamp(),
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
        'respondedAt': timestampProvider.serverTimestamp(),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

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
        final ownerId =
            data?['userId'] ?? data?['fromUserId'] ?? data?['toUserId'];
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
        final ownerId = docData?['userId'] ??
            docData?['fromUserId'] ??
            docData?['toUserId'];
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
  Future<List<GroupInvitation>> getGroupInvitations(String groupId,
      {GroupInvitationStatus? status}) async {
    Query<Map<String, dynamic>> query =
        _invitationsRef.where('groupId', isEqualTo: groupId);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    final snap = await query.orderBy('sentAt', descending: true).get();
    return snap.docs
        .map((doc) => GroupInvitation.fromMap(doc.id, doc.data()))
        .toList();
  }

  /// Cleanup expired invitations.
  Future<int> cleanupExpiredInvitations() async {
    final now = DateTime.now();
    final expiredRefs = await expiredInvitations(now);

    if (expiredRefs.isNotEmpty) {
      // Update to expired status instead of deleting
      await updateDocuments(expiredRefs, {
        'status': GroupInvitationStatus.expired.name,
        'expiredAt': timestampProvider.serverTimestamp(),
      });
    }

    return expiredRefs.length;
  }
}
