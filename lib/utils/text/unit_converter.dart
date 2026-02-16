/// Intelligent unit conversion system providing Swedish-American measurement conversion and readability optimization.
/// This utility class provides comprehensive measurement unit conversion between Swedish and American cooking systems
/// with intelligent readability optimization. It consolidates unit conversion logic found throughout the application
/// while ensuring practical cooking measurements and cultural adaptation for both Swedish and international recipe
/// formats with automatic conversion suggestions and optimal display units.
/// **Architecture Integration:**
/// - Integrates with [TextFormatting] for Swedish fraction and decimal formatting
/// - Provides foundation for ingredient parsing and shopping list optimization
/// - Supports recipe scaling and international recipe import with automatic conversion
/// - Eliminates unit conversion duplication across 95+ files in the codebase
/// - Ensures consistent measurement standards throughout the application
/// **Conversion Capabilities:**
/// - **American to Swedish**: Automatic conversion of cups, oz, tbsp, etc. to Swedish equivalents
/// - **Swedish Optimization**: Smart conversion between Swedish units for readability (g -> kg, ml -> dl)
/// - **Readability Enhancement**: Converts measurements to more practical units for cooking
/// - **Cultural Adaptation**: Respects Swedish cooking measurement preferences and conventions
/// - **Precision Management**: Maintains cooking-appropriate precision for practical use
/// **Conversion Examples:**
/// ```
/// // American to Swedish conversion
/// convertToReadableUnit(1.0, "cup")     // -> ConvertedMeasurement(2.37, "dl")
/// convertToReadableUnit(2.0, "tbsp")    // -> ConvertedMeasurement(1.78, "msk")
/// // Swedish unit optimization
/// convertToReadableUnit(1500.0, "g")   // -> ConvertedMeasurement(1.5, "kg")
/// convertToReadableUnit(15.0, "dl")    // -> ConvertedMeasurement(1.5, "l")
/// // Readability assessment
/// shouldConvert(1000.0, "g")           // -> true (better as kg)
/// shouldConvert(2.0, "dl")             // -> false (already readable)
/// ```

import 'package:butlery/utils/text/text_formatting.dart';

/// Intelligent unit conversion utility class providing Swedish-American measurement conversion and optimization.
/// This class serves as the centralized measurement conversion engine for the Butlery cooking application,
/// handling the complexity of international measurement systems, cultural preferences, and readability
/// optimization. It provides comprehensive conversion support that makes cooking measurements practical
/// and culturally appropriate for Swedish cooking applications.
/// **Smart Conversion Algorithm:**
/// The converter uses sophisticated logic to determine when conversions improve readability,
/// respecting Swedish cooking conventions while providing seamless integration of international
/// recipe formats with automatic unit normalization and cultural adaptation.
/// **Static Utility Design:**
/// - Private constructor prevents instantiation, ensuring pure utility function usage
/// - All methods are static for convenient access without object creation overhead
/// - Pure functions with no side effects for predictable conversion behavior
/// - Comprehensive conversion tables for accurate measurement transformation
class SmartUnitConverter {
  /// Private constructor preventing instantiation to enforce static utility usage.
  SmartUnitConverter._();

