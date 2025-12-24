// lib/repositories/firebase/modules/shopping_template_operations_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

/// Module handling shopping list template operations.
/// Provides template CRUD, search, and list generation from templates.
class ShoppingTemplateOperationsModule {
  final FirebaseFirestore firestore;
  final AuthRepository authRepository;
  final CollectionReference<Map<String, dynamic>> templatesRef;
  final String Function() requireCurrentUserId;
  final Future<UnifiedShoppingList?> Function(String id) readList;
  final Future<UnifiedShoppingList> Function(UnifiedShoppingList entity)
      createList;
  final Future<void> Function({
    required String currentUserId,
    required String resourceOwnerId,
    required String resourceType,
    required String resourceId,
  }) validateOwnership;

  ShoppingTemplateOperationsModule({
    required this.firestore,
    required this.authRepository,
    required this.templatesRef,
    required this.requireCurrentUserId,
    required this.readList,
    required this.createList,
    required this.validateOwnership,
  });

  /// Save shopping list as reusable template
  Future<String> saveAsTemplate({
    required String listId,
    required String templateName,
    String? description,
    List<String>? tags,
    bool isPublic = false,
  }) async {
    final uid = requireCurrentUserId();

    // Get the list to convert to template
    final list = await readList(listId);
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

    final docRef = await templatesRef.add(templateData);
    return docRef.id;
  }

  /// Update template metadata
  Future<void> updateTemplate({
    required String templateId,
    String? name,
    String? description,
    List<String>? tags,
    bool? isPublic,
  }) async {
    final uid = requireCurrentUserId();

    final templateRef = templatesRef.doc(templateId);
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

  /// Delete template with ownership validation
  Future<void> deleteTemplate(String templateId) async {
    final uid = requireCurrentUserId();

    final templateRef = templatesRef.doc(templateId);
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

  /// Get user's saved templates
  Future<List<Map<String, dynamic>>> getUserTemplates() async {
    final uid = requireCurrentUserId();

    final snapshot = await templatesRef
        .where('ownerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50) // Limit user templates to 50 most recent
        .get();

    return snapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  }

  /// Get public templates with optional search and tag filtering
  Future<List<Map<String, dynamic>>> getPublicTemplates({
    int limit = 20,
    String? searchQuery,
    List<String>? tags,
  }) async {
    // Increase query limit to account for filtering, but cap at reasonable maximum
    final queryLimit = searchQuery != null || (tags != null && tags.isNotEmpty)
        ? (limit * 3)
            .clamp(20, 100) // Get more docs to filter from, but cap at 100
        : limit;

    final query = templatesRef
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(queryLimit);

    // Note: Firestore doesn't support text search, so we'll filter client-side
    final snapshot = await query.get();

    var templates = snapshot.docs
        .map((doc) => {
              'id': doc.id,
              ...doc.data(),
            })
        .toList();

    // Client-side filtering for search query
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      templates = templates.where((template) {
        final name = (template['name'] as String? ?? '').toLowerCase();
        final description =
            (template['description'] as String? ?? '').toLowerCase();
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

  /// Create new shopping list from template
  Future<String> createListFromTemplate({
    required String templateId,
    required String listName,
    String? description,
  }) async {
    final uid = requireCurrentUserId();

    // Get template
    final templateDoc = await templatesRef.doc(templateId).get();
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
    final templateItems =
        List<Map<String, dynamic>>.from(templateData['items'] ?? []);
    final items = templateItems
        .map((itemData) => UnifiedShoppingItem.fromFirestore(itemData))
        .toList();

    final newList = UnifiedShoppingList(
      name: listName.trim(),
      description: description?.trim(),
      ownerId: uid,
      ownerDisplayName:
          authRepository.currentUser?.displayName ?? 'Unknown User',
      items: items,
    );

    final createdList = await createList(newList);
    return createdList.id;
  }
}
