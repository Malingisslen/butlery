# ViewModel Testing Guide

This guide covers testing ViewModels using mocked services, state management validation, and AsyncOperationMixin patterns.

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
  group('RecipeDetailViewModel', () {
    late RecipeDetailViewModel viewModel;
    late MockUnifiedRecipeService mockService;
    late Recipe testRecipe;

    setUp(() {
      mockService = MockUnifiedRecipeService();
      testRecipe = RecipeFactory.build(id: 'recipe-1', title: 'Test Recipe');

      viewModel = RecipeDetailViewModel(
        recipe: testRecipe,
        recipeService: mockService,
      );
    });

    tearDown(() {
      viewModel.dispose();
      reset(mockService);
    });
  });
}
```

## Testing Initialization

```dart
test('initializes with provided recipe', () {
  // Assert
  expect(viewModel.recipe, equals(testRecipe));
  expect(viewModel.isLoading, isFalse);
  expect(viewModel.error, isNull);
});

test('initialize() loads initial data', () async {
  // Arrange
  when(() => mockService.personal.getRecipe(any()))
      .thenAnswer((_) async => testRecipe);

  // Act
  await viewModel.initialize();

  // Assert
  expect(viewModel.isInitialized, isTrue);
  verify(() => mockService.personal.getRecipe(testRecipe.id)).called(1);
});
```

## Testing State Management

### Testing notifyListeners

```dart
test('notifies listeners when state changes', () async {
  // Arrange
  var notificationCount = 0;
  viewModel.addListener(() => notificationCount++);

  when(() => mockService.personal.updateRecipe(any()))
      .thenAnswer((_) async => testRecipe.copyWith(title: 'Updated'));

  // Act
  await viewModel.updateTitle('Updated');

  // Assert
  expect(notificationCount, greaterThan(0));
});

test('does not notify after dispose', () async {
  // Arrange
  var notificationCount = 0;
  viewModel.addListener(() => notificationCount++);

  // Act
  viewModel.dispose();
  viewModel.updateLocalState('new value');  // Shouldn't notify

  // Assert
  expect(notificationCount, equals(0));
});
```

### Testing Loading States

```dart
test('sets isLoading during async operation', () async {
  // Arrange
  when(() => mockService.personal.deleteRecipe(any()))
      .thenAnswer((_) => Future.delayed(Duration(milliseconds: 100)));

  // Act
  expect(viewModel.isLoading, isFalse);

  final deleteTask = viewModel.deleteRecipe();

  // Check loading state during operation
  expect(viewModel.isLoading, isTrue);

  await deleteTask;

  // Check loading state after operation
  expect(viewModel.isLoading, isFalse);
});

test('clears isLoading on error', () async {
  // Arrange
  when(() => mockService.personal.updateRecipe(any()))
      .thenThrow(Exception('Update failed'));

  // Act
  expect(viewModel.isLoading, isFalse);

  try {
    await viewModel.updateRecipe(testRecipe);
  } catch (_) {
    // Expected
  }

  // Assert
  expect(viewModel.isLoading, isFalse);
});
```

### Testing Error States

```dart
test('sets error message on failure', () async {
  // Arrange
  when(() => mockService.personal.deleteRecipe(any()))
      .thenThrow(Exception('Failed to delete'));

  // Act
  await viewModel.deleteRecipe();

  // Assert
  expect(viewModel.hasError, isTrue);
  expect(viewModel.errorMessage, isNotEmpty);
});

