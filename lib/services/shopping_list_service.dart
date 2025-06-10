// lib/services/shopping_list_service.dart

import '../models/recipe.dart';
import '../models/shopping_item.dart';
import '../utils/text_utils.dart';

/// Service för att hantera inköpslistor
class ShoppingListService {
  /// Skapa inköpslista från en veckomeny
  List<ShoppingItem> createShoppingListFromMenu(
    Map<String, List<Recipe>> menu,
  ) {
    final Map<String, ShoppingItem> aggregatedItems = {};

    // Gå igenom alla recept i menyn
    for (final recipes in menu.values) {
      for (final recipe in recipes) {
        for (final ingredient in recipe.ingredients) {
          final parsed = parseIngredient(ingredient);
          final key = '${parsed.name}-${parsed.unit}';

          if (aggregatedItems.containsKey(key)) {
            // Uppdatera befintlig artikel
            final existing = aggregatedItems[key]!;
            aggregatedItems[key] = ShoppingItem(
              name: existing.name,
              amount: existing.amount + parsed.amount,
              unit: existing.unit,
              category: existing.category,
              bought: false, // Nya items är alltid oköpta
            );
          } else {
            // Lägg till ny artikel
            aggregatedItems[key] = parsed;
          }
        }
      }
    }

    // Sortera efter kategori och namn
    final sortedItems =
        aggregatedItems.values.toList()..sort((a, b) {
          final categoryCompare = a.category.compareTo(b.category);
          if (categoryCompare != 0) return categoryCompare;
          return a.name.compareTo(b.name);
        });

    return sortedItems;
  }

  /// Parsa en ingrediensrad till strukturerad data
  ShoppingItem parseIngredient(String ingredient) {
    final trimmed = ingredient.trim();

    // Matcha mönster som "2 dl mjölk", "1 kg potatis", "salt", etc.
    final pattern = RegExp(
      r'^(\d+(?:[,\.]\d+)?(?:\s*-\s*\d+(?:[,\.]\d+)?)?)\s*([a-zA-ZåäöÅÄÖ]+)?\s+(.+)$',
    );

    final match = pattern.firstMatch(trimmed);

    if (match != null) {
      // Har mängd och eventuell enhet
      final amountStr = match.group(1)!;
      final unit = match.group(2) ?? '';
      final name = match.group(3)!;

      // Hantera intervall (t.ex. "1-2 dl")
      double amount;
      if (amountStr.contains('-')) {
        final parts = amountStr.split('-');
        final min = parseSwedishNumber(parts[0]);
        final max = parseSwedishNumber(parts[1]);
        amount = (min + max) / 2; // Ta medelvärdet
      } else {
        amount = parseSwedishNumber(amountStr);
      }

      return ShoppingItem(
        name: _normalizeIngredientName(name),
        amount: amount,
        unit: _normalizeUnit(unit),
        category: _categorizeIngredient(name),
        bought: false,
      );
    } else {
      // Ingen mängd angiven (t.ex. "salt", "peppar")
      return ShoppingItem(
        name: _normalizeIngredientName(trimmed),
        amount: 1,
        unit: '',
        category: _categorizeIngredient(trimmed),
        bought: false,
      );
    }
  }

  /// Normalisera ingrediensnamn
  String _normalizeIngredientName(String name) {
    // Ta bort onödiga ord och standardisera
    String normalized = name.toLowerCase().trim();

    // Ta bort vanliga suffix
    normalized = normalized
        .replaceAll(
          RegExp(
            r',?\s*(färsk|färska|fryst|frysta|hackad|hackade|riven|rivna|strimlad|strimlade)$',
          ),
          '',
        )
        .replaceAll(RegExp(r',?\s*(gärna|helst|ev\.?|eventuellt).*$'), '');

    // Standardisera vissa ingredienser
    final replacements = {
      'mjölk': 'mjölk',
      'mellanmjölk': 'mjölk',
      'standardmjölk': 'mjölk',
      'lättmjölk': 'mjölk',
      'vetemjöl': 'mjöl',
      'mjöl': 'mjöl',
      'strösocker': 'socker',
      'socker': 'socker',
    };

    for (final entry in replacements.entries) {
      if (normalized.contains(entry.key)) {
        normalized = normalized.replaceAll(entry.key, entry.value);
        break;
      }
    }

    // Första bokstaven versal
    if (normalized.isNotEmpty) {
      normalized = normalized[0].toUpperCase() + normalized.substring(1);
    }

    return normalized;
  }

