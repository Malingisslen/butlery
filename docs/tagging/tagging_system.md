# Butlery Tagging System — Complete Specification

**Version:** 2.3
**Generator Version:** 1.0.0
**Schema Version:** 2
**Date:** December 2025
**Status:** Single Source of Truth for tagging and menu generation

---

## Purpose

Automatic tagging system that analyzes recipes and generates tags based on ingredient properties. Enables:

- **Safe filtering** for allergies and dietary restrictions
- **Smart menu generation** that "feels like AI without being AI"
- **Searchable recipe collection** based on time, occasion, cuisine, etc.

---

## Fundamental Principle: Tri-valued Logic

For allergen and dietary tags, we use **three states**, not two:

| State | Meaning | When Set |
|-------|---------|----------|
| **CONTAINS** | Recipe contains the allergen | At least one ingredient has the property |
| **FREE** | Recipe is proven free | 100% coverage + no ingredient has property |
| **UNKNOWN** | We don't know | Coverage < 100% OR unknown ingredient |

### Why This Is Critical

```
❌ WRONG: WHERE NOT contains_gluten    (lets UNKNOWN slip through)
✓ RIGHT: WHERE gluten_status == FREE   (only proven free recipes)
```

### Tri-valued Algebra for Combined Allergens

For allergens combining multiple properties (e.g., `nötter` = tree-nut OR peanut, `skaldjur` = crustacean OR mollusc):

#### Priority Order

```
CONTAINS > UNKNOWN > FREE
```

#### OR-logic (used for combination allergens)

| Condition A | Condition B | Result |
|-------------|-------------|--------|
| CONTAINS | * (anything) | CONTAINS |
| FREE | FREE | FREE |
| FREE | UNKNOWN | UNKNOWN |
| UNKNOWN | UNKNOWN | UNKNOWN |

**Examples:**
- Almond (tree-nut: CONTAINS) + unknown ingredient (peanut: UNKNOWN) → nötter: **CONTAINS**
- No tree nuts (tree-nut: FREE) + unknown ingredient (peanut: UNKNOWN) → nötter: **UNKNOWN**
- No tree nuts (tree-nut: FREE) + no peanuts (peanut: FREE) → nötter: **FREE**

### Coverage Requirements by Tag Type

| Tag Type | Coverage Requirement | Consequence on Uncertainty |
|----------|---------------------|---------------------------|
| Allergen (contains/free) | 100% | Set UNKNOWN |
| Dietary (vegetarian, vegan) | 100% | Set UNKNOWN |
| Protein identity | 80% | Set anyway if clear main ingredient |
| Cuisine | 60% | Set based on key ingredients |
| Practical/Mood | 60% | Set based on available info |

---

## System Architecture

```
RECIPE (raw data)
    │
    ▼
MODULE1: IngredientNormalizer
    │ "2 dl whipping cream" → "cream"
    │ "1 tbsp Japanese soy" → "soy sauce"
    ▼
Normalized ingredients: ["chicken", "cream", "pasta"]
    │
    ▼
IngredientLookupService.lookup()
    │ Fetches properties + group per ingredient
    ▼
MODULE2: TagGenerator (5 calculation phases)
    │
    ├── Phase 1: Base tags (time, allergens, dietary, protein, cooking method)
    ├── Phase 2: Simple derived (dish type, spicy/mild, meal type)
    ├── Phase 3: Complex derived (difficulty, texture, nutritional, practical)
    ├── Phase 4: Mood/occasion (time-based, holidays, seasons)
    └── Phase 5: Cuisine tags (17 world cuisines)
    │
    ▼
Output: TagResult {
  tags: ["kyckling", "krämig", "pastabaserad", "under-30-min"],
  allergenStatus: {
    gluten: CONTAINS,
    mjölk: CONTAINS,
    nötter: FREE,
    ...
  },
  dietaryStatus: {
    vegetarisk: CONTAINS,
    vegansk: CONTAINS,
    ...
  },
  coverage: 1.0,
  generatorVersion: "1.0.0"
}
```

---

## Implementation Files