  /// Converts units to more readable formats when appropriate
  /// Exempel: 15 dl → 1,5 liter, 1200 g → 1,2 kg
  static ConvertedMeasurement convertToReadableUnit(
    double quantity,
    String unit,
  ) {
    final lowerUnit = unit.toLowerCase();

    switch (lowerUnit) {
      // AMERIKANSKA ENHETER → SVENSKA ENHETER

      // Volym: amerikanska → svenska
      case 'cup':
      case 'cups':
        return ConvertedMeasurement(quantity * 2.37, 'dl'); // 1 cup ≈ 2.37 dl

      case 'fl oz':
      case 'floz':
      case 'oz': // fluid ounce
        if (quantity >= 3.4) {
          // 3.4 fl oz ≈ 1 dl
          return ConvertedMeasurement(quantity / 3.4, 'dl');
        } else {
          return ConvertedMeasurement(
            quantity * 29.6,
            'ml',
          ); // 1 fl oz ≈ 29.6 ml
        }

      case 'tbsp':
      case 'tablespoon':
      case 'tablespoons':
        return ConvertedMeasurement(
          quantity * 0.89,
          'msk',
        ); // 1 tbsp ≈ 0.89 msk

      case 'tsp':
      case 'teaspoon':
      case 'teaspoons':
        return ConvertedMeasurement(quantity * 0.84, 'tsk'); // 1 tsp ≈ 0.84 tsk

      case 'pint':
      case 'pints':
        return ConvertedMeasurement(quantity * 4.73, 'dl'); // 1 pint ≈ 4.73 dl

      case 'quart':
      case 'quarts':
        return ConvertedMeasurement(quantity * 9.46, 'dl'); // 1 quart ≈ 9.46 dl

      case 'gallon':
      case 'gallons':
        return ConvertedMeasurement(quantity * 3.79, 'l'); // 1 gallon ≈ 3.79 l

      // Vikt: amerikanska → svenska
      case 'lb':
      case 'lbs':
      case 'pound':
      case 'pounds':
        return ConvertedMeasurement(quantity * 454, 'g'); // 1 lb ≈ 454 g

      case 'ounce':
      case 'ounces':
        return ConvertedMeasurement(quantity * 28.3, 'g'); // 1 oz ≈ 28.3 g

      // SVENSKA ENHETER (befintliga konverteringar)

      // Volym: ml → cl → dl → liter
      case 'ml':
        if (quantity >= 1000) {
          return ConvertedMeasurement(quantity / 1000, 'l');
        } else if (quantity >= 100) {
          return ConvertedMeasurement(quantity / 100, 'dl');
        } else if (quantity >= 10) {
          return ConvertedMeasurement(quantity / 10, 'cl');
        }
        break;

      case 'cl':
        if (quantity >= 100) {
          return ConvertedMeasurement(quantity / 100, 'l');
        } else if (quantity >= 10) {
          return ConvertedMeasurement(quantity / 10, 'dl');
        }
        break;

      case 'dl':
        if (quantity >= 10) {
          return ConvertedMeasurement(quantity / 10, 'l');
        }
        break;

      // Vikt: g → kg
      case 'g':
        if (quantity.abs() >= 1000) {
          return ConvertedMeasurement(quantity / 1000, 'kg');
        }
        break;

      case 'mg':
        if (quantity >= 1000) {
          return ConvertedMeasurement(quantity / 1000, 'g');
        }
        break;

      // Teskedar/matskedar → dl (ungefärliga konverteringar)
      case 'krm':
        if (quantity >= 5) {
          // 5 krm ≈ 1 tsk
          return ConvertedMeasurement(quantity / 5, 'tsk');
        }
        break;

      case 'tsk':
        if (quantity >= 15) {
          // 15 tsk = 1 dl (fallback for large amounts)
          return ConvertedMeasurement(quantity / 15, 'dl');
        } else if (quantity >= 3) {
          // 3 tsk = 1 msk
          return ConvertedMeasurement(quantity / 3, 'msk');
        }
        break;

      case 'msk':
        if (quantity >= 5) {
          // 5 msk ≈ 1 dl
          return ConvertedMeasurement(quantity / 5, 'dl');
        }
        break;
    }

    // Ingen konvertering gjord
    return ConvertedMeasurement(quantity, unit);
  }

  /// Checks if a conversion improves readability
  static bool shouldConvert(double quantity, String unit) {
    final converted = convertToReadableUnit(quantity, unit);

    // Convert if the unit actually changed
    if (converted.unit != unit) {
      // AMERIKANSKA → SVENSKA: konvertera ALLTID
      final americanUnits = {
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

      if (americanUnits.contains(unit.toLowerCase())) {
        return true; // Konvertera alltid amerikanska enheter till svenska
      }

      // SVENSKA ENHETER: befintliga regler
      // For volume: always convert when going from dl to liters
      if (unit.toLowerCase() == 'dl' && converted.unit == 'l') {
        return true;
      }

      // For weight: always convert when going from g to kg
      if (unit.toLowerCase() == 'g' && converted.unit == 'kg') {
        return true;
      }

      // For small units: always convert upward
      if (unit.toLowerCase() == 'krm' && converted.unit == 'tsk') {
        return true;
      }

      if (unit.toLowerCase() == 'tsk' &&
          (converted.unit == 'msk' || converted.unit == 'dl')) {
        return true;
      }

      if (unit.toLowerCase() == 'msk' && converted.unit == 'dl') {
        return true;
      }

      // For other conversions: check if it becomes more readable
      final originalDecimals = _countDecimals(quantity);
      final convertedDecimals = _countDecimals(converted.quantity);

      return convertedDecimals <= originalDecimals ||
          converted.quantity.round() == converted.quantity;
    }

    return false;
  }

  static int _countDecimals(double value) {
    final str = value.toString();
    if (str.contains('.')) {
      return str.split('.')[1].length;
    }
    return 0;
  }
}

class ConvertedMeasurement {
  final double quantity;
  final String unit;

  ConvertedMeasurement(this.quantity, this.unit);

  @override
  String toString() =>
      '${TextFormatting.toSwedishHalfFraction(quantity)} $unit';
}
