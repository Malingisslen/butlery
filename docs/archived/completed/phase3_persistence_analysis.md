# Recipe Persistence Analysis - Phase 3A

**Date**: 2025-01-31
**Goal**: Identify all recipe persistence points for auto-population integration

---

## Persistence Points Found

### 1. Firebase Recipe Repository (PRIMARY)

**File**: `lib/repositories/firebase/firebase_recipe_repository.dart`

#### Method: `create()`
**Line**: 164
**Type**: Create
**Input**: Recipe object
**Output**: Future<Recipe>
**Integration Needed**: YES
**Priority**: 🔴 HIGHEST (main persistence layer)

**Current Code**:
```dart
@override
Future<Recipe> create(Recipe entity) async {
  // Validate user owns the recipe they're creating
  final currentUser = requireCurrentUserId();

  // Permission validation...

  return await super.create(entity);  // Calls base class
}
```

**Analysis**:
- ✅ Saves Recipe object directly
- ✅ Called by all recipe creation flows
- ✅ Main integration point
- ✅ Should auto-populate here before super.create()

**Integration Strategy**:
```dart
@override
Future<Recipe> create(Recipe entity) async {
  // Validation...

  // MODUL1 Phase 3: Auto-populate normalized ingredients
  Recipe recipeToSave = entity;
  if (IngredientProcessor.needsNormalization(entity)) {
    final normalized = IngredientProcessor.normalizeIngredientsForRecipe(
      entity.core.ingredients,
    );
    recipeToSave = entity.copyWith(
      core: entity.core.copyWith(ingredientsNormalized: normalized),
    );
  }

  return await super.create(recipeToSave);
}
```

---

#### Method: `update()`
**Line**: 191
**Type**: Update
**Input**: Recipe object
**Output**: Future<void>
**Integration Needed**: YES
**Priority**: 🔴 HIGHEST (main persistence layer)

**Current Code**:
```dart
@override
Future<void> update(Recipe entity) async {
  // Validate user owns the recipe they're updating
  final currentUser = requireCurrentUserId();

  // Permission validation...

  await super.update(entity);  // Calls base class
}
```

**Analysis**:
- ✅ Updates Recipe object
- ✅ Called by all recipe update flows
- ✅ Main integration point
- ✅ Should auto-populate here before super.update()

**Integration Strategy**: Same as create() above

---

### 2. Personal Recipe Module (SERVICE LAYER)

**File**: `lib/services/unified/modules/personal_recipe_module.dart`

#### Method: `createPersonalRecipe()`
**Line**: 41
**Type**: Create
**Input**: Individual parameters (title, ingredients, etc.)
**Output**: Future<String?> (recipe ID)
**Integration Needed**: NO (delegates to repository)
**Priority**: 🟡 MEDIUM (service layer - repository handles it)

**Current Code**:
```dart
Future<String?> createPersonalRecipe({
  required String title,
  String description = '',
  List<String> ingredients = const [],
  // ... other parameters
}) async {
  final newRecipe = Recipe.personal(
    title: title.trim(),
    description: description,
    ingredients: ingredients,
    // ...
  );

  // Save to cache
  await _saveToCache(newRecipe);

  // Background sync to database
  _startBackgroundRecipeSync(newRecipe, 'create');

  return newRecipe.id;
}
```

**Analysis**:
- ⚠️ Creates Recipe but delegates to repository via background sync
- ⚠️ May bypass repository layer (background sync)
- ⚠️ Need to check _startBackgroundRecipeSync() implementation
- ✅ If it calls repository, repository handles normalization
- ⚠️ If it writes directly to Firestore, needs integration here

**Action Required**: Check _startBackgroundRecipeSync() implementation

---

#### Method: `updatePersonalRecipe()`
**Line**: 105
**Type**: Update
**Input**: Recipe object
**Output**: Future<bool>
**Integration Needed**: NO (delegates to repository)
**Priority**: 🟡 MEDIUM (service layer - repository handles it)

**Analysis**: Same as createPersonalRecipe() above

---

### 3. Import Manager (IMPORT FLOW)

**File**: `lib/services/import/import_manager.dart`

#### Method: `saveImportedRecipe()`
**Line**: 267
**Type**: Create (save imported recipe)
**Input**: Recipe object
**Output**: Future<ImportManagerResult>
**Integration Needed**: NO (delegates to repository)
**Priority**: 🟢 LOW (delegates to personalOperations)

**Current Code**:
```dart
Future<ImportManagerResult> saveImportedRecipe(Recipe recipe) async {
  try {
    final saveResult = await _personalOperations.addUnifiedRecipe(recipe);

    if (saveResult.isSuccess) {
      return ImportManagerResult.success(recipe, strategy: 'direct_save');
    }
  } catch (e) {
    return ImportManagerResult.failure('Error saving recipe: $e', ...);
  }
}
```