| Component | File Path |
|-----------|-----------|
| TagGenerator | `lib/services/tagging/tag_generator.dart` |
| Phase 1 | `lib/services/tagging/phases/tag_phase1_base.dart` |
| Phase 2 | `lib/services/tagging/phases/tag_phase2_derived.dart` |
| Phase 3 | `lib/services/tagging/phases/tag_phase3_complex.dart` |
| Phase 4 | `lib/services/tagging/phases/tag_phase4_mood.dart` |
| Phase 5 | `lib/services/tagging/phases/tag_phase5_cuisine.dart` |
| AllergenConfig | `lib/services/tagging/config/allergen_config.dart` |
| DietaryConfig | `lib/services/tagging/config/dietary_config.dart` |
| CuisineConfig | `lib/services/tagging/config/cuisine_config.dart` |
| TagResult | `lib/models/tagging/tag_result.dart` |
| TriState | `lib/models/tagging/tri_state.dart` |
| IngredientData | `lib/models/tagging/ingredient_data.dart` |
| IngredientLookupResult | `lib/models/tagging/ingredient_lookup_result.dart` |

---

## Phase 1: Base Tags

### Time Tags

Based on `recipe.core.timeMinutes`:

| Tag | Rule |
|-----|------|
| `under-15-min` | timeMinutes ≤ 15 |
| `under-30-min` | timeMinutes ≤ 30 |
| `under-45-min` | timeMinutes ≤ 45 |
| `under-60-min` | timeMinutes ≤ 60 |
| `över-60-min` | timeMinutes > 60 |

### Allergen Status (via AllergenConfig)

#### EU Allergens (14)

| Key | Trigger Property | Contains Tag | Free Tag |
|-----|------------------|--------------|----------|
| `gluten` | `contains-gluten` | `innehåller-gluten` | `glutenfri` |
| `mjölk` | `dairy` | `innehåller-mjölk` | `mjölkfri` |
| `ägg` | `egg` | `innehåller-ägg` | `äggfri` |
| `fisk` | `fish` | `innehåller-fisk` | `fiskfri` |
| `kräftdjur` | `crustacean` | `innehåller-kräftdjur` | `kräftdjursfri` |
| `blötdjur` | `mollusc` | `innehåller-blötdjur` | `blötdjursfri` |
| `trädnötter` | `tree-nut` | `innehåller-trädnötter` | `trädnötsfri` |
| `jordnötter` | `peanut` | `innehåller-jordnötter` | `jordnötsfri` |
| `soja` | `soy` | `innehåller-soja` | `sojafri` |
| `sesam` | `sesame` | `innehåller-sesam` | `sesamfri` |
| `selleri` | `celery` | `innehåller-selleri` | `sellerifri` |
| `senap` | `mustard` | `innehåller-senap` | `senapsfri` |
| `lupin` | `lupin` | `innehåller-lupin` | `lupinfri` |
| `sulfiter` | `sulfites` | `innehåller-sulfiter` | `sulfitfri` |

#### Additional Allergens

| Key | Trigger Property | Contains Tag | Free Tag |
|-----|------------------|--------------|----------|
| `laktos` | `contains-lactose` | `innehåller-laktos` | `laktosfri` |
| `alkohol` | `contains-alcohol` | `innehåller-alkohol` | `alkoholfri` |
| `kött` | `meat` | `innehåller-kött` | — |
| `fläsk` | `pork` | `innehåller-fläsk` | `fläskfri` |
| `nötkött` | `beef` | `innehåller-nötkött` | `nötkötsfri` |

#### Combined Allergens (OR logic)

| Key | Trigger Properties | Contains Tag | Free Tag |
|-----|-------------------|--------------|----------|
| `skaldjur` | `crustacean OR mollusc` | `innehåller-skaldjur` | `skaldjursfri` |
| `nötter` | `tree-nut OR peanut` | `innehåller-nötter` | `nötfri` |

#### UI Grouping (for display)

| Group | Allergens |
|-------|-----------|
| `dairy` | mjölk, laktos |
| `nuts` | trädnötter, jordnötter, nötter |
| `seafood` | fisk, kräftdjur, blötdjur, skaldjur |
| `meat` | kött, fläsk, nötkött |

### Dietary Status (via DietaryConfig)

All require 100% coverage (`requiresFullCoverage = true`):