  /// Normalisera enhet
  String _normalizeUnit(String unit) {
    final lower = unit.toLowerCase();

    final unitMap = {
      'dl': 'dl',
      'deciliter': 'dl',
      'l': 'l',
      'liter': 'l',
      'ml': 'ml',
      'milliliter': 'ml',
      'g': 'g',
      'gram': 'g',
      'kg': 'kg',
      'kilogram': 'kg',
      'hg': 'hg',
      'hekto': 'hg',
      'tsk': 'tsk',
      'tesked': 'tsk',
      'msk': 'msk',
      'matsked': 'msk',
      'krm': 'krm',
      'kryddmått': 'krm',
      'st': 'st',
      'styck': 'st',
      'stycken': 'st',
      'port': 'port',
      'portioner': 'port',
      'påse': 'påse',
      'påsar': 'påse',
      'burk': 'burk',
      'burkar': 'burk',
      'paket': 'paket',
      'förp': 'förp',
      'förpackning': 'förp',
      'klyftor': 'klyftor',
      'klyfta': 'klyftor',
    };

    return unitMap[lower] ?? unit;
  }

  /// Kategorisera ingrediens
  String _categorizeIngredient(String ingredient) {
    final lower = ingredient.toLowerCase();

    // Mejeri
    if (RegExp(r'(mjölk|grädde|yoghurt|fil|ost|smör|ägg)').hasMatch(lower)) {
      return 'Mejeri';
    }

    // Kött & Fisk
    if (RegExp(
      r'(kött|fläsk|nöt|kyckling|fisk|lax|torsk|räkor|bacon|korv|skinka)',
    ).hasMatch(lower)) {
      return 'Kött & Fisk';
    }

    // Frukt & Grönt
    if (RegExp(
      r'(tomat|gurka|sallad|paprika|lök|vitlök|potatis|morot|broccoli|äpple|banan|citron|lime)',
    ).hasMatch(lower)) {
      return 'Frukt & Grönt';
    }

    // Skafferi
    if (RegExp(
      r'(mjöl|socker|salt|peppar|olja|pasta|ris|buljong|krydd)',
    ).hasMatch(lower)) {
      return 'Skafferi';
    }

    // Bröd
    if (RegExp(r'(bröd|toast|knäcke)').hasMatch(lower)) {
      return 'Bröd';
    }

    // Frys
    if (RegExp(r'(fryst|frys)').hasMatch(lower)) {
      return 'Frys';
    }

    // Konserver
    if (RegExp(
      r'(krossade tomater|tomat på burk|bönor|burk)',
    ).hasMatch(lower)) {
      return 'Konserver';
    }

    return 'Övrigt';
  }

  /// Gruppera inköpslista efter kategori
  Map<String, List<ShoppingItem>> groupByCategory(List<ShoppingItem> items) {
    final Map<String, List<ShoppingItem>> grouped = {};

    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return grouped;
  }

  /// Markera artikel som köpt/oköpt
  List<ShoppingItem> toggleBought(List<ShoppingItem> items, int index) {
    if (index < 0 || index >= items.length) return items;

    final updatedItems = List<ShoppingItem>.from(items);
    final item = updatedItems[index];

    updatedItems[index] = ShoppingItem(
      name: item.name,
      amount: item.amount,
      unit: item.unit,
      category: item.category,
      bought: !item.bought,
    );

    return updatedItems;
  }

  /// Få antal köpta artiklar
  int getBoughtCount(List<ShoppingItem> items) {
    return items.where((item) => item.bought).length;
  }

  /// Rensa alla köpta markeringar
  List<ShoppingItem> clearAllBought(List<ShoppingItem> items) {
    return items
        .map(
          (item) => ShoppingItem(
            name: item.name,
            amount: item.amount,
            unit: item.unit,
            category: item.category,
            bought: false,
          ),
        )
        .toList();
  }
}
