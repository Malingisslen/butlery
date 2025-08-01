// lib/widgets/common/input/portion_scaler_logic.dart

import 'package:butlery/utils/text/text_formatting.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';
import 'package:butlery/utils/text/unit_converter.dart';
import 'package:butlery/utils/text/swedish_pluralization.dart';

/// Contains the business logic for portion scaling and unit conversion
class PortionScalerLogic {
  static const Set<String> _americanUnits = {
    'cup',
    'cups',
    'oz',
    'fl oz',
    'floz',
    'tbsp',
    'tsp',
    'lb',
    'lbs',
    'pound',
    'pounds',
    'ounce',
    'ounces',
    'pint',
    'pints',
    'quart',
    'quarts',
    'gallon',
    'gallons',
    'tablespoon',
    'tablespoons',
    'teaspoon',
    'teaspoons',
  };

  /// Detects if any ingredient contains American units
  static bool detectAmericanUnits(List<String> ingredients) {
    for (final ingredient in ingredients) {
      final parsed = IngredientParser.parseIngredient(ingredient);

      if (_americanUnits.contains(parsed.unit.toLowerCase())) {
        return true;
      }

      // Fallback: simple string check
      final lowerIngredient = ingredient.toLowerCase();
      for (final unit in _americanUnits) {
        if (lowerIngredient.contains(' $unit ') ||
            lowerIngredient.startsWith('$unit ') ||
            lowerIngredient.endsWith(' $unit')) {
          return true;
        }
      }
    }
    return false;
  }

  /// Scales ingredients from original portions to new portions
  static List<String> scaleIngredients(
    List<String> originalIngredients,
    int originalPortions,
    int newPortions,
    bool convertToSwedish,
  ) {
    if (originalPortions == 0 || newPortions == originalPortions) {
      // Even if portions are same, run conversion if convertToSwedish is true
      if (convertToSwedish) {
        final scaledList = <String>[];
        for (final ingredient in originalIngredients) {
          final converted = _scaleIndividualIngredient(
            ingredient,
            1.0,
            convertToSwedish,
          ); // Scale factor 1.0
          scaledList.add(converted);
        }
        return scaledList;
      }

      return List.from(originalIngredients);
    }

    final scaleFactor = newPortions.toDouble() / originalPortions.toDouble();
    final scaledList = <String>[];

    for (final ingredient in originalIngredients) {
      final scaled = _scaleIndividualIngredient(
        ingredient,
        scaleFactor,
        convertToSwedish,
      );
      scaledList.add(scaled);
    }

    return scaledList;
  }

  /// Scales a single ingredient by the given scale factor
  static String _scaleIndividualIngredient(
    String ingredient,
    double scaleFactor,
    bool convertToSwedish,
  ) {
    if (ingredient.trim().isEmpty) return ingredient;

    final parsed = IngredientParser.parseIngredient(ingredient);

    // If no quantity found, return unchanged
    if (parsed.quantity == 1.0 &&
        parsed.unit.isEmpty &&
        parsed.name == ingredient) {
      return ingredient;
    }

    // Scale the quantity
    final scaledQuantity = parsed.quantity * scaleFactor;

    // Unit conversion
    String finalUnit = parsed.unit;
    double finalQuantity = scaledQuantity;

    // American → Swedish conversion (if enabled)
    if (convertToSwedish && parsed.unit.isNotEmpty) {
      if (_americanUnits.contains(parsed.unit.toLowerCase())) {
        final converted = SmartUnitConverter.convertToReadableUnit(
          scaledQuantity,
          parsed.unit,
        );
        finalQuantity = converted.quantity;
        finalUnit = converted.unit;
      }
    }

    // Normal Swedish unit conversion (always active)
    if (parsed.unit.isNotEmpty &&
        SmartUnitConverter.shouldConvert(finalQuantity, finalUnit)) {
      final converted = SmartUnitConverter.convertToReadableUnit(
        finalQuantity,
        finalUnit,
      );
      finalQuantity = converted.quantity;
      finalUnit = converted.unit;
    }

    // Format with Swedish fractions and units
    final formattedQuantity = TextFormatting.toSwedishHalfFraction(finalQuantity);

    // Build together again
    if (finalUnit.isNotEmpty) {
      return '$formattedQuantity $finalUnit ${parsed.name}';
    } else {
      // Use pluralization for ingredients without unit
      return SwedishPluralization.formatIngredient(parsed.name, scaledQuantity);
    }
  }
}