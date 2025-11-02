# Code Deduplication Utilities

Comprehensive guide to Butlery's deduplication infrastructure - utilities that eliminate 1,500-2,400 lines of boilerplate across the codebase.

## Overview

Butlery provides 5 utility systems that eliminate common boilerplate patterns:

1. **SerializationUtils** - Safe Firestore parsing (5-10% adoption, 300-600 lines saved)
2. **ErrorHandlingMixin** - Try-catch elimination via BaseService (23% adoption, 2,000-3,000 lines saved)
3. **Default Value Extensions** - Null coalescing cleanup (0% adoption, 750+ opportunities)
4. **ValidationUtils** - Form validation standardization (15% adoption, 200-400 lines saved)
5. **Migration Framework** - Decision trees from AsyncOperationMixin lessons

**Current Status**: Partial adoption (0-23% across utilities)
**Opportunity**: 75-85 files could migrate (1,500-2,400 lines eliminated)

## When This Skill Activates

Auto-activates when you:
- Parse Firestore documents manually
- Write try-catch blocks for error handling
- Use `value ?? defaultValue` patterns
- Validate form inputs manually
- Migrate existing code to use infrastructure

## Quick Reference

### SerializationUtils (5-10% adoption)

**Problem**: Manual Firestore parsing with null checks
```dart
// Before (10 lines)
factory Recipe.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return Recipe(
    title: data['title'] as String? ?? '',
    portions: data['portions'] as int? ?? 4,
    createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    ingredients: (data['ingredients'] as List?)?.map((e) => e as String).toList() ?? [],
  );
}

// After (6 lines)
factory Recipe.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return Recipe(
    title: SerializationUtils.safeString(data, 'title'),
    portions: SerializationUtils.safeInt(data, 'portions', defaultValue: 4),
    createdAt: SerializationUtils.safeDateTime(data, 'createdAt') ?? DateTime.now(),
    ingredients: SerializationUtils.safeStringList(data, 'ingredients'),
  );
}
```

**Saved**: 30-50 lines per model file (15-20 models = 300-600 lines)

### ErrorHandlingMixin (23% adoption)

**Problem**: Repetitive try-catch blocks
```dart
// Before (15 lines)
Future<Recipe?> getRecipe(String id) async {
  try {
    final recipe = await _repository.getById(id);
    return recipe;
  } catch (e) {
    _logger.error('Failed to get recipe: $e');
    rethrow;
  }
}

// After (5 lines) - via BaseService
Future<Recipe?> getRecipe(String id) async {
  return await executeServiceOperation(
    () => _repository.getById(id),
    operationName: 'Get recipe',
  );
}
```

**Saved**: 10-20 lines per service method (140+ services = 2,000-3,000 lines)

### Default Value Extensions (0% adoption - HIGH OPPORTUNITY)

**Problem**: Manual null coalescing everywhere
```dart
// Before (verbose and repetitive)
final name = recipe.title ?? '';
final items = cart.items ?? [];
final count = user.recipeCount ?? 0;
if (ingredients != null && ingredients.isNotEmpty) { ... }

// After (clean and readable)
final name = recipe.title.orEmpty();
final items = cart.items.orEmpty();
final count = user.recipeCount.orZero();
if (ingredients.hasItems) { ... }
```

**Saved**: 2-3 lines per file (150+ files = 300-450 lines), massive readability improvement

### ValidationUtils (15% adoption)

**Problem**: Manual validation logic
```dart
// Before (10 lines)
String? validateTitle(String? value) {
  if (value == null || value.isEmpty) {
    return 'Titel krävs';
  }
  if (value.trim().isEmpty) {
    return 'Titel får inte vara tom';
  }
  if (value.length > 100) {
    return 'Titel får max vara 100 tecken';
  }
  return null;
}

// After (4 lines)
String? validateTitle(String? value) {
  return ValidationUtils.validateRequired(value, 'Titel') ??
         ValidationUtils.validateMaxLength(value, 100, 'Titel');
}
```

**Saved**: 5-10 lines per validation method (40+ files = 200-400 lines)

### Migration Framework

**Decision Tree** (from AsyncOperationMixin lessons):
1. **Assess Current Code**: Is it well-architected or boilerplate-heavy?
2. **Choose Migration Type**: Full, Partial, or Defer
3. **Apply Gradually**: Start with high-value, low-risk migrations

