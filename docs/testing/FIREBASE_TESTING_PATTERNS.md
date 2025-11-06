# Firebase Testing Patterns - Butlery Application

**Comprehensive guide for testing Firebase-specific operations, FieldValue operations, and running tests in the Butlery Flutter application.**

**Last Updated**: January 2025

---

## Table of Contents

- [Firebase Testing Patterns](#firebase-testing-patterns-overview)
  - [Firebase FieldValue Operations](#firebase-fieldvalue-operations)
  - [Solution: Repository Abstraction](#solution-repository-abstraction)
- [Firebase Test Helper](#firebase-test-helper)
- [Firebase Emulator Setup](#firebase-emulator-setup)
- [Running Tests](#running-tests)
  - [Quick Commands](#quick-commands)
  - [Running Tests by Category](#running-tests-by-category)
  - [CI/CD Integration](#cicd-integration)
- [Related Documentation](#related-documentation)

---

## Firebase Testing Patterns Overview

The core challenge in testing Firebase code is handling server-side operations that cannot be mocked.

### Firebase FieldValue Operations

FieldValue operations are **server-side constructs** that execute on Firebase servers, not in client code:
- `FieldValue.serverTimestamp()` - Sets timestamp on server
- `FieldValue.increment(n)` - Atomic increment on server
- `FieldValue.arrayUnion(elements)` - Atomic array addition
- `FieldValue.arrayRemove(elements)` - Atomic array removal
- `FieldValue.delete()` - Marks field for deletion

**These cannot be mocked with traditional mocking frameworks.**

---

#### FieldValue Operations Cannot Be Mocked

```dart
// IMPOSSIBLE - Cannot mock FieldValue
when(() => FieldValue.serverTimestamp()).thenReturn(???);
when(() => FieldValue.increment(1)).thenReturn(???);
```

**Why?** FieldValue operations are server-side markers that tell Firebase what to do. They don't execute in client code, so mocking them is meaningless.

---

### Solution: Repository Abstraction

The solution is to create repository abstractions that hide FieldValue operations behind business methods.

```dart
// CORRECT - Create repository abstraction
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

**Key Principle**: Mock business operations (incrementSentCount), not Firebase operations (FieldValue.increment).

---

## Firebase Test Helper

Create a centralized helper for Firebase testing to reduce boilerplate and ensure consistency.

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
      print('Connected to Firebase emulators');
    } catch (e) {
      _connectionTimeout?.cancel();
      print('Failed to connect to Firebase emulators: $e');
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

**Usage**:
```dart
@Tags(['integration', 'firebase'])
void main() {
  setUpAll(() async {
    await FirebaseTestHelper.connectToEmulators();
  });

  setUp(() async {
    await FirebaseTestHelper.clearFirestoreData();
  });

  test('Firebase operation', () async {
    // Your test here
  });
}
```

---

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

**Output**:
```
Emulator Hub running at localhost:4400
Firestore Emulator running at localhost:8080
Auth Emulator running at localhost:9099
Storage Emulator running at localhost:9199
```

### 4. View Emulator UI

Navigate to http://localhost:4000 to see the Emulator Suite UI.

**Features**:
- View Firestore collections and documents
- View Auth users
- View Storage files
- Monitor real-time activity
- Clear data between tests

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

---

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

---

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

**Benefits**:
- Automated testing on every PR
- Parallel test execution
- Coverage reporting
- Fast feedback on failures

---

## Related Documentation

- **[TESTING_COMPLETE_GUIDE.md](./TESTING_COMPLETE_GUIDE.md)** - Complete testing guide
- **[TEST_PATTERNS_QUICK_REFERENCE.md](./TEST_PATTERNS_QUICK_REFERENCE.md)** - Quick pattern lookup
- **[INTEGRATION_TESTING.md](./INTEGRATION_TESTING.md)** - Integration testing patterns
- **[WIDGET_E2E_TESTING.md](./WIDGET_E2E_TESTING.md)** - Widget and E2E testing patterns
- **[TESTING_DASHBOARD.md](./TESTING_DASHBOARD.md)** - Current test coverage and priorities

---

**Last Updated**: January 2025
**Maintained By**: Butlery Development Team
