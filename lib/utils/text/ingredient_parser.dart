// lib/utils/text/ingredient_parser.dart

import 'package:butlery/utils/text/text_formatting.dart';
import 'package:butlery/utils/text/unit_converter.dart';
import 'package:butlery/utils/text/swedish_pluralization.dart';

/// IngredientParser - Ingredient parsing utilities
///
/// Handles parsing of Swedish ingredient format with unit conversion.
class IngredientParser {
  // Regex som hanterar svenska bråk och decimalformat
  static final RegExp quantityRegex = RegExp(
    r'^(\d+(?:[,\.]\d+)?|½|¼|¾|\d+\s*½|\d+\s*¼|\d+\s*¾)([A-Za-zÅÄÖåäö]+)?\s*(.+)$',
  );

  // Utökad enhetslista med amerikanska enheter
  static final Set<String> standaloneUnits = {
    // Svenska enheter
    'g', 'kg', 'hg', 'dag', 'mg',
    'dl', 'l', 'ml', 'cl',
    'msk', 'tsk', 'krm',
    'burk', 'pkt', 'förpackning', 'påse', 'ask', 'flaska',
    'st', 'bit', 'skiva', 'skvätt', 'nypa', 'klyfta', 'sked',
    'glas', 'kopp', 'mugg', 'port', 'portioner', 'pers', 'personer',
    'knippe',
    'bunch',
    'blad',
    'kvist',
    'tube',
    'tub',
    'kasse',
    'låda',
    'burkar',
    'paket',

    // Amerikanska enheter
    'cup', 'cups', 'oz', 'fl oz', 'floz', 'tbsp', 'tsp',
    'lb', 'lbs', 'pound', 'pounds', 'ounce', 'ounces',
    'pint', 'pints', 'quart', 'quarts', 'gallon', 'gallons',
    'tablespoon', 'tablespoons', 'teaspoon', 'teaspoons',
  };

  static double parseQuantity(String qtyString) {
    final trimmed = qtyString.trim();

    // Hantera svenska bråk
    if (trimmed == '½') return 0.5;
    if (trimmed == '¼') return 0.25;
    if (trimmed == '¾') return 0.75;

    // Hantera "2 ½" format
    if (trimmed.contains('½')) {
      final parts = trimmed.split('½');
      if (parts.length == 2) {
        final whole =
            double.tryParse(parts[0].trim().replaceAll(',', '.')) ?? 0;
        return whole + 0.5;
      }
    }

    // Hantera "2 ¼" format
    if (trimmed.contains('¼')) {
      final parts = trimmed.split('¼');
      if (parts.length == 2) {
        final whole =
            double.tryParse(parts[0].trim().replaceAll(',', '.')) ?? 0;
        return whole + 0.25;
      }
    }

    // Hantera "2 ¾" format
    if (trimmed.contains('¾')) {
      final parts = trimmed.split('¾');
      if (parts.length == 2) {
        final whole =
            double.tryParse(parts[0].trim().replaceAll(',', '.')) ?? 0;
        return whole + 0.75;
      }
    }

    // Standardparsing med komma -> punkt för Dart
    final normalized = trimmed.replaceAll(',', '.');
    return double.tryParse(normalized) ?? 1.0;
  }

  static ParsedIngredient parseIngredient(String rawIngredient) {
    final ingredient = rawIngredient.trim();

    if (ingredient.isEmpty) {
      return ParsedIngredient(quantity: 1.0, unit: '', name: ingredient);
    }

    // FÖRBÄTTRAD: Försök hitta enheter direkt först
    final words = ingredient.toLowerCase().split(RegExp(r'\s+'));

    for (int i = 0; i < words.length; i++) {
      if (standaloneUnits.contains(words[i])) {
        // Hitta quantity före enheten
        final beforeUnit = words.take(i);
        final afterUnit = words.skip(i + 1);

        double quantity = 1.0;
        if (beforeUnit.isNotEmpty) {
          final qtyStr = beforeUnit.join(' ');
          quantity = parseQuantity(qtyStr);
        }

        final result = ParsedIngredient(
          quantity: quantity,
          unit: words[i],
          name: afterUnit.join(' '),
        );
        return result;
      }
    }

    // Fallback till original regex parsing
    final match = quantityRegex.firstMatch(ingredient);

    if (match != null) {
      final qtyString = match.group(1)!;
      final attachedUnit = match.group(2);
      final rest = match.group(3)!.trim();

      final quantity = parseQuantity(qtyString);

      if (attachedUnit != null && attachedUnit.isNotEmpty) {
        // Enhet fäst på siffran (t.ex. "400g")
        return ParsedIngredient(
          quantity: quantity,
          unit: attachedUnit.toLowerCase(),
          name: rest,
        );
      } else {
        // Kolla om enheten är fristående
        final tokens = rest.split(RegExp(r'\s+'));
        if (tokens.isNotEmpty &&
            standaloneUnits.contains(tokens[0].toLowerCase())) {
          final unitName = rest.substring(tokens[0].length).trim();
          return ParsedIngredient(
            quantity: quantity,
            unit: tokens[0].toLowerCase(),
            name: unitName,
          );
        } else {
          return ParsedIngredient(quantity: quantity, unit: '', name: rest);
        }
      }
    }

    // Ingen kvantitet hittad - kolla om det börjar med enhet
    final tokens = ingredient.split(RegExp(r'\s+'));
    if (tokens.isNotEmpty &&
        standaloneUnits.contains(tokens[0].toLowerCase())) {
      return ParsedIngredient(
        quantity: 1.0,
        unit: tokens[0].toLowerCase(),
        name: ingredient.substring(tokens[0].length).trim(),
      );
    }

    return ParsedIngredient(quantity: 1.0, unit: '', name: ingredient);
  }

  /// Skala och formatera ingrediens med smart enhetskonvertering
  static String scaleAndFormatIngredient(
    String rawIngredient,
    double scaleFactor,
  ) {
    if (rawIngredient.trim().isEmpty || scaleFactor <= 0) {
      return rawIngredient;
    }

    final parsed = parseIngredient(rawIngredient);

    // Om ingen kvantitet hittades, returnera oförändrad
    if (parsed.quantity == 1.0 &&
        parsed.unit.isEmpty &&
        parsed.name == rawIngredient) {
      return rawIngredient;
    }

    // Skala kvantiteten
    final scaledQuantity = parsed.quantity * scaleFactor;

    // Försök smart enhetskonvertering
    String finalUnit = parsed.unit;
    double finalQuantity = scaledQuantity;

    if (parsed.unit.isNotEmpty &&
        SmartUnitConverter.shouldConvert(scaledQuantity, parsed.unit)) {
      final converted = SmartUnitConverter.convertToReadableUnit(
        scaledQuantity,
        parsed.unit,
      );
      finalQuantity = converted.quantity;
      finalUnit = converted.unit;
    }

    // Formatera med svenska bråk och enheter
    final formattedQuantity = TextFormatting.toSwedishHalfFraction(finalQuantity);

    // Bygg ihop igen
    if (finalUnit.isNotEmpty) {
      return '$formattedQuantity $finalUnit ${parsed.name}';
    } else {
      // Använd pluralisering för ingredienser utan enhet
      return SwedishPluralization.formatIngredient(parsed.name, scaledQuantity);
    }
  }
}

class ParsedIngredient {
  final double quantity;
  final String unit;
  final String name;

  ParsedIngredient({
    required this.quantity,
    required this.unit,
    required this.name,
  });

  String get key => unit.isEmpty ? name : '$unit $name';
}