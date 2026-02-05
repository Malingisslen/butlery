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

### Bug 6: `createPersonalCopy()` Drops All Tags

**File**: `recipe_factory.dart:294-324`, `realtime_recipe.dart`
**Severity**: HIGH

When a user copies a shared or realtime recipe to their personal collection, `createPersonalCopy()` does NOT include `tagResult`. The copied recipe loses all auto-generated tags, allergen status, and dietary information. The user sees a blank slate where there used to be complete tag data.

### Bug 7: Recipe.copyWith() Doesn't Expose tagResult

**File**: `recipe_unified.dart:1031-1083`

The `Recipe` facade's `copyWith()` method has no `tagResult` parameter. Code that needs to update tags must manually construct `Recipe(core: recipe.core.copyWith(tagResult: ...))` instead. This is a footgun - any code using `recipe.copyWith(...)` silently preserves the OLD tags via fallback, even when it should be regenerating them.

---

## Part 3: Systemic Architectural Problems

These are the deep structural issues that no amount of bug-fixing will resolve.

### Problem 1: The System Is Fundamentally a Closed-World Classifier in an Open-World Domain

The entire tagging architecture assumes a **closed world**: every ingredient that matters is in the database, and if it isn't, the system cannot make any claims. This is the 100% coverage gate on TriState.

But recipes exist in an **open world**: users import from websites, type freeform text, use brand names, regional dialects, abbreviations, and creative descriptions. The gap between the ~2230 known ingredients and the infinite variety of real recipe text is the root cause of most failures.

**Systemic fix**: The architecture needs an **open-world reasoning layer** between the lookup service and the tag generator. Instead of binary matched/unmatched, ingredients should carry a confidence score:

```
matched exactly     -> confidence 1.0, properties from DB
matched by alias    -> confidence 0.95, properties from DB
matched by fuzzy    -> confidence 0.8, properties from DB
inferred from name  -> confidence 0.5, properties guessed from naming patterns
completely unknown  -> confidence 0.0, no properties

Coverage = weighted average of confidence scores (not binary match count)
```

This changes the fundamental equation: a recipe where "salt" has confidence 1.0 and "kryddmått kanel" has confidence 0.5 (inferred as spice, no allergens) would have high effective coverage instead of being degraded to UNKNOWN for everything.

### Problem 2: Tags Are Generated but Never Used for Discovery

The system generates ~50+ possible tags per recipe across 5 phases: time, allergen, dietary, protein, carb, cooking method, dish type, difficulty, texture, temperature, nutrition, practical, sustainability, mood, occasion, holiday, season, cuisine. This is impressive engineering.

But looking at how tags are actually consumed:
- `SearchService.filterByTags()` only filters by **personal tags** (user-created), not auto-generated tags
- The UI shows allergen/dietary badges but doesn't let users filter by "show me all grillad recipes" or "find me barnvänlig dishes"
- There's no browse-by-tag view, no tag cloud, no "recipes like this" feature

