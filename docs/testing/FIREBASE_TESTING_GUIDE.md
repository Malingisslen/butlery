# 🔥 Butlery Firebase Testing Guide

## Overview

This guide provides comprehensive patterns and solutions for testing Firebase-dependent code in the Butlery application. It addresses the unique challenges of testing server-side constructs like FieldValue operations and provides practical solutions.

## The Core Problem

Firebase FieldValue operations are server-side constructs that execute on Firebase servers, not in your client code:
- `FieldValue.serverTimestamp()` - Sets timestamp on server
- `FieldValue.increment(n)` - Atomic increment on server
- `FieldValue.arrayUnion(elements)` - Atomic array addition
- `FieldValue.arrayRemove(elements)` - Atomic array removal
- `FieldValue.delete()` - Marks field for deletion

These cannot be mocked with traditional mocking frameworks, causing hundreds of test failures.

## The Solution: Hybrid Testing Strategy

### Testing Pyramid

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

### 1. Unit Tests (80% of tests)

**Purpose**: Test business logic, data transformations, and service coordination.

**Approach**: Mock at the repository level, not Firebase level.

#### Example: Testing a Service with Firebase Dependencies

```dart
// ❌ WRONG - Trying to mock FieldValue
class BadApproach {
  test('bad test', () {
    when(() => FieldValue.serverTimestamp()).thenReturn(???); // Impossible!
  });
}

// ✅ CORRECT - Mock at repository level
class GoodApproach {
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
}
```

#### Creating Repository-Level Mocks

```dart
// Create a coordinator/wrapper for unit testing
class AccountDeletionCoordinator {
  final MockAccountDeletionRepository repository;
  final MockOfflineService offlineService;
  
  Future<Map<String, dynamic>> deleteUserAccount({
    required String reason,
  }) async {
    // Business logic coordination
    final tasks = {
      'recipes': repository.deleteUserRecipes(userId),
      'menus': repository.deleteUserMenus(userId),
      'offline': offlineService.clearUserData(userId),
    };
    
    // Execute and track results
    for (final entry in tasks.entries) {
      final success = await entry.value;
      // Track success/failure
    }
    
    return result;
  }
}
```

### 2. Integration Tests (15% of tests)

**Purpose**: Test actual Firebase operations, complex queries, and batch operations.

**Approach**: Use Firebase emulator or FakeFirebaseFirestore.

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

### 3. E2E Tests (5% of tests)

**Purpose**: Test critical user journeys in staging environment.

**Examples**:
- Complete authentication flow
- Recipe creation and sharing workflow  
- Real-time collaboration features
- Payment processing

## Firebase Testing Helper

Create a centralized helper for Firebase testing:

```dart
// test/infrastructure/firebase/firebase_test_helper.dart
class FirebaseTestHelper {
  static const _emulatorHost = 'localhost';
  static const _firestorePort = 8080;
  static const _authPort = 9099;
  static const _storagePort = 9199;
  
  static Timer? _connectionTimeout;
  
  /// Connect to Firebase emulators
  static Future<void> connectToEmulators() async {
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

## Decision Matrix: When to Use Each Approach

| Scenario | Unit Test | Integration Test | Reason |
|----------|-----------|------------------|---------|
| Business logic | ✅ | ❌ | Fast, isolated, deterministic |
| Data validation | ✅ | ❌ | Pure functions |
| Service coordination | ✅ | ❌ | Mock at repository boundary |
| Error handling | ✅ | ❌ | Test error paths easily |
| FieldValue.serverTimestamp() | ❌ | ✅ | Server-side operation |
| FieldValue.increment() | ❌ | ✅ | Server-side atomic operation |
| FieldValue.arrayUnion() | ❌ | ✅ | Server-side array operation |
| Complex queries (memberPermissions.$uid) | ❌ | ✅ | Dynamic field paths |
| Batch operations | ⚠️ | ✅ | Test atomicity properly |
| Transactions | ❌ | ✅ | Server-side consistency |
| Security rules | ❌ | ✅ | Server-side validation |
| Real-time listeners | ⚠️ | ✅ | Stream behavior |
| Offline persistence | ❌ | ✅ | Firebase caching |

Legend: ✅ Preferred | ⚠️ Possible but limited | ❌ Not recommended

## Common Patterns and Solutions

### Pattern 1: Testing Services with FieldValue Operations

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

### Pattern 2: Testing Batch Operations

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

### Pattern 3: Testing Complex Queries

```dart
// Queries with dynamic field paths
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

