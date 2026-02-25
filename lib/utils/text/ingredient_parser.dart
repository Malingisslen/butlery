/// Swedish ingredient parsing system with comprehensive format support.
/// Supports traditional Swedish measurements, ASCII/Unicode fractions, compound ingredients, and scaling.

import 'package:butlery/utils/text/text_formatting.dart';
import 'package:butlery/utils/text/unit_converter.dart';
import 'package:butlery/utils/text/swedish_pluralization.dart';
import 'package:butlery/utils/text/unit_definitions.dart';
import 'package:butlery/utils/text/quantity_parser.dart';

/// Central ingredient parsing engine for Swedish cooking formats.
class IngredientParser {
  IngredientParser._();

  /// Regex for Swedish fraction and decimal format parsing.
  static final RegExp quantityRegex = RegExp(
    r'^(\d+(?:[,\.]\d+)?|[½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗]|\d+\s*[½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗])([A-Za-zÅÄÖåäö]+)?\s*(.+)$',
  );

  /// Comprehensive measurement unit set (delegates to UnitDefinitions).
  static Set<String> get standaloneUnits => UnitDefinitions.standaloneUnits;

  /// Normalizes whitespace and separates attached units.
  static String _normalizeWhitespace(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ').replaceAllMapped(
          RegExp(r'(\d)([a-zåäöA-ZÅÄÖ])'),
          (m) => '${m[1]} ${m[2]}',
        );
  }

  /// Parses Swedish quantity strings (delegates to QuantityParser).
  static double parseQuantity(String qtyString) =>
      QuantityParser.parse(qtyString);

  /// Parses an ingredient string into structured components.
  static ParsedIngredient parseIngredient(String rawIngredient) {
    if (rawIngredient.isEmpty) {
      return const ParsedIngredient(quantity: 1.0, unit: '', name: '');
    }

    final ingredient = _normalizeWhitespace(rawIngredient);
    if (ingredient.isEmpty) {
      return const ParsedIngredient(quantity: 1.0, unit: '', name: '');
    }

    final words = ingredient.split(RegExp(r'\s+'));

    // Step 1: Try ASCII fractions first
    if (words.length >= 3) {
      final possibleMixed = '${words[0]} ${words[1]}';
      final asciiQty = QuantityParser.parseAsciiFraction(possibleMixed);

      if (asciiQty != null) {
        final remainingWords = words.skip(2).toList();
        if (remainingWords.isNotEmpty &&
            UnitDefinitions.isKnownUnit(remainingWords[0])) {
          return ParsedIngredient(
            quantity: asciiQty,
            unit: remainingWords[0].toLowerCase(),
            name: remainingWords.skip(1).join(' ').toLowerCase(),
          );
        } else {
          return ParsedIngredient(
            quantity: asciiQty,
            unit: '',
            name: remainingWords.join(' ').toLowerCase(),
          );
        }
      }
    }

    if (words.isNotEmpty) {
      final asciiQty = QuantityParser.parseAsciiFraction(words[0]);
      if (asciiQty != null) {
        final remainingWords = words.skip(1).toList();
        if (remainingWords.isNotEmpty &&
            UnitDefinitions.isKnownUnit(remainingWords[0])) {
          return ParsedIngredient(
            quantity: asciiQty,
            unit: remainingWords[0].toLowerCase(),
            name: remainingWords.skip(1).join(' ').toLowerCase(),
          );
        } else {
          return ParsedIngredient(
            quantity: asciiQty,
            unit: '',
            name: remainingWords.join(' ').toLowerCase(),
          );
        }
      }
    }

    // Step 2: Unit-first detection
    final lowerWords = ingredient.toLowerCase().split(RegExp(r'\s+'));
    for (int i = 0; i < lowerWords.length; i++) {
      if (UnitDefinitions.isKnownUnit(lowerWords[i])) {
        final beforeUnit = words.take(i);
        final afterUnit = words.skip(i + 1);

        double quantity = 1.0;
        if (beforeUnit.isNotEmpty) {
          quantity = parseQuantity(beforeUnit.join(' '));
        }

        return ParsedIngredient(
          quantity: quantity,
          unit: lowerWords[i],
          name: afterUnit.join(' ').toLowerCase(),
        );
      }
    }

    // Step 3: Regex fallback for attached units
    final match = quantityRegex.firstMatch(ingredient);
    if (match != null) {
      final qtyString = match.group(1)!;
      final attachedUnit = match.group(2);
      final rest = match.group(3)!.trim();
      final quantity = parseQuantity(qtyString);

      if (attachedUnit != null && attachedUnit.isNotEmpty) {
        return ParsedIngredient(
          quantity: quantity,
          unit: attachedUnit.toLowerCase(),
          name: rest.toLowerCase(),
        );
      } else {
        final tokens = rest.split(RegExp(r'\s+'));
        if (tokens.isNotEmpty && UnitDefinitions.isKnownUnit(tokens[0])) {
          final unitName = rest.substring(tokens[0].length).trim();
          return ParsedIngredient(
            quantity: quantity,
            unit: tokens[0].toLowerCase(),
            name: unitName.toLowerCase(),
          );
        } else {
          return ParsedIngredient(
              quantity: quantity, unit: '', name: rest.toLowerCase());
        }
      }
    }

    // Step 4: Check if ingredient starts with a unit
    final tokens = ingredient.split(RegExp(r'\s+'));
    if (tokens.isNotEmpty && UnitDefinitions.isKnownUnit(tokens[0])) {
      return ParsedIngredient(
        quantity: 1.0,
        unit: tokens[0].toLowerCase(),
        name: ingredient.substring(tokens[0].length).trim().toLowerCase(),
      );
    }

    return ParsedIngredient(
        quantity: 1.0, unit: '', name: ingredient.toLowerCase());
  }

  /// Parses compound ingredients containing "och" (and) into separate items.
  static List<ParsedIngredient> parseCompoundIngredient(String rawIngredient) {
    if (rawIngredient.isEmpty) {
      return const [ParsedIngredient(quantity: 1.0, unit: '', name: '')];
    }

    final normalized = _normalizeWhitespace(rawIngredient);
    if (normalized.isEmpty) {
      return const [ParsedIngredient(quantity: 1.0, unit: '', name: '')];
    }

    final ingredient = normalized.toLowerCase();
    if (!ingredient.contains(' och ')) {
      return [parseIngredient(rawIngredient)];
    }

    final parts = ingredient.split(RegExp(r'\s+och\s+'));
    final first = parseIngredient(parts[0]);
    final results = <ParsedIngredient>[first];

    for (int i = 1; i < parts.length; i++) {
      final part = parts[i].trim();
      final parsed = parseIngredient(part);

      // CRIT-11: Inherit quantity OR unit from first if this part has defaults
      // "2 dl mjölk och grädde" -> inherit both quantity and unit for "grädde"
      // "2 dl mjölk och 3 grädde" -> inherit just unit, keep quantity 3
      // "2 ägg och smör" -> inherit quantity for "smör"
      // Only inherit quantity if the part didn't start with an explicit number
      final hasExplicitQuantity = RegExp(r'^\d|^[½¼¾⅓⅔⅛⅜⅝⅞]').hasMatch(part);
      final inheritQuantity = !hasExplicitQuantity && parsed.quantity == 1.0;
      final inheritUnit = parsed.unit.isEmpty && first.unit.isNotEmpty;

      if (inheritQuantity || inheritUnit) {
        results.add(ParsedIngredient(
          quantity: inheritQuantity ? first.quantity : parsed.quantity,
          unit: inheritUnit ? first.unit : parsed.unit,
          name: parsed.name,
        ));
      } else {
        results.add(parsed);
      }
    }

    return results;
  }

  /// Scales and formats an ingredient with smart unit conversion.
  static String scaleAndFormatIngredient(
      String rawIngredient, double scaleFactor) {
    if (rawIngredient.trim().isEmpty || scaleFactor <= 0) {
      return rawIngredient;
    }

    final parsed = parseIngredient(rawIngredient);

    // Guard: if parsing returned the raw input as-is, don't scale
    // Compare lowercase since parseIngredient lowercases the name
    if (parsed.quantity == 1.0 &&
        parsed.unit.isEmpty &&
        parsed.name == rawIngredient.toLowerCase()) {
      return rawIngredient;
    }

    final scaledQuantity = parsed.quantity * scaleFactor;
    String finalUnit = parsed.unit;
    double finalQuantity = scaledQuantity;

    if (parsed.unit.isNotEmpty &&
        SmartUnitConverter.shouldConvert(scaledQuantity, parsed.unit)) {
      final converted =
          SmartUnitConverter.convertToReadableUnit(scaledQuantity, parsed.unit);
      finalQuantity = converted.quantity;
      finalUnit = converted.unit;
    }

    final formattedQuantity =
        TextFormatting.toSwedishHalfFraction(finalQuantity);

    if (finalUnit.isNotEmpty) {
      return '$formattedQuantity $finalUnit ${parsed.name}';
    } else {
      return SwedishPluralization.formatIngredient(parsed.name, scaledQuantity);
    }
  }
}

/// Structured representation of a parsed ingredient.
class ParsedIngredient {
  final double quantity;
  final String unit;
  final String name;

  const ParsedIngredient({
    required this.quantity,
    required this.unit,
    required this.name,
  });

  /// Generates a grouping key for ingredient consolidation.
  String get key => unit.isEmpty ? name : '$unit $name';

  @override
  String toString() {
    if (unit.isEmpty) return '$quantity $name';
    return '$quantity $unit $name';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParsedIngredient &&
        other.quantity == quantity &&
        other.unit == unit &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(quantity, unit, name);
}
