# 🧪 Butlery Test Guide - Primary Reference

## Quick Start for Tests

### 1. Standard Unit Test Template
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../../infrastructure/helpers/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  group('ServiceName', () {
    late ServiceName service;
    late MockDependency mockDependency;
    
    setUpAll(() async {
      // Initialize test infrastructure once for all tests
      await BaseUnitTest.setupUnit();
    });
    
    setUp(() async {
      // Initialize service locator and create service for each test
      await TestServiceLocator.initialize();
      mockDependency = TestServiceLocator.mockDependency;
      service = ServiceName(dependency: mockDependency);
    });
    
    tearDown(() async {
      // Reset mocks and service locator after each test
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      // Final cleanup after all tests
      await BaseUnitTest.teardownUnit();
    });
    
    test('should do something', () async {
      // Arrange
      mockDependency.setState(value: 'test');
      
      // Act
      final result = await service.doSomething();
      
      // Assert
      expect(result, isTrue);
    });
  });
}
```

## ✅ MUST DO

### 1. Configuration Over Stubbing
```dart
// ✅ CORRECT - Use configuration methods
mockAuthRepository.setAuthState(userId: 'test123');
mockRecipeService.setRecipeState(recipes: [recipe1, recipe2]);

// ❌ WRONG - Never stub concrete getters
when(() => mockAuthRepository.currentUserId).thenReturn('test123');
when(() => mockRecipeService.recipes).thenReturn([]);
```

### 2. Test Lifecycle Pattern
```dart
// ✅ CORRECT - Full lifecycle
setUpAll(() async {
  await BaseUnitTest.setupUnit();  // Once for all tests
});

setUp(() async {
  await TestServiceLocator.initialize();  // Before each test
});

tearDown(() async {
  BaseUnitTest.resetMocks();  // After each test
  await TestServiceLocator.reset();
});

tearDownAll(() async {
  await BaseUnitTest.teardownUnit();  // Final cleanup
});

// ❌ WRONG - Old patterns
tearDown(() async {
  await BaseUnitTest.teardownUnit();  // This is for tearDownAll, not tearDown!
});
```

### 3. AAA Pattern with Comments
```dart
test('should perform action', () async {
  // Arrange
  final mock = MockService();
  mock.setServiceState(data: testData);
  
  // Act
  final result = await service.performAction();
  
  // Assert
  expect(result, expectedValue);
});
```

### 4. Fallback Values (Automatic)
```dart
// ✅ Automatically registered when you call BaseUnitTest.setupUnit()
// No need to register fallback values manually!

// ❌ OLD WAY (no longer needed)
setUpAll(() {
  registerFallbackValue(Recipe.empty());
  registerFallbackValue(DateTime.now());
  // etc...
});

// ✅ NEW WAY - Just use BaseUnitTest.setupUnit()
setUpAll(() async {
  await BaseUnitTest.setupUnit();  // Handles all fallback registrations
});
```

### 5. Stub ALL Async Methods
```dart
// ✅ CORRECT - Stub every async method
when(() => mock.fetchData()).thenAnswer((_) async => []);
when(() => mock.saveData(any())).thenAnswer((_) async => true);
when(() => mock.deleteData(any())).thenAnswer((_) async {});

// ❌ WRONG - Forgetting causes "Null is not a subtype of Future"
```

### 5. Check Production JSON Structure
```dart
// ✅ CORRECT - Check actual structure
final json = recipe.toJson();
expect(json['core']['id'], equals(recipe.core.id));
expect(json['core']['title'], equals(recipe.core.title));

// ❌ WRONG - Assuming structure
expect(json['id'], equals(recipe.id));
```

## ❌ NEVER DO

1. **Never use TestContext** - Removed for simplicity
2. **Never stub concrete getters** - Use configuration methods
3. **Never use Future.delayed** - Except for stream events (100ms max)
4. **Never assume JSON structure** - Always check production code
5. **Never mix setUp patterns** - Always use BaseUnitTest.setupUnit()
6. **Never register fallback values manually** - They're centralized
7. **Never use teardownUnit in tearDown** - Use resetMocks() instead
8. **Never skip tearDown cleanup** - Always reset mocks and service locator

## Test Data Builders

### Recipe Builder
```dart
final recipe = RecipeBuilder()
  .withTitle('Köttbullar')
  .withTime(45)
  .asFavorite()
  .build();

