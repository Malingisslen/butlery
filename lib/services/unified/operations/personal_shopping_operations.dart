import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';

/// Personal shopping operations interface providing individual shopping list management.
/// Handles personal list CRUD, item management, recipe integration, import/export, and analytics.
/// Delegates to UnifiedShoppingService while maintaining clean separation from collaborative features.
class PersonalShoppingOperations {
  final UnifiedShoppingService _parent;

  PersonalShoppingOperations(this._parent);

  Future<String?> createList(
    String name, {
    List<UnifiedShoppingItem>? items,
  }) async {
    return await _parent.createPersonalList(name, items: items);
  }

  List<UnifiedShoppingList> getAllLists() {
    return _parent.personalLists;
  }

  UnifiedShoppingList? getListById(String id) {
    try {
      return _parent.personalLists.firstWhere((list) => list.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<bool> renameList(String listId, String newName) async {
    final list = getListById(listId);
    if (list == null) {
      AppLogger.error('Cannot rename: Personal list not found');
      return false;
    }

    return await _parent.renameList(listId, newName);
  }

  Future<bool> deleteList(String listId) async {
    final list = getListById(listId);
    if (list == null) {
      AppLogger.error('Cannot delete: Personal list not found');
      return false;
    }

    if (list.isCollaborative) {
      AppLogger.error(
          'Cannot delete collaborative list through personal operations');
      return false;
    }

    return await _parent.deleteList(listId);
  }

  Future<bool> setActiveList(String listId) async {
    final list = getListById(listId);
    if (list == null) {
      AppLogger.error('Cannot set active: Personal list not found');
      return false;
    }

    return await _parent.setActiveList(listId);
  }

  UnifiedShoppingList? getActiveList() {
    final activeList = _parent.activeList;
    return activeList?.isPersonal == true ? activeList : null;
  }

  Future<bool> addItem({
    String? listId,
    required String name,
    required double amount,
    String unit = '',
    String category = 'Övrigt',
    String? note,
    double? estimatedPrice,
    int priority = 3,
  }) async {
    if (listId != null) {
      final list = getListById(listId);
      if (list == null) {
        AppLogger.error('Cannot add item: Personal list not found');
        return false;
      }

      // Temporarily set as active for adding item
      final previousActiveId = _parent.activeListId;
      await _parent.setActiveList(listId);

      final result = await _parent.addItemToActiveList(
        name: name,
        amount: amount,
        unit: unit,
        category: category,
        note: note,
        estimatedPrice: estimatedPrice,
        priority: priority,
      );

      // Restore previous active list
      if (previousActiveId != null) {
        await _parent.setActiveList(previousActiveId);
      }

      return result;
    }

    // Add to currently active list
    return await _parent.addItemToActiveList(
      name: name,
      amount: amount,
      unit: unit,
      category: category,
      note: note,
      estimatedPrice: estimatedPrice,
      priority: priority,
    );
  }

  Future<bool> updateItem({
    required String listId,
    required String itemId,
    String? name,
    double? amount,
    String? unit,
    String? category,
    String? note,
    double? estimatedPrice,
    int? priority,
  }) async {
    final list = getListById(listId);
    if (list == null) {
      AppLogger.error('Cannot update item: Personal list not found');
      return false;
    }

    UnifiedShoppingItem? item;
    try {
      item = list.items.firstWhere((item) => item.id == itemId);
    } catch (e) {
      AppLogger.error('Cannot update item: Item not found');
      return false;
    }

    // Create updated item
    final updatedItem = UnifiedShoppingItem(
      id: item.id,
      name: name ?? item.name,
      amount: amount ?? item.amount,
      unit: unit ?? item.unit,
      category: category ?? item.category,
      note: note ?? item.note,
      estimatedPrice: estimatedPrice ?? item.estimatedPrice,
      priority: priority ?? item.priority,
      bought: item.bought,
      purchasedAt: item.purchasedAt,
      purchasedByUserId: item.purchasedByUserId,
      purchasedByDisplayName: item.purchasedByDisplayName,
      addedByUserId: item.addedByUserId,
      addedByDisplayName: item.addedByDisplayName,
      addedAt: item.addedAt,
      lastModifiedByUserId: item.lastModifiedByUserId,
      lastModifiedByDisplayName: item.lastModifiedByDisplayName,
      lastModifiedAt: item.lastModifiedAt,
    );

    // Update the list
    final newItems =
        list.items.map((i) => i.id == itemId ? updatedItem : i).toList();
    final updatedList = list.copyWith(items: newItems);

    return await _parent.updateList(updatedList);
  }

  Future<bool> toggleItemBought(String itemId) async {
    final activeList = getActiveList();
    if (activeList == null) {
      AppLogger.error('No active personal list');
      return false;
    }

    return await _parent.toggleItemBought(itemId);
  }

  Future<bool> removeItem(String itemId) async {
    final activeList = getActiveList();
    if (activeList == null) {
      AppLogger.error('No active personal list');
      return false;
    }

    return await _parent.removeItemFromActiveList(itemId);
  }

  Future<bool> clearBoughtItems({String? listId}) async {
    if (listId != null) {
      final list = getListById(listId);
      if (list == null) {
        AppLogger.error('Cannot clear bought items: Personal list not found');
        return false;
      }

      // Temporarily set as active for clearing
      final previousActiveId = _parent.activeListId;
      await _parent.setActiveList(listId);

      final result = await _parent.clearBoughtItems();

      // Restore previous active list
      if (previousActiveId != null) {
        await _parent.setActiveList(previousActiveId);
      }

      return result;
    }

    return await _parent.clearBoughtItems();
  }

  Future<bool> uncheckAllItems({String? listId}) async {
    if (listId != null) {
      final list = getListById(listId);
      if (list == null) {
        AppLogger.error('Cannot uncheck items: Personal list not found');
        return false;
      }

      // Temporarily set as active for unchecking
      final previousActiveId = _parent.activeListId;
      await _parent.setActiveList(listId);

      final result = await _parent.uncheckAllItems();

      // Restore previous active list
      if (previousActiveId != null) {
        await _parent.setActiveList(previousActiveId);
      }

      return result;
    }

    return await _parent.uncheckAllItems();
  }

  Map<String, dynamic> getListStats(String listId) {
    final list = getListById(listId);
    if (list == null) return {};

    final totalItems = list.items.length;
    final boughtItems = list.items.where((item) => item.bought).length;
    final remainingItems = totalItems - boughtItems;

    final estimatedTotal = list.items
        .where((item) => item.estimatedPrice != null)
        .fold(0.0, (sum, item) => sum + (item.estimatedPrice! * item.amount));

    final categoryBreakdown = <String, int>{};
    for (final item in list.items) {
      categoryBreakdown[item.category] =
          (categoryBreakdown[item.category] ?? 0) + 1;
    }

    return {
      'listId': listId,
      'listName': list.name,
      'totalItems': totalItems,
      'boughtItems': boughtItems,
      'remainingItems': remainingItems,
      'completionPercentage':
          totalItems > 0 ? (boughtItems / totalItems * 100).round() : 0,
      'estimatedTotal': estimatedTotal,
      'categoryBreakdown': categoryBreakdown,
      'lastUpdated': list.updatedAt,
    };
  }

  Map<String, List<UnifiedShoppingItem>> getItemsByCategory(String listId) {
    final list = getListById(listId);
    if (list == null) return {};

    final categoryMap = <String, List<UnifiedShoppingItem>>{};

    for (final item in list.items) {
      final category = item.category.isEmpty ? 'Övrigt' : item.category;
      if (!categoryMap.containsKey(category)) {
        categoryMap[category] = [];
      }
      categoryMap[category]!.add(item);
    }

    // Sort items within each category by priority and name
    categoryMap.forEach((category, items) {
      items.sort((a, b) {
        final priorityCompare = a.priority.compareTo(b.priority);
        return priorityCompare != 0
            ? priorityCompare
            : a.name.compareTo(b.name);
      });
    });

    return categoryMap;
  }

  String exportListAsText(String listId) {
    final list = getListById(listId);
    if (list == null) return 'Lista hittades inte';

    final buffer = StringBuffer();
    buffer.writeln('📋 ${list.name}');
    buffer.writeln('=' * list.name.length);
    buffer.writeln();

    final activeItems = list.items.where((item) => !item.bought).toList();
    final boughtItems = list.items.where((item) => item.bought).toList();

    if (activeItems.isNotEmpty) {
      buffer.writeln('📝 Kvar att handla:');
      for (final item in activeItems) {
        buffer.writeln('☐ ${item.displayText}');
      }
      buffer.writeln();
    }

    if (boughtItems.isNotEmpty) {
      buffer.writeln('✅ Inhandlat:');
      for (final item in boughtItems) {
        buffer.writeln('☑ ${item.displayText}');
      }
    }

    buffer.writeln();
    buffer.writeln('Skapad: ${list.createdAt.toString().split(' ')[0]}');
    buffer.writeln('Uppdaterad: ${list.updatedAt.toString().split(' ')[0]}');

    return buffer.toString();
  }

  Map<String, dynamic> exportListAsData(String listId) {
    final list = getListById(listId);
    if (list == null) return {'error': 'Lista hittades inte'};

    return {
      'format': 'personal_shopping_list',
      'exportDate': DateTime.now().toIso8601String(),
      'list': {
        'id': list.id,
        'name': list.name,
        'description': list.description,
        'createdAt': list.createdAt.toIso8601String(),
        'updatedAt': list.updatedAt.toIso8601String(),
        'items': list.items
            .map((item) => {
                  'id': item.id,
                  'name': item.name,
                  'amount': item.amount,
                  'unit': item.unit,
                  'category': item.category,
                  'note': item.note,
                  'estimatedPrice': item.estimatedPrice,
                  'priority': item.priority,
                  'bought': item.bought,
                  'purchasedAt': item.purchasedAt?.toIso8601String(),
                })
            .toList(),
      },
      'statistics': getListStats(listId),
    };
  }

  Future<bool> importItemsFromText({
    required String listId,
    required String text,
    bool clearExisting = false,
  }) async {
    final list = getListById(listId);
    if (list == null) {
      AppLogger.error('Cannot import items: Personal list not found');
      return false;
    }

    try {
      final lines = text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      final itemsToAdd = <UnifiedShoppingItem>[];

      for (final line in lines) {
        // Skip headers and separators
        if (line.startsWith('=') ||
            line.startsWith('📋') ||
            line.startsWith('📝') ||
            line.startsWith('✅')) {
          continue;
        }

        // Parse item line
        String itemName = line.replaceAll(RegExp(r'^[☐☑✓✗-]\s*'), '').trim();
        if (itemName.isEmpty) continue;

        // Try to parse amount and unit
        double amount = 1.0;
        String unit = '';

        final amountMatch =
            RegExp(r'(\d+(?:\.\d+)?)\s*(\w+)?\s*(.+)').firstMatch(itemName);
        if (amountMatch != null) {
          amount = double.tryParse(amountMatch.group(1) ?? '1.0') ?? 1.0;
          unit = amountMatch.group(2) ?? '';
          itemName = amountMatch.group(3) ?? itemName;
        }

        final item = UnifiedShoppingItem.basic(
          name: itemName,
          amount: amount,
          unit: unit,
          category: 'Importerat',
        );

        itemsToAdd.add(item);
      }

      // Update the list
      List<UnifiedShoppingItem> newItems;
      if (clearExisting) {
        newItems = itemsToAdd;
      } else {
        newItems = [...list.items, ...itemsToAdd];
      }

      final updatedList = list.copyWith(items: newItems);
      await _parent.updateList(updatedList);

      AppLogger.success('Imported ${itemsToAdd.length} items to ${list.name}');
      return true;
    } catch (e) {
      AppLogger.error('Failed to import items from text', e);
      return false;
    }
  }

  Future<String?> createListFromRecipe({
    required String recipeName,
    required List<String> ingredients,
    double servingMultiplier = 1.0,
  }) async {
    try {
      final items = ingredients.map((ingredient) {
        // Basic parsing of ingredient text
        final parts = ingredient.split(' ');
        double amount = 1.0;
        String unit = '';
        String name = ingredient;

        if (parts.isNotEmpty) {
          final firstPart = parts[0];
          final parsedAmount = double.tryParse(firstPart);
          if (parsedAmount != null) {
            amount = parsedAmount * servingMultiplier;
            if (parts.length > 1) {
              unit = parts[1];
              name = parts.skip(2).join(' ');
            }
          }
        }

        return UnifiedShoppingItem.basic(
          name: name,
          amount: amount,
          unit: unit,
          category: 'Recept',
        );
      }).toList();

      return await createList(
        'Inköp för $recipeName',
        items: items,
      );
    } catch (e) {
      AppLogger.error('Failed to create list from recipe', e);
      return null;
    }
  }
}
