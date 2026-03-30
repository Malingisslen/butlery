import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';

/// Per-user category preferences for shopping lists.
/// Stores item→category overrides and default category display order.
class CategoryPreferences {
  final String id;
  final Map<String, String> itemCategoryOverrides;
  final List<String> defaultCategoryOrder;
  final DateTime updatedAt;

  CategoryPreferences({
    this.id = 'shopping',
    this.itemCategoryOverrides = const {},
    List<String>? defaultCategoryOrder,
    DateTime? updatedAt,
  })  : defaultCategoryOrder =
            defaultCategoryOrder ?? ShoppingCategory.defaultStoreOrder,
        updatedAt = updatedAt ?? DateTime.now();

  CategoryPreferences copyWith({
    Map<String, String>? itemCategoryOverrides,
    List<String>? defaultCategoryOrder,
    DateTime? updatedAt,
  }) {
    return CategoryPreferences(
      id: id,
      itemCategoryOverrides:
          itemCategoryOverrides ?? this.itemCategoryOverrides,
      defaultCategoryOrder:
          defaultCategoryOrder ?? this.defaultCategoryOrder,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itemCategoryOverrides': itemCategoryOverrides,
      'defaultCategoryOrder': defaultCategoryOrder,
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
      updatedAt: SerializationUtils.safeDateTime(data, 'updatedAt'),
    );
  }

  /// Normalize item name for consistent lookups
  static String normalizeItemName(String name) {
    return name.trim().toLowerCase();
  }
}