| Key | Excluded Properties | Required Properties |
|-----|---------------------|---------------------|
| `vegetarisk` | meat, seafood | — |
| `vegansk` | animal-product | — |
| `pescetarian` | meat | fish OR shellfish OR crustacean OR mollusc |
| `graviditetssäker` | high-mercury, contains-alcohol | — |
| `barnvänlig` | is-spicy, contains-alcohol | — |
| `halalanpassad` | pork, contains-alcohol | — |
| `kosheranpassad` | pork, shellfish, crustacean, mollusc | — |
| `nötkötsfri` | beef | — |

### Protein Tags

Based on ingredient groups and names:

| Tag | Trigger |
|-----|---------|
| `kyckling` | Group `protein/meat/poultry` + name contains "kyckling" |
| `anka` | Group `protein/meat/poultry` + name contains "anka" |
| `kalkon` | Group `protein/meat/poultry` + name contains "kalkon" |
| `nötkött` | Group `protein/meat/beef` |
| `fläskkött` | Group `protein/meat/pork` |
| `lamm` | Group `protein/meat/lamb` |
| `vilt` | Group `protein/meat/game` |
| `fisk` | Group `protein/seafood/fish` |
| `lax` | Group `protein/seafood/fish` + name contains "lax" |
| `torsk` | Group `protein/seafood/fish` + name contains "torsk" |
| `sill` | Group `protein/seafood/fish` + name contains "sill" |
| `skaldjur` | Group `protein/seafood/shellfish` |
| `räkor` | Group `protein/seafood/shellfish` + property `crustacean` + name contains "räk" |
| `tofu` | Group `protein/plant-based` + name contains "tofu" |
| `baljväxter` | Group `vegetable/legume` |
| `ägg` | Group `protein/egg` |

### Carb/Base Tags

| Tag | Trigger |
|-----|---------|
| `pastabaserad` | Name: pasta, spagetti, penne, lasagne, tagliatelle + group contains `pasta-bread` |
| `risbaserad` | Name contains "ris" + group contains `grain` |
| `potatisbaserad` | Name contains "potatis" + group contains `vegetable/root` |
| `nudelbaserad` | Name contains: nudl, wontonnudl, risnudl, glasnudl |
| `brödbaserad` | Group contains `grain/bread` OR name contains "bröd" |
| `fullkorn` | Group `grain/whole` |

### Cooking Method Tags

Uses word boundary regex matching: `(?:^|[^a-zåäö])$word`

| Tag | Keywords |
|-----|----------|
| `ugnsbakad` | "ugn" OR ("°c" OR "grader") AND NOT "mikro"/"micro" |
| `stekt` | "stek" OR "bryn" |
| `grillad` | "grill" |
| `kokt` | "koka"/"kok" OR "sjud" |
| `ångkokt` | "ångkok" OR "ånga" |
| `pocherad` | "pochera" OR "pocherad" |
| `friterad` | "fritera" OR "friterad" OR "fritering" |
| `airfryer` | exact "airfryer" or "air fryer" |
| `slow-cooker` | exact "slow cooker" or "crock pot" |
| `tryckkokare` | "tryckkokare" OR exact "instant pot" |
| `sous-vide` | exact "sous vide" or "sous-vide" |
| `wokad` | "wok" |
| `microugn` | "micro" OR "mikro" |
| `rökt` | "rök" AND NOT "röra" AND NOT "rörelse" |

### Dish Type Tags

Based on recipe title keywords:

| Tag | Keywords |
|-----|----------|
| `soppa` | soppa, buljong |
| `sallad` | sallad |
| `gryta` | gryta |
| `gratäng` | gratäng |
| `curry` | curry |
| `smörgås` | smörgås, macka |
| `hamburgare` | hamburgare, burger |
| `pizza` | pizza |
| `taco` | taco, tacos |
| `bowl` | bowl, poké, poke |
| `paj` | paj, pie, quiche |
| `kaka` | kaka, tårta (NOT if title contains "pannkak") |
| `bröd` | bröd |
| `köttbullar` | köttbull |
| `omelett` | omelett |
| `pannkaka` | pannkak, crêpe, crepe |
| `våffla` | våffl |
| `smoothie` | smoothie |
| `wok` | wok |
| `dipp` | dipp, dip |
| `sås` | sås |

---

## Phase 2: Simple Derived Tags

Depends on Phase 1 results.

### Dish Category Tags

| Tag | Rule |
|-----|------|
| `pasta-dish` | Phase 1 has `pastabaserad` |
| `rice-dish` | Phase 1 has `risbaserad` |
| `noodle-dish` | Phase 1 has `nudelbaserad` |
| `potato-dish` | Phase 1 has `potatisbaserad` |
| `bread-dish` | Phase 1 has `brödbaserad` |

