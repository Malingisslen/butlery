# Tagging System Update Prompt

Use this prompt when you need to update the Butlery recipe tagging system.

---

## System Overview

The tagging system automatically generates tags for recipes based on their ingredients. It uses:

- **Ingredient Database**: 2230+ ingredients with properties, groups, and aliases
- **Tag Generator**: 4-phase tag generation (base → derived → complex → mood)
- **Tri-valued Logic**: CONTAINS / FREE / UNKNOWN for allergens and dietary status

### Key Files

| Component | Location | Purpose |
|-----------|----------|---------|
| Ingredient CSV | `docs/tagging/data/Butlery_Ingredients_INGREDIENTS.csv` | Master ingredient data |
| Properties CSV | `docs/tagging/data/Butlery_Ingredients_PROPERTIES.csv` | Property definitions |
| Groups CSV | `docs/tagging/data/Butlery_Ingredients_GROUPS.csv` | Group taxonomy |
| Sync Script | `functions/src/admin/sync-ingredients.ts` | Syncs CSV → Firestore |
| Tag Generator | `lib/services/tagging/tag_generator.dart` | Generates tags from ingredients |
| Allergen Config | `lib/services/tagging/config/allergen_config.dart` | Allergen definitions |
| Dietary Config | `lib/services/tagging/config/dietary_config.dart` | Dietary status definitions |
| System Spec | `docs/tagging/tagging_system.md` | Complete specification |

### Firestore Collections

- `ingredients` - Global ingredient database (synced from CSV)
- `user_ingredients` - User-defined custom ingredients

---

## What Can Be Updated

### 1. Ingredients
Add, modify, or remove ingredients in the database.

**CSV columns:**
- `id` - Unique kebab-case identifier (e.g., `chicken-breast`)
- `swedish` - Swedish name
- `english` - English name
- `group` - Taxonomy path (e.g., `protein/meat/poultry`)
- `properties` - Comma-separated properties (e.g., `animal-product,meat,poultry`)
- `aliases_sv` - Semicolon-separated Swedish aliases
- `aliases_en` - Semicolon-separated English aliases
- `search_terms` - Additional search terms
- `status` - `validated`, `draft`, or `deleted`

**To update:** Upload new/modified rows from your Excel/CSV

### 2. Properties
Add new properties that ingredients can have.

**Current property categories:**
- Diet-base: `animal-product`, `dairy`, `egg`, `meat`, `seafood`, `plant-based`, `vegan-friendly`
- Meat-detail: `beef`, `pork`, `poultry`, `lamb`, `game`, `fish`, `shellfish`
- Allergens: `contains-gluten`, `contains-lactose`, `peanut`, `tree-nut`, `soy`, `sesame`, `crustacean`, `mollusc`, etc.
- Special: `contains-alcohol`, `is-spicy`, `needs-cooking`, `doesnt-freeze-well`

**To update:** Describe the new property and which ingredients should have it

### 3. Groups (Taxonomy)
Modify the ingredient classification hierarchy.

**Current top-level groups:**
- `protein/` (meat, seafood, dairy, egg, plant-based)
- `vegetable/` (root, leaf, legume, mushroom, etc.)
- `fruit/` (berry, citrus, stone, dried)
- `grain/` (whole, flour, pasta-bread)
- `fat/` (oil, solid)
- `spice/` (herb-fresh, herb-dry, ground, seed)
- `other/` (condiment, sweetener, baking, nut-seed, beverage)

**To update:** Describe the new group structure

### 4. Tag Rules
Modify how tags are generated in each phase.

**Phases:**
- Phase 1: Base tags (time, allergens, dietary, protein, cooking method)
- Phase 2: Derived tags (pasta-dish, spicy, pescetarian, halal-friendly)
- Phase 3: Complex tags (easy/medium/advanced, creamy, kid-friendly)
- Phase 4: Mood/occasion tags (weeknight, comfort-food, christmas)

**To update:** Describe the new tag rule or modification

### 5. Allergen/Dietary Config
Add or modify allergen and dietary status definitions.

**To update:** Describe the new allergen or dietary restriction

---

## How to Update

### Updating Ingredients (most common)

1. **Prepare your data** in Excel/CSV format with the columns listed above
2. **Upload or paste** the new/modified rows
3. I will:
   - Validate the data format
   - Update `docs/tagging/data/Butlery_Ingredients_INGREDIENTS.csv`
   - Run the sync script to push to Firestore

**Sync commands:**
```bash
cd functions
GOOGLE_APPLICATION_CREDENTIALS=service-account.json npm run sync-ingredients:dry-run  # Preview
GOOGLE_APPLICATION_CREDENTIALS=service-account.json npm run sync-ingredients -- --force  # Apply
```

### Updating Tag Rules

1. **Describe** the rule change (which phase, what triggers, what tag)
2. I will:
   - Update the relevant Dart file in `lib/services/tagging/`
   - Update tests if needed
   - Update the specification in `docs/tagging/tagging_system.md`

### Updating Properties or Groups

1. **Describe** the new property/group
2. I will:
   - Update the CSV data files
   - Update Dart config if needed
   - Sync to Firestore

---

## Instructions for Claude

When the user wants to update the tagging system:

1. **Ask what they want to update:**
   - Ingredients (add/modify/remove)?
   - Properties (new ingredient properties)?
   - Groups (taxonomy changes)?
   - Tag rules (generation logic)?
   - Allergen/dietary config?

2. **Request the appropriate data:**
   - For ingredients: Ask them to upload CSV or paste the rows
   - For properties: Ask which ingredients should have it
   - For tag rules: Ask for the trigger conditions and resulting tag
   - For config: Ask for the specific requirements

3. **Validate before applying:**
   - Check CSV format and required columns
   - Verify property/group names match existing conventions
   - Run dry-run before actual sync

4. **After updating:**
   - Run `flutter analyze` to check for errors
   - Run relevant tests: `flutter test test/unit/services/tagging/`
   - Sync to Firestore if ingredient data changed

---

## Quick Reference

**Add new ingredient:**
```csv
id,swedish,english,group,properties,aliases_sv,aliases_en,search_terms,status
new-ingredient,svenskt namn,english name,protein/meat/beef,animal-product;meat;beef,alias1;alias2,alias1;alias2,search terms,validated
```

**Property naming:** kebab-case, English (e.g., `contains-gluten`, `tree-nut`)

**Group path format:** `category/subcategory/type` (e.g., `protein/seafood/fish`)

**Allergen tri-state:** Always use CONTAINS/FREE/UNKNOWN, never boolean

---

## Start Here

What would you like to update in the tagging system?

1. **Ingredients** - Add, modify, or remove ingredients
2. **Properties** - Add new ingredient properties
3. **Groups** - Modify the ingredient taxonomy
4. **Tag Rules** - Change how tags are generated
5. **Config** - Update allergen or dietary definitions

Please specify what you'd like to update, and upload any relevant data files.
