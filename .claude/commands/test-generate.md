# /test-generate - Generate Repository Tests

Automated test generation for Butlery repositories. Creates comprehensive test files following established patterns from the codebase.

## Usage

```
/test-generate <repository_name>
```

**Examples**:
```
/test-generate firebase_auth_repository
/test-generate base_shared_content_repository
/test-generate firebase_shopping_repository
```

## What Gets Generated

A complete test file (~500-600 lines) including:

1. **File Header** - Repository description and imports
2. **Test Setup** - FakeFirebaseFirestore, mocks, test data
3. **Helper Methods** - Test data factories and seeders
4. **Permission Tests** - 5-10 tests (~150 lines)
5. **CRUD Tests** - 5-8 tests (~200 lines)
6. **Edge Case Tests** - 3-5 tests (~100 lines)
7. **Feature-Specific Tests** - Based on repository type

## Priority Repositories

### Critical Priority (Auth & Infrastructure)

**1. firebase_auth_repository.dart** 🔥
- **Why**: Core authentication - foundation for all operations
- **Tests Needed**:
  - Sign in/out, token refresh, auth state changes
  - Password reset, email verification
  - Error handling (invalid credentials, network errors)
- **Estimated Lines**: 400-500

**2. base_shared_content_repository.dart** 🔥
- **Why**: Base class for shared recipes/menus/shopping lists
- **Tests Needed**:
  - CRUD with permission validation
  - Ownership checks, shared content access
  - Member management
- **Estimated Lines**: 500-600

### High Priority (Core Features)

**3. firebase_shopping_repository.dart**
- **Why**: Shopping list operations (needs real Firestore tests)
- **Current**: Only mock tests exist
- **Tests Needed**: Full FakeFirebaseFirestore test suite
- **Estimated Lines**: 450-550

**4. firebase_social_recipe_repository.dart**
- **Why**: Social recipe sharing and collaboration
- **Current**: Partial tests exist
- **Tests Needed**: Complete permission validation, sharing workflows
- **Estimated Lines**: 500-600

**5. collaborative_recipe_repository.dart**
- **Why**: Real-time collaborative editing
- **Current**: Mock tests only
- **Tests Needed**: Real-time operations, concurrent editing
- **Estimated Lines**: 400-500

### Medium Priority

**6. firestore_repository.dart** (Infrastructure)
**7-10. Additional repositories** from testing dashboard

## Test Template Structure

### 1. File Header (10 lines)

```dart
/// Comprehensive unit tests for [RepositoryName].
///
/// Tests [key operations] including CRUD operations,
/// permission validation, and [specific features].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';

// Repository under test
import 'package:butlery/repositories/firebase/[repository_file].dart';

// Test infrastructure
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/di/test_service_locator.dart';
```

### 2. Test Setup (100 lines)

```dart
void main() {
  group('[RepositoryName] - [Feature]', () {
    late [RepositoryType] repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    // Test constants
    const testUserId = 'user-123';
    const testItemId = 'item-456';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(/* ... */);
    });

    setUp() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepo = MockAuthRepository();
      mockUser = FakeUser(uid: testUserId);

      when(() => mockAuthRepo.currentUser).thenReturn(mockUser);
      when(() => mockAuthRepo.currentUserId).thenReturn(testUserId);

      repository = [RepositoryType](
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    }

    tearDown() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    }

    // Test groups follow...
  });
}
```

### 3. Helper Methods (50-100 lines)

```dart
// Test data creation helpers
Recipe createTestRecipe({
  String? id,
  String? userId,
  String? title,
}) {
  return Recipe(
    id: id ?? testItemId,
    userId: userId ?? testUserId,
    title: title ?? 'Test Recipe',
    portions: 4,
    ingredients: [
      Ingredient(name: 'Flour', amount: '2', unit: 'cups'),
    ],
    instructions: ['Mix ingredients'],
    createdAt: DateTime(2025, 1, 1),
  );
}

// Seed data into Firestore
Future<void> seedRecipe(Recipe recipe) async {
  await fakeFirestore
      .collection('users')
      .doc(recipe.userId)
      .collection('recipes')
      .doc(recipe.id)
      .set(recipe.toFirestore());
}

Future<void> seedMultipleRecipes(int count) async {
  for (var i = 0; i < count; i++) {
    final recipe = createTestRecipe(
      id: 'recipe_$i',
      title: 'Recipe $i',
    );
    await seedRecipe(recipe);
  }
}
```

### 4. Permission Validation Tests (150 lines)

