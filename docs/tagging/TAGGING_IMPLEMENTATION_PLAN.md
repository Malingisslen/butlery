# Tagging System: Implementation Plan

Read this document fully before starting work. It describes the current system, confirmed bugs, and the planned fixes. The companion analysis is in `docs/tagging/TAGGING_ANALYSIS.md`.

## Context

The tagging system auto-generates recipe tags (allergen, dietary, cuisine, mood, etc.) from ingredient text. Users report it "does not work." The root causes are a mix of confirmed bugs and architectural design flaws that prevent the system from producing useful output on real-world recipe data.

## Current Architecture

```
Recipe.core.ingredients (raw strings like "2 dl hackad gul lök")
  |
  v
IngredientParser          lib/utils/text/ingredient_parser.dart
  -> ParsedIngredient(quantity, unit, name)
  |
  v
IngredientNormalizer      lib/utils/text/ingredient_normalizer.dart
  -> removes prep words ("hackad"), plurals ("tomater"->"tomat")
  -> preserves compounds ("vitpeppar", "rödlök")
  -> uses KnownIngredients  lib/constants/known_ingredients.dart
  |
  v
SwedishCharacterNormalizer  lib/utils/text/swedish_character_normalizer.dart
  -> å->a, ä->a, ö->o (lowercase)
  |
  v
IngredientLookupService   lib/services/tagging/ingredient_lookup_service.dart
  -> LRU cache (500 entries)
  -> exact name -> alias -> variations -> fuzzy matching
  -> uses FirebaseIngredientRepository  lib/repositories/firebase/firebase_ingredient_repository.dart
  -> ~2230 ingredients loaded into memory at init
  |
  v
IngredientLookupResult    lib/models/tagging/ingredient_lookup_result.dart
  -> matched: List<IngredientData>, unmatched: List<String>, coverage: double
  -> TriState logic: coverage < 1.0 = ALL allergen/dietary = UNKNOWN
  |
  v
TagGenerator              lib/services/tagging/tag_generator.dart
  -> Phase 1 (Base)       lib/services/tagging/phases/tag_phase1_base.dart
  -> Phase 2 (Derived)    lib/services/tagging/phases/tag_phase2_derived.dart
  -> Phase 3 (Complex)    lib/services/tagging/phases/tag_phase3_complex.dart
  -> Phase 4 (Mood)       lib/services/tagging/phases/tag_phase4_mood.dart
  -> Phase 5 (Cuisine)    lib/services/tagging/phases/tag_phase5_cuisine.dart
  |
  v
TagResult                 lib/models/tagging/tag_result.dart
  -> tags: Set<String>, allergenStatus: Map, dietaryStatus: Map, coverage, unknownIngredients
  -> stored on recipe.core.tagResult in Firestore
```

**DI registration**: `lib/core/di/modules/tagging_module.dart`
**Orchestrator**: `lib/services/tagging/tagging_service.dart`
**Trigger point**: `lib/services/unified/modules/personal_recipe_module.dart` `_applyTagging()`

**Personal tags** (separate system): `lib/services/tagging/personal_tag_service.dart`, `lib/models/tagging/personal_tag.dart`, `lib/models/tagging/personal_tag_rule.dart`

**Key config files**:
- `lib/services/tagging/config/allergen_config.dart` - allergen property mappings
- `lib/services/tagging/config/dietary_config.dart` - dietary exclusion rules
- `lib/services/tagging/config/cuisine_config.dart` - 22 cuisine detection rules
- `lib/services/tagging/config/tagging_thresholds.dart` - centralized threshold constants

## Test Files

21 test files exist. Key ones:
- `test/unit/services/tagging/tagging_service_test.dart`
- `test/unit/services/tagging/tag_generator_test.dart`
- `test/unit/services/tagging/personal_tag_service_test.dart`
- `test/unit/models/tagging/tag_result_test.dart`
- `test/integration/firebase/services/tagging_integration_test.dart`
- `test/integration/firebase/services/batch_tagging_test.dart`
- `test/integration/firebase/services/recipe_tag_persistence_test.dart`
- `test/performance/tagging_performance_test.dart`
- Test builders: `test/infrastructure/builders/personal_tag_builder.dart`
- Test helpers: `test/infrastructure/helpers/tagging_test_helper.dart`

