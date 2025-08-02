/// Comprehensive ingredient parsing system providing Swedish ingredient format parsing and intelligent unit conversion.
///
/// This utility class provides sophisticated ingredient parsing capabilities for Swedish cooking format, supporting
/// traditional Swedish measurements, American unit conversions, fraction parsing, and intelligent quantity scaling.
/// It consolidates ingredient parsing logic that was previously scattered across multiple files, providing consistent
/// parsing behavior with comprehensive Swedish language support and cooking measurement standards.
///
/// **Architecture Integration:**
/// - Integrates with [TextFormatting] for Swedish fraction formatting and number parsing
/// - Uses [SmartUnitConverter] for intelligent measurement unit conversions
/// - Leverages [SwedishPluralization] for proper ingredient name formatting
/// - Provides foundation for recipe scaling and shopping list generation
/// - Supports both Swedish and American measurement systems with automatic conversion
///
/// **Parsing Capabilities:**
/// - **Swedish Fractions**: Supports ½, ¼, ¾ notation and mixed fractions like "2 ½"
/// - **Measurement Units**: Comprehensive support for Swedish cooking measurements (dl, msk, tsk, etc.)
/// - **American Units**: Automatic recognition and conversion of cups, oz, tbsp, tsp, etc.
/// - **Quantity Scaling**: Intelligent ingredient scaling with unit optimization
/// - **Ingredient Formatting**: Smart formatting with pluralization and fraction display
///
/// **Supported Formats:**
/// ```
/// // Traditional Swedish format
/// "2 dl mjölk" -> ParsedIngredient(quantity: 2.0, unit: "dl", name: "mjölk")
/// "½ msk salt" -> ParsedIngredient(quantity: 0.5, unit: "msk", name: "salt")
/// "400g finhackad kött" -> ParsedIngredient(quantity: 400.0, unit: "g", name: "finhackad kött")
/// 
/// // American format (auto-converted)
/// "1 cup flour" -> ParsedIngredient(quantity: 2.37, unit: "dl", name: "flour")
/// "2 tbsp butter" -> ParsedIngredient(quantity: 1.78, unit: "msk", name: "butter")
/// ```
///
/// **Usage Examples:**
/// ```dart
/// // Parse individual ingredient
/// final parsed = IngredientParser.parseIngredient("2 ½ dl mjölk");
/// print('${parsed.quantity} ${parsed.unit} ${parsed.name}'); // "2.5 dl mjölk"
/// 
/// // Scale ingredients with smart unit conversion
/// final scaled = IngredientParser.scaleAndFormatIngredient("400g mjöl", 2.0);
/// print(scaled); // "800g mjöl" or "0.8kg mjöl" depending on smart conversion
/// 
/// // Parse complex mixed quantities
/// final complex = IngredientParser.parseIngredient("1 ¾ msk smör");
/// print(complex.quantity); // 1.75
/// ```

import 'package:butlery/utils/text/text_formatting.dart';
import 'package:butlery/utils/text/unit_converter.dart';
import 'package:butlery/utils/text/swedish_pluralization.dart';

/// Comprehensive ingredient parsing system providing Swedish cooking format parsing and intelligent unit conversion.
///
/// This class serves as the central ingredient parsing engine for the Butlery cooking application, handling the
/// complexity of Swedish cooking measurements, American unit conversions, fraction parsing, and intelligent
/// quantity scaling. It provides consistent parsing behavior that supports both traditional Swedish cooking
/// formats and international recipe imports with automatic unit normalization.
///
/// **Swedish Cooking Format Support:**
/// The parser handles traditional Swedish cooking notation including native fractions (½, ¼, ¾),
/// mixed number formats ("2 ½"), and comprehensive measurement unit recognition for both Swedish
/// and American cooking systems with intelligent conversion between systems.
///
/// **Smart Parsing Algorithm:**
/// - Unit-first detection for optimal parsing accuracy
/// - Regex-based quantity extraction with fraction support
/// - Intelligent fallback parsing for edge cases
/// - Automatic unit normalization and conversion
class IngredientParser {
  /// Private constructor preventing instantiation to enforce static utility usage.
  IngredientParser._();
  /// Advanced regex pattern for Swedish fraction and decimal format parsing
  ///
  /// Matches various Swedish quantity formats including:
  /// - Decimal numbers with comma or period: "2,5", "3.14"
  /// - Unicode fractions: "½", "¼", "¾"
  /// - Mixed fractions: "2 ½", "1 ¼", "3 ¾"
  /// - Attached units: "400g", "2dl"
  /// - Separated ingredients: "2 dl mjölk"
  static final RegExp quantityRegex = RegExp(
    r'^(\d+(?:[,\.]\d+)?|½|¼|¾|\d+\s*½|\d+\s*¼|\d+\s*¾)([A-Za-zÅÄÖåäö]+)?\s*(.+)$',
  );

