// lib/services/unified/operations/shopping_share/shopping_template_module.dart

// Firebase access refactored to use repository pattern
// Now uses ShoppingRepository for all template CRUD operations

// UnifiedShoppingList import removed - operations now handled by repository
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/services/unified/operations/shopping_share/shared/shopping_share_utils.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:get_it/get_it.dart';

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
  final ShoppingRepository _shoppingRepository;

  ShoppingTemplateModule(this._parent) : _shoppingRepository = GetIt.instance<ShoppingRepository>();

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
      
      // Save template using repository
      await _shoppingRepository.saveAsTemplate(
        listId: listId,
        templateName: templateName.trim(),
        description: description?.trim(),
        tags: tags,
        isPublic: isPublic,
      );
      
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

      // Update template using repository
      await _shoppingRepository.updateTemplate(
        templateId: templateId,
        name: name?.trim().isEmpty == true ? null : name?.trim(),
        description: description?.trim().isEmpty == true ? null : description?.trim(),
        tags: tags,
        isPublic: isPublic,
      );
      
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

      // Create list from template using repository
      final listName = customName ?? 'Lista från mall';
      final listId = await _shoppingRepository.createListFromTemplate(
        templateId: templateId,
        listName: listName,
      );
      
      AppLogger.success('✅ Created list from template: $listName');
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

      // Get user templates using repository
      return await _shoppingRepository.getUserTemplates();
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

      // Delete template using repository
      await _shoppingRepository.deleteTemplate(templateId);
      
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

  // Other helper methods removed - template operations now handled by repository layer
}