# Unit Testing

**Complete guide to testing services and ViewModels in Butlery**

**Last Updated**: January 2025
**Related Guides**: [Testing Strategy](TESTING_STRATEGY.md) | [Integration Testing](INTEGRATION_TESTING.md) | [Testing Dashboard](TESTING_DASHBOARD.md)

---

## Overview

Unit tests form the foundation of your test suite (80% of tests). They are fast, isolated, and test business logic without external dependencies.

**Key Principles:**
- Mock at repository level, never Firebase directly
- Test business logic, not Firebase operations
- Fast execution (<100ms per test)
- Deterministic results
- No external dependencies

---

## Service Layer Testing

Services orchestrate business logic, coordinate between repositories and ViewModels, and handle error recovery. They are critical to test comprehensively.

### Service Test Categories

#### 1. Initialization Tests

```dart
group('Initialization', () {
  test('should initialize with default state', () {
    expect(service.isInitialized, isFalse);
    expect(service.cache, isEmpty);
  });

  test('should load initial data from repository', () async {
    // Arrange
    final testData = [TestModel()];
    when(() => mockRepository.getAll())
        .thenAnswer((_) async => testData);

    // Act
    await service.initialize();

    // Assert
    expect(service.isInitialized, isTrue);
    verify(() => mockRepository.getAll()).called(1);
  });
});
```

#### 2. CRUD Operation Tests

```dart
group('CRUD Operations', () {
  test('should create and cache item', () async {
    // Arrange
    final item = TestModel(id: '123');
    when(() => mockRepository.create(any()))
        .thenAnswer((_) async => item);

    // Act
    final result = await service.create(item);

    // Assert
    expect(result, equals(item));
    expect(service.cache.contains(item), isTrue);
    verify(() => mockRepository.create(item)).called(1);
  });

  test('should update cache on item update', () async {
    // Arrange
    final item = TestModel(id: '123');
    service.cache.add(item);
    final updatedItem = item.copyWith(title: 'Updated');

    when(() => mockRepository.update(any()))
        .thenAnswer((_) async => updatedItem);

    // Act
    await service.update(updatedItem);

    // Assert
    expect(service.cache.contains(updatedItem), isTrue);
    verify(() => mockRepository.update(updatedItem)).called(1);
  });
});
```

#### 3. Business Logic Tests

```dart
group('Business Logic', () {
  test('should calculate derived values correctly', () {
    // Test calculations, transformations, business rules
    final items = [
      Item(price: 10.0),
      Item(price: 20.0),
      Item(price: 30.0),
    ];

    final total = service.calculateTotal(items);

    expect(total, equals(60.0));
  });

  test('should validate data before operations', () {
    // Test validation logic
    final invalidItem = Item(price: -10.0);

    expect(
      () => service.create(invalidItem),
      throwsA(isA<ValidationException>()),
    );
  });
});
```

#### 4. Error Handling Tests

```dart
group('Error Handling', () {
  test('should retry on transient failures', () async {
    // Arrange
    var attempts = 0;
    when(() => mockRepository.fetch()).thenAnswer((_) async {
      attempts++;
      if (attempts < 3) throw NetworkException();
      return testData;
    });

    // Act
    final result = await service.fetchWithRetry();

    // Assert
    expect(result, equals(testData));
    expect(attempts, equals(3));
  });

  test('should fall back to cache on network error', () async {
    // Arrange
    when(() => mockRepository.fetch())
        .thenThrow(NetworkException());
    service.cache.add(cachedData);

    // Act
    final result = await service.fetchData();

    // Assert
    expect(result, equals(cachedData));
  });
});
```

#### 5. State Management Tests

```dart
group('State Management', () {
  test('should notify listeners on state change', () {
    // Arrange
    var notified = false;
    service.addListener(() => notified = true);

    // Act
    service.updateState();

    // Assert
    expect(notified, isTrue);
  });

  test('should maintain consistency across operations', () async {
    // Test state consistency during concurrent operations
    await Future.wait([
      service.operation1(),
      service.operation2(),
    ]);

    expect(service.isConsistent, isTrue);
  });
});
```

### Service Testing Checklist

- [ ] **Initialization**: Service starts in correct state
- [ ] **Dependencies**: All dependencies properly injected
- [ ] **Happy Path**: Core functionality works correctly
- [ ] **Error Cases**: All error scenarios handled
- [ ] **Edge Cases**: Empty data, nulls, boundaries tested
- [ ] **Concurrency**: Thread-safe operations verified
- [ ] **Performance**: No unnecessary operations
- [ ] **Cleanup**: Resources properly disposed

---

## ViewModel Testing

