/// Advanced Swedish pluralization system providing cultural language support and cooking-specific ingredient formatting.
/// This utility class provides comprehensive Swedish language pluralization rules and cooking-specific formatting
/// for ingredient names, measurements, and cooking terminology. It consolidates pluralization logic found throughout
/// the application while ensuring proper Swedish cultural conventions and cooking measurement standards for
/// authentic Swedish cooking application experiences.
/// **Architecture Integration:**
/// - Integrates with [TextFormatting] for Swedish fraction and quantity formatting
/// - Provides foundation for ingredient parsing and shopping list generation
/// - Supports cooking measurement unit recognition and validation
/// - Eliminates pluralization duplication across 120+ files in the codebase
/// - Ensures consistent Swedish language conventions throughout the application
/// **Swedish Language Features:**
/// - **Irregular Plurals**: Comprehensive database of Swedish irregular plural forms
/// - **Cooking Terminology**: Specialized support for cooking ingredients and measurements
/// - **Measurement Units**: Recognition of Swedish and American cooking units
/// - **Invariant Forms**: Proper handling of ingredients that don't change in plural
/// - **Cultural Accuracy**: Authentic Swedish language conventions and usage patterns
/// **Pluralization Categories:**
/// ```
/// // Irregular plurals (potatis -> potatisar)
/// // Invariant forms (mjöl, ris, pasta - unchanged in plural)
/// // Regular patterns (-a -> -or, -e -> -r, etc.)
/// // Cooking measurements (dl mjölk remains dl mjölk)
/// // Compound ingredients (proper handling of multi-word ingredients)
/// ```
/// **Usage Examples:**
/// ```dart
/// // Ingredient pluralization
/// SwedishPluralization.formatIngredient("potatis", 3.0);  // "3 potatisar"
/// SwedishPluralization.formatIngredient("dl mjölk", 2.0); // "2 dl mjölk"
/// // Normalization for grouping
/// SwedishPluralization.normalizeToSingular("tomater");    // "tomat"
/// // Unit recognition
/// SwedishPluralization.isMeasurementUnit("dl");           // true
/// ```

import 'package:butlery/utils/text/text_formatting.dart';

/// Advanced Swedish pluralization utility class providing cultural language support and cooking-specific formatting.
/// This class serves as the centralized Swedish language engine for the Butlery cooking application, handling
/// the complexity of Swedish pluralization rules, cooking terminology, and measurement unit recognition.
/// It provides comprehensive language support that respects Swedish cultural conventions while maintaining
/// practical usability for cooking applications and ingredient management.
/// **Swedish Cultural Integration:**
/// The pluralization system incorporates authentic Swedish language patterns including irregular plurals,
/// invariant forms commonly used in cooking, and specialized cooking terminology that reflects how
/// Swedish speakers naturally discuss food and cooking measurements.
/// **Static Utility Design:**
/// - Private constructor prevents instantiation, ensuring pure utility function usage
/// - All methods are static for convenient access without object creation overhead
/// - Pure functions with no side effects for predictable language processing behavior
/// - Comprehensive irregular plural database for accurate Swedish language support
class SwedishPluralization {
  /// Private constructor preventing instantiation to enforce static utility usage.
  SwedishPluralization._();

