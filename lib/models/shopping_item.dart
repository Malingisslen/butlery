// lib/models/shopping_item.dart

class ShoppingItem {
  final String name; // Ingrediensens namn, t.ex. "Tomat"
  double amount; // Summerad mängd, t.ex. 1.5
  String unit; // Enhet, t.ex. "kg", "dl", "" om ingen
  bool bought; // Har vi köpt den? Avprickningsflagga

  ShoppingItem({
    required this.name,
    required this.amount,
    this.unit = '',
    this.bought = false,
  });
}
