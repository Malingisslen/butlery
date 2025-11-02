# Testing Patterns Skill

## Purpose

Generate comprehensive tests for repositories, services, ViewModels, widgets, and integration flows using FakeFirestore, mocks, and test factories. This skill ensures consistent test patterns and high-quality test coverage across all layers.

## When to Use This Skill

This skill activates automatically when:
- Creating or modifying test files
- Questions about testing, mocking, or test coverage
- Generating tests for services, repositories, ViewModels, or widgets
- Files in `test/` directory or discussing testing strategies

## Test Philosophy

### Bottom-Up Testing Strategy

Butlery follows a **bottom-up testing approach**:

```
1. Repositories (Data Layer) - Test data access and permission validation
2. Services (Business Layer) - Test business logic with mocked repositories
3. ViewModels (Presentation Layer) - Test state management with mocked services
4. Widgets (UI Layer) - Test UI components and user interactions
5. Integration Tests - Test critical user flows end-to-end
```

### Critical Path Focus

Prioritize testing:
- ✅ **Critical paths**: Authentication, data creation, permission validation
- ✅ **Security**: Permission checks, audit logging, GDPR compliance
- ✅ **Business logic**: Workflows, validation rules, data transformations
- ✅ **State management**: Loading states, error handling, reactive updates

### Coverage Goals

- **Repositories**: High coverage (permission validation critical)
- **Services**: High coverage (business logic critical)
- **ViewModels**: High coverage (state management critical)
- **Widgets**: Moderate coverage (critical UI flows)
- **Integration**: Key user flows

## Test Infrastructure

### Essential Testing Dependencies

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4              # Mocking (preferred over Mockito)
  fake_cloud_firestore: ^4.0.0  # Firestore mocking
  firebase_auth_mocks: ^0.15.0  # Auth mocking
  firebase_storage_mocks: ^0.8.0 # Storage mocking
  faker: ^2.2.0                  # Test data generation
  glados: 1.1.7                  # Property-based testing
  golden_toolkit: ^0.15.0        # Golden/screenshot testing
  patrol: ^3.13.0                # E2E testing
  http_mock_adapter: ^0.6.1      # HTTP mocking
