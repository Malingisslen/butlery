/// Configuration for dietary status detection in the tagging system.
///
/// Dietary statuses use tri-valued logic:
/// - FREE: Recipe is safe for this diet (proven)
/// - CONTAINS: Recipe contains excluded ingredients
/// - UNKNOWN: Coverage < 100% or unknown ingredients
library;

/// Single dietary configuration.
class DietaryEntry {
  /// Dietary key (e.g., 'vegetarisk').
  final String key;

  /// Swedish tag name.
  final String tagSv;

  /// Properties that disqualify this diet.
  /// If recipe has ANY of these → CONTAINS.
  final List<String> excludedProperties;

  /// Properties that are required (optional).
  /// If specified, recipe must have at least one.
  final List<String>? requiredProperties;

  /// Whether this requires 100% coverage.
  final bool requiresFullCoverage;

  /// Description for UI.
  final String description;

  const DietaryEntry({
    required this.key,
    required this.tagSv,
    required this.excludedProperties,
    this.requiredProperties,
    this.requiresFullCoverage = true,
    required this.description,
  });
}

/// All configured dietary statuses.
class DietaryConfig {
  DietaryConfig._();

  /// All dietary entries.
  static const List<DietaryEntry> all = [
    DietaryEntry(
      key: 'vegetarisk',
      tagSv: 'vegetarisk',
      // Use specific properties (not 'seafood') to avoid data integrity risk:
      // an ingredient might have 'fish' but not 'seafood' in the database
      excludedProperties: ['meat', 'fish', 'crustacean', 'mollusc'],
      description: 'Ingen ingrediens har kött eller fisk/skaldjur',
    ),
    DietaryEntry(
      key: 'vegansk',
      tagSv: 'vegansk',
      excludedProperties: ['animal-product'],
      description: 'Ingen ingrediens har animaliska produkter',
    ),
    DietaryEntry(
      key: 'pescetarian',
      tagSv: 'pescetarian',
      excludedProperties: ['meat'],
      // H8: Use actual ingredient properties (not 'shellfish' which doesn't exist)
      requiredProperties: ['fish', 'crustacean', 'mollusc'],
      description: 'Ingen kött (vegetariska rätter ingår)',
    ),
    DietaryEntry(
      key: 'graviditetssäker',
      tagSv: 'graviditetssäker',
      excludedProperties: ['high-mercury', 'contains-alcohol'],
      description: 'Undvik stor rovfisk och alkohol',
    ),
    DietaryEntry(
      key: 'barnvänlig',
      tagSv: 'barnvänlig',
      excludedProperties: ['is-spicy', 'contains-alcohol'],
      description: 'Ej starkt, ej alkohol',
    ),
    DietaryEntry(
      key: 'halalanpassad',
      tagSv: 'halalanpassad',
      excludedProperties: ['pork', 'contains-alcohol'],
      description: 'Ej fläsk, ej alkohol',
    ),
    DietaryEntry(
      key: 'kosheranpassad',
      tagSv: 'kosheranpassad',
      // H8: Use actual ingredient properties (not 'shellfish' which doesn't exist)
      excludedProperties: ['pork', 'crustacean', 'mollusc'],
      description: 'Ej fläsk, ej skaldjur',
    ),
    DietaryEntry(
      key: 'nötkötsfri',
      tagSv: 'nötkötsfri',
      excludedProperties: ['beef'],
      description: 'Ej nötkött',
    ),
    DietaryEntry(
      key: 'aip-vänlig',
      tagSv: 'aip-vänlig',
      excludedProperties: [
        'nightshade',
        'contains-gluten',
        'dairy',
        'egg',
        'soy',
        'peanut',
        'tree-nut',
        'contains-alcohol',
      ],
      requiresFullCoverage: true,
      description:
          'Autoimmun protokoll - inga nattskuggväxter eller vanliga allergener',
    ),
  ];

  /// Gets a dietary entry by key.
  static DietaryEntry? getByKey(String key) {
    return all.where((d) => d.key == key).firstOrNull;
  }

  /// All dietary keys.
  static List<String> get allKeys => all.map((d) => d.key).toList();

  /// Gets entries that require full coverage.
  static List<DietaryEntry> get fullCoverageRequired =>
      all.where((d) => d.requiresFullCoverage).toList();
}
