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
///   listItems: items,
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
import 'package:butlery/models/unified/unified_shopping_item.dart';
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
  })  : _viewRepository = viewRepository ??
            SharedShoppingViewRepository(
              authRepository: authRepository ?? FirebaseAuthRepository(),
            ),
        _engagementRepository = engagementRepository ??
            SharedShoppingEngagementRepository(
              authRepository: authRepository ?? FirebaseAuthRepository(),
            ),
        _dismissalRepository = dismissalRepository ??
            SharedShoppingDismissalRepository(
              authRepository: authRepository ?? FirebaseAuthRepository(),
            ),
        super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  @override
  String get collectionName => FirestoreCollections.sharedShoppingLists;
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
  List<String> get createRequiredFields => ['listItems', 'listName'];

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
    return firestore.collection(FirestoreCollections.sharedShoppingLists);
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
          'Cannot create shared shopping list for another user');
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
        '✅ Created shared shopping list with ${recipientIds.length} members in subcollection');

    return listId;
  }

  /// Get all shared shopping lists for a specific user
  Future<List<SharedShoppingList>> getSharedShoppingListsForUser(
      String userId) async {
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
          'Cannot access this shared shopping list');
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
    // Use subcollection method (Issue #014: Unlimited views support)
    return await addView(listId, userId);
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
      String userId) async {
    final uid = requireCurrentUserId();

    if (userId != uid) {
      throw PermissionDeniedException(
          'Cannot get joined lists for another user');
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
            '📋 User ${userId.maskedUserId} has no joined shopping lists');
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
      final listIdList = listIds.toList();
      for (var i = 0; i < listIdList.length; i += 10) {
        final end = (i + 10 < listIdList.length) ? i + 10 : listIdList.length;
        final batch = listIdList.sublist(i, end);

        final batchSnapshot = await getCollectionRef()
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        joinedLists.addAll(
          batchSnapshot.docs.map((doc) => fromFirestore(doc)),
        );
      }

      AppLogger.info(
          '📋 User $userId has joined ${joinedLists.length} shopping lists');
      return joinedLists;
    } catch (e) {
      AppLogger.error(
          'Failed to get joined shopping lists for user $userId: $e');
      throw RepositoryException('Failed to retrieve joined shopping lists: $e');
    }
  }

  // SHOPPING LIST ITEMS SUBCOLLECTION CRUD (Issue #015)

  /// Adds an item to the shopping list items subcollection.
  /// **Issue #015**: Items stored in subcollection instead of array.
  /// Updates itemCount atomically via FieldValue.increment.
  /// Validates:
  /// - User has access to the list (owner or member)
  /// - Item has valid data (id, name, amount, unit, category, bought)
  /// Throws:
  /// - [PermissionDeniedException] if user doesn't have access
  /// - [RepositoryException] if operation fails
  Future<void> addItem(String listId, UnifiedShoppingItem item) async {
    try {
      await validateListAccess(listId);

      final itemRef = firestore
          .collection(FirestoreCollections.sharedShoppingLists)
          .doc(listId)
          .collection(FirestoreCollections.items)
          .doc(item.id);

      await itemRef.set(item.toFirestore());

      // Update item count atomically
      await _updateItemCount(listId, increment: 1);

      AppLogger.info('🛒 Added item ${item.name} to shopping list $listId');
    } catch (e) {
      AppLogger.error('Failed to add item to shopping list $listId: $e');
      throw RepositoryException('Failed to add item: $e');
    }
  }

  /// Adds multiple items to the shopping list in a batch operation.
  /// **Issue #015**: Items stored in subcollection. Uses Firestore batch writes
  /// for atomic multi-item addition with itemCount update.
  /// Validates user access before performing batch operation.
  /// Throws:
  /// - [PermissionDeniedException] if user doesn't have access
  /// - [RepositoryException] if batch operation fails
  Future<void> addItemsBatch(
      String listId, List<UnifiedShoppingItem> items) async {
    if (items.isEmpty) return;

    try {
      await validateListAccess(listId);

      final batch = firestore.batch();
      final listRef = firestore
          .collection(FirestoreCollections.sharedShoppingLists)
          .doc(listId);

      // Add all items to subcollection
      for (final item in items) {
        final itemRef =
            listRef.collection(FirestoreCollections.items).doc(item.id);
        batch.set(itemRef, item.toFirestore());
      }

      // Update item count atomically
      batch.update(listRef, {'itemCount': FieldValue.increment(items.length)});

      await batch.commit();

      AppLogger.info('🛒 Added ${items.length} items to shopping list $listId');
    } catch (e) {
      AppLogger.error(
          'Failed to add ${items.length} items to shopping list $listId: $e');
      throw RepositoryException('Failed to add items in batch: $e');
    }
  }

  /// Gets all items for a shopping list from the items subcollection.
  /// **Issue #015**: Items loaded from subcollection, not from main document array.
  /// Returns items ordered by addedAt timestamp (oldest first).
  /// Validates user access before loading items.
  /// Throws:
  /// - [PermissionDeniedException] if user doesn't have access
  /// - [RepositoryException] if query fails
  Future<List<UnifiedShoppingItem>> getItems(String listId) async {
    try {
      await validateListAccess(listId);

      final snapshot = await firestore
          .collection(FirestoreCollections.sharedShoppingLists)
          .doc(listId)
          .collection(FirestoreCollections.items)
          .orderBy('addedAt', descending: false)
          .get();

      final items = snapshot.docs
          .map((doc) => UnifiedShoppingItem.fromFirestore(doc.data()))
          .toList();

      AppLogger.info(
          '🛒 Loaded ${items.length} items from shopping list $listId');
      return items;
    } catch (e) {
      AppLogger.error('Failed to get items from shopping list $listId: $e');
      throw RepositoryException('Failed to retrieve items: $e');
    }
  }

  /// Gets a specific item by ID from the items subcollection.
  /// **Issue #015**: Direct subcollection document access.
  /// Returns null if item doesn't exist.
  /// Validates user access before loading item.
  /// Throws:
  /// - [PermissionDeniedException] if user doesn't have access
  /// - [RepositoryException] if query fails
  Future<UnifiedShoppingItem?> getItem(String listId, String itemId) async {
    try {
      await validateListAccess(listId);

      final doc = await firestore
          .collection(FirestoreCollections.sharedShoppingLists)
          .doc(listId)
          .collection(FirestoreCollections.items)
          .doc(itemId)
          .get();

      if (!doc.exists) return null;

      return UnifiedShoppingItem.fromFirestore(doc.data()!);
    } catch (e) {
      AppLogger.error(
          'Failed to get item $itemId from shopping list $listId: $e');
      throw RepositoryException('Failed to retrieve item: $e');
    }
  }

  /// Updates an item in the shopping list items subcollection.
  /// **Issue #015**: Updates subcollection document, not array element.
  /// Validates user access before updating.
  /// Throws:
  /// - [PermissionDeniedException] if user doesn't have access
  /// - [RepositoryException] if update fails
  Future<void> updateItem(String listId, UnifiedShoppingItem item) async {
    try {
      await validateListAccess(listId);

      await firestore
          .collection(FirestoreCollections.sharedShoppingLists)
          .doc(listId)
          .collection(FirestoreCollections.items)
          .doc(item.id)
          .update(item.toFirestore());

      AppLogger.info('🛒 Updated item ${item.name} in shopping list $listId');
    } catch (e) {
      AppLogger.error('Failed to update item in shopping list $listId: $e');
      throw RepositoryException('Failed to update item: $e');
    }
  }

  /// Removes an item from the shopping list items subcollection.
  /// **Issue #015**: Deletes subcollection document and decrements itemCount.
  /// Validates user access before deleting.
  /// Throws:
  /// - [PermissionDeniedException] if user doesn't have access
  /// - [RepositoryException] if deletion fails
  Future<void> removeItem(String listId, String itemId) async {
    try {
      await validateListAccess(listId);

      await firestore
          .collection(FirestoreCollections.sharedShoppingLists)
          .doc(listId)
          .collection(FirestoreCollections.items)
          .doc(itemId)
          .delete();

      // Update item count atomically
      await _updateItemCount(listId, increment: -1);

      AppLogger.info('🛒 Removed item $itemId from shopping list $listId');
    } catch (e) {
      AppLogger.error('Failed to remove item from shopping list $listId: $e');
      throw RepositoryException('Failed to remove item: $e');
    }
  }

  /// Toggles the bought status of an item in the shopping list.
  /// **Issue #015**: Updates subcollection document with purchase metadata.
  /// When bought=true, adds purchasedByUserId and purchasedAt timestamp.
  /// When bought=false, clears purchase metadata.
  /// Validates user access before updating.
  /// Throws:
  /// - [PermissionDeniedException] if user doesn't have access
  /// - [RepositoryException] if update fails
  Future<void> toggleItemBought(
      String listId, String itemId, bool bought) async {
    try {
      await validateListAccess(listId);

      final updateData = {
        'bought': bought,
        'purchasedByUserId': bought ? authRepository.currentUserId : null,
        'purchasedAt': bought ? timestampProvider.serverTimestamp() : null,
      };

      await firestore
          .collection(FirestoreCollections.sharedShoppingLists)
          .doc(listId)
          .collection(FirestoreCollections.items)
          .doc(itemId)
          .update(updateData);

      AppLogger.info(
          '🛒 Toggled item $itemId bought status to $bought in list $listId');
    } catch (e) {
      AppLogger.error(
          'Failed to toggle item bought status in list $listId: $e');
      throw RepositoryException('Failed to toggle item bought status: $e');
    }
  }

  /// Removes all completed items (bought=true) from the shopping list.
  /// **Issue #015**: Batch deletes from subcollection and recalculates itemCount.
  /// Uses Firestore batch writes for atomic multi-item deletion.
  /// Validates user access before performing batch deletion.
  /// Returns the number of items deleted.
  /// Throws:
  /// - [PermissionDeniedException] if user doesn't have access
  /// - [RepositoryException] if batch operation fails
  Future<int> clearCompletedItems(String listId) async {
    try {
      await validateListAccess(listId);

      // Query all completed items
      final snapshot = await firestore
          .collection(FirestoreCollections.sharedShoppingLists)
          .doc(listId)
          .collection(FirestoreCollections.items)
          .where('bought', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) return 0;

      // Batch delete all completed items
      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      // Recalculate item count to ensure consistency
      await _updateItemCount(listId, recalculate: true);

      final deletedCount = snapshot.docs.length;
      AppLogger.info(
          '🛒 Cleared $deletedCount completed items from list $listId');
      return deletedCount;
    } catch (e) {
      AppLogger.error('Failed to clear completed items from list $listId: $e');
      throw RepositoryException('Failed to clear completed items: $e');
    }
  }

  /// Unchecks all items in the shopping list (sets bought=false).
  /// **Issue #015**: Batch updates subcollection documents and clears purchase metadata.
  /// Uses Firestore batch writes for atomic multi-item update.
  /// Validates user access before performing batch update.
  /// Returns the number of items unchecked.
  /// Throws:
  /// - [PermissionDeniedException] if user doesn't have access
  /// - [RepositoryException] if batch operation fails
  Future<int> uncheckAllItems(String listId) async {
    try {
      await validateListAccess(listId);

      // Query all bought items
      final snapshot = await firestore
          .collection(FirestoreCollections.sharedShoppingLists)
          .doc(listId)
          .collection(FirestoreCollections.items)
          .where('bought', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) return 0;

      // Batch update all items to bought=false
      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'bought': false,
          'purchasedByUserId': null,
          'purchasedAt': null,
        });
      }

      await batch.commit();

      final uncheckedCount = snapshot.docs.length;
      AppLogger.info('🛒 Unchecked $uncheckedCount items in list $listId');
      return uncheckedCount;
    } catch (e) {
      AppLogger.error('Failed to uncheck all items in list $listId: $e');
      throw RepositoryException('Failed to uncheck all items: $e');
    }
  }

  /// Streams items in real-time for collaborative editing.
  /// **Issue #015**: Real-time stream from items subcollection.
  /// Returns a stream that emits the complete item list whenever any item changes.
  /// Items ordered by addedAt timestamp (oldest first).
  /// Validates user access before creating stream.
  /// Throws:
  /// - [PermissionDeniedException] if user doesn't have access
  Stream<List<UnifiedShoppingItem>> streamItems(String listId) {
    try {
      // Note: Access validation happens on first stream event
      return firestore
          .collection(FirestoreCollections.sharedShoppingLists)
          .doc(listId)
          .collection(FirestoreCollections.items)
          .orderBy('addedAt', descending: false)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => UnifiedShoppingItem.fromFirestore(doc.data()))
              .toList());
    } catch (e) {
      AppLogger.error('Failed to create item stream for list $listId: $e');
      throw RepositoryException('Failed to stream items: $e');
    }
  }

  // ITEM COUNT MANAGEMENT (Issue #015)

  /// Updates the cached itemCount field in the main shopping list document.
  /// **Issue #015**: Maintains itemCount consistency with items subcollection.
  /// Supports two modes:
  /// 1. **Increment/Decrement**: Atomically adjusts count (add/remove single item)
  /// 2. **Recalculate**: Queries subcollection and sets exact count (bulk operations)
  /// Parameters:
  /// - [listId]: Shopping list ID
  /// - [increment]: Amount to increment (positive) or decrement (negative). Default: 0
  /// - [recalculate]: If true, recalculates from subcollection. Default: false
  /// Throws:
  /// - [RepositoryException] if update fails
  Future<void> _updateItemCount(
    String listId, {
    int increment = 0,
    bool recalculate = false,
  }) async {
    try {
      final listRef = firestore
          .collection(FirestoreCollections.sharedShoppingLists)
          .doc(listId);

      if (recalculate) {
        // Recalculate from subcollection (for bulk operations)
        final snapshot =
            await listRef.collection(FirestoreCollections.items).get();
        await listRef.update({'itemCount': snapshot.size});
        AppLogger.debug(
            '🛒 Recalculated itemCount for list $listId: ${snapshot.size}');
      } else if (increment != 0) {
        // Atomic increment/decrement (for single item operations)
        await listRef.update({'itemCount': FieldValue.increment(increment)});
        AppLogger.debug('🛒 Updated itemCount for list $listId by $increment');
      }
    } catch (e) {
      AppLogger.error('Failed to update itemCount for list $listId: $e');
      throw RepositoryException('Failed to update item count: $e');
    }
  }

  /// Validates that the current user has access to the shopping list.
  /// **Issue #015**: Access validation for items subcollection operations.
  /// Checks if user is:
  /// - The list owner (sharedByUserId)
  /// - A list member (exists in members subcollection)
  /// Throws:
  /// - [PermissionDeniedException] if user doesn't have access
  /// - [RepositoryException] if validation fails
  Future<void> validateListAccess(String listId) async {
    try {
      final userId = authRepository.currentUserId;
      if (userId == null) {
        throw PermissionDeniedException(
            'User must be authenticated to access shopping list');
      }

      // Check if user is owner
      final listDoc = await firestore
          .collection(FirestoreCollections.sharedShoppingLists)
          .doc(listId)
          .get();

      if (!listDoc.exists) {
        throw RepositoryException('Shopping list not found: $listId');
      }

      final listData = listDoc.data()!;
      final ownerId = listData['sharedByUserId'] as String?;

      if (ownerId == userId) {
        return; // Owner has full access
      }

      // Check if user is a member
      final memberDoc = await firestore
          .collection(FirestoreCollections.sharedShoppingLists)
          .doc(listId)
          .collection(FirestoreCollections.members)
          .doc(userId)
          .get();

      if (!memberDoc.exists) {
        throw PermissionDeniedException(
            'User does not have access to shopping list $listId');
      }
    } catch (e) {
      if (e is PermissionDeniedException || e is AuthenticationException) {
        rethrow;
      }
      AppLogger.error('Failed to validate access for list $listId: $e');
      throw RepositoryException('Failed to validate list access: $e');
    }
  }
}
