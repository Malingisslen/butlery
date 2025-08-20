# Hybrid Testing Strategy

## Overview

This document describes the hybrid testing strategy implemented for the Butlery Flutter application to address Firebase-specific testing challenges while maintaining high test coverage and fast test execution.

## Problem Statement

Firebase operations like `FieldValue.serverTimestamp()`, `FieldValue.arrayUnion()`, `FieldValue.arrayRemove()`, and `FieldValue.increment()` are server-side constructs that cannot be properly mocked client-side. Using `FakeFirebaseFirestore` for all tests was causing 157+ test failures.

## Solution: Hybrid Testing Pattern

We've implemented a three-tier testing strategy:

### 1. Unit Tests (80% of tests)
- **Purpose**: Test business logic and application behavior
- **Approach**: Mock repositories at the interface level, not Firebase implementation
- **Location**: `/test/unit/`
- **Execution**: Fast, no external dependencies
- **Tag**: None (default tests)

### 2. Integration Tests (15% of tests)
- **Purpose**: Test Firebase-specific operations and real-time features
- **Approach**: Use Firebase emulator for realistic Firebase behavior
- **Location**: `/test/integration/`
- **Execution**: Slower, requires Firebase emulator
- **Tag**: `@Tags(['integration'])`

### 3. E2E Tests (5% of tests)
- **Purpose**: Test complete user workflows
- **Approach**: Full application testing with real or emulated services
- **Location**: `/test/e2e/` (when implemented)
- **Execution**: Slowest, full environment required

## File Structure

```
test/
├── unit/
│   ├── repositories/
│   │   ├── firebase_user_repository_mock_test.dart
│   │   ├── firebase_recipe_repository_mock_test.dart
│   │   └── ... (other unit tests)
│   └── services/
│       └── ... (service unit tests)
│
├── integration/
│   └── firebase/
│       └── repositories/
│           ├── user_repository_integration_test.dart
│           ├── recipe_repository_integration_test.dart
│           └── ... (other integration tests)
│
└── infrastructure/
    ├── mocks/
    │   └── production_mocks.dart (centralized mocks)
    ├── factories/
    │   └── mock_factory.dart (mock creation helpers)
    └── di/
        └── test_service_locator.dart (test DI setup)
```

## Running Tests

### Firebase Emulator Setup (Required for Integration Tests)

```bash
# Install Firebase CLI (one-time setup)
npm install -g firebase-tools

# Start Firebase emulators
firebase emulators:start --only firestore,auth,storage

# Or use the UI for debugging
firebase emulators:start
# Then visit http://localhost:4000 for the Emulator UI
```

### Local Development

#### Windows (CMD/PowerShell)
```bash
# Run all tests
scripts\run_tests.bat all

# Run only unit tests (fast)
scripts\run_tests.bat unit

# Run only integration tests (requires Firebase emulator)
scripts\run_tests.bat integration
```

#### Linux/Mac/WSL
```bash
# Make script executable (first time only)
chmod +x scripts/run_tests.sh

# Run all tests
./scripts/run_tests.sh all

# Run only unit tests (fast)
./scripts/run_tests.sh unit

# Run only integration tests (requires Firebase emulator)
./scripts/run_tests.sh integration
```

#### Using Flutter directly
```bash
# Run unit tests only
flutter test --exclude-tags=integration

# Run integration tests only (start emulators first!)
flutter test --tags=integration

# Run all tests
flutter test
```

### CI/CD Pipeline

The GitHub Actions workflow automatically runs both test types:

1. **Unit Tests Job**: Runs on every push/PR, fast feedback
2. **Integration Tests Job**: Runs with Firebase emulator, thorough validation

## Implementation Examples for Problem Services

### Example 1: NotificationAnalyticsManager

#### Problem Code
```dart
// This fails with FakeFirebaseFirestore
await _firestore.collection('analytics').doc(metricId).set({
  'timestamp': FieldValue.serverTimestamp(),
  'count': FieldValue.increment(1),
  'categories': FieldValue.arrayUnion([category]),
});
```

