import 'package:butlery/repositories/interfaces/repository.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

/// Repository interface for shopping list operations.
abstract class ShoppingRepository extends Repository<UnifiedShoppingList> {
  /// Sets the specified shopping list as the currently active list.
  Future<void> setActiveList(String listId);

  /// Retrieves the currently active shopping list, if one is set.
  Future<UnifiedShoppingList?> getActiveList();

  /// Adds a new item to the specified shopping list.
  Future<void> addItem(String listId, UnifiedShoppingItem item);

  /// Adds multiple items to the specified shopping list using batch operations.
  Future<void> addItemsBatch(String listId, List<UnifiedShoppingItem> items);

  /// Removes an item from the specified shopping list.
  Future<void> removeItem(String listId, String itemId);

  // Template operations
  Future<String> saveAsTemplate({
    required String listId,
    required String templateName,
    String? description,
    List<String>? tags,
    bool isPublic = false,
  });

  Future<void> updateTemplate({
    required String templateId,
    String? name,
    String? description,
    List<String>? tags,
    bool? isPublic,
  });

  Future<void> deleteTemplate(String templateId);

  Future<List<Map<String, dynamic>>> getUserTemplates();

  Future<List<Map<String, dynamic>>> getPublicTemplates({
    int limit = 20,
    String? searchQuery,
    List<String>? tags,
  });

  Future<String> createListFromTemplate({
    required String templateId,
    required String listName,
    String? description,
  });
}
