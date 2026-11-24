import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/shopping_store.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

/// Per-user category preferences for shopping lists.
/// Stores item→category overrides, default category display order and the
/// user's own stores (each with its own order) and which one a list uses.
class CategoryPreferences {
  final String id;
  final Map<String, String> itemCategoryOverrides;
  final List<String> defaultCategoryOrder;
  final List<ShoppingStore> stores;
  final Map<String, String> activeStoreByList;
  final DateTime updatedAt;

  CategoryPreferences({
    this.id = 'shopping',
    this.itemCategoryOverrides = const {},
    List<String>? defaultCategoryOrder,
    this.stores = const [],
    this.activeStoreByList = const {},
    DateTime? updatedAt,
  }) : defaultCategoryOrder =
           defaultCategoryOrder ?? ShoppingCategory.defaultStoreOrder,
       updatedAt = updatedAt ?? clock.now();

  CategoryPreferences copyWith({
    Map<String, String>? itemCategoryOverrides,
    List<String>? defaultCategoryOrder,
    List<ShoppingStore>? stores,
    Map<String, String>? activeStoreByList,
    DateTime? updatedAt,
  }) {
    return CategoryPreferences(
      id: id,
      itemCategoryOverrides:
          itemCategoryOverrides ?? this.itemCategoryOverrides,
      defaultCategoryOrder: defaultCategoryOrder ?? this.defaultCategoryOrder,
      stores: stores ?? this.stores,
      activeStoreByList: activeStoreByList ?? this.activeStoreByList,
      updatedAt: updatedAt ?? clock.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itemCategoryOverrides': itemCategoryOverrides,
      'defaultCategoryOrder': defaultCategoryOrder,
      'stores': stores.map((s) => s.toFirestore()).toList(),
      'activeStoreByList': activeStoreByList,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory CategoryPreferences.fromFirestore(Map<String, dynamic> data) {
    return CategoryPreferences(
      itemCategoryOverrides: SerializationUtils.safeMap(
        data,
        'itemCategoryOverrides',
      ).map((k, v) => MapEntry(k, v.toString())),
      defaultCategoryOrder: SerializationUtils.safeStringList(
        data,
        'defaultCategoryOrder',
      ),
      stores: SerializationUtils.safeList<ShoppingStore?>(
        data,
        'stores',
        ShoppingStore.tryFromFirestore,
      ).whereType<ShoppingStore>().toList(),
      activeStoreByList: SerializationUtils.safeMap(
        data,
        'activeStoreByList',
      ).map((k, v) => MapEntry(k, v.toString())),
      updatedAt: SerializationUtils.safeDateTime(data, 'updatedAt'),
    );
  }

  /// Normalize item name for consistent lookups
  static String normalizeItemName(String name) {
    return name.trim().toLowerCase();
  }
}
