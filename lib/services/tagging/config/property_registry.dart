import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart';

/// C1: Registry of valid ingredient properties.
///
/// Used to validate that properties in allergen/dietary configs exist
/// in the ingredient database. Throws at startup if typos detected.
class PropertyRegistry {
  PropertyRegistry._();

  /// All valid ingredient properties from the ingredient database.
  /// Update this list when adding new properties to ingredients.
  static const Set<String> validProperties = {
    // Allergens (EU mandatory 14)
    'dairy',
    'egg',
    'fish',
    'crustacean',
    'mollusc',
    'peanut',
    'tree-nut',
    'wheat',
    'contains-gluten',
    'soy',
    'sesame',
    'celery',
    'mustard',
    'lupin',
    'sulfites',

    // Lactose (separate from dairy protein)
    'contains-lactose',

    // Meat types
    'meat',
    'pork',
    'beef',
    'poultry',
    'lamb',
    'game',

    // Seafood
    'seafood',
    'high-mercury',

    // Other animal products
    'animal-product',

    // Diet-related
    'contains-alcohol',
    'is-spicy',
    'plant-based',

    // Special diet properties
    'nightshade', // Tomato, potato, peppers, eggplant, chili

    // Practical
    'doesnt-freeze-well',
    'raw-safe',
  };

  /// Checks if a property name is valid.
  static bool isValid(String property) => validProperties.contains(property);

  /// Validates a property and logs a warning if unknown.
  ///
  /// Returns true if valid, false if unknown.
  static bool validateOrWarn(String property, String context) {
    if (!isValid(property)) {
      AppLogger.warning(
        '⚠️ Unknown property "$property" in $context. '
            'Consider adding to PropertyRegistry if intentional.',
        'PropertyRegistry',
      );
      return false;
    }
    return true;
  }

  /// Validates multiple properties and returns the invalid ones.
  static Set<String> getInvalidProperties(Iterable<String> properties) {
    return properties.where((p) => !isValid(p)).toSet();
  }

  /// Validates properties from a config and logs warnings for unknowns.
  static void validateConfigProperties(
    Iterable<String> properties,
    String configName,
  ) {
    for (final property in properties) {
      validateOrWarn(property, configName);
    }
  }

  /// C1: Validates all properties in AllergenConfig and DietaryConfig.
  ///
  /// Throws [StateError] if any invalid properties are found.
  /// Call this at app startup (in TaggingService.onInitialize) to fail fast
  /// on configuration errors like typos in property names.
  ///
  /// Example error for typo "daiyr" instead of "dairy":
  /// ```
  /// StateError: Property validation failed. Fix these typos:
  ///   - AllergenConfig: Unknown property "daiyr" for allergen "mjölk"
  /// ```
  static void validateAllConfigs() {
    final errors = <String>[];

    // Validate AllergenConfig - check all trigger properties
    for (final allergen in AllergenConfig.all) {
      for (final prop in allergen.triggerProperties) {
        if (!isValid(prop)) {
          errors.add(
            'AllergenConfig: Unknown property "$prop" for allergen "${allergen.key}"',
          );
        }
      }
    }

    // Validate DietaryConfig - check excluded and required properties
    for (final dietary in DietaryConfig.all) {
      for (final prop in dietary.excludedProperties) {
        if (!isValid(prop)) {
          errors.add(
            'DietaryConfig: Unknown excluded property "$prop" for diet "${dietary.key}"',
          );
        }
      }

      if (dietary.requiredProperties != null) {
        for (final prop in dietary.requiredProperties!) {
          if (!isValid(prop)) {
            errors.add(
              'DietaryConfig: Unknown required property "$prop" for diet "${dietary.key}"',
            );
          }
        }
      }
    }

    if (errors.isNotEmpty) {
      throw StateError(
        'Property validation failed. Fix these typos in config files:\n'
        '${errors.map((e) => '  - $e').join('\n')}',
      );
    }

    AppLogger.debug(
      '✓ Property validation passed for ${AllergenConfig.all.length} allergens '
          'and ${DietaryConfig.all.length} dietary configs',
      'PropertyRegistry',
    );
  }
}
