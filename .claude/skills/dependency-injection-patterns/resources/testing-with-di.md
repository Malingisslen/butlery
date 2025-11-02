# Testing with Dependency Injection

Comprehensive guide to testing services with mocks using TestServiceLocator in Butlery.

## Overview

Testing with DI in Butlery uses a separate test container that mirrors production:
- **TestServiceLocator** - Separate DI container for tests
- **Mock Registration** - Register mocks instead of real implementations
- **Setup/Teardown** - Clean test isolation
- **Same Structure** - 7 modules mirrored in tests

**Key Benefit**: Services depend on DI → easy to inject mocks for testing.

## TestServiceLocator

**Purpose**: Separate DI container for tests with mock support

**Location**: `test/infrastructure/di/test_service_locator.dart`

**Lifecycle**:
1. `setup()` - Initialize test container
2. `registerMock()` - Replace service with mock
3. `reset()` - Clean up after test

### Basic Usage

```dart
import 'package:butlery/test/infrastructure/di/test_service_locator.dart';

void main() {
  group('RecipeService Tests', () {
    late RecipeService service;
    late MockRecipeRepository mockRepository;

    setUpAll() async {
      // One-time setup: Initialize test service locator
      await TestServiceLocator.setup();
    });

    setUp() {
      // Per-test setup: Create mocks and register
      mockRepository = MockRecipeRepository();

      // Register mock (replaces real RecipeRepository)
      TestServiceLocator.registerMock<RecipeRepository>(mockRepository);

      // Get service under test (with injected mock)
      service = ServiceLocator.get<RecipeService>();
    });

    tearDown() async {
      // Per-test cleanup: Reset mocks
      await TestServiceLocator.reset();
    });

    test('getRecipe returns recipe from repository', () async {
      // Arrange: Setup mock behavior
      when(() => mockRepository.getById(any()))
          .thenAnswer((_) async => testRecipe);

      // Act: Call service
      final result = await service.getRecipe('recipe-123');

      // Assert: Verify result and mock was called
      expect(result, testRecipe);
      verify(() => mockRepository.getById('recipe-123')).called(1);
    });
  });
}
```

## Test Service Locator Setup

### setUpAll() - One-Time Initialization

**Purpose**: Initialize test DI container once for test suite

```dart
setUpAll() async {
  await TestServiceLocator.setup();
});
```

**What it does**:
1. Creates test GetIt instance
2. Registers all 7 modules (same as production)
3. Initializes test infrastructure

**When to call**: Once per test file (in setUpAll)

### setUp() - Per-Test Setup

**Purpose**: Register mocks for each test

```dart
setUp() {
  // Create mocks
  mockAuthRepository = MockAuthRepository();
  mockRecipeRepository = MockRecipeRepository();

  // Register mocks
  TestServiceLocator.registerMock<AuthRepository>(mockAuthRepository);
  TestServiceLocator.registerMock<RecipeRepository>(mockRecipeRepository);

  // Get service under test
  service = ServiceLocator.get<RecipeService>();
});
```

**What it does**:
1. Creates mock objects
2. Replaces real services with mocks
3. Gets service under test (with injected mocks)

**When to call**: Before each test (in setUp)

### tearDown() - Per-Test Cleanup

**Purpose**: Reset mocks after each test

```dart
tearDown() async {
  await TestServiceLocator.reset();
});
```

**What it does**:
1. Clears all registered mocks
2. Resets service locator state
3. Ensures clean state for next test

**When to call**: After each test (in tearDown)

## Mocking Dependencies

### Creating Mocks with Mocktail

```dart
import 'package:mocktail/mocktail.dart';

// Define mock class
class MockRecipeRepository extends Mock implements RecipeRepository {}
class MockUserService extends Mock implements UserService {}
class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockRecipeRepository mockRepository;

  setUp() {
    mockRepository = MockRecipeRepository();
  });
}
```

### Registering Mocks

```dart
setUp() {
  // Create mock
  mockRepository = MockRecipeRepository();

  // Register mock (replaces real RecipeRepository)
  TestServiceLocator.registerMock<RecipeRepository>(mockRepository);

  // Any service that depends on RecipeRepository will get the mock
  service = ServiceLocator.get<RecipeService>();
  // service._repository is now mockRepository ✅
});
```

### Setting Up Mock Behavior

**when() - Setup expected calls**:
```dart
// Return value
when(() => mockRepository.getById(any()))
    .thenAnswer((_) async => testRecipe);

// Throw exception
when(() => mockRepository.getById(any()))
    .thenThrow(Exception('Not found'));

// Return different values on successive calls
when(() => mockRepository.getById(any()))
    .thenAnswer((_) async => firstRecipe)
    .thenAnswer((_) async => secondRecipe);
```