test('clears error on successful operation', () async {
  // Arrange - Set initial error
  when(() => mockService.personal.updateRecipe(any()))
      .thenThrow(Exception('Error'));
  await viewModel.updateRecipe(testRecipe);
  expect(viewModel.hasError, isTrue);

  // Act - Successful operation
  when(() => mockService.personal.updateRecipe(any()))
      .thenAnswer((_) async => testRecipe);
  await viewModel.updateRecipe(testRecipe);

  // Assert - Error cleared
  expect(viewModel.hasError, isFalse);
  expect(viewModel.errorMessage, isNull);
});
```

## Testing AsyncOperationMixin

### Named Operations

```dart
test('prevents duplicate named operations', () async {
  // Arrange
  when(() => mockService.personal.loadRecipes())
      .thenAnswer((_) => Future.delayed(Duration(seconds: 1), () => []));

  // Act - Start two operations with same name
  final op1 = viewModel.loadRecipes();  // Named operation: 'loadRecipes'
  final op2 = viewModel.loadRecipes();  // Should be ignored/deduplicated

  await Future.wait([op1, op2]);

  // Assert - Service called only once
  verify(() => mockService.personal.loadRecipes()).called(1);
});
```

### Debounced Operations

```dart
test('debounces rapid consecutive calls', () async {
  // Arrange
  when(() => mockService.searchRecipes(any()))
      .thenAnswer((_) async => [testRecipe]);

  // Act - Make rapid calls
  viewModel.searchRecipes('pa');
  await Future.delayed(Duration(milliseconds: 100));
  viewModel.searchRecipes('pas');
  await Future.delayed(Duration(milliseconds: 100));
  viewModel.searchRecipes('past');

  // Wait for debounce
  await Future.delayed(Duration(milliseconds: 400));

  // Assert - Only last call executed
  verify(() => mockService.searchRecipes('past')).called(1);
  verifyNever(() => mockService.searchRecipes('pa'));
  verifyNever(() => mockService.searchRecipes('pas'));
});
```

### Cached Operations

```dart
test('returns cached result on subsequent calls', () async {
  // Arrange
  when(() => mockService.personal.getRecipe(any()))
      .thenAnswer((_) async => testRecipe);

  // Act - First call
  final result1 = await viewModel.loadRecipe('recipe-1');

  // Act - Second call (should use cache)
  final result2 = await viewModel.loadRecipe('recipe-1');

  // Assert
  expect(result1, equals(result2));
  verify(() => mockService.personal.getRecipe('recipe-1')).called(1);
});

test('refreshes cache after expiry', () async {
  // Arrange
  when(() => mockService.personal.getRecipe(any()))
      .thenAnswer((_) async => testRecipe);

  // Act
  await viewModel.loadRecipe('recipe-1');  // Populate cache

  // Wait for cache expiry (assuming 5-minute cache)
  await Future.delayed(Duration(minutes: 6));

  await viewModel.loadRecipe('recipe-1');  // Should refresh

  // Assert
  verify(() => mockService.personal.getRecipe('recipe-1')).called(2);
});
```

## Testing User Actions

### Simple Actions

```dart
test('deleteRecipe() calls service and updates state', () async {
  // Arrange
  when(() => mockService.personal.deleteRecipe(any()))
      .thenAnswer((_) async => {});

  // Act
  final result = await viewModel.deleteRecipe();

  // Assert
  expect(result, isTrue);
  verify(() => mockService.personal.deleteRecipe(testRecipe.id)).called(1);
});

test('updateTitle() updates recipe and calls service', () async {
  // Arrange
  when(() => mockService.personal.updateRecipe(any()))
      .thenAnswer((_) async => testRecipe.copyWith(title: 'New Title'));

  // Act
  await viewModel.updateTitle('New Title');

  // Assert
  expect(viewModel.recipe.title, equals('New Title'));
  verify(() => mockService.personal.updateRecipe(any())).called(1);
});
```

### Complex Actions

```dart
test('shareWithFriends() coordinates multiple services', () async {
  // Arrange
  final friendIds = ['friend-1', 'friend-2'];
  when(() => mockService.social.shareWithFriends(any(), any()))
      .thenAnswer((_) async => SharedRecipe(/* ... */));
  when(() => mockNavigationService.navigateToSuccess())
      .thenAnswer((_) async => {});

  // Act
  await viewModel.shareWithFriends(friendIds);

  // Assert
  verify(() => mockService.social.shareWithFriends(testRecipe.id, friendIds)).called(1);
  verify(() => mockNavigationService.navigateToSuccess()).called(1);
  expect(viewModel.isShared, isTrue);
});
```

## Testing Form Validation

### Field Validation

```dart
test('validates title is not empty', () {
  // Act
  viewModel.setTitle('');

  // Assert
  expect(viewModel.titleError, isNotNull);
  expect(viewModel.isValid, isFalse);
});

test('clears error when title becomes valid', () {
  // Arrange
  viewModel.setTitle('');  // Invalid
  expect(viewModel.titleError, isNotNull);

  // Act
  viewModel.setTitle('Valid Title');

  // Assert
  expect(viewModel.titleError, isNull);
});

test('validates all fields before save', () async {
  // Arrange
  viewModel.setTitle('');  // Invalid
  viewModel.setIngredients([]);  // Invalid

  // Act
  final canSave = await viewModel.validateAndSave();

  // Assert
  expect(canSave, isFalse);
  expect(viewModel.titleError, isNotNull);
  expect(viewModel.ingredientsError, isNotNull);
  verifyNever(() => mockService.personal.updateRecipe(any()));
});
```

### Form State

```dart
test('tracks form dirty state', () {
  // Arrange
  expect(viewModel.isDirty, isFalse);

  // Act
  viewModel.setTitle('New Title');

  // Assert
  expect(viewModel.isDirty, isTrue);
});

