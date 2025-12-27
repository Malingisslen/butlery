# Butlery Tagging System — Complete Specification

**Version:** 1
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

For allergens combining multiple properties (e.g., `nuts` = tree-nut OR peanut, `shellfish` = crustacean OR mollusc), the following calculation rules apply:

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
- Almond (tree-nut: CONTAINS) + unknown ingredient (peanut: UNKNOWN) → nuts: **CONTAINS**
- No tree nuts (tree-nut: FREE) + unknown ingredient (peanut: UNKNOWN) → nuts: **UNKNOWN**
- No tree nuts (tree-nut: FREE) + no peanuts (peanut: FREE) → nuts: **FREE**

#### AND-logic (used for dietary status)

| Condition A | Condition B | Result |
|-------------|-------------|--------|
| FREE | FREE | FREE |
| FREE | UNKNOWN | UNKNOWN |
| FREE | CONTAINS | CONTAINS |
| UNKNOWN | UNKNOWN | UNKNOWN |
| CONTAINS | * (anything) | CONTAINS |

**Implementation requirement:** Tri-valued logic must be implemented explicitly — never use boolean-cast that treats UNKNOWN as false.

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
IngredientService.lookup()
    │ Fetches properties + group per ingredient
    ▼
MODULE2: TagGenerator (4 calculation phases)
    │
    ▼
