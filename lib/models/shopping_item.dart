// lib/models/shopping_item.dart

/// Representerar en artikel i inköpslistan
class ShoppingItem {
  final String name;
  final double amount;
  final String unit;
  final String category;
  final bool bought;

  ShoppingItem({
    required this.name,
    required this.amount,
    this.unit = '',
    this.category = 'Övrigt',
    this.bought = false,
  });

  /// Konvertera till JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
      'category': category,
      'bought': bought,
    };
  }

  /// Skapa från JSON
  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      unit: json['unit'] as String? ?? '',
      category: json['category'] as String? ?? 'Övrigt',
      bought: json['bought'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    if (unit.isNotEmpty) {
      return '$amount $unit $name';
    }
    return '$amount $name';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShoppingItem &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          amount == other.amount &&
          unit == other.unit &&
          category == other.category &&
          bought == other.bought;

  @override
  int get hashCode =>
      name.hashCode ^
      amount.hashCode ^
      unit.hashCode ^
      category.hashCode ^
      bought.hashCode;
}