#### Solution: Split Testing Approach

**Unit Test (Mock at Service Level)**
```dart
// test/unit/services/notifications/modules/notification_analytics_manager_test.dart
void main() {
  group('NotificationAnalyticsManager Unit Tests', () {
    late MockNotificationRepository mockRepository;
    late NotificationAnalyticsManager manager;
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      mockRepository = TestServiceLocator.mockNotificationRepository;
      manager = NotificationAnalyticsManager(repository: mockRepository);
    });
    
    test('should record notification sent', () async {
      // Mock at repository level, not Firebase level
      mockRepository.setAnalyticsState(
        sentCount: 5,
        deliveredCount: 3,
      );
      
      await manager.recordNotificationSent('user123', 'social');
      
      expect(mockRepository.getAnalytics().sentCount, equals(6));
    });
  });
}
```

**Integration Test (Real Firebase Operations)**
```dart
// test/integration/firebase/notification_analytics_integration_test.dart
@Tags(['integration'])
void main() {
  group('NotificationAnalyticsManager Integration Tests', () {
    late FirebaseFirestore firestore;
    late NotificationAnalyticsManager manager;
    
    setUpAll(() async {
      // Connect to Firebase emulator
      firestore = FirebaseFirestore.instance;
      await firestore.useFirestoreEmulator('localhost', 8080);
    });
    
    test('should use serverTimestamp correctly', () async {
      manager = NotificationAnalyticsManager(firestore: firestore);
      
      await manager.recordNotificationSent('user123', 'social');
      
      // Verify FieldValue operations work correctly
      final doc = await firestore
          .collection('analytics')
          .doc('daily_${DateTime.now().toIso8601String().split('T')[0]}')
          .get();
      
      expect(doc.data()?['timestamp'], isNotNull);
      expect(doc.data()?['sentCount'], equals(1));
      expect(doc.data()?['categories'], contains('social'));
    });
  });
}
```

### Example 2: AccountDeletionService

**Unit Test (Business Logic Focus)**
```dart
void main() {
  test('should coordinate deletion across services', () async {
    // Mock the coordination, not Firebase operations
    when(() => mockRecipeService.deleteAllUserRecipes('user123'))
        .thenAnswer((_) async => 5);
    when(() => mockSocialService.removeUserFromAllGroups('user123'))
        .thenAnswer((_) async => true);
    
    final result = await service.deleteUserAccount('user123');
    
    expect(result.recipesDeleted, equals(5));
    expect(result.success, isTrue);
  });
}
```

**Integration Test (Firebase Batch Operations)**
```dart
@Tags(['integration'])
void main() {
  test('should handle batch deletions with FieldValue.delete()', () async {
    // Test actual Firebase batch operations
    final batch = firestore.batch();
    
    await service.deleteUserAccount('user123');
    
    // Verify batch operations completed
    final userDoc = await firestore.collection('users').doc('user123').get();
    expect(userDoc.exists, isFalse);
  });
}
```

## Firebase Test Helper Infrastructure

### NEW: Firebase Test Helper (January 2025)

We've created comprehensive Firebase testing infrastructure to properly handle FieldValue operations:

#### Location
- **Helper**: `/test/infrastructure/firebase/firebase_test_helper.dart`
- **Patterns**: `/test/infrastructure/firebase/firebase_testing_patterns.dart`

#### Key Features
1. **Emulator Connection Management**: Automatic connection to Firebase emulators
2. **Data Cleanup**: Clear Firestore data between tests
3. **FieldValue Testing**: Proper patterns for serverTimestamp, increment, arrayUnion
4. **Batch Operations**: Test complex batch operations with FieldValue
5. **Stream Utilities**: Helper methods for testing real-time listeners

