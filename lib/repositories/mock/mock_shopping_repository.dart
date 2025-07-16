import '../interfaces/shopping_repository.dart';
import '../../models/unified/unified_shopping_list.dart';
import '../../models/unified/unified_shopping_item.dart';
import 'in_memory_repository.dart';

/// In-memory implementation of [ShoppingRepository] for tests.
class MockShoppingRepository extends InMemoryRepository<UnifiedShoppingList>
    implements ShoppingRepository {
  MockShoppingRepository() : super((l) => l.id);

  String? _activeListId;

  @override
  Future<void> setActiveList(String listId) async {
    _activeListId = listId;
  }

  @override
  Future<UnifiedShoppingList?> getActiveList() async {
    return _activeListId != null ? items[_activeListId!] : null;
  }

  @override
  Future<void> addItem(String listId, UnifiedShoppingItem item) async {
    final list = items[listId];
    if (list != null) {
      items[listId] = list.addItem(item);
    }
  }

  @override
  Future<void> removeItem(String listId, String itemId) async {
    final list = items[listId];
    if (list != null) {
      items[listId] = list.removeItem(itemId);
    }
  }
}
