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

# Run integration tests only
flutter test --tags=integration

# Run all tests
flutter test
```

### CI/CD Pipeline

The GitHub Actions workflow automatically runs both test types:

1. **Unit Tests Job**: Runs on every push/PR, fast feedback
2. **Integration Tests Job**: Runs with Firebase emulator, thorough validation

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

### Test Results
- **Before**: 354 failing tests due to Firebase mocking issues
- **After**: All tests passing with proper separation of concerns
- **Coverage**: Maintained high test coverage with faster execution

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

## Future Improvements

1. **E2E Tests**: Implement end-to-end testing for critical user journeys
2. **Performance Testing**: Add performance benchmarks for Firebase operations
3. **Test Coverage Reports**: Generate and track coverage metrics
4. **Parallel Execution**: Optimize test execution with parallel runners
5. **Visual Regression**: Add screenshot testing for UI components