// lib/repositories/firebase/modules/shopping_repository_routing_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';

/// Module handling collection routing between personal and collaborative shopping lists.
///
/// Routes CRUD operations to appropriate Firestore collections:
/// - Personal lists: /users/{userId}/unified_shopping_lists
/// - Collaborative lists: /unified_shared_shopping_lists
class ShoppingRepositoryRoutingModule {
  final FirebaseFirestore firestore;
  final AuthRepository authRepository;
  final CollectionReference<Map<String, dynamic>> sharedListsRef;
  final String Function() requireCurrentUserId;
  final void Function({
    required Map<String, dynamic> data,
    required List<String> requiredFields,
    required String resourceType,
  }) validateRequiredFields;
  final void Function({
    required String userId,
    required String resource,
    required String operation,
    required bool granted,
    String? details,
  }) logPermissionCheck;
  final UnifiedShoppingList Function(DocumentSnapshot<Map<String, dynamic>> doc) fromFirestore;

  ShoppingRepositoryRoutingModule({
    required this.firestore,
    required this.authRepository,
    required this.sharedListsRef,
    required this.requireCurrentUserId,
    required this.validateRequiredFields,
    required this.logPermissionCheck,
    required this.fromFirestore,
  });

  /// Create collaborative list in shared collection
  Future<UnifiedShoppingList> createCollaborativeList(UnifiedShoppingList entity) async {
    final uid = requireCurrentUserId();

    // Validate required fields for collaborative lists
    validateRequiredFields(
      data: entity.toFirestore(),
      requiredFields: ['name', 'ownerId', 'memberPermissions'],
      resourceType: 'collaborative_shopping_list',
    );

    final docRef = sharedListsRef.doc();
    final listToSave = UnifiedShoppingList(
      id: docRef.id,
      name: entity.name,
      ownerId: entity.ownerId,
      ownerDisplayName: entity.ownerDisplayName,
      items: entity.items,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      lastSyncedAt: entity.lastSyncedAt,
      syncStatus: entity.syncStatus,
      type: entity.type,
      memberPermissions: entity.memberPermissions,
      lastActivityAt: entity.lastActivityAt,
      lastActivityByUserId: entity.lastActivityByUserId,
      lastActivityByDisplayName: entity.lastActivityByDisplayName,
      description: entity.description,
      settings: entity.settings,
      categoryIds: entity.categoryIds,
      allowGuestEditing: entity.allowGuestEditing,
      autoRemoveCompleted: entity.autoRemoveCompleted,
    );

    await docRef.set(listToSave.toFirestore());

    logPermissionCheck(
      userId: uid,
      resource: 'collaborative_shopping_list',
      operation: 'create',
      granted: true,
      details: 'List: ${listToSave.name}, Members: ${entity.memberPermissions.length}',
    );

    AppLogger.success('Created collaborative list "${listToSave.name}" with ${entity.items.length} items in shared collection');
    return listToSave;
  }

  /// Update collaborative list in shared collection
  Future<UnifiedShoppingList> updateCollaborativeList(UnifiedShoppingList entity) async {
    final uid = requireCurrentUserId();

    // Validate entity exists
    final docRef = sharedListsRef.doc(entity.id);
    final docSnapshot = await docRef.get();

    if (!docSnapshot.exists) {
      throw ResourceNotFoundException(
        'Collaborative shopping list not found',
        resourceType: 'collaborative_shopping_list',
        resourceId: entity.id,
      );
    }

    await docRef.set(entity.toFirestore(), SetOptions(merge: true));

    logPermissionCheck(
      userId: uid,
      resource: 'collaborative_shopping_list',
      operation: 'update',
      granted: true,
      details: 'List: ${entity.name}',
    );

    AppLogger.info('Updated collaborative list "${entity.name}" with ${entity.items.length} items in shared collection');
    return entity;
  }
}