ViewModels are the **brain of your UI** - they handle user interactions, manage UI state, coordinate between services and views, and control navigation.

**Poor ViewModel testing = Bugs in production UI**

### ViewModel Test Categories

#### 1. Initialization & Loading States

```dart
group('Initialization', () {
  test('should start with loading state', () {
    expect(viewModel.isLoading, isTrue);
    expect(viewModel.hasError, isFalse);
    expect(viewModel.data, isEmpty);
  });

  test('should load initial data on init', () async {
    // Arrange
    final testData = [TestModel()];
    when(() => mockService.fetchData())
        .thenAnswer((_) async => testData);

    // Act
    await viewModel.initialize();

    // Assert
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.data, equals(testData));
    verify(() => mockService.fetchData()).called(1);
  });
});
```

#### 2. User Interaction Handling

```dart
group('User Interactions', () {
  test('should handle item selection', () {
    // Arrange
    final item = TestModel(id: '123');
    var notificationCount = 0;
    viewModel.addListener(() => notificationCount++);

    // Act
    viewModel.selectItem(item);

    // Assert
    expect(viewModel.selectedItem, equals(item));
    expect(notificationCount, greaterThan(0));
  });

  test('should handle form submission', () async {
    // Arrange
    viewModel.titleController.text = 'Test Title';
    viewModel.descriptionController.text = 'Test Description';

    when(() => mockService.create(any()))
        .thenAnswer((_) async => true);

    // Act
    await viewModel.submitForm();

    // Assert
    expect(viewModel.isSubmitting, isFalse);
    verify(() => mockService.create(any())).called(1);
  });
});
```

#### 3. Validation Logic

```dart
group('Validation', () {
  test('should validate required fields', () {
    // Arrange
    viewModel.titleController.text = '';

    // Act
    final isValid = viewModel.validateForm();

    // Assert
    expect(isValid, isFalse);
    expect(viewModel.titleError, isNotNull);
  });

  test('should validate email format', () {
    // Test various email formats
    expect(viewModel.validateEmail('test@example.com'), isTrue);
    expect(viewModel.validateEmail('invalid'), isFalse);
    expect(viewModel.validateEmail(''), isFalse);
  });
});
```

#### 4. Error Handling & Recovery

```dart
group('Error Handling', () {
  test('should show error when service fails', () async {
    // Arrange
    when(() => mockService.fetchData())
        .thenThrow(Exception('Network error'));

    // Act
    await viewModel.loadData();

    // Assert
    expect(viewModel.hasError, isTrue);
    expect(viewModel.errorMessage, contains('Network'));
    expect(viewModel.isLoading, isFalse);
  });

  test('should retry on user request', () async {
    // Arrange
    viewModel.setError('Initial error');
    when(() => mockService.fetchData())
        .thenAnswer((_) async => testData);

    // Act
    await viewModel.retry();

    // Assert
    expect(viewModel.hasError, isFalse);
    expect(viewModel.data, isNotEmpty);
  });
});
```

#### 5. State Transitions

```dart
group('State Transitions', () {
  test('should transition through states correctly', () async {
    // Track state changes
    final states = <ViewState>[];
    viewModel.addListener(() {
      states.add(viewModel.currentState);
    });

    // Trigger state changes
    await viewModel.performComplexOperation();

    // Verify state sequence
    expect(states, [
      ViewState.loading,
      ViewState.processing,
      ViewState.success,
    ]);
  });
});
```

#### 6. Pagination & Infinite Scroll

```dart
group('Pagination', () {
  test('should load more items when scrolled', () async {
    // Arrange
    final page1 = List.generate(10, (i) => Item(id: '$i'));
    final page2 = List.generate(10, (i) => Item(id: '${i+10}'));

    when(() => mockService.fetchPage(1))
        .thenAnswer((_) async => page1);
    when(() => mockService.fetchPage(2))
        .thenAnswer((_) async => page2);

    // Act
    await viewModel.loadInitial();
    await viewModel.loadMore();

    // Assert
    expect(viewModel.items, hasLength(20));
    expect(viewModel.hasMore, isTrue);
  });
});
```

### ViewModel Testing Checklist

**Must Test:**
- [ ] **Initialization**: Correct initial state
- [ ] **Loading States**: isLoading, isRefreshing, etc.
- [ ] **Error States**: hasError, errorMessage
- [ ] **User Actions**: All button taps, form submissions
- [ ] **Validation**: All form validation logic
- [ ] **State Changes**: notifyListeners called appropriately
- [ ] **Cleanup**: dispose() releases resources

