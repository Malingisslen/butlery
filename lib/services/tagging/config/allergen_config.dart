/// Configuration for allergen detection in the tagging system.
///
/// Based on EU allergen regulations plus additional common allergens.
/// Each allergen maps to ingredient properties and output tags.
library;

/// Single allergen configuration.
class AllergenEntry {
  /// Allergen key (e.g., 'gluten').
  final String key;

  /// Property or properties that trigger this allergen.
  /// Can be a single property or multiple joined with ' OR '.
  final String triggerProperty;

  /// Swedish tag when recipe contains this allergen.
  final String containsTag;

  /// Swedish tag when recipe is free from this allergen.
  final String? freeTag;

  /// Whether this is an EU-regulated allergen.
  final bool isEuAllergen;

  const AllergenEntry({
    required this.key,
    required this.triggerProperty,
    required this.containsTag,
    this.freeTag,
    this.isEuAllergen = false,
  });

  /// Gets the properties that trigger this allergen as a list.
  List<String> get triggerProperties {
    if (triggerProperty.contains(' OR ')) {
      return triggerProperty.split(' OR ').map((p) => p.trim()).toList();
    }
    return [triggerProperty];
  }

  /// Whether this allergen combines multiple properties.
  bool get isCombined => triggerProperty.contains(' OR ');
}

/// All configured allergens.
class AllergenConfig {
  AllergenConfig._();

  /// All allergen entries in order.
  static const List<AllergenEntry> all = [
    // EU Allergens (14)
    AllergenEntry(
      key: 'gluten',
      triggerProperty: 'contains-gluten',
      containsTag: 'innehåller-gluten',
      freeTag: 'glutenfri',
      isEuAllergen: true,
    ),
    AllergenEntry(
      key: 'mjölk',
      triggerProperty: 'dairy',
      containsTag: 'innehåller-mjölk',
      freeTag: 'mjölkfri',
      isEuAllergen: true,
    ),
    AllergenEntry(
      key: 'ägg',
      triggerProperty: 'egg',
      containsTag: 'innehåller-ägg',
      freeTag: 'äggfri',
      isEuAllergen: true,
    ),
    AllergenEntry(
      key: 'fisk',
      triggerProperty: 'fish',
      containsTag: 'innehåller-fisk',
      freeTag: 'fiskfri',
      isEuAllergen: true,
    ),
    AllergenEntry(
      key: 'kräftdjur',
      triggerProperty: 'crustacean',
      containsTag: 'innehåller-kräftdjur',
      freeTag: 'kräftdjursfri',
      isEuAllergen: true,
    ),
    AllergenEntry(
      key: 'blötdjur',
      triggerProperty: 'mollusc',
      containsTag: 'innehåller-blötdjur',
      freeTag: 'blötdjursfri',
      isEuAllergen: true,
    ),
    AllergenEntry(
      key: 'trädnötter',
      triggerProperty: 'tree-nut',
      containsTag: 'innehåller-trädnötter',
      freeTag: 'trädnötsfri',
      isEuAllergen: true,
    ),
    AllergenEntry(
      key: 'jordnötter',
      triggerProperty: 'peanut',
      containsTag: 'innehåller-jordnötter',
      freeTag: 'jordnötsfri',
      isEuAllergen: true,
    ),
    AllergenEntry(
      key: 'soja',
      triggerProperty: 'soy',
      containsTag: 'innehåller-soja',
      freeTag: 'sojafri',
      isEuAllergen: true,
    ),
    AllergenEntry(
      key: 'sesam',
      triggerProperty: 'sesame',
      containsTag: 'innehåller-sesam',
      freeTag: 'sesamfri',
      isEuAllergen: true,
    ),
    AllergenEntry(
      key: 'selleri',
      triggerProperty: 'celery',
      containsTag: 'innehåller-selleri',
      freeTag: 'sellerifri',
      isEuAllergen: true,
    ),
    AllergenEntry(
      key: 'senap',
      triggerProperty: 'mustard',
      containsTag: 'innehåller-senap',
      freeTag: 'senapfri',
      isEuAllergen: true,
    ),
    AllergenEntry(
      key: 'lupin',
      triggerProperty: 'lupin',
      containsTag: 'innehåller-lupin',
      freeTag: 'lupinfri',
      isEuAllergen: true,
    ),
    AllergenEntry(
      key: 'sulfiter',
      triggerProperty: 'sulfites',
      containsTag: 'innehåller-sulfiter',
      freeTag: 'sulfitfri',
      isEuAllergen: true,
    ),

    // Additional common allergens
    AllergenEntry(
      key: 'laktos',
      triggerProperty: 'contains-lactose',
      containsTag: 'innehåller-laktos',
      freeTag: 'laktosfri',
    ),
    AllergenEntry(
      key: 'alkohol',
      triggerProperty: 'contains-alcohol',
      containsTag: 'innehåller-alkohol',
      freeTag: 'alkoholfri',
    ),
    AllergenEntry(
      key: 'kött',
      triggerProperty: 'meat',
      containsTag: 'innehåller-kött',
      // No free tag - use vegetarian instead
    ),
    AllergenEntry(
      key: 'fläsk',
      triggerProperty: 'pork',
      containsTag: 'innehåller-fläsk',
      freeTag: 'fläskfri',
    ),
    AllergenEntry(
      key: 'nötkött',
      triggerProperty: 'beef',
      containsTag: 'innehåller-nötkött',
      freeTag: 'nötköttssfri',
    ),

    // Combined allergens
    AllergenEntry(
      key: 'skaldjur',
      triggerProperty: 'crustacean OR mollusc',
      containsTag: 'innehåller-skaldjur',
      freeTag: 'skaldjursfri',
    ),
    AllergenEntry(
      key: 'nötter',
      triggerProperty: 'tree-nut OR peanut',
      containsTag: 'innehåller-nötter',
      freeTag: 'nötfri',
    ),
  ];

  /// Gets an allergen by key.
  static AllergenEntry? getByKey(String key) {
    try {
      return all.firstWhere((a) => a.key == key);
    } catch (_) {
      return null;
    }
  }

  /// Gets all EU allergens.
  static List<AllergenEntry> get euAllergens =>
      all.where((a) => a.isEuAllergen).toList();

  /// Gets all combined allergens.
  static List<AllergenEntry> get combinedAllergens =>
      all.where((a) => a.isCombined).toList();

  /// Gets all single-property allergens.
  static List<AllergenEntry> get simpleAllergens =>
      all.where((a) => !a.isCombined).toList();

  /// All allergen keys.
  static List<String> get allKeys => all.map((a) => a.key).toList();
}