test('resets dirty state after save', () async {
  // Arrange
  viewModel.setTitle('New Title');
  expect(viewModel.isDirty, isTrue);

  when(() => mockService.personal.updateRecipe(any()))
      .thenAnswer((_) async => testRecipe);

  // Act
  await viewModel.save();

  // Assert
  expect(viewModel.isDirty, isFalse);
});
```

## Testing Streams and Subscriptions

### Stream Subscriptions

```dart
test('subscribes to recipe updates', () async {
  // Arrange
  final controller = StreamController<Recipe>();
  when(() => mockService.realtime.watchRecipe(any()))
      .thenAnswer((_) => controller.stream);

  // Act
  viewModel.watchRecipe();

  // Emit update
  final updatedRecipe = testRecipe.copyWith(title: 'Updated');
  controller.add(updatedRecipe);

  await Future.delayed(Duration(milliseconds: 100));

  // Assert
  expect(viewModel.recipe.title, equals('Updated'));

  await controller.close();
});

test('cancels subscriptions on dispose', () async {
  // Arrange
  final controller = StreamController<Recipe>();
  when(() => mockService.realtime.watchRecipe(any()))
      .thenAnswer((_) => controller.stream);

  viewModel.watchRecipe();

  // Act
  viewModel.dispose();

  // Assert - Stream should be cancelled
  expect(controller.hasListener, isFalse);

  await controller.close();
});
```

### Multiple Subscriptions

```dart
test('manages multiple stream subscriptions', () async {
  // Arrange
  final recipeController = StreamController<Recipe>();
  final commentsController = StreamController<List<Comment>>();

  when(() => mockService.realtime.watchRecipe(any()))
      .thenAnswer((_) => recipeController.stream);
  when(() => mockService.comments.watchComments(any()))
      .thenAnswer((_) => commentsController.stream);

  // Act
  viewModel.watchRecipe();
  viewModel.watchComments();

  // Emit updates
  recipeController.add(testRecipe.copyWith(title: 'Updated'));
  commentsController.add([Comment(/* ... */)]);

  await Future.delayed(Duration(milliseconds: 100));

  // Assert
  expect(viewModel.recipe.title, equals('Updated'));
  expect(viewModel.comments, hasLength(1));

  // Cleanup
  viewModel.dispose();
  await recipeController.close();
  await commentsController.close();
});
```

## Testing Navigation

```dart
test('navigates on successful save', () async {
  // Arrange
  when(() => mockService.personal.updateRecipe(any()))
      .thenAnswer((_) async => testRecipe);
  when(() => mockNavigationService.pop()).thenAnswer((_) async => {});

  // Act
  await viewModel.saveAndClose();

  // Assert
  verify(() => mockNavigationService.pop()).called(1);
});

test('does not navigate on save failure', () async {
  // Arrange
  when(() => mockService.personal.updateRecipe(any()))
      .thenThrow(Exception('Save failed'));

  // Act
  await viewModel.saveAndClose();

  // Assert
  verifyNever(() => mockNavigationService.pop());
});
```

## Testing Disposal

```dart
test('dispose() cancels subscriptions', () {
  // Arrange
  final controller = StreamController<Recipe>();
  when(() => mockService.realtime.watchRecipe(any()))
      .thenAnswer((_) => controller.stream);

  viewModel.watchRecipe();

  // Act
  viewModel.dispose();

  // Assert
  expect(controller.hasListener, isFalse);
});

test('dispose() clears listeners', () {
  // Arrange
  var listenerCalled = false;
  viewModel.addListener(() => listenerCalled = true);

  // Act
  viewModel.dispose();
  viewModel.notifyListeners();  // Should not call listener

  // Assert
  expect(listenerCalled, isFalse);
});

test('dispose() is idempotent', () {
  // Act & Assert - Should not throw
  expect(() {
    viewModel.dispose();
    viewModel.dispose();  // Second call should be safe
  }, returnsNormally);
});
```

## Testing List ViewModels

### Loading Items

```dart
test('loadRecipes() populates recipe list', () async {
  // Arrange
  final recipes = RecipeFactory.buildList(5);
  when(() => mockService.personal.getAllRecipes())
      .thenAnswer((_) async => recipes);

  // Act
  await viewModel.loadRecipes();

  // Assert
  expect(viewModel.recipes, hasLength(5));
  expect(viewModel.hasRecipes, isTrue);
  expect(viewModel.isEmpty, isFalse);
});

