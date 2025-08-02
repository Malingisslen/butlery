/// Intelligent shopping list generation system providing ingredient consolidation and Swedish formatting for menu planning.
///
/// This utility class provides sophisticated shopping list generation from menu data, consolidating ingredients
/// across multiple recipes with intelligent unit conversion, quantity aggregation, and proper Swedish formatting.
/// It eliminates duplicate shopping list generation logic while providing comprehensive ingredient management
/// and smart measurement unit optimization for practical shopping experiences.
///
/// **Architecture Integration:**
/// - Integrates with [IngredientParser] for accurate ingredient parsing and recognition
/// - Uses [SmartUnitConverter] for optimal measurement unit conversions and readability
/// - Leverages [SwedishPluralization] for proper ingredient name formatting and pluralization
/// - Supports complex menu structures with multiple recipes and ingredient variations
/// - Provides foundation for collaborative shopping and menu planning features
///
/// **Shopping List Features:**
/// - **Ingredient Consolidation**: Automatically combines similar ingredients across recipes
/// - **Unit Optimization**: Converts quantities to practical shopping units (e.g., 1500g -> 1.5kg)
/// - **Swedish Formatting**: Applies proper Swedish measurement and language conventions
/// - **Duplicate Handling**: Intelligent ingredient deduplication with normalization
/// - **Quantity Aggregation**: Sums quantities of identical ingredients across recipes
///
/// **Consolidation Algorithm:**
/// ```
/// 1. Parse all ingredients from menu recipes
/// 2. Normalize ingredient names to singular form
/// 3. Group by unit + normalized name combination
/// 4. Sum quantities for matching ingredient groups
/// 5. Apply smart unit conversion for readability
/// 6. Format with Swedish pluralization and measurements
/// 7. Sort alphabetically for organized shopping
/// ```
///
/// **Usage Examples:**
/// ```dart
/// // Generate shopping list from menu
/// final menu = {
///   'Huvudrätter': [recipe1, recipe2],
///   'Efterrätter': [recipe3],
/// };
/// 
/// final shoppingList = ShoppingListGenerator.generateShoppingList(menu);
/// // Returns: ["1,5 kg mjöl", "6 ägg", "3 dl grädde", ...]
/// ```

import 'package:butlery/utils/text/unit_converter.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';
import 'package:butlery/utils/text/swedish_pluralization.dart';

