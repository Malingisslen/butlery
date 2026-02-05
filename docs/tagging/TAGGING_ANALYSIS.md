# Tagging System Analysis

Full analysis of the automatic recipe tagging system. Covers why tagging may not be working, identified bugs, architectural issues, and improvement recommendations.

## System Overview

The tagging system has two subsystems:

1. **Auto-generated tags** (`TagResult`) - 5-phase generation engine analyzing ingredients, instructions, and metadata to produce allergen/dietary/category tags
2. **Personal tags** (`PersonalTag`) - User-defined tags with rule-based automation

The auto-tagging pipeline:
```
Raw ingredient strings
  -> IngredientParser (extract name from "2 dl hackad lök")
  -> IngredientNormalizer (remove adjectives, normalize plurals)
  -> SwedishCharacterNormalizer (å->a, ä->a, ö->o)
  -> IngredientLookupService (match against ~2230 ingredients in Firestore)
  -> TagGenerator 5-phase pipeline
  -> TagResult stored on recipe document
```

---

## Part 1: Why Tagging May Not Be Working

### Theory 1: Ingredient Database Coverage Gap (HIGH LIKELIHOOD)

The ingredient database has ~2230 entries. For a Swedish recipe app, this is relatively small. The tagging system's TriState logic means:

- **If even ONE ingredient is unmatched** -> coverage < 100% -> ALL allergen/dietary statuses become `UNKNOWN`
- **If ALL ingredients are unmatched** -> `TagResult.allUnknown()` with zero tags

This is the most likely failure mode. Common Swedish ingredient strings that recipes contain (e.g., "1 msk olivolja", "salt och peppar", "kryddmått kanel") must pass through parsing -> normalization -> lookup. Any failure in this pipeline produces an unmatched ingredient, which degrades the entire result.

**Evidence in code** (`ingredient_lookup_result.dart:114-122`):
```dart
TriState getPropertyStatus(String property) {
  if (coverage < 1.0) {  // <-- ANY unknown = all UNKNOWN
    return TriState.unknown;
  }
  ...
}
```

**Impact**: A recipe with 10 ingredients where 9 match but "salt och peppar" doesn't match -> 90% coverage -> all allergen statuses UNKNOWN -> all dietary statuses UNKNOWN. The only tags generated would be time tags, cooking method tags, and dish type tags (from title/instructions), but NO allergen, dietary, or protein tags.

### Theory 2: SwedishCharacterNormalizer Double Application (MEDIUM LIKELIHOOD)

Swedish characters are normalized at multiple points:

1. `IngredientLookupService._cleanForLookup()` calls `SwedishCharacterNormalizer.normalize()` which converts å->a, ä->a, ö->o
2. `FirebaseIngredientRepository._normalize()` also does the same conversion (plus é->e, ü->u, ñ->n)
3. The ingredient database in Firestore stores the ORIGINAL Swedish names ("kycklingbröst", not "kycklingbrost")

The repository's `findByName()` normalizes both the query AND the index keys. But `IngredientLookupService` normalizes the query BEFORE passing it to the repository. If the repository's normalization is applied on top, this should still work. However, the `_generateLookupVariations()` method works on the ALREADY-normalized (diacritics-removed) string. Variations like "kott" for "kött" will be generated, but the compound suffix list still uses Swedish characters ("bröst", "filé"), which will never match against the normalized input "brost", "file".

**Evidence** (`ingredient_lookup_service.dart:34-55`): The `_compoundSuffixes` list contains Swedish characters like "bröst", "filé", "mjölk", "grädde". But `_cleanForLookup()` at line 350-358 normalizes Swedish chars first. So the input will be "brost", "file", "mjolk", "gradde" - which will never match the suffixes.

**Impact**: Compound word variation generation is broken for any word containing å, ä, or ö. Lookups for "kycklingbrost" will fail the compound suffix check for "bröst" because the input has been normalized to ASCII.

### Theory 3: IngredientNormalizer Strips Too Aggressively (MEDIUM LIKELIHOOD)

The normalizer removes preparation words, size descriptors, type descriptors, and color descriptors. It also tries to extract base ingredients from compounds (e.g., "tomatsås" -> "tomat"). The issue: it may over-normalize.

