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

## Summary

The key to testing Firebase code effectively is understanding what you're testing:

1. **Testing business logic?** → Use unit tests with repository mocks
2. **Testing Firebase operations?** → Use integration tests with emulator
3. **Testing user journeys?** → Use E2E tests in staging

Remember: Most of your tests (80%) should be unit tests that are fast and reliable. Only test Firebase operations when you specifically need to verify server-side behavior.