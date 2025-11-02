# ErrorHandlingMixin - BaseService Pattern

Comprehensive guide to using ErrorHandlingMixin via BaseService to eliminate try-catch boilerplate in Butlery services.

**Note**: This guide has been split into 3 focused parts for better readability (<350 lines each):

---

## Guide Structure

### [Part 1: Basics & Core Patterns](./error-handling-mixin-part1-basics.md) (~245 lines)

**Topics**:
- Overview and benefits
- BaseService pattern (recommended usage)
- ErrorHandlingMixin methods (executeServiceOperation, CRUD wrappers)
- Batch and sequential operations
- Error classification

**When to use**: Understanding the core infrastructure and available methods

---

### [Part 2: Real-World Examples](./error-handling-mixin-part2-examples.md) (~350 lines)

**Topics**:
- Example 1: Simple Service (RecipeService) - 35 lines saved
- Example 2: Network Service (ImageUploadService) - 50 lines saved with retry logic
- Example 3: CRUD Service (MenuService) - 70 lines saved with validation
- Before/after comparisons from actual codebase

**When to use**: Seeing practical implementation patterns and understanding the impact

---

### [Part 3: Migration Guide & Best Practices](./error-handling-mixin-part3-migration.md) (~325 lines)

**Topics**:
- 7-step migration guide (identify, extend, replace, CRUD wrappers, retry, batch, test)
- Migration priorities (HIGH/MEDIUM/LOW/DEFER)
- Best practices checklist
- Common pitfalls and anti-patterns
- Related resources

**When to use**: Migrating existing services to BaseService pattern

---

## Quick Reference

### Basic Pattern
```dart
class RecipeService extends BaseService {
  final RecipeRepository _repository;

  RecipeService({required RecipeRepository repository})
      : _repository = repository;

  @override
  String get serviceName => 'RecipeService';

  Future<Recipe?> getRecipe(String id) async {
    return await executeServiceOperation(
      () => _repository.getById(id),
      operationName: 'Get recipe',
    );
  }
}
```

### CRUD Operations
```dart
// Create
await safeCreate(() => _repository.create(recipe), 'Recipe');

// Update
await safeUpdate(() => _repository.update(recipe), 'Recipe', recipe.id);

// Delete
await safeDelete(() => _repository.delete(id), 'Recipe', id);

// Load
await safeLoad(() => _repository.getById(id), 'Recipe', id);
```

### Network Operations with Retry
```dart
return await executeServiceOperation(
  () => _api.search(query),
  operationName: 'Search recipes',
  retryOnFailure: true,
  maxRetries: 3,
);
```

---

## Navigation

**Choose your topic**:
- Need to understand the core pattern? → [Part 1](./error-handling-mixin-part1-basics.md)
- Want to see real examples? → [Part 2](./error-handling-mixin-part2-examples.md)
- Ready to migrate a service? → [Part 3](./error-handling-mixin-part3-migration.md)

**See all parts**:
- [Part 1: Basics & Core Patterns](./error-handling-mixin-part1-basics.md)
- [Part 2: Real-World Examples](./error-handling-mixin-part2-examples.md)
- [Part 3: Migration Guide & Best Practices](./error-handling-mixin-part3-migration.md)

---

**Total**: ~920 lines split into 3 manageable parts
**Impact**: 2,000-3,000 lines saved across 140+ services
**Current Adoption**: 23.7% (44 of 186 services)
**Adoption Target**: 75-80%
**Status**: ✅ Production-ready infrastructure
**Last Updated**: 2025-01-31
