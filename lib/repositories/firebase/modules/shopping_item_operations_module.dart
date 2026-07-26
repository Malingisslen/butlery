// lib/repositories/firebase/modules/shopping_item_operations_module.dart

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/extensions/iterable_extensions.dart';

/// Module handling shopping item operations with dual storage support.
/// Supports two storage strategies:
/// - Personal lists: Items in subcollection (/items)
/// - Collaborative lists: Items inline in document
///
/// BUT-1665: this module is the entry point the shopping UI actually reaches
/// (view → viewmodel → UnifiedShoppingService → ShoppingItemManagementModule →
/// repository → here), so every collaborative item write goes through
/// [mutateCollaborativeList], which rebuilds the `items` array from the LIVE
/// document inside a transaction. Rebuilding it from [readList]'s cached copy
/// silently dropped whatever another household member ticked in between.
class ShoppingItemOperationsModule {
  final FirebaseFirestore firestore;
  final AuthRepository authRepository;
  final String Function() requireCurrentUserId;
  final Future<UnifiedShoppingList?> Function(String id) readList;
  final Future<UnifiedShoppingList> Function(
    String listId,
    UnifiedShoppingList Function(UnifiedShoppingList live) mutate,
  )
  mutateCollaborativeList;
  final CollectionReference<Map<String, dynamic>> Function(String userId)
  getUserCollection;
  final Future<void> Function({
    required String currentUserId,
    required String resourceOwnerId,
    required String resourceType,
    required String resourceId,
  })
  validateOwnership;
  final void Function({
    required Map<String, dynamic> data,
    required List<String> requiredFields,
    required String resourceType,
  })
  validateRequiredFields;
  final void Function({
    required String userId,
    required String resource,
    required String operation,
    required bool granted,
    String? details,
  })
  logPermissionCheck;

  ShoppingItemOperationsModule({
    required this.firestore,
    required this.authRepository,
    required this.requireCurrentUserId,
    required this.readList,
    required this.mutateCollaborativeList,
    required this.getUserCollection,
    required this.validateOwnership,
    required this.validateRequiredFields,
    required this.logPermissionCheck,
  });

  /// Rebuilds [live] with [items] and stamps the shared-list activity fields.
  /// Always applied to the transaction's live document, never to a cached one.
  UnifiedShoppingList _withItems(
    UnifiedShoppingList live,
    List<UnifiedShoppingItem> items,
    String uid,
  ) {
    final now = clock.now().toUtc();
    return live.copyWith(
      items: items,
      updatedAt: now,
      lastActivityAt: now,
      lastActivityByUserId: uid,
      lastActivityByDisplayName: authRepository.currentUser?.displayName,
    );
  }

  /// Reads the list so the caller can route on its type and verify ownership,
  /// throwing [ResourceNotFoundException] when it is gone. For a collaborative
  /// list this copy is only a router — the write itself re-reads the live
  /// document inside [mutateCollaborativeList].
  Future<UnifiedShoppingList> _requireList(String listId) async {
    final list = await readList(listId);
    if (list == null) {
      throw ResourceNotFoundException(
        'Shopping list not found',
        resourceType: 'shopping_list',
        resourceId: listId,
      );
    }
    return list;
  }

  /// Add item to shopping list (handles both personal and collaborative)
  Future<void> addItem(String listId, UnifiedShoppingItem item) async {
    final uid = requireCurrentUserId();

    // Verify list exists and user has access
    final list = await _requireList(listId);

    // Validate item data
    validateRequiredFields(
      data: item.toFirestore(),
      requiredFields: ['name', 'id'],
      resourceType: 'shopping_item',
    );

    if (list.type == ListType.collaborative) {
      AppLogger.info(
        'Adding item to collaborative list (inline storage)',
        'ShoppingRepository',
      );

      await mutateCollaborativeList(
        listId,
        (live) => _withItems(live, [...live.items, item], uid),
      );
    } else {
      // Handle personal lists - items stored in subcollection
      AppLogger.info(
        'Adding item to personal list (subcollection storage)',
        'ShoppingRepository',
      );

      // For personal lists, verify ownership
      await validateOwnership(
        currentUserId: uid,
        resourceOwnerId: list.ownerId,
        resourceType: 'shopping_list',
        resourceId: listId,
      );

      await getUserCollection(uid)
          .doc(listId)
          .collection(FirestoreCollections.items)
          .doc(item.id)
          .set(item.toFirestore());
    }

    logPermissionCheck(
      userId: uid,
      resource: 'shopping_item',
      operation: 'add',
      granted: true,
      details: 'List: $listId, Type: ${list.type}',
    );
  }