```

### Core Test Helpers

**TestServiceLocator** - Mock DI setup:
```dart
// test/helpers/test_service_locator.dart
class TestServiceLocator {
  static void setupMocks() {
    ServiceLocator.reset();

    // Register mock dependencies
    ServiceLocator.register<AuthRepository>(MockAuthRepository());
    ServiceLocator.register<RecipeRepository>(MockRecipeRepository());
    // ... all mocks
  }
}
```

**TestDataFactory** - Consistent test data:
```dart
// test/helpers/test_data_factory.dart
class RecipeFactory {
  static Recipe build({
    String? id,
    String? title,
    List<String>? ingredients,
  }) {
    return Recipe(
      id: id ?? const Uuid().v4(),
      title: title ?? 'Test Recipe',
      ingredients: ingredients ?? ['Ingredient 1', 'Ingredient 2'],
      portions: 4,
      createdAt: DateTime.now(),
    );
  }
}
```

## Quick Test Generation Guide

### 5-Step Process for Any Layer

1. **Set up test dependencies** (mocks, fakes, factories)
2. **Create test subject** (repository, service, ViewModel, widget)
3. **Arrange** - Set up test data and mocks
4. **Act** - Execute the operation being tested
5. **Assert** - Verify expected behavior

### Example: Repository Test

```dart
void main() {
  group('FirebaseRecipeRepository', () {
    late FirebaseRecipeRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;

    setUp(() {
      // Step 1: Set up dependencies
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepo = MockAuthRepository();
      mockAuthRepo.setAuthState(userId: 'user-1', isAuthenticated: true);

      // Step 2: Create test subject
      repository = FirebaseRecipeRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    test('create() saves recipe to Firestore', () async {
      // Step 3: Arrange
      final recipe = RecipeFactory.build(id: 'recipe-1', createdBy: 'user-1');

      // Step 4: Act
      final created = await repository.create(recipe);

      // Step 5: Assert
      expect(created.id, equals('recipe-1'));

      final doc = await fakeFirestore
          .collection('users/user-1/recipes')
          .doc('recipe-1')
          .get();
      expect(doc.exists, isTrue);
    });
  });
}
```

## Test Patterns by Layer

### Repository Tests (FakeFirestore)

```dart
void main() {
  group('FirebaseRecipeRepository', () {
    late FirebaseRecipeRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepo = MockAuthRepository();
      mockAuthRepo.setAuthState(userId: 'user-1', isAuthenticated: true);

      repository = FirebaseRecipeRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    group('CRUD Operations', () {
      test('create() saves to Firestore', () async { /* ... */ });
      test('read() retrieves from Firestore', () async { /* ... */ });
      test('update() modifies in Firestore', () async { /* ... */ });
      test('delete() removes from Firestore', () async { /* ... */ });
    });

    group('Permission Validation', () {
      test('create() rejects unauthenticated user', () async {
        mockAuthRepo.setAuthState(user: null);
        expect(
          () => repository.create(RecipeFactory.build()),
          throwsA(isA<AuthenticationException>()),
        );
      });
    });

    group('Streaming', () {
      test('watch() streams updates', () async { /* ... */ });
    });
  });
}
```

### Service Tests (Mocked Repositories)

```dart
void main() {
  group('RecipeService', () {
    late RecipeService service;
    late MockRecipeRepository mockRepo;
    late MockAuthRepository mockAuth;

    setUp(() {
      mockRepo = MockRecipeRepository();
      mockAuth = MockAuthRepository();
      mockAuth.setAuthState(userId: 'user-1');

      service = RecipeService(
        recipeRepository: mockRepo,
        authRepository: mockAuth,
      );
    });

    group('Business Logic', () {
      test('createRecipe() sets owner to current user', () async {
        final recipe = RecipeFactory.build();
        when(() => mockRepo.create(any())).thenAnswer((_) async => recipe);

        await service.createRecipe(recipe);

        verify(() => mockRepo.create(
          argThat(predicate<Recipe>((r) => r.createdBy == 'user-1')),
        )).called(1);
      });
    });

    group('Error Handling', () {
      test('handles repository errors gracefully', () async {
        when(() => mockRepo.create(any())).thenThrow(Exception('Firestore error'));

        expect(
          () => service.createRecipe(RecipeFactory.build()),
          throwsException,
        );
      });
    });
  });
}
```

### ViewModel Tests (Mocked Services)

```dart
void main() {
  group('RecipeDetailViewModel', () {
    late RecipeDetailViewModel viewModel;
    late MockUnifiedRecipeService mockService;
    late Recipe testRecipe;

    setUp(() {
      mockService = MockUnifiedRecipeService();
      testRecipe = RecipeFactory.build(id: 'recipe-1');

      viewModel = RecipeDetailViewModel(
        recipe: testRecipe,
        recipeService: mockService,
      );
    });

    test('initializes with recipe', () {
      expect(viewModel.recipe, equals(testRecipe));
      expect(viewModel.isLoading, isFalse);
    });

    test('deleteRecipe() updates loading state', () async {
      when(() => mockService.personal.deleteRecipe(any()))
          .thenAnswer((_) async => {});

      expect(viewModel.isLoading, isFalse);

      final deleteTask = viewModel.deleteRecipe();
      expect(viewModel.isLoading, isTrue);

      await deleteTask;
      expect(viewModel.isLoading, isFalse);
    });

    test('notifies listeners on state change', () async {
      var notified = false;
      viewModel.addListener(() => notified = true);

      when(() => mockService.personal.deleteRecipe(any()))
          .thenAnswer((_) async => {});

      await viewModel.deleteRecipe();

      expect(notified, isTrue);
    });
  });
}
```

### Widget Tests (testWidgets)

```dart
void main() {
  group('RecipeCard', () {
    testWidgets('displays recipe title', (tester) async {
      final recipe = RecipeFactory.build(title: 'Test Recipe');

      await tester.pumpWidget(
        MaterialApp(home: RecipeCard(recipe: recipe)),
      );

      expect(find.text('Test Recipe'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      final recipe = RecipeFactory.build();
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: RecipeCard(
            recipe: recipe,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(RecipeCard));
      expect(tapped, isTrue);
    });
  });
}
```

## Common Test Scenarios

### Testing Permission Validation

```dart
test('rejects unauthorized access', () async {
  mockAuthRepo.setAuthState(user: null);

  expect(
    () => repository.create(RecipeFactory.build()),
    throwsA(isA<AuthenticationException>()),
  );
});

test('allows authorized access', () async {
  mockAuthRepo.setAuthState(userId: 'user-1', isAuthenticated: true);

  final recipe = RecipeFactory.build(createdBy: 'user-1');
  final created = await repository.create(recipe);

  expect(created, isNotNull);
});
```

### Testing Error Handling

```dart
test('handles network errors', () async {
  when(() => mockRepo.create(any()))
      .thenThrow(NetworkException('No connection'));

  expect(
    () => service.createRecipe(RecipeFactory.build()),
    throwsA(isA<NetworkException>()),
  );
});

test('retries on transient failures', () async {
  var attempts = 0;
  when(() => mockRepo.create(any())).thenAnswer((_) async {
    attempts++;
    if (attempts < 3) throw Exception('Transient error');
    return RecipeFactory.build();
  });

  await service.createRecipeWithRetry(RecipeFactory.build());

  expect(attempts, equals(3));
});
```

### Testing Loading States

```dart
test('manages loading state during async operation', () async {
  when(() => mockService.getData())
      .thenAnswer((_) => Future.delayed(Duration(milliseconds: 100)));

  expect(viewModel.isLoading, isFalse);

  final loadTask = viewModel.loadData();
  expect(viewModel.isLoading, isTrue);

  await loadTask;
  expect(viewModel.isLoading, isFalse);
});
```

### Testing Stream Updates

```dart
test('watch() emits updates', () async {
  final recipe = RecipeFactory.build();
  final controller = StreamController<Recipe?>();

  when(() => repository.watch(any())).thenAnswer((_) => controller.stream);

  final stream = repository.watch('recipe-1');

  controller.add(recipe);

  expect(await stream.first, equals(recipe));

  controller.close();
});
```

## Resource Files

For detailed testing guides by layer:

- **[repository-testing.md](./resources/repository-testing.md)** - FakeFirestore setup, permission tests, CRUD patterns
- **[service-testing.md](./resources/service-testing.md)** - Mock patterns, BaseService testing, business logic
- **[viewmodel-testing.md](./resources/viewmodel-testing.md)** - AsyncOperationMixin tests, ChangeNotifier patterns
- **[widget-testing.md](./resources/widget-testing.md)** - testWidgets patterns, pump, find, expect
- **[test-factories.md](./resources/test-factories.md)** - Test data generation, factories for all models
- **[integration-testing.md](./resources/integration-testing.md)** - E2E tests, Patrol, critical user flows

## Test Organization

### Directory Structure

```
test/
├── unit/                           # Unit tests
│   ├── repositories/               # Repository tests
│   │   ├── firebase_recipe_repository_test.dart
│   │   └── firebase_user_repository_test.dart
│   ├── services/                   # Service tests
│   │   ├── recipe_service_test.dart
│   │   └── unified_recipe_service_test.dart
│   └── viewmodels/                 # ViewModel tests
│       ├── recipe_detail_viewmodel_test.dart
│       └── recipe_list_viewmodel_test.dart
├── widget/                         # Widget tests
│   ├── recipe_card_test.dart
│   └── recipe_list_item_test.dart
├── views/                          # View tests
│   └── recipe_detail_view_test.dart
├── integration/                    # Integration tests
│   └── recipe_creation_flow_test.dart
└── helpers/                        # Test utilities
    ├── test_service_locator.dart
    ├── test_data_factory.dart
    └── mock_repositories.dart
```

### Naming Conventions

- Test files: `{name}_test.dart`
- Mock classes: `Mock{ClassName}`
- Test factories: `{Model}Factory`
- Test groups: Match class/feature name
- Test descriptions: Use descriptive sentences

## Running Tests

```bash
# All tests
flutter test

# Specific test file
flutter test test/unit/repositories/firebase_recipe_repository_test.dart

# Tests in directory
flutter test test/unit/services/

# With coverage
flutter test --coverage
flutter test --coverage --test-randomize-ordering-seed random

# Specific test by name
flutter test --name "create() saves recipe"

# Watch mode (re-run on file changes)
flutter test --watch
```

## Best Practices

### ✅ DO:
- Test behavior, not implementation
- Use descriptive test names
- Follow AAA pattern (Arrange, Act, Assert)
- Mock external dependencies
- Test edge cases and error conditions
- Clean up resources (controllers, subscriptions)
- Use test factories for consistent data
- Group related tests

### ❌ DON'T:
- Test private methods directly
- Create god tests (test one thing per test)
- Depend on test execution order
- Use real Firebase in unit tests
- Leave unused mocks/imports
- Skip tearDown cleanup
- Hardcode test data inline

## Quick Reference

### Repository Test Template
```dart
void main() {
  group('Firebase{Model}Repository', () {
    late Firebase{Model}Repository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepo = MockAuthRepository();
      mockAuthRepo.setAuthState(userId: 'user-1', isAuthenticated: true);
      repository = Firebase{Model}Repository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    test('create() saves to Firestore', () async {
      // Test implementation
    });
  });
}
```

### Service Test Template
```dart
void main() {
  group('{Name}Service', () {
    late {Name}Service service;
    late Mock{Name}Repository mockRepo;

    setUp(() {
      mockRepo = Mock{Name}Repository();
      service = {Name}Service(repository: mockRepo);
    });

    test('method() does expected action', () async {
      // Test implementation
    });
  });
}
```

### ViewModel Test Template
```dart
void main() {
  group('{Name}ViewModel', () {
    late {Name}ViewModel viewModel;
    late Mock{Name}Service mockService;

    setUp(() {
      mockService = Mock{Name}Service();
      viewModel = {Name}ViewModel(service: mockService);
    });

    test('state changes trigger notifyListeners', () async {
      // Test implementation
    });
  });
}
```

## Related Skills

**Complementary Skills**:
- 🏗️ **[butlery-architecture](../butlery-architecture/SKILL.md)** - For understanding the architecture being tested
- 🗄️ **[firebase-repository-patterns](../firebase-repository-patterns/SKILL.md)** - For repository implementation patterns to test
- 🎨 **[state-management-patterns](../state-management-patterns/SKILL.md)** - For ViewModel patterns to test

---

**Last Updated**: 2025-01-31
**Skill Version**: 1.0.0
**Applicable To**: All test files in `test/` directory
