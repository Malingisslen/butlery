# Migration Framework - Decision Trees and Best Practices

Comprehensive guide to migrating code to use Butlery's deduplication infrastructure, with lessons learned from the successful AsyncOperationMixin initiative.

## Overview

Migration framework provides decision trees for adopting deduplication utilities:
- **Lessons from AsyncOperationMixin** - Successful migration patterns (12-15 ViewModels)
- **Full vs Partial vs Defer** - Three migration strategies
- **Risk assessment framework** - Evaluate migration safety
- **Before/after examples** - Real migration outcomes
- **Decision trees** - When to migrate, when to defer

**Key Learning**: Not all code should migrate. Respect well-architected custom solutions.

## AsyncOperationMixin Success Story

### Initiative Overview

**Goal**: Migrate ViewModels to use AsyncOperationMixin for automatic loading/error state management

**Result**: ✅ COMPLETE (Jan 2025)
- **12-15 of 97 ViewModels migrated** (80-100% of viable candidates)
- **Key Insight**: Only 12-15 ViewModels benefit from migration
- **Learning**: Most ViewModels (82-85) have well-architected custom state management that should NOT be replaced

### Migration Categories

**Full Migration** (2-3 ViewModels):
- Simple CRUD ViewModels with basic loading/error patterns
- No complex state management
- Direct benefit from AsyncOperationMixin infrastructure

**Partial Migration** (10-12 ViewModels):
- ViewModels with custom state but could use specific features (debouncing, caching)
- Cherry-pick benefits (e.g., use `executeDebounced` for search, keep custom state)
- Hybrid approach: AsyncOperationMixin + custom state

**Deferred** (82-85 ViewModels):
- Stream-based ViewModels (real-time Firebase)
- Manager-based ViewModels (FriendsViewModel with 6 managers)
- Complex state machines (multi-step workflows)
- Well-architected custom solutions

### Decision Framework Applied

```
Is the ViewModel well-architected?
├─ YES → Defer migration (e.g., FriendsViewModel with managers)
│   Rationale: Would destroy good architecture
│   Outcome: Keep as-is
│
└─ NO → Is it boilerplate-heavy?
    ├─ YES → Full migration (e.g., simple CRUD ViewModels)
    │   Rationale: High value, low risk
    │   Outcome: Replace all state management
    │
    └─ PARTIAL → Partial migration (e.g., SearchViewModel)
        Rationale: Keep custom state, add debouncing
        Outcome: Hybrid approach
```

### Real Examples from AsyncOperationMixin

**Example 1: Full Migration - RecipeListViewModel**

**Before** (50 lines):
```dart
class RecipeListViewModel extends ChangeNotifier {
  List<Recipe> _recipes = [];
  bool _isLoading = false;
  String? _error;

  Future<void> loadRecipes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _recipes = await _service.getUserRecipes();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

**After** (25 lines):
```dart
class RecipeListViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {

  List<Recipe> _recipes = [];

  Future<void> loadRecipes() async {
    await executeAsync(() async {
      _recipes = await _service.getUserRecipes();
    });
  }
  // isLoading, hasError, errorMessage provided automatically
}
```

**Result**: ✅ Success - 50% code reduction, cleaner state management

**Example 2: Partial Migration - SearchViewModel**

**Before** (80 lines):
```dart
class SearchViewModel extends ChangeNotifier {
  String _query = '';
  List<Recipe> _results = [];
  bool _isLoading = false;

  Timer? _debounceTimer;

