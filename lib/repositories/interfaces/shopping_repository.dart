import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

abstract class ShoppingRepository extends Repository<UnifiedShoppingList> {
  /// Set the currently active shopping list
  Future<void> setActiveList(String listId);

  /// Get the currently active shopping list if any
  Future<UnifiedShoppingList?> getActiveList();

  /// Add an item to a shopping list
  Future<void> addItem(String listId, UnifiedShoppingItem item);

  /// Remove an item from a shopping list
  Future<void> removeItem(String listId, String itemId);

  // ===== TEMPLATE OPERATIONS =====

  /// Save shopping list as template
  Future<String> saveAsTemplate({
    required String listId,
    required String templateName,
    String? description,
    List<String>? tags,
    bool isPublic = false,
  });

  /// Update existing template
  Future<void> updateTemplate({
    required String templateId,
    String? name,
    String? description,
    List<String>? tags,
    bool? isPublic,
  });

  /// Delete template
  Future<void> deleteTemplate(String templateId);

  /// Get user's templates
  Future<List<Map<String, dynamic>>> getUserTemplates();

  /// Get public templates
  Future<List<Map<String, dynamic>>> getPublicTemplates({
    int limit = 20,
    String? searchQuery,
    List<String>? tags,
  });

  /// Create shopping list from template
  Future<String> createListFromTemplate({
    required String templateId,
    required String listName,
    String? description,
  });
}
