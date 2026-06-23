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
class ShoppingItemOperationsModule {
  final FirebaseFirestore firestore;
  final AuthRepository authRepository;
  final String Function() requireCurrentUserId;
  final Future<UnifiedShoppingList?> Function(String id) readList;
  final Future<UnifiedShoppingList> Function(UnifiedShoppingList entity)
  updateCollaborativeList;
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
    required this.updateCollaborativeList,
    required this.getUserCollection,
    required this.validateOwnership,
    required this.validateRequiredFields,
    required this.logPermissionCheck,
  });

  /// Add item to shopping list (handles both personal and collaborative)
  Future<void> addItem(String listId, UnifiedShoppingItem item) async {
    final uid = requireCurrentUserId();

    // Verify list exists and user has access
    final list = await readList(listId);
    if (list == null) {
      throw ResourceNotFoundException(
        'Shopping list not found',
        resourceType: 'shopping_list',
        resourceId: listId,
      );
    }

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

      final updatedItems = [...list.items, item];
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: clock.now().toUtc(),
        lastActivityAt: clock.now().toUtc(),
        lastActivityByUserId: uid,
        lastActivityByDisplayName: authRepository.currentUser?.displayName,
      );

      await updateCollaborativeList(updatedList);
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
    final list = await readList(listId);
    if (list == null) {
      throw ResourceNotFoundException(
        'Shopping list not found',
        resourceType: 'shopping_list',
        resourceId: listId,
      );
    }

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

      final updatedItems = [...list.items, ...items];
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: clock.now().toUtc(),
        lastActivityAt: clock.now().toUtc(),
        lastActivityByUserId: uid,
        lastActivityByDisplayName: authRepository.currentUser?.displayName,
      );

      await updateCollaborativeList(updatedList);
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

    final list = await readList(listId);
    if (list == null) {
      throw ResourceNotFoundException(
        'Shopping list not found',
        resourceType: 'shopping_list',
        resourceId: listId,
      );
    }

    if (list.type == ListType.collaborative) {
      final updatedItems = list.items.map((existing) {
        return existing.id == item.id ? item : existing;
      }).toList();
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: clock.now().toUtc(),
        lastActivityAt: clock.now().toUtc(),
        lastActivityByUserId: uid,
        lastActivityByDisplayName: authRepository.currentUser?.displayName,
      );
      await updateCollaborativeList(updatedList);
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
    final list = await readList(listId);
    if (list == null) {
      throw ResourceNotFoundException(
        'Shopping list not found',
        resourceType: 'shopping_list',
        resourceId: listId,
      );
    }

    if (list.type == ListType.collaborative) {
      AppLogger.info(
        'Removing item from collaborative list (inline storage)',
        'ShoppingRepository',
      );

      final updatedItems = list.items
          .where((item) => item.id != itemId)
          .toList();
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: clock.now().toUtc(),
        lastActivityAt: clock.now().toUtc(),
        lastActivityByUserId: uid,
        lastActivityByDisplayName: authRepository.currentUser?.displayName,
      );

      await updateCollaborativeList(updatedList);
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

    final list = await readList(listId);
    if (list == null) {
      throw ResourceNotFoundException(
        'Shopping list not found',
        resourceType: 'shopping_list',
        resourceId: listId,
      );
    }

    final itemIdSet = itemIds.toSet();

    if (list.type == ListType.collaborative) {
      final updatedItems = list.items
          .where((item) => !itemIdSet.contains(item.id))
          .toList();
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: clock.now().toUtc(),
        lastActivityAt: clock.now().toUtc(),
        lastActivityByUserId: uid,
        lastActivityByDisplayName: authRepository.currentUser?.displayName,
      );
      await updateCollaborativeList(updatedList);
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
