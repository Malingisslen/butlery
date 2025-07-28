// lib/repositories/firebase/firebase_shopping_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
// Using existing permission exceptions

/// Repository for handling shopping lists stored in Firestore.
///
/// Refactored to extend BaseFirebaseRepository with UserScopedFirebaseRepository mixin,
/// eliminating 50+ lines of duplicate CRUD code and authentication checks.
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
      FirebaseFirestore.instance.collection('unified_shared_shopping_lists');

  // ===== ENHANCED BASE CLASS METHODS =====

  @override
  Future<List<UnifiedShoppingList>> readAll() async {
    // Override to add ordering and combine personal + shared lists
    try {
      final personalLists = await readAllSafe();
      // TODO: Add shared lists when implemented
      return personalLists;
    } catch (e) {
      return await readAllSafe();
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
    
    // For personal lists, verify ownership
    await validateOwnership(
      currentUserId: uid,
      resourceOwnerId: list.ownerId,
      resourceType: 'shopping_list',
      resourceId: listId,
    );
    
    // Validate item data
    validateRequiredFields(
      data: item.toFirestore(),
      requiredFields: ['name', 'id'],
      resourceType: 'shopping_item',
    );
    
    await getUserCollection(uid)
        .doc(listId)
        .collection('items')
        .doc(item.id)
        .set(item.toFirestore());
        
    logPermissionCheck(
      userId: uid,
      resource: 'shopping_item',
      operation: 'add',
      granted: true,
      details: 'List: $listId',
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
        
    logPermissionCheck(
      userId: uid,
      resource: 'shopping_item',
      operation: 'remove',
      granted: true,
      details: 'List: $listId, Item: $itemId',
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
  Future<void> saveCollaborativeList(UnifiedShoppingList list) async {
    await _sharedListsRef
        .doc(list.id)
        .set(list.toFirestore(), SetOptions(merge: true));
  }

  /// Delete a personal list.
  /// Uses base class delete method for consistency.
  Future<void> deletePersonalList(String listId) async {
    await delete(listId);
  }

  /// Delete a collaborative list.
  Future<void> deleteCollaborativeList(String listId) async {
    await _sharedListsRef.doc(listId).delete();
  }

  /// Fetch all personal lists for the current user.
  /// Uses base class stream methods for consistency.
  Stream<List<UnifiedShoppingList>> personalListsStream() {
    try {
      final uid = requireCurrentUserId();
      return getUserCollection(uid)
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
      return _sharedListsRef
          .where('memberPermissions.$uid', isNotEqualTo: null)
          .snapshots()
          .map((snap) =>
              snap.docs.map(UnifiedShoppingList.fromFirestore).toList());
    } catch (e) {
      return const Stream.empty();
    }
  }

  // ===== TEMPLATE OPERATIONS =====

  CollectionReference<Map<String, dynamic>> get _templatesRef =>
      FirebaseFirestore.instance.collection('shoppingListTemplates');

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
    
    final snapshot = await _templatesRef
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
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