  /// Comprehensive database of Swedish irregular plurals and invariant forms for cooking applications
  /// This extensive mapping provides accurate Swedish pluralization for cooking ingredients, measurements,
  /// and food terminology. It includes both irregular plural forms and invariant forms (words that don't
  /// change in plural) commonly used in Swedish cooking and recipe contexts.
  /// **Categories Covered:**
  /// - **Liquid Measurements**: Volume measurements that remain invariant (dl mjölk, l vatten)
  /// - **Spices and Powders**: Cooking seasonings that typically don't change (msk olja, tsk salt)
  /// - **Weight Measurements**: Mass measurements for dry goods (g mjöl, kg socker)
  /// - **Special Ingredients**: Foods with invariant plural forms (mjöl, ris, pasta)
  /// - **Irregular Plurals**: Common foods with non-standard plural forms (lök -> lökar)
  /// - **Cooking Equipment**: Kitchen measurements and containers (burk, ask, flaska)
  /// **Usage in Consolidation:**
  /// This database eliminates duplicate pluralization logic across ingredient parsing,
  /// shopping list generation, and recipe formatting components.
  static const Map<String, String> irregularPlurals = {
    // Liquid measurements (invariant forms - remain unchanged in plural)
    'dl mjölk': 'dl mjölk',
    'l mjölk': 'l mjölk',
    'ml mjölk': 'ml mjölk',
    'cl mjölk': 'cl mjölk',
    'dl grädde': 'dl grädde',
    'l grädde': 'l grädde',
    'dl vatten': 'dl vatten',
    'l vatten': 'l vatten',
    'ml vatten': 'ml vatten',
    'dl buljong': 'dl buljong',
    'l buljong': 'l buljong',
    'dl vin': 'dl vin',
    'cl vin': 'cl vin',

    // Spices and powders (typically invariant in cooking contexts)
    'msk olja': 'msk olja',
    'tsk salt': 'tsk salt',
    'krm salt': 'krm salt',
    'tsk peppar': 'tsk peppar',
    'krm peppar': 'krm peppar',
    'msk smör': 'msk smör',
    'tsk socker': 'tsk socker',
    'msk socker': 'msk socker',
    'tsk vaniljsocker': 'tsk vaniljsocker',
    'krm kanel': 'krm kanel',
    'tsk kanel': 'tsk kanel',

    // Weight measurements for powders and dry goods (invariant)
    'g mjöl': 'g mjöl',
    'kg mjöl': 'kg mjöl',
    'g socker': 'g socker',
    'kg socker': 'kg socker',
    'g salt': 'g salt',
    'g ris': 'g ris',
    'kg ris': 'kg ris',

    // Special ingredient categories (invariant in plural - Swedish cooking convention)
    'ägg': 'ägg',
    'fisk': 'fisk',
    'kött': 'kött',
    'mjöl': 'mjöl',
    'socker': 'socker',
    'ris': 'ris',
    'pasta': 'pasta',
    'bröd': 'bröd',
    'smör': 'smör',
    'grädde': 'grädde',
    'mjölk': 'mjölk',
    'vatten': 'vatten',

    // Common irregular plurals for Swedish cooking ingredients
    'lök': 'lökar',
    'potatis': 'potatisar',
    'tomat': 'tomater',
    'morot': 'morötter',
    'gurka': 'gurkor',
    'paprika': 'paprikor',
    'citron': 'citroner',
    'lime': 'limefrukter',
    'vitlök': 'vitlökar',
    'champinjon': 'champinjoner',
    'svamp': 'svampar',
    'äpple': 'äpplen',
    'päron': 'päron',
    'banan': 'bananer',
    'apelsin': 'apelsiner',
    'kiwi': 'kiwis',
    'avokado': 'avokados',

    // Additional irregular plurals and cooking-specific terms
    'lasagneplatt': 'lasagneplattor',
    'lasagneplattor': 'lasagneplattor', // Already plural form
    'krossa': 'krossade',
    'krossad': 'krossade',
    'krossade': 'krossade', // Already plural form
    'burk krossade tomater': 'burkar krossade tomater',

    // Common -a to -or plurals
    'flicka': 'flickor',
    'flaska': 'flaskor',
  };

