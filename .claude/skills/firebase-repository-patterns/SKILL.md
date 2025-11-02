# Firebase Repository Patterns

Comprehensive guide to Butlery's Firebase repository patterns, including BaseFirebaseRepository usage, permission validation, and Firestore best practices.

## Overview

All Firebase repositories in Butlery follow consistent patterns:
- Extend **BaseFirebaseRepository** for standard CRUD operations
- Implement **permission validation** on all operations
- Use **audit logging** for security-sensitive actions
- Support **real-time streams** via watch() methods
- Handle **user-scoped** vs **global** collections correctly

## Core Patterns

### Repository Architecture

```
BaseFirebaseRepository<T>
  ├── CRUD Operations (create, update, delete, getById)
  ├── Permission Validation (validateCreatePermission, etc.)
  ├── Audit Logging (logAuditEvent)
  ├── Streaming Support (watch, watchAll)
  └── Batch Operations (batchCreate, batchUpdate)

Your Repository extends BaseFirebaseRepository<Recipe>
  ├── Domain-specific queries (getUserRecipes, getPublicRecipes)
  ├── Custom validation (recipe title validation, etc.)
  └── Business logic helpers (duplicate recipe, etc.)
```

### Permission Model

Every repository operation validates permissions:
- **Create**: User authenticated, within quota limits
- **Read**: User owns resource OR resource is shared with user
- **Update**: User owns resource OR has edit permissions
- **Delete**: User owns resource

## Quick Reference

### Creating a New Repository

```dart
class MyRepository extends BaseFirebaseRepository<MyModel> {
  MyRepository({
    required FirebaseFirestore firestore,
    required AuthRepository authRepository,
  }) : super(
    firestore: firestore,
    authRepository: authRepository,
    collectionPath: 'myCollection', // or user-scoped: 'users/{userId}/myCollection'
  );

  @override
  MyModel fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MyModel.fromMap(data);
  }

  @override
  Map<String, dynamic> toFirestore(MyModel model) {
    return model.toMap();
  }

  @override
  Future<void> validateCreatePermission(MyModel model) async {
    await super.validateCreatePermission(model);
    // Add custom validation
    if (model.title.isEmpty) {
      throw ValidationException('Title required');
    }
  }
}
```

### Using Repository in Service

```dart
class MyService extends BaseService {
  final MyRepository _repository;

  MyService({required MyRepository repository})
      : _repository = repository,
        super(serviceName: 'MyService');

  Future<MyModel?> getById(String id) async {
    return await executeServiceOperation(
      () => _repository.getById(id),
      operationName: 'Get item',
    );
  }

  Future<MyModel> create(MyModel model) async {
    return await executeServiceOperation(
      () => _repository.create(model),
      operationName: 'Create item',
    );
  }
}
```

### Testing Repositories

```dart
void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockAuthRepository mockAuth;
  late MyRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockAuthRepository();
    when(() => mockAuth.currentUserId).thenReturn('user_1');

    repository = MyRepository(
      firestore: fakeFirestore,
      authRepository: mockAuth,
    );
  });

  test('creates document', () async {
    final model = MyModel(id: '1', title: 'Test');
    await repository.create(model);

    final doc = await fakeFirestore.collection('myCollection').doc('1').get();
    expect(doc.exists, isTrue);
  });
}
```

## When to Use This Skill

Auto-activates when:
- Creating new repository classes
- Working with Firebase/Firestore operations
- Implementing permission validation
- Adding CRUD operations
- Debugging repository issues
- Writing repository tests

## Deep Dive Resources

Explore specific repository patterns:

1. **[Base Repository Usage](resources/base-repository-usage.md)**
   - Extending BaseFirebaseRepository
   - Collection path patterns (user-scoped vs global)
   - fromFirestore and toFirestore implementation
   - CRUD operations and error handling

2. **[Permission Validation Patterns](resources/permission-validation-patterns.md)**
   - validateCreatePermission, validateUpdatePermission, etc.
   - Ownership validation
   - Shared resource permissions
   - Role-based access control
   - Security audit logging

3. **[Firestore Operations](resources/firestore-operations.md)**
   - Query patterns (where, orderBy, limit)
   - Real-time streams (watch, watchAll)
   - Batch operations (batch writes, transactions)
   - Pagination and infinite scroll
   - Optimistic updates

## Critical Rules

### NEVER Bypass Repository Layer

```dart
// ❌ CRITICAL VIOLATION - Direct Firestore access
final doc = await FirebaseFirestore.instance
    .collection('recipes')
    .doc(id)
    .get();

// ✅ CORRECT - Use repository
final recipe = await _recipeRepository.getById(id);
```