  void search(String query) {
    _query = query;

    // Manual debouncing
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 500), () async {
      _isLoading = true;
      notifyListeners();

      try {
        _results = await _service.search(_query);
        _isLoading = false;
        notifyListeners();
      } catch (e) {
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
```

**After** (40 lines):
```dart
class SearchViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {

  String _query = '';
  List<Recipe> _results = [];

  Future<void> search(String query) async {
    _query = query;

    await executeDebounced(
      'search',
      () async {
        _results = await _service.search(_query);
      },
      Duration(milliseconds: 500),
    );
  }
  // Debouncing, loading, error handled automatically
  // No need to manage Timer, no manual dispose
}
```

**Result**: ✅ Success - 50% code reduction, automatic debouncing

**Example 3: Defer - FriendsViewModel (Well-Architected)**

**Current** (905 lines with 6 managers):
```dart
class FriendsViewModel extends ChangeNotifier {
  // 6 specialized managers (facade pattern)
  late final FriendsSearchManager _searchManager;
  late final FriendsProfileCacheManager _profileManager;
  late final FriendsSelectionManager _selectionManager;
  late final FriendsCategoryManager _categoryManager;
  late final FriendsStreamManager _streamManager;
  late final FriendsActionManager _actionManager;

  // Expose manager state via getters
  String get searchQuery => _searchManager.searchQuery;
  List<UserProfile> get filteredFriends => _streamManager.filteredFriends;
  // ... well-architected facade
}
```

**Decision**: ✅ DEFER - Do not migrate
- Well-architected manager-based facade pattern
- Complex state coordination between 6 managers
- Custom stream-based real-time updates
- AsyncOperationMixin would destroy good architecture

**Rationale**: Respect existing architecture. Not all code needs migration.

## Migration Decision Tree

### Level 1: Assess Current Code

```
Question: Is the current code well-architected?

Well-Architected Indicators:
✅ Uses established patterns (facade, manager delegation)
✅ Clear separation of concerns
✅ Single responsibility respected
✅ Extensive existing tests
✅ Custom state management for specific requirements
✅ Stream-based real-time updates
✅ Complex state machines

Boilerplate-Heavy Indicators:
❌ Repetitive try-catch blocks
❌ Manual loading/error state management
❌ Duplicate null checking patterns
❌ Manual debouncing/retry logic
❌ No clear architecture
❌ Copy-pasted validation logic
```

**If well-architected → DEFER migration**
**If boilerplate-heavy → Continue to Level 2**

### Level 2: Choose Migration Type

```
Question: Can all boilerplate be replaced?

Full Migration (Replace ALL state management):
✅ Simple CRUD operations
✅ Basic loading/error patterns
✅ No custom state requirements
✅ Direct mapping to utility methods

Partial Migration (Cherry-pick benefits):
✅ Some custom state needed
✅ Could benefit from specific features (debouncing, retry)
✅ Hybrid approach acceptable
✅ Keep existing architecture + add utility

DEFER (Keep as-is):
✅ Complex custom requirements
✅ Well-working current implementation
✅ Migration would add complexity
✅ Low value, high risk
```

### Level 3: Risk Assessment

```
Risk Assessment Questions:

1. Code Coverage:
   - Has tests? → LOWER RISK (can verify behavior unchanged)
   - No tests? → HIGHER RISK (manual verification needed)

2. Usage Frequency:
   - Rarely used? → LOWER RISK (fewer users affected)
   - Critical path? → HIGHER RISK (requires thorough testing)

3. Complexity:
   - Simple logic? → LOWER RISK (easy to verify)
   - Complex state? → HIGHER RISK (hard to verify equivalence)

4. Dependencies:
   - Isolated? → LOWER RISK (limited blast radius)
   - Central component? → HIGHER RISK (wide impact)

5. Recent Changes:
   - Stable code? → LOWER RISK (unlikely to have hidden bugs)
   - Recently modified? → HIGHER RISK (may introduce regressions)
```

**Risk Score**:
- **LOW (0-2 high-risk factors)**: Safe to migrate
- **MEDIUM (3-4 high-risk factors)**: Migrate with caution + extensive testing
- **HIGH (5+ high-risk factors)**: Consider deferring

## Migration Strategies by Utility

### SerializationUtils Migration

**Decision Tree**:
```
Is this a Firestore model with fromFirestore()?
├─ YES → Is parsing complex (nested objects, custom types)?
│   ├─ YES → Full migration (HIGH value)
│   └─ NO → Opportunistic migration (when touching file)
└─ NO → Not applicable
```

**Migration Pattern**: Full replacement of manual parsing

**Risk**: LOW (pure data transformation, easy to test)

**Example**:
```dart
// Before: 15 lines of manual parsing
// After: 8 lines with SerializationUtils
// Outcome: ✅ Success - cleaner, type-safe
```

### ErrorHandlingMixin (BaseService) Migration

**Decision Tree**:
```
Does this service have 3+ methods with try-catch?
├─ YES → Does it use ChangeNotifier?
│   ├─ YES → DEFER (different pattern)
│   └─ NO → Is it a static utility?
│       ├─ YES → DEFER (no instance state)
│       └─ NO → Full migration (extend BaseService)
└─ NO → Is it 1-2 methods only?
    ├─ YES → DEFER (low value)
    └─ NO → Partial migration (when adding more methods)
```

**Migration Pattern**: Extend BaseService, replace try-catch with executeServiceOperation()

**Risk**: LOW-MEDIUM (error handling critical, but well-tested infrastructure)

**Example**:
```dart
// Before: 60 lines with repetitive try-catch
// After: 25 lines extending BaseService
// Outcome: ✅ Success - consistent error handling
```

### Default Value Extensions Migration

**Decision Tree**:
```
Does this file use value ?? default?
├─ YES → How many occurrences?
│   ├─ 5+ → Full migration (HIGH value)
│   ├─ 2-4 → Opportunistic migration (when touching file)
│   └─ 1 → DEFER (low value)
└─ NO → Not applicable
```

**Migration Pattern**: Replace all `??` patterns with extensions

**Risk**: VERY LOW (pure syntax change, no behavior change)

**Example**:
```dart
// Before: 20 occurrences of value ?? default
// After: 20 uses of value.orDefault()
// Outcome: ✅ Success - massive readability improvement
```

### ValidationUtils Migration

**Decision Tree**:
```
Is this a form ViewModel or input widget?
├─ YES → Does it have 3+ validation methods?
│   ├─ YES → Full migration (HIGH value)
│   └─ NO → Partial migration (use for common patterns)
└─ NO → Is it custom business logic?
    ├─ YES → Add to ValidationUtils first, then use
    └─ NO → DEFER (not applicable)
```

**Migration Pattern**: Replace manual validation with ValidationUtils methods

**Risk**: LOW (validation well-tested, clear behavior)

**Example**:
```dart
// Before: 80 lines of manual validation
// After: 25 lines with ValidationUtils
// Outcome: ✅ Success - reusable, consistent
```

## Migration Process

### Step 1: Assess Code

**Questions to answer**:
1. Is code well-architected or boilerplate-heavy?
2. What utility applies? (SerializationUtils, BaseService, Extensions, ValidationUtils)
3. How much code is affected? (lines, methods, files)
4. What's the migration type? (Full, Partial, Defer)

**Tools**:
```bash
# Find try-catch blocks
grep -r "try {" lib/services/ | wc -l

# Find null coalescing
grep -r " ?? " lib/ | wc -l

# Find manual validation
grep -r "if.*isEmpty" lib/viewmodels/ | wc -l
```

### Step 2: Choose Strategy

**Full Migration**:
- Replace ALL boilerplate with utility
- Test comprehensively
- Commit as single atomic change

**Partial Migration**:
- Identify specific features to use (debouncing, retry, validation)
- Keep custom state/logic
- Hybrid approach: utility + custom
- Test both paths

**Defer**:
- Document why deferring (well-architected, low value, etc.)
- Add TODO if considering future migration
- Move on to higher-value targets

### Step 3: Execute Migration

**Process**:
1. **Create branch**: `git checkout -b migrate/[component-name]`
2. **Read current implementation**: Understand behavior
3. **Write tests** (if none exist): Capture current behavior
4. **Apply migration**: Replace with utility
5. **Run tests**: Verify behavior unchanged
6. **Manual testing**: UI smoke test for ViewModels
7. **Code review**: Verify migration correct
8. **Commit**: Descriptive message explaining migration

### Step 4: Verify Success

**Verification Checklist**:
- [ ] All tests pass
- [ ] No new warnings from `flutter analyze`
- [ ] Manual testing shows no regressions
- [ ] Code is cleaner (fewer lines, more readable)
- [ ] No new bugs introduced

**If verification fails**:
- Investigate cause
- Fix issue or revert migration
- Document why migration failed (add to DEFER list)

## Migration Examples

### Example 1: Full Migration - RecipeRepository

**Assessment**:
- Boilerplate-heavy: ✅ (10+ methods with try-catch)
- Utility: BaseFirebaseRepository
- Risk: LOW (has tests, isolated component)
- Strategy: FULL migration

**Before** (200 lines):
```dart
class RecipeRepository {
  Future<Recipe?> getById(String id) async {
    try {
      final doc = await _firestore.collection('recipes').doc(id).get();
      if (!doc.exists) return null;
      return Recipe.fromFirestore(doc);
    } catch (e) {
      _logger.error('Failed to get recipe');
      rethrow;
    }
  }
  // + 9 more similar methods
}
```

**After** (80 lines):
```dart
class RecipeRepository extends BaseFirebaseRepository<Recipe> {
  @override
  String get collectionPath => 'recipes';

  @override
  Recipe fromFirestore(DocumentSnapshot doc) => Recipe.fromFirestore(doc);

  // getById, create, update, delete provided by base
}
```

**Result**: ✅ Success - 60% code reduction

### Example 2: Partial Migration - SearchViewModel

**Assessment**:
- Has custom state: ✅ (filter state, category selection)
- Could use debouncing: ✅
- Risk: MEDIUM (no tests, critical path)
- Strategy: PARTIAL migration (add debouncing only)

**Before**:
```dart
class SearchViewModel extends ChangeNotifier {
  String _query = '';
  RecipeCategory? _category;
  List<Recipe> _results = [];

  Timer? _debounceTimer;

  void search(String query) {
    _query = query;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 500), _performSearch);
  }

  void selectCategory(RecipeCategory category) {
    _category = category;
    _performSearch();
  }

  Future<void> _performSearch() async {
    // Custom search logic with filters
  }
}
```

**After** (Partial):
```dart
class SearchViewModel extends ChangeNotifier with AsyncOperationMixin {
  String _query = '';
  RecipeCategory? _category;
  List<Recipe> _results = [];