### Spicy/Mild Tags

| Tag | Rule |
|-----|------|
| `stark` | Any ingredient has property `is-spicy` |
| `mild` | No ingredients have `is-spicy` AND hasFullCoverage |

### Few Ingredients

| Tag | Rule |
|-----|------|
| `få-ingredienser` | ingredient count ≤ 6 |

### Practical Tags

| Tag | Rule |
|-----|------|
| `rå` | No cooking methods AND title contains: sashimi, tartare, tartar, carpaccio, ceviche |
| `one-pot` | Phase 1 has `gryta` AND instructions contain: "en gryta", "samma kastrull", "one pot" |
| `plåtmat` | Instructions contain "plåt" OR "sheet pan" |
| `no-bake` | No cooking methods AND instructions contain: "no bake", "utan ugn", "ingen tillagning" |
| `långkokt` | time > 120 min AND (has `slow-cooker` OR `gryta`) |
| `över-natten` | Instructions contain: "över natten", "overnight", "i kylen över natten" |

### Meal Type Tags

| Tag | Rule |
|-----|------|
| `dessert` | Phase 1 has `kaka` OR title contains "dessert"/"efterrätt" |
| `frukost` | Phase 1 has `pannkaka`/`våffla` OR title contains "frukost" |
| `fika` | Phase 1 has `kaka` OR title contains "bulle"/"fika" |
| `dryck` | Phase 1 has `smoothie` OR title contains "drink" |

---

## Phase 3: Complex Derived Tags

Depends on Phase 1 + Phase 2 results.

### Difficulty Levels

| Tag | Rule |
|-----|------|
| `enkel` | ingredients ≤ 6 AND time ≤ 30 min AND NO advanced techniques |
| `medel` | Default (neither easy nor advanced) |
| `avancerad` | ingredients > 12 OR time > 60 min OR advanced techniques |

**Advanced technique keywords:** sous vide, tempera, karamellisera, flambera, emulsion, réducer, confit, creme anglaise, meringue, maräng, soufflé, rulla, vira, vik in

### Texture Tags

| Tag | Rule |
|-----|------|
| `krämig` | Creamy ingredient in **top 5** (grädde, creme, créme, kokosmjölk, mascarpone) AND (instructions contain "sås"/"rör" OR has `pastabaserad`) |
| `krispig` | Phase 1 has `friterad` OR instructions contain: krispig, frasig, knaprig |
| `ostig` | More than 1 cheese ingredient OR title contains "ost" |

### Temperature Tags

| Tag | Rule |
|-----|------|
| `kall-rätt` | Phase 2 has `rå` OR Phase 1 has `sallad` OR title contains "kall" |
| `varm-rätt` | Phase 1 has any of: ugnsbakad, stekt, kokt, grillad, gryta, soppa |

### Nutritional Tags

| Tag | Rule |
|-----|------|
| `proteinrik` | ≥ 2 protein ingredients AND protein ratio > 25% of matched |
| `fiberrik` | Phase 1 has `baljväxter`/`fullkorn` OR has group `vegetable/legume` |
| `grönsaksrik` | ≥ 3 vegetable ingredients |

### Practical Tags

| Tag | Rule |
|-----|------|
| `barnvänlig` | Phase 2 has `mild` AND alkohol is FREE AND has recognizable protein (kyckling, köttbullar, fläskkött, nötkött, fisk, ägg) |
| `frysbar` | NO property `doesnt-freeze-well` AND NOT `sallad` AND (has gryta OR soppa OR köttbullar OR pastabaserad) |
| `meal-prep` | NOT `sallad` AND NO `doesnt-freeze-well` AND portions ≥ 4 AND (has gryta OR soppa OR köttbullar OR gratäng) |
| `storkok` | portions ≥ 6 OR title contains "storkok" |

### Sustainability Tags

Based on ingredient metadata (requires 80% coverage of ingredients with data):

| Tag | Rule |
|-----|------|
| `klimatsmart` | ≥80% of ingredients with carbon data have `carbonFootprintCategory` = 'low' or 'medium' |
| `budgetvänlig` | ≥80% of ingredients with price data have `priceCategory` = 'budget' or 'medium' |

