// lib/utils/text/shopping_list_generator.dart

import 'package:butlery/utils/text/unit_converter.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';
import 'package:butlery/utils/text/swedish_pluralization.dart';

/// ShoppingListGenerator - Shopping list generation utilities
///
/// Handles generation of shopping lists from menu data.
class ShoppingListGenerator {
  static List<String> generateShoppingList(Map<String, List<dynamic>> menu) {
    if (menu.isEmpty) return [];

    // Samla alla ingredienser
    final List<String> allIngredients = [];
    for (final recipesInSection in menu.values) {
      for (final recipe in recipesInSection) {
        // Anta att recipe har en ingredients property som är List<String>
        if (recipe is Map && recipe.containsKey('ingredients')) {
          final ingredients = recipe['ingredients'] as List?;
          if (ingredients != null) {
            allIngredients.addAll(ingredients.map((e) => e.toString()));
          }
        } else if (recipe.toString().contains('ingredients')) {
          // Fallback för Recipe objekt
          try {
            final recipeObj = recipe as dynamic;
            final ingredients = recipeObj.ingredients as List<String>?;
            if (ingredients != null) {
              allIngredients.addAll(ingredients);
            }
          } catch (e) {
            // Ignorera fel och fortsätt
          }
        }
      }
    }

    // Gruppera ingredienser
    final Map<String, double> groupedIngredients = {};

    for (final rawIngredient in allIngredients) {
      if (rawIngredient.trim().isEmpty) continue;

      final parsed = IngredientParser.parseIngredient(rawIngredient);

      // Skapa en nyckel baserat på enhet + normaliserat namn
      final normalizedName = SwedishPluralization.normalizeToSingular(
        parsed.name,
      );
      final key =
          parsed.unit.isEmpty
              ? normalizedName
              : '${parsed.unit} $normalizedName';

      // Summera kvantiteter
      groupedIngredients[key] =
          (groupedIngredients[key] ?? 0.0) + parsed.quantity;
    }

    // Formatera för visning med smart enhetskonvertering
    final displayList = <String>[];
    final sortedKeys = groupedIngredients.keys.toList()..sort();

    for (final key in sortedKeys) {
      final totalQuantity = groupedIngredients[key]!;

      // Använd smart enhetskonvertering för inköpslistor
      final parts = key.split(' ');
      if (parts.length > 1 &&
          SwedishPluralization.isMeasurementUnit(parts[0])) {
        final unit = parts[0];
        final name = parts.sublist(1).join(' ');

        if (SmartUnitConverter.shouldConvert(totalQuantity, unit)) {
          final converted = SmartUnitConverter.convertToReadableUnit(
            totalQuantity,
            unit,
          );
          final formatted = SwedishPluralization.formatIngredient(
            '${converted.unit} $name',
            converted.quantity,
          );
          displayList.add(formatted);
        } else {
          final formatted = SwedishPluralization.formatIngredient(
            key,
            totalQuantity,
          );
          displayList.add(formatted);
        }
      } else {
        final formatted = SwedishPluralization.formatIngredient(
          key,
          totalQuantity,
        );
        displayList.add(formatted);
      }
    }

    return displayList;
  }
}