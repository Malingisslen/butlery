import 'dart:async' show unawaited;
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/models/category_preferences.dart';
import 'package:butlery/models/list_category_order.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/utils/logger.dart';

/// Manages per-user category preferences: item→category overrides and category ordering.
class ShoppingCategoryPreferencesModule {
  final CategoryPreferencesRepository _repository;

  CategoryPreferences? _preferences;
  final Map<String, ListCategoryOrder> _listOrders = {};

  ShoppingCategoryPreferencesModule({
    required CategoryPreferencesRepository repository,
  }) : _repository = repository;

  bool get isLoaded => _preferences != null;

  Future<void> load() async {
    _preferences = await _repository.getPreferences();
    _preferences ??= CategoryPreferences();
  }

  /// Get the user's category override for an item, or null if none exists
  String? getUserCategoryOverride(String itemName) {
    if (_preferences == null) return null;
    final normalized = CategoryPreferences.normalizeItemName(itemName);
    return _preferences!.itemCategoryOverrides[normalized];
  }

  /// Set item→category override for the user and record globally
  Future<void> setItemCategory(String itemName, String category) async {
    final normalized = CategoryPreferences.normalizeItemName(itemName);
    final updatedOverrides = Map<String, String>.from(
      _preferences?.itemCategoryOverrides ?? {},
    );
    updatedOverrides[normalized] = category;

    _preferences = (_preferences ?? CategoryPreferences()).copyWith(
      itemCategoryOverrides: updatedOverrides,
    );

    try {
      await _repository.savePreferences(_preferences!);
      unawaited(_repository.recordGlobalOverride(itemName, category));
    } catch (e, st) {
      AppLogger.error('Failed to save item category override: $e', st);
    }
  }

  /// Get effective category order for a list (list-specific → user default → hardcoded)
  List<String> getEffectiveCategoryOrder(String? listId) {
    if (listId != null && _listOrders.containsKey(listId)) {
      return _listOrders[listId]!.categoryOrder;
    }
    if (_preferences != null && _preferences!.defaultCategoryOrder.isNotEmpty) {
      return _preferences!.defaultCategoryOrder;
    }
    return ShoppingCategory.defaultStoreOrder;
  }

  /// Save category order for a specific list
  Future<void> saveListCategoryOrder(
    String listId,
    List<String> order,
  ) async {
    final listOrder = ListCategoryOrder(
      listId: listId,
      categoryOrder: order,
    );
    _listOrders[listId] = listOrder;
    try {
      await _repository.saveListCategoryOrder(listOrder);
    } catch (e, st) {
      AppLogger.error('Failed to save list category order: $e', st);
    }
  }

  /// Save user's default category order
  Future<void> saveDefaultCategoryOrder(List<String> order) async {
    _preferences = (_preferences ?? CategoryPreferences()).copyWith(
      defaultCategoryOrder: order,
    );
    try {
      await _repository.savePreferences(_preferences!);
    } catch (e, st) {
      AppLogger.error('Failed to save default category order: $e', st);
    }
  }

  /// Reset a list's category order to the user default
  Future<void> resetListCategoryOrder(String listId) async {
    _listOrders.remove(listId);
    try {
      await _repository.deleteListCategoryOrder(listId);
    } catch (e, st) {
      AppLogger.error('Failed to reset list category order: $e', st);
    }
  }

  /// Load list-specific category order (lazy, on demand)
  Future<List<String>> loadListCategoryOrder(String listId) async {
    if (_listOrders.containsKey(listId)) {
      return _listOrders[listId]!.categoryOrder;
    }
    final order = await _repository.getListCategoryOrder(listId);
    if (order != null) {
      _listOrders[listId] = order;
      return order.categoryOrder;
    }
    return getEffectiveCategoryOrder(listId);
  }

  void reset() {
    _preferences = null;
    _listOrders.clear();
  }
}
