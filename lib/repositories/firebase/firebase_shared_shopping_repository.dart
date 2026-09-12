/// Firebase repository for shared shopping list management with consistent sharing patterns.
/// This repository implements unified sharing functionality following Single Responsibility Principle,
/// matching the patterns established by other shared content repositories for consistent API design.
/// It provides complete shared shopping list operations while maintaining clean separation from
/// business logic and ensuring consistent behavior across all shared content types.
/// **Single Responsibility Focus:**
/// This repository exclusively handles shared shopping list data operations:
/// - **Shared Shopping List Storage**: Complete CRUD operations for shared shopping lists in Firestore
/// - **Status Management**: Read/unread, joined/dismissed status tracking with atomic updates
/// - **Permission Validation**: Comprehensive access control for shared shopping list operations
/// - **Query Operations**: Efficient retrieval of shared lists with user-specific filtering
/// **What This Repository Does NOT Handle:**
/// - UI concerns and presentation logic (handled by ViewModels and UI components)
/// - Business logic and validation (handled by services and business layer)
/// - Collaborative list creation (handled by shopping services)
/// - User authentication (handled by auth services)
/// **Shared Shopping Repository Features:**
/// - **Consistent API**: Unified operations matching SharedRecipe and SharedMenu patterns
/// - **Status Tracking**: Read/unread, joined/dismissed status with efficient batch updates
/// - **Permission Security**: Comprehensive access validation with audit logging
/// - **Query Optimization**: Efficient Firestore queries with user-specific filtering
/// - **Error Handling**: Robust exception handling with meaningful error messages
/// **Usage Examples:**
/// ```dart
/// // Initialize repository
/// final sharedShoppingRepo = FirebaseSharedShoppingRepository();
/// // Create shared shopping list
/// final sharedList = SharedShoppingList.create(
///   sharedByUserId: currentUserId,
///   sharedByDisplayName: 'Anna Andersson',
///   sharedToUserIds: [friend1Id, friend2Id],
///   shareMessage: 'Min veckohandling',
///   listName: 'Veckohandling v.45',
/// );
/// await sharedShoppingRepo.createSharedShoppingList(sharedList);
/// // Get shared lists for user
/// final sharedLists = await sharedShoppingRepo.getSharedShoppingListsForUser(userId);
/// // Update status
/// await sharedShoppingRepo.markAsViewed(listId, userId);
/// await sharedShoppingRepo.markAsJoined(listId, userId);
/// await sharedShoppingRepo.markAsDismissed(listId, userId);
/// ```

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/repositories/firebase/base_shared_content_repository.dart';
import 'package:butlery/repositories/firebase/base_view_repository.dart';
import 'package:butlery/repositories/firebase/base_engagement_repository.dart';
import 'package:butlery/repositories/firebase/base_dismissal_repository.dart';
import 'package:butlery/repositories/firebase/shared_content/shared_shopping_view_repository.dart';
import 'package:butlery/repositories/firebase/shared_content/shared_shopping_engagement_repository.dart';
import 'package:butlery/repositories/firebase/shared_content/shared_shopping_dismissal_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/extensions/iterable_extensions.dart';