---

## Phase 4: Mood & Occasion Tags

Depends on Phase 1 + Phase 2 + Phase 3 results.

### Time-Based Occasions

| Tag | Rule |
|-----|------|
| `vardagsmiddag` | has `under-45-min` AND (enkel OR medel) |
| `helgmat` | medel OR avancerad OR time > 60 min |
| `middagsbjudning` | avancerad OR has luxury ingredients |
| `snabblagat` | has `under-15-min` AND enkel |
| `fredagsmys` | has taco OR pizza OR hamburgare OR title contains "nachos" |
| `söndagsmiddag` | time > 60 min AND (gryta OR ugnsbakad) |

### Mood Tags

| Tag | Rule |
|-----|------|
| `comfort-food` | krämig AND (pastabaserad OR potatisbaserad OR risbaserad) |
| `värmande` | soppa OR gryta |
| `fräsch` | sallad OR (kall-rätt AND has group `fruit/citrus`) |
| `lyxig` | Has luxury ingredients |

**Luxury ingredients:** oxfilé, entrecôte, hummer, kräftor, tryffel, kaviar, foie gras, wagyu, kalvfilé

### Swedish Holiday Tags

| Tag | Rule |
|-----|------|
| `jul` | Title contains "jul" OR Christmas keywords (julskinka, lutfisk, jansson, julbord) OR ≥ 2 Christmas ingredients (rödbeta, sill, julkorv, prinskorv, kål) |
| `lucia` | Title contains: lucia, lussebulle, lussekatt |
| `påsk` | Title contains "påsk" OR has `lamm` OR (has `ägg` AND title contains ägg/egg) |
| `midsommar` | Title contains "midsommar" OR (has sill AND färskpotatis/nypotatis) OR (jordgubb AND has property `dairy`) |
| `kräftskiva` | Title contains "kräftskiva"/"kräftkalas" OR ingredient contains "kräft" |
| `nyår` | Title contains "nyår" OR has luxury seafood (hummer, ostron, kaviar) |

### Season Tags

**Threshold: ≥ 2 seasonal ingredients required**

**Hybrid Detection Approach:**
1. **Primary (Field-based):** Uses `seasonAvailability` field from IngredientData when ≥2 ingredients have season data
2. **Fallback (Name-based):** Uses ingredient name matching when insufficient field data available

| Tag | Field Value / Seasonal Ingredients | Bonus Indicator |
|-----|-----------------------------------|-----------------|
| `vår` | `seasonAvailability: spring` / sparris, rabarber, rädisor, vårlök | — |
| `sommar` | `seasonAvailability: summer` / jordgubb, hallon, blåbär, sallad, gurka | `grillad` counts as +1 |
| `höst` | `seasonAvailability: fall` / svamp, kantarell, äpple, pumpa, kål | `vilt` counts as +1 |
| `vinter` | `seasonAvailability: winter` / rotfrukt, morot, palsternacka, kålrot | — |

**Note:** No automatic `året-runt` tag — absence of season tags indicates year-round suitability.

---

## Phase 5: Cuisine Tags

Depends on Phase 1-4 results and ingredient analysis.

### Detection Approach

Cuisine tags are assigned when a recipe meets the threshold (typically 2-3 key ingredients) for a specific cuisine. Uses `CuisineConfig` for declarative configuration.

### Supported Cuisines (17)

| Tag | Key Indicators | Threshold |
|-----|---------------|-----------|
| `svensk` | lingon, dill, potatis, sill | 2 ingredients |
| `italiensk` | pasta, basilika, tomat, olivolja, parmesan | 2 ingredients |
| `asiatisk` | soja, ingefära, sesamolja, risnudlar | 2 ingredients |
| `japansk` | miso, wasabi, nori, sake | 2 ingredients |
| `kinesisk` | hoisin, szechuan, five-spice | 2 ingredients |
| `thailändsk` | kokosmjölk + lime, fiskås, thai-basilika | 2 ingredients |
| `vietnamesisk` | fiskås, lime, mynta, risnudlar | 2 ingredients |
| `indisk` | garam masala, curry, koriander, gurkmeja | 2 ingredients |
| `mexikansk` | jalapeño, koriander, lime, tortilla | 2 ingredients |
| `mellanöstern` | tahini, sumak, za'atar, granatäpple | 2 ingredients |
| `grekisk` | fetaost, oregano, tzatziki, oliver | 2 ingredients |
| `fransk` | dijon, grädde, vin, timjan | 2 ingredients |
| `spansk` | saffran, chorizo, paprika, sherry | 2 ingredients |
| `amerikansk` | bbq-sås, cheddar, jalapeño, majsirap | 2 ingredients |
| `koreansk` | gochujang, kimchi, sesamolja | 2 ingredients |
| `nordafrikansk` | harissa, ras el hanout, bevarade citroner | 2 ingredients |
| `karibisk` | jerk, allspice, kokosmjölk, lime | 2 ingredients |

