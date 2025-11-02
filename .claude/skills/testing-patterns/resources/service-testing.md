# Service Testing Guide

This guide covers testing services using mocked repositories, business logic validation, and error handling patterns.

## Testing Infrastructure

### Required Dependencies

```yaml
dev_dependencies:
  mocktail: ^1.0.4
  flutter_test:
    sdk: flutter
```

### Test Base Setup

```dart
void main() {
  group('RecipeService', () {
    late RecipeService service;
    late MockRecipeRepository mockRepository;
    late MockAuthRepository mockAuthRepository;
    late MockUserRepository mockUserRepository;

    setUp(() {
      // Create mocks
      mockRepository = MockRecipeRepository();
      mockAuthRepository = MockAuthRepository();
      mockUserRepository = MockUserRepository();

      // Set default auth state
      when(() => mockAuthRepository.currentUserId).thenReturn('test-user-123');
      when(() => mockAuthRepository.isAuthenticated).thenReturn(true);

      // Create service with mocks
      service = RecipeService(
        recipeRepository: mockRepository,
        authRepository: mockAuthRepository,
        userRepository: mockUserRepository,
      );
    });

    tearDown(() {
      // Reset mocks if needed
      reset(mockRepository);
      reset(mockAuthRepository);
      reset(mockUserRepository);
    });
  });
}
```

## Testing Business Logic

### Simple Business Logic

```dart
test('createRecipe() sets owner to current user', () async {
  // Arrange
  final currentUser = UserProfile(id: 'test-user-123', email: 'test@test.com');
  when(() => mockUserRepository.getCurrentUserProfile())
      .thenAnswer((_) async => currentUser);

  final recipe = Recipe(
    id: 'recipe-1',
    title: 'Test Recipe',
    ingredients: ['Ingredient 1'],
    createdAt: DateTime.now(),
  );

  when(() => mockRepository.create(any()))
      .thenAnswer((_) async => recipe);

  // Act
  await service.createRecipe(recipe);

  // Assert - Verify owner was set
  verify(() => mockRepository.create(
    argThat(predicate<Recipe>((r) => r.createdBy == 'test-user-123')),
  )).called(1);
});
```

### Multi-Repository Coordination

```dart
test('discoverRecipes() filters by friends and preferences', () async {
  // Arrange
  final friendIds = ['friend-1', 'friend-2'];
  final userProfile = UserProfile(
    id: 'test-user-123',
    dietaryRestrictions: ['vegetarian'],
  );

  when(() => mockFriendsRepository.getFriendIds())
      .thenAnswer((_) async => friendIds);
  when(() => mockUserRepository.getCurrentUserProfile())
      .thenAnswer((_) async => userProfile);

  final allRecipes = [
    SharedRecipe(id: 'recipe-1', ownerId: 'friend-1', tags: ['vegetarian']),
    SharedRecipe(id: 'recipe-2', ownerId: 'stranger', tags: ['meat']),
    SharedRecipe(id: 'recipe-3', ownerId: 'friend-2', tags: ['vegan']),
  ];

  when(() => mockSocialRecipeRepository.getDiscoverableRecipes())
      .thenAnswer((_) async => allRecipes);

  // Act
  final discovered = await service.discoverRecipes();

  // Assert - Only friend recipes
  expect(discovered, hasLength(2));
  expect(discovered.map((r) => r.id), containsAll(['recipe-1', 'recipe-3']));
});
```

### Data Transformation

```dart
test('importFromUrl() transforms and optimizes data', () async {
  // Arrange
  final rawData = ImportedRecipeData(
    title: 'Imported Recipe',
    ingredients: ['  ingredient 1  ', 'INGREDIENT 2'],  // Needs normalization
    imageUrl: 'http://example.com/large-image.jpg',
  );

  when(() => mockParserService.parseUrl(any()))
      .thenAnswer((_) async => rawData);

  when(() => mockImageService.downloadAndOptimize(any()))
      .thenAnswer((_) async => 'optimized-url.jpg');

  when(() => mockRepository.create(any()))
      .thenAnswer((invocation) async => invocation.positionalArguments[0] as Recipe);

  // Act
  final recipe = await service.importFromUrl('http://example.com/recipe');

  // Assert - Verify transformation
  verify(() => mockRepository.create(
    argThat(predicate<Recipe>((r) {
      return r.title == 'Imported Recipe' &&
          r.imageUrl == 'optimized-url.jpg' &&
          r.ingredients.length == 2;
    })),
  )).called(1);
});
```

### Validation Rules