  Future<void> search(String query) async {
    _query = query;
    await executeDebounced('search', _performSearch, Duration(milliseconds: 500));
  }

  void selectCategory(RecipeCategory category) {
    _category = category;
    _performSearch(); // Immediate, no debounce
  }

  Future<void> _performSearch() async {
    // Keep custom search logic with filters
  }
}
```

**Result**: ✅ Success - Debouncing simplified, kept custom state

### Example 3: Defer - FriendsViewModel

**Assessment**:
- Well-architected: ✅ (6-manager facade pattern)
- Boilerplate-heavy: ❌ (minimal duplication)
- Risk: HIGH (complex, critical path, extensive tests)
- Strategy: DEFER

**Rationale**:
- Manager-based facade is excellent architecture
- AsyncOperationMixin would force flattening of managers
- Custom stream management for real-time updates
- Well-tested existing implementation (50+ tests)
- Migration would destroy good architecture

**Decision**: Keep as-is, document as exemplary pattern

## Common Migration Pitfalls

### Pitfall 1: Over-Migration

**Problem**: Forcing migration where custom solution is better

**Example**:
```dart
// ❌ WRONG - Destroying well-architected stream-based ViewModel
class RealtimeRecipeViewModel extends ChangeNotifier with AsyncOperationMixin {
  // Trying to use AsyncOperationMixin with streams - doesn't fit!
}

// ✅ RIGHT - Keep custom stream management
class RealtimeRecipeViewModel extends ChangeNotifier {
  Stream<Recipe> watchRecipe(String id) {
    return _repository.watchRecipe(id);
  }
  // Custom stream-based state - perfect as-is
}
```

**Solution**: Respect well-architected code. Not all code needs migration.

### Pitfall 2: Under-Testing

**Problem**: Migrating without verifying behavior unchanged

**Example**:
```dart
// Migrated service without tests
class RecipeService extends BaseService {
  // Behavior changed subtly, but no tests caught it
}
```

**Solution**: Write tests BEFORE migration if none exist. Verify behavior unchanged AFTER migration.

### Pitfall 3: Partial Migration Confusion

**Problem**: Mixing utility and custom state incorrectly

**Example**:
```dart
// ❌ WRONG - Mixing AsyncOperationMixin loading state with manual state
class ViewModel extends ChangeNotifier with AsyncOperationMixin {
  bool _isLoading = false; // Conflicts with AsyncOperationMixin.isLoading!

