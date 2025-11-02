# ErrorHandlingMixin - Part 3: Migration Guide & Best Practices

Step-by-step migration guide, priorities, and best practices for adopting ErrorHandlingMixin.

**Part of**: [error-handling-mixin](./error-handling-mixin.md) (split for readability)
**See also**: [Part 1: Basics](./error-handling-mixin-part1-basics.md), [Part 2: Examples](./error-handling-mixin-part2-examples.md)

## Migration Guide

### Step 1: Identify Candidates

Look for services with:
- Repetitive try-catch blocks (3+ methods with same pattern)
- Manual logging in every method
- Retry logic for network operations
- CRUD operations with validation

**Find candidates**:
```bash
# Find services with try-catch blocks
grep -r "try {" lib/services/ | wc -l

# Find services with manual logging
grep -r "_logger.error" lib/services/

# Find services not extending BaseService
grep -r "class.*Service {" lib/services/
```

### Step 2: Extend BaseService

**Before**:
```dart
class RecipeService {
  final RecipeRepository _repository;
  final Logger _logger;

  RecipeService({
    required RecipeRepository repository,
    required Logger logger,
  }) : _repository = repository,
       _logger = logger;
}
```

**After**:
```dart
class RecipeService extends BaseService {
  final RecipeRepository _repository;

  RecipeService({required RecipeRepository repository})
      : _repository = repository;

  @override
  String get serviceName => 'RecipeService';
}
```

**Changes**:
- Remove `Logger _logger` field (provided by BaseService)
- Extend BaseService
- Implement serviceName getter
- Remove logger from constructor

### Step 3: Replace Try-Catch with executeServiceOperation()

**Before**:
```dart
Future<Recipe?> getRecipe(String id) async {
  try {
    _logger.info('Getting recipe: $id');
    final recipe = await _repository.getById(id);
    _logger.info('Recipe retrieved');
    return recipe;
  } catch (e, stackTrace) {
    _logger.error('Failed to get recipe', error: e, stackTrace: stackTrace);
    rethrow;
  }
}
```

**After**:
```dart
Future<Recipe?> getRecipe(String id) async {
  return await executeServiceOperation(
    () => _repository.getById(id),
    operationName: 'Get recipe',
  );
}
```

**Pattern**:
1. Remove try-catch block
2. Remove manual logging
3. Wrap operation in `executeServiceOperation()`
4. Provide descriptive `operationName`

### Step 4: Use CRUD Wrappers

**Before**:
```dart
Future<Recipe> createRecipe(Recipe recipe) async {
  try {
    if (recipe.title.isEmpty) {
      throw ValidationException('Title required');
    }
    return await _repository.create(recipe);
  } catch (e) {
    _logger.error('Failed to create recipe');
    rethrow;
  }
}
```

**After**:
```dart
Future<Recipe> createRecipe(Recipe recipe) async {
  return await safeCreate(
    () => _repository.create(recipe),
    'Recipe',
  );
}
```

**Available wrappers**:
- `safeCreate()` - Create operations
- `safeUpdate()` - Update operations
- `safeDelete()` - Delete operations
- `safeLoad()` - Load operations

### Step 5: Add Retry for Network Operations

**Before**:
```dart
Future<List<Recipe>> searchRecipes(String query) async {
  int retries = 0;
  while (retries < 3) {
    try {
      return await _api.search(query);
    } on SocketException {
      retries++;
      if (retries >= 3) rethrow;
      await Future.delayed(Duration(seconds: retries * 2));
    }
  }
  return [];
}
```

**After**:
```dart
Future<List<Recipe>> searchRecipes(String query) async {
  return await executeServiceOperation(
    () => _api.search(query),
    operationName: 'Search recipes',
    retryOnFailure: true,
    maxRetries: 3,
  );
}
```

### Step 6: Convert Batch Operations

**Before**:
```dart
Future<List<Recipe>> importRecipes(List<Recipe> recipes) async {
  final imported = <Recipe>[];
  for (var recipe in recipes) {
    try {
      final created = await _repository.create(recipe);
      imported.add(created);
    } catch (e) {
      _logger.error('Failed to import recipe, continuing...');
    }
  }
  return imported;
}
```

