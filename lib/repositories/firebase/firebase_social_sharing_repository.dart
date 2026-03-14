/// Firebase Firestore implementation for comprehensive social content sharing and permission management.
/// This repository provides a complete social sharing platform using Firebase Firestore, enabling
/// users to share recipes, menus, and other content with friends and groups while maintaining
/// sophisticated permission controls, engagement analytics, and sharing lifecycle management.
/// It implements advanced social features for collaborative cooking and community building.
/// **Architecture Integration:**
/// - Extends [BaseFirebaseRepository] for consistent CRUD operations and error handling
/// - Implements [SocialSharingRepository] interface for standardized sharing operations
/// - Integrates with [PermissionValidationMixin] for comprehensive security validation
/// - Uses [AppLogger] for detailed sharing activity monitoring and debugging
/// - Coordinates with notification system for social engagement alerts
/// **Social Sharing Features:**
/// - **Multi-target Sharing**: Share content with individual users or entire groups
/// - **Permission Management**: Granular control over who can access shared content
/// - **Engagement Tracking**: Monitor acceptance, viewing, and interaction patterns
/// - **Sharing Lifecycle**: Complete management from sharing to revocation
/// - **Real-time Streams**: Live updates for shared content discovery
/// - **Statistics Analytics**: Comprehensive sharing and engagement metrics
/// **Security and Privacy:**
/// - **Ownership Validation**: Ensures only content owners can manage sharing permissions
/// - **Self-operation Checks**: Prevents users from accepting/declining on behalf of others
/// - **Access Control**: Validates user permissions before any sharing operations
/// - **Audit Logging**: Complete audit trail for all sharing activities
/// - **Data Protection**: Secure handling of sensitive sharing information

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/social_sharing_repository.dart';
// import '../interfaces/auth_repository.dart'; // Imported from base class
import 'package:butlery/models/shared_content.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// Firebase implementation for social content sharing with comprehensive community engagement features.
/// This repository provides complete social sharing functionality using Firebase Firestore as the
/// backend, enabling users to share cooking content with friends and groups while maintaining
/// sophisticated permission controls and engagement analytics.
/// **Sharing System Architecture:**
/// - **User-to-User Sharing**: Direct sharing with individual friends and community members
/// - **Group Sharing**: Efficient distribution to cooking groups and communities
/// - **Permission Management**: Granular control over content access and modification rights
/// - **Engagement Analytics**: Comprehensive tracking of sharing success and user interaction
/// - **Real-time Updates**: Live streams for immediate sharing notifications and updates
/// **Usage Examples:**
/// ```dart
/// final sharingRepo = FirebaseSocialSharingRepository(
///   authRepository: ServiceLocator.get<AuthRepository>(),
/// );
/// // Share content with specific users
/// await sharingRepo.shareToUsers([friendId1, friendId2], sharedContent);
/// // Share with a cooking group
/// await sharingRepo.shareToGroup(groupId, sharedContent);
/// // Accept shared content
/// await sharingRepo.acceptSharedContent(contentId, userId);
/// // Get sharing analytics
/// final stats = await sharingRepo.getSharingStats(userId);
/// print('Acceptance rate: ${stats['acceptanceRate']}');
/// ```
class FirebaseSocialSharingRepository
    extends BaseFirebaseRepository<SharedContent>
    implements SocialSharingRepository {
  /// Creates a Firebase social sharing repository with dependency injection support.
  /// [firestore] Optional Firestore instance for testing, defaults to production instance
  /// [authRepository] Required authentication repository for user validation and security
  FirebaseSocialSharingRepository({
    super.firestore,
    required super.authRepository,
    super.auditRepository,
    super.timestampProvider,
  });

  @override
  String get collectionName => FirestoreCollections.sharedContent;

  @override
  SharedContent fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return SharedContent.fromFirestore(doc);
  }

  @override
  Map<String, dynamic> toFirestore(SharedContent entity) =>
      entity.toFirestore();

  @override
  String getId(SharedContent entity) => entity.id;
  @override
  Future<bool> validateCreatePermission(
      String userId, SharedContent entity) async {
    // Users can only create shared content as themselves (must be the owner)
    return entity.ownerId == userId;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, SharedContent? entity) async {
    if (entity == null) return false;

    // Owner can always read their shared content
    if (entity.ownerId == userId) return true;

    // Recipients can read content shared with them
    if (entity.sharedWithUserIds.contains(userId)) return true;

    // S6 fix: Verify actual group membership before granting access
    if (entity.sharedWithGroupIds.isNotEmpty) {
      final results = await Future.wait(
        entity.sharedWithGroupIds.map((groupId) async {
          try {
            final groupDoc = await firestore
                .collection('users')
                .doc(entity.ownerId)
                .collection(FirestoreCollections.userFriendCategories)
                .doc(groupId)
                .get();
            if (groupDoc.exists) {
              final data = groupDoc.data() ?? {};
              final members =
                  SerializationUtils.safeStringList(data, 'friendUserIds');
              return members.contains(userId);
            }
          } catch (_) {
            // Skip groups we can't read
          }
          return false;
        }),
      );
      if (results.any((isMember) => isMember)) return true;
    }

    return false;
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, SharedContent entity) async {
    // Only the owner can update sharing permissions and metadata
    return entity.ownerId == userId;
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    // Only the owner can revoke sharing (delete shared content record)
    try {
      final content = await read(resourceId);
      if (content == null) return false;
      return content.ownerId == userId;
    } catch (e) {
      return false;
    }
  }

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
        details:
            'Group: $groupId, Content: ${content.contentType}/${content.contentId}',
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
        details:
            'Users: ${userIds.length}, Content: ${content.contentType}/${content.contentId}',
      );

      AppLogger.info('Content shared to ${userIds.length} users');
    } catch (e) {
      AppLogger.error('Failed to share to users', e);
      throw Exception('Failed to share to users: $e');
    }
  }

  @override
  Stream<List<SharedContent>> getSharedWithMe(String userId) {
    // Optimized (#043): Added limit to prevent unbounded stream
    try {
      return collection
          .where('sharedWithUserIds', arrayContains: userId)
          .orderBy('sharedAt', descending: true)
          .limit(50) // Limit to 50 most recent shares
          .snapshots()
          .map((snapshot) => snapshot.docs.map(fromFirestore).toList());
    } catch (e) {
      AppLogger.error('Failed to get shared content', e);
      return Stream.value([]);
    }
  }

  @override
  Stream<List<SharedContent>> getMySharedContent(String userId) {
    // Optimized (#043): Added limit to prevent unbounded stream
    try {
      return collection
          .where('ownerId', isEqualTo: userId)
          .orderBy('sharedAt', descending: true)
          .limit(50) // Limit to 50 most recent shares
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
        'acceptedBy.$userId': timestampProvider.serverTimestamp(),
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
        'declinedBy.$userId': timestampProvider.serverTimestamp(),
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
      final sharedByMe =
          await collection.where('ownerId', isEqualTo: userId).get();

      // Get content shared with user
      final sharedWithMe = await collection
          .where('sharedWithUserIds', arrayContains: userId)
          .get();

      // Calculate stats
      final int totalShared = sharedByMe.docs.length;
      final int totalReceived = sharedWithMe.docs.length;
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
