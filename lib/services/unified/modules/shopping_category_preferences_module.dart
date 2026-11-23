import 'dart:async' show unawaited;
import 'package:butlery/repositories/interfaces/category_preferences_repository.dart';
import 'package:butlery/models/category_preferences.dart';
import 'package:butlery/models/list_category_order.dart';
import 'package:butlery/models/shopping_store.dart';
import 'package:clock/clock.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
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

  // Bumped by [reset]; a load that finishes after a sign-out must not put the
  // previous account's preferences back.
  int _generation = 0;

  Future<void> load() async {
    final generation = _generation;
    final loaded = await _repository.getPreferences();
    if (generation != _generation) return;
    _preferences = loaded ?? CategoryPreferences();
  }

  /// Get the user's category override for an item, or null if none exists
  String? getUserCategoryOverride(String itemName) {
    if (_preferences == null) return null;
    final normalized = CategoryPreferences.normalizeItemName(itemName);
    return _preferences!.itemCategoryOverrides[normalized];
  }

  /// [item] in the category the user once moved this name to, so a row a
  /// recipe or the menu adds lands where the user's own rows already do.
  UnifiedShoppingItem withUserCategory(UnifiedShoppingItem item) {
    final override = getUserCategoryOverride(item.name);
    return override == null || override == item.category
        ? item
        : item.copyWith(category: override);
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

  /// Get effective category order for a list (store → list → user default → hardcoded)
  List<String> getEffectiveCategoryOrder(String? listId) {
    final store = activeStoreFor(listId);
    if (store != null && store.categoryOrder.isNotEmpty) {
      return store.categoryOrder;
    }
    if (listId != null && _listOrders.containsKey(listId)) {
      return _listOrders[listId]!.categoryOrder;
    }
    if (_preferences != null && _preferences!.defaultCategoryOrder.isNotEmpty) {
      return _preferences!.defaultCategoryOrder;
    }
    return ShoppingCategory.defaultStoreOrder;
  }

  List<ShoppingStore> get stores => _preferences?.stores ?? const [];

  /// The store the user picked for [listId], or null (personal, per list).
  ShoppingStore? activeStoreFor(String? listId) {
    if (listId == null) return null;
    final id = _preferences?.activeStoreByList[listId];
    if (id == null || id.isEmpty) return null;
    return stores.where((s) => s.id == id).firstOrNull;
  }

  /// Adds a store named [name]; null when the name is blank or the user is
  /// at [ShoppingStore.maxStores].
  Future<ShoppingStore?> addStore(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || stores.length >= ShoppingStore.maxStores) {
      return null;
    }
    final store = ShoppingStore(
      id: 'store_${clock.now().microsecondsSinceEpoch}',
      name: trimmed.length > ShoppingStore.maxNameLength
          ? trimmed.substring(0, ShoppingStore.maxNameLength)
          : trimmed,
    );
    await _saveStores([...stores, store]);
    return store;
  }

  Future<void> deleteStore(String storeId) async {
    final active = Map<String, String>.from(
      _preferences?.activeStoreByList ?? {},
    )..updateAll((_, id) => id == storeId ? '' : id);
    await _saveStores(
      stores.where((s) => s.id != storeId).toList(),
      activeStoreByList: active,
    );
  }

  /// Picks [storeId] for [listId]; null means no store (an empty string is
  /// stored because a merge write cannot remove a map key).
  Future<void> setActiveStore(String listId, String? storeId) async {
    final active = Map<String, String>.from(
      _preferences?.activeStoreByList ?? {},
    )..[listId] = storeId.orEmpty();
    await _saveStores(stores, activeStoreByList: active);
  }

  Future<void> saveStoreCategoryOrder(
    String storeId,
    List<String> order,
  ) async {
    await _saveStores([
      for (final s in stores)
        s.id == storeId ? s.copyWith(categoryOrder: order) : s,
    ]);
  }

  Future<void> _saveStores(
    List<ShoppingStore> updated, {
    Map<String, String>? activeStoreByList,
  }) async {
    _preferences = (_preferences ?? CategoryPreferences()).copyWith(
      stores: updated,
      activeStoreByList: activeStoreByList,
    );
    try {
      await _repository.savePreferences(_preferences!);
    } catch (e, st) {
      AppLogger.error('Failed to save shopping stores: $e', st);
    }
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
    _generation++;
    _preferences = null;
    _listOrders.clear();
  }
}
