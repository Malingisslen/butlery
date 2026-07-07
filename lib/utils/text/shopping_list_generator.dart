/// Intelligent shopping list generation system providing ingredient consolidation and Swedish formatting for menu planning.
/// This utility class provides sophisticated shopping list generation from menu data, consolidating ingredients
/// across multiple recipes with intelligent unit conversion, quantity aggregation, and proper Swedish formatting.
/// It eliminates duplicate shopping list generation logic while providing comprehensive ingredient management
/// and smart measurement unit optimization for practical shopping experiences.
/// **Architecture Integration:**
/// - Integrates with [IngredientParser] for accurate ingredient parsing and recognition
/// - Uses [SmartUnitConverter] for optimal measurement unit conversions and readability
/// - Leverages [SwedishPluralization] for proper ingredient name formatting and pluralization
/// - Supports complex menu structures with multiple recipes and ingredient variations
/// - Provides foundation for collaborative shopping and menu planning features
/// **Shopping List Features:**
/// - **Ingredient Consolidation**: Automatically combines similar ingredients across recipes
/// - **Unit Optimization**: Converts quantities to practical shopping units (e.g., 1500g -> 1.5kg)
/// - **Swedish Formatting**: Applies proper Swedish measurement and language conventions
/// - **Duplicate Handling**: Intelligent ingredient deduplication with normalization
/// - **Quantity Aggregation**: Sums quantities of identical ingredients across recipes
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
/// **Usage Examples:**
/// ```dart
/// // Generate shopping list from menu
/// final menu = {
///   'Huvudrätter': [recipe1, recipe2],
///   'Efterrätter': [recipe3],
/// };
/// final shoppingList = ShoppingListGenerator.generateShoppingList(menu);
/// // Returns: ["1,5 kg mjöl", "6 ägg", "3 dl grädde", ...]
/// ```

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/utils/text/unit_converter.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';
import 'package:butlery/utils/text/swedish_pluralization.dart';
import 'package:butlery/utils/text/ingredient_processor.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/shopping/ingredient_categorizer.dart';

/// Intelligent shopping list generation system providing ingredient consolidation and optimization for menu planning.
/// This class serves as the central shopping list generation engine for the Butlery cooking application,
/// handling the complexity of ingredient consolidation across multiple recipes, unit optimization,
/// and Swedish formatting conventions. It provides comprehensive ingredient management that transforms
/// complex menu data into organized, practical shopping lists.
/// **Smart Consolidation Algorithm:**
/// The generator uses a sophisticated multi-step process that parses ingredients, normalizes names,
/// groups similar items, aggregates quantities, and applies intelligent unit conversion for optimal
/// shopping readability and Swedish cultural conventions.
/// **Static Utility Design:**
/// - Private constructor prevents instantiation, ensuring pure utility function usage
/// - All methods are static for convenient access without object creation overhead
/// - Pure functions with no side effects for predictable list generation behavior
/// - Comprehensive error handling for robust operation with diverse menu data
class ShoppingListGenerator {
  /// Private constructor preventing instantiation to enforce static utility usage.
  ShoppingListGenerator._();