### Configuration

Cuisine detection is defined in `lib/services/tagging/config/cuisine_config.dart` using a declarative pattern similar to `AllergenConfig`.

---

## TagResult Model

### Core Properties

```dart
class TagResult {
  Set<String> tags;                      // All identity/category tags
  Map<String, TriState> allergenStatus;  // Allergen safety status
  Map<String, TriState> dietaryStatus;   // Dietary compatibility
  double coverage;                       // 0.0-1.0 ingredient match %
  List<String> unknownIngredients;       // Names not in database
  DateTime generatedAt;                  // Generation timestamp
  String? generatorVersion;              // Version for retagging
  String? errorReason;                   // V2: Explicit error reason for failed results
  bool isPartial;                        // True if phases were skipped due to timeout
}
```

**Schema Version:** 2 (added `errorReason` field)

### Special States

| Factory | generatorVersion | Purpose |
|---------|------------------|---------|
| `TagResult.empty()` | `'empty'` | Recipes with no ingredients |
| `TagResult.pending()` | `'pending'` | Recipes saved offline |

### Key Properties

| Property | Logic |
|----------|-------|
| `isPending` | `generatorVersion == 'pending'` |
| `hasFailed` | `generatorVersion == 'failed'` |
| `needsRetagging` | version is null OR hasFailed OR isPending OR version != kTagGeneratorVersion |

### Firestore Serialization

```json
{
  "tags": ["kyckling", "under-30-min", "stekt"],
  "allergenStatus": {
    "gluten": "FREE",
    "mjölk": "CONTAINS",
    "ägg": "UNKNOWN"
  },
  "dietaryStatus": {
    "vegetarisk": "CONTAINS",
    "vegansk": "CONTAINS"
  },
  "coverage": 1.0,
  "unknownIngredients": [],
  "generatedAt": "2025-01-15T12:00:00.000Z",
  "generatorVersion": "1.0.0"
}
```

---

## IngredientData Model

```dart
@immutable
class IngredientData {
  // Core fields
  String id;              // Kebab-case identifier (IMMUTABLE - see contract below)
  String swedish;         // Swedish name
  String english;         // English name
  String group;           // Hierarchical: "protein/meat/poultry"
  Set<String> properties; // Allergens, dietary flags
  List<String> aliasesSv; // Swedish alternatives
  List<String> aliasesEn; // English alternatives
  List<String> searchTerms;
  String status;          // verified, draft, needs-review, user-defined

  // Extended fields (Sprint 3-5)
  String? seasonAvailability;     // spring, summer, fall, winter, year-round
  String? priceCategory;          // budget, medium, premium
  String? carbonFootprintCategory; // low, medium, high
  String? originRegion;           // nordic, mediterranean, asian, etc.
  String? cuisineAffinity;        // Primary cuisine association
  bool? isOrganic;                // Organic variant flag
  String? storageType;            // refrigerated, frozen, pantry
  int? shelfLifeDays;             // Typical shelf life
}
```

### ID Immutability Contract

**CRITICAL**: The `id` field is the canonical identifier and MUST be:
- **Globally unique**: No two ingredients may share the same ID
- **Immutable**: Once assigned, an ID must NEVER change
- **Stable**: The same ingredient always has the same ID across systems

This class uses ID-only equality, which means changing an ID causes:
- Cache corruption (LRU cache uses ID as key)
- Duplicate entries in Sets
- Failed cascade retagging (TypeScript uses ID to find recipes)

### Group Hierarchy Helpers

| Property | Example |
|----------|---------|
| `topLevelGroup` | "protein" from "protein/meat/poultry" |
| `midLevelGroup` | "meat" |
| `leafGroup` | "poultry" |
| `groupDepth` | 1-3 |