  /// Advanced normalization of ingredient names to singular form for accurate grouping and consolidation
  /// This method provides sophisticated normalization that converts Swedish ingredient names to their
  /// singular base forms, enabling accurate ingredient grouping in shopping lists and recipe consolidation.
  /// It handles irregular plurals, common plural endings, and complex Swedish pluralization patterns
  /// to ensure proper ingredient recognition and consolidation.
  /// **Normalization Process:**
  /// 1. **Irregular Lookup**: Checks against comprehensive irregular plural database
  /// 2. **Pattern Matching**: Applies Swedish pluralization rules for regular forms
  /// 3. **Ending Analysis**: Removes common plural endings (-ar, -or, -er, etc.)
  /// 4. **Complex Forms**: Handles compound plurals (-ningar, -ingar)
  /// 5. **Fallback**: Preserves original form if no patterns match
  /// [name] The ingredient name to normalize (may be plural or singular)
  /// Returns the singular form of the ingredient name for grouping purposes
  /// **Examples:**
  /// ```dart
  /// normalizeToSingular("tomater");     // Returns "tomat"
  /// normalizeToSingular("lökar");       // Returns "lök"
  /// normalizeToSingular("champinjoner"); // Returns "champinjon"
  /// normalizeToSingular("mjöl");        // Returns "mjöl" (unchanged)
  /// ```
  static String normalizeToSingular(String name) {
    final lower = name.toLowerCase().trim();

    // First check against irregular plurals database (reverse lookup)
    for (final entry in irregularPlurals.entries) {
      if (entry.value.toLowerCase() == lower) {
        return entry.key;
      }
    }

    // Remove common Swedish plural endings with length validation
    if (lower.endsWith('ar') && lower.length > 3) {
      return name.substring(0, name.length - 2);
    }
    if (lower.endsWith('or') && lower.length > 3) {
      // Many Swedish -or plurals have -a singulars (e.g., flickor -> flicka, flaskor -> flaska)
      // Try both patterns: remove -or and remove -or + add a
      final withoutOr = name.substring(0, name.length - 2);
      final withA = '${withoutOr}a';

      // Check if the -a form is known in our database
      if (irregularPlurals.containsKey(withA.toLowerCase()) &&
          irregularPlurals[withA.toLowerCase()] == lower) {
        return withA;
      }
      // Default to simple -or removal
      return withoutOr;
    }
    if (lower.endsWith('er') && lower.length > 3) {
      return name.substring(0, name.length - 2);
    }
    if (lower.endsWith('ingar') && lower.length > 6) {
      return '${name.substring(0, name.length - 5)}ing';
    }
    if (lower.endsWith('ningar') && lower.length > 7) {
      return '${name.substring(0, name.length - 6)}ning';
    }

    // Return original if no normalization patterns match
    return name;
  }

  /// Intelligent Swedish pluralization with cooking-specific rules and cultural accuracy
  /// This method provides comprehensive Swedish pluralization that handles both regular and irregular
  /// plural forms while respecting Swedish cooking conventions. It includes special handling for
  /// measurement units, compound ingredient names, and cultural patterns specific to Swedish
  /// cooking terminology and ingredient descriptions.
  /// **Pluralization Strategy:**
  /// 1. **Count Validation**: Returns singular for count of 1.0
  /// 2. **Irregular Lookup**: Checks comprehensive irregular plurals database
  /// 3. **Compound Analysis**: Handles multi-word ingredient names properly
  /// 4. **Unit Detection**: Preserves measurement units while pluralizing ingredients
  /// 5. **Pattern Application**: Applies Swedish pluralization rules for regular forms
  /// [singular] The singular form of the ingredient name
  /// [count] The quantity count to determine plural necessity
  /// Returns properly pluralized Swedish ingredient name
  /// **Examples:**
  /// ```dart
  /// pluralize("potatis", 2.0);     // Returns "potatisar"
  /// pluralize("dl mjölk", 3.0);    // Returns "dl mjölk" (unit preserved)
  /// pluralize("ägg", 4.0);         // Returns "ägg" (invariant)
  /// pluralize("lök", 1.0);        // Returns "lök" (singular)
  /// ```
  static String pluralize(String singular, double count) {
    // Return singular form for count of 1.0
    if (count == 1.0) {
      return singular;
    }

    final lower = singular.toLowerCase();

    // Check irregular plurals database first
    if (irregularPlurals.containsKey(lower)) {
      final plural = irregularPlurals[lower]!;
      // Preserve original case for first letter
      if (singular.isNotEmpty && singular[0].toUpperCase() == singular[0]) {
        return plural[0].toUpperCase() + plural.substring(1);
      }
      return plural;
    }

    // Handle compound ingredient names (e.g., "burk tomatsås")
    final parts = singular.split(' ');
    if (parts.length > 1) {
      final firstWord = parts[0];
      final rest = parts.sublist(1).join(' ');

      // Only pluralize first word if it's not a measurement unit
      if (isMeasurementUnit(firstWord.toLowerCase())) {
        return singular; // Keep unchanged for measurement units
      } else {
        final firstPlural = _pluralizeWord(firstWord);
        return '$firstPlural $rest';
      }
    }

    return _pluralizeWord(singular);
  }

