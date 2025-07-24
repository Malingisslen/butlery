// lib/services/unified/operations/shopping_share/shopping_template_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/unified/unified_shopping_list.dart';
import '../../../../core/utils/logger.dart';
import '../../../../services/permission_service.dart';
import '../../../../core/injection.dart';
import 'shared/shopping_share_utils.dart';

/// Shopping list template module
/// 
/// This module handles ONLY template operations:
/// - Save shopping lists as templates
/// - Create lists from templates
/// - Manage template metadata
/// - Template validation and error handling
/// 
/// ❌ DOES NOT CONTAIN: Sharing, export, import, social features
class ShoppingTemplateModule {
  final dynamic _parent; // UnifiedShoppingService

  ShoppingTemplateModule(this._parent);

  // ===== TEMPLATE CREATION =====

  /// Save shopping list as template
  Future<bool> saveAsTemplate({
    required String listId,
    required String templateName,
    String? description,
    List<String>? tags,
    bool isPublic = false,
  }) async {
    try {
      final list = _getListById(listId);
      final errorMessage = ShoppingShareUtils.validateListExists(list);
      if (errorMessage != null) {
        AppLogger.error('Cannot save template: $errorMessage');
        return false;
      }
      
      if (!sl<PermissionService>().isAuthenticated) {
        AppLogger.warning('User must be logged in to save template');
        return false;
      }
      
      final currentUser = sl<PermissionService>().currentUser;
      if (currentUser == null) return false;

      if (templateName.trim().isEmpty) {
        AppLogger.error('Template name cannot be empty');
        return false;
      }
      
      // Save template to Firestore
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('shoppingListTemplates').add({
        'name': templateName.trim(),
        'description': description?.trim(),
        'ownerId': currentUser.uid,
        'ownerDisplayName': currentUser.displayName,
        'originalListId': listId,
        'items': _createTemplateItems(list!),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isPublic': isPublic,
        'tags': tags ?? <String>[],
        'statistics': ShoppingShareUtils.getListStatistics(list),
        'metadata': {
          'itemCount': list.items.length,
          'categoryCount': _getCategoryCount(list),
          'version': '1.0',
        },
      });
      
      AppLogger.success('✅ Template saved: $templateName');
      return true;
    } catch (e) {
      AppLogger.error('Failed to save template', e);
      return false;
    }
  }

