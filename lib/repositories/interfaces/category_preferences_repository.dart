import 'package:butlery/models/category_preferences.dart';
import 'package:butlery/models/list_category_order.dart';

/// Repository for user category preferences and per-list category ordering.
abstract class CategoryPreferencesRepository {
  Future<CategoryPreferences?> getPreferences();
  Future<void> savePreferences(CategoryPreferences prefs);
  Future<ListCategoryOrder?> getListCategoryOrder(String listId);
  Future<void> saveListCategoryOrder(ListCategoryOrder order);
  Future<void> deleteListCategoryOrder(String listId);

  /// Record a category override to the global collection for crowd-sourced learning
  Future<void> recordGlobalOverride(String itemName, String category);
}