---

## Confirmed Bugs (fix these first)

### BUG-1: Compound Suffix Lists Use Swedish Characters After ASCII Normalization

**Severity**: HIGH - breaks compound word variation generation for all words with å, ä, ö

**Root cause**: `_cleanForLookup()` at line 350-359 of `ingredient_lookup_service.dart` calls `SwedishCharacterNormalizer.normalize()` which strips å->a, ä->a, ö->o. The cleaned name is then passed to `_generateLookupVariations()`. But `_compoundSuffixes` (lines 34-55) and `_compoundEndings` (lines 60-114) contain Swedish characters: "bröst", "filé", "kött", "fläsk", "mjölk", "grädde", "sås", "färs", "mjöl".

The `name.endsWith(suffix)` check will NEVER match because the name is ASCII but the suffixes are Swedish.

**Example**: "kycklingbröst" -> cleaned to "kycklingbrost" -> `.endsWith('bröst')` -> **false**

**Fix**: Normalize both `_compoundSuffixes` and `_compoundEndings` to ASCII. Replace Swedish characters in these lists:
```
bröst -> brost    filé -> file     kött -> kott
fläsk -> flask    färs -> fars     mjölk -> mjolk
grädde -> gradde  sås -> sas       mjöl -> mjol
lök -> lok        bröd -> brod     soppa -> soppa (no change)
vitlök -> vitlok  lår -> lar       njure -> njure (no change)
kotlett -> kotlett (no change)      kotletter -> kotletter (no change)
purjolök -> purjolok               rödlök -> rodlok
```

**Test**: Write a test that passes "kycklingbröst" through `_cleanForLookup()` then `_generateLookupVariations()` and asserts "kyckling" is in the variations list.

---

### BUG-2: `createPersonalCopy()` Drops All Tags

**Severity**: HIGH - users who copy shared recipes lose all tag data

**File**: `lib/models/recipe/recipe_factory.dart` lines 295-324

**Root cause**: `createPersonalCopy()` constructs a new `RecipeCore()` without passing `tagResult`, `tagOverrides`, or `ingredientsNormalized`. These fields default to null.

**Fix**: Pass through the source recipe's tag data:
```dart
return Recipe(
  core: RecipeCore(
    // ... existing fields ...
    tagResult: sourceRecipe.core.tagResult,
    tagOverrides: sourceRecipe.core.tagOverrides,
    ingredientsNormalized: sourceRecipe.core.ingredientsNormalized != null
        ? [...sourceRecipe.core.ingredientsNormalized!]
        : null,
  ),
  type: RecipeType.personal,
);
```

Also check `lib/models/realtime/realtime_recipe.dart` for the same issue in its `createPersonalCopy()`.

**Test**: Write a test that creates a recipe with a TagResult, calls `createPersonalCopy()`, and asserts the copy's tagResult is not null.

---

### BUG-3: Recipe.copyWith() Missing tagResult Parameter

**Severity**: MEDIUM - forces awkward workarounds, risk of stale tags

**File**: `lib/models/recipe_unified.dart` lines 1031-1054

**Root cause**: The `Recipe.copyWith()` parameter list includes `tagOverrides` but not `tagResult`.

**Fix**: Add `TagResult? tagResult,` to the parameter list and pass it to `core.copyWith(tagResult: tagResult)` in the body.

**Test**: Write a test that calls `recipe.copyWith(tagResult: newTagResult)` and asserts the result has the new tag result.

---

### BUG-4: `barnvänlig` Tag Unreachable in Practice

**Severity**: MEDIUM - kid-friendly tag never appears

**File 1**: `lib/services/tagging/phases/tag_phase2_derived.dart` lines 42-43
```dart
} else if (phase1.lookup.hasFullCoverage) {  // <-- 100% coverage required
  tags.add('mild');
}
```

**File 2**: `lib/services/tagging/phases/tag_phase3_complex.dart` lines 251-253
```dart
bool _isKidFriendly(Phase1Result p1, Phase2Result p2) {
  if (!p2.hasTag('mild')) return false;  // <-- requires mild
```