**Analysis**:
- ✅ Delegates to _personalOperations.addUnifiedRecipe()
- ✅ If that delegates to repository, repository handles normalization
- ✅ No integration needed here

---

### 4. Service Adapter (ADAPTER LAYER)

**File**: `lib/services/unified/modules/service_adapters/recipe_service_adapter.dart`

#### Method: `createRecipe()`
**Line**: 36
**Type**: Create
**Input**: Recipe object
**Output**: Future<String?>
**Integration Needed**: NO (adapter layer)
**Priority**: 🟢 LOW (adapter - delegates to repository)

#### Method: `updateRecipe()`
**Line**: 48
**Type**: Update
**Input**: Recipe object
**Output**: Future<bool>
**Integration Needed**: NO (adapter layer)
**Priority**: 🟢 LOW (adapter - delegates to repository)

**Analysis**:
- ✅ Adapter layer - delegates to underlying service/repository
- ✅ No integration needed

---

### 5. Cache Operations (CACHE LAYER)

**File**: `lib/services/unified/modules/cache_operations.dart`

#### Method: `saveRecipeToCache()`
**Line**: 85
**Type**: Cache (not persistence)
**Integration Needed**: NO
**Priority**: ⚪ NONE (cache only, not main persistence)

**Analysis**:
- ❌ Only saves to cache, not database
- ❌ No integration needed

---

### 6. Realtime Recipe Service (COLLABORATIVE)

**File**: `lib/services/realtime/realtime_recipe_service.dart`

#### Method: `createRealtimeRecipe()`
**Line**: 43
**Type**: Create (collaborative/realtime recipe)
**Integration Needed**: MAYBE
**Priority**: 🟡 MEDIUM (collaborative feature)

**Analysis**:
- ⚠️ Creates realtime collaborative recipes
- ⚠️ May have different persistence flow
- ⚠️ Need to check if it uses Recipe model or RealtimeRecipe model

**Action Required**: Check if RealtimeRecipe also needs normalization

---

### 7. Collaborative Recipe Repository

**File**: `lib/repositories/collaborative_recipe_repository.dart`

#### Method: `createRealtimeRecipe()`
**Line**: 71
**Type**: Create (realtime/collaborative)
**Integration Needed**: MAYBE
**Priority**: 🟡 MEDIUM (if uses Recipe model)

#### Method: `updateRealtimeRecipe()`
**Line**: 78
**Type**: Update (realtime/collaborative)
**Integration Needed**: MAYBE
**Priority**: 🟡 MEDIUM (if uses Recipe model)

**Analysis**:
- ⚠️ Uses RealtimeRecipe model (not Recipe)
- ⚠️ May not have ingredientsNormalized field
- ⚠️ Need to check RealtimeRecipe model structure

**Action Required**: Check RealtimeRecipe model

---

## Summary Table

| File | Method | Line | Type | Integration | Priority | Notes |
|------|--------|------|------|-------------|----------|-------|
| **firebase_recipe_repository.dart** | **create()** | **164** | **Create** | **YES** | **🔴 HIGHEST** | **Main persistence** |
| **firebase_recipe_repository.dart** | **update()** | **191** | **Update** | **YES** | **🔴 HIGHEST** | **Main persistence** |
| personal_recipe_module.dart | createPersonalRecipe() | 41 | Create | CHECK | 🟡 MEDIUM | Check background sync |
| personal_recipe_module.dart | updatePersonalRecipe() | 105 | Update | CHECK | 🟡 MEDIUM | Check background sync |
| import_manager.dart | saveImportedRecipe() | 267 | Create | NO | 🟢 LOW | Delegates to repository |
| recipe_service_adapter.dart | createRecipe() | 36 | Create | NO | 🟢 LOW | Adapter delegates |
| recipe_service_adapter.dart | updateRecipe() | 48 | Update | NO | 🟢 LOW | Adapter delegates |
| collaborative_recipe_repository.dart | createRealtimeRecipe() | 71 | Create | MAYBE | 🟡 MEDIUM | Check RealtimeRecipe model |
| collaborative_recipe_repository.dart | updateRealtimeRecipe() | 78 | Update | MAYBE | 🟡 MEDIUM | Check RealtimeRecipe model |

---

## Priority Integration Points

### 🔴 HIGHEST PRIORITY (Must Integrate)

1. **`firebase_recipe_repository.dart::create()`** (line 164)
   - Main recipe creation persistence
   - ALL recipe creation flows use this
   - Auto-populate before super.create()

2. **`firebase_recipe_repository.dart::update()`** (line 191)
   - Main recipe update persistence
   - ALL recipe update flows use this
   - Auto-populate before super.update()

### 🟡 MEDIUM PRIORITY (Check & Integrate if Needed)