```dart
test('validateRecipe() returns errors for invalid data', () async {
  // Arrange
  final invalidRecipe = Recipe(
    id: 'recipe-1',
    title: '',  // Empty title
    ingredients: [],  // No ingredients
    portions: -1,  // Invalid portions
    createdAt: DateTime.now(),
  );

  // Act
  final result = await service.validateRecipe(invalidRecipe);

  // Assert
  expect(result.isValid, isFalse);
  expect(result.errors, contains('Title is required'));
  expect(result.errors, contains('At least one ingredient required'));
  expect(result.errors, contains('Portions must be greater than 0'));
});

test('validateRecipe() passes for valid recipe', () async {
  // Arrange
  final validRecipe = Recipe(
    id: 'recipe-1',
    title: 'Valid Recipe',
    ingredients: ['Ingredient 1'],
    portions: 4,
    createdAt: DateTime.now(),
  );

  // Act
  final result = await service.validateRecipe(validRecipe);

  // Assert
  expect(result.isValid, isTrue);
  expect(result.errors, isEmpty);
});
```

## Testing BaseService Features

### Testing executeServiceOperation

```dart
test('executeServiceOperation() handles repository errors', () async {
  // Arrange
  when(() => mockRepository.read(any()))
      .thenThrow(Exception('Firestore error'));

  // Act & Assert
  expect(
    () => service.getRecipe('recipe-1'),
    throwsException,
  );
});

test('executeServiceOperation() checks auth when required', () async {
  // Arrange
  when(() => mockAuthRepository.isAuthenticated).thenReturn(false);

  // Act & Assert
  expect(
    () => service.createRecipe(RecipeFactory.build()),
    throwsA(isA<AuthenticationException>()),
  );

  // Verify repository was not called
  verifyNever(() => mockRepository.create(any()));
});

test('executeServiceOperation() checks network when required', () async {
  // Arrange
  when(() => mockNetworkService.isConnected).thenReturn(false);

  // Act & Assert
  expect(
    () => service.syncRecipes(),
    throwsA(isA<NetworkException>()),
  );
});
```

### Testing Retry Logic

```dart
test('retries operation on transient failures', () async {
  // Arrange
  var attempts = 0;
  when(() => mockRepository.create(any())).thenAnswer((_) async {
    attempts++;
    if (attempts < 3) {
      throw Exception('Transient error');
    }
    return RecipeFactory.build();
  });

  // Act
  await service.createRecipeWithRetry(RecipeFactory.build());

  // Assert
  expect(attempts, equals(3));
  verify(() => mockRepository.create(any())).called(3);
});

test('gives up after max retries', () async {
  // Arrange
  when(() => mockRepository.create(any()))
      .thenThrow(Exception('Persistent error'));

  // Act & Assert
  expect(
    () => service.createRecipeWithRetry(RecipeFactory.build(), maxRetries: 3),
    throwsException,
  );

  verify(() => mockRepository.create(any())).called(3);
});
```

### Testing Batch Operations

```dart
test('batchImport() continues on individual failures', () async {
  // Arrange
  final recipes = RecipeFactory.buildList(5);

  when(() => mockRepository.create(recipes[0]))
      .thenAnswer((_) async => recipes[0]);
  when(() => mockRepository.create(recipes[1]))
      .thenThrow(Exception('Failed'));
  when(() => mockRepository.create(recipes[2]))
      .thenAnswer((_) async => recipes[2]);
  when(() => mockRepository.create(recipes[3]))
      .thenThrow(Exception('Failed'));
  when(() => mockRepository.create(recipes[4]))
      .thenAnswer((_) async => recipes[4]);

  // Act
  final result = await service.batchImportRecipes(recipes, continueOnError: true);

  // Assert
  expect(result.successful, equals(3));
  expect(result.failed, equals(2));
  verify(() => mockRepository.create(any())).called(5);
});
```

## Testing Caching

```dart
test('getRecipe() returns cached recipe on subsequent calls', () async {
  // Arrange
  final recipe = RecipeFactory.build(id: 'recipe-1');
  when(() => mockRepository.read('recipe-1'))
      .thenAnswer((_) async => recipe);

  // Act - First call
  final result1 = await service.getRecipe('recipe-1');

  // Act - Second call (should use cache)
  final result2 = await service.getRecipe('recipe-1');

  // Assert
  expect(result1, equals(recipe));
  expect(result2, equals(recipe));

  // Repository called only once
  verify(() => mockRepository.read('recipe-1')).called(1);
});

test('invalidateCache() forces fresh fetch', () async {
  // Arrange
  final recipe = RecipeFactory.build(id: 'recipe-1');
  when(() => mockRepository.read('recipe-1'))
      .thenAnswer((_) async => recipe);

  // Act
  await service.getRecipe('recipe-1');  // Populates cache
  service.invalidateCache('recipe-1');  // Clear cache
  await service.getRecipe('recipe-1');  // Should fetch again

  // Assert - Repository called twice
  verify(() => mockRepository.read('recipe-1')).called(2);
});

test('cache expires after timeout', () async {
  // Arrange
  final recipe = RecipeFactory.build(id: 'recipe-1');
  when(() => mockRepository.read('recipe-1'))
      .thenAnswer((_) async => recipe);

  // Act
  await service.getRecipe('recipe-1');  // Populates cache

  // Wait for cache to expire (if using time-based expiry)
  await Future.delayed(Duration(minutes: 6));  // Assuming 5-min cache

  await service.getRecipe('recipe-1');  // Should fetch again

  // Assert
  verify(() => mockRepository.read('recipe-1')).called(2);
});
```

## Testing Layered Services

### Personal Layer

```dart
test('personal.createRecipe() uses personal repository', () async {
  // Arrange
  final recipe = RecipeFactory.build();
  when(() => mockPersonalRepository.create(any()))
      .thenAnswer((_) async => recipe);

  // Act
  await unifiedService.personal.createRecipe(recipe);

  // Assert
  verify(() => mockPersonalRepository.create(recipe)).called(1);
  verifyNever(() => mockSocialRepository.create(any()));
});
```

### Social Layer

```dart
test('social.shareWithFriends() notifies friends', () async {
  // Arrange
  final recipe = RecipeFactory.build();
  final friendIds = ['friend-1', 'friend-2'];

  when(() => mockFriendsRepository.verifyFriends(any()))
      .thenAnswer((_) async => friendIds);
  when(() => mockSocialRepository.shareRecipe(any(), any()))
      .thenAnswer((_) async => SharedRecipe(/* ... */));
  when(() => mockNotificationService.sendShareNotification(any(), any()))
      .thenAnswer((_) async => {});

  // Act
  await unifiedService.social.shareWithFriends(recipe.id, friendIds);

  // Assert
  verify(() => mockNotificationService.sendShareNotification(
    userId: 'friend-1',
    recipeTitle: recipe.title,
  )).called(1);
  verify(() => mockNotificationService.sendShareNotification(
    userId: 'friend-2',
    recipeTitle: recipe.title,
  )).called(1);
});
```

### Realtime Layer

```dart
test('realtime.updateField() tracks presence', () async {
  // Arrange
  final recipe = RecipeFactory.build(id: 'recipe-1');
  when(() => mockRepository.read(any()))
      .thenAnswer((_) async => recipe);
  when(() => mockRepository.update(any()))
      .thenAnswer((_) async => {});
  when(() => mockPresenceService.markAsEditing(any(), any()))
      .thenAnswer((_) async => {});
  when(() => mockPresenceService.markAsIdle(any()))
      .thenAnswer((_) async => {});

  // Act
  await unifiedService.realtime.updateRecipeField('recipe-1', 'title', 'New Title');

  // Assert
  verify(() => mockPresenceService.markAsEditing('recipe-1', 'title')).called(1);
  verify(() => mockRepository.update(any())).called(1);
  verify(() => mockPresenceService.markAsIdle('recipe-1')).called(1);
});
```

## Testing Error Scenarios

### Network Errors

```dart
test('handles NetworkException', () async {
  // Arrange
  when(() => mockRepository.create(any()))
      .thenThrow(NetworkException('No connection'));

  // Act & Assert
  expect(
    () => service.createRecipe(RecipeFactory.build()),
    throwsA(isA<NetworkException>()),
  );
});
```

### Authentication Errors

```dart
test('handles AuthenticationException', () async {
  // Arrange
  when(() => mockAuthRepository.isAuthenticated).thenReturn(false);

  // Act & Assert
  expect(
    () => service.createRecipe(RecipeFactory.build()),
    throwsA(isA<AuthenticationException>()),
  );
});
```

### Permission Errors

```dart
test('handles PermissionDeniedException', () async {
  // Arrange
  when(() => mockRepository.update(any()))
      .thenThrow(PermissionDeniedException('Not authorized'));

  // Act & Assert
  expect(
    () => service.updateRecipe(RecipeFactory.build()),
    throwsA(isA<PermissionDeniedException>()),
  );
});
```

### Validation Errors

```dart
test('throws ValidationException for invalid data', () async {
  // Arrange
  final invalidRecipe = Recipe(
    id: 'recipe-1',
    title: '',  // Invalid
    ingredients: [],  // Invalid
    portions: -1,  // Invalid
    createdAt: DateTime.now(),
  );

  // Act & Assert
  expect(
    () => service.createRecipe(invalidRecipe),
    throwsA(isA<ValidationException>()),
  );
});
```