**Key Learning**: Not all code should migrate - respect well-architected custom solutions

## Resource Files

Detailed documentation for each utility system:

1. **[serialization-utils.md](resources/serialization-utils.md)** - Firestore parsing patterns
   - Safe data extraction (safeString, safeInt, safeDateTime, safeList)
   - Timestamp handling (DateTime, String, int, Timestamp)
   - Nested objects and converters
   - Migration examples (15-20 models)

2. **[error-handling-mixin.md](resources/error-handling-mixin.md)** - BaseService patterns
   - executeServiceOperation() wrapper
   - Network retry logic (max 3 retries)
   - CRUD operation wrappers (safeCreate, safeUpdate, safeDelete)
   - Batch operations with continue-on-error
   - Migration examples (140+ services)

3. **[default-value-extensions.md](resources/default-value-extensions.md)** - Null coalescing
   - String extensions (.orEmpty(), .isNullOrEmpty)
   - List extensions (.orEmpty(), .hasItems)
   - Numeric extensions (.orZero(), .orDefault())
   - DateTime extensions (.orNow(), .orDefault())
   - Migration examples (750+ opportunities)

4. **[validation-utils.md](resources/validation-utils.md)** - Form validation
   - validateRequired(), validateMaxLength(), validateEmail()
   - Business rule validation (recipe names, amounts)
   - Collection validation (hasItems, safeCount)
   - Extension methods for cleaner syntax
   - Migration examples (40+ files)

5. **[migration-framework.md](resources/migration-framework.md)** - Decision trees
   - AsyncOperationMixin lessons learned
   - Full vs Partial vs Defer migration patterns
   - Risk assessment framework
   - Before/after examples from successful migrations

## Adoption Status

**Current Adoption Rates**:
- **SerializationUtils**: 5-10% (5-10 of 100+ models)
- **ErrorHandlingMixin**: 23.7% (44 of 186 services)
- **Default Value Extensions**: 0% (newly created, 750+ opportunities)
- **ValidationUtils**: 15% (15-20 of 100+ validation cases)
- **AsyncOperationMixin**: ✅ COMPLETE (12-15 of eligible ViewModels)

**Migration Opportunities**:
- **HIGH Priority**: Default Value Extensions (0% adoption, high readability impact)
- **HIGH Priority**: SerializationUtils (5-10% adoption, 300-600 lines saved)
- **MEDIUM Priority**: BaseService (23% adoption, 2,000-3,000 lines saved)
- **MEDIUM Priority**: ValidationUtils (15% adoption, 200-400 lines saved)
- **COMPLETE**: AsyncOperationMixin (lessons documented for future patterns)

**Total Impact**: 75-85 files, 1,500-2,400 lines eliminated

## Usage Guidelines

### Immediate Use (All New Code)

**ALWAYS use these in new code**:
- ✅ Default Value Extensions for null coalescing
- ✅ SerializationUtils for Firestore parsing
- ✅ ValidationUtils for form validation
- ✅ BaseService for new services

**Examples**:
```dart
// New model parsing
factory Recipe.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return Recipe(
    title: SerializationUtils.safeString(data, 'title'),
    portions: SerializationUtils.safeInt(data, 'portions', defaultValue: 4),
  );
}

// New service with BaseService
class RecipeService extends BaseService {
  Future<Recipe?> getRecipe(String id) async {
    return await executeServiceOperation(
      () => _repository.getById(id),
      operationName: 'Get recipe',
    );
  }
}

// Null coalescing in any file
final name = recipe.title.orEmpty();  // Instead of: recipe.title ?? ''
if (ingredients.hasItems) { ... }     // Instead of: ingredients != null && ingredients.isNotEmpty
```

### High Priority (When Touching Existing Code)

**Apply when refactoring**:
- ⚠️ BaseService for services with try-catch blocks
- ⚠️ SerializationUtils for models with manual parsing
- ⚠️ Default Value Extensions when touching null coalescing code

**Example**:
```dart
// If you're already editing a service method with try-catch,
// consider migrating to executeServiceOperation()

// If you're already editing a model's fromFirestore(),
// consider migrating to SerializationUtils

// If you're already editing code with value ?? default,
// replace with .orDefault() extensions
```

### Opportunistic (AsyncOperationMixin Pattern)

