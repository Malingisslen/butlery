/// Single source of truth for the valid ingredient-property vocabulary.
///
/// This file intentionally has ZERO imports so it can be consumed both by the
/// runtime app (via [PropertyRegistry]) and by the standalone
/// `dart scripts/migrate_tag_configs.dart` seed-generator without dragging in
/// Flutter/Firebase through the logger. Keeping one const here is what stops
/// the migration script's generated `properties.json` (seeded to the prod
/// `tag_configs/properties` doc and consumed by
/// `FirebaseTagConfig.validate()`) from drifting away from the config gate.
///
/// Update this map when adding new properties to ingredients, and keep it in
/// lockstep with the Sheet vocabulary (PROPERTIES.csv) and the TS data-sync
/// gate (`VALID_PROPERTIES` in sync-ingredients-core.ts) — the lockstep is
/// pinned by `tag_phase1_seafood_safety_test.dart`.
library;

/// The vocabulary grouped by category. Keys are stable ids that the
/// personal-tag rule dialog maps to localized labels (BUT-1618: the dialog
/// previously held its own hand-maintained copy of this vocabulary, which
/// drifted when 'wheat' was retired).
///
/// Every property appears in exactly ONE category — the partition is pinned
/// by `property_registry_test.dart`, because a property listed twice would
/// give the rule dialog's dropdown two items with the same value (a
/// DropdownButton assertion crash when editing a rule with that value).
const Map<String, List<String>> kIngredientPropertyCategories = {
  // Allergens (EU mandatory 14). Fish/crustacean/mollusc live here, not in
  // the seafood group, because they drive the allergen verdicts.
  'allergens': [
    'dairy',
    'egg',
    'fish',
    'crustacean',
    'mollusc',
    'peanut',
    'tree-nut',
    // 'wheat' retired 2026-07-14 (BUT-1498): cereal-gluten is modelled as
    // 'contains-gluten' below, and the TS data-sync gate (VALID_PROPERTIES in
    // sync-ingredients-core.ts) rejects a bare 'wheat', so no ingredient can
    // carry it. Kept out of the valid set to end the registry/CSV/TS drift.
    'contains-gluten',
    'soy',
    'sesame',
    'celery',
    'mustard',
    'lupin',
    'sulfites',
  ],

  // Lactose (separate from dairy protein)
  'lactose': ['contains-lactose'],

  // Meat types
  'meat': ['meat', 'pork', 'beef', 'poultry', 'lamb', 'game'],

  // Seafood umbrella properties (the per-species allergen properties above
  // drive the actual verdicts).
  'seafood': [
    'seafood',
    // 'shellfish' is the meat-detail umbrella property the Sheet + TS
    // data-sync gate accept on ingredient rows (crustacean/mollusc drive the
    // actual allergen verdicts). Added 2026-07-14 (BUT-1498) so the config
    // gate recognises it too, ending the registry/CSV/TS vocabulary drift.
    'shellfish',
    'high-mercury',
  ],

  // Other animal products
  'animal': ['animal-product'],

  // Diet-related
  'diet': [
    'contains-alcohol',
    'is-spicy',
    'plant-based',
    'nightshade', // Tomato, potato, peppers, eggplant, chili
  ],

  // Practical
  'other': [
    'vegan-friendly',
    'needs-cooking',
    'doesnt-freeze-well',
    'raw-safe',
  ],
};

/// Flat validity set, derived from the categorized map so the two views of
/// the vocabulary cannot drift apart. Unmodifiable: this vocabulary grounds
/// allergen verdicts, so it must not be silently mutable now that it is `final`
/// rather than a `const` literal.
final Set<String> kValidIngredientProperties = Set.unmodifiable({
  for (final properties in kIngredientPropertyCategories.values) ...properties,
});
