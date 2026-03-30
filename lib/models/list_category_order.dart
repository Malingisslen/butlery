import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// Per-list category display order, personal to each user.
class ListCategoryOrder {
  final String listId;
  final List<String> categoryOrder;
  final DateTime updatedAt;

  ListCategoryOrder({
    required this.listId,
    required this.categoryOrder,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toFirestore() {
    return {
      'categoryOrder': categoryOrder,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ListCategoryOrder.fromFirestore(
    String listId,
    Map<String, dynamic> data,
  ) {
    return ListCategoryOrder(
      listId: listId,
      categoryOrder: SerializationUtils.safeStringList(
        data,
        'categoryOrder',
      ),
      updatedAt: SerializationUtils.safeDateTime(data, 'updatedAt'),
    );
  }
}