**Why**: Repository layer enforces permissions, audit logging, and consistent error handling.

### ALWAYS Validate Permissions

```dart
// ❌ WRONG - Missing permission check
Future<Recipe> updateRecipe(Recipe recipe) async {
  final docRef = _firestore.collection('recipes').doc(recipe.id);
  await docRef.update(recipe.toMap());
  return recipe;
}

// ✅ CORRECT - Permission validated
Future<Recipe> updateRecipe(Recipe recipe) async {
  await validateUpdatePermission(recipe);
  await logAuditEvent('recipe_updated', recipe.id);
  return await update(recipe);
}
```

### ALWAYS Use User-Scoped Collections for Personal Data

```dart
// ❌ WRONG - Global collection for user data
collectionPath: 'recipes'

// ✅ CORRECT - User-scoped collection
collectionPath: 'users/{userId}/recipes'
```

**Why**: User-scoped collections automatically enforce data isolation and simplify Firestore security rules.

## Repository Adoption Status

**Current State**: Partial adoption of BaseFirebaseRepository
- High-value: All critical repositories use BaseFirebaseRepository
- Opportunity: Legacy repositories can be migrated for consistency

**When touching legacy repositories**: Migrate to BaseFirebaseRepository pattern for better maintainability.

## Common Patterns

### User-Scoped Collection

```dart
class PersonalRecipeRepository extends BaseFirebaseRepository<Recipe> {
  PersonalRecipeRepository({
    required super.firestore,
    required super.authRepository,
  }) : super(
    collectionPath: 'users/{userId}/recipes',
  );

  Future<List<Recipe>> getUserRecipes() async {
    final userId = authRepository.currentUserId!;
    return await query(
      (collection) => collection.where('userId', isEqualTo: userId),
    );
  }
}
```

### Global Shared Collection

```dart
class SharedRecipeRepository extends BaseFirebaseRepository<SharedRecipe> {
  SharedRecipeRepository({
    required super.firestore,
    required super.authRepository,
  }) : super(
    collectionPath: 'sharedRecipes',
  );

  Future<List<SharedRecipe>> getSharedWithMe() async {
    final userId = authRepository.currentUserId!;
    return await query(
      (collection) => collection
          .where('sharedWith', arrayContains: userId),
    );
  }
}
```

### Real-time Streaming

```dart
Stream<Recipe?> watchRecipe(String recipeId) {
  return watch(recipeId);
}

Stream<List<Recipe>> watchUserRecipes() {
  final userId = authRepository.currentUserId!;
  return queryStream(
    (collection) => collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true),
  );
}
```

## Anti-Patterns to Avoid

### 1. Direct Firestore Instance Access (🔥 CRITICAL)

```dart
// ❌ CRITICAL - Bypasses all repository protections
FirebaseFirestore.instance.collection('recipes').add(data);

// ✅ CORRECT
_recipeRepository.create(recipe);
```

### 2. Missing Permission Validation (🔥 CRITICAL)

```dart
// ❌ CRITICAL - Anyone can delete anything
Future<void> delete(String id) async {
  await _firestore.collection('recipes').doc(id).delete();
}

// ✅ CORRECT
Future<void> delete(String id) async {
  final recipe = await getById(id);
  await validateDeletePermission(recipe);
  await logAuditEvent('recipe_deleted', id);
  await super.delete(id);
}
```

### 3. Inconsistent Error Handling (🔥 HIGH)

```dart
// ❌ WRONG - Swallows errors
try {
  await _firestore.collection('recipes').doc(id).get();
} catch (e) {
  return null;
}

// ✅ CORRECT - Use repository's error handling
return await safeOperation(
  () => getById(id),
  operationName: 'Get recipe',
);
```

## Testing Checklist

When testing repositories:
- ✅ Test all CRUD operations
- ✅ Test permission validation (auth, ownership, sharing)
- ✅ Test error scenarios (not found, unauthorized, network)
- ✅ Test streaming operations
- ✅ Test batch operations
- ✅ Verify audit logging for security-sensitive operations

## Related Skills

- **butlery-architecture** - Overall architecture patterns
- **testing-patterns** - Repository testing strategies
- **code-deduplication-utilities** - BaseFirebaseRepository and mixins

## Examples from Codebase

See real implementations:
- `lib/repositories/firebase/firebase_recipe_repository.dart` - Personal recipes
- `lib/repositories/firebase/firebase_social_recipe_repository.dart` - Shared recipes
- `lib/repositories/firebase/firebase_friends_repository.dart` - Friend management
- `lib/repositories/base/base_firebase_repository.dart` - Base implementation