## Testing Checklist

### Before Writing Tests

- [ ] Identify if code uses FieldValue operations
- [ ] Check for complex Firestore queries
- [ ] Determine if testing business logic or Firebase operations
- [ ] Choose appropriate test type (unit vs integration)

### Unit Test Checklist

- [ ] Mock at repository level, not Firebase level
- [ ] Use configuration methods for mocks
- [ ] Test business logic and coordination
- [ ] Test error handling paths
- [ ] Avoid testing Firebase operations directly

### Integration Test Checklist

- [ ] Tag tests with `@Tags(['integration'])`
- [ ] Connect to emulators in setUpAll
- [ ] Clear data in setUp for isolation
- [ ] Test FieldValue operations work correctly
- [ ] Test batch/transaction atomicity
- [ ] Verify complex queries execute properly

### Common Mistakes to Avoid

1. **Don't mock FieldValue operations** - They're server-side constructs
2. **Don't use FakeFirebaseFirestore for everything** - It has limitations
3. **Don't forget to clean up** - Always clear data between tests
4. **Don't test Firebase in unit tests** - Keep them fast and isolated
5. **Don't skip integration tests** - They catch real Firebase issues

## Running Tests

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
cmd.exe /c "flutter test test/unit/services/notification_analytics_manager_test.dart"
```

## Firebase Emulator Setup

### 1. Install Firebase CLI
```bash
npm install -g firebase-tools
```

### 2. Configure firebase.json
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

### 3. Start Emulators
```bash
firebase emulators:start
```

### 4. View Emulator UI
Navigate to http://localhost:4000 to see the Emulator Suite UI.

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

## E2E Testing with Firebase (5% of tests)

E2E tests verify complete user journeys but face unique challenges with Firebase apps due to production Firebase initialization. Our solution uses a **three-tier E2E testing system**.

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
**Purpose:** Critical user journeys without Firebase dependencies  
**Approach:** Full app with mock Firebase services  
**Use Cases:** UI flows, navigation, form validation, local state

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
**Purpose:** Firebase-dependent user journeys  
**Approach:** Full app with Firebase emulator  
**Use Cases:** Authentication, data persistence, real-time features

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
**Purpose:** Production-like critical paths  
**Approach:** Real Firebase staging project  
**Use Cases:** Production integrations, payment flows, external services

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

### E2E Test Infrastructure

#### Base E2E Test Classes

```dart
// test/e2e/infrastructure/base_e2e_test.dart
abstract class BaseE2ETest {
  static Future<void> setupE2E() async {
    await BaseWidgetTest.setupWidget();
  }
  
  static Future<void> teardownE2E() async {
    await BaseWidgetTest.teardownWidget();
  }
  
  /// Helper to create E2E test environment
  static Widget createE2EApp({required E2EConfig config}) {
    return MaterialApp(
      home: _getAppForConfig(config),
      locale: const Locale('sv', 'SE'),
    );
  }
}

// Mock E2E tests - fastest execution
class MockE2ETest extends BaseE2ETest {
  static Future<void> runMockApp() async {
    // Initialize with mocked Firebase services
    await TestServiceLocator.initialize();
    TestServiceLocator.configureForScenario(TestScenario.unauthenticated);
  }
}