```dart
group('Permission Validation', () {
  test('should allow user to create their own recipe', () async {
    final recipe = createTestRecipe(userId: testUserId);

    final created = await repository.create(recipe);

    expect(created.id, recipe.id);
    expect(created.userId, testUserId);
  });

  test('should reject user from creating recipe for another user', () async {
    final recipe = createTestRecipe(userId: 'other-user');

    expect(
      () => repository.create(recipe),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  test('should reject create when user not authenticated', () async {
    when(() => mockAuthRepo.currentUserId).thenReturn(null);
    final recipe = createTestRecipe();

    expect(
      () => repository.create(recipe),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('should allow user to read their own recipe', () async {
    final recipe = createTestRecipe();
    await seedRecipe(recipe);

    final result = await repository.getById(testItemId);

    expect(result, isNotNull);
    expect(result!.id, testItemId);
  });

  test('should reject user from reading another user\'s recipe', () async {
    final recipe = createTestRecipe(userId: 'other-user');
    await seedRecipe(recipe);

    expect(
      () => repository.getById(testItemId),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  test('should allow owner to update recipe', () async {
    final recipe = createTestRecipe();
    await seedRecipe(recipe);

    final updated = recipe.copyWith(title: 'Updated Title');
    await repository.update(updated);

    final result = await repository.getById(testItemId);
    expect(result!.title, 'Updated Title');
  });

  test('should reject non-owner from updating recipe', () async {
    final recipe = createTestRecipe(userId: 'other-user');
    await seedRecipe(recipe);

    expect(
      () => repository.update(recipe),
      throwsA(isA<PermissionDeniedException>()),
    );
  });

  test('should only allow owner to delete recipe', () async {
    final recipe = createTestRecipe(userId: 'other-user');
    await seedRecipe(recipe);

    expect(
      () => repository.delete(testItemId),
      throwsA(isA<PermissionDeniedException>()),
    );
  });
});
```

### 5. CRUD Operation Tests (200 lines)

```dart
group('CRUD Operations', () {
  test('should create recipe successfully', () async {
    final recipe = createTestRecipe();

    final created = await repository.create(recipe);

    expect(created.id, recipe.id);
    expect(created.title, recipe.title);

    // Verify in Firestore
    final doc = await fakeFirestore
        .collection('users')
        .doc(testUserId)
        .collection('recipes')
        .doc(testItemId)
        .get();

    expect(doc.exists, isTrue);
    expect(doc['title'], 'Test Recipe');
  });

  test('should get recipe by ID', () async {
    final recipe = createTestRecipe();
    await seedRecipe(recipe);

    final result = await repository.getById(testItemId);

    expect(result, isNotNull);
    expect(result!.id, testItemId);
    expect(result.title, 'Test Recipe');
  });

  test('should return null for non-existent recipe', () async {
    final result = await repository.getById('nonexistent');

    expect(result, isNull);
  });

  test('should get all user recipes', () async {
    await seedMultipleRecipes(5);

    final results = await repository.getUserRecipes(testUserId);

    expect(results.length, 5);
    expect(results[0].userId, testUserId);
  });

  test('should update recipe successfully', () async {
    final recipe = createTestRecipe();
    await seedRecipe(recipe);

    final updated = recipe.copyWith(
      title: 'Updated Title',
      portions: 8,
    );

    await repository.update(updated);

    final result = await repository.getById(testItemId);
    expect(result!.title, 'Updated Title');
    expect(result.portions, 8);
  });

  test('should delete recipe successfully', () async {
    final recipe = createTestRecipe();
    await seedRecipe(recipe);

    await repository.delete(testItemId);

    final result = await repository.getById(testItemId);
    expect(result, isNull);

    // Verify removed from Firestore
    final doc = await fakeFirestore
        .collection('users')
        .doc(testUserId)
        .collection('recipes')
        .doc(testItemId)
        .get();

    expect(doc.exists, isFalse);
  });

  test('should batch create multiple recipes', () async {
    final recipes = List.generate(
      3,
      (i) => createTestRecipe(id: 'recipe_$i', title: 'Recipe $i'),
    );

    await repository.batchCreate(recipes);

    final results = await repository.getUserRecipes(testUserId);
    expect(results.length, 3);
  });
});
```

### 6. Edge Case Tests (100 lines)

```dart
group('Edge Cases', () {
  test('should handle user not authenticated', () async {
    when(() => mockAuthRepo.currentUserId).thenReturn(null);

    expect(
      () => repository.getUserRecipes('user-123'),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('should handle empty recipe list', () async {
    final results = await repository.getUserRecipes(testUserId);

    expect(results, isEmpty);
  });

  test('should handle creating recipe with missing fields', () async {
    final invalidRecipe = createTestRecipe(title: '');

    expect(
      () => repository.create(invalidRecipe),
      throwsA(isA<ValidationException>()),
    );
  });

  test('should handle updating non-existent recipe', () async {
    final recipe = createTestRecipe();

    expect(
      () => repository.update(recipe),
      throwsA(isA<NotFoundException>()),
    );
  });

  test('should handle deleting non-existent recipe', () async {
    // Should not throw, just no-op
    await repository.delete('nonexistent');

    // Verify no error occurred
  });
});
```