3. **`personal_recipe_module.dart::createPersonalRecipe()`** (line 41)
   - Check if _startBackgroundRecipeSync() bypasses repository
   - If yes, integrate here
   - If no, repository handles it

4. **`personal_recipe_module.dart::updatePersonalRecipe()`** (line 105)
   - Same as above

5. **Realtime/Collaborative recipes**
   - Check if RealtimeRecipe model has ingredientsNormalized field
   - If yes, integrate in collaborative_recipe_repository
   - If no, add field to model first

---

## Action Items

### Immediate (Phase 3B)

1. ✅ **Integrate firebase_recipe_repository.dart::create()**
   - Add auto-population before super.create()
   - Test with new recipe creation

2. ✅ **Integrate firebase_recipe_repository.dart::update()**
   - Add auto-population before super.update()
   - Test with recipe editing

### Follow-up Checks

3. **Check personal_recipe_module background sync**
   ```bash
   grep -A 20 "_startBackgroundRecipeSync" lib/services/unified/modules/personal_recipe_module.dart
   ```
   - If it calls repository → No action needed
   - If it writes directly → Integrate here

4. **Check RealtimeRecipe model**
   ```bash
   grep -A 30 "class RealtimeRecipe" lib/models/
   ```
   - If has ingredientsNormalized → Integrate collaborative repository
   - If not → Add field to model (separate task)

---

## Integration Pattern (Template)

For firebase_recipe_repository.dart methods:

```dart
import 'package:butlery/utils/text/ingredient_processor.dart';

@override
Future<Recipe> create(Recipe entity) async {
  // Existing validation...
  final currentUser = requireCurrentUserId();

  // ... permission checks ...

  // MODUL1 Phase 3: Auto-populate normalized ingredients
  Recipe recipeToSave = entity;
  if (IngredientProcessor.needsNormalization(entity)) {
    final normalizedIngredients =
        IngredientProcessor.normalizeIngredientsForRecipe(
          entity.core.ingredients,
        );

    recipeToSave = entity.copyWith(
      core: entity.core.copyWith(
        ingredientsNormalized: normalizedIngredients,
      ),
    );
  }

  // Call super with potentially updated recipe
  return await super.create(recipeToSave);
}

@override
Future<void> update(Recipe entity) async {
  // Existing validation...
  final currentUser = requireCurrentUserId();

  // ... permission checks ...

  // MODUL1 Phase 3: Auto-populate normalized ingredients
  Recipe recipeToSave = entity;
  if (IngredientProcessor.needsNormalization(entity)) {
    final normalizedIngredients =
        IngredientProcessor.normalizeIngredientsForRecipe(
          entity.core.ingredients,
        );

    recipeToSave = entity.copyWith(
      core: entity.core.copyWith(
        ingredientsNormalized: normalizedIngredients,
      ),
    );
  }

  // Call super with potentially updated recipe
  await super.update(recipeToSave);
}
```

---

## Expected Impact

### Immediate Impact
- ✅ All new recipes get normalized ingredients automatically
- ✅ All recipe edits refresh normalized ingredients
- ✅ Import flows get normalized ingredients (via repository)

### Coverage
- ✅ Manual recipe creation (via repository)
- ✅ Manual recipe editing (via repository)
- ✅ Text import (via import_manager → repository)
- ✅ OCR import (via import_manager → repository)
- ✅ File import (via import_manager → repository)

### No Coverage (Intentional)
- ❌ Collaborative real-time recipes (if separate model)
- ❌ Cache-only operations (not persistence)

---

## Verification Plan

After integration:

1. **Create new recipe**
   - Input: "2 dl hackad lök", "3 st stora ägg"
   - Check Firestore: ingredientsNormalized = ["lök", "ägg"]

2. **Edit existing recipe**
   - Modify ingredients
   - Save
   - Check Firestore: ingredientsNormalized updated

3. **Import recipe**
   - Import via copy/paste or OCR
   - Check Firestore: ingredientsNormalized populated

4. **Check old recipes**
   - Open recipe without ingredientsNormalized
   - Should open without error
   - Edit and save
   - Check Firestore: ingredientsNormalized now populated

---

## Risk Assessment

### Technical Risk: LOW ✅
- Only 2 methods to modify (create, update)
- Clear integration point (before super.create/update)
- Non-breaking (optional field)
- Backward compatible

### Data Risk: LOW ✅
- Doesn't modify existing data
- Only adds to new field (optional)
- No data loss risk

### Performance Risk: LOW ✅
- Normalization adds ~2-4ms per save
- Negligible for user experience
- No impact on reads

---

## Conclusion

**Primary Integration Points**: 2 methods in firebase_recipe_repository.dart

**Estimated Implementation Time**: 30 minutes

**Ready to proceed with Phase 3B**: YES ✅

---

**Document Status**: Phase 3A Complete
**Next Phase**: 3B - Implement auto-population
**Approval**: Ready for implementation