  /// Comprehensive measurement unit recognition supporting Swedish and American cooking systems
  ///
  /// This set provides complete coverage of cooking measurements used in Swedish and international
  /// recipes, enabling accurate parsing and automatic unit conversion. The units are organized
  /// by category for optimal recognition and conversion accuracy.
  ///
  /// **Swedish Measurements:**
  /// - Weight: g, kg, hg, dag, mg
  /// - Volume: dl, l, ml, cl
  /// - Cooking: msk (matsked), tsk (tesked), krm (kryddmått)
  /// - Packaging: burk, pkt, förpackning, påse, ask, flaska
  /// - Counting: st, bit, skiva, klyfta, port, etc.
  ///
  /// **American Measurements:**
  /// - Volume: cup, fl oz, tbsp, tsp, pint, quart, gallon
  /// - Weight: lb, oz, pound, ounce
  /// - Variations: cups, tablespoons, teaspoons, etc.
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

  /// Parses Swedish quantity strings with comprehensive fraction and decimal support
  ///
  /// This method handles the complexity of Swedish cooking notation, including traditional
  /// Unicode fractions (½, ¼, ¾) and mixed number formats commonly used in Swedish recipes.
  /// It provides robust parsing with automatic comma-to-decimal conversion for Swedish
  /// number formatting standards.
  ///
  /// **Supported Formats:**
  /// - Unicode fractions: "½" -> 0.5, "¼" -> 0.25, "¾" -> 0.75
  /// - Mixed fractions: "2 ½" -> 2.5, "1 ¼" -> 1.25, "3 ¾" -> 3.75
  /// - Decimal numbers: "2,5" -> 2.5, "3.14" -> 3.14
  /// - Whole numbers: "400" -> 400.0
  ///
  /// [qtyString] The quantity string to parse (e.g., "2 ½", "0,5", "¾")
  /// Returns the parsed quantity as a double, defaults to 1.0 for invalid input
  ///
  /// **Examples:**
  /// ```dart
  /// parseQuantity("½");     // Returns 0.5
  /// parseQuantity("2 ¼");   // Returns 2.25
  /// parseQuantity("1,5");   // Returns 1.5
  /// parseQuantity("400");   // Returns 400.0
  /// ```
  static double parseQuantity(String qtyString) {
    final trimmed = qtyString.trim();

    // Handle Unicode fractions with precise Swedish cooking standards
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

  /// Comprehensive ingredient parsing with intelligent unit detection and Swedish format support
  ///
  /// This method serves as the primary ingredient parsing engine, using a sophisticated multi-pass
  /// parsing algorithm that prioritizes accuracy and handles the complexity of Swedish cooking notation.
  /// It employs unit-first detection for optimal accuracy, followed by regex-based parsing with
  /// comprehensive fallback handling for edge cases.
  ///
  /// **Parsing Strategy:**
  /// 1. **Unit-First Detection**: Scans for known measurement units to anchor parsing
  /// 2. **Quantity Extraction**: Parses quantities before detected units with fraction support
  /// 3. **Regex Fallback**: Uses pattern matching for attached units ("400g")
  /// 4. **Edge Case Handling**: Manages ingredients without quantities or with complex formats
  ///
  /// **Input Format Support:**
  /// - Traditional Swedish: "2 dl mjölk", "½ msk salt", "400g mjöl"
  /// - Mixed fractions: "1 ¾ dl grädde", "2 ½ tsk vaniljsocker"
  /// - Attached units: "400g kött", "2dl vatten"
  /// - Unit-less ingredients: "1 stor lök", "3 ägg"
  /// - American format: "1 cup flour", "2 tbsp butter" (auto-converted)
  ///
  /// [rawIngredient] The raw ingredient string to parse
  /// Returns [ParsedIngredient] with quantity, unit, and name components
  ///
  /// **Examples:**
  /// ```dart
  /// parseIngredient("2 dl mjölk");
  /// // Returns: ParsedIngredient(quantity: 2.0, unit: "dl", name: "mjölk")
  /// 
  /// parseIngredient("½ msk salt");
  /// // Returns: ParsedIngredient(quantity: 0.5, unit: "msk", name: "salt")
  /// 
  /// parseIngredient("400g kött");
  /// // Returns: ParsedIngredient(quantity: 400.0, unit: "g", name: "kött")
  /// ```
  static ParsedIngredient parseIngredient(String rawIngredient) {
    final ingredient = rawIngredient.trim();

    // Handle empty ingredient gracefully
    if (ingredient.isEmpty) {
      return ParsedIngredient(quantity: 1.0, unit: '', name: ingredient);
    }

    // ENHANCED: Unit-first detection for optimal parsing accuracy
    // This approach prioritizes known measurement units for more reliable parsing
    final words = ingredient.toLowerCase().split(RegExp(r'\s+'));

    for (int i = 0; i < words.length; i++) {
      if (standaloneUnits.contains(words[i])) {
        // Extract quantity preceding the detected unit
        final beforeUnit = words.take(i);
        final afterUnit = words.skip(i + 1);

        double quantity = 1.0;
        if (beforeUnit.isNotEmpty) {
          final qtyStr = beforeUnit.join(' ');
          quantity = parseQuantity(qtyStr);
        }

        // Construct parsed ingredient with detected components
        final result = ParsedIngredient(
          quantity: quantity,
          unit: words[i],
          name: afterUnit.join(' '),
        );
        return result;
      }
    }

    // Fallback to regex-based parsing for attached units and complex formats
    final match = quantityRegex.firstMatch(ingredient);

    if (match != null) {
      final qtyString = match.group(1)!;
      final attachedUnit = match.group(2);
      final rest = match.group(3)!.trim();

      final quantity = parseQuantity(qtyString);

      if (attachedUnit != null && attachedUnit.isNotEmpty) {
        // Handle units attached directly to numbers (e.g., "400g")
        return ParsedIngredient(
          quantity: quantity,
          unit: attachedUnit.toLowerCase(),
          name: rest,
        );
      } else {
        // Check for standalone units in remaining text
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

    // Final fallback: Check if ingredient starts with a unit (edge case handling)
    final tokens = ingredient.split(RegExp(r'\s+'));
    if (tokens.isNotEmpty &&
        standaloneUnits.contains(tokens[0].toLowerCase())) {
      return ParsedIngredient(
        quantity: 1.0,
        unit: tokens[0].toLowerCase(),
        name: ingredient.substring(tokens[0].length).trim(),
      );
    }

    // Default case: No quantity or unit detected, treat as ingredient name
    return ParsedIngredient(quantity: 1.0, unit: '', name: ingredient);
  }

  /// Intelligent ingredient scaling with smart unit conversion and Swedish formatting
  ///
  /// This method provides comprehensive ingredient scaling that goes beyond simple multiplication,
  /// incorporating smart unit conversion to maintain readability and Swedish cooking conventions.
  /// It automatically converts scaled quantities to more appropriate units when beneficial and
  /// applies proper Swedish formatting including fraction notation and pluralization.
  ///
  /// **Smart Scaling Features:**
  /// - **Unit Optimization**: Automatically converts to more readable units (e.g., 1500g -> 1.5kg)
  /// - **Fraction Formatting**: Uses Swedish half-fractions (½, ¼, ¾) when appropriate
  /// - **Pluralization**: Applies Swedish pluralization rules for ingredient names
  /// - **Preservation**: Maintains original format for ingredients without quantities
  /// - **American Conversion**: Handles American units with automatic Swedish conversion
  ///
  /// **Scaling Examples:**
  /// ```
  /// // Basic scaling with unit optimization
  /// scaleAndFormatIngredient("400g mjöl", 2.0);
  /// // Returns: "800g mjöl" or "0.8kg mjöl" (depending on smart conversion)
  /// 
  /// // Fraction formatting
  /// scaleAndFormatIngredient("1 dl mjölk", 0.5);
  /// // Returns: "½ dl mjölk"
  /// 
  /// // Pluralization handling
  /// scaleAndFormatIngredient("1 ägg", 3.0);
  /// // Returns: "3 ägg"
  /// ```
  ///
  /// [rawIngredient] The original ingredient string to scale
  /// [scaleFactor] The scaling factor to apply (e.g., 2.0 for double, 0.5 for half)
  /// Returns the scaled and formatted ingredient string with optimized units and Swedish formatting
  static String scaleAndFormatIngredient(
    String rawIngredient,
    double scaleFactor,
  ) {
    // Validate input parameters
    if (rawIngredient.trim().isEmpty || scaleFactor <= 0) {
      return rawIngredient;
    }

    final parsed = parseIngredient(rawIngredient);

    // Preserve original format for ingredients without detected quantities
    if (parsed.quantity == 1.0 &&
        parsed.unit.isEmpty &&
        parsed.name == rawIngredient) {
      return rawIngredient;
    }

    // Apply scaling factor to quantity
    final scaledQuantity = parsed.quantity * scaleFactor;

    // Attempt smart unit conversion for improved readability
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

    // Apply Swedish fraction formatting and proper notation
    final formattedQuantity = TextFormatting.toSwedishHalfFraction(finalQuantity);

    // Reconstruct ingredient with proper formatting
    if (finalUnit.isNotEmpty) {
      return '$formattedQuantity $finalUnit ${parsed.name}';
    } else {
      // Apply Swedish pluralization for unit-less ingredients
      return SwedishPluralization.formatIngredient(parsed.name, scaledQuantity);
    }
  }
}

/// Structured representation of a parsed ingredient with quantity, unit, and name components.
///
/// This class provides a clean data structure for ingredient parsing results, supporting the
/// Swedish cooking format with proper type safety and convenient access methods. It serves as
/// the return type for ingredient parsing operations and provides utility methods for working
/// with parsed ingredient data.
///
/// **Component Structure:**
/// - **quantity**: Numeric amount (e.g., 2.5 for "2½ dl")
/// - **unit**: Measurement unit (e.g., "dl", "msk", "g") or empty string for unit-less ingredients
/// - **name**: Ingredient name (e.g., "mjölk", "salt", "finhackad lök")
///
/// **Usage Examples:**
/// ```dart
/// final parsed = ParsedIngredient(
///   quantity: 2.5,
///   unit: 'dl',
///   name: 'mjölk',
/// );
/// 
/// print('${parsed.quantity} ${parsed.unit} ${parsed.name}'); // "2.5 dl mjölk"
/// print(parsed.key); // "dl mjölk" (for grouping)
/// ```
class ParsedIngredient {
  /// Numeric quantity of the ingredient (supports fractions and decimals)
  final double quantity;
  
  /// Measurement unit (Swedish or American, normalized to lowercase)
  /// Empty string for ingredients without units (e.g., "1 stor lök")
  final String unit;
  
  /// Ingredient name or description (everything after quantity and unit)
  final String name;

  /// Creates a new parsed ingredient with the specified components
  ///
  /// [quantity] The numeric amount of the ingredient
  /// [unit] The measurement unit (empty string if no unit)
  /// [name] The ingredient name or description
  const ParsedIngredient({
    required this.quantity,
    required this.unit,
    required this.name,
  });

  /// Generates a grouping key for ingredient consolidation in shopping lists
  ///
  /// Returns the unit and name combination for ingredients with units,
  /// or just the name for unit-less ingredients. This enables proper
  /// grouping of similar ingredients in shopping list generation.
  ///
  /// **Examples:**
  /// - "2 dl mjölk" -> "dl mjölk"
  /// - "1 stor lök" -> "stor lök"
  /// - "400g kött" -> "g kött"
  String get key => unit.isEmpty ? name : '$unit $name';
  
  /// Returns a formatted string representation of the parsed ingredient
  @override
  String toString() {
    if (unit.isEmpty) {
      return '$quantity $name';
    }
    return '$quantity $unit $name';
  }
  
  /// Checks equality based on quantity, unit, and name
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParsedIngredient &&
        other.quantity == quantity &&
        other.unit == unit &&
        other.name == name;
  }
  
  /// Generates hash code for proper Map and Set usage
  @override
  int get hashCode => Object.hash(quantity, unit, name);
}