**After**:
```dart
Future<List<Recipe>> importRecipes(List<Recipe> recipes) async {
  final operations = recipes.map((r) => () => _repository.create(r)).toList();

  return await executeBatchOperation(
    operations,
    operationName: 'Import recipes',
    continueOnError: true,
  );
}
```

### Step 7: Test Migration

```dart
test('getRecipe returns recipe', () async {
  when(() => mockRepository.getById(any()))
      .thenAnswer((_) async => testRecipe);

  final result = await service.getRecipe('recipe-123');

  expect(result, testRecipe);
  verify(() => mockRepository.getById('recipe-123')).called(1);
});

test('getRecipe handles errors', () async {
  when(() => mockRepository.getById(any()))
      .thenThrow(Exception('Test error'));

  expect(
    () => service.getRecipe('recipe-123'),
    throwsA(isA<Exception>()),
  );
});

test('searchRecipes retries on network error', () async {
  var callCount = 0;
  when(() => mockApi.search(any())).thenAnswer((_) async {
    callCount++;
    if (callCount < 3) {
      throw SocketException('Network error');
    }
    return [testRecipe];
  });

  final result = await service.searchRecipes('pasta');

  expect(result, [testRecipe]);
  expect(callCount, 3); // Retried twice, succeeded on 3rd
});
```

## Migration Priority

**HIGH Priority** (40-50 services):
1. Services with 5+ methods with try-catch (biggest wins)
2. Services with network calls (benefit from retry logic)
3. Services with batch operations
4. Recently created services (easier migration)

**MEDIUM Priority** (50-60 services):
1. Services with 3-4 methods with try-catch
2. Services with manual logging
3. CRUD-heavy services (use CRUD wrappers)

**LOW Priority** (30-40 services):
1. Services with 1-2 methods
2. Services with complex error handling (custom logic)
3. Services that work well as-is

**DEFER** (5-10 services):
1. Services with ChangeNotifier (different pattern)
2. Static utility classes (no instance state)
3. Services with well-architected custom error handling

## Best Practices

1. **Always extend BaseService for new services** - Standard pattern
2. **Migrate when touching existing services** - Opportunistic migration
3. **Use descriptive operation names** - Helps with logging/debugging
4. **Enable retry for network operations** - Improves reliability
5. **Use CRUD wrappers for standard operations** - Consistent validation
6. **Test error paths** - Verify error handling works correctly
7. **Don't over-migrate** - Respect well-architected custom error handling

## Common Pitfalls

**1. Forgetting serviceName**:
```dart
// ❌ WRONG - Missing serviceName
class RecipeService extends BaseService {
  // Forgot to override serviceName
}

// ✅ RIGHT - Implement serviceName
class RecipeService extends BaseService {
  @override
  String get serviceName => 'RecipeService';
}
```

**2. Double-logging**:
```dart
// ❌ WRONG - Manual logging AND executeServiceOperation
Future<Recipe?> getRecipe(String id) async {
  logger.info('Getting recipe'); // Unnecessary
  return await executeServiceOperation(
    () => _repository.getById(id),
    operationName: 'Get recipe', // Already logs
  );
}

// ✅ RIGHT - Let executeServiceOperation handle logging
Future<Recipe?> getRecipe(String id) async {
  return await executeServiceOperation(
    () => _repository.getById(id),
    operationName: 'Get recipe',
  );
}
```

**3. Wrong retry usage**:
```dart
// ❌ WRONG - Retry for local operations
Future<Recipe?> getRecipe(String id) async {
  return await executeServiceOperation(
    () => _repository.getById(id), // Local Firestore, doesn't need retry
    operationName: 'Get recipe',
    retryOnFailure: true, // Unnecessary
  );
}

// ✅ RIGHT - Retry only for network calls
Future<List<Recipe>> searchRecipes(String query) async {
  return await executeServiceOperation(
    () => _api.search(query), // External API call
    operationName: 'Search recipes',
    retryOnFailure: true, // Makes sense
  );
}
```

## Related Resources

- [Serialization Utils](serialization-utils.md) - Safe data parsing
- [Validation Utils](validation-utils.md) - Input validation
- [Default Value Extensions](default-value-extensions.md) - Null handling
- [Migration Framework](migration-framework.md) - Migration decision trees

---

**Impact**: 2,000-3,000 lines saved across 140+ services
**Adoption Target**: 75-80% (from 23.7%)
**Priority**: HIGH (use in all new services, migrate when touching existing)
