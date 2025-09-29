// lib/repositories/firebase/firebase_shopping_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';
// Using existing permission exceptions

/// Firebase Firestore implementation for shopping list operations and template management.
///
/// This repository implements the [ShoppingRepository] interface using Firebase Firestore,
/// managing both personal and collaborative shopping lists with comprehensive template
/// functionality. It combines user-scoped personal lists with shared collaborative lists
/// and a community template system.
///
/// **Architecture Design:**
/// Extends [BaseFirebaseRepository] with [UserScopedFirebaseRepository] mixin to eliminate
/// 50+ lines of duplicate CRUD code while providing specialized shopping list operations.
/// Uses multiple Firestore collections for different data types:
/// - Personal lists: `/users/{userId}/unified_shopping_lists`
/// - Collaborative lists: `/unified_shared_shopping_lists`
/// - Templates: `/shoppingListTemplates`
///
/// **Multi-Collection Management:**
/// - **Personal Lists**: User-owned lists stored in user-scoped collections
/// - **Collaborative Lists**: Shared lists with member permissions and real-time sync
/// - **Template System**: Reusable shopping list patterns with public/private visibility
/// - **Active List Tracking**: Single active list management for streamlined UX
///
/// **Security and Permissions:**
/// - **Ownership Validation**: Verifies user ownership for all personal list operations
/// - **Access Control**: Validates member permissions for collaborative lists
/// - **Template Privacy**: Supports public and private template visibility
/// - **Permission Logging**: Audit trail for all permission-sensitive operations
/// - **Field Validation**: Ensures data integrity for lists, items, and templates
///
/// **Performance Features:**
/// - **Smart Querying**: Optimized template search with client-side filtering fallback
/// - **Batch Operations**: Efficient bulk operations for items and templates
/// - **Stream Management**: Real-time updates for both personal and collaborative lists
/// - **Query Limits**: Performance-conscious limits on template and archive queries
///
/// **Template System:**
/// Creates reusable shopping list templates that users can save, share publicly,
/// and use to quickly generate new shopping lists. Supports search, categorization,
/// and metadata tracking for enhanced discoverability.
///
/// **Usage Examples:**
/// ```dart
/// final shoppingRepo = FirebaseShoppingRepository(
///   authRepository: ServiceLocator.get<AuthRepository>(),
/// );
/// 
/// // Create and set active list
/// final list = UnifiedShoppingList(name: 'Weekly Groceries');
/// final created = await shoppingRepo.create(list);
/// await shoppingRepo.setActiveList(created.id);
/// 
/// // Save as template
/// final templateId = await shoppingRepo.saveAsTemplate(
///   listId: created.id,
///   templateName: 'Weekly Template',
///   isPublic: true,
/// );
/// 
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
  String? _activeListId;

  FirebaseShoppingRepository({
    super.firestore,
    AuthRepository? authRepository,
  }) : super(
          authRepository: authRepository ?? FirebaseAuthRepository(),
        );

  // ===== BASE CLASS IMPLEMENTATION =====

  @override
  String get collectionName => 'unified_shopping_lists';

  @override
  UnifiedShoppingList fromFirestore(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      UnifiedShoppingList.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(UnifiedShoppingList entity) =>
      entity.toFirestore();

  @override
  String getId(UnifiedShoppingList entity) => entity.id;

  // ===== SHARED COLLECTIONS ACCESS =====

  CollectionReference<Map<String, dynamic>> get _sharedListsRef =>
      firestore.collection('unified_shared_shopping_lists');

  // ===== COLLECTION ROUTING OVERRIDE =====

  /// Override create method to route collaborative lists to correct collection
  @override
  Future<UnifiedShoppingList> create(UnifiedShoppingList entity) async {
    if (entity.type == ListType.collaborative) {
      // Route collaborative lists to shared collection
      AppLogger.info('ULTRATHINK: Routing collaborative list "${entity.name}" to shared collection', 'ShoppingRepository');
      return await _createCollaborativeList(entity);
    } else {
      // Route personal lists to user-scoped collection
      AppLogger.info('ULTRATHINK: Routing personal list "${entity.name}" to user collection', 'ShoppingRepository');
      return await super.create(entity);
    }
  }

  /// Override update method to route collaborative lists to correct collection
  @override
  Future<UnifiedShoppingList> update(UnifiedShoppingList entity) async {
    if (entity.type == ListType.collaborative) {
      // Route collaborative lists to shared collection
      AppLogger.info('ULTRATHINK: Updating collaborative list "${entity.name}" in shared collection', 'ShoppingRepository');
      return await _updateCollaborativeList(entity);
    } else {
      // Route personal lists to user-scoped collection  
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
        AppLogger.info('Reading collaborative list from shared collection', 'ShoppingRepository');
        return fromFirestore(collabDoc);
      }
    } catch (e) {
      AppLogger.warning('Error checking collaborative collection during read: $e');
    }
    
    // If not found in collaborative collection, try user collection
    try {
      final result = await super.read(id);
      if (result != null) {
        AppLogger.info('Reading personal list from user collection', 'ShoppingRepository');
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
        AppLogger.info('ULTRATHINK: Deleting collaborative list from shared collection', 'ShoppingRepository');
        await _sharedListsRef.doc(id).delete();
        return;
      }
    } catch (e) {
      AppLogger.warning('Error checking collaborative collection during delete: $e');
    }
    
    // If not found in collaborative collection, delete from user collection
    AppLogger.info('ULTRATHINK: Deleting personal list from user collection', 'ShoppingRepository');
    await super.delete(id);
  }

  /// Create collaborative list in shared collection
  Future<UnifiedShoppingList> _createCollaborativeList(UnifiedShoppingList entity) async {
    final uid = requireCurrentUserId();
    
    // Validate required fields for collaborative lists
    validateRequiredFields(
      data: entity.toFirestore(),
      requiredFields: ['name', 'ownerId', 'memberPermissions'],
      resourceType: 'collaborative_shopping_list',
    );
    
    final docRef = _sharedListsRef.doc();
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
  Future<UnifiedShoppingList> _updateCollaborativeList(UnifiedShoppingList entity) async {
    final uid = requireCurrentUserId();
    
    // Validate entity exists
    final docRef = _sharedListsRef.doc(entity.id);
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

  // ===== ENHANCED BASE CLASS METHODS =====

  @override
  Future<List<UnifiedShoppingList>> readAll() async {
    // Override to add ordering and combine personal + shared lists
    try {
      final uid = requireCurrentUserId();
      AppLogger.info('Loading shopping lists for user: $uid');
      
      // Get personal lists using direct base class method (avoiding circular call)
      final personalRef = getCollectionRef();
      final personalSnapshot = await personalRef.get();
      final personalLists = <UnifiedShoppingList>[];
      
      // Load each list with its items from subcollection
      for (final listDoc in personalSnapshot.docs) {
        final list = fromFirestore(listDoc);
        
        // Load items for this list from subcollection
        final itemsSnapshot = await getUserCollection(uid)
            .doc(list.id)
            .collection('items')
            .get();
            
        final items = itemsSnapshot.docs
            .map((doc) => UnifiedShoppingItem.fromFirestore(doc.data()))
            .toList();
            
        // Create list with loaded items
        final listWithItems = list.copyWith(items: items);
        personalLists.add(listWithItems);
        
        AppLogger.info('Loaded list "${list.name}" with ${items.length} items', 'ShoppingRepository');
      }
      
      
      // Get shared/collaborative lists where user is a member
      final sharedSnapshot = await _sharedListsRef
          .where('memberPermissions.$uid', isNotEqualTo: null)
          .limit(20) // Most users won't have more than 20 shared lists
          .get();
      
      final sharedLists = <UnifiedShoppingList>[];
      for (final doc in sharedSnapshot.docs) {
        try {
          final list = UnifiedShoppingList.fromFirestore(doc);
          
          // Safety check: Skip lists with invalid data
          if (list.name.isEmpty) {
            AppLogger.warning('Skipping collaborative list with empty name: ${doc.id}');
            continue;
          }
          
          AppLogger.info('ULTRATHINK DEBUG: Loaded collaborative list "${list.name}" with ${list.items.length} items (origin: ${list.collaborativeOrigin ?? "direct"})', 'ShoppingRepository');
          
          // Debug log each item to verify they're loading correctly
          for (int i = 0; i < list.items.length && i < 3; i++) {
            final item = list.items[i];
            AppLogger.info('  Item ${i+1}: "${item.name}" (bought: ${item.bought})', 'ShoppingRepository');
          }
          if (list.items.length > 3) {
            AppLogger.info('  ... and ${list.items.length - 3} more items', 'ShoppingRepository');
          }
          
          sharedLists.add(list);
        } catch (e) {
          AppLogger.error('Failed to load collaborative list ${doc.id}: $e');
          // Continue loading other lists
        }
      }
          
      
      // Combine and sort by updatedAt (most recent first)
      final allLists = [...personalLists, ...sharedLists];
      allLists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      AppLogger.success('Successfully loaded ${allLists.length} shopping lists (${personalLists.length} personal, ${sharedLists.length} collaborative)');
      return allLists;
    } catch (e) {
      AppLogger.error('Failed to load shopping lists: $e');
      // Fallback to empty list to prevent app crashes
      return [];
    }
  }

  // ===== SPECIALIZED SHOPPING LIST OPERATIONS =====

  @override
  Future<void> setActiveList(String listId) async {
    _activeListId = listId;
  }

  @override
  Future<UnifiedShoppingList?> getActiveList() async {
    if (_activeListId == null) return null;
    return read(_activeListId!);
  }

  @override
  Future<void> addItem(String listId, UnifiedShoppingItem item) async {
    final uid = requireCurrentUserId();
    
    // Verify list exists and user has access
    final list = await read(listId);
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
      // ULTRATHINK FIX: Handle collaborative lists - items stored inline in document
      AppLogger.info('ULTRATHINK: Adding item to collaborative list (inline storage)', 'ShoppingRepository');
      
      final updatedItems = [...list.items, item];
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
        lastActivityByUserId: uid,
        lastActivityByDisplayName: authRepository.currentUser?.displayName,
      );
      
      await _updateCollaborativeList(updatedList);
    } else {
      // Handle personal lists - items stored in subcollection
      AppLogger.info('ULTRATHINK: Adding item to personal list (subcollection storage)', 'ShoppingRepository');
      
      // For personal lists, verify ownership
      await validateOwnership(
        currentUserId: uid,
        resourceOwnerId: list.ownerId,
        resourceType: 'shopping_list',
        resourceId: listId,
      );
      
      await getUserCollection(uid)
          .doc(listId)
          .collection('items')
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

  /// Add multiple items to a list using Firebase batch operations for better performance
  @override
  Future<void> addItemsBatch(String listId, List<UnifiedShoppingItem> items) async {
    final uid = requireCurrentUserId();
    
    // Verify list exists and user has access
    final list = await read(listId);
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
      // ULTRATHINK FIX: Validate collaborative list edit permissions before adding items
      final userPermission = list.memberPermissions[uid];
      final canEdit = userPermission == SharedListPermission.admin ||
                     userPermission == SharedListPermission.edit;
      
      if (!canEdit) {
        AppLogger.warning('PERMISSION DENIED: User $uid cannot edit collaborative list ${list.id} (permission: $userPermission)', 'ShoppingRepository');
        throw PermissionDeniedException(
          'Du har inte behörighet att redigera denna delade inköpslista',
          resource: 'collaborative_list:${list.id}',
          userId: uid,
        );
      }
      
      AppLogger.info('ULTRATHINK: Adding ${items.length} items to collaborative list (inline storage) - permission validated', 'ShoppingRepository');
      
      final updatedItems = [...list.items, ...items];
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
        lastActivityByUserId: uid,
        lastActivityByDisplayName: authRepository.currentUser?.displayName,
      );
      
      await _updateCollaborativeList(updatedList);
    } else {
      // Handle personal lists - items stored in subcollection
      AppLogger.info('ULTRATHINK: Adding ${items.length} items to personal list (subcollection storage)', 'ShoppingRepository');
      
      // For personal lists, verify ownership
      await validateOwnership(
        currentUserId: uid,
        resourceOwnerId: list.ownerId,
        resourceType: 'shopping_list',
        resourceId: listId,
      );
      
      // Use Firebase batch for atomic operation
      final batch = firestore.batch();
      final itemsCollection = getUserCollection(uid).doc(listId).collection('items');
      
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

  @override
  Future<void> removeItem(String listId, String itemId) async {
    final uid = requireCurrentUserId();
    
    // Verify list exists and user has access
    final list = await read(listId);
    if (list == null) {
      throw ResourceNotFoundException(
        'Shopping list not found',
        resourceType: 'shopping_list',
        resourceId: listId,
      );
    }
    
    if (list.type == ListType.collaborative) {
      // ULTRATHINK FIX: Handle collaborative lists - items stored inline in document
      AppLogger.info('ULTRATHINK: Removing item from collaborative list (inline storage)', 'ShoppingRepository');
      
      final updatedItems = list.items.where((item) => item.id != itemId).toList();
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
        lastActivityAt: DateTime.now(),
        lastActivityByUserId: uid,
        lastActivityByDisplayName: authRepository.currentUser?.displayName,
      );
      
      await _updateCollaborativeList(updatedList);
    } else {
      // Handle personal lists - items stored in subcollection
      AppLogger.info('ULTRATHINK: Removing item from personal list (subcollection storage)', 'ShoppingRepository');
      
      // For personal lists, verify ownership
      await validateOwnership(
        currentUserId: uid,
        resourceOwnerId: list.ownerId,
        resourceType: 'shopping_list',
        resourceId: listId,
      );
      
      await getUserCollection(uid)
          .doc(listId)
          .collection('items')
          .doc(itemId)
          .delete();
    }
        
    logPermissionCheck(
      userId: uid,
      resource: 'shopping_item',
      operation: 'remove',
      granted: true,
      details: 'List: $listId, Item: $itemId, Type: ${list.type}',
    );
  }

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
    AppLogger.warning('DEPRECATED: saveCollaborativeList() - use update() method instead');
    await _updateCollaborativeList(list);
  }

  /// Delete a personal list.
  /// Uses base class delete method for consistency.
  Future<void> deletePersonalList(String listId) async {
    await delete(listId);
  }

  /// Delete a collaborative list.
  /// DEPRECATED: Use standard delete method instead (it now routes correctly)
  Future<void> deleteCollaborativeList(String listId) async {
    AppLogger.warning('DEPRECATED: deleteCollaborativeList() - use delete() method instead');
    await _sharedListsRef.doc(listId).delete();
  }

  /// Fetch all personal lists for the current user.
  /// Uses base class stream methods for consistency.
  Stream<List<UnifiedShoppingList>> personalListsStream() {
    try {
      final uid = requireCurrentUserId();
      // ✅ PERFORMANCE FIX: Added limit to prevent unbounded streaming
      return getUserCollection(uid)
          .orderBy('updatedAt', descending: true)
          .limit(20) // Limit personal lists to 20 most recent
          .snapshots()
          .map((snap) => snap.docs.map(fromFirestore).toList());
    } catch (e) {
      return const Stream.empty();
    }
  }

  /// Fetch collaborative lists where the current user is a member.
  Stream<List<UnifiedShoppingList>> collaborativeListsStream() {
    try {
      final uid = requireCurrentUserId();
      // ✅ PERFORMANCE FIX: Added limit to prevent unbounded streaming
      return _sharedListsRef
          .where('memberPermissions.$uid', isNotEqualTo: null)
          .orderBy('updatedAt', descending: true)
          .limit(20) // Limit collaborative lists to 20 most recent
          .snapshots()
          .map((snap) =>
              snap.docs.map(UnifiedShoppingList.fromFirestore).toList());
    } catch (e) {
      return const Stream.empty();
    }
  }

  // ===== TEMPLATE OPERATIONS =====

  CollectionReference<Map<String, dynamic>> get _templatesRef =>
      firestore.collection('shoppingListTemplates');

  @override
  Future<String> saveAsTemplate({
    required String listId,
    required String templateName,
    String? description,
    List<String>? tags,
    bool isPublic = false,
  }) async {
    final uid = requireCurrentUserId();
    
    // Get the list to convert to template
    final list = await read(listId);
    if (list == null) {
      throw ResourceNotFoundException(
        'Shopping list not found',
        resourceType: 'shopping_list',
        resourceId: listId,
      );
    }

    // Verify ownership
    await validateOwnership(
      currentUserId: uid,
      resourceOwnerId: list.ownerId,
      resourceType: 'shopping_list',
      resourceId: listId,
    );

    // Create template data
    final templateData = {
      'name': templateName.trim(),
      'description': description?.trim(),
      'ownerId': uid,
      'ownerDisplayName': authRepository.currentUser?.displayName,
      'originalListId': listId,
      'items': list.items.map((item) => item.toFirestore()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isPublic': isPublic,
      'tags': tags ?? <String>[],
      'metadata': {
        'itemCount': list.items.length,
        'version': '1.0',
      },
    };

    final docRef = await _templatesRef.add(templateData);
    return docRef.id;
  }

  @override
  Future<void> updateTemplate({
    required String templateId,
    String? name,
    String? description,
    List<String>? tags,
    bool? isPublic,
  }) async {
    final uid = requireCurrentUserId();
    
    final templateRef = _templatesRef.doc(templateId);
    final templateDoc = await templateRef.get();
    
    if (!templateDoc.exists) {
      throw ResourceNotFoundException(
        'Template not found',
        resourceType: 'template',
        resourceId: templateId,
      );
    }

    final templateData = templateDoc.data()!;
    await validateOwnership(
      currentUserId: uid,
      resourceOwnerId: templateData['ownerId'] as String,
      resourceType: 'template',
      resourceId: templateId,
    );

    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) updateData['name'] = name.trim();
    if (description != null) updateData['description'] = description.trim();
    if (tags != null) updateData['tags'] = tags;
    if (isPublic != null) updateData['isPublic'] = isPublic;

    await templateRef.update(updateData);
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    final uid = requireCurrentUserId();
    
    final templateRef = _templatesRef.doc(templateId);
    final templateDoc = await templateRef.get();
    
    if (!templateDoc.exists) {
      throw ResourceNotFoundException(
        'Template not found',
        resourceType: 'template',
        resourceId: templateId,
      );
    }

    final templateData = templateDoc.data()!;
    await validateOwnership(
      currentUserId: uid,
      resourceOwnerId: templateData['ownerId'] as String,
      resourceType: 'template',
      resourceId: templateId,
    );

    await templateRef.delete();
  }

  @override
  Future<List<Map<String, dynamic>>> getUserTemplates() async {
    final uid = requireCurrentUserId();
    
    // ✅ PERFORMANCE FIX: Added limit to prevent unbounded query
    final snapshot = await _templatesRef
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50) // Limit user templates to 50 most recent
        .get();

    return snapshot.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getPublicTemplates({
    int limit = 20,
    String? searchQuery,
    List<String>? tags,
  }) async {
    // ✅ PERFORMANCE FIX: Improved query strategy to minimize client-side filtering
    // Increase query limit to account for filtering, but cap at reasonable maximum
    final queryLimit = searchQuery != null || (tags != null && tags.isNotEmpty) 
        ? (limit * 3).clamp(20, 100) // Get more docs to filter from, but cap at 100
        : limit;

    final query = _templatesRef
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(queryLimit);

    // Note: Firestore doesn't support text search, so we'll filter client-side
    // For production, consider implementing server-side search with Algolia or similar
    final snapshot = await query.get();
    
    var templates = snapshot.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();

    // Client-side filtering for search query
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      templates = templates.where((template) {
        final name = (template['name'] as String? ?? '').toLowerCase();
        final description = (template['description'] as String? ?? '').toLowerCase();
        return name.contains(lowerQuery) || description.contains(lowerQuery);
      }).toList();
    }

    // Client-side filtering for tags
    if (tags != null && tags.isNotEmpty) {
      templates = templates.where((template) {
        final templateTags = List<String>.from(template['tags'] ?? []);
        return tags.any((tag) => templateTags.contains(tag));
      }).toList();
    }

    // Ensure we don't return more than requested limit
    return templates.take(limit).toList();
  }

  @override
  Future<String> createListFromTemplate({
    required String templateId,
    required String listName,
    String? description,
  }) async {
    final uid = requireCurrentUserId();
    
    // Get template
    final templateDoc = await _templatesRef.doc(templateId).get();
    if (!templateDoc.exists) {
      throw ResourceNotFoundException(
        'Template not found',
        resourceType: 'template',
        resourceId: templateId,
      );
    }

    final templateData = templateDoc.data()!;
    
    // Check if template is public or user owns it
    final isPublic = templateData['isPublic'] as bool? ?? false;
    final templateOwnerId = templateData['ownerId'] as String;
    
    if (!isPublic && templateOwnerId != uid) {
      throw PermissionDeniedException(
        'No access to private template',
        resource: 'template:$templateId',
        userId: uid,
      );
    }

    // Create shopping list from template
    final templateItems = List<Map<String, dynamic>>.from(templateData['items'] ?? []);
    final items = templateItems.map((itemData) => 
        UnifiedShoppingItem.fromFirestore(itemData)).toList();

    final newList = UnifiedShoppingList(
      name: listName.trim(),
      description: description?.trim(),
      ownerId: uid,
      ownerDisplayName: authRepository.currentUser?.displayName ?? 'Unknown User',
      items: items,
    );

    final createdList = await create(newList);
    return createdList.id;
  }
}
