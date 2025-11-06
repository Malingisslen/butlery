# Testing Strategy

**Complete testing strategy, pyramid, and common patterns for Butlery**

**Last Updated**: January 2025
**Related Guides**: [Unit Testing](UNIT_TESTING.md) | [Integration Testing](INTEGRATION_TESTING.md) | [Testing Dashboard](TESTING_DASHBOARD.md)

---

## Overview

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

    tearDown() async {
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

    testWidgets('renders correctly', (tester) async {
      await tester.pumpWidget(createTestWidget());
      expect(find.byType(WidgetUnderTest), findsOneWidget);
    });
  });
}
```

---

## Mock Management Patterns

### Repository-Level Mocking (CORRECT for Unit Tests)

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

### What NOT to Mock (WRONG)

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

### Mock State Configuration Pattern

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

### Capturing Arguments Pattern

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

---

## Test Data Builders

### Recipe Builder

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

### User Builder

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

## Best Practices

### DO: Repository-Level Mocking

✅ **Mock repositories, not Firebase**
- Clean interface between business and data
- Fast, deterministic tests
- Easy to maintain

✅ **Use test builders for complex objects**
- Readable test setup
- Consistent test data
- Easy to modify

✅ **Configure mock states**
- Reusable test configurations
- Clear test scenarios
- Less duplication

### DON'T: Firebase-Level Mocking

❌ **Don't mock FieldValue operations**
- Impossible to mock correctly
- Leads to false positives
- Use integration tests instead

❌ **Don't test Firebase logic in unit tests**
- Use FakeFirestore or emulators
- Integration tests are the right place

❌ **Don't create brittle mocks**
- Avoid over-specification
- Mock only what's needed
- Keep mocks simple

---

## Common Mistakes

### 1. Mocking Too Deep

```dart
// ❌ BAD - Mocking too many layers
final mockFirestore = MockFirebaseFirestore();
final mockCollection = MockCollectionReference();
final mockDoc = MockDocumentReference();
// ... too complex!

// ✅ GOOD - Mock at repository level
final mockRepository = MockRecipeRepository();
```

### 2. Not Using Test Builders

```dart
// ❌ BAD - Inline object creation
final recipe = Recipe(
  id: 'id1',
  title: 'title',
  userId: 'user1',
  // ... many fields
);

// ✅ GOOD - Use builder
final recipe = RecipeBuilder()
    .withTitle('title')
    .build();
```

### 3. Missing Teardown

```dart
// ❌ BAD - No cleanup
setUp(() {
  mockService = MockService();
});
// Missing tearDown!

// ✅ GOOD - Proper cleanup
tearDown() {
  mockService.reset();
  TestServiceLocator.reset();
});
```

---

## Next Steps

- **Unit Testing**: See [UNIT_TESTING.md](UNIT_TESTING.md) for service and ViewModel tests
- **Integration Testing**: See [INTEGRATION_TESTING.md](INTEGRATION_TESTING.md) for Firebase patterns
- **Widget Testing**: See [WIDGET_E2E_TESTING.md](WIDGET_E2E_TESTING.md) for UI tests
- **Firebase Patterns**: See [FIREBASE_TESTING_PATTERNS.md](FIREBASE_TESTING_PATTERNS.md) for FieldValue mocking

---

**Last Updated**: January 2025 | **Verified Against**: Actual test patterns in codebase