**Root cause**: `mild` requires 100% ingredient coverage. `barnvänlig` requires `mild`. Real recipes almost never achieve 100% coverage, making both tags unreachable.

**Fix**: Change the `mild` threshold to a configurable value (suggest 80%):
```dart
} else if (phase1.lookup.coverage >= TaggingThresholds.mildCoverageThreshold) {
  tags.add('mild');
}
```
Add `static const double mildCoverageThreshold = 0.8;` to `TaggingThresholds`.

---

### BUG-5: Season Tags Unstable Across Retagging

**File**: `lib/services/tagging/tag_generator.dart` lines 297-303

**Root cause**: `_getCurrentSeason()` uses `DateTime.now().month`. A recipe tagged in winter gets different season resolution when retagged in summer.

**Fix**: Either remove the season conflict resolution entirely (let recipes have multiple season tags) or make `_getCurrentSeason` accept a `DateTime` parameter and use `recipe.core.createdAt` instead of `DateTime.now()`.

---

## Architectural Changes (do after bugs are fixed)

### ARCH-1: Confidence-Based Coverage (replaces binary TriState)

**Goal**: Replace the binary "100% or UNKNOWN" model with graduated confidence.

**Changes needed**:

1. **New model** `lib/models/tagging/ingredient_match.dart`:
```dart
class IngredientMatch {
  final String originalText;
  final IngredientData? data;
  final double confidence;     // 0.0-1.0
  final MatchMethod method;    // exact, alias, fuzzy, inferred, unknown

  Set<String> get properties => data?.properties ?? _inferredProperties;
  Set<String> _inferredProperties;  // populated by inference layer
}

enum MatchMethod { exact, alias, fuzzy, inferred, unknown }
```

2. **Update** `IngredientLookupResult` to use `List<IngredientMatch>` instead of separate `matched`/`unmatched` lists. Coverage becomes `matches.map((m) => m.confidence).average`.

3. **Update TriState methods** in `IngredientLookupResult`:
   - `getPropertyStatus()`: CONTAINS if any ingredient with confidence > 0.5 has the property. FREE if weighted coverage > 0.8 and no ingredients have it. UNKNOWN otherwise.
   - Keep 100% high-confidence requirement for allergen FREE claims (safety).
   - Use 60%+ for general tags like cuisine, mood, difficulty.

4. **Add inference layer** to `IngredientLookupService`:
   - After lookup fails, infer properties from Swedish naming patterns:
     - Contains "ost" -> likely dairy
     - Contains "kött" or "fläsk" -> likely meat
     - Contains "mjöl" -> likely grain
     - Is "salt", "peppar", "socker", "vatten" -> known safe (no allergens)
   - Return as `IngredientMatch` with confidence 0.3-0.5 and `method: inferred`

**Files to modify**:
- `lib/models/tagging/ingredient_lookup_result.dart` (major rewrite)
- `lib/services/tagging/ingredient_lookup_service.dart` (add inference, change return type)
- `lib/services/tagging/phases/tag_phase1_base.dart` (use new confidence thresholds)
- `lib/services/tagging/phases/tag_phase2_derived.dart` (use confidence for mild/stark)
- `lib/services/tagging/phases/tag_phase3_complex.dart` (use confidence for barnvänlig, etc.)
- `lib/models/tagging/tag_result.dart` (no change needed - already stores coverage as double)
- All 21 test files need updating

**Test strategy**: Create test recipes with mixed confidence levels. Assert that:
- A recipe with 90% exact matches + 10% inferred gets non-UNKNOWN dietary status
- A recipe with 50% unknowns still gets UNKNOWN for allergen FREE claims
- A recipe with 80% coverage gets the `mild` tag

---

### ARCH-2: Expose Auto-Tags in Search/Filter UI

**Goal**: Let users filter recipes by auto-generated tags like "thailändsk", "barnvänlig", "comfort-food".

**Current state**: `SearchService.filterByTags()` only handles personal tags. Auto-tags sit unused in `recipe.core.tagResult.tags`.

**Approach**: Add an auto-tag filter alongside the existing personal tag filter in the recipe list view.

