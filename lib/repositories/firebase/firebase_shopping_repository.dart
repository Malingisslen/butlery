// lib/repositories/firebase/firebase_shopping_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/utils/logger.dart';

// Module imports
import 'package:butlery/repositories/firebase/modules/shopping_repository_routing_module.dart';
import 'package:butlery/repositories/firebase/modules/shopping_repository_query_module.dart';
import 'package:butlery/repositories/firebase/modules/shopping_item_operations_module.dart';
import 'package:butlery/repositories/firebase/modules/shopping_template_operations_module.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase Firestore implementation for shopping list operations and template management.
/// This repository implements the [ShoppingRepository] interface using Firebase Firestore,
/// managing both personal and collaborative shopping lists with comprehensive template
/// functionality. It combines user-scoped personal lists with shared collaborative lists
/// and a community template system.
/// **Architecture Design:**
/// Extends [BaseFirebaseRepository] with [UserScopedFirebaseRepository] mixin to eliminate
/// 50+ lines of duplicate CRUD code while providing specialized shopping list operations.
/// Uses multiple Firestore collections for different data types:
/// - Personal lists: `/users/{userId}/unified_shopping_lists`
/// - Collaborative lists: `/unified_shared_shopping_lists`
/// - Templates: `/shoppingListTemplates`
/// **Multi-Collection Management:**
/// - **Personal Lists**: User-owned lists stored in user-scoped collections
/// - **Collaborative Lists**: Shared lists with member permissions and real-time sync
/// - **Template System**: Reusable shopping list patterns with public/private visibility
/// - **Active List Tracking**: Single active list management for streamlined UX
/// **Security and Permissions:**
/// - **Ownership Validation**: Verifies user ownership for all personal list operations
/// - **Access Control**: Validates member permissions for collaborative lists
/// - **Template Privacy**: Supports public and private template visibility
/// - **Permission Logging**: Audit trail for all permission-sensitive operations
/// - **Field Validation**: Ensures data integrity for lists, items, and templates
/// **Performance Features:**
/// - **Smart Querying**: Optimized template search with client-side filtering fallback
/// - **Batch Operations**: Efficient bulk operations for items and templates
/// - **Stream Management**: Real-time updates for both personal and collaborative lists
/// - **Query Limits**: Performance-conscious limits on template and archive queries
/// **Template System:**
/// Creates reusable shopping list templates that users can save, share publicly,
/// and use to quickly generate new shopping lists. Supports search, categorization,
/// and metadata tracking for enhanced discoverability.
/// **Usage Examples:**
/// ```dart
/// final shoppingRepo = FirebaseShoppingRepository(
///   authRepository: ServiceLocator.get<AuthRepository>(),
/// );
/// // Create a list
/// final list = UnifiedShoppingList(name: 'Weekly Groceries');
/// final created = await shoppingRepo.create(list);
/// // Save as template
/// final templateId = await shoppingRepo.saveAsTemplate(
///   listId: created.id,
///   templateName: 'Weekly Template',
///   isPublic: true,
/// );
/// // Create from template
/// final newListId = await shoppingRepo.createListFromTemplate(
///   templateId: templateId,
///   listName: 'This Week\'s List',
/// );
/// ```
class FirebaseShoppingRepository
    extends BaseFirebaseRepository<UnifiedShoppingList>
    with UserScopedFirebaseRepository<UnifiedShoppingList>
    implements ShoppingRepository {
  // Feature modules
  late final ShoppingRepositoryRoutingModule _routingModule;
  late final ShoppingRepositoryQueryModule _queryModule;
  late final ShoppingItemOperationsModule _itemOpsModule;
  late final ShoppingTemplateOperationsModule _templateOpsModule;

  FirebaseShoppingRepository({
    super.firestore,
    AuthRepository? authRepository,
    super.auditRepository,
    super.timestampProvider,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        ) {
    _initializeModules();
  }

  void _initializeModules() {
    _routingModule = ShoppingRepositoryRoutingModule(
      firestore: firestore,
      authRepository: authRepository,
      sharedListsRef: _sharedListsRef,
      requireCurrentUserId: requireCurrentUserId,
      validateRequiredFields: validateRequiredFields,
      logPermissionCheck: logPermissionCheck,
      fromFirestore: fromFirestore,
    );

    _queryModule = ShoppingRepositoryQueryModule(
      firestore: firestore,
      sharedListsRef: _sharedListsRef,
      requireCurrentUserId: requireCurrentUserId,
      getUserCollection: getUserCollection,
      fromFirestore: fromFirestore,
      readList: read,
    );

    _itemOpsModule = ShoppingItemOperationsModule(
      firestore: firestore,
      authRepository: authRepository,
      requireCurrentUserId: requireCurrentUserId,
      readList: read,
      updateCollaborativeList: _routingModule.updateCollaborativeList,
      getUserCollection: getUserCollection,
      validateOwnership: validateOwnership,
      validateRequiredFields: validateRequiredFields,
      logPermissionCheck: logPermissionCheck,
    );

    _templateOpsModule = ShoppingTemplateOperationsModule(
      firestore: firestore,
      authRepository: authRepository,
      templatesRef: _templatesRef,
      requireCurrentUserId: requireCurrentUserId,
      readList: read,
      createList: create,
      validateOwnership: validateOwnership,
      timestampProvider: timestampProvider,
    );
  }

  @override
  String get collectionName => FirestoreCollections.unifiedShoppingLists;

  @override
  UnifiedShoppingList fromFirestore(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      UnifiedShoppingList.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(UnifiedShoppingList entity) =>
      entity.toFirestore();

  @override
  String getId(UnifiedShoppingList entity) => entity.id;
  @override
  Future<bool> validateCreatePermission(
      String userId, UnifiedShoppingList entity) async {
    // Users can only create shopping lists in their own collection
    return entity.ownerId == userId;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, UnifiedShoppingList? entity) async {
    if (entity == null) return false;

    // Owner can always read
    if (entity.ownerId == userId) return true;

    // For collaborative lists, check if user is a member (has permissions)
    if (entity.isCollaborative) {
      return entity.memberPermissions.containsKey(userId);
    }

    return false;
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, UnifiedShoppingList entity) async {
    // Owner can always update
    if (entity.ownerId == userId) return true;

    // For collaborative lists, members with permissions can update
    if (entity.isCollaborative) {
      return entity.memberPermissions.containsKey(userId);
    }

    return false;
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    // Only the owner can delete shopping lists
    try {
      final list = await read(resourceId);
      if (list == null) return false;
      return list.ownerId == userId;
    } catch (e) {
      AppLogger.error('Failed to validate delete permission: $e');
      return false;
    }
  }

  CollectionReference<Map<String, dynamic>> get _sharedListsRef =>
      firestore.collection(FirestoreCollections.unifiedSharedShoppingLists);

  /// Override create method to route collaborative lists to correct collection
  @override
  Future<UnifiedShoppingList> create(UnifiedShoppingList entity) async {
    if (entity.type == ListType.collaborative) {
      AppLogger.info(
          'ULTRATHINK: Routing collaborative list "${entity.name}" to shared collection',
          'ShoppingRepository');
      return await _routingModule.createCollaborativeList(entity);
    } else {
      AppLogger.info(
          'ULTRATHINK: Routing personal list "${entity.name}" to user collection',
          'ShoppingRepository');
      return await super.create(entity);
    }
  }

  /// Override update method to route collaborative lists to correct collection
  @override
  Future<UnifiedShoppingList> update(UnifiedShoppingList entity) async {
    if (entity.type == ListType.collaborative) {
      AppLogger.info(
          'ULTRATHINK: Updating collaborative list "${entity.name}" in shared collection',
          'ShoppingRepository');
      return await _routingModule.updateCollaborativeList(entity);
    } else {
      await super.update(entity);
      return entity;
    }
  }

  /// Override read method to search both collaborative and personal collections
  @override
  Future<UnifiedShoppingList?> read(String id) async {
    // First try to find if it's a collaborative list
    try {
      final collabDoc = await _sharedListsRef.doc(id).get();
      if (collabDoc.exists && collabDoc.data() != null) {
        AppLogger.info('Reading collaborative list from shared collection',
            'ShoppingRepository');
        return fromFirestore(collabDoc);
      }
    } catch (e) {
      AppLogger.warning(
          'Error checking collaborative collection during read: $e');
    }

    // If not found in collaborative collection, try user collection
    try {
      final result = await super.read(id);
      if (result != null) {
        AppLogger.info(
            'Reading personal list from user collection', 'ShoppingRepository');
      }
      return result;
    } catch (e) {
      AppLogger.warning('Error reading from user collection: $e');
      return null;
    }
  }

  /// Override delete method to route collaborative lists to correct collection
  @override
  Future<void> delete(String id) async {
    // First try to find if it's a collaborative list
    try {
      final collabDoc = await _sharedListsRef.doc(id).get();
      if (collabDoc.exists) {
        AppLogger.info(
            'ULTRATHINK: Deleting collaborative list from shared collection',
            'ShoppingRepository');
        await _sharedListsRef.doc(id).delete();
        return;
      }
    } catch (e) {
      AppLogger.warning(
          'Error checking collaborative collection during delete: $e');
    }

    // If not found in collaborative collection, delete from user collection
    AppLogger.info('ULTRATHINK: Deleting personal list from user collection',
        'ShoppingRepository');
    await super.delete(id);
  }

  @override
  Future<List<UnifiedShoppingList>> readAll() async => _queryModule.readAll();

  @override
  Future<void> addItem(String listId, UnifiedShoppingItem item) async =>
      _itemOpsModule.addItem(listId, item);

  /// Add multiple items to a list using Firebase batch operations for better performance
  @override
  Future<void> addItemsBatch(
          String listId, List<UnifiedShoppingItem> items) async =>
      _itemOpsModule.addItemsBatch(listId, items);

  @override
  Future<void> removeItem(String listId, String itemId) async =>
      _itemOpsModule.removeItem(listId, itemId);

  @override
  Future<void> updateItem(String listId, UnifiedShoppingItem item) async =>
      _itemOpsModule.updateItem(listId, item);

  @override
  Future<void> removeItemsBatch(String listId, List<String> itemIds) async =>
      _itemOpsModule.removeItemsBatch(listId, itemIds);

  /// Create or update a personal list for the current user.
  /// Uses base class create/update methods for consistency.
  Future<void> savePersonalList(UnifiedShoppingList list) async {
    try {
      await update(list);
    } catch (e) {
      // If update fails (e.g., document doesn't exist), create it
      await create(list);
    }
  }

  /// Create or update a collaborative list.
  /// DEPRECATED: Use standard create/update methods instead (they now route correctly)
  Future<void> saveCollaborativeList(UnifiedShoppingList list) async {
    AppLogger.warning(
        'DEPRECATED: saveCollaborativeList() - use update() method instead');
    await _routingModule.updateCollaborativeList(list);
  }

  /// Delete a personal list.
  /// Uses base class delete method for consistency.
  Future<void> deletePersonalList(String listId) async {
    await delete(listId);
  }

  /// Delete a collaborative list.
  /// DEPRECATED: Use standard delete method instead (it now routes correctly)
  Future<void> deleteCollaborativeList(String listId) async {
    AppLogger.warning(
        'DEPRECATED: deleteCollaborativeList() - use delete() method instead');
    await _sharedListsRef.doc(listId).delete();
  }

  /// Fetch all personal lists for the current user.
  /// Uses base class stream methods for consistency.
  Stream<List<UnifiedShoppingList>> personalListsStream() =>
      _queryModule.personalListsStream();

  /// Fetch collaborative lists where the current user is a member.
  Stream<List<UnifiedShoppingList>> collaborativeListsStream() =>
      _queryModule.collaborativeListsStream();
  CollectionReference<Map<String, dynamic>> get _templatesRef =>
      firestore.collection(FirestoreCollections.shoppingListTemplates);

  @override
  Future<String> saveAsTemplate({
    required String listId,
    required String templateName,
    String? description,
    List<String>? tags,
    bool isPublic = false,
  }) async =>
      _templateOpsModule.saveAsTemplate(
        listId: listId,
        templateName: templateName,
        description: description,
        tags: tags,
        isPublic: isPublic,
      );

  @override
  Future<void> updateTemplate({
    required String templateId,
    String? name,
    String? description,
    List<String>? tags,
    bool? isPublic,
  }) async =>
      _templateOpsModule.updateTemplate(
        templateId: templateId,
        name: name,
        description: description,
        tags: tags,
        isPublic: isPublic,
      );

  @override
  Future<void> deleteTemplate(String templateId) async =>
      _templateOpsModule.deleteTemplate(templateId);

  @override
  Future<List<Map<String, dynamic>>> getUserTemplates() async =>
      _templateOpsModule.getUserTemplates();

  @override
  Future<List<Map<String, dynamic>>> getPublicTemplates({
    int limit = 20,
    String? searchQuery,
    List<String>? tags,
  }) async =>
      _templateOpsModule.getPublicTemplates(
        limit: limit,
        searchQuery: searchQuery,
        tags: tags,
      );

  @override
  Future<String> createListFromTemplate({
    required String templateId,
    required String listName,
    String? description,
  }) async =>
      _templateOpsModule.createListFromTemplate(
        templateId: templateId,
        listName: listName,
        description: description,
      );
}