  Future<void> load() async {
    _isLoading = true; // Don't do this, use executeAsync
    notifyListeners();
  }
}

// ✅ RIGHT - Use AsyncOperationMixin OR manual, not both
class ViewModel extends ChangeNotifier with AsyncOperationMixin {
  Future<void> load() async {
    await executeAsync(() async {
      // AsyncOperationMixin handles isLoading
    });
  }
}
```

**Solution**: Choose one pattern for loading/error state. Don't mix utility and manual state.

### Pitfall 4: Ignoring Risk Assessment

**Problem**: Migrating high-risk code without precautions

**Example**:
```dart
// Migrating critical auth service with no tests - HIGH RISK!
class AuthService extends BaseService {
  // Changed behavior, broke authentication
}
```

**Solution**: Use risk assessment framework. HIGH risk = extensive testing required.

## Success Metrics

**How to measure migration success**:

1. **Code Reduction**: Lines saved (target: 20-50% per file)
2. **Test Coverage**: Tests pass + behavior unchanged
3. **Readability**: Code easier to understand (subjective but important)
4. **Consistency**: Codebase uses standard patterns
5. **Maintainability**: Easier to update in future

**Expected outcomes by utility**:

| Utility | Lines Saved | Adoption Target | Priority |
|---------|-------------|-----------------|----------|
| SerializationUtils | 300-600 | 80-90% | HIGH |
| BaseService | 2,000-3,000 | 75-80% | HIGH |
| Default Extensions | 300-450 | 60-70% | VERY HIGH |
| ValidationUtils | 200-400 | 60-70% | HIGH |

## Best Practices

1. **Start small**: Migrate 1-2 files first, learn, then scale
2. **Test thoroughly**: Verify behavior unchanged
3. **Respect architecture**: Don't destroy good custom solutions
4. **Document decisions**: Why migrated OR why deferred
5. **Iterate**: Full → Partial → Defer based on learnings
6. **Measure impact**: Track lines saved, readability improvement
7. **Share learnings**: Document patterns for team

## Related Resources

- [Serialization Utils](serialization-utils.md) - Firestore parsing patterns
- [Error Handling Mixin](error-handling-mixin.md) - BaseService patterns
- [Default Value Extensions](default-value-extensions.md) - Null coalescing
- [Validation Utils](validation-utils.md) - Form validation
- AsyncOperationMixin Final Report: `/ASYNCOPERATION_FINAL_REPORT.md`
- Week 3 Migration Success: `/docs/architecture/WEEK3_MIGRATION_SUCCESS.md`

---

**Key Takeaway**: Migration is about improving code quality, not forcing all code into a single pattern. Respect well-architected solutions, migrate boilerplate-heavy code, and always verify behavior unchanged.