#### Usage Example
```dart
import 'package:flutter_test/flutter_test.dart';
import '../../infrastructure/firebase/firebase_test_helper.dart';

@Tags(['integration'])
void main() {
  setUpAll(() async {
    await FirebaseTestHelper.connectToEmulators();
  });
  
  setUp(() async {
    await FirebaseTestHelper.clearFirestoreData();
  });
  
  test('should handle FieldValue operations', () async {
    // This runs against real Firebase emulator
    await FirebaseTestHelper.testServerTimestamp();
    await FirebaseTestHelper.testIncrement();
    await FirebaseTestHelper.testArrayUnion();
  });
  
  // Or use the convenient wrapper
  firebaseIntegrationTest('should delete account properly', () async {
    await FirebaseTestHelper.testAccountDeletion('user123');
  });
}
```

## Writing Tests

### Unit Tests (Mock-based)

```dart
void main() {
  group('UserRepository Mock Tests', () {
    late MockUserRepository mockRepository;
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Create configured mock
      mockRepository = MockFactory.createUserRepository(
        currentUserId: 'test_user',
        profiles: {},
      );
    });
    
    test('should fetch user profile', () async {
      // Use configuration methods, not stubbing
      mockRepository.setUserRepositoryState(
        profiles: {'user_1': testProfile},
      );
      
      final profile = await mockRepository.getUserProfile('user_1');
      expect(profile, equals(testProfile));
    });
  });
}
```

### Integration Tests (Firebase Emulator)

```dart
@Tags(['integration'])
void main() {
  group('UserRepository Integration Tests', () {
    late FirebaseUserRepository repository;
    late FakeFirebaseFirestore firestore;
    
    setUp(() async {
      firestore = FakeFirebaseFirestore();
      repository = FirebaseUserRepository(firestore: firestore);
    });
    
    test('should use serverTimestamp for profile updates', () async {
      // Test actual Firebase operations
      await repository.updateProfile(
        userId: 'test_user',
        data: {'name': 'Test User'},
      );
      
      // Verify Firebase-specific behavior
      final doc = await firestore
          .collection('users')
          .doc('test_user')
          .get();
      
      expect(doc.data()?['updatedAt'], isNotNull);
    });
  });
}
```

## Decision Matrix: Unit vs Integration Tests

### When to Use Unit Tests
✅ Use unit tests when:
- Testing business logic and calculations
- Testing data transformations
- Testing error handling logic  
- Testing state management
- Testing coordination between services
- Mocking at the repository level (not Firebase level)

### When to Use Integration Tests
✅ Use integration tests when:
- Using FieldValue operations (serverTimestamp, increment, arrayUnion, arrayRemove)
- Testing complex Firestore queries with dynamic fields (e.g., `memberPermissions.$uid`)
- Testing batch operations or transactions
- Testing Firebase security rules
- Testing real-time listeners and streams
- Testing Firebase Functions triggers
- Verifying actual Firebase behavior

### When to Use E2E Tests
✅ Use E2E tests when:
- Testing complete user journeys
- Testing authentication flows end-to-end
- Testing cross-platform behavior
- Testing performance under load
- Validating critical business workflows

## Key Principles

### 1. Configuration Over Stubbing
Instead of stubbing concrete methods, use configuration methods:

```dart
// ✅ CORRECT - Configuration
mockRepository.setAuthState(userId: 'test_123');

// ❌ WRONG - Stubbing concrete getter
when(() => mockRepository.currentUserId).thenReturn('test_123');
```

### 2. Mock at Repository Level
Mock the repository interface, not Firebase itself:

```dart
// ✅ CORRECT - Mock repository
class MockUserRepository extends Mock implements UserRepository {}

// ❌ WRONG - Mock Firebase directly
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
```

### 3. Separate Concerns
- **Unit tests**: Focus on business logic, use mocks
- **Integration tests**: Test Firebase operations, use emulator
- **Keep tests focused**: Don't mix concerns in a single test

## Benefits

1. **Fast Feedback**: Unit tests run in seconds without external dependencies
2. **Reliability**: No more flaky tests due to Firebase mocking limitations
3. **Comprehensive Coverage**: Both business logic and Firebase operations tested
4. **Maintainability**: Clear separation of concerns and test types
5. **CI/CD Ready**: Automated pipeline handles both test types

## Migration Status

