# Issue #014 Phase 2 Analysis: Model Layer Migration

**Date**: November 13, 2025
**Phase**: Model Layer Array Removal
**Status**: 🔍 **ANALYSIS COMPLETE**
**Dependencies**: Phase 1 (Repository Layer) ✅ Complete

---

## Executive Summary

Phase 2 involves removing array fields from shared content models now that repositories use Firestore subcollections (Issue #014). Arrays served two purposes:
1. **Firestore queries** - Enabled `arrayContains` queries (NOW OBSOLETE - Phase 1 uses subcollections)
2. **Status checking** - Methods like `isViewedBy(userId)` check array membership (MUST BE REFACTORED)

**Key Decision**: Remove arrays entirely and move status-checking logic to repository layer.

---

## Problem Analysis

### Current Array Dependencies

#### 1. BaseSharedContentModel (4 arrays)

**File**: `lib/models/shared_content/base_shared_content_model.dart`

**Array Fields**:
- `sharedToUserIds` (line 56) - List of recipient user IDs
- `viewedByUserIds` (line 73) - Users who have viewed the content
- `engagedByUserIds` (line 76) - Users who imported/joined the content
- `dismissedByUserIds` (line 79) - Users who dismissed the content

**Methods Using Arrays**:
```dart
// Line 125-127
bool canBeViewedBy(String userId) {
  return sharedByUserId == userId || sharedToUserIds.contains(userId);
}

// Line 130
bool isViewedBy(String userId) => viewedByUserIds.contains(userId);

// Line 133
bool isEngagedBy(String userId) => engagedByUserIds.contains(userId);

// Line 136
bool isDismissedBy(String userId) => dismissedByUserIds.contains(userId);

// Line 166-173 - Aggregates all status arrays
int get totalInteractions {
  final allInteractors = <String>{
    ...viewedByUserIds,
    ...engagedByUserIds,
    ...dismissedByUserIds,
  };
  return allInteractors.length;
}
```

**Serialization Methods** (lines 198-261):
- `getCommonFirestoreFields()` - Persists arrays to Firestore
- `getCommonJsonFields()` - Persists arrays to JSON cache
- `parseCommonFieldsFromFirestore()` - Reads arrays from Firestore
- `parseCommonFieldsFromJson()` - Reads arrays from JSON

#### 2. CopyOnWriteSupport Mixin (1 array)

**File**: `lib/models/shared_content/copy_on_write_mixin.dart`

**Array Field**:
- `activeCollaboratorIds` (line 71) - Users actively collaborating on content

**Methods Using Array**:
```dart
// Line 118
bool canBeEditedBy(String userId) {
  if (sharedByUserId == userId) return true;
  if (copyOnWriteTriggered) {
    return activeCollaboratorIds.contains(userId); // ❌ Array check
  }
  return _allowsCollaboration() && sharedToUserIds.contains(userId); // ❌ Array check
}

// Line 148-150
bool isActiveCollaborator(String userId) {
  return activeCollaboratorIds.contains(userId); // ❌ Array check
}

// Line 153
int get activeCollaboratorCount => activeCollaboratorIds.length; // ❌ Array access

// Line 156
bool get hasActiveCollaborators => activeCollaboratorIds.isNotEmpty; // ❌ Array access

// Line 269
String getNextCollaborationAction(String userId) {
  // ... logic uses activeCollaboratorIds.contains(userId)
}
```

**Serialization Methods** (lines 194-231):
- `getCopyOnWriteFirestoreFields()` - Persists activeCollaboratorIds
- `parseCopyOnWriteFieldsFromFirestore()` - Reads activeCollaboratorIds

#### 3. SharedRecipe Model (inherits all arrays)

**File**: `lib/models/shared_recipe.dart`

**Direct Array Usage**:
```dart
// Line 290
bool isSharedTo(String userId) => sharedToUserIds.contains(userId);

// Line 324
if (!sharedToUserIds.contains(userId)) {
  return EditMode.noAccess;
}

// Line 328
if (copyOnWriteTriggered && activeCollaboratorIds.contains(userId)) {
  return EditMode.collaborative;
}
```

**Inherited Methods** (from BaseSharedContentModel + mixins):
- All status-checking methods use arrays
- All serialization methods persist arrays

---

## Migration Strategy

### Key Principle: Lightweight Models + Repository-Based Status Checking

**Before** (Array-based):
```dart
// Model has arrays, status checking is synchronous
final sharedRecipe = await repository.getSharedRecipe(recipeId);
final hasViewed = sharedRecipe.isViewedBy(userId); // ✅ Synchronous, uses array
```

**After** (Subcollection-based):
```dart
// Model has NO arrays, status checking delegates to repository
final sharedRecipe = await repository.getSharedRecipe(recipeId);
final hasViewed = await repository.hasViewed(recipeId, userId); // ✅ Async, queries subcollection
```

### Changes Required

#### 1. BaseSharedContentModel Changes

**Remove Array Fields**:
- ❌ `sharedToUserIds` - Data now in `members` subcollection
- ❌ `viewedByUserIds` - Data now in `views` subcollection
- ❌ `engagedByUserIds` - Data now in `engagements` subcollection
- ❌ `dismissedByUserIds` - Data now in `dismissals` subcollection

**Keep Count Fields** (for performance):
- ✅ `viewCount` - Aggregated count (no need to query subcollection)
- ✅ `engagementCount` - Aggregated count
- ✅ `dismissalCount` - Add this field (currently missing)

**Remove Methods** (no longer valid without arrays):
- ❌ `canBeViewedBy(userId)` - Move to repository
- ❌ `isViewedBy(userId)` - Move to repository
- ❌ `isEngagedBy(userId)` - Move to repository
- ❌ `isDismissedBy(userId)` - Move to repository
- ❌ `totalInteractions` - Can't calculate without arrays

**Keep Methods** (still valid):
- ✅ `shouldBeShownTo(userId)` - BUT refactor to use repository checks (async)
- ✅ `isDismissed` getter - BUT refactor to use repository
- ✅ `isViewed` getter - BUT refactor to use repository
- ✅ `conversionRate` - Uses counts only
- ✅ `timeAgoText` - Uses timestamp only

**Update Serialization**:
- Remove array fields from `getCommonFirestoreFields()`
- Remove array fields from `getCommonJsonFields()`
- Remove array parsing from `parseCommonFieldsFromFirestore()`
- Remove array parsing from `parseCommonFieldsFromJson()`

#### 2. CopyOnWriteSupport Mixin Changes

**Remove Array Field**:
- ❌ `activeCollaboratorIds` - Data now in `collaborators` subcollection

**Add Count Field**:
- ✅ `activeCollaboratorCount` - Aggregated count (int, not computed)

**Remove/Refactor Methods**:
- ❌ `isActiveCollaborator(userId)` - Move to repository
- ❌ `hasActiveCollaborators` - Use count field instead: `activeCollaboratorCount > 0`
- ⚠️ `canBeEditedBy(userId)` - REFACTOR to async, query repository
- ⚠️ `getNextCollaborationAction(userId)` - REFACTOR to async, query repository

**Update Serialization**:
- Remove `activeCollaboratorIds` from `getCopyOnWriteFirestoreFields()`
- Add `activeCollaboratorCount` to serialization
- Update parsing methods

#### 3. SharedRecipe Model Changes

**Remove Methods**:
- ❌ `isSharedTo(userId)` - Move to repository (`isMember(recipeId, userId)`)

**Refactor Methods**:
- ⚠️ `getEditModeFor(userId)` - Make async, use repository for membership/collaborator checks

**Update Serialization**:
- No direct changes (inherits from base class)

#### 4. SharedMenu Model Changes

**Same pattern as SharedRecipe** (identical changes)

#### 5. SharedShoppingList Model Changes

**Same pattern as SharedRecipe** (no `activeCollaboratorIds` - shopping lists don't use CoW)

---

## Repository Method Mapping

**Old Model Methods** → **New Repository Methods**:

| Old (Synchronous)                     | New (Asynchronous)                              |
|---------------------------------------|-------------------------------------------------|
| `model.canBeViewedBy(userId)`         | `repository.isMember(contentId, userId)`        |
| `model.isViewedBy(userId)`            | `repository.hasViewed(contentId, userId)`       |
| `model.isEngagedBy(userId)`           | `repository.hasEngaged(contentId, userId)`      |
| `model.isDismissedBy(userId)`         | `repository.hasDismissed(contentId, userId)`    |
| `model.isSharedTo(userId)`            | `repository.isMember(contentId, userId)`        |
| `model.isActiveCollaborator(userId)`  | `repository.isCollaborator(contentId, userId)`  |
| `model.totalInteractions`             | N/A (requires multiple queries - not practical) |

**Note**: All repository methods already exist from Phase 1 (BaseSharedContentRepository).

---

## Breaking Changes

### 1. Status-Checking Methods (HIGH IMPACT)

**Affected Consumers**: ViewModels, UI components, services

**Change**: Synchronous property access → Asynchronous repository queries

**Example Migration**:

```dart
// BEFORE (synchronous)
class RecipeDetailViewModel extends ChangeNotifier {
  void _checkStatus(SharedRecipe recipe, String userId) {
    final hasViewed = recipe.isViewedBy(userId); // ✅ Synchronous
    final canView = recipe.canBeViewedBy(userId); // ✅ Synchronous
    notifyListeners();
  }
}

// AFTER (asynchronous)
class RecipeDetailViewModel extends ChangeNotifier {
  final FirebaseSharedRecipeRepository _repository;

  Future<void> _checkStatus(SharedRecipe recipe, String userId) async {
    final hasViewed = await _repository.hasViewed(recipe.id, userId); // ⚠️ Async
    final isMember = await _repository.isMember(recipe.id, userId); // ⚠️ Async
    notifyListeners();
  }
}
```

**Mitigation**: Phase 3 (Service Layer) will update all consumers systematically.

### 2. Serialization Changes (MEDIUM IMPACT)

**Affected**: Model factories (`fromFirestore`, `fromJson`)

**Change**: Array fields no longer exist in Firestore/JSON

**Example**:

```dart
// BEFORE
factory SharedRecipe.fromMap(String id, Map<String, dynamic> data) {
  final commonFields = BaseSharedContentModel.parseCommonFieldsFromFirestore(data);
  return SharedRecipe(
    viewedByUserIds: commonFields['viewedByUserIds'] as List<String>, // ❌ Won't exist
    engagedByUserIds: commonFields['engagedByUserIds'] as List<String>, // ❌ Won't exist
    // ...
  );
}

// AFTER
factory SharedRecipe.fromMap(String id, Map<String, dynamic> data) {
  final commonFields = BaseSharedContentModel.parseCommonFieldsFromFirestore(data);
  return SharedRecipe(
    // Arrays removed from constructor
    viewCount: commonFields['viewCount'] as int,
    engagementCount: commonFields['engagementCount'] as int,
    // ...
  );
}
```

### 3. Constructor Parameter Removal (LOW IMPACT)

**Affected**: Code that manually constructs SharedRecipe/SharedMenu/SharedShoppingList

**Change**: Array parameters removed from constructors

**Mitigation**: Most code uses factory constructors (`SharedRecipe.create()`) which can be updated internally.

---

## Implementation Plan

### Step 1: Update BaseSharedContentModel

**File**: `lib/models/shared_content/base_shared_content_model.dart`

**Changes**:
1. Remove array fields from class (lines 56, 73, 76, 79)
2. Add `dismissalCount` field (for consistency with viewCount/engagementCount)
3. Remove array parameters from constructor
4. Remove status-checking methods that use arrays
5. Update serialization methods to exclude arrays
6. Keep count-based methods (`conversionRate`, etc.)

**Estimated Lines Changed**: ~80 lines

### Step 2: Update CopyOnWriteSupport Mixin

**File**: `lib/models/shared_content/copy_on_write_mixin.dart`

**Changes**:
1. Remove `activeCollaboratorIds` array field (line 71)
2. Change `activeCollaboratorCount` from computed property to stored field
3. Remove `isActiveCollaborator(userId)` method
4. Update `hasActiveCollaborators` to use count field
5. Mark `canBeEditedBy()` as DEPRECATED (will be removed in Phase 3)
6. Update serialization methods

**Estimated Lines Changed**: ~40 lines

### Step 3: Update SharedRecipe Model

**File**: `lib/models/shared_recipe.dart`

**Changes**:
1. Remove `isSharedTo(userId)` method
2. Mark `getEditModeFor(userId)` as DEPRECATED (requires async refactor in Phase 3)
3. Update constructor to remove array parameters
4. Update `copyWith()` to remove array parameters
5. No serialization changes (inherits from base)

**Estimated Lines Changed**: ~30 lines

### Step 4: Update SharedMenu Model

**File**: `lib/models/shared_menu.dart`

**Changes**: Identical to SharedRecipe (same structure)

**Estimated Lines Changed**: ~30 lines

### Step 5: Update SharedShoppingList Model

**File**: `lib/models/shared_shopping_list.dart`

**Changes**: Similar to SharedRecipe (no CoW-specific changes)

**Estimated Lines Changed**: ~25 lines

---

## Risk Assessment

### Phase 2 Risks

**Risk Level**: ⚠️ **MEDIUM-HIGH**

**Key Risks**:

1. **Breaking Changes for Consumers** (HIGH)
   - **Impact**: All ViewModels, services, and UI components using status-checking methods will break
   - **Mitigation**: Phase 3 will systematically update all consumers
   - **Detection**: `flutter analyze` will catch compile errors immediately

2. **Data Migration Dependency** (HIGH)
   - **Impact**: Models expect arrays to not exist in Firestore, but Phase 4 (migration) hasn't run yet
   - **Mitigation**: Keep Phase 2 changes in feature branch until Phase 4 completes
   - **Rollback**: Git revert if issues arise

3. **Test Failures** (MEDIUM)
   - **Impact**: All model tests expecting arrays will fail
   - **Mitigation**: Update tests simultaneously with model changes
   - **Timeline**: Add 2 hours for test updates

### Success Criteria

**Phase 2 Complete When**:
- ✅ All array fields removed from models
- ✅ All status-checking methods removed (or marked deprecated)
- ✅ Serialization updated to exclude arrays
- ✅ `flutter analyze` passes with zero errors
- ✅ All model tests pass (after updates)
- ✅ Documentation updated

---

## Dependencies

### Completed (Phase 1)
- ✅ BaseSharedContentRepository has subcollection methods
- ✅ All 3 repositories use subcollections
- ✅ Repository methods tested and verified

### Required Before Phase 2
- ✅ No blockers (Phase 1 complete)

### Required After Phase 2 (Phase 3)
- ⏳ Service layer updated to use repository status checks
- ⏳ ViewModels updated to use async repository methods
- ⏳ UI components updated (if they directly use model methods)

---

## Next Steps

### Immediate (Phase 2 Implementation)

**Order of Operations**:
1. Update BaseSharedContentModel (foundation)
2. Update CopyOnWriteSupport mixin (depends on base)
3. Update SharedRecipe model (depends on base + mixin)
4. Update SharedMenu model (same pattern as recipes)
5. Update SharedShoppingList model (same pattern, no CoW)
6. Run `flutter analyze` to catch all breaking changes
7. Update model tests to match new structure

**Estimated Time**: 4 hours (as per original plan)

### After Phase 2 (Phase 3)

**Consumer Updates Required**:
- Social recipe services (2 hours)
- Social menu services (2 hours)
- Social shopping services (2 hours)
- ViewModels using shared content (estimated 10+ files)
- UI components directly checking status (estimated 5+ files)

---

## Conclusion

Phase 2 removes the final traces of array-based architecture from models, completing the transition to subcollection-based data storage. This is a **NECESSARY breaking change** to eliminate the 100-element array limit and enable unlimited sharing.

**Key Achievement**: Models become lightweight DTOs focused on content representation, while repositories handle all Firebase interactions and status checking.

**Risk Managed**: Breaking changes are unavoidable but will be systematically addressed in Phase 3 (Service Layer updates).

**Ready to Proceed**: ✅ Analysis complete, implementation plan finalized.

---

**Phase 2 Analysis Complete** ✅
**Ready for Implementation** ✅
**Estimated Time**: 4 hours
**Risk Level**: Medium-High (managed with Phase 3 migration)