**Files to investigate**:
- The search service (find via `grep -r "filterByTags"`)
- The recipe list view and its viewmodel
- The filter chip UI component

**Implementation sketch**:
1. Add `filterByAutoTags(Set<String> tags)` to the search service
2. Aggregate all distinct auto-tags across the user's recipes (can be cached)
3. Show auto-tags as a separate "System Tags" section in the filter UI
4. Category grouping: cuisine tags, mood tags, dietary tags, difficulty tags

---

### ARCH-3: Tag Debugging View

**Goal**: Make it possible to see WHY a recipe got specific tags (or didn't).

**Approach**: Add a developer/debug section to recipe detail that shows:
- Ingredient coverage percentage
- List of unmatched ingredients with the normalization trace
- Which tag rules fired and which didn't
- Confidence scores per ingredient (after ARCH-1)

**Implementation**: The `TagDecision` model already captures allergen/dietary reasoning. Extend it to cover all tag categories. Store decisions in `TagResult.decisions` (already exists but not stored in Firestore). For debug mode, persist decisions temporarily.

---

### ARCH-4: Independent Tag Generators (replace phase chain)

**Goal**: Eliminate cascading failures from the sequential phase architecture.

**Current**: Phase 1 -> Phase 2 -> Phase 3 -> Phase 4 -> Phase 5 (sequential, each depends on previous)

**Proposed**: Independent generators that all receive the same `(Recipe, IngredientLookupResult)` input:

```
TagInput(recipe, lookupResult)
  |
  +-- AllergenGenerator     -> Map<String, TriState> allergenStatus
  +-- DietaryGenerator      -> Map<String, TriState> dietaryStatus
  +-- CategoryGenerator     -> Set<String> category tags (time, method, protein, carb)
  +-- DifficultyGenerator   -> String difficulty tag
  +-- TextureGenerator      -> Set<String> texture tags (krämig, krispig)
  +-- MoodGenerator         -> Set<String> mood/occasion tags
  +-- SeasonGenerator       -> Set<String> season/holiday tags
  +-- CuisineGenerator      -> Set<String> cuisine tags
  |
  v
  TagResult.merge(all generator outputs)
```

**Key benefit**: If the cuisine generator fails or times out, allergen status still works. Today, a Phase 1 timeout kills everything downstream.

**Files to create/modify**:
- Create `lib/services/tagging/generators/` directory
- One file per generator, each implementing a `TagGeneratorPlugin` interface
- Modify `tag_generator.dart` to orchestrate independent generators
- Delete phase result types (`Phase1Result`, `Phase2Result`, etc.) after migration
- Update all phase test files

This is a larger refactor. Do it AFTER the bugs and ARCH-1 are working.

---

## Execution Order

```
1. BUG-1  Fix compound suffix normalization        (LOW effort, HIGH impact)
2. BUG-2  Fix createPersonalCopy tag preservation   (LOW effort, HIGH impact)
3. BUG-3  Add tagResult to Recipe.copyWith          (LOW effort, MEDIUM impact)
4. BUG-4  Relax mild/barnvänlig coverage threshold  (LOW effort, MEDIUM impact)
5. BUG-5  Fix season tag stability                  (LOW effort, LOW impact)
6. ARCH-1 Confidence-based coverage model           (MEDIUM effort, HIGH impact)
7. ARCH-2 Expose auto-tags in filter UI             (MEDIUM effort, HIGH impact)
8. ARCH-3 Tag debugging view                        (MEDIUM effort, MEDIUM impact)
9. ARCH-4 Independent tag generators                (HIGH effort, MEDIUM impact)
```

Each step should be a separate commit. Run `flutter analyze` and relevant tests after each change. The bug fixes (1-5) are independent and can be done in any order or in parallel.

---

## Critical Rules (from CLAUDE.md)

- Max 500 lines per file. Use facade pattern if exceeded.
- `ServiceLocator.get<T>()` for all service access
- `SerializationUtils.safeX()` for all Firestore deserialization
- `withValues(alpha:)` not `withOpacity()` for colors
- Comments explain WHY not WHAT. All comments in English.
- Test paths use forward slashes: `flutter test test/unit/file_test.dart`
- Never use `FirebaseFirestore.instance` directly
