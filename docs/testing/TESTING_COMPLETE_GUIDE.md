# 🧪 Complete Testing Guide - Butlery Application

**Comprehensive guide covering all testing approaches, patterns, and execution strategies for the Butlery Flutter application.**

**Last Updated**: January 2025
**Version**: 2.0
**Test Status**: See [TESTING_DASHBOARD.md](./TESTING_DASHBOARD.md)

---

## 📑 Table of Contents

### Core Strategy
- [Testing Strategy Overview](#testing-strategy-overview)
- [The Testing Pyramid](#the-testing-pyramid)
- [Decision Matrix: Which Test Type?](#decision-matrix-which-test-type)

### Common Patterns
- [Common Test Patterns](#common-test-patterns)
- [Setup & Teardown Patterns](#setup--teardown-patterns)
- [Mock Management Patterns](#mock-management-patterns)
- [Test Data Builders](#test-data-builders)

### Test Types
- [Unit Testing](#unit-testing)
  - [Service Layer Testing](#service-layer-testing)
  - [ViewModel Testing](#viewmodel-testing)
- [Integration Testing](#integration-testing)
- [Widget Testing](#widget-testing)
- [E2E Testing](#e2e-testing)

### Firebase Deep Dive
- [Firebase Testing Patterns](#firebase-testing-patterns)
- [FieldValue Operations](#fieldvalue-operations)
- [Firebase Emulator Setup](#firebase-emulator-setup)

### Production Execution
- [Running Tests](#running-tests)
- [Production Testing Guide](#production-testing-guide)
- [Bug Reporting](#bug-reporting)

---

## Testing Strategy Overview

Butlery uses a **hybrid testing strategy** that balances speed, reliability, and comprehensive coverage. The strategy is built on understanding what to test at each level and how to handle Firebase's unique challenges.

### The Core Problem: Firebase FieldValue Operations

Firebase FieldValue operations are **server-side constructs** that execute on Firebase servers, not in client code:
- `FieldValue.serverTimestamp()` - Sets timestamp on server
- `FieldValue.increment(n)` - Atomic increment on server
- `FieldValue.arrayUnion(elements)` - Atomic array addition
- `FieldValue.arrayRemove(elements)` - Atomic array removal
- `FieldValue.delete()` - Marks field for deletion

**These cannot be mocked with traditional mocking frameworks**, which is why we need a hybrid approach.

### The Solution: Strategic Test Distribution

```
        E2E Tests (5%)
       /              \
      /  Integration   \
     /   Tests (15%)    \
    /                    \
   /    Unit Tests        \
  /        (80%)           \
 /________________________ \
```

---

## The Testing Pyramid

### 🟢 Unit Tests (80% of tests)

**Purpose**: Business logic, calculations, state management, service coordination
**Location**: `/test/unit/`
**Speed**: Fast (<100ms per test)
**Dependencies**: None (all mocked)

**Approach**: Mock at repository level, never mock Firebase directly

**When to use Unit Tests:**
- Testing business logic and calculations
- Testing data transformations
- Testing service coordination
- Testing error handling
- Testing validation rules
- Testing state management

**Benefits**:
- ✅ Fast feedback (seconds for hundreds of tests)
- ✅ No external dependencies
- ✅ Deterministic results
- ✅ Easy to debug
- ✅ Can run offline

### 🟡 Integration Tests (15% of tests)

**Purpose**: Firebase operations, complex queries, batch operations
**Location**: `/test/integration/`
**Speed**: Slower (requires emulator or FakeFirebaseFirestore)
**Dependencies**: Firebase emulator or FakeFirebaseFirestore

**Approach**: Use real or simulated Firebase services

**When to use Integration Tests:**
- Using `FieldValue.serverTimestamp()`
- Using `FieldValue.increment()`
- Using `FieldValue.arrayUnion()` or `FieldValue.arrayRemove()`
- Testing complex queries with dynamic fields (`memberPermissions.$uid`)
- Testing batch operations or transactions
- Testing security rules
- Testing real-time listeners

**Benefits**:
- ✅ Test actual Firebase behavior
- ✅ Catch server-side operation issues
- ✅ Verify complex queries work correctly
- ✅ Test atomicity of batch operations

### 🔴 E2E Tests (5% of tests)

**Purpose**: Critical user journeys in production-like environment
**Location**: `/test/e2e/`
**Speed**: Slowest (full application stack)
**Dependencies**: Full environment (Firebase, services, etc.)

**Examples**:
- Complete authentication flow
- Recipe creation and sharing workflow
- Real-time collaboration features
- Payment processing
- Critical user journeys

**Benefits**:
- ✅ Test complete user flows
- ✅ Verify system integration
- ✅ Catch integration issues
- ✅ Production confidence

---

## Decision Matrix: Which Test Type?

| Scenario | Unit | Integration | E2E | Reason |
|----------|------|-------------|-----|---------|
| Business logic | ✅ | ❌ | ❌ | Fast, isolated, deterministic |
| Data validation | ✅ | ❌ | ❌ | Pure functions |
| Service coordination | ✅ | ❌ | ❌ | Mock at repository boundary |
| Error handling | ✅ | ❌ | ❌ | Test error paths easily |
| FieldValue.serverTimestamp() | ❌ | ✅ | ❌ | Server-side operation |
| FieldValue.increment() | ❌ | ✅ | ❌ | Server-side atomic operation |
| FieldValue.arrayUnion() | ❌ | ✅ | ❌ | Server-side array operation |
| Complex queries (dynamic fields) | ❌ | ✅ | ❌ | Dynamic field paths |
| Batch operations | ⚠️ | ✅ | ❌ | Test atomicity properly |
| Transactions | ❌ | ✅ | ❌ | Server-side consistency |
| Security rules | ❌ | ✅ | ❌ | Server-side validation |
| Real-time listeners | ⚠️ | ✅ | ❌ | Stream behavior |
| Offline persistence | ❌ | ✅ | ❌ | Firebase caching |
| UI rendering | ❌ | ❌ | Widget | UI-specific testing |
| Complete user flows | ❌ | ❌ | ✅ | End-to-end validation |

Legend: ✅ Preferred | ⚠️ Possible but limited | ❌ Not recommended

---

## Common Test Patterns

### Setup & Teardown Patterns

#### Standard Unit Test Setup

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';

void main() {
  group('ComponentName', () {
    late ComponentUnderTest component;
    late MockService mockService;
    late MockRepository mockRepository;

    setUp(() async {
      // Initialize test infrastructure
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Create mocks using factory
      mockService = MockFactory.createService();
      mockRepository = MockFactory.createRepository();

      // Configure initial states
      mockRepository.setRepositoryState(data: []);

      // Register mocks
      TestServiceLocator.registerMock<Service>(mockService);
      TestServiceLocator.registerMock<Repository>(mockRepository);

      // Create component under test
      component = ComponentUnderTest(
        service: mockService,
        repository: mockRepository,
      );
    });

    tearDown(() async {
      // Clean up
      component.dispose(); // If applicable
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    // Test cases follow...
  });
}
```

#### Integration Test Setup with Firebase

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../infrastructure/firebase/firebase_test_helper.dart';

@Tags(['integration', 'firebase'])
void main() {
  group('Firebase Integration Tests', () {
    setUpAll(() async {
      // Connect to Firebase emulators once for all tests
      await FirebaseTestHelper.connectToEmulators();
    });

    setUp(() async {
      // Clear data for clean test state
      await FirebaseTestHelper.clearFirestoreData();
    });

    tearDown(() async {
      // Optional: Additional cleanup per test
    });

    test('Firebase operation test', () async {
      final firestore = FirebaseFirestore.instance;

      // Test Firebase operations
      await firestore.collection('test').add({
        'timestamp': FieldValue.serverTimestamp(),
        'counter': FieldValue.increment(1),
      });

      // Verify results
      final docs = await firestore.collection('test').get();
      expect(docs.docs.first.data()['timestamp'], isA<Timestamp>());
    });
  });
}
```

#### Widget Test Setup

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import '../../test_support/base_widget_test.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  group('WidgetName', () {
    late MockViewModel mockViewModel;

    setUp(() async {
      await BaseWidgetTest.setupWidget();
      await TestServiceLocator.initialize();

      mockViewModel = MockViewModel();
      // Configure initial state
      mockViewModel.setViewModelState(
        isLoading: false,
        data: [],
      );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseWidgetTest.resetMocks();
    });

    Widget createTestWidget({Widget? child}) {
      return MaterialApp(
        home: ChangeNotifierProvider<ViewModel>.value(
          value: mockViewModel,
          child: child ?? WidgetUnderTest(),
        ),
      );
    }

    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(createTestWidget());
      expect(find.byType(WidgetUnderTest), findsOneWidget);
    });
  });
}
```

### Mock Management Patterns

#### Repository-Level Mocking (CORRECT for Unit Tests)

```dart
// ✅ CORRECT - Mock at repository level
test('should track notification analytics', () async {
  // Arrange
  final mockRepository = MockNotificationRepository();
  final service = NotificationAnalyticsManager(
    repository: mockRepository,
  );

  // Configure mock with business data
  mockRepository.setAnalyticsState(
    sentCount: 100,
    deliveredCount: 85,
  );

  when(() => mockRepository.incrementSentCount())
      .thenAnswer((_) async => 101);

  // Act
  await service.trackNotificationSent('user123', 'social');

  // Assert
  verify(() => mockRepository.incrementSentCount()).called(1);
});
```

#### What NOT to Mock (WRONG)

```dart
// ❌ WRONG - Trying to mock FieldValue (impossible!)
test('bad test', () {
  when(() => FieldValue.serverTimestamp()).thenReturn(???); // Impossible!
});

// ❌ WRONG - Testing repository logic in service tests
test('should query database correctly', () {
  // This belongs in repository tests!
});
```

#### Mock State Configuration Pattern

```dart
// Configure mock states for different test scenarios
class MockRecipeRepository extends Mock implements RecipeRepository {
  void setRepositoryState({
    List<Recipe>? recipes,
    bool hasError = false,
    String? errorMessage,
  }) {
    if (hasError) {
      when(() => getAll()).thenThrow(Exception(errorMessage));
    } else {
      when(() => getAll()).thenAnswer((_) async => recipes ?? []);
    }
  }
}

// Usage in tests
setUp(() {
  mockRepository.setRepositoryState(
    recipes: [Recipe(id: '1', title: 'Test Recipe')],
  );
});
```

#### Capturing Arguments Pattern

```dart
// Use Map<String, dynamic>.from() for type safety
test('should update with correct data', () async {
  // Arrange
  when(() => mockFirestore.collection(any()).doc(any()).update(any()))
      .thenAnswer((_) async => {});

  // Act
  await service.updateData('123', {'field': 'value'});

  // Assert
  final captured = verify(() => mockDoc.update(captureAny())).captured;
  final updateData = Map<String, dynamic>.from(captured.first as Map);
  expect(updateData['field'], equals('value'));
});
```

### Test Data Builders

#### Recipe Builder

```dart
class RecipeBuilder {
  String _id = 'test-recipe-id';
  String _title = 'Test Recipe';
  String _userId = 'test-user-id';
  List<String> _ingredients = ['Ingredient 1', 'Ingredient 2'];
  List<String> _instructions = ['Step 1', 'Step 2'];
  int _portions = 4;

  RecipeBuilder withId(String id) {
    _id = id;
    return this;
  }

  RecipeBuilder withTitle(String title) {
    _title = title;
    return this;
  }

  RecipeBuilder withUserId(String userId) {
    _userId = userId;
    return this;
  }

  RecipeBuilder withIngredients(List<String> ingredients) {
    _ingredients = ingredients;
    return this;
  }

  Recipe build() {
    return Recipe(
      id: _id,
      title: _title,
      userId: _userId,
      ingredients: _ingredients,
      instructions: _instructions,
      portions: _portions,
    );
  }
}

// Usage
final recipe = RecipeBuilder()
    .withTitle('Pasta Carbonara')
    .withIngredients(['Pasta', 'Eggs', 'Bacon'])
    .build();
```

#### User Builder

```dart
class UserBuilder {
  String _uid = 'test-user-id';
  String _email = 'test@example.com';
  String _displayName = 'Test User';
  bool _isAuthenticated = true;

  UserBuilder withUid(String uid) {
    _uid = uid;
    return this;
  }

  UserBuilder withEmail(String email) {
    _email = email;
    return this;
  }

  UserBuilder withDisplayName(String displayName) {
    _displayName = displayName;
    return this;
  }

  UserBuilder unauthenticated() {
    _isAuthenticated = false;
    return this;
  }

  User build() {
    return User(
      uid: _uid,
      email: _email,
      displayName: _displayName,
    );
  }
}
```

---

## Unit Testing

Unit tests form the foundation of your test suite (80% of tests). They are fast, isolated, and test business logic without external dependencies.

### Service Layer Testing

Services orchestrate business logic, coordinate between repositories and ViewModels, and handle error recovery. They are critical to test comprehensively.

#### Service Test Categories

**1. Initialization Tests**
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

**2. CRUD Operation Tests**
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

**3. Business Logic Tests**
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

**4. Error Handling Tests**
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

**5. State Management Tests**
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

#### Service Testing Checklist

- [ ] **Initialization**: Service starts in correct state
- [ ] **Dependencies**: All dependencies properly injected
- [ ] **Happy Path**: Core functionality works correctly
- [ ] **Error Cases**: All error scenarios handled
- [ ] **Edge Cases**: Empty data, nulls, boundaries tested
- [ ] **Concurrency**: Thread-safe operations verified
- [ ] **Performance**: No unnecessary operations
- [ ] **Cleanup**: Resources properly disposed

### ViewModel Testing

ViewModels are the **brain of your UI** - they handle user interactions, manage UI state, coordinate between services and views, and control navigation.

**Poor ViewModel testing = Bugs in production UI**

#### ViewModel Test Categories

**1. Initialization & Loading States**
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

**2. User Interaction Handling**
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

**3. Validation Logic**
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

**4. Error Handling & Recovery**
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

**5. State Transitions**
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

**6. Pagination & Infinite Scroll**
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

#### ViewModel Testing Checklist

**Must Test**
- [ ] **Initialization**: Correct initial state
- [ ] **Loading States**: isLoading, isRefreshing, etc.
- [ ] **Error States**: hasError, errorMessage
- [ ] **User Actions**: All button taps, form submissions
- [ ] **Validation**: All form validation logic
- [ ] **State Changes**: notifyListeners called appropriately
- [ ] **Cleanup**: dispose() releases resources

**Should Test**
- [ ] **Navigation**: Navigation events triggered
- [ ] **Permissions**: Auth checks before actions
- [ ] **Concurrency**: No race conditions
- [ ] **Edge Cases**: Empty lists, null values
- [ ] **Performance**: No unnecessary rebuilds

**Nice to Have**
- [ ] **Animations**: Animation controllers
- [ ] **Accessibility**: Screen reader support
- [ ] **Localization**: Translated strings

---

## Integration Testing

Integration tests verify Firebase operations, complex queries, and batch operations. Use them for the 15% of functionality that requires actual server-side behavior.

### When to Write Integration Tests

**MUST use integration tests for:**
1. Any code using `FieldValue` operations
2. Complex multi-document Firestore transactions
3. Nested document updates across collections
4. Server timestamp dependencies
5. Dynamic field queries (`memberPermissions.$uid`)
6. Batch operation atomicity
7. Security rule validation

### Integration Test Options

#### Option A: Firebase Emulator (Most Realistic)

```dart
@Tags(['integration', 'firebase'])
void main() {
  setUpAll(() async {
    // Connect to Firebase emulators
    await FirebaseTestHelper.connectToEmulators();
  });

  setUp(() async {
    // Clear data for clean test state
    await FirebaseTestHelper.clearFirestoreData();
  });

  test('should handle serverTimestamp correctly', () async {
    final firestore = FirebaseFirestore.instance;

    // Create document with server timestamp
    await firestore.collection('audit_logs').add({
      'timestamp': FieldValue.serverTimestamp(),
      'userId': 'test123',
      'action': 'deletion',
    });

    // Verify timestamp was set
    final docs = await firestore
        .collection('audit_logs')
        .where('userId', isEqualTo: 'test123')
        .get();

    expect(docs.docs.first.data()['timestamp'], isA<Timestamp>());

    // Verify it's recent (within 5 seconds)
    final timestamp = (docs.docs.first.data()['timestamp'] as Timestamp).toDate();
    expect(
      timestamp.difference(DateTime.now()).inSeconds.abs(),
      lessThan(5),
    );
  });
}
```

#### Option B: FakeFirebaseFirestore (Simpler Setup)

```dart
@Tags(['integration'])
void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  test('should handle batch operations', () async {
    // Add test data
    await firestore.collection('users').doc('user123').set({
      'name': 'Test User',
      'recipes': 10,
    });

    // Perform batch operation
    final batch = firestore.batch();
    batch.delete(firestore.collection('users').doc('user123'));
    batch.update(
      firestore.collection('statistics').doc('global'),
      {'deletedUsers': FieldValue.increment(1)},
    );
    await batch.commit();

    // Verify results
    final userDoc = await firestore.collection('users').doc('user123').get();
    expect(userDoc.exists, isFalse);
  });
}
```

### Common Integration Test Patterns

#### Pattern 1: Testing FieldValue Operations

```dart
// Service that uses FieldValue
class NotificationAnalyticsManager {
  final FirebaseFirestore _firestore;

  Future<void> recordNotificationSent(String category) async {
    final dayKey = DateTime.now().toIso8601String().split('T')[0];

    await _firestore.collection('analytics').doc('daily_$dayKey').set({
      'sentCount': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
      'categories': FieldValue.arrayUnion([category]),
    }, SetOptions(merge: true));
  }
}

// UNIT TEST - Mock at repository level
test('unit: should track notification sent', () async {
  final mockRepo = MockNotificationRepository();
  final manager = NotificationAnalyticsManager(repository: mockRepo);

  when(() => mockRepo.incrementSentCount())
      .thenAnswer((_) async => 11);

  await manager.recordNotificationSent('social');

  verify(() => mockRepo.incrementSentCount()).called(1);
});

// INTEGRATION TEST - Test actual FieldValue
test('integration: should use FieldValue operations', () async {
  await FirebaseTestHelper.connectToEmulators();
  final manager = NotificationAnalyticsManager(
    firestore: FirebaseFirestore.instance,
  );

  await manager.recordNotificationSent('social');

  final doc = await FirebaseFirestore.instance
      .collection('analytics')
      .doc('daily_${DateTime.now().toIso8601String().split('T')[0]}')
      .get();

  expect(doc.data()?['sentCount'], equals(1));
  expect(doc.data()?['categories'], contains('social'));
  expect(doc.data()?['lastUpdated'], isA<Timestamp>());
});
```

#### Pattern 2: Testing Batch Operations

```dart
// UNIT TEST - Test coordination logic
test('unit: should coordinate batch deletion', () async {
  final coordinator = DeletionCoordinator(
    recipeRepo: mockRecipeRepo,
    menuRepo: mockMenuRepo,
  );

  when(() => mockRecipeRepo.deleteAll('user123'))
      .thenAnswer((_) async => 5);
  when(() => mockMenuRepo.deleteAll('user123'))
      .thenAnswer((_) async => 3);

  final result = await coordinator.deleteUserContent('user123');

  expect(result.recipesDeleted, equals(5));
  expect(result.menusDeleted, equals(3));
});

// INTEGRATION TEST - Test actual batch atomicity
test('integration: should execute batch atomically', () async {
  final firestore = FakeFirebaseFirestore();

  // Setup test data
  await firestore.collection('recipes').doc('r1').set({'userId': 'user123'});
  await firestore.collection('menus').doc('m1').set({'userId': 'user123'});

  // Execute batch
  final batch = firestore.batch();
  batch.delete(firestore.collection('recipes').doc('r1'));
  batch.delete(firestore.collection('menus').doc('m1'));
  await batch.commit();

  // Verify atomicity
  final recipes = await firestore.collection('recipes').get();
  final menus = await firestore.collection('menus').get();
  expect(recipes.docs, isEmpty);
  expect(menus.docs, isEmpty);
});
```

#### Pattern 3: Testing Complex Queries

```dart
// WRONG in unit test:
test('unit: complex query fails', () async {
  final fakeFirestore = FakeFirebaseFirestore();

  // This query might not work correctly
  final results = await fakeFirestore
      .collection('lists')
      .where('memberPermissions.$userId', isEqualTo: 'admin')
      .get(); // May fail or give wrong results
});

// RIGHT in integration test:
test('integration: complex query works', () async {
  await FirebaseTestHelper.connectToEmulators();

  await FirebaseFirestore.instance.collection('lists').add({
    'memberPermissions': {
      'user123': 'admin',
      'user456': 'viewer',
    },
  });

  final results = await FirebaseFirestore.instance
      .collection('lists')
      .where('memberPermissions.user123', isEqualTo: 'admin')
      .get();

  expect(results.docs, hasLength(1));
});
```

### Integration Test Checklist

- [ ] Tag tests with `@Tags(['integration'])`
- [ ] Connect to emulators in setUpAll
- [ ] Clear data in setUp for isolation
- [ ] Test FieldValue operations work correctly
- [ ] Test batch/transaction atomicity
- [ ] Verify complex queries execute properly
- [ ] Test security rules if applicable
- [ ] Verify real-time listeners work

---

## Widget Testing

Widget tests verify that UI components render correctly, respond to user interactions, and handle different states appropriately.

**Current Status**: 149 widget test files in `/test/widget/` ✅

### Widget Test Structure

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import '../../test_support/base_widget_test.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  group('WidgetName', () {
    late MockViewModel mockViewModel;

    setUp(() async {
      await BaseWidgetTest.setupWidget();
      await TestServiceLocator.initialize();

      mockViewModel = MockViewModel();
      // Configure initial state
      mockViewModel.setViewModelState(
        isLoading: false,
        data: [],
      );
    });

    tearDown() async {
      await TestServiceLocator.reset();
      BaseWidgetTest.resetMocks();
    });

    Widget createTestWidget({Widget? child}) {
      return MaterialApp(
        home: ChangeNotifierProvider<ViewModel>.value(
          value: mockViewModel,
          child: child ?? WidgetUnderTest(),
        ),
      );
    }

    // Test cases follow...
  });
}
```

### Widget Test Categories

**1. Initial Rendering**
```dart
group('Initial Rendering', () {
  testWidgets('should display correctly with data', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(
      data: [Item(title: 'Test Item')],
    );

    // Act
    await tester.pumpWidget(createTestWidget());

    // Assert
    expect(find.text('Test Item'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('should show empty state', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(data: []);

    // Act
    await tester.pumpWidget(createTestWidget());

    // Assert
    expect(find.text('No items found'), findsOneWidget);
    expect(find.byIcon(Icons.inbox), findsOneWidget);
  });
});
```

**2. Loading States**
```dart
group('Loading States', () {
  testWidgets('should show loading indicator', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(isLoading: true);

    // Act
    await tester.pumpWidget(createTestWidget());

    // Assert
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Test Item'), findsNothing);
  });

  testWidgets('should hide loading when complete', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(isLoading: true);
    await tester.pumpWidget(createTestWidget());

    // Act
    mockViewModel.setViewModelState(
      isLoading: false,
      data: [Item()],
    );
    await tester.pump();

    // Assert
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
});
```

**3. User Interactions**
```dart
group('User Interactions', () {
  testWidgets('should handle tap on item', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(
      data: [Item(id: '123', title: 'Tap Me')],
    );

    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('Tap Me'));
    await tester.pump();

    // Assert
    verify(() => mockViewModel.onItemTap('123')).called(1);
  });

  testWidgets('should submit form on button press', (tester) async {
    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.enterText(find.byType(TextField), 'Test Input');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // Assert
    verify(() => mockViewModel.submitForm('Test Input')).called(1);
  });
});
```

**4. Error States**
```dart
group('Error States', () {
  testWidgets('should display error message', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(
      hasError: true,
      errorMessage: 'Network error occurred',
    );

    // Act
    await tester.pumpWidget(createTestWidget());

    // Assert
    expect(find.text('Network error occurred'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);
  });

  testWidgets('should show retry button on error', (tester) async {
    // Arrange
    mockViewModel.setViewModelState(hasError: true);

    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('Retry'));

    // Assert
    verify(() => mockViewModel.retry()).called(1);
  });
});
```

**5. Form Validation**
```dart
group('Form Validation', () {
  testWidgets('should show validation errors', (tester) async {
    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('Submit'));
    await tester.pump();

    // Assert
    expect(find.text('Title is required'), findsOneWidget);
  });

  testWidgets('should enable submit when valid', (tester) async {
    // Act
    await tester.pumpWidget(createTestWidget());
    await tester.enterText(
      find.byKey(Key('title_field')),
      'Valid Title',
    );
    await tester.pump();

    // Assert
    final submitButton = tester.widget<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(submitButton.onPressed, isNotNull);
  });
});
```

### Common Widget Testing Patterns

#### Testing Scrollable Content
```dart
testWidgets('should scroll to load more items', (tester) async {
  // Arrange
  mockViewModel.setViewModelState(
    data: List.generate(20, (i) => Item(id: '$i')),
  );

  // Act
  await tester.pumpWidget(createTestWidget());
  await tester.drag(find.byType(ListView), Offset(0, -500));
  await tester.pump();

  // Assert
  verify(() => mockViewModel.loadMore()).called(1);
});
```

#### Testing Animations
```dart
testWidgets('should animate on state change', (tester) async {
  // Act
  await tester.pumpWidget(createTestWidget());
  mockViewModel.triggerAnimation();

  // Pump frames for animation
  await tester.pump();
  await tester.pump(Duration(milliseconds: 500));

  // Assert
  final opacity = tester.widget<AnimatedOpacity>(
    find.byType(AnimatedOpacity),
  );
  expect(opacity.opacity, equals(1.0));
});
```

#### Testing Dialogs
```dart
testWidgets('should show confirmation dialog', (tester) async {
  // Act
  await tester.pumpWidget(createTestWidget());
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();

  // Assert
  expect(find.text('Are you sure?'), findsOneWidget);
  expect(find.text('Cancel'), findsOneWidget);
  expect(find.text('Confirm'), findsOneWidget);
});
```

#### Testing Navigation
```dart
testWidgets('should navigate to detail screen', (tester) async {
  // Arrange
  final navigatorKey = GlobalKey<NavigatorState>();

  // Act
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: WidgetUnderTest(),
      routes: {
        '/detail': (_) => DetailScreen(),
      },
    ),
  );
  await tester.tap(find.text('View Details'));
  await tester.pumpAndSettle();

  // Assert
  expect(find.byType(DetailScreen), findsOneWidget);
});
```

### Widget Testing Checklist

**Per Widget**
- [ ] **Renders correctly** with valid data
- [ ] **Handles empty state** appropriately
- [ ] **Shows loading state** when loading
- [ ] **Displays errors** clearly
- [ ] **Responds to taps** correctly
- [ ] **Validates input** if applicable
- [ ] **Accessible** with semantic labels
- [ ] **Responsive** to different screen sizes

**Per Screen**
- [ ] **Navigation works** between screens
- [ ] **State preserved** on navigation
- [ ] **Dialogs display** correctly
- [ ] **Keyboard handling** for forms
- [ ] **Scroll behavior** correct
- [ ] **Pull to refresh** if applicable

---

## E2E Testing

E2E tests verify complete user journeys but face unique challenges with Firebase apps. Our solution uses a **three-tier E2E testing system**.

### The E2E Firebase Challenge

Standard E2E tests fail with Firebase apps because:
- `main()` initializes Firebase with production config
- Tests have no Firebase credentials/project
- Platform channels fail in test environment

**Error Example:**
```
PlatformException(channel-error, Unable to establish connection on channel:
"dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi.initializeCore".)
```

### Three-Tier E2E Solution

#### Tier 1: Mock E2E Tests (60% of E2E) ⚡ Fastest

**Purpose**: Critical user journeys without Firebase dependencies
**Approach**: Full app with mock Firebase services
**Use Cases**: UI flows, navigation, form validation, local state

```dart
// lib/main_e2e_mock.dart
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Skip Firebase initialization completely
  await _initializeE2EMockSystem();

  runApp(const ButleryApp());
}

// test/e2e/flows/authentication_flow_mock_test.dart
testWidgets('complete registration UI flow', (tester) async {
  // Test pure UI/UX journey without Firebase
  await E2ETestRunner.runMockApp();
  await tester.pumpAndSettle();

  // Complete registration form flow
  await _completeRegistrationForm(tester);
  expect(find.byType(MainApp), findsOneWidget);
});
```

#### Tier 2: Emulator E2E Tests (35% of E2E) 🔥 Firebase Operations

**Purpose**: Firebase-dependent user journeys
**Approach**: Full app with Firebase emulator
**Use Cases**: Authentication, data persistence, real-time features

```dart
// lib/main_e2e_emulator.dart
Future<void> main() async {
  await Firebase.initializeApp();

  // Connect to Firebase emulators
  await _connectToE2EEmulators();
  await _initializeModularSystem();

  runApp(const ButleryApp());
}

// test/e2e/flows/authentication_flow_emulator_test.dart
testWidgets('complete authentication with Firebase', (tester) async {
  // Test with real Firebase Auth operations
  await E2ETestRunner.runEmulatorApp();
  await tester.pumpAndSettle();

  // Real Firebase user creation
  await _performRealRegistration(tester);

  // Verify Firebase state
  final user = FirebaseAuth.instance.currentUser;
  expect(user, isNotNull);
});
```

#### Tier 3: Staging E2E Tests (5% of E2E) 🌐 Production-Like

**Purpose**: Production-like critical paths
**Approach**: Real Firebase staging project
**Use Cases**: Production integrations, payment flows, external services

```dart
// lib/main_e2e_staging.dart
Future<void> main() async {
  await Firebase.initializeApp(
    options: StagingFirebaseOptions.currentPlatform, // Staging project
  );

  await _initializeModularSystem();
  runApp(const ButleryApp());
}
```

### E2E Test Patterns

#### Pattern 1: Authentication Journey (Mock)
```dart
testWidgets('registration form validation and UI flow', (tester) async {
  await MockE2ETest.runMockApp();

  // Test UI/UX without Firebase dependency
  await tester.pumpWidget(createE2EApp(config: E2EConfig.mock));
  await tester.pumpAndSettle();

  // Navigate to registration
  await tester.tap(find.text('Skapa konto'));
  await tester.pumpAndSettle();

  // Test form validation
  await tester.tap(find.byKey(Key('submit_button')));
  await tester.pumpAndSettle();
  expect(find.textContaining('obligatorisk'), findsAtLeastNWidgets(1));

  // Fill valid form
  await tester.enterText(find.byKey(Key('name_field')), 'Test User');
  await tester.enterText(find.byKey(Key('email_field')), 'test@example.com');
  await tester.enterText(find.byKey(Key('password_field')), 'password123');

  // Submit form
  await tester.tap(find.byKey(Key('submit_button')));
  await tester.pumpAndSettle();

  // Should navigate to main app (mocked success)
  expect(find.byType(AuthView), findsNothing);
});
```

#### Pattern 2: Authentication Journey (Emulator)
```dart
testWidgets('complete Firebase authentication flow', (tester) async {
  await EmulatorE2ETest.runEmulatorApp();

  await tester.pumpWidget(createE2EApp(config: E2EConfig.emulator));
  await tester.pumpAndSettle();

  // Complete real Firebase registration
  await _performRealRegistrationFlow(tester);

  // Verify real Firebase user created
  final user = FirebaseAuth.instance.currentUser;
  expect(user, isNotNull);
  expect(user!.email, equals('e2etest@example.com'));

  // Verify user document created in Firestore
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  expect(userDoc.exists, isTrue);
});
```

#### Pattern 3: Complete User Journey
```dart
testWidgets('recipe creation to sharing journey', (tester) async {
  await EmulatorE2ETest.runEmulatorApp();

  // Create authenticated user
  final user = await FirebaseTestHelper.createE2ETestUser(
    email: 'chef@example.com',
    password: 'password123',
    displayName: 'Chef User',
  );

  await tester.pumpWidget(createE2EApp(config: E2EConfig.emulator));
  await tester.pumpAndSettle();

  // Navigate to recipe creation
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();

  // Create complete recipe
  await _createRecipe(tester, 'E2E Test Recipe');

  // Share recipe
  await _shareRecipe(tester);

  // Verify recipe exists in Firebase
  final recipeDocs = await FirebaseFirestore.instance
      .collection('recipes')
      .where('userId', isEqualTo: user.uid)
      .get();
  expect(recipeDocs.docs.length, equals(1));
  expect(recipeDocs.docs.first.data()['title'], equals('E2E Test Recipe'));
});
```

---

## Firebase Testing Patterns

### Firebase FieldValue Operations

The core challenge in testing Firebase code is handling server-side operations that cannot be mocked.

#### FieldValue Operations Cannot Be Mocked

```dart
// ❌ IMPOSSIBLE - Cannot mock FieldValue
when(() => FieldValue.serverTimestamp()).thenReturn(???);
when(() => FieldValue.increment(1)).thenReturn(???);
```

#### Solution: Repository Abstraction

```dart
// ✅ CORRECT - Create repository abstraction
abstract class NotificationRepository {
  Future<int> incrementSentCount();
  Future<DateTime> getCurrentTimestamp();
  Future<void> addCategory(String category);
}

// Implementation uses FieldValue
class NotificationRepositoryImpl implements NotificationRepository {
  final FirebaseFirestore _firestore;

  @override
  Future<int> incrementSentCount() async {
    await _firestore.collection('analytics').doc('daily').set({
      'sentCount': FieldValue.increment(1),
    }, SetOptions(merge: true));

    final doc = await _firestore.collection('analytics').doc('daily').get();
    return doc.data()?['sentCount'] ?? 0;
  }
}

// Mock for unit tests
class MockNotificationRepository extends Mock implements NotificationRepository {
  void setAnalyticsState({int sentCount = 0}) {
    when(() => incrementSentCount()).thenAnswer((_) async => sentCount + 1);
  }
}
```

### Firebase Test Helper

Create a centralized helper for Firebase testing:

```dart
// test/infrastructure/firebase/firebase_test_helper.dart
class FirebaseTestHelper {
  static const _emulatorHost = 'localhost';
  static const _firestorePort = 8080;
  static const _authPort = 9099;
  static const _storagePort = 9199;

  static Timer? _connectionTimeout;
  static bool _emulatorsConnected = false;

  /// Connect to Firebase emulators
  static Future<void> connectToEmulators() async {
    if (_emulatorsConnected) return;

    try {
      // Set timeout for connection
      _connectionTimeout = Timer(Duration(seconds: 10), () {
        throw TimeoutException('Failed to connect to Firebase emulators');
      });

      // Connect to Firestore emulator
      FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, _firestorePort);

      // Connect to Auth emulator
      await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, _authPort);

      // Connect to Storage emulator if needed
      await FirebaseStorage.instance.useStorageEmulator(_emulatorHost, _storagePort);

      _connectionTimeout?.cancel();
      _emulatorsConnected = true;
      print('✅ Connected to Firebase emulators');
    } catch (e) {
      _connectionTimeout?.cancel();
      print('❌ Failed to connect to Firebase emulators: $e');
      throw e;
    }
  }

  /// Clear all Firestore data
  static Future<void> clearFirestoreData() async {
    final firestore = FirebaseFirestore.instance;

    // Get all collections
    final collections = [
      'users', 'recipes', 'menus', 'shopping_lists',
      'friendships', 'messages', 'audit_logs'
    ];

    for (final collection in collections) {
      final docs = await firestore.collection(collection).get();
      for (final doc in docs.docs) {
        await doc.reference.delete();
      }
    }
  }

  /// Create E2E test user with complete profile
  static Future<User> createE2ETestUser({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user!;
    await user.updateDisplayName(displayName);

    // Create complete user profile for E2E testing
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'displayName': displayName,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });

    return user;
  }

  /// Test FieldValue operations
  static Future<void> testFieldValueOperations() async {
    final testDoc = FirebaseFirestore.instance.collection('test').doc('fieldvalues');

    // Test serverTimestamp
    await testDoc.set({
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Test increment
    await testDoc.update({
      'counter': FieldValue.increment(1),
    });

    // Test arrayUnion
    await testDoc.update({
      'tags': FieldValue.arrayUnion(['new-tag']),
    });

    // Test arrayRemove
    await testDoc.update({
      'oldTags': FieldValue.arrayRemove(['old-tag']),
    });
  }
}
```

### Firebase Emulator Setup

#### 1. Install Firebase CLI
```bash
npm install -g firebase-tools
```

#### 2. Configure firebase.json
```json
{
  "emulators": {
    "auth": {
      "port": 9099
    },
    "firestore": {
      "port": 8080,
      "rules": "firestore.rules"
    },
    "storage": {
      "port": 9199
    },
    "ui": {
      "enabled": true,
      "port": 4000
    },
    "singleProjectMode": true
  }
}
```

#### 3. Start Emulators
```bash
firebase emulators:start
```

#### 4. View Emulator UI
Navigate to http://localhost:4000 to see the Emulator Suite UI.

---

## Running Tests

### Quick Commands

```bash
# Unit tests only (fast, no Firebase)
cmd.exe /c "flutter test --exclude-tags integration"

# Integration tests with FakeFirebaseFirestore
cmd.exe /c "flutter test --tags integration"

# Integration tests with Firebase emulator
# First: firebase emulators:start
cmd.exe /c "flutter test --tags integration,firebase"

# All tests
cmd.exe /c "flutter test"

# Specific test file
cmd.exe /c "flutter test test/unit/services/notification_service_test.dart"

# With coverage
cmd.exe /c "flutter test --coverage"

# Widget tests only
cmd.exe /c "flutter test test/widget/"

# E2E tests (mock)
cmd.exe /c "flutter test test/e2e --tags e2e,mock"

# E2E tests (emulator)
firebase emulators:start --only firestore,auth &
cmd.exe /c "flutter test test/e2e --tags e2e,emulator"
```

### Running Tests by Category

```bash
# Run all service tests
cmd.exe /c "flutter test test/unit/services/"

# Run all viewmodel tests
cmd.exe /c "flutter test test/unit/viewmodels/"

# Run all repository tests
cmd.exe /c "flutter test test/unit/repositories/"

# Run all model tests
cmd.exe /c "flutter test test/unit/models/"
```

### CI/CD Integration

```yaml
# .github/workflows/tests.yml
name: Tests
on: [pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - name: Run Unit Tests
        run: flutter test --exclude-tags integration

  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - name: Setup Firebase Emulator
        run: |
          npm install -g firebase-tools
          firebase emulators:exec --only firestore,auth \
            "flutter test --tags integration"

  e2e-mock:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - name: Run Mock E2E Tests
        run: flutter test test/e2e --tags "e2e,mock"
```

---

## Production Testing Guide

### Testing Objectives

1. **Identify all bugs** in production code
2. **Document non-working features** with severity levels
3. **Verify feature completion** against requirements
4. **Create fix roadmap** based on priority

### Testing Methodology

For each feature area:
- **Happy Path**: Normal expected usage
- **Edge Cases**: Boundary conditions
- **Error Cases**: Invalid inputs, network failures
- **Permissions**: Unauthorized access attempts
- **Performance**: Large datasets, slow networks

### Bug Classification

| Severity | Description | Example |
|----------|-------------|---------|
| **🔴 Critical** | App crashes, data loss, security issues | Login completely broken |
| **🟠 High** | Major feature broken, blocks user flow | Cannot create recipes |
| **🟡 Medium** | Feature partially works, has workaround | Import works but loses formatting |
| **🟢 Low** | Minor issues, cosmetic problems | Text alignment issues |

### Feature Testing Checklist

```markdown
## Feature: [Feature Name]
**Tester**: [Name]
**Date**: [Date]
**Version**: [App Version]

### Test Cases
- [ ] Happy path scenario
- [ ] Empty/null data handling
- [ ] Large data sets (100+ items)
- [ ] Network disconnection
- [ ] Permission denied scenarios
- [ ] Concurrent user actions
- [ ] Cross-platform consistency

### Results
- **Working**: ✅/❌
- **Issues Found**: [Count]
- **Critical Bugs**: [List bug IDs]
```

### Running App for Testing

```bash
# Run on connected device/emulator
cmd.exe /c "flutter run"

# Run with verbose logging
cmd.exe /c "flutter run -v"

# Run specific platform
cmd.exe /c "flutter run -d chrome"    # Web
cmd.exe /c "flutter run -d android"   # Android

# Profile mode for performance testing
cmd.exe /c "flutter run --profile"

# Check widget rebuilds
cmd.exe /c "flutter run --track-widget-creation"
```

---

## Bug Reporting

### Bug Report Format

When you find a bug, document it using this format:

```markdown
## BUG-[NUMBER]: [Short Description]

**Severity**: Critical/High/Medium/Low
**Feature Area**: [e.g., Recipe Import]
**View**: [e.g., ImportViaUrlView]
**ViewModel**: [e.g., UrlImportViewModel]

### Steps to Reproduce
1. Navigate to [screen]
2. Perform [action]
3. Observe [result]

### Expected Behavior
[What should happen]

### Actual Behavior
[What actually happens]

### Error Details
```
[Any error messages or stack traces]
```

### Screenshots
[If applicable]

### Workaround
[If available]

### Environment
- Platform: [iOS/Android/Web]
- Flutter Version: [version]
- Device: [device model]

### Fix Status
- [ ] Not Started
- [ ] In Progress
- [ ] Fixed
- [ ] Verified
```

---

## Testing Checklist

### Before Writing Tests

- [ ] Identify if code uses FieldValue operations
- [ ] Check for complex Firestore queries
- [ ] Determine if testing business logic or Firebase operations
- [ ] Choose appropriate test type (unit vs integration vs widget vs E2E)

### Unit Test Checklist

- [ ] Mock at repository level, not Firebase level
- [ ] Use configuration methods for mocks
- [ ] Test business logic and coordination
- [ ] Test error handling paths
- [ ] Avoid testing Firebase operations directly
- [ ] Test all public methods
- [ ] Test edge cases (nulls, empty lists, boundaries)
- [ ] Verify resource cleanup (dispose, close streams)

### Integration Test Checklist

- [ ] Tag tests with `@Tags(['integration'])`
- [ ] Connect to emulators in setUpAll
- [ ] Clear data in setUp for isolation
- [ ] Test FieldValue operations work correctly
- [ ] Test batch/transaction atomicity
- [ ] Verify complex queries execute properly
- [ ] Test security rules if applicable

### Widget Test Checklist

- [ ] Test initial rendering with valid data
- [ ] Test empty state display
- [ ] Test loading state indicator
- [ ] Test error state display
- [ ] Test user interactions (taps, scrolls)
- [ ] Test form validation
- [ ] Test accessibility (semantic labels)
- [ ] Test responsive behavior

### E2E Test Checklist

- [ ] Choose appropriate tier (mock/emulator/staging)
- [ ] Test complete user journeys
- [ ] Verify navigation flows
- [ ] Test cross-feature integration
- [ ] Verify data persistence
- [ ] Test error recovery
- [ ] Verify production-like scenarios

---

## Common Mistakes to Avoid

### ❌ DON'T

1. **Don't mock FieldValue operations** - They're server-side constructs
2. **Don't use FakeFirebaseFirestore for everything** - It has limitations with complex queries
3. **Don't forget to clean up** - Always clear data between tests
4. **Don't test Firebase in unit tests** - Keep them fast and isolated
5. **Don't skip integration tests** - They catch real Firebase issues
6. **Don't test implementation details** - Test behavior, not internals
7. **Don't use arbitrary delays** - Use `pumpAndSettle()` or proper async/await
8. **Don't test framework behavior** - Focus on your code

### ✅ DO

1. **Mock at repository level** - Clean abstraction boundary
2. **Use builders for test data** - Consistent, readable test data
3. **Clear data between tests** - Avoid test pollution
4. **Test error paths** - Don't only test happy paths
5. **Use meaningful test names** - Describe what you're testing
6. **Keep tests focused** - One assertion per test when possible
7. **Use setup helpers** - DRY principle applies to tests
8. **Document complex tests** - Explain the "why"

---

## Troubleshooting

### Problem: "Cannot mock FieldValue.serverTimestamp()"
**Solution**: Mock at repository level instead of trying to mock FieldValue.

### Problem: "FakeFirebaseFirestore query returns wrong results"
**Solution**: Use Firebase emulator for complex queries with dynamic fields.

### Problem: "Tests are slow with Firebase emulator"
**Solution**:
1. Only use emulator for integration tests (15% of tests)
2. Start emulator once before test suite
3. Clear data instead of restarting emulator

### Problem: "Integration tests fail intermittently"
**Solution**:
1. Always clear data in setUp
2. Use unique IDs for test data
3. Add proper async/await handling
4. Consider using test transactions

### Problem: "Widget test finds multiple widgets"
**Solution**: Use more specific finders with `byKey()` or `byType()` with unique keys.

### Problem: "Test fails on CI but passes locally"
**Solution**: Check for timing issues, use `pumpAndSettle()`, verify emulator connection.

---

## Coverage Goals

### Overall Targets
- **Unit Tests**: 80% of test suite (fast, isolated)
- **Integration Tests**: 15% of test suite (Firebase operations)
- **E2E Tests**: 5% of test suite (critical journeys)

### Minimum Coverage Per Component
- **Services**: 5 tests minimum, all public methods tested
- **ViewModels**: 5 tests minimum, all user interactions tested
- **Widgets**: All critical components tested
- **Repositories**: All CRUD operations tested

### Priority Order
1. Services used by multiple ViewModels (high impact)
2. ViewModels controlling critical UI flows
3. Services with complex business logic
4. Widgets with user interactions
5. Utility services and helper classes

---

## Summary

The key to testing Firebase code effectively is understanding **what you're testing**:

1. **Testing business logic?** → Use unit tests with repository mocks
2. **Testing Firebase operations?** → Use integration tests with emulator
3. **Testing UI rendering?** → Use widget tests
4. **Testing user journeys?** → Use three-tier E2E system (mock/emulator/staging)

Remember: **Most of your tests (80%) should be unit tests** that are fast and reliable. Only test Firebase operations when you specifically need to verify server-side behavior.

---

## Related Documents

- **[TESTING_DASHBOARD.md](./TESTING_DASHBOARD.md)** - Current coverage and priorities
- **[TEST_PATTERNS_QUICK_REFERENCE.md](./TEST_PATTERNS_QUICK_REFERENCE.md)** - Quick pattern lookup
- **[HYBRID_TESTING_STRATEGY.md](./HYBRID_TESTING_STRATEGY.md)** - Strategy overview
- **Templates**: `/test/templates/` - Test templates for each type

---

**Last Updated**: January 2025
**Maintained By**: Butlery Development Team
**Questions?** See [TESTING_DASHBOARD.md](./TESTING_DASHBOARD.md) for current status and priorities