// Swedish presets
final breakfast = RecipeBuilder().asSwedishBreakfast().build();
final dinner = RecipeBuilder().asSwedishDinner().build();
final fika = RecipeBuilder().asSwedishFika().build();
```

### User Builder
```dart
final user = UserBuilder()
  .withName('Sven Svensson')
  .withEmail('sven@example.se')
  .asSwedishUser()
  .build();
```

## Mock Access Pattern

```dart
// Always get mocks via TestServiceLocator static properties
final authService = TestServiceLocator.mockAuthService;
final recipeRepo = TestServiceLocator.mockRecipeRepository;

// Configure mocks via setters
authService.setAuthState(isAuthenticated: true);
recipeRepo.setRecipeState(recipes: [recipe1, recipe2]);

// Or via ServiceLocator.get (if not exposed as static property)
final customService = ServiceLocator.get<CustomService>();
```

## Test Templates

Use the appropriate template from `/test/templates/`:

1. **di_heavy_test_template.dart.template** - For tests with many dependencies
2. **simple_unit_test_template.dart.template** - For simple service tests
3. **viewmodel_test_template.dart.template** - For ViewModel tests
4. **model_test_template.dart.template** - For model/entity tests
5. **error_test_template.dart.template** - For comprehensive error testing

Copy the template and replace placeholders with your specific test needs.

## Commands

```bash
# Run all tests
cmd.exe /c "flutter test"

# Run specific test
cmd.exe /c "flutter test test/unit/services/auth_service_test.dart"

# Check analyzer (MUST be 0 issues)
cmd.exe /c "flutter analyze"
```

## File Organization

```
test/
├── infrastructure/
│   ├── helpers/        # Base test classes
│   ├── di/            # Test service locator
│   ├── factories/     # Mock and data factories
│   └── mocks/         # Mock implementations
│       ├── production_mocks.dart  # 46 centralized mocks
│       └── fallback_values.dart   # Centralized fallback registrations
├── templates/         # Test templates (.dart.template files)
│   ├── di_heavy_test_template.dart.template
│   ├── simple_unit_test_template.dart.template
│   ├── viewmodel_test_template.dart.template
│   ├── model_test_template.dart.template
│   └── error_test_template.dart.template
├── unit/              # Unit tests (target: 60%)
├── widget/            # Widget tests (target: 30%)
├── integration/       # Integration tests (target: 10%)
└── fixtures/          # Test data files
```

## Current Status (January 2025 - Verified Test Metrics)
- **Unit tests**: 2081 passing, 137 failing, 3 skipped (77 test files)
- **Integration tests**: 1 passing, 55 failing (10 test files, Firebase connection issues)
- **Widget tests**: 0 tests (empty directories exist)
- **46 centralized mocks** in production_mocks.dart ✅
- **Centralized fallback values** in fallback_values.dart ✅
- **All tearDown patterns standardized** (resetMocks + reset) ✅
- **5 test templates** created for different test types ✅
- **Configuration pattern** fully implemented ✅
- **0 duplicate mocks** (all centralized) ✅
- **Repository tests**: 43/47 (91.5% coverage) ⚠️
- **Service tests**: 36/129 (27.9% coverage) 🔴 Critical gap
- **ViewModel tests**: 5/54 (9.3% coverage) 🔴 Urgent attention needed
- **Total test count**: 2,218 tests (2,082 pass, 192 fail, 3 skip)

## Firebase Testing Strategy 🔥

### Problem
Firebase FieldValue operations (`serverTimestamp()`, `arrayUnion()`, `increment()`) are server-side constructs that cannot be properly mocked with FakeFirebaseFirestore, causing 157+ test failures.

### Solution: Hybrid Testing Approach

#### 1. Unit Tests (80%) - Mock at Repository Level
```dart
// ✅ CORRECT - Mock at repository level for business logic
class MockAccountDeletionRepository extends Mock {
  Future<bool> deleteUserRecipes(String userId) async => true;
  Future<String> createAuditLog(...) async => 'audit_123';
}

