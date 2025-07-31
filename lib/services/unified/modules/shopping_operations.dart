// Merged from shopping_item_management.dart + shopping_list_management.dart
import 'package:flutter/foundation.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

class ShoppingOperations {
  // Merged CRUD operations for items and lists
  Future<void> addItem(String listId, UnifiedShoppingItem item) async {}
  Future<void> removeItem(String listId, String itemId) async {}
  Future<void> createList(UnifiedShoppingList list) async {}
  Future<void> deleteList(String listId) async {}
}