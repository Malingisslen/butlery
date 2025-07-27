// lib/repositories/firebase/firebase_social_sharing_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../interfaces/social_sharing_repository.dart';
// import '../interfaces/auth_repository.dart'; // Imported from base class
import '../../models/shared_content.dart';
import 'base_firebase_repository.dart';
import '../../core/utils/logger.dart';
import '../../core/exceptions/permission_exceptions.dart';

/// Firebase implementation of SocialSharingRepository
/// 
/// Handles all social sharing operations including group and user sharing
class FirebaseSocialSharingRepository extends BaseFirebaseRepository<SharedContent>
    implements SocialSharingRepository {
  
  FirebaseSocialSharingRepository({
    super.firestore,
    required super.authRepository,
  });

  @override
  String get collectionName => 'shared_content';

  @override
  SharedContent fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return SharedContent.fromFirestore(doc);
  }

  @override
  Map<String, dynamic> toFirestore(SharedContent entity) => entity.toFirestore();

  @override
  String getId(SharedContent entity) => entity.id;

  @override
  Future<void> shareToGroup(String groupId, SharedContent content) async {
    final currentUser = requireCurrentUserId();
    
    // Validate user owns the content
    await validateOwnership(
      currentUserId: currentUser,
      resourceOwnerId: content.ownerId,
      resourceType: 'shared_content',
      resourceId: content.id,
    );
    
    try {
      // Create new share with group
      final updatedContent = content.copyWith(
        sharedWithGroupIds: [...content.sharedWithGroupIds, groupId],
      );
      
      await collection.doc(content.id).set(
        updatedContent.toFirestore(),
        SetOptions(merge: true),
      );
      
      // Log the sharing action
      logPermissionCheck(
        userId: currentUser,
        resource: 'shared_content',
        operation: 'share_to_group',
        granted: true,
        details: 'Group: $groupId, Content: ${content.contentType}/${content.contentId}',
      );
      
      AppLogger.info('Content shared to group: $groupId');
    } catch (e) {
      AppLogger.error('Failed to share to group', e);
      throw Exception('Failed to share to group: $e');
    }
  }

  @override
  Future<void> shareToUsers(List<String> userIds, SharedContent content) async {
    final currentUser = requireCurrentUserId();
    
    // Validate user owns the content
    await validateOwnership(
      currentUserId: currentUser,
      resourceOwnerId: content.ownerId,
      resourceType: 'shared_content',
      resourceId: content.id,
    );
    
    try {
      // Create new share with users
      final updatedContent = content.copyWith(
        sharedWithUserIds: [
          ...content.sharedWithUserIds,
          ...userIds.where((id) => !content.sharedWithUserIds.contains(id)),
        ],
      );
      
      await collection.doc(content.id).set(
        updatedContent.toFirestore(),
        SetOptions(merge: true),
      );
      
      // Log the sharing action
      logPermissionCheck(
        userId: currentUser,
        resource: 'shared_content',
        operation: 'share_to_users',
        granted: true,
        details: 'Users: ${userIds.length}, Content: ${content.contentType}/${content.contentId}',
      );
      
      AppLogger.info('Content shared to ${userIds.length} users');
    } catch (e) {
      AppLogger.error('Failed to share to users', e);
      throw Exception('Failed to share to users: $e');
    }
  }

  @override
  Stream<List<SharedContent>> getSharedWithMe(String userId) {
    try {
      return collection
          .where('sharedWithUserIds', arrayContains: userId)
          .orderBy('sharedAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(fromFirestore).toList());
    } catch (e) {
      AppLogger.error('Failed to get shared content', e);
      return Stream.value([]);
    }
  }

  @override
  Stream<List<SharedContent>> getMySharedContent(String userId) {
    try {
      return collection
          .where('ownerId', isEqualTo: userId)
          .orderBy('sharedAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(fromFirestore).toList());
    } catch (e) {
      AppLogger.error('Failed to get my shared content', e);
      return Stream.value([]);
    }
  }

  @override
  Future<void> updateSharingPermissions(
    String contentId,
    List<String> addUserIds,
    List<String> removeUserIds,
  ) async {
    final currentUser = requireCurrentUserId();
    
    try {
      // Get the content to validate ownership
      final doc = await collection.doc(contentId).get();
      if (!doc.exists) {
        throw ResourceNotFoundException(
          'Shared content not found',
          resourceType: 'shared_content',
          resourceId: contentId,
        );
      }
      
      final content = fromFirestore(doc);
      
      // Validate ownership
      await validateOwnership(
        currentUserId: currentUser,
        resourceOwnerId: content.ownerId,
        resourceType: 'shared_content',
        resourceId: contentId,
      );
      
      // Update permissions
      await collection.doc(contentId).update({
        'sharedWithUserIds': FieldValue.arrayUnion(addUserIds),
      });
      
      if (removeUserIds.isNotEmpty) {
        await collection.doc(contentId).update({
          'sharedWithUserIds': FieldValue.arrayRemove(removeUserIds),
        });
      }
      
      AppLogger.info('Updated sharing permissions for content: $contentId');
    } catch (e) {
      AppLogger.error('Failed to update sharing permissions', e);
      rethrow;
    }
  }

  @override
  Future<void> revokeSharing(String contentId) async {
    final currentUser = requireCurrentUserId();
    
    try {
      // Get the content to validate ownership
      final doc = await collection.doc(contentId).get();
      if (!doc.exists) {
        throw ResourceNotFoundException(
          'Shared content not found',
          resourceType: 'shared_content',
          resourceId: contentId,
        );
      }
      
      final content = fromFirestore(doc);
      
      // Validate ownership
      await validateOwnership(
        currentUserId: currentUser,
        resourceOwnerId: content.ownerId,
        resourceType: 'shared_content',
        resourceId: contentId,
      );
      
      // Delete the sharing record
      await collection.doc(contentId).delete();
      
      AppLogger.info('Revoked sharing for content: $contentId');
    } catch (e) {
      AppLogger.error('Failed to revoke sharing', e);
      rethrow;
    }
  }

  @override
  Future<void> acceptSharedContent(String contentId, String userId) async {
    await validateSelfOperation(
      currentUserId: currentUserId,
      targetUserId: userId,
      operation: 'accept shared content',
    );
    
    try {
      await collection.doc(contentId).update({
        'acceptedBy.$userId': FieldValue.serverTimestamp(),
      });
      
      AppLogger.info('User $userId accepted shared content: $contentId');
    } catch (e) {
      AppLogger.error('Failed to accept shared content', e);
      throw Exception('Failed to accept shared content: $e');
    }
  }

  @override
  Future<void> declineSharedContent(String contentId, String userId) async {
    await validateSelfOperation(
      currentUserId: currentUserId,
      targetUserId: userId,
      operation: 'decline shared content',
    );
    
    try {
      await collection.doc(contentId).update({
        'declinedBy.$userId': FieldValue.serverTimestamp(),
      });
      
      AppLogger.info('User $userId declined shared content: $contentId');
    } catch (e) {
      AppLogger.error('Failed to decline shared content', e);
      throw Exception('Failed to decline shared content: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getSharingStats(String userId) async {
    try {
      // Get content shared by user
      final sharedByMe = await collection
          .where('ownerId', isEqualTo: userId)
          .get();
      
      // Get content shared with user
      final sharedWithMe = await collection
          .where('sharedWithUserIds', arrayContains: userId)
          .get();
      
      // Calculate stats
      int totalShared = sharedByMe.docs.length;
      int totalReceived = sharedWithMe.docs.length;
      int acceptedCount = 0;
      int viewedCount = 0;
      
      for (final doc in sharedWithMe.docs) {
        final data = doc.data();
        if (data['acceptedBy']?[userId] != null) {
          acceptedCount++;
        }
        if (data['viewedBy']?[userId] != null) {
          viewedCount++;
        }
      }
      
      return {
        'totalShared': totalShared,
        'totalReceived': totalReceived,
        'acceptedCount': acceptedCount,
        'viewedCount': viewedCount,
        'acceptanceRate': totalReceived > 0 ? acceptedCount / totalReceived : 0,
      };
    } catch (e) {
      AppLogger.error('Failed to get sharing stats', e);
      return {
        'totalShared': 0,
        'totalReceived': 0,
        'acceptedCount': 0,
        'viewedCount': 0,
        'acceptanceRate': 0,
      };
    }
  }
}