// Emulator E2E tests - real Firebase operations
class EmulatorE2ETest extends BaseE2ETest {
  static Future<void> runEmulatorApp() async {
    await FirebaseTestHelper.connectToEmulators();
    await FirebaseTestHelper.clearFirestoreData();
  }
}
```

#### Enhanced FirebaseTestHelper for E2E

```dart
// test/infrastructure/firebase/firebase_test_helper.dart (enhanced)
class FirebaseTestHelper {
  /// Initialize Firebase for E2E emulator testing
  static Future<void> initializeE2EEmulator() async {
    if (!_emulatorsConnected) {
      await connectToEmulators();
    }
    
    // Clear all data for clean E2E test state
    await clearFirestoreData();
    await _clearAuthUsers();
  }
  
  /// Create E2E test user with complete profile
  static Future<User> createE2ETestUser({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final user = await createTestUser(
      email: email,
      password: password,
      displayName: displayName,
    );
    
    // Create complete user profile for E2E testing
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'displayName': displayName,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    });
    
    return user;
  }
  
  /// Simulate complete user journey data
  static Future<void> createE2EUserJourney(String userId) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    
    // Create user's recipes
    final recipeRef = firestore.collection('recipes').doc();
    batch.set(recipeRef, {
      'title': 'E2E Test Recipe',
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Create shopping list
    final shoppingRef = firestore.collection('shopping_lists').doc();
    batch.set(shoppingRef, {
      'title': 'E2E Shopping List',
      'userId': userId,
      'items': ['Item 1', 'Item 2'],
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();
  }
  
  private static Future<void> _clearAuthUsers() async {
    // Clear all test users from Auth emulator
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      // Ignore if no user signed in
    }
  }
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

### Running E2E Tests

```bash
# Mock E2E tests (fastest - no Firebase)
flutter test test/e2e --tags "e2e,mock"

# Emulator E2E tests (requires Firebase emulator)
firebase emulators:start --only firestore,auth &
flutter test test/e2e --tags "e2e,emulator"

# All E2E tests
./scripts/run_all_e2e_tests.sh

# Specific E2E flow
flutter test test/e2e/flows/authentication_flow_test.dart
```

### E2E Test Scripts

```bash
#!/bin/bash
# scripts/run_e2e_emulator.sh
echo "🚀 Starting E2E tests with Firebase emulator"

# Start emulator in background
firebase emulators:start --only firestore,auth --project demo-test &
EMULATOR_PID=$!

# Wait for emulator to start
sleep 5

# Run E2E tests
flutter test test/e2e --tags "e2e,emulator"
TEST_RESULT=$?

# Stop emulator
kill $EMULATOR_PID

exit $TEST_RESULT
```

### CI/CD Integration

```yaml
# .github/workflows/e2e.yml
name: E2E Tests
on: [pull_request]

jobs:
  e2e-mock:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - name: Run Mock E2E Tests
        run: flutter test test/e2e --tags "e2e,mock"
  
  e2e-emulator:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - name: Setup Firebase Emulator
        run: |
          npm install -g firebase-tools
          firebase emulators:exec --only firestore,auth \
            "flutter test test/e2e --tags e2e,emulator"
```

### Benefits of Three-Tier E2E System

✅ **Fast Feedback:** Mock E2E tests run in <30 seconds  
✅ **Firebase Validation:** Emulator tests catch real Firebase issues  
✅ **Production Confidence:** Staging tests verify real integrations  
✅ **Ultrathink Compliance:** Production-code-first analysis maintained  
✅ **Swedish Localization:** Complete E2E user journey testing  
✅ **Zero Duplication:** Centralized patterns and configuration  

## Summary

The key to testing Firebase code effectively is understanding what you're testing:

1. **Testing business logic?** → Use unit tests with repository mocks
2. **Testing Firebase operations?** → Use integration tests with emulator
3. **Testing user journeys?** → Use three-tier E2E system (mock/emulator/staging)

Remember: Most of your tests (80%) should be unit tests that are fast and reliable. Only test Firebase operations when you specifically need to verify server-side behavior.