### Verifying Mock Calls

**verify() - Check mock was called**:
```dart
// Verify called once with specific argument
verify(() => mockRepository.getById('recipe-123')).called(1);

// Verify called multiple times
verify(() => mockRepository.create(any())).called(3);

// Verify never called
verifyNever(() => mockRepository.delete(any()));

// Verify call order
verifyInOrder([
  () => mockRepository.getById('1'),
  () => mockRepository.getById('2'),
]);
```

## Testing Services

### Example 1: Simple Service Test

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/recipe_service.dart';
import 'package:butlery/repositories/recipe_repository.dart';
import 'package:butlery/test/infrastructure/di/test_service_locator.dart';

class MockRecipeRepository extends Mock implements RecipeRepository {}

void main() {
  group('RecipeService', () {
    late RecipeService service;
    late MockRecipeRepository mockRepository;

    setUpAll() async {
      await TestServiceLocator.setup();

      // Register fallback values for Mocktail
      registerFallbackValue(Recipe(
        id: '',
        title: '',
        userId: '',
        createdAt: DateTime.now(),
      ));
    });

    setUp() {
      mockRepository = MockRecipeRepository();
      TestServiceLocator.registerMock<RecipeRepository>(mockRepository);

      service = ServiceLocator.get<RecipeService>();
    });

    tearDown() async {
      await TestServiceLocator.reset();
    });

    test('getRecipe returns recipe from repository', () async {
      // Arrange
      final testRecipe = Recipe(id: 'recipe-123', title: 'Test Recipe');
      when(() => mockRepository.getById(any()))
          .thenAnswer((_) async => testRecipe);

      // Act
      final result = await service.getRecipe('recipe-123');

      // Assert
      expect(result, testRecipe);
      expect(result?.title, 'Test Recipe');
      verify(() => mockRepository.getById('recipe-123')).called(1);
    });

    test('createRecipe creates recipe in repository', () async {
      // Arrange
      final newRecipe = Recipe(id: 'new-123', title: 'New Recipe');
      when(() => mockRepository.create(any()))
          .thenAnswer((_) async => newRecipe);

      // Act
      final result = await service.createRecipe(newRecipe);

      // Assert
      expect(result.id, 'new-123');
      verify(() => mockRepository.create(newRecipe)).called(1);
    });

    test('deleteRecipe deletes from repository', () async {
      // Arrange
      when(() => mockRepository.delete(any()))
          .thenAnswer((_) async => {});

      // Act
      await service.deleteRecipe('recipe-123');

      // Assert
      verify(() => mockRepository.delete('recipe-123')).called(1);
    });
  });
}
```

### Example 2: Service with Multiple Dependencies

```dart
class MockRecipeRepository extends Mock implements RecipeRepository {}
class MockUserService extends Mock implements UserService {}
class MockPermissionService extends Mock implements PermissionService {}