test('loadRecipes() handles empty result', () async {
  // Arrange
  when(() => mockService.personal.getAllRecipes())
      .thenAnswer((_) async => []);

  // Act
  await viewModel.loadRecipes();

  // Assert
  expect(viewModel.recipes, isEmpty);
  expect(viewModel.hasRecipes, isFalse);
  expect(viewModel.isEmpty, isTrue);
});
```

### Pagination

```dart
test('loadMore() appends to existing recipes', () async {
  // Arrange
  final page1 = RecipeFactory.buildList(10);
  final page2 = RecipeFactory.buildList(10);

  when(() => mockService.personal.getRecipesPage(0))
      .thenAnswer((_) async => page1);
  when(() => mockService.personal.getRecipesPage(1))
      .thenAnswer((_) async => page2);

  // Act
  await viewModel.loadRecipes();  // Load page 1
  await viewModel.loadMore();     // Load page 2

  // Assert
  expect(viewModel.recipes, hasLength(20));
  expect(viewModel.hasMore, isTrue);
});

test('loadMore() sets hasMore to false when no more items', () async {
  // Arrange
  when(() => mockService.personal.getRecipesPage(any()))
      .thenAnswer((_) async => []);  // No more items

  // Act
  await viewModel.loadMore();

  // Assert
  expect(viewModel.hasMore, isFalse);
  expect(viewModel.isLoadingMore, isFalse);
});
```

### Filtering and Searching

```dart
test('filterByCategory() updates filtered list', () async {
  // Arrange
  final recipes = [
    RecipeFactory.build(category: 'pasta'),
    RecipeFactory.build(category: 'pizza'),
    RecipeFactory.build(category: 'pasta'),
  ];
  when(() => mockService.personal.getAllRecipes())
      .thenAnswer((_) async => recipes);

  await viewModel.loadRecipes();

  // Act
  viewModel.filterByCategory('pasta');

  // Assert
  expect(viewModel.filteredRecipes, hasLength(2));
  expect(viewModel.filteredRecipes.every((r) => r.category == 'pasta'), isTrue);
});

test('search() debounces and filters', () async {
  // Arrange
  final recipes = RecipeFactory.buildList(10);
  when(() => mockService.searchRecipes(any()))
      .thenAnswer((_) async => recipes);

  // Act
  viewModel.search('pasta');
  viewModel.search('past');
  viewModel.search('pas');  // Rapid changes

  await Future.delayed(Duration(milliseconds: 400));  // Wait for debounce

  // Assert - Only last search executed
  verify(() => mockService.searchRecipes('pas')).called(1);
});
```

## Mock Helpers

```dart
class MockUnifiedRecipeService extends Mock implements UnifiedRecipeService {}
class MockNavigationService extends Mock implements NavigationService {}
class MockImagePickerService extends Mock implements ImagePickerService {}
```

## Best Practices

### ✅ DO:
- Test initialization
- Test all state changes
- Test notifyListeners() calls
- Verify loading/error states
- Test disposal cleanup
- Cancel subscriptions in tests
- Mock all service dependencies
- Test form validation
- Test user actions
- Test navigation flows

### ❌ DON'T:
- Test private ViewModel methods
- Test widget rendering (that's widget tests)
- Use real services
- Skip disposal tests
- Leave subscriptions uncancelled
- Test implementation details
- Depend on test execution order
- Skip error scenarios

## Common Patterns

### Testing with Fake Timer

```dart
test('auto-saves after delay', () async {
  // Arrange
  fakeAsync((async) {
    viewModel.setTitle('New Title');

    // Fast-forward time
    async.elapse(Duration(seconds: 5));

    // Assert
    verify(() => mockService.personal.updateRecipe(any())).called(1);
  });
});
```

### Testing Computed Properties

```dart
test('isValid computed from validation state', () {
  // Arrange
  viewModel.setTitle('Valid');
  viewModel.setIngredients(['Ingredient']);

  // Assert
  expect(viewModel.isValid, isTrue);

  // Act
  viewModel.setTitle('');

  // Assert
  expect(viewModel.isValid, isFalse);
});
```

---

**See Also**:
- [Service Testing](./service-testing.md) - Testing services with mocked repositories
- [Widget Testing](./widget-testing.md) - Testing widgets with ViewModels
- [Testing Patterns Overview](../SKILL.md) - Complete testing guide