// Test business logic without Firebase
test('should coordinate deletion across services', () async {
  when(() => mockRepo.deleteUserRecipes('user123'))
      .thenAnswer((_) async => true);
  
  final result = await service.deleteAccount('user123');
  expect(result.success, isTrue);
});

// ❌ WRONG - Don't try to mock FieldValue
when(() => FieldValue.serverTimestamp()).thenReturn(???); // Impossible!
```

#### 2. Integration Tests (15%) - Firebase Emulator
```dart
// Test actual Firebase operations with emulator
@Tags(['integration', 'firebase'])
void main() {
  setUpAll(() async {
    await FirebaseTestHelper.connectToEmulators();
  });
  
  setUp(() async {
    await FirebaseTestHelper.clearFirestoreData();
  });
  
  test('should handle FieldValue.serverTimestamp', () async {
    final firestore = FirebaseFirestore.instance;
    
    // Create document with server timestamp
    await firestore.collection('audit_logs').add({
      'timestamp': FieldValue.serverTimestamp(),
      'action': 'test',
    });
    
    // Verify timestamp was set by server
    final doc = await firestore.collection('audit_logs')
        .where('action', isEqualTo: 'test')
        .get();
    
    expect(doc.docs.first.data()['timestamp'], isA<Timestamp>());
  });
}
```

#### 3. E2E Tests (5%) - Critical User Journeys
For authentication flows, data sync, and critical features only.

### Decision Matrix: Unit vs Integration

| Scenario | Test Type | Reason |
|----------|-----------|---------|
| Business logic | Unit | Fast, isolated, no Firebase needed |
| Data transformations | Unit | Pure functions, deterministic |
| Service coordination | Unit | Mock at repository boundary |
| FieldValue operations | Integration | Server-side constructs |
| Complex Firestore queries | Integration | Dynamic field paths like `memberPermissions.$uid` |
| Batch operations | Integration | Transaction atomicity |
| Security rules | Integration | Server-side validation |
| Real-time listeners | Integration | Stream behavior |

### Firebase Test Helper (`test/infrastructure/firebase/firebase_test_helper.dart`)
```dart
class FirebaseTestHelper {
  static const _emulatorHost = 'localhost';
  static const _firestorePort = 8080;
  static const _authPort = 9099;
  
  static Future<void> connectToEmulators() async {
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, _firestorePort);
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, _authPort);
  }
  
  static Future<void> clearFirestoreData() async {
    // Clear all collections for clean test state
  }
}
```

### Test Structure
```
test/
├── unit/           # Mock repositories (fast, no Firebase)
├── integration/    # Firebase emulator (real FieldValue ops)
│   └── firebase/
│       ├── firebase_test_helper.dart
│       ├── firebase_testing_patterns.dart
│       └── account_deletion_integration_test.dart
└── test_support/   # Base test classes
```

### Running Tests
```bash
# Unit tests only (fast, no Firebase)
cmd.exe /c "flutter test --exclude-tags integration"

# Integration tests (requires emulator)
# First start emulator: firebase emulators:start
cmd.exe /c "flutter test --tags integration"

# All tests
cmd.exe /c "flutter test"
```

### Common Pitfalls & Solutions

**Pitfall 1: Stubbing FieldValue operations**
```dart
// ❌ WRONG - Can't mock server-side constructs
when(() => mockFirestore.serverTimestamp()).thenReturn(...);

// ✅ CORRECT - Mock at repository level
when(() => mockRepo.updateTimestamp()).thenAnswer((_) async => DateTime.now());
```

**Pitfall 2: Using FakeFirebaseFirestore for complex queries**
```dart
// ❌ WRONG - Dynamic field paths fail
await fakeFirestore.collection('lists')
    .where('memberPermissions.$uid', isEqualTo: 'admin')
    .get(); // Fails!