void main() {
  group('SocialRecipeService', () {
    late SocialRecipeService service;
    late MockRecipeRepository mockRepository;
    late MockUserService mockUserService;
    late MockPermissionService mockPermissionService;

    setUpAll() async {
      await TestServiceLocator.setup();
    });

    setUp() {
      // Create all mocks
      mockRepository = MockRecipeRepository();
      mockUserService = MockUserService();
      mockPermissionService = MockPermissionService();

      // Register all mocks
      TestServiceLocator.registerMock<RecipeRepository>(mockRepository);
      TestServiceLocator.registerMock<UserService>(mockUserService);
      TestServiceLocator.registerMock<PermissionService>(mockPermissionService);

      // Get service (all dependencies injected as mocks)
      service = ServiceLocator.get<SocialRecipeService>();
    });

    tearDown() async {
      await TestServiceLocator.reset();
    });

    test('shareRecipe checks permissions before sharing', () async {
      // Arrange
      when(() => mockPermissionService.canShareRecipe(any()))
          .thenAnswer((_) async => true);
      when(() => mockRepository.shareRecipe(any(), any()))
          .thenAnswer((_) async => {});

      // Act
      await service.shareRecipe('recipe-123', ['user-456']);

      // Assert
      verify(() => mockPermissionService.canShareRecipe('recipe-123')).called(1);
      verify(() => mockRepository.shareRecipe('recipe-123', ['user-456'])).called(1);
    });

    test('shareRecipe throws when permission denied', () async {
      // Arrange
      when(() => mockPermissionService.canShareRecipe(any()))
          .thenAnswer((_) async => false);

      // Act & Assert
      expect(
        () => service.shareRecipe('recipe-123', ['user-456']),
        throwsA(isA<PermissionDeniedException>()),
      );

      verify(() => mockPermissionService.canShareRecipe('recipe-123')).called(1);
      verifyNever(() => mockRepository.shareRecipe(any(), any()));
    });
  });
}
```

## Testing ViewModels

### Example: ViewModel Test

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/recipe_viewmodel.dart';
import 'package:butlery/services/recipe_service.dart';
import 'package:butlery/test/infrastructure/di/test_service_locator.dart';

class MockRecipeService extends Mock implements RecipeService {}

void main() {
  group('RecipeViewModel', () {
    late RecipeViewModel viewModel;
    late MockRecipeService mockService;

    setUpAll() async {
      await TestServiceLocator.setup();
    });

    setUp() {
      mockService = MockRecipeService();
      TestServiceLocator.registerMock<RecipeService>(mockService);

      // ViewModel accesses service via ServiceLocator
      viewModel = RecipeViewModel();
    });

    tearDown() async {
      viewModel.dispose();
      await TestServiceLocator.reset();
    });

    test('loadRecipes loads recipes from service', () async {
      // Arrange
      final testRecipes = [
        Recipe(id: '1', title: 'Recipe 1'),
        Recipe(id: '2', title: 'Recipe 2'),
      ];
      when(() => mockService.getUserRecipes())
          .thenAnswer((_) async => testRecipes);

      // Act
      await viewModel.loadRecipes();

      // Assert
      expect(viewModel.recipes, testRecipes);
      expect(viewModel.recipes.length, 2);
      expect(viewModel.isLoading, isFalse);
      verify(() => mockService.getUserRecipes()).called(1);
    });

    test('loadRecipes sets error when service fails', () async {
      // Arrange
      when(() => mockService.getUserRecipes())
          .thenThrow(Exception('Network error'));

      // Act
      await viewModel.loadRecipes();

      // Assert
      expect(viewModel.hasError, isTrue);
      expect(viewModel.errorMessage, contains('Network error'));
      expect(viewModel.recipes, isEmpty);
    });
  });
}
```

## Testing Repositories

### Example: Repository Test with FakeFirestore

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/repositories/firebase_recipe_repository.dart';
import 'package:butlery/test/infrastructure/di/test_service_locator.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('FirebaseRecipeRepository', () {
    late FirebaseRecipeRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;

    setUpAll() async {
      await TestServiceLocator.setup();
    });

    setUp() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepo = MockAuthRepository();

      // Mock current user
      when(() => mockAuthRepo.currentUserId).thenReturn('user-123');

      // Register mocks
      TestServiceLocator.registerMock<FirestoreRepository>(
        FakeFirestoreRepository(firestore: fakeFirestore),
      );
      TestServiceLocator.registerMock<AuthRepository>(mockAuthRepo);

      repository = ServiceLocator.get<FirebaseRecipeRepository>();
    });

    tearDown() async {
      await TestServiceLocator.reset();
    });

    test('create stores recipe in Firestore', () async {
      // Arrange
      final recipe = Recipe(
        id: 'recipe-123',
        userId: 'user-123',
        title: 'Test Recipe',
        createdAt: DateTime.now(),
      );

      // Act
      await repository.create(recipe);

      // Assert: Verify in fake Firestore
      final doc = await fakeFirestore
          .collection('users')
          .doc('user-123')
          .collection('recipes')
          .doc('recipe-123')
          .get();

      expect(doc.exists, isTrue);
      expect(doc['title'], 'Test Recipe');
    });

    test('getById returns recipe from Firestore', () async {
      // Arrange: Seed fake Firestore
      await fakeFirestore
          .collection('users')
          .doc('user-123')
          .collection('recipes')
          .doc('recipe-123')
          .set({
        'id': 'recipe-123',
        'userId': 'user-123',
        'title': 'Test Recipe',
        'createdAt': Timestamp.now(),
      });

      // Act
      final result = await repository.getById('recipe-123');

      // Assert
      expect(result, isNotNull);
      expect(result!.id, 'recipe-123');
      expect(result.title, 'Test Recipe');
    });
  });
}
```

## Common Testing Patterns

### Pattern 1: Testing Service with BaseService

```dart
test('service logs operation', () async {
  // Arrange
  final mockLogger = MockLogger();
  TestServiceLocator.registerMock<Logger>(mockLogger);

  service = ServiceLocator.get<RecipeService>(); // BaseService logs

  when(() => mockRepository.getById(any()))
      .thenAnswer((_) async => testRecipe);

  // Act
  await service.getRecipe('recipe-123');

  // Assert: Verify logging
  verify(() => mockLogger.info(contains('Get recipe'))).called(1);
});
```

### Pattern 2: Testing Error Handling

```dart
test('service handles repository error', () async {
  // Arrange
  when(() => mockRepository.getById(any()))
      .thenThrow(Exception('Database error'));

  // Act & Assert
  expect(
    () => service.getRecipe('recipe-123'),
    throwsA(isA<Exception>()),
  );
});
```

### Pattern 3: Testing Async Operations

```dart
test('service handles multiple concurrent calls', () async {
  // Arrange
  when(() => mockRepository.getById(any()))
      .thenAnswer((_) async {
        await Future.delayed(Duration(milliseconds: 100));
        return testRecipe;
      });

  // Act: Call service concurrently
  final futures = [
    service.getRecipe('1'),
    service.getRecipe('2'),
    service.getRecipe('3'),
  ];

  await Future.wait(futures);

  // Assert: All calls completed
  verify(() => mockRepository.getById('1')).called(1);
  verify(() => mockRepository.getById('2')).called(1);
  verify(() => mockRepository.getById('3')).called(1);
});
```

### Pattern 4: Testing with Real Implementations (Integration Tests)

```dart
test('integration: service with real repository', () async {
  // Don't register mocks - use real implementations
  // Test integration between service and repository

  final service = ServiceLocator.get<RecipeService>();
  // service will get real RecipeRepository

  final recipe = Recipe(id: 'test', title: 'Test');
  final created = await service.createRecipe(recipe);

  expect(created.id, 'test');
  // Real repository stores in Firestore
});
```

## Test Helpers

### registerFallbackValue()

**Purpose**: Register default values for Mocktail's any() matcher

```dart
setUpAll() {
  // Register fallback for any(that: ...) matchers
  registerFallbackValue(Recipe(
    id: '',
    title: '',
    userId: '',
    createdAt: DateTime.now(),
  ));

  registerFallbackValue(<String>[]);
});
```

**When needed**: When using `any()` or `any(that: ...)` with custom types

### Test Data Factories

```dart
// Helper to create test recipes
Recipe createTestRecipe({
  String? id,
  String? userId,
  String? title,
}) {
  return Recipe(
    id: id ?? 'test-recipe',
    userId: userId ?? 'test-user',
    title: title ?? 'Test Recipe',
    portions: 4,
    ingredients: ['flour', 'sugar'],
    instructions: ['Mix', 'Bake'],
    createdAt: DateTime(2025, 1, 1),
  );
}

