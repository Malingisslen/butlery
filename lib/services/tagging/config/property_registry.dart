import 'package:butlery/core/utils/logger.dart';

/// M3: Registry of valid ingredient properties.
///
/// Used to validate that properties in allergen/dietary configs exist
/// in the ingredient database. Warns on unknown properties.
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
    'sulphites',

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
}