// ✅ CORRECT - Use integration test with emulator
await FirebaseTestHelper.connectToEmulators();
// Now the query works correctly
```

**Pitfall 3: Not cleaning up between tests**
```dart
// ✅ CORRECT - Always clear data in setUp
setUp(() async {
  await FirebaseTestHelper.clearFirestoreData();
});
```

## Completed Work ✅

### Phase 3: Firebase Testing Strategy (Completed)
1. ✅ Analyzed Firebase testing issue with deep thinking (Gemini analysis)
2. ✅ Created hybrid testing strategy documentation
3. ✅ Added integration test structure
4. ✅ Created Firebase emulator setup helper (firebase_test_helper.dart)
5. ✅ Added FieldValue operations integration tests
6. ✅ Fixed NotificationAnalyticsManager tests (0% to 90% coverage)
7. ✅ Fixed AccountDeletionService tests with proper batch operation testing
8. ✅ Fixed ActivityService tests (26 tests all passing)
9. ✅ Created firebase_testing_patterns.dart with comprehensive examples
10. ✅ Updated firebase.json with emulator configuration

### Phase 1: Infrastructure Cleanup
1. ✅ Removed TestContext from all base test helpers
2. ✅ Fixed production ServiceLocator usage in 10 test files
3. ✅ Added automatic production ServiceLocator initialization to TestServiceLocator

### Phase 2: Mock & Pattern Standardization
1. ✅ Fixed 56 analyzer errors from sealed class mocking
2. ✅ Centralized 46 commonly used mocks in production_mocks.dart
3. ✅ Created centralized fallback value registration (44 files simplified)
4. ✅ Standardized tearDown pattern in 100+ test files
5. ✅ Created 5 test templates for consistent patterns
6. ✅ Fixed all tearDownAll misuse (changed to tearDown)
7. ✅ Added BaseUnitTest.resetMocks() to 27 files
8. ✅ Added TestServiceLocator.reset() to 25 files

### Original Achievements
1. ✅ Fixed all 46 stubbing violations (using configuration methods)
2. ✅ Established configuration pattern for all mocks
3. ✅ Added FirestoreRepository test with dependency injection support
4. ✅ Modified FirestoreRepository to support constructor injection for testing
5. ✅ Added comprehensive BaseFirebaseRepository test (foundation for all Firebase repos)
10. ✅ Tested permission validation, CRUD operations, batch operations, and error handling
11. ✅ **COMPLETED ALL REPOSITORY TESTS (Latest Session):**
    - firebase_social_sharing_repository_test.dart (36 tests)
    - friend_category_repository_test.dart (39 tests)
    - friend_relationship_repository_test.dart (29 tests)
    - friend_request_repository_test.dart (33 tests)
    - group_invitation_repository_test.dart (31 tests)
    - base_hive_repository_test.dart (21 tests)
    - recipe_hive_repository_test.dart (31 tests)
12. ✅ Achieved 91.5% repository layer coverage (43/47 repositories tested)

## Next Priority (Following True Dependency Order)
1. ⚠️ **Repository Layer** - 43/47 repositories tested (91.5% coverage, 4 missing)
2. **🔴 URGENT: Service Layer** - Only 36/129 tested (93 missing!)
   - Focus on critical services first (auth, data management, sync)
3. **🔴 CRITICAL: ViewModel Layer** - Only 5/54 tested (49 missing!)
   - Start with most-used ViewModels
4. Achieve 90% coverage layer by layer (services → viewmodels)
5. Create external_mocks.dart for third-party library mocks
6. Then: Add widget tests for critical UI components
7. Finally: Add integration tests for auth and recipe flows

**Why this order?**
- **Repositories are the foundation** - Services depend on them
- **Services depend on Repositories** - ViewModels depend on Services  
- **Bottom-up testing** ensures each layer has solid foundations
- **Bugs in lower layers** have cascading effects on all layers above