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

  /// UI grouping for related allergens.
  ///
  /// Used to visually group related allergens in the UI:
  /// - 'dairy': mjölk (dairy protein) and laktos (lactose sugar)
  /// - 'nuts': trädnötter, jordnötter, nötter (combined)
  /// - 'seafood': fisk, kräftdjur, blötdjur, skaldjur (combined)
  /// - 'meat': kött, fläsk, nötkött
  /// - null: standalone allergens
  final String? uiGroup;

  /// Short description explaining the allergen for UI tooltips.
  final String? description;

  const AllergenEntry({
    required this.key,
    required this.triggerProperty,
    required this.containsTag,
    this.freeTag,
    this.isEuAllergen = false,
    this.uiGroup,
    this.description,
  });

  /// Pattern for parsing OR-combined properties.
  /// Handles flexible whitespace and case insensitivity.
  static final _orPattern = RegExp(r'\s+OR\s+', caseSensitive: false);

  /// Gets the properties that trigger this allergen as a list.
  List<String> get triggerProperties {
    if (_orPattern.hasMatch(triggerProperty)) {
      return triggerProperty.split(_orPattern).map((p) => p.trim()).toList();
    }
    return [triggerProperty];
  }

  /// Whether this allergen combines multiple properties.
  bool get isCombined => _orPattern.hasMatch(triggerProperty);
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
      uiGroup: 'dairy',
      description: 'Mjölkprotein (kasein, vassle). Skiljer sig från laktos.',
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
      uiGroup: 'seafood',
    ),
    AllergenEntry(
      key: 'kräftdjur',
      triggerProperty: 'crustacean',
      containsTag: 'innehåller-kräftdjur',
      freeTag: 'kräftdjursfri',
      isEuAllergen: true,
      uiGroup: 'seafood',
    ),
    AllergenEntry(
      key: 'blötdjur',
      triggerProperty: 'mollusc',
      containsTag: 'innehåller-blötdjur',
      freeTag: 'blötdjursfri',
      isEuAllergen: true,
      uiGroup: 'seafood',
    ),
    AllergenEntry(
      key: 'trädnötter',
      triggerProperty: 'tree-nut',
      containsTag: 'innehåller-trädnötter',
      freeTag: 'trädnötsfri',
      isEuAllergen: true,
      uiGroup: 'nuts',
    ),
    AllergenEntry(
      key: 'jordnötter',
      triggerProperty: 'peanut',
      containsTag: 'innehåller-jordnötter',
      freeTag: 'jordnötsfri',
      isEuAllergen: true,
      uiGroup: 'nuts',
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
      uiGroup: 'dairy',
      description:
          'Mjölksocker. Mjölkfri ≠ laktosfri (laktosfria produkter innehåller mjölkprotein).',
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
      uiGroup: 'meat',
      // No free tag - use vegetarian instead
    ),
    AllergenEntry(
      key: 'fläsk',
      triggerProperty: 'pork',
      containsTag: 'innehåller-fläsk',
      freeTag: 'fläskfri',
      uiGroup: 'meat',
    ),
    AllergenEntry(
      key: 'nötkött',
      triggerProperty: 'beef',
      containsTag: 'innehåller-nötkött',
      freeTag: 'nötköttssfri',
      uiGroup: 'meat',
    ),

    // Combined allergens
    AllergenEntry(
      key: 'skaldjur',
      triggerProperty: 'crustacean OR mollusc',
      containsTag: 'innehåller-skaldjur',
      freeTag: 'skaldjursfri',
      uiGroup: 'seafood',
    ),
    AllergenEntry(
      key: 'nötter',
      triggerProperty: 'tree-nut OR peanut',
      containsTag: 'innehåller-nötter',
      freeTag: 'nötfri',
      uiGroup: 'nuts',
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

  /// Gets allergens by UI group.
  ///
  /// Useful for grouping related allergens in the UI.
  /// Example: 'dairy' returns [mjölk, laktos]
  static List<AllergenEntry> getByUiGroup(String group) =>
      all.where((a) => a.uiGroup == group).toList();

  /// Gets all unique UI groups.
  static List<String> get allUiGroups =>
      all.map((a) => a.uiGroup).whereType<String>().toSet().toList();

  /// UI group display names in Swedish.
  static const Map<String, String> uiGroupNames = {
    'dairy': 'Mjölk & Laktos',
    'nuts': 'Nötter',
    'seafood': 'Fisk & Skaldjur',
    'meat': 'Kött',
  };
}