// Use in tests
test('service processes recipe', () {
  final recipe = createTestRecipe(title: 'My Recipe');
  // ...
});
```

## Best Practices

1. **Use TestServiceLocator** - Always use for service tests
2. **setUpAll for TestServiceLocator.setup()** - One-time initialization
3. **setUp for mocks** - Create and register mocks per test
4. **tearDown for reset** - Clean state after each test
5. **registerFallbackValue** - For custom types with any()
6. **Test factories** - Use factories for consistent test data
7. **Verify calls** - Always verify mock interactions
8. **Test error paths** - Test both success and failure cases

## Common Pitfalls

### Pitfall 1: Forgetting to Reset

**❌ WRONG**:
```dart
tearDown() {
  // Forgot to reset!
}
```

**Result**: Mocks persist between tests, causing test interference

**✅ RIGHT**:
```dart
tearDown() async {
  await TestServiceLocator.reset();
}
```

### Pitfall 2: Not Registering Fallback Values

**❌ WRONG**:
```dart
when(() => mockRepository.create(any())).thenAnswer(...);
// Error: Bad state: No fallback value for Recipe
```

**✅ RIGHT**:
```dart
setUpAll() {
  registerFallbackValue(Recipe(id: '', ...));
}

when(() => mockRepository.create(any())).thenAnswer(...); // Works!
```

### Pitfall 3: Creating Service Instead of Getting from DI

**❌ WRONG**:
```dart
setUp() {
  // Creating service directly (bypasses DI)
  service = RecipeService(
    repository: mockRepository,
  );
}
```

**Why wrong**: Not testing DI integration

**✅ RIGHT**:
```dart
setUp() {
  TestServiceLocator.registerMock<RecipeRepository>(mockRepository);

  // Get from DI (tests full integration)
  service = ServiceLocator.get<RecipeService>();
}
```

## Related Resources

- [module-structure.md](module-structure.md) - Understanding DI modules
- [registration-patterns.md](registration-patterns.md) - How services are registered
- [service-access-patterns.md](service-access-patterns.md) - How to access services

---

**Impact**: Easy testing via mock injection
**Benefit**: Tests are isolated, fast, and reliable
**Pattern**: TestServiceLocator mirrors production DI
