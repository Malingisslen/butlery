# Firebase Integration Tests

## Overview
These tests verify actual Firebase operations using the Firebase Emulator Suite.
They test real FieldValue operations, complex queries, and Firebase-specific behavior.

## Setup

### 1. Install Firebase Emulator
```bash
npm install -g firebase-tools
firebase init emulators
```

### 2. Configure Emulator
Select Firestore emulator and use default ports:
- Firestore: 8080
- Auth: 9099

### 3. Run Tests
```bash
# Start emulator and run tests
firebase emulators:exec --only firestore,auth "flutter test test/integration/firebase --tags integration"

# Or start emulator separately
firebase emulators:start --only firestore,auth
flutter test test/integration/firebase --tags integration
```

## Test Structure

```
integration/
├── firebase/
│   ├── repositories/
│   │   ├── firebase_social_recipe_repository_integration_test.dart
│   │   ├── firebase_user_repository_integration_test.dart
│   │   └── firebase_messaging_repository_integration_test.dart
│   ├── field_values/
│   │   └── field_value_operations_test.dart
│   └── setup/
│       └── firebase_test_setup.dart
```

## Test Categories

### Repository Integration Tests
Test actual Firebase repository implementations with:
- Real FieldValue.serverTimestamp()
- Real FieldValue.arrayUnion()
- Real FieldValue.increment()
- Complex Firestore queries
- Transaction operations
- Batch writes

### Field Value Operations
Specific tests for Firebase server-side operations:
- Timestamp generation
- Array manipulation
- Atomic increments
- Server-side validation

## CI/CD Configuration

```yaml
# .github/workflows/test.yml
jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter test --exclude-tags integration
  
  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: npm install -g firebase-tools
      - run: |
          firebase emulators:exec --only firestore,auth \
            "flutter test --tags integration"
```

## Writing Integration Tests

```dart
@Tags(['integration'])
void main() {
  group('Firebase Integration', () {
    setUpAll(() async {
      await FirebaseTestSetup.initialize();
    });
    
    test('FieldValue.serverTimestamp works', () async {
      final doc = await FirebaseFirestore.instance
          .collection('test')
          .add({
            'timestamp': FieldValue.serverTimestamp(),
          });
      
      final snapshot = await doc.get();
      expect(snapshot.data()!['timestamp'], isA<Timestamp>());
    });
  });
}
```

## Benefits
- Tests real Firebase behavior
- Catches Firebase-specific bugs
- Validates complex operations
- No production data impact
- Reproducible test environment