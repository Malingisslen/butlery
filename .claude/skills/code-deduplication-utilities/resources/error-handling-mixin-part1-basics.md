# ErrorHandlingMixin - Part 1: Basics & Core Patterns

Guide to using ErrorHandlingMixin via BaseService to eliminate try-catch boilerplate.

**Part of**: [error-handling-mixin](./error-handling-mixin.md) (split for readability)
**See also**: [Part 2: Examples](./error-handling-mixin-part2-examples.md), [Part 3: Migration](./error-handling-mixin-part3-migration.md)

## Overview

ErrorHandlingMixin (included in BaseService) eliminates repetitive error handling across services:
- **669 lines of infrastructure** eliminating 1,100-1,400 lines of try-catch blocks
- **Automatic logging** with operation context
- **Network retry logic** (max 3 retries for transient failures)
- **CRUD operation wrappers** (safeCreate, safeUpdate, safeDelete, safeLoad)
- **Batch operations** with continue-on-error support
- **Error classification** (DNS, network, auth, 404, 503)
- **Current Adoption**: 23.7% (44 of 186 services)
- **Opportunity**: 140+ services with try-catch blocks (2,000-3,000 lines saved)

**Location**:
- `lib/core/mixins/error_handling_mixin.dart` (core infrastructure)
- `lib/core/base/base_service.dart` (recommended usage pattern)

## Core Pattern: BaseService

**ALL new services should extend BaseService** instead of using ErrorHandlingMixin directly:

```dart
class RecipeService extends BaseService {
  final RecipeRepository _repository;

  RecipeService({required RecipeRepository repository})
      : _repository = repository;

  @override
  String get serviceName => 'RecipeService';

  // ErrorHandlingMixin methods available automatically
  Future<Recipe?> getRecipe(String id) async {
    return await executeServiceOperation(
      () => _repository.getById(id),
      operationName: 'Get recipe',
    );
  }
}
```

**Key Benefits**:
- Includes ErrorHandlingMixin automatically
- Pre-flight checks (auth, network, permissions)
- Built-in caching with expiry management
- Lifecycle hooks (onInitialize, onDispose)
- Consistent service pattern across codebase

## ErrorHandlingMixin Methods

### executeServiceOperation()

**Primary method for all service operations**:

```dart
Future<T> executeServiceOperation<T>(
  Future<T> Function() operation, {
  required String operationName,
  bool retryOnFailure = false,
  int maxRetries = 3,
})

// Usage
Future<Recipe?> getRecipe(String id) async {
  return await executeServiceOperation(
    () => _repository.getById(id),
    operationName: 'Get recipe',
  );
}

// With retry for network operations
Future<List<Recipe>> searchRecipes(String query) async {
  return await executeServiceOperation(
    () => _api.search(query),
    operationName: 'Search recipes',
    retryOnFailure: true,
    maxRetries: 3,
  );
}
```

**What it does**:
1. Logs operation start
2. Executes operation
3. Catches errors and logs with context
4. Retries on transient failures (if enabled)
5. Classifies errors (network, auth, etc.)
6. Returns result or rethrows

### CRUD Operation Wrappers

**Specialized wrappers for common operations**:

```dart
// safeCreate - Create with validation
Future<T?> safeCreate<T>(
  Future<T> Function() createOperation,
  String entityType,
)

// safeUpdate - Update with validation
Future<void> safeUpdate(
  Future<void> Function() updateOperation,
  String entityType,
  String entityId,
)

// safeDelete - Delete with confirmation
Future<void> safeDelete(
  Future<void> Function() deleteOperation,
  String entityType,
  String entityId,
)

// safeLoad - Load with caching
Future<T?> safeLoad<T>(
  Future<T?> Function() loadOperation,
  String entityType,
  String entityId,
)

// Usage
Future<Recipe> createRecipe(Recipe recipe) async {
  return await safeCreate(
    () => _repository.create(recipe),
    'Recipe',
  );
}

Future<void> updateRecipe(Recipe recipe) async {
  await safeUpdate(
    () => _repository.update(recipe),
    'Recipe',
    recipe.id,
  );
}

Future<void> deleteRecipe(String id) async {
  await safeDelete(
    () => _repository.delete(id),
    'Recipe',
    id,
  );
}

Future<Recipe?> loadRecipe(String id) async {
  return await safeLoad(
    () => _repository.getById(id),
    'Recipe',
    id,
  );
}
```

### Batch Operations

**Execute multiple operations with continue-on-error**:

```dart
Future<List<T>> executeBatchOperation<T>(
  List<Future<T> Function()> operations, {
  required String operationName,
  bool continueOnError = true,
})

// Usage
Future<List<Recipe>> batchCreateRecipes(List<Recipe> recipes) async {
  final operations = recipes.map((recipe) => () => _repository.create(recipe)).toList();

  return await executeBatchOperation(
    operations,
    operationName: 'Batch create recipes',
    continueOnError: true, // Continue even if some fail
  );
}
```

**What it does**:
1. Executes all operations
2. Logs progress (X of N completed)
3. If continueOnError: collects successes, logs failures
4. If !continueOnError: stops on first failure
5. Returns successful results

### Sequential Operations

**Execute operations in order with dependency handling**:

```dart
Future<T> executeSequentialOperation<T>(
  List<Future<T> Function()> operations, {
  required String operationName,
})

// Usage
Future<void> createRecipeWithMedia(Recipe recipe, File image) async {
  await executeSequentialOperation([
    () => _imageService.uploadImage(image),
    () => _repository.create(recipe),
    () => _notificationService.notifyFriends(recipe.id),
  ], operationName: 'Create recipe with media');
}
```

**What it does**:
1. Executes operations in order
2. Stops on first failure
3. Logs each step
4. Returns result of last operation

## Error Classification

ErrorHandlingMixin automatically classifies errors:

```dart
// DNS errors
'Failed to lookup host' → 'DNS resolution failed'

// Network errors
SocketException → 'Network connectivity issue'
TimeoutException → 'Operation timed out'

// Auth errors
'permission-denied' → 'Permission denied'
'unauthenticated' → 'Authentication required'

// HTTP errors
404 → 'Resource not found'
503 → 'Service temporarily unavailable'

// Generic errors
Exception → Logs with full context
```

**Example log output**:
```
[RecipeService] Starting: Get recipe
[RecipeService] ERROR in Get recipe: Network connectivity issue
[RecipeService] Retrying Get recipe (attempt 1 of 3)...
[RecipeService] Completed: Get recipe
```

---

## Next Steps

Continue with:
- **[Part 2: Examples](./error-handling-mixin-part2-examples.md)** - Real-world examples from the codebase
- **[Part 3: Migration](./error-handling-mixin-part3-migration.md)** - Migration guide, priorities, and best practices

---

**Patterns**: BaseService, executeServiceOperation, CRUD wrappers, batch operations
**Status**: ✅ Production-ready
