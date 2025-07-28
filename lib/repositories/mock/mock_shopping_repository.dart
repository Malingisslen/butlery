import 'package:butlery/repositories/interfaces/shopping_repository.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/repositories/mock/in_memory_repository.dart';

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

  // ===== TEMPLATE OPERATIONS (MOCK IMPLEMENTATION) =====

  final Map<String, Map<String, dynamic>> _templates = {};

  @override
  Future<String> saveAsTemplate({
    required String listId,
    required String templateName,
    String? description,
    List<String>? tags,
    bool isPublic = false,
  }) async {
    final list = items[listId];
    if (list == null) throw Exception('List not found');

    final templateId = 'template_${DateTime.now().millisecondsSinceEpoch}';
    _templates[templateId] = {
      'id': templateId,
      'name': templateName,
      'description': description,
      'ownerId': 'mock_user',
      'ownerDisplayName': 'Mock User',
      'originalListId': listId,
      'items': list.items.map((item) => item.toFirestore()).toList(),
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'isPublic': isPublic,
      'tags': tags ?? <String>[],
      'metadata': {
        'itemCount': list.items.length,
        'version': '1.0',
      },
    };

    return templateId;
  }

  @override
  Future<void> updateTemplate({
    required String templateId,
    String? name,
    String? description,
    List<String>? tags,
    bool? isPublic,
  }) async {
    final template = _templates[templateId];
    if (template == null) throw Exception('Template not found');

    if (name != null) template['name'] = name;
    if (description != null) template['description'] = description;
    if (tags != null) template['tags'] = tags;
    if (isPublic != null) template['isPublic'] = isPublic;
    template['updatedAt'] = DateTime.now().toIso8601String();
  }

  @override
  Future<void> deleteTemplate(String templateId) async {
    _templates.remove(templateId);
  }

  @override
  Future<List<Map<String, dynamic>>> getUserTemplates() async {
    return _templates.values.where((t) => t['ownerId'] == 'mock_user').toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getPublicTemplates({
    int limit = 20,
    String? searchQuery,
    List<String>? tags,
  }) async {
    var templates = _templates.values.where((t) => t['isPublic'] == true).toList();
    
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      templates = templates.where((template) {
        final name = (template['name'] as String? ?? '').toLowerCase();
        final description = (template['description'] as String? ?? '').toLowerCase();
        return name.contains(lowerQuery) || description.contains(lowerQuery);
      }).toList();
    }

    return templates.take(limit).toList();
  }

  @override
  Future<String> createListFromTemplate({
    required String templateId,
    required String listName,
    String? description,
  }) async {
    final template = _templates[templateId];
    if (template == null) throw Exception('Template not found');

    final templateItems = List<Map<String, dynamic>>.from(template['items'] ?? []);
    final itemsList = templateItems.map((itemData) => 
        UnifiedShoppingItem.fromFirestore(itemData)).toList();

    final newList = UnifiedShoppingList(
      name: listName,
      description: description,
      ownerId: 'mock_user',
      ownerDisplayName: 'Mock User',
      items: itemsList,
    );

    final createdList = await create(newList);
    return createdList.id;
  }
}
