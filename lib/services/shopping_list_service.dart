// lib/services/shopping_list_service.dart

import '../models/shopping_item.dart';
import '../models/recipe.dart';

/// Service som från en veckomeny (måltidstyp → lista recept)
/// bygger en samman­slagen inköpslista (ShoppingItem per ingrediens).
class ShoppingListService {
  /// Tar en meny där nyckeln är måltidstyp och värdet är listor av recept,
  /// och returnerar en summerad lista av ShoppingItem.
  List<ShoppingItem> createShoppingListFromMenu(
    Map<String, List<Recipe>> menuMap,
  ) {
    final Map<String, ShoppingItem> aggregated = {};

    for (var recipes in menuMap.values) {
      for (var recipe in recipes) {
        for (var raw in recipe.ingredients) {
          final item = _parseIngredient(raw);
          final key = '${item.name}|${item.unit}';
          if (aggregated.containsKey(key)) {
            aggregated[key]!.amount += item.amount;
          } else {
            aggregated[key] = item;
          }
        }
      }
    }

    return aggregated.values.toList();
  }

  /// Enkel parser som försöker plocka mängd, enhet och namn ur en sträng.
  /// Exempel: "3 dl mjöl" → amount:3, unit:"dl", name:"mjöl"
  ShoppingItem _parseIngredient(String raw) {
    final parts = raw.split(RegExp(r'\s+'));
    double amount = 1;
    String unit = '';
    String name = raw;

    // Första delen är siffra (eller tal med ,)
    final num =
        parts.isNotEmpty
            ? double.tryParse(parts[0].replaceAll(',', '.'))
            : null;
    if (num != null) {
      amount = num;
      if (parts.length >= 3) {
        unit = parts[1];
        name = parts.sublist(2).join(' ');
      } else if (parts.length == 2) {
        name = parts[1];
      }
    }

    return ShoppingItem(name: name, amount: amount, unit: unit);
  }
}