### Completed Repositories ✅
- firebase_friends_repository_test.dart
- firebase_notifications_repository_test.dart
- firebase_comments_repository_test.dart
- firebase_user_repository_test.dart
- firebase_recipe_repository_test.dart
- collaborative_recipe_repository_test.dart
- firebase_shopping_repository_test.dart
- firebase_messaging_repository_test.dart
- base_firebase_repository_test.dart

### Services Requiring Migration 🔄
Based on the January 2025 audit, these services have Firebase FieldValue issues:

#### Priority 1: Currently Failing/Skipped Tests
- **NotificationAnalyticsManager** (0% coverage - all tests skipped)
  - Issue: Heavy use of `FieldValue.serverTimestamp()` for metrics
  - Solution: Create integration tests for analytics operations
  
- **AccountDeletionService** (45.5% coverage)
  - Issue: Batch deletion operations with `FieldValue.delete()`
  - Solution: Integration tests for GDPR-critical deletion flows

- **ActivityService** (<10% coverage)
  - Issue: Activity tracking uses `FieldValue.serverTimestamp()` and `FieldValue.increment()`
  - Solution: Mock at service level for unit tests, integration tests for Firebase operations

#### Priority 2: Services with FakeFirebaseFirestore Limitations
- **FCMService** - Uses local mocks instead of centralized due to Firebase limitations
- **NotificationRepository** - Using FakeFirebaseFirestore with limitations
- **OfflineInitialization** - Platform channel issues combined with Firebase

### Test Results
- **Before**: 354 failing tests due to Firebase mocking issues
- **After (Partial)**: Repositories migrated and passing
- **Remaining**: 3-4 critical services still need migration
- **Coverage Impact**: Could recover ~15-20% coverage by fixing these services

## Troubleshooting

### Firebase Emulator Issues

If integration tests fail with connection errors:

1. **Install Firebase CLI**: `npm install -g firebase-tools`
2. **Check ports**: Ensure ports 8080, 9099, 9199 are available
3. **Manual start**: Run `firebase emulators:start` in a separate terminal
4. **Check logs**: Look for emulator startup errors

### Test Discovery Issues

If tests aren't found:

1. **Check tags**: Ensure `@Tags(['integration'])` is properly set
2. **File location**: Integration tests must be in `/test/integration/`
3. **Import statements**: Include proper test imports

### Mock Configuration Issues

If mocks aren't working correctly:

1. **Use configuration methods**: Don't stub concrete implementations
2. **Register fallback values**: For Mocktail, register required types
3. **Check mock factory**: Use `MockFactory` for consistent mock creation

## Coverage Improvement Potential

By implementing this hybrid strategy for the identified services:

### Immediate Coverage Gains
- **NotificationAnalyticsManager**: 0% → 90% (+90% coverage)
- **AccountDeletionService**: 45.5% → 90% (+44.5% coverage)
- **ActivityService**: <10% → 85% (+75% coverage)
- **FCMService**: Could use centralized mocks with proper abstraction

### Overall Impact
- **Current Average**: 72.3% (based on audit)
- **Potential Average**: 85-90% after migration
- **Test Reliability**: Eliminate false failures from FieldValue operations
- **Execution Speed**: Unit tests remain fast, integration tests run separately

### Implementation Priority
1. **Week 1**: NotificationAnalyticsManager (highest impact, clearest path)
2. **Week 2**: AccountDeletionService (GDPR compliance critical)
3. **Week 3**: ActivityService (core feature, needs most work)
4. **Week 4**: Standardize remaining services to hybrid approach

## Future Improvements

1. **E2E Tests**: Implement end-to-end testing for critical user journeys
2. **Performance Testing**: Add performance benchmarks for Firebase operations
3. **Test Coverage Reports**: Generate and track coverage metrics
4. **Parallel Execution**: Optimize test execution with parallel runners
5. **Visual Regression**: Add screenshot testing for UI components
6. **Automated Migration**: Create scripts to help migrate existing tests to hybrid pattern
7. **Mock Abstraction Layer**: Build abstraction layer to swap between mock and real Firebase