**The tagging system is generating data that nothing consumes.** The auto-generated tags (which are the bulk of the system's output) are essentially stored and forgotten. Only allergen/dietary status and personal tags have functional UI.

**Systemic fix**: Either remove the unused phases (2-5) to simplify maintenance, or build the discovery UI that makes those tags valuable. The tagging system should be designed backward from user needs: what do users want to FIND? Then generate exactly those tags.

### Problem 3: Two Parallel Tag Systems That Don't Talk to Each Other

Auto-tags (`TagResult.tags`) and personal tags (`PersonalTag`) are completely separate systems with separate storage, separate UI, and separate filtering logic.

- Auto-tags are in `recipe.core.tagResult.tags` (a `Set<String>` on the recipe document)
- Personal tags are in `recipe.core.personalTagIds` (a `List<String>` referencing separate tag documents)
- The search/filter UI only uses personal tags
- The display UI shows auto-tags as badges but personal tags as filter chips

This means a user who wants "show me all Thai recipes" cannot do it unless they manually create a "Thai" personal tag and apply it to recipes, even though the auto-tagger already generates a "thailändsk" tag. The two systems are solving the same problem in incompatible ways.

**Systemic fix**: Unify the tag model. Every tag (auto or personal) should be a first-class entity that can be used for filtering, browsing, and discovery. Auto-tags should automatically appear as filterable options alongside personal tags.

### Problem 4: The Pipeline Is Hardcoded and Brittle

All tag generation logic is hardcoded in Dart classes. Adding a new cuisine requires editing `cuisine_config.dart`. Adding a new cooking method requires editing `tag_phase1_base.dart`. Every change requires an app release.

The Firebase config system (`TagConfigService`) exists but only covers allergen and dietary configs. The 676 lines of `cuisine_config.dart` with 22 hardcoded cuisine entries, the season ingredient lists, the holiday ingredient lists, the cooking method keyword lists - all of these are static.

**Systemic fix**: Move the entire tag vocabulary and detection rules to Firebase Remote Config or Firestore. Tag definitions should be data, not code:

```json
{
  "tagId": "thailandsk",
  "category": "cuisine",
  "displayName": { "sv": "Thailändsk", "en": "Thai" },
  "detection": {
    "titleKeywords": ["thai", "pad thai", "tom yum"],
    "ingredientKeywords": ["kokosmjölk", "fisksås", "citrongräs"],
    "minIngredientMatches": 2
  }
}
```

This makes the entire tag system updatable without app releases, and opens the door for admin tooling to manage tags.

### Problem 5: No Ingredient Lifecycle Management

The ingredient database is a static artifact synced from CSV files via a manual tool (`tool/sync_ingredients.dart`). There is no:
- Dashboard showing match rates and coverage trends over time
- Automated detection of frequently-unmatched ingredients
- Pipeline from "user-defined ingredient" to "global ingredient" (user ingredients are siloed per-user)
- Quality scoring for ingredient entries (do they have all aliases? correct properties?)
- A/B testing capability for normalization or matching changes

The database is the foundation the entire system stands on, but it has no growth mechanism. It will always have coverage gaps because nothing systematically closes them.

**Systemic fix**: Build an ingredient management pipeline:
1. **Telemetry**: Every unmatched ingredient gets logged to a Firestore collection with frequency counts
2. **Admin dashboard**: Shows top-N unmatched ingredients, sorted by frequency. One-click to add to database
3. **User-to-global promotion**: When 3+ users define the same custom ingredient, flag it for promotion to global
4. **Quality scores**: Each ingredient has a completeness score (has Swedish name + English name + properties + aliases + group)
5. **Automated testing**: A test suite of ~500 real recipe ingredient strings that validates match rates on every database change

### Problem 6: The Phase Architecture Creates Coupling Without Value

The 5-phase design (Base -> Derived -> Complex -> Mood -> Cuisine) was designed so each phase builds on previous results. But examining the actual dependencies:

- **Phase 2** depends on Phase 1 tags (e.g., `hasTag('pastabaserad')` -> add `pasta-dish`). But these derived tags are just renaming Phase 1 tags. "pastabaserad" and "pasta-dish" carry the same information.
- **Phase 3** checks Phase 2 tags like `mild` (which itself depends on Phase 1 coverage). The phase chain amplifies the coverage problem: one failed phase cascades through all subsequent phases.
- **Phase 4** does completely independent things (season detection from ingredient names, holiday detection from title keywords) that don't actually need Phases 2-3.
- **Phase 5** (cuisine) also doesn't need Phases 2-4, which is why there's already a `calculateFromPhase1` fallback.

The phase architecture adds complexity (5 result types, cascading failures, timeout handling per phase) without adding real value. Most phases could run independently from the ingredient lookup result and recipe metadata.

**Systemic fix**: Replace the sequential phase chain with independent **tag generators** that each receive the same input (recipe + ingredient lookup) and produce tags independently. Run them in parallel. No cascading failures. Simpler code.

```
IngredientLookupResult + Recipe
  |
  +-- AllergenTagGenerator    -> allergen status
  +-- DietaryTagGenerator     -> dietary status
  +-- ProteinTagGenerator     -> protein tags
  +-- CookingMethodGenerator  -> method tags
  +-- DifficultyGenerator     -> difficulty tag
  +-- MoodGenerator           -> mood/occasion tags
  +-- CuisineGenerator        -> cuisine tags
  +-- SeasonGenerator         -> season tags
  |
  v
  TagResult (merged)
```

### Problem 7: No Observability or Debugging Tools

When tagging "doesn't work," there's no way to diagnose WHY without reading source code. The system has logging (`AppLogger`) but no structured diagnostics.

Questions that should be answerable from the app itself:
- For recipe X, what was the coverage? Which ingredients were unmatched? Why?
- What normalization steps did "2 dl hackad gul lök" go through? What was the final lookup query?
- Which tag generation rules fired? Which didn't and why?
- Across all my recipes, what's the average coverage? What are the most common unknown ingredients?

The `TagDecision` model captures some of this for allergens/dietary, but it's not stored in Firestore by default and there's no UI to view it.

**Systemic fix**: Build a tag debugging view accessible from the recipe detail screen. Show the full pipeline trace: raw input -> parsed -> normalized -> lookup result -> which rules fired -> final tags. This is invaluable for both development and user support.

---

## Part 4: Improvement Recommendations (Tactical)

### Category A: Accuracy

#### A1. Open-World Confidence Scoring
Replace binary matched/unmatched with confidence scores. Ingredients matched exactly get 1.0. Fuzzy matches get 0.8. Name-pattern inferences get 0.5. Coverage becomes a weighted average. Allergen FREE claims still require high confidence, but most tags become usable at 60%+ coverage.

#### A2. Property Inference for Unmatched Ingredients
When an ingredient is unmatched, run a second pass that infers properties from naming patterns: words ending in "-ost" are likely dairy, words ending in "-kött" are likely meat, words containing "mjöl" are likely grain. This doesn't need to be perfect - even 70% accuracy on inferences dramatically improves effective coverage.

#### A3. Common Ingredient Pairs as Single Entries
"salt och peppar", "olja och vinäger", "socker och vanilj" - these common pairs should be recognized by the parser and split into individual ingredients before lookup, or added to the database as composite entries with "no allergen" properties.

### Category B: Architecture

#### B1. Unify Tag Systems
Merge auto-tags and personal tags into a single tag model. Auto-tags become system-managed tags that users can filter by just like personal tags. The recipe list filter UI shows both in the same chip bar.

#### B2. Data-Driven Tag Definitions
Move all tag detection rules (cuisine keywords, season ingredients, holiday ingredients, cooking methods) to Firestore. Each tag rule is a document with detection criteria. The client downloads these at startup and evaluates locally. Changes are instant, no app release needed.

#### B3. Independent Tag Generators
Replace the 5-phase chain with independent generators that run in parallel. Each generator receives the same input and produces tags independently. No cascading failures. Easier to test, debug, and extend.

#### B4. Ingredient Telemetry Pipeline
Log every unmatched ingredient to Firestore with frequency counts. Build an admin view to see the top gaps. Create a one-click "add to database" flow. This turns the ingredient database from a static artifact into a living, growing system.

### Category C: UX

#### C1. Tag-Based Recipe Discovery
Build a browse-by-tag view. Show tag categories (cuisine, difficulty, mood, dietary) as sections. Let users drill into "All Thai recipes" or "All comfort food". This makes the tag system's output visible and useful.

#### C2. Tag Debugging UI
Add a "Why these tags?" section to recipe detail. Show coverage percentage, unmatched ingredients, and which rules produced which tags. Let power users understand and trust the system.

#### C3. Unknown Ingredient Feedback Loop
When recipes have unmatched ingredients, show a non-intrusive prompt: "We couldn't identify 2 ingredients. Help us improve?" Let users classify unknowns (it's a spice, it's dairy, etc.) and feed this back into the system.

---

## Part 5: Priority Matrix

| Change | Impact | Effort | Priority |
|--------|--------|--------|----------|
| Fix compound suffix bug | HIGH | LOW | Do first |
| Expose auto-tags in search/filter UI | HIGH | MEDIUM | Do second |
| Add confidence scoring to IngredientLookupResult | HIGH | MEDIUM | Do third |
| Property inference for unmatched ingredients | HIGH | MEDIUM | Do fourth |
| Ingredient telemetry pipeline | HIGH | MEDIUM | Do fifth |
| Unify auto-tags and personal tags for filtering | VERY HIGH | HIGH | Plan next |
| Data-driven tag definitions (Firebase) | HIGH | HIGH | Plan next |
| Independent tag generators (remove phase chain) | MEDIUM | HIGH | Plan later |
| Tag debugging UI | MEDIUM | MEDIUM | Plan later |
| Browse-by-tag discovery view | HIGH | HIGH | Plan later |