## Step-by-Step Generation Workflow

### Step 1: Analyze Repository

```
1. Read repository file: lib/repositories/firebase/[repository].dart
2. Identify:
   - Repository type (user-scoped vs global)
   - Collection path
   - Model type
   - Custom methods
   - Permission validation approach
```

### Step 2: Check Existing Tests

```
1. Look for existing test: test/unit/repositories/[repository]_test.dart
2. If exists:
   - Analyze coverage gaps
   - Determine what to add
3. If doesn't exist:
   - Start from template
```

### Step 3: Generate Test File

```
1. Copy template structure
2. Replace [RepositoryName], [RepositoryType], etc.
3. Add repository-specific:
   - Test data factories
   - Feature-specific test groups
   - Custom validation tests
4. Ensure 500-600 lines of comprehensive tests
```

### Step 4: Verify & Run

```
1. Format code: dart format test/unit/repositories/[repository]_test.dart
2. Run tests: flutter test test/unit/repositories/[repository]_test.dart
3. Fix any errors
4. Verify all tests pass
```

## Repository-Specific Patterns

### User-Scoped Repository

```dart
// Collection path: users/{userId}/recipes
setUp() {
  repository = RecipeRepository(
    firestore: fakeFirestore,
    authRepository: mockAuthRepo,
  );
}

Future<void> seedRecipe(Recipe recipe) async {
  await fakeFirestore
      .collection('users')
      .doc(recipe.userId)
      .collection('recipes')
      .doc(recipe.id)
      .set(recipe.toFirestore());
}
```

### Global Collection Repository

```dart
// Collection path: sharedRecipes
setUp() {
  repository = SharedRecipeRepository(
    firestore: fakeFirestore,
    authRepository: mockAuthRepo,
  );
}

Future<void> seedSharedRecipe(SharedRecipe recipe) async {
  await fakeFirestore
      .collection('sharedRecipes')
      .doc(recipe.id)
      .set(recipe.toFirestore());
}
```

### Repository with Subcollections

```dart
// Comments subcollection under recipes
Future<void> seedComment(Comment comment) async {
  await fakeFirestore
      .collection('sharedRecipes')
      .doc(comment.recipeId)
      .collection('comments')
      .doc(comment.id)
      .set(comment.toFirestore());
}

test('should get all comments for recipe', () async {
  await seedMultipleComments(recipeId: 'recipe_1', count: 3);

  final comments = await repository.getCommentsForRecipe('recipe_1');

  expect(comments.length, 3);
});
```

## Feature-Specific Test Groups

### Social Features (Friends, Sharing)

```dart
group('Sharing Operations', () {
  test('should share recipe with friend', () async { ... });
  test('should unshare recipe', () async { ... });
  test('should get recipes shared with user', () async { ... });
});
```

### Real-time Features

```dart
group('Real-time Operations', () {
  test('should watch recipe changes', () async { ... });
  test('should watch collection changes', () async { ... });
});
```

### Ratings & Comments

```dart
group('Rating Operations', () {
  test('should add rating to recipe', () async { ... });
  test('should calculate average rating', () async { ... });
  test('should get user rating for recipe', () async { ... });
});
```

## Example: Complete Generated Test

See existing comprehensive tests for reference:
- `test/unit/repositories/firebase_shared_recipe_repository_test.dart` (519 lines)
- `test/unit/repositories/firebase_comments_repository_test.dart` (711 lines)
- `test/unit/repositories/firebase_user_repository_test.dart`

## Testing Checklist

After generating tests, verify:

- [ ] All imports correct
- [ ] Test setup/teardown complete
- [ ] Helper methods for test data
- [ ] Permission validation tests (8-10 tests)
- [ ] CRUD operation tests (6-8 tests)
- [ ] Edge case tests (4-5 tests)
- [ ] Feature-specific tests (varies)
- [ ] All tests pass: `flutter test test/unit/repositories/[repository]_test.dart`
- [ ] Code formatted: `dart format`
- [ ] No warnings: `flutter analyze`

## Benefits

- **Consistent Testing**: All repositories tested the same way
- **Comprehensive Coverage**: 500-600 lines covers all scenarios
- **Fast Development**: Generate instead of write from scratch
- **Quality Assurance**: Catches permission bugs, edge cases
- **Documentation**: Tests document expected behavior

## Next Steps After Generation

1. **Run Tests**: Verify all pass
2. **Review Coverage**: Check for gaps
3. **Add Feature Tests**: Add repository-specific scenarios
4. **Commit**: Create commit with generated tests

---

**Estimated Time**: 15-20 minutes per repository test generation
**Skill Required**: testing-patterns, firebase-repository-patterns