Output: {
  tags: ["contains-meat", "creamy", "pasta-dish", "italian"],
  allergenStatus: {
    gluten: CONTAINS,
    dairy: CONTAINS,
    nuts: FREE,
    ...
  },
  coverage: 1.0
}
```

---

## Two Types of Knowledge

### Type A: "What does this recipe contain?" (Safety-critical)

- Based on ingredient **properties**
- Uses tri-valued logic
- **Errors can make someone sick**
- Examples: `contains-gluten`, `gluten-free`, `vegan`

### Type B: "What kind of dish is this?" (Identity)

- Based on ingredient **groups** + keywords + derivation
- Binary logic (tag exists or doesn't)
- **Errors give weird menu, not health risk**
- Examples: `chicken`, `italian`, `comfort-food`

---

## Properties (Ingredient Characteristics)

Properties describe what an ingredient **contains or is**. They are stored on the ingredient and inherited to the recipe.

### Current Properties in Database (33 total)

#### Diet-base (7)
| Property | Swedish | Used for Tag |
|----------|---------|--------------|
| `animal-product` | Animal product | vegan |
| `dairy` | Dairy | dairy-free |
| `egg` | Egg | egg-free |
| `meat` | Meat | vegetarian |
| `plant-based` | Plant-based | (identification) |
| `seafood` | Fish & shellfish | vegetarian |
| `vegan-friendly` | Vegan | (identification) |

#### Meat-detail (7)
| Property | Swedish | Used for Tag |
|----------|---------|--------------|
| `beef` | Beef | beef |
| `fish` | Fish | fish, fish-free |
| `game` | Game | game |
| `lamb` | Lamb | lamb |
| `pork` | Pork | pork-free, halal |
| `poultry` | Poultry | chicken, duck |
| `shellfish` | Shellfish | shellfish |

#### Allergen (12)
| Property | Swedish | EU Allergen | Used for Tag |
|----------|---------|-------------|--------------|
| `contains-gluten` | Contains gluten | ✓ | gluten-free |
| `contains-lactose` | Contains lactose | — | lactose-free |
| `peanut` | Peanut | ✓ | peanut-free |
| `tree-nut` | Tree nut | ✓ | tree-nut-free, nut-free |
| `sesame` | Sesame | ✓ | sesame-free |
| `soy` | Soy | ✓ | soy-free |
| `crustacean` | Crustacean | ✓ | crustacean-free |
| `mollusc` | Mollusc | ✓ | mollusc-free |
| `celery` | Celery | ✓ | celery-free |
| `mustard` | Mustard | ✓ | mustard-free |
| `lupin` | Lupin | ✓ | lupin-free |
| `sulfites` | Sulfites | ✓ | sulfite-free |

#### Special-diet (3)
| Property | Swedish | Used for |
|----------|---------|----------|
| `contains-alcohol` | Alcohol | alcohol-free, halal |
| `high-mercury` | High mercury | pregnancy-safe |
| `nightshade` | Nightshade | AIP-friendly |

#### Practical (4)
| Property | Swedish | Used for |
|----------|---------|----------|
| `needs-cooking` | Must be cooked | raw tags |
| `processed` | Processed product | (identification) |
| `is-spicy` | Spicy/hot | spicy, mild, kid-friendly |
| `doesnt-freeze-well` | Freezes poorly | freezer-friendly |

### Properties to Add (Target)

| Property | Description | Priority |
|----------|-------------|----------|
| `high-fodmap` | High FODMAP (garlic, onion) | Medium — IBS filtering |
| `spring-seasonal` | Spring season (asparagus, rhubarb) | Medium — seasonal adaptation |
| `summer-seasonal` | Summer season (strawberries, new potatoes) | Medium |
| `autumn-seasonal` | Autumn season (mushrooms, apples) | Medium |
| `winter-seasonal` | Winter season (cabbage, root vegetables) | Medium |
| `premium-ingredient` | Luxury (beef tenderloin, lobster) | Low — dinner party |
| `pantry-staple` | Basic ingredient (salt, oil) | Low — can ignore in coverage |

---

## Groups (Ingredient Taxonomy)

Groups describe what an ingredient **is** in a hierarchical structure. Used to identify the dish's character.

### Group Structure (61 groups, 3 levels)

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

### Group → Tag Mapping

| Group Pattern | Generates Tag |
|---------------|---------------|
| `protein/meat/beef` | `beef` |
| `protein/meat/pork` | `pork` |
| `protein/meat/poultry` | `chicken` (if chicken), `duck` (if duck) |
| `protein/meat/lamb` | `lamb` |
| `protein/meat/game` | `game` |
| `protein/seafood/fish` | `fish` + specific (`salmon`, `cod`, `herring`) |
| `protein/seafood/shellfish` | `shellfish` |
| `protein/plant-based` | `tofu`, `legumes` |
| `grain/pasta-bread` | `pasta-based` (if pasta), `bread-based` (if bread) |
| `grain/*` + rice | `rice-based` |
| `vegetable/root` + potato | `potato-based` |

---

## Tags

### Calculation Phases

Tags are generated in four phases where each phase can depend on previous phases' results:

| Phase | Count | Source | Dependencies |
|-------|-------|--------|--------------|
| Phase 1 | ~100 | Properties, groups, metadata | None |
| Phase 2 | ~20 | Combinations of Phase 1 | Phase 1 |
| Phase 3 | ~20 | Complex rules | Phase 1 + 2 |
| Phase 4 | ~25 | Mood/occasion | Phase 1 + 2 + 3 |

---

### Phase 1: Base Tags

#### Time (5)
Based on recipe's `totalTime` metadata.

| Tag | Rule |
|-----|------|
| `under-15-min` | totalTime ≤ 15 |
| `under-30-min` | totalTime ≤ 30 |
| `under-45-min` | totalTime ≤ 45 |
| `under-60-min` | totalTime ≤ 60 |
| `over-60-min` | totalTime > 60 |

#### Allergen Status (14 allergens × 2 states = potentially 28, but stored as status)

For each allergen, a **status** (CONTAINS/FREE/UNKNOWN) is stored, not separate tags.

| Allergen | Property | Contains Tag | Free Tag |
|----------|----------|--------------|----------|
| Gluten | `contains-gluten` | `contains-gluten` | `gluten-free` |
| Lactose | `contains-lactose` | `contains-lactose` | `lactose-free` |
| Dairy | `dairy` | `contains-dairy` | `dairy-free` |
| Egg | `egg` | `contains-egg` | `egg-free` |
| Tree nuts | `tree-nut` | `contains-tree-nuts` | `tree-nut-free` |
| Peanuts | `peanut` | `contains-peanuts` | `peanut-free` |
| Nuts (both) | `tree-nut` OR `peanut` | `contains-nuts` | `nut-free` |
| Fish | `fish` | `contains-fish` | `fish-free` |
| Crustacean | `crustacean` | `contains-crustacean` | `crustacean-free` |
| Mollusc | `mollusc` | `contains-mollusc` | `mollusc-free` |
| Shellfish (all) | `crustacean` OR `mollusc` | `contains-shellfish` | `shellfish-free` |
| Soy | `soy` | `contains-soy` | `soy-free` |
| Sesame | `sesame` | `contains-sesame` | `sesame-free` |
| Celery | `celery` | `contains-celery` | `celery-free` |
| Mustard | `mustard` | `contains-mustard` | `mustard-free` |
| Lupin | `lupin` | `contains-lupin` | `lupin-free` |
| Sulfites | `sulfites` | `contains-sulfites` | `sulfite-free` |
| Alcohol | `contains-alcohol` | `contains-alcohol` | `alcohol-free` |
| Meat | `meat` | `contains-meat` | — |
| Pork | `pork` | `contains-pork` | `pork-free` |

#### Dietary (calculated from properties)

| Tag | Rule (all require 100% coverage) |
|-----|----------------------------------|
| `vegetarian` | No ingredient has `meat` or `seafood` |
| `vegan` | No ingredient has `animal-product` |

**Note:** `pescetarian` exists both as **dietary-status** (in DietaryConfig, for safe filtering) and as **identity tag** (in Phase 2, for categorization). See "Pescetarian: Status vs Tag" below.

#### Pescetarian: Status vs Tag

Pescetarian is handled in two ways with different purposes:

| Context | Purpose | Logic | Coverage Requirement |
|---------|---------|-------|---------------------|
| **DietaryConfig** | Filtering ("is this pescetarian-safe?") | No `meat` + at least one `fish` or `shellfish` | 100% |
| **Tags_Phase2** | Identification ("is this a pescetarian dish?") | `vegetarian` == false AND (`fish` == true OR `shellfish` == true) AND `meat` == false | No |

DietaryConfig gives a **status** (TRUE/FALSE) used for safe filtering.
Tags_Phase2 gives a **tag** used for categorization and search.

#### Protein (based on groups)

| Tag | Triggered by Group |
|-----|--------------------|
| `chicken` | `protein/meat/poultry` + swedish/english contains "kyckling"/"chicken" |
| `duck` | `protein/meat/poultry` + swedish/english contains "anka"/"duck" |
| `beef` | `protein/meat/beef` |
| `pork` | `protein/meat/pork` |
| `lamb` | `protein/meat/lamb` |
| `game` | `protein/meat/game` |
| `fish` | `protein/seafood/fish` |
| `salmon` | `protein/seafood/fish` + swedish contains "lax" |
| `cod` | `protein/seafood/fish` + swedish contains "torsk" |
| `herring` | `protein/seafood/fish` + swedish contains "sill" |
| `shrimp` | `protein/seafood/shellfish` + `crustacean` + swedish contains "räk" |
| `shellfish` | `protein/seafood/shellfish` |
| `tofu` | `protein/plant-based` + swedish contains "tofu" |
| `legumes` | `vegetable/legume` |
| `egg` | `protein/egg` (as main protein, not just ingredient) |

#### Base/Carb (based on groups + amount)

| Tag | Rule |
|-----|------|
| `pasta-based` | Contains pasta as main ingredient |
| `rice-based` | Contains rice as main ingredient |
| `potato-based` | Contains potato as main ingredient |
| `noodle-based` | Contains noodles as main ingredient |
| `bread-based` | Contains bread as main ingredient |
| `whole-grain` | Main carb has group `grain/whole` |

#### Cooking Method (based on keywords in instructions)

| Tag | Keywords |
|-----|----------|
| `oven-baked` | "ugn", "oven", "degrees", "°C" (not "micro") |
| `pan-fried` | "stek", "fry", "sear", "brown" |
| `grilled` | "grill", "grilla" |
| `boiled` | "koka", "boil", "simmer" |
| `steamed` | "ångkok", "steam" |
| `poached` | "pochera", "poach" |
| `deep-fried` | "fritera", "deep fry" |
| `airfryer` | "airfryer", "air fryer" |
| `slow-cooker` | "slow cooker", "crock pot", "långkok" (appliance) |
| `pressure-cooker` | "tryckkokare", "instant pot" |
| `sous-vide` | "sous vide", "sous-vide" |
| `wok` | "wok", "woka" |
| `microwave` | "micro", "mikro" |
| `smoked` | "rök", "smoke" |
| `raw` | No cooking words + right type (sashimi, tartare, carpaccio) |

#### Dish Type (based on title + keywords)

| Tag | Keywords in title/instructions |
|-----|-------------------------------|
| `soup` | "soppa", "soup", "broth" |
| `salad` | "sallad", "salad" |
| `stew` | "gryta", "stew" |
| `gratin` | "gratäng", "gratin" |
| `curry` | "curry" |
| `sandwich` | "smörgås", "sandwich", "macka" |
| `burger` | "hamburgare", "burger" |
| `pizza` | "pizza" |
| `taco` | "taco", "tacos" |
| `bowl` | "bowl", "poké" |
| `pie` | "paj", "pie", "quiche" |
| `cake` | "kaka", "cake", "tårta" (not pancake) |
| `bread` | "bröd", "bread" (as end product) |
| `meatballs` | "köttbull", "meatball" |
| `omelet` | "omelett", "omelet" |
| `pancake` | "pannkak", "crêpe", "pancake" |
| `waffle` | "våffl", "waffle" |
| `smoothie` | "smoothie" |
| `wok` | "wok" (as dish type) |
| `dip` | "dipp", "dip" |
| `sauce` | "sås", "sauce" (as end product) |

#### Cuisine (based on ingredient combinations + keywords)

| Tag | Positive Triggers | Negative Triggers |
|-----|-------------------|-------------------|
| `swedish` | **Title:** "jansson", "raggmunk", "pyttipanna", "ärtsoppa", "pannbiff", "wallenbergare" **OR Ingredient:** meatballs, falukorv, lingonberry, potato + cream + dill | soy sauce, taco, wok |
| `italian` | pasta + (tomato OR parmesan OR basil), risotto, pizza | soy sauce, ginger |
| `mexican` | taco, jalapeño, lime + cilantro, tortilla | soy sauce, pasta |
| `thai` | coconut milk + lime + chili, fish sauce, Thai basil | parmesan |
| `indian` | garam masala, curry + coconut milk, naan | soy sauce, pasta |
| `chinese` | soy sauce + ginger, sesame oil, wok-style | parmesan, pasta |
| `japanese` | soy sauce + mirin + dashi, wasabi, nori | parmesan |
| `korean` | gochujang, kimchi, sesame oil + soy sauce | parmesan, pasta |
| `vietnamese` | fish sauce + lime, rice noodles, fresh herbs | parmesan |
| `greek` | feta + olives + cucumber, tzatziki | soy sauce |
| `mediterranean` | olive oil + garlic + tomato, herbs | soy sauce, cream |
| `middle-eastern` | tahini, pomegranate, cumin | soy sauce |
| `french` | cream + wine + thyme, Dijon mustard | soy sauce |
| `spanish` | chorizo, paprika, saffron, olives | soy sauce |
| `american` | BBQ, bacon, cheddar, ranch | — |
| `nordic` | dill + gravad, lingonberry, Nordic berries | soy sauce, chili |
| `asian` | Umbrella: soy sauce OR ginger OR sesame oil | parmesan, cream |

#### Cuisine Prioritization on Overlap

A dish gets max 2 cuisine tags. On conflict, prioritize:

1. **Specific > General** — e.g., `japanese` before `asian`
2. **Title match > Ingredient match** — if recipe title contains cuisine keyword
3. **More positive triggers > fewer** — count matching triggers

**Examples:**
- Recipe with soy sauce + mirin + dashi → `japanese` (specific), not `asian` (general)
- Recipe with pasta + tomato + garlic + olive oil → `italian` + `mediterranean` (both match, max 2)
- Recipe with soy sauce + pasta → Conflict! Choose based on title or dominant ingredients

---

### Phase 2: Simple Derived (requires Phase 1)

| Tag | Rule |
|-----|------|
| `pasta-dish` | `pasta-based` = true |
| `rice-dish` | `rice-based` = true |
| `noodle-dish` | `noodle-based` = true |
| `raw` | No cooking method + (sashimi OR tartare OR carpaccio in title) |
| `one-pot` | `stew` = true AND all ingredients cooked together |
| `sheet-pan` | "plåt" in instructions OR "sheet pan" |
| `no-bake` | No oven, no stove, no cooking |
| `slow-cooked` | totalTime > 120 AND (`slow-cooker` OR `stew`) |
| `overnight` | "över natten", "overnight" in instructions |
| `low-effort` | Active time < 15 min (if available) |
| `few-ingredients` | Ingredient count ≤ 6 (excl. pantry staples) |
| `spicy` | Contains `is-spicy` ingredient (chili, jalapeño, cayenne) |
| `mild` | No `is-spicy` ingredients |
| `dessert` | `cake` OR `tårta` OR dessert category |
| `breakfast` | `pancake` OR `waffle` OR breakfast keywords |
| `fika` | `cake` OR fika keywords (bulle, kaka) |
| `drink` | `smoothie` OR drink keywords |
| `pescetarian` | `vegetarian` = false AND (`fish` = true OR `shellfish` = true) AND `meat` = false |
| `halal-friendly` | `pork-free` = true AND `alcohol-free` = true |

**Note:** Tags `spicy`, `mild` require ingredients to have `is-spicy` property set.

---

### Phase 3: Complex Derived (requires Phase 1 + 2)

| Tag | Rule |
|-----|------|
| `easy` | ≤6 ingredients AND ≤30 min AND simple techniques |
| `medium` | 7-12 ingredients OR 30-60 min OR medium techniques |
| `advanced` | >12 ingredients OR >60 min OR advanced techniques |
| `creamy` | cream OR crème fraiche OR coconut milk + sauce/pasta |
| `crispy` | `deep-fried` OR "crispy" in instructions |
| `cheesy` | Cheese as main ingredient (≥100g or prominent) |
| `cold-dish` | No heat treatment, served cold |
| `hot-dish` | Heat treatment, served hot |
| `veggie-rich` | ≥3 vegetables as main ingredients |
| `herby` | ≥2 fresh herbs |
| `high-protein` | Protein ingredient ≥200g per serving |
| `high-fiber` | Legumes OR whole grain as base |
| `kid-friendly` | `mild` = true AND recognizable protein AND no bitter vegetables |
| `meal-prep-friendly` | Keeps well, easy to reheat, not salad |
| `freezer-friendly` | No ingredients with `doesnt-freeze-well` |
| `batch-cooking` | Servings ≥6 OR "storkok" in title |

**Note:** Tags `kid-friendly` and `freezer-friendly` require ingredients to have respective property (`is-spicy`, `doesnt-freeze-well`) set.

---

### Phase 4: Mood/Occasion (requires Phase 1 + 2 + 3)

| Tag | Rule |
|-----|------|
| `weeknight` | `under-45-min` AND `easy/medium` AND common ingredients |
| `weekend` | `medium/advanced` OR longer cooking time |
| `dinner-party` | `advanced` OR luxury ingredients OR impressive presentation |
| `comfort-food` | `creamy` AND (pasta OR potato OR rice) |
| `warming` | `soup` OR `stew` OR hot + spiced |
| `refreshing` | `salad` OR cold + citrus/cucumber |
| `quick-fix` | `under-15-min` AND `easy` |
| `luxurious` | Premium ingredients (beef tenderloin, lobster, truffle) |
| `friday-night` | `taco` OR `pizza` OR `burger` OR `nachos` |
| `christmas` | **Title:** "jul" **OR Ingredient:** (julskinka OR ribs OR jansson OR lutfisk) + (beet salad OR kale OR Christmas mustard) |
| `lucia` | **Title:** "lucia", "lussebulle", "lussekatt" **OR Ingredient:** saffron + (bun OR bread) |
| `easter` | **Title:** "påsk" **OR Ingredient:** (lamb OR egg as main) + (egg half OR herring) |
| `midsummer` | **Title:** "midsommar" **OR Ingredient:** (herring + new potatoes) OR (strawberries + cream) |
| `crayfish-party` | **Title:** "kräftskiva", "kräftkalas" **OR Ingredient:** crayfish as main ingredient |
| `new-years` | **Title:** "nyår" **OR** luxury ingredients (lobster, oysters, caviar) + festive context |
| `sunday-dinner` | Longer cooking + traditional |
| `spring` | Spring ingredients (asparagus, rhubarb, new vegetables) |
| `summer` | Summer ingredients (strawberries, grilled, salads) |
| `autumn` | Autumn ingredients (mushrooms, apples, cabbage, game) |
| `winter` | Winter ingredients (root vegetables, cabbage, slow-cooked) |
| `year-round` | No season-dependent main ingredients |

---

## Important Separations

### Crustacean vs Mollusc (separate EU allergens)

These are **separate allergens** per EU legislation and must never be mixed:

| Type | Property | Ingredients |
|------|----------|-------------|
| Crustacean | `crustacean` | Shrimp, crab, lobster, crayfish, langoustine |
| Mollusc | `mollusc` | Mussels, oysters, squid, snails, scallops |

A recipe with mussels should have:
- `contains-mollusc` = CONTAINS
- `mollusc-free` = CONTAINS (it contains mollusc)
- `contains-crustacean` = FREE (if no crustaceans)
- `crustacean-free` = FREE

### Tree Nuts vs Peanuts

| Type | Property | Ingredients |
|------|----------|-------------|
| Tree nuts | `tree-nut` | Almond, hazelnut, walnut, cashew, pistachio, macadamia |
| Peanuts | `peanut` | Peanut, peanut butter (NOTE: biologically a legume) |

**Nut-free** = both `tree-nut-free` AND `peanut-free`

### Fish vs Shellfish

| Type | Property | Ingredients |
|------|----------|-------------|
| Fish | `fish` | Salmon, cod, herring, mackerel, tuna |
| Shellfish | `shellfish` (or `crustacean`/`mollusc`) | Shrimp, mussels, crab |

**Seafood** = fish OR shellfish, but they are separate allergens.

---

## Database Structure

### Ingredient

```json
{
  "id": "chicken-breast",
  "swedish": "kycklingbröst",
  "english": "chicken breast",
  "group": "protein/meat/poultry",
  "properties": ["animal-product", "meat", "poultry", "needs-cooking"],
  "aliases_sv": ["kycklingfilé", "kyckling"],
  "aliases_en": ["chicken fillet"],
  "status": "verified"
}
```

### Property

```json
{
  "id": "contains-gluten",
  "name_sv": "Innehåller gluten",
  "name_en": "Contains Gluten",
  "category": "allergen",
  "excludes_tags": ["gluten-free"]
}
```

### Group

```json
{
  "path": "protein/meat/poultry",
  "name_sv": "Fjäderfä",
  "name_en": "Poultry",
  "parent": "protein/meat",
  "level": 3
}
```

### TagResult (output from TagGenerator)

```json
{
  "tags": ["chicken", "creamy", "pasta-dish", "italian", "under-30-min"],
  "allergenStatus": {
    "gluten": "CONTAINS",
    "dairy": "CONTAINS",
    "egg": "FREE",
    "peanut": "FREE",
    "tree-nut": "FREE",
    "fish": "FREE",
    "crustacean": "FREE",
    "mollusc": "FREE",
    "soy": "FREE",
    "sesame": "FREE",
    "celery": "FREE",
    "mustard": "FREE",
    "lupin": "FREE",
    "sulfites": "FREE",
    "alcohol": "FREE",
    "pork": "FREE"
  },
  "dietaryStatus": {
    "vegetarian": "CONTAINS",
    "vegan": "CONTAINS",
    "lactose-free": "CONTAINS",
    "dairy-free": "CONTAINS"
  },
  "coverage": 1.0,
  "unknownIngredients": []
}
```

---

## Menu Generation

### Matching Logic Three Layers

**Layer 1: Hard Requirements (must be met)**
- Allergies: `allergenStatus[X] == FREE`
- Dietary restrictions: `dietaryStatus[X] == FREE`
- Explicitly stated requirements

**Layer 2: Soft Preferences (scored)**
- Seasonal adaptation
- Variation from history
- Day adaptation (weekday/weekend)

**Layer 3: Balancing (weekly optimization)**
- Max 2 of same cuisine per week
- Max 2 of same protein per week
- Variation in cooking method

### Constraint Relaxation (fallback when 0 candidates)

| Priority | Release | Communication |
|----------|---------|---------------|
| 1 | Variation in cooking method | Silent |
| 2 | Seasonal preference | Silent |
| 3 | Variation in cuisine | "Got a bit more [X] this week" |
| 4 | Variation in protein | "Got a bit more [Y] this week" |
| 5 | Time constraint (+15 min) | "Couldn't find anything under X min" |

**Never release:** Allergy filters, diet type filters

---

## Test Cases

| # | Scenario | Input | Expected Result |
|---|----------|-------|-----------------|
| 1 | Almond, no peanuts | Recipe with almond | `tree-nut`: CONTAINS, `peanut`: FREE |
| 2 | Mussels, no shrimp | Recipe with mussels | `mollusc`: CONTAINS, `crustacean`: FREE |
| 3 | Salmon + vegetables | Salmon recipe | `vegetarian`: CONTAINS, `pescetarian` ✓ |
| 4 | 50% unknown ingredients | 5 of 10 known | All allergen status: UNKNOWN |
| 5 | Pasta + soy sauce | Fusion recipe | Max one of `italian`/`asian` |
| 6 | Pure vegetarian | No animal products | `vegetarian`: FREE, `meat`: FREE |
| 7 | Cream in recipe | Cream sauce | `dairy`: CONTAINS, `lactose`: CONTAINS |
| 8 | Lactose-free cream | Lactose-free cream sauce | `dairy`: CONTAINS, `lactose`: FREE |

---

## Naming Conventions

- **Tag names:** Swedish, kebab-case, lowercase: `under-15-min`, `innehåller-gluten`
- **English exceptions:** Where Swedish term is missing: `comfort-food`, `bowl`
- **Property names:** English, kebab-case: `contains-gluten`, `tree-nut`
- **Group paths:** English, slash-separated: `protein/meat/poultry`

---

## Document History

| Version | Date | Changes |
|---------|------|---------|