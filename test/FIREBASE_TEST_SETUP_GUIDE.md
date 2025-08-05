# Firebase Test Setup Guide

## Overview

The Firebase test environment is now fully configured for safe, isolated testing. This setup provides three testing modes to suit different test scenarios.

## Test Modes

### 1. Mock Mode (Default) ✅
- **Use for**: Unit tests, widget tests
- **Features**: No real Firebase connection, instant responses, deterministic behavior
- **Setup**: Automatic (default mode)

### 2. Emulator Mode
- **Use for**: Integration tests, realistic Firebase behavior
- **Features**: Real Firebase APIs, isolated from production, resetable data
- **Setup**: Requires Firebase emulators running

### 3. Test Project Mode
- **Use for**: Full end-to-end tests
- **Features**: Real Firebase project (separate from production)
- **Setup**: Requires test Firebase project configuration

## Configuration Files Created

1. **`lib/firebase_options_test.dart`**
   - Test-specific Firebase configuration
   - Safe test project IDs and keys
   - Isolated from production Firebase

2. **`test/helpers/firebase_test_setup.dart`**
   - Main Firebase test configuration
   - Test mode management
   - Data seeding utilities

3. **Updated `test/test_configuration.dart`**
   - Automatic Firebase initialization
   - Clean state between tests
   - Integrated with existing test setup

## Usage Examples

### Basic Unit Test (Uses Mocks Automatically)
```dart
void main() {
  configureTests(); // Firebase mocks initialized automatically
  
  test('create recipe in Firebase', () async {
    // Firebase is mocked - no real connection
    final recipe = TestServiceLocator.createTestRecipe();
    
    // This uses the mock Firestore
    await FirebaseEmulatorHelper.firestore
        .collection('recipes')
        .add(recipe.toMap());
    
    // Verify it was added
    final snapshot = await FirebaseEmulatorHelper.firestore
        .collection('recipes')
        .get();
    expect(snapshot.docs, hasLength(1));
  });
}
```

### Integration Test with Emulators
```dart
void main() {
  group('Recipe Integration Tests', () {
    setUpAll(() async {
      // Use emulator mode for more realistic testing
      await FirebaseTestSetup.initialize(
        mode: FirebaseTestMode.emulators,
      );
    });
    
    test('full recipe workflow', () async {
      // Create test user
      final user = await FirebaseTestSetup.createTestUser(
        email: 'chef@test.com',
        displayName: 'Test Chef',
      );
      
      // Seed test data
      await FirebaseTestSetup.seedTestData(
        recipes: [
          FirebaseTestData.generateRecipe(
            title: 'Pasta Carbonara',
            userId: user.uid,
          ),
        ],
      );
      
      // Test with real Firebase APIs (emulated)
      final recipes = await FirebaseEmulatorHelper.firestore
          .collection('recipes')
          .where('userId', isEqualTo: user.uid)
          .get();
          
      expect(recipes.docs, hasLength(1));
    });
  });
}
```

### Using Test Scenarios
```dart
void main() {
  configureTests();
  
  group('Social Features', () {
    setUp(() async {
      // Set up a complete social scenario
      await FirebaseTestScenarios.setupSocialScenario();
    });
    
    test('friend can see shared recipe', () async {
      // Test data is already seeded with users and friendships
      final friendsSnapshot = await FirebaseEmulatorHelper.firestore
          .collection('friends')
          .get();
      
      expect(friendsSnapshot.docs, isNotEmpty);
    });
  });
}
```

## Running Tests

### With Mocks (Default)
```bash
# Just run tests normally - mocks are used automatically
cmd.exe /c "flutter test"
```

### With Emulators
```bash
# 1. Start Firebase emulators first
firebase emulators:start --project butlery-test

# 2. Run tests that use emulator mode
cmd.exe /c "flutter test test/integration"
```

## Common Patterns

### 1. Test User Creation
```dart
final user = await FirebaseTestSetup.createTestUser(
  email: 'test@example.com',
  displayName: 'Test User',
  verified: true,
);
```

### 2. Data Seeding
```dart
await FirebaseTestSetup.seedTestData(
  recipes: [/* recipe data */],
  users: [/* user data */],
  customData: {
    'customCollection': {/* custom docs */}
  },
);
```

### 3. Accessing Firebase Services
```dart
// Firestore (works in all modes)
final firestore = FirebaseEmulatorHelper.firestore;

// Auth (works in all modes)
final auth = FirebaseEmulatorHelper.auth;

// Storage (works in all modes)
final storage = FirebaseEmulatorHelper.storage;
```

## Best Practices

1. **Use Mocks for Unit Tests**: Faster, more reliable, no external dependencies
2. **Use Emulators for Integration Tests**: More realistic, still isolated
3. **Always Clean State**: Tests automatically reset Firebase between runs
4. **Seed Minimal Data**: Only create data needed for specific test
5. **Use Test Scenarios**: Leverage pre-built scenarios for common setups

## Troubleshooting

### "Firebase not initialized" Error
- Make sure to call `configureTests()` at the start of your test file
- This automatically initializes Firebase with mocks

### "Emulators not running" Error
- Start emulators: `firebase emulators:start --project butlery-test`
- Or switch to mock mode (default)

### Test Data Not Cleaned Up
- The test configuration automatically resets Firebase between tests
- If needed, manually call: `await FirebaseTestSetup.reset()`

## Security Notes

- Test Firebase configuration is completely isolated from production
- Test project ID: `butlery-test` (not your real project)
- Safe to run tests without affecting any real data
- Mock mode doesn't connect to any external services

## Next Steps

1. ✅ Firebase test environment is ready
2. ✅ Tests can now safely interact with Firebase
3. Next: Generate golden files for visual regression tests
4. Then: Fix individual test failures