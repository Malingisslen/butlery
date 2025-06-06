// lib/services/shopping_list_service.dart

import '../models/shopping_item.dart';
import '../models/recipe.dart';
import '../utils/text_utils.dart';

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
          final parsed = IngredientParser.parseIngredient(raw);

          // Normalisera ingrediensnamnet till singular för bättre gruppering
          final normalizedName = SwedishPluralization.normalizeToSingular(
            parsed.name,
          );

          // Skapa en unik nyckel baserat på enhet + normaliserat namn
          final key =
              parsed.unit.isEmpty
                  ? normalizedName
                  : '${parsed.unit}|$normalizedName';

          if (aggregated.containsKey(key)) {
            // Summera mängden
            aggregated[key]!.amount += parsed.quantity;
          } else {
            // Skapa ny ShoppingItem
            aggregated[key] = ShoppingItem(
              name: normalizedName,
              amount: parsed.quantity,
              unit: parsed.unit,
            );
          }
        }
      }
    }

    // Formatera slutresultatet med korrekt pluralisering
    final result = <ShoppingItem>[];
    for (var item in aggregated.values) {
      final formattedName = SwedishPluralization.pluralize(
        item.name,
        item.amount,
      );

      result.add(
        ShoppingItem(
          name: formattedName,
          amount: item.amount,
          unit: item.unit,
          bought: false,
        ),
      );
    }

    // Sortera alfabetiskt för bättre användbarhet
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return result;
  }

  /// Hjälpmetod för att generera en textrepresentation av inköpslistan
  String generateShoppingListText(List<ShoppingItem> items) {
    final buffer = StringBuffer();
    buffer.writeln('Inköpslista:');
    buffer.writeln();

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final checkbox = item.bought ? '☑' : '☐';

      String displayText;
      if (item.unit.isNotEmpty) {
        final amountStr = toSwedishHalfFraction(item.amount);
        displayText = '$amountStr ${item.unit} ${item.name}';
      } else {
        final amountStr =
            item.amount == 1.0 ? '' : '${toSwedishHalfFraction(item.amount)} ';
        displayText = '$amountStr${item.name}';
      }

      buffer.writeln('$checkbox $displayText');
    }

    return buffer.toString();
  }

  /// Hjälpmetod för att räkna statistik över inköpslistan
  Map<String, int> getShoppingListStats(List<ShoppingItem> items) {
    final total = items.length;
    final bought = items.where((item) => item.bought).length;
    final remaining = total - bought;

    return {
      'total': total,
      'bought': bought,
      'remaining': remaining,
      'completionPercentage': total > 0 ? (bought / total * 100).round() : 0,
    };
  }

  /// Markerar en vara som köpt/ej köpt
  void toggleItemBought(List<ShoppingItem> items, int index) {
    if (index >= 0 && index < items.length) {
      items[index].bought = !items[index].bought;
    }
  }

  /// Rensar alla checkade artiklar från listan
  List<ShoppingItem> clearBoughtItems(List<ShoppingItem> items) {
    return items.where((item) => !item.bought).toList();
  }

  /// Sorterar listan - köpta sist
  List<ShoppingItem> sortShoppingList(List<ShoppingItem> items) {
    items.sort((a, b) {
      // Först sorterar vi på köpt-status (false först)
      if (a.bought != b.bought) {
        return a.bought.toString().compareTo(b.bought.toString());
      }
      // Sedan alfabetiskt på namn
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }
}