  /// Update existing template
  Future<bool> updateTemplate({
    required String templateId,
    String? name,
    String? description,
    List<String>? tags,
    bool? isPublic,
  }) async {
    try {
      if (!sl<PermissionService>().isAuthenticated) {
        AppLogger.warning('User must be logged in to update template');
        return false;
      }

      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return false;

      final firestore = FirebaseFirestore.instance;
      final templateDoc = firestore.collection('shoppingListTemplates').doc(templateId);

      // Verify ownership
      final templateSnapshot = await templateDoc.get();
      if (!templateSnapshot.exists || 
          templateSnapshot.data()!['ownerId'] != currentUserId) {
        AppLogger.error('Template not found or access denied');
        return false;
      }

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null && name.trim().isNotEmpty) {
        updateData['name'] = name.trim();
      }
      if (description != null) {
        updateData['description'] = description.trim().isEmpty ? null : description.trim();
      }
      if (tags != null) {
        updateData['tags'] = tags;
      }
      if (isPublic != null) {
        updateData['isPublic'] = isPublic;
      }

      await templateDoc.update(updateData);
      
      AppLogger.success('✅ Template updated');
      return true;
    } catch (e) {
      AppLogger.error('Failed to update template', e);
      return false;
    }
  }

  // ===== TEMPLATE USAGE =====

  /// Create shopping list from template
  Future<String?> createFromTemplate({
    required String templateId,
    String? customName,
  }) async {
    try {
      if (!sl<PermissionService>().isAuthenticated) {
        AppLogger.warning('User must be logged in to create from template');
        return null;
      }

      // Load template data from Firebase
      final templateDoc = await FirebaseFirestore.instance
          .collection('shoppingListTemplates')
          .doc(templateId)
          .get();

      if (!templateDoc.exists) {
        AppLogger.error('Template not found');
        return null;
      }

      final templateData = templateDoc.data()!;
      final listName = customName ?? '${templateData['name']} (från mall)';
      final itemsData = templateData['items'] as List<dynamic>? ?? [];

      // Create items from template
      final items = itemsData.map((itemData) => _createItemFromTemplate(itemData)).toList();

      // Create new shopping list
      final listId = await _parent.createPersonalList(listName, items: items);
      if (listId != null) {
        AppLogger.success('✅ Created list from template: $listName');

        // Update template usage statistics
        await _updateTemplateUsageStats(templateId);
      }
      
      return listId;
    } catch (e) {
      AppLogger.error('Failed to create list from template', e);
      return null;
    }
  }

  // ===== TEMPLATE MANAGEMENT =====

  /// Get templates created by current user
  Future<List<Map<String, dynamic>>> getMyTemplates() async {
    try {
      if (!sl<PermissionService>().isAuthenticated) return [];
      
      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return [];

      final querySnapshot = await FirebaseFirestore.instance
          .collection('shoppingListTemplates')
          .where('ownerId', isEqualTo: currentUserId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Namnlös mall',
          'description': data['description'],
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],
          'isPublic': data['isPublic'] ?? false,
          'tags': data['tags'] ?? [],
          'itemCount': metadata['itemCount'] ?? 0,
          'categoryCount': metadata['categoryCount'] ?? 0,
          'usageCount': data['usageCount'] ?? 0,
        };
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get templates', e);
      return [];
    }
  }

  /// Delete template
  Future<bool> deleteTemplate(String templateId) async {
    try {
      if (!sl<PermissionService>().isAuthenticated) {
        AppLogger.warning('User must be logged in to delete template');
        return false;
      }

      final currentUserId = sl<PermissionService>().currentUserId;
      if (currentUserId == null) return false;

      final firestore = FirebaseFirestore.instance;
      final templateDoc = firestore.collection('shoppingListTemplates').doc(templateId);

      // Verify ownership
      final templateSnapshot = await templateDoc.get();
      if (!templateSnapshot.exists || 
          templateSnapshot.data()!['ownerId'] != currentUserId) {
        AppLogger.error('Template not found or access denied');
        return false;
      }

      await templateDoc.delete();
      
      AppLogger.success('✅ Template deleted');
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete template', e);
      return false;
    }
  }

  // ===== HELPER METHODS =====

  /// Get list by ID from parent service
  dynamic _getListById(String listId) {
    return _parent.lists.where((list) => list.id == listId).firstOrNull;
  }

  /// Create template items from shopping list
  List<Map<String, dynamic>> _createTemplateItems(UnifiedShoppingList list) {
    return list.items.map((item) => {
      'name': item.name,
      'amount': item.amount,
      'unit': item.unit,
      'category': item.category,
      'note': item.note,
      'estimatedPrice': item.estimatedPrice,
      'priority': item.priority,
    }).toList();
  }

  /// Create shopping item from template data
  dynamic _createItemFromTemplate(Map<String, dynamic> itemData) {
    // This would use the UnifiedShoppingItem constructor
    // The exact implementation depends on the item model
    return {
      'name': itemData['name'] ?? 'Okänd artikel',
      'amount': (itemData['amount'] as num?)?.toDouble() ?? 1.0,
      'unit': itemData['unit'] ?? '',
      'category': itemData['category'] ?? 'Övrigt',
      'note': itemData['note'],
      'estimatedPrice': (itemData['estimatedPrice'] as num?)?.toDouble(),
      'priority': itemData['priority'] ?? 3,
    };
  }

  /// Get unique category count from list
  int _getCategoryCount(UnifiedShoppingList list) {
    final categories = list.items.map((item) => item.category).where((c) => c.isNotEmpty).toSet();
    return categories.length;
  }

  /// Update template usage statistics
  Future<void> _updateTemplateUsageStats(String templateId) async {
    try {
      await FirebaseFirestore.instance
          .collection('shoppingListTemplates')
          .doc(templateId)
          .update({
        'usageCount': FieldValue.increment(1),
        'lastUsedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.debug('Failed to update template usage stats: $e');
      // Non-critical error, don't propagate
    }
  }
}