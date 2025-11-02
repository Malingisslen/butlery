# Repository Testing Guide

This guide covers testing Firebase repositories using FakeFirebaseFirestore, permission validation, and CRUD operations.

## Testing Infrastructure

### Required Dependencies

```yaml
dev_dependencies:
  fake_cloud_firestore: ^4.0.0
  firebase_auth_mocks: ^0.15.0
  mocktail: ^1.0.4
```

### Test Base Setup

```dart
void main() {
  group('FirebaseRecipeRepository', () {
    late FirebaseRecipeRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();

      // Create mock auth repository
      mockAuthRepo = MockAuthRepository();
      mockAuthRepo.setAuthState(
        userId: 'test-user-123',
        isAuthenticated: true,
      );

      // Create repository with fakes
      repository = FirebaseRecipeRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() {
      // Clean up if needed
    });
  });
}
```

## Testing CRUD Operations

### Create Operation

```dart
test('create() saves recipe to Firestore', () async {
  // Arrange
  final recipe = Recipe(
    id: 'recipe-1',
    title: 'Test Recipe',
    ingredients: ['Ingredient 1', 'Ingredient 2'],
    portions: 4,
    createdBy: 'test-user-123',
    createdAt: DateTime.now(),
  );

  // Act
  final created = await repository.create(recipe);

  // Assert
  expect(created.id, equals('recipe-1'));
  expect(created.title, equals('Test Recipe'));

  // Verify in Firestore
  final doc = await fakeFirestore
      .collection('users/test-user-123/recipes')
      .doc('recipe-1')
      .get();

  expect(doc.exists, isTrue);
  expect(doc.data()!['title'], equals('Test Recipe'));
  expect(doc.data()!['portions'], equals(4));
});
```

### Read Operation

```dart
test('read() retrieves recipe from Firestore', () async {
  // Arrange - Pre-populate Firestore
  await fakeFirestore
      .collection('users/test-user-123/recipes')
      .doc('recipe-1')
      .set({
    'title': 'Existing Recipe',
    'ingredients': ['Ingredient 1'],
    'portions': 4,
    'createdBy': 'test-user-123',
    'createdAt': Timestamp.now(),
  });

  // Act
  final recipe = await repository.read('recipe-1');

  // Assert
  expect(recipe, isNotNull);
  expect(recipe!.id, equals('recipe-1'));
  expect(recipe.title, equals('Existing Recipe'));
});

test('read() returns null when recipe not found', () async {
  // Act
  final recipe = await repository.read('non-existent-id');

  // Assert
  expect(recipe, isNull);
});
```

### Update Operation

```dart
test('update() modifies recipe in Firestore', () async {
  // Arrange - Create initial recipe
  final initialRecipe = Recipe(
    id: 'recipe-1',
    title: 'Original Title',
    ingredients: ['Ingredient 1'],
    portions: 4,
    createdBy: 'test-user-123',
    createdAt: DateTime.now(),
  );
  await repository.create(initialRecipe);

  // Act - Update recipe
  final updatedRecipe = initialRecipe.copyWith(
    title: 'Updated Title',
    portions: 6,
  );
  await repository.update(updatedRecipe);

  // Assert
  final doc = await fakeFirestore
      .collection('users/test-user-123/recipes')
      .doc('recipe-1')
      .get();

  expect(doc.data()!['title'], equals('Updated Title'));
  expect(doc.data()!['portions'], equals(6));
});
```

### Delete Operation

```dart
test('delete() removes recipe from Firestore', () async {
  // Arrange
  await repository.create(Recipe(
    id: 'recipe-1',
    title: 'Recipe to Delete',
    createdBy: 'test-user-123',
    createdAt: DateTime.now(),
  ));

  // Act
  await repository.delete('recipe-1');

  // Assert
  final doc = await fakeFirestore
      .collection('users/test-user-123/recipes')
      .doc('recipe-1')
      .get();

  expect(doc.exists, isFalse);
});
```

### ReadAll Operation

```dart
test('readAll() retrieves all user recipes', () async {
  // Arrange - Create multiple recipes
  await repository.create(Recipe(
    id: 'recipe-1',
    title: 'Recipe 1',
    createdBy: 'test-user-123',
    createdAt: DateTime.now(),
  ));
  await repository.create(Recipe(
    id: 'recipe-2',
    title: 'Recipe 2',
    createdBy: 'test-user-123',
    createdAt: DateTime.now(),
  ));

  // Act
  final recipes = await repository.readAll();

  // Assert
  expect(recipes, hasLength(2));
  expect(recipes.map((r) => r.title), containsAll(['Recipe 1', 'Recipe 2']));
});

test('readAll() returns empty list when no recipes', () async {
  // Act
  final recipes = await repository.readAll();

  // Assert
  expect(recipes, isEmpty);
});
```

## Testing Permission Validation

### Authentication Checks

```dart
test('create() rejects unauthenticated user', () async {
  // Arrange
  mockAuthRepo.setAuthState(user: null, userId: null, isAuthenticated: false);
  final recipe = Recipe(
    id: 'recipe-1',
    title: 'Test Recipe',
    createdBy: 'test-user-123',
    createdAt: DateTime.now(),
  );

  // Act & Assert
  expect(
    () => repository.create(recipe),
    throwsA(isA<AuthenticationException>()),
  );
});

test('create() allows authenticated user', () async {
  // Arrange
  mockAuthRepo.setAuthState(
    userId: 'test-user-123',
    isAuthenticated: true,
  );
  final recipe = Recipe(
    id: 'recipe-1',
    title: 'Test Recipe',
    createdBy: 'test-user-123',
    createdAt: DateTime.now(),
  );

  // Act
  final created = await repository.create(recipe);

  // Assert
  expect(created, isNotNull);
});
```

### Ownership Validation

```dart
test('update() rejects when user does not own recipe', () async {
  // Arrange - Recipe owned by different user
  await fakeFirestore
      .collection('users/other-user/recipes')
      .doc('recipe-1')
      .set({
    'title': 'Other User Recipe',
    'createdBy': 'other-user',
    'createdAt': Timestamp.now(),
  });

  final recipe = Recipe(
    id: 'recipe-1',
    title: 'Updated Title',
    createdBy: 'other-user',
    createdAt: DateTime.now(),
  );

  // Act & Assert
  expect(
    () => repository.update(recipe),
    throwsA(isA<PermissionDeniedException>()),
  );
});

test('delete() rejects when user does not own recipe', () async {
  // Arrange
  mockAuthRepo.setAuthState(userId: 'test-user-123');

  // Act & Assert
  expect(
    () => repository.delete('recipe-owned-by-other-user'),
    throwsA(isA<PermissionDeniedException>()),
  );
});
```

### Shared Content Access

```dart
test('read() allows access to shared recipe', () async {
  // Arrange - Recipe shared with current user
  await fakeFirestore.collection('shared_recipes').doc('recipe-1').set({
    'title': 'Shared Recipe',
    'ownerId': 'other-user',
    'sharedWith': ['test-user-123'],  // Current user has access
    'createdAt': Timestamp.now(),
  });

  // Act
  final recipe = await repository.read('recipe-1');

  // Assert
  expect(recipe, isNotNull);
  expect(recipe!.title, equals('Shared Recipe'));
});

test('read() denies access to non-shared recipe', () async {
  // Arrange - Recipe NOT shared with current user
  await fakeFirestore.collection('shared_recipes').doc('recipe-1').set({
    'title': 'Private Recipe',
    'ownerId': 'other-user',
    'sharedWith': ['different-user'],  // Current user NOT in list
    'createdAt': Timestamp.now(),
  });

  // Act
  final recipe = await repository.read('recipe-1');

  // Assert
  expect(recipe, isNull);  // Or throwsA(isA<PermissionDeniedException>())
});
```

## Testing Streaming Operations

### Watch Single Entity

```dart
test('watch() emits recipe updates', () async {
  // Arrange - Create initial recipe
  await repository.create(Recipe(
    id: 'recipe-1',
    title: 'Initial Title',
    createdBy: 'test-user-123',
    createdAt: DateTime.now(),
  ));

  // Act - Start watching
  final stream = repository.watch('recipe-1');

  // Collect emissions
  final emissions = <Recipe?>[];
  final subscription = stream.listen(emissions.add);

  // Wait for initial emission
  await Future.delayed(Duration(milliseconds: 100));

  // Update recipe
  await repository.update(Recipe(
    id: 'recipe-1',
    title: 'Updated Title',
    createdBy: 'test-user-123',
    createdAt: DateTime.now(),
  ));

  // Wait for update emission
  await Future.delayed(Duration(milliseconds: 100));

  // Assert
  expect(emissions, hasLength(2));
  expect(emissions[0]!.title, equals('Initial Title'));
  expect(emissions[1]!.title, equals('Updated Title'));

  await subscription.cancel();
});

test('watch() emits null when recipe deleted', () async {
  // Arrange
  await repository.create(Recipe(
    id: 'recipe-1',
    title: 'Recipe',
    createdBy: 'test-user-123',
    createdAt: DateTime.now(),
  ));

  final stream = repository.watch('recipe-1');
  final emissions = <Recipe?>[];
  final subscription = stream.listen(emissions.add);

  await Future.delayed(Duration(milliseconds: 100));

  // Act - Delete recipe
  await repository.delete('recipe-1');
  await Future.delayed(Duration(milliseconds: 100));

  // Assert
  expect(emissions.last, isNull);

  await subscription.cancel();
});
```

