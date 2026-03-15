/// Base repository for shared content (recipes, menus, shopping lists) with unified
/// status management, permission validation, and subcollection-based member tracking.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/firebase/base_view_repository.dart';
import 'package:butlery/repositories/firebase/base_engagement_repository.dart';
import 'package:butlery/repositories/firebase/base_dismissal_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/user_counters.dart';
import 'package:butlery/models/shared_content_member.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

abstract class BaseSharedContentRepository<T>
    extends BaseFirebaseRepository<T> {
  BaseSharedContentRepository({
    super.firestore,
    required super.authRepository,
    super.timestampProvider,
  });

  String get contentTypeName;
  String get resourceType;
  List<String> get createRequiredFields;
  String getContentTitle(T entity);
  String get importAction;
  String get importField;
  bool get supportsCollaboration => true;
  bool get tracksCounts => true;

  BaseViewRepository get viewRepository;
  BaseEngagementRepository get engagementRepository;
  BaseDismissalRepository get dismissalRepository;

  /// Counter type key for this content (e.g., 'shared_recipes', 'shared_menus')
  String get counterTypeKey;

  /// Get reference to user counters document
  DocumentReference<Map<String, dynamic>> _getUserCountersRef(String userId) {
    return firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .collection(FirestoreCollections.counters)
        .doc('shared_content');
  }

  /// Increment unread counter for a user (call when sharing content)
  Future<void> incrementUnreadCounter(String userId) async {
    try {
      final counterField = UserCounterIncrements.fieldForType(counterTypeKey);
      await _getUserCountersRef(userId).set({
        counterField: FieldValue.increment(1),
        'totalSharedContent': FieldValue.increment(1),
        'lastUpdated': timestampProvider.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Log but don't fail - counter is best-effort optimization
      AppLogger.warning('Failed to increment counter for $userId: $e');
    }
  }

  /// Decrement unread counter for a user (call when viewing content)
  Future<void> decrementUnreadCounter(String userId) async {
    try {
      final counterField = UserCounterIncrements.fieldForType(counterTypeKey);
      // Use a transaction to ensure we don't go below 0
      await firestore.runTransaction((transaction) async {
        final counterDoc = await transaction.get(_getUserCountersRef(userId));
        if (counterDoc.exists) {
          final currentCount = counterDoc.data()?[counterField] as int? ?? 0;
          if (currentCount > 0) {
            transaction.update(_getUserCountersRef(userId), {
              counterField: FieldValue.increment(-1),
              'lastUpdated': timestampProvider.serverTimestamp(),
            });
          }
        }
      });
    } catch (e) {
      // Log but don't fail - counter is best-effort optimization
      AppLogger.warning('Failed to decrement counter for $userId: $e');
    }
  }

  /// Get unread count from denormalized counter (fast path)
  Future<int> getUnreadCountFromCounter(String userId) async {
    try {
      final counterDoc = await _getUserCountersRef(userId).get();
      if (!counterDoc.exists) return 0;

      final counterField = UserCounterIncrements.fieldForType(counterTypeKey);
      return counterDoc.data()?[counterField] as int? ?? 0;
    } catch (e) {
      AppLogger.warning('Failed to get counter for $userId: $e');
      return 0;
    }
  }

  Future<String> createSharedContent(T entity) async {
    final uid = requireCurrentUserId();

    validateRequiredFields(
      data: toFirestore(entity),
      requiredFields: [
        'sharedByUserId',
        'sharedByDisplayName',
        ...createRequiredFields,
      ],
      resourceType: resourceType,
    );

    try {
      final docRef = getCollectionRef().doc();

      // Create new instance with correct ID
      final entityData = toFirestore(entity);
      await docRef.set(entityData);

      logPermissionCheck(
        userId: uid,
        resource: resourceType,
        operation: 'create',
        granted: true,
        details: 'Title: "${getContentTitle(entity)}"',
      );

      AppLogger.success(
          '✅ Created shared $contentTypeName: ${getContentTitle(entity)}');
      return docRef.id;
    } catch (e) {
      AppLogger.error('Failed to create shared $contentTypeName: $e');
      throw RepositoryException('Failed to create shared $contentTypeName: $e');
    }
  }

  Future<void> markAsViewed(String contentId, String userId) async {
    await _updateUserStatus(contentId, userId, 'viewedByUserIds', 'viewed');
    // Decrement unread counter when content is viewed
    await decrementUnreadCounter(userId);
  }

  Future<void> markAsDismissed(String contentId, String userId) async {
    await addDismissal(contentId, userId);
  }

  Future<void> undismiss(String contentId, String userId) async {
    await removeDismissal(contentId, userId);
  }

  Future<void> markAsImportedOrJoined(String contentId, String userId) async {
    final uid = requireCurrentUserId();

    if (userId != uid) {
      throw PermissionDeniedException(
          'Cannot mark $contentTypeName as $importAction for another user');
    }

    try {
      await addEngagement(contentId, userId, action: importAction);
      await addView(contentId, userId);

      AppLogger.success(
          '✅ Marked shared $contentTypeName $contentId as $importAction by user $userId');

      logPermissionCheck(
        userId: uid,
        resource: resourceType,
        operation: 'mark_$importAction',
        granted: true,
        details: '$contentTypeName: $contentId',
      );
    } catch (e) {
      AppLogger.error(
          'Failed to mark $contentTypeName $contentId as $importAction: $e');
      throw RepositoryException('Failed to update $importAction status: $e');
    }
  }

  Future<List<T>> getSharedContentForUser(
    String userId, {
    int limit = 25,
    DocumentSnapshot? startAfter,
  }) async {
    return await getSharedContentForUserViaSubcollection(
      userId,
      limit: limit,
      startAfter: startAfter,
    );
  }

  @Deprecated('Use getSharedContentForUser with startAfter parameter instead')
  Future<DocumentSnapshot?> getLastDocumentForUser(String userId) async {
    AppLogger.warning(
        'getLastDocumentForUser is deprecated - subcollection queries handle pagination differently');
    return null;
  }

  Future<int> getUnreadCountForUser(String userId) async {
    final uid = requireCurrentUserId();

    if (userId != uid) {
      throw PermissionDeniedException(
          'Cannot get unread count for another user');
    }

    try {
      // Fast path: use denormalized counter
      final count = await getUnreadCountFromCounter(userId);
      AppLogger.info(
          '📊 Unread shared $contentTypeName count for user $userId: $count');
      return count;
    } catch (e) {
      AppLogger.error('Failed to get unread count for user $userId: $e');
      return 0;
    }
  }

  /// Recalculate and sync counter from actual data (use for repair/migration)
  Future<int> recalculateUnreadCount(String userId) async {
    final uid = requireCurrentUserId();

    if (userId != uid) {
      throw PermissionDeniedException(
          'Cannot recalculate count for another user');
    }

    try {
      final sharedContent = await getSharedContentForUserViaSubcollection(
        userId,
        limit: 100,
      );

      final unreadCount = sharedContent
          .where((content) =>
              shouldShowToUser(content, userId) &&
              !isViewedByUser(content, userId))
          .length;

      // Sync counter with actual value
      final counterField = UserCounterIncrements.fieldForType(counterTypeKey);
      await _getUserCountersRef(userId).set({
        counterField: unreadCount,
        'lastUpdated': timestampProvider.serverTimestamp(),
      }, SetOptions(merge: true));

      AppLogger.info(
          '📊 Recalculated unread $contentTypeName count for user $userId: $unreadCount');
      return unreadCount;
    } catch (e) {
      AppLogger.error('Failed to recalculate count for user $userId: $e');
      return 0;
    }
  }

  Future<void> deleteSharedContent(String contentId) async {
    final uid = requireCurrentUserId();

    try {
      final sharedContent = await read(contentId);
      if (sharedContent == null) {
        throw ResourceNotFoundException('Shared $contentTypeName not found',
            resourceType: resourceType, resourceId: contentId);
      }

      if (!isCreatedBy(sharedContent, uid)) {
        throw PermissionDeniedException(
            'Cannot delete shared $contentTypeName - insufficient permissions');
      }

      await getCollectionRef().doc(contentId).delete();

      AppLogger.success(
          '✅ Deleted shared $contentTypeName: ${getContentTitle(sharedContent)}');

      logPermissionCheck(
        userId: uid,
        resource: resourceType,
        operation: 'delete',
        granted: true,
        details: 'Title: "${getContentTitle(sharedContent)}" ($contentId)',
      );
    } catch (e) {
      if (e is PermissionDeniedException || e is ResourceNotFoundException) {
        rethrow;
      }
      AppLogger.error(
          'Failed to delete shared $contentTypeName $contentId: $e');
      throw RepositoryException('Failed to delete shared $contentTypeName: $e');
    }
  }

  Future<void> _updateUserStatus(String contentId, String userId,
      String statusField, String operation) async {
    final uid = requireCurrentUserId();

    if (userId != uid) {
      throw PermissionDeniedException(
          'Cannot update $contentTypeName status for another user');
    }

    try {
      final sharedContent = await read(contentId);
      if (sharedContent == null) {
        throw ResourceNotFoundException('Shared $contentTypeName not found',
            resourceType: resourceType, resourceId: contentId);
      }

      final updateData = <String, dynamic>{
        statusField: FieldValue.arrayUnion([userId]),
      };

      if (operation == 'viewed' && tracksCounts) {
        updateData['viewCount'] = FieldValue.increment(1);
      }

      await getCollectionRef().doc(contentId).update(updateData);

      AppLogger.success(
          '✅ Marked shared $contentTypeName $contentId as $operation by user $userId');

      logPermissionCheck(
        userId: uid,
        resource: resourceType,
        operation: 'mark_$operation',
        granted: true,
        details:
            '$contentTypeName: "${getContentTitle(sharedContent)}" ($contentId)',
      );
    } catch (e) {
      AppLogger.error(
          'Failed to mark $contentTypeName $contentId as $operation: $e');
      if (e is PermissionDeniedException || e is ResourceNotFoundException) {
        rethrow;
      }
      throw RepositoryException('Failed to update $operation status: $e');
    }
  }

  Future<void> addMember(
    String contentId,
    String userId, {
    required String addedBy,
    String? displayName,
    String? avatarUrl,
    String role = 'viewer',
  }) async {
    final uid = requireCurrentUserId();
    final content = await read(contentId);
    if (content == null || !isCreatedBy(content, uid)) {
      throw PermissionDeniedException(
          'Only the owner can add members to $contentTypeName');
    }

    try {
      final member = SharedContentMember(
        userId: userId,
        // V1-QP-001: Use provided displayName or fallback for legacy callers
        displayName: displayName ?? 'Användare',
        avatarUrl: avatarUrl,
        addedAt: DateTime.now(),
        addedBy: addedBy,
        role: role,
      );

      await getCollectionRef()
          .doc(contentId)
          .collection(FirestoreCollections.members)
          .doc(userId)
          .set(member.toFirestore());

      // Increment unread counter for the new member
      await incrementUnreadCounter(userId);

      AppLogger.success(
          '✅ Added user $userId as member to $contentTypeName $contentId');
    } catch (e) {
      AppLogger.error('Failed to add member to $contentTypeName: $e');
      throw RepositoryException('Failed to add member: $e');
    }
  }

  /// Get members with denormalized display info (avoids N+1 user lookups)
  Future<List<SharedContentMember>> getMembersWithInfo(
    String contentId, {
    int? limit,
  }) async {
    try {
      var query = getCollectionRef()
          .doc(contentId)
          .collection(FirestoreCollections.members)
          .orderBy('addedAt', descending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => SharedContentMember.fromFirestore(doc.data()))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to get members with info: $e');
      return [];
    }
  }

  Future<void> removeMember(String contentId, String userId) async {
    final currentUser = requireCurrentUserId();
    final isSelfRemoval = currentUser == userId;

    // Owner can remove anyone; members can only remove themselves
    if (!isSelfRemoval) {
      final content = await read(contentId);
      if (content == null || !isCreatedBy(content, currentUser)) {
        throw PermissionDeniedException(
            'Only the owner can remove other members from $contentTypeName');
      }
    }

    try {
      await getCollectionRef()
          .doc(contentId)
          .collection(FirestoreCollections.members)
          .doc(userId)
          .delete();

      AppLogger.success(
          '✅ Removed user $userId from $contentTypeName $contentId');
    } catch (e) {
      AppLogger.error('Failed to remove member from $contentTypeName: $e');
      throw RepositoryException('Failed to remove member: $e');
    }
  }

  Future<bool> isMember(String contentId, String userId) async {
    try {
      final doc = await getCollectionRef()
          .doc(contentId)
          .collection(FirestoreCollections.members)
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      AppLogger.error('Failed to check membership: $e');
      return false;
    }
  }

  Future<List<String>> getMembers(String contentId, {int? limit}) async {
    try {
      var query = getCollectionRef()
          .doc(contentId)
          .collection(FirestoreCollections.members)
          .orderBy('addedAt', descending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => doc.data()['userId'] as String)
          .toList();
    } catch (e) {
      AppLogger.error('Failed to get members: $e');
      return [];
    }
  }

  Future<void> addView(String contentId, String userId) async {
    try {
      await viewRepository.markAsViewed(contentId);
      AppLogger.success(
          '✅ Added view for user $userId on $contentTypeName $contentId');
    } catch (e) {
      AppLogger.error('Failed to add view: $e');
      throw RepositoryException('Failed to add view: $e');
    }
  }

  Future<bool> hasViewed(String contentId, String userId) async {
    try {
      return await viewRepository.hasViewed(contentId);
    } catch (e) {
      AppLogger.error('Failed to check view status: $e');
      return false;
    }
  }

  Future<void> addEngagement(
    String contentId,
    String userId, {
    required String action,
    String? targetId,
  }) async {
    try {
      await engagementRepository.markAsEngaged(
        contentId,
        action: action,
        targetId: targetId,
      );
      AppLogger.success(
          '✅ Added $action for user $userId on $contentTypeName $contentId');
    } catch (e) {
      AppLogger.error('Failed to add engagement: $e');
      throw RepositoryException('Failed to add engagement: $e');
    }
  }

  Future<bool> hasEngaged(String contentId, String userId) async {
    try {
      return await engagementRepository.hasEngaged(contentId);
    } catch (e) {
      AppLogger.error('Failed to check engagement status: $e');
      return false;
    }
  }

  Future<void> addDismissal(String contentId, String userId,
      {String? reason}) async {
    try {
      await dismissalRepository.dismiss(contentId, reason: reason);

      AppLogger.success(
          '✅ Added dismissal for user $userId on $contentTypeName $contentId');
    } catch (e) {
      AppLogger.error('Failed to add dismissal: $e');
      throw RepositoryException('Failed to add dismissal: $e');
    }
  }

  Future<void> removeDismissal(String contentId, String userId) async {
    try {
      await dismissalRepository.undismiss(contentId);

      AppLogger.success(
          '✅ Removed dismissal for user $userId on $contentTypeName $contentId');
    } catch (e) {
      AppLogger.error('Failed to remove dismissal: $e');
      throw RepositoryException('Failed to remove dismissal: $e');
    }
  }

  Future<bool> hasDismissed(String contentId, String userId) async {
    try {
      return await dismissalRepository.isDismissed(contentId);
    } catch (e) {
      AppLogger.error('Failed to check dismissal status: $e');
      return false;
    }
  }

  Future<void> addCollaborator(String contentId, String userId) async {
    final currentUser = requireCurrentUserId();
    final content = await read(contentId);
    if (content == null || !isCreatedBy(content, currentUser)) {
      throw PermissionDeniedException(
          'Only the owner can add collaborators to $contentTypeName');
    }

    try {
      await getCollectionRef()
          .doc(contentId)
          .collection(FirestoreCollections.collaborators)
          .doc(userId)
          .set({
        'userId': userId,
        'joinedAt': timestampProvider.serverTimestamp(),
        'lastEditAt': timestampProvider.serverTimestamp(),
      }, SetOptions(merge: true));

      AppLogger.success(
          '✅ Added collaborator $userId to $contentTypeName $contentId');
    } catch (e) {
      AppLogger.error('Failed to add collaborator: $e');
      throw RepositoryException('Failed to add collaborator: $e');
    }
  }

  Future<void> removeCollaborator(String contentId, String userId) async {
    final currentUser = requireCurrentUserId();
    final isSelfRemoval = currentUser == userId;
    if (!isSelfRemoval) {
      final content = await read(contentId);
      if (content == null || !isCreatedBy(content, currentUser)) {
        throw PermissionDeniedException(
            'Only the owner can remove other collaborators from $contentTypeName');
      }
    }

    try {
      await getCollectionRef()
          .doc(contentId)
          .collection(FirestoreCollections.collaborators)
          .doc(userId)
          .delete();

      AppLogger.success(
          '✅ Removed collaborator $userId from $contentTypeName $contentId');
    } catch (e) {
      AppLogger.error('Failed to remove collaborator: $e');
      throw RepositoryException('Failed to remove collaborator: $e');
    }
  }

  Future<bool> isCollaborator(String contentId, String userId) async {
    try {
      final doc = await getCollectionRef()
          .doc(contentId)
          .collection(FirestoreCollections.collaborators)
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      AppLogger.error('Failed to check collaborator status: $e');
      return false;
    }
  }

  Future<List<String>> getCollaborators(String contentId, {int? limit}) async {
    try {
      var query = getCollectionRef()
          .doc(contentId)
          .collection(FirestoreCollections.collaborators)
          .orderBy('joinedAt', descending: false);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => doc.data()['userId'] as String)
          .toList();
    } catch (e) {
      AppLogger.error('Failed to get collaborators: $e');
      return [];
    }
  }

  /// Uses Firestore collection group queries to find content where user is a member.
  Future<List<T>> getSharedContentForUserViaSubcollection(
    String userId, {
    int limit = 25,
    DocumentSnapshot? startAfter,
  }) async {
    final uid = requireCurrentUserId();

    if (userId != uid) {
      throw PermissionDeniedException(
          'Cannot access shared $contentTypeName for another user');
    }

    try {
      final memberQuery = firestore
          .collectionGroup('members')
          .where('userId', isEqualTo: userId)
          .limit(limit * 2);

      final memberSnapshot = await memberQuery.get();

      if (memberSnapshot.docs.isEmpty) {
        return [];
      }

      final contentIds = <String>{};
      for (final memberDoc in memberSnapshot.docs) {
        final parentPath = memberDoc.reference.parent.parent?.path ?? 'unknown';
        final contentId = memberDoc.reference.parent.parent?.id;
        final pathSegments = parentPath.split('/');
        final isMatchingCollection =
            pathSegments.isNotEmpty && pathSegments.first == collectionName;

        if (contentId != null && isMatchingCollection) {
          contentIds.add(contentId);
        }
      }

      if (contentIds.isEmpty) {
        return [];
      }

      final batches = <List<String>>[];
      final contentIdList = contentIds.toList();
      for (var i = 0; i < contentIdList.length; i += 10) {
        final end =
            (i + 10 < contentIdList.length) ? i + 10 : contentIdList.length;
        batches.add(contentIdList.sublist(i, end));
      }

      final allContent = <T>[];
      for (final batch in batches) {
        final docFutures = batch.map((id) => getCollectionRef().doc(id).get());
        final docs = await Future.wait(docFutures);
        final validDocs = docs.where((doc) => doc.exists).toList();

        final batchContent = validDocs
            .map((doc) => fromFirestore(doc))
            .where((content) => shouldShowToUser(content, userId))
            .toList();

        allContent.addAll(batchContent);

        if (allContent.length >= limit) {
          break;
        }
      }

      allContent.sort((a, b) => getContentDate(b).compareTo(getContentDate(a)));
      final limitedContent = allContent.take(limit).toList();

      AppLogger.info(
          '📊 Found ${limitedContent.length} shared $contentTypeName for user $userId');
      return limitedContent;
    } catch (e) {
      AppLogger.error(
          'Failed to get shared $contentTypeName for user $userId via subcollections: $e');
      throw RepositoryException(
          'Failed to retrieve shared $contentTypeName: $e');
    }
  }

  bool shouldShowToUser(T content, String userId);
  bool isViewedByUser(T content, String userId);
  bool isCreatedBy(T content, String userId);

  /// Date used for sorting shared content (most recent first).
  DateTime getContentDate(T entity);

  @override
  Future<bool> validateCreatePermission(String userId, T entity) async {
    return isCreatedBy(entity, userId);
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, T? entity) async {
    if (entity == null) return false;
    return shouldShowToUser(entity, userId);
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, T entity) async {
    return isCreatedBy(entity, userId);
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    try {
      final content = await read(resourceId);
      if (content == null) return false;
      return isCreatedBy(content, userId);
    } on PermissionDeniedException {
      return false;
    }
  }
}