---

## IngredientLookupResult Model

```dart
class IngredientLookupResult {
  List<IngredientData> matched;   // Found ingredients
  List<String> unmatched;         // Not found names
  double coverage;                // matched / total
}
```

### Key Properties

| Property | Logic |
|----------|-------|
| `hasUnknowns` | `unmatched.isNotEmpty` |
| `hasFullCoverage` | `coverage >= 1.0` |
| `totalCount` | `matched.length + unmatched.length` |

### Status Calculation

```dart
TriState getPropertyStatus(String property) {
  if (coverage < 1.0) return TriState.unknown;
  if (hasProperty(property)) return TriState.contains;
  return TriState.free;
}
```

---

## Properties Reference (33 Total)

### Diet-base (7)

| Property | Description |
|----------|-------------|
| `animal-product` | Any animal-derived ingredient |
| `dairy` | Dairy products |
| `egg` | Eggs |
| `meat` | Meat (not seafood) |
| `plant-based` | Plant-based |
| `seafood` | Fish & shellfish |
| `vegan-friendly` | Suitable for vegans |

### Meat-detail (7)

| Property | Description |
|----------|-------------|
| `beef` | Beef |
| `fish` | Fish |
| `game` | Game meat |
| `lamb` | Lamb |
| `pork` | Pork |
| `poultry` | Poultry |
| `shellfish` | Shellfish |

### Allergen (12 + combined)

| Property | EU Allergen |
|----------|-------------|
| `contains-gluten` | ✓ |
| `contains-lactose` | — |
| `peanut` | ✓ |
| `tree-nut` | ✓ |
| `sesame` | ✓ |
| `soy` | ✓ |
| `crustacean` | ✓ |
| `mollusc` | ✓ |
| `celery` | ✓ |
| `mustard` | ✓ |
| `lupin` | ✓ |
| `sulfites` | ✓ |

### Special-diet (3)

| Property | Used for |
|----------|----------|
| `contains-alcohol` | Alcohol-free, halal |
| `high-mercury` | Pregnancy-safe |
| `nightshade` | AIP-friendly |

### Practical (4)

| Property | Used for |
|----------|----------|
| `needs-cooking` | Raw tags |
| `processed` | Identification |
| `is-spicy` | Spicy, mild, kid-friendly |
| `doesnt-freeze-well` | Freezer-friendly |

---

## Group Taxonomy (61 groups)

```
protein/
├── meat/
│   ├── beef
│   ├── pork
│   ├── poultry
│   ├── lamb
│   ├── game
│   └── other
├── seafood/
│   ├── fish
│   └── shellfish
├── dairy
├── egg
└── plant-based

vegetable/
├── root
├── leaf
├── fruit-veg
├── onion-family
├── cruciferous
├── mushroom
├── legume
├── stem
└── sprout

fruit/
├── berry
├── common
├── exotic
├── citrus
├── stone
└── dried

grain/
├── whole
├── flour/
│   ├── gluten-free
│   └── gluten-containing
├── pasta-bread
├── cereal
└── bread

fat/
├── oil
└── solid

spice/
├── herb-fresh
├── herb-dry
├── ground
├── seed
├── blend
├── paste
└── other

other/
├── condiment
├── sweetener
├── baking
├── nut-seed/
│   ├── tree-nut
│   └── seed
├── beverage
├── liquid
├── dessert
└── prepared-meal
```

---

## Important Separations

### Crustacean vs Mollusc (separate EU allergens)

| Type | Property | Ingredients |
|------|----------|-------------|
| Crustacean | `crustacean` | Shrimp, crab, lobster, crayfish |
| Mollusc | `mollusc` | Mussels, oysters, squid, scallops |

### Tree Nuts vs Peanuts

| Type | Property | Ingredients |
|------|----------|-------------|
| Tree nuts | `tree-nut` | Almond, hazelnut, walnut, cashew |
| Peanuts | `peanut` | Peanut, peanut butter |

**Nötfri** = both `tree-nut-free` AND `peanut-free`

### Fish vs Shellfish

| Type | Property | Ingredients |
|------|----------|-------------|
| Fish | `fish` | Salmon, cod, herring |
| Shellfish | `crustacean`/`mollusc` | Shrimp, mussels, crab |

---

## Test Coverage

### Unit Tests (252 tests)