### Watch Collection

```dart
test('watchAll() emits collection updates', () async {
  // Arrange
  final stream = repository.watchAll();
  final emissions = <List<Recipe>>[];
  final subscription = stream.listen(emissions.add);

  await Future.delayed(Duration(milliseconds: 100));

  // Act - Add recipes
  await repository.create(Recipe(
    id: 'recipe-1',
    title: 'Recipe 1',
    createdBy: 'test-user-123',
    createdAt: DateTime.now(),
  ));

  await Future.delayed(Duration(milliseconds: 100));

  await repository.create(Recipe(
    id: 'recipe-2',
    title: 'Recipe 2',
    createdBy: 'test-user-123',
    createdAt: DateTime.now(),
  ));

  await Future.delayed(Duration(milliseconds: 100));

  // Assert
  expect(emissions, hasLength(3));
  expect(emissions[0], isEmpty);
  expect(emissions[1], hasLength(1));
  expect(emissions[2], hasLength(2));

  await subscription.cancel();
});
```

## Testing Batch Operations

```dart
test('batchCreate() saves multiple recipes', () async {
  // Arrange
  final recipes = [
    Recipe(id: 'recipe-1', title: 'Recipe 1', createdBy: 'test-user-123', createdAt: DateTime.now()),
    Recipe(id: 'recipe-2', title: 'Recipe 2', createdBy: 'test-user-123', createdAt: DateTime.now()),
    Recipe(id: 'recipe-3', title: 'Recipe 3', createdBy: 'test-user-123', createdAt: DateTime.now()),
  ];

  // Act
  await repository.batchCreate(recipes);

  // Assert
  final allRecipes = await repository.readAll();
  expect(allRecipes, hasLength(3));
});

test('batchDelete() removes multiple recipes', () async {
  // Arrange
  await repository.batchCreate([
    Recipe(id: 'recipe-1', title: 'Recipe 1', createdBy: 'test-user-123', createdAt: DateTime.now()),
    Recipe(id: 'recipe-2', title: 'Recipe 2', createdBy: 'test-user-123', createdAt: DateTime.now()),
  ]);

  // Act
  await repository.batchDelete(['recipe-1', 'recipe-2']);

  // Assert
  final recipes = await repository.readAll();
  expect(recipes, isEmpty);
});
```

## Testing User-Scoped vs Global Collections

### User-Scoped Repository

```dart
test('user-scoped repository uses correct collection path', () async {
  // Arrange
  final recipe = Recipe(
    id: 'recipe-1',
    title: 'User Recipe',
    createdBy: 'test-user-123',
    createdAt: DateTime.now(),
  );

  // Act
  await repository.create(recipe);

  // Assert - Verify path
  final doc = await fakeFirestore
      .collection('users/test-user-123/recipes')  // User-scoped path
      .doc('recipe-1')
      .get();

  expect(doc.exists, isTrue);
});

test('user-scoped repository only returns current user data', () async {
  // Arrange - Add recipes for multiple users
  await fakeFirestore.collection('users/user-1/recipes').doc('recipe-1').set({
    'title': 'User 1 Recipe',
    'createdBy': 'user-1',
    'createdAt': Timestamp.now(),
  });

  await fakeFirestore.collection('users/user-2/recipes').doc('recipe-2').set({
    'title': 'User 2 Recipe',
    'createdBy': 'user-2',
    'createdAt': Timestamp.now(),
  });

  mockAuthRepo.setAuthState(userId: 'user-1');

  // Act
  final recipes = await repository.readAll();

  // Assert - Only user-1's recipes
  expect(recipes, hasLength(1));
  expect(recipes[0].title, equals('User 1 Recipe'));
});
```