/// Intelligent shopping list generation system providing ingredient consolidation and optimization for menu planning.
///
/// This class serves as the central shopping list generation engine for the Butlery cooking application,
/// handling the complexity of ingredient consolidation across multiple recipes, unit optimization,
/// and Swedish formatting conventions. It provides comprehensive ingredient management that transforms
/// complex menu data into organized, practical shopping lists.
///
/// **Smart Consolidation Algorithm:**
/// The generator uses a sophisticated multi-step process that parses ingredients, normalizes names,
/// groups similar items, aggregates quantities, and applies intelligent unit conversion for optimal
/// shopping readability and Swedish cultural conventions.
///
/// **Static Utility Design:**
/// - Private constructor prevents instantiation, ensuring pure utility function usage
/// - All methods are static for convenient access without object creation overhead
/// - Pure functions with no side effects for predictable list generation behavior
/// - Comprehensive error handling for robust operation with diverse menu data
class ShoppingListGenerator {
  /// Private constructor preventing instantiation to enforce static utility usage.
  ShoppingListGenerator._();
  /// Comprehensive shopping list generation with intelligent ingredient consolidation and optimization
  ///
  /// This method serves as the primary shopping list generation engine, processing complex menu structures
  /// to create optimized, consolidated shopping lists. It handles ingredient parsing, normalization,
  /// aggregation, and formatting with Swedish cultural conventions and smart unit conversion for
  /// practical shopping experiences.
  ///
  /// **Generation Process:**
  /// 1. **Ingredient Extraction**: Parses all ingredients from menu recipes
  /// 2. **Data Processing**: Handles various recipe data formats and structures
  /// 3. **Normalization**: Converts ingredient names to singular form for grouping
  /// 4. **Consolidation**: Groups identical ingredients and sums quantities
  /// 5. **Unit Optimization**: Applies smart unit conversion for readability
  /// 6. **Swedish Formatting**: Formats with proper pluralization and measurements
  /// 7. **Alphabetical Sorting**: Organizes for efficient shopping
  ///
  /// **Menu Structure Support:**
  /// - Map-based recipe data with ingredient arrays
  /// - Recipe object format with ingredients property
  /// - Mixed data formats with robust error handling
  /// - Empty menu handling with graceful fallback
  ///
  /// [menu] The menu data structure containing recipes organized by sections
  /// Returns a sorted list of consolidated shopping items with Swedish formatting
  ///
  /// **Examples:**
  /// ```dart
  /// final menu = {
  ///   'Huvudrätter': [
  ///     {'ingredients': ['400g köttfärs', '2 lökar']},
  ///     {'ingredients': ['200g köttfärs', '1 lök']},
  ///   ],
  /// };
  /// 
  /// final list = generateShoppingList(menu);
  /// // Returns: ['600g köttfärs', '3 lökar']
  /// ```
  static List<String> generateShoppingList(Map<String, List<dynamic>> menu) {
    // Handle empty menu gracefully
    if (menu.isEmpty) return [];

    // Extract all ingredients from menu structure with robust error handling
    final List<String> allIngredients = [];
    for (final recipesInSection in menu.values) {
      for (final recipe in recipesInSection) {
        // Handle Map-based recipe data with ingredients property
        if (recipe is Map && recipe.containsKey('ingredients')) {
          final ingredients = recipe['ingredients'] as List?;
          if (ingredients != null) {
            allIngredients.addAll(ingredients.map((e) => e.toString()));
          }
        } else if (recipe.toString().contains('ingredients')) {
          // Fallback for Recipe object format with dynamic property access
          try {
            final recipeObj = recipe as dynamic;
            final ingredients = recipeObj.ingredients as List<String>?;
            if (ingredients != null) {
              allIngredients.addAll(ingredients);
            }
          } catch (e) {
            // Gracefully handle parsing errors and continue processing
          }
        }
      }
    }

    // Intelligent ingredient grouping with normalization and consolidation
    final Map<String, double> groupedIngredients = {};

    for (final rawIngredient in allIngredients) {
      // Skip empty or whitespace-only ingredients
      if (rawIngredient.trim().isEmpty) continue;

      final parsed = IngredientParser.parseIngredient(rawIngredient);

      // Create grouping key based on unit + normalized ingredient name
      // This enables proper consolidation of similar ingredients
      final normalizedName = SwedishPluralization.normalizeToSingular(
        parsed.name,
      );
      final key =
          parsed.unit.isEmpty
              ? normalizedName
              : '${parsed.unit} $normalizedName';

      // Aggregate quantities for identical ingredients
      groupedIngredients[key] =
          (groupedIngredients[key] ?? 0.0) + parsed.quantity;
    }

    // Format for display with smart unit conversion and Swedish formatting
    final displayList = <String>[];
    final sortedKeys = groupedIngredients.keys.toList()..sort();

    for (final key in sortedKeys) {
      final totalQuantity = groupedIngredients[key]!;

      // Apply smart unit conversion for practical shopping quantities
      final parts = key.split(' ');
      if (parts.length > 1 &&
          SwedishPluralization.isMeasurementUnit(parts[0])) {
        final unit = parts[0];
        final name = parts.sublist(1).join(' ');

        // Check if unit conversion would improve readability
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
          // Use original unit if conversion doesn't improve readability
          final formatted = SwedishPluralization.formatIngredient(
            key,
            totalQuantity,
          );
          displayList.add(formatted);
        }
      } else {
        // Handle unit-less ingredients with proper pluralization
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