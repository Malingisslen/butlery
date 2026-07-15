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
/// Update this list when adding new properties to ingredients, and keep it in
/// lockstep with the Sheet vocabulary (PROPERTIES.csv) and the TS data-sync
/// gate (`VALID_PROPERTIES` in sync-ingredients-core.ts) — the lockstep is
/// pinned by `tag_phase1_seafood_safety_test.dart`.
library;

const Set<String> kValidIngredientProperties = {
  // Allergens (EU mandatory 14)
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
  // 'shellfish' is the meat-detail umbrella property the Sheet + TS data-sync
  // gate accept on ingredient rows (crustacean/mollusc drive the actual
  // allergen verdicts). Added 2026-07-14 (BUT-1498) so the config gate
  // recognises it too, ending the registry/CSV/TS vocabulary drift.
  'shellfish',
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
  'vegan-friendly',
  'needs-cooking',
  'doesnt-freeze-well',
  'raw-safe',
};