**Apply gradually with decision framework**:
1. **Assess**: Is current code well-architected or boilerplate-heavy?
2. **Decide**: Full migration, Partial migration, or Defer
3. **Apply**: Start with high-value, low-risk migrations

**Key Learning**: Not all code should migrate. Respect well-architected custom solutions (streams, manager patterns, complex state).

## Migration Decision Tree

```
Is the code well-architected?
├─ YES → Defer migration (respect existing architecture)
└─ NO → Is it boilerplate-heavy?
    ├─ YES → Full migration (high value)
    └─ PARTIAL → Partial migration (cherry-pick benefits)
```

**Examples from AsyncOperationMixin**:
- ✅ **Full Migration**: Simple ViewModels with basic loading/error patterns
- ✅ **Partial Migration**: ViewModels with custom state but could use debouncing
- ✅ **Defer**: Well-architected stream-based or manager-based ViewModels

## Best Practices

1. **Use Extensions Everywhere**: Immediate readability improvement with no risk
2. **SerializationUtils in Models**: Standard pattern for all new models
3. **BaseService for Services**: All new services should extend BaseService
4. **Gradual Migration**: Don't rush to migrate well-working code
5. **Respect Architecture**: If code is well-architected, leave it alone
6. **High-Value First**: Prioritize migrations with biggest impact
7. **Test After Migration**: Verify behavior unchanged

## Anti-Patterns to Avoid

**1. Over-Migration** (🔥 HIGH):
```dart
// ❌ WRONG - Migrating well-architected code unnecessarily
class WellArchitectedViewModel {
  // Has custom stream-based state management
  // DON'T force AsyncOperationMixin here
}
```

**2. Manual Null Checks** (⚠️):
```dart
// ❌ WRONG - Manual null coalescing
final name = value ?? '';

// ✅ RIGHT - Use extension
final name = value.orEmpty();
```

**3. Repetitive Firestore Parsing** (⚠️):
```dart
// ❌ WRONG - Manual parsing with null checks
final title = data['title'] as String? ?? '';

// ✅ RIGHT - Use SerializationUtils
final title = SerializationUtils.safeString(data, 'title');
```

**4. Naked Try-Catch** (⚠️):
```dart
// ❌ WRONG - Manual error handling in services
try {
  return await _repository.get(id);
} catch (e) {
  _logger.error(e);
  rethrow;
}

// ✅ RIGHT - Use BaseService
return await executeServiceOperation(
  () => _repository.get(id),
  operationName: 'Get item',
);
```

## Real-World Examples

### Example 1: Model Migration (SerializationUtils)

**Before** (lib/models/recipe.dart - 15 lines):
```dart
factory Recipe.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return Recipe(
    id: doc.id,
    title: data['title'] as String? ?? '',
    portions: data['portions'] as int? ?? 4,
    createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    ingredients: (data['ingredients'] as List?)
        ?.map((e) => e as String)
        .toList() ?? [],
    tags: (data['tags'] as List?)
        ?.map((e) => e as String)
        .toList() ?? [],
    isFavorite: data['isFavorite'] as bool? ?? false,
  );
}
```

**After** (9 lines):
```dart
factory Recipe.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return Recipe(
    id: doc.id,
    title: SerializationUtils.safeString(data, 'title'),
    portions: SerializationUtils.safeInt(data, 'portions', defaultValue: 4),
    createdAt: SerializationUtils.safeDateTime(data, 'createdAt') ?? DateTime.now(),
    updatedAt: SerializationUtils.safeDateTime(data, 'updatedAt'),
    ingredients: SerializationUtils.safeStringList(data, 'ingredients'),
    tags: SerializationUtils.safeStringList(data, 'tags'),
    isFavorite: SerializationUtils.safeBool(data, 'isFavorite'),
  );
}
```

**Saved**: 6 lines, improved type safety, consistent null handling

### Example 2: Service Migration (BaseService)

**Before** (lib/services/recipe_service.dart - 25 lines):
```dart
class RecipeService {
  Future<Recipe?> getRecipe(String id) async {
    try {
      final recipe = await _repository.getById(id);
      return recipe;
    } catch (e) {
      _logger.error('Failed to get recipe: $e');
      rethrow;
    }
  }

  Future<void> updateRecipe(Recipe recipe) async {
    try {
      await _repository.update(recipe);
    } catch (e) {
      _logger.error('Failed to update recipe: $e');
      rethrow;
    }
  }

  Future<void> deleteRecipe(String id) async {
    try {
      await _repository.delete(id);
    } catch (e) {
      _logger.error('Failed to delete recipe: $e');
      rethrow;
    }
  }
}
```