  /// Add multiple items to a list using Firebase batch operations
  Future<void> addItemsBatch(
    String listId,
    List<UnifiedShoppingItem> items,
  ) async {
    final uid = requireCurrentUserId();

    // Verify list exists and user has access
    final list = await _requireList(listId);

    if (items.isEmpty) return;

    // Validate all items before batch operation
    for (final item in items) {
      validateRequiredFields(
        data: item.toFirestore(),
        requiredFields: ['name', 'id'],
        resourceType: 'shopping_item',
      );
    }

    if (list.type == ListType.collaborative) {
      // Validate collaborative list edit permissions before adding items
      final userPermission = list.memberPermissions[uid];
      final canEdit =
          userPermission == SharedListPermission.admin ||
          userPermission == SharedListPermission.edit;

      if (!canEdit) {
        AppLogger.warning(
          'PERMISSION DENIED: User ${uid.maskedUserId} cannot edit collaborative list ${list.id} (permission: $userPermission)',
          'ShoppingRepository',
        );
        throw PermissionDeniedException(
          AppLocale.current.shoppingListEditPermissionDenied,
          resource: 'collaborative_list:${list.id}',
          userId: uid,
        );
      }

      AppLogger.info(
        'Adding ${items.length} items to collaborative list (inline storage) - permission validated',
        'ShoppingRepository',
      );

      await mutateCollaborativeList(
        listId,
        (live) => _withItems(live, [...live.items, ...items], uid),
      );
    } else {
      // Handle personal lists - items stored in subcollection
      AppLogger.info(
        'Adding ${items.length} items to personal list (subcollection storage)',
        'ShoppingRepository',
      );

      // For personal lists, verify ownership
      await validateOwnership(
        currentUserId: uid,
        resourceOwnerId: list.ownerId,
        resourceType: 'shopping_list',
        resourceId: listId,
      );

      // Use Firebase batch for atomic operation
      final batch = firestore.batch();
      final itemsCollection = getUserCollection(
        uid,
      ).doc(listId).collection(FirestoreCollections.items);

      for (final item in items) {
        batch.set(itemsCollection.doc(item.id), item.toFirestore());
      }

      // Execute batch operation
      await batch.commit();
    }

    logPermissionCheck(
      userId: uid,
      resource: 'shopping_item',
      operation: 'batch_add',
      granted: true,
      details: 'List: $listId, Items: ${items.length}, Type: ${list.type}',
    );
  }

  /// Update an existing item in the shopping list atomically
  Future<void> updateItem(String listId, UnifiedShoppingItem item) async {
    final uid = requireCurrentUserId();

    final list = await _requireList(listId);

    if (list.type == ListType.collaborative) {
      // Only the edited item is replaced; every other entry comes from the
      // live document, so a concurrent tick on a different item survives. An
      // item another member deleted meanwhile is not resurrected.
      await mutateCollaborativeList(
        listId,
        (live) => _withItems(
          live,
          live.items
              .map((existing) => existing.id == item.id ? item : existing)
              .toList(),
          uid,
        ),
      );
    } else {
      await validateOwnership(
        currentUserId: uid,
        resourceOwnerId: list.ownerId,
        resourceType: 'shopping_list',
        resourceId: listId,
      );

      await getUserCollection(uid)
          .doc(listId)
          .collection(FirestoreCollections.items)
          .doc(item.id)
          .update(item.toFirestore());
    }

    logPermissionCheck(
      userId: uid,
      resource: 'shopping_item',
      operation: 'update',
      granted: true,
      details: 'List: $listId, Item: ${item.id}, Type: ${list.type}',
    );
  }

  /// Remove item from shopping list (handles both personal and collaborative)
  Future<void> removeItem(String listId, String itemId) async {
    final uid = requireCurrentUserId();

    // Verify list exists and user has access
    final list = await _requireList(listId);

    if (list.type == ListType.collaborative) {
      AppLogger.info(
        'Removing item from collaborative list (inline storage)',
        'ShoppingRepository',
      );

      await mutateCollaborativeList(
        listId,
        (live) => _withItems(
          live,
          live.items.where((item) => item.id != itemId).toList(),
          uid,
        ),
      );
    } else {
      // Handle personal lists - items stored in subcollection
      AppLogger.info(
        'Removing item from personal list (subcollection storage)',
        'ShoppingRepository',
      );

      // For personal lists, verify ownership
      await validateOwnership(
        currentUserId: uid,
        resourceOwnerId: list.ownerId,
        resourceType: 'shopping_list',
        resourceId: listId,
      );

      await getUserCollection(
        uid,
      ).doc(listId).collection(FirestoreCollections.items).doc(itemId).delete();
    }

    logPermissionCheck(
      userId: uid,
      resource: 'shopping_item',
      operation: 'remove',
      granted: true,
      details: 'List: $listId, Item: $itemId, Type: ${list.type}',
    );
  }

  /// Remove multiple items from shopping list using batch operations
  Future<void> removeItemsBatch(String listId, List<String> itemIds) async {
    if (itemIds.isEmpty) return;

    final uid = requireCurrentUserId();

    final list = await _requireList(listId);

    final itemIdSet = itemIds.toSet();

    if (list.type == ListType.collaborative) {
      await mutateCollaborativeList(
        listId,
        (live) => _withItems(
          live,
          live.items.where((item) => !itemIdSet.contains(item.id)).toList(),
          uid,
        ),
      );
    } else {
      await validateOwnership(
        currentUserId: uid,
        resourceOwnerId: list.ownerId,
        resourceType: 'shopping_list',
        resourceId: listId,
      );

      final itemsCollection = getUserCollection(
        uid,
      ).doc(listId).collection(FirestoreCollections.items);

      for (final chunk in itemIds.chunked(kFirestoreBatchSafeChunkSize)) {
        final batch = firestore.batch();
        for (final itemId in chunk) {
          batch.delete(itemsCollection.doc(itemId));
        }
        await batch.commit();
      }
    }

    logPermissionCheck(
      userId: uid,
      resource: 'shopping_item',
      operation: 'batch_remove',
      granted: true,
      details: 'List: $listId, Items: ${itemIds.length}, Type: ${list.type}',
    );
  }
}