/// Firebase repository for shared shopping list operations with consistent API patterns
class FirebaseSharedShoppingRepository
    extends BaseSharedContentRepository<SharedShoppingList> {
  final SharedShoppingViewRepository _viewRepository;
  final SharedShoppingEngagementRepository _engagementRepository;
  final SharedShoppingDismissalRepository _dismissalRepository;

  FirebaseSharedShoppingRepository({
    super.firestore,
    AuthRepository? authRepository,
    super.timestampProvider,
    SharedShoppingViewRepository? viewRepository,
    SharedShoppingEngagementRepository? engagementRepository,
    SharedShoppingDismissalRepository? dismissalRepository,
  }) : _viewRepository =
           viewRepository ??
           SharedShoppingViewRepository(
             firestore: firestore,
             authRepository: authRepository ?? FirebaseAuthRepository(),
           ),
       _engagementRepository =
           engagementRepository ??
           SharedShoppingEngagementRepository(
             firestore: firestore,
             authRepository: authRepository ?? FirebaseAuthRepository(),
           ),
       _dismissalRepository =
           dismissalRepository ??
           SharedShoppingDismissalRepository(
             firestore: firestore,
             authRepository: authRepository ?? FirebaseAuthRepository(),
           ),
       super(
         authRepository: authRepository ?? FirebaseAuthRepository(),
       );

  @override
  String get collectionName => FirestoreCollections.sharedContent;

  @override
  String get contentType => 'shopping_list';
  @override
  BaseViewRepository get viewRepository => _viewRepository;

  @override
  BaseEngagementRepository get engagementRepository => _engagementRepository;

  @override
  BaseDismissalRepository get dismissalRepository => _dismissalRepository;
  @override
  String get contentTypeName => 'shopping_list';

  @override
  String get counterTypeKey => 'shared_shopping_lists';

  @override
  String get resourceType => 'shared_shopping_list';

  @override
  List<String> get createRequiredFields => ['listName'];

  @override
  String getContentTitle(SharedShoppingList entity) => entity.listName;

  @override
  String get importAction => 'joined';

  @override
  String get importField => 'joinedByUserIds';

  @override
  bool get supportsCollaboration => true;

  @override
  bool get tracksCounts => false; // Shopping lists don't track view/join counts
  @override
  CollectionReference<Map<String, dynamic>> getCollectionRef() {
    return firestore.collection(FirestoreCollections.sharedContent);
  }

  @override
  SharedShoppingList fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return SharedShoppingList.fromFirestore(doc);
  }

  @override
  Map<String, dynamic> toFirestore(SharedShoppingList entity) {
    return entity.toFirestore();
  }

  @override
  String getId(SharedShoppingList entity) => entity.id;
  @override
  bool shouldShowToUser(SharedShoppingList content, String userId) {
    // Note (Issue #014): Array-based status methods removed.
    // Actual dismissed/viewed filtering happens via subcollection queries.
    // Shopping lists are always collaborative, so allow access if owner or shared.
    return true; // Actual member validation happens via subcollection queries
  }

  @override
  bool isViewedByUser(SharedShoppingList content, String userId) {
    // Note (Issue #014): Array-based status removed.
    // Use hasViewed() repository method for actual viewed status.
    // This sync method defaults to false; call hasViewed() for accurate status.
    return false;
  }

  @override
  bool isCreatedBy(SharedShoppingList content, String userId) {
    return content.sharedByUserId == userId;
  }

  @override
  DateTime getContentDate(SharedShoppingList entity) => entity.sharedAt;

  /// Create new shared shopping list with comprehensive validation
  /// Note (Issue #014): recipientIds must be passed separately as sharedToUserIds
  /// is no longer stored in the model (tracked in Firestore subcollections instead).
  Future<String> createSharedShoppingList(
    SharedShoppingList sharedShoppingList, {
    required List<String> recipientIds,
  }) async {
    final uid = requireCurrentUserId();

    // Shopping list-specific validations
    if (sharedShoppingList.sharedByUserId != uid) {
      throw PermissionDeniedException(
        'Cannot create shared shopping list for another user',
      );
    }

    if (recipientIds.isEmpty) {
      throw ArgumentError('Must specify at least one recipient');
    }

    // Create the shared shopping list document
    final listId = await createSharedContent(sharedShoppingList);

    // Add all recipients to members subcollection (Issue #014: Unlimited sharing)
    for (final recipientId in recipientIds) {
      await addMember(listId, recipientId, addedBy: uid);
    }

    AppLogger.success(
      '✅ Created shared shopping list with ${recipientIds.length} members in subcollection',
    );

    return listId;
  }

  /// Get all shared shopping lists for a specific user
  Future<List<SharedShoppingList>> getSharedShoppingListsForUser(
    String userId,
  ) async {
    // Use subcollection-based query (Issue #014: Unlimited sharing support)
    return await getSharedContentForUserViaSubcollection(userId);
  }

  /// Get specific shared shopping list by ID
  Future<SharedShoppingList?> getSharedShoppingList(String listId) async {
    final uid = requireCurrentUserId();

    // Fetch document directly without base class permission check (Issue #014)
    // We need to check members subcollection, which requires async call
    final doc = await getCollectionRef().doc(listId).get();

    if (!doc.exists) {
      return null;
    }

    final sharedList = fromFirestore(doc);

    // Shopping list-specific permission validation (Issue #014)
    // Check if user is owner or member via subcollection
    final isOwner = sharedList.sharedByUserId == uid;
    final isMember = await this.isMember(listId, uid);
    final canAccess = isOwner || isMember;

    if (!canAccess) {
      throw PermissionDeniedException(
        'Cannot access this shared shopping list',
      );
    }

    // Shopping list-specific logging
    logPermissionCheck(
      userId: uid,
      resource: 'shared_shopping_list',
      operation: 'read',
      granted: true,
      details: 'List: "${sharedList.listName}" ($listId)',
    );

    return sharedList;
  }

  /// Mark shared shopping list as viewed by user
  @override
  Future<void> markAsViewed(String listId, String userId) async {
    await addView(listId, userId);
    await decrementUnreadCounter(userId);
  }

  /// Mark shared shopping list as joined by user
  Future<void> markAsJoined(String listId, String userId) async {
    // Use subcollection method (Issue #014: Unlimited joins support)
    return await addEngagement(listId, userId, action: 'join');
  }

  /// Mark shared shopping list as dismissed by user
  @override
  Future<void> markAsDismissed(String listId, String userId) async {
    // Use subcollection method (Issue #014: Unlimited dismissals support)
    return await addDismissal(listId, userId);
  }

  /// Remove dismissal status for user (restore visibility)
  @override
  Future<void> undismiss(String listId, String userId) async {
    // Use subcollection method (Issue #014)
    return await removeDismissal(listId, userId);
  }

  /// Delete shared shopping list (only by creator)
  Future<void> deleteSharedShoppingList(String listId) async {
    // Delegate to base class method
    return await deleteSharedContent(listId);
  }

  /// Get unread shared shopping lists count for user
  @override
  Future<int> getUnreadCountForUser(String userId) async {
    // Delegate to base class method
    return await super.getUnreadCountForUser(userId);
  }

  /// Get joined shared shopping lists for user
  Future<List<SharedShoppingList>> getJoinedShoppingListsForUser(
    String userId,
  ) async {
    final uid = requireCurrentUserId();

    if (userId != uid) {
      throw PermissionDeniedException(
        'Cannot get joined lists for another user',
      );
    }

    try {
      // Query engagements subcollection (Issue #014: Unlimited joins support)
      final engagementsSnapshot = await firestore
          .collectionGroup('engagements')
          .where('userId', isEqualTo: userId)
          .where('action', isEqualTo: 'join')
          .limit(200)
          .get();

      if (engagementsSnapshot.docs.isEmpty) {
        AppLogger.info(
          '📋 User ${userId.maskedUserId} has no joined shopping lists',
        );
        return [];
      }

      // Extract list IDs from engagement documents
      final listIds = <String>{};
      for (final engagementDoc in engagementsSnapshot.docs) {
        final listId = engagementDoc.reference.parent.parent?.id;
        if (listId != null) {
          listIds.add(listId);
        }
      }

      // Batch fetch shopping list documents (max 10 per query)
      final joinedLists = <SharedShoppingList>[];
      for (final batch in listIds.chunked(kFirestoreWhereInLimit)) {
        final batchSnapshot = await getCollectionRef()
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        joinedLists.addAll(
          batchSnapshot.docs.map((doc) => fromFirestore(doc)),
        );
      }

      AppLogger.info(
        '📋 User ${userId.maskedUserId} has joined ${joinedLists.length} shopping lists',
      );
      return joinedLists;
    } catch (e) {
      AppLogger.error(
        'Failed to get joined shopping lists for user ${userId.maskedUserId}: $e',
      );
      throw RepositoryException('Failed to retrieve joined shopping lists: $e');
    }
  }
}
