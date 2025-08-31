# 🔧 Service Layer Testing Guide

> **📊 For current coverage: [TESTING_DASHBOARD.md](./TESTING_DASHBOARD.md)**  
> **⚡ For general patterns: [TEST_PATTERNS_QUICK_REFERENCE.md](./TEST_PATTERNS_QUICK_REFERENCE.md)**

## Service Testing Philosophy

Services in Butlery follow the **unified architecture pattern** and require comprehensive testing because they:
- Orchestrate complex business logic
- Coordinate between repositories and ViewModels
- Handle error recovery and retry logic
- Manage caching and state synchronization

## Service Test Pattern

### Standard Service Test Structure
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('ServiceName', () {
    late ServiceName service;
    late MockRepository mockRepository;
    late MockCacheService mockCache;
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Get mocks from TestServiceLocator
      mockRepository = TestServiceLocator.mockRecipeRepository;
      mockCache = MockCacheService();
      
      // Configure mock states
      mockRepository.setRepositoryState(data: []);
      
      // Create service with dependencies
      service = ServiceName(
        repository: mockRepository,
        cache: mockCache,
      );
    });
    
    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });
    
    // Test categories follow...
  });
}
```

## Test Categories for Services

### 1. Initialization Tests
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

### 2. CRUD Operation Tests
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
    // Similar pattern for update, delete, etc.
  });
});
```

### 3. Business Logic Tests
```dart
group('Business Logic', () {
  test('should calculate derived values correctly', () {
    // Test any calculations, transformations, or business rules
    final result = service.calculateTotal([item1, item2]);
    expect(result, equals(expectedTotal));
  });
  
  test('should validate data before operations', () {
    // Test validation logic
    expect(
      () => service.create(invalidItem),
      throwsA(isA<ValidationException>()),
    );
  });
});
```

### 4. Error Handling Tests
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

### 5. State Management Tests
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
    // Test that state remains consistent during concurrent ops
  });
});
```

## Service-Specific Testing Focus

Services require special attention to:
- **Business Logic**: Complex calculations and transformations
- **State Management**: Caching and synchronization
- **Error Recovery**: Retry logic and fallbacks
- **Coordination**: Multiple repository interactions

## Common Service Testing Pitfalls

### ❌ DON'T
```dart
// Don't test repository logic in service tests
test('should query database correctly', () {
  // This belongs in repository tests!
});

// Don't skip error scenarios
test('should handle success', () {
  // Where's the error handling test?
});

// Don't ignore edge cases
test('should work with normal data', () {
  // What about empty lists, nulls, duplicates?
});
```

### ✅ DO
```dart
// Test service orchestration
test('should coordinate repository and cache', () {
  // Test how service manages multiple dependencies
});

// Test business rules
test('should apply discount rules correctly', () {
  // Service-specific business logic
});

// Test error recovery
test('should recover from partial failure', () {
  // How service handles complex error scenarios
});
```

## Service-Specific Test Examples

### UnifiedRecipeService
```dart
test('should merge personal and social recipes', () async {
  // Arrange
  mockPersonalModule.setRecipes([personalRecipe]);
  mockSocialModule.setRecipes([socialRecipe]);
  
  // Act
  final recipes = await service.getAllRecipes();
  
  // Assert
  expect(recipes, containsAll([personalRecipe, socialRecipe]));
  expect(recipes, hasLength(2));
});
```

### CollaborativeShoppingOperations
```dart
test('should sync shopping list changes in real-time', () async {
  // Arrange
  final stream = service.watchShoppingList('list-123');
  
  // Act
  service.addItem('list-123', 'Milk');
  
  // Assert
  await expectLater(
    stream,
    emits(predicate((list) => list.contains('Milk'))),
  );
});
```

### NotificationService
```dart
test('should batch notifications for efficiency', () async {
  // Arrange
  for (int i = 0; i < 10; i++) {
    service.queueNotification(Notification(id: '$i'));
  }
  
  // Act
  await service.processBatch();
  
  // Assert
  verify(() => mockFCM.sendBatch(any())).called(1); // Not 10!
});
```

## Testing Checklist for Each Service

- [ ] **Initialization**: Service starts in correct state
- [ ] **Dependencies**: All dependencies properly injected
- [ ] **Happy Path**: Core functionality works correctly
- [ ] **Error Cases**: All error scenarios handled
- [ ] **Edge Cases**: Empty data, nulls, boundaries tested
- [ ] **Concurrency**: Thread-safe operations verified
- [ ] **Performance**: No unnecessary operations
- [ ] **Cleanup**: Resources properly disposed
- [ ] **Integration**: Works with real dependencies (integration test)

## Coverage Goals

### Minimum Coverage Per Service
- **5 tests minimum** per service file
- **All public methods** must have at least one test
- **All error paths** must be tested
- **Critical services** need 10+ tests

### Priority Order
1. Services used by multiple ViewModels (high impact)
2. Services with complex business logic
3. Services handling user data
4. Services with external dependencies
5. Utility services

## Next Steps

1. **Immediate**: Test the 15 critical services listed above
2. **This Week**: Achieve 50% service coverage (65/129)
3. **Next Week**: Achieve 75% service coverage (97/129)
4. **Goal**: 90% service coverage with 600+ tests

## Running Service Tests

```bash
# Run all service tests
cmd.exe /c "flutter test test/unit/services/"

