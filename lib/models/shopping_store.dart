import 'package:butlery/core/utils/serialization_utils.dart';

/// A store the user shops in, with the category order they walk it in.
class ShoppingStore {
  static const int maxNameLength = 40;
  static const int maxStores = 10;

  final String id;
  final String name;
  final List<String> categoryOrder;

  const ShoppingStore({
    required this.id,
    required this.name,
    this.categoryOrder = const [],
  });

  ShoppingStore copyWith({String? name, List<String>? categoryOrder}) {
    return ShoppingStore(
      id: id,
      name: name ?? this.name,
      categoryOrder: categoryOrder ?? this.categoryOrder,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'name': name,
    'categoryOrder': categoryOrder,
  };

  /// Null when the row has no usable id or name, so one damaged entry cannot
  /// take the rest of the user's stores with it.
  static ShoppingStore? tryFromFirestore(Object? raw) {
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    final id = data['id'];
    final name = data['name'];
    if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
      return null;
    }
    return ShoppingStore(
      id: id,
      name: name,
      categoryOrder: SerializationUtils.safeStringList(data, 'categoryOrder'),
    );
  }
}
