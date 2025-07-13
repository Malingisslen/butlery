import '../repository.dart';
import '../../models/unified/unified_shopping_list.dart';
import '../../models/unified/unified_shopping_item.dart';

abstract class ShoppingRepository extends Repository<UnifiedShoppingList> {
  /// Set the currently active shopping list
  Future<void> setActiveList(String listId);

  /// Get the currently active shopping list if any
  Future<UnifiedShoppingList?> getActiveList();

  /// Add an item to a shopping list
  Future<void> addItem(String listId, UnifiedShoppingItem item);

  /// Remove an item from a shopping list
  Future<void> removeItem(String listId, String itemId);
}