# Run specific service test
cmd.exe /c "flutter test test/unit/services/unified_recipe_service_test.dart"

# Run with coverage
cmd.exe /c "flutter test --coverage test/unit/services/"
```

## Priority 2 Services Completion (January 2025)

### DialogService Widget Tests
- **Status**: ✅ 22/22 tests passing
- **Pattern**: Widget testing approach for UI-dependent services
- **Key Achievement**: Context safety, Swedish localization, accessibility
- **Location**: `test/widget/services/dialog_service_test.dart`

### NotificationAnalyticsManager Unit Tests  
- **Status**: ✅ 28/28 unit tests passing
- **Pattern**: Hybrid testing - unit tests for business logic, integration for FieldValue
- **Key Achievement**: Repository abstraction, metric calculations, batch processing
- **Location**: `test/unit/services/notifications/modules/notification_analytics_manager_test.dart`

## Phase 5 Operations Completion (January 2025)

### CollaborativeMenuOperations
- **Status**: ✅ 24/24 tests passing
- **Key Learning**: Removed 5 tests requiring Firebase FieldValue operations
- **Pattern**: Tests using `FieldValue.arrayUnion()`, `FieldValue.arrayRemove()`, `FieldValue.serverTimestamp()`, and `FieldValue.increment()` must be integration tests
- **Solution**: Follow HYBRID_TESTING_STRATEGY.md for server-side operations

### SocialMenuOperations  
- **Status**: ✅ 19/19 tests passing
- **Coverage**: 100% of public methods tested
- **Key Additions**: 8 new tests for error handling, auth states, and edge cases
- **Pattern**: Comprehensive mock setup for friend service and Firestore operations

### Testing Patterns for Operations Classes

#### When to Remove Tests from Unit Scope
Remove unit tests and create integration tests when:
1. Using `FieldValue` operations (server-side constructs)
2. Complex multi-document Firestore transactions
3. Nested document updates across collections
4. Server timestamp dependencies
5. Complex data parsing requiring full model structures

#### Mock State Management Pattern
```dart
// ALWAYS create fresh mocks per test to avoid state pollution
setUp(() async {
  await BaseUnitTest.setupUnit();
  await TestServiceLocator.initialize();
  
  // Fresh mock instances
  mockFirestore = MockFirebaseFirestore();
  mockCollection = MockCollectionReference();
  mockDoc = MockDocumentReference();
  
  // Wire up mock chains
  when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
  when(() => mockCollection.doc(any())).thenReturn(mockDoc);
  
  // Create fresh operations instance
  operations = SocialMenuOperations(
    firestore: mockFirestore,
    friendsService: mockFriendsService,
  );
});
```

#### Capturing Arguments Pattern
```dart
// Use Map<String, dynamic>.from() for type safety
final captured = verify(() => mockDoc.update(captureAny())).captured;
final updateData = Map<String, dynamic>.from(captured.first as Map);
expect(updateData['field'], equals(expectedValue));
```

---
*For current coverage and priorities, see [TESTING_DASHBOARD.md](./TESTING_DASHBOARD.md)*