Examples of problematic cases:
- "créme fraîche" - The normalizer may struggle with non-Swedish accented characters
- "salt och peppar" as a single ingredient string - `IngredientParser` doesn't split on "och"
- "2 st vitlöksklyftor" - Parser extracts "vitlöksklyftor", normalizer tries to split compound, but if "vitlök" isn't matched via the compound ending "klyftor" + base, it remains as-is

### Theory 4: `ingredientsNormalized` Field Is Null (HIGH LIKELIHOOD)

`TaggingService.generateTags()` at line 73-74:
```dart
final ingredients =
    recipe.core.ingredientsNormalized ?? recipe.core.ingredients;
```

If `ingredientsNormalized` is null (which it will be for any recipe that hasn't been through the normalization pipeline), the RAW ingredient strings like "2 dl hackad gul lök" are passed directly. These then go through `lookupFromRaw()` which does parse and normalize them, but the parsing of raw strings is more error-prone than pre-normalized strings.

The question is whether `ingredientsNormalized` is populated before tagging runs. Looking at `personal_recipe_module.dart`, tagging is applied at line 164 - but normalization of ingredients may not have happened yet if it depends on a separate processing step.

### Theory 5: TagConfigService Firebase Config Not Loaded (MEDIUM LIKELIHOOD)

`TaggingService` takes an optional `TagConfigService`. The `TagGenerator` uses `tagConfigService?.configOrNull` which means if the config service hasn't loaded yet, `firebaseConfig` will be null. This causes Phase 1 to fall back to static configs, which should still work, but the static configs may be outdated or incomplete compared to Firebase configs.

**Evidence** (`tag_phase1_base.dart:165-170`):
```dart
} else {
  // HIGH-2: Log warning when falling back to static config
  AppLogger.warning(
    'Firebase allergen config unavailable - using static fallback.',
    'TagPhase1Base',
  );
```

If you see this warning in logs, the Firebase config didn't load in time.

### Theory 6: Tagging Service Is Null (MEDIUM LIKELIHOOD)

In `personal_recipe_module.dart:794`:
```dart
if (_taggingService == null) {
  return recipe;  // <-- Returns recipe WITHOUT ANY TAGS
}
```

If `ServiceLocator.get<TaggingService>()` throws (because the module hasn't been initialized yet), the recipe is saved with NO tags at all. This silently fails.

### Theory 7: Race Condition Between Config Init and First Tag Generation (LOW-MEDIUM)

The DI module initializes services in order: TagConfigService -> TaggingService -> PersonalTagService. But `TaggingService` is registered as a lazy singleton. If `generateTags()` is called before the module's `initialize()` runs, the `onInitialize()` method (which calls `PropertyRegistry.validateAllConfigs()` and `_lookupService.initialize()`) hasn't executed. The ingredient lookup service won't have its cache populated, and all lookups will go to Firestore directly (slower, potentially timing out).

---

## Part 2: Identified Bugs and Issues

### Bug 1: Compound Suffix Matching After Swedish Normalization

**File**: `ingredient_lookup_service.dart:362-477`
**Severity**: HIGH

`_generateLookupVariations()` uses compound suffix lists with Swedish characters (bröst, filé, mjölk, etc.) but the input name has already been through `_cleanForLookup()` which strips Swedish diacritics. The suffix check `name.endsWith(suffix)` will always fail for any suffix containing å, ä, or ö.

**Example**: Input "kycklingbröst" -> cleaned to "kycklingbrost" -> check `.endsWith('bröst')` -> false. The variation "kyckling bröst" is never generated.

### Bug 2: Coverage Calculation Treats Normalized Duplicates as Separate

**File**: `ingredient_lookup_service.dart:485-528`

`lookupFromRaw()` deduplicates after normalization (line 513), but the coverage is calculated based on the deduplicated count. If a recipe has "2 dl mjölk" and "1 dl mjölk" as separate ingredients, they normalize to the same thing, one is removed, and coverage is calculated on the smaller set. This means a recipe where the duplicate ingredient isn't matched has a higher coverage impact.

This isn't necessarily a bug, but it means coverage depends on ingredient list structure rather than unique ingredient knowledge.

### Bug 3: Phase 3 `barnvänlig` Requires `mild` Tag Which Requires 100% Coverage

**File**: `tag_phase3_complex.dart:251-263`

`_isKidFriendly()` requires `p2.hasTag('mild')`. The `mild` tag in Phase 2 requires `phase1.lookup.hasFullCoverage` (100% coverage). So `barnvänlig` is effectively impossible unless every single ingredient is matched. For most real recipes, one or two ingredients will be unknown, making this tag unreachable.

### Bug 4: `barnvänlig` Dietary Status vs Tag Confusion

Phase 3 generates a `barnvänlig` TAG, but the dietary config also has a `barnvänlig` dietary STATUS entry. These are separate systems - the tag is in `TagResult.tags` while the dietary status is in `TagResult.dietaryStatus`. Users may see conflicting information if one shows "kid friendly" and the other doesn't.

### Bug 5: Season Tag Resolution Uses Current Date, Not Recipe Context

**File**: `tag_generator.dart:297-303`

Season conflict resolution uses `DateTime.now().month` to prefer the current season. A recipe tagged in winter might lose its "sommar" tag. When retagged in summer, it might lose "vinter". This means seasonal tags are unstable across retagging runs.

---

## Part 3: Improvement Recommendations

### Category A: Accuracy Improvements

#### A1. Relax TriState Logic for Partial Coverage

**Current**: Coverage < 100% -> all allergens/dietary = UNKNOWN
**Proposed**: Use graduated confidence levels

If a recipe has 90% coverage and no gluten-containing ingredients are found among the 90%, the probability that the remaining 10% contains gluten is low. The system could use:
- 100% coverage: CONFIRMED FREE/CONFIRMED CONTAINS
- 80-99% coverage: LIKELY FREE/LIKELY CONTAINS
- 50-79% coverage: UNCERTAIN
- <50% coverage: UNKNOWN

This would make the system dramatically more useful for real-world recipes where 100% ingredient match is rare.

#### A2. Contextual Ingredient Inference

When an ingredient is unmatched, the system could infer its properties from context:
- If the ingredient name contains "ost" -> likely dairy, contains lactose
- If it's in the protein group context of other matched ingredients -> likely protein
- If it's a common preparation like "salt och peppar" -> known safe defaults (no allergens)

This would reduce the "all UNKNOWN" problem for common misses.

#### A3. Fuzzy Matching with Levenshtein Distance

The current fuzzy matching uses prefix/substring matching with score weighting. Adding Levenshtein distance matching would catch typos and minor spelling variations:
- "tomatpure" vs "tomatpuré" (missing accent)
- "spagetti" vs "spaghetti" (common misspelling)
- "rödlök" vs "rodlok" (normalized form)

#### A4. NLP-Based Ingredient Parsing

The current `IngredientParser` uses regex-based parsing which misses many Swedish constructions. A proper NLP-based parser trained on Swedish recipe text could handle:
- "ca 2-3 dl" (approximate quantities with ranges)
- "salt och peppar efter smak" (to-taste instructions mixed with ingredients)
- "1 paket (400g) tofu" (packaging descriptions)
- "valfri grönsak" (abstract ingredient references)

#### A5. Machine Learning for Cuisine Detection

Phase 5 uses keyword matching for cuisine detection. An ML model trained on recipe text could detect cuisine more accurately by considering ingredient combinations, cooking methods, and flavor profiles together rather than isolated keyword checks.

### Category B: Speed Improvements

#### B1. Pre-Compute Tags at Write Time, Not Read Time

Currently tagging is synchronous with recipe save. For web where cache is no-op, this blocks the save. Moving tagging to a background Cloud Function triggered on recipe write would:
- Make saves instant
- Allow more sophisticated tag generation (ML models, etc.)
- Enable global ingredient database updates to cascade retag without client involvement

#### B2. Batch Ingredient Lookup Instead of Sequential

`IngredientLookupService.lookupIngredients()` looks up ingredients one at a time in a loop (line 160-167). For Firestore-backed repositories, this means N sequential reads. A batch `getAll()` query loading all ingredients into memory on init (which the repository already does) means lookups are O(1) in-memory - but the loop still has overhead from async/await per ingredient.

A synchronous batch lookup method that searches the in-memory cache without async would eliminate this overhead.

#### B3. Cache Ingredient Normalization Results

`IngredientNormalizer.normalize()` is pure (no side effects, deterministic). Results could be cached to avoid re-normalizing the same strings across tagging runs. This matters for batch retagging of 100+ recipes where many share common ingredients.

### Category C: Smarter Tag Generation

#### C1. Title-Based Tag Reinforcement

The system generates tags from ingredients, instructions, and title separately. But it doesn't use the title to REINFORCE or CORRECT ingredient-based tags. For example:
- Title "Vegansk pasta" but ingredients have dairy -> flag conflict, trust title for dietary intent
- Title "Snabb kycklinggryta" but time is missing -> infer "under-30-min" from "snabb"
- Title "Mormors köttbullar" -> could add "husmanskost" tag

#### C2. Instruction-Based Ingredient Inference

When ingredients are unmatched, instructions can provide context:
- "Stek kycklingen i olivolja" -> confirms kyckling is present even if ingredient lookup failed
- "Servera med ris" -> side dishes mentioned in instructions could add tags

#### C3. Cross-Recipe Learning

Track which ingredients commonly appear together across all user recipes. Use this to:
- Suggest missing ingredients (improving normalization)
- Detect unusual combinations (potential input errors)
- Generate "similar to" tags

#### C4. User Feedback Loop

When a user manually corrects a tag (via tag overrides), feed this back into the system:
- If users frequently override "gluten: UNKNOWN" to "gluten: FREE" for recipes with >90% coverage, the system should learn the 90% threshold is safe
- Track which unknown ingredients users identify, and auto-add to database

#### C5. Temporal and Seasonal Context

The system detects seasons from ingredients but doesn't use recipe creation date or user location:
- A recipe created in December with "glögg" should get "jul" (Christmas) tag
- A recipe with strawberries created in June should prefer "sommar" over other seasons
- Consider Swedish food calendar events (midsommar, kräftskiva, etc.)

#### C6. Portion and Quantity-Aware Tagging

Currently, the system ignores quantities. But quantities matter:
- "2 kg kyckling" vs "50g kyckling" - the first is a chicken-focused dish, the second uses chicken as garnish
- "1 liter grädde" vs "1 msk grädde" - the first is actually a cream-based dish
- This could improve tags like "proteinrik", "krämig", "ostig"

#### C7. Image-Based Tag Verification (Future)

If the app supports recipe images, ML image classification could verify or supplement text-based tags:
- Detect dish type from image (soup, salad, pasta)
- Verify color-based tags (green = veggie-rich)
- Add presentation tags (plated, rustic, colorful)

### Category D: Architecture Improvements

#### D1. Fix the Compound Suffix Bug

Normalize the compound suffix lists to ASCII, or apply the variation generation BEFORE Swedish character normalization. This is the most impactful quick fix.

#### D2. Add Ingredient Database Analytics

Track unmatched ingredients in production to identify gaps in the database. The code has `trackUnmatchedIngredients` Cloud Function, but the client should also surface common unknowns to the user and/or admin.

#### D3. Separate Allergen Safety from Tag Generation

Currently, allergen/dietary status and category tags are generated in the same pipeline. Safety-critical allergen detection should be a separate, more conservative system with:
- Explicit "I don't know" UI for unknown allergens
- User confirmation for allergen-free claims
- Stricter coverage requirements (keep 100% for allergen FREE claims)
- More relaxed requirements for general tags (50% coverage is enough for "pasta-dish")

#### D4. Versioned Tag Schema with Migration

The system has `kTagGeneratorVersion = '1.0.0'` but no automatic migration when the version changes. When tag generation logic changes, ALL recipes need retagging. The `RetaggingScheduler` handles this, but in batches of 10 at app startup with a 5-second delay. For a user with hundreds of recipes, this could take many app sessions.

Consider server-side batch retagging via Cloud Functions when the generator version changes.

#### D5. Tag Taxonomy and Hierarchy

Tags are flat strings. A hierarchical taxonomy would enable:
- Tag inheritance ("kyckling" implies "protein", "kött")
- Faceted search (filter by category -> subcategory)
- Tag conflict detection at the schema level rather than hardcoded rules
- Localization (tag keys could be locale-independent, display names localized)

---

## Part 4: Quick Wins (Highest Impact, Lowest Effort)

1. **Fix compound suffix bug** (Theory 2 / Bug 1) - Normalize suffix lists to ASCII or defer normalization
2. **Add common multi-ingredient strings** to KnownIngredients: "salt och peppar", "salt och svartpeppar", etc.
3. **Relax coverage for non-safety tags** - Don't require 100% for protein tags, cooking method tags, etc. Only require 100% for allergen FREE claims
4. **Log and surface unknown ingredients** to users with a "help us identify" prompt
5. **Pre-populate `ingredientsNormalized`** before tagging runs to ensure consistent input