**Should Test:**
- [ ] **Navigation**: Navigation events triggered
- [ ] **Permissions**: Auth checks before actions
- [ ] **Concurrency**: No race conditions
- [ ] **Edge Cases**: Empty lists, null values
- [ ] **Performance**: No unnecessary rebuilds

**Nice to Have:**
- [ ] **Animations**: Animation controllers
- [ ] **Accessibility**: Screen reader support
- [ ] **Localization**: Translated strings

---

## Common Patterns

### Testing Async Operations

```dart
test('should handle async operation with loading states', () async {
  // Track loading states
  final loadingStates = <bool>[];
  viewModel.addListener(() {
    loadingStates.add(viewModel.isLoading);
  });

  // Configure slow async operation
  when(() => mockService.fetchData()).thenAnswer(
    (_) => Future.delayed(Duration(milliseconds: 100), () => testData),
  );

  // Start operation
  final future = viewModel.loadData();

  // Verify loading started
  expect(viewModel.isLoading, isTrue);

  // Wait for completion
  await future;

  // Verify loading sequence
  expect(loadingStates, [true, false]);
});
```

### Testing Stream Subscriptions

```dart
test('should listen to data stream', () async {
  // Arrange
  final controller = StreamController<List<Item>>();
  when(() => mockRepository.watchItems())
      .thenAnswer((_) => controller.stream);

  // Act
  viewModel.startListening();

  // Emit data
  controller.add([Item(id: '1')]);
  await Future.delayed(Duration.zero); // Let stream process

  // Assert
  expect(viewModel.items, hasLength(1));

  // Cleanup
  await controller.close();
});
```

### Testing Debounced Operations

```dart
test('should debounce search queries', () async {
  // Configure search
  when(() => mockService.search(any()))
      .thenAnswer((_) async => searchResults);

  // Trigger multiple searches rapidly
  viewModel.searchController.text = 'a';
  viewModel.searchController.text = 'ab';
  viewModel.searchController.text = 'abc';

  // Wait for debounce period
  await Future.delayed(Duration(milliseconds: 500));

  // Verify only last search executed
  verify(() => mockService.search('abc')).called(1);
  verifyNever(() => mockService.search('a'));
  verifyNever(() => mockService.search('ab'));
});
```

---

## Best Practices

### DO

✅ **Test business logic thoroughly**
- All calculations and transformations
- All validation rules
- All error handling paths

✅ **Use test builders for complex objects**
- RecipeBuilder, UserBuilder, etc.
- Consistent test data
- Easy to modify

✅ **Test state transitions**
- Loading → Success
- Loading → Error
- Success → Refreshing

✅ **Verify mock interactions**
- Correct number of calls
- Correct arguments
- Proper sequence

### DON'T

❌ **Don't test Firebase operations**
- Use integration tests instead
- Mock at repository level

❌ **Don't test framework code**
- Flutter handles its own testing
- Focus on your business logic

❌ **Don't create brittle tests**
- Test behavior, not implementation
- Avoid over-mocking
- Keep tests simple

---

## Common Mistakes

### 1. Testing Implementation Details

```dart
// ❌ BAD - Testing private implementation
test('should call private method', () {
  // Don't test private methods!
});

// ✅ GOOD - Test public behavior
test('should calculate total correctly', () {
  final total = service.calculateTotal(items);
  expect(total, equals(expectedTotal));
});
```

### 2. Not Testing Error Cases

```dart
// ❌ BAD - Only testing happy path
test('should load data', () async {
  await service.loadData();
  expect(service.data, isNotEmpty);
});

// ✅ GOOD - Test error cases too
test('should handle load error', () async {
  when(() => mockRepository.fetch())
      .thenThrow(Exception('Error'));

  await service.loadData();

  expect(service.hasError, isTrue);
});
```

### 3. Missing Cleanup

```dart
// ❌ BAD - No cleanup
setUp(() {
  mockService = MockService();
  viewModel = ViewModel(service: mockService);
});
// Missing tearDown!

// ✅ GOOD - Proper cleanup
tearDown() {
  viewModel.dispose();
  mockService.reset();
});
```

---

## Next Steps

- **Integration Testing**: See [INTEGRATION_TESTING.md](INTEGRATION_TESTING.md) for Firebase tests
- **Widget Testing**: See [WIDGET_E2E_TESTING.md](WIDGET_E2E_TESTING.md) for UI tests
- **Firebase Patterns**: See [FIREBASE_TESTING_PATTERNS.md](FIREBASE_TESTING_PATTERNS.md) for FieldValue mocking
- **Testing Dashboard**: See [TESTING_DASHBOARD.md](TESTING_DASHBOARD.md) for current coverage

---

**Last Updated**: January 2025 | **Verified Against**: Actual test patterns in codebase