### Global Repository

```dart
test('global repository uses shared collection path', () async {
  // Arrange
  final sharedRecipe = SharedRecipe(
    id: 'shared-recipe-1',
    title: 'Shared Recipe',
    ownerId: 'test-user-123',
    sharedWith: ['user-2', 'user-3'],
    createdAt: DateTime.now(),
  );

  // Act
  await sharedRecipeRepository.create(sharedRecipe);

  // Assert - Verify global path
  final doc = await fakeFirestore
      .collection('shared_recipes')  // Global path, not user-scoped
      .doc('shared-recipe-1')
      .get();

  expect(doc.exists, isTrue);
});
```

## Testing Error Scenarios

```dart
test('handles Firestore errors gracefully', () async {
  // Arrange - Simulate Firestore error
  // Note: FakeFirebaseFirestore doesn't easily simulate errors
  // Use a custom mock or test with real Firebase emulator

  // Example pattern:
  expect(
    () => repository.create(invalidRecipe),
    throwsA(isA<FirestoreException>()),
  );
});

test('handles network errors', () async {
  // This typically requires mocking the Firestore instance
  // Or using Firebase emulator with network simulation
});
```

## Test Helpers

### MockAuthRepository

```dart
class MockAuthRepository extends Mock implements AuthRepository {
  String? _userId;
  bool _isAuthenticated = false;

  void setAuthState({
    String? userId,
    bool isAuthenticated = true,
  }) {
    _userId = userId;
    _isAuthenticated = isAuthenticated;
  }

  @override
  String? get currentUserId => _userId;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Stream<String?> get authStateChanges => Stream.value(_userId);
}
```

### RecipeFactory

```dart
class RecipeFactory {
  static Recipe build({
    String? id,
    String? title,
    List<String>? ingredients,
    int? portions,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return Recipe(
      id: id ?? const Uuid().v4(),
      title: title ?? 'Test Recipe',
      ingredients: ingredients ?? ['Ingredient 1', 'Ingredient 2'],
      portions: portions ?? 4,
      createdBy: createdBy ?? 'test-user-123',
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  static List<Recipe> buildList(int count) {
    return List.generate(
      count,
      (index) => build(
        id: 'recipe-$index',
        title: 'Recipe $index',
      ),
    );
  }
}
```

## Best Practices

### ✅ DO:
- Use FakeFirebaseFirestore for all repository tests
- Test all CRUD operations
- Test permission validation thoroughly
- Test streaming operations
- Clean up streams (cancel subscriptions)
- Use test factories for consistent data
- Test both success and failure scenarios
- Verify data in Firestore after operations

### ❌ DON'T:
- Use real Firebase in unit tests
- Skip permission validation tests
- Leave subscriptions uncanceled
- Hardcode test data
- Test private repository methods directly
- Depend on test execution order
- Mix repository tests with service tests

## Common Patterns

### Testing with Multiple Users

```dart
test('filters data by user', () async {
  // User 1
  mockAuthRepo.setAuthState(userId: 'user-1');
  await repository.create(RecipeFactory.build(createdBy: 'user-1'));

  // User 2
  mockAuthRepo.setAuthState(userId: 'user-2');
  await repository.create(RecipeFactory.build(createdBy: 'user-2'));

  // Back to User 1
  mockAuthRepo.setAuthState(userId: 'user-1');
  final recipes = await repository.readAll();

  expect(recipes, hasLength(1));
  expect(recipes[0].createdBy, equals('user-1'));
});
```

### Testing Timestamp Conversion

```dart
test('fromFirestore() converts Timestamp to DateTime', () async {
  // Arrange
  final now = DateTime.now();
  await fakeFirestore.collection('users/test-user-123/recipes').doc('recipe-1').set({
    'title': 'Recipe',
    'createdAt': Timestamp.fromDate(now),
    'createdBy': 'test-user-123',
  });

  // Act
  final recipe = await repository.read('recipe-1');

  // Assert
  expect(recipe!.createdAt.millisecondsSinceEpoch,
      closeTo(now.millisecondsSinceEpoch, 1000));
});
```

---

**See Also**:
- [Service Testing](./service-testing.md) - Testing services with mocked repositories
- [Test Factories](./test-factories.md) - Test data generation patterns
- [Testing Patterns Overview](../SKILL.md) - Complete testing guide
