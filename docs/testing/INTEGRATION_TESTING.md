# Integration Testing Guide - Butlery Application

**Comprehensive guide for integration testing Firebase operations, complex queries, and batch operations in the Butlery Flutter application.**

**Last Updated**: January 2025

---

## Table of Contents

- [Overview](#overview)
- [When to Write Integration Tests](#when-to-write-integration-tests)
- [Integration Test Options](#integration-test-options)
  - [Option A: Firebase Emulator](#option-a-firebase-emulator-most-realistic)
  - [Option B: FakeFirebaseFirestore](#option-b-fakefirebasefirestore-simpler-setup)
- [Common Integration Test Patterns](#common-integration-test-patterns)
  - [Pattern 1: Testing FieldValue Operations](#pattern-1-testing-fieldvalue-operations)
  - [Pattern 2: Testing Batch Operations](#pattern-2-testing-batch-operations)
  - [Pattern 3: Testing Complex Queries](#pattern-3-testing-complex-queries)
- [Integration Test Checklist](#integration-test-checklist)
- [Related Documentation](#related-documentation)

---

## Overview

Integration tests verify Firebase operations, complex queries, and batch operations. Use them for the 15% of functionality that requires actual server-side behavior.

**Key Principle**: Integration tests should test what unit tests cannot - actual Firebase server-side behavior including FieldValue operations, batch atomicity, and complex query execution.

---

## When to Write Integration Tests

**MUST use integration tests for:**
1. Any code using `FieldValue` operations
2. Complex multi-document Firestore transactions
3. Nested document updates across collections
4. Server timestamp dependencies
5. Dynamic field queries (`memberPermissions.$uid`)
6. Batch operation atomicity
7. Security rule validation

**DON'T use integration tests for:**
- Business logic (use unit tests)
- Data transformations (use unit tests)
- Service coordination (use unit tests)
- UI rendering (use widget tests)

---

## Integration Test Options

### Option A: Firebase Emulator (Most Realistic)

**Best for**: Testing actual Firebase behavior including security rules and real-time operations.

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

**Advantages**:
- Tests actual Firebase behavior
- Tests security rules
- Tests real-time listeners
- Most realistic environment

**Disadvantages**:
- Requires emulator setup
- Slower than FakeFirebaseFirestore
- Requires emulator running

---

### Option B: FakeFirebaseFirestore (Simpler Setup)

**Best for**: Quick integration tests without emulator setup, simple Firebase operations.

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

**Advantages**:
- No emulator required
- Fast test execution
- Simple setup

**Disadvantages**:
- Does not test security rules
- May not handle complex queries correctly
- Simulates rather than tests real Firebase

---

## Common Integration Test Patterns

### Pattern 1: Testing FieldValue Operations

FieldValue operations are server-side constructs that cannot be mocked. Integration tests are the only way to verify they work correctly.

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

**FieldValue Operations to Test**:
- `FieldValue.serverTimestamp()` - Verify server sets timestamp
- `FieldValue.increment(n)` - Verify atomic increment
- `FieldValue.arrayUnion(elements)` - Verify array addition
- `FieldValue.arrayRemove(elements)` - Verify array removal
- `FieldValue.delete()` - Verify field deletion

---

### Pattern 2: Testing Batch Operations

Batch operations must be atomic - either all operations succeed or all fail. Integration tests verify this atomicity.

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

**What to Test in Batch Operations**:
- All operations complete successfully
- No partial completion on error
- Correct order of operations
- Transaction consistency
- Error handling and rollback

---

### Pattern 3: Testing Complex Queries

Complex Firestore queries, especially those with dynamic field paths, need integration testing to verify correct execution.

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

**Complex Queries to Test**:
- Dynamic field path queries (`field.$variable`)
- Compound queries (multiple where clauses)
- Array-contains queries
- Geo-queries
- Queries with orderBy and limit
- Collection group queries

---

## Integration Test Checklist

Use this checklist to ensure your integration tests are complete and correct:

**Test Setup**:
- [ ] Tag tests with `@Tags(['integration'])`
- [ ] Connect to emulators in setUpAll
- [ ] Clear data in setUp for isolation
- [ ] Use unique test data IDs

**FieldValue Operations**:
- [ ] Test FieldValue.serverTimestamp() sets correct timestamp
- [ ] Test FieldValue.increment() performs atomic increment
- [ ] Test FieldValue.arrayUnion() adds elements correctly
- [ ] Test FieldValue.arrayRemove() removes elements correctly
- [ ] Test FieldValue.delete() removes field

**Batch Operations**:
- [ ] Test batch/transaction atomicity
- [ ] Test partial failure rolls back all operations
- [ ] Test batch size limits
- [ ] Test operation ordering

**Complex Queries**:
- [ ] Verify complex queries execute properly
- [ ] Test dynamic field path queries
- [ ] Test compound queries
- [ ] Test query performance with large datasets

**Security and Rules**:
- [ ] Test security rules if applicable
- [ ] Verify unauthorized access is blocked
- [ ] Test permission validation

**Real-time Features**:
- [ ] Verify real-time listeners work
- [ ] Test listener updates on data changes
- [ ] Test listener cleanup

**Error Handling**:
- [ ] Test network failure scenarios
- [ ] Test permission denied scenarios
- [ ] Test invalid data scenarios

---

## Related Documentation

- **[TESTING_COMPLETE_GUIDE.md](./TESTING_COMPLETE_GUIDE.md)** - Complete testing guide
- **[FIREBASE_TESTING_PATTERNS.md](./FIREBASE_TESTING_PATTERNS.md)** - Firebase-specific patterns
- **[TESTING_DASHBOARD.md](./TESTING_DASHBOARD.md)** - Current test coverage and priorities

---

**Last Updated**: January 2025
**Maintained By**: Butlery Development Team