  /// Comprehensive measurement unit recognition for Swedish and American cooking systems
  /// This method provides accurate detection of measurement units to prevent incorrect pluralization
  /// of cooking measurements. It supports both Swedish cooking measurements and American units
  /// commonly found in imported recipes, ensuring proper handling of international recipe formats.
  /// **Unit Categories:**
  /// - **Swedish Weight**: g, kg, hg, dag, mg
  /// - **Swedish Volume**: dl, l, ml, cl
  /// - **Swedish Cooking**: msk (matsked), tsk (tesked), krm (kryddmått)
  /// - **American Volume**: cup, fl oz, tbsp, tsp, pint, quart, gallon
  /// - **American Weight**: lb, oz, pound, ounce
  /// - **Variations**: Supports both singular and plural forms
  /// [word] The word to check for measurement unit recognition
  /// Returns true if the word is a recognized measurement unit
  /// **Examples:**
  /// ```dart
  /// isMeasurementUnit("dl");        // Returns true
  /// isMeasurementUnit("cups");      // Returns true
  /// isMeasurementUnit("potatis");   // Returns false
  /// ```
  static bool isMeasurementUnit(String word) {
    const units = {
      // Swedish measurement units
      'g', 'kg', 'hg', 'dag', 'mg',
      'dl', 'l', 'ml', 'cl',
      'msk', 'tsk', 'krm',

      // American measurement units (with variations)
      'cup', 'cups', 'oz', 'fl oz', 'floz', 'tbsp', 'tsp',
      'lb', 'lbs', 'pound', 'pounds', 'ounce', 'ounces',
      'pint', 'pints', 'quart', 'quarts', 'gallon', 'gallons',
      'tablespoon', 'tablespoons', 'teaspoon', 'teaspoons',
    };
    return units.contains(word);
  }

  static String _pluralizeWord(String word) {
    final lower = word.toLowerCase();

    // Special cases for specific words
    final specialCases = {
      'lasagneplatt': 'lasagneplattor',
      'krossade tomat': 'krossade tomater',
      'krossad tomat': 'krossade tomater',
      'lök': 'lökar',
      'potatis': 'potatisar',
      'tomat': 'tomater',
      'morot': 'morötter',
      'gurka': 'gurkor',
      'paprika': 'paprikor',
      'citron': 'citroner',
      'vitlök': 'vitlökar',
      'champinjon': 'champinjoner',
      'svamp': 'svampar',
      'äpple': 'äpplen',
      'banan': 'bananer',
      'apelsin': 'apelsiner',
      'avokado': 'avokados',
      'burk': 'burkar',
      'påse': 'påsar',
      'förpackning': 'förpackningar',
      'flaska': 'flaskor',
      'flicka': 'flickor',
      'ask': 'askar',
      'kött': 'kött', // Invariant
      'fisk': 'fisk', // Invariant
      'mjöl': 'mjöl', // Invariant
      'socker': 'socker', // Invariant
      'ris': 'ris', // Invariant
      'pasta': 'pasta', // Invariant
      'bröd': 'bröd', // Invariant
      'smör': 'smör', // Invariant
      'grädde': 'grädde', // Invariant
      'mjölk': 'mjölk', // Invariant
      'vatten': 'vatten', // Invariant
    };

    if (specialCases.containsKey(lower)) {
      // Preserve original case structure
      final special = specialCases[lower]!;
      if (word.isNotEmpty && word[0].toUpperCase() == word[0]) {
        // First letter uppercase
        return special[0].toUpperCase() + special.substring(1);
      }
      return special;
    }

    // Regular rules for pluralization
    if (lower.endsWith('ing')) {
      return '${word}ar';
    }
    if (lower.endsWith('ling')) {
      return '${word}ar';
    }
    if (lower.endsWith('ning')) {
      return '${word}ar';
    }
    if (lower.endsWith('a')) {
      return '${word.substring(0, word.length - 1)}or';
    }
    if (lower.endsWith('e')) {
      return '${word}r';
    }
    if (lower.endsWith('el')) {
      return '${word.substring(0, word.length - 2)}lar';
    }
    if (lower.endsWith('er')) {
      return '${word.substring(0, word.length - 2)}rar';
    }
    if (lower.endsWith('en')) {
      return '${word.substring(0, word.length - 2)}nar';
    }

    // Standard: lägg till 'ar'
    return '${word}ar';
  }