## Testing Async Operations

### Concurrent Operations

```dart
test('handles concurrent creates', () async {
  // Arrange
  final recipes = RecipeFactory.buildList(3);
  when(() => mockRepository.create(any()))
      .thenAnswer((invocation) async {
    await Future.delayed(Duration(milliseconds: 100));
    return invocation.positionalArguments[0] as Recipe;
  });

  // Act - Start all operations concurrently
  final futures = recipes.map((r) => service.createRecipe(r));
  await Future.wait(futures);

  // Assert
  verify(() => mockRepository.create(any())).called(3);
});
```

### Operation Cancellation

```dart
test('supports operation cancellation', () async {
  // Arrange
  final completer = Completer<Recipe>();
  when(() => mockRepository.create(any()))
      .thenAnswer((_) => completer.future);

  // Act - Start operation
  final future = service.createRecipe(RecipeFactory.build());

  // Cancel before completion
  service.cancelOperation('create-recipe');

  // Complete operation
  completer.complete(RecipeFactory.build());

  // Assert - Operation was cancelled
  await expectLater(future, throwsA(isA<CancelledException>()));
});
```

## Mock Helpers

### Creating Mocks with mocktail

```dart
class MockRecipeRepository extends Mock implements RecipeRepository {}
class MockAuthRepository extends Mock implements AuthRepository {}
class MockUserRepository extends Mock implements UserRepository {}
class MockImageService extends Mock implements ImageService {}
class MockNotificationService extends Mock implements NotificationService {}
```

### Setting Up Common Mocks

```dart
void setupAuthMock(MockAuthRepository mock, {
  String userId = 'test-user-123',
  bool isAuthenticated = true,
}) {
  when(() => mock.currentUserId).thenReturn(userId);
  when(() => mock.isAuthenticated).thenReturn(isAuthenticated);
  when(() => mock.authStateChanges).thenAnswer((_) => Stream.value(userId));
}

void setupRepositoryMock(MockRecipeRepository mock, {
  Recipe? recipe,
  List<Recipe>? recipes,
}) {
  if (recipe != null) {
    when(() => mock.read(any())).thenAnswer((_) async => recipe);
    when(() => mock.create(any())).thenAnswer((_) async => recipe);
    when(() => mock.update(any())).thenAnswer((_) async => {});
  }

  if (recipes != null) {
    when(() => mock.readAll()).thenAnswer((_) async => recipes);
  }
}
```

## Best Practices

### ✅ DO:
- Mock all external dependencies
- Test business logic thoroughly
- Test error scenarios
- Verify method calls with `verify()`
- Use `argThat()` for complex argument matching
- Test BaseService features (auth checks, retries)
- Test all layers in layered services
- Reset mocks in tearDown
- Use descriptive test names

### ❌ DON'T:
- Test implementation details
- Mock the service under test
- Skip error scenario tests
- Use real repositories in service tests
- Depend on test execution order
- Leave mocks in inconsistent state
- Test private service methods directly
- Hardcode test data

## Common Patterns

### Testing with Time

```dart
test('uses current timestamp', () async {
  // Arrange
  final now = DateTime.now();
  when(() => mockRepository.create(any()))
      .thenAnswer((invocation) async => invocation.positionalArguments[0] as Recipe);

  // Act
  await service.createRecipe(RecipeFactory.build());

  // Assert
  verify(() => mockRepository.create(
    argThat(predicate<Recipe>((r) {
      final diff = r.createdAt.difference(now).abs();
      return diff < Duration(seconds: 1);
    })),
  )).called(1);
});
```

### Testing with Predicates

```dart
test('filters recipes correctly', () async {
  // Arrange
  final recipes = [
    RecipeFactory.build(title: 'Pasta'),
    RecipeFactory.build(title: 'Pizza'),
    RecipeFactory.build(title: 'Salad'),
  ];
  when(() => mockRepository.readAll()).thenAnswer((_) async => recipes);

  // Act
  final filtered = await service.searchRecipes('pa');

  // Assert
  expect(filtered, hasLength(2));
  expect(filtered.every((r) => r.title.toLowerCase().contains('pa')), isTrue);
});
```

---

**See Also**:
- [Repository Testing](./repository-testing.md) - Testing repositories with FakeFirestore
- [ViewModel Testing](./viewmodel-testing.md) - Testing ViewModels with mocked services
- [Testing Patterns Overview](../SKILL.md) - Complete testing guide
