/// Factory for creating test shopping list objects
///
/// Provides consistent test data creation for unified shopping lists
/// with Swedish defaults and complete data initialization.
library;

import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

/// Factory for creating test shopping lists
class ShoppingListFactory {
  /// Build a shopping list with Swedish defaults
  static UnifiedShoppingList build({
    String? id,
    String name = 'Inköpslista',
    String ownerId = 'test-user-123',
    String ownerDisplayName = 'Test Användare',
    List<UnifiedShoppingItem>? items,
    ListType type = ListType.personal,
    Map<String, SharedListPermission>? memberPermissions,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    return UnifiedShoppingList(
      id: id ?? 'list_${now.millisecondsSinceEpoch}',
      name: name,
      ownerId: ownerId,
      ownerDisplayName: ownerDisplayName,
      items: items ?? [],
      type: type,
      memberPermissions: memberPermissions ?? {},
      description: description,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? now,
      lastSyncedAt: now,
      syncStatus: SyncStatus.synced,
    );
  }

  /// Build a shopping list item with Swedish defaults
  static UnifiedShoppingItem buildItem({
    String? id,
    String name = 'Mjölk',
    double amount = 1.0,
    String unit = 'liter',
    String category = 'Mejeri',
    bool bought = false,
    int priority = 3,
    DateTime? addedAt,
  }) {
    final now = DateTime.now();
    return UnifiedShoppingItem(
      id: id ?? 'item_${now.millisecondsSinceEpoch}',
      name: name,
      amount: amount,
      unit: unit,
      category: category,
      bought: bought,
      priority: priority,
      addedAt: addedAt ?? now,
    );
  }

  /// Build a week's shopping list with Swedish groceries
  static UnifiedShoppingList buildWeeklyList({
    String? id,
    String? ownerId,
    String? ownerDisplayName,
  }) {
    return build(
      id: id,
      name: 'Veckans inköp',
      ownerId: ownerId ?? 'test-user-123',
      ownerDisplayName: ownerDisplayName ?? 'Test Användare',
      description: 'Inköpslista för vecka ${DateTime.now().weekday}',
      items: [
        buildItem(name: 'Mjölk', amount: 2, unit: 'liter', category: 'Mejeri'),
        buildItem(name: 'Bröd', amount: 1, unit: 'st', category: 'Bageri'),
        buildItem(name: 'Ägg', amount: 12, unit: 'st', category: 'Mejeri'),
        buildItem(name: 'Köttfärs', amount: 500, unit: 'g', category: 'Kött'),
        buildItem(
            name: 'Potatis', amount: 2, unit: 'kg', category: 'Grönsaker'),
        buildItem(name: 'Lök', amount: 3, unit: 'st', category: 'Grönsaker'),
        buildItem(
            name: 'Tomater', amount: 500, unit: 'g', category: 'Grönsaker'),
        buildItem(name: 'Ost', amount: 200, unit: 'g', category: 'Mejeri'),
        buildItem(name: 'Smör', amount: 500, unit: 'g', category: 'Mejeri'),
        buildItem(name: 'Kaffe', amount: 500, unit: 'g', category: 'Skafferi'),
      ],
    );
  }

  /// Build a shared shopping list for collaboration
  static UnifiedShoppingList buildSharedList({
    String? id,
    String? ownerId,
    String? ownerDisplayName,
    Map<String, SharedListPermission>? memberPermissions,
  }) {
    return build(
      id: id,
      name: 'Familjens inköpslista',
      ownerId: ownerId ?? 'test-user-123',
      ownerDisplayName: ownerDisplayName ?? 'Test Användare',
      type: ListType.collaborative,
      memberPermissions: memberPermissions ??
          {
            'user-456': SharedListPermission.edit,
            'user-789': SharedListPermission.view,
          },
      description: 'Delad lista för familjen',
      items: [
        buildItem(name: 'Mjölk', category: 'Mejeri'),
        buildItem(name: 'Bröd', category: 'Bageri'),
        buildItem(name: 'Frukt', amount: 1, unit: 'kg', category: 'Frukt'),
      ],
    );
  }

  /// Build a recipe-linked shopping list
  static UnifiedShoppingList buildRecipeList({
    String? id,
    String recipeId = 'recipe-123',
    String recipeTitle = 'Köttbullar med potatismos',
    String? ownerId,
    String? ownerDisplayName,
  }) {
    return build(
      id: id,
      name: 'Ingredienser för $recipeTitle',
      ownerId: ownerId ?? 'test-user-123',
      ownerDisplayName: ownerDisplayName ?? 'Test Användare',
      description: 'Automatiskt genererad från recept',
      items: [
        buildItem(
          name: 'Köttfärs',
          amount: 500,
          unit: 'g',
          category: 'Kött',
        ),
        buildItem(
          name: 'Ströbröd',
          amount: 1,
          unit: 'dl',
          category: 'Skafferi',
        ),
        buildItem(
          name: 'Ägg',
          amount: 1,
          unit: 'st',
          category: 'Mejeri',
        ),
        buildItem(
          name: 'Potatis',
          amount: 1,
          unit: 'kg',
          category: 'Grönsaker',
        ),
        buildItem(
          name: 'Mjölk',
          amount: 2,
          unit: 'dl',
          category: 'Mejeri',
        ),
        buildItem(
          name: 'Smör',
          amount: 50,
          unit: 'g',
          category: 'Mejeri',
        ),
      ],
    );
  }
}