  /// Comprehensive shopping list generation with intelligent ingredient consolidation and optimization
  /// This method serves as the primary shopping list generation engine, processing complex menu structures
  /// to create optimized, consolidated shopping lists. It handles ingredient parsing, normalization,
  /// aggregation, and formatting with Swedish cultural conventions and smart unit conversion for
  /// practical shopping experiences.
  /// **Generation Process:**
  /// 1. **Ingredient Extraction**: Parses all ingredients from menu recipes
  /// 2. **Data Processing**: Handles various recipe data formats and structures
  /// 3. **Normalization**: Converts ingredient names to singular form for grouping
  /// 4. **Consolidation**: Groups identical ingredients and sums quantities
  /// 5. **Unit Optimization**: Applies smart unit conversion for readability
  /// 6. **Swedish Formatting**: Formats with proper pluralization and measurements
  /// 7. **Alphabetical Sorting**: Organizes for efficient shopping
  /// **Menu Structure Support:**
  /// - Map-based recipe data with ingredient arrays
  /// - Recipe object format with ingredients property
  /// - Mixed data formats with robust error handling
  /// - Empty menu handling with graceful fallback
  /// [menu] The menu data structure containing recipes organized by sections
  /// Returns a sorted list of consolidated shopping items with Swedish formatting
  /// **Examples:**
  /// ```dart
  /// final menu = {
  ///   'Huvudrätter': [
  ///     {'ingredients': ['400g köttfärs', '2 lökar']},
  ///     {'ingredients': ['200g köttfärs', '1 lök']},
  ///   ],
  /// };
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
        } else if (recipe is Recipe) {
          allIngredients.addAll(recipe.ingredients);
        } else {
          // Duck-typing fallback: try accessing .ingredients on dynamic objects
          try {
            final dynamic dynamicRecipe = recipe;
            final ingredients = dynamicRecipe.ingredients;
            if (ingredients is List) {
              allIngredients.addAll(ingredients.map((e) => e.toString()));
            }
          } catch (_) {
            // Object doesn't have an ingredients property — skip
          }
        }
      }
    }

    // Intelligent ingredient grouping with normalization and consolidation
    final Map<String, double> groupedIngredients = {};
    // Track the original display name per grouping key (first occurrence wins)
    final Map<String, String> displayKeys = {};

    for (final rawIngredient in allIngredients) {
      // Skip empty or whitespace-only ingredients
      if (rawIngredient.trim().isEmpty) continue;

      // MODUL1 Pattern B: Parse + Normalize for better grouping
      // This removes preparation words, normalizes plural, and validates ingredients
      // Examples:
      // - "2 dl hackad lök" + "1 dl skivad lök" → both group as "dl lök"
      // - "3 st stora ägg" + "2 st ägg" → both group as "st ägg"
      final processed = IngredientProcessor.parseAndNormalize(rawIngredient);

      // Create grouping key based on unit + normalized ingredient name
      // Use normalized name for grouping to consolidate similar ingredients
      final key = processed.unit.isEmpty
          ? processed.normalizedName
          : '${processed.unit} ${processed.normalizedName}';

      // Preserve the original name (with descriptors) for display.
      // First occurrence wins — keeps "finhackad lök" instead of bare "lök".
      final origKey = processed.unit.isEmpty
          ? processed.originalName
          : '${processed.unit} ${processed.originalName}';
      displayKeys.putIfAbsent(key, () => origKey);

      // Aggregate quantities for identical ingredients
      groupedIngredients[key] =
          (groupedIngredients[key] ?? 0.0) + processed.quantity;
    }

    // Format for display with smart unit conversion and Swedish formatting
    final displayList = <String>[];
    final sortedKeys = groupedIngredients.keys.toList()..sort();

    for (final key in sortedKeys) {
      final totalQuantity = groupedIngredients[key]!;
      final display = displayKeys[key] ?? key;

      // Apply smart unit conversion for practical shopping quantities
      final parts = display.split(' ');
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
            display,
            totalQuantity,
          );
          displayList.add(formatted);
        }
      } else {
        // Handle unit-less ingredients with proper pluralization
        final formatted = SwedishPluralization.formatIngredient(
          display,
          totalQuantity,
        );
        displayList.add(formatted);
      }
    }

    return displayList;
  }

  /// Generate consolidated shopping items from a menu with ingredient dedup.
  ///
  /// Loops through all recipes, parses each ingredient, and consolidates
  /// by (unit + normalizedName) so that e.g. "2 dl mjölk" and "3 dl mjölk"
  /// become a single item with amount 5.
  static List<UnifiedShoppingItem> generateShoppingItemsFromMenu(
    Map<String, List<Recipe>> menu,
  ) {
    if (menu.isEmpty) return [];

    final Map<String, double> quantities = {};
    final Map<String, String> units = {};
    final Map<String, String> displayNames = {};
    final Map<String, String> categories = {};

    for (final recipes in menu.values) {
      for (final recipe in recipes) {
        if (recipe.ingredients.isEmpty) continue;

        for (final rawIngredient in recipe.ingredients) {
          if (rawIngredient.trim().isEmpty) continue;

          final processed = IngredientProcessor.parseAndNormalize(
            rawIngredient,
          );
          final key = processed.unit.isEmpty
              ? processed.normalizedName
              : '${processed.unit}_${processed.normalizedName}';

          quantities[key] = (quantities[key] ?? 0.0) + processed.quantity;
          units.putIfAbsent(key, () => processed.unit);
          displayNames.putIfAbsent(key, () => processed.originalName.trim());
          categories.putIfAbsent(
            key,
            () => IngredientCategorizer.categorize(processed.normalizedName),
          );
        }
      }
    }

    final sortedKeys = quantities.keys.toList()..sort();
    return sortedKeys
        .map(
          (key) => UnifiedShoppingItem(
            name: displayNames[key]!,
            amount: quantities[key]!,
            unit: units[key]!,
            category: categories[key]!,
            bought: false,
          ),
        )
        .toList();
  }

  /// Generate shopping items from a single recipe with Swedish ingredient parsing and categorization.
  /// This method creates UnifiedShoppingItem objects from a recipe's ingredients, providing
  /// structured shopping data ready for addition to shopping lists. It leverages the existing
  /// Swedish ingredient parsing infrastructure and intelligent categorization system.
  /// **Processing Features:**
  /// - Swedish ingredient parsing with unit/quantity extraction
  /// - Automatic ingredient categorization (Mejeri, Kött & Fisk, etc.)
  /// - Smart unit conversion and formatting
  /// - Fallback categorization for unknown ingredients
  /// - Robust error handling for malformed ingredient strings
  /// [recipe] Recipe object containing ingredients list to convert
  /// [portions] Optional portion scaling factor (defaults to recipe portions)
  /// Returns List of UnifiedShoppingItem objects ready for shopping list addition
  /// **Usage Example:**
  /// ```dart
  /// final recipe = Recipe(
  ///   title: 'Pannkakor',
  ///   ingredients: ['2 dl mjölk', '1 ägg', '100g mjöl'],
  /// );
  /// final items = ShoppingListGenerator.generateShoppingItemsFromRecipe(recipe);
  /// // Returns: [
  /// //   UnifiedShoppingItem(name: 'mjölk', amount: 2.0, unit: 'dl', category: ShoppingCategory.dairy),
  /// //   UnifiedShoppingItem(name: 'ägg', amount: 1.0, unit: 'st', category: ShoppingCategory.dairy),
  /// //   UnifiedShoppingItem(name: 'mjöl', amount: 100.0, unit: 'g', category: ShoppingCategory.dryGoods),
  /// // ]
  /// ```
  static List<UnifiedShoppingItem> generateShoppingItemsFromRecipe(
    Recipe recipe, {
    int? portions,
  }) {
    // Handle empty ingredients gracefully
    if (recipe.ingredients.isEmpty) return [];

    final List<UnifiedShoppingItem> shoppingItems = [];
    final targetPortions = portions ?? recipe.portions ?? 1;
    final originalPortions = recipe.portions ?? 1;
    final scalingFactor = originalPortions > 0
        ? targetPortions / originalPortions
        : 1.0;

    for (final rawIngredient in recipe.ingredients) {
      // Skip empty or whitespace-only ingredients
      if (rawIngredient.trim().isEmpty) continue;

      try {
        // MODUL1 Pattern B: Parse + Normalize for better categorization
        // Normalized name improves category detection accuracy
        final processed = IngredientProcessor.parseAndNormalize(rawIngredient);

        // Scale quantity based on portion adjustment
        final scaledQuantity = processed.quantity * scalingFactor;

        // Determine category using normalized name for better accuracy
        // Example: "hackad lök" → normalized to "lök" → correctly categorized as vegetable
        final category = IngredientCategorizer.categorize(
          processed.normalizedName,
        );

        // Create UnifiedShoppingItem with original name for display
        // but use normalized name for better categorization
        final shoppingItem = UnifiedShoppingItem(
          name: processed.originalName.trim(), // Display original
          amount: scaledQuantity,
          unit: processed.unit,
          category: category,
          bought: false,
          note: '', // No notes from recipe ingredients
          priority: 3, // Default priority
        );

        shoppingItems.add(shoppingItem);
      } catch (e) {
        // Handle parsing errors gracefully - create basic item
        final fallbackItem = UnifiedShoppingItem(
          name: rawIngredient.trim(),
          amount: 1.0,
          unit: 'st',
          category: ShoppingCategory.other,
          bought: false,
          note: AppLocale.current.ingredientParseError,
          priority: 3,
        );

        shoppingItems.add(fallbackItem);
      }
    }

    return shoppingItems;
  }
}