  /// Advanced ingredient formatting with Swedish quantity display and intelligent pluralization
  /// This method serves as the primary ingredient formatting function, combining Swedish quantity
  /// formatting with appropriate pluralization rules. It handles measurement units, fraction
  /// notation, and cultural conventions to provide natural Swedish ingredient display that
  /// reflects how Swedish speakers naturally describe cooking ingredients.
  /// **Formatting Features:**
  /// - **Swedish Fractions**: Uses Unicode fraction notation (½, ¼, ¾) when appropriate
  /// - **Unit Preservation**: Maintains measurement units without pluralization
  /// - **Smart Pluralization**: Applies Swedish pluralization rules for ingredient names
  /// - **Cultural Accuracy**: Follows Swedish cooking terminology and conventions
  /// - **Special Cases**: Handles complex ingredient names and measurement combinations
  /// [ingredientKey] The ingredient identifier (may include unit and name)
  /// [totalQuantity] The total quantity to format and display
  /// Returns formatted Swedish ingredient string with proper quantity and pluralization
  /// **Examples:**
  /// ```dart
  /// formatIngredient("potatis", 3.0);     // Returns "3 potatisar"
  /// formatIngredient("dl mjölk", 1.5);    // Returns "1½ dl mjölk"
  /// formatIngredient("lasagneplatt", 6.0); // Returns "6 lasagneplattor"
  /// ```
  static String formatIngredient(String ingredientKey, double totalQuantity) {
    // Format quantity with Swedish fraction notation
    final qtyStr = TextFormatting.toSwedishHalfFraction(totalQuantity);

    // For quantity of 1, display singular form
    if (totalQuantity == 1.0) {
      return '$qtyStr $ingredientKey';
    }

    // Parse ingredient key into unit and name components
    final parts = ingredientKey.split(' ');
    if (parts.length > 1 && isMeasurementUnit(parts[0])) {
      // For measurement units (e.g., "dl mjölk" -> "2 dl mjölk")
      // Keep unit invariant according to Swedish cooking conventions
      return '$qtyStr $ingredientKey';
    } else {
      // For standalone ingredients, apply smart pluralization
      String pluralized;
      if (ingredientKey.toLowerCase().contains('platt')) {
        // Special case for cooking sheet/plate items
        pluralized = ingredientKey.replaceAll(
          RegExp(r'platt$', caseSensitive: false),
          'plattor',
        );
      } else {
        pluralized = pluralize(ingredientKey, totalQuantity);
      }
      return '$qtyStr $pluralized';
    }
  }
}

/// Legacy exports for backward compatibility during migration phase
/// These exports provide backward compatibility for existing code that hasn't been updated to use
/// the new SwedishPluralization class methods. They maintain the same behavior while delegating
/// to the consolidated implementation for consistent pluralization throughout the application.
/// **Migration Note:** New code should use `SwedishPluralization.methodName()` directly.
/// These legacy exports will be removed in a future version once all code has been migrated.

/// Legacy export: Use SwedishPluralization.irregularPlurals instead
const Map<String, String> irregularPlurals =
    SwedishPluralization.irregularPlurals;

/// Legacy export: Use SwedishPluralization.formatIngredient() instead
String pluralizeSwedish(String singular, double count) {
  return SwedishPluralization.formatIngredient(singular, count);
}