**After** (15 lines):
```dart
class RecipeService extends BaseService {
  @override
  String get serviceName => 'RecipeService';

  Future<Recipe?> getRecipe(String id) async {
    return await executeServiceOperation(
      () => _repository.getById(id),
      operationName: 'Get recipe',
    );
  }

  Future<void> updateRecipe(Recipe recipe) async {
    await executeServiceOperation(
      () => _repository.update(recipe),
      operationName: 'Update recipe',
    );
  }

  Future<void> deleteRecipe(String id) async {
    await executeServiceOperation(
      () => _repository.delete(id),
      operationName: 'Delete recipe',
    );
  }
}
```

**Saved**: 10 lines, consistent error handling, automatic logging

### Example 3: Extension Usage (Default Values)

**Before** (lib/viewmodels/recipe_viewmodel.dart - 20 occurrences):
```dart
final title = recipe.title ?? '';
final ingredients = recipe.ingredients ?? [];
final portions = recipe.portions ?? 4;
final tags = recipe.tags ?? [];
final imageUrl = recipe.imageUrl ?? '';

if (ingredients != null && ingredients.isNotEmpty) {
  // Process ingredients
}

if (tags != null && tags.isNotEmpty) {
  // Process tags
}

final count = recipes?.length ?? 0;
```

**After** (clean and readable):
```dart
final title = recipe.title.orEmpty();
final ingredients = recipe.ingredients.orEmpty();
final portions = recipe.portions.orDefault(4);
final tags = recipe.tags.orEmpty();
final imageUrl = recipe.imageUrl.orEmpty();

if (ingredients.hasItems) {
  // Process ingredients
}

if (tags.hasItems) {
  // Process tags
}

final count = recipes.safeCount;
```

**Saved**: ~5 lines, massive readability improvement

## Testing After Migration

**Always verify behavior unchanged**:

```dart
// Test SerializationUtils migration
test('fromFirestore parses correctly', () {
  final doc = FakeDocumentSnapshot(data: {
    'title': 'Test Recipe',
    'portions': 4,
  });

  final recipe = Recipe.fromFirestore(doc);

  expect(recipe.title, 'Test Recipe');
  expect(recipe.portions, 4);
});

// Test BaseService migration
test('getRecipe returns recipe', () async {
  when(() => mockRepository.getById(any()))
      .thenAnswer((_) async => testRecipe);

  final result = await service.getRecipe('recipe-123');

  expect(result, testRecipe);
  verify(() => mockRepository.getById('recipe-123')).called(1);
});
```

## Success Metrics

**Target Adoption Rates**:
- SerializationUtils: 80-90% (from 5-10%)
- BaseService: 75-80% (from 23%)
- Default Value Extensions: 60-70% (from 0%)
- ValidationUtils: 60-70% (from 15%)

**Expected Impact**:
- **Lines Saved**: 1,500-2,400 total
- **Readability**: Massive improvement (especially extensions)
- **Consistency**: Standardized patterns across codebase
- **Maintainability**: Less boilerplate to maintain

## Related Skills

**Complementary Skills**:
- 🏗️ **[butlery-architecture](../butlery-architecture/SKILL.md)** - For BaseService patterns that use ErrorHandlingMixin
- 🎨 **[state-management-patterns](../state-management-patterns/SKILL.md)** - For AsyncOperationMixin usage in ViewModels
- 📋 **[testing-patterns](../testing-patterns/SKILL.md)** - For testing code using these utilities

**Documentation Resources**:
- `/ASYNCOPERATION_FINAL_REPORT.md` - AsyncOperationMixin migration lessons
- `/docs/architecture/DEDUPLICATION_PATTERNS.md` - Complete deduplication patterns guide
- `/docs/architecture/WEEK3_MIGRATION_SUCCESS.md` - Migration success stories

---

**Skill Version**: 1.0
**Last Updated**: 2025-01-31
**Status**: Week 3 of Claude Code infrastructure system
**Progress**: 70% complete (Weeks 1-2 done, Week 3 in progress)