| File | Tests | Coverage |
|------|-------|----------|
| `tag_generator_test.dart` | 113 | All 4 phases, L1 trigger dedup |
| `tag_result_test.dart` | 41 | Serialization, equality, helpers |
| `ingredient_lookup_result_test.dart` | 37 | Group queries, TriState |
| `ingredient_lookup_service_test.dart` | 57 | Cache, variations, L3/L4 fixes |
| `ingredient_normalizer_test.dart` | 20 | Normalization, L2 color handling |
| `tri_state_test.dart` | 28 | Combination logic |
| `allergen_config_test.dart` | 13 | Config parsing |
| `dietary_config_test.dart` | 15 | Dietary config |
| `tagging_service_test.dart` | 15 | Service orchestration |
| `timeout_handling_test.dart` | 16 | Phase timeout behavior |
| `user_ingredient_merge_test.dart` | 10 | M2 user override priority |

### Integration Tests (51 tests)

| File | Tests | Coverage |
|------|-------|----------|
| `tagging_integration_test.dart` | 9 | Save → tag → store → read |
| `retagging_workflow_test.dart` | 13 | Version mismatch & retag |
| `offline_tagging_sync_test.dart` | 11 | Offline queue & sync |
| `batch_tagging_test.dart` | 7 | 100+ recipes |
| `tagging_performance_test.dart` | 11 | < 500ms benchmarks |

---

## Naming Conventions

- **Tag names:** Swedish, kebab-case: `under-15-min`, `innehåller-gluten`
- **Property names:** English, kebab-case: `contains-gluten`, `tree-nut`
- **Group paths:** English, slash-separated: `protein/meat/poultry`
- **Allergen keys:** Swedish: `gluten`, `mjölk`, `ägg`

---

## Architecture Constraints

### Single-Isolate Cache

The `IngredientLookupService` LRU cache (500 entries) is designed for single-isolate use only. Cache operations are synchronous and atomic within Dart's event loop. Do NOT use across isolates without additional synchronization.

### Swedish Character Normalization Contract

**CRITICAL**: Dart and TypeScript MUST use identical normalization for cascade retagging to work.

| Character | Normalized |
|-----------|------------|
| å | a |
| ä | a |
| ö | o |

**Implementations:**
- Dart: `lib/utils/text/swedish_character_normalizer.dart`
- TypeScript: `functions/src/ingredients/on-ingredient-soft-deleted.ts`

If these ever diverge, cascade retagging will silently fail.

### Timeout Guarantee

Phase 1 (allergen/dietary status) ALWAYS completes, even with zero timeout. This ensures safety-critical allergen data is never skipped. Phases 2-4 may be skipped if timeout exceeded, setting `isPartial=true`.

---

## Cloud Functions

| Function | Schedule | Purpose |
|----------|----------|---------|
| `cleanupDeletedIngredients` | Weekly (Mon 4 AM) | Hard-delete ingredients soft-deleted > 30 days |
| `cleanupOldAuditLogs` | Weekly (Sun 3 AM) | Delete audit logs older than retention period |
| `onIngredientSoftDeleted` | On update | Cascade retag recipes using deleted ingredient |
| `bulkMarkForRetagging` | Callable | Admin function to mark recipes for retagging |
| `trackUnmatchedIngredients` | On recipe update | Track unknown ingredients for admin analytics |
| `getUnmatchedIngredientStats` | Callable | Query top unmatched ingredients by frequency |

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Dec 2025 | Initial specification |
| 2.0 | Dec 2025 | Updated to match implementation: Swedish tag names, actual thresholds (season ≥2 ingredients, creamy top 5), UI grouping, pending/failed states, test coverage |
| 2.1 | Dec 2025 | Updated test coverage table (252 tests): added new test files for lookup service, normalizer, timeout handling; documented L1-L4 bug fix test coverage |
| 2.2 | Dec 2025 | Schema v2 with errorReason field, architecture constraints (ID immutability, single-isolate cache, normalization contract), Cloud Functions documentation, cascade timeout increased to 120s |
| 2.3 | Dec 2025 | Sprint 3-5 features: Phase 5 cuisine tags (17 cuisines), sustainability tags (klimatsmart, budgetvänlig), hybrid season detection, extended IngredientData model (8 new fields), unmatched ingredient analytics Cloud